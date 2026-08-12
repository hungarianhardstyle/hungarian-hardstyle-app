const functions = require('firebase-functions/v1');
const { onDocumentWritten } = require('firebase-functions/v2/firestore');
const { HttpsError } = functions.https;
const { defineSecret } = require('firebase-functions/params');
const crypto = require('crypto');
const admin = require('firebase-admin');
const { getFirestore } = require('firebase-admin/firestore');
const { google } = require('googleapis');

admin.initializeApp();

const db = getFirestore(admin.app(), 'hungarian-hardstyle');
const ADMIN_EMAIL = 'djdeeroy@gmail.com';
const WORDPRESS_BASE_URL = 'https://hungarianhardstyle.hu/wp-json/huhs/v1';
const WORDPRESS_USERNAME = defineSecret('WORDPRESS_USERNAME');
const WORDPRESS_APPLICATION_PASSWORD = defineSecret('WORDPRESS_APPLICATION_PASSWORD');
const GOOGLE_PLAY_SERVICE_ACCOUNT_JSON = defineSecret('GOOGLE_PLAY_SERVICE_ACCOUNT_JSON');
const GOOGLE_PLAY_PACKAGE_NAME = 'hu.hungarianhardstyle.app';
const callWindows = new Map();
const wordPressCall = (handler) => functions
  .runWith({ secrets: [WORDPRESS_USERNAME, WORDPRESS_APPLICATION_PASSWORD] })
  .https.onCall(handler);

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

exports.submitWordPressContent = wordPressCall(
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

exports.listWordPressSubmissions = wordPressCall(
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

exports.manageWordPressSubmission = wordPressCall(
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

exports.updateWordPressSubmission = wordPressCall(
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


const WORDPRESS_ADMIN_PATHS = new Set([
  '/wp/v2/huhs_event',
  '/wp/v2/huhs_artist',
  '/wp/v2/huhs_organizer',
  '/wp/v2/huhs_release',
  '/wp/v2/huhs_submission',
  '/huhs/v1/admin',
]);

exports.wordPressAdminRequest = wordPressCall(
  async (data, context) => {
    if (!context.auth) throw new HttpsError('permission-denied', 'Csak admin használhatja a WordPress vezérlőközpontot.');
    const profile = (await db.collection('community_profiles').doc(context.auth.uid).get()).data() || {};
    if (!isAdmin(context, profile)) throw new HttpsError('permission-denied', 'Csak admin használhatja a WordPress vezérlőközpontot.');
    if (!allowCall(context.auth.uid, 'wp_admin_request')) {
      securityLog('wp_admin_request_rate_limited', context);
      throw new HttpsError('resource-exhausted', 'Túl sok admin művelet, próbáld később.');
    }
    const rawPath = String(data?.path || '');
    const path = rawPath.split('?')[0];
    const method = String(data?.method || 'GET').toUpperCase();
    const isAllowedPath = WORDPRESS_ADMIN_PATHS.has(path) || [...WORDPRESS_ADMIN_PATHS].some((base) => path.startsWith(base + '/') && /^\/\d+$/.test(path.slice(base.length)));
    if (!isAllowedPath || !['GET', 'POST', 'PUT', 'DELETE'].includes(method)) {
      throw new HttpsError('invalid-argument', 'Nem engedélyezett WordPress admin útvonal vagy művelet.');
    }
    const query = rawPath.includes('?') ? `?${rawPath.split('?').slice(1).join('?')}` : '';
    const credentials = `${WORDPRESS_USERNAME.value()}:${WORDPRESS_APPLICATION_PASSWORD.value()}`;
    const options = {
      method,
      headers: {
        Authorization: `Basic ${Buffer.from(credentials).toString('base64')}`,
        Accept: 'application/json',
      },
    };
    if (method !== 'GET' && method !== 'DELETE') {
      options.headers['Content-Type'] = 'application/json';
      options.body = JSON.stringify(data?.body && typeof data.body === 'object' ? data.body : {});
    }
    const response = await fetch(`https://hungarianhardstyle.hu/wp-json${path}${query}`, options);
    const body = await response.json().catch(() => ({}));
    if (!response.ok) throw new HttpsError('failed-precondition', body?.message || 'A WordPress admin művelet sikertelen.');
    return body;
  },
);
exports.deleteCommunityUser = functions.https.onCall(async (data, context) => {
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

  let targetUser;
  try {
    targetUser = await admin.auth().getUser(uid);
  } catch (error) {
    if (error?.code === 'auth/user-not-found') targetUser = null; else throw error;
  }
  if (String(targetUser?.email || '').trim().toLowerCase() === ADMIN_EMAIL) {
    throw new HttpsError('failed-precondition', 'A fő adminisztrátori fiók nem törölhető.');
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

exports.claimArtistProfile = functions.https.onCall(async (data, context) => {
  if (!context.auth || context.auth.token.email_verified !== true) {
    throw new HttpsError('permission-denied', 'Hitelesített e-mailes fiók szükséges.');
  }
  const artistId = Number(data?.artistId);
  const email = String(context.auth.token.email || '').trim().toLowerCase();
  const isAdminClaim = email === ADMIN_EMAIL;
  if (!Number.isInteger(artistId) || artistId <= 0 || !email || email === 'info@hungarianhardstyle.hu') {
    throw new HttpsError('invalid-argument', 'Érvényes DJ-adatlap és e-mail szükséges.');
  }
  if (!allowCall(context.auth.uid, 'artist_claim', 5)) {
    throw new HttpsError('resource-exhausted', 'Túl sok claim-kérés, próbáld később.');
  }
  const claimRef = db.collection('artist_claims').doc(String(artistId));
  const existing = await claimRef.get();
  if (existing.exists && existing.data()?.uid !== context.auth.uid) {
    throw new HttpsError('already-exists', 'Ezt a DJ-adatlapot már claimelte egy másik fiók.');
  }
  const response = await fetch(`${WORDPRESS_BASE_URL}/artists/${artistId}`);
  const artist = await response.json().catch(() => ({}));
  if (!response.ok || (!isAdminClaim && String(artist?.booking_email || '').trim().toLowerCase() !== email)) {
    throw new HttpsError('permission-denied', 'A bejelentkezési e-mail nem egyezik a booking e-maillel.');
  }
  await claimRef.set({
    artistId,
    uid: context.auth.uid,
    email,
    status: 'claimed',
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  return { claimed: true, artistId };
});

exports.getArtistClaimStatus = functions.https.onCall(async (data) => {
  const artistId = Number(data?.artistId);
  if (!Number.isInteger(artistId) || artistId <= 0) {
    throw new HttpsError('invalid-argument', 'Érvényes DJ-adatlap szükséges.');
  }
  const claim = await db.collection('artist_claims').doc(String(artistId)).get();
  return { claimed: claim.exists };
});

exports.getMyClaimedArtists = functions.https.onCall(async (data, context) => {
  if (!context.auth || context.auth.token.email_verified !== true) {
    throw new HttpsError('permission-denied', 'Bejelentkezés szükséges.');
  }
  const snapshot = await db
    .collection('artist_claims')
    .where('uid', '==', context.auth.uid)
    .get();
  return {
    artistIds: snapshot.docs
      .map((doc) => Number(doc.data()?.artistId))
      .filter((id) => Number.isInteger(id) && id > 0),
  };
});

exports.verifyLabelPurchase = functions
  .runWith({ secrets: [GOOGLE_PLAY_SERVICE_ACCOUNT_JSON] })
  .https.onCall(async (data, context) => {
    if (!context.auth || context.auth.token.firebase?.sign_in_provider === 'anonymous') {
      throw new HttpsError('unauthenticated', 'Bejelentkezés szükséges a vásárláshoz.');
    }
    if (!allowCall(context.auth.uid, 'label_purchase', 10)) {
      throw new HttpsError('resource-exhausted', 'Túl sok vásárlási ellenőrzés.');
    }
    const productId = String(data?.productId || '').trim();
    const purchaseToken = String(data?.purchaseToken || '').trim();
    const releaseId = Number(data?.releaseId || 0);
    const productMatch = productId.match(/^huhs_release_([0-9]+)_(radio_wav|radio_mp3_320|extended_wav|extended_mp3_320|wav|mp3_320)$/);
    if (!productMatch || !purchaseToken || !Number.isInteger(releaseId) || releaseId < 1 || Number(productMatch[1]) !== releaseId) {
      throw new HttpsError('invalid-argument', 'Érvénytelen Label-vásárlási adat.');
    }
    let serviceAccount;
    try {
      serviceAccount = JSON.parse(GOOGLE_PLAY_SERVICE_ACCOUNT_JSON.value());
    } catch (_) {
      throw new HttpsError('failed-precondition', 'A Google Play vásárlás-ellenőrzés nincs beállítva.');
    }
    const auth = new google.auth.GoogleAuth({
      credentials: serviceAccount,
      scopes: ['https://www.googleapis.com/auth/androidpublisher'],
    });
    const androidPublisher = google.androidpublisher({ version: 'v3', auth });
    let purchase;
    try {
      purchase = await androidPublisher.purchases.products.get({
        packageName: GOOGLE_PLAY_PACKAGE_NAME,
        productId,
        token: purchaseToken,
      });
    } catch (error) {
      securityLog('label_purchase_verification_failed', context);
      throw new HttpsError('permission-denied', 'A Google Play-vásárlás nem ellenőrizhető.');
    }
    if (Number(purchase.data.purchaseState) !== 0) {
      throw new HttpsError('permission-denied', 'A vásárlás nincs teljesítve.');
    }
    const entitlement = {
      uid: context.auth.uid,
      releaseId,
      productId,
      purchaseTokenHash: crypto.createHash('sha256').update(purchaseToken).digest('hex'),
      orderId: String(purchase.data.orderId || ''),
      verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    await db.collection('label_entitlements').doc(`${context.auth.uid}_${productId}`).set(entitlement, { merge: true });
    return { verified: true, releaseId, productId };
  });

exports.getLabelDownloadUrl = functions
  .runWith({ secrets: [WORDPRESS_USERNAME, WORDPRESS_APPLICATION_PASSWORD] })
  .https.onCall(async (data, context) => {
    if (!context.auth || context.auth.token.firebase?.sign_in_provider === 'anonymous') {
      throw new HttpsError('unauthenticated', 'Bejelentkezés szükséges a letöltéshez.');
    }
    if (!allowCall(context.auth.uid, 'label_download', 10)) {
      throw new HttpsError('resource-exhausted', 'Túl sok letöltési kérés.');
    }
    const releaseId = Number(data?.releaseId || 0);
    const variant = String(data?.variant || '').trim();
    if (!Number.isInteger(releaseId) || releaseId < 1 || !['wav', 'mp3_320', 'mp3_128', 'radio_wav', 'radio_mp3_320', 'extended_wav', 'extended_mp3_320'].includes(variant)) {
      throw new HttpsError('invalid-argument', 'Érvénytelen Label-letöltési adat.');
    }
    const paid = variant !== 'mp3_128';
    const productId = `huhs_release_${releaseId}_${variant}`;
    const entitlement = paid
      ? await db.collection('label_entitlements')
        .doc(`${context.auth.uid}_${productId}`)
        .get()
      : null;
    if (paid && (!entitlement || !entitlement.exists || entitlement.data()?.releaseId !== releaseId)) {
      throw new HttpsError('permission-denied', 'Ehhez a fájlhoz nincs vásárlási jogosultság.');
    }
    if (!paid && variant === 'mp3_128') {
      const unlock = await db.collection('label_ad_unlocks').doc(`${context.auth.uid}_${releaseId}`).get();
      if (!unlock.exists || unlock.data()?.releaseId !== releaseId || Number(unlock.data()?.expiresAt || 0) < Date.now()) {
        throw new HttpsError('permission-denied', 'A 128 kbps változat feloldása szükséges.');
      }
    }
    const credentials = `${WORDPRESS_USERNAME.value()}:${WORDPRESS_APPLICATION_PASSWORD.value()}`;
    const response = await fetch(`${WORDPRESS_BASE_URL}/private-download-token`, {
      method: 'POST',
      headers: {
        Authorization: `Basic ${Buffer.from(credentials).toString('base64')}`,
        'Content-Type': 'application/json',
        Accept: 'application/json',
      },
      body: JSON.stringify({ releaseId, variant }),
    });
    const body = await response.json().catch(() => ({}));
    if (!response.ok || typeof body.download_url !== 'string') {
      throw new HttpsError('failed-precondition', body?.message || 'A Label-letöltés nem érhető el.');
    }
    return { downloadUrl: body.download_url, expiresIn: Number(body.expires_in || 300) };
  });

exports.admobRewardedSsv = functions.https.onRequest(async (req, res) => {
  try {
    const rawQuery = String(req.originalUrl || '').split('?')[1] || '';
    const params = new URLSearchParams(rawQuery);
    const transactionId = String(params.get('transaction_id') || '').trim();
    const customData = String(params.get('custom_data') || '').trim();
    // AdMob's dashboard validator does not create a real reward transaction.
    // Return success for that probe without granting anything. A probe may
    // also omit the signed callback fields entirely.
    if (params.get('user_id') || !transactionId || !params.get('signature')) {
      return res.status(200).send('validated');
    }
    const signatureMarker = '&signature=';
    const signatureStart = rawQuery.indexOf(signatureMarker);
    if (signatureStart < 0) return res.status(400).send('missing signature');
    const signedQuery = rawQuery.slice(0, signatureStart);
    const signature = String(params.get('signature') || '').trim();
    const keyId = Number(params.get('key_id') || 0);
    if (!keyId) return res.status(400).send('missing key id');
    const keyResponse = await fetch('https://www.gstatic.com/admob/reward/verifier-keys.json');
    const keyBody = await keyResponse.json();
    const key = (keyBody.keys || []).find((item) => Number(item.keyId) === keyId);
    if (!key?.pem || !signature) return res.status(400).send('unknown signing key');
    const valid = crypto.verify('sha256', Buffer.from(signedQuery, 'utf8'), { key: key.pem, dsaEncoding: 'der' }, Buffer.from(signature, 'base64url'));
    if (!valid) return res.status(400).send('invalid signature');
    if (!customData) return res.status(400).send('missing reward data');
    const decoded = JSON.parse(Buffer.from(decodeURIComponent(customData), 'base64url').toString('utf8'));
    const uid = String(decoded.uid || '').trim();
    const releaseId = Number(decoded.releaseId || 0);
    if (!uid || !Number.isInteger(releaseId) || releaseId < 1) return res.status(400).send('invalid reward data');
    const transaction = db.collection('admob_reward_transactions').doc(transactionId);
    await db.runTransaction(async (tx) => {
      if ((await tx.get(transaction)).exists) return;
      tx.set(transaction, { uid, releaseId, createdAt: admin.firestore.FieldValue.serverTimestamp() });
      tx.set(db.collection('label_ad_unlocks').doc(`${uid}_${releaseId}`), {
        uid, releaseId, expiresAt: Date.now() + 24 * 60 * 60 * 1000,
        transactionId, createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });
    return res.status(200).send('ok');
  } catch (error) {
    console.warn(JSON.stringify({ event: 'admob_ssv_failed', message: String(error?.message || error) }));
    return res.status(400).send('invalid callback');
  }
});

exports.sendPersonalizedPush = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new HttpsError('permission-denied', 'Bejelentkezés szükséges.');
  const profile = (await db.collection('community_profiles').doc(context.auth.uid).get()).data() || {};
  if (!isAdmin(context, profile)) throw new HttpsError('permission-denied', 'Csak admin küldhet célzott értesítést.');
  const kind = String(data?.kind || '');
  const id = Number(data?.id);
  const title = String(data?.title || '').trim();
  const body = String(data?.body || '').trim();
  if (!['event', 'organizer'].includes(kind) || !Number.isInteger(id) || !title || !body) {
    throw new HttpsError('invalid-argument', 'Érvényes esemény/szervező és üzenet szükséges.');
  }
  const favorites = await db.collectionGroup('favorites').where('kind', '==', kind).get();
  const tokens = [];
  for (const favorite of favorites.docs) {
    if (Number(favorite.data().id) !== id) continue;
    const userId = favorite.ref.parent.parent?.id;
    if (!userId) continue;
    const profile = (await db.collection('community_profiles').doc(userId).get()).data() || {};
    const userTokens = profile.fcmTokens;
    if (Array.isArray(userTokens)) tokens.push(...userTokens.filter((token) => typeof token === 'string'));
  }
  const uniqueTokens = [...new Set(tokens)].slice(0, 500);
  if (!uniqueTokens.length) return { sent: 0 };
  const result = await admin.messaging().sendEachForMulticast({
    tokens: uniqueTokens,
    notification: { title, body },
    data: { type: kind, id: String(id) },
  });
  return { sent: result.successCount, failed: result.failureCount };
});

exports.getVotingSummary = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new HttpsError('permission-denied', 'Csak admin tekintheti meg az összesítőt.');
  const profile = (await db.collection('community_profiles').doc(context.auth.uid).get()).data() || {};
  if (!isAdmin(context, profile)) throw new HttpsError('permission-denied', 'Csak admin tekintheti meg az összesítőt.');
  const seasonId = Number(data?.seasonId);
  if (!Number.isInteger(seasonId) || seasonId <= 0) throw new HttpsError('invalid-argument', 'Érvényes szezon szükséges.');
  const snapshot = await db.collection('voting_votes').where('seasonId', '==', seasonId).get();
  const counts = {};
  for (const doc of snapshot.docs) {
    const vote = doc.data() || {};
    const ids = Array.isArray(vote.candidateIds) ? vote.candidateIds : [vote.candidateId];
    for (const id of ids) {
      const key = `${vote.category || ''}:${id}`;
      counts[key] = (counts[key] || 0) + 1;
    }
  }
  return { totalVotes: snapshot.size, counts };
});

exports.notifyConnectionRequest = onDocumentWritten(
  {
    document: 'connection_requests/{requestId}',
    database: 'hungarian-hardstyle',
    region: 'europe-central2',
  },
  async (event) => {
    const requestId = event.params.requestId;
    const before = event.data?.before?.data() || {};
    const request = event.data?.after?.data() || {};
    console.log(JSON.stringify({
      event: 'connection_request_received',
      requestId,
      status: request.status || null,
      from: request.from || null,
      to: request.to || null,
    }));
    if (request.status !== 'pending' || !request.from || !request.to) return null;
    const beforeNotification = before.notificationRequestedAt?.toMillis?.();
    const notification = request.notificationRequestedAt?.toMillis?.();
    if (!notification || beforeNotification === notification) return null;
    const target = (await db.collection('community_profiles').doc(String(request.to)).get()).data() || {};
    const rawTokens = target.fcmTokens;
    const tokens = Array.isArray(rawTokens)
      ? rawTokens
      : rawTokens && typeof rawTokens === 'object'
        ? Object.values(rawTokens)
        : typeof rawTokens === 'string'
          ? [rawTokens]
          : [];
    if (typeof target.fcmToken === 'string') tokens.push(target.fcmToken);
    const uniqueTokens = [...new Set(
      tokens
        .filter((token) => typeof token === 'string' && token.trim())
        .map((token) => token.trim()),
    )].slice(0, 500);
    if (!uniqueTokens.length) {
      console.warn(JSON.stringify({
        event: 'connection_request_no_target_token',
        requestId,
        target: String(request.to),
      }));
      return null;
    }
    const sender = (await db.collection('community_profiles').doc(String(request.from)).get()).data() || {};
    const name = String(sender.displayName || 'Egy felhasználó').trim();
    const result = await admin.messaging().sendEachForMulticast({
      tokens: uniqueTokens,
      notification: { title: 'Új ismerősnek jelölés', body: `${name} ismerősnek jelölt.` },
      data: { type: 'connection_request', senderId: String(request.from) },
    });
    console.log(JSON.stringify({
      event: 'connection_request_push_result',
      requestId,
      target: String(request.to),
      tokenCount: uniqueTokens.length,
      successCount: result.successCount,
      failureCount: result.failureCount,
      failures: result.responses
        .filter((response) => !response.success)
        .map((response) => ({
          code: response.error?.code || 'unknown',
          message: response.error?.message || '',
        })),
    }));
    const invalidTokens = uniqueTokens.filter((_, index) => {
      const error = result.responses[index].error;
      return error?.code === 'messaging/registration-token-not-registered';
    });
    if (invalidTokens.length) {
      await db.collection('community_profiles').doc(String(request.to)).update({
        fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens),
      });
    }
    return result;
  },
);
