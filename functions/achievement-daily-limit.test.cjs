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

const {
  __awardAchievementPointsForTests: award,
  __achievementDailyLimitsForTests: limits,
  __awardNewsReactionPointsForTests: awardNewsReaction,
} = require('./index.js');

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

test('a visszavonas a plafonon is mukodik (a napi keret nem blokkolja a levonast)', async () => {
  const uid = 'limit-news-3';
  await seedProfile(uid);

  for (const postId of [9201, 9202, 9203]) await award(uid, 2, `news-like:${postId}`);
  assert.equal(await pointsOf(uid), 6);

  // A napi keret elfogyott, de a visszavonasnak (állapotváltásnak) működnie kell.
  const revoke = await award(uid, -2, 'news-like:9202');
  assert.equal(revoke.changed, true, 'a visszavonas nem eshet a napi plafon ala');
  assert.equal(await pointsOf(uid), 4);

  await cleanup(uid);
});

test('a hír-lájk: a visszavonás NEM vesz el pontot, és az újralájk nem ad újat', async () => {
  // A TULAJDONOS SZABÁLYA: „ha kiveszem a lájkot, ne adja vissza megint".
  // Ezt a lájk-pontmag viselkedése adja ki (nem a ledger tiltása), ezért itt a
  // valódi magot mérjük: lájk → visszavonás → újralájk.
  const uid = 'limit-like-rule';
  await seedProfile(uid);

  const like = await awardNewsReaction({}, { [uid]: true }, 9401);
  assert.equal(like[0]?.changed, true, 'az első lájk pontot ad');
  assert.equal(await pointsOf(uid), 2);

  // Visszavonás: a pont MARAD (nincs levonás), ledger-sor sem keletkezik.
  const unlike = await awardNewsReaction({ [uid]: true }, {}, 9401);
  assert.deepEqual(unlike, [], 'a visszavonás nem ad és nem vesz el pontot');
  assert.equal(await pointsOf(uid), 2, 'a lájkpont megmarad');

  // Újralájk: nem jár új pont (nincs állapotváltozás), és nem lehet farmolni.
  const again = await awardNewsReaction({}, { [uid]: true }, 9401);
  assert.equal(again[0]?.changed, false, 'az újralájk nem ad másodszor pontot');
  assert.equal(await pointsOf(uid), 2);

  const ledger = await db.collection('achievement_ledger').where('uid', '==', uid).get();
  assert.equal(ledger.size, 1, 'egyetlen ledger-sor van a cikkhez');

  await cleanup(uid);
});

test('az esemény-részvétel oda-vissza váltogatása nem veszíti el a pontot', async () => {
  // A korábbi kulcs (`…:grant` / `…:revoke`) miatt a visszavonás UTÁNI újabb
  // jóváírás örökre blokkolva maradt — a felhasználó mínuszba került. Most a
  // ledger az ÁLLAPOTOT tárolja, ezért a harmadik váltás már újra jóváír.
  const uid = 'limit-attendance-cycle';
  await seedProfile(uid);

  const first = await award(uid, 10, 'attendance:777');
  assert.equal(first.changed, true);
  const off = await award(uid, -10, 'attendance:777');
  assert.equal(off.changed, true);
  assert.equal(await pointsOf(uid), 0);

  const back = await award(uid, 10, 'attendance:777');
  assert.equal(back.changed, true, 'a visszajelentkezés újra pontot ad (nincs csapda)');
  assert.equal(await pointsOf(uid), 10);

  // Ismételt jóváírás ugyanarra: nincs új pont (farmolás elleni védelem).
  const duplicate = await award(uid, 10, 'attendance:777');
  assert.equal(duplicate.changed, false);
  assert.equal(await pointsOf(uid), 10);

  // Soha nem kapott érte pontot → nincs mit visszavonni (nincs mínusz a semmiből).
  const neverGranted = await award(uid, -10, 'attendance:999');
  assert.equal(neverGranted.changed, false, 'a sosem adott pont nem vonható le');
  assert.equal(await pointsOf(uid), 10);

  const ledger = await db.collection('achievement_ledger').where('uid', '==', uid).get();
  assert.equal(ledger.size, 1, 'forrásonként egyetlen állapot-sor van');

  await cleanup(uid);
});

test('a régi (grant/revoke) ledger-sor blokkolja az ismételt jóváírást — nincs dupla pont', async () => {
  // ÉLES HIBA (2026-09-19): a ledger-kulcs átállása után a régi `…:grant` sort
  // már nem találta meg a kód, ezért ugyanazért a teljesítményért **másodszor**
  // is kifizette a pontot (Denoiser `profile-complete` +30 kétszer). Ez a teszt
  // azt rögzíti, hogy a régi sorokat is figyelembe vesszük.
  const crypto = require('node:crypto');
  const uid = 'limit-legacy-duplicate';
  await seedProfile(uid);
  const legacyId = crypto
    .createHash('sha256')
    .update(`${uid}:profile-complete:grant`)
    .digest('hex')
    .slice(0, 40);
  await db.collection('achievement_ledger').doc(legacyId).set({
    uid,
    sourceKey: 'profile-complete',
    delta: 30,
    pointsAfter: 30,
    createdAt: FieldValue.serverTimestamp(),
  });
  await db
    .collection('community_profiles')
    .doc(uid)
    .set({ achievementPoints: 30 }, { merge: true });

  const result = await award(uid, 30, 'profile-complete');
  assert.equal(result.changed, false, 'a régi jóváírást nem lehet még egyszer kifizetni');
  assert.equal(await pointsOf(uid), 30, 'a pontszám nem nő duplán');

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
