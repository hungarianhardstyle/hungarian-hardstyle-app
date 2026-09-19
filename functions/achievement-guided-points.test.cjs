const { test, before } = require('node:test');
const assert = require('node:assert/strict');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

/**
 * A KÉT „hiányzó" pontforrás VALÓDI viselkedése.
 *
 * A tulajdonos jelzése: az Achievement-útmutatóban szerepelt „Kiadvány
 * megvásárlása +20 pont" és „Közösségi aktivitás +5–20 pont", de a kódban
 * **nem volt mögöttük szabály** — a tulajdonos döntése: „azoknak léteznie kéne".
 * Mostantól élnek:
 *
 *  1. **Kiadvány-vásárlás:** a `verifyLabelPurchase` a Google Play APIn
 *     ellenőrzi a vásárlást, és **minden megvásárolt változat** +20 pontot ér
 *     (`release-purchase:<productId>`), egyszer.
 *  2. **Jóváhagyott beküldés:** a beküldött esemény/DJ/szervező **jóváhagyásakor**
 *     a beküldő +10 pontot kap (`submission:<kind>:<wpId>`), **napi legfeljebb 3**
 *     beküldésért — mert a beküldések száma a felhasználó kezében van.
 *  3. **Napi aktivitási pont (1–5):** a tulajdonos kérése — *„arra is kéne 1-5
 *     achievement pont naponta, ha valaki kommentel egy cikkhez, ír a chatre;
 *     ezt döntse el a szerver, mennyit aktívkodott és úgy ossza ki"*. A szerver
 *     a LEZÁRT napot értékeli (hozzászólás × 2 + chat-üzenet), sávosan oszt
 *     1–5 pontot, és egy napra egyszer fizet (`daily-activity:<dátum>`).
 *
 * Futtatás (a repository gyökeréből):
 *   npx firebase emulators:exec --only firestore --project demo-huhs \
 *     "node functions/achievement-guided-points.test.cjs"
 */

const projectId = process.env.GCLOUD_PROJECT || 'demo-huhs';
const databaseId = 'hungarian-hardstyle';

const app = initializeApp({ projectId });
const db = getFirestore(app, databaseId);

const {
  __awardApprovedSubmissionPointsForTests: awardSubmission,
  __awardReleasePurchasePointsForTests: awardPurchase,
  __achievementPointsForTests: pointValues,
  __achievementDailyLimitsForTests: limits,
  __dailyActivityPointsForTests: dailyPoints,
  __recordDailyActivityForTests: recordDailyActivity,
  __awardDailyActivityForDayForTests: awardDailyActivity,
} = require('./index.js');

function todayKey() {
  return new Date().toISOString().slice(0, 10);
}

async function seedProfile(uid) {
  await db.collection('community_profiles').doc(uid).set(
    {
      uid,
      displayName: `guided-test-${uid.slice(0, 8)}`,
      achievementPoints: 0,
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
}

async function pointsOf(uid) {
  const profile = await db.collection('community_profiles').doc(uid).get();
  return Number(profile.data()?.achievementPoints || 0);
}

async function seedSubmissionAuthor(wpId, uid, kind = 'event') {
  await db.collection('submission_authors').doc(String(wpId)).set({
    uid,
    kind,
    title: `teszt beküldés ${wpId}`,
    createdAt: FieldValue.serverTimestamp(),
  });
}

async function cleanup(uid) {
  await db.collection('community_profiles').doc(uid).delete().catch(() => {});
  for (const name of [
    'achievement_ledger',
    'achievement_submission_limits',
    'daily_activity',
    'notifications',
  ]) {
    const snapshot = await db
      .collection(name)
      .where(name === 'notifications' ? 'recipientUid' : 'uid', '==', uid)
      .get()
      .catch(() => null);
    if (snapshot) for (const document of snapshot.docs) await document.ref.delete().catch(() => {});
  }
}

before(async () => {
  assert.ok(
    process.env.FIRESTORE_EMULATOR_HOST,
    'Ez a teszt Firestore-emulatort igenyel (FIRESTORE_EMULATOR_HOST).',
  );
});

test('a pontértékek és a napi keret a tulajdonos döntése szerint', () => {
  assert.equal(pointValues.approvedSubmission, 10);
  assert.equal(pointValues.releasePurchase, 20);
  assert.equal(limits.submission, 3);
});

test('jóváhagyott beküldés: a BEKÜLDŐ kap +10 pontot, indoklással', async () => {
  const uid = 'guided-submission-1';
  await seedProfile(uid);
  await seedSubmissionAuthor(7001, uid, 'event');

  const result = await awardSubmission(7001);
  assert.equal(result.changed, true);
  assert.equal(await pointsOf(uid), 10);

  const ledger = await db.collection('achievement_ledger').where('uid', '==', uid).get();
  const rows = ledger.docs.map((document) => document.data());
  assert.equal(rows.length, 1);
  assert.equal(rows[0].sourceKey, 'submission:event:7001');
  assert.equal(rows[0].state, 'granted');

  const notifications = await db.collection('notifications').where('recipientUid', '==', uid).get();
  assert.equal(notifications.size, 1);
  const body = String(notifications.docs[0].data().body || '');
  assert.match(body, /jóváhagyott beküldésedért/, 'az értesítés megmondja, miért jár a pont');

  await cleanup(uid);
});

test('ugyanaz a beküldés kétszer jóváhagyva sem ad kétszer pontot', async () => {
  const uid = 'guided-submission-2';
  await seedProfile(uid);
  await seedSubmissionAuthor(7002, uid, 'artist');

  assert.equal((await awardSubmission(7002)).changed, true);
  const again = await awardSubmission(7002);
  assert.equal(again.changed, false, 'a naplókulcs a beküldés azonosítója, ezért egyszer jár');
  assert.equal(await pointsOf(uid), 10);

  await cleanup(uid);
});

test('a napi keret a beküldésekre is fog: a 4. már nem ad pontot', async () => {
  const uid = 'guided-submission-3';
  await seedProfile(uid);
  for (const wpId of [7101, 7102, 7103]) {
    await seedSubmissionAuthor(wpId, uid, 'event');
    assert.equal((await awardSubmission(wpId)).changed, true, `a(z) ${wpId} beküldés pontot ad`);
  }
  assert.equal(await pointsOf(uid), 30);

  await seedSubmissionAuthor(7104, uid, 'event');
  const blocked = await awardSubmission(7104);
  assert.equal(blocked.changed, false, 'a napi 3 beküldés után nem jár több pont');
  assert.equal(await pointsOf(uid), 30);

  const counter = await db
    .collection('achievement_submission_limits')
    .doc(`${uid}_${todayKey()}`)
    .get();
  assert.equal(Number(counter.data()?.count || 0), 3);
  assert.equal(Number(counter.data()?.date ? 1 : 0), 1, 'a számláló naplózza a napot');

  // A profilban is megjelenik a keret állapota (a kliens jelzéseihez).
  const profile = await db.collection('community_profiles').doc(uid).get();
  const mirror = profile.data()?.achievementDailyLimit;
  assert.equal(mirror?.kind, 'submission');
  assert.equal(mirror?.limit, 3);
  assert.equal(mirror?.count, 3);

  await cleanup(uid);
});

test('ismeretlen beküldés (nincs szerző-megfeleltetés) nem ad pontot', async () => {
  const uid = 'guided-submission-4';
  await seedProfile(uid);

  const result = await awardSubmission(7999);
  assert.equal(result.changed, false, 'a régi (megfeleltetés nélküli) beküldés nem ír jóvá');
  assert.equal(await pointsOf(uid), 0);

  await cleanup(uid);
});

test('kiadvány-vásárlás: minden megvásárolt VÁLTOZAT +20 pontot ér, egyszer', async () => {
  const uid = 'guided-purchase-1';
  await seedProfile(uid);

  const first = await awardPurchase(uid, 'huhs_release_4242_radio_mp3_320');
  assert.equal(first.changed, true);
  assert.equal(await pointsOf(uid), 20);

  // Ugyanaz a változat ismételt ellenőrzése (pl. újraindított app): nem ad újat.
  const again = await awardPurchase(uid, 'huhs_release_4242_radio_mp3_320');
  assert.equal(again.changed, false);
  assert.equal(await pointsOf(uid), 20);

  // EGY MÁSIK változat viszont külön tétel — a tulajdonos döntése szerint +20.
  const extended = await awardPurchase(uid, 'huhs_release_4242_extended_wav');
  assert.equal(extended.changed, true);
  assert.equal(await pointsOf(uid), 40);

  const notifications = await db.collection('notifications').where('recipientUid', '==', uid).get();
  assert.equal(notifications.size, 2, 'mindkét vásárlásról szól az értesítés');
  assert.match(
    String(notifications.docs[0].data().body || ''),
    /kiadvány megvásárlásáért/,
    'az értesítés megmondja, miért jár a pont',
  );

  const counter = await db
    .collection('achievement_news_like_limits')
    .doc(`${uid}_${todayKey()}`)
    .get();
  assert.equal(counter.exists, false, 'a vásárlás nem fogyasztja a lájk-keretet');

  await cleanup(uid);
});

test('hiányzó adat nem ad pontot (nincs néma jóváírás)', async () => {
  assert.equal((await awardPurchase('', 'huhs_release_1_wav')).changed, false);
  assert.equal((await awardPurchase('valaki', '')).changed, false);
  assert.equal((await awardSubmission(0)).changed, false);
  assert.equal((await awardSubmission('nem-szam')).changed, false);
});

test('a napi aktivitás sávjai: 1 egységtől 1 pont, 25 egységtől 5 (plafon)', () => {
  assert.equal(dailyPoints({}), 0);
  assert.equal(dailyPoints({ comments: 0, chatMessages: 0 }), 0);
  // Egyetlen tevékenység is ér pontot.
  assert.equal(dailyPoints({ chatMessages: 1 }), 1);
  assert.equal(dailyPoints({ comments: 1 }), 1);
  // A hozzászólás 2 egységet ér: 2 hozzászólás = 4 egység = 2 pont.
  assert.equal(dailyPoints({ comments: 2 }), 2);
  assert.equal(dailyPoints({ comments: 4 }), 3);
  assert.equal(dailyPoints({ comments: 1, chatMessages: 6 }), 3);
  assert.equal(dailyPoints({ comments: 8 }), 4);
  assert.equal(dailyPoints({ chatMessages: 25 }), 5);
  // A plafon fölött sem ad többet (nem lehet a chattel farmolni).
  assert.equal(dailyPoints({ chatMessages: 500 }), 5);
  assert.equal(dailyPoints({ comments: 100 }), 5);
  // Hibás/negatív adat nem ad pontot.
  assert.equal(dailyPoints({ comments: -5, chatMessages: -5 }), 0);
  assert.equal(dailyPoints({ comments: 'sok', chatMessages: null }), 0);
});

test('az aktivitás számlálója a valódi tevékenységet gyűjti (hozzászólás, chat)', async () => {
  const uid = 'guided-activity-1';
  await seedProfile(uid);
  await recordDailyActivity(uid, 'comments');
  await recordDailyActivity(uid, 'comments');
  await recordDailyActivity(uid, 'chatMessages');
  // Ismeretlen mező és üres uid: nem ír semmit.
  assert.equal(await recordDailyActivity(uid, 'ismeretlen'), false);
  assert.equal(await recordDailyActivity('', 'comments'), false);

  const counter = await db.collection('daily_activity').doc(`${uid}_${todayKey()}`).get();
  assert.equal(Number(counter.data()?.comments || 0), 2);
  assert.equal(Number(counter.data()?.chatMessages || 0), 1);

  await cleanup(uid);
  await db.collection('daily_activity').doc(`${uid}_${todayKey()}`).delete().catch(() => {});
});

test('a napi aktivitási pont a LEZÁRT napra jár, naponta egyszer, indoklással', async () => {
  const uid = 'guided-activity-2';
  await seedProfile(uid);
  const day = '2026-09-18';

  // 3 hozzászólás (6 egység) + 2 chat = 8 egység → 3 pont.
  const result = await awardDailyActivity({
    uid,
    date: day,
    comments: 3,
    chatMessages: 2,
  });
  assert.equal(result.changed, true);
  assert.equal(result.points, 3);
  assert.equal(await pointsOf(uid), 3);

  const ledger = await db
    .collection('achievement_ledger')
    .where('uid', '==', uid)
    .get();
  assert.equal(ledger.docs[0].data().sourceKey, `daily-activity:${day}`);

  const notifications = await db.collection('notifications').where('recipientUid', '==', uid).get();
  assert.equal(notifications.size, 1);
  assert.match(
    String(notifications.docs[0].data().body || ''),
    /tegnapi közösségi aktivitásodért/,
    'az értesítés megmondja, miért jár a pont',
  );

  // Ugyanaz a nap kétszer: nem fizet újra (akkor sem, ha még aktívabb lett).
  const again = await awardDailyActivity({
    uid,
    date: day,
    comments: 30,
    chatMessages: 30,
  });
  assert.equal(again.changed, false);
  assert.equal(await pointsOf(uid), 3);

  // Egy MÁSIK nap viszont újra jár.
  const nextDay = await awardDailyActivity({
    uid,
    date: '2026-09-19',
    comments: 0,
    chatMessages: 1,
  });
  assert.equal(nextDay.changed, true);
  assert.equal(nextDay.points, 1);
  assert.equal(await pointsOf(uid), 4);

  await cleanup(uid);
});

test('aktivitás nélkül nincs napi pont (nincs jóváírás a semmire)', async () => {
  const uid = 'guided-activity-3';
  await seedProfile(uid);

  const result = await awardDailyActivity({
    uid,
    date: '2026-09-18',
    comments: 0,
    chatMessages: 0,
  });
  assert.equal(result.changed, false);
  assert.equal(result.points, 0);
  assert.equal(await pointsOf(uid), 0);

  // Dátum/uid nélkül sem történik semmi.
  assert.equal((await awardDailyActivity({ uid, date: '', comments: 5 })).changed, false);
  assert.equal((await awardDailyActivity({ uid: '', date: '2026-09-18', comments: 5 })).changed, false);

  await cleanup(uid);
});
