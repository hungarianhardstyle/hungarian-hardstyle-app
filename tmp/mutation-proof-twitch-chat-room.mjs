#!/usr/bin/env node
/**
 * MUTÁCIÓS BIZONYÍTÉK a Twitch-chat HELYÉHEZ és a beviteli sávjához (394,
 * 2026-10-02).
 *
 * A tulajdonos jelzései:
 *  * „az a chat rész NAGYON kicsi, az olvasható rész”,
 *  * „sztem a rádió lekerülhet a twitch chat részről”,
 *  * „eltűnt a billenytűzet eltűntető gomb is”,
 *  * „+ nincsenek emotok”.
 *
 * A fájlokat a helyükön írjuk át, majd **bájtazonosan visszaállítjuk**.
 *
 * Használat: node tmp/mutation-proof-twitch-chat-room.mjs
 */
import { execFileSync } from 'node:child_process';
import crypto from 'node:crypto';
import fs from 'node:fs';

const FLUTTER = 'cmd';
const SCREEN = 'lib/screens/twitch/twitch_screen.dart';
const FRAME = 'lib/screens/twitch/twitch_layout.dart';
const SHELL = 'lib/screens/main_navigation.dart';
const CHAT = 'lib/screens/twitch/twitch_chat.dart';

const LAYOUT_TEST = 'test/screens/twitch_layout_test.dart';
const RADIO_TEST = 'test/widgets/radio_bar_hidden_test.dart';
const CHAT_TEST = 'test/services/twitch_chat_test.dart';

const KEYBOARD_TEST = 'gépelés közben (billentyűzet) a videó eltűnik';
const RADIO_LINT = 'a Twitch-oldal megnyíláskor elrejti, bezáráskor visszaadja';
const SHELL_LINT = 'a keret a rádiósávot a burokban rejti el';
const COMPOSER_TEST = 'a beviteli sávban ott az emotikon-gomb és a billentyűzet-elrejtő';
const EMOJI_TEST = 'az emotikon-választó a mezőbe szúrja a kiválasztott emojit';

const digest = (file) => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const targets = [SCREEN, FRAME, SHELL, CHAT];
const before = Object.fromEntries(targets.map((file) => [file, digest(file)]));

/** [cím, fájl, lépések, várt bukó teszt, teszt-fájl] */
const mutations = [
  [
    'gépelés közben NEM húzódik össze a videó (a chat olvasható része kicsi marad)',
    FRAME,
    [[
      `        if (!keyboardVisible) ...[
          _videoArea(twitchStackedVideoHeight(size)),
          info,
        ],`,
      `        _videoArea(twitchStackedVideoHeight(size)),
        info,`,
    ]],
    KEYBOARD_TEST,
    LAYOUT_TEST,
  ],
  [
    'a rádiósáv elrejtésének elvétele a Twitch-oldal megnyílásakor',
    SCREEN,
    [['    radioBarVisibility.hide();', '    // (mutáció: nincs elrejtés)']],
    RADIO_LINT,
    RADIO_TEST,
  ],
  [
    'a rádiósáv visszaadásának elvétele (az oldal elhagyása után is rejtve maradna)',
    SCREEN,
    [['    radioBarVisibility.show();', '    // (mutáció: nem adja vissza)']],
    RADIO_LINT,
    RADIO_TEST,
  ],
  [
    'a rádiósáv burkolásának elvétele a keretben (fekvő elrendezés)',
    SHELL,
    [[
      `                  ? const SafeArea(
                      top: false,
                      child: HideRadioBar(child: RadioPlayerBar()),
                    )`,
      '                  ? const SafeArea(top: false, child: RadioPlayerBar())',
    ]],
    SHELL_LINT,
    RADIO_TEST,
  ],
  [
    'az emotikon-gomb elvétele a beviteli sávból',
    CHAT,
    [[
      `              IconButton(
                tooltip: tr(context, 'Emotikon'),
                onPressed: () => unawaited(_pickEmoji()),
                icon: const Icon(Icons.emoji_emotions_outlined),
              ),`,
      '              const SizedBox.shrink(),',
    ]],
    COMPOSER_TEST,
    CHAT_TEST,
  ],
  [
    'a billentyűzet-elrejtő gomb elvétele a beviteli sávból',
    CHAT,
    [['              const KeyboardDismissButton(),', '              const SizedBox.shrink(),']],
    COMPOSER_TEST,
    CHAT_TEST,
  ],
  [
    'az emotikon beszúrásának elvétele (a választó nem ír a mezőbe)',
    CHAT,
    [['    insertChatEmoji(_controller, emoji, focusNode: _focusNode);', '    // (mutáció: nem szúrja be)']],
    EMOJI_TEST,
    CHAT_TEST,
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
fs.writeFileSync('tmp/mutation-twitch-chat-room-proof.txt', `${report.join('\n')}\n`, 'utf8');
process.exitCode = caught === mutations.length && untouched ? 0 : 1;
