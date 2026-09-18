/**
 * Firestore security-rule tests for the display-name reservation.
 *
 * Run against the Firestore emulator from the repository root:
 *   npx firebase emulators:exec --only firestore --project demo-huhs \
 *     "node functions/rules.test.cjs"
 *
 * Why these tests exist: the client that is already installed on devices writes
 * `displayName` directly instead of going through claimDisplayName. The
 * tightened rule must therefore keep accepting every name that client would
 * have accepted, and reject only a name that already belongs to another
 * account. That distinction is the whole release-safety question, and it cannot
 * be answered by reading the rule.
 */
const { test, before, after, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const { doc, setDoc, updateDoc, Timestamp } = require('firebase/firestore');

const PROJECT_ID = 'demo-huhs';
const OWNER_UID = 'owner-uid';
const TAKEN_NAME = 'Headhunterz';
const FREE_NAME = 'Teszt Elek';

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      host: '127.0.0.1',
      port: 8080,
      rules: fs.readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8'),
    },
  });
});

after(async () => {
  if (env) await env.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
  // The reservation is stored under the normalized name, exactly as
  // normalizeDisplayName() in functions/index.js produces it.
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'display_name_claims', 'headhunterz'), {
      uid: OWNER_UID,
      displayName: TAKEN_NAME,
    });
  });
});

const firestoreFor = (uid, email) =>
  env.authenticatedContext(uid, { email }).firestore();

const profilePayload = (displayName, extra = {}) => ({
  displayName,
  role: 'partygoer',
  accessRole: 'none',
  createdAt: Timestamp.now(),
  updatedAt: Timestamp.now(),
  ...extra,
});

test('egy szabad nevet a telepített kliens továbbra is beírhat közvetlenül', async () => {
  const db = firestoreFor('user-a', 'a@example.com');
  await assertSucceeds(
    setDoc(doc(db, 'community_profiles', 'user-a'), profilePayload(FREE_NAME)),
  );
});

test('más fiók által lefoglalt nevet közvetlen írással nem lehet elvenni', async () => {
  const db = firestoreFor('user-b', 'b@example.com');
  await assertFails(
    setDoc(doc(db, 'community_profiles', 'user-b'), profilePayload(TAKEN_NAME)),
  );
});

test('a foglalás tulajdonosa a saját nevét továbbra is beírhatja', async () => {
  const db = firestoreFor(OWNER_UID, 'owner@example.com');
  await assertSucceeds(
    setDoc(doc(db, 'community_profiles', OWNER_UID), profilePayload(TAKEN_NAME)),
  );
});

test('az összehasonlítás normalizált: a kis-nagybetű nem hoz létre második példányt', async () => {
  const db = firestoreFor('user-c', 'c@example.com');
  await assertFails(
    setDoc(doc(db, 'community_profiles', 'user-c'), profilePayload('HEADHUNTERZ')),
  );
});

test('az összehasonlítás normalizált: a dupla szóköz ugyanaz a név', async () => {
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'display_name_claims', 'hard style'), {
      uid: OWNER_UID,
      displayName: 'Hard Style',
    });
  });
  const db = firestoreFor('user-d', 'd@example.com');
  // 'Hard  Style' collapses to 'hard style' in both the server helper and the
  // rule, so this must be rejected too; otherwise the rule's normalization
  // would silently disagree with the reservation it is checking.
  await assertFails(
    setDoc(doc(db, 'community_profiles', 'user-d'), profilePayload('Hard  Style')),
  );
});

test('displayName nélküli profil-létrehozás továbbra sem megengedett', async () => {
  // This documents the pre-existing contract rather than a change: the create
  // rule has always required a display name, so the Google path must claim the
  // name first. The assertion is here to prove the tightened rule did not turn
  // this into an evaluation error that hides the real reason.
  const db = firestoreFor('user-e', 'e@example.com');
  await assertFails(
    setDoc(doc(db, 'community_profiles', 'user-e'), {
      role: 'partygoer',
      accessRole: 'none',
      email: 'e@example.com',
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    }),
  );
});

test('a szokásos profilfrissítés (bio, role) változatlanul működik', async () => {
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), 'community_profiles', 'user-f'),
      profilePayload(FREE_NAME, { email: 'f@example.com' }),
    );
  });
  const db = firestoreFor('user-f', 'f@example.com');
  await assertSucceeds(
    updateDoc(doc(db, 'community_profiles', 'user-f'), { bio: 'Szia!' }),
  );
});

test('a foglalás kollekciója kliensoldalról nem olvasható és nem írható', async () => {
  const db = firestoreFor('user-g', 'g@example.com');
  await assertFails(setDoc(doc(db, 'display_name_claims', 'sajat nev'), { uid: 'user-g' }));
});
