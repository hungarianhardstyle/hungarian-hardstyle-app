// MUTÁCIÓS BIZONYÍTÉK a heti összefoglaló széles körű push-jához (2.14.8).
//
// A kapu akkor ér valamit, ha a VALÓDI hibát elkapja:
//   1. a fan-out eltűnik (marad a régi, ~45 profilra menő push);
//   2. a tartalék-út mindig lefut (minden regisztrált DUPLA push-t kapna);
//   3. a szöveg nem a katalógusból jön (nyelv helyett fix szöveg).
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import fs from 'node:fs';

const file = 'functions/index.js';
const original = fs.readFileSync(file);
const hash = createHash('sha256').update(original).digest('hex');
const TEST = 'functions/weekly-digest-plan.test.cjs';

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
    title: 'a plugin-fan-out eltűnik (marad a szűk push)',
    apply: (text) =>
      text.replace(
        '  const fanout = await sendWeeklyDigestPush({ week: weekKey, params });',
        '  const fanout = { sent: 0 };',
      ),
  },
  {
    title: 'a tartalék-út mindig lefut (dupla push)',
    apply: (text) => text.replace('  if (fanout.failed) {', '  if (true) {'),
  },
  {
    title: 'a szöveg nem a katalógusból jön',
    apply: (text) =>
      text.replace(
        '    const text = notificationText(WEEKLY_DIGEST_KIND, language, params);',
        "    const text = { title: 'Heti osszefoglalo', body: 'x' };",
      ),
  },
];

const baseline = runTests();
console.log(`alapállapot: ${baseline.failed ? 'BUKIK (hiba!)' : 'zöld'}`);
let bad = baseline.failed ? 1 : 0;
let caught = 0;

try {
  for (const mutation of mutations) {
    const source = fs.readFileSync(file, 'utf8');
    const mutated = mutation.apply(source);
    if (mutated === source) {
      console.log(`ELTER  ${mutation.title} — a minta nem illett`);
      bad += 1;
      continue;
    }
    fs.writeFileSync(file, mutated, 'utf8');
    const result = runTests();
    if (result.failed) {
      caught += 1;
      console.log(`OK     ${mutation.title} — ELKAPVA`);
    } else {
      bad += 1;
      console.log(`ELTER  ${mutation.title} — NEM bukott meg`);
    }
    fs.writeFileSync(file, source, 'utf8');
  }
} finally {
  fs.writeFileSync(file, original);
}

const restored = createHash('sha256').update(fs.readFileSync(file)).digest('hex') === hash;
const after = runTests();
console.log(`\nbájtazonos visszaállítás: ${restored ? 'IGEN' : 'NEM'}`);
console.log(`a helyreállított kör: ${after.failed ? 'BUKIK' : 'zöld'}`);
if (!restored || after.failed) bad += 1;
console.log(`${caught}/${mutations.length} mutáció elkapva${bad ? `, ${bad} hiba` : ''}`);
process.exitCode = bad === 0 ? 0 : 1;
