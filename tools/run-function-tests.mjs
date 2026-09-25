#!/usr/bin/env node
/**
 * A `functions/` tesztjeinek futtatása — KÉT csoportban.
 *
 * MIÉRT KELL: a repóban kétféle teszt él:
 *  1. **tiszta** tesztek (nincs hálózat/Firebase) — sima `node --test` elég;
 *  2. **emulátoros** tesztek — a VALÓDI függvényeket mérik, ezért Firestore
 *     (és néhol Auth) emulátor kell hozzájuk, különben a Firebase Admin
 *     hitelesítés nélkül elhasal.
 *
 * ⚠️ AMIT MÉRTEM (2026-09-25): ha az emulátoros fájlokat **egy** emulátorban,
 * együtt futtatjuk, a suite-ok **összeérnek** (közös gyűjtemények, rate-limit
 * számlálók), és 14 teszt hamisan elbukik. Ezért ez az eszköz **fájlonként külön
 * emulátort** indít — így minden suite tiszta adatbázison fut.
 *
 * Használat:
 *   node tools/run-function-tests.mjs              # tiszta tesztek + emulátorosok
 *   node tools/run-function-tests.mjs --pure       # csak a tiszta tesztek
 *   node tools/run-function-tests.mjs --emulator   # csak az emulátorosok
 *   node tools/run-function-tests.mjs --list       # mit futtatna (nem futtat)
 */
import { execFileSync, spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';

/** Emulátoros suite-ok: fájl + a hozzá kellő emulátor-szolgáltatások.
 *  ⚠️ A szolgáltatás-készletet **mérve** állítottam be: a legtöbb suite elég a
 *  Firestore, de a `label-purchase-limit` a valódi callable-t hívja, ezért kell
 *  hozzá az Auth (9099) és a Functions (5001) emulátor is — ezt a fájl a saját
 *  fejlécében is így dokumentálja. */
export const EMULATOR_SUITES = [
  { file: 'functions/account-deletion.test.cjs', services: 'firestore' },
  { file: 'functions/achievement-daily-limit.test.cjs', services: 'firestore' },
  { file: 'functions/achievement-guided-points.test.cjs', services: 'firestore' },
  { file: 'functions/achievement-restore.test.cjs', services: 'firestore' },
  { file: 'functions/label-purchase-limit.test.cjs', services: 'firestore,auth,functions' },
  { file: 'functions/prize-draw.test.cjs', services: 'firestore' },
  { file: 'functions/push-dedupe.test.cjs', services: 'firestore' },
  { file: 'functions/registration.integration.test.cjs', services: 'firestore,auth,functions',
    // ⚠️ MIÉRT KELL A DEBUG-KÖRNYEZET (mért, 2026-09-25): a
    // `checkRegistrationEligibility` és a `checkDisplayNameAvailability`
    // `enforceAppCheck: true`-val fut, és a `firebase-functions` HTTP-rétege a
    // hiányzó App Check-tokent **emulátorban is** `unauthenticated` (401)
    // hibával dobja el → 6 teszt hamisan piros volt. Az emulátor nem tud valódi
    // App Check-tokent hitelesíteni, ezért a `skipTokenVerification`
    // debug-szolgáltatással indul a functions runtime; a teszt ilyenkor egy
    // aláíratlan, csak dekódolt tokent küld. Debug-mód nélkül a suite NEM hazudik
    // zöldet: az érintett 6 teszt kihagyva fut, indoklással.
    env: { FIREBASE_DEBUG_MODE: 'true', FIREBASE_DEBUG_FEATURES: '{"skipTokenVerification":true}' } },
  { file: 'functions/rules.test.cjs', services: 'firestore' },
];

/** A `node --test` összegsorainak kiolvasása (tiszta függvény). */
export function parseTotals(output) {
  const pick = (name) => {
    const match = new RegExp(`^\\u2139 ${name} (\\d+)$`, 'm').exec(output);
    return match ? Number(match[1]) : 0;
  };
  return {
    tests: pick('tests'),
    pass: pick('pass'),
    fail: pick('fail'),
    skipped: pick('skipped'),
  };
}

/** Minden `functions/*.test.cjs`, ami NEM emulátoros (tiszta). */
export function pureSuites(dir = 'functions') {
  const emulatorFiles = new Set(EMULATOR_SUITES.map((suite) => path.basename(suite.file)));
  return fs
    .readdirSync(dir)
    .filter((name) => name.endsWith('.test.cjs') && !emulatorFiles.has(name))
    .sort()
    .map((name) => path.join(dir, name));
}

export function selfTest() {
  const checks = [];
  const check = (label, ok) => checks.push({ label, ok });
  const sample = ['ℹ tests 12', 'ℹ pass 10', 'ℹ fail 2', 'ℹ skipped 0'].join('\n');
  const totals = parseTotals(sample);
  check('a tests sort kiolvassa', totals.tests === 12);
  check('a pass sort kiolvassa', totals.pass === 10);
  check('a fail sort kiolvassa', totals.fail === 2);
  check('hiányzó sor nulla', parseTotals('').fail === 0);
  const pure = pureSuites();
  check('van tiszta suite', pure.length > 0);
  check(
    'az emulátoros fájlok nincsenek a tiszta listában',
    !pure.some((file) => EMULATOR_SUITES.some((suite) => suite.file === file)),
  );
  check(
    'a rules.test.cjs az emulátoros listában van',
    EMULATOR_SUITES.some((suite) => suite.file.endsWith('rules.test.cjs')),
  );
  const registration = EMULATOR_SUITES.find((suite) =>
    suite.file.endsWith('registration.integration.test.cjs'));
  check(
    'a registration.integration App Check debug-környezettel fut',
    registration?.env?.FIREBASE_DEBUG_MODE === 'true'
      && JSON.parse(registration.env.FIREBASE_DEBUG_FEATURES).skipTokenVerification === true,
  );
  return checks;
}

function run(command, env) {
  // ⚠️ Windows-on a `shell: true` + argumentum-tömb a belső idézőjeleket
  // elveszíti (a `node --test <fájl>` így szétesik), ezért **egy** parancssort
  // adunk át — így a `emulators:exec` a saját, idézőjeles parancsát kapja meg.
  const result = spawnSync(command, {
    encoding: 'utf8',
    shell: true,
    maxBuffer: 64 * 1024 * 1024,
    // A suite-ok saját környezete (pl. App Check debug) — az emulátor a
    // functions runtime-ot ebből a környezetből indítja.
    env: env ? { ...process.env, ...env } : process.env,
  });
  return { output: `${result.stdout ?? ''}${result.stderr ?? ''}`, status: result.status ?? 1 };
}

function main() {
  if (process.argv.includes('--self-test')) {
    const checks = selfTest();
    for (const check of checks) console.log(`${check.ok ? 'OK  ' : 'HIBA'} ${check.label}`);
    const failed = checks.filter((check) => !check.ok).length;
    console.log(`\n${checks.length - failed}/${checks.length} önteszt rendben`);
    return failed ? 1 : 0;
  }

  const pure = pureSuites();
  const onlyPure = process.argv.includes('--pure');
  const onlyEmulator = process.argv.includes('--emulator');
  if (process.argv.includes('--list')) {
    console.log(`tiszta suite-ok (${pure.length}):`);
    for (const file of pure) console.log(`  ${file}`);
    console.log(`\nemulátoros suite-ok (${EMULATOR_SUITES.length}), fájlonként külön emulátorral:`);
    for (const suite of EMULATOR_SUITES) console.log(`  ${suite.file}  [${suite.services}]`);
    return 0;
  }

  const failures = [];
  if (!onlyEmulator) {
    console.log(`=== tiszta tesztek (${pure.length} fájl) ===`);
    const result = run(`node --test ${pure.map((file) => `"${file}"`).join(' ')}`);
    const totals = parseTotals(result.output);
    console.log(
      `  tests ${totals.tests} | pass ${totals.pass} | fail ${totals.fail} | skipped ${totals.skipped}`,
    );
    if (result.status !== 0) failures.push(`tiszta tesztek (${totals.fail} bukó)`);
  }

  if (!onlyPure) {
    console.log(`\n=== emulátoros tesztek (${EMULATOR_SUITES.length} fájl, egyenként külön emulátor) ===`);
    for (const suite of EMULATOR_SUITES) {
      const result = run(
        `npx firebase emulators:exec --only ${suite.services} --project demo-huhs ` +
          `"node --test ${suite.file}"`,
        suite.env,
      );
      const totals = parseTotals(result.output);
      const ok = result.status === 0 && totals.fail === 0 && totals.tests > 0;
      console.log(
        `${ok ? 'OK  ' : 'HIBA'} ${suite.file} [${suite.services}] — ` +
          `tests ${totals.tests} | pass ${totals.pass} | fail ${totals.fail} | skipped ${totals.skipped}`,
      );
      if (!ok) failures.push(`${suite.file} (${totals.fail} bukó, ${totals.tests} teszt futott)`);
    }
  }

  console.log('');
  if (failures.length) {
    console.log(`BUKÓ: ${failures.join(', ')}`);
    return 1;
  }
  console.log('MINDEN TESZT RENDBEN.');
  return 0;
}

if (process.argv[1] && process.argv[1].endsWith('run-function-tests.mjs')) {
  process.exitCode = main();
}
