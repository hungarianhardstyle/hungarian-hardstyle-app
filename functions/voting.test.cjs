const { test } = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');

function fixture() {
  const records = new Map();
  const ref = path => ({
    path,
    async get() {
      return { exists: records.has(path), data: () => records.get(path) };
    },
  });
  const collection = name => ({
    doc: id => ref(`${name}/${id}`),
  });
  class HttpsError extends Error {
    constructor(code, message) {
      super(message);
      this.code = code;
    }
  }
  const context = {
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
    records,
  };
}

const user = uid => ({ auth: { uid, token: { firebase: { sign_in_provider: 'password' } } } });
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

test('vendég is szavazhat, de achievement pontot nem kap', async () => {
  const fixtureState = fixture();
  const result = await fixtureState.call({ seasonId: 2026, deviceId: device, votes: completeBallot() }, guest('guest-1'));
  assert.equal(result.ok, true);
  assert.equal(result.achievementPoints, 0);
  const status = await fixtureState.status({ seasonId: 2026, deviceId: device }, guest('guest-1'));
  assert.equal(status.votedCategories.length, 5);
  assert.equal([...fixtureState.records.keys()].filter((key) => key.startsWith('achievement_ledger/')).length, 0);
});

test('ugyanarról a készülékről másik fiókkal sem lehet újra szavazni', async () => {
  const fixtureState = fixture();
  await fixtureState.call({ seasonId: 2026, deviceId: device, votes: completeBallot() }, guest('guest-1'));
  await assert.rejects(
    fixtureState.call({ seasonId: 2026, deviceId: device, votes: completeBallot() }, user('user-2')),
    { code: 'already-exists' },
  );
});
