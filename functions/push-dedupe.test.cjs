const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

/**
 * A DUPLA PUSH bizonyítása — a Cloud Function-ök oldalán.
 *
 * A tulajdonos jelzése: „nézzünk rá arra, hogy LEHETSÉGES, némelyik push kétszer
 * megy ki". A mérés a naplókban megtalálta: ugyanarra a beszélgetésre **5–7
 * ezredmásodpercen belül kétszer** futott le a küldés
 * (`node tools/check-push-duplicates.mjs`).
 *
 * A gyökér a Firestore-triggerek **legalább egyszer** (at-least-once)
 * kézbesítése: ugyanaz az esemény kétszer is lefuthat. Az értesítés-felismerés
 * (`dedupeKey`) ezt eddig is kezelte — a PUSH viszont nem: a bejegyzés már
 * megvolt, de a push újra kiment. Az ismerős-jelölésnél ez a védelem **már
 * megvolt** (`if (!created) return null;`), a meetupnál, a privát üzenetnél és a
 * chatjelentésnél viszont nem.
 *
 * Ez a teszt a VALÓDI függvényeket futtatja a Firestore-emulátoron, csak a
 * küldést helyettesíti — és kétszer adja le ugyanazt az eseményt, pontosan úgy,
 * ahogy egy újrakézbesítés teszi.
 *
 * Futtatás (a repository gyökeréből):
 *   npx firebase emulators:exec --only firestore --project demo-huhs \
 *     "node functions/push-dedupe.test.cjs"
 */

const projectId = process.env.GCLOUD_PROJECT || 'demo-huhs';
const databaseId = 'hungarian-hardstyle';

const app = initializeApp({ projectId });
const db = getFirestore(app, databaseId);

const {
  __pushNotifyForTests: pushNotify,
} = require('./index.js');

const ADMIN_EMAIL = 'djdeeroy@gmail.com';

function fakePush() {
  const calls = [];
  return {
    calls,
    send: async (message, tokens) => {
      calls.push({ message, tokens });
      return {
        successCount: tokens.length,
        failureCount: 0,
        responses: tokens.map(() => ({ success: true })),
      };
    },
  };
}

function privateMessageEvent({ conversationId, messageId, senderId, recipientId, text = 'Szia!' }) {
  return {
    params: { conversationId, messageId },
    data: { data: () => ({ senderId, recipientId, text }) },
  };
}

function meetupEvent({ eventId, meetupUserId, senderId, before = {}, after }) {
  return {
    params: { eventId, meetupUserId },
    data: {
      before: { data: () => before },
      after: { data: () => after },
    },
  };
}

function chatReportEvent({ reportId, reporterName = 'Teszt Elek', reason = 'spam' }) {
  return {
    params: { reportId },
    data: { data: () => ({ reporterName, reason }) },
  };
}

async function cleanup(ids) {
  for (const path of ids) {
    const parts = path.split('/');
    if (parts.length === 1) {
      const snapshot = await db.collection(parts[0]).get();
      await Promise.all(snapshot.docs.map((doc) => doc.ref.delete()));
    } else {
      await db.doc(path).delete().catch(() => {});
      const snapshot = await db.collection(path).get().catch(() => null);
      if (snapshot) await Promise.all(snapshot.docs.map((doc) => doc.ref.delete()));
    }
  }
}

let conversationId;
let senderId;
let recipientId;
let meetupEventId;
let meetupUserId;
let adminUid;

before(async () => {
  conversationId = 'pushdedupe-conversation';
  senderId = 'pushdedupe-sender';
  recipientId = 'pushdedupe-recipient';
  meetupEventId = 'pushdedupe-event';
  meetupUserId = 'pushdedupe-meetup-user';
  adminUid = 'pushdedupe-admin';

  await db.collection('private_conversations').doc(conversationId).set({
    participantIds: [senderId, recipientId],
    participantNames: { [senderId]: 'Küldő Béla', [recipientId]: 'Fogadó Anna' },
  });
  await db.collection('private_user_data').doc(recipientId).set(
    { fcmTokens: ['token-recipient'] },
    { merge: true },
  );
  await db.collection('private_user_data').doc(adminUid).set(
    { fcmTokens: ['token-admin'] },
    { merge: true },
  );
  await db.collection('community_profiles').doc(adminUid).set({
    email: ADMIN_EMAIL,
    displayName: 'Teszt Admin',
    achievementPoints: 0,
    updatedAt: FieldValue.serverTimestamp(),
  });
  await db.collection('community_profiles').doc(senderId).set({
    displayName: 'Küldő Béla',
    achievementPoints: 0,
    updatedAt: FieldValue.serverTimestamp(),
  });
});

after(async () => {
  await cleanup([
    'notifications',
    'private_user_data',
    'community_profiles',
    'event_meetups',
    'chat_reports',
  ]);
  await db.recursiveDelete(db.collection('private_conversations').doc(conversationId)).catch(() => {});
});

test('privát üzenet: az újrakézbesítés NEM küld második push-t', async () => {
  const messageId = `msg-${Date.now()}`;
  const event = privateMessageEvent({ conversationId, messageId, senderId, recipientId });
  const push = fakePush();
  const deps = { sendPush: push.send, pushTokens: async () => ['token-recipient'], removeTokens: async () => {} };

  const first = await pushNotify.handlePrivateMessageNotification(event, deps);
  assert.ok(first, 'az első kézbesítés elküldi a push-t');
  assert.equal(push.calls.length, 1, 'egyszer küldött');

  // UGYANAZ az esemény mégegyszer = trigger-újrakézbesítés.
  const second = await pushNotify.handlePrivateMessageNotification(event, deps);
  assert.equal(second, null, 'a második kézbesítés nem csinál semmit');
  assert.equal(push.calls.length, 1, 'a push NEM ment ki kétszer');
});

test('privát üzenet: két KÜLÖN üzenet két push (a védelem nem blokkol túl)', async () => {
  const push = fakePush();
  const deps = { sendPush: push.send, pushTokens: async () => ['token-recipient'], removeTokens: async () => {} };
  await pushNotify.handlePrivateMessageNotification(
    privateMessageEvent({ conversationId, messageId: `a-${Date.now()}`, senderId, recipientId }),
    deps,
  );
  await pushNotify.handlePrivateMessageNotification(
    privateMessageEvent({ conversationId, messageId: `b-${Date.now()}`, senderId, recipientId }),
    deps,
  );
  assert.equal(push.calls.length, 2, 'két üzenet = két értesítés');
});

test('chatjelentés: az újrakézbesítés NEM küld második push-t', async () => {
  const reportId = `report-${Date.now()}`;
  const event = chatReportEvent({ reportId });
  const push = fakePush();
  const deps = { sendPush: push.send, pushTokens: async (uid) => [`token-${uid}`], removeTokens: async () => {} };

  const first = await pushNotify.handleChatReportNotification(event, deps);
  assert.ok(first, 'az első kézbesítés elküldi a push-t');
  const afterFirst = push.calls.length;

  const second = await pushNotify.handleChatReportNotification(event, deps);
  assert.equal(second, null, 'a második kézbesítés nem csinál semmit');
  assert.equal(push.calls.length, afterFirst, 'a push NEM ment ki kétszer');
});

test('meetup-érdeklődés: az újrakézbesítés NEM küld második push-t', async () => {
  const sender = 'pushdedupe-interested';
  const before = { eventTitle: 'Teszt fesztivál', interestedBy: {} };
  const after = { eventTitle: 'Teszt fesztivál', interestedBy: { [sender]: true } };
  const event = meetupEvent({ eventId: meetupEventId, meetupUserId, senderId: sender, before, after });
  const push = fakePush();
  const deps = { sendPush: push.send, pushTokens: async () => ['token-meetup'] };

  const first = await pushNotify.handleMeetupInterestNotification(event, deps);
  assert.ok(first && first.successCount === 1, 'az első kézbesítés elküldi a push-t');

  // Újrakézbesítés: ugyanaz a before/after pár.
  const second = await pushNotify.handleMeetupInterestNotification(event, deps);
  assert.equal(push.calls.length, 1, 'a push NEM ment ki kétszer');
  assert.ok(second && second.successCount === 0, 'a második kézbesítés nem küld semmit');
});

test('a napló viszi az ÜZENET azonosítóját (a dupla bizonyítható)', () => {
  const source = require('node:fs').readFileSync(require('node:path').join(__dirname, 'index.js'), 'utf8');
  const block = source.slice(
    source.indexOf("event: 'private_message_push_result'"),
    source.indexOf("event: 'private_message_push_result'") + 200,
  );
  assert.match(block, /messageId/, 'a küldés naplója tartalmazza a messageId-t');
});

test('minden push-útvonal védett a dupla küldés ellen (nincs kivétel)', () => {
  const source = require('node:fs').readFileSync(require('node:path').join(__dirname, 'index.js'), 'utf8');
  // Minden értesítés-küldő út kapuját név szerint kérjük számon. Kétféle védelem
  // van, és mindkettő elfogadható — de az útnak az EGYIKET tartalmaznia kell:
  //   * `created` kapu: az értesítés csak most jött létre (a trigger
  //     újrakézbesítése nem megy át rajta);
  //   * állapotváltás-kapu: az esemény csak akkor számít, ha az állapot TÉNYLEG
  //     megváltozott (újrakézbesítésnél a `before` és az `after` ugyanaz).
  const routes = [
    { marker: 'connection_accepted:', gate: /if \(!created\) return null;/ },
    { marker: 'connection_request:', gate: /beforeNotification === notification/ },
    { marker: 'meetup_interest:', gate: /if \(!created\) continue;/ },
    { marker: 'private_message:', gate: /if \(!created\) return null;/ },
    { marker: 'chat_report:', gate: /!created\.some\(Boolean\)/ },
    {
      marker: 'event-rating-request:',
      // Itt a kulcs külön változóban készül, ezért a keresés a forrására megy.
      search: 'event-rating-request:',
      gate: /if \(!notificationCreated\) continue;/,
    },
  ];
  for (const route of routes) {
    const needle = route.search || `dedupeKey: \`${route.marker}`;
    const index = source.indexOf(needle);
    assert.ok(index > 0, `${route.marker} megtalálható a kódban`);
    const window = source.slice(Math.max(0, index - 1200), index + 1200);
    assert.match(
      window,
      route.gate,
      `${route.marker} előtt ott a dupla küldés elleni kapu`,
    );
  }
});

test('minden push-hívás a naplózott közös helperen megy (nincs néma második út)', () => {
  const source = require('node:fs').readFileSync(require('node:path').join(__dirname, 'index.js'), 'utf8');
  // A küldést végző helper hívásainak mindegyike egy értesítés-küldő úthoz
  // tartozik; a `sendEachForMulticast` közvetlen hívása tilos (egy helyen van).
  const direct = source.split('sendEachForMulticast(').length - 1;
  assert.equal(direct, 1, 'csak a közös helper hívja a Firebase API-t');
});
