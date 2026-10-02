#!/usr/bin/env node
/**
 * MUTÁCIÓS BIZONYÍTÉK a Twitch-oldal ELRENDEZÉSÉHEZ (392, 2026-10-02).
 *
 * MIÉRT: a tulajdonos három jelzése — *„az a chat rész elég pici”*, *„fekvő
 * módban nincs chat”*, *„figyelj a tabletre is”*. A javítás lényege, hogy az
 * elrendezés alkalmazkodik; ez a bizonyíték azt méri, hogy a geometriát mérő
 * kapuk **tényleg elkapják** a régi (hibás) viselkedést — a bukó teszt nevével.
 *
 * ⚠️ A fájlokat a helyükön írjuk át, majd **bájtazonosan visszaállítjuk**.
 *
 * Használat: node tmp/mutation-proof-twitch-layout.mjs
 */
import { execFileSync } from 'node:child_process';
import crypto from 'node:crypto';
import fs from 'node:fs';

// ⚠️ MÉRT ESZKÖZ-HIBA: `execFileSync('flutter')` = ENOENT, `'flutter.bat'` =
// EINVAL → a helyes út a `cmd /c flutter test …`.
const FLUTTER = 'cmd';
const SERVICE = 'lib/services/twitch_layout.dart';
const FRAME = 'lib/screens/twitch/twitch_layout.dart';
const SCREEN = 'lib/screens/twitch/twitch_screen.dart';
const LAYOUT_TEST = 'test/screens/twitch_layout_test.dart';

const LANDSCAPE_TEST = 'fekvő telefonon a chat a videó MELLETT van';
const TABLET_TEST = 'tableten is egymás mellett van a chat';
const SMALL_CHAT_TEST = 'álló telefonon a chat a videó ALATT van';
const OPEN_RATIO_TEST = 'nyitott képarányú (kis tablet / összecsukható) képernyőn is a chat kapja a helyet';
const SCREEN_LINT = 'a Twitch-oldal nem épít saját függőleges elrendezést';

const digest = (file) => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const targets = [SERVICE, FRAME, SCREEN, LAYOUT_TEST];
const before = Object.fromEntries(targets.map((file) => [file, digest(file)]));

/** [cím, fájl, lépések ([mit cserélünk, mire]), melyik teszt bukjon] */
const mutations = [
  [
    'az elrendezés MINDIG függőleges (a régi viselkedés: fekvő módban nincs chat)',
    SERVICE,
    [[
      `  if (size.width >= twitchSideBySideMinWidth || size.width > size.height) {
    return TwitchLayoutMode.sideBySide;
  }
  return TwitchLayoutMode.stacked;`,
      '  return TwitchLayoutMode.stacked;',
    ]],
    LANDSCAPE_TEST,
  ],
  [
    'a videó MAGASSÁG-KORLÁTJA elvéve (a videó elviszi a helyet — „elég pici” chat)',
    SERVICE,
    [['  return byWidth < cap ? byWidth : cap;', '  return byWidth;']],
    OPEN_RATIO_TEST,
  ],
  [
    'a chat oszlop szélessége NULLA (fekvő módban nem látszana a chat)',
    SERVICE,
    [[
      `  final wanted = size.width * 0.38;
  if (wanted < twitchSideChatMinWidth) return twitchSideChatMinWidth;
  if (wanted > twitchSideChatMaxWidth) return twitchSideChatMaxWidth;
  return wanted;`,
      '  return 0;',
    ]],
    LANDSCAPE_TEST,
  ],
  [
    'a függőleges módban a chat FIX 40 px (a bejelentett „pici chat”)',
    FRAME,
    [[
      `        Expanded(
          key: const Key('twitch-stacked-chat'),
          child: chat,
        ),`,
      `        SizedBox(
          key: const Key('twitch-stacked-chat'),
          height: 40,
          child: chat,
        ),`,
    ]],
    SMALL_CHAT_TEST,
  ],
  [
    'a képernyő SAJÁT 16:9 videót épít a váza helyett (a régi hiba visszahozása)',
    SCREEN,
    [[
      '    body: TwitchLayoutFrame(',
      '    body: Column(children: [AspectRatio(aspectRatio: 16 / 9, child: SizedBox()), TwitchLayoutFrame(',
    ]],
    SCREEN_LINT,
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
    output = execFileSync(FLUTTER, ['/c', 'flutter', 'test', LAYOUT_TEST], {
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
fs.writeFileSync('tmp/mutation-twitch-layout-proof.txt', `${report.join('\n')}\n`, 'utf8');
process.exitCode = caught === mutations.length && untouched ? 0 : 1;
