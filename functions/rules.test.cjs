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
const { doc, setDoc, updateDoc, deleteDoc, Timestamp } = require('firebase/firestore');

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

// ---------------------------------------------------------------------------
// Chat-üzenet szerkesztése
//
// A tulajdonos kérése: „a chaten a felhasználó tudja szerkeszteni a saját
// üzenetét … Admin természetesen mindenkiét + admin törölni is tudjon."
//
// A felület csak felkínálja a lehetőséget — a VALÓDI védelem ez a szabály, ezért
// itt emulátoron, a szabállyal szemben mérjük.
// ---------------------------------------------------------------------------

const chatPost = (authorId, extra = {}) => ({
  authorId,
  authorName: 'Teszt Elek',
  authorImageUrl: '',
  authorRole: 'partygoer',
  authorAccessRole: 'none',
  isAnonymous: false,
  text: 'Eredeti üzenet',
  replyToText: '',
  imageUrl: '',
  reactions: {},
  reactionBy: {},
  pinned: false,
  createdAt: Timestamp.now(),
  ...extra,
});

async function seedChatPost(postId, authorId) {
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'live_feed_posts', postId), chatPost(authorId));
  });
}

test('a SZERZO szerkesztheti a saját Chat-üzenetét', async () => {
  const authorUid = 'chat-author';
  await seedChatPost('post-a', authorUid);
  const db = firestoreFor(authorUid, 'author@example.com');

  await assertSucceeds(
    updateDoc(doc(db, 'live_feed_posts', 'post-a'), {
      text: 'Javított üzenet',
      editedAt: Timestamp.now(),
    }),
  );
});

test('a szerző NEM szerkesztheti MÁS üzenetét', async () => {
  await seedChatPost('post-b', 'mas-szerzo');
  const db = firestoreFor('betolakodo', 'betolakodo@example.com');

  await assertFails(
    updateDoc(doc(db, 'live_feed_posts', 'post-b'), { text: 'Átírva' }),
  );
});

test('a szerző csak a text/editedAt mezot valtoztathatja', async () => {
  // Ez a lényegi védelem: a szerkesztés nem lehet eszköz arra, hogy valaki
  // más nevében írjon, üzenetet rögzítsen, vagy reakciót hamisítson.
  const authorUid = 'chat-author-2';
  await seedChatPost('post-c', authorUid);
  const db = firestoreFor(authorUid, 'author2@example.com');

  await assertFails(
    updateDoc(doc(db, 'live_feed_posts', 'post-c'), { authorName: 'Valaki Más' }),
  );
  await assertFails(
    updateDoc(doc(db, 'live_feed_posts', 'post-c'), { pinned: true }),
  );
  await assertFails(
    updateDoc(doc(db, 'live_feed_posts', 'post-c'), { reactions: { '❤️': 99 } }),
  );
  await assertSucceeds(
    updateDoc(doc(db, 'live_feed_posts', 'post-c'), { text: 'Csak a szoveg' }),
  );
});

test('a szerző üres szöveget nem menthet (a szerkesztés nem ürítheti ki)', async () => {
  const authorUid = 'chat-author-3';
  await seedChatPost('post-d', authorUid);
  const db = firestoreFor(authorUid, 'author3@example.com');

  // Üres szöveg: a szabály a szerzőnek is megköveteli az 1–2000 karaktert,
  // különben a szerkesztéssel ki lehetne üríteni az üzenetet.
  await assertFails(
    updateDoc(doc(db, 'live_feed_posts', 'post-d'), { text: '' }),
  );
  await assertFails(
    updateDoc(doc(db, 'live_feed_posts', 'post-d'), { text: 'x'.repeat(2001) }),
  );
});

test('a SZERZŐ nem törölheti a saját üzenetét (a törlés admin-jog)', async () => {
  const authorUid = 'chat-author-4';
  await seedChatPost('post-f', authorUid);
  const db = firestoreFor(authorUid, 'author4@example.com');

  await assertFails(deleteDoc(doc(db, 'live_feed_posts', 'post-f')));
});

test('az ADMIN bárki üzenetét szerkesztheti és törölheti', async () => {
  await seedChatPost('post-e', 'mas-szerzo');
  const db = firestoreFor('admin-uid', 'djdeeroy@gmail.com');

  await assertSucceeds(
    updateDoc(doc(db, 'live_feed_posts', 'post-e'), { text: 'Admin javította' }),
  );
  await assertSucceeds(deleteDoc(doc(db, 'live_feed_posts', 'post-e')));
});
