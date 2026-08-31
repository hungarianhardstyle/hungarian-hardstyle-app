const functions = require('firebase-functions/v1');
const { onDocumentCreated, onDocumentWritten } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
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
// Match the region schema returned by the current Play catalog.
const GOOGLE_PLAY_REGIONS_VERSION = '2025/03';
let labelProductSyncRunning = false;
let achievementBadgesCache = null;
let achievementBadgesCacheAt = 0;
const ACHIEVEMENT_BADGES_CACHE_TTL_MS = 5 * 60 * 1000;
let eventExpiryCacheAt = 0;
let eventExpiryCache = null;
const VALID_EVENT_IDS_CACHE_TTL_MS = 5 * 60 * 1000;
const wordPressCall = (handler) => functions
  .runWith({ secrets: [WORDPRESS_USERNAME, WORDPRESS_APPLICATION_PASSWORD] })
  .https.onCall(handler);

const labelProductSyncSecrets = [
  WORDPRESS_USERNAME,
  WORDPRESS_APPLICATION_PASSWORD,
  GOOGLE_PLAY_SERVICE_ACCOUNT_JSON,
];

async function allowCall(uid, key, limit = 20) {
  const bucket = Math.floor(Date.now() / 60_000);
  const ref = db.collection('rate_limits').doc(crypto
    .createHash('sha256').update(`${key}:${uid}:${bucket}`).digest('hex'));
  let allowed = false;
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const count = Number(snapshot.data()?.count || 0);
    allowed = count < limit;
    if (allowed) {
      transaction.set(ref, { key, uid, bucket, count: count + 1, updatedAt: admin.firestore.FieldValue.serverTimestamp() });
    }
  });
  return allowed;
}

const defaultAchievementBadges = [
  { slug: 'starter', name: 'Kezdő ütem', min_points: 0, description: 'A HUHS közösség alapjelvénye.', image_url: '' },
  { slug: 'first-step', name: 'Első lépés', min_points: 100, description: 'Az első közösségi mérföldkő.', image_url: '' },
  { slug: 'regular', name: 'Rendszeres látogató', min_points: 300, description: 'Rendszeresen jelen van a közösségben.', image_url: '' },
  { slug: 'hardstyle-face', name: 'Hardstyle arc', min_points: 700, description: 'Láthatóan aktív HUHS-közösségi tag.', image_url: '' },
  { slug: 'community', name: 'Közösségi ember', min_points: 1500, description: 'Sokat tesz a közösségi jelenlétért.', image_url: '' },
  { slug: 'scene-veteran', name: 'Scene veteran', min_points: 3000, description: 'Hosszú távon aktív színtértag.', image_url: '' },
  { slug: 'huhs-legend', name: 'HUHS legenda', min_points: 6000, description: 'Kiemelkedő, tartós közösségi aktivitás.', image_url: '' },
];

async function getAchievementBadges() {
  if (achievementBadgesCache && Date.now() - achievementBadgesCacheAt < ACHIEVEMENT_BADGES_CACHE_TTL_MS) return achievementBadgesCache;
  try {
    const response = await fetch(`${WORDPRESS_BASE_URL}/achievements/badges`, { headers: { Accept: 'application/json' } });
    const body = await response.json();
    if (response.ok && Array.isArray(body) && body.length) {
      achievementBadgesCache = body.filter((badge) => badge.active !== 0).map((badge) => ({
        slug: String(badge.slug || '').trim(), name: String(badge.name || 'HUHS jelvény').trim(),
        min_points: Math.max(0, Number(badge.min_points || 0)),
        description: String(badge.description || '').trim(), image_url: String(badge.image_url || '').trim(),
      })).filter((badge) => badge.slug);
      achievementBadgesCacheAt = Date.now();
    }
  } catch (error) {
    console.warn(JSON.stringify({ event: 'achievement_catalog_fallback', message: error?.message || String(error) }));
  }
  achievementBadgesCache = achievementBadgesCache || defaultAchievementBadges;
  achievementBadgesCacheAt = Date.now();
  return achievementBadgesCache;
}

async function getValidEventIds() {
  const now = Date.now();
  if (eventExpiryCache && now - eventExpiryCacheAt < VALID_EVENT_IDS_CACHE_TTL_MS) {
    return new Set([...eventExpiryCache.entries()]
      .filter(([, expiry]) => expiry >= now)
      .map(([id]) => id));
  }
  try {
    const response = await fetch(`${WORDPRESS_BASE_URL}/events?summary=true&include_past=true`, { headers: { Accept: 'application/json' } });
    const body = await response.json();
    // An unavailable WordPress endpoint is not proof that every event is
    // invalid. Keep this distinct from an empty, successfully loaded catalog
    // so a transient outage cannot roll back legitimate user writes.
    if (!response.ok || !Array.isArray(body)) return null;
    eventExpiryCache = new Map(body
      .map((event) => [Number(event?.id), eventExpiryTimestamp(event)])
      .filter(([id, expiry]) => Number.isInteger(id) && id > 0 && Number.isFinite(expiry)));
    const validEventIds = new Set([...eventExpiryCache.entries()]
      .filter(([, expiry]) => expiry >= now)
      .map(([id]) => id));
    eventExpiryCacheAt = Date.now();
    return validEventIds;
  } catch (error) {
    console.warn(JSON.stringify({ event: 'event_validation_failed', message: error?.message || String(error) }));
    return null;
  }
}

function eventExpiryTimestamp(event) {
  const dateText = String(event?.end_date || event?.start_date || '').trim();
  if (!dateText) return NaN;
  const timeText = String(
    event?.end_date ? (event?.end_time || '') : (event?.start_time || ''),
  ).trim();
  return Date.parse(`${dateText}T${timeText || '23:59:59'}`);
}

function sameEventState(before, after) {
  const comparable = (data) => Object.fromEntries(Object.entries(data || {})
    .filter(([key]) => key !== 'updatedAt' && key !== '_huhsExpiredEventReverted')
    .sort(([first], [second]) => first.localeCompare(second)));
  return JSON.stringify(comparable(before)) === JSON.stringify(comparable(after));
}

async function restoreExpiredEventWrite(event, before, after) {
  const afterExists = event.data?.after?.exists === true;
  const beforeExists = event.data?.before?.exists === true;
  if (afterExists && after?._huhsExpiredEventReverted === true &&
      before?._huhsExpiredEventReverted !== true) return true;
  if (!beforeExists && !afterExists) return true;
  if (beforeExists && afterExists && sameEventState(before, after)) return true;
  const reference = event.data?.after?.ref || event.data?.before?.ref;
  if (!reference) return true;
  if (beforeExists) {
    await reference.set({ ...before, _huhsExpiredEventReverted: true });
  } else if (afterExists) {
    await reference.delete();
  }
  return true;
}

async function awardAchievementPoints(uid, delta, sourceKey) {
  if (!uid || !Number.isInteger(delta) || delta === 0 || !sourceKey) return { changed: false };
  const ledgerId = crypto.createHash('sha256').update(`${uid}:${sourceKey}:${delta > 0 ? 'grant' : 'revoke'}`).digest('hex').slice(0, 40);
  const ledgerRef = db.collection('achievement_ledger').doc(ledgerId);
  const profileRef = db.collection('community_profiles').doc(uid);
  let result = { changed: false };
  await db.runTransaction(async (transaction) => {
    const ledger = await transaction.get(ledgerRef);
    if (ledger.exists) return;
    const profile = await transaction.get(profileRef);
    // Anonymous interactions may still use public features such as news
    // reactions, but they never have an achievement profile and must not
    // receive points or cause one to be created implicitly.
    if (!profile.exists) return;
    const current = Math.max(0, Number(profile.data()?.achievementPoints || 0));
    const points = Math.max(0, current + delta);
    const badges = await getAchievementBadges();
    const badge = badges.filter((item) => points >= item.min_points).sort((a, b) => b.min_points - a.min_points)[0] || defaultAchievementBadges[0];
    transaction.set(profileRef, {
      achievementPoints: points,
      achievementBadge: {
        slug: badge.slug, name: badge.name, description: badge.description,
        imageUrl: badge.image_url || '',
      },
      achievementUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    transaction.create(ledgerRef, {
      uid, sourceKey, delta, pointsAfter: points,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    result = { changed: true, points, badge: badge.slug };
  });
  return result;
}

function normalizeReferralCode(value) {
  return String(value || '').trim().toUpperCase().replace(/[^A-Z0-9]/g, '').slice(0, 16);
}

function referralCodeForUid(uid) {
  return crypto.createHash('sha256').update(`huhs-referral:${uid}`).digest('hex').slice(0, 8).toUpperCase();
}

exports.getMyReferralCode = functions.https.onCall(async (data, context) => {
  const uid = String(context.auth?.uid || '').trim();
  if (!uid || context.auth?.token?.firebase?.sign_in_provider === 'anonymous') {
    throw new HttpsError('unauthenticated', 'Bejelentkezés szükséges.');
  }
  const profileRef = db.collection('community_profiles').doc(uid);
  let code = '';
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(profileRef);
    if (!snapshot.exists) throw new HttpsError('not-found', 'A profil nem található.');
    code = normalizeReferralCode(snapshot.data()?.referralCode) || referralCodeForUid(uid);
    if (snapshot.data()?.referralCode !== code) {
      transaction.set(profileRef, { referralCode: code }, { merge: true });
    }
  });
  return { code };
});

exports.claimReferralCode = functions.https.onCall(async (data, context) => {
  const uid = String(context.auth?.uid || '').trim();
  if (!uid || context.auth?.token?.firebase?.sign_in_provider === 'anonymous') {
    throw new HttpsError('unauthenticated', 'Bejelentkezés szükséges.');
  }
  const code = normalizeReferralCode(data?.code);
  if (code.length < 6) throw new HttpsError('invalid-argument', 'Érvénytelen ajánlókód.');
  const authUser = await admin.auth().getUser(uid);
  const createdAt = authUser.metadata.creationTime ? new Date(authUser.metadata.creationTime) : null;
  if (!createdAt || Date.now() - createdAt.getTime() > 24 * 60 * 60 * 1000) {
    throw new HttpsError('failed-precondition', 'Ajánlókód csak új regisztrációnál használható.');
  }
  const matches = await db.collection('community_profiles').where('referralCode', '==', code).limit(2).get();
  const inviter = matches.docs.find((doc) => doc.id !== uid);
  if (!inviter) throw new HttpsError('not-found', 'Az ajánlókód nem található.');
  const inviteeRef = db.collection('community_profiles').doc(uid);
  await db.runTransaction(async (transaction) => {
    const invitee = await transaction.get(inviteeRef);
    if (!invitee.exists) throw new HttpsError('failed-precondition', 'A profil még nem készült el.');
    const current = invitee.data() || {};
    if (current.referredBy) return;
    transaction.set(inviteeRef, {
      referredBy: inviter.id,
      referralClaimedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
  });
  return { claimed: true };
});

exports.awardAchievementFromReferral = onDocumentWritten({
  document: 'community_profiles/{userId}', database: 'hungarian-hardstyle', region: 'europe-central2',
}, async (event) => {
  const before = event.data?.before?.data() || {};
  const after = event.data?.after?.data() || {};
  const invitedBy = String(after.referredBy || '').trim();
  if (!invitedBy || before.referredBy || after.referralRewardGranted === true) return null;
  const userId = String(event.params.userId || '').trim();
  const result = await awardAchievementPoints(invitedBy, 50, `referral:${userId}`);
  await event.data.after.ref.update({
    referralRewardGranted: true,
    referralRewardGrantedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  console.log(JSON.stringify({ event: 'achievement_referral', inviterUid: invitedBy, invitedUid: userId, result }));
  return result;
});

exports.refreshAchievementBadge = functions.https.onCall(async (data, context) => {
  const uid = String(context.auth?.uid || '').trim();
  if (!uid) throw new functions.https.HttpsError('unauthenticated', 'Bejelentkezés szükséges.');

  const profileRef = db.collection('community_profiles').doc(uid);
  const result = await db.runTransaction(async (transaction) => {
    const profileSnapshot = await transaction.get(profileRef);
    if (!profileSnapshot.exists) {
      throw new functions.https.HttpsError('not-found', 'A profil nem található.');
    }
    const profile = profileSnapshot.data() || {};
    const points = Math.max(0, Number(profile.achievementPoints || 0));
    const badges = await getAchievementBadges();
    const badge = badges
      .filter((item) => points >= item.min_points)
      .sort((a, b) => b.min_points - a.min_points)[0] || defaultAchievementBadges[0];
    const achievementBadge = {
      slug: badge.slug,
      name: badge.name,
      description: badge.description,
      imageUrl: badge.image_url || '',
    };
    const current = profile.achievementBadge || {};
    if (current.slug !== achievementBadge.slug || current.imageUrl !== achievementBadge.imageUrl ||
        current.name !== achievementBadge.name || current.description !== achievementBadge.description) {
      transaction.set(profileRef, {
        achievementBadge,
        achievementUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
    }
    return { achievementPoints: points, achievementBadge };
  });
  return result;
});

// Public profile view: return only the public achievement summary.  This is
// separate from refreshAchievementBadge so viewing somebody else's profile
// never gets access to private profile fields and does not depend on the
// client having a freshly populated community_profiles document.
exports.getPublicAchievement = functions.https.onCall(async (data, context) => {
  const viewerUid = String(context.auth?.uid || '').trim();
  const targetUid = String(data?.userId || '').trim();
  const provider = context.auth?.token?.firebase?.sign_in_provider;
  if (!viewerUid || provider === 'anonymous') {
    throw new functions.https.HttpsError('unauthenticated', 'Bejelentkezés szükséges.');
  }
  if (!targetUid || targetUid.length > 128) {
    throw new functions.https.HttpsError('invalid-argument', 'Érvénytelen felhasználó.');
  }

  const profileSnapshot = await db.collection('community_profiles').doc(targetUid).get();
  if (!profileSnapshot.exists) {
    throw new functions.https.HttpsError('not-found', 'A profil nem található.');
  }
  const profile = profileSnapshot.data() || {};
  const points = Math.max(0, Number(profile.achievementPoints || 0));
  const catalog = await getAchievementBadges();
  const stored = profile.achievementBadge && typeof profile.achievementBadge === 'object'
    ? profile.achievementBadge : {};
  const badge = catalog
    .filter((item) => points >= item.min_points)
    .sort((a, b) => b.min_points - a.min_points)[0] || defaultAchievementBadges[0];
  return {
    achievementPoints: points,
    achievementBadge: {
      slug: badge.slug,
      name: badge.name,
      description: badge.description,
      imageUrl: badge.image_url || String(stored.imageUrl || '').trim(),
    },
  };
});

function publicProfileData(profile, userId) {
  const socialLinks = profile.socialLinks && typeof profile.socialLinks === 'object'
    ? Object.fromEntries(Object.entries(profile.socialLinks)
      .filter(([key, value]) => typeof key === 'string' && typeof value === 'string')
      .map(([key, value]) => [key, String(value).trim()]))
    : {};
  const numberOr = (value, fallback) => Number.isFinite(Number(value)) ? Number(value) : fallback;
  return {
    userId,
    displayName: String(profile.displayName || '').trim(),
    role: String(profile.role || 'partygoer').trim(),
    accessRole: ['admin', 'moderator'].includes(profile.accessRole) ? profile.accessRole : 'none',
    bio: String(profile.bio || '').trim(),
    profileImageUrl: String(profile.profileImageUrl || '').trim(),
    profileFocusX: numberOr(profile.profileFocusX, 50),
    profileFocusY: numberOr(profile.profileFocusY, 25),
    profileZoom: numberOr(profile.profileZoom, 1),
    profilePanX: numberOr(profile.profilePanX, 0),
    profilePanY: numberOr(profile.profilePanY, 0),
    socialLinks,
  };
}

function requireRegisteredViewer(context) {
  const provider = context.auth?.token?.firebase?.sign_in_provider;
  if (!context.auth?.uid || provider === 'anonymous') {
    throw new functions.https.HttpsError('unauthenticated', 'Bejelentkezés szükséges.');
  }
  return String(context.auth.uid).trim();
}

// Public profile fields are deliberately projected server-side.  Do not
// return the source community_profiles document: it contains private email
// and push-token data needed by account and notification code.
exports.getPublicProfile = functions.https.onCall(async (data, context) => {
  requireRegisteredViewer(context);
  const targetUid = String(data?.userId || '').trim();
  if (!targetUid || targetUid.length > 128) {
    throw new functions.https.HttpsError('invalid-argument', 'Érvénytelen felhasználó.');
  }
  const snapshot = await db.collection('community_profiles').doc(targetUid).get();
  if (!snapshot.exists) {
    throw new functions.https.HttpsError('not-found', 'A profil nem található.');
  }
  return publicProfileData(snapshot.data() || {}, targetUid);
});

exports.getPublicProfiles = functions.https.onCall(async (data, context) => {
  requireRegisteredViewer(context);
  const snapshot = await db.collection('community_profiles').limit(200).get();
  return {
    profiles: snapshot.docs.map((doc) => publicProfileData(doc.data() || {}, doc.id)),
  };
});

function boolMap(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return {};
  return Object.fromEntries(Object.entries(value).filter(([, active]) => active === true));
}

exports.awardAchievementFromAttendance = onDocumentWritten({
  document: 'event_attendance/{eventId}/users/{userId}', database: 'hungarian-hardstyle', region: 'europe-central2',
}, async (event) => {
  const before = event.data?.before?.data() || {};
  const after = event.data?.after?.data() || {};
  const uid = String(event.params.userId || '').trim();
  const eventId = String(event.params.eventId || '').trim();
  if (!uid || !eventId) return null;
  const validEventIds = await getValidEventIds();
  if (validEventIds === null) return null;
  if (!validEventIds.has(Number(eventId))) {
    await restoreExpiredEventWrite(event, before, after);
    return null;
  }
  const beforeAttending = before.state === 'attending';
  const afterAttending = after.state === 'attending';
  if (beforeAttending === afterAttending) return null;
  const result = await awardAchievementPoints(uid, afterAttending ? 10 : -10, `attendance:${eventId}`);
  console.log(JSON.stringify({ event: 'achievement_attendance', uid, eventId, result }));
  return result;
});

exports.awardAchievementFromMeetup = onDocumentWritten({
  document: 'event_meetups/{eventId}/users/{userId}', database: 'hungarian-hardstyle', region: 'europe-central2',
}, async (event) => {
  const beforeExists = event.data?.before?.exists;
  const beforeData = event.data?.before?.data() || {};
  const after = event.data?.after?.data() || {};
  const uid = String(event.params.userId || '').trim();
  const eventId = String(event.params.eventId || '').trim();
  if (!uid || !eventId) return null;
  const validEventIds = await getValidEventIds();
  if (validEventIds === null) return null;
  if (!validEventIds.has(Number(eventId))) {
    await restoreExpiredEventWrite(event, beforeData, after);
    return null;
  }
  const results = [];
  if (!beforeExists && event.data?.after?.exists) results.push(await awardAchievementPoints(uid, 5, `meetup:${eventId}`));
  if (beforeExists && !event.data?.after?.exists) results.push(await awardAchievementPoints(uid, -5, `meetup:${eventId}`));
  const beforeInterested = boolMap(event.data?.before?.data()?.interestedBy);
  const afterInterested = boolMap(after.interestedBy);
  for (const interestedUid of Object.keys(afterInterested)) {
    if (!beforeInterested[interestedUid]) {
      results.push(await awardAchievementPoints(interestedUid, 15, `meetup-interest:${eventId}:${uid}:${interestedUid}`));
    }
  }
  for (const interestedUid of Object.keys(beforeInterested)) {
    if (!afterInterested[interestedUid]) {
      results.push(await awardAchievementPoints(interestedUid, -15, `meetup-interest:${eventId}:${uid}:${interestedUid}`));
    }
  }
  return results;
});

exports.awardAchievementFromNewsReaction = onDocumentWritten({
  document: 'news_reactions/{postId}', database: 'hungarian-hardstyle', region: 'europe-central2',
}, async (event) => {
  const before = boolMap(event.data?.before?.data()?.likedBy);
  const after = boolMap(event.data?.after?.data()?.likedBy);
  const postId = String(event.params.postId || '').trim();
  const results = [];
  for (const uid of Object.keys(after)) if (!before[uid]) results.push(await awardAchievementPoints(uid, 2, `news-like:${postId}`));
  for (const uid of Object.keys(before)) if (!after[uid]) results.push(await awardAchievementPoints(uid, -2, `news-like:${postId}`));
  return results;
});

exports.awardAchievementFromProfile = onDocumentWritten({
  document: 'community_profiles/{userId}', database: 'hungarian-hardstyle', region: 'europe-central2',
}, async (event) => {
  if (!event.data?.after?.exists) return null;
  const profile = event.data.after.data() || {};
  const uid = String(event.params.userId || '').trim();
  if (!uid) return null;
  const profileEmail = String(profile.email || '').trim().toLowerCase();
  let authEmail = '';
  try {
    authEmail = String((await admin.auth().getUser(uid)).email || '').trim().toLowerCase();
  } catch (error) {
    console.warn(JSON.stringify({ event: 'profile_achievement_auth_lookup_failed', uid: uid.slice(0, 8), message: error?.message || String(error) }));
    return null;
  }
  const complete = String(profile.displayName || '').trim()
    && String(profile.bio || '').trim()
    && profileEmail
    && authEmail
    && profileEmail === authEmail;
  if (!complete) return null;
  return awardAchievementPoints(uid, 30, 'profile-complete');
});

function securityLog(event, context) {
  const uid = String(context.auth?.uid || 'anonymous');
  console.warn(JSON.stringify({ event, uid: uid.slice(0, 8) }));
}

exports.toggleNewsReaction = functions.https.onCall(async (data, context) => {
  const uid = context.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Bejelentkezés szükséges.');

  const postId = Number(data?.postId);
  if (!Number.isInteger(postId) || postId <= 0) {
    throw new HttpsError('invalid-argument', 'Érvényes hír-azonosító szükséges.');
  }
  if (!(await allowCall(uid, 'toggleNewsReaction', 60))) {
    throw new HttpsError('resource-exhausted', 'Túl sok reakciókérés.');
  }

  const reference = db.collection('news_reactions').doc(String(postId));
  let result;
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(reference);
    const data = snapshot.data() || {};
    const rawLikedBy = data.likedBy;
    const likedBy = {};
    if (rawLikedBy && typeof rawLikedBy === 'object' && !Array.isArray(rawLikedBy)) {
      for (const [likedUid, liked] of Object.entries(rawLikedBy)) {
        if (liked === true) likedBy[likedUid] = true;
      }
    } else if (Array.isArray(rawLikedBy)) {
      for (const likedUid of rawLikedBy) {
        if (typeof likedUid === 'string' && likedUid) likedBy[likedUid] = true;
      }
    }

    const liked = likedBy[uid] === true;
    if (liked) delete likedBy[uid];
    else likedBy[uid] = true;
    const count = Object.keys(likedBy).length;
    result = { count, liked: !liked };
    transaction.set(reference, { count, likedBy });
  });
  return result;
});

function activeAdUnlock(data, releaseId, variant = 'mp3_128') {
  if (!data || data.releaseId !== releaseId) return false;
  // Older unlock documents predate variant-specific rewards and are valid for
  // the original 128 kbps reward only. New rewards must name their variant.
  if (variant === 'mp3_128' && !data.variants && !data.variant) return true;
  if (data.variant === variant) return true;
  return data.variants?.[variant] === true;
}

async function sendMulticastToAllTokens(message, tokens) {
  let successCount = 0;
  let failureCount = 0;
  // Do not rely solely on the manifest fallback: One UI versions can cache
  // or substitute the application icon differently. An explicit resource
  // name makes the HuHS notification mark deterministic across devices.
  const pushMessage = {
    ...message,
    android: {
      ...(message.android || {}),
      notification: {
        ...(message.android?.notification || {}),
        icon: 'ic_stat_huhs',
        color: '#F2383D',
      },
    },
  };
  const responses = [];
  for (let offset = 0; offset < tokens.length; offset += 500) {
    const result = await admin.messaging().sendEachForMulticast({
      ...pushMessage,
      tokens: tokens.slice(offset, offset + 500),
    });
    successCount += result.successCount;
    failureCount += result.failureCount;
    responses.push(...result.responses);
  }
  return { successCount, failureCount, responses };
}

async function getPushTokens(uid) {
  const privateData = (await db.collection('private_user_data').doc(uid).get()).data() || {};
  const legacyData = (await db.collection('community_profiles').doc(uid).get()).data() || {};
  const values = [privateData.fcmTokens, legacyData.fcmTokens, legacyData.fcmToken];
  return [...new Set(values.flatMap((raw) => Array.isArray(raw)
    ? raw
    : raw && typeof raw === 'object'
      ? Object.values(raw)
      : typeof raw === 'string' ? [raw] : [])
    .filter((token) => typeof token === 'string' && token.trim())
    .map((token) => token.trim()))];
}

// Backend-only durable inbox entries. The hash makes retries idempotent.
async function createNotification({ recipientUid, type, title, body, targetType, targetId, dedupeKey }) {
  const recipient = String(recipientUid || '').trim();
  const key = String(dedupeKey || '').trim();
  if (!recipient || !key) return;
  const notificationId = crypto.createHash('sha256').update(key).digest('hex');
  try {
    await db.collection('notifications').doc(notificationId).create({
      recipientUid: recipient,
      type: String(type || 'general').trim(),
      title: String(title || '').trim().slice(0, 120),
      body: String(body || '').trim().slice(0, 500),
      targetType: String(targetType || '').trim(),
      targetId: String(targetId || '').trim(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      readAt: null,
    });
  } catch (error) {
    if (error?.code !== 6 && error?.code !== 'already-exists') throw error;
  }
}

async function createNotificationBestEffort(payload) {
  try {
    await createNotification(payload);
  } catch (error) {
    console.warn(JSON.stringify({
      event: 'notification_write_failed',
      type: payload?.type || 'unknown',
      recipientUid: String(payload?.recipientUid || '').slice(0, 8),
      message: error?.message || String(error),
    }));
  }
}

// WordPress content is managed outside Firestore, so there is no Firestore
// create trigger to generate inbox entries. Poll only the public lightweight
// lists and keep a server-side cursor; the first run establishes a baseline
// and later runs notify only about newly published IDs.
async function pollWordPressContentNotifications() {
  const endpoints = [
    { key: 'news', path: '/posts', targetType: 'news', type: 'new_news', title: 'Új hír érkezett' },
    { key: 'release', path: '/releases', targetType: 'release', type: 'new_release', title: 'Új release érkezett' },
    { key: 'artist', path: '/artists?per_page=50', targetType: 'artist', type: 'new_artist', title: 'Új DJ került fel' },
    { key: 'organizer', path: '/organizers?per_page=50', targetType: 'organizer', type: 'new_organizer', title: 'Új szervező került fel' },
    { key: 'event', path: '/events', targetType: 'event', type: 'new_event', title: 'Új esemény érkezett' },
  ];
  const stateRef = db.collection('app_settings').doc('wordpress_content_notifications');
  const stateSnapshot = await stateRef.get();
  const previous = stateSnapshot.data()?.ids || {};
  const current = {};
  const newlyPublished = [];

  for (const endpoint of endpoints) {
    const response = await fetch(`${WORDPRESS_BASE_URL}${endpoint.path}`, {
      headers: { Accept: 'application/json' },
    });
    if (!response.ok) throw new Error(`WordPress ${endpoint.key} lista: HTTP ${response.status}`);
    const body = await response.json();
    const items = Array.isArray(body) ? body : Array.isArray(body?.items) ? body.items : [];
    const ids = items.map((item) => String(item?.id || '').trim()).filter(Boolean).slice(0, 100);
    current[endpoint.key] = ids;
    if (stateSnapshot.exists) {
      const oldIds = new Set(Array.isArray(previous[endpoint.key]) ? previous[endpoint.key] : []);
      for (const item of items) {
        const id = String(item?.id || '').trim();
        if (id && !oldIds.has(id)) newlyPublished.push({ ...endpoint, id, item });
      }
    }
  }

  await stateRef.set({ ids: current, updatedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
  if (!newlyPublished.length) return { baseline: !stateSnapshot.exists, created: 0 };

  const profiles = await db.collection('community_profiles').select().get();
  let created = 0;
  for (const item of newlyPublished) {
    const name = String(item.item?.title?.rendered || item.item?.title || item.item?.name || '').trim();
    await Promise.all(profiles.docs.map(async (profile) => {
      const recipientUid = profile.id;
      await createNotificationBestEffort({
        recipientUid,
        type: item.type,
        title: item.title,
        body: name || item.title,
        targetType: item.targetType,
        targetId: item.id,
        dedupeKey: `wordpress_content:${item.key}:${item.id}:${recipientUid}`,
      });
      created += 1;
    }));
  }
  return { baseline: false, created };
}

exports.pollWordPressContentNotifications = onSchedule({
  schedule: 'every 5 minutes',
  timeZone: 'Europe/Budapest',
  region: 'europe-central2',
}, async () => {
  try {
    const result = await pollWordPressContentNotifications();
    console.info('wordpress_content_notifications', result);
  } catch (error) {
    console.warn(JSON.stringify({
      event: 'wordpress_content_notifications_failed',
      message: error?.message || String(error),
    }));
  }
});

async function removePushTokens(uid, tokens) {
  if (!tokens.length) return;
  await db.collection('private_user_data').doc(uid).set({
    fcmTokens: admin.firestore.FieldValue.arrayRemove(...tokens),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
  // Keep legacy cleanup for tokens written by older app versions.
  await db.collection('community_profiles').doc(uid).update({
    fcmTokens: admin.firestore.FieldValue.arrayRemove(...tokens),
  }).catch(() => {});
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

async function notifySubmissionAdmins(kind, title, id) {
  const profiles = await db.collection('community_profiles').get();
  const adminProfiles = profiles.docs.filter((profileDoc) => {
    const profile = profileDoc.data() || {};
    return String(profile.email || '').trim().toLowerCase() === ADMIN_EMAIL
      || profile.accessRole === 'admin';
  });
  const tokenLists = await Promise.all(
    adminProfiles.map((profileDoc) => getPushTokens(profileDoc.id)),
  );
  const tokens = tokenLists.flat();
  const uniqueTokens = [...new Set(tokens.map((token) => token.trim()).filter(Boolean))];
  if (!uniqueTokens.length) return { sent: 0 };
  const result = await sendMulticastToAllTokens({
    notification: { title: `Új ${kind}beküldés`, body: title },
    data: { type: 'submission', kind, id: String(id) },
  }, uniqueTokens);
  return { sent: result.successCount, failed: result.failureCount };
}

exports.submitWordPressContent = wordPressCall(
  async (data, context) => {
    if (!context.auth || context.auth.token.firebase?.sign_in_provider === 'anonymous') {
      throw new HttpsError('permission-denied', 'Regisztráció szükséges a beküldéshez.');
    }
    if (!await allowCall(context.auth.uid, 'submission')) {
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

    const requestHash = crypto.createHash('sha256')
      .update(`${context.auth.uid}:${data.kind}:${JSON.stringify(payload)}`)
      .digest('hex');
    const requestRef = db.collection('submission_requests').doc(requestHash);
    let duplicateResponse;
    let duplicateInProgress = false;
    await db.runTransaction(async (transaction) => {
      const existing = await transaction.get(requestRef);
      if (existing.exists) {
        duplicateResponse = existing.data()?.response;
        duplicateInProgress = !duplicateResponse;
        return;
      }
      transaction.create(requestRef, {
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        kind: data.kind,
      });
    });
    if (duplicateResponse) return duplicateResponse;
    if (duplicateInProgress) {
      throw new HttpsError('already-exists', 'Ezt a beküldést már feldolgozzuk.');
    }

    const profileSnapshot = await db.collection('community_profiles').doc(context.auth.uid).get();
    const profile = profileSnapshot.data() || {};
    if (!isAdmin(context, profile) && route.role && profile.role !== route.role) {
      await requestRef.delete().catch(() => {});
      throw new HttpsError('permission-denied', 'Ehhez a beküldéshez nincs jogosultságod.');
    }

    const credentials = `${WORDPRESS_USERNAME.value()}:${WORDPRESS_APPLICATION_PASSWORD.value()}`;
    const response = await fetch(`${WORDPRESS_BASE_URL}${route.path}`, {
      method: 'POST',
      headers: {
        Authorization: `Basic ${Buffer.from(credentials).toString('base64')}`,
        'Content-Type': 'application/json',
        Accept: 'application/json',
        'X-HUHS-Skip-Submission-Push': '1',
      },
      body: JSON.stringify(payload),
    });
    const body = await response.json().catch(() => ({}));
    if (!response.ok) {
      await requestRef.delete().catch(() => {});
      throw new HttpsError('failed-precondition', body.message || 'A WordPress beküldés sikertelen.');
    }
    await requestRef.set({ response: body, completedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
    if (body?.id) {
      const label = data.kind === 'artist' ? 'DJ' : data.kind === 'organizer' ? 'szervező' : 'esemény';
      await notifySubmissionAdmins(label, body.title || payload.title || '', body.id)
        .catch((error) => console.warn('submission admin push failed', error));
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
    if (!await allowCall(context.auth.uid, 'wp_admin')) {
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
    if (!await allowCall(context.auth.uid, 'wp_admin')) {
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
    if (!await allowCall(context.auth.uid, 'wp_admin')) {
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
    if (!await allowCall(context.auth.uid, 'wp_admin_request')) {
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
    if (!response.ok) {
      console.warn('wordpress_admin_request_failed', {
        uid: context.auth.uid,
        path,
        method,
        status: response.status,
        message: typeof body?.message === 'string' ? body.message : '',
      });
      throw new HttpsError('failed-precondition', body?.message || 'A WordPress admin művelet sikertelen.');
    }
    console.info('wordpress_admin_request_ok', { uid: context.auth.uid, path, method });
    return body;
  },
);
exports.deleteCommunityUser = functions.https.onCall(async (data, context) => {
  const email = String(context.auth?.token?.email || '').trim().toLowerCase();
  if (!context.auth) {
    throw new HttpsError('permission-denied', 'Csak admin törölhet felhasználót.');
  }
    if (!await allowCall(context.auth.uid, 'user_delete', 10)) {
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

exports.deletePrivateConversation = functions.https.onCall(async (data, context) => {
  const uid = String(context.auth?.uid || '').trim();
  if (!uid || context.auth.token.firebase?.sign_in_provider === 'anonymous') {
    throw new HttpsError('unauthenticated', 'Bejelentkezés szükséges a beszélgetés törléséhez.');
  }
  if (!await allowCall(uid, 'private_conversation_delete', 10)) {
    securityLog('private_conversation_delete_rate_limited', context);
    throw new HttpsError('resource-exhausted', 'Túl sok törlési művelet, próbáld később.');
  }

  const conversationId = String(data?.conversationId || '').trim();
  if (!conversationId || !/^[^_]+_[^_]+$/.test(conversationId)) {
    throw new HttpsError('invalid-argument', 'Érvénytelen beszélgetésazonosító.');
  }

  const conversationRef = db.collection('private_conversations').doc(conversationId);
  const conversation = await conversationRef.get();
  if (!conversation.exists) return { deleted: true };
  const participants = Array.isArray(conversation.data()?.participantIds)
    ? conversation.data().participantIds.map((id) => String(id))
    : [];
  if (!participants.includes(uid)) {
    securityLog('private_conversation_delete_denied', context);
    throw new HttpsError('permission-denied', 'Csak a beszélgetés résztvevője törölheti azt.');
  }

  const messages = await conversationRef.collection('messages').get();
  for (let offset = 0; offset < messages.docs.length; offset += 400) {
    const batch = db.batch();
    messages.docs.slice(offset, offset + 400).forEach((message) => batch.delete(message.ref));
    await batch.commit();
  }
  await conversationRef.delete();
  return { deleted: true };
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
    if (!await allowCall(context.auth.uid, 'artist_claim', 5)) {
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
    if (!await allowCall(context.auth.uid, 'label_purchase', 10)) {
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
    const purchaseTokenHash = crypto.createHash('sha256').update(purchaseToken).digest('hex');
    const previousOwner = await db.collection('label_entitlements')
      .where('purchaseTokenHash', '==', purchaseTokenHash)
      .limit(1)
      .get();
    if (!previousOwner.empty && previousOwner.docs[0].data()?.uid !== context.auth.uid) {
      securityLog('label_purchase_user_mismatch', context);
      throw new HttpsError('permission-denied', 'Ez a vásárlás már másik felhasználóhoz tartozik.');
    }
    const entitlement = {
      uid: context.auth.uid,
      releaseId,
      productId,
      purchaseTokenHash,
      orderId: String(purchase.data.orderId || ''),
      verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    const claimRef = db.collection('label_purchase_claims').doc(purchaseTokenHash);
    const entitlementRef = db.collection('label_entitlements').doc(`${context.auth.uid}_${productId}`);
    await db.runTransaction(async (tx) => {
      const claim = await tx.get(claimRef);
      if (claim.exists && claim.data()?.uid !== context.auth.uid) {
        securityLog('label_purchase_user_mismatch', context);
        throw new HttpsError('permission-denied', 'Ez a vásárlás már másik felhasználóhoz tartozik.');
      }
      if (!claim.exists) {
        tx.create(claimRef, {
          uid: context.auth.uid,
          productId,
          purchaseTokenHash,
          claimedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      } else {
        tx.set(claimRef, { lastVerifiedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
      }
      tx.set(entitlementRef, entitlement, { merge: true });
    });
    return { verified: true, releaseId, productId };
  });

exports.getLabelDownloadUrl = functions
  .runWith({ secrets: [WORDPRESS_USERNAME, WORDPRESS_APPLICATION_PASSWORD] })
  .https.onCall(async (data, context) => {
    const releaseId = Number(data?.releaseId || 0);
    const variant = String(data?.variant || '').trim();
    const isAnonymous = !context.auth || context.auth.token.firebase?.sign_in_provider === 'anonymous';
    if (isAnonymous) {
      throw new HttpsError('unauthenticated', 'Bejelentkezés szükséges a letöltéshez.');
    }
    const callerKey = context.auth?.uid
      || context.rawRequest?.ip
      || context.rawRequest?.socket?.remoteAddress
      || 'anonymous';
    if (!await allowCall(callerKey, 'label_download', 10)) {
      throw new HttpsError('resource-exhausted', 'Túl sok letöltési kérés.');
    }
    if (!Number.isInteger(releaseId) || releaseId < 1 || !['free_wav', 'wav', 'mp3_320', 'mp3_128', 'radio_wav', 'radio_mp3_320', 'extended_wav', 'extended_mp3_320'].includes(variant)) {
      throw new HttpsError('invalid-argument', 'Érvénytelen Label-letöltési adat.');
    }
    const paid = !['free_wav', 'mp3_128'].includes(variant);
    const productId = `huhs_release_${releaseId}_${variant}`;
    const entitlement = paid
      ? await db.collection('label_entitlements')
        .doc(`${context.auth.uid}_${productId}`)
        .get()
      : null;
    if (paid && (!entitlement || !entitlement.exists || entitlement.data()?.releaseId !== releaseId)) {
      throw new HttpsError('permission-denied', 'Ehhez a fájlhoz nincs vásárlási jogosultság.');
    }
    if (!paid && ['free_wav', 'mp3_128'].includes(variant)) {
      const unlock = await db.collection('label_ad_unlocks').doc(`${context.auth.uid}_${releaseId}`).get();
      if (!unlock.exists || !activeAdUnlock(unlock.data(), releaseId, variant)) {
        throw new HttpsError('permission-denied', 'A reklámos feloldás szükséges ehhez a változathoz.');
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
      console.warn('label_download_wordpress_failed', {
        releaseId,
        variant,
        status: response.status,
        message: typeof body?.message === 'string' ? body.message : '',
      });
      throw new HttpsError('failed-precondition', body?.message || 'A Label-letöltés nem érhető el.');
    }
    console.info('label_download_wordpress_ok', { releaseId, variant });
    return { downloadUrl: body.download_url, expiresIn: Number(body.expires_in || 300) };
  });

const labelProductDefinitions = [
  { type: 'radio_wav', label: 'Radio WAV' },
  { type: 'radio_mp3_320', label: 'Radio MP3 320 kbps' },
  { type: 'extended_wav', label: 'Extended WAV' },
  { type: 'extended_mp3_320', label: 'Extended MP3 320 kbps' },
];

function parseHufPrice(value) {
  const match = String(value || '').replace(/\s/g, '').match(/\d+/);
  const price = Number(match?.[0] || 0);
  return Number.isInteger(price) && price > 0 ? price : 0;
}

function productIdForRelease(releaseId, type) {
  // Keep the established product-ID shape used by the working releases.
  // Product IDs are immutable in Play, so the release ID keeps each new
  // product unique without introducing a second namespace that the catalog
  // backend has intermittently rejected with a generic 500.
  return `huhs_release_${releaseId}_${type}`;
}

function productIdFromResponse(product) {
  return String(product?.productId || '').trim();
}

async function upsertPlayProduct(androidPublisher, release, definition, productId, price) {
  let current = null;
  try {
    current = (await androidPublisher.monetization.onetimeproducts.get({
      packageName: GOOGLE_PLAY_PACKAGE_NAME,
      productId,
    })).data;
  } catch (error) {
    if (error?.response?.status !== 404) throw error;
  }

  const purchaseOptionId = String(current?.purchaseOptions?.[0]?.purchaseOptionId || 'default');
  const title = `${String(release.title || 'HUHS Release')} – ${definition.label}`.slice(0, 55);
  const description = `Hungarian Hardstyle ${definition.label} letöltés: ${String(release.title || 'Release')}`.slice(0, 200);
  const currentOption = current?.purchaseOptions?.find((option) => option.purchaseOptionId === purchaseOptionId)
    || current?.purchaseOptions?.[0]
    || null;
  const regionalPrices = new Map(
    (currentOption?.regionalPricingAndAvailabilityConfigs || [])
      .filter((item) => item?.regionCode)
      .map((item) => [String(item.regionCode), item]),
  );
  regionalPrices.set('HU', {
    regionCode: 'HU',
    price: { currencyCode: 'HUF', units: String(price), nanos: 0 },
    availability: 'AVAILABLE',
  });
  const purchaseOption = {
    purchaseOptionId,
    buyOption: currentOption?.buyOption || { legacyCompatible: true, multiQuantityEnabled: false },
    regionalPricingAndAvailabilityConfigs: [...regionalPrices.values()],
  };
  if (currentOption?.newRegionsConfig) purchaseOption.newRegionsConfig = currentOption.newRegionsConfig;
  const product = {
    packageName: GOOGLE_PLAY_PACKAGE_NAME,
    productId,
    listings: [{ languageCode: 'hu-HU', title, description }],
    purchaseOptions: [purchaseOption],
  };
  // Use the documented single-product upsert endpoint. The previous code
  // routed every individual product through batchUpdate, although this sync
  // never sends a batch. PATCH supports the same allowMissing create path and
  // keeps the request/response unambiguous for one product.
  const request = (latencyTolerance) => ({
    packageName: GOOGLE_PLAY_PACKAGE_NAME,
    productId,
    updateMask: 'listings,purchaseOptions',
    // googleapis exposes this REST query object field as a flattened
    // parameter. Passing an object makes the client serialize it as
    // regionsVersion[version], which the Play transcoder rejects.
    'regionsVersion.version': GOOGLE_PLAY_REGIONS_VERSION,
    allowMissing: true,
    latencyTolerance,
    requestBody: product,
  });
  let result;
  try {
    result = await androidPublisher.monetization.onetimeproducts.patch(
      request('PRODUCT_UPDATE_LATENCY_TOLERANCE_LATENCY_SENSITIVE'),
    );
  } catch (error) {
    const isBackendError = error?.response?.status === 500
      && (error?.response?.data?.error?.status === 'INTERNAL'
        || error?.response?.data?.error?.errors?.some((item) => item.reason === 'backendError'));
    if (!isBackendError) throw error;
    console.warn('label_product_sync_latency_tolerant_retry', {
      releaseId: Number(release.id), type: definition.type, productId, price,
    });
    result = await androidPublisher.monetization.onetimeproducts.patch(
      request('PRODUCT_UPDATE_LATENCY_TOLERANCE_LATENCY_TOLERANT'),
    );
  }
  let saved = result.data || product;
  let savedOption = saved.purchaseOptions?.find((option) => option.purchaseOptionId === purchaseOptionId)
    || saved.purchaseOptions?.[0];
  console.log('label_product_sync_play_patch_response', {
    releaseId: Number(release.id), type: definition.type, productId,
    purchaseOptionCount: Array.isArray(saved.purchaseOptions) ? saved.purchaseOptions.length : 0,
    purchaseOptionState: savedOption?.state || 'missing',
  });

  // The Play API can acknowledge the PATCH while the product shell is
  // visible before its purchase option is actually persisted. In that state
  // the Console shows "Add purchase option" and Billing returns the product
  // as unavailable. Re-read the resource and repair the option through the
  // documented batchUpdate endpoint (its regionsVersion is a JSON object,
  // unlike the flattened PATCH query parameter).
  if (!savedOption) {
    for (const delayMs of [500, 1500, 3000]) {
      await new Promise((resolve) => setTimeout(resolve, delayMs));
      saved = (await androidPublisher.monetization.onetimeproducts.get({
        packageName: GOOGLE_PLAY_PACKAGE_NAME,
        productId,
      })).data;
      savedOption = saved.purchaseOptions?.find((option) => option.purchaseOptionId === purchaseOptionId)
        || saved.purchaseOptions?.[0];
      if (savedOption) break;
    }
  }

  if (!savedOption) {
    const batchResult = await androidPublisher.monetization.onetimeproducts.batchUpdate({
      packageName: GOOGLE_PLAY_PACKAGE_NAME,
      requestBody: {
        requests: [{
          oneTimeProduct: product,
          updateMask: 'listings,purchaseOptions',
          regionsVersion: { version: GOOGLE_PLAY_REGIONS_VERSION },
          allowMissing: true,
          latencyTolerance: 'PRODUCT_UPDATE_LATENCY_TOLERANCE_LATENCY_TOLERANT',
        }],
      },
    });
    saved = batchResult.data?.oneTimeProducts?.[0] || null;
    savedOption = saved?.purchaseOptions?.find((option) => option.purchaseOptionId === purchaseOptionId)
      || saved?.purchaseOptions?.[0];
  }

  if (!savedOption) {
    throw new Error(`Play purchase option missing after upsert: ${productId}`);
  }

  if (savedOption && savedOption.state !== 'ACTIVE') {
    await androidPublisher.monetization.onetimeproducts.purchaseOptions.batchUpdateStates({
      packageName: GOOGLE_PLAY_PACKAGE_NAME,
      productId,
      requestBody: {
        requests: [{
          activatePurchaseOptionRequest: {
            packageName: GOOGLE_PLAY_PACKAGE_NAME,
            productId,
            purchaseOptionId: savedOption.purchaseOptionId || purchaseOptionId,
            latencyTolerance: 'PRODUCT_UPDATE_LATENCY_TOLERANCE_LATENCY_TOLERANT',
          },
        }],
      },
    });
  }

  const verified = (await androidPublisher.monetization.onetimeproducts.get({
    packageName: GOOGLE_PLAY_PACKAGE_NAME,
    productId,
  })).data;
  const verifiedOption = verified.purchaseOptions?.find(
    (option) => option.purchaseOptionId === (savedOption.purchaseOptionId || purchaseOptionId),
  ) || verified.purchaseOptions?.[0];
  if (!verifiedOption || verifiedOption.state !== 'ACTIVE') {
    throw new Error(`Play purchase option is not active after sync: ${productId}`);
  }
  console.log('label_product_sync_play_verified', {
    releaseId: Number(release.id), type: definition.type, productId,
    purchaseOptionId: verifiedOption.purchaseOptionId,
    purchaseOptionState: verifiedOption.state,
    huAvailability: verifiedOption.regionalPricingAndAvailabilityConfigs?.find(
      (item) => item.regionCode === 'HU',
    )?.availability || 'missing',
  });
  return productIdFromResponse(saved) || productId;
}

async function updateWordPressReleaseProducts(credentials, releaseId, products) {
  const response = await fetch(`${WORDPRESS_BASE_URL}/releases/${releaseId}/play-products`, {
    method: 'POST',
    headers: {
      Authorization: `Basic ${Buffer.from(credentials).toString('base64')}`,
      'Content-Type': 'application/json',
      Accept: 'application/json',
    },
    body: JSON.stringify({ products }),
  });
  const body = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(body?.message || `WordPress Play-termék frissítés: HTTP ${response.status}`);
  return body;
}

async function syncReleasePlayProducts(release, credentials, androidPublisher) {
  const products = {};
  if (String(release.audio_status || '') !== 'ready') {
    return { releaseId: Number(release.id), products, skipped: 'audio-not-ready' };
  }
  const existing = new Map((Array.isArray(release.products) ? release.products : []).map((item) => [String(item.type), item]));
  const prices = release.product_prices || {};
  const available = new Set((Array.isArray(release.versions) ? release.versions : []).filter((item) => item.available).map((item) => String(item.type)));
  const errors = [];
  for (const definition of labelProductDefinitions) {
    const rawKnown = existing.get(definition.type);
    const knownId = String(rawKnown?.id || '');
    // Never attach a product belonging to another release. This prevents a
    // copied/stale WordPress ID from leaving the new release's buttons grey.
    const known = rawKnown && knownId.startsWith(`huhs_release_${release.id}_`)
      ? rawKnown
      : null;
    const price = parseHufPrice(prices[definition.type] || known?.price);
    const sourceType = definition.type.startsWith('radio_') ? 'radio' : 'extended';
    if (!known?.id && (!available.has(sourceType) || !price)) continue;
    if (known?.id && !price) {
      products[definition.type] = String(known.id);
      continue;
    }
    const productId = String(known?.id || productIdForRelease(release.id, definition.type));
    try {
      products[definition.type] = await upsertPlayProduct(androidPublisher, release, definition, productId, price);
      console.info('label_product_sync_item', {
        releaseId: Number(release.id), type: definition.type,
        productId: products[definition.type], price, status: 'ok',
      });
    } catch (error) {
      const apiError = error?.response?.data?.error || error?.response?.data || null;
      const detail = {
        releaseId: Number(release.id), type: definition.type, productId, price,
        status: error?.response?.status || null, message: error?.message || String(error),
        apiError: apiError ? {
          code: apiError.code || null,
          status: apiError.status || null,
          message: apiError.message || null,
          reasons: Array.isArray(apiError.errors)
            ? apiError.errors.map((item) => ({ reason: item.reason || null, message: item.message || null }))
            : [],
          raw: JSON.stringify(apiError),
        } : null,
      };
      errors.push(detail);
      console.error('label_product_sync_item_failed', detail);
    }
  }
  if (Object.keys(products).length) await updateWordPressReleaseProducts(credentials, release.id, products);
  return { releaseId: Number(release.id), products, errors };
}

async function syncWordPressLabelProducts(releaseId = 0) {
  if (labelProductSyncRunning) return { skipped: true, reason: 'already-running' };
  labelProductSyncRunning = true;
  try {
    const credentials = `${WORDPRESS_USERNAME.value()}:${WORDPRESS_APPLICATION_PASSWORD.value()}`;
    let serviceAccount;
    try {
      serviceAccount = JSON.parse(GOOGLE_PLAY_SERVICE_ACCOUNT_JSON.value());
    } catch (_) {
      throw new Error('A Google Play service account secret érvénytelen.');
    }
    const auth = new google.auth.GoogleAuth({
      credentials: serviceAccount,
      scopes: ['https://www.googleapis.com/auth/androidpublisher'],
    });
    const androidPublisher = google.androidpublisher({ version: 'v3', auth });
    const response = await fetch(`${WORDPRESS_BASE_URL}/releases`, { headers: { Accept: 'application/json' } });
    const body = await response.json().catch(() => ({}));
    if (!response.ok || !Array.isArray(body.items)) throw new Error('A WordPress release-lista nem tölthető be.');
    const releases = body.items.filter((release) => !releaseId || Number(release.id) === releaseId);
    const results = [];
    for (const release of releases) {
      try {
        const result = await syncReleasePlayProducts(release, credentials, androidPublisher);
        results.push(result);
        console.info('label_product_sync_release', result);
      } catch (error) {
        console.error('label_product_sync_failed', {
          releaseId: release.id, title: release.title,
          message: error?.message || String(error), status: error?.response?.status || null,
        });
      }
    }
    return { processed: results.length, results };
  } finally {
    labelProductSyncRunning = false;
  }
}

exports.syncLabelProducts = functions
  .runWith({ secrets: labelProductSyncSecrets })
  .https.onCall(async (data, context) => {
    if (!context.auth) throw new HttpsError('permission-denied', 'Csak admin indíthatja a Play-termékszinkront.');
    const profile = (await db.collection('community_profiles').doc(context.auth.uid).get()).data() || {};
    if (!isAdmin(context, profile)) throw new HttpsError('permission-denied', 'Csak admin indíthatja a Play-termékszinkront.');
    const releaseId = Number(data?.releaseId || 0);
    if (releaseId && (!Number.isInteger(releaseId) || releaseId < 1)) throw new HttpsError('invalid-argument', 'Érvénytelen release-azonosító.');
    return syncWordPressLabelProducts(releaseId);
  });

exports.syncWordPressLabelProducts = onSchedule({
  schedule: 'every 5 minutes',
  timeZone: 'Europe/Budapest',
  secrets: labelProductSyncSecrets,
}, async () => syncWordPressLabelProducts());

// WordPress queues this request immediately after audio processing succeeds.
// The scheduled sync remains as a safety-net for missed or failed requests.
exports.syncQueuedWordPressLabelProducts = onDocumentCreated({
  document: 'label_product_sync_requests/{requestId}',
  database: 'hungarian-hardstyle',
  region: 'us-central1',
  secrets: labelProductSyncSecrets,
}, async (event) => {
  const request = event.data?.data() || {};
  const releaseId = Number(request.releaseId || 0);
  if (!Number.isInteger(releaseId) || releaseId < 1) return;
  const result = await syncWordPressLabelProducts(releaseId);
  console.info('label_product_sync_queued_request', { releaseId, result });
});

exports.getLabelAdUnlockStatus = functions.https.onCall(async (data, context) => {
  if (!context.auth || context.auth.token.firebase?.sign_in_provider === 'anonymous') {
    throw new HttpsError('unauthenticated', 'Bejelentkezés szükséges.');
  }
    if (!await allowCall(context.auth.uid, 'label_ad_unlock_status', 40)) {
    throw new HttpsError('resource-exhausted', 'Túl sok feloldási ellenőrzés.');
  }
  const releaseId = Number(data?.releaseId || 0);
  const variant = String(data?.variant || 'mp3_128').trim();
  if (!['free_wav', 'free_link', 'mp3_128'].includes(variant)) {
    throw new HttpsError('invalid-argument', 'Érvénytelen reklámos feloldási változat.');
  }
  if (!Number.isInteger(releaseId) || releaseId < 1) {
    throw new HttpsError('invalid-argument', 'Érvénytelen release azonosító.');
  }
  const snapshot = await db.collection('label_ad_unlocks')
    .doc(`${context.auth.uid}_${releaseId}`)
    .get();
  const unlock = snapshot.data() || {};
  const unlocked = snapshot.exists && activeAdUnlock(unlock, releaseId, variant);
  return { unlocked };
});

exports.admobRewardedSsv = functions.https.onRequest(async (req, res) => {
  const reject = (reason) => {
    console.warn(JSON.stringify({ event: 'admob_ssv_rejected', reason }));
    return res.status(400).send(reason);
  };
  try {
    const originalUrl = String(req.originalUrl || '');
    const requestUrl = String(req.url || '');
    const rawQuery = originalUrl.split('?')[1] || '';
    const params = new URLSearchParams(rawQuery);
    const transactionId = String(params.get('transaction_id') || '').trim();
    const customData = String(params.get('custom_data') || '').trim();
    // AdMob's dashboard validator does not create a real reward transaction.
    // Return success for that probe without granting anything. A probe may
    // also omit the signed callback fields entirely.
    if (!transactionId && !params.get('signature')) {
      return res.status(200).send('validated');
    }
    const signatureMatch = /(?:^|&)signature=([^&]*)/.exec(rawQuery);
    if (!signatureMatch) return reject('missing signature');
    const signature = String(params.get('signature') || '').trim();
    const keyId = Number(params.get('key_id') || 0);
    if (!keyId) return reject('missing key id');
    const keyResponse = await fetch('https://www.gstatic.com/admob/reward/verifier-keys.json');
    const keyBody = await keyResponse.json();
    const key = (keyBody.keys || []).find((item) => Number(item.keyId) === keyId);
    if (!key?.pem || !signature) return reject('unknown signing key');
    // Google signs the query exactly as received, up to (but excluding) the
    // `&signature=` separator. Do not decode, reorder, or remove key_id.
    const signedQuery = rawQuery.slice(0, signatureMatch.index);
    const signatureBytes = [
      Buffer.from(signature, 'base64url'),
      Buffer.from(signature, 'base64'),
    ];
    const normalizedSignature = signature.replace(/-/g, '+').replace(/_/g, '/');
    const publicKeys = [key.pem];
    if (key.base64) {
      publicKeys.push(crypto.createPublicKey({
        key: Buffer.from(key.base64, 'base64'),
        format: 'der',
        type: 'spki',
      }));
    }
    const queryFromUrl = requestUrl.split('?')[1] || '';
    const urlSignatureMatch = /(?:^|&)signature=([^&]*)/.exec(queryFromUrl);
    const verificationInputs = [
      { label: 'original-excluding-separator', value: signedQuery },
      ...(urlSignatureMatch
        ? [{ label: 'url-excluding-separator', value: queryFromUrl.slice(0, urlSignatureMatch.index) }]
        : []),
    ];
    const decodeQuery = (value) => value.split('&').map((part) => {
      const separator = part.indexOf('=');
      if (separator < 0) return decodeURIComponent(part);
      return `${decodeURIComponent(part.slice(0, separator))}=${decodeURIComponent(part.slice(separator + 1))}`;
    }).join('&');
    verificationInputs.push({
      label: 'decoded-query',
      value: decodeQuery(signedQuery),
    });
    const verificationResults = [];
    for (const input of verificationInputs) {
      for (const [keyIndex, publicKey] of publicKeys.entries()) {
        for (const [signatureIndex, bytes] of signatureBytes.entries()) {
          verificationResults.push({
            input: input.label,
            keyIndex,
            signatureIndex,
            valid: crypto.verify(
              'sha256',
              Buffer.from(input.value, 'utf8'),
              { key: publicKey, dsaEncoding: 'der' },
              bytes,
            ),
          });
        }
      }
    }
    for (const input of verificationInputs) {
      for (const [keyIndex, publicKey] of publicKeys.entries()) {
        const verifier = crypto.createVerify('sha256');
        verifier.update(input.value, 'utf8');
        verificationResults.push({
          input: `${input.label}-createVerify`,
          keyIndex,
          valid: verifier.verify(publicKey, normalizedSignature, 'base64'),
        });
      }
    }
    const valid = verificationResults.some((result) => result.valid);
    if (!valid) return reject('invalid signature');
    if (!customData) return reject('missing reward data');
    let decoded;
    try {
      decoded = JSON.parse(Buffer.from(customData, 'base64url').toString('utf8'));
    } catch (_) {
      decoded = JSON.parse(Buffer.from(decodeURIComponent(customData), 'base64url').toString('utf8'));
    }
    const uid = String(decoded.uid || '').trim();
    const releaseId = Number(decoded.releaseId || 0);
    const variant = String(decoded.variant || 'mp3_128').trim();
    if (!uid || !Number.isInteger(releaseId) || releaseId < 1
      || !['free_wav', 'free_link', 'mp3_128'].includes(variant)) return reject('invalid reward data');
    const transaction = db.collection('admob_reward_transactions').doc(transactionId);
    await db.runTransaction(async (tx) => {
      if ((await tx.get(transaction)).exists) return;
      const unlockRef = db.collection('label_ad_unlocks').doc(`${uid}_${releaseId}`);
      const unlock = await tx.get(unlockRef);
      const existingVariants = unlock.exists && unlock.data()?.variants && typeof unlock.data().variants === 'object'
        ? unlock.data().variants
        : {};
      tx.set(transaction, { uid, releaseId, createdAt: admin.firestore.FieldValue.serverTimestamp() });
      tx.set(unlockRef, {
        uid, releaseId, transactionId,
        variants: { ...existingVariants, [variant]: true },
        unlockedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
    });
    return res.status(200).send('ok');
  } catch (error) {
    console.warn(JSON.stringify({ event: 'admob_ssv_failed', message: String(error?.message || error) }));
    return res.status(400).send('invalid callback');
  }
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
    const sender = (await db.collection('community_profiles').doc(String(request.from)).get()).data() || {};
    const name = String(sender.displayName || 'Egy felhasználó').trim();
    await createNotificationBestEffort({ recipientUid: String(request.to), type: 'connection_request', title: 'Új ismerősnek jelölés', body: `${name} ismerősnek jelölt.`, targetType: 'profile', targetId: String(request.from), dedupeKey: `connection_request:${requestId}:${notification}` });
    const uniqueTokens = await getPushTokens(String(request.to));
    if (!uniqueTokens.length) {
      console.warn(JSON.stringify({
        event: 'connection_request_no_target_token',
        requestId,
        target: String(request.to),
      }));
      return null;
    }
    const result = await sendMulticastToAllTokens({
      notification: { title: 'Új ismerősnek jelölés', body: `${name} ismerősnek jelölt.` },
      data: { type: 'connection_request', senderId: String(request.from) },
    }, uniqueTokens);
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
      await removePushTokens(String(request.to), invalidTokens);
    }
    return result;
  },
);

exports.notifyMeetupInterest = onDocumentWritten(
  {
    document: 'event_meetups/{eventId}/users/{meetupUserId}',
    database: 'hungarian-hardstyle',
    region: 'europe-central2',
  },
  async (event) => {
    const before = event.data?.before?.data() || {};
    const after = event.data?.after?.data() || {};
    const meetupUserId = String(event.params.meetupUserId || '').trim();
    const eventId = String(event.params.eventId || '').trim();
    const beforeInterested = before.interestedBy && typeof before.interestedBy === 'object'
      ? before.interestedBy
      : {};
    const afterInterested = after.interestedBy && typeof after.interestedBy === 'object'
      ? after.interestedBy
      : {};
    const newInterests = Object.keys(afterInterested).filter((uid) => (
      afterInterested[uid] === true && beforeInterested[uid] !== true
    ));
    if (!meetupUserId || !eventId || !newInterests.length) return null;

    const targetBlocked = await db.collection('community_profiles')
      .doc(meetupUserId).collection('blocked_users').get();
    const blockedIds = new Set(targetBlocked.docs.map((doc) => doc.id));
    const targetTokens = await getPushTokens(meetupUserId);
    const eventTitle = String(after.eventTitle || 'az esemény').trim();
    const results = [];
    for (const senderId of newInterests) {
      if (senderId === meetupUserId || blockedIds.has(senderId)) continue;
      const reverseBlocked = await db.collection('community_profiles')
        .doc(senderId).collection('blocked_users').doc(meetupUserId).get();
      if (reverseBlocked.exists) continue;
      const sender = (await db.collection('community_profiles').doc(senderId).get()).data() || {};
      const senderName = String(sender.displayName || 'Egy felhasználó').trim();
      await createNotificationBestEffort({ recipientUid: meetupUserId, type: 'meetup_interest', title: 'Új Meetup érdeklődés', body: `${senderName} szívesen találkozna veled a(z) ${eventTitle} eseményen.`, targetType: 'event', targetId: eventId, dedupeKey: `meetup_interest:${eventId}:${meetupUserId}:${senderId}` });
      if (!targetTokens.length) continue;
      const result = await sendMulticastToAllTokens({
        notification: {
          title: 'Új Meetup érdeklődés',
          body: `${senderName} szívesen találkozna veled a(z) ${eventTitle} eseményen.`,
        },
        data: {
          type: 'meetup_interest',
          senderId,
          eventId,
        },
      }, targetTokens);
      results.push(result);
    }
    return {
      successCount: results.reduce((sum, result) => sum + result.successCount, 0),
      failureCount: results.reduce((sum, result) => sum + result.failureCount, 0),
    };
  },
);

exports.notifyPrivateMessage = onDocumentCreated(
  {
    document: 'private_conversations/{conversationId}/messages/{messageId}',
    database: 'hungarian-hardstyle',
    region: 'europe-central2',
  },
  async (event) => {
    const message = event.data?.data() || {};
    const senderId = String(message.senderId || '').trim();
    const recipientId = String(message.recipientId || '').trim();
    const conversationId = String(event.params.conversationId || '').trim();
    const text = String(message.text || '').trim();
    if (!senderId || !recipientId || !conversationId || !text || senderId === recipientId) {
      return null;
    }

    const conversation = (await db.collection('private_conversations').doc(conversationId).get()).data() || {};
    const participantIds = Array.isArray(conversation.participantIds)
      ? conversation.participantIds.map((id) => String(id))
      : [];
    if (!participantIds.includes(senderId) || !participantIds.includes(recipientId)) {
      console.warn(JSON.stringify({
        event: 'private_message_invalid_participants',
        conversationId,
      }));
      return null;
    }

    const participantNames = conversation.participantNames || {};
    const senderName = String(participantNames[senderId] || 'Egy felhasználó').trim();
    await createNotificationBestEffort({ recipientUid: recipientId, type: 'private_message', title: `${senderName || 'Egy felhasználó'} üzenetet küldött`, body: text, targetType: 'private_conversation', targetId: conversationId, dedupeKey: `private_message:${conversationId}:${event.params.messageId}` });
    const uniqueTokens = await getPushTokens(recipientId);
    if (!uniqueTokens.length) {
      console.log(JSON.stringify({
        event: 'private_message_no_target_token',
        conversationId,
        recipientId,
      }));
      return null;
    }
    const result = await sendMulticastToAllTokens({
      notification: {
        title: `${senderName || 'Egy felhasználó'} üzenetet küldött`,
        body: text.slice(0, 160),
      },
      data: {
        type: 'private_message',
        conversationId,
        senderId,
      },
    }, uniqueTokens);
    console.log(JSON.stringify({
      event: 'private_message_push_result',
      conversationId,
      recipientId,
      tokenCount: uniqueTokens.length,
      successCount: result.successCount,
      failureCount: result.failureCount,
    }));

    const invalidTokens = uniqueTokens.filter((_, index) => {
      const error = result.responses[index].error;
      return error?.code === 'messaging/registration-token-not-registered';
    });
    if (invalidTokens.length) {
      await removePushTokens(recipientId, invalidTokens);
    }
    return result;
  },
);

exports.notifyChatReport = onDocumentCreated(
  {
    document: 'chat_reports/{reportId}',
    database: 'hungarian-hardstyle',
    region: 'europe-central2',
  },
  async (event) => {
    const reportId = String(event.params.reportId || '').trim();
    const report = event.data?.data() || {};
    if (!reportId) return null;

    const profiles = await db.collection('community_profiles').get();
    const recipientIds = profiles.docs
      .filter((profileDoc) => {
        const profile = profileDoc.data() || {};
        const email = String(profile.email || '').trim().toLowerCase();
        return email === ADMIN_EMAIL
          || profile.accessRole === 'admin'
          || profile.accessRole === 'moderator';
      })
      .map((profileDoc) => profileDoc.id);

    const reporterName = String(report.reporterName || 'Egy felhasználó').trim();
    const reason = String(report.reason || '').trim();
    await Promise.all(recipientIds.map((recipientUid) => createNotificationBestEffort({ recipientUid, type: 'chat_report', title: 'Új chatjelentés', body: reason ? `${reporterName}: ${reason}` : `${reporterName} új chatjelentést küldött.`, targetType: 'chat_report', targetId: reportId, dedupeKey: `chat_report:${reportId}:${recipientUid}` })));
    const tokenLists = await Promise.all(recipientIds.map((uid) => getPushTokens(uid)));
    const uniqueTokens = [...new Set(tokenLists.flat().map((token) => token.trim()).filter(Boolean))];
    if (!uniqueTokens.length) {
      console.log(JSON.stringify({ event: 'chat_report_no_recipient_token', reportId }));
      return null;
    }
    const result = await sendMulticastToAllTokens({
      notification: {
        title: 'Új chatjelentés',
        body: reason ? `${reporterName}: ${reason}`.slice(0, 160) : `${reporterName} új chatjelentést küldött.`,
      },
      data: {
        type: 'chat_report',
        reportId,
      },
    }, uniqueTokens);

    const invalidTokens = uniqueTokens.filter((_, index) => (
      result.responses[index].error?.code === 'messaging/registration-token-not-registered'
    ));
    if (invalidTokens.length) {
      await Promise.all(recipientIds.map((uid) => removePushTokens(uid, invalidTokens)));
    }

    console.log(JSON.stringify({
      event: 'chat_report_push_result',
      reportId,
      recipientCount: recipientIds.length,
      tokenCount: uniqueTokens.length,
      successCount: result.successCount,
      failureCount: result.failureCount,
    }));
    return result;
  },
);
