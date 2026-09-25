const nodeTest = require('node:test');
// ⚠️ Ez a suite a Firestore-EMULÁTORON fut, mert a VALÓDI függvényeket méri.
// Emulátor nélkül (pl. sima `node --test`) a Firebase Admin nem talál
// hitelesítést („Could not load the default credentials"), és a suite HAMIS
// pirosat mutatna — ezért ilyenkor minden teszt „kihagyva" jelzést kap, a suite
// pedig zölden lefut. Emulátorral a tesztek valóban lefutnak.
//
// Futtatás emulátorral (a repository gyökeréből):
//   npx firebase emulators:exec --only firestore --project demo-huhs \
//     "node functions/achievement-restore.test.cjs"
const EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST;
const TEST_SKIP = EMULATOR_HOST
  ? false
  : 'Firestore-emulátor nélkül kihagyva (FIRESTORE_EMULATOR_HOST nincs beállítva)';
// A hookok is emulátorhoz kötöttek: kihagyott futásnál NE is regisztráljuk őket,
// különben a `before`/`beforeEach` a kihagyott teszteknél is elindulna, és a
// Firebase Admin hitelesítés nélkül hibát dobna (ez volt a `push-dedupe` esete).
const guardHook = (hook) => (fn, options) => (TEST_SKIP ? undefined : hook(fn, options));
const before = guardHook(nodeTest.before);
const beforeEach = guardHook(nodeTest.beforeEach);
const after = guardHook(nodeTest.after);
function test(name, options, fn) {
  if (typeof options === 'function') {
    return nodeTest.test(name, { skip: TEST_SKIP }, options);
  }
  return nodeTest.test(name, { ...options, skip: TEST_SKIP || options?.skip }, fn);
}
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

/**
 * Az ELVESZETT achievement-pontok visszaallitasa — VALODI viselkedes.
 *
 * A tulajdonos jelzese: „egy user jelezte, hogy lajkolt hirt es nem kapta meg,
 * es valoban nullan all (Szabo Attila)". Az elo meres megmutatta a gyokeret: a
 * regi kod a lajk visszavonasakor LEVONTA a pontot. A tulajdonos dontese: „a
 * szabalyok maradjanak meg", de a MAR elveszett pontok alljanak vissza.
 *
 * Ez a teszt a VALODI `awardAchievementPoints`-ot futtatja a Firestore-
 * emulatoron (nem forras-szoveget keres), es a visszaallitas ket fontos
 * tulajdonsagat meri:
 *  1. PONTOSAN annyit ad vissza, amennyit a ledger szerint elvettek;
 *  2. IDEMPOTENS — a masodik futas nem ad uj pontot (a Firestore-trigger
 *     tobbszor is tuzelhet).
 * Plusz a sajat hibam korrekcioja: a `profile-complete` egyszeri jutalmat a
 * ledger-kulcs atallasa utan MÁSODSZOR is kifizette (`796c0f52` elott).
 *
 * Futtatas (a repository gyokerebol):
 *   npx firebase emulators:exec --only firestore --project demo-huhs \
 *     "node functions/achievement-restore.test.cjs"
 */

const projectId = process.env.GCLOUD_PROJECT || 'demo-huhs';
const databaseId = 'hungarian-hardstyle';

const app = initializeApp({ projectId });
const db = getFirestore(app, databaseId);

const {
  __buildAchievementRestorePlanForTests: buildPlan,
  __applyAchievementRestorePlanForTests: applyPlan,
} = require('./index.js');

const silentLogger = { log() {}, warn() {}, error() {} };

function legacyId(uid, sourceKey, suffix) {
  return crypto
    .createHash('sha256')
    .update(`${uid}:${sourceKey}:${suffix}`)
    .digest('hex')
    .slice(0, 40);
}

async function seedProfile(uid, points = 0) {
  await db.collection('community_profiles').doc(uid).set(
    {
      uid,
      displayName: `restore-test-${uid.slice(0, 8)}`,
      achievementPoints: points,
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
}

async function seedLegacyRow(uid, sourceKey, suffix, delta) {
  await db
    .collection('achievement_ledger')
    .doc(legacyId(uid, sourceKey, suffix))
    .set({
      uid,
      sourceKey,
      delta,
      pointsAfter: delta > 0 ? delta : 0,
      createdAt: FieldValue.serverTimestamp(),
    });
}

async function pointsOf(uid) {
  const profile = await db.collection('community_profiles').doc(uid).get();
  return Number(profile.data()?.achievementPoints || 0);
}

async function ledgerOf(uid) {
  const snapshot = await db.collection('achievement_ledger').where('uid', '==', uid).get();
  return snapshot.docs.map((document) => document.data());
}

/** A tervet ugyanugy allitjuk elo, mint a Cloud Function: a VALODI ledgerbol. */
async function livePlanFor(uid) {
  const snapshot = await db.collection('achievement_ledger').where('uid', '==', uid).get();
  return buildPlan(snapshot.docs.map((document) => document.data()));
}

async function cleanup(uid) {
  for (const name of ['community_profiles', 'notifications']) {
    if (name === 'community_profiles') {
      await db.collection(name).doc(uid).delete().catch(() => {});
      continue;
    }
    const snapshot = await db.collection(name).where('recipientUid', '==', uid).get().catch(() => null);
    if (snapshot) for (const document of snapshot.docs) await document.ref.delete().catch(() => {});
  }
  const ledger = await db.collection('achievement_ledger').where('uid', '==', uid).get().catch(() => null);
  if (ledger) for (const document of ledger.docs) await document.ref.delete().catch(() => {});
}

before(async () => {
  assert.ok(
    process.env.FIRESTORE_EMULATOR_HOST,
    'Ez a teszt Firestore-emulatort igenyel (FIRESTORE_EMULATOR_HOST).',
  );
});

test('a terv csak a hír-lájk visszavonást és a dupla profile-complete-ot javítja', () => {
  const plan = buildPlan([
    // Régi (grant/revoke páros) hír-lájk: a pont elveszett.
    { uid: 'a', sourceKey: 'news-like:1', delta: 2 },
    { uid: 'a', sourceKey: 'news-like:1', delta: -2 },
    // Jóváírás, visszavonás nélkül: nincs mit visszaállítani.
    { uid: 'b', sourceKey: 'news-like:2', delta: 2 },
    // Esemény oda-vissza: VALÓDI életciklus, nem hiba.
    { uid: 'c', sourceKey: 'attendance:9', delta: 10 },
    { uid: 'c', sourceKey: 'attendance:9', delta: -10 },
    // A saját hibám: egyszeri jutalom kétszer.
    { uid: 'd', sourceKey: 'profile-complete', delta: 30 },
    { uid: 'd', sourceKey: 'profile-complete', delta: 30, state: 'granted' },
  ]);

  assert.deepEqual(plan.restores, [
    { uid: 'a', sourceKey: 'news-like-restore:1', delta: 2 },
  ]);
  assert.deepEqual(plan.corrections, [
    { uid: 'd', sourceKey: 'correction:profile-complete-duplicate', delta: -30 },
  ]);
  assert.equal(buildPlan([]).restores.length, 0);
  assert.equal(buildPlan(undefined).corrections.length, 0);

  // Ami MÁR vissza van állítva / korrigálva, azt a terv nem kéri újra — így az
  // előnézet a végrehajtás után üres, és nem ígér olyat, ami nem történne meg.
  const applied = buildPlan([
    { uid: 'a', sourceKey: 'news-like:1', delta: 2 },
    { uid: 'a', sourceKey: 'news-like:1', delta: -2 },
    { uid: 'a', sourceKey: 'news-like-restore:1', delta: 2, state: 'granted' },
    { uid: 'd', sourceKey: 'profile-complete', delta: 30 },
    { uid: 'd', sourceKey: 'profile-complete', delta: 30, state: 'granted' },
    { uid: 'd', sourceKey: 'correction:profile-complete-duplicate', delta: -30, state: 'revoked' },
  ]);
  assert.deepEqual(applied, { restores: [], corrections: [] });
});

test('a visszavont lájkpont visszaáll, és az értesítés megmondja, miért', async () => {
  const uid = 'restore-like-1';
  await seedProfile(uid, 0);
  await seedLegacyRow(uid, 'news-like:500', 'grant', 2);
  await seedLegacyRow(uid, 'news-like:500', 'revoke', -2);
  assert.equal(await pointsOf(uid), 0, 'a kiindulás: a visszavonás elvette a pontot');

  const plan = await livePlanFor(uid);
  assert.equal(plan.restores.length, 1);
  const { summary } = await applyPlan({ plan, logger: silentLogger });
  assert.equal(summary.restoredPoints, 2);
  assert.equal(await pointsOf(uid), 2, 'a pont visszaállt');

  const ledger = await ledgerOf(uid);
  const restoreRow = ledger.find((row) => row.sourceKey === 'news-like-restore:500');
  assert.ok(restoreRow, 'a visszaállítás külön ledger-sort kapott');
  assert.equal(restoreRow.state, 'granted');
  assert.equal(restoreRow.delta, 2);

  const notifications = await db
    .collection('notifications')
    .where('recipientUid', '==', uid)
    .get();
  assert.equal(notifications.size, 1, 'a felhasználó értesítést kap');
  const body = String(notifications.docs[0].data().body || '');
  assert.match(body, /visszaállításáért/, 'az értesítés megmondja, miért jár a pont');

  await cleanup(uid);
});

test('a visszaállítás idempotens: a második futás nem ad új pontot', async () => {
  const uid = 'restore-like-2';
  await seedProfile(uid, 0);
  await seedLegacyRow(uid, 'news-like:501', 'grant', 2);
  await seedLegacyRow(uid, 'news-like:501', 'revoke', -2);

  const first = await applyPlan({ plan: await livePlanFor(uid), logger: silentLogger });
  assert.equal(first.summary.restoredPoints, 2);

  const second = await applyPlan({ plan: await livePlanFor(uid), logger: silentLogger });
  assert.equal(second.summary.restoredPoints, 0, 'a második futás nem ad pontot');
  assert.equal(second.summary.changed, 0);
  assert.equal(await pointsOf(uid), 2, 'a pontszám nem nő duplán');

  const ledger = await ledgerOf(uid);
  assert.equal(
    ledger.filter((row) => row.sourceKey === 'news-like-restore:501').length,
    1,
    'egyetlen visszaállítás-sor van',
  );

  await cleanup(uid);
});

test('csak azt állítja vissza, amit a napló szerint elvettek', async () => {
  const uid = 'restore-like-3';
  await seedProfile(uid, 0);
  // Olyan cikk, amiért SOHA nem járt pont (a napi keret fogta meg), de a
  // visszavonás így is levont 2-t: ezt visszaadjuk (pontosan 2-t, nem 4-et).
  await seedLegacyRow(uid, 'news-like:502', 'revoke', -2);
  // Olyan cikk, amiért járt pont és nem vonták vissza: nincs mit tenni.
  await seedLegacyRow(uid, 'news-like:503', 'grant', 2);
  await seedProfile(uid, 0);

  const plan = await livePlanFor(uid);
  assert.deepEqual(
    plan.restores.map((entry) => entry.sourceKey),
    ['news-like-restore:502'],
  );
  const { summary } = await applyPlan({ plan, logger: silentLogger });
  assert.equal(summary.restoredPoints, 2);
  assert.equal(await pointsOf(uid), 2, 'pontosan a levont 2 pont jött vissza');

  await cleanup(uid);
});

test('az esemény-részvétel oda-vissza váltogatása nem kap visszaállítást', async () => {
  const uid = 'restore-attendance-1';
  await seedProfile(uid, 0);
  await seedLegacyRow(uid, 'attendance:600', 'grant', 10);
  await seedLegacyRow(uid, 'attendance:600', 'revoke', -10);

  const plan = await livePlanFor(uid);
  assert.equal(plan.restores.length, 0, 'a lemondás valódi életciklus, nem hiba');

  const { summary } = await applyPlan({ plan, logger: silentLogger });
  assert.equal(summary.changed, 0);
  assert.equal(await pointsOf(uid), 0);

  await cleanup(uid);
});

test('a dupla profile-complete jóváírás korrekciója pontosan egyszer fut', async () => {
  const uid = 'restore-duplicate-1';
  await seedProfile(uid, 60);
  await seedLegacyRow(uid, 'profile-complete', 'grant', 30);
  await db.collection('achievement_ledger').doc(`modern-${uid}`).set({
    uid,
    sourceKey: 'profile-complete',
    state: 'granted',
    delta: 30,
    pointsAfter: 60,
    createdAt: FieldValue.serverTimestamp(),
  });

  const plan = await livePlanFor(uid);
  assert.deepEqual(plan.corrections, [
    { uid, sourceKey: 'correction:profile-complete-duplicate', delta: -30 },
  ]);

  const first = await applyPlan({ plan, applyCorrections: true, logger: silentLogger });
  assert.equal(first.summary.correctedPoints, -30);
  assert.equal(await pointsOf(uid), 30, 'a dupla jóváírásból 30 pont marad');

  const modern = (await ledgerOf(uid)).find((row) => row.sourceKey === 'profile-complete' && 'state' in row);
  assert.equal(modern.state, 'granted', 'a jóváírás naplója megmarad (nem hazudunk visszavonást)');

  const second = await applyPlan({
    plan: await livePlanFor(uid),
    applyCorrections: true,
    logger: silentLogger,
  });
  assert.equal(second.summary.correctedPoints, 0, 'a korrekció nem fut le kétszer');
  assert.equal(await pointsOf(uid), 30);

  await cleanup(uid);
});

test('korrekció nélkül (applyCorrections=false) a dupla jóváírás érintetlen', async () => {
  const uid = 'restore-duplicate-2';
  await seedProfile(uid, 60);
  await seedLegacyRow(uid, 'profile-complete', 'grant', 30);
  await db.collection('achievement_ledger').doc(`modern-${uid}`).set({
    uid,
    sourceKey: 'profile-complete',
    state: 'granted',
    delta: 30,
    pointsAfter: 60,
    createdAt: FieldValue.serverTimestamp(),
  });

  const { summary } = await applyPlan({
    plan: await livePlanFor(uid),
    applyCorrections: false,
    logger: silentLogger,
  });
  assert.equal(summary.planned, 0, 'a korrekciót külön kell engedélyezni');
  assert.equal(await pointsOf(uid), 60);

  await cleanup(uid);
});
