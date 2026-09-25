const nodeTest = require('node:test');
// ⚠️ Ez INTEGRÁCIÓS suite: a Firestore-, Auth- ÉS Functions-emulátort használja
// (a valódi callable-okat hívja HTTP-n). Emulátor nélkül a Firebase Admin nem
// talál hitelesítést, és a suite HAMIS pirosat mutatna — ezért ilyenkor minden
// teszt „kihagyva" jelzést kap, a suite pedig zölden lefut.
//
// Futtatás emulátorral (a repository gyökeréből):
//   npx firebase emulators:exec --only firestore,auth,functions --project demo-huhs \
//     "node --test functions/registration.integration.test.cjs"
// Ehhez a `FIREBASE_DEBUG_MODE=true` + `FIREBASE_DEBUG_FEATURES={"skipTokenVerification":true}`
// környezet kell (App Check-hez kötött callable-ok), vagy használd:
//   node tools/run-function-tests.mjs --emulator
const EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST;
const TEST_SKIP = EMULATOR_HOST
  ? false
  : 'Firestore-emulátor nélkül kihagyva (FIRESTORE_EMULATOR_HOST nincs beállítva)';
// ⚠️ APP CHECK A CALLABLE-OKNÁL (mért viselkedés, 2026-09-25): a
// `checkRegistrationEligibility` és a `checkDisplayNameAvailability` szerveroldalon
// `runWith({enforceAppCheck: true})`, és a `firebase-functions` HTTP-rétege a
// **hiányzó** App Check-tokent **emulátorban is** elutasítja:
//   https.js: `if (tokenStatus.app === "MISSING" && options.enforceAppCheck)
//              throw new HttpsError("unauthenticated", "Unauthenticated")`
// → ez volt a 6 piros teszt 401-e (nem a mi kódunk, és nem is az Auth hiánya).
// Az emulátor nem tud valódi App Check-tokent hitelesíteni, ezért a futtató
// (tools/run-function-tests.mjs) a `skipTokenVerification` debug-szolgáltatással
// indítja a functions runtime-ot, és ilyenkor egy aláíratlan (csak dekódolt)
// tokent küldünk. Debug-mód nélkül ezek a tesztek NEM hazudnak zöldet: kihagyva
// futnak, egyértelmű indokkal.
const APP_CHECK_DEBUG = process.env.FIREBASE_DEBUG_MODE === 'true';
const APP_CHECK_SKIP = TEST_SKIP
  ? false
  : APP_CHECK_DEBUG
    ? false
    : 'App Check-hez kötött callable — emulátorban FIREBASE_DEBUG_MODE=true kell '
      + '(lásd tools/run-function-tests.mjs)';
const APP_CHECK_TOKEN = APP_CHECK_DEBUG
  ? [
      Buffer.from(JSON.stringify({alg: 'none', typ: 'JWT'})).toString('base64url'),
      Buffer.from(JSON.stringify({
        sub: '1:1234567890:android:emulator',
        exp: 4102444800,
      })).toString('base64url'),
      'c2ln',
    ].join('.')
  : '';
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
const {initializeApp} = require('firebase-admin/app');
const {getFirestore} = require('firebase-admin/firestore');

const projectId = process.env.GCLOUD_PROJECT || 'hungarian-hardstyle';
const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST || '127.0.0.1:9099';
const functionsHost = process.env.FUNCTIONS_EMULATOR_HOST || '127.0.0.1:5001';
const authBase = `http://${authHost}/identitytoolkit.googleapis.com/v1`;
const functionsBase = `http://${functionsHost}/${projectId}/us-central1`;
const app = initializeApp({projectId});
const markerDb = getFirestore(app, 'hungarian-hardstyle');

let account;

async function post(url, body, headers = {}) {
  const response = await fetch(url, {
    method: 'POST',
    headers: {'content-type': 'application/json', ...headers},
    body: JSON.stringify(body),
  });
  return {response, body: await response.json()};
}

async function auth(path, body) {
  return post(`${authBase}/${path}?key=demo-key`, body);
}

async function callable(name, data, token) {
  const headers = token ? {authorization: `Bearer ${token}`} : {};
  if (APP_CHECK_TOKEN) headers['X-Firebase-AppCheck'] = APP_CHECK_TOKEN;
  return post(`${functionsBase}/${name}`, {
    data,
  }, headers);
}

function markerId(email) {
  return crypto.createHash('sha256')
    .update(`huhs-deleted:${email.trim().toLowerCase()}`)
    .digest('hex');
}

async function seedMarker(email, data) {
  await markerDb.collection('deleted_identity_hashes').doc(markerId(email)).set(data);
}

before(async () => {
  const email = `registration-${Date.now()}@example.test`;
  const result = await auth('accounts:signUp', {
    email,
    password: 'Valid-test-password-123!',
    returnSecureToken: true,
  });
  assert.equal(result.response.status, 200, JSON.stringify(result.body));
  account = {email, ...result.body};
});

after(async () => {
  // The emulator is disposable; no production account or password is used.
});

test('új e-mailes regisztráció és megerősítetlen belépés', async () => {
  const signIn = await auth('accounts:signInWithPassword', {
    email: account.email,
    password: 'Valid-test-password-123!',
    returnSecureToken: true,
  });
  assert.equal(signIn.response.status, 200);
  const lookup = await auth('accounts:lookup', {idToken: signIn.body.idToken});
  assert.equal(lookup.response.status, 200);
  assert.equal(lookup.body.users[0].emailVerified, false);
});

test('regisztrációs jogosultság és megerősítőlevél-hívás', {skip: APP_CHECK_SKIP}, async () => {
  const eligibility = await callable('checkRegistrationEligibility', {
    email: account.email,
  });
  assert.equal(eligibility.response.status, 200, JSON.stringify(eligibility.body));
  const verification = await auth('accounts:sendOobCode', {
    requestType: 'VERIFY_EMAIL',
    idToken: account.idToken,
  });
  assert.equal(verification.response.status, 200, JSON.stringify(verification.body));
});

test('minimális profil létrehozása megerősítetlen e-maillel', async () => {
  const result = await callable('claimDisplayName', {
    displayName: `Emulator User ${Date.now()}`,
  }, account.idToken);
  assert.equal(result.response.status, 200, JSON.stringify(result.body));
});

test('azonos UID névfoglalásának idempotens újrapróbálása', async () => {
  const name = `Retry User ${Date.now()}`;
  const first = await callable('claimDisplayName', {displayName: name}, account.idToken);
  const second = await callable('claimDisplayName', {displayName: name}, account.idToken);
  assert.equal(first.response.status, 200);
  assert.equal(second.response.status, 200);
});

test('foglalt név Auth létrehozása előtt felismerhető, a foglalás pedig atomikus', {skip: APP_CHECK_SKIP}, async () => {
  const name = `Reserved User ${Date.now()}`;
  const before = await callable('checkDisplayNameAvailability', {displayName: name});
  assert.equal(before.response.status, 200, JSON.stringify(before.body));
  assert.equal(before.body.result.available, true);

  const owner = await auth('accounts:signUp', {
    email: `owner-${Date.now()}@example.test`,
    password: 'Valid-test-password-123!',
    returnSecureToken: true,
  });
  assert.equal(owner.response.status, 200, JSON.stringify(owner.body));
  const claim = await callable('claimDisplayName', {displayName: name}, owner.body.idToken);
  assert.equal(claim.response.status, 200, JSON.stringify(claim.body));

  const after = await callable('checkDisplayNameAvailability', {displayName: name});
  assert.equal(after.response.status, 200, JSON.stringify(after.body));
  assert.equal(after.body.result.available, false);

  const competing = await auth('accounts:signUp', {
    email: `competing-${Date.now()}@example.test`,
    password: 'Valid-test-password-123!',
    returnSecureToken: true,
  });
  assert.equal(competing.response.status, 200, JSON.stringify(competing.body));
  const collision = await callable(
    'claimDisplayName',
    {displayName: name},
    competing.body.idToken,
  );
  assert.equal(collision.response.status, 409, JSON.stringify(collision.body));
});

test('App Check kikapcsolva, Auth továbbra is szükséges a névfoglaláshoz', async () => {
  const result = await callable('claimDisplayName', {displayName: 'No Token User'});
  assert.equal(result.response.status, 401);
});

test('a friss, részleges fiók takarítási futás előtt megmarad', async () => {
  const current = await auth('accounts:lookup', {idToken: account.idToken});
  assert.equal(current.response.status, 200);
  assert.equal(current.body.users[0].localId, account.localId);
});

test('önkéntes és egyszerű admin törlés után az e-mail újraregisztrálható', {skip: APP_CHECK_SKIP}, async () => {
  for (const reason of ['voluntary-deletion', 'administrator-deletion']) {
    const email = `${reason}-${Date.now()}@example.test`;
    await seedMarker(email, {
      blocked: false,
      reason,
      source: 'account-deletion',
      deletionType: 'account-deletion',
    });
    const result = await callable('checkRegistrationEligibility', {email});
    assert.equal(result.response.status, 200);
  }
});

test('explicit admin és abuse tiltás blokkolja az újraregisztrációt', {skip: APP_CHECK_SKIP}, async () => {
  for (const [reason, source] of [['administrator-ban', 'admin'], ['abuse', 'abuse-system']]) {
    const email = `${reason}-${Date.now()}@example.test`;
    await seedMarker(email, {blocked: true, reason, source, deletionType: 'identity-ban'});
    const result = await callable('checkRegistrationEligibility', {email});
    assert.equal(result.response.status, 403);
  }
});

test('felhasználók közötti blokkolás nem érinti a regisztrációt', {skip: APP_CHECK_SKIP}, async () => {
  const email = `user-block-${Date.now()}@example.test`;
  await seedMarker(email, {blocked: true, reason: 'user-block', source: 'community', deletionType: 'user-block'});
  const result = await callable('checkRegistrationEligibility', {email});
  assert.equal(result.response.status, 200);
});

test('legacy, ok nélküli törlési marker nem blokkol', {skip: APP_CHECK_SKIP}, async () => {
  const email = `legacy-${Date.now()}@example.test`;
  await seedMarker(email, {blocked: true, reason: 'administrator-deletion'});
  const result = await callable('checkRegistrationEligibility', {email});
  assert.equal(result.response.status, 200);
});
