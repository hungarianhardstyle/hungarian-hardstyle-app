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
const callWindows = new Map();

// ponytail: process-local limit; move to a shared counter only if traffic exceeds one instance.
function allowCall(uid, key, limit = 20) {
  const now = Date.now();
  const bucketKey = `${key}:${uid}`;
  const current = callWindows.get(bucketKey) || { started: now, count: 0 };
  if (now - current.started >= 60_000) {
    callWindows.set(bucketKey, { started: now, count: 1 });
    return true;
  }
  if (current.count >= limit) return false;
  current.count += 1;
  callWindows.set(bucketKey, current);
  return true;
}

function securityLog(event, context) {
  const uid = String(context.auth?.uid || 'anonymous');
  console.warn(JSON.stringify({ event, uid: uid.slice(0, 8) }));
}

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
    if (!allowCall(context.auth.uid, 'submission')) {
      securityLog('submission_rate_limited', context);
      throw new HttpsError('resource-exhausted', 'Túl sok beküldés, próbáld később.');
    }

    const route = submissionRoutes[String(data?.kind || '')];
    const payload = data?.payload;
    if (!route || !payload || typeof payload !== 'object' || Array.isArray(payload)) {
      throw new HttpsError('invalid-argument', 'Érvénytelen beküldési adat.');
    }
    if (JSON.stringify(payload).length > 512_000) {
      throw new HttpsError('invalid-argument', 'A beküldés túl nagy.');
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

exports.listWordPressSubmissions = onCall(
  { secrets: [WORDPRESS_USERNAME, WORDPRESS_APPLICATION_PASSWORD] },
  async (data, context) => {
    if (!context.auth) {
      throw new HttpsError('permission-denied', 'Csak admin tekintheti meg a beküldéseket.');
    }
    const profile = (await db.collection('community_profiles').doc(context.auth.uid).get()).data() || {};
    if (!isAdmin(context, profile)) {
      throw new HttpsError('permission-denied', 'Csak admin tekintheti meg a beküldéseket.');
    }
    if (!allowCall(context.auth.uid, 'wp_admin')) {
      securityLog('wp_admin_rate_limited', context);
      throw new HttpsError('resource-exhausted', 'Túl sok admin művelet, próbáld később.');
    }
    const credentials = `${WORDPRESS_USERNAME.value()}:${WORDPRESS_APPLICATION_PASSWORD.value()}`;
    const response = await fetch(
      'https://hungarianhardstyle.hu/wp-json/wp/v2/huhs_submission?status=pending&per_page=100&_fields=id,date,title,link,content,excerpt,type,post_type',
      { headers: { Authorization: `Basic ${Buffer.from(credentials).toString('base64')}`, Accept: 'application/json' } },
    );
    const body = await response.json().catch(() => []);
    if (!response.ok) {
      throw new HttpsError('failed-precondition', body?.message || 'A WordPress beküldések nem tölthetők be.');
    }
    return Array.isArray(body) ? body.map((item) => ({
      id: item.id,
      date: item.date,
      title: item.title?.rendered || '',
      link: item.link || '',
      content: item.content?.rendered || '',
      excerpt: item.excerpt?.rendered || '',
      type: item.type || item.post_type || '',
    })) : [];
  },
);

exports.manageWordPressSubmission = onCall(
  { secrets: [WORDPRESS_USERNAME, WORDPRESS_APPLICATION_PASSWORD] },
  async (data, context) => {
    if (!context.auth) {
      throw new HttpsError('permission-denied', 'Csak admin kezelheti a beküldéseket.');
    }
    const profile = (await db.collection('community_profiles').doc(context.auth.uid).get()).data() || {};
    if (!isAdmin(context, profile)) {
      throw new HttpsError('permission-denied', 'Csak admin kezelheti a beküldéseket.');
    }
    if (!allowCall(context.auth.uid, 'wp_admin')) {
      securityLog('wp_admin_rate_limited', context);
      throw new HttpsError('resource-exhausted', 'Túl sok admin művelet, próbáld később.');
    }
    const id = Number(data?.id);
    const action = String(data?.action || '');
    if (!Number.isInteger(id) || id <= 0 || !['approve', 'trash'].includes(action)) {
      throw new HttpsError('invalid-argument', 'Érvénytelen beküldés-művelet.');
    }
    const credentials = `${WORDPRESS_USERNAME.value()}:${WORDPRESS_APPLICATION_PASSWORD.value()}`;
    const url = action === 'approve'
      ? `${WORDPRESS_BASE_URL}/submissions/${id}/approve`
      : `https://hungarianhardstyle.hu/wp-json/wp/v2/huhs_submission/${id}`;
    const response = await fetch(
      url,
      {
        method: action === 'approve' ? 'POST' : 'DELETE',
        headers: {
          Authorization: `Basic ${Buffer.from(credentials).toString('base64')}`,
          Accept: 'application/json',
        },
      },
    );
    const body = await response.json().catch(() => ({}));
    if (!response.ok) {
      throw new HttpsError('failed-precondition', body?.message || 'A WordPress művelet sikertelen.');
    }
    return { ok: true, action, id, profileId: body?.profile_id || null };
  },
);

exports.updateWordPressSubmission = onCall(
  { secrets: [WORDPRESS_USERNAME, WORDPRESS_APPLICATION_PASSWORD] },
  async (data, context) => {
    if (!context.auth) {
      throw new HttpsError('permission-denied', 'Csak admin szerkeszthet beküldést.');
    }
    const profile = (await db.collection('community_profiles').doc(context.auth.uid).get()).data() || {};
    if (!isAdmin(context, profile)) {
      throw new HttpsError('permission-denied', 'Csak admin szerkeszthet beküldést.');
    }
    if (!allowCall(context.auth.uid, 'wp_admin')) {
      securityLog('wp_admin_rate_limited', context);
      throw new HttpsError('resource-exhausted', 'Túl sok admin művelet, próbáld később.');
    }
    const id = Number(data?.id);
    const title = String(data?.title || '').trim();
    const content = String(data?.content || '');
    if (!Number.isInteger(id) || id <= 0 || !title || title.length > 300 || content.length > 512_000) {
      throw new HttpsError('invalid-argument', 'Érvénytelen beküldési adat.');
    }
    const credentials = `${WORDPRESS_USERNAME.value()}:${WORDPRESS_APPLICATION_PASSWORD.value()}`;
    const response = await fetch(`https://hungarianhardstyle.hu/wp-json/wp/v2/huhs_submission/${id}`, {
      method: 'PUT',
      headers: {
        Authorization: `Basic ${Buffer.from(credentials).toString('base64')}`,
        'Content-Type': 'application/json',
        Accept: 'application/json',
      },
      body: JSON.stringify({ title, content }),
    });
    const body = await response.json().catch(() => ({}));
    if (!response.ok) {
      throw new HttpsError('failed-precondition', body?.message || 'A WordPress beküldés mentése sikertelen.');
    }
    return { ok: true, id, title: body?.title?.rendered || title };
  },
);

exports.deleteCommunityUser = onCall(async (data, context) => {
  const email = String(context.auth?.token?.email || '').trim().toLowerCase();
  if (!context.auth) {
    throw new HttpsError('permission-denied', 'Csak admin törölhet felhasználót.');
  }
  if (!allowCall(context.auth.uid, 'user_delete', 10)) {
    securityLog('user_delete_rate_limited', context);
    throw new HttpsError('resource-exhausted', 'Túl sok törlési művelet, próbáld később.');
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

  securityLog('community_user_deleted', context);

  return { deleted: true, uid };
});
