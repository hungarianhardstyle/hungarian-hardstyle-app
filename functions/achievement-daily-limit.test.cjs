const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const { initializeApp, getApps } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

/**
 * A napi achievement-plafon VALODI viselkedese.
 *
 * A tulajdonos jelzese: „hir lajkolassal ne lehessen achievement pontokat
 * farmolni, eddig volt benne valami tiltas, hogy max napi 3 hir lajkolasert
 * jar achi egy usernek, most mintha nem így működne".
 *
 * A korlat a `awardAchievementPoints()` tranzakciojaban van:
 *   - `achievement_ledger/<uid>:<sourceKey>:grant` a duplikacio ellen;
 *   - `achievement_news_like_limits/<uid>_<YYYY-MM-DD>` a NAPI plafon ellen.
 *
 * A ketto NEM ugyanaz: a ledger-kulcs tartalmazza a `postId`-t, ezert a ledger
 * onmagaban csak ugyanannak a cikknek az ismetelt lajkolasat fogja meg. Egy nap
 * viszont tobb tucat kulonbozo cikket is meg lehet nyitni — ezert kell a kulon
 * napi szamlalo, es ezert ez a teszt a TOBB kulonbozo cikket is vegigjatsza.
 *
 * Ez a teszt a VALODI `awardAchievementPoints`-ot hivja a Firestore-emulatoron
 * (nem forras-szoveget keres), tehat a tranzakcio, a szamlalo es a plafon
 * tenyleges viselkedeset bizonyitja.
 *
 * Futtatas (a repository gyokerebol):
 *   npx firebase emulators:exec --only firestore --project demo-huhs \
 *     "node functions/achievement-daily-limit.test.cjs"
 */

const projectId = process.env.GCLOUD_PROJECT || 'demo-huhs';
const databaseId = 'hungarian-hardstyle';

// FONTOS a sorrend: a `./index.js` a betolteskor `admin.initializeApp()`-et
// hiv, tehat a DEFAULT appnak MÁR LÉTEZNIE KELL, ugyanazzal a projekt-azonosítóval.
// Ha forditva csinalnank, a FirebaseAppError „already exists with a different
// configuration" hibaval allna le.
const app = initializeApp({ projectId });
const db = getFirestore(app, databaseId);

const { __awardAchievementPointsForTests: award, __achievementDailyLimitsForTests: limits } =
  require('./index.js');

function todayKey() {
  return new Date().toISOString().slice(0, 10);
}

async function pointsOf(uid) {
  const profile = await db.collection('community_profiles').doc(uid).get();
  return Number(profile.data()?.achievementPoints || 0);
}

async function counterOf(collection, uid) {
  const document = await db.collection(collection).doc(`${uid}_${todayKey()}`).get();
  return Number(document.data()?.count || 0);
}

async function seedProfile(uid) {
  await db.collection('community_profiles').doc(uid).set(
    {
      uid,
      displayName: `limit-test-${uid.slice(0, 6)}`,
      achievementPoints: 0,
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
}

async function cleanup(uid) {
  const collections = [
    'community_profiles',
    'achievement_ledger',
    'achievement_news_like_limits',
    'achievement_article_comment_limits',
    'notifications',
  ];
  for (const name of collections) {
    const snapshot = await db.collection(name).where('uid', '==', uid).get().catch(() => null);
    if (!snapshot) continue;
    for (const document of snapshot.docs) await document.ref.delete().catch(() => {});
  }
  await db.collection('community_profiles').doc(uid).delete().catch(() => {});
  const counters = await db
    .collection('achievement_news_like_limits')
    .where('uid', '==', uid)
    .get()
    .catch(() => null);
  if (counters) for (const document of counters.docs) await document.ref.delete().catch(() => {});
}

before(async () => {
  assert.ok(
    process.env.FIRESTORE_EMULATOR_HOST,
    'Ez a teszt Firestore-emulatort igenyel (FIRESTORE_EMULATOR_HOST).',
  );
});

after(async () => {
  // Az emulator eldobhato, de a sajat sorainkat rendben hagyjuk.
});

test('a napi plafon ertekei: hir 3, komment 3', () => {
  assert.equal(limits.newsLike, 3);
  assert.equal(limits.articleComment, 3);
});

test('hir-lajkolas: a 3. utan NEM jar tobb pont, akkor sem, ha mas cikk', async () => {
  const uid = 'limit-news-1';
  await seedProfile(uid);

  // Harom kulonbozo cikk -> harom jogosult pont.
  for (const postId of [9001, 9002, 9003]) {
    const result = await award(uid, 2, `news-like:${postId}`);
    assert.equal(result.changed, true, `a(z) ${postId} cikkre jart pont`);
    assert.equal(result.points, (postId - 9000) * 2);
  }
  assert.equal(await pointsOf(uid), 6);
  assert.equal(await counterOf('achievement_news_like_limits', uid), 3);

  // A negyedik kulonbozo cikk: a napi keret elfogyott.
  const blocked = await award(uid, 2, 'news-like:9004');
  assert.equal(blocked.changed, false, 'a napi plafon utan nem jar pont');
  assert.equal(await pointsOf(uid), 6, 'a pontszam valtozatlan');
  assert.equal(
    await counterOf('achievement_news_like_limits', uid),
    3,
    'a szamlalo a plafonon all, nem no tovabb',
  );

  // Es meg egy, hogy ne egyetlen elutasitas legyen a bizonyitek.
  await award(uid, 2, 'news-like:9005');
  await award(uid, 2, 'news-like:9006');
  assert.equal(await pointsOf(uid), 6);

  const ledger = await db
    .collection('achievement_ledger')
    .where('uid', '==', uid)
    .get();
  assert.equal(ledger.size, 3, 'csak a harom jogosult grant kerult a ledgerbe');

  await cleanup(uid);
});

test('ugyanaz a cikk ketszer: a ledger fogja meg (nem a napi szamlalo)', async () => {
  const uid = 'limit-news-2';
  await seedProfile(uid);

  const first = await award(uid, 2, 'news-like:9100');
  assert.equal(first.changed, true);
  const second = await award(uid, 2, 'news-like:9100');
  assert.equal(second.changed, false, 'ugyanaz a cikk nem ad masodszor pontot');
  assert.equal(await pointsOf(uid), 2);

  await cleanup(uid);
});

test('a visszavonas (unlike) a plafonon is mukodik', async () => {
  const uid = 'limit-news-3';
  await seedProfile(uid);

  for (const postId of [9201, 9202, 9203]) await award(uid, 2, `news-like:${postId}`);
  assert.equal(await pointsOf(uid), 6);

  // A 4. grant mar nem jar ponttal, de a visszavonasnak mukodnie kell.
  const revoke = await award(uid, -2, 'news-like:9202');
  assert.equal(revoke.changed, true, 'a visszavonas nem eshet a napi plafon ala');
  assert.equal(await pointsOf(uid), 4);

  // Es a visszavonas utan sem ad ugyanaz a cikk ujra pontot.
  const again = await award(uid, 2, 'news-like:9202');
  assert.equal(again.changed, false);
  assert.equal(await pointsOf(uid), 4);

  await cleanup(uid);
});

test('a cikk-komment kulon szamlalot hasznal, sajat plafonnal', async () => {
  const uid = 'limit-comment-1';
  await seedProfile(uid);

  for (const postId of [9301, 9302, 9303]) {
    const result = await award(uid, 1, `article-comment:${postId}:comment-${postId}`);
    assert.equal(result.changed, true);
  }
  assert.equal(await pointsOf(uid), 3);
  assert.equal(await counterOf('achievement_article_comment_limits', uid), 3);

  const blocked = await award(uid, 1, 'article-comment:9304:comment-9304');
  assert.equal(blocked.changed, false, 'a komment plafon is fog');
  assert.equal(await pointsOf(uid), 3);

  // A hir-szamlalo erintetlen maradt: a ket forras nem eszi meg egymast.
  assert.equal(await counterOf('achievement_news_like_limits', uid), 0);

  await cleanup(uid);
});

test('a nem korlatozott forras (pl. esemeny-reszvetel) nem fogyasztja a napi keretet', async () => {
  const uid = 'limit-other-1';
  await seedProfile(uid);

  for (const eventId of [1, 2, 3, 4, 5]) {
    const result = await award(uid, 10, `attendance:${eventId}`);
    assert.equal(result.changed, true, 'a reszvetel nem esik plafon ala');
  }
  assert.equal(await pointsOf(uid), 50);
  assert.equal(await counterOf('achievement_news_like_limits', uid), 0);
  assert.equal(await counterOf('achievement_article_comment_limits', uid), 0);

  await cleanup(uid);
});
