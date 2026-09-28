const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const { logWarning, WARNING_SEVERITY } = require('./log-warning');

const functionsSource = fs.readFileSync(path.join(__dirname, 'index.js'), 'utf8');

/** A naplózás elfogása: a `console.log` és a `console.warn` kimenetét is mérjük. */
function captureLog(run) {
  const lines = [];
  const warns = [];
  const originalLog = console.log;
  const originalWarn = console.warn;
  console.log = (...args) => lines.push(args.map((value) => String(value)).join(' '));
  console.warn = (...args) => warns.push(args.map((value) => String(value)).join(' '));
  try {
    const returned = run();
    return { lines, warns, returned };
  } finally {
    console.log = originalLog;
    console.warn = originalWarn;
  }
}

test('a kezelt figyelmeztetés egy sorban, WARNING szinten megy ki', () => {
  const { lines, warns, returned } = captureLog(() =>
    logWarning('achievement_catalog_fallback', 'This operation was aborted'),
  );
  assert.equal(lines.length, 1, 'pontosan egy strukturált naplósor');
  // ⚠️ A `console.warn` a Cloud Run alatt a stderr-re megy, amit a Cloud Logging
  // ERROR-ként számol — egy KEZELT ág nem kerülhet oda.
  assert.equal(warns.length, 0, 'a segéd nem írhat a stderr-re');
  const entry = JSON.parse(lines[0]);
  assert.equal(entry.severity, WARNING_SEVERITY);
  assert.equal(entry.severity, 'WARNING');
  assert.equal(entry.event, 'achievement_catalog_fallback');
  assert.equal(entry.message, 'This operation was aborted');
  assert.deepEqual(returned, entry, 'a visszaadott bejegyzés ugyanaz, amit kiírt');
});

test('a kiegészítő mezők bekerülnek, de a súlyosságot nem lehet felülírni', () => {
  const { lines } = captureLog(() =>
    logWarning('esemeny', 'uzenet', {
      status: 503,
      route: '/achievements/badges',
      severity: 'ERROR',
      event: 'mas-esemeny',
      message: 'mas-uzenet',
    }),
  );
  const entry = JSON.parse(lines[0]);
  assert.equal(entry.status, 503);
  assert.equal(entry.route, '/achievements/badges');
  assert.equal(entry.severity, 'WARNING', 'a hívó nem emelheti hibává');
  assert.equal(entry.event, 'esemeny');
  assert.equal(entry.message, 'uzenet');
});

test('a jelvény-katalógus kezelt tartalék-ága a segéddel naplóz', () => {
  const start = functionsSource.indexOf('async function getAchievementBadges');
  assert.ok(start >= 0, 'hiányzó getAchievementBadges');
  const end = functionsSource.indexOf('function versionBadgeImageUrl', start);
  assert.ok(end > start, 'hiányzó blokk-vég');
  const block = functionsSource.slice(start, end);
  assert.match(block, /logWarning\('achievement_catalog_fallback', error\?\.message \|\| String\(error\)\);/);
  assert.doesNotMatch(block, /console\.warn\(/, 'a kezelt ág nem mehet a stderr-re (ERROR)');
  assert.match(
    functionsSource,
    /const \{ logWarning \} = require\('\.\/log-warning'\);/,
    'a segéd importja kötelező',
  );
});
