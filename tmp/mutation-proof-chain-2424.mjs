#!/usr/bin/env node
/**
 * Mutációs bizonyíték a plugin 2.14.24 push-lánc javítására.
 *
 * MIÉRT: a zöld ellenőrzés önmagában nem bizonyít semmit — a kérdés az, hogy a
 * mérés ELKAPJA-e a hibát. Ezért minden javítást visszafordítunk egy MÁSOLATBAN
 * (a kiadott könyvtárat nem bántjuk), és megnézzük, hogy a verifikáló pirosra
 * vált, pontosan a várt ellenőrzésnél.
 *
 * Futás: node tmp/mutation-proof-chain-2424.mjs
 * Kilépés: 0 = minden mutációt elkapott a mérés, 1 = valamelyik átcsúszott.
 */
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const BASE = path.join(ROOT, 'tmp', 'plugin-2154', 'huhs-mobile-api');
const WORK = path.join(ROOT, 'tmp', 'mutation-proof-chain-2424');
const VERIFIER = '/work/tools/verify-push-news-watchdog.php';
const IMAGE = 'php:8.2-cli';

const MUTATIONS = [
  {
    name: 'tokenhiba-torli-a-feladatot',
    title: 'a régi viselkedés: tokenhiba esetén a folytató kör TÖRLI a feladatot',
    anchor: `        $job['postponed'] = $postponed;
        $job['last_run'] = time();
        update_option($option, $job, false);`,
    replacement: `        $job['postponed'] = $postponed;
        $job['last_run'] = time();
        delete_option($option);`,
    expect: 'feladat MEGMARAD',
  },
  {
    name: 'halo-csak-az-aktiv-feladatot-nezi',
    title: 'a régi viselkedés: a biztonsági háló csak az EGYETLEN aktív feladatot nézi',
    anchor: `    $keys = huhs_push_live_jobs();
    if (!$keys) return;`,
    replacement: `    $activeOnly = (string) get_option('huhs_push_active_job', '');
    $keys = $activeOnly === '' ? array() : array($activeOnly);
    if (!$keys) return;`,
    expect: 'is befejez',
  },
  {
    name: 'halo-csak-a-szivveres-korat-nezi',
    title: 'a régi viselkedés: a háló csak a szívverés korát nézi (a hiányzó cron-eseményt nem)',
    anchor: `        $scheduled = (bool) wp_next_scheduled('huhs_push_continue', array($key));
        // A cron-láncnak kellene folytatnia; csak akkor lépünk be, ha elakadt.
        if ($scheduled && $age <= HUHS_PUSH_RESUME_GAP) continue;
        // Frissen ütemezett (esemény még nem látszik, mert most készült) kör.
        if (!$scheduled && $age <= 3) continue;`,
    replacement: `        $scheduled = (bool) wp_next_scheduled('huhs_push_continue', array($key));
        if ($age <= HUHS_PUSH_RESUME_GAP) continue;`,
    expect: 'akkor is folytat',
  },
  {
    name: 'hir-a-globalis-mutator-jegyzi-fel',
    title: 'a mért hiba: a hír a GLOBÁLIS aktív mutatót jegyzi fel (2.14.25 javítás nélkül)',
    anchor: `        $found = huhs_push_find_job($data);`,
    replacement: `        $globalKey = (string) get_option('huhs_push_active_job', '');
        $globalJob = $globalKey !== '' ? get_option('huhs_push_job_' . $globalKey, null) : null;
        $found = is_array($globalJob) ? array('key' => $globalKey, 'job' => $globalJob) : null;`,
    expect: 'a hívás helyén mérve',
  },
  {
    name: 'befejezes-nem-zarja-le-a-konyvelest',
    title: 'a mért dupla-push motor: a záró kör NEM takarítja a hír-könyvelést (2.14.25 nélkül)',
    anchor: `    huhs_push_news_chain_complete($data);`,
    replacement: `    // (a 2.14.25 előtti viselkedés: nincs lezárás)`,
    expect: 'LEZÁRJA a hír-könyvelést',
  },
];

function runVerifier(pluginDir) {
  const result = spawnSync(
    'docker',
    ['run', '--rm', '-v', `${ROOT}:/work`, '-w', '/work', IMAGE, 'php', VERIFIER, pluginDir],
    { encoding: 'utf8', shell: false, maxBuffer: 32 * 1024 * 1024 },
  );
  const output = `${result.stdout ?? ''}${result.stderr ?? ''}`;
  const failures = output
    .split(/\r?\n/)
    .filter((line) => line.startsWith('HIBA '))
    .map((line) => line.replace(/^HIBA /, ''));
  return { status: result.status, output, failures };
}

let failed = 0;

// 0) Kontroll: a kiadott (javított) könyvtár zöld — enélkül a bizonyíték értelmetlen.
const control = runVerifier('/work/tmp/plugin-2154/huhs-mobile-api');
const controlOk = control.status === 0 && control.output.includes('PUSH-NEWS OK');
console.log(`${controlOk ? 'OK  ' : 'HIBA'} kontroll: a javított plugin zöld (${control.status}, ${control.failures.length} hiba)`);
if (!controlOk) failed++;

fs.rmSync(WORK, { recursive: true, force: true });

for (const mutation of MUTATIONS) {
  const dir = path.join(WORK, mutation.name);
  const pluginDir = path.join(dir, 'huhs-mobile-api');
  fs.mkdirSync(dir, { recursive: true });
  fs.cpSync(BASE, pluginDir, { recursive: true });

  const file = path.join(pluginDir, 'includes', 'push.php');
  const source = fs.readFileSync(file, 'utf8');
  const hits = source.split(mutation.anchor).length - 1;
  if (hits !== 1) {
    console.log(`HIBA ${mutation.name}: a horgony ${hits}× szerepel (1 kell) — a bizonyíték nem érvényes`);
    failed++;
    continue;
  }
  fs.writeFileSync(file, source.replace(mutation.anchor, mutation.replacement), 'utf8');

  const result = runVerifier(`/work/tmp/mutation-proof-chain-2424/${mutation.name}/huhs-mobile-api`);
  const caught = result.status !== 0
    && result.failures.some((label) => label.includes(mutation.expect))
    && !result.output.includes('PUSH-NEWS OK');
  console.log(`${caught ? 'OK  ' : 'HIBA'} ${mutation.title} → ${caught
    ? `a mérés elkapja (${result.failures.length} piros, köztük: „${result.failures.find((l) => l.includes(mutation.expect))}”)`
    : `a mérés NEM kapja el (exit=${result.status}, ${result.failures.length} piros)`}`);
  if (!caught) failed++;
}

console.log(failed === 0
  ? `\nMINDEN MUTÁCIÓT ELKAPOTT A MÉRÉS (${MUTATIONS.length}/${MUTATIONS.length} + kontroll)`
  : `\n${failed} eset nem bizonyított`);
process.exit(failed === 0 ? 0 : 1);
