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
const { doc, setDoc, updateDoc, deleteDoc, getDoc, Timestamp } = require('firebase/firestore');

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

// ---------------------------------------------------------------------------
// A felületi nyelv (`language`) — a szerveroldali értesítések nyelve
//
// A tulajdonos kérése (2026-09-25): *„az értesítések is"* angolul. A címzett
// nyelvét a szerver a `community_profiles/{uid}.language` mezőből olvassa
// (`functions/notification-texts.js`), ezért a kliensnek írhatónak KELL lennie —
// de csak a két ismert értékre, és csak a saját profilján.

test('a felületi nyelvet a saját profilba be lehet írni (hu/en)', async () => {
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), 'community_profiles', 'user-lang'),
      profilePayload(FREE_NAME, { email: 'lang@example.com' }),
    );
  });
  const db = firestoreFor('user-lang', 'lang@example.com');
  await assertSucceeds(
    updateDoc(doc(db, 'community_profiles', 'user-lang'), { language: 'en' }),
  );
  await assertSucceeds(
    updateDoc(doc(db, 'community_profiles', 'user-lang'), { language: 'hu' }),
  );
});

test('ismeretlen nyelvkódot a szabály elutasít', async () => {
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), 'community_profiles', 'user-lang2'),
      profilePayload(FREE_NAME, { email: 'lang2@example.com' }),
    );
  });
  const db = firestoreFor('user-lang2', 'lang2@example.com');
  await assertFails(
    updateDoc(doc(db, 'community_profiles', 'user-lang2'), { language: 'de' }),
  );
});

test('más profiljának nyelvét nem lehet átírni', async () => {
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), 'community_profiles', 'user-lang3'),
      profilePayload(FREE_NAME, { email: 'lang3@example.com' }),
    );
  });
  const db = firestoreFor('user-lang4', 'lang4@example.com');
  await assertFails(
    updateDoc(doc(db, 'community_profiles', 'user-lang3'), { language: 'en' }),
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

/* ------------------------------------------------------------------ */
/* A TÖRÖLT FIÓK jelzője                                               */
/* ------------------------------------------------------------------ */

/*
 * A tulajdonos jelzése: *„adminként nem törli az usert, googleval regelt"*.
 *
 * Élő mérés szerint a törlés LEFUTOTT (a függvény 200-at adott, az Auth-fiók és
 * a profil is eltűnt), a Google-fiók viszont egy új bejelentkezéssel UGYANAZZAL a
 * UID-dal újra létrejön. Ezért a törlést a `deleted_user_ids` jelzővel kell
 * felismerni — ehhez viszont a törölt felhasználónak a SAJÁT sorát olvasnia kell
 * tudnia, különben az app nem tudja megmondani, mi történt.
 *
 * Ez a négy teszt pontosan ezt a négy állítást méri.
 */

const USER_A = 'user-deleted-a';
const USER_B = 'user-deleted-b';

beforeEach(async () => {
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'deleted_user_ids', USER_A), {
      deletedAt: Timestamp.now(),
    });
  });
});

test('a törölt felhasználó a SAJÁT törlés-jelzőjét el tudja olvasni', async () => {
  const db = firestoreFor(USER_A, 'a@example.com');
  const snapshot = await assertSucceeds(
    getDoc(doc(db, 'deleted_user_ids', USER_A)),
  );
  assert.equal(snapshot.exists(), true, 'a jelzőnek látszania kell');
});

test('más felhasználó törlés-jelzője NEM olvasható', async () => {
  const db = firestoreFor(USER_B, 'b@example.com');
  await assertFails(getDoc(doc(db, 'deleted_user_ids', USER_A)));
});

test('a törlés-jelzőt kliensből írni sem lehet (sem törölni)', async () => {
  const db = firestoreFor(USER_B, 'b@example.com');
  await assertFails(setDoc(doc(db, 'deleted_user_ids', USER_B), { deletedAt: Timestamp.now() }));
  await assertFails(deleteDoc(doc(db, 'deleted_user_ids', USER_B)));
});

test('a törölt felhasználó profilja közben tiltott marad (isRegistered)', async () => {
  // Ez a lényeg: a törölt fiók MINDEN `isRegistered()` szabálytól elesik, ezért a
  // kliensnek a jelzőből kell megértenie, hogy ki kell jelentkeztetni — enélkül a
  // felhasználó értelmezhetetlen hibákat kap.
  const db = firestoreFor(USER_A, 'a@example.com');
  await assertFails(
    setDoc(doc(db, 'community_profiles', USER_A), profilePayload('Teszt Törölt')),
  );
});

/* ------------------------------------------------------------------ */
/* Chat-@hivatkozás (mention) — a `mentions` mező szabálya             */
/* ------------------------------------------------------------------ */

/*
 * A tulajdonos kérése: *„egy @xy betűvel tudjak hivatkozni a chaten cikkre,
 * djre, szervezőre, eseményre, kiadványra vagy személyre/userre"*.
 *
 * A `live_feed_posts` create-szabálya `keys().hasOnly([...])`, ezért a
 * `mentions` mező **nincs** benne automatikusan: enélkül a kliens írása
 * elutasításra kerülne. Ez a szabály viszont önmagában nem elég a teljes
 * védelemhez, mert a Firestore-szabály nyelvében **nem lehet listán
 * végigiterálni** — itt csak a darabszám (max 10) és az ELSŐ elem alakja
 * mérhető. A többi elem alakját és a jogosultságot a szerver (a
 * `publishChatPost` callable → `sanitizeMentions`) ellenőrzi; azt a
 * `functions/chat-mention-plan.test.cjs` méri.
 */

const mention = (type, id, label) => ({ type, id, label });

const chatCreatePayload = (authorUid, extra = {}) => ({
  authorId: authorUid,
  authorName: 'Teszt Elek',
  authorImageUrl: '',
  authorRole: 'partygoer',
  authorAccessRole: 'none',
  isAnonymous: false,
  text: 'Nézd meg @Kobakologia!',
  replyToText: '',
  imageUrl: '',
  reactions: {},
  reactionBy: {},
  pinned: false,
  createdAt: Timestamp.now(),
  ...extra,
});

// A create-szabály a `firebase.sign_in_provider` claimet is nézi (nem lehet
// névtelen), ezért a tokenbe beadjuk — a bejelentkezési mód jelszavas.
const chatWriter = (uid, email) =>
  env.authenticatedContext(uid, {
    email,
    firebase: { sign_in_provider: 'password' },
  }).firestore();

test('a SZEMÉLY- és a TARTALOM-hivatkozás is bekerülhet (a mentions mező átment a whitelisten)', async () => {
  const db = chatWriter('mention-author', 'mention@example.com');

  await assertSucceeds(
    setDoc(
      doc(db, 'live_feed_posts', 'mention-post-1'),
      chatCreatePayload('mention-author', {
        mentions: [
          mention('user', 'uid-1', 'Kobakologia'),
          mention('event', '12505', 'Hard Base Classic'),
        ],
      }),
    ),
  );

  const stored = await getDoc(doc(db, 'live_feed_posts', 'mention-post-1'));
  assert.equal(stored.data().mentions.length, 2, 'a hivatkozások elmentődtek');
});

test('a 10 hivatkozás belefér, a 11. már nem (a szabály a DARABSZÁMOT nézi)', async () => {
  const db = chatWriter('mention-author-2', 'mention2@example.com');
  const ten = Array.from({ length: 10 }, (_, index) =>
    mention('user', `uid-${index}`, `Tag ${index}`),
  );

  await assertSucceeds(
    setDoc(
      doc(db, 'live_feed_posts', 'mention-post-10'),
      chatCreatePayload('mention-author-2', { mentions: ten }),
    ),
  );
  await assertFails(
    setDoc(
      doc(db, 'live_feed_posts', 'mention-post-11'),
      chatCreatePayload('mention-author-2', {
        mentions: [...ten, mention('user', 'uid-10', 'Tag 10')],
      }),
    ),
  );
});

test('a whitelist-en kívüli mező és a rossz alakú hivatkozás továbbra is elutasított', async () => {
  const db = chatWriter('mention-author-3', 'mention3@example.com');
  const payload = (extra) => chatCreatePayload('mention-author-3', extra);

  // 1) a create-whitelistbe nem tartozó mező — a `mentions` bevétele nem nyitott
  //    kaput arra, hogy bármi más is bekerüljön a dokumentumba.
  await assertFails(
    setDoc(doc(db, 'live_feed_posts', 'mention-post-x1'), payload({ mentionCount: 1 })),
  );

  // 2) az ELSŐ hivatkozás alakja: csak `type`, `id`, `label` lehet benne.
  await assertFails(
    setDoc(
      doc(db, 'live_feed_posts', 'mention-post-x2'),
      payload({
        mentions: [{ type: 'user', id: 'uid-1', label: 'Kobakologia', extra: 'nem oda való' }],
      }),
    ),
  );

  // 3) a hosszkorlátok (id ≤ 64, label ≤ 80) az első elemen.
  await assertFails(
    setDoc(
      doc(db, 'live_feed_posts', 'mention-post-x3'),
      payload({ mentions: [mention('user', 'uid-1', 'y'.repeat(81))] }),
    ),
  );
  await assertFails(
    setDoc(
      doc(db, 'live_feed_posts', 'mention-post-x4'),
      payload({ mentions: [mention('user', 'x'.repeat(65), 'Kobakologia')] }),
    ),
  );

  // 4) a `mentions` csak lista lehet.
  await assertFails(
    setDoc(
      doc(db, 'live_feed_posts', 'mention-post-x5'),
      payload({ mentions: { type: 'user', id: 'uid-1', label: 'Kobakologia' } }),
    ),
  );
});
