const { onCall, HttpsError } = require('firebase-functions/v1/https');
const admin = require('firebase-admin');

admin.initializeApp();

const db = admin.firestore();
const ADMIN_EMAIL = 'djdeeroy@gmail.com';

exports.deleteCommunityUser = onCall(async (data, context) => {
  const email = String(context.auth?.token?.email || '').trim().toLowerCase();
  if (!context.auth) {
    throw new HttpsError('permission-denied', 'Csak admin törölhet felhasználót.');
  }

  const callerProfile = await db.collection('community_profiles').doc(context.auth.uid).get();
  const callerData = callerProfile.data() || {};
  if (
    email !== ADMIN_EMAIL &&
    callerData.accessRole !== 'admin' &&
    callerData.role !== 'admin'
  ) {
    throw new HttpsError('permission-denied', 'Only admins can delete users.');
  }

  const uid = String(data?.uid || '').trim();
  if (!uid || uid === context.auth.uid) {
    throw new HttpsError('invalid-argument', 'Érvényes, másik felhasználó szükséges.');
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
