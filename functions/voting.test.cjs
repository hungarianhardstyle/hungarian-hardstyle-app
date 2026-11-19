const { test } = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');

function fixture({ active = true, failCatalog = false } = {}) {
  const records = new Map();
  const ref = path => ({
    path,
    async get() {
      return { exists: records.has(path), data: () => records.get(path) };
    },
  });
  const collection = name => ({
    doc: id => ref(`${name}/${id}`),
    where: (field, operator, value) => ({ limit: () => ({ get: async () => ({
      empty: ![...records].some(([key, data]) => key.startsWith(`${name}/`) && data[field] === value),
    }) }) }),
  });
  class HttpsError extends Error {
    constructor(code, message) {
      super(message);
      this.code = code;
    }
  }
  const context = {
    process: { env: { HUHS_VOTING_EMAIL_KEY: 'synthetic-fixture-key' } },
    WORDPRESS_BASE_URL: 'https://example.test',
    AbortSignal,
    deletedIdentityKey: (email) => email.trim().toLowerCase(),
    isExplicitIdentityBan: (marker) => marker.blocked === true,
    fetch: async () => ({ ok: !failCatalog, json: async () => ({
      active, seasonId: 2026,
      categories: Object.entries(completeBallot()).map(([key, ids]) => ({
        key, candidates: ids.map(id => ({ id })),
      })),
    }) }),
    exports: {},
    functions: { https: { onCall: handler => handler }, runWith: () => ({ https: { onCall: handler => handler } }) },
    HttpsError,
    db: {
      collection,
      runTransaction: async callback => callback({
        get: transactionRef => transactionRef.get(),
        create: (transactionRef, value) => records.set(transactionRef.path, value),
        set: (transactionRef, value, options) => records.set(
          transactionRef.path,
          options?.merge ? { ...(records.get(transactionRef.path) || {}), ...value } : value,
        ),
      }),
    },
    FieldValue: { serverTimestamp: () => ({}) },
    crypto: require('node:crypto'),
    awardAchievementPoints: async (uid, points, sourceKey) => {
      records.set(`achievement_ledger/${uid}:${sourceKey}`, { points });
      return { changed: true };
    },
  };
  const source = fs.readFileSync(`${__dirname}/index.js`, 'utf8');
  const start = source.indexOf('const VOTING_REQUIRED_COUNTS');
  const end = source.indexOf('exports.notifyConnectionRequest');
  vm.runInNewContext(source.slice(start, end), context);
  return {
    call: context.exports.submitVotingBallot,
    status: context.exports.getVotingStatus,
    hasVerifiedVotingBallot: vm.runInNewContext('hasVerifiedVotingBallot', context),
    records,
  };
}

const user = (uid, email = `${uid}@example.test`, verified = true) => ({
  auth: { uid, token: { email, email_verified: verified, firebase: { sign_in_provider: 'password' } } },
});
const guest = uid => ({ auth: { uid, token: { firebase: { sign_in_provider: 'anonymous' } } } });
const device = 'device-installation-12345678901234567890';
const completeBallot = () => ({
  hungarian_hardstyle_dj: [1, 2, 3, 4, 5],
  hungarian_hardcore_dj: [6, 7, 8],
  hungarian_track: [9, 10],
  hungarian_organizer: [11],
  international_dj: [12, 13, 14, 15, 16],
});

test('a teljes szavazólap egyszerre menthető, a külföldi kategória öt jelöltet kér', async () => {
  const fixtureState = fixture();
  const result = await fixtureState.call({ seasonId: 2026, deviceId: device, votes: completeBallot() }, user('user-1'));
  assert.equal(result.ok, true);
  assert.equal(
    [...fixtureState.records.keys()].filter((key) => key.startsWith('voting_votes/')).length,
    5,
  );
  assert.equal(result.achievementPoints, 10);
});

test('a szavazási achievement csak egyszer jár ugyanarra az évadra', async () => {
  const fixtureState = fixture();
  await fixtureState.call({ seasonId: 2026, deviceId: device, votes: completeBallot() }, user('user-1'));
  await assert.rejects(
    fixtureState.call({ seasonId: 2026, deviceId: device, votes: completeBallot() }, user('user-1')),
    { code: 'already-exists' },
  );
  assert.equal([...fixtureState.records.keys()].filter((key) => key.startsWith('achievement_ledger/')).length, 1);
});

test('részleges szavazólap szerveroldalon elutasításra kerül', async () => {
  const fixtureState = fixture();
  const partial = { ...completeBallot() };
  delete partial.international_dj;
  await assert.rejects(
    fixtureState.call({ seasonId: 2026, deviceId: device, votes: partial }, user('user-1')),
    { code: 'invalid-argument' },
  );
});

test('duplikált jelölt és ismételt kategória nem menthető', async () => {
  const fixtureState = fixture();
  const duplicate = completeBallot();
  duplicate.international_dj = [12, 12, 13, 14, 15];
  await assert.rejects(
    fixtureState.call({ seasonId: 2026, votes: duplicate }, user('user-1')),
    { code: 'invalid-argument' },
  );
  await fixtureState.call({ seasonId: 2026, deviceId: device, votes: completeBallot() }, user('user-1'));
  await assert.rejects(
    fixtureState.call({ seasonId: 2026, deviceId: device, votes: completeBallot() }, user('user-1')),
    { code: 'already-exists' },
  );
});

test('vendég és meg nem erősített fiók nem adhat le szavazatot', async () => {
  const fixtureState = fixture();
  for (const voter of [guest('guest-1'), user('unverified', undefined, false)]) {
    await assert.rejects(fixtureState.call({ seasonId: 2026, deviceId: device, votes: completeBallot() }, voter),
      { code: 'permission-denied' });
  }
  assert.equal(fixtureState.records.size, 0);
});

test('ugyanarról a készülékről másik fiókkal sem lehet újra szavazni', async () => {
  const fixtureState = fixture();
  await fixtureState.call({ seasonId: 2026, deviceId: device, votes: completeBallot() }, user('user-1'));
  await assert.rejects(
    fixtureState.call({ seasonId: 2026, deviceId: device, votes: completeBallot() }, user('user-2')),
    { code: 'already-exists' },
  );
});

for (const appFirst of [true, false]) {
  test(`${appFirst ? 'app → web' : 'web → app'}: egyszeri leadás és közös státusz`, async () => {
    const state = fixture();
    const voter = user('same-user');
    const app = { seasonId: 2026, deviceId: device, votes: completeBallot() };
    const web = { seasonId: 2026, votes: completeBallot() };
    await state.call(appFirst ? app : web, voter);
    assert.equal((await state.status(appFirst ? web : app, voter)).votedCategories.length, 5);
    await assert.rejects(state.call(appFirst ? web : app, voter), { code: 'already-exists' });
    assert.equal([...state.records.keys()].filter(key => key.startsWith('achievement_ledger/')).length, 1);
  });
}

test('ugyanaz az igazolt cím új UID-val sem szavazhat újra és nem látja a régi választásokat', async () => {
  const state = fixture();
  const data = { seasonId: 2026, votes: completeBallot() };
  await state.call(data, user('first', 'Example@example.test'));
  const other = user('second', 'example@example.test');
  await assert.rejects(state.call(data, other), { code: 'already-exists' });
  const current = await state.status(data, other);
  assert.equal(current.votedCategories.length, 5);
  assert.deepEqual(Object.keys(current.selectedCandidateIds), []);
});

test('lezárt évad, hibás jelölt és elérhetetlen katalógus esetén nem ír szavazatot', async () => {
  const voter = user('user');
  const data = { seasonId: 2026, votes: completeBallot() };
  await assert.rejects(fixture({ active: false }).call(data, voter), { code: 'failed-precondition' });
  await assert.rejects(fixture({ failCatalog: true }).call(data, voter), { code: 'unavailable' });
  const state = fixture();
  data.votes.hungarian_organizer = [123456];
  await assert.rejects(state.call(data, voter), { code: 'invalid-argument' });
  assert.equal(state.records.size, 0);
});

test('a webes szavazó megmarad profil nélkül, a bizonyítottan tiltott cím pedig nem szavazhat', async () => {
  const state = fixture();
  const data = { seasonId: 2026, votes: completeBallot() };
  const web = { uid: 'web', emailVerified: true };
  assert.equal(await state.hasVerifiedVotingBallot(web), false);
  state.records.set('deleted_identity_hashes/banned@example.test', { blocked: true });
  await assert.rejects(state.call(data, user('banned')), { code: 'permission-denied' });
  await state.call(data, user(web.uid));
  assert.equal(await state.hasVerifiedVotingBallot(web), true);
  assert.equal(await state.hasVerifiedVotingBallot({ ...web, emailVerified: false }), false);
});
