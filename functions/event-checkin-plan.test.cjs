'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {
  EVENT_CHECKIN_POINTS,
  WELCOME_SIGN_IN_POINTS,
  parseCheckinTarget,
  checkinDocId,
  checkinSourceKey,
  checkinBadge,
} = require('./event-checkin-plan');
const { achievementReasonKey, notificationText } = require('./notification-texts');

test('a saját QR-linkből kiolvassa az eseményt és a kódot', () => {
  assert.deepEqual(parseCheckinTarget('https://hungarianhardstyle.hu/checkin/12992/abcdef1234567890wxyz'), {
    eventId: 12992,
    code: 'abcdef1234567890wxyz',
  });
  assert.deepEqual(parseCheckinTarget('https://www.hungarianhardstyle.hu/checkin/5/ABCDEFGH12/'), {
    eventId: 5,
    code: 'abcdefgh12',
  });
});

test('idegen domain, http, rossz útvonal vagy rövid kód: nincs találat (nem tippel)', () => {
  for (const raw of [
    'https://evil.example/checkin/12992/abcdef1234567890',
    'http://hungarianhardstyle.hu/checkin/12992/abcdef1234567890',
    'https://hungarianhardstyle.hu/events/12992',
    'https://hungarianhardstyle.hu/checkin/0/abcdef1234567890',
    'https://hungarianhardstyle.hu/checkin/12/abc',
    'nem link',
    '',
    null,
  ]) {
    assert.equal(parseCheckinTarget(raw), null, String(raw));
  }
});

test('a kliens mezőit is elfogadja, de ugyanazzal a szigorral', () => {
  assert.deepEqual(parseCheckinTarget({ eventId: 7, code: 'AbCdEfGh12' }), { eventId: 7, code: 'abcdefgh12' });
  assert.equal(parseCheckinTarget({ eventId: 'x', code: 'abcdefgh12' }), null);
  assert.equal(parseCheckinTarget({ eventId: 7, code: 'a/b' }), null);
});

test('a rekord- és a pontkulcs eseményenként egyedi (egyszer fizet)', () => {
  assert.equal(checkinDocId('uid1', 12992), 'uid1_12992');
  assert.equal(checkinSourceKey(12992), 'event-checkin:12992');
  assert.notEqual(checkinSourceKey(1), checkinSourceKey(2));
});

test('a jelvény: a beállított név és kép, különben az általános „Ott voltam”', () => {
  assert.deepEqual(checkinBadge({ title: 'Hard Base', badgeName: 'Hard Base 2026', badgeUrl: 'https://x/y.png' }), {
    badgeName: 'Hard Base 2026',
    badgeUrl: 'https://x/y.png',
    title: 'Hard Base',
  });
  assert.equal(checkinBadge({ title: 'Kassa Hajó' }).badgeName, 'Kassa Hajó – ott voltam');
  assert.equal(checkinBadge({}).badgeName, 'Ott voltam');
  assert.equal(checkinBadge({ badgeUrl: 'javascript:alert(1)' }).badgeUrl, '');
});

test('a két új pontforrásnak saját indoklása van mindkét nyelven', () => {
  assert.equal(achievementReasonKey('event-checkin:12992'), 'achievement_reason_event_checkin');
  assert.equal(achievementReasonKey('welcome-sign-in'), 'achievement_reason_welcome_sign_in');
  for (const lang of ['hu', 'en']) {
    assert.ok(notificationText('achievement_reason_event_checkin', lang).body.length > 3);
    assert.ok(notificationText('achievement_reason_welcome_sign_in', lang).body.length > 3);
  }
  assert.equal(EVENT_CHECKIN_POINTS, 30);
  assert.equal(WELCOME_SIGN_IN_POINTS, 25);
});

test('forrás-lint: a callable bejelentkezést kér, a WordPress dönt, a ledger fizet', () => {
  const source = fs.readFileSync(path.join(__dirname, 'index.js'), 'utf8');
  const start = source.indexOf('exports.checkInEvent');
  const end = source.indexOf('exports.claimWelcomeSignInBonus');
  assert.ok(start > 0 && end > start);
  const body = source.slice(start, end);
  assert.match(body, /requireRegisteredViewer\(context\)/);
  assert.match(body, /\/events\/\$\{target\.eventId\}\/checkin/);
  assert.match(body, /awardAchievementPoints\(uid, EVENT_CHECKIN_POINTS, checkinSourceKey\(target\.eventId\)\)/);
  // A UID a hitelesített tokenből jön, nem a kliens kéréséből.
  assert.doesNotMatch(body, /data\??\.uid/);
  const welcome = source.slice(end, end + 800);
  assert.match(welcome, /requireRegisteredViewer\(context\)/);
  assert.match(welcome, /'welcome-sign-in'/);
  assert.match(source, /db\.collection\('event_checkins'\)\.where\('uid', '==', uid\)\.get\(\)/);
});
