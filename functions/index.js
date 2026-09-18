const functions = require('firebase-functions/v1');
const { onDocumentCreated, onDocumentWritten } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { HttpsError } = functions.https;
const { defineSecret } = require('firebase-functions/params');
const crypto = require('crypto');
const admin = require('firebase-admin');
const { getApps } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore, FieldPath, FieldValue } = require('firebase-admin/firestore');
// Lazy-loaded: only the Play purchase/product-sync paths need googleapis, so
// eager loading would slow every function's cold start.
let _googleApis = null;
function googleApis() {
  if (!_googleApis) _googleApis = require('googleapis').google;
  return _googleApis;
}
const { selectOwnedCloudinaryAssets, destroyCloudinaryAsset, listOwnedCloudinaryAssets } = require('./cloudinary');
const { authEmailTemplate, deletionEmailTemplate, emailChangeEmailTemplate, sendMail } = require('./email_service');
const { generateAuthActionLink } = require('./auth_action_link');
const { buildGameLeaderboard } = require('./game_results');
const { gameRewardPoints, buildRankedGameEntries } = require('./game_rewards');

admin.initializeApp();

const db = getFirestore(getApps()[0], 'hungarian-hardstyle');
const auth = getAuth(getApps()[0]);
const ADMIN_EMAIL = 'djdeeroy@gmail.com';
const EMAIL_ACTION_URL = 'https://hungarian-hardstyle.firebaseapp.com';
const HUHS_SMTP_HOST = defineSecret('HUHS_SMTP_HOST');
const HUHS_SMTP_PORT = defineSecret('HUHS_SMTP_PORT');
const HUHS_SMTP_SECURE = defineSecret('HUHS_SMTP_SECURE');
const HUHS_SMTP_USER = defineSecret('HUHS_SMTP_USER');
const HUHS_SMTP_PASSWORD = defineSecret('HUHS_SMTP_PASSWORD');
const SMTP_SECRETS = [HUHS_SMTP_HOST, HUHS_SMTP_PORT, HUHS_SMTP_SECURE, HUHS_SMTP_USER, HUHS_SMTP_PASSWORD];

function normalizedEmail(value) {
  return String(value || '')
    .trim()
    .toLowerCase();
}

function normalizedAccountRole(role) {
  return role === 'organizer' || role === 'admin' ? 'organizer' : role === 'dj' ? 'dj' : 'partygoer';
}

function normalizedAccessRole(role) {
  return role === 'admin' || role === 'moderator' ? role : 'none';
}

function deletedIdentityKey(email) {
  // Only a one-way identity marker is retained after deletion. It is used
  // solely by the Auth blocking hook and never returned to clients.
  return crypto
    .createHash('sha256')
    .update(`huhs-deleted:${normalizedEmail(email)}`)
    .digest('hex');
}

function isExplicitIdentityBan(marker) {
  return (
    marker?.blocked === true &&
    ['administrator-ban', 'abuse'].includes(String(marker.reason || '').trim()) &&
    ['admin', 'abuse-system'].includes(String(marker.source || '').trim()) &&
    marker.deletionType === 'identity-ban'
  );
}

// Registration is intentionally checked before Auth creation so a deleted
// identity cannot silently return as a new account. This callable has no Auth
// requirement; the one-way identity marker is the only identity it receives.
exports.checkRegistrationEligibility = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  if (!(await allowCallByIp(context, 'registration_eligibility', 30))) {
    throw new HttpsError('resource-exhausted', 'Túl sok kérés.');
  }
  const email = normalizedEmail(data?.email);
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
    throw new HttpsError('invalid-argument', 'Érvénytelen e-mail-cím.');
  }
  const deletedIdentity = await db.collection('deleted_identity_hashes').doc(deletedIdentityKey(email)).get();
  // Legacy records only contained deletedAt and represented account cleanup,
  // not a moderation ban. Only an explicit administrator/abuse marker may
  // block a later registration with the same identity.
  const deletedIdentityData = deletedIdentity.data() || {};
  const registrationBlocked = isExplicitIdentityBan(deletedIdentityData);
  if (registrationBlocked) {
    throw new HttpsError('permission-denied', 'Ehhez az e-mail-címhez tiltott fiók tartozik.');
  }
  return { allowed: true };
});

exports.banCommunityIdentity = functions.runWith({ enforceAppCheck: false }).https.onCall(async (data, context) => {
  const callerEmail = normalizedEmail(context.auth?.token?.email);
  if (!context.auth) throw new HttpsError('permission-denied', 'Csak admin tilthat identitást.');
  const callerProfile = await db.collection('community_profiles').doc(context.auth.uid).get();
  const callerData = callerProfile.data() || {};
  if (callerEmail !== ADMIN_EMAIL && callerData.accessRole !== 'admin' && callerData.role !== 'admin') {
    throw new HttpsError('permission-denied', 'Csak admin tilthat identitást.');
  }
  const uid = String(data?.uid || '').trim();
  const reason = String(data?.reason || '').trim();
  const source = String(data?.source || '').trim();
  if (!uid || !['administrator-ban', 'abuse'].includes(reason) || !['admin', 'abuse-system'].includes(source)) {
    throw new HttpsError('invalid-argument', 'Érvényes identitás-tiltási ok szükséges.');
  }
  const targetUser = await auth.getUser(uid);
  const email = normalizedEmail(targetUser.email);
  if (!email) throw new HttpsError('failed-precondition', 'A fiókhoz nem tartozik e-mail-cím.');
  await db.collection('deleted_identity_hashes').doc(deletedIdentityKey(email)).set(
    {
      blocked: true,
      reason,
      source,
      deletionType: 'identity-ban',
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
  return { blocked: true };
});

exports.requestEmailChange = functions.runWith({ enforceAppCheck: false }).https.onCall(async (data, context) => {
  const uid = context.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Jelentkezz be az e-mail módosításához.');
  const email = normalizedEmail(data?.email);
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) throw new HttpsError('invalid-argument', 'Érvénytelen e-mail-cím.');
  const user = await auth.getUser(uid);
  const currentEmail = normalizedEmail(user.email);
  if (!currentEmail || currentEmail === email) throw new HttpsError('invalid-argument', 'Adj meg új e-mail-címet.');
  const profileRef = db.collection('community_profiles').doc(uid);
  const profile = (await profileRef.get()).data() || {};
  const currentYear = new Date().getUTCFullYear();
  const emailChangeYear = Number(
    profile.emailChangeYear || (Number(profile.emailChangeCount || 0) > 0 ? currentYear : 0),
  );
  if (emailChangeYear === currentYear)
    throw new HttpsError('failed-precondition', 'E-mail-címet évente egyszer lehet módosítani.');
  try {
    const owner = await auth.getUserByEmail(email);
    if (owner.uid !== uid) throw new HttpsError('already-exists', 'Ez az e-mail-cím már használatban van.');
  } catch (error) {
    if (error.code !== 'auth/user-not-found') throw error;
  }
  const identityMarker = await db.collection('deleted_identity_hashes').doc(deletedIdentityKey(email)).get();
  if (isExplicitIdentityBan(identityMarker.data() || {})) {
    throw new HttpsError('permission-denied', 'Ehhez az e-mail-címhez tiltott identitás tartozik.');
  }
  await profileRef.set(
    {
      previousEmail: currentEmail,
      pendingEmail: email,
      pendingEmailExpiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
  return { requested: true };
});

exports.syncEmailChange = functions
  .runWith({ secrets: SMTP_SECRETS, enforceAppCheck: false })
  .https.onCall(async (data, context) => {
    const uid = context.auth?.uid;
    if (!uid) throw new HttpsError('unauthenticated', 'Jelentkezz be.');
    const email = normalizedEmail((await auth.getUser(uid)).email);
    const ref = db.collection('community_profiles').doc(uid);
    const profile = (await ref.get()).data() || {};
    if (!email || profile.pendingEmail !== email) return { synced: false };
    await ref.set(
      {
        email,
        pendingEmail: FieldValue.delete(),
        pendingEmailExpiresAt: FieldValue.delete(),
        emailChangeCount: 1,
        emailChangeYear: new Date().getUTCFullYear(),
        previousEmail: FieldValue.delete(),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    if (profile.previousEmail && profile.previousEmail !== email) {
      await sendIdentityEmailOnce({
        key: `email-change:${uid}:${email}`,
        to: profile.previousEmail,
        template: emailChangeEmailTemplate(),
      });
    }
    return { synced: true };
  });

function emailDeliveryJobRef(key) {
  return db.collection('email_delivery_jobs').doc(crypto.createHash('sha256').update(key).digest('hex'));
}

async function recentEmailDeliveryOutcome(key, deliveryType) {
  const job = (await emailDeliveryJobRef(key).get()).data() || {};
  const sentAt = job.sentAt?.toDate?.()?.getTime?.();
  if (
    job.status === 'sent' &&
    deliveryType === 'auth-verification' &&
    Number.isFinite(sentAt) &&
    Date.now() - sentAt < 60 * 1000
  ) {
    return 'already_sent';
  }
  if (job.status === 'sending' && job.leaseUntil?.toDate?.()?.getTime() > Date.now()) {
    return 'in_flight';
  }
  return null;
}

async function sendIdentityEmailOnce({
  key,
  to,
  template,
  operationId = crypto.randomUUID(),
  deliveryType = 'identity',
}) {
  const resendDeduplicationWindowMs = 60 * 1000;
  const jobRef = emailDeliveryJobRef(key);
  const leaseId = crypto.randomUUID();
  const leaseUntil = new Date(Date.now() + 5 * 60 * 1000);
  const claim = await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(jobRef);
    const job = snapshot.data() || {};
    if (job.status === 'sent') {
      const sentAt = job.sentAt?.toDate?.()?.getTime?.();
      const recentAuthVerification =
        deliveryType === 'auth-verification' &&
        Number.isFinite(sentAt) &&
        Date.now() - sentAt < resendDeduplicationWindowMs;
      if (recentAuthVerification || deliveryType !== 'auth-verification' || !Number.isFinite(sentAt)) {
        return { claimed: false, outcome: 'already_sent' };
      }
    }
    if (job.status === 'sending' && job.leaseUntil?.toDate?.()?.getTime() > Date.now()) {
      return { claimed: false, outcome: 'in_flight' };
    }
    transaction.set(
      jobRef,
      {
        status: 'sending',
        operationId,
        deliveryType,
        recipientHash: crypto.createHash('sha256').update(normalizedEmail(to)).digest('hex'),
        expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
        leaseId,
        leaseUntil,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    return { claimed: true };
  });
  if (!claim.claimed) {
    console.info(
      JSON.stringify({
        event: 'email_delivery_skipped',
        operationId,
        deliveryType,
        result: claim.outcome,
      }),
    );
    return { sent: claim.outcome === 'already_sent', outcome: claim.outcome };
  }
  try {
    const delivery = await sendMail({ to, ...template });
    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(jobRef);
      if (snapshot.data()?.leaseId !== leaseId) return;
      transaction.set(
        jobRef,
        {
          status: 'sent',
          sentAt: FieldValue.serverTimestamp(),
          smtpResponseCode: Number.isInteger(delivery.responseCode) ? delivery.responseCode : null,
          messageId: delivery.messageId || FieldValue.delete(),
          expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
          leaseId: FieldValue.delete(),
          leaseUntil: FieldValue.delete(),
        },
        { merge: true },
      );
    });
    console.info(
      JSON.stringify({
        event: 'email_delivery_finished',
        operationId,
        deliveryType,
        attempts: delivery.attempts,
        smtpResponseCode: delivery.responseCode,
        messageId: delivery.messageId || undefined,
        result: 'smtp_accepted',
      }),
    );
    return {
      sent: true,
      outcome: 'smtp_accepted',
      attempts: delivery.attempts,
    };
  } catch (error) {
    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(jobRef);
      if (snapshot.data()?.leaseId === leaseId)
        transaction.set(
          jobRef,
          {
            status: 'failed',
            operationId,
            deliveryType,
            attempts: Number(error?.attempts || 1),
            failureCode: String(error?.smtpCode || 'unknown'),
            failureCommand: String(error?.command || 'unknown'),
            failureResponseCode: Number.isInteger(error?.responseCode) ? error.responseCode : null,
            failureStage: String(error?.stage || 'unknown'),
            failedAt: FieldValue.serverTimestamp(),
            expiresAt: new Date(Date.now() + 60 * 60 * 1000),
            leaseId: FieldValue.delete(),
            leaseUntil: FieldValue.delete(),
          },
          { merge: true },
        );
    });
    console.warn(
      JSON.stringify({
        event: 'email_delivery_failed',
        operationId,
        deliveryType,
        attempts: Number(error?.attempts || 1),
        result: 'smtp_rejected',
        smtpCode: String(error?.smtpCode || 'unknown'),
        command: String(error?.command || 'unknown'),
        responseCode: Number.isInteger(error?.responseCode) ? error.responseCode : null,
        stage: String(error?.stage || 'unknown'),
      }),
    );
    return { sent: false, outcome: 'smtp_rejected', operationId };
  }
}

exports.sendAuthEmail = functions
  .runWith({ secrets: SMTP_SECRETS, enforceAppCheck: false })
  .https.onCall(async (data, context) => {
    const action = String(data?.action || '').trim();
    const email = normalizedEmail(data?.email || context.auth?.token?.email);
    if (!['verification', 'passwordReset'].includes(action) || !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
      throw new HttpsError('invalid-argument', 'Érvénytelen e-mailes művelet.');
    }
    if (action !== 'passwordReset' && !context.auth) throw new HttpsError('unauthenticated', 'Jelentkezz be.');
    if (action !== 'passwordReset' && normalizedEmail(context.auth.token.email) !== email) {
      throw new HttpsError('permission-denied', 'Csak a saját e-mail-címedre kérhetsz levelet.');
    }
    if (action === 'verification') {
      const authUser = await auth.getUser(context.auth.uid);
      const hasPasswordProvider = authUser.providerData.some((provider) => provider.providerId === 'password');
      if (!hasPasswordProvider) {
        throw new HttpsError('failed-precondition', 'Google-fiókhoz nem szükséges e-mail-megerősítés.');
      }
    }
    const identity = action === 'passwordReset' ? email : context.auth.uid;
    const verificationDeliveryKey = `auth:verification:${identity}`;
    if (action === 'verification') {
      const recentOutcome = await recentEmailDeliveryOutcome(verificationDeliveryKey, 'auth-verification');
      if (recentOutcome) {
        return {
          sent: recentOutcome === 'already_sent',
          outcome: recentOutcome,
        };
      }
    }
    if (!(await allowCall(`email:${identity}`, `auth_email_${action}`, 3))) {
      throw new HttpsError('resource-exhausted', 'Kérlek, próbáld később.');
    }
    if (action === 'passwordReset') {
      try {
        await auth.getUserByEmail(email);
      } catch (error) {
        if (error?.code === 'auth/user-not-found') return { sent: true };
        throw new HttpsError('internal', 'A levélküldés nem sikerült.');
      }
    }
    let link;
    try {
      const settings = { url: EMAIL_ACTION_URL, handleCodeInApp: false };
      const generated = await generateAuthActionLink({
        auth,
        action,
        email,
        settings,
      });
      link = generated.link;
      if (generated.attempts > 1) {
        console.info(
          JSON.stringify({
            event: 'auth_action_link_retried',
            action,
            attempts: generated.attempts,
          }),
        );
      }
    } catch (error) {
      console.warn(
        JSON.stringify({
          event: 'auth_action_link_failed',
          code: String(error?.code || 'unknown'),
          attempts: Number(error?.attempts || 1),
        }),
      );
      throw new HttpsError('internal', 'A levélküldés nem sikerült.');
    }
    const template = authEmailTemplate(action, link);
    const operationId = crypto.randomUUID();
    const delivery = await sendIdentityEmailOnce({
      key: action === 'verification' ? verificationDeliveryKey : `${action}:${identity}:${link.split('?')[0]}`,
      to: email,
      template,
      operationId,
      deliveryType: `auth-${action}`,
    });
    if (!delivery.sent && !['already_sent', 'in_flight'].includes(delivery.outcome)) {
      throw new HttpsError('unavailable', 'A levélküldés nem sikerült. Próbáld újra később.', { operationId });
    }
    return { sent: delivery.sent, outcome: delivery.outcome };
  });
// Article comments are accessed only through this callable (Admin SDK).
// Keep compatibility with already distributed Play builds until a verified
// App Check enforcement is intentionally disabled; active clients must remain
// compatible while Auth and server-side authorization continue to protect calls.
exports.articleComments = functions.runWith({ enforceAppCheck: false }).https.onCall(async (data, context) => {
  const postId = Number(data?.postId);
  if (!Number.isSafeInteger(postId) || postId <= 0) throw new HttpsError('invalid-argument', 'Érvénytelen cikk.');
  const collection = db.collection('article_comments').doc(String(postId)).collection('comments');
  const action = data?.action || 'list';
  const uid = context.auth?.uid;
  const profile = uid ? (await db.collection('community_profiles').doc(uid).get()).data() || {} : {};
  const moderator = isAdmin(context, profile) || profile.accessRole === 'moderator';
  if (action === 'list') {
    let query = collection.orderBy('createdAt', 'desc').orderBy(FieldPath.documentId(), 'desc');
    if (data.cursor) {
      if (typeof data.cursor !== 'string' || !/^[a-zA-Z0-9_-]{1,128}$/.test(data.cursor))
        throw new HttpsError('invalid-argument', 'Érvénytelen lapozás.');
      const cursor = await collection.doc(data.cursor).get();
      if (cursor.exists) query = query.startAfter(cursor);
    }
    const result = await query.limit(21).get();
    const docs = result.docs.slice(0, 20);
    return {
      moderator,
      hasMore: result.size > 20,
      items: docs.map((doc) => {
        const value = doc.data();
        return {
          id: doc.id,
          authorId: value.authorId,
          authorName: value.authorName,
          imageUrl: value.imageUrl,
          text: value.text,
          replyToName: value.replyToName || '',
          replyToText: value.replyToText || '',
          createdAt: value.createdAt?.toMillis() || 0,
        };
      }),
    };
  }
  if (!uid) throw new HttpsError('unauthenticated', 'Próbáld újra a küldést.');
  if (isAnonymousAuth(context))
    throw new HttpsError('unauthenticated', 'A hozzászóláshoz regisztráció szükséges.');
  if ((await db.collection('community_bans').doc(uid).get()).exists)
    throw new HttpsError('permission-denied', 'Jelenleg nem hozzászólhatsz.');
  const id = data?.id;
  if (typeof id !== 'string' || !/^[a-zA-Z0-9_-]{1,128}$/.test(id))
    throw new HttpsError('invalid-argument', 'Érvénytelen hozzászólás.');
  const ref = collection.doc(id);
  if (action === 'create') {
    const text = typeof data.text === 'string' ? data.text.trim() : '';
    if (!text || text.length > 2000) throw new HttpsError('invalid-argument', 'Írj 1–2000 karakteres hozzászólást.');
    const existing = await ref.get();
    if (existing.exists) {
      if (existing.data().authorId === uid && existing.data().text === text) return { ok: true };
      throw new HttpsError('already-exists', 'Ez a hozzászólás már létezik.');
    }
    if (!(await allowCall(uid, 'article-comment', 5)))
      throw new HttpsError('resource-exhausted', 'Kérlek, várj egy percet az újabb hozzászólással.');
    const response = await fetch(`https://hungarianhardstyle.hu/wp-json/huhs/v1/posts/${postId}`, {
      signal: AbortSignal.timeout(15000),
    });
    if (!response.ok) throw new HttpsError('unavailable', 'A cikk most nem érhető el. Próbáld újra később.');
    const article = await response.json();
    if (Number(article.id) !== postId) throw new HttpsError('not-found', 'A cikk nem található.');
    // Replies quote only the targeted comment (no chains): the author name and
    // a short text snapshot are copied onto the new comment, and the quoted
    // author is notified.
    const replyToCommentId = typeof data?.replyToCommentId === 'string' ? data.replyToCommentId.trim() : '';
    let replyToName = '';
    let replyToText = '';
    let replyToAuthorId = '';
    if (replyToCommentId) {
      if (!/^[a-zA-Z0-9_-]{1,128}$/.test(replyToCommentId))
        throw new HttpsError('invalid-argument', 'Érvénytelen válaszcél.');
      const target = await collection.doc(replyToCommentId).get();
      if (target.exists) {
        const targetData = target.data() || {};
        replyToAuthorId = String(targetData.authorId || '').trim();
        replyToName = String(targetData.authorName || '').trim().slice(0, 80);
        replyToText = String(targetData.text || '').trim().slice(0, 200);
      }
    }
    let commentCreated = false;
    await db.runTransaction(async (tx) => {
      const current = await tx.get(ref);
      if (current.exists) {
        if (current.data().authorId !== uid || current.data().text !== text)
          throw new HttpsError('already-exists', 'Ez a hozzászólás már létezik.');
        return;
      }
      tx.create(ref, {
        authorId: uid,
        authorName: profile.displayName || 'HUHS tag',
        imageUrl: profile.profileImageUrl || '',
        text,
        ...(replyToName && replyToText ? { replyToCommentId, replyToName, replyToText } : {}),
        createdAt: FieldValue.serverTimestamp(),
      });
      commentCreated = true;
    });
    if (commentCreated) {
      const admins = (await db.collection('community_profiles').get()).docs.filter(
        (admin) => admin.data()?.accessRole === 'admin',
      );
      await Promise.all(
        admins.map((admin) =>
          createNotificationBestEffort({
            recipientUid: admin.id,
            type: 'article_comment',
            title: 'Új hozzászólás érkezett',
            body: 'Új hozzászólás érkezett egy cikkhez. Ellenőrizd a közösségi tartalmak között.',
            targetType: 'article',
            targetId: String(postId),
            dedupeKey: `article-comment-notification:${postId}:${id}:${admin.id}`,
            senderId: uid,
          }),
        ),
      );
      // One point per article comment, with the daily limit enforced inside
      // the idempotent server-side achievement ledger.
      await awardAchievementPoints(uid, 1, `article-comment:${postId}:${id}`);
      if (replyToAuthorId && replyToAuthorId !== uid) {
        await createNotificationBestEffort({
          recipientUid: replyToAuthorId,
          type: 'article_comment_reply',
          title: 'Válaszoltak a hozzászólásodra',
          body: `${profile.displayName || 'Egy HUHS tag'} válaszolt a hozzászólásodra egy cikknél.`,
          targetType: 'article',
          targetId: String(postId),
          dedupeKey: `article-comment-reply:${postId}:${id}:${replyToAuthorId}`,
          senderId: uid,
        });
      }
    }
  } else if (action === 'delete') {
    await db.runTransaction(async (tx) => {
      const comment = await tx.get(ref);
      if (!comment.exists) return;
      if (comment.data().authorId !== uid && !moderator)
        throw new HttpsError('permission-denied', 'Ezt a hozzászólást nem törölheted.');
      tx.delete(ref);
    });
  } else if (action === 'report') {
    const comment = await ref.get();
    if (!comment.exists) throw new HttpsError('not-found', 'A hozzászólás már nem található.');
    if (!(await allowCall(uid, 'article-report', 10)))
      throw new HttpsError('resource-exhausted', 'Kérlek, próbáld később.');
    await db
      .collection('chat_reports')
      .doc(crypto.createHash('sha256').update(`article:${postId}:${id}:${uid}`).digest('hex'))
      .set({
        postId: id,
        articleId: postId,
        type: 'article_comment',
        reporterId: uid,
        reporterName: profile.displayName || 'Vendég',
        reportedUserId: comment.data().authorId,
        reportedUserName: comment.data().authorName,
        reportedText: comment.data().text,
        reason: 'Cikkhozzászólás jelentése',
        status: 'open',
        createdAt: FieldValue.serverTimestamp(),
      });
  } else throw new HttpsError('invalid-argument', 'Ismeretlen művelet.');
  return { ok: true };
});
const WORDPRESS_BASE_URL = 'https://hungarianhardstyle.hu/wp-json/huhs/v1';
const WORDPRESS_USERNAME = defineSecret('WORDPRESS_USERNAME');
const WORDPRESS_APPLICATION_PASSWORD = defineSecret('WORDPRESS_APPLICATION_PASSWORD');
const GOOGLE_PLAY_SERVICE_ACCOUNT_JSON = defineSecret('GOOGLE_PLAY_SERVICE_ACCOUNT_JSON');
const CLOUDINARY_API_KEY = defineSecret('CLOUDINARY_API_KEY');
const CLOUDINARY_API_SECRET = defineSecret('CLOUDINARY_API_SECRET');
const CLOUDINARY_CLOUD_NAME = 'fjxo93em';
const GOOGLE_PLAY_PACKAGE_NAME = 'hu.hungarianhardstyle.app';
// Match the region schema returned by the current Play catalog.
const GOOGLE_PLAY_REGIONS_VERSION = '2025/03';
let achievementBadgesCache = null;
let achievementBadgesCacheAt = 0;
// Badge artwork can be replaced in WordPress without changing its media URL.
// Keep the catalog cache short enough to notice that change, while still
// deduplicating concurrent profile/chat requests.
const ACHIEVEMENT_BADGES_CACHE_TTL_MS = 30 * 1000;
let eventExpiryCacheAt = 0;
let eventExpiryCache = null;
const VALID_EVENT_IDS_CACHE_TTL_MS = 5 * 60 * 1000;
const wordPressCall = (handler) =>
  functions
    .runWith({
      secrets: [WORDPRESS_USERNAME, WORDPRESS_APPLICATION_PASSWORD],
      enforceAppCheck: true,
    })
    .https.onCall(handler);
function isAnonymousAuth(context) {
  return context.auth?.token?.firebase?.sign_in_provider === 'anonymous' || context.auth?.token?.is_anonymous === true;
}

exports.getGameAudioClip = wordPressCall(async (data, context) => {
  if (!context.auth?.uid) throw new HttpsError('unauthenticated', 'A játék használatához be kell jelentkezned.');
  if (isAnonymousAuth(context))
    throw new HttpsError('unauthenticated', 'A játék használatához regisztráció szükséges.');
  const gameId = Number(data?.gameId);
  if (!Number.isSafeInteger(gameId) || gameId <= 0) throw new HttpsError('invalid-argument', 'Érvénytelen játék.');
  const credentials = `${WORDPRESS_USERNAME.value()}:${WORDPRESS_APPLICATION_PASSWORD.value()}`;
  const response = await fetch(`${WORDPRESS_BASE_URL}/games/${gameId}/clip-token`, {
    method: 'POST',
    headers: {
      Authorization: `Basic ${Buffer.from(credentials).toString('base64')}`,
      Accept: 'application/json',
    },
    signal: AbortSignal.timeout(15000),
  });
  const body = await response.json().catch(() => ({}));
  if (response.status === 409)
    throw new HttpsError('unavailable', 'A hangrészlet még készül. Próbáld újra pár másodperc múlva.');
  if (!response.ok || typeof body.download_url !== 'string')
    throw new HttpsError('failed-precondition', 'A játék hangrészlete most nem érhető el.');
  return { url: body.download_url, expiresIn: Number(body.expires_in) || 300 };
});

async function syncGameStatsToWordPress(gameId, stats) {
  const credentials = `${WORDPRESS_USERNAME.value()}:${WORDPRESS_APPLICATION_PASSWORD.value()}`;
  const response = await fetch(`${WORDPRESS_BASE_URL}/games/${gameId}/stats`, {
    method: 'POST',
    headers: {
      Authorization: `Basic ${Buffer.from(credentials).toString('base64')}`,
      Accept: 'application/json',
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      submissions: Number(stats.submissions || 0),
      correct_answers: Number(stats.correctAnswers || 0),
      total_answers: Number(stats.totalAnswers || 0),
    }),
    signal: AbortSignal.timeout(15000),
  });
  if (!response.ok) throw new Error(`WordPress játékstatisztika frissítése sikertelen: ${response.status}`);
}

exports.submitGameAttempt = wordPressCall(async (data, context) => {
  const uid = context.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'A játék használatához be kell jelentkezned.');
  if (isAnonymousAuth(context)) throw new HttpsError('unauthenticated', 'A játékhoz regisztráció szükséges.');
  const gameId = Number(data?.gameId);
  if (!Number.isSafeInteger(gameId) || gameId <= 0) throw new HttpsError('invalid-argument', 'Érvénytelen játék.');

  const credentials = `${WORDPRESS_USERNAME.value()}:${WORDPRESS_APPLICATION_PASSWORD.value()}`;
  const response = await fetch(`${WORDPRESS_BASE_URL}/games/${gameId}/private`, {
    headers: {
      Authorization: `Basic ${Buffer.from(credentials).toString('base64')}`,
      Accept: 'application/json',
    },
    signal: AbortSignal.timeout(15000),
  });
  const game = await response.json().catch(() => ({}));
  if (!response.ok || !game || game.type === undefined) throw new HttpsError('not-found', 'A játék nem található.');
  if (game.status !== 'active') throw new HttpsError('failed-precondition', 'Ez a játék már nem fogad válaszokat.');

  const timeline = game.type === 'timeline';
  let correctAnswers = 0;
  let totalAnswers = 0;
  let submittedAnswers = null;
  let submittedOrderedIds = null;
  if (timeline) {
    const orderedIds = Array.isArray(data?.orderedIds) ? data.orderedIds.map(String) : [];
    const expected = Array.isArray(game.timeline_items)
      ? [...game.timeline_items]
          .sort((a, b) => String(a.date || '').localeCompare(String(b.date || '')))
          .map((item) => String(item.id || ''))
      : [];
    if (expected.length < 2 || orderedIds.length !== expected.length || new Set(orderedIds).size !== orderedIds.length)
      throw new HttpsError('invalid-argument', 'A teljes idővonalat add meg.');
    if (orderedIds.some((id) => !expected.includes(id)))
      throw new HttpsError('invalid-argument', 'Érvénytelen idővonal-válasz.');
    totalAnswers = 1;
    correctAnswers = orderedIds.every((id, index) => id === expected[index]) ? 1 : 0;
    submittedOrderedIds = orderedIds;
  } else {
    const answers = Array.isArray(data?.answers) ? data.answers.map(Number) : [];
    const questions = Array.isArray(game.questions) ? game.questions : [];
    if (!questions.length || answers.length !== questions.length)
      throw new HttpsError('invalid-argument', 'Minden kérdésre válaszolj.');
    if (
      answers.some(
        (answer, index) =>
          !Number.isInteger(answer) ||
          answer < 0 ||
          answer >= (Array.isArray(questions[index]?.options) ? questions[index].options.length : 0),
      )
    ) {
      throw new HttpsError('invalid-argument', 'Érvénytelen válasz érkezett.');
    }
    totalAnswers = questions.length;
    correctAnswers = questions.reduce((total, question, index) => {
      const correct = Number(question.correct);
      const answer = Number(answers[index]);
      return total + (Number.isInteger(answer) && answer === correct ? 1 : 0);
    }, 0);
    submittedAnswers = answers;
  }

  const attemptId = crypto.createHash('sha256').update(`game:${gameId}:${uid}`).digest('hex');
  const attemptRef = db.collection('game_attempts').doc(attemptId);
  const statsRef = db.collection('game_stats').doc(String(gameId));
  let result;
  await db.runTransaction(async (transaction) => {
    const existing = await transaction.get(attemptRef);
    if (existing.exists) {
      const saved = existing.data() || {};
      result = {
        alreadySubmitted: true,
        correctAnswers: Number(saved.correctAnswers || 0),
        totalAnswers: Number(saved.totalAnswers || 0),
        achievementPoints: Number(saved.achievementPoints || 0),
        answers: Array.isArray(saved.answers) ? saved.answers.map(Number) : null,
        orderedIds: Array.isArray(saved.orderedIds) ? saved.orderedIds.map(String) : null,
      };
      return;
    }
    const achievementPoints = gameRewardPoints(game, correctAnswers, totalAnswers);
    transaction.create(attemptRef, {
      gameId,
      uid,
      correctAnswers,
      totalAnswers,
      achievementPoints,
      answers: submittedAnswers,
      orderedIds: submittedOrderedIds,
      createdAt: FieldValue.serverTimestamp(),
    });
    transaction.set(
      statsRef,
      {
        gameId,
        submissions: FieldValue.increment(1),
        correctAnswers: FieldValue.increment(correctAnswers),
        totalAnswers: FieldValue.increment(totalAnswers),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    result = {
      alreadySubmitted: false,
      correctAnswers,
      totalAnswers,
      achievementPoints,
    };
  });

  const stats = (await statsRef.get()).data() || {};
  try {
    await syncGameStatsToWordPress(gameId, stats);
  } catch (error) {
    console.warn(
      JSON.stringify({
        event: 'game_stats_sync_failed',
        gameId,
        message: error?.message || String(error),
      }),
    );
  }
  return result;
});

async function finalizeClosedGameRewards(game) {
  const gameId = Number(game?.id);
  if (!Number.isSafeInteger(gameId) || gameId <= 0 || game?.status !== 'closed')
    return { finalized: false, reason: 'not_closed' };
  const statsRef = db.collection('game_stats').doc(String(gameId));
  const stats = (await statsRef.get()).data() || {};
  if (stats.rewardsFinalized === true) return { finalized: false, reason: 'already_finalized' };

  const attempts = await db.collection('game_attempts').where('gameId', '==', gameId).get();
  const uids = [...new Set(attempts.docs.map((attempt) => String(attempt.data()?.uid || '').trim()).filter(Boolean))];
  const profiles = uids.length
    ? await db.getAll(...uids.map((uid) => db.collection('community_profiles').doc(uid)))
    : [];
  const namesByUid = new Map(
    profiles
      .filter((profile) => profile.exists)
      .map((profile) => [profile.id, String(profile.data()?.displayName || '').trim()]),
  );
  const ranked = buildRankedGameEntries(
    attempts.docs.map((attempt) => {
      const value = attempt.data() || {};
      return {
        uid: String(value.uid || '').trim(),
        displayName: namesByUid.get(String(value.uid || '').trim()) || '',
        correctAnswers: Number(value.correctAnswers || 0),
        totalAnswers: Number(value.totalAnswers || 0),
        submittedAt: value.createdAt?.toMillis?.() || 0,
      };
    }),
  );
  const ranksByUid = new Map(ranked.map((entry) => [entry.uid, entry.rank]));
  const title = String(game.title || 'HUHS játék').trim();
  const awards = attempts.docs.map(async (attempt) => {
    const value = attempt.data() || {};
    const uid = String(value.uid || '').trim();
    const points = Math.max(0, Number(value.achievementPoints || 0));
    if (!uid || points <= 0) return;
    const won = ranksByUid.get(uid) === 1;
    await awardAchievementPoints(uid, points, `game:${gameId}:reward`, {
      title: won ? 'Megnyerted a HUHS játékot!' : 'Elkészült a játékod eredménye',
      body: won
        ? `Megnyerted a „${title}” játékot, és +${points} achievement pontot kaptál.`
        : `A „${title}” játékban elért eredményedért +${points} achievement pontot kaptál.`,
    });
  });
  const results = await Promise.allSettled(awards);
  const failed = results.find((result) => result.status === 'rejected');
  if (failed) throw failed.reason;
  await statsRef.set(
    {
      resultsAvailable: true,
      resultsAvailableAt: FieldValue.serverTimestamp(),
      rewardsFinalized: true,
      rewardsFinalizedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
  return { finalized: true, attempts: attempts.size };
}

async function loadLatestClosedGame() {
  const response = await fetch(`${WORDPRESS_BASE_URL}/games/results/latest`, {
    headers: { Accept: 'application/json' },
    signal: AbortSignal.timeout(15000),
  });
  if (!response.ok) throw new Error(`WordPress játéklezárás: HTTP ${response.status}`);
  const game = await response.json().catch(() => null);
  return game && game.status === 'closed' ? game : null;
}

exports.finalizeClosedGameRewards = onSchedule(
  {
    schedule: 'every 5 minutes',
    timeZone: 'Europe/Budapest',
    region: 'europe-central2',
  },
  async () => {
    const game = await loadLatestClosedGame();
    if (!game) return;
    const result = await finalizeClosedGameRewards(game);
    console.info(
      JSON.stringify({
        event: 'game_rewards_finalized',
        gameId: Number(game.id),
        ...result,
      }),
    );
  },
);

exports.getGameAttemptStatus = wordPressCall(async (data, context) => {
  const uid = context.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'A játék használatához be kell jelentkezned.');
  if (isAnonymousAuth(context)) throw new HttpsError('unauthenticated', 'A játékhoz regisztráció szükséges.');
  const gameId = Number(data?.gameId);
  if (!Number.isSafeInteger(gameId) || gameId <= 0) throw new HttpsError('invalid-argument', 'Érvénytelen játék.');

  const attemptId = crypto.createHash('sha256').update(`game:${gameId}:${uid}`).digest('hex');
  const snapshot = await db.collection('game_attempts').doc(attemptId).get();
  if (!snapshot.exists) return { submitted: false };
  const saved = snapshot.data() || {};
  return {
    submitted: true,
    correctAnswers: Number(saved.correctAnswers || 0),
    totalAnswers: Number(saved.totalAnswers || 0),
    achievementPoints: Number(saved.achievementPoints || 0),
    answers: Array.isArray(saved.answers) ? saved.answers.map(Number) : null,
    orderedIds: Array.isArray(saved.orderedIds) ? saved.orderedIds.map(String) : null,
    submittedAt: saved.createdAt?.toMillis?.() || null,
  };
});

exports.getGameResults = wordPressCall(async (data, context) => {
  if (!(await allowCallByIp(context, 'game_results', 60))) {
    throw new HttpsError('resource-exhausted', 'Túl sok kérés.');
  }
  const gameId = Number(data?.gameId);
  if (!Number.isSafeInteger(gameId) || gameId <= 0) throw new HttpsError('invalid-argument', 'Érvénytelen játék.');

  const statsRef = db.collection('game_stats').doc(String(gameId));
  const stats = await statsRef.get();
  if (stats.data()?.resultsAvailable !== true || stats.data()?.rewardsFinalized !== true) {
    const response = await fetch(`${WORDPRESS_BASE_URL}/games/${gameId}`, {
      headers: { Accept: 'application/json' },
      signal: AbortSignal.timeout(15000),
    });
    const game = await response.json().catch(() => ({}));
    if (!response.ok || game?.status !== 'closed') {
      throw new HttpsError('failed-precondition', 'Az eredménylista jelenleg nem érhető el.');
    }
    await finalizeClosedGameRewards(game);
  }

  const attempts = await db.collection('game_attempts').where('gameId', '==', gameId).get();
  const profileRefs = attempts.docs
    .map((attempt) => String(attempt.data()?.uid || '').trim())
    .filter(Boolean)
    .map((uid) => db.collection('community_profiles').doc(uid));
  const profiles = profileRefs.length ? await db.getAll(...profileRefs) : [];
  const namesByUid = new Map(
    profiles
      .filter((profile) => profile.exists)
      .map((profile) => [profile.id, String(profile.data()?.displayName || '').trim()]),
  );
  const entries = attempts.docs.map((attempt) => {
    const value = attempt.data() || {};
    return {
      displayName: namesByUid.get(String(value.uid || '')) || '',
      correctAnswers: Number(value.correctAnswers || 0),
      totalAnswers: Number(value.totalAnswers || 0),
      submittedAt: value.createdAt?.toMillis?.() || 0,
    };
  });
  return { items: buildGameLeaderboard(entries) };
});

const labelProductSyncSecrets = [WORDPRESS_USERNAME, WORDPRESS_APPLICATION_PASSWORD, GOOGLE_PLAY_SERVICE_ACCOUNT_JSON];

async function allowCall(uid, key, limit = 20) {
  const bucket = Math.floor(Date.now() / 60_000);
  const ref = db
    .collection('rate_limits')
    .doc(crypto.createHash('sha256').update(`${key}:${uid}:${bucket}`).digest('hex'));
  let allowed = false;
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const count = Number(snapshot.data()?.count || 0);
    allowed = count < limit;
    if (allowed) {
      transaction.set(ref, {
        key,
        uid,
        bucket,
        count: count + 1,
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
  });
  return allowed;
}

function callerIp(context) {
  return String(context?.rawRequest?.ip || context?.rawRequest?.socket?.remoteAddress || '').trim();
}

// IP-scoped rate limit for public (unauthenticated) readers. The IP is hashed
// before it becomes part of the rate-limit key so no raw address is persisted.
// Fails open only when no IP is available (Firebase always provides one).
async function allowCallByIp(context, key, limit = 30) {
  const ip = callerIp(context);
  if (!ip) return true;
  const ipHash = crypto.createHash('sha256').update(`huhs-ip:${ip}`).digest('hex').slice(0, 16);
  return allowCall(`ip:${ipHash}`, key, limit);
}

const defaultAchievementBadges = [
  {
    slug: 'starter',
    name: 'Kezdő ütem',
    min_points: 0,
    description: 'A HUHS közösség alapjelvénye.',
    image_url: '',
  },
  {
    slug: 'first-step',
    name: 'Első lépés',
    min_points: 100,
    description: 'Az első közösségi mérföldkő.',
    image_url: '',
  },
  {
    slug: 'regular',
    name: 'Rendszeres látogató',
    min_points: 300,
    description: 'Rendszeresen jelen van a közösségben.',
    image_url: '',
  },
  {
    slug: 'hardstyle-face',
    name: 'Hardstyle arc',
    min_points: 700,
    description: 'Láthatóan aktív HUHS-közösségi tag.',
    image_url: '',
  },
  {
    slug: 'community',
    name: 'Közösségi ember',
    min_points: 1500,
    description: 'Sokat tesz a közösségi jelenlétért.',
    image_url: '',
  },
  {
    slug: 'scene-veteran',
    name: 'Scene veteran',
    min_points: 3000,
    description: 'Hosszú távon aktív színtértag.',
    image_url: '',
  },
  {
    slug: 'huhs-legend',
    name: 'HUHS legenda',
    min_points: 6000,
    description: 'Kiemelkedő, tartós közösségi aktivitás.',
    image_url: '',
  },
];

async function getAchievementBadges() {
  if (achievementBadgesCache && Date.now() - achievementBadgesCacheAt < ACHIEVEMENT_BADGES_CACHE_TTL_MS)
    return achievementBadgesCache;
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 2500);
  try {
    const response = await fetch(`${WORDPRESS_BASE_URL}/achievements/badges`, {
      headers: { Accept: 'application/json' },
      signal: controller.signal,
    });
    const body = await response.json();
    if (response.ok && Array.isArray(body) && body.length) {
      const catalogVersion = String(
        response.headers.get('etag') ||
          response.headers.get('last-modified') ||
          body.map((badge) => `${badge?.slug || ''}:${badge?.image_url || ''}:${badge?.updated_at || ''}`).join('|'),
      ).trim();
      const versionToken = crypto.createHash('sha1').update(catalogVersion).digest('hex').slice(0, 16);
      achievementBadgesCache = body
        .filter((badge) => badge.active !== 0)
        .map((badge) => ({
          slug: String(badge.slug || '').trim(),
          name: String(badge.name || 'HUHS jelvény').trim(),
          min_points: Math.max(0, Number(badge.min_points || 0)),
          description: String(badge.description || '').trim(),
          image_url: versionBadgeImageUrl(String(badge.image_url || '').trim(), versionToken),
        }))
        .filter((badge) => badge.slug);
      achievementBadgesCacheAt = Date.now();
      return achievementBadgesCache;
    }
  } catch (error) {
    console.warn(
      JSON.stringify({
        event: 'achievement_catalog_fallback',
        message: error?.message || String(error),
      }),
    );
  } finally {
    clearTimeout(timeout);
  }
  // Keep the last valid catalog if one exists. Do not cache the image-less
  // emergency defaults: the next request must be allowed to retry WordPress.
  return achievementBadgesCache || defaultAchievementBadges;
}

function versionBadgeImageUrl(imageUrl, versionToken) {
  if (!imageUrl || !versionToken) return imageUrl;
  try {
    const parsed = new URL(imageUrl);
    parsed.searchParams.set('huhs_badge_v', versionToken);
    return parsed.toString();
  } catch (_) {
    const separator = imageUrl.includes('?') ? '&' : '?';
    return `${imageUrl}${separator}huhs_badge_v=${encodeURIComponent(versionToken)}`;
  }
}

async function getValidEventIds() {
  const now = Date.now();
  if (eventExpiryCache && now - eventExpiryCacheAt < VALID_EVENT_IDS_CACHE_TTL_MS) {
    return new Set([...eventExpiryCache.entries()].filter(([, expiry]) => expiry >= now).map(([id]) => id));
  }
  try {
    const response = await fetch(`${WORDPRESS_BASE_URL}/events?summary=true&include_past=true`, {
      headers: { Accept: 'application/json' },
    });
    const body = await response.json();
    // An unavailable WordPress endpoint is not proof that every event is
    // invalid. Keep this distinct from an empty, successfully loaded catalog
    // so a transient outage cannot roll back legitimate user writes.
    if (!response.ok || !Array.isArray(body)) return null;
    eventExpiryCache = new Map(
      body
        .map((event) => [Number(event?.id), eventExpiryTimestamp(event)])
        .filter(([id, expiry]) => Number.isInteger(id) && id > 0 && Number.isFinite(expiry)),
    );
    const validEventIds = new Set(
      [...eventExpiryCache.entries()].filter(([, expiry]) => expiry >= now).map(([id]) => id),
    );
    eventExpiryCacheAt = Date.now();
    return validEventIds;
  } catch (error) {
    console.warn(
      JSON.stringify({
        event: 'event_validation_failed',
        message: error?.message || String(error),
      }),
    );
    return null;
  }
}

function eventExpiryTimestamp(event) {
  const dateText = String(event?.end_date || event?.start_date || '').trim();
  if (!dateText) return NaN;
  const timeText = String(event?.end_date ? event?.end_time || '' : event?.start_time || '').trim();
  return Date.parse(`${dateText}T${timeText || '23:59:59'}`);
}

function sameEventState(before, after) {
  const comparable = (data) =>
    Object.fromEntries(
      Object.entries(data || {})
        .filter(([key]) => key !== 'updatedAt' && key !== '_huhsExpiredEventReverted')
        .sort(([first], [second]) => first.localeCompare(second)),
    );
  return JSON.stringify(comparable(before)) === JSON.stringify(comparable(after));
}

async function restoreExpiredEventWrite(event, before, after) {
  const afterExists = event.data?.after?.exists === true;
  const beforeExists = event.data?.before?.exists === true;
  if (afterExists && after?._huhsExpiredEventReverted === true && before?._huhsExpiredEventReverted !== true)
    return true;
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

async function awardAchievementPoints(uid, delta, sourceKey, notification = null) {
  if (!uid || !Number.isInteger(delta) || delta === 0 || !sourceKey) return { changed: false };
  const ledgerId = crypto
    .createHash('sha256')
    .update(`${uid}:${sourceKey}:${delta > 0 ? 'grant' : 'revoke'}`)
    .digest('hex')
    .slice(0, 40);
  const ledgerRef = db.collection('achievement_ledger').doc(ledgerId);
  const profileRef = db.collection('community_profiles').doc(uid);
  const isNewsLikeGrant = delta > 0 && sourceKey.startsWith('news-like:');
  const isArticleCommentGrant = delta > 0 && sourceKey.startsWith('article-comment:');
  const dailyLimit = isNewsLikeGrant || isArticleCommentGrant ? 5 : null;
  const dailyLimitRef =
    dailyLimit == null
      ? null
      : db
          .collection(isNewsLikeGrant ? 'achievement_news_like_limits' : 'achievement_article_comment_limits')
          .doc(`${uid}_${new Date().toISOString().slice(0, 10)}`);
  let result = { changed: false };
  // A WordPress fetch must never run inside a Firestore transaction: it can
  // hold the document lock for the full 2.5s HTTP timeout and cause contention.
  // Load the badge catalog first (it is cached for 30s and falls back safely).
  const badges = await getAchievementBadges();
  await db.runTransaction(async (transaction) => {
    const ledger = await transaction.get(ledgerRef);
    if (ledger.exists) return;
    const dailyActivity = dailyLimitRef ? await transaction.get(dailyLimitRef) : null;
    if (dailyActivity && Number(dailyActivity.data()?.count || 0) >= dailyLimit) return;
    const profile = await transaction.get(profileRef);
    // Anonymous interactions may still use public features such as news
    // reactions, but they never have an achievement profile and must not
    // receive points or cause one to be created implicitly.
    if (!profile.exists) return;
    const current = Math.max(0, Number(profile.data()?.achievementPoints || 0));
    const storedBadge = profile.data()?.achievementBadge;
    const previousBadgeSlug = String(storedBadge?.slug || '').trim();
    const points = Math.max(0, current + delta);
    const badge = persistedAchievementBadge(badges, points, storedBadge);
    // Only touch the badge and its cache version when the rank really changed.
    // Rewriting `achievementUpdatedAt` on every point would invalidate the
    // versioned badge image URL for every client on every single like.
    const badgeChanged = !sameAchievementBadge(storedBadge, badge);
    transaction.set(
      profileRef,
      {
        achievementPoints: points,
        ...(badgeChanged
          ? {
              achievementBadge: badge,
              achievementUpdatedAt: FieldValue.serverTimestamp(),
            }
          : {}),
      },
      { merge: true },
    );
    transaction.create(ledgerRef, {
      uid,
      sourceKey,
      delta,
      pointsAfter: points,
      createdAt: FieldValue.serverTimestamp(),
    });
    if (dailyLimitRef) {
      transaction.set(
        dailyLimitRef,
        {
          uid,
          date: new Date().toISOString().slice(0, 10),
          count: Number(dailyActivity?.data()?.count || 0) + 1,
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    }
    result = {
      changed: true,
      points,
      badge: badge.slug,
      badgeName: badge.name,
      levelChanged: previousBadgeSlug !== badge.slug,
    };
  });
  if (result.changed && delta > 0) {
    const title = String(notification?.title || 'Achievement pontot kaptál');
    const body = String(
      notification?.body ||
        `+${delta} achievement pontot kaptál. Új összpontszám: ${result.points}.` +
        (result.levelChanged ? ` Új rangod: „${result.badgeName || 'Achievement'}”.` : ''),
    );
    const notificationCreated = await createNotificationBestEffort({
      recipientUid: uid,
      type: 'achievement_points',
      title,
      body,
      targetType: 'achievement',
      targetId: uid,
      dedupeKey: `achievement-points:${ledgerId}`,
    });
    if (notificationCreated) await sendAchievementPushBestEffort(uid, title, body);
  }
  return result;
}

exports.reconcileAchievementPoints = functions
  .runWith({ enforceAppCheck: false })
  .https.onCall(async (data, context) => {
    if (!context.auth) throw new HttpsError('permission-denied', 'Csak admin futtathatja az újraszámolást.');
    const caller = (await db.collection('community_profiles').doc(context.auth.uid).get()).data() || {};
    if (!isAdmin(context, caller))
      throw new HttpsError('permission-denied', 'Csak admin futtathatja az újraszámolást.');
    const dryRun = data?.dryRun !== false;
    const [ledgerSnapshot, profileSnapshot] = await Promise.all([
      db.collection('achievement_ledger').get(),
      db.collection('community_profiles').get(),
    ]);
    const totals = new Map();
    for (const document of ledgerSnapshot.docs) {
      const entry = document.data() || {};
      const uid = String(entry.uid || '').trim();
      const delta = Number(entry.delta || 0);
      if (!uid || !Number.isInteger(delta)) continue;
      totals.set(uid, (totals.get(uid) || 0) + delta);
    }
    const badges = await getAchievementBadges();
    const changes = [];
    for (const profileDocument of profileSnapshot.docs) {
      const uid = profileDocument.id;
      const profile = profileDocument.data() || {};
      const points = Math.max(0, totals.get(uid) || 0);
      const badge = persistedAchievementBadge(badges, points, profile.achievementBadge);
      const current = Math.max(0, Number(profile.achievementPoints || 0));
      const badgeChanged = !sameAchievementBadge(profile.achievementBadge, badge);
      if (current !== points || badgeChanged) {
        changes.push({ uid, from: current, to: points, badge: badge.slug });
        if (!dryRun)
          await profileDocument.ref.set(
            {
              achievementPoints: points,
              ...(badgeChanged
                ? {
                    achievementBadge: badge,
                    achievementUpdatedAt: FieldValue.serverTimestamp(),
                  }
                : {}),
            },
            { merge: true },
          );
      }
    }
    return {
      dryRun,
      ledgerEntries: ledgerSnapshot.size,
      profiles: profileSnapshot.size,
      changed: changes.length,
      changes: changes.slice(0, 100),
    };
  });

function normalizeReferralCode(value) {
  return String(value || '')
    .trim()
    .toUpperCase()
    .replace(/[^A-Z0-9]/g, '')
    .slice(0, 16);
}

function referralCodeForUid(uid) {
  return crypto.createHash('sha256').update(`huhs-referral:${uid}`).digest('hex').slice(0, 8).toUpperCase();
}

exports.getMyReferralCode = functions.runWith({ enforceAppCheck: false }).https.onCall(async (data, context) => {
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

exports.claimReferralCode = functions.runWith({ enforceAppCheck: false }).https.onCall(async (data, context) => {
  const uid = String(context.auth?.uid || '').trim();
  if (!uid || context.auth?.token?.firebase?.sign_in_provider === 'anonymous') {
    throw new HttpsError('unauthenticated', 'Bejelentkezés szükséges.');
  }
  const code = normalizeReferralCode(data?.code);
  if (code.length < 6) throw new HttpsError('invalid-argument', 'Érvénytelen ajánlókód.');
  const authUser = await auth.getUser(uid);
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
    transaction.set(
      inviteeRef,
      {
        referredBy: inviter.id,
        referralClaimedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  });
  return { claimed: true };
});

exports.awardAchievementFromReferral = onDocumentWritten(
  {
    document: 'community_profiles/{userId}',
    database: 'hungarian-hardstyle',
    region: 'europe-central2',
  },
  async (event) => {
    const before = event.data?.before?.data() || {};
    const after = event.data?.after?.data() || {};
    const invitedBy = String(after.referredBy || '').trim();
    if (!invitedBy || before.referredBy || after.referralRewardGranted === true) return null;
    const userId = String(event.params.userId || '').trim();
    const result = await awardAchievementPoints(invitedBy, 50, `referral:${userId}`);
    await event.data.after.ref.update({
      referralRewardGranted: true,
      referralRewardGrantedAt: FieldValue.serverTimestamp(),
    });
    console.log(JSON.stringify({ event: 'achievement_referral', result }));
    return result;
  },
);

exports.refreshAchievementBadge = functions.runWith({ enforceAppCheck: false }).https.onCall(async (data, context) => {
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
    // Without a reachable WordPress catalog this keeps the stored badge
    // instead of overwriting it with the image-less emergency starter rank.
    const achievementBadge = persistedAchievementBadge(badges, points, profile.achievementBadge);
    if (!sameAchievementBadge(profile.achievementBadge, achievementBadge)) {
      transaction.set(
        profileRef,
        {
          achievementBadge,
          achievementUpdatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    }
    return { achievementPoints: points, achievementBadge };
  });
  return result;
});

// Public profile view: return only the public achievement summary.  This is
// separate from refreshAchievementBadge so viewing somebody else's profile
// never gets access to private profile fields and does not depend on the
// client having a freshly populated community_profiles document.
exports.getPublicAchievement = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  const targetUid = String(data?.userId || '').trim();
  if (!targetUid || targetUid.length > 128) {
    throw new functions.https.HttpsError('invalid-argument', 'Érvénytelen felhasználó.');
  }

  const profileSnapshot = await db.collection('community_profiles').doc(targetUid).get();
  if (!profileSnapshot.exists) {
    throw new functions.https.HttpsError('not-found', 'A profil nem található.');
  }
  const profile = profileSnapshot.data() || {};
  const catalog = await getAchievementBadges();
  const achievement = publicAchievementData(profile, catalog);
  await persistPublicAchievementIfNeeded(profileSnapshot.ref, profile, achievement);
  return achievement;
});

exports.getAchievementLeaderboard = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  if (!(await allowCallByIp(context, 'achievement_leaderboard', 120))) {
    throw new HttpsError('resource-exhausted', 'Túl sok kérés.');
  }
  const requestedSize = Number(data?.pageSize || 50);
  const pageSize = Number.isInteger(requestedSize) ? Math.min(100, Math.max(10, requestedSize)) : 50;
  const cursorPoints = Number(data?.cursorPoints);
  const cursorUserId = String(data?.cursorUserId || '').trim();
  const requestedOffset = Number(data?.offset || 0);
  const offset = Number.isSafeInteger(requestedOffset) && requestedOffset >= 0 ? requestedOffset : 0;
  let query = db
    .collection('public_profiles')
    .orderBy('achievementPoints', 'desc')
    .orderBy(FieldPath.documentId(), 'asc');
  if (Number.isFinite(cursorPoints) && cursorUserId) {
    query = query.startAfter(cursorPoints, cursorUserId);
  }
  const snapshot = await query.limit(pageSize + 1).get();
  const pageDocs = snapshot.docs.slice(0, pageSize);
  // A warm catalog (no extra request) repairs rows whose stored badge artwork
  // is missing. A valid stored URL is kept as-is, because replacing it would
  // force every client to download the same image again.
  const catalog = achievementCatalogIsReliable() ? achievementBadgesCache : null;
  const items = pageDocs.map((document, index) => {
    const profile = document.data() || {};
    const badge =
      profile.achievementBadge && typeof profile.achievementBadge === 'object' ? profile.achievementBadge : {};
    let badgeName = String(badge.name || '').trim();
    let badgeImageUrl = String(badge.imageUrl || badge.image_url || '').trim();
    if (!badgeImageUrl && catalog) {
      const catalogBadge = publicAchievementData(profile, catalog).achievementBadge;
      badgeImageUrl = String(catalogBadge.imageUrl || '').trim();
      if (!badgeName) badgeName = String(catalogBadge.name || '').trim();
    }
    return {
      userId: document.id,
      displayName: String(profile.displayName || '').trim(),
      points: Math.max(0, Number(profile.achievementPoints || 0)),
      badgeName: badgeName || 'Kezdő ütem',
      badgeImageUrl,
      rank: offset + index + 1,
    };
  });
  const last = pageDocs.at(-1);
  return {
    items,
    hasMore: snapshot.size > pageSize,
    nextCursor: last
      ? {
          points: Math.max(0, Number(last.data()?.achievementPoints || 0)),
          userId: last.id,
          offset: offset + pageDocs.length,
        }
      : null,
  };
});

function badgeForPoints(catalog, points) {
  return (
    catalog.filter((item) => points >= item.min_points).sort((a, b) => b.min_points - a.min_points)[0] ||
    defaultAchievementBadges[0]
  );
}

// `defaultAchievementBadges` is a display-only emergency catalog: every entry
// has an empty image URL and the only rank below 100 points is the starter
// badge. It is fine for rendering one response during a WordPress outage, but
// it must never be written back to a profile, because that demotes the stored
// rank and wipes the artwork until something else recalculates it.
function achievementCatalogIsReliable() {
  return Array.isArray(achievementBadgesCache) && achievementBadgesCache.length > 0;
}

function normalizedStoredBadge(stored) {
  if (!stored || typeof stored !== 'object') return null;
  const slug = String(stored.slug || '').trim();
  if (!slug) return null;
  return {
    slug,
    name: String(stored.name || '').trim(),
    description: String(stored.description || '').trim(),
    imageUrl: String(stored.imageUrl || stored.image_url || '').trim(),
  };
}

// Rank that may be persisted. With a reliable catalog it is derived from the
// points; during a WordPress outage the already stored badge is kept so the
// user never loses the rank and the artwork they already earned.
function persistedAchievementBadge(catalog, points, storedBadge) {
  const stored = normalizedStoredBadge(storedBadge);
  if (!achievementCatalogIsReliable()) {
    if (stored) return stored;
    const fallback = defaultAchievementBadges[0];
    return {
      slug: fallback.slug,
      name: fallback.name,
      description: fallback.description,
      imageUrl: fallback.image_url || '',
    };
  }
  const badge = badgeForPoints(catalog, points);
  return {
    slug: badge.slug,
    name: badge.name,
    description: badge.description,
    imageUrl: badge.image_url || '',
  };
}

function sameAchievementBadge(first, second) {
  const left = normalizedStoredBadge(first);
  const right = normalizedStoredBadge(second);
  if (!left || !right) return left === right;
  return (
    left.slug === right.slug &&
    left.name === right.name &&
    left.description === right.description &&
    left.imageUrl === right.imageUrl
  );
}

function publicAchievementData(profile, catalog) {
  const points = Math.max(0, Number(profile?.achievementPoints || 0));
  const badge = badgeForPoints(catalog, points);
  const stored =
    profile?.achievementBadge && typeof profile.achievementBadge === 'object' ? profile.achievementBadge : {};
  const storedImage = String(stored.imageUrl || stored.image_url || '').trim();
  return {
    achievementPoints: points,
    achievementBadge: {
      slug: badge.slug,
      name: badge.name,
      description: badge.description,
      // Keep an already stored image as a safe fallback if the WordPress
      // catalog is temporarily missing the media URL, but only for the same
      // badge. A starter image must never be attached to a higher rank.
      imageUrl: badge.image_url || (stored.slug === badge.slug ? storedImage : ''),
    },
  };
}

async function persistPublicAchievementIfNeeded(profileRef, profile, achievement) {
  const next = achievement.achievementBadge || {};
  if (!String(next.imageUrl || '').trim()) return;
  if (sameAchievementBadge(profile?.achievementBadge, next)) return;
  await profileRef.set(
    {
      achievementBadge: next,
      achievementUpdatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
}

function publicProfileData(profile, userId, achievement = null) {
  const socialLinks =
    profile.socialLinks && typeof profile.socialLinks === 'object'
      ? Object.fromEntries(
          Object.entries(profile.socialLinks)
            .filter(([key, value]) => typeof key === 'string' && typeof value === 'string')
            .map(([key, value]) => [key, String(value).trim()]),
        )
      : {};
  const numberOr = (value, fallback) => (Number.isFinite(Number(value)) ? Number(value) : fallback);
  const publicAchievement = achievement || {
    achievementPoints: Math.max(0, numberOr(profile.achievementPoints, 0)),
    achievementBadge:
      profile.achievementBadge && typeof profile.achievementBadge === 'object' ? profile.achievementBadge : {},
  };
  const achievementBadge = publicAchievement.achievementBadge || {};
  // The badge artwork may change without changing the rest of the profile.
  // Always use the newest profile/achievement timestamp for the public image
  // cache key; using `updatedAt` first could otherwise keep an old badge URL
  // forever when `achievementUpdatedAt` was newer.
  const versionCandidates = [profile.updatedAt, profile.achievementUpdatedAt].map((value) => {
    if (value?.toMillis instanceof Function) return value.toMillis();
    const numeric = Number(value);
    return Number.isFinite(numeric) ? numeric : 0;
  });
  const profileVersion = String(Math.max(...versionCandidates, 0));
  const badgeImageUrl = String(achievementBadge.imageUrl || achievementBadge.image_url || '').trim();
  const profileImageUrl =
    [
      profile.profileSourceImageUrl,
      profile.profileImageUrl,
      // Keep older profile records visible while they are migrated.
      profile.imageUrl,
      profile.photoURL,
      profile.photoUrl,
    ].find((value) => typeof value === 'string' && value.trim().length > 0) || '';
  const memberSince = profile.createdAt?.toMillis?.() || null;
  return {
    userId,
    displayName: String(profile.displayName || '').trim() || `HUHS user ${Number(profile.huhsUserNumber) || ''}`.trim(),
    role: String(profile.role || 'partygoer').trim(),
    accessRole: ['admin', 'moderator'].includes(profile.accessRole) ? profile.accessRole : 'none',
    bio: String(profile.bio || '').trim(),
    profileImageUrl: String(profileImageUrl).trim(),
    ...(Number.isFinite(memberSince) ? { memberSince } : {}),
    profileFocusX: numberOr(profile.profileFocusX, 50),
    profileFocusY: numberOr(profile.profileFocusY, 25),
    profileZoom: numberOr(profile.profileZoom, 1),
    profilePanX: numberOr(profile.profilePanX, 0),
    profilePanY: numberOr(profile.profilePanY, 0),
    // A public projection uses this value to invalidate image caches without
    // reducing image quality or exposing private profile fields.
    profileVersion,
    socialLinks,
    // Include the already materialized public achievement state so profile
    // and chat can render it with the same callable response.
    achievementPoints: Math.max(0, numberOr(publicAchievement.achievementPoints, 0)),
    achievementBadge: {
      slug: String(achievementBadge.slug || '').trim(),
      name: String(achievementBadge.name || '').trim(),
      description: String(achievementBadge.description || '').trim(),
      // Make a changed badge design a new cache key without resizing or
      // reducing the original image quality.
      imageUrl: versionBadgeImageUrl(badgeImageUrl, profileVersion),
    },
  };
}

function isUnnumberedPlaceholderDisplayName(value) {
  const normalized = String(value || '')
    .trim()
    .toLowerCase()
    .replace(/\s+/g, ' ');
  return !normalized || /^(?:hun hs|hs hu|hu hs|huhs user)$/.test(normalized);
}

async function ensureHuhsUserNumber(userId) {
  const profileRef = db.collection('community_profiles').doc(userId);
  const counterRef = db.collection('app_settings').doc('huhs_user_number_counter');
  let assignedNumber = 0;
  await db.runTransaction(async (transaction) => {
    const [profileSnapshot, counterSnapshot] = await Promise.all([
      transaction.get(profileRef),
      transaction.get(counterRef),
    ]);
    const profile = profileSnapshot.data() || {};
    if (!profileSnapshot.exists) return;
    const existing = Number(profile.huhsUserNumber || 0);
    const currentName = String(profile.displayName || '').trim();
    if (Number.isInteger(existing) && existing >= 1000 && !isUnnumberedPlaceholderDisplayName(currentName)) {
      assignedNumber = existing;
      return;
    }
    const next =
      Number.isInteger(existing) && existing >= 1000
        ? existing
        : Math.max(1000, Number(counterSnapshot.data()?.nextNumber || 1000));
    assignedNumber = next;
    transaction.set(
      profileRef,
      {
        huhsUserNumber: next,
        displayName: `HUHS user ${next}`,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    if (!(Number.isInteger(existing) && existing >= 1000)) {
      transaction.set(counterRef, { nextNumber: next + 1 }, { merge: true });
    }
  });
  return assignedNumber;
}

function requireRegisteredViewer(context) {
  const provider = context.auth?.token?.firebase?.sign_in_provider;
  if (!context.auth?.uid || provider === 'anonymous') {
    throw new functions.https.HttpsError('unauthenticated', 'Bejelentkezés szükséges.');
  }
  return String(context.auth.uid).trim();
}

function normalizeDisplayName(value) {
  return String(value || '')
    .trim()
    .replace(/\s+/g, ' ')
    .toLocaleLowerCase('hu-HU');
}

function displayNameKey(value) {
  return crypto.createHash('sha256').update(normalizeDisplayName(value)).digest('hex');
}

// Plain-text counterpart of displayNameKey.
//
// A Firestore security rule cannot compute a SHA-256 hash, so name ownership is
// also mirrored under the normalized name itself. That is the only form the
// rules can look up, and it is what stops a client from writing a profile
// document directly with a name that already belongs to another account.
function displayNameClaimRef(value) {
  return db.collection('display_name_claims').doc(normalizeDisplayName(value));
}

function validatedDisplayName(value) {
  const displayName = String(value || '')
    .trim()
    .replace(/\s+/g, ' ');
  if (displayName.length < 2 || displayName.length > 40) {
    throw new functions.https.HttpsError('invalid-argument', 'A név 2–40 karakter hosszú legyen.');
  }
  if (
    !/^[\p{L}\p{N}][\p{L}\p{N} ._'\-]*$/u.test(displayName) ||
    /(?:kurva|fasz|geci|buzi|cigány|nigger)/iu.test(displayName)
  ) {
    throw new functions.https.HttpsError('invalid-argument', 'Ez a felhasználónév nem használható.');
  }
  return displayName;
}

// This is only an early UX check. claimDisplayName remains the authoritative
// transaction because another account may reserve the name between calls.
exports.checkDisplayNameAvailability = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  if (!(await allowCallByIp(context, 'display_name_availability', 30))) {
    throw new HttpsError('resource-exhausted', 'Túl sok kérés.');
  }
  const displayName = validatedDisplayName(data?.displayName);
  const snapshot = await db.collection('display_name_index').doc(displayNameKey(displayName)).get();
  return { available: !snapshot.exists };
});

// Reserves a display name atomically so two users cannot claim the same name
// during concurrent registration or profile saves.
exports.claimDisplayName = functions.runWith({ enforceAppCheck: false }).https.onCall(async (data, context) => {
  const uid = requireRegisteredViewer(context);
  const targetUid = String(data?.targetUid || uid).trim();
  if (targetUid !== uid) {
    const callerProfile = (await db.collection('community_profiles').doc(uid).get()).data() || {};
    if (!isAdmin(context, callerProfile)) throw new functions.https.HttpsError('permission-denied', 'Csak admin módosíthat másik felhasználónevet.');
  }
  if ((await db.collection('deleted_user_ids').doc(targetUid).get()).exists) {
    throw new functions.https.HttpsError('permission-denied', 'A korábbi fiók törölve lett. Regisztrálj új fiókot.');
  }
  const displayName = validatedDisplayName(data?.displayName);
  const key = displayNameKey(displayName);
  const indexRef = db.collection('display_name_index').doc(key);
  const profileRef = db.collection('community_profiles').doc(targetUid);
  try {
    await db.runTransaction(async (transaction) => {
      const [indexSnapshot, profileSnapshot] = await Promise.all([
        transaction.get(indexRef),
        transaction.get(profileRef),
      ]);
      const ownerUid = String(indexSnapshot.data()?.uid || '').trim();
      if (ownerUid && ownerUid !== targetUid) {
        throw new functions.https.HttpsError('already-exists', 'display-name-already-in-use');
      }
      const oldName = String(profileSnapshot.data()?.displayName || '').trim();
      const oldPlaceholder = isUnnumberedPlaceholderDisplayName(oldName) || /^HUHS user \d+$/i.test(oldName);
      const isOwnerAdmin =
        targetUid !== uid || String(context.auth?.token?.email || '')
          .trim()
          .toLowerCase() === ADMIN_EMAIL;
      const currentYear = new Date().getUTCFullYear();
      const storedChangeCount = Math.max(0, Number(profileSnapshot.data()?.usernameChangeCount || 0));
      const changeYear = Number(
        profileSnapshot.data()?.usernameChangeYear || (storedChangeCount > 0 ? currentYear : 0),
      );
      const changeCount = changeYear === currentYear ? storedChangeCount : 0;
      if (
        !isOwnerAdmin &&
        oldName &&
        !oldPlaceholder &&
        normalizeDisplayName(oldName) !== normalizeDisplayName(displayName) &&
        changeCount >= 1
      ) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'A felhasználónevet évente egyszer lehet módosítani.',
        );
      }
      const oldKey = oldName ? displayNameKey(oldName) : '';
      const oldIndexSnapshot =
        oldKey && oldKey !== key ? await transaction.get(db.collection('display_name_index').doc(oldKey)) : null;
      const oldNormalized = oldName ? normalizeDisplayName(oldName) : '';
      const renamed = oldNormalized !== '' && oldNormalized !== normalizeDisplayName(displayName);
      const oldClaimRef = renamed ? displayNameClaimRef(oldName) : null;
      const oldClaimSnapshot = oldClaimRef ? await transaction.get(oldClaimRef) : null;
      transaction.set(indexRef, {
        uid: targetUid,
        displayName,
        normalizedName: normalizeDisplayName(displayName),
        updatedAt: FieldValue.serverTimestamp(),
      });
      // Mirror the reservation in the plain-text collection the security rules
      // read, so the reservation is enforced for direct client writes too.
      transaction.set(displayNameClaimRef(displayName), {
        uid: targetUid,
        displayName,
        updatedAt: FieldValue.serverTimestamp(),
      });
      if (oldIndexSnapshot && String(oldIndexSnapshot.data()?.uid || '').trim() === targetUid) {
        transaction.delete(db.collection('display_name_index').doc(oldKey));
      }
      if (oldClaimRef && String(oldClaimSnapshot?.data()?.uid || '').trim() === targetUid) {
        transaction.delete(oldClaimRef);
      }
      transaction.set(
        profileRef,
        {
          displayName,
          usernameChangeCount: isOwnerAdmin
            ? 0
            : oldName && !oldPlaceholder && normalizeDisplayName(oldName) !== normalizeDisplayName(displayName)
              ? changeCount + 1
              : changeCount,
          ...(isOwnerAdmin
            ? { usernameChangeYear: FieldValue.delete() }
            : oldName && !oldPlaceholder && normalizeDisplayName(oldName) !== normalizeDisplayName(displayName)
              ? { usernameChangeYear: currentYear }
              : {}),
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    });
  } catch (error) {
    console.error(
      JSON.stringify({
        event: 'claim_display_name_failed',
        step: 'transaction',
        errorCode: error?.code || 'unknown',
      }),
    );
    throw error;
  }
  return { displayName, uid: targetUid };
});

exports.toggleChatReaction = functions.runWith({ enforceAppCheck: false }).https.onCall(async (data, context) => {
  const uid = String(context.auth?.uid || '').trim();
  const postId = String(data?.postId || '').trim();
  const emoji = String(data?.emoji || '').trim();
  const allowedReactions = new Set(['❤️', '🔥', '🙌']);
  if (!uid) throw new HttpsError('unauthenticated', 'Bejelentkezés szükséges.');
  if (!/^[a-zA-Z0-9_-]{1,128}$/.test(postId) || !allowedReactions.has(emoji)) {
    throw new HttpsError('invalid-argument', 'Érvénytelen reakció.');
  }
  if (!(await allowCall(uid, 'chat_reaction', 60))) {
    throw new HttpsError('resource-exhausted', 'Túl sok reakció, próbáld később.');
  }
  const postRef = db.collection('live_feed_posts').doc(postId);
  let selected = '';
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(postRef);
    if (!snapshot.exists) throw new HttpsError('not-found', 'A bejegyzés nem található.');
    const current = snapshot.data() || {};
    const source = current.reactionBy && typeof current.reactionBy === 'object' ? current.reactionBy : {};
    const reactionBy = {};
    for (const [userId, value] of Object.entries(source)) {
      if (typeof userId === 'string' && userId.length <= 128 && allowedReactions.has(value)) {
        reactionBy[userId] = value;
      }
    }
    if (reactionBy[uid] === emoji) delete reactionBy[uid];
    else reactionBy[uid] = emoji;
    selected = reactionBy[uid] || '';
    const reactions = {};
    for (const value of Object.values(reactionBy)) reactions[value] = Number(reactions[value] || 0) + 1;
    transaction.update(postRef, { reactions, reactionBy });
  });
  return { selected };
});

exports.publishChatPost = functions.runWith({ enforceAppCheck: false }).https.onCall(async (data, context) => {
  const uid = String(context.auth?.uid || '').trim();
  if (!uid) throw new HttpsError('unauthenticated', 'Bejelentkezés szükséges.');
  if (!(await allowCall(uid, 'chat_post', 20))) {
    throw new HttpsError('resource-exhausted', 'Túl sok üzenet, próbáld később.');
  }
  if ((await db.collection('community_bans').doc(uid).get()).exists) {
    throw new HttpsError('permission-denied', 'Jelenleg nem írhatsz a Chatbe.');
  }
  const text = typeof data?.text === 'string' ? data.text.trim() : '';
  const imageUrl = typeof data?.imageUrl === 'string' ? data.imageUrl.trim() : '';
  const replyToText = typeof data?.replyToText === 'string' ? data.replyToText.trim().slice(0, 200) : '';
  const replyToName = typeof data?.replyToName === 'string' ? data.replyToName.trim().slice(0, 80) : '';
  const imagePublicId = typeof data?.imagePublicId === 'string' ? data.imagePublicId.trim() : '';
  const isAnonymous = context.auth.token.firebase?.sign_in_provider === 'anonymous';
  if ((!text && !imageUrl) || text.length > 2000) {
    throw new HttpsError('invalid-argument', 'Az üzenet nem lehet üres vagy túl hosszú.');
  }
  if (isAnonymous && imageUrl) {
    throw new HttpsError('permission-denied', 'Névtelen felhasználó nem tölthet fel képet.');
  }
  if (imageUrl && !/^https:\/\/res\.cloudinary\.com\/fjxo93em\/image\/upload\/.+/.test(imageUrl)) {
    throw new HttpsError('invalid-argument', 'Érvénytelen képforrás.');
  }
  if (imagePublicId && !imagePublicId.startsWith(`huhs_users/${uid}/`)) {
    throw new HttpsError('invalid-argument', 'Érvénytelen képazonosító.');
  }
  const profile = (await db.collection('community_profiles').doc(uid).get()).data() || {};
  const admin = isAdmin(context, profile);
  const displayName = isAnonymous
    ? `Unknown User ${uid.slice(-4)}`
    : String(profile.displayName || `HUHS user ${profile.huhsUserNumber || ''}`).trim() || 'HUHS user';
  const role = isAnonymous ? '' : normalizedAccountRole(profile.role);
  const accessRole = isAnonymous ? '' : normalizedAccessRole(profile.accessRole);
  const profileImage = String(profile.profileImageUrl || profile.profileSourceImageUrl || '').trim();
  const authorImageUrl = /^https:\/\/res\.cloudinary\.com\/fjxo93em\/image\/upload\/.+/.test(profileImage)
    ? profileImage
    : '';
  const ref = db.collection('live_feed_posts').doc();
  await ref.set({
    authorId: uid,
    authorName: displayName,
    authorImageUrl: isAnonymous ? '' : authorImageUrl,
    authorRole: role,
    authorAccessRole: accessRole,
    isAnonymous,
    text,
    ...(replyToText ? { replyToText } : {}),
    ...(replyToText && replyToName ? { replyToName } : {}),
    imageUrl,
    ...(imagePublicId ? { imagePublicId } : {}),
    reactions: {},
    reactionBy: {},
    pinned: admin && data?.pinned === true,
    createdAt: FieldValue.serverTimestamp(),
  });
  return { id: ref.id };
});

exports.manageConnection = functions.runWith({ enforceAppCheck: false }).https.onCall(async (data, context) => {
  const uid = requireRegisteredViewer(context);
  const action = String(data?.action || '').trim();
  const otherUid = String(data?.otherUid || '').trim();
  if (!['request', 'respond', 'remove', 'prune'].includes(action)) {
    throw new HttpsError('invalid-argument', 'Érvénytelen ismerős-művelet.');
  }
  if (action !== 'prune' && (!otherUid || otherUid === uid || otherUid.length > 128)) {
    throw new HttpsError('invalid-argument', 'Érvénytelen felhasználó.');
  }
  if (!(await allowCall(uid, `connection_${action}`, action === 'prune' ? 5 : 30))) {
    throw new HttpsError('resource-exhausted', 'Túl sok ismerős-művelet, próbáld később.');
  }

  if (action === 'prune') {
    const connections = await db.collection('community_profiles').doc(uid).collection('connections').get();
    const stale = [];
    for (const connection of connections.docs) {
      if (!(await db.collection('community_profiles').doc(connection.id).get()).exists) stale.push(connection.ref);
    }
    for (let offset = 0; offset < stale.length; offset += 400) {
      const batch = db.batch();
      stale.slice(offset, offset + 400).forEach((reference) => batch.delete(reference));
      await batch.commit();
    }
    return { removed: stale.length };
  }

  const ownConnection = db.collection('community_profiles').doc(uid).collection('connections').doc(otherUid);
  const otherConnection = db.collection('community_profiles').doc(otherUid).collection('connections').doc(uid);
  const outgoingRequest = db.collection('connection_requests').doc(`${uid}_${otherUid}`);
  const incomingRequest = db.collection('connection_requests').doc(`${otherUid}_${uid}`);

  if (action === 'remove') {
    const batch = db.batch();
    batch.delete(ownConnection);
    batch.delete(otherConnection);
    batch.delete(outgoingRequest);
    batch.delete(incomingRequest);
    await batch.commit();
    return { status: 'removed' };
  }

  if (action === 'request') {
    const [target, own, reverse, blockedByMe, blockedByOther] = await Promise.all([
      db.collection('community_profiles').doc(otherUid).get(),
      ownConnection.get(),
      otherConnection.get(),
      db.collection('community_profiles').doc(uid).collection('blocked_users').doc(otherUid).get(),
      db.collection('community_profiles').doc(otherUid).collection('blocked_users').doc(uid).get(),
    ]);
    if (!target.exists) throw new HttpsError('not-found', 'A felhasználó nem található.');
    if (blockedByMe.exists || blockedByOther.exists)
      throw new HttpsError('permission-denied', 'Az ismerős-jelölés nem elérhető.');
    if (own.exists || reverse.exists) return { status: 'accepted' };
    const existing = await outgoingRequest.get();
    if (existing.data()?.status === 'pending') {
      await outgoingRequest.update({
        notificationRequestedAt: FieldValue.serverTimestamp(),
      });
      return { status: 'pending' };
    }
    const profile = (await db.collection('community_profiles').doc(uid).get()).data() || {};
    await outgoingRequest.set({
      from: uid,
      to: otherUid,
      fromName: String(profile.displayName || context.auth.token.name || 'Felhasználó').trim(),
      fromImageUrl: String(profile.profileImageUrl || '').trim(),
      status: 'pending',
      createdAt: FieldValue.serverTimestamp(),
      notificationRequestedAt: FieldValue.serverTimestamp(),
    });
    return { status: 'pending' };
  }

  const accept = data?.accept === true;
  const request = await incomingRequest.get();
  const requestData = request.data() || {};
  if (!request.exists || requestData.from !== otherUid || requestData.to !== uid || requestData.status !== 'pending') {
    throw new HttpsError('failed-precondition', 'Az ismerős-kérés már nem érhető el.');
  }
  const batch = db.batch();
  batch.update(incomingRequest, {
    status: accept ? 'accepted' : 'rejected',
    updatedAt: FieldValue.serverTimestamp(),
  });
  if (accept) {
    const targetProfile = (await db.collection('community_profiles').doc(uid).get()).data() || {};
    batch.set(ownConnection, {
      userId: otherUid,
      displayName: String(requestData.fromName || ''),
      imageUrl: String(requestData.fromImageUrl || ''),
      createdAt: FieldValue.serverTimestamp(),
    });
    batch.set(otherConnection, {
      userId: uid,
      displayName: String(targetProfile.displayName || context.auth.token.name || ''),
      imageUrl: String(targetProfile.profileImageUrl || ''),
      createdAt: FieldValue.serverTimestamp(),
    });
  }
  await batch.commit();
  return { status: accept ? 'accepted' : 'rejected' };
});

// Public profile fields are deliberately projected server-side.  Do not
// return the source community_profiles document: it contains private email
// and push-token data needed by account and notification code.
exports.getPublicProfile = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  const targetUid = String(data?.userId || '').trim();
  if (!targetUid || targetUid.length > 128) {
    throw new functions.https.HttpsError('invalid-argument', 'Érvénytelen felhasználó.');
  }
  const snapshot = await db.collection('community_profiles').doc(targetUid).get();
  if (!snapshot.exists) {
    throw new functions.https.HttpsError('not-found', 'A profil nem található.');
  }
  let profile = snapshot.data() || {};
  if (isUnnumberedPlaceholderDisplayName(profile.displayName)) {
    profile = {
      ...profile,
      huhsUserNumber: await ensureHuhsUserNumber(targetUid),
    };
  }
  // This is the fallback when the realtime public projection has not arrived
  // yet. Keep it Firebase-only: waiting for the WordPress badge catalog here
  // made opening a profile or a private message needlessly slow.
  //
  // The catalog is used only when this instance already loaded it (a warm
  // 30-second cache, no extra request). That repairs a stored badge that was
  // written while WordPress was unreachable, instead of keeping an image-less
  // starter rank on the profile until the next recalculation.
  const catalog = achievementCatalogIsReliable() ? achievementBadgesCache : null;
  const achievement = catalog ? publicAchievementData(profile, catalog) : null;
  const result = publicProfileData(profile, targetUid, achievement);
  if (achievement) await persistPublicAchievementIfNeeded(snapshot.ref, profile, achievement);
  await persistPublicProfileProjection(targetUid, result);
  return result;
});

async function persistPublicProfileProjection(userId, data) {
  if (!userId || !data || typeof data !== 'object') return;
  await db.collection('public_profiles').doc(userId).set(data, { merge: true });
}

async function commitReferenceUpdates(references, data) {
  for (let offset = 0; offset < references.length; offset += 400) {
    const batch = db.batch();
    references.slice(offset, offset + 400).forEach((reference) => batch.set(reference, data, { merge: true }));
    await batch.commit();
  }
}

async function syncDenormalizedProfileReferences(userId, publicData) {
  const displayName = String(publicData.displayName || '').trim();
  const imageUrl = String(publicData.profileImageUrl || '').trim();
  const [posts, meetups, ownConnections, conversations, comments] = await Promise.all([
    db.collection('live_feed_posts').where('authorId', '==', userId).get(),
    db.collectionGroup('users').where('userId', '==', userId).get(),
    db.collection('community_profiles').doc(userId).collection('connections').get(),
    db.collection('private_conversations').where('participantIds', 'array-contains', userId).get(),
    db.collectionGroup('comments').where('authorId', '==', userId).get(),
  ]);
  await Promise.all([
    commitReferenceUpdates(
      posts.docs.map((doc) => doc.ref),
      { authorName: displayName, authorImageUrl: imageUrl },
    ),
    commitReferenceUpdates(
      meetups.docs.filter((doc) => doc.ref.path.startsWith('event_meetups/')).map((doc) => doc.ref),
      { displayName, imageUrl },
    ),
    commitReferenceUpdates(
      ownConnections.docs.map((doc) =>
        db.collection('community_profiles').doc(doc.id).collection('connections').doc(userId),
      ),
      {
        displayName,
        imageUrl,
      },
    ),
    commitReferenceUpdates(
      comments.docs.filter((doc) => doc.ref.path.startsWith('article_comments/')).map((doc) => doc.ref),
      { authorName: displayName, imageUrl },
    ),
  ]);
  for (const conversation of conversations.docs) {
    const value = conversation.data() || {};
    await conversation.ref.set(
      {
        participantNames: {
          ...(value.participantNames || {}),
          [userId]: displayName,
        },
        participantImages: {
          ...(value.participantImages || {}),
          [userId]: imageUrl,
        },
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  }
}

// Keep a public-only, realtime-friendly projection in Firestore. Chat and
// profile surfaces can read this document directly without touching the
// WordPress API or the private community_profiles document.
exports.syncPublicProfileProjection = onDocumentWritten(
  {
    document: 'community_profiles/{userId}',
    database: 'hungarian-hardstyle',
    region: 'europe-central2',
  },
  async (event) => {
    const after = event.data?.after;
    const uid = String(event.params.userId || '').trim();
    if (!uid) return null;
    if ((await db.collection('deleted_user_ids').doc(uid).get()).exists) {
      if (after?.exists) await db.recursiveDelete(after.ref);
      await db.collection('public_profiles').doc(uid).delete();
      return null;
    }
    if (!after?.exists) {
      await db.collection('public_profiles').doc(uid).delete();
      return null;
    }
    const profile = after.data() || {};
    if (isUnnumberedPlaceholderDisplayName(profile.displayName)) {
      await ensureHuhsUserNumber(uid);
      return null;
    }
    const publicData = publicProfileData(profile, uid);
    await persistPublicProfileProjection(uid, publicData);
    const before = event.data?.before?.data() || {};
    const beforePublic = publicProfileData(before, uid);
    if (
      beforePublic.displayName !== publicData.displayName ||
      beforePublic.profileImageUrl !== publicData.profileImageUrl
    ) {
      await syncDenormalizedProfileReferences(uid, publicData);
    }
    return null;
  },
);

exports.repairCommunityProfileProjections = onSchedule(
  {
    schedule: 'every day 03:00',
    timeZone: 'Europe/Budapest',
    region: 'europe-central2',
  },
  async () => {
    // Recalculate the badge from the real WordPress catalog, so a rank that was
    // stamped from the image-less emergency catalog during an outage is
    // repaired for everybody, not only for the profiles that were opened.
    const catalog = await getAchievementBadges();
    const catalogReliable = achievementCatalogIsReliable();
    const snapshot = await db.collection('community_profiles').get();
    let repaired = 0;
    let badgesRepaired = 0;
    let claimsBackfilled = 0;
    const claimConflicts = [];
    for (const document of snapshot.docs) {
      const profile = document.data() || {};
      if (isUnnumberedPlaceholderDisplayName(profile.displayName)) {
        await ensureHuhsUserNumber(document.id);
        repaired++;
        continue;
      }
      // Backfill the plain-text name reservation the security rules read. Names
      // claimed before display_name_claims existed, and names chosen by clients
      // that only mirror the reservation, are protected from the next run on.
      const reservedName = String(profile.displayName || '').trim();
      if (reservedName) {
        const claimRef = displayNameClaimRef(reservedName);
        const claim = await claimRef.get();
        const claimOwner = String(claim.data()?.uid || '').trim();
        if (!claimOwner) {
          await claimRef.set(
            {
              uid: document.id,
              displayName: reservedName,
              updatedAt: FieldValue.serverTimestamp(),
            },
            { merge: true },
          );
          claimsBackfilled++;
        } else if (claimOwner !== document.id) {
          // Two profiles normalize to the same name. The existing owner keeps
          // the reservation; the duplicate is reported for a manual review
          // instead of being renamed automatically.
          claimConflicts.push({
            name: normalizeDisplayName(reservedName),
            kept: claimOwner,
            duplicate: document.id,
          });
        }
      }
      const achievement = catalogReliable ? publicAchievementData(profile, catalog) : null;
      if (achievement && !sameAchievementBadge(profile.achievementBadge, achievement.achievementBadge)) {
        await document.ref.set(
          {
            achievementBadge: achievement.achievementBadge,
            achievementUpdatedAt: FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
        badgesRepaired++;
      }
      const publicData = publicProfileData(profile, document.id, achievement);
      await persistPublicProfileProjection(document.id, publicData);
      await syncDenormalizedProfileReferences(document.id, publicData);
    }
    console.info('community_profile_projection_repair', {
      profiles: snapshot.size,
      repaired,
      badgesRepaired,
      claimsBackfilled,
      claimConflicts: claimConflicts.length,
    });
    if (claimConflicts.length > 0) {
      console.warn('community_profile_display_name_conflicts', claimConflicts);
    }
  },
);

exports.getPublicProfiles = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  requireRegisteredViewer(context);
  // The callable is used by the private-message user picker. Read the
  // already-denormalized public projection instead of downloading every
  // private profile (including email and moderation fields) and recalculating
  // badges one document at a time.
  const snapshot = await db
    .collection('public_profiles')
    .select('displayName', 'profileImageUrl', 'profileFocusX', 'profileFocusY', 'profileZoom', 'profilePanX', 'profilePanY', 'profileVersion', 'achievementPoints', 'achievementBadge')
    .get();
  const profiles = snapshot.docs
    .map((doc) => ({ ...doc.data(), userId: doc.id }))
    .filter((profile) => !isUnnumberedPlaceholderDisplayName(profile.displayName));
  return {
    profiles,
  };
});

function boolMap(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return {};
  return Object.fromEntries(Object.entries(value).filter(([, active]) => active === true));
}

exports.awardAchievementFromAttendance = onDocumentWritten(
  {
    document: 'event_attendance/{eventId}/users/{userId}',
    database: 'hungarian-hardstyle',
    region: 'europe-central2',
  },
  async (event) => {
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
    console.log(JSON.stringify({ event: 'achievement_attendance', eventId, result }));
    return result;
  },
);

exports.awardAchievementFromMeetup = onDocumentWritten(
  {
    document: 'event_meetups/{eventId}/users/{userId}',
    database: 'hungarian-hardstyle',
    region: 'europe-central2',
  },
  async (event) => {
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
    if (!beforeExists && event.data?.after?.exists)
      results.push(await awardAchievementPoints(uid, 5, `meetup:${eventId}`));
    if (beforeExists && !event.data?.after?.exists)
      results.push(await awardAchievementPoints(uid, -5, `meetup:${eventId}`));
    const beforeInterested = boolMap(event.data?.before?.data()?.interestedBy);
    const afterInterested = boolMap(after.interestedBy);
    for (const interestedUid of Object.keys(afterInterested)) {
      if (!beforeInterested[interestedUid]) {
        results.push(
          await awardAchievementPoints(interestedUid, 15, `meetup-interest:${eventId}:${uid}:${interestedUid}`),
        );
      }
    }
    for (const interestedUid of Object.keys(beforeInterested)) {
      if (!afterInterested[interestedUid]) {
        results.push(
          await awardAchievementPoints(interestedUid, -15, `meetup-interest:${eventId}:${uid}:${interestedUid}`),
        );
      }
    }
    return results;
  },
);

exports.awardAchievementFromNewsReaction = onDocumentWritten(
  {
    document: 'news_reactions/{postId}',
    database: 'hungarian-hardstyle',
    region: 'europe-central2',
  },
  async (event) => {
    const before = boolMap(event.data?.before?.data()?.likedBy);
    const after = boolMap(event.data?.after?.data()?.likedBy);
    const postId = String(event.params.postId || '').trim();
    const results = [];
    for (const uid of Object.keys(after))
      if (!before[uid]) results.push(await awardAchievementPoints(uid, 2, `news-like:${postId}`));
    for (const uid of Object.keys(before))
      if (!after[uid]) results.push(await awardAchievementPoints(uid, -2, `news-like:${postId}`));
    return results;
  },
);

exports.rateEvent = functions.runWith({ enforceAppCheck: false }).https.onCall(async (data, context) => {
  const uid = context.auth?.uid;
  if (!uid || context.auth.token.firebase.sign_in_provider === 'anonymous') {
    throw new HttpsError('unauthenticated', 'Bejelentkezés szükséges.');
  }
  const eventId = Number(data?.eventId);
  const score = Number(data?.score);
  if (!Number.isInteger(eventId) || eventId < 1 || !Number.isInteger(score) || score < 1 || score > 5) {
    throw new HttpsError('invalid-argument', 'Érvényes esemény és 1–5 közötti értékelés szükséges.');
  }
  const validEvents = await getValidEventIds();
  if (!validEvents || validEvents.has(eventId)) {
    throw new HttpsError('failed-precondition', 'Az esemény még nem értékelhető.');
  }
  const attendance = await db.collection('event_attendance').doc(String(eventId)).collection('users').doc(uid).get();
  if (attendance.data()?.state !== 'attending') {
    throw new HttpsError('failed-precondition', 'Csak a részvételüket jelző felhasználók értékelhetik az eseményt.');
  }
  const ref = db.collection('event_ratings').doc(String(eventId)).collection('users').doc(uid);
  const existing = await ref.get();
  if (existing.exists) {
    throw new HttpsError('already-exists', 'Ezt az eseményt már értékelted.');
  }
  await ref.create({
    eventId,
    userId: uid,
    score,
    createdAt: FieldValue.serverTimestamp(),
  });
  return { saved: true, score };
});

exports.setEventAttendance = functions.runWith({ enforceAppCheck: false }).https.onCall(async (data, context) => {
  const uid = context.auth?.uid;
  if (!uid || context.auth.token.firebase.sign_in_provider === 'anonymous') {
    throw new HttpsError('unauthenticated', 'Bejelentkezés szükséges.');
  }
  const eventId = Number(data?.eventId);
  const state = String(data?.state || '').trim();
  const title = String(data?.title || '')
    .trim()
    .slice(0, 300);
  if (!Number.isInteger(eventId) || eventId < 1 || !['attending', 'not_attending'].includes(state)) {
    throw new HttpsError('invalid-argument', 'Érvényes esemény és részvételi állapot szükséges.');
  }
  const validEvents = await getValidEventIds();
  if (!validEvents || !validEvents.has(eventId)) {
    throw new HttpsError('failed-precondition', 'Lejárt eseményen már nem módosítható a részvétel.');
  }
  const attendanceRef = db.collection('event_attendance').doc(String(eventId)).collection('users').doc(uid);
  const plannedRef = db.collection('community_profiles').doc(uid).collection('planned_events').doc(String(eventId));
  const attendanceData = {
    eventId,
    state,
    updatedAt: FieldValue.serverTimestamp(),
  };
  await db.runTransaction(async (transaction) => {
    transaction.set(attendanceRef, attendanceData, { merge: true });
    if (state === 'attending') {
      transaction.set(
        plannedRef,
        {
          eventId,
          ...(title ? { title } : {}),
          state,
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    } else {
      transaction.delete(plannedRef);
    }
  });
  return { saved: true, state };
});

exports.awardAchievementFromEventRating = onDocumentWritten(
  {
    document: 'event_ratings/{eventId}/users/{userId}',
    database: 'hungarian-hardstyle',
    region: 'europe-central2',
  },
  async (event) => {
    if (event.data?.before?.exists || !event.data?.after?.exists) return null;
    const eventId = String(event.params.eventId || '').trim();
    const uid = String(event.params.userId || '').trim();
    return awardAchievementPoints(uid, 10, `event-rating:${eventId}`);
  },
);

exports.togglePrivateMessageReaction = functions
  .runWith({ enforceAppCheck: false })
  .https.onCall(async (data, context) => {
    const uid = context.auth?.uid;
    if (!uid || context.auth.token.firebase.sign_in_provider === 'anonymous') {
      throw new HttpsError('unauthenticated', 'Bejelentkezés szükséges.');
    }
    const conversationId = String(data?.conversationId || '').trim();
    const messageId = String(data?.messageId || '').trim();
    if (!conversationId || !messageId) throw new HttpsError('invalid-argument', 'Érvényes üzenet szükséges.');
    const conversationRef = db.collection('private_conversations').doc(conversationId);
    const messageRef = conversationRef.collection('messages').doc(messageId);
    let liked = false;
    await db.runTransaction(async (transaction) => {
      const conversation = await transaction.get(conversationRef);
      const message = await transaction.get(messageRef);
      const participants = conversation.data()?.participantIds || [];
      if (!conversation.exists || !message.exists || !participants.includes(uid)) {
        throw new HttpsError('permission-denied', 'Az üzenet nem érhető el.');
      }
      const reactionBy = { ...(message.data()?.reactionBy || {}) };
      const reactions = { ...(message.data()?.reactions || {}) };
      liked = reactionBy[uid] === '❤️';
      if (liked) {
        delete reactionBy[uid];
        reactions['❤️'] = Math.max(0, Number(reactions['❤️'] || 1) - 1);
      } else {
        reactionBy[uid] = '❤️';
        reactions['❤️'] = Number(reactions['❤️'] || 0) + 1;
      }
      transaction.update(messageRef, { reactions, reactionBy });
    });
    return { liked: !liked };
  });

exports.awardAchievementFromProfile = onDocumentWritten(
  {
    document: 'community_profiles/{userId}',
    database: 'hungarian-hardstyle',
    region: 'europe-central2',
  },
  async (event) => {
    if (!event.data?.after?.exists) return null;
    const profile = event.data.after.data() || {};
    const uid = String(event.params.userId || '').trim();
    if (!uid) return null;
    const profileEmail = String(profile.email || '')
      .trim()
      .toLowerCase();
    let authEmail = '';
    try {
      authEmail = String((await auth.getUser(uid)).email || '')
        .trim()
        .toLowerCase();
    } catch (error) {
      console.warn(
        JSON.stringify({
          event: 'profile_achievement_auth_lookup_failed',
          message: error?.message || String(error),
        }),
      );
      return null;
    }
    const complete =
      String(profile.displayName || '').trim() &&
      String(profile.bio || '').trim() &&
      profileEmail &&
      authEmail &&
      profileEmail === authEmail;
    if (!complete) return null;
    return awardAchievementPoints(uid, 30, 'profile-complete');
  },
);

// Backfill the one-time profile-completion reward for profiles created before
// the trigger existed. The ledger key makes repeated app starts harmless.
exports.claimProfileCompletionAchievement = functions
  .runWith({ enforceAppCheck: false })
  .https.onCall(async (data, context) => {
    const uid = requireRegisteredViewer(context);
    const profile = (await db.collection('community_profiles').doc(uid).get()).data() || {};
    const profileEmail = String(profile.email || '')
      .trim()
      .toLowerCase();
    let authEmail = '';
    try {
      authEmail = String((await auth.getUser(uid)).email || '')
        .trim()
        .toLowerCase();
    } catch (_) {
      throw new HttpsError('failed-precondition', 'A profil ellenőrzése nem sikerült.');
    }
    const complete =
      String(profile.displayName || '').trim() &&
      String(profile.bio || '').trim() &&
      profileEmail &&
      authEmail &&
      profileEmail === authEmail;
    if (!complete) return { awarded: false };
    const result = await awardAchievementPoints(uid, 30, 'profile-complete');
    return { awarded: result.changed === true, points: 30 };
  });

function securityLog(event, context) {
  const uid = context?.auth?.uid;
  // One-way hash keeps the audit trail attributable without logging the raw
  // UID, preserving the anonymization guarantee for deleted users.
  const uidHash = uid
    ? crypto.createHash('sha256').update(`huhs-security:${uid}`).digest('hex').slice(0, 16)
    : undefined;
  console.warn(JSON.stringify({ event, uidHash, result: 'recorded' }));
}

exports.toggleNewsReaction = functions.runWith({ enforceAppCheck: false }).https.onCall(async (data, context) => {
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
      priority: 'high',
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
  return [
    ...new Set(
      values
        .flatMap((raw) =>
          Array.isArray(raw)
            ? raw
            : raw && typeof raw === 'object'
              ? Object.values(raw)
              : typeof raw === 'string'
                ? [raw]
                : [],
        )
        .filter((token) => typeof token === 'string' && token.trim())
        .map((token) => token.trim()),
    ),
  ];
}

async function sendAchievementPushBestEffort(uid, title, body) {
  try {
    const privateData = (await db.collection('private_user_data').doc(uid).get()).data() || {};
    const preferences = privateData.notificationPreferences || {};
    if (preferences.enabled === false || preferences.achievements === false) return;
    const tokens = await getPushTokens(uid);
    if (!tokens.length) return;
    await sendMulticastToAllTokens(
      {
        notification: { title, body },
        data: { type: 'achievement_points', targetId: uid },
      },
      tokens,
    );
  } catch (error) {
    console.warn(
      JSON.stringify({
        event: 'achievement_push_failed',
        message: error?.message || String(error),
      }),
    );
  }
}

// Backend-only durable inbox entries. The hash makes retries idempotent.
async function createNotification({ recipientUid, type, title, body, targetType, targetId, dedupeKey, senderId }) {
  const recipient = String(recipientUid || '').trim();
  const key = String(dedupeKey || '').trim();
  if (!recipient || !key) return false;
  const notificationId = crypto.createHash('sha256').update(key).digest('hex');
  try {
    await db
      .collection('notifications')
      .doc(notificationId)
      .create({
        recipientUid: recipient,
        type: String(type || 'general').trim(),
        title: String(title || '')
          .trim()
          .slice(0, 120),
        body: String(body || '')
          .trim()
          .slice(0, 500),
        targetType: String(targetType || '').trim(),
        targetId: String(targetId || '').trim(),
        senderId: String(senderId || '')
          .trim()
          .slice(0, 128),
        createdAt: FieldValue.serverTimestamp(),
        readAt: null,
      });
    return true;
  } catch (error) {
    if (error?.code === 6 || error?.code === 'already-exists') return false;
    throw error;
  }
}

async function createNotificationBestEffort(payload) {
  try {
    return await createNotification(payload);
  } catch (error) {
    console.warn(
      JSON.stringify({
        event: 'notification_write_failed',
        type: payload?.type || 'unknown',
        recipientUid: String(payload?.recipientUid || '').slice(0, 8),
        message: error?.message || String(error),
      }),
    );
    return false;
  }
}

async function notifyUsersToRateCompletedEvents() {
  const response = await fetch(`${WORDPRESS_BASE_URL}/events?include_past=true`, {
    headers: { Accept: 'application/json' },
  });
  if (!response.ok) throw new Error(`WordPress eseménylista: HTTP ${response.status}`);
  const body = await response.json();
  const events = Array.isArray(body) ? body : Array.isArray(body?.items) ? body.items : [];
  const now = Date.now();
  let created = 0;
  let pushed = 0;

  for (const item of events) {
    const eventId = Number(item?.id);
    const expiry = eventExpiryTimestamp(item);
    if (!Number.isInteger(eventId) || !Number.isFinite(expiry) || expiry >= now) continue;
    const eventTitle = String(item?.title?.rendered || item?.title || item?.name || 'Az esemény').trim();
    const attendance = await db.collection('event_attendance').doc(String(eventId)).collection('users').get();
    for (const attendanceDoc of attendance.docs) {
      if (attendanceDoc.data()?.state !== 'attending') continue;
      const uid = attendanceDoc.id;
      const rating = await db.collection('event_ratings').doc(String(eventId)).collection('users').doc(uid).get();
      if (rating.exists) continue;
      const dedupeKey = `event-rating-request:${eventId}:${uid}`;
      const notificationCreated = await createNotificationBestEffort({
        recipientUid: uid,
        type: 'event_rating_request',
        title: 'Értékeld az eseményt',
        body: `${eventTitle} véget ért. Értékeld az eseményt az appban.`,
        targetType: 'event',
        targetId: String(eventId),
        dedupeKey,
      });
      if (!notificationCreated) continue;
      created += 1;
      const tokens = await getPushTokens(uid);
      if (!tokens.length) continue;
      const result = await sendMulticastToAllTokens(
        {
          notification: {
            title: 'Értékeld az eseményt',
            body: `${eventTitle} véget ért. Értékeld az eseményt az appban.`,
          },
          data: { type: 'event_rating_request', eventId: String(eventId) },
        },
        tokens,
      );
      pushed += result.successCount;
    }
  }
  return { created, pushed };
}

exports.notifyUsersToRateCompletedEvents = onSchedule(
  {
    schedule: 'every 5 minutes',
    timeZone: 'Europe/Budapest',
    region: 'europe-central2',
  },
  async () => {
    try {
      const result = await notifyUsersToRateCompletedEvents();
      console.info('event_rating_notifications', result);
    } catch (error) {
      console.warn(
        JSON.stringify({
          event: 'event_rating_notifications_failed',
          message: error?.message || String(error),
        }),
      );
    }
  },
);

// WordPress content is managed outside Firestore, so there is no Firestore
// create trigger to generate inbox entries. Poll only the public lightweight
// lists and keep a server-side cursor; the first run establishes a baseline
// and later runs notify only about newly published IDs.
async function pollWordPressContentNotifications() {
  const endpoints = [
    {
      key: 'news',
      path: '/posts',
      targetType: 'news',
      type: 'new_news',
      title: 'Új hír érkezett',
    },
    {
      key: 'release',
      path: '/releases',
      targetType: 'release',
      type: 'new_release',
      title: 'Új release érkezett',
    },
    {
      key: 'artist',
      path: '/artists?per_page=50',
      targetType: 'artist',
      type: 'new_artist',
      title: 'Új DJ került fel',
    },
    {
      key: 'organizer',
      path: '/organizers?per_page=50',
      targetType: 'organizer',
      type: 'new_organizer',
      title: 'Új szervező került fel',
    },
    {
      key: 'event',
      path: '/events',
      targetType: 'event',
      type: 'new_event',
      title: 'Új esemény érkezett',
    },
  ];
  const stateRef = db.collection('app_settings').doc('wordpress_content_notifications');
  const stateSnapshot = await stateRef.get();
  const previous = stateSnapshot.data()?.ids || {};
  const previousRevisions = stateSnapshot.data()?.revisions || {};
  // A revision-terkep bevezetese elott keszult allapotnal meg nem tudjuk
  // megallapitani, mi valtozott, ezert az elso futas csak feltolti (nincs
  // ertesites-vihar a mar meglevo tartalmakra).
  const hasRevisions = Object.keys(previousRevisions).length > 0;
  const current = {};
  const currentRevisions = {};
  const newlyPublished = [];

  for (const endpoint of endpoints) {
    const response = await fetch(`${WORDPRESS_BASE_URL}${endpoint.path}`, {
      headers: { Accept: 'application/json' },
    });
    if (!response.ok) throw new Error(`WordPress ${endpoint.key} lista: HTTP ${response.status}`);
    const body = await response.json();
    const items = Array.isArray(body) ? body : Array.isArray(body?.items) ? body.items : [];
    const ids = items
      .map((item) => String(item?.id || '').trim())
      .filter(Boolean)
      .slice(0, 100);
    current[endpoint.key] = ids;

    // A publikalasi datum a "revision": csak ujra kozzetetelkor valtozik,
    // egyszeru szerkeszteskor nem. Ez azert fontos, mert a push is a
    // kozzetetelhez kotodik (a WordPress plugin küldi), igy a ket rendszer
    // ugyanakkor sul el — korabban a vazlatba tett, majd ujra kozzetett cikk
    // push-t kapott, de az app ertesiteslistajaba nem kerult be.
    const revisions = {};
    for (const item of items) {
      const id = String(item?.id || '').trim();
      if (!id) continue;
      const revision = String(item?.date || item?.date_gmt || '').trim();
      if (revision) revisions[id] = revision;
    }
    currentRevisions[endpoint.key] = revisions;

    if (!stateSnapshot.exists) continue;
    const oldIds = new Set(Array.isArray(previous[endpoint.key]) ? previous[endpoint.key] : []);
    const oldRevisions = previousRevisions[endpoint.key] || {};
    for (const item of items) {
      const id = String(item?.id || '').trim();
      if (!id) continue;
      const revision = revisions[id] || '';
      if (!oldIds.has(id)) {
        newlyPublished.push({ ...endpoint, id, item, revision });
        continue;
      }
      if (hasRevisions && revision && oldRevisions[id] && revision !== oldRevisions[id]) {
        newlyPublished.push({ ...endpoint, id, item, revision });
      }
    }
  }

  await stateRef.set(
    { ids: current, revisions: currentRevisions, updatedAt: FieldValue.serverTimestamp() },
    { merge: true },
  );
  if (!newlyPublished.length) return { baseline: !stateSnapshot.exists, created: 0 };

  // The fan-out only needs each profile's document id, so select just that
  // instead of reading every profile field (including private data) into memory.
  const profiles = await db.collection('community_profiles').select(FieldPath.documentId()).get();
  let created = 0;
  for (const item of newlyPublished) {
    const name = String(item.item?.title?.rendered || item.item?.title || item.item?.name || '').trim();
    await Promise.all(
      profiles.docs.map(async (profile) => {
        const recipientUid = profile.id;
        await createNotificationBestEffort({
          recipientUid,
          type: item.type,
          title: item.title,
          body: name || item.title,
          targetType: item.targetType,
          targetId: item.id,
          dedupeKey: `wordpress_content:${item.key}:${item.id}:${item.revision || ''}:${recipientUid}`,
        });
        created += 1;
      }),
    );
  }
  return { baseline: false, created };
}

exports.pollWordPressContentNotifications = onSchedule(
  {
    schedule: 'every 5 minutes',
    timeZone: 'Europe/Budapest',
    region: 'europe-central2',
  },
  async () => {
    try {
      const result = await pollWordPressContentNotifications();
      console.info('wordpress_content_notifications', result);
    } catch (error) {
      console.warn(
        JSON.stringify({
          event: 'wordpress_content_notifications_failed',
          message: error?.message || String(error),
        }),
      );
    }
  },
);

async function removePushTokens(uid, tokens) {
  if (!tokens.length) return;
  await db
    .collection('private_user_data')
    .doc(uid)
    .set(
      {
        fcmTokens: FieldValue.arrayRemove(...tokens),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  // Keep legacy cleanup for tokens written by older app versions.
  await db
    .collection('community_profiles')
    .doc(uid)
    .update({
      fcmTokens: FieldValue.arrayRemove(...tokens),
    })
    .catch(() => {});
}

const submissionRoutes = {
  event: { path: '/event-submissions', role: null },
  artist: { path: '/artist-submissions', role: 'dj' },
  organizer: { path: '/organizer-submissions', role: 'organizer' },
};

function isAdmin(context, profile) {
  return (
    String(context.auth?.token?.email || '')
      .trim()
      .toLowerCase() === ADMIN_EMAIL || profile.accessRole === 'admin'
  );
}

async function notifySubmissionAdmins(kind, title, id) {
  const profiles = await db.collection('community_profiles').get();
  const adminProfiles = profiles.docs.filter((profileDoc) => {
    const profile = profileDoc.data() || {};
    return (
      String(profile.email || '')
        .trim()
        .toLowerCase() === ADMIN_EMAIL || profile.accessRole === 'admin'
    );
  });
  const tokenLists = await Promise.all(adminProfiles.map((profileDoc) => getPushTokens(profileDoc.id)));
  const tokens = tokenLists.flat();
  const uniqueTokens = [...new Set(tokens.map((token) => token.trim()).filter(Boolean))];
  if (!uniqueTokens.length) return { sent: 0 };
  const result = await sendMulticastToAllTokens(
    {
      notification: { title: `Új ${kind}beküldés`, body: title },
      data: { type: 'submission', kind, id: String(id) },
    },
    uniqueTokens,
  );
  return { sent: result.successCount, failed: result.failureCount };
}

exports.submitWordPressContent = wordPressCall(async (data, context) => {
  if (!context.auth || context.auth.token.firebase?.sign_in_provider === 'anonymous') {
    throw new HttpsError('permission-denied', 'Regisztráció szükséges a beküldéshez.');
  }
  if (!(await allowCall(context.auth.uid, 'submission'))) {
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

  const requestHash = crypto
    .createHash('sha256')
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
      createdAt: FieldValue.serverTimestamp(),
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
  await requestRef.set({ response: body, completedAt: FieldValue.serverTimestamp() }, { merge: true });
  if (body?.id) {
    const label = data.kind === 'artist' ? 'DJ' : data.kind === 'organizer' ? 'szervező' : 'esemény';
    await notifySubmissionAdmins(label, body.title || payload.title || '', body.id).catch((error) =>
      console.warn('submission admin push failed', error),
    );
  }
  return body;
});

exports.listWordPressSubmissions = wordPressCall(async (data, context) => {
  if (!context.auth) {
    throw new HttpsError('permission-denied', 'Csak admin tekintheti meg a beküldéseket.');
  }
  const profile = (await db.collection('community_profiles').doc(context.auth.uid).get()).data() || {};
  if (!isAdmin(context, profile)) {
    throw new HttpsError('permission-denied', 'Csak admin tekintheti meg a beküldéseket.');
  }
  if (!(await allowCall(context.auth.uid, 'wp_admin'))) {
    securityLog('wp_admin_rate_limited', context);
    throw new HttpsError('resource-exhausted', 'Túl sok admin művelet, próbáld később.');
  }
  const credentials = `${WORDPRESS_USERNAME.value()}:${WORDPRESS_APPLICATION_PASSWORD.value()}`;
  const response = await fetch(
    'https://hungarianhardstyle.hu/wp-json/wp/v2/huhs_submission?status=pending&per_page=100&_fields=id,date,title,link,content,excerpt,type,post_type',
    {
      headers: {
        Authorization: `Basic ${Buffer.from(credentials).toString('base64')}`,
        Accept: 'application/json',
      },
    },
  );
  const body = await response.json().catch(() => []);
  if (!response.ok) {
    throw new HttpsError('failed-precondition', body?.message || 'A WordPress beküldések nem tölthetők be.');
  }
  return Array.isArray(body)
    ? body.map((item) => ({
        id: item.id,
        date: item.date,
        title: item.title?.rendered || '',
        link: item.link || '',
        content: item.content?.rendered || '',
        excerpt: item.excerpt?.rendered || '',
        type: item.type || item.post_type || '',
      }))
    : [];
});

exports.manageWordPressSubmission = wordPressCall(async (data, context) => {
  if (!context.auth) {
    throw new HttpsError('permission-denied', 'Csak admin kezelheti a beküldéseket.');
  }
  const profile = (await db.collection('community_profiles').doc(context.auth.uid).get()).data() || {};
  if (!isAdmin(context, profile)) {
    throw new HttpsError('permission-denied', 'Csak admin kezelheti a beküldéseket.');
  }
  if (!(await allowCall(context.auth.uid, 'wp_admin'))) {
    securityLog('wp_admin_rate_limited', context);
    throw new HttpsError('resource-exhausted', 'Túl sok admin művelet, próbáld később.');
  }
  const id = Number(data?.id);
  const action = String(data?.action || '');
  if (!Number.isInteger(id) || id <= 0 || !['approve', 'trash'].includes(action)) {
    throw new HttpsError('invalid-argument', 'Érvénytelen beküldés-művelet.');
  }
  const credentials = `${WORDPRESS_USERNAME.value()}:${WORDPRESS_APPLICATION_PASSWORD.value()}`;
  const url =
    action === 'approve'
      ? `${WORDPRESS_BASE_URL}/submissions/${id}/approve`
      : `https://hungarianhardstyle.hu/wp-json/wp/v2/huhs_submission/${id}`;
  const response = await fetch(url, {
    method: action === 'approve' ? 'POST' : 'DELETE',
    headers: {
      Authorization: `Basic ${Buffer.from(credentials).toString('base64')}`,
      Accept: 'application/json',
    },
  });
  const body = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new HttpsError('failed-precondition', body?.message || 'A WordPress művelet sikertelen.');
  }
  return { ok: true, action, id, profileId: body?.profile_id || null };
});

exports.updateWordPressSubmission = wordPressCall(async (data, context) => {
  if (!context.auth) {
    throw new HttpsError('permission-denied', 'Csak admin szerkeszthet beküldést.');
  }
  const profile = (await db.collection('community_profiles').doc(context.auth.uid).get()).data() || {};
  if (!isAdmin(context, profile)) {
    throw new HttpsError('permission-denied', 'Csak admin szerkeszthet beküldést.');
  }
  if (!(await allowCall(context.auth.uid, 'wp_admin'))) {
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
});

const WORDPRESS_ADMIN_PATHS = new Set([
  '/wp/v2/huhs_event',
  '/wp/v2/huhs_artist',
  '/wp/v2/huhs_organizer',
  '/wp/v2/huhs_release',
  '/wp/v2/huhs_submission',
  '/huhs/v1/admin',
]);

exports.wordPressAdminRequest = wordPressCall(async (data, context) => {
  if (!context.auth) throw new HttpsError('permission-denied', 'Csak admin használhatja a WordPress vezérlőközpontot.');
  const profile = (await db.collection('community_profiles').doc(context.auth.uid).get()).data() || {};
  if (!isAdmin(context, profile))
    throw new HttpsError('permission-denied', 'Csak admin használhatja a WordPress vezérlőközpontot.');
  if (!(await allowCall(context.auth.uid, 'wp_admin_request'))) {
    securityLog('wp_admin_request_rate_limited', context);
    throw new HttpsError('resource-exhausted', 'Túl sok admin művelet, próbáld később.');
  }
  const rawPath = String(data?.path || '');
  const path = rawPath.split('?')[0];
  const method = String(data?.method || 'GET').toUpperCase();
  const isAllowedPath =
    WORDPRESS_ADMIN_PATHS.has(path) ||
    [...WORDPRESS_ADMIN_PATHS].some((base) => path.startsWith(base + '/') && /^\/\d+$/.test(path.slice(base.length)));
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
  console.info('wordpress_admin_request_ok', {
    uid: context.auth.uid,
    path,
    method,
  });
  return body;
});
async function deleteDocumentReferences(documents) {
  const uniqueDocuments = [...new Map(documents.map((document) => [document.ref.path, document])).values()];
  for (let offset = 0; offset < uniqueDocuments.length; offset += 400) {
    const batch = db.batch();
    uniqueDocuments.slice(offset, offset + 400).forEach((document) => batch.delete(document.ref));
    await batch.commit();
  }
}

async function removeUserReactions(uid) {
  const [posts, news] = await Promise.all([
    db.collection('live_feed_posts').get(),
    db.collection('news_reactions').get(),
  ]);
  const writes = [];
  for (const document of posts.docs) {
    const data = document.data() || {};
    const reactionBy = { ...(data.reactionBy || {}) };
    if (!Object.prototype.hasOwnProperty.call(reactionBy, uid)) continue;
    delete reactionBy[uid];
    const reactions = {};
    for (const value of Object.values(reactionBy)) {
      reactions[value] = Number(reactions[value] || 0) + 1;
    }
    writes.push({ ref: document.ref, data: { reactionBy, reactions } });
  }
  for (const document of news.docs) {
    const data = document.data() || {};
    const likedBy = Array.isArray(data.likedBy)
      ? Object.fromEntries(data.likedBy.filter((value) => typeof value === 'string').map((value) => [value, true]))
      : { ...(data.likedBy || {}) };
    if (!Object.prototype.hasOwnProperty.call(likedBy, uid)) continue;
    delete likedBy[uid];
    writes.push({
      ref: document.ref,
      data: { likedBy, count: Object.keys(likedBy).length },
    });
  }
  for (let offset = 0; offset < writes.length; offset += 400) {
    const batch = db.batch();
    writes.slice(offset, offset + 400).forEach(({ ref, data }) => batch.set(ref, data, { merge: true }));
    await batch.commit();
  }
}

async function deleteUserReferences(uid, profileData = {}) {
  const [
    relatedUserDocs,
    connectionRequestsFrom,
    connectionRequestsTo,
    conversations,
    comments,
    notifications,
    gameAttempts,
    ledgerEntries,
    votes,
    deviceClaims,
    reportsByUser,
    reportsAboutUser,
    artistClaims,
    labelEntitlements,
    labelPurchaseClaims,
    labelAdUnlocks,
    rewardedTransactions,
    referringProfiles,
    ownPosts,
  ] = await Promise.all([
    db.collectionGroup('users').get(),
    db.collection('connection_requests').where('from', '==', uid).get(),
    db.collection('connection_requests').where('to', '==', uid).get(),
    db.collection('private_conversations').where('participantIds', 'array-contains', uid).get(),
    db.collectionGroup('comments').where('authorId', '==', uid).get(),
    db.collection('notifications').where('recipientUid', '==', uid).get(),
    db.collection('game_attempts').where('uid', '==', uid).get(),
    db.collection('achievement_ledger').where('uid', '==', uid).get(),
    db.collection('voting_votes').where('userId', '==', uid).get(),
    db.collection('voting_device_claims').where('userId', '==', uid).get(),
    db.collection('chat_reports').where('reporterId', '==', uid).get(),
    db.collection('chat_reports').where('reportedUserId', '==', uid).get(),
    db.collection('artist_claims').where('uid', '==', uid).get(),
    db.collection('label_entitlements').where('uid', '==', uid).get(),
    db.collection('label_purchase_claims').where('uid', '==', uid).get(),
    db.collection('label_ad_unlocks').where('uid', '==', uid).get(),
    db.collection('admob_reward_transactions').where('uid', '==', uid).get(),
    db.collection('community_profiles').where('referredBy', '==', uid).get(),
    db.collection('live_feed_posts').where('authorId', '==', uid).get(),
  ]);
  const cloudinaryAssets = [];
  for (const [publicIdKey, urlKey] of [
    ['profileImagePublicId', 'profileImageUrl'],
    ['profileSourceImagePublicId', 'profileSourceImageUrl'],
  ])
    cloudinaryAssets.push({
      ownerUid: uid,
      publicId: profileData[publicIdKey],
      secureUrl: profileData[urlKey],
    });
  ownPosts.docs.forEach((post) => {
    const value = post.data() || {};
    cloudinaryAssets.push({
      ownerUid: uid,
      publicId: value.imagePublicId,
      secureUrl: value.imageUrl,
    });
  });
  for (const conversation of conversations.docs) {
    const messages = await conversation.ref.collection('messages').get();
    messages.docs.forEach((message) => {
      const value = message.data() || {};
      if (value.senderId === uid)
        cloudinaryAssets.push({
          ownerUid: uid,
          publicId: value.imagePublicId,
          secureUrl: value.imageUrl,
        });
    });
  }
  const selectedCloudinary = selectOwnedCloudinaryAssets(uid, cloudinaryAssets);
  let listedCloudinary = [];
  let cloudinaryListPending = false;
  try {
    listedCloudinary = await listOwnedCloudinaryAssets({
      cloudName: CLOUDINARY_CLOUD_NAME,
      apiKey: CLOUDINARY_API_KEY.value(),
      apiSecret: CLOUDINARY_API_SECRET.value(),
      uid,
    });
  } catch (error) {
    cloudinaryListPending = true;
    console.warn(
      JSON.stringify({
        event: 'account_deletion_cloudinary_list_failed',
        step: 'list_owned_assets',
        uidHash: crypto.createHash('sha256').update(uid).digest('hex').slice(0, 16),
        errorCode: error?.code || error?.message || 'unknown',
      }),
    );
  }
  const allCloudinaryAssets = [...selectedCloudinary.assets, ...listedCloudinary].filter(
    (asset, index, assets) => assets.findIndex((other) => other.publicId === asset.publicId) === index,
  );
  for (const asset of allCloudinaryAssets) {
    await destroyCloudinaryAsset({
      cloudName: CLOUDINARY_CLOUD_NAME,
      apiKey: CLOUDINARY_API_KEY.value(),
      apiSecret: CLOUDINARY_API_SECRET.value(),
      publicId: asset.publicId,
    });
  }
  const cleanupOperations = [];
  for (const document of relatedUserDocs.docs) {
    const path = document.ref.path.split('/');
    if (path.length !== 4) continue;
    const rootCollection = path[0];
    const value = document.data() || {};
    if (
      (rootCollection === 'event_meetups' && (document.id === uid || value.userId === uid)) ||
      (rootCollection === 'event_attendance' && document.id === uid) ||
      (rootCollection === 'event_ratings' && document.id === uid)
    ) {
      cleanupOperations.push({ type: 'delete', ref: document.ref });
    } else if (rootCollection === 'event_meetups' && value.interestedBy?.[uid] === true) {
      const interestedBy = { ...value.interestedBy };
      delete interestedBy[uid];
      cleanupOperations.push({
        type: 'set',
        ref: document.ref,
        data: {
          interestedBy,
          updatedAt: FieldValue.serverTimestamp(),
        },
      });
    }
  }
  const ownConnections = await db.collection('community_profiles').doc(uid).collection('connections').get();
  ownConnections.docs.forEach((connection) =>
    cleanupOperations.push({
      type: 'delete',
      ref: db.collection('community_profiles').doc(connection.id).collection('connections').doc(uid),
    }),
  );
  for (let offset = 0; offset < cleanupOperations.length; offset += 400) {
    const batch = db.batch();
    cleanupOperations.slice(offset, offset + 400).forEach((operation) => {
      if (operation.type === 'delete') batch.delete(operation.ref);
      else batch.set(operation.ref, operation.data, { merge: true });
    });
    await batch.commit();
  }
  await Promise.all([
    removeUserReactions(uid),
    deleteDocumentReferences([...connectionRequestsFrom.docs, ...connectionRequestsTo.docs]),
    deleteDocumentReferences(comments.docs.filter((doc) => doc.ref.path.startsWith('article_comments/'))),
    deleteDocumentReferences(notifications.docs),
    deleteDocumentReferences(gameAttempts.docs),
    deleteDocumentReferences(ledgerEntries.docs),
    deleteDocumentReferences(votes.docs),
    deleteDocumentReferences(deviceClaims.docs),
    deleteDocumentReferences([...reportsByUser.docs, ...reportsAboutUser.docs]),
    deleteDocumentReferences(artistClaims.docs),
    deleteDocumentReferences(labelEntitlements.docs),
    deleteDocumentReferences(labelPurchaseClaims.docs),
    deleteDocumentReferences(labelAdUnlocks.docs),
    deleteDocumentReferences(rewardedTransactions.docs),
    ...conversations.docs.map((conversation) => db.recursiveDelete(conversation.ref)),
    ...ownPosts.docs.map((post) => post.ref.delete()),
  ]);
  if (referringProfiles.size) {
    const batch = db.batch();
    referringProfiles.docs.forEach((profile) =>
      batch.set(
        profile.ref,
        {
          referredBy: FieldValue.delete(),
          referralRewardGranted: FieldValue.delete(),
          referralRewardGrantedAt: FieldValue.delete(),
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      ),
    );
    await batch.commit();
  }
  for (const attempt of gameAttempts.docs) {
    const value = attempt.data() || {};
    const gameId = Number(value.gameId || 0);
    if (!Number.isSafeInteger(gameId) || gameId <= 0) continue;
    await db
      .collection('game_stats')
      .doc(String(gameId))
      .set(
        {
          submissions: FieldValue.increment(-1),
          correctAnswers: FieldValue.increment(-Math.max(0, Number(value.correctAnswers || 0))),
          totalAnswers: FieldValue.increment(-Math.max(0, Number(value.totalAnswers || 0))),
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
  }
  const oldName = String(profileData.displayName || '').trim();
  if (oldName) {
    const indexRef = db.collection('display_name_index').doc(displayNameKey(oldName));
    const index = await indexRef.get();
    if (String(index.data()?.uid || '').trim() === uid) await indexRef.delete();
    // The plain-text claim must be released too, otherwise the name stays
    // permanently blocked for everybody after an account is deleted.
    const claimRef = displayNameClaimRef(oldName);
    const claim = await claimRef.get();
    if (String(claim.data()?.uid || '').trim() === uid) await claimRef.delete();
  }
  await db.recursiveDelete(db.collection('community_profiles').doc(uid));
  await Promise.all([
    db.collection('public_profiles').doc(uid).delete(),
    db.collection('private_user_data').doc(uid).delete(),
    db.collection('community_bans').doc(uid).delete(),
  ]);
  return {
    manualCleanupRequired: selectedCloudinary.manualCleanupRequired,
    cloudinaryListPending,
  };
}

// Keep this compatible with the currently released Play client until its
// Play Integrity attestation is verified end-to-end. Admin authorization,
// rate limiting and the protected primary-admin account remain server-side.
exports.deleteCommunityUser = functions
  .runWith({
    secrets: [CLOUDINARY_API_KEY, CLOUDINARY_API_SECRET, ...SMTP_SECRETS],
    enforceAppCheck: false,
  })
  .https.onCall(async (data, context) => {
    const email = String(context.auth?.token?.email || '')
      .trim()
      .toLowerCase();
    if (!context.auth) {
      throw new HttpsError('permission-denied', 'Csak admin törölhet felhasználót.');
    }
    if (!(await allowCall(context.auth.uid, 'user_delete', 10))) {
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
      if (email !== ADMIN_EMAIL && callerData.accessRole !== 'admin' && callerData.role !== 'admin') {
        throw new HttpsError('permission-denied', 'Only admins can delete users.');
      }
    }

    const selfDelete = uid === context.auth.uid;
    const deletionRef = db.collection('account_deletions').doc(uid);
    await deletionRef.set(
      {
        status: 'pending',
        selfDelete,
        deletionType: 'account-deletion',
        source: 'deleteCommunityUser',
        expiresAt: FieldValue.delete(),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    let targetUser;
    try {
      targetUser = await auth.getUser(uid);
    } catch (error) {
      if (error?.code === 'auth/user-not-found') targetUser = null;
      else throw error;
    }
    if (
      String(targetUser?.email || '')
        .trim()
        .toLowerCase() === ADMIN_EMAIL
    ) {
      throw new HttpsError('failed-precondition', 'A fő adminisztrátori fiók nem törölhető.');
    }

    const profileSnapshot = await db.collection('community_profiles').doc(uid).get();
    const profileData = profileSnapshot.data() || {};
    try {
      await auth.deleteUser(uid);
    } catch (error) {
      // Make retries safe when Auth was already deleted but Firestore cleanup did not finish.
      if (error?.code !== 'auth/user-not-found') throw error;
    }
    await db.collection('deleted_user_ids').doc(uid).set({
      deletedAt: FieldValue.serverTimestamp(),
    });
    let cleanup;
    try {
      cleanup = await deleteUserReferences(uid, profileData);
    } catch (error) {
      // Auth is already gone; preserve a retryable deletion record instead of
      // turning partial cleanup into a misleading hard failure.
      await deletionRef.set(
        {
          status: 'pending',
          lastError: error?.code || 'cleanup-failed',
          expiresAt: FieldValue.delete(),
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      securityLog('community_user_core_deleted_cleanup_pending', context);
      return { deleted: true, uid, cleanupStatus: 'cleanup_pending' };
    }

    const authStillExists = await auth
      .getUser(uid)
      .then(() => true)
      .catch((error) => {
        if (error?.code === 'auth/user-not-found') return false;
        throw error;
      });
    const profileStillExists = (await db.collection('community_profiles').doc(uid).get()).exists;
    if (authStillExists || profileStillExists) {
      await deletionRef.set(
        {
          status: 'pending',
          lastError: 'required-account-data-remains',
          expiresAt: FieldValue.delete(),
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      throw new HttpsError('aborted', 'A fiók törlése nem fejeződött be, próbáld újra.');
    }
    if (cleanup.cloudinaryListPending) {
      if (!selfDelete && targetUser?.email) {
        await sendIdentityEmailOnce({
          key: `admin-deletion:${uid}`,
          to: targetUser.email,
          template: deletionEmailTemplate(),
        });
      }
      await deletionRef.set(
        {
          status: 'pending',
          lastError: 'cloudinary-list-temporary-failure',
          expiresAt: FieldValue.delete(),
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      securityLog('community_user_core_deleted_cleanup_pending', context);
      return { deleted: true, uid, cleanupStatus: 'cleanup_pending' };
    }
    await deletionRef.set(
      {
        status: cleanup.manualCleanupRequired ? 'manual_cleanup_required' : 'completed',
        ...(cleanup.manualCleanupRequired
          ? { lastError: 'legacy-cloudinary-public-id-missing' }
          : { completedAt: FieldValue.serverTimestamp() }),
        expiresAt: new Date(Date.now() + 48 * 60 * 60 * 1000),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    if (!selfDelete && targetUser?.email) {
      await sendIdentityEmailOnce({
        key: `admin-deletion:${uid}`,
        to: targetUser.email,
        template: deletionEmailTemplate(),
      });
    }

    securityLog('community_user_deleted', context);

    return {
      deleted: true,
      uid,
      cleanupStatus: cleanup.manualCleanupRequired ? 'manual_cleanup_required' : 'completed',
    };
  });

exports.cleanupIncompleteAccounts = onSchedule(
  {
    schedule: 'every 15 minutes',
    timeZone: 'Europe/Budapest',
    region: 'europe-central2',
    secrets: [CLOUDINARY_API_KEY, CLOUDINARY_API_SECRET],
  },
  async () => {
    const expiredEmailJobs = await db
      .collection('email_delivery_jobs')
      .where('expiresAt', '<=', new Date())
      .limit(100)
      .get();
    await deleteDocumentReferences(expiredEmailJobs.docs);

    let pageToken;
    const cutoff = Date.now() - 24 * 60 * 60 * 1000;
    do {
      const page = await auth.listUsers(1000, pageToken);
      for (const authUser of page.users) {
        if (normalizedEmail(authUser.email) === ADMIN_EMAIL) continue;
        const created = authUser.metadata.creationTime ? new Date(authUser.metadata.creationTime).getTime() : 0;
        if (!created || created > cutoff) continue;
        const profileSnapshot = await db.collection('community_profiles').doc(authUser.uid).get();
        const profile = profileSnapshot.data() || {};
        const name = String(profile.displayName || '').trim();
        const incompleteName = !name || isUnnumberedPlaceholderDisplayName(name) || /^HUHS user \d+$/i.test(name);
        const pendingEmail = normalizedEmail(profile.pendingEmail);
        const pendingExpiry = profile.pendingEmailExpiresAt?.toDate?.();
        const pendingExpiryTime = pendingExpiry?.getTime?.();
        const pendingEmailExpired = Boolean(
          pendingEmail && Number.isFinite(pendingExpiryTime) && pendingExpiryTime <= Date.now(),
        );
        const hasGoogleProvider = authUser.providerData.some((provider) => provider.providerId === 'google.com');
        if ((authUser.emailVerified || hasGoogleProvider) && !incompleteName) {
          if (pendingEmailExpired) {
            await profileSnapshot.ref.set(
              {
                pendingEmail: FieldValue.delete(),
                pendingEmailExpiresAt: FieldValue.delete(),
                updatedAt: FieldValue.serverTimestamp(),
              },
              { merge: true },
            );
          }
          continue;
        }
        const email = normalizedEmail(authUser.email || profile.email);
        if (email) {
          const markerRef = db.collection('deleted_identity_hashes').doc(deletedIdentityKey(email));
          const markerSnapshot = await markerRef.get();
          if (!isExplicitIdentityBan(markerSnapshot.data() || {})) {
            await markerRef.set(
              {
                blocked: false,
                reason: 'incomplete-account-cleanup',
                source: 'cleanupIncompleteAccounts',
                deletionType: 'account-deletion',
                createdAt: FieldValue.serverTimestamp(),
                updatedAt: FieldValue.serverTimestamp(),
              },
              { merge: true },
            );
          }
        }
        try {
          await auth.deleteUser(authUser.uid);
        } catch (error) {
          if (error?.code !== 'auth/user-not-found') throw error;
        }
        await db.collection('deleted_user_ids').doc(authUser.uid).set({ deletedAt: FieldValue.serverTimestamp() });
        await deleteUserReferences(authUser.uid, profile);
      }
      pageToken = page.pageToken;
    } while (pageToken);

    const pendingDeletions = await db.collection('account_deletions').where('status', '==', 'pending').limit(50).get();
    for (const deletion of pendingDeletions.docs) {
      const uid = deletion.id;
      const authStillExists = await auth
        .getUser(uid)
        .then(() => true)
        .catch((error) => {
          if (error?.code === 'auth/user-not-found') return false;
          throw error;
        });
      if (authStillExists) continue;
      const profileSnapshot = await db.collection('community_profiles').doc(uid).get();
      try {
        const cleanup = await deleteUserReferences(uid, profileSnapshot.data() || {});
        if (cleanup.cloudinaryListPending) continue;
        await deletion.ref.set(
          {
            status: cleanup.manualCleanupRequired ? 'manual_cleanup_required' : 'completed',
            ...(cleanup.manualCleanupRequired
              ? { lastError: 'legacy-cloudinary-public-id-missing' }
              : { completedAt: FieldValue.serverTimestamp() }),
            expiresAt: new Date(Date.now() + 48 * 60 * 60 * 1000),
            updatedAt: FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
      } catch (error) {
        console.error(
          JSON.stringify({
            event: 'account_deletion_retry_failed',
            step: 'retry_pending_cleanup',
            uidHash: crypto.createHash('sha256').update(uid).digest('hex').slice(0, 16),
            errorCode: error?.code || error?.message || 'unknown',
          }),
        );
      }
    }
  },
);

exports.deletePrivateConversation = functions
  .runWith({ enforceAppCheck: false })
  .https.onCall(async (data, context) => {
    const uid = String(context.auth?.uid || '').trim();
    if (!uid || context.auth.token.firebase?.sign_in_provider === 'anonymous') {
      throw new HttpsError('unauthenticated', 'Bejelentkezés szükséges a beszélgetés törléséhez.');
    }
    if (!(await allowCall(uid, 'private_conversation_delete', 10))) {
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

exports.claimArtistProfile = functions.runWith({ enforceAppCheck: false }).https.onCall(async (data, context) => {
  if (!context.auth || context.auth.token.email_verified !== true) {
    throw new HttpsError('permission-denied', 'Hitelesített e-mailes fiók szükséges.');
  }
  const artistId = Number(data?.artistId);
  const email = String(context.auth.token.email || '')
    .trim()
    .toLowerCase();
  const isAdminClaim = email === ADMIN_EMAIL;
  if (!Number.isInteger(artistId) || artistId <= 0 || !email || email === 'info@hungarianhardstyle.hu') {
    throw new HttpsError('invalid-argument', 'Érvényes DJ-adatlap és e-mail szükséges.');
  }
  if (!(await allowCall(context.auth.uid, 'artist_claim', 5))) {
    throw new HttpsError('resource-exhausted', 'Túl sok claim-kérés, próbáld később.');
  }
  const claimRef = db.collection('artist_claims').doc(String(artistId));
  const existing = await claimRef.get();
  if (existing.exists && existing.data()?.uid !== context.auth.uid) {
    throw new HttpsError('already-exists', 'Ezt a DJ-adatlapot már claimelte egy másik fiók.');
  }
  const response = await fetch(`${WORDPRESS_BASE_URL}/artists/${artistId}`);
  const artist = await response.json().catch(() => ({}));
  if (
    !response.ok ||
    (!isAdminClaim &&
      String(artist?.booking_email || '')
        .trim()
        .toLowerCase() !== email)
  ) {
    throw new HttpsError('permission-denied', 'A bejelentkezési e-mail nem egyezik a booking e-maillel.');
  }
  await claimRef.set({
    artistId,
    uid: context.auth.uid,
    email,
    status: 'claimed',
    updatedAt: FieldValue.serverTimestamp(),
  });
  return { claimed: true, artistId };
});

exports.getArtistClaimStatus = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  if (!(await allowCallByIp(context, 'artist_claim_status', 60))) {
    throw new HttpsError('resource-exhausted', 'Túl sok kérés.');
  }
  const artistId = Number(data?.artistId);
  if (!Number.isInteger(artistId) || artistId <= 0) {
    throw new HttpsError('invalid-argument', 'Érvényes DJ-adatlap szükséges.');
  }
  const claim = await db.collection('artist_claims').doc(String(artistId)).get();
  return { claimed: claim.exists };
});

exports.getMyClaimedArtists = functions.runWith({ enforceAppCheck: false }).https.onCall(async (data, context) => {
  if (!context.auth || context.auth.token.email_verified !== true) {
    throw new HttpsError('permission-denied', 'Bejelentkezés szükséges.');
  }
  const snapshot = await db.collection('artist_claims').where('uid', '==', context.auth.uid).get();
  return {
    artistIds: snapshot.docs.map((doc) => Number(doc.data()?.artistId)).filter((id) => Number.isInteger(id) && id > 0),
  };
});

exports.verifyLabelPurchase = functions
  .runWith({
    secrets: [GOOGLE_PLAY_SERVICE_ACCOUNT_JSON],
    enforceAppCheck: false,
  })
  .https.onCall(async (data, context) => {
    if (!context.auth || context.auth.token.firebase?.sign_in_provider === 'anonymous') {
      throw new HttpsError('unauthenticated', 'Bejelentkezés szükséges a vásárláshoz.');
    }
    if (!(await allowCall(context.auth.uid, 'label_purchase', 10))) {
      throw new HttpsError('resource-exhausted', 'Túl sok vásárlási ellenőrzés.');
    }
    const productId = String(data?.productId || '').trim();
    const purchaseToken = String(data?.purchaseToken || '').trim();
    const releaseId = Number(data?.releaseId || 0);
    const productMatch = productId.match(
      /^huhs_release_([0-9]+)_(radio_wav|radio_mp3_320|extended_wav|extended_mp3_320|wav|mp3_320)$/,
    );
    if (
      !productMatch ||
      !purchaseToken ||
      !Number.isInteger(releaseId) ||
      releaseId < 1 ||
      Number(productMatch[1]) !== releaseId
    ) {
      throw new HttpsError('invalid-argument', 'Érvénytelen Label-vásárlási adat.');
    }
    let serviceAccount;
    try {
      serviceAccount = JSON.parse(GOOGLE_PLAY_SERVICE_ACCOUNT_JSON.value());
    } catch (_) {
      throw new HttpsError('failed-precondition', 'A Google Play vásárlás-ellenőrzés nincs beállítva.');
    }
    const auth = new googleApis().auth.GoogleAuth({
      credentials: serviceAccount,
      scopes: ['https://www.googleapis.com/auth/androidpublisher'],
    });
    const androidPublisher = googleApis().androidpublisher({ version: 'v3', auth });
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
    const previousOwner = await db
      .collection('label_entitlements')
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
      verifiedAt: FieldValue.serverTimestamp(),
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
          claimedAt: FieldValue.serverTimestamp(),
        });
      } else {
        tx.set(claimRef, { lastVerifiedAt: FieldValue.serverTimestamp() }, { merge: true });
      }
      tx.set(entitlementRef, entitlement, { merge: true });
    });
    return { verified: true, releaseId, productId };
  });

exports.getLabelDownloadUrl = functions
  .runWith({
    secrets: [WORDPRESS_USERNAME, WORDPRESS_APPLICATION_PASSWORD],
    enforceAppCheck: false,
  })
  .https.onCall(async (data, context) => {
    const releaseId = Number(data?.releaseId || 0);
    const variant = String(data?.variant || '').trim();
    const isAnonymous = !context.auth || context.auth.token.firebase?.sign_in_provider === 'anonymous';
    if (isAnonymous) {
      throw new HttpsError('unauthenticated', 'Bejelentkezés szükséges a letöltéshez.');
    }
    const callerKey =
      context.auth?.uid || context.rawRequest?.ip || context.rawRequest?.socket?.remoteAddress || 'anonymous';
    if (!(await allowCall(callerKey, 'label_download', 10))) {
      throw new HttpsError('resource-exhausted', 'Túl sok letöltési kérés.');
    }
    if (
      !Number.isInteger(releaseId) ||
      releaseId < 1 ||
      ![
        'free_wav',
        'wav',
        'mp3_320',
        'mp3_96',
        'mp3_128',
        'radio_wav',
        'radio_mp3_320',
        'extended_wav',
        'extended_mp3_320',
      ].includes(variant)
    ) {
      throw new HttpsError('invalid-argument', 'Érvénytelen Label-letöltési adat.');
    }
    const paid = !['free_wav', 'mp3_96', 'mp3_128'].includes(variant);
    const productId = `huhs_release_${releaseId}_${variant}`;
    const entitlement = paid
      ? await db.collection('label_entitlements').doc(`${context.auth.uid}_${productId}`).get()
      : null;
    if (paid && (!entitlement || !entitlement.exists || entitlement.data()?.releaseId !== releaseId)) {
      throw new HttpsError('permission-denied', 'Ehhez a fájlhoz nincs vásárlási jogosultság.');
    }
    if (!paid && ['free_wav', 'mp3_96', 'mp3_128'].includes(variant)) {
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
    return {
      downloadUrl: body.download_url,
      expiresIn: Number(body.expires_in || 300),
    };
  });

// Public opinion poll ("Kérdőív").
//
// Only a registered account may vote, and only once. The WordPress site is the
// store of record: it keeps a salted fingerprint of the voter and nothing else,
// so no name, e-mail address or Firebase UID is stored anywhere. The caller
// never sends its own identity: the UID comes from the verified auth token, so
// one account cannot vote on behalf of another.
//
// Calling this without `optionIndex` only asks whether this account has already
// voted, which is how the app decides between the ballot and the thank-you
// state.
exports.pollVote = functions
  .runWith({
    secrets: [WORDPRESS_USERNAME, WORDPRESS_APPLICATION_PASSWORD],
    enforceAppCheck: false,
  })
  .https.onCall(async (data, context) => {
    requireRegisteredViewer(context);
    const pollId = Number(data?.pollId || 0);
    if (!Number.isInteger(pollId) || pollId < 1) {
      throw new HttpsError('invalid-argument', 'Érvénytelen kérdőív.');
    }
    const hasOption = data?.optionIndex !== undefined && data?.optionIndex !== null;
    const optionIndex = Number(data?.optionIndex ?? -1);
    if (hasOption && (!Number.isInteger(optionIndex) || optionIndex < 0 || optionIndex > 9)) {
      throw new HttpsError('invalid-argument', 'Érvénytelen válaszlehetőség.');
    }

    const uid = String(context.auth.uid);
    if (hasOption && !(await allowCall(uid, 'poll_vote', 20))) {
      throw new HttpsError('resource-exhausted', 'Túl sok kérés, próbáld később.');
    }

    const credentials = `${WORDPRESS_USERNAME.value()}:${WORDPRESS_APPLICATION_PASSWORD.value()}`;
    const response = await fetch(`${WORDPRESS_BASE_URL}${hasOption ? '/poll/vote' : '/poll/status'}`, {
      method: 'POST',
      headers: {
        Authorization: `Basic ${Buffer.from(credentials).toString('base64')}`,
        'Content-Type': 'application/json',
        Accept: 'application/json',
      },
      body: JSON.stringify(hasOption ? { pollId, optionIndex, uid } : { pollId, uid }),
    });
    const payload = await response.json().catch(() => ({}));
    // A kerdőív-szavazas diagnosztikaja. Az UID-t SZANDEKOSAN nem naplozzuk
    // (adatvedelem): csak a hosszat, hogy azonosithato legyen, valtozott-e.
    // Ez a sor valaszolja meg azt a kerdest, amit a kliens nem tud: a WordPress
    // valoban rogzitette-e a szavazatot, es ismeri-e fel a masodikat.
    console.info('poll_vote_wordpress_result', {
      pollId,
      optionIndex: hasOption ? optionIndex : null,
      uidLength: uid.length,
      status: response.status,
      voted: payload?.voted === true,
      alreadyVoted: payload?.alreadyVoted === true,
    });
    if (!response.ok) {
      console.warn('poll_vote_wordpress_failed', {
        pollId,
        hasOption,
        status: response.status,
        message: typeof payload?.message === 'string' ? payload.message : '',
      });
      throw new HttpsError(
        response.status === 403 ? 'failed-precondition' : 'internal',
        typeof payload?.message === 'string' && payload.message !== ''
          ? payload.message
          : 'A szavazat rögzítése nem sikerült.',
      );
    }
    if (!hasOption) return { voted: payload?.voted === true };
    return { ok: true, alreadyVoted: payload?.alreadyVoted === true };
  });

// ---------------------------------------------------------------------------
// IDEIGLENES DIAGNOSZTIKA - a kerdőív-szavazat szerveroldali bizonyitasara.
//
// A tulajdonos jelezte, hogy ujra tudott szavazni (eloször frissites utan,
// majd az app ujranyitasa utan). A kliens oldalon javitottuk a beragadt
// „szavaztal mar?" allapotot, de azt is bizonyitani kell, hogy a WordPress
// valoban rogziti a szavazatot es felismeri a masodikat.
//
// Ez a fuggveny pontosan azt a negy lepest jatsza le, amit az app:
//   status -> vote -> vote (masodszor) -> status
// Egy VELETLEN proba-UID-vel dolgozik, majd a sajat sorat torli, ezert a
// valodi szavazatszamot nem valtoztatja meg. A valasz megmutatja, mit ad a
// WordPress mind a negy lepesben.
//
// Futtatas (a bejelentkezett tulajdonos tokenjevel):
//   npx firebase functions:log --only pollVoteDiagnostics
// Es a hivas: POST https://us-central1-hungarian-hardstyle.cloudfunctions.net/pollVoteDiagnostics
// A fuggveny a deploy utan EGYSZER fut, utana torolni kell.
// ---------------------------------------------------------------------------
exports.pollVoteDiagnostics = functions
  .runWith({
    secrets: [WORDPRESS_USERNAME, WORDPRESS_APPLICATION_PASSWORD],
    enforceAppCheck: false,
    timeoutSeconds: 120,
  })
  .https.onCall(async (data, context) => {
    const uid = requireRegisteredViewer(context);
    const pollId = Number(data?.pollId || 0);
    if (!Number.isInteger(pollId) || pollId < 1) {
      throw new HttpsError('invalid-argument', 'Érvénytelen kérdőív.');
    }

    const probe = `diag-${crypto.randomBytes(8).toString('hex')}`;
    const credentials = `${WORDPRESS_USERNAME.value()}:${WORDPRESS_APPLICATION_PASSWORD.value()}`;
    const request = async (path, body) => {
      const response = await fetch(`${WORDPRESS_BASE_URL}${path}`, {
        method: 'POST',
        headers: {
          Authorization: `Basic ${Buffer.from(credentials).toString('base64')}`,
          'Content-Type': 'application/json',
          Accept: 'application/json',
        },
        body: JSON.stringify(body),
      });
      const payload = await response.json().catch(() => ({}));
      return { status: response.status, payload };
    };

    const report = { pollId, callerUidLength: uid.length, probeUid: probe };
    report.statusBefore = await request('/poll/status', { pollId, uid: probe });
    report.voteFirst = await request('/poll/vote', { pollId, optionIndex: 0, uid: probe });
    report.voteSecond = await request('/poll/vote', { pollId, optionIndex: 0, uid: probe });
    report.statusAfter = await request('/poll/status', { pollId, uid: probe });
    report.cleanup = await request('/poll/vote', {
      pollId,
      optionIndex: 0,
      uid: probe,
      remove: true,
    });
    report.statusAfterCleanup = await request('/poll/status', { pollId, uid: probe });
    console.info('poll_vote_diagnostics', JSON.stringify(report));
    return report;
  });

const labelProductDefinitions = [
  { type: 'radio_wav', label: 'Radio WAV' },
  { type: 'radio_mp3_320', label: 'Radio MP3 320 kbps' },
  { type: 'extended_wav', label: 'Extended WAV' },
  { type: 'extended_mp3_320', label: 'Extended MP3 320 kbps' },
];

function parseHufPrice(value) {
  const match = String(value || '')
    .replace(/\s/g, '')
    .match(/\d+/);
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
    current = (
      await androidPublisher.monetization.onetimeproducts.get({
        packageName: GOOGLE_PLAY_PACKAGE_NAME,
        productId,
      })
    ).data;
  } catch (error) {
    if (error?.response?.status !== 404) throw error;
  }

  const purchaseOptionId = String(current?.purchaseOptions?.[0]?.purchaseOptionId || 'default');
  const title = `${String(release.title || 'HUHS Release')} – ${definition.label}`.slice(0, 55);
  const description = `Hungarian Hardstyle ${definition.label} letöltés: ${String(release.title || 'Release')}`.slice(
    0,
    200,
  );
  const currentOption =
    current?.purchaseOptions?.find((option) => option.purchaseOptionId === purchaseOptionId) ||
    current?.purchaseOptions?.[0] ||
    null;
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
    buyOption: currentOption?.buyOption || {
      legacyCompatible: true,
      multiQuantityEnabled: false,
    },
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
    const isBackendError =
      error?.response?.status === 500 &&
      (error?.response?.data?.error?.status === 'INTERNAL' ||
        error?.response?.data?.error?.errors?.some((item) => item.reason === 'backendError'));
    if (!isBackendError) throw error;
    console.warn('label_product_sync_latency_tolerant_retry', {
      releaseId: Number(release.id),
      type: definition.type,
      productId,
      price,
    });
    result = await androidPublisher.monetization.onetimeproducts.patch(
      request('PRODUCT_UPDATE_LATENCY_TOLERANCE_LATENCY_TOLERANT'),
    );
  }
  let saved = result.data || product;
  let savedOption =
    saved.purchaseOptions?.find((option) => option.purchaseOptionId === purchaseOptionId) || saved.purchaseOptions?.[0];
  console.log('label_product_sync_play_patch_response', {
    releaseId: Number(release.id),
    type: definition.type,
    productId,
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
      saved = (
        await androidPublisher.monetization.onetimeproducts.get({
          packageName: GOOGLE_PLAY_PACKAGE_NAME,
          productId,
        })
      ).data;
      savedOption =
        saved.purchaseOptions?.find((option) => option.purchaseOptionId === purchaseOptionId) ||
        saved.purchaseOptions?.[0];
      if (savedOption) break;
    }
  }

  if (!savedOption) {
    const batchResult = await androidPublisher.monetization.onetimeproducts.batchUpdate({
      packageName: GOOGLE_PLAY_PACKAGE_NAME,
      requestBody: {
        requests: [
          {
            oneTimeProduct: product,
            updateMask: 'listings,purchaseOptions',
            regionsVersion: { version: GOOGLE_PLAY_REGIONS_VERSION },
            allowMissing: true,
            latencyTolerance: 'PRODUCT_UPDATE_LATENCY_TOLERANCE_LATENCY_TOLERANT',
          },
        ],
      },
    });
    saved = batchResult.data?.oneTimeProducts?.[0] || null;
    savedOption =
      saved?.purchaseOptions?.find((option) => option.purchaseOptionId === purchaseOptionId) ||
      saved?.purchaseOptions?.[0];
  }

  if (!savedOption) {
    throw new Error(`Play purchase option missing after upsert: ${productId}`);
  }

  // A release that is not out yet has to exist in Play — the review and the
  // propagation have to finish before the launch day — but it must not be
  // buyable. The purchase option is therefore kept inactive until the release
  // date. The scheduled sync runs every five minutes, so the option activates
  // itself on the day without anybody pressing anything.
  const releaseIsUpcoming = release?.is_upcoming === true;
  const currentState = String(savedOption.state || '').toUpperCase();

  if (releaseIsUpcoming ? currentState === 'ACTIVE' : currentState !== 'ACTIVE') {
    const optionId = savedOption.purchaseOptionId || purchaseOptionId;
    await androidPublisher.monetization.onetimeproducts.purchaseOptions.batchUpdateStates({
      packageName: GOOGLE_PLAY_PACKAGE_NAME,
      productId,
      requestBody: {
        requests: [
          releaseIsUpcoming
            ? {
                deactivatePurchaseOptionRequest: {
                  packageName: GOOGLE_PLAY_PACKAGE_NAME,
                  productId,
                  purchaseOptionId: optionId,
                  latencyTolerance: 'PRODUCT_UPDATE_LATENCY_TOLERANCE_LATENCY_TOLERANT',
                },
              }
            : {
                activatePurchaseOptionRequest: {
                  packageName: GOOGLE_PLAY_PACKAGE_NAME,
                  productId,
                  purchaseOptionId: optionId,
                  latencyTolerance: 'PRODUCT_UPDATE_LATENCY_TOLERANCE_LATENCY_TOLERANT',
                },
              },
        ],
      },
    });
  }

  const verified = (
    await androidPublisher.monetization.onetimeproducts.get({
      packageName: GOOGLE_PLAY_PACKAGE_NAME,
      productId,
    })
  ).data;
  const verifiedOption =
    verified.purchaseOptions?.find(
      (option) => option.purchaseOptionId === (savedOption.purchaseOptionId || purchaseOptionId),
    ) || verified.purchaseOptions?.[0];
  const verifiedState = String(verifiedOption?.state || '').toUpperCase();
  // The pre-release requirement is "not buyable", not one specific Play state
  // string: the catalog has more than one non-active state, and rejecting an
  // unknown one would fail the sync for a product that is in fact safe.
  const stateIsCorrect = releaseIsUpcoming ? verifiedState !== 'ACTIVE' : verifiedState === 'ACTIVE';
  if (!verifiedOption || !stateIsCorrect) {
    throw new Error(
      releaseIsUpcoming
        ? `Play purchase option is still active before the release date: ${productId}`
        : `Play purchase option is not active after sync: ${productId}`,
    );
  }
  console.log('label_product_sync_play_verified', {
    releaseId: Number(release.id),
    type: definition.type,
    productId,
    purchaseOptionId: verifiedOption.purchaseOptionId,
    purchaseOptionState: verifiedOption.state,
    releaseIsUpcoming,
    huAvailability:
      verifiedOption.regionalPricingAndAvailabilityConfigs?.find((item) => item.regionCode === 'HU')?.availability ||
      'missing',
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
    return {
      releaseId: Number(release.id),
      products,
      skipped: 'audio-not-ready',
    };
  }
  const existing = new Map(
    (Array.isArray(release.products) ? release.products : []).map((item) => [String(item.type), item]),
  );
  const prices = release.product_prices || {};
  const available = new Set(
    (Array.isArray(release.versions) ? release.versions : [])
      .filter((item) => item.available)
      .map((item) => String(item.type)),
  );
  const errors = [];
  for (const definition of labelProductDefinitions) {
    const rawKnown = existing.get(definition.type);
    const knownId = String(rawKnown?.id || '');
    // Never attach a product belonging to another release. This prevents a
    // copied/stale WordPress ID from leaving the new release's buttons grey.
    const known = rawKnown && knownId.startsWith(`huhs_release_${release.id}_`) ? rawKnown : null;
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
        releaseId: Number(release.id),
        type: definition.type,
        productId: products[definition.type],
        price,
        status: 'ok',
      });
    } catch (error) {
      const apiError = error?.response?.data?.error || error?.response?.data || null;
      const detail = {
        releaseId: Number(release.id),
        type: definition.type,
        productId,
        price,
        status: error?.response?.status || null,
        message: error?.message || String(error),
        apiError: apiError
          ? {
              code: apiError.code || null,
              status: apiError.status || null,
              message: apiError.message || null,
              reasons: Array.isArray(apiError.errors)
                ? apiError.errors.map((item) => ({
                    reason: item.reason || null,
                    message: item.message || null,
                  }))
                : [],
              raw: JSON.stringify(apiError),
            }
          : null,
      };
      errors.push(detail);
      console.error('label_product_sync_item_failed', detail);
    }
  }
  if (Object.keys(products).length) await updateWordPressReleaseProducts(credentials, release.id, products);
  return { releaseId: Number(release.id), products, errors };
}

const LABEL_SYNC_LEASE_MS = 4 * 60 * 1000;

// A Firestore-based lease serializes the label sync across concurrent function
// instances, unlike the previous per-instance boolean which only worked on a
// single warm instance.
async function acquireLabelSyncLease() {
  const ref = db.collection('sync_locks').doc('label_product_sync');
  const now = Date.now();
  let acquired = false;
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const leaseUntil = snapshot.data()?.leaseUntil?.toDate?.()?.getTime?.() || 0;
    if (now >= leaseUntil) {
      transaction.set(ref, {
        leaseUntil: new Date(now + LABEL_SYNC_LEASE_MS),
        updatedAt: FieldValue.serverTimestamp(),
      });
      acquired = true;
    }
  });
  return acquired;
}

async function releaseLabelSyncLease() {
  await db.collection('sync_locks').doc('label_product_sync').delete().catch(() => {});
}

async function syncWordPressLabelProducts(releaseId = 0) {
  if (!(await acquireLabelSyncLease())) return { skipped: true, reason: 'already-running' };
  try {
    const credentials = `${WORDPRESS_USERNAME.value()}:${WORDPRESS_APPLICATION_PASSWORD.value()}`;
    let serviceAccount;
    try {
      serviceAccount = JSON.parse(GOOGLE_PLAY_SERVICE_ACCOUNT_JSON.value());
    } catch (_) {
      throw new Error('A Google Play service account secret érvénytelen.');
    }
    const auth = new googleApis().auth.GoogleAuth({
      credentials: serviceAccount,
      scopes: ['https://www.googleapis.com/auth/androidpublisher'],
    });
    const androidPublisher = googleApis().androidpublisher({ version: 'v3', auth });
    const response = await fetch(`${WORDPRESS_BASE_URL}/releases`, {
      headers: { Accept: 'application/json' },
    });
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
          releaseId: release.id,
          title: release.title,
          message: error?.message || String(error),
          status: error?.response?.status || null,
        });
      }
    }
    return { processed: results.length, results };
  } finally {
    await releaseLabelSyncLease();
  }
}

exports.syncLabelProducts = functions
  .runWith({ secrets: labelProductSyncSecrets, enforceAppCheck: false })
  .https.onCall(async (data, context) => {
    if (!context.auth) throw new HttpsError('permission-denied', 'Csak admin indíthatja a Play-termékszinkront.');
    const profile = (await db.collection('community_profiles').doc(context.auth.uid).get()).data() || {};
    if (!isAdmin(context, profile))
      throw new HttpsError('permission-denied', 'Csak admin indíthatja a Play-termékszinkront.');
    const releaseId = Number(data?.releaseId || 0);
    if (releaseId && (!Number.isInteger(releaseId) || releaseId < 1))
      throw new HttpsError('invalid-argument', 'Érvénytelen release-azonosító.');
    return syncWordPressLabelProducts(releaseId);
  });

exports.syncWordPressLabelProducts = onSchedule(
  {
    schedule: 'every 5 minutes',
    timeZone: 'Europe/Budapest',
    secrets: labelProductSyncSecrets,
  },
  async () => syncWordPressLabelProducts(),
);

// WordPress queues this request immediately after audio processing succeeds.
// The scheduled sync remains as a safety-net for missed or failed requests.
exports.syncQueuedWordPressLabelProducts = onDocumentCreated(
  {
    document: 'label_product_sync_requests/{requestId}',
    database: 'hungarian-hardstyle',
    region: 'us-central1',
    secrets: labelProductSyncSecrets,
  },
  async (event) => {
    const request = event.data?.data() || {};
    const releaseId = Number(request.releaseId || 0);
    if (!Number.isInteger(releaseId) || releaseId < 1) return;
    const result = await syncWordPressLabelProducts(releaseId);
    console.info('label_product_sync_queued_request', { releaseId, result });
  },
);

exports.getLabelAdUnlockStatus = functions.runWith({ enforceAppCheck: false }).https.onCall(async (data, context) => {
  if (!context.auth || context.auth.token.firebase?.sign_in_provider === 'anonymous') {
    throw new HttpsError('unauthenticated', 'Bejelentkezés szükséges.');
  }
  if (!(await allowCall(context.auth.uid, 'label_ad_unlock_status', 40))) {
    throw new HttpsError('resource-exhausted', 'Túl sok feloldási ellenőrzés.');
  }
  const releaseId = Number(data?.releaseId || 0);
  const variant = String(data?.variant || 'mp3_128').trim();
  if (!['free_wav', 'free_link', 'mp3_96', 'mp3_128'].includes(variant)) {
    throw new HttpsError('invalid-argument', 'Érvénytelen reklámos feloldási változat.');
  }
  if (!Number.isInteger(releaseId) || releaseId < 1) {
    throw new HttpsError('invalid-argument', 'Érvénytelen release azonosító.');
  }
  const snapshot = await db.collection('label_ad_unlocks').doc(`${context.auth.uid}_${releaseId}`).get();
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
    const signatureBytes = [Buffer.from(signature, 'base64url'), Buffer.from(signature, 'base64')];
    const normalizedSignature = signature.replace(/-/g, '+').replace(/_/g, '/');
    const publicKeys = [key.pem];
    if (key.base64) {
      publicKeys.push(
        crypto.createPublicKey({
          key: Buffer.from(key.base64, 'base64'),
          format: 'der',
          type: 'spki',
        }),
      );
    }
    const queryFromUrl = requestUrl.split('?')[1] || '';
    const urlSignatureMatch = /(?:^|&)signature=([^&]*)/.exec(queryFromUrl);
    const verificationInputs = [
      { label: 'original-excluding-separator', value: signedQuery },
      ...(urlSignatureMatch
        ? [
            {
              label: 'url-excluding-separator',
              value: queryFromUrl.slice(0, urlSignatureMatch.index),
            },
          ]
        : []),
    ];
    const decodeQuery = (value) =>
      value
        .split('&')
        .map((part) => {
          const separator = part.indexOf('=');
          if (separator < 0) return decodeURIComponent(part);
          return `${decodeURIComponent(part.slice(0, separator))}=${decodeURIComponent(part.slice(separator + 1))}`;
        })
        .join('&');
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
    if (
      !uid ||
      !Number.isInteger(releaseId) ||
      releaseId < 1 ||
      !['free_wav', 'free_link', 'mp3_96', 'mp3_128'].includes(variant)
    )
      return reject('invalid reward data');
    const transaction = db.collection('admob_reward_transactions').doc(transactionId);
    await db.runTransaction(async (tx) => {
      if ((await tx.get(transaction)).exists) return;
      const unlockRef = db.collection('label_ad_unlocks').doc(`${uid}_${releaseId}`);
      const unlock = await tx.get(unlockRef);
      const existingVariants =
        unlock.exists && unlock.data()?.variants && typeof unlock.data().variants === 'object'
          ? unlock.data().variants
          : {};
      tx.set(transaction, {
        uid,
        releaseId,
        createdAt: FieldValue.serverTimestamp(),
      });
      tx.set(
        unlockRef,
        {
          uid,
          releaseId,
          transactionId,
          variants: { ...existingVariants, [variant]: true },
          unlockedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    });
    return res.status(200).send('ok');
  } catch (error) {
    console.warn(
      JSON.stringify({
        event: 'admob_ssv_failed',
        message: String(error?.message || error),
      }),
    );
    return res.status(400).send('invalid callback');
  }
});

exports.getVotingSummary = functions.runWith({ enforceAppCheck: false }).https.onCall(async (data, context) => {
  if (!context.auth) throw new HttpsError('permission-denied', 'Csak admin tekintheti meg az összesítőt.');
  const profile = (await db.collection('community_profiles').doc(context.auth.uid).get()).data() || {};
  if (!isAdmin(context, profile)) throw new HttpsError('permission-denied', 'Csak admin tekintheti meg az összesítőt.');
  const seasonId = Number(data?.seasonId);
  if (!Number.isInteger(seasonId) || seasonId <= 0)
    throw new HttpsError('invalid-argument', 'Érvényes szezon szükséges.');
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

const VOTING_REQUIRED_COUNTS = Object.freeze({
  hungarian_hardstyle_dj: 5,
  hungarian_hardcore_dj: 3,
  hungarian_track: 2,
  hungarian_organizer: 1,
  international_dj: 5,
});

function requireVotingUser(context) {
  if (!context.auth?.uid) {
    throw new HttpsError('unauthenticated', 'A szavazáshoz az appnak azonosítania kell a felhasználót.');
  }
  return context.auth.uid;
}

function normalizeVotingDeviceId(rawDeviceId) {
  const value = String(rawDeviceId || '').trim();
  if (!/^[A-Za-z0-9_-]{24,128}$/.test(value)) {
    throw new HttpsError('invalid-argument', 'Érvényes készülékazonosító szükséges.');
  }
  return value;
}

function votingDeviceIdForRequest(context, rawDeviceId) {
  const value = String(rawDeviceId || '').trim();
  if (!value && context.auth.token.firebase?.sign_in_provider !== 'anonymous') {
    // Keep already released registered clients compatible until they receive
    // the build that starts sending the installation ID.
    return `legacy-user-${context.auth.uid}`;
  }
  return normalizeVotingDeviceId(value);
}

function votingDeviceRef(seasonId, deviceId) {
  const deviceHash = crypto.createHash('sha256').update(deviceId).digest('hex').slice(0, 40);
  return db.collection('voting_device_claims').doc(`${seasonId}_${deviceHash}`);
}

function normalizeVotingBallot(rawVotes) {
  if (!rawVotes || typeof rawVotes !== 'object' || Array.isArray(rawVotes)) {
    throw new HttpsError('invalid-argument', 'Érvényes szavazólap szükséges.');
  }
  const votes = {};
  for (const [category, rawIds] of Object.entries(rawVotes)) {
    if (!Object.prototype.hasOwnProperty.call(VOTING_REQUIRED_COUNTS, category)) {
      throw new HttpsError('invalid-argument', 'Ismeretlen szavazási kategória.');
    }
    if (!Array.isArray(rawIds)) throw new HttpsError('invalid-argument', 'A jelöltek listája érvénytelen.');
    const ids = rawIds.map(Number);
    const required = VOTING_REQUIRED_COUNTS[category];
    if (
      ids.length !== required ||
      ids.some((id) => !Number.isSafeInteger(id) || id <= 0) ||
      new Set(ids).size !== ids.length
    ) {
      throw new HttpsError(
        'invalid-argument',
        `${category} kategóriában pontosan ${required} különböző jelölt szükséges.`,
      );
    }
    votes[category] = ids;
  }
  return votes;
}

exports.getVotingStatus = functions.runWith({ enforceAppCheck: false }).https.onCall(async (data, context) => {
  const uid = requireVotingUser(context);
  const seasonId = Number(data?.seasonId);
  if (!Number.isSafeInteger(seasonId) || seasonId <= 0)
    throw new HttpsError('invalid-argument', 'Érvényes szezon szükséges.');
  const deviceId = votingDeviceIdForRequest(context, data?.deviceId);
  const categories = Object.keys(VOTING_REQUIRED_COUNTS);
  const refs = categories.map((category) => db.collection('voting_votes').doc(`${seasonId}_${category}_${uid}`));
  const [voteSnapshots, deviceSnapshot] = await Promise.all([
    Promise.all(refs.map((ref) => ref.get())),
    votingDeviceRef(seasonId, deviceId).get(),
  ]);
  const votedCategories = new Set();
  const selectedCandidateIds = {};
  voteSnapshots.forEach((snapshot, index) => {
    if (snapshot.exists) {
      const category = categories[index];
      votedCategories.add(category);
      const ids = snapshot.data()?.candidateIds;
      if (Array.isArray(ids)) {
        selectedCandidateIds[category] = ids.map(Number).filter((id) => Number.isSafeInteger(id) && id > 0);
      }
    }
  });
  const deviceData = deviceSnapshot.exists ? deviceSnapshot.data() || {} : {};
  const deviceCategories = Array.isArray(deviceData.categories) ? deviceData.categories : [];
  deviceCategories.forEach((category) => {
    if (Object.prototype.hasOwnProperty.call(VOTING_REQUIRED_COUNTS, category)) {
      votedCategories.add(category);
      const ids = deviceData.selections?.[category];
      if (!selectedCandidateIds[category] && Array.isArray(ids)) {
        selectedCandidateIds[category] = ids.map(Number).filter((id) => Number.isSafeInteger(id) && id > 0);
      }
    }
  });
  return {
    seasonId,
    votedCategories: [...votedCategories],
    selectedCandidateIds,
  };
});

exports.submitVotingBallot = functions.runWith({ enforceAppCheck: false }).https.onCall(async (data, context) => {
  const uid = requireVotingUser(context);
  const seasonId = Number(data?.seasonId);
  if (!Number.isSafeInteger(seasonId) || seasonId <= 0)
    throw new HttpsError('invalid-argument', 'Érvényes szezon szükséges.');
  const deviceId = votingDeviceIdForRequest(context, data?.deviceId);
  const votes = normalizeVotingBallot(data?.votes);
  const refs = Object.keys(VOTING_REQUIRED_COUNTS).map((category) => ({
    category,
    ref: db.collection('voting_votes').doc(`${seasonId}_${category}_${uid}`),
  }));
  const deviceRef = votingDeviceRef(seasonId, deviceId);
  const createdCategories = [];
  let ballotComplete = false;
  await db.runTransaction(async (transaction) => {
    const current = new Map();
    for (const item of refs) current.set(item.category, await transaction.get(item.ref));
    const deviceClaim = await transaction.get(deviceRef);
    const deviceData = deviceClaim.exists ? deviceClaim.data() || {} : {};
    const selections =
      deviceData.selections && typeof deviceData.selections === 'object' ? { ...deviceData.selections } : {};
    const claimedCategories = new Set(
      Array.isArray(deviceData.categories)
        ? deviceData.categories.filter((category) =>
            Object.prototype.hasOwnProperty.call(VOTING_REQUIRED_COUNTS, category),
          )
        : [],
    );
    if (deviceClaim.exists && deviceData.userId && deviceData.userId !== uid) {
      throw new HttpsError('already-exists', 'Erről a készülékről erre az évadra már érkezett szavazat.');
    }
    const missing = refs
      .filter(
        (item) => !current.get(item.category).exists && !claimedCategories.has(item.category) && !votes[item.category],
      )
      .map((item) => item.category);
    if (missing.length) {
      throw new HttpsError('invalid-argument', `Hiányzó kötelező kategória: ${missing.join(', ')}.`);
    }
    for (const item of refs) {
      if (!votes[item.category]) continue;
      if (current.get(item.category).exists || claimedCategories.has(item.category)) {
        throw new HttpsError('already-exists', 'Ebben az éves szavazásban már szavaztál.');
      }
      transaction.create(item.ref, {
        seasonId,
        category: item.category,
        candidateIds: votes[item.category],
        userId: uid,
        createdAt: FieldValue.serverTimestamp(),
      });
      selections[item.category] = votes[item.category];
      createdCategories.push(item.category);
    }
    const allCategories = [
      ...new Set([
        ...claimedCategories,
        ...refs.filter((item) => current.get(item.category).exists).map((item) => item.category),
        ...createdCategories,
      ]),
    ];
    ballotComplete = refs.every((item) => allCategories.includes(item.category));
    transaction.set(
      deviceRef,
      {
        seasonId,
        userId: uid,
        categories: allCategories,
        createdAt: deviceClaim.exists
          ? deviceData.createdAt || FieldValue.serverTimestamp()
          : FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        selections,
      },
      { merge: true },
    );
  });
  const isRegistered = context.auth.token.firebase?.sign_in_provider !== 'anonymous';
  let achievement = { changed: false };
  if (ballotComplete && isRegistered) {
    achievement = await awardAchievementPoints(uid, 10, `voting:${seasonId}`);
  }
  return {
    ok: true,
    seasonId,
    createdCategories,
    achievementPoints: achievement.changed ? 10 : 0,
  };
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
    console.log(
      JSON.stringify({
        event: 'connection_request_received',
        status: request.status || null,
      }),
    );
    if (!request.from || !request.to) return null;
    const from = String(request.from);
    const to = String(request.to);
    const beforeStatus = String(before.status || '');

    if (request.status === 'accepted') {
      // The accepter's status transition is the single source of truth. The
      // deterministic notification key keeps Firestore and push delivery
      // idempotent when the trigger is retried.
      if (beforeStatus === 'accepted') return null;
      const accepter = (await db.collection('community_profiles').doc(to).get()).data() || {};
      const name = String(accepter.displayName || 'Egy felhasználó').trim();
      const title = 'Ismerős-jelölés elfogadva';
      const body = `${name} elfogadta az ismerős-jelölésedet.`;
      const created = await createNotificationBestEffort({
        recipientUid: from,
        type: 'connection_accepted',
        title,
        body,
        targetType: 'profile',
        targetId: to,
        dedupeKey: `connection_accepted:${requestId}`,
      });
      if (!created) return null;
      const tokens = await getPushTokens(from);
      if (!tokens.length) return null;
      const result = await sendMulticastToAllTokens(
        {
          notification: { title, body },
          data: { type: 'connection_accepted', targetId: to },
        },
        tokens,
      );
      const invalidTokens = tokens.filter((_, index) => {
        const error = result.responses[index].error;
        return error?.code === 'messaging/registration-token-not-registered';
      });
      if (invalidTokens.length) await removePushTokens(from, invalidTokens);
      return result;
    }

    if (request.status !== 'pending') return null;
    const beforeNotification = before.notificationRequestedAt?.toMillis?.();
    const notification = request.notificationRequestedAt?.toMillis?.();
    if (!notification || beforeNotification === notification) return null;
    const sender = (await db.collection('community_profiles').doc(from).get()).data() || {};
    const name = String(sender.displayName || 'Egy felhasználó').trim();
    await createNotificationBestEffort({
      recipientUid: to,
      type: 'connection_request',
      title: 'Új ismerősnek jelölés',
      body: `${name} ismerősnek jelölt.`,
      targetType: 'profile',
      targetId: from,
      dedupeKey: `connection_request:${requestId}:${notification}`,
    });
    const uniqueTokens = await getPushTokens(to);
    if (!uniqueTokens.length) {
      console.warn(
        JSON.stringify({
          event: 'connection_request_no_target_token',
          requestId,
        }),
      );
      return null;
    }
    const result = await sendMulticastToAllTokens(
      {
        notification: {
          title: 'Új ismerősnek jelölés',
          body: `${name} ismerősnek jelölt.`,
        },
        data: { type: 'connection_request', senderId: from },
      },
      uniqueTokens,
    );
    console.log(
      JSON.stringify({
        event: 'connection_request_push_result',
        requestId,
        tokenCount: uniqueTokens.length,
        successCount: result.successCount,
        failureCount: result.failureCount,
        failures: result.responses
          .filter((response) => !response.success)
          .map((response) => ({
            code: response.error?.code || 'unknown',
            message: response.error?.message || '',
          })),
      }),
    );
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
    const beforeInterested = before.interestedBy && typeof before.interestedBy === 'object' ? before.interestedBy : {};
    const afterInterested = after.interestedBy && typeof after.interestedBy === 'object' ? after.interestedBy : {};
    const newInterests = Object.keys(afterInterested).filter(
      (uid) => afterInterested[uid] === true && beforeInterested[uid] !== true,
    );
    if (!meetupUserId || !eventId || !newInterests.length) return null;

    const targetBlocked = await db.collection('community_profiles').doc(meetupUserId).collection('blocked_users').get();
    const blockedIds = new Set(targetBlocked.docs.map((doc) => doc.id));
    const targetTokens = await getPushTokens(meetupUserId);
    const eventTitle = String(after.eventTitle || 'az esemény').trim();
    const results = [];
    for (const senderId of newInterests) {
      if (senderId === meetupUserId || blockedIds.has(senderId)) continue;
      const reverseBlocked = await db
        .collection('community_profiles')
        .doc(senderId)
        .collection('blocked_users')
        .doc(meetupUserId)
        .get();
      if (reverseBlocked.exists) continue;
      const sender = (await db.collection('community_profiles').doc(senderId).get()).data() || {};
      const senderName = String(sender.displayName || 'Egy felhasználó').trim();
      await createNotificationBestEffort({
        recipientUid: meetupUserId,
        type: 'meetup_interest',
        title: 'Új Meetup érdeklődés',
        body: `${senderName} szívesen találkozna veled a(z) ${eventTitle} eseményen.`,
        targetType: 'event',
        targetId: eventId,
        dedupeKey: `meetup_interest:${eventId}:${meetupUserId}:${senderId}`,
      });
      if (!targetTokens.length) continue;
      const result = await sendMulticastToAllTokens(
        {
          notification: {
            title: 'Új Meetup érdeklődés',
            body: `${senderName} szívesen találkozna veled a(z) ${eventTitle} eseményen.`,
          },
          data: {
            type: 'meetup_interest',
            senderId,
            eventId,
          },
        },
        targetTokens,
      );
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
    const imageUrl = String(message.imageUrl || '').trim();
    if (!senderId || !recipientId || !conversationId || (!text && !imageUrl) || senderId === recipientId) {
      return null;
    }
    const notificationBody = text || 'Képet küldött.';

    const conversation = (await db.collection('private_conversations').doc(conversationId).get()).data() || {};
    const participantIds = Array.isArray(conversation.participantIds)
      ? conversation.participantIds.map((id) => String(id))
      : [];
    if (!participantIds.includes(senderId) || !participantIds.includes(recipientId)) {
      console.warn(
        JSON.stringify({
          event: 'private_message_invalid_participants',
          conversationId,
        }),
      );
      return null;
    }

    const participantNames = conversation.participantNames || {};
    const senderName = String(participantNames[senderId] || 'Egy felhasználó').trim();
    const [blockedBySender, blockedByRecipient] = await Promise.all([
      db.collection('community_profiles').doc(senderId).collection('blocked_users').doc(recipientId).get(),
      db.collection('community_profiles').doc(recipientId).collection('blocked_users').doc(senderId).get(),
    ]);
    if (blockedBySender.exists || blockedByRecipient.exists) return null;
    await createNotificationBestEffort({
      recipientUid: recipientId,
      type: 'private_message',
      title: `${senderName || 'Egy felhasználó'} üzenetet küldött`,
      body: notificationBody,
      targetType: 'private_conversation',
      targetId: conversationId,
      senderId,
      dedupeKey: `private_message:${conversationId}:${event.params.messageId}`,
    });
    const uniqueTokens = await getPushTokens(recipientId);
    if (!uniqueTokens.length) {
      console.log(
        JSON.stringify({
          event: 'private_message_no_target_token',
          conversationId,
        }),
      );
      return null;
    }
    const result = await sendMulticastToAllTokens(
      {
        notification: {
          title: `${senderName || 'Egy felhasználó'} üzenetet küldött`,
          body: notificationBody.slice(0, 160),
        },
        data: {
          type: 'private_message',
          conversationId,
          senderId,
        },
      },
      uniqueTokens,
    );
    console.log(
      JSON.stringify({
        event: 'private_message_push_result',
        conversationId,
        tokenCount: uniqueTokens.length,
        successCount: result.successCount,
        failureCount: result.failureCount,
      }),
    );

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
        const email = String(profile.email || '')
          .trim()
          .toLowerCase();
        return email === ADMIN_EMAIL || profile.accessRole === 'admin' || profile.accessRole === 'moderator';
      })
      .map((profileDoc) => profileDoc.id);

    const reporterName = String(report.reporterName || 'Egy felhasználó').trim();
    const reason = String(report.reason || '').trim();
    await Promise.all(
      recipientIds.map((recipientUid) =>
        createNotificationBestEffort({
          recipientUid,
          type: 'chat_report',
          title: 'Új chatjelentés',
          body: reason ? `${reporterName}: ${reason}` : `${reporterName} új chatjelentést küldött.`,
          targetType: 'chat_report',
          targetId: reportId,
          dedupeKey: `chat_report:${reportId}:${recipientUid}`,
        }),
      ),
    );
    const tokenLists = await Promise.all(recipientIds.map((uid) => getPushTokens(uid)));
    const uniqueTokens = [
      ...new Set(
        tokenLists
          .flat()
          .map((token) => token.trim())
          .filter(Boolean),
      ),
    ];
    if (!uniqueTokens.length) {
      console.log(JSON.stringify({ event: 'chat_report_no_recipient_token', reportId }));
      return null;
    }
    const result = await sendMulticastToAllTokens(
      {
        notification: {
          title: 'Új chatjelentés',
          body: reason ? `${reporterName}: ${reason}`.slice(0, 160) : `${reporterName} új chatjelentést küldött.`,
        },
        data: {
          type: 'chat_report',
          reportId,
        },
      },
      uniqueTokens,
    );

    const invalidTokens = uniqueTokens.filter(
      (_, index) => result.responses[index].error?.code === 'messaging/registration-token-not-registered',
    );
    if (invalidTokens.length) {
      await Promise.all(recipientIds.map((uid) => removePushTokens(uid, invalidTokens)));
    }

    console.log(
      JSON.stringify({
        event: 'chat_report_push_result',
        reportId,
        recipientCount: recipientIds.length,
        tokenCount: uniqueTokens.length,
        successCount: result.successCount,
        failureCount: result.failureCount,
      }),
    );
    return result;
  },
);
