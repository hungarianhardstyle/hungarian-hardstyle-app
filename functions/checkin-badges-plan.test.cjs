'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { readBadgePrefs, normalizeFeatured, visibleBadges } = require('./checkin-badges-plan');

test('beállítások: alapból nyilvános, kiemelés nélkül; hibás értékek kiszűrve', () => {
  assert.deepEqual(readBadgePrefs(undefined), { showAll: true, featured: [] });
  assert.deepEqual(readBadgePrefs({ checkinBadgesPublic: false }), { showAll: false, featured: [] });
  assert.deepEqual(readBadgePrefs({ featuredCheckinEventIds: [5, '7', 5, 'x', -1, 1.5, 9, 11] }), {
    showAll: true,
    featured: [5, 7, 9],
  });
});

test('kiemelés: csak a saját jelvények közül, legfeljebb 3, ismétlés nélkül', () => {
  const owned = [1, 2, 3, 4];
  assert.deepEqual(normalizeFeatured([2, 1], owned), [2, 1]);
  assert.deepEqual(normalizeFeatured([], owned), []);
  assert.equal(normalizeFeatured([1, 2, 3, 4], owned), null);
  assert.equal(normalizeFeatured([9], owned), null);
  assert.equal(normalizeFeatured([1, 1], owned), null);
  assert.equal(normalizeFeatured(['a'], owned), null);
  assert.equal(normalizeFeatured('1', owned), null);
});

test('láthatóság: a tulajdonos mindent lát, más csak amit a tulajdonos megenged', () => {
  const badges = [{ eventId: 1 }, { eventId: 2 }, { eventId: 3 }];
  assert.equal(visibleBadges({ badges, prefs: { showAll: false, featured: [2] }, own: true }).length, 3);
  assert.equal(visibleBadges({ badges, prefs: { showAll: true, featured: [2] }, own: false }).length, 3);
  assert.deepEqual(visibleBadges({ badges, prefs: { showAll: false, featured: [2] }, own: false }), [{ eventId: 2 }]);
  assert.deepEqual(visibleBadges({ badges, prefs: { showAll: false, featured: [] }, own: false }), []);
});
