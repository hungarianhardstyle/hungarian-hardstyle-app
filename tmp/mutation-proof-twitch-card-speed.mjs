#!/usr/bin/env node
/**
 * MUTÁCIÓS BIZONYÍTÉK a főoldali Twitch-kártya GYORSÍTÁSÁHOZ (395, 2026-10-02).
 *
 * A tulajdonos jelzése: *„meg ez a twitch kártya a főoldalon 100 év mire betölt”*.
 * A mért gyökerek: (1) a kártya a Twitch-állapotra várt, pedig a behirdetett
 * kártyához nem kell; (2) a kép 1179 KB volt, gyorsítótár és kicsinyítés nélkül.
 *
 * A fájlokat a helyükön írjuk át, majd **bájtazonosan visszaállítjuk**.
 *
 * Használat: node tmp/mutation-proof-twitch-card-speed.mjs
 */
import { execFileSync } from 'node:child_process';
import crypto from 'node:crypto';
import fs from 'node:fs';

const FLUTTER = 'cmd';
const CARD = 'lib/widgets/twitch_live_card.dart';
const SERVICE = 'lib/services/twitch_live.dart';

const CARD_TEST = 'test/widgets/twitch_live_card_test.dart';
const LIVE_TEST = 'test/services/twitch_live_test.dart';

const INSTANT_TEST = 'a behirdetett kártya AZONNAL megjelenik';
const SPEED_LINT = 'a kártya AZONNAL megjelenik, ha be van hirdetve';
const IMAGE_TEST = 'élő adásnál a saját kép és felirat kerül a kártyára';
const SMALL_TEST = 'a kicsinyített kép kerül a kártyára, ha a plugin megadja';

const digest = (file) => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const targets = [CARD, SERVICE];
const before = Object.fromEntries(targets.map((file) => [file, digest(file)]));

/** [cím, fájl, lépések, várt bukó teszt, teszt-fájl] */
const mutations = [
  [
    'a kártya újra a Twitch-állapotra vár (a „100 év” hiba)',
    CARD,
    [['    final visible = announcement ||\n        (live != null &&', '    final visible = (live != null &&']],
    INSTANT_TEST,
    CARD_TEST,
  ],
  [
    'a gyorsítótárazott kép helyett újra `Image.network`',
    CARD,
    [['                        CachedNetworkImage(', '                        Image.network(']],
    SPEED_LINT,
    LIVE_TEST,
  ],
  [
    'a kicsinyítés (memCacheWidth) elvétele — teljes méretben dekódolna',
    CARD,
    [['                          memCacheWidth: 900,\n', '']],
    IMAGE_TEST,
    CARD_TEST,
  ],
  [
    'a kicsinyített kép használatának elvétele (a nagy kép megy ki)',
    SERVICE,
    [[
      `  String get displayImageUrl =>
      imageUrlSmall.trim().isNotEmpty ? imageUrlSmall.trim() : imageUrl.trim();`,
      '  String get displayImageUrl => imageUrl.trim();',
    ]],
    SMALL_TEST,
    LIVE_TEST,
  ],
];

const failures = [];
const report = [];
const say = (line) => {
  console.log(line);
  report.push(line);
};

let caught = 0;
for (const [index, [title, file, steps, expectedFailure, testFile]] of mutations.entries()) {
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
    output = execFileSync(FLUTTER, ['/c', 'flutter', 'test', testFile], {
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
fs.writeFileSync('tmp/mutation-twitch-card-speed-proof.txt', `${report.join('\n')}\n`, 'utf8');
process.exitCode = caught === mutations.length && untouched ? 0 : 1;
