#!/usr/bin/env node
/**
 * Az ELFOGADOTT beküldések pontjának kifizetése — plugin ↔ szerver egyezés.
 *
 * MIÉRT: a tulajdonos kérése szerint az achievement-pont **csak elfogadott**
 * beküldésért jár, a beküldést viszont **két helyen** lehet elfogadni:
 *  * az appban (natív admin → Beküldések) — ez azonnal szól a Firebase-nek;
 *  * a WordPress adminban — ez **nem** szólt, ezért ott elveszett a pont.
 *
 * A megoldás két részből áll, és ez a kapu **mindkettőt** méri:
 *  1. a plugin 2.5.8-as végpontja (`/submission-statuses`) megmondja, hogy egy
 *     beküldést elfogadtak-e (`created_profile_id`), és **hitelesítés mögött van**;
 *  2. a Cloud Function (`reconcileSubmissionPoints`) ezt lekérdezi, és **csak**
 *     `accepted === true` esetén fizet — ráadásul nem fizet kétszer, és a napi
 *     keret miatt elhalasztott pontot **nem veszíti el**.
 *
 * Futtatás:
 *   node tools/verify-submission-payout.mjs            (forrás-ellenőrzés)
 *   node tools/verify-submission-payout.mjs --live      (ÉLES: a végpont válaszol-e)
 *   node tools/verify-submission-payout.mjs --self-test (a detektorok bizonyítása)
 */
import fs from 'node:fs';
import path from 'node:path';
import { accessToken, createChecker, secret } from './lib/live-firebase.mjs';

const PLUGIN_DIR = '.tmp-api-24115/huhs-mobile-api';
const SUBMISSIONS_PHP = path.join(PLUGIN_DIR, 'includes', 'submissions.php');
const FUNCTIONS_JS = 'functions/index.js';
const WORDPRESS_BASE_URL = 'https://hungarianhardstyle.hu/wp-json/huhs/v1';

/** A plugin-oldali végpont és a szerveroldali pályázat vizsgálata (tiszta). */
export function analyzePayout({ submissionsSource, functionsSource }) {
  const checks = [];
  const check = (label, ok, detail = '') => checks.push({ label, ok: Boolean(ok), detail });

  check(
    'a plugin 2.5.8-as végpontja létezik (submission-statuses)',
    /register_rest_route\('huhs\/v1',\s*'\/submission-statuses'/.test(submissionsSource),
  );
  check(
    'a végpont HITELESÍTÉS mögött van (nem nyilvános)',
    /'\/submission-statuses'[\s\S]{0,400}?permission_callback'\s*=>\s*'huhs_submission_api_permission'/.test(
      submissionsSource,
    ),
  );
  check(
    'az elfogadást a created_profile_id meta adja (nem a poszt státusza)',
    /created_profile_id/.test(submissionsSource) &&
      /'accepted'\s*=>\s*\$profile_id\s*>\s*0/.test(submissionsSource),
  );
  check(
    'a végpont egyszerre legfeljebb 100 azonosítót fogad (nincs korlátlan kérés)',
    /array_slice\(array_unique\(\$ids\),\s*0,\s*100\)/.test(submissionsSource),
  );

  check(
    'a szerver lekérdezi a végpontot',
    /submission-statuses/.test(functionsSource) && /fetchSubmissionStatuses/.test(functionsSource),
  );
  check(
    'a szerver CSAK elfogadottra fizet',
    /status\.accepted !== true\)\s*\{[\s\S]{0,200}?continue;/.test(functionsSource),
  );
  check(
    'a szerver a naplóból ellenőrzi, hogy a pont már megvan-e (nincs dupla fizetés)',
    /submissionPointsAlreadyGranted/.test(functionsSource) &&
      /submission:\$\{kind\}:\$\{wpId\}/.test(functionsSource),
  );
  check(
    'a napi keret miatt elhalasztott pont NEM veszik el (nincs kész-jelölés)',
    /summary\.deferred \+= 1;[\s\S]{0,120}?continue;/.test(functionsSource),
  );
  check(
    'WordPress-hiba esetén nem jelöl meg semmit (nincs néma elveszett pont)',
    /if \(!statuses\) return \{ \.\.\.summary, deferred: pending\.length \};/.test(functionsSource),
  );
  check(
    'a pótlás ütemezve fut (nem kell hozzá kézi indítás)',
    /exports\.reconcileSubmissionPoints = onSchedule\(/.test(functionsSource),
  );

  return { checks, failures: checks.filter((entry) => !entry.ok) };
}

function readSources() {
  return {
    submissionsSource: fs.existsSync(SUBMISSIONS_PHP) ? fs.readFileSync(SUBMISSIONS_PHP, 'utf8') : '',
    functionsSource: fs.readFileSync(FUNCTIONS_JS, 'utf8'),
  };
}

function selfTest() {
  const sources = readSources();
  const results = [];
  const check = (label, ok, detail = '') => results.push({ label, ok: Boolean(ok), detail });

  // ⚠️ A verzió-összehasonlítás (a régi kapu hibája: a 2.6.0/2.7.0-et
  // hibásnak jelezte, mert csak az utolsó számot nézte).
  for (const [version, expected] of [
    ['2.5.8', true],
    ['2.5.9', true],
    ['2.6.0', true],
    ['2.7.0', true],
    ['3.0.0', true],
    ['2.5.7', false],
    ['2.4.99', false],
    ['1.9.9', false],
    ['', false],
    ['nem-verzió', false],
  ]) {
    check(
      `verzió-összehasonlítás: „${version}" ${expected ? '≥' : '<'} 2.5.8`,
      versionAtLeast(version, '2.5.8') === expected,
    );
  }

  const good = analyzePayout(sources);
  check('a valódi forrásokon minden ellenőrzés rendben', good.failures.length === 0, JSON.stringify(good.failures));

  check(
    'a NYILVÁNOS végpont (hitelesítés nélkül) elhasal',
    analyzePayout({
      ...sources,
      submissionsSource: sources.submissionsSource.replace(
        /('\/submission-statuses'[\s\S]{0,400}?permission_callback'\s*=>\s*)'huhs_submission_api_permission'/,
        "$1'__return_true'",
      ),
    }).failures.length > 0,
  );
  check(
    'az „elfogadás nélkül is fizet” változat elhasal',
    analyzePayout({
      ...sources,
      // CRLF-tűrő: a forrás Windows-sorvéggel jön, ezért a `\r?\n` kell.
      functionsSource: sources.functionsSource.replace(
        /if \(!status \|\| status\.accepted !== true\) \{\r?\n\s*if \(status\) summary\.deferred \+= 1;\r?\n\s*continue;\r?\n\s*\}/,
        'if (false) {\r\n      continue;\r\n    }',
      ),
    }).failures.length > 0,
  );
  check(
    'a dupla-fizetés ellenőrzésének eltávolítása elhasal',
    analyzePayout({
      ...sources,
      functionsSource: sources.functionsSource.replace(/submissionPointsAlreadyGranted/g, 'nemLetezoFuggveny'),
    }).failures.length > 0,
  );
  check(
    'a WordPress-hiba „kész”-nek jelölése elhasal',
    analyzePayout({
      ...sources,
      functionsSource: sources.functionsSource.replace(
        'if (!statuses) return { ...summary, deferred: pending.length };',
        'if (!statuses) return summary;',
      ),
    }).failures.length > 0,
  );

  for (const result of results) console.log(`${result.ok ? 'OK   ' : 'HIBA '} ${result.label}${result.ok || !result.detail ? '' : ` — ${result.detail}`}`);
  const failed = results.filter((result) => !result.ok).length;
  console.log('');
  console.log(`${results.length - failed}/${results.length} ellenőrzés rendben${failed ? ` — ${failed} HIBA` : ''}`);
  console.log(failed === 0 ? 'Önteszt: a detektorok működnek.' : 'Önteszt: HIBA!');
  return failed ? 1 : 0;
}

/**
 * Verzió-összehasonlítás: `2.7.0` ≥ `2.5.8`?
 *
 * ⚠️ MIÉRT KELL (a korábbi kapu hibája): a régi ellenőrzés a verzió **utolsó**
 * számát nézte (`Number('2.7.0'.split('.').pop()) >= 8` → `0 >= 8` = HAMIS),
 * ezért a 2.6.0/2.7.0-et **hibásnak** jelezte — vagyis minden 2.5.8 utáni
 * kiadásnál pirosat adott. Ez a hiba a 2.7.0 feltöltésekor élesben elő is jött.
 */
export function versionAtLeast(version, minimum) {
  const parse = (value) =>
    String(value || '')
      .trim()
      .split('.')
      .map((part) => Number.parseInt(part, 10));
  const actual = parse(version);
  const required = parse(minimum);
  if (actual.some((part) => !Number.isFinite(part)) || required.length === 0) {
    return false;
  }
  if (actual.length === 0 || !Number.isFinite(required[0])) return false;
  for (let index = 0; index < Math.max(actual.length, required.length); index += 1) {
    const left = actual[index] ?? 0;
    const right = required[index] ?? 0;
    if (!Number.isFinite(left) || !Number.isFinite(right)) return false;
    if (left > right) return true;
    if (left < right) return false;
  }
  return true;
}

/**
 * ÉLES: a plugin végpontja válaszol-e, és a hitelesítés rendben van-e.
 * A WordPress-jelszavakat futásidőben, a Secret Managerből kéri.
 */
async function liveCheck() {
  const checker = createChecker();
  const token = await accessToken();
  const username = secret('WORDPRESS_USERNAME');
  const password = secret('WORDPRESS_APPLICATION_PASSWORD');
  const auth = `Basic ${Buffer.from(`${username}:${password}`).toString('base64')}`;

  const pluginVersion = await fetch(`${WORDPRESS_BASE_URL}/admin?action=settings`, {
    headers: { Authorization: auth, Accept: 'application/json' },
  })
    .then((response) => response.json().catch(() => ({})))
    .catch(() => ({}));
  const version = String(pluginVersion?.apiVersion || '');
  checker.check('a plugin 2.5.8 (vagy újabb) van fent', versionAtLeast(version, '2.5.8'), `apiVersion=${version}`);

  // Üres azonosítólista: 400-at kell adnia (a végpont él, és értelmesen válaszol).
  const empty = await fetch(`${WORDPRESS_BASE_URL}/submission-statuses?ids=`, {
    headers: { Authorization: auth, Accept: 'application/json' },
  });
  checker.check('a végpont válaszol (üres kérésre 400)', empty.status === 400, `status=${empty.status}`);

  const one = await fetch(`${WORDPRESS_BASE_URL}/submission-statuses?ids=1`, {
    headers: { Authorization: auth, Accept: 'application/json' },
  });
  const body = await one.json().catch(() => ({}));
  checker.check(
    'nem létező azonosítóra üres listát ad (nem hibázik)',
    one.status === 200 && Array.isArray(body?.items) && body.items.length === 0,
    `status=${one.status}`,
  );

  // Hitelesítés nélkül nem szabad kiszolgálnia.
  const anonymous = await fetch(`${WORDPRESS_BASE_URL}/submission-statuses?ids=1`);
  checker.check('hitelesítés nélkül elutasít (401/403)', [401, 403].includes(anonymous.status), `status=${anonymous.status}`);

  console.log(`plugin=${version} token=${token ? 'van' : 'nincs'}`);
  return checker.report();
}

if (process.argv.includes('--self-test')) {
  process.exitCode = selfTest();
} else if (process.argv.includes('--live')) {
  liveCheck()
    .then((code) => {
      process.exitCode = code;
    })
    .catch((error) => {
      console.error(`HIBA: ${error.message}`);
      process.exitCode = 2;
    });
} else {
  const { checks, failures } = analyzePayout(readSources());
  for (const entry of checks) {
    console.log(`${entry.ok ? 'OK   ' : 'HIBA '} ${entry.label}${entry.ok || !entry.detail ? '' : ` — ${entry.detail}`}`);
  }
  console.log('');
  console.log(`${checks.length - failures.length}/${checks.length} ellenőrzés rendben${failures.length ? ` — ${failures.length} HIBA` : ''}`);
  process.exitCode = failures.length ? 1 : 0;
}
