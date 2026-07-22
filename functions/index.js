const { onCall, HttpsError } = require('firebase-functions/v1/https');
const { defineSecret } = require('firebase-functions/params');
const admin = require('firebase-admin');
const { getFirestore } = require('firebase-admin/firestore');

admin.initializeApp();

const db = getFirestore(admin.app(), 'hungarian-hardstyle');
const ADMIN_EMAIL = 'djdeeroy@gmail.com';
const WORDPRESS_BASE_URL = 'https://hungarianhardstyle.hu/wp-json/huhs/v1';
const WORDPRESS_USERNAME = defineSecret('WORDPRESS_USERNAME');
const WORDPRESS_APPLICATION_PASSWORD = defineSecret('WORDPRESS_APPLICATION_PASSWORD');

const submissionRoutes = {
  event: { path: '/event-submissions', role: null },
  artist: { path: '/artist-submissions', role: 'dj' },
  organizer: { path: '/organizer-submissions', role: 'organizer' },
};

function isAdmin(context, profile) {
  return String(context.auth?.token?.email || '').trim().toLowerCase() === ADMIN_EMAIL
    || profile.accessRole === 'admin';
}

exports.submitWordPressContent = onCall(
  { secrets: [WORDPRESS_USERNAME, WORDPRESS_APPLICATION_PASSWORD] },
  async (data, context) => {
    if (!context.auth || context.auth.token.firebase?.sign_in_provider === 'anonymous') {
      throw new HttpsError('permission-denied', 'Regisztráció szükséges a beküldéshez.');
    }

    const route = submissionRoutes[String(data?.kind || '')];
    const payload = data?.payload;
    if (!route || !payload || typeof payload !== 'object' || Array.isArray(payload)) {
      throw new HttpsError('invalid-argument', 'Érvénytelen beküldési adat.');
    }

    const profileSnapshot = await db.collection('community_profiles').doc(context.auth.uid).get();
    const profile = profileSnapshot.data() || {};
    if (!isAdmin(context, profile) && route.role && profile.role !== route.role) {
      throw new HttpsError('permission-denied', 'Ehhez a beküldéshez nincs jogosultságod.');
    }

    const credentials = `${WORDPRESS_USERNAME.value()}:${WORDPRESS_APPLICATION_PASSWORD.value()}`;
    const response = await fetch(`${WORDPRESS_BASE_URL}${route.path}`, {
      method: 'POST',
      headers: {
        Authorization: `Basic ${Buffer.from(credentials).toString('base64')}`,
        'Content-Type': 'application/json',
        Accept: 'application/json',
      },
      body: JSON.stringify(payload),
    });
    const body = await response.json().catch(() => ({}));
    if (!response.ok) {
      throw new HttpsError('failed-precondition', body.message || 'A WordPress beküldés sikertelen.');
    }
    return body;
  },
);

exports.deleteCommunityUser = onCall(async (data, context) => {
  const email = String(context.auth?.token?.email || '').trim().toLowerCase();
  if (!context.auth) {
    throw new HttpsError('permission-denied', 'Csak admin törölhet felhasználót.');
  }

  const uid = String(data?.uid || '').trim();
  if (!uid) {
    throw new HttpsError('invalid-argument', 'Érvényes felhasználó szükséges.');
  }

  if (uid !== context.auth.uid) {
    const callerProfile = await db.collection('community_profiles').doc(context.auth.uid).get();
    const callerData = callerProfile.data() || {};
    if (
      email !== ADMIN_EMAIL &&
      callerData.accessRole !== 'admin' &&
      callerData.role !== 'admin'
    ) {
      throw new HttpsError('permission-denied', 'Only admins can delete users.');
    }
  }

  try {
    await admin.auth().deleteUser(uid);
  } catch (error) {
    // Make retries safe when Auth was already deleted but Firestore cleanup did not finish.
    if (error?.code !== 'auth/user-not-found') throw error;
  }
  await db.collection('community_profiles').doc(uid).delete();

  const posts = await db
    .collection('live_feed_posts')
    .where('authorId', '==', uid)
    .get();
  for (let index = 0; index < posts.docs.length; index += 400) {
    const batch = db.batch();
    posts.docs.slice(index, index + 400).forEach((post) => batch.delete(post.ref));
    await batch.commit();
  }

  return { deleted: true, uid };
});
