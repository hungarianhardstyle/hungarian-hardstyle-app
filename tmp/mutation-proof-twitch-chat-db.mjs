#!/usr/bin/env node
/**
 * MUTÁCIÓS BIZONYÍTÉK az ADATBÁZIS-hibához (395, 2026-10-02).
 *
 * A tulajdonos kérdése: *„üzenet azért nem küldhető a twitch chates részre mert a
 * stream nem live?”* — a valódi ok az volt, hogy a stream-chat szolgáltatás a
 * `FirebaseFirestore.instance`-t használta, ami a **`(default)`** adatbázisra
 * mutat, ahol nincs `twitch_chat` szabály (éles mérés: ott **403**, a néves
 * adatbázisban **200**).
 *
 * Ez a bizonyíték azt méri, hogy a kapuk **tényleg elkapják** a visszaállított
 * hibát — a bukó teszt nevével együtt. Bájtazonos visszaállítással.
 *
 * Használat: node tmp/mutation-proof-twitch-chat-db.mjs
 */
import { execFileSync } from 'node:child_process';
import crypto from 'node:crypto';
import fs from 'node:fs';

const FLUTTER = 'cmd';
const SERVICE = 'lib/services/twitch_chat.dart';
const TEST = 'test/services/twitch_chat_test.dart';
const DB_LINT = 'a szolgáltatás a NÉVES adatbázist használja';
const APP_LINT = 'az egész app a néves adatbázist használja';

const digest = (file) => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const targets = [SERVICE, TEST];
const before = Object.fromEntries(targets.map((file) => [file, digest(file)]));

const mutations = [
  [
    'a szolgáltatás visszaállítása a (default) adatbázisra (a valódi hiba)',
    SERVICE,
    [[
      ': _firestore = firestore ?? huHsFirestore(),',
      ': _firestore = firestore ?? FirebaseFirestore.instance,',
    ]],
    DB_LINT,
  ],
  [
    'az adatbázis-azonosító kivétele a közös konstansból (kézzel beírt szöveg)',
    SERVICE,
    [['      databaseId: CommunityService.firestoreDatabaseId,', "      databaseId: 'valami-mas',"]],
    DB_LINT,
  ],
  [
    'az `instanceFor` elvétele a segédfüggvényből (a (default) adatbázis)',
    SERVICE,
    [[
      `FirebaseFirestore huHsFirestore() => FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: CommunityService.firestoreDatabaseId,
    );`,
      'FirebaseFirestore huHsFirestore() => FirebaseFirestore.instance;',
    ]],
    DB_LINT,
  ],
];

const failures = [];
const report = [];
const say = (line) => {
  console.log(line);
  report.push(line);
};

let caught = 0;
for (const [index, [title, file, steps, expectedFailure]] of mutations.entries()) {
  const source = fs.readFileSync(file, 'utf8');
  let mutated = source;
  let applies = true;
  for (const [from, to] of steps) {
    if (!mutated.includes(from)) {
      applies = false;
      break;
    }
    mutated = mutated.replace(from, to);
  }
  if (!applies) {
    say(`ELTÉR  ${title} — a minta nem illik a forrásra (a bizonyíték érvénytelen)`);
    failures.push(title);
    continue;
  }
  fs.writeFileSync(file, mutated, 'utf8');
  let output = '';
  let failed = false;
  try {
    output = execFileSync(FLUTTER, ['/c', 'flutter', 'test', TEST], {
      encoding: 'utf8',
      maxBuffer: 64 * 1024 * 1024,
    });
  } catch (error) {
    failed = true;
    output = `${error.stdout ?? ''}${error.stderr ?? ''}`;
  } finally {
    fs.writeFileSync(file, source, 'utf8');
  }
  const named = output.includes(expectedFailure);
  if (failed && named) {
    caught += 1;
    say(`OK     ${title} → a kapu elcsípte («${expectedFailure}»)`);
  } else {
    failures.push(title);
    say(`ELTÉR  ${title} → NEM bukott el a várt teszt («${expectedFailure}»), failed=${failed}`);
    for (const line of output.split(/\r?\n/).filter((entry) => /\[E\]|Expected:|Actual:/.test(entry)).slice(0, 4)) {
      say(`       ${line.trim().slice(0, 160)}`);
    }
  }
  if (index === 0) say('       (az első futás felmelegíti a fordítót, ezért lassabb)');
}

const after = Object.fromEntries(targets.map((file) => [file, digest(file)]));
const untouched = targets.every((file) => before[file] === after[file]);
say(`\n${caught}/${mutations.length} mutáció ELKAPVA`);
say(`a források ${untouched ? 'BÁJTAZONOSAK (érintetlenek)' : 'MEGVÁLTOZTAK — HIBA!'}`);
fs.writeFileSync('tmp/mutation-twitch-chat-db-proof.txt', `${report.join('\n')}\n`, 'utf8');
process.exitCode = caught === mutations.length && untouched ? 0 : 1;
