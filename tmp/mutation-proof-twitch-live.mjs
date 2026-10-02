#!/usr/bin/env node
/**
 * MUTÁCIÓS BIZONYÍTÉK a Twitch-élő figyelő **teljes útjára** (2026-10-02).
 *
 * MIÉRT: az új emulátoros integrációs suite (`functions/twitch-live.test.cjs`)
 * zöldje önmagában nem bizonyíték — a mutáció méri, hogy a kapu **tényleg
 * elkapja-e** a visszaállított hibát, és a **bukó teszt nevét** is megköveteli
 * (nem elég, hogy „valami elhasalt").
 *
 * ⚠️ A fájlokat a helyükön írjuk át, majd **bájtazonosan visszaállítjuk** — a
 * végén a sha256-oknak egyezniük kell. Emulátoros futtatás fájlonként.
 *
 * Használat: node tmp/mutation-proof-twitch-live.mjs
 */
import { execSync } from 'node:child_process';
import crypto from 'node:crypto';
import fs from 'node:fs';

const PLAN = 'functions/twitch-live-plan.js';
const INDEX = 'functions/index.js';
const TEST = 'functions/twitch-live.test.cjs';

const digest = (file) => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const targets = [PLAN, INDEX];
const before = Object.fromEntries(targets.map((file) => [file, digest(file)]));

/** [cím, fájl, mit cserélünk, mire, melyik tesztnek kell buknia] */
const mutations = [
  [
    'a „már bejelentett adás" kapu elvétele (másodszor is kimenne a push)',
    PLAN,
    "  if (streamId === announced) return { notify: false, reason: 'already-announced', streamId, reset: false };",
    '  // (mutáció: nincs ismétlés-kapu)',
    'ugyanarról az adásról MÁSODSZOR nem szól',
  ],
  [
    'az adás végi jelölés-törlés elvétele (a következő adás néma maradna)',
    PLAN,
    "    return { notify: false, reason: announced ? 'stream-ended' : 'offline', streamId: '', reset: Boolean(announced) };",
    "    return { notify: false, reason: announced ? 'stream-ended' : 'offline', streamId: '', reset: false };",
    'az adás végén a jelölés törlődik',
  ],
  [
    'a tulajdonosi kapcsoló elvétele (kikapcsolva is küldene)',
    PLAN,
    "  if (!enabled) return { notify: false, reason: 'disabled', streamId, reset: false };",
    '  // (mutáció: nincs kapcsoló)',
    'a tulajdonosi kapcsoló kikapcsolva nem küld',
  ],
  [
    'a push célpontjának elrontása (a koppintás nem a streamhez vinne)',
    INDEX,
    "        targetType: 'custom',",
    "        targetType: 'none',",
    'élő adásnál MINDENKINEK szól',
  ],
  [
    'a jelölés írásának elvétele (minden kör újra szólna)',
    INDEX,
    '      announcedStreamId: plan.streamId,',
    '      announcedStreamId: state.announcedStreamId ?? null,',
    'ugyanarról az adásról MÁSODSZOR nem szól',
  ],
  [
    'a Twitch-hibaág elvétele (hálózati hiba esetén is küldene)',
    INDEX,
    "  if (!live) return { skipped: 'unreachable' };",
    '  // (mutáció: nincs hibakapu)',
    'ha a Twitch nem érhető el',
  ],
];

const failures = [];
const report = [];
const say = (line) => {
  console.log(line);
  report.push(line);
};

/**
 * ⚠️ MÉRT ESZKÖZ-HIBA (2026-10-02): a Node-ból indított emulátor két módon is
 * elhasalt:
 *  1. `execFileSync('npx', [...], { shell: true })` → a shell **szóköznél
 *     elvágta** a `node functions/…` parancsot, a Firebase pedig
 *     *„Too many arguments"*-szal állt le → minden mutáció „elhasalt", de nem a
 *     teszt bukott (hamis bizonyíték);
 *  2. ezért a **projektben bevált** hívást használjuk: `execSync` egyetlen
 *     parancssorral, a belső parancsot **idézőjelben** (lásd
 *     `tools/run-function-tests.mjs`).
 */
const runSuite = () =>
  execSync(
    'npx firebase emulators:exec --only firestore --project demo-huhs ' +
      `"node --test ${TEST}"`,
    { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 },
  );

let caught = 0;
for (const [title, file, from, to, expectedFailure] of mutations) {
  const source = fs.readFileSync(file, 'utf8');
  if (!source.includes(from)) {
    say(`ELTER  ${title} — a minta nem illik a forrásra (a bizonyíték érvénytelen)`);
    failures.push(title);
    continue;
  }
  fs.writeFileSync(file, source.replace(from, to), 'utf8');
  let output = '';
  let failed = false;
  try {
    output = runSuite();
  } catch (error) {
    failed = true;
    output = `${error.stdout ?? ''}${error.stderr ?? ''}`;
  } finally {
    fs.writeFileSync(file, source, 'utf8');
  }
  const named = output.includes(expectedFailure);
  if (failed && named) {
    caught += 1;
    say(`OK     ${title} → a kapu elcsípte («${expectedFailure}»)`.slice(0, 200));
  } else {
    failures.push(title);
    say(`ELTER  ${title} → NEM bukott el a várt teszt («${expectedFailure}»), failed=${failed}`);
    for (const line of output.split(/\r?\n/).filter((entry) => /AssertionError|✖/.test(entry)).slice(0, 3)) {
      say(`       ${line.trim().slice(0, 140)}`);
    }
  }
}

const after = Object.fromEntries(targets.map((file) => [file, digest(file)]));
const untouched = targets.every((file) => before[file] === after[file]);
say(`\n${caught}/${mutations.length} mutáció ELKAPVA`);
say(`a források ${untouched ? 'BÁJTAZONOSAK (érintetlenek)' : 'MEGVÁLTOZTAK — HIBA!'}`);
fs.writeFileSync('tmp/mutation-twitch-live-proof.txt', `${report.join('\n')}\n`, 'utf8');
process.exitCode = caught === mutations.length && untouched ? 0 : 1;
