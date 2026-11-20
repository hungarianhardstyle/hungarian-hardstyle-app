// A HARD-backend szerveroldali döntései a VALÓDI függvényeken mérve (kor-kapu, kihívás-takarítás).
//
// Futtatás (a repó gyökeréből, Firestore-emulátoron):
//   firebase emulators:exec --only firestore --project demo-huhs \
//     "node functions/hard-backend.test.cjs"
//
// Emulátor nélkül minden teszt „kihagyva" (nem hamis piros).
const nodeTest = require('node:test');
const assert = require('node:assert/strict');
const SKIP = process.env.FIRESTORE_EMULATOR_HOST
  ? false
  : 'Firestore-emulátor nélkül kihagyva (FIRESTORE_EMULATOR_HOST nincs beállítva)';
const test = (name, fn) => nodeTest.test(name, { skip: SKIP }, fn);

process.env.CLOUDINARY_API_KEY = 'test-key';
process.env.CLOUDINARY_API_SECRET = 'test-secret';

let db;
let requireHardAdult;
let cleanupExpiredHardChallenges;
if (!SKIP) {
  const { initializeApp } = require('firebase-admin/app');
  const { getFirestore } = require('firebase-admin/firestore');
  const app = initializeApp({ projectId: process.env.GCLOUD_PROJECT || 'demo-huhs' });
  db = getFirestore(app, 'hungarian-hardstyle');
  ({
    __requireHardAdultForTests: requireHardAdult,
    __cleanupExpiredHardChallengesForTests: cleanupExpiredHardChallenges,
  } = require('./index.js'));
}

nodeTest.beforeEach(async () => {
  if (SKIP) return;
  await db.recursiveDelete(db.collection('community_profiles'));
  await db.recursiveDelete(db.collection('hard_wallet_challenges'));
});

const yearsAgo = (years) => {
  const d = new Date();
  d.setUTCFullYear(d.getUTCFullYear() - years);
  return d.toISOString().slice(0, 10);
};
const profile = (uid, data) => db.collection('community_profiles').doc(uid).set({ displayName: uid, ...data });
const denied = (promise) =>
  assert.rejects(promise, (error) => error?.code === 'permission-denied' || error?.httpErrorCode?.canonicalName === 'PERMISSION_DENIED');

test('kor-kapu: a nagykorú (18+) átmegy', async () => {
  await profile('felnott', { birthDate: yearsAgo(30) });
  await requireHardAdult('felnott');
});

test('kor-kapu: a kiskorú, a hiányzó és az érvénytelen dátum, a hiányzó profil is elutasított', async () => {
  await profile('kiskoru', { birthDate: yearsAgo(16) });
  await profile('nincs-datum', {});
  await profile('rossz-datum', { birthDate: 'nem-datum' });
  await denied(requireHardAdult('kiskoru'));
  await denied(requireHardAdult('nincs-datum'));
  await denied(requireHardAdult('rossz-datum'));
  await denied(requireHardAdult('nincs-profil'));
});

test('kor-kapu határeset: aki holnap tölti be a 18-at, ma még elutasított', async () => {
  const d = new Date();
  d.setUTCFullYear(d.getUTCFullYear() - 18);
  d.setUTCDate(d.getUTCDate() + 1); // holnap tölti be a 18-at
  await profile('majdnem', { birthDate: d.toISOString().slice(0, 10) });
  await denied(requireHardAdult('majdnem'));
});

test('kihívás-takarítás: a régen lejárt törlődik, a friss és a most lejárt megmarad', async () => {
  const now = 10 * 60 * 60 * 1000;
  const col = db.collection('hard_wallet_challenges');
  await col.doc('regi').set({ uid: 'u', expiresAtMs: now - 3 * 60 * 60 * 1000 });
  await col.doc('most-lejart').set({ uid: 'u', expiresAtMs: now - 5 * 60 * 1000 }); // türelmi időn belül
  await col.doc('friss').set({ uid: 'u', expiresAtMs: now + 5 * 60 * 1000 });
  assert.equal(await cleanupExpiredHardChallenges(now), 1);
  assert.equal((await col.doc('regi').get()).exists, false);
  assert.equal((await col.doc('most-lejart').get()).exists, true);
  assert.equal((await col.doc('friss').get()).exists, true);
});

test('kihívás-takarítás: üres gyűjteménynél 0-t ad, és nem hibázik', async () => {
  assert.equal(await cleanupExpiredHardChallenges(Date.now()), 0);
});
