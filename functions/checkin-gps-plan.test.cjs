'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const {
  distanceMeters,
  parsePosition,
  gpsCheckinDecision,
  gpsDecisionMessage,
} = require('./checkin-gps-plan');

// Budapest, Deák tér (47.4979, 19.0402)
const venue = { enabled: true, lat: 47.4979, lng: 19.0402, radius: 250, state: 'open' };

test('távolság: ismert értékek', () => {
  assert.equal(Math.round(distanceMeters(47.4979, 19.0402, 47.4979, 19.0402)), 0);
  // ~111 km egy szélességi fok
  assert.ok(Math.abs(distanceMeters(47, 19, 48, 19) - 111_195) < 300);
  // ~100 m északra
  const d = distanceMeters(47.4979, 19.0402, 47.4979 + 0.0009, 19.0402);
  assert.ok(d > 95 && d < 105, String(d));
});

test('pozíció: csak érvényes számok és tartományok', () => {
  assert.deepEqual(parsePosition({ lat: 47.5, lng: 19, accuracy: 12 }), { lat: 47.5, lng: 19, accuracy: 12 });
  assert.deepEqual(parsePosition({ lat: '47.5', lng: '19', accuracy: '12' }), { lat: 47.5, lng: 19, accuracy: 12 });
  for (const bad of [undefined, {}, { lat: 91, lng: 0, accuracy: 1 }, { lat: 0, lng: 181, accuracy: 1 }, { lat: 0, lng: 0, accuracy: -1 }, { lat: 'x', lng: 0, accuracy: 1 }, { lat: null, lng: 0, accuracy: 1 }]) {
    assert.equal(parsePosition(bad), null, JSON.stringify(bad));
  }
});

test('döntés: a helyszínen belül elfogadva', () => {
  const near = { lat: 47.4979 + 0.0009, lng: 19.0402, accuracy: 20 };
  const result = gpsCheckinDecision(venue, near);
  assert.equal(result.ok, true);
  assert.ok(result.distance < 250);
});

test('döntés: távol, pontatlan, kikapcsolt és ablakon kívüli esetek elutasítva', () => {
  const far = { lat: 47.55, lng: 19.0402, accuracy: 20 };
  assert.equal(gpsCheckinDecision(venue, far).code, 'too_far');
  assert.equal(gpsCheckinDecision(venue, { lat: 47.4979, lng: 19.0402, accuracy: 500 }).code, 'inaccurate');
  assert.equal(gpsCheckinDecision({ ...venue, enabled: false }, far).code, 'disabled');
  assert.equal(gpsCheckinDecision(null, far).code, 'disabled');
  assert.equal(gpsCheckinDecision({ ...venue, state: 'before' }, far).code, 'before');
  assert.equal(gpsCheckinDecision({ ...venue, state: 'closed' }, far).code, 'closed');
  assert.equal(gpsCheckinDecision({ ...venue, state: 'unknown' }, far).code, 'unknown');
});

test('üzenet: a távolság és a pontosság benne van', () => {
  assert.match(gpsDecisionMessage({ code: 'too_far', distance: 480 }), /480 m/);
  assert.match(gpsDecisionMessage({ code: 'inaccurate', accuracy: 320 }), /320 m/);
  assert.match(gpsDecisionMessage({ code: 'disabled' }), /QR/);
});
