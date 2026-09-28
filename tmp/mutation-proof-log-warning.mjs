// MUTÁCIÓS BIZONYÍTÉK a kezelt-hiba naplózás kapujához (2026-09-28).
//
// A kapu akkor ér valamit, ha a VALÓDI hibát elkapja. Három mutáció:
//   1. a segéd visszaír a stderr-re (`console.warn`) -> a Cloud Logging ERROR-nak veszi;
//   2. a súlyosság-védő elvétele -> a hívó hibává emelhetné a figyelmeztetést;
//   3. a hívási hely visszaállítása `console.warn`-ra.
// A valódi fájlokat a szkript a végén bájtazonosan visszaállítja (és ellenőrzi).
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import fs from 'node:fs';

const files = ['functions/log-warning.js', 'functions/index.js'];
const originals = new Map(files.map((file) => [file, fs.readFileSync(file)]));
const hashes = new Map(files.map((file) => [file, createHash('sha256').update(originals.get(file)).digest('hex')]));
const TEST = 'functions/log-warning.test.cjs';

function runTests() {
  try {
    const out = execFileSync(process.execPath, ['--test', TEST], {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'pipe'],
      maxBuffer: 32 * 1024 * 1024,
    });
    return { failed: false, output: out };
  } catch (error) {
    return { failed: true, output: `${error.stdout ?? ''}${error.stderr ?? ''}` };
  }
}

const mutations = [
  {
    title: 'a segéd a stderr-re ír (console.warn)',
    file: 'functions/log-warning.js',
    apply: (text) => text.replace('  console.log(JSON.stringify(entry));', '  console.warn(JSON.stringify(entry));'),
  },
  {
    title: 'a súlyosság-védő elvétele',
    file: 'functions/log-warning.js',
    apply: (text) =>
      text.replace(
        "    if (key === 'severity' || key === 'event' || key === 'message') continue;",
        '    if (false) continue;',
      ),
  },
  {
    title: 'a hívási hely visszaállítása console.warn-ra',
    file: 'functions/index.js',
    apply: (text) =>
      text.replace(
        "    logWarning('achievement_catalog_fallback', error?.message || String(error));",
        "    console.warn('achievement_catalog_fallback', error?.message || String(error));",
      ),
  },
];

const baseline = runTests();
console.log(`alapállapot: ${baseline.failed ? 'BUKIK (hiba!)' : 'zöld'}`);
let bad = baseline.failed ? 1 : 0;
let caught = 0;

try {
  for (const mutation of mutations) {
    const original = originals.get(mutation.file).toString('utf8');
    const mutated = mutation.apply(original);
    if (mutated === original) {
      console.log(`ELTER  ${mutation.title} — a minta nem illett`);
      bad += 1;
      continue;
    }
    fs.writeFileSync(mutation.file, mutated, 'utf8');
    const result = runTests();
    if (result.failed) {
      caught += 1;
      console.log(`OK     ${mutation.title} — ELKAPVA`);
    } else {
      bad += 1;
      console.log(`ELTER  ${mutation.title} — NEM bukott meg`);
    }
    fs.writeFileSync(mutation.file, original, 'utf8');
  }
} finally {
  for (const file of files) fs.writeFileSync(file, originals.get(file));
}

const restored = files.every(
  (file) => createHash('sha256').update(fs.readFileSync(file)).digest('hex') === hashes.get(file),
);
const after = runTests();
console.log(`\nbájtazonos visszaállítás: ${restored ? 'IGEN' : 'NEM'}`);
console.log(`a helyreállított kör: ${after.failed ? 'BUKIK' : 'zöld'}`);
if (!restored || after.failed) bad += 1;
console.log(`${caught}/${mutations.length} mutáció elkapva${bad ? `, ${bad} hiba` : ''}`);
process.exitCode = bad === 0 ? 0 : 1;
