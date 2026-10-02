#!/usr/bin/env node
/**
 * MUTÁCIÓS BIZONYÍTÉK a Twitch-oldal TÁMOGATÁS GOMBJÁNAK HELYÉHEZ (2026-10-02).
 *
 * MIÉRT: a tulajdonos jelzése — *„az a támogatás gomb nagyon rossz helyen van”*
 * (a képen a chat „Küldés” gombja mellett lebegett). Az új kapuk a gomb
 * HELYÉT mérik; ez a bizonyíték azt méri, hogy a kapuk **tényleg elkapják**,
 * ha a hiba visszakerül — és a **bukó teszt nevét** is megköveteli (nem elég,
 * hogy „valami elhasalt”).
 *
 * ⚠️ A fájlokat a helyükön írjuk át, majd **bájtazonosan visszaállítjuk** — a
 * végén a sha256-nak egyeznie kell a kiindulással, különben a bizonyíték
 * érvénytelen (és a szkript hibával lép ki).
 *
 * Használat: node tmp/mutation-proof-donate-placement.mjs
 */
import { execFileSync } from 'node:child_process';
import crypto from 'node:crypto';
import fs from 'node:fs';

// ⚠️ MÉRT ESZKÖZ-HIBA (2026-10-02): a `flutter` a gépen `flutter.bat` —
// `execFileSync('flutter', …)` = ENOENT, `'flutter.bat'` = EINVAL (Node nem
// indít `.bat`-ot `shell` nélkül). A helyes út: `cmd /c flutter test …`.
const FLUTTER = 'cmd';
const SCREEN = 'lib/screens/twitch/twitch_screen.dart';
const TWITCH_TEST = 'test/services/twitch_live_test.dart';
const FLUTTER_ARGS = () => ['/c', 'flutter', 'test', TWITCH_TEST];

const PLACEMENT_TEST = 'a támogatás gomb a videó alatt van, a chattől elkülönítve';
const ICON_TEST = 'a támogatás ikonja mindkét helyen ugyanaz';

const digest = (file) => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const targets = [SCREEN, TWITCH_TEST];
const before = Object.fromEntries(targets.map((file) => [file, digest(file)]));

const DONATE_BLOCK = [
  '          Padding(',
  '            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),',
  '            child: SizedBox(',
  '              width: double.infinity,',
  '              child: OutlinedButton.icon(',
  '                onPressed: () => unawaited(DonateScreen.openDonate()),',
  '                icon: const Icon(Icons.volunteer_activism, size: 18),',
  "                label: const AppText('Támogatás PayPallal'),",
  '              ),',
  '            ),',
  '          ),',
].join('\n');

/**
 * [cím, fájl, lépések ([mit cserélünk, mire] párok), melyik tesztnek kell elhasalnia]
 *
 * ⚠️ MÉRT SAJÁT HIBA (2026-10-02): az első változatban a „chat alá kerül” mutáció
 * csak a `Divider` sort vette ki, ezért a gomb a helyén maradt — a bizonyíték
 * „3/4”-et mutatott, pedig a kapu jó volt, a **mutáció** volt pontatlan. A helyes
 * mutáció a gombot tényleg **áthelyezi** (kiveszi, majd a chat UTÁN szúrja be).
 */
const mutations = [
  [
    'a LEBEGŐ GOMB visszaállítása (a tulajdonos által látott hiba)',
    SCREEN,
    [
      [
        '          const Expanded(child: LiveFeedScreen()),\n        ],\n      ),\n    );',
        '          const Expanded(child: LiveFeedScreen()),\n        ],\n      ),\n      floatingActionButton: FloatingActionButton.extended(\n        onPressed: () => unawaited(DonateScreen.openDonate()),\n        icon: const Icon(Icons.payment),\n        label: const AppText(\'Támogatás\'),\n      ),\n    );',
      ],
    ],
    PLACEMENT_TEST,
  ],
  [
    'a támogatás gomb a CHAT ALÁ kerül (nem a videó alá)',
    SCREEN,
    [
      [DONATE_BLOCK, ''],
      [
        '          const Expanded(child: LiveFeedScreen()),',
        `          const Expanded(child: LiveFeedScreen()),\n${DONATE_BLOCK}`,
      ],
    ],
    PLACEMENT_TEST,
  ],
  [
    'a támogatás gomb kivétele a képernyőről (nem lenne támogatás)',
    SCREEN,
    [["                label: const AppText('Támogatás PayPallal'),", "                label: const AppText('Küldés'),"]],
    PLACEMENT_TEST,
  ],
  [
    'a támogatás ikonjának visszaállítása SZÍVRE (az a kedvencelést jelenti)',
    SCREEN,
    [
      [
        'icon: const Icon(Icons.volunteer_activism, size: 18),',
        'icon: const Icon(Icons.favorite, size: 18),',
      ],
    ],
    ICON_TEST,
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
    output = execFileSync(FLUTTER, FLUTTER_ARGS(file), { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
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
fs.writeFileSync('tmp/mutation-donate-placement-proof.txt', `${report.join('\n')}\n`, 'utf8');
process.exitCode = caught === mutations.length && untouched ? 0 : 1;
