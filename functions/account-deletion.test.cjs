const { test, before, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

/**
 * A felhasznalo-torles Cloudinary-hatara — a VALODI fuggvenyeken merve.
 *
 * MIERT: a tulajdonos jelezte (2026-09-19), hogy az admin „nem torli az usert,
 * a teszt acc ugyanugy ott van". Eles meres mutatta meg a gyokot:
 *   * a `deleted_user_ids/<uid>` bekerult, az Auth-fiok eltunt;
 *   * a `community_profiles/<uid>` VISZONT megmaradt;
 *   * az `account_deletions/<uid>.lastError` = `cloudinary-delete-temporary-failure:401`.
 * Vagyis a Cloudinary `destroy` hivasa dobott (elavult API-secret), es ez a
 * kivetel meg a `community_profiles/<uid>` torlese ELOTT kifutott a
 * `deleteUserReferences`-bol — a hivo pedig „sikert" jelentett.
 *
 * Ezek a tesztek azt rogzitik, hogy ez tobbé ne tortenhessen meg:
 *   1. Cloudinary-hiba eseten IS lefut a teljes Firestore-takaritas;
 *   2. a fuggoben maradt kepek NEM vesznek el (a hivo megkapja oket);
 *   3. sikeres Cloudinary-val minden torlodik, es nincs fuggoben maradek;
 *   4. a 15 percenkenti ujraproba csak a kepekkel foglalkozik (olcso), es
 *      helyreall, amint a Cloudinary ujra valaszol.
 *
 * A teszt a VALODI `__deleteUserReferencesForTests` / `__retryCloudinaryAssetCleanupForTests`
 * fuggvenyeket hivja a Firestore-emulatoron, KIZAROLAG a halozati hivast
 * (`fetch`) helyettesitve. Igy a gyujtemeny-takaritas, a rekurziv torles es a
 * visszateresi ertek tenylegesen fut.
 *
 * Futtatas (a repository gyokerebol):
 *   npx firebase emulators:exec --only firestore --project demo-huhs \
 *     "node functions/account-deletion.test.cjs"
 */

// A titkokat a `defineSecret().value()` a kornyezeti valtozokbol olvassa; a
// tesztben hamis ertek kell, kulonben a fuggveny „nincs beallitva" hibaval all meg.
process.env.CLOUDINARY_API_KEY = 'test-key';
process.env.CLOUDINARY_API_SECRET = 'test-secret';

const projectId = process.env.GCLOUD_PROJECT || 'demo-huhs';
const databaseId = 'hungarian-hardstyle';

// FONTOS a sorrend: a `./index.js` betolteskor `admin.initializeApp()`-et hiv,
// ezert a DEFAULT appnak MAR LETEZNIE kell ugyanazzal a projekt-azonosítóval.
const app = initializeApp({ projectId });
const db = getFirestore(app, databaseId);

const {
  __deleteUserReferencesForTests: deleteUserReferences,
  __retryCloudinaryAssetCleanupForTests: retryCloudinaryAssetCleanup,
} = require('./index.js');

const COLLECTIONS = [
  'community_profiles',
  'public_profiles',
  'private_user_data',
  'community_bans',
  'notifications',
  'live_feed_posts',
  'news_reactions',
  'display_name_claims',
  'display_name_index',
];

let cloudinaryMode = 'fail';
let listedResources = [];
let cloudinaryCalls = [];

/**
 * A halozati hatar egyetlen helye: minden Cloudinary hivas itt landol.
 * `fail` modban a valos 401-et utanozzuk („api_secret mismatch").
 */
function installFetchStub() {
  globalThis.fetch = async (url, options = {}) => {
    const target = String(url);
    cloudinaryCalls.push({
      url: target,
      method: String(options.method || 'GET'),
      body: String(options.body || ''),
    });
    if (!target.includes('api.cloudinary.com')) {
      throw new Error(`Varatlan URL a tesztben: ${target}`);
    }
    if (cloudinaryMode === 'fail') {
      return { ok: false, status: 401, json: async () => ({ error: { message: 'api_secret mismatch' } }) };
    }
    if (target.includes('/resources/image/upload')) {
      return { ok: true, status: 200, json: async () => ({ resources: listedResources }) };
    }
    return { ok: true, status: 200, json: async () => ({ result: 'ok' }) };
  };
}

async function resetDatabase() {
  for (const name of COLLECTIONS) {
    const snapshot = await db.collection(name).get();
    if (snapshot.empty) continue;
    await db.recursiveDelete(db.collection(name));
  }
}

/** A torolt felhasznalo teljes lábnyoma, ahogy az eles adatbazisban is van. */
async function seedUser(uid) {
  const profile = {
    displayName: 'Teszt acc',
    email: 'teszt@example.test',
    role: 'partygoer',
    profileImagePublicId: `huhs_users/${uid}/profile`,
    profileImageUrl: `https://res.cloudinary.com/fjxo93em/image/upload/v1/huhs_users/${uid}/profile.jpg`,
  };
  await db.collection('community_profiles').doc(uid).set(profile);
  await db.collection('public_profiles').doc(uid).set({ displayName: 'Teszt acc' });
  await db.collection('private_user_data').doc(uid).set({ email: 'teszt@example.test' });
  await db.collection('community_bans').doc(uid).set({ reason: 'teszt' });
  await db.collection('notifications').doc('notif-1').set({ recipientUid: uid, title: 'x' });
  await db.collection('live_feed_posts').doc('post-1').set({
    authorId: uid,
    text: 'szia',
    imagePublicId: `huhs_users/${uid}/post`,
    imageUrl: `https://res.cloudinary.com/fjxo93em/image/upload/v1/huhs_users/${uid}/post.jpg`,
  });
  // Kapcsolatok mindket iranyban (a parjat is takaritani kell).
  await db.collection('community_profiles').doc(uid).collection('connections').doc('uid-mas').set({ at: 1 });
  await db.collection('community_profiles').doc('uid-mas').collection('connections').doc(uid).set({ at: 1 });
  return { uid, profile };
}

const destroyCalls = () => cloudinaryCalls.filter((call) => call.url.includes('/image/destroy'));

before(() => {
  installFetchStub();
});

beforeEach(async () => {
  cloudinaryMode = 'fail';
  listedResources = [];
  cloudinaryCalls = [];
  await resetDatabase();
});

test('Cloudinary 401 eseten IS befejezodik a felhasznalo torlese', async () => {
  const { uid, profile } = await seedUser('uid-teszt-acc');
  // Eloszor rogzitjuk, hogy a kiindulas valoban „letezik" (nem vacuus a teszt).
  assert.equal((await db.collection('community_profiles').doc(uid).get()).exists, true);
  assert.equal((await db.collection('live_feed_posts').doc('post-1').get()).exists, true);

  const result = await deleteUserReferences(uid, profile);

  // A Cloudinary elutasitotta a kepeket (401) — ez lathato is marad:
  assert.equal(result.cloudinaryListPending, true);
  assert.deepEqual(
    [...result.cloudinaryDestroyFailed].sort(),
    [`huhs_users/${uid}/post`, `huhs_users/${uid}/profile`].sort(),
  );
  assert.equal(destroyCalls().length, 2, 'a kepek torleset tenylegesen meg kellett probalni');

  // A LENYEG: a Firestore-takaritas a Cloudinary-hiba ellenere lefutott.
  assert.equal((await db.collection('community_profiles').doc(uid).get()).exists, false, 'a profil nem tunt el');
  assert.equal((await db.collection('public_profiles').doc(uid).get()).exists, false);
  assert.equal((await db.collection('private_user_data').doc(uid).get()).exists, false);
  assert.equal((await db.collection('community_bans').doc(uid).get()).exists, false);
  assert.equal((await db.collection('notifications').doc('notif-1').get()).exists, false);
  assert.equal((await db.collection('live_feed_posts').doc('post-1').get()).exists, false);
  assert.equal(
    (await db.collection('community_profiles').doc('uid-mas').collection('connections').doc(uid).get()).exists,
    false,
    'a par kapcsolata is torlendo',
  );
  // A profil alkollekciojaval egyutt a sajat kapcsolata is eltunt.
  assert.equal((await db.collection('community_profiles').doc(uid).collection('connections').get()).empty, true);
});

test('sikeres Cloudinary-val minden torlodik es nincs fuggoben maradek', async () => {
  const { uid, profile } = await seedUser('uid-rendben');
  cloudinaryMode = 'ok';
  listedResources = [];

  const result = await deleteUserReferences(uid, profile);

  assert.equal(result.cloudinaryListPending, false);
  assert.deepEqual(result.cloudinaryDestroyFailed, []);
  assert.equal(result.manualCleanupRequired, false);
  assert.equal((await db.collection('community_profiles').doc(uid).get()).exists, false);
  assert.equal((await db.collection('public_profiles').doc(uid).get()).exists, false);
  assert.deepEqual(
    destroyCalls()
      .map((call) => decodeURIComponent(call.body).match(/public_id=([^&]+)/)?.[1])
      .sort(),
    [`huhs_users/${uid}/post`, `huhs_users/${uid}/profile`].sort(),
  );
});

test('a regi (public_id nelkuli) kep jelzest kap, nem pedig csendes sikert', async () => {
  const uid = 'uid-regi-kep';
  const profile = {
    displayName: 'Regi kep',
    profileImageUrl: 'https://res.cloudinary.com/fjxo93em/image/upload/v1/huhs_users/uid-regi-kep/legacy.jpg',
  };
  await db.collection('community_profiles').doc(uid).set(profile);

  const result = await deleteUserReferences(uid, profile);

  assert.equal(result.manualCleanupRequired, true);
  assert.equal((await db.collection('community_profiles').doc(uid).get()).exists, false);
});

test('a 15 percenkenti ujraproba csak a kepekkel foglalkozik, es helyreall', async () => {
  const uid = 'uid-maradek';

  // 1) Amig a Cloudinary 401-et ad, a rekord fuggoben marad, de nem veszit adatot.
  cloudinaryMode = 'fail';
  const failed = await retryCloudinaryAssetCleanup(uid, { cloudinaryListPending: true });
  assert.equal(failed.listPending, true);
  assert.deepEqual(failed.assets, []);

  // 2) Amint a Cloudinary ujra valaszol, a maradek kep torlodik -> nincs tobb teendo.
  cloudinaryCalls = [];
  cloudinaryMode = 'ok';
  listedResources = [{ public_id: `huhs_users/${uid}/profile` }];
  const healed = await retryCloudinaryAssetCleanup(uid, {
    cloudinaryListPending: true,
    pendingCloudinaryAssets: [],
  });
  assert.equal(healed, null);
  assert.ok(
    destroyCalls().some((call) => decodeURIComponent(call.body).includes(`huhs_users/${uid}/profile`)),
    'a lista alapjan meg kell probalni a kep torleset',
  );
});

test('ismert public_id eseten nem keri le ujra a kepek listajat', async () => {
  const uid = 'uid-ismert';
  cloudinaryMode = 'ok';

  const healed = await retryCloudinaryAssetCleanup(uid, {
    cloudinaryListPending: false,
    pendingCloudinaryAssets: [`huhs_users/${uid}/profile`],
  });

  assert.equal(healed, null);
  assert.equal(
    cloudinaryCalls.filter((call) => call.url.includes('/resources/image/upload')).length,
    0,
    'ismert public_id eseten nincs szukseg a (draga) lista-lekerdezesre',
  );
  assert.equal(destroyCalls().length, 1);
});
