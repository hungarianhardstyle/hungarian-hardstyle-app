const nodeTest = require('node:test');
// ⚠️ Ez a suite a Firestore-, Auth- ÉS Functions-emulátoron fut (a valódi
// callable-t hívja HTTP-n, ezért kell a 9099 és az 5001 port is). Emulátor
// nélkül a suite HAMIS pirosat mutatna — ezért ilyenkor minden teszt
// „kihagyva" jelzést kap, a suite pedig zölden lefut.
//
// Futtatás emulátorral (a repository gyökeréből):
//   npx firebase emulators:exec --only firestore,auth,functions --project demo-huhs \
//     "node functions/label-purchase-limit.test.cjs"
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

/**
 * A VÁSÁRLÁS-ELLENŐRZÉS KÉRÉS-KERETE — valódi viselkedés, emulátoron.
 *
 * MIÉRT: a vásárlások **helyreállítása** egyszerre több birtokolt terméket
 * ellenőriz. A régi keret (10/perc/fiók) miatt a **11.** kiadvány már
 * `resource-exhausted`-be futott volna. A tulajdonos döntése (2026-09-22):
 * „előbb csak a szerveroldali rész".
 *
 * Amit ez a teszt MÉR (nem forrásszöveget keres, hanem hív):
 *  1. a **régi út VÁLTOZATLAN**: 10 hívás után a 11. `resource-exhausted`;
 *  2. a **helyreállítás** (`restore: true`) a 11. hívásnál **még megy**;
 *  3. a **közös összkeret** befogja a lazább vödröt: a 21. hívás
 *     `resource-exhausted` — tehát a jelző nem a korlát megkerülése;
 *  4. a **kevert út** (10 + 10) sem megy 20 fölé.
 *
 * Futtatás (a repository gyökeréből):
 *   npx firebase emulators:exec --only firestore,auth,functions \
 *     --project demo-huhs "node --test functions/label-purchase-limit.test.cjs"
 *
 * ⚠️ A hívások szándékosan **hibás tokennel** mennek: a Google Play-t nem
 * hívjuk valódi vásárlással. Az számít, hogy a válasz **nem**
 * `resource-exhausted` — vagyis a kérés **átjutott a kereten**, és csak a
 * Play-ellenőrzésnél állt meg (hiányzó szolgáltatásfiók vagy elutasított token).
 * Ezért a teszt a "nem keret-blokk" állítást méri, nem a pontos hibakódot.
 */

const projectId = process.env.GCLOUD_PROJECT || 'demo-huhs';
const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST || '127.0.0.1:9099';
const functionsHost = process.env.FUNCTIONS_EMULATOR_HOST || '127.0.0.1:5001';
const authBase = `http://${authHost}/identitytoolkit.googleapis.com/v1`;
const callableBase = `http://${functionsHost}/${projectId}/us-central1`;

/** Külön fiók minden méréshez: a keret fiókonként ÉS percenként számol. */
async function freshToken() {
  const email = `label-limit-${Date.now()}-${Math.random().toString(36).slice(2)}@example.test`;
  const response = await fetch(`${authBase}/accounts:signUp?key=demo-key`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      email,
      password: 'Valid-test-password-123!',
      returnSecureToken: true,
    }),
  });
  const body = await response.json();
  assert.equal(response.status, 200, JSON.stringify(body));
  assert.ok(body.idToken, 'nincs idToken az emulátortól');
  return body.idToken;
}

/**
 * Egy ellenőrzés-hívás a megadott fiókkal. Visszaadja a hibakódot (`null`, ha
 * nem hiba). A termék-azonosító és a `releaseId` SZABÁLYOS, hogy a kérés a
 * keret után jusson el a Play-ellenőrzésig; a token szándékosan hamis.
 */
async function verifyWith(authToken, { restore, releaseId = 12699 } = {}) {
  const data = {
    releaseId,
    productId: `huhs_release_${releaseId}_mp3_320`,
    purchaseToken: 'emulator-invalid-token',
  };
  if (restore !== undefined) data.restore = restore;
  const response = await fetch(`${callableBase}/verifyLabelPurchase`, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      authorization: `Bearer ${authToken}`,
    },
    body: JSON.stringify({ data }),
  });
  const body = await response.json();
  return body?.error?.status || null;
}

async function codesFor(authToken, count, options) {
  const codes = [];
  for (let i = 0; i < count; i++) {
    codes.push(await verifyWith(authToken, options));
  }
  return codes;
}

test('a normál út kerete VÁLTOZATLAN: a 11. hívás resource-exhausted', async () => {
  const codes = await codesFor(await freshToken(), 11, {});
  for (const code of codes.slice(0, 10)) {
    assert.notEqual(code, 'RESOURCE_EXHAUSTED', `váratlan keret-blokk: ${code}`);
  }
  assert.equal(codes[10], 'RESOURCE_EXHAUSTED', 'a régi 10/perc keret nem lazulhat');
});

test('a helyreállítás (restore: true) a 11. hívásnál MÉG megy', async () => {
  const codes = await codesFor(await freshToken(), 11, { restore: true });
  assert.notEqual(
    codes[10],
    'RESOURCE_EXHAUSTED',
    'a helyreállításnak külön vödröt kell kapnia (a 11. kiadvány is elférjen)',
  );
});

test('a régi jelző nélküli és a restore út vödre KÜLÖN (nem ugyanaz a keret)', async () => {
  const authToken = await freshToken();
  // 10 normál hívás felemészti a `label_purchase` vödröt…
  const normal = await codesFor(authToken, 10, {});
  assert.ok(
    normal.every((code) => code !== 'RESOURCE_EXHAUSTED'),
    'az első 10 normál hívás elfér',
  );
  // …a helyreállítás viszont a saját vödréből megy tovább.
  const restore = await verifyWith(authToken, { restore: true });
  assert.notEqual(
    restore,
    'RESOURCE_EXHAUSTED',
    'a restore ne fogyassza a normál vásárlás-ellenőrzés keretét',
  );
});

test('a KÖZÖS összkeret befogja a lazább vödröt: a 21. hívás resource-exhausted', async () => {
  const codes = await codesFor(await freshToken(), 21, { restore: true });
  assert.notEqual(codes[19], 'RESOURCE_EXHAUSTED', 'a 20. hívás még elférjen');
  assert.equal(
    codes[20],
    'RESOURCE_EXHAUSTED',
    'a 21. hívást az összkeretnek meg kell fognia',
  );
});

test('a kevert út is legfeljebb 20/perc (nincs kijátszás a két vödörrel)', async () => {
  const authToken = await freshToken();
  const codes = [
    ...(await codesFor(authToken, 10, {})),
    ...(await codesFor(authToken, 11, { restore: true })),
  ];
  assert.equal(
    codes[20],
    'RESOURCE_EXHAUSTED',
    'a két vödör együtt sem adhat 20/perc fölé',
  );
});
