const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

/**
 * Az app-push NAPOKIG nem ment ki a Cloud Functionokbol.
 *
 * A `firebase-admin` 14-ben a regi `admin.messaging()` namespace-hivas MEGSZUNT
 * (`typeof admin.messaging === 'undefined'`), ezert a `sendMulticastToAllTokens()`
 * MINDEN hivasnal ezzel allt le: „admin.messaging is not a function".
 *
 * Ez azert maradt rejtve, mert:
 *   1. a hivo helperek `console.warn`-nal nyelik el a hibat (a muvelet maga
 *      sikeres marad: a pont/profil/ertekeles beirasa nem fugg a pushtol);
 *   2. a HIR-ertesitest a WordPress plugin kuld, nem ez a fuggveny — egy
 *      mukodo hirek-push elfedte a tobbi hat utvonalat.
 *
 * Erintett utvonalak (mind ugyanezen a helperen megy):
 *   achievement pont, esemeny-ertekelési keres, uj bekuldes (adminok),
 *   ismeros-jeloles, meetup-erdeklodes, privat uzenet, chat jelentes.
 */

const functionsSource = fs.readFileSync(path.join(__dirname, 'index.js'), 'utf8');

test('a messaging a tamogatott modulalis uton jon letre', () => {
  assert.match(
    functionsSource,
    /const \{ getMessaging \} = require\('firebase-admin\/messaging'\);/,
    'a getMessaging importalva van',
  );
  assert.match(
    functionsSource,
    /const messaging = getMessaging\(\);/,
    'a kuldest vegzo helper getMessaging()-et hasznal',
  );
});

test('a regi admin.messaging() hivas nem tert vissza', () => {
  // A `admin.messaging` csak a hibát leíró kommentben szerepelhet, kódként nem.
  const codeOnly = functionsSource
    .split('\n')
    .filter((line) => {
      const trimmed = line.trim();
      return !trimmed.startsWith('//') && !trimmed.startsWith('*') && !trimmed.startsWith('/*');
    })
    .join('\n');
  assert.doesNotMatch(
    codeOnly,
    /admin\.messaging\(/,
    'a torott hivas nem hasznalhato ujra (firebase-admin 14-ben nem letezik)',
  );
});

test('a valodi firebase-admin csomagban tenyleg nincs admin.messaging', () => {
  // Ez a teny, ami a hibat okozta — ha valaha visszakerul a namespace-hivas,
  // ez a teszt megmagyarazza, miert nem mukodne.
  const admin = require('firebase-admin');
  assert.equal(
    typeof admin.messaging,
    'undefined',
    'a telepitett firebase-admin 14-ben nincs admin.messaging',
  );
  const { getMessaging } = require('firebase-admin/messaging');
  assert.equal(typeof getMessaging, 'function', 'a modulalis ut elerheto');
});

test('a kuldest vegzo helper egyetlen helyen van, es listat ad vissza', () => {
  const start = functionsSource.indexOf('async function sendMulticastToAllTokens(');
  assert.ok(start > 0, 'a helper megvan');
  const end = functionsSource.indexOf('\nasync function getPushTokens(', start);
  const helper = functionsSource.slice(start, end);
  assert.match(helper, /sendEachForMulticast\(/);
  assert.match(helper, /successCount \+= result\.successCount/);
  assert.match(helper, /slice\(offset, offset \+ 500\)/, 'több mint 500 token eseten is megy');
});

test('a hivasok ugyanazon az egy helperen mennek (nincs masodik, eltero ut)', () => {
  const directCalls = functionsSource.split('sendEachForMulticast(').length - 1;
  assert.equal(directCalls, 1, 'csak a helper hivja a Firebase API-t');
  const helperCalls = functionsSource.split('sendMulticastToAllTokens(').length - 1;
  assert.ok(helperCalls >= 6, `legalabb 6 utvonal hasznalja (talalt: ${helperCalls})`);
});
