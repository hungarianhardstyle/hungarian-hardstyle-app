// A HARD-adatok törlése a fiók törlésekor — a VALÓDI `deleteUserReferences`-en mérve.
//
// Futtatás (a repó gyökeréből, Firestore-emulátoron):
//   firebase emulators:exec --only firestore --project demo-huhs \
//     "node functions/hard-deletion.test.cjs"
//
// Emulátor nélkül minden teszt „kihagyva" (nem hamis piros), mint az
// `account-deletion.test.cjs`-ben.
const nodeTest = require('node:test');
const assert = require('node:assert/strict');
const SKIP = process.env.FIRESTORE_EMULATOR_HOST
  ? false
  : 'Firestore-emulátor nélkül kihagyva (FIRESTORE_EMULATOR_HOST nincs beállítva)';
const test = (name, fn) => nodeTest.test(name, { skip: SKIP }, fn);

process.env.CLOUDINARY_API_KEY = 'test-key';
process.env.CLOUDINARY_API_SECRET = 'test-secret';

let db;
let deleteUserReferences;
if (!SKIP) {
  const { initializeApp } = require('firebase-admin/app');
  const { getFirestore } = require('firebase-admin/firestore');
  // A ./index.js betöltéskor initializeApp-ot hív: a default appnak előbb kell léteznie.
  const app = initializeApp({ projectId: process.env.GCLOUD_PROJECT || 'demo-huhs' });
  db = getFirestore(app, 'hungarian-hardstyle');
  ({ __deleteUserReferencesForTests: deleteUserReferences } = require('./index.js'));
  // A Cloudinary-hívás hálózati: üres találatot adó helyettesítő (nincs képe a tesztfióknak).
  globalThis.fetch = async () => ({ ok: true, status: 200, json: async () => ({ resources: [], result: 'ok' }) });
}

const COLLECTIONS = [
  'community_profiles', 'public_profiles', 'private_user_data', 'community_bans',
  'hard_wallet_links', 'hard_wallet_owners', 'hard_wallet_challenges', 'hard_audit_logs',
];

nodeTest.beforeEach(async () => {
  if (SKIP) return;
  for (const name of COLLECTIONS) await db.recursiveDelete(db.collection(name));
});

async function seedHard(uid, address) {
  await db.collection('community_profiles').doc(uid).set({ displayName: 'HARD teszt', role: 'partygoer' });
  await db.collection('hard_wallet_links').doc(uid).set({ address });
  await db.collection('hard_wallet_owners').doc(address).set({ uid });
  await db.collection('hard_wallet_challenges').doc(`c-${uid}`).set({ uid, address, used: true });
  await db.collection('hard_audit_logs').doc(`l-${uid}`).set({ uid, action: 'wallet_linked', address });
}

test('fióktörléskor a tárcakötés, a tulajdonos-térkép, a kihívás és a napló is törlődik', async () => {
  await seedHard('uid-a', 'ADDR-A');
  assert.equal((await db.collection('hard_wallet_links').doc('uid-a').get()).exists, true);

  await deleteUserReferences('uid-a', { displayName: 'HARD teszt' });

  for (const [collection, id] of [
    ['hard_wallet_links', 'uid-a'],
    ['hard_wallet_owners', 'ADDR-A'],
    ['hard_wallet_challenges', 'c-uid-a'],
    ['hard_audit_logs', 'l-uid-a'],
  ]) {
    assert.equal((await db.collection(collection).doc(id).get()).exists, false, `${collection}/${id} megmaradt`);
  }
});

test('a törölt fiók tárcája újra köthető másik fiókhoz (nem marad blokkolva)', async () => {
  await seedHard('uid-a', 'ADDR-A');
  await deleteUserReferences('uid-a', {});
  assert.equal((await db.collection('hard_wallet_owners').doc('ADDR-A').get()).exists, false);
});

test('más fiók HARD-adata érintetlen marad', async () => {
  await seedHard('uid-a', 'ADDR-A');
  await seedHard('uid-b', 'ADDR-B');
  await deleteUserReferences('uid-a', {});
  for (const [collection, id] of [
    ['hard_wallet_links', 'uid-b'],
    ['hard_wallet_owners', 'ADDR-B'],
    ['hard_wallet_challenges', 'c-uid-b'],
    ['hard_audit_logs', 'l-uid-b'],
  ]) {
    assert.equal((await db.collection(collection).doc(id).get()).exists, true, `${collection}/${id} elveszett`);
  }
});

test('HARD-adat nélküli fióknál a törlés hibátlanul lefut', async () => {
  await db.collection('community_profiles').doc('uid-c').set({ displayName: 'Nincs HARD' });
  await deleteUserReferences('uid-c', {});
  assert.equal((await db.collection('community_profiles').doc('uid-c').get()).exists, false);
});
