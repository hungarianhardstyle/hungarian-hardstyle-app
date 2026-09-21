const { test } = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const crypto = require('node:crypto');

function fixture() {
  const records = new Map();
  const dailyActivity = [];
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
  function isAnonymousAuth(context) {
    return context.auth?.token?.firebase?.sign_in_provider === 'anonymous' || context.auth?.token?.is_anonymous === true;
  }
  let allowed = true;
  const context = {
    exports: {}, functions: { https: { onCall: handler => handler }, runWith: () => ({ https: { onCall: handler => handler } }) }, HttpsError, crypto,
    db: { collection, runTransaction: async fn => fn({ get: ref => ref.get(), create: (ref, value) => records.set(ref.path, value), update: (ref, value) => records.set(ref.path, { ...(records.get(ref.path) || {}), ...value }), delete: ref => records.delete(ref.path) }) },
    FieldPath: { documentId: () => '__name__' },
    FieldValue: { serverTimestamp: () => ({ toMillis: () => 1 }) },
    isAdmin: (_, profile) => profile.accessRole === 'admin', allowCall: async () => allowed,
    isAnonymousAuth,
    awardAchievementPoints: async () => {},
    // A napi aktivitási pont (2026-09-20) óta a hozzászólás létrehozása ezt is
    // hívja. Az index.js ide vágott szeletében (`exports.articleComments =` …
    // `const WORDPRESS_BASE_URL`) a valódi függvény NINCS benne (az sokkal
    // lejjebb, a ~2996. sorban él), ezért itt STUB-olnunk kell — különben a
    // szelet `ReferenceError: recordDailyActivity is not defined`-dal elhal.
    // ⚠️ A stub önmagában elrejthetné, ha a valódi hívás eltűnik: ezt az
    // utolsó teszt a VALÓDI forrásból ellenőrzi.
    recordDailyActivity: async (uid, field) => {
      dailyActivity.push([uid, field]);
      return true;
    },
    createNotificationBestEffort: async () => true,
    fetch: async () => ({ ok: true, json: async () => ({ id: 123 }) }), AbortSignal,
  };
  const source = fs.readFileSync(`${__dirname}/index.js`, 'utf8');
  vm.runInNewContext(source.slice(source.indexOf('exports.articleComments ='), source.indexOf('const WORDPRESS_BASE_URL')), context);
  return { call: context.exports.articleComments, records, dailyActivity, denyRate: () => { allowed = false; } };
}
// A cikkhozzászólás regisztrációhoz kötött: csak nem névtelen Auth-token
// hozhat létre, módosíthat vagy jelenthet hozzászólást.
const registered = uid => ({ auth: { uid, token: { firebase: { sign_in_provider: 'password' } } } });
const anonymousUser = uid => ({ auth: { uid, token: { firebase: { sign_in_provider: 'anonymous' } } } });
const commentKeys = (records, postId) => [...records.keys()].filter(key => key.startsWith(`article_comments/${postId}/comments/`));

test('a regisztrált hozzászólás idempotens, és a cikkek elkülönülnek', async () => {
  const { call, records } = fixture();
  records.set('community_profiles/owner', { displayName: 'Teszt Elek' });
  const data = { action: 'create', postId: 123, id: 'test', text: 'Hello', authorName: 'admin' };
  await call(data, registered('owner'));
  await call(data, registered('owner'));
  assert.equal(commentKeys(records, 123).length, 1);
  const result = await call({ postId: 123 }, {});
  assert.equal(result.items[0].authorName, 'Teszt Elek');
  assert.equal(result.items[0].text, 'Hello');
  assert.equal((await call({ postId: 124 }, {})).items.length, 0);
});
test('névtelen, üres, túl hosszú és gyakoriság-korlátozott írás elutasítva', async () => {
  const f = fixture();
  const data = { postId: 123, id: 'x', action: 'create', text: 'hello' };
  await assert.rejects(f.call(data, {}), { code: 'unauthenticated' });
  await assert.rejects(f.call(data, anonymousUser('guest')), { code: 'unauthenticated' });
  for (const text of ['', ' '.repeat(3), 'x'.repeat(2001)]) await assert.rejects(f.call({ ...data, text }, registered('u')), { code: 'invalid-argument' });
  f.denyRate();
  await assert.rejects(f.call(data, registered('u')), { code: 'resource-exhausted' });
});
test('más nem írhatja felül és nem törölheti; a tulajdonos törölhet; a jelentés privát', async () => {
  const { call, records } = fixture();
  const data = { postId: 123, id: 'x', action: 'create', text: 'hello' };
  await call(data, registered('owner'));
  await assert.rejects(call(data, registered('other')), { code: 'already-exists' });
  await assert.rejects(call({ ...data, action: 'delete' }, registered('other')), { code: 'permission-denied' });
  await call({ ...data, action: 'report' }, registered('other'));
  assert.equal([...records.keys()].filter(key => key.startsWith('chat_reports/')).length, 1);
  await call({ ...data, action: 'delete' }, registered('owner'));
  assert.equal((await call({ postId: 123 }, {})).items.length, 0);
});
test('tiltott felhasználó nem küldhet, és érvénytelen cikk/azonosító elutasítva', async () => {
  const { call, records } = fixture();
  records.set('community_bans/banned', {});
  await assert.rejects(call({ postId: 123, action: 'create', id: 'x', text: 'hi' }, registered('banned')), { code: 'permission-denied' });
  await assert.rejects(call({ postId: -1 }, {}), { code: 'invalid-argument' });
  await assert.rejects(call({ postId: 123, action: 'delete', id: '../x' }, registered('u')), { code: 'invalid-argument' });
});
test('a válasz a megcélzott hozzászólást idézi, lánc nélkül', async () => {
  const { call, records } = fixture();
  records.set('community_profiles/owner', { displayName: 'Teszt Elek' });
  records.set('community_profiles/replier', { displayName: 'Válaszoló' });
  await call({ postId: 123, action: 'create', id: 'parent', text: 'Eredeti' }, registered('owner'));
  await call({ postId: 123, action: 'create', id: 'reply', text: 'Válasz', replyToCommentId: 'parent' }, registered('replier'));
  const stored = records.get('article_comments/123/comments/reply');
  assert.equal(stored.replyToName, 'Teszt Elek');
  assert.equal(stored.replyToText, 'Eredeti');
  assert.equal(stored.authorName, 'Válaszoló');
  const items = (await call({ postId: 123 }, {})).items;
  const reply = items.find(item => item.id === 'reply');
  assert.equal(reply.replyToName, 'Teszt Elek');
  // A válasz csak egyetlen idézetet hordoz, és nem hivatkozik tovább a szülőre.
  assert.equal(reply.replyToCommentId, undefined);
  assert.equal(items.find(item => item.id === 'parent').replyToName, '');
});

// A tulajdonos kérése: „a chaten a felhasználó tudja szerkeszteni a saját
// üzenetét, ugyanezt a cikkek alatti kommenteknél is. Admin természetesen
// mindenkiét + admin törölni is tudjon."

test('a SZERZO szerkesztheti a saját hozzászólását, és kap „szerkesztve" jelzést', async () => {
  const { call, records } = fixture();
  await call({ postId: 123, action: 'create', id: 'x', text: 'Eredeti szöveg' }, registered('owner'));

  const result = await call({ postId: 123, action: 'edit', id: 'x', text: '  Javított szöveg  ' }, registered('owner'));

  assert.equal(result.ok, true);
  assert.equal(result.text, 'Javított szöveg', 'a szoveget trimmelve taroljuk');
  assert.equal(records.get('article_comments/123/comments/x').text, 'Javított szöveg');
  // A jelzes a listaban is megjelenik, hogy a felulet ki tudja irni.
  const item = (await call({ postId: 123 }, {})).items.find(entry => entry.id === 'x');
  assert.equal(item.text, 'Javított szöveg');
  assert.ok(item.editedAt > 0, 'a szerkesztes jelzese megjelenik a valaszban');
});

test('az ADMIN/MODERATOR mas hozzaszolasat is szerkesztheti', async () => {
  const { call, records } = fixture();
  records.set('community_profiles/admin', { displayName: 'Admin', accessRole: 'admin' });
  records.set('community_profiles/mod', { displayName: 'Modi', accessRole: 'moderator' });
  await call({ postId: 123, action: 'create', id: 'x', text: 'Eredeti' }, registered('owner'));

  await call({ postId: 123, action: 'edit', id: 'x', text: 'Admin javította' }, registered('admin'));
  assert.equal(records.get('article_comments/123/comments/x').text, 'Admin javította');

  await call({ postId: 123, action: 'edit', id: 'x', text: 'Moderátor javította' }, registered('mod'));
  assert.equal(records.get('article_comments/123/comments/x').text, 'Moderátor javította');
});

test('MAS felhasznalo nem szerkesztheti a hozzaszolast', async () => {
  const { call, records } = fixture();
  records.set('community_profiles/other', { displayName: 'Másik' });
  await call({ postId: 123, action: 'create', id: 'x', text: 'Eredeti' }, registered('owner'));

  await assert.rejects(
    call({ postId: 123, action: 'edit', id: 'x', text: 'Hackelte' }, registered('other')),
    { code: 'permission-denied' },
  );
  assert.equal(records.get('article_comments/123/comments/x').text, 'Eredeti');
});

test('a szerkesztes ugyanugy ellenorzi a hosszt, mint a letrehozas', async () => {
  const { call, records } = fixture();
  await call({ postId: 123, action: 'create', id: 'x', text: 'Eredeti' }, registered('owner'));

  for (const text of ['', '   ', 'x'.repeat(2001)]) {
    await assert.rejects(call({ postId: 123, action: 'edit', id: 'x', text }, registered('owner')), {
      code: 'invalid-argument',
    });
  }
  assert.equal(records.get('article_comments/123/comments/x').text, 'Eredeti');
});

test('nem letezo hozzaszolas szerkesztese not-found', async () => {
  const { call } = fixture();
  await assert.rejects(call({ postId: 123, action: 'edit', id: 'nincs', text: 'x' }, registered('owner')), {
    code: 'not-found',
  });
});

// A napi aktivitási pont (2026-09-20) óta a létrehozás ezt is hívja. A fenti
// stub csak azt mutatja, hogy a szelet ELJUT a hívásig; azt, hogy a valódi
// `articleComments` tényleg számol vele, a VALÓDI forrásból kell igazolni —
// különben a stub csendben elfedné, ha a hívás eltűnne.
test('a valodi forras a hozzaszolast a napi aktivitasba is beszamolja', async () => {
  const { call, records, dailyActivity } = fixture();
  records.set('community_profiles/owner', { displayName: 'Teszt Elek' });
  await call({ action: 'create', postId: 123, id: 'test', text: 'Hello' }, registered('owner'));
  assert.deepEqual(dailyActivity, [['owner', 'comments']]);

  const source = fs.readFileSync(`${__dirname}/index.js`, 'utf8');
  const start = source.indexOf('exports.articleComments =');
  const body = source.slice(start, source.indexOf('const WORDPRESS_BASE_URL', start));
  assert.ok(
    body.includes("await recordDailyActivity(uid, 'comments');"),
    'a articleComments hozzaszolás-létrehozása számoljon a napi aktivitással',
  );
  assert.ok(
    source.includes('async function recordDailyActivity(uid, field, amount = 1)'),
    'a recordDailyActivity létezzen a valódi forrásban (a teszt-szelet nem tartalmazza)',
  );
});
