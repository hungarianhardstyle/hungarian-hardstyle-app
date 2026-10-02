const nodeTest = require('node:test');
// ⚠️ Ez a suite a Firestore-EMULÁTORON fut, mert a VALÓDI függvényt méri
// (`runTwitchLiveNotice`), és a Firestore-írásokat is ellenőrzi. Emulátor nélkül
// a Firebase Admin nem talál hitelesítést, ezért ilyenkor minden teszt
// „kihagyva" jelzést kap, a suite pedig zölden lefut.
//
// Futtatás (a repository gyökeréből):
//   npx firebase emulators:exec --only firestore --project demo-huhs \
//     "node functions/twitch-live.test.cjs"
const EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST;
const TEST_SKIP = EMULATOR_HOST
  ? false
  : 'Firestore-emulátor nélkül kihagyva (FIRESTORE_EMULATOR_HOST nincs beállítva)';
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
const { getFirestore } = require('firebase-admin/firestore');

/**
 * A TWITCH-ÉLŐ FIGYELŐ **teljes útja** — a döntéstől a széles pushig.
 *
 * MIÉRT (a tulajdonos kérése): *„érzekelje ha indul a twitch stream”* és
 * *„szóljon push mindenkinek, amikor elindítod a Twitch-streamet”*. A tiszta
 * döntés külön tesztekkel mérve van (`twitch-live-plan.test.cjs`), a **hívó**
 * viszont eddig csak forrás-linttel: nem volt mérve, hogy tényleg
 *  (1) kiolvassa a jelölést a Firestore-ból,
 *  (2) meghívja a Twitch-állapot lekérdezését,
 *  (3) **egyszer** küldjön adásonként (a második kör ne küldjön újra),
 *  (4) a WordPress-admin push-végpontot a **helyes payload-alakkal** hívja,
 *  (5) bejövő értesítést írjon a profiloknak (a dedupe-kulcs hash-elt azonosítójával),
 *  (6) az adás végén **törölje a jelölést**, hogy a következő adás újra szóljon.
 *
 * Ezt a suite a **Firestore-emulátoron**, a **valódi** `runTwitchLiveNotice`
 * függvénnyel méri; csak a **hálózat** van helyettesítve (Twitch GraphQL és a
 * WordPress-végpont) — külső szolgáltatás és éles adat nélkül.
 *
 * Futtatás (a repository gyökeréből):
 *   npx firebase emulators:exec --only firestore --project demo-huhs \
 *     "node functions/twitch-live.test.cjs"
 */

const projectId = process.env.GCLOUD_PROJECT || 'demo-huhs';
const databaseId = 'hungarian-hardstyle';

const app = initializeApp({ projectId });
const db = getFirestore(app, databaseId);

const { __twitchLiveForTests } = require('./index.js');
const { runTwitchLiveNotice } = __twitchLiveForTests;

const STATE_DOC = 'app_settings/twitch_live';
const PROFILE_UIDS = ['uid-alpha', 'uid-beta', 'uid-gamma'];

/** A Twitch GraphQL válasza — a mért éles alak szerint (2026-10-01). */
function twitchBody(stream) {
  return JSON.stringify({ data: { user: { id: '87485328', displayName: 'HungarianHardstyle', stream } } });
}

const LIVE_ONE = {
  id: '44123456789',
  title: 'HUHS Live #42 — hardstyle session',
  viewersCount: 128,
  createdAt: '2026-10-02T18:00:00Z',
  type: 'live',
  game: { name: 'Music' },
  previewImageURL: 'https://static-cdn.jtvnw.net/previews-ttv/live_user_hungarianhardstyle-640x360.jpg',
};
const LIVE_TWO = { ...LIVE_ONE, id: '44123456790', title: 'HUHS Live #43 — esti session' };

/** Hálózat-helyettesítő: a Twitch-válasz és a WordPress-hívások rögzítése. */
function installFetchStub() {
  const calls = { twitch: 0, wordpress: [], mode: 'offline', stream: LIVE_ONE, fail: false };
  const realFetch = globalThis.fetch;
  globalThis.fetch = async (url, options = {}) => {
    const target = String(url);
    if (target.includes('gql.twitch.tv')) {
      calls.twitch += 1;
      if (calls.fail) throw new Error('hálózati hiba (szimulált)');
      const body = calls.mode === 'live' ? twitchBody(calls.stream) : twitchBody(null);
      return { ok: true, status: 200, text: async () => body, json: async () => JSON.parse(body) };
    }
    if (target.includes('/huhs/v1/admin')) {
      calls.wordpress.push({ url: target, payload: JSON.parse(options.body || '{}') });
      return {
        ok: true,
        status: 200,
        json: async () => ({ ok: true, sent: 1027, queued: true }),
        text: async () => '{"ok":true}',
      };
    }
    throw new Error(`nem várt hívás a tesztben: ${target}`);
  };
  return { calls, restore: () => { globalThis.fetch = realFetch; } };
}

let stub;

before(async () => {
  // A profilok, akiknek a bejövő értesítés készül (a figyelő ezeket olvassa).
  for (const uid of PROFILE_UIDS) {
    await db.collection('private_user_data').doc(uid).set({ notificationPreferences: { enabled: true } });
  }
});

beforeEach(async () => {
  stub = installFetchStub();
  await db.doc(STATE_DOC).delete();
  const existing = await db.collection('notifications').get();
  await Promise.all(existing.docs.map((doc) => doc.ref.delete()));
});

after(() => {
  stub?.restore();
});

test('adás nélkül semmi nem történik (nincs push, nincs jelölés)', async () => {
  stub.calls.mode = 'offline';
  const result = await runTwitchLiveNotice();

  assert.equal(result.skipped, 'offline');
  assert.equal(stub.calls.wordpress.length, 0, 'nem mehet ki push adás nélkül');
  assert.equal((await db.doc(STATE_DOC).get()).exists, false, 'nem írhatunk jelölést adás nélkül');
  const notifications = await db.collection('notifications').get();
  assert.equal(notifications.size, 0);
});

test('élő adásnál MINDENKINEK szól: bejövő értesítés + széles push', async () => {
  stub.calls.mode = 'live';
  stub.calls.stream = LIVE_ONE;
  const result = await runTwitchLiveNotice();

  assert.equal(result.notified, true);
  assert.equal(result.streamId, LIVE_ONE.id);
  assert.equal(result.created, PROFILE_UIDS.length, 'minden profilnak kell bejövő értesítés');
  assert.equal(result.pushed, 1027, 'a széles push küldött darabszáma a WordPress válaszából');

  // A WordPress-hívás PONTOS alakja (ez az, amit élesben is küldünk).
  assert.equal(stub.calls.wordpress.length, 1, 'adásonként EGYSZER hívjuk a push-végpontot');
  const payload = stub.calls.wordpress[0].payload;
  assert.equal(payload.action, 'send_push');
  assert.equal(payload.targetType, 'custom');
  assert.equal(payload.url, 'https://www.twitch.tv/hungarianhardstyle');
  // ⚠️ MÉRT RÉSZLET (2026-10-02): a push szövege a **katalógusból** jön (minden
  // adásnál ugyanaz a cím), a `{title}` helyőrzőbe viszont a **adás címe** kerül —
  // ezért a cím és az adás címe NEM ugyanaz, és ez így helyes.
  const { TEXTS } = require('./notification-texts.js');
  const catalogue = TEXTS.twitch_live.hu;
  assert.equal(payload.title, catalogue.title);
  assert.equal(payload.body, catalogue.body.replace('{title}', LIVE_ONE.title));
  assert.ok(payload.body.includes(LIVE_ONE.title), 'a törzsben ott kell lennie az adás címének');

  // A jelölés: erről az adásról többé nem szólunk. A tárolt cím az ADÁS címe
  // (a kártyához/állapothoz), nem a push szövege.
  const state = (await db.doc(STATE_DOC).get()).data();
  assert.equal(state.announcedStreamId, LIVE_ONE.id);
  assert.equal(state.title, LIVE_ONE.title);
  assert.equal(state.viewers, LIVE_ONE.viewersCount);

  // A bejövő értesítések a dedupe-kulcs HASH-elt azonosítójával jönnek létre.
  for (const uid of PROFILE_UIDS) {
    const id = crypto.createHash('sha256').update(`twitch_live:${LIVE_ONE.id}:${uid}`).digest('hex');
    const doc = await db.collection('notifications').doc(id).get();
    assert.equal(doc.exists, true, `hiányzó értesítés: ${uid}`);
    assert.equal(doc.get('recipientUid'), uid);
    assert.equal(doc.get('type'), 'twitch_live');
  }
});

test('ugyanarról az adásról MÁSODSZOR nem szól (ez a lényeg)', async () => {
  stub.calls.mode = 'live';
  stub.calls.stream = LIVE_ONE;
  await runTwitchLiveNotice();
  const firstWordpress = stub.calls.wordpress.length;
  const firstNotifications = (await db.collection('notifications').get()).size;

  // A következő ötperces kör ugyanazt az adást látja.
  const second = await runTwitchLiveNotice();

  assert.equal(second.skipped, 'already-announced');
  assert.equal(stub.calls.wordpress.length, firstWordpress, 'NEM mehet ki második push');
  assert.equal((await db.collection('notifications').get()).size, firstNotifications);
});

test('az adás végén a jelölés törlődik — a következő adás újra szól', async () => {
  stub.calls.mode = 'live';
  stub.calls.stream = LIVE_ONE;
  await runTwitchLiveNotice();

  // Az adás véget ér.
  stub.calls.mode = 'offline';
  const ended = await runTwitchLiveNotice();
  assert.equal(ended.skipped, 'stream-ended');
  const cleared = (await db.doc(STATE_DOC).get()).data();
  assert.equal(cleared.announcedStreamId, '', 'a jelölést törölni kell, különben a következő adás néma marad');

  // Új adás: MEGINT szól.
  stub.calls.mode = 'live';
  stub.calls.stream = LIVE_TWO;
  const again = await runTwitchLiveNotice();
  assert.equal(again.notified, true);
  assert.equal(again.streamId, LIVE_TWO.id);
  assert.equal(stub.calls.wordpress.length, 2, 'a második adásról is ki kell mennie a pushnak');

  const state = (await db.doc(STATE_DOC).get()).data();
  assert.equal(state.announcedStreamId, LIVE_TWO.id);
});

test('a tulajdonosi kapcsoló kikapcsolva nem küld (de a jelölést sem írja)', async () => {
  await db.doc(STATE_DOC).set({ enabled: false });
  stub.calls.mode = 'live';
  const result = await runTwitchLiveNotice();

  assert.equal(result.skipped, 'disabled');
  assert.equal(stub.calls.wordpress.length, 0);
  const state = (await db.doc(STATE_DOC).get()).data();
  assert.equal(state.enabled, false);
  assert.ok(!state.announcedStreamId, 'kikapcsolt figyelőnél nem jelölünk be adást');
});

test('ha a Twitch nem érhető el, nem tippelünk (nincs push, a jelölés marad)', async () => {
  stub.calls.mode = 'live';
  await runTwitchLiveNotice();
  const before = (await db.doc(STATE_DOC).get()).data();

  stub.calls.fail = true;
  const result = await runTwitchLiveNotice();

  assert.equal(result.skipped, 'unreachable');
  assert.equal(stub.calls.wordpress.length, 1, 'hálózati hiba esetén nem küldünk');
  const after = (await db.doc(STATE_DOC).get()).data();
  assert.equal(after.announcedStreamId, before.announcedStreamId, 'a jelölést nem rontjuk el');
});
