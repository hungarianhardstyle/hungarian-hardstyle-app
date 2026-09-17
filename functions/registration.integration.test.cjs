const { test, before, after } = require('node:test');
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
  return post(`${functionsBase}/${name}`, {
    data,
  }, token ? {authorization: `Bearer ${token}`} : {});
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

test('regisztrációs jogosultság és megerősítőlevél-hívás', async () => {
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

test('foglalt név Auth létrehozása előtt felismerhető, a foglalás pedig atomikus', async () => {
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

test('önkéntes és egyszerű admin törlés után az e-mail újraregisztrálható', async () => {
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

test('explicit admin és abuse tiltás blokkolja az újraregisztrációt', async () => {
  for (const [reason, source] of [['administrator-ban', 'admin'], ['abuse', 'abuse-system']]) {
    const email = `${reason}-${Date.now()}@example.test`;
    await seedMarker(email, {blocked: true, reason, source, deletionType: 'identity-ban'});
    const result = await callable('checkRegistrationEligibility', {email});
    assert.equal(result.response.status, 403);
  }
});

test('felhasználók közötti blokkolás nem érinti a regisztrációt', async () => {
  const email = `user-block-${Date.now()}@example.test`;
  await seedMarker(email, {blocked: true, reason: 'user-block', source: 'community', deletionType: 'user-block'});
  const result = await callable('checkRegistrationEligibility', {email});
  assert.equal(result.response.status, 200);
});

test('legacy, ok nélküli törlési marker nem blokkol', async () => {
  const email = `legacy-${Date.now()}@example.test`;
  await seedMarker(email, {blocked: true, reason: 'administrator-deletion'});
  const result = await callable('checkRegistrationEligibility', {email});
  assert.equal(result.response.status, 200);
});
