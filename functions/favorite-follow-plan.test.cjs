'use strict';

/**
 * A **követés a kedvencek alapján** tiszta logikájának tesztje
 * (`functions/favorite-follow-plan.js`).
 *
 * A mérés tárgya: a mért WordPress-alakból (`artists: [{id,name}]`,
 * `organizer: {id,name}`) helyesen olvassuk-e ki a kedvenc-kapcsolatokat, és a
 * tartalmonként **egyszer** küldés kulcsa tényleg tartalomhoz kötött-e.
 */
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const plan = require('./favorite-follow-plan.js');

test('a kiadvány a DJ-it jelöli (mért alak)', () => {
  const targets = plan.followTargetsFor('release', { id: 12699, artists: [{ id: 12373, name: 'Goze' }] });
  assert.deepEqual(targets, [{ kind: 'artist', id: '12373' }]);
});

test('az esemény a szervezőt ÉS a fellépő DJ-ket jelöli', () => {
  const targets = plan.followTargetsFor('event', {
    id: 12505,
    organizer: { id: 11673, name: 'Hungarian Hardstyle' },
    artists: [{ id: 12373, name: 'Goze' }, { id: 10007, name: 'Nc' }],
  });
  assert.deepEqual(targets, [
    { kind: 'organizer', id: '11673' },
    { kind: 'artist', id: '12373' },
    { kind: 'artist', id: '10007' },
  ]);
});

test('a hír és az ismeretlen végpont nem jelöl követést', () => {
  assert.deepEqual(plan.followTargetsFor('news', { artists: [{ id: 1 }] }), []);
  assert.deepEqual(plan.followTargetsFor('', {}), []);
});

test('hiányos vagy hibás azonosítót kihagy (nem tippel)', () => {
  const targets = plan.followTargetsFor('event', {
    organizer: { name: 'Nincs azonosító' },
    artists: [{ id: 'abc' }, { id: '' }, { id: 42 }],
  });
  assert.deepEqual(targets, [{ kind: 'artist', id: '42' }]);
});

test('az ismétlődő azonosító csak egyszer szerepel', () => {
  const targets = plan.followTargetsFor('event', {
    organizer: { id: 7 },
    artists: [{ id: 7 }, { id: 7 }],
  });
  assert.deepEqual(targets, [
    { kind: 'organizer', id: '7' },
    { kind: 'artist', id: '7' },
  ]);
});

test('az egyszerű azonosító-lista (számok) is működik', () => {
  assert.deepEqual(plan.relationIds([1, '2', 3]), ['1', '2', '3']);
  assert.deepEqual(plan.relationIds(5), ['5']);
  assert.deepEqual(plan.relationIds(null), []);
});

test('a katalógus-típus a végpont kulcsából jön', () => {
  assert.equal(plan.followCatalogKindFor('release'), 'favorite_release');
  assert.equal(plan.followCatalogKindFor('event'), 'favorite_event');
  assert.equal(plan.followCatalogKindFor('news'), '');
});

test('a kulcs tartalmonként egyszer fut (nem a kedvenc-típustól függ)', () => {
  const first = plan.favoriteFollowKey('event', 12505, 'uid-1');
  const sameContentAgain = plan.favoriteFollowKey('event', 12505, 'uid-1');
  const otherContent = plan.favoriteFollowKey('event', 12506, 'uid-1');
  const otherUser = plan.favoriteFollowKey('event', 12505, 'uid-2');
  assert.equal(first, sameContentAgain);
  assert.notEqual(first, otherContent);
  assert.notEqual(first, otherUser);
  assert.match(first, /^favorite-follow:event:12505:/);
  assert.equal(plan.favoriteFollowKey('', 12505, 'uid-1'), '');
  assert.equal(plan.favoriteFollowKey('event', '', 'uid-1'), '');
  assert.equal(plan.favoriteFollowKey('event', 12505, ''), '');
});

test('a katalógusban van mindkét követés-szöveg, magyarul és angolul', () => {
  const catalog = require('./notification-texts.js');
  const release = catalog.notificationText('favorite_release', 'hu', { name: 'Goze — Change of Pace' });
  const event = catalog.notificationText('favorite_event', 'en', { name: 'Hard Base Classic' });
  assert.ok(release && release.title && release.body.includes('Goze'), JSON.stringify(release));
  assert.ok(event && event.title && event.body.includes('Hard Base Classic'), JSON.stringify(event));
  assert.match(release.title, /kiadvány/);
  assert.match(event.title, /event/i);
});

test('forrás-lint: a fan-out a kedvencekhez is küld, és nem dupláz', () => {
  const source = fs.readFileSync(path.join(__dirname, 'index.js'), 'utf8');
  assert.match(source, /require\('\.\/favorite-follow-plan'\)/);
  assert.match(source, /followTargetsFor\(/);
  assert.match(source, /favoriteFollowKey\(/);
  assert.match(source, /collectionGroup\(FAVORITES_COLLECTION\)/);
  // A `createNotificationBestEffort` `created` kapuja nélkül duplázna a bejegyzés.
  assert.match(source, /const created = await createNotificationBestEffort\(/);
});
