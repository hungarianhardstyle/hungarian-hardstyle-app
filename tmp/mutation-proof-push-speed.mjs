// MUTÁCIÓS BIZONYÍTÉK a push-kifutás gyorsításához (plugin 2.14.13).
//
// MIÉRT: a zöld kapu önmagában nem bizonyíték — a mutáció azt méri, hogy a kapu
// TÉNYLEG elkapja-e a visszaállított lassú viselkedést. Minden mutáció a
// **másolatban** fut (a szállítandó forráshoz nem nyúlunk), és a végén a forrás
// bájtazonosságát is mérjük.
import { execFileSync } from 'node:child_process';
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';

const SOURCE = 'tmp/plugin-2153/huhs-mobile-api';
const WORK = 'tmp/mutation-speed';
const TEST = '/work/tools/verify-push-speed.php';

const digest = (file) => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const before = {
  push: digest(path.join(SOURCE, 'includes/push.php')),
  diagnostics: digest(path.join(SOURCE, 'includes/diagnostics.php')),
};

/** [cím, fájl, mit cserélünk, mire, melyik ellenőrzésnek kell elhasalnia] */
const mutations = [
  [
    'a PÁRHUZAMOSSÁG visszaállítása 25-re (a mért lassú kifutás)',
    'includes/push.php',
    "define('HUHS_PUSH_CONCURRENCY', 50)",
    "define('HUHS_PUSH_CONCURRENCY', 25)",
    'a párhuzamosság 50',
  ],
  [
    'a FELADAT-létrehozás utáni folytatás visszaállítása 2 másodpercre',
    'includes/push.php',
    "wp_schedule_single_event(time() + 1, 'huhs_push_continue', array($key))",
    "wp_schedule_single_event(time() + 2, 'huhs_push_continue', array($key))",
    'a folytatás MINDKÉT helyen 1 másodpercre van ütemezve',
  ],
  [
    'a KÖR VÉGI folytatás visszaállítása 2 másodpercre',
    'includes/push.php',
    "wp_schedule_single_event(time() + 1, 'huhs_push_continue', array($job_key))",
    "wp_schedule_single_event(time() + 2, 'huhs_push_continue', array($job_key))",
    'a folytatás MINDKÉT helyen 1 másodpercre van ütemezve',
  ],
  [
    'a KERETEK elrejtése a diagnosztikából (nem lenne mérhető a PHP időkorlátja)',
    'includes/diagnostics.php',
    '        $parts[] = huhs_push_diag_limits();',
    '        // (mutáció: a keretek elrejtve)',
    'a diagnosztikai sor a fejlécbe is bekerül',
  ],
  [
    'a FOGLALÁS (lock) elengedésének elvétele a kör végén',
    'includes/push.php',
    "        delete_option($lock_option);\n        if (!wp_next_scheduled('huhs_push_continue', array($job_key))) {",
    "        // (mutáció: a foglalás szándékosan bent marad)\n        if (!wp_next_scheduled('huhs_push_continue', array($job_key))) {",
    'a foglalás (lock) elengedve',
  ],
];

fs.rmSync(WORK, { recursive: true, force: true });
fs.mkdirSync(WORK, { recursive: true });

let caught = 0;
const report = [];
const say = (line) => {
  console.log(line);
  report.push(line);
};

for (const [index, [title, file, from, to, expectedFailure]] of mutations.entries()) {
  const dir = path.join(WORK, `m${index + 1}`);
  fs.mkdirSync(dir, { recursive: true });
  const target = path.join(dir, 'huhs-mobile-api');
  fs.cpSync(SOURCE, target, { recursive: true });

  const path_ = path.join(target, file);
  const source = fs.readFileSync(path_, 'utf8');
  if (!source.includes(from)) {
    say(`ELTER  ${title} — a minta nem illik a forrásra (a bizonyíték érvénytelen)`);
    continue;
  }
  fs.writeFileSync(path_, source.replace(from, to), 'utf8');

  let output = '';
  let failed = false;
  try {
    output = execFileSync(
      'docker',
      ['run', '--rm', '-v', `${process.cwd()}:/work`, '-w', '/work', 'php:8.2-cli', 'php', TEST, `/work/${target.replaceAll('\\', '/')}`],
      { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 },
    );
  } catch (error) {
    failed = true;
    output = `${error.stdout ?? ''}${error.stderr ?? ''}`;
  }

  const hit = failed || output.includes('HIBA');
  const named = output.includes(expectedFailure);
  if (hit && named) {
    caught += 1;
    say(`OK     ${title} → a kapu elcsípte («${expectedFailure}»)`);
  } else {
    say(`ELTER  ${title} → NEM bukott el a várt ellenőrzés («${expectedFailure}»), failed=${failed}`);
    for (const line of output.split(/\r?\n/).filter((entry) => entry.startsWith('HIBA')).slice(0, 5)) say(`       ${line}`);
  }
}

const after = {
  push: digest(path.join(SOURCE, 'includes/push.php')),
  diagnostics: digest(path.join(SOURCE, 'includes/diagnostics.php')),
};
const untouched = before.push === after.push && before.diagnostics === after.diagnostics;
say(`\n${caught}/${mutations.length} mutáció ELKAPVA`);
say(`a szállítandó forrás ${untouched ? 'BÁJTAZONOS (érintetlen)' : 'MEGVÁLTOZOTT — HIBA!'}`);
fs.writeFileSync('tmp/mutation-speed-proof.txt', `${report.join('\n')}\n`, 'utf8');
fs.rmSync(WORK, { recursive: true, force: true });
process.exitCode = caught === mutations.length && untouched ? 0 : 1;
