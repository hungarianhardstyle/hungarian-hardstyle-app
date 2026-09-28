// MUTÁCIÓS BIZONYÍTÉK az ISMÉTELT KÖR kapujához (2026-09-28).
//
// A kérdés nem az, hogy zöld-e a teszt, hanem hogy a VALÓDI hibát elkapja-e:
//   1. a 2. kör ugyanazt a kulcsot kapja (nem szólna senkinek);
//   2. az e-mail kapuja figyelmen kívül hagyja a kört (nem menne ki új e-mail);
//   3. a hívó mindig az 1. kört küldi (a kör beállítása hatástalan).
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import fs from 'node:fs';

const files = ['functions/birth-date-notice-plan.js', 'functions/index.js'];
const originals = new Map(files.map((file) => [file, fs.readFileSync(file)]));
const hashes = new Map(
  files.map((file) => [file, createHash('sha256').update(originals.get(file)).digest('hex')]),
);
const TEST = 'functions/birth-date-notice-plan.test.cjs';

function runTests() {
  try {
    const output = execFileSync(process.execPath, ['--test', TEST], {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'pipe'],
      maxBuffer: 32 * 1024 * 1024,
    });
    return { failed: false, output };
  } catch (error) {
    return { failed: true, output: `${error.stdout ?? ''}${error.stderr ?? ''}` };
  }
}

const mutations = [
  {
    title: 'a 2. kör ugyanazt a kulcsot kapja (nincs új értesítés)',
    file: 'functions/birth-date-notice-plan.js',
    apply: (text) =>
      text.replace(
        '  return normalized > 1 ? `${key}:r${normalized}` : key;',
        '  return key;',
      ),
  },
  {
    title: 'az e-mail kapuja nem nézi a kört',
    file: 'functions/birth-date-notice-plan.js',
    apply: (text) =>
      text.replace(
        '    const alreadyEmailed = noticeRoundOf(profile) >= noticeRound;',
        '    const alreadyEmailed = Boolean(profile[EMAIL_FIELD]);',
      ),
  },
  {
    title: 'a hívó mindig az 1. kört küldi',
    file: 'functions/index.js',
    apply: (text) =>
      text.replace(
        '        round: normalizeBirthDateNoticeRound(settings.round),',
        '        round: 1,',
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
