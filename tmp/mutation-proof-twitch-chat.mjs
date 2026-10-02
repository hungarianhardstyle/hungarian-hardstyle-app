#!/usr/bin/env node
/**
 * MUTÁCIÓS BIZONYÍTÉK a **stream-chat** kapuihoz (391, 2026-10-02).
 *
 * MIÉRT: a tulajdonos jelzése — *„a twitch oldal alatti chatr ha írok,
 * valamiért a fő chatre is kikerül...”*. A javítás lényege, hogy a Twitch-oldal
 * **ne** a fő chat gyűjteményét használja. Ez a bizonyíték azt méri, hogy a
 * kapuk **tényleg elkapják**, ha a hiba visszakerül — a bukó teszt **nevével**
 * együtt (nem elég, hogy „valami elhasalt”).
 *
 * ⚠️ A fájlokat a helyükön írjuk át, majd **bájtazonosan visszaállítjuk**.
 *
 * Használat: node tmp/mutation-proof-twitch-chat.mjs
 */
import { execFileSync } from 'node:child_process';
import crypto from 'node:crypto';
import fs from 'node:fs';

// ⚠️ MÉRT ESZKÖZ-HIBA: a `flutter` a gépen `flutter.bat` — `execFileSync('flutter')`
// = ENOENT, `'flutter.bat'` = EINVAL. A helyes út: `cmd /c flutter test …`.
const FLUTTER = 'cmd';
const SCREEN = 'lib/screens/twitch/twitch_screen.dart';
const SERVICE = 'lib/services/twitch_chat.dart';
const RULES = 'firestore.rules';
const CHAT_TEST = 'test/services/twitch_chat_test.dart';
const GLUE_TEST = 'test/services/twitch_live_test.dart';

const PLACEMENT = 'a Twitch-oldal a stream-chatet használja, nem a fő chatet';
const SERVICE_LINT = 'a szolgáltatás nem ír a fő chatbe, és élőben, fordítva olvas';
const RULES_LINT = 'a Firestore-szabály tartalmazza a külön gyűjteményt';
const BYTES_TEST = '500 karakternél hosszabb nem küldhető';

const digest = (file) => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const targets = [SCREEN, SERVICE, RULES, CHAT_TEST, GLUE_TEST];
const before = Object.fromEntries(targets.map((file) => [file, digest(file)]));

/** [cím, fájl, lépések ([mit cserélünk, mire]), melyik teszt bukjon, melyik teszt-fájl] */
const mutations = [
  [
    'a Twitch-oldal visszaállítása a FŐ chatre (a tulajdonos által látott hiba)',
    SCREEN,
    [['const Expanded(child: TwitchStreamChat()),', 'const Expanded(child: LiveFeedScreen()),']],
    PLACEMENT,
    CHAT_TEST,
  ],
  [
    'a szolgáltatás a FŐ chat gyűjteményébe ír (nem külön szál)',
    SERVICE,
    [['collection(twitchChatCollection)', "collection('live_feed_posts')"]],
    SERVICE_LINT,
    CHAT_TEST,
  ],
  [
    'a szolgáltatás fordítva (legrégebbivel kezdve) olvas',
    SERVICE,
    [["orderBy('createdAt', descending: true)", "orderBy('createdAt', descending: false)"]],
    SERVICE_LINT,
    CHAT_TEST,
  ],
  [
    'a hossz-korlát elvétele a kliensen (bármilyen hosszú üzenet elmenne)',
    SERVICE,
    [['if (text.length > twitchChatMaxLength) return null;', '// (mutáció: nincs hossz-korlát)']],
    BYTES_TEST,
    CHAT_TEST,
  ],
  [
    'a Firestore-szabály elvétele a külön gyűjteményről',
    RULES,
    [['match /twitch_chat/{messageId} {', 'match /twitch_chat_disabled/{messageId} {']],
    RULES_LINT,
    CHAT_TEST,
  ],
  [
    'a szabály hossz-korlátjának fellazítása 500 → 5000',
    RULES,
    [['request.resource.data.text.size() <= 500', 'request.resource.data.text.size() <= 5000']],
    RULES_LINT,
    CHAT_TEST,
  ],
  [
    'a Twitch-oldal a stream-chat helyett a fő chatet használná (a bekötés kapuja)',
    SCREEN,
    [['const Expanded(child: TwitchStreamChat()),', 'const Expanded(child: LiveFeedScreen()),']],
    'a Twitch-oldal a stream-chatjét, a támogatást és a kis képernyőt használja',
    GLUE_TEST,
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
fs.writeFileSync('tmp/mutation-twitch-chat-proof.txt', `${report.join('\n')}\n`, 'utf8');
process.exitCode = caught === mutations.length && untouched ? 0 : 1;
