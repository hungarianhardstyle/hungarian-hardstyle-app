const { test } = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const crypto = require('node:crypto');

function fixture() {
  const records = new Map();
  const ref = path => ({
    path, collection: name => collection(`${path}/${name}`),
    get: async () => ({ exists: records.has(path), data: () => records.get(path) }),
    set: async value => records.set(path, value),
  });
  const collection = path => ({
    doc: id => ref(`${path}/${id}`), orderBy() { return this; },
    limit() { return this; }, startAfter() { return this; },
    async get() {
      const docs = [...records].filter(([key]) => key.startsWith(`${path}/`)).map(([key, value]) => ({ id: key.split('/').pop(), data: () => value }));
      return { docs, size: docs.length };
    },
  });
  class HttpsError extends Error { constructor(code, message) { super(message); this.code = code; } }
  let allowed = true;
  const context = {
    exports: {}, functions: { https: { onCall: handler => handler }, runWith: () => ({ https: { onCall: handler => handler } }) }, HttpsError, crypto,
    db: { collection, runTransaction: async fn => fn({ get: ref => ref.get(), create: (ref, value) => records.set(ref.path, value), delete: ref => records.delete(ref.path) }) },
    FieldPath: { documentId: () => '__name__' },
    FieldValue: { serverTimestamp: () => ({ toMillis: () => 1 }) },
    isAdmin: (_, profile) => profile.accessRole === 'admin', allowCall: async () => allowed,
    awardAchievementPoints: async () => {},
    fetch: async () => ({ ok: true, json: async () => ({ id: 123 }) }), AbortSignal,
  };
  const source = fs.readFileSync(`${__dirname}/index.js`, 'utf8');
  vm.runInNewContext(source.slice(source.indexOf('exports.articleComments ='), source.indexOf('const WORDPRESS_BASE_URL')), context);
  return { call: context.exports.articleComments, records, denyRate: () => { allowed = false; } };
}
const user = uid => ({ auth: { uid, token: { firebase: { sign_in_provider: 'anonymous' } } } });
test('guest identity is server generated; retries do not duplicate; articles stay separate', async () => {
  const { call, records } = fixture();
  const data = { action: 'create', postId: 123, id: 'test', text: 'Hello', authorName: 'admin' };
  await call(data, user('guest'));
  await call(data, user('guest'));
  assert.equal(records.size, 1);
  const result = await call({ postId: 123 }, {});
  assert.match(result.items[0].authorName, /^Unknown User \d{4}$/);
  assert.equal((await call({ postId: 124 }, {})).items.length, 0);
});
test('unauthenticated, empty, too long and rate-limited writes rejected', async () => {
  const f = fixture();
  const data = { postId: 123, id: 'x', action: 'create', text: 'hello' };
  await assert.rejects(f.call(data, {}), { code: 'unauthenticated' });
  for (const text of ['', ' '.repeat(3), 'x'.repeat(2001)]) await assert.rejects(f.call({ ...data, text }, user('u')), { code: 'invalid-argument' });
  f.denyRate();
  await assert.rejects(f.call(data, user('u')), { code: 'resource-exhausted' });
});
test('other users cannot overwrite or delete; owner can delete; report is private', async () => {
  const { call, records } = fixture();
  const data = { postId: 123, id: 'x', action: 'create', text: 'hello' };
  await call(data, user('owner'));
  await assert.rejects(call(data, user('other')), { code: 'already-exists' });
  await assert.rejects(call({ ...data, action: 'delete' }, user('other')), { code: 'permission-denied' });
  await call({ ...data, action: 'report' }, user('other'));
  assert.equal([...records.keys()].filter(key => key.startsWith('chat_reports/')).length, 1);
  await call({ ...data, action: 'delete' }, user('owner'));
  assert.equal((await call({ postId: 123 }, {})).items.length, 0);
});
test('banned user cannot send and invalid article/path rejected', async () => {
  const { call, records } = fixture();
  records.set('community_bans/banned', {});
  await assert.rejects(call({ postId: 123, action: 'create', id: 'x', text: 'hi' }, user('banned')), { code: 'permission-denied' });
  await assert.rejects(call({ postId: -1 }, {}), { code: 'invalid-argument' });
  await assert.rejects(call({ postId: 123, action: 'delete', id: '../x' }, user('u')), { code: 'invalid-argument' });
});
