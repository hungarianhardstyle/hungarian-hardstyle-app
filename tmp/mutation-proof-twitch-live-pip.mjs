#!/usr/bin/env node
/**
 * MUTÁCIÓS BIZONYÍTÉK a Twitch-élő ÉRTESÍTÉS útvonalához és a KIS KÉPERNYŐ
 * (PiP) felületéhez (393, 2026-10-02).
 *
 * A tulajdonos jelzései:
 *  * „ha kimegy a push a twitch chatről, hogy live … akkor nyissa meg a twitches
 *    oldalt a pushra nyomva”,
 *  * „ez a kis ablak a PIP is elég FOSCSI, a rádió gomb dominál”,
 *  * „a pip gomb se megy amúgy a twitch oldalon”.
 *
 * Ez a bizonyíték azt méri, hogy a kapuk **tényleg elkapják** a hibákat — a bukó
 * teszt nevével együtt. A fájlokat a helyükön írjuk át, majd **bájtazonosan
 * visszaállítjuk**.
 *
 * Használat: node tmp/mutation-proof-twitch-live-pip.mjs
 */
import { execFileSync } from 'node:child_process';
import crypto from 'node:crypto';
import fs from 'node:fs';

const FLUTTER = 'cmd';
const PUSH = 'lib/services/push_notification_service.dart';
const ROUTER = 'lib/screens/notifications/notification_center_screen.dart';
const SCREEN = 'lib/screens/twitch/twitch_screen.dart';
const SHELL = 'lib/screens/main_navigation.dart';
const SERVICE = 'lib/services/picture_in_picture.dart';
const ACTIVITY = 'android/app/src/main/kotlin/hu/hungarianhardstyle/app/MainActivity.kt';

const PUSH_TEST = 'test/screens/notification_targets_test.dart';
const PIP_TEST = 'test/widgets/picture_in_picture_ui_test.dart';

const NOTIF_TEST = 'a Twitch-élő értesítés az app Twitch-oldalát nyitja';
const PUSH_LINT = 'a Twitch-élő PUSH is az app Twitch-oldalát nyitja';
const PIP_VIDEO_LINT = 'a Twitch-oldal PiP-ben CSAK a videót rajzolja';
const SHELL_LINT = 'a burok (rádiósáv, menü) el van rejtve PiP-ben';
const NATIVE_LINT = 'a natív oldal jelzi az állapotot';
const HIDE_TEST = 'a rádiósáv (és minden, ami a burokban van) eltűnik PiP-ben';

const digest = (file) => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const targets = [PUSH, ROUTER, SCREEN, SHELL, SERVICE, ACTIVITY];
const before = Object.fromEntries(targets.map((file) => [file, digest(file)]));

/** [cím, fájl, lépések, várt bukó teszt, teszt-fájl] */
const mutations = [
  [
    'az appon belüli élő értesítés ágának elvétele (a koppintás némán elveszne)',
    ROUTER,
    [[
      `      if (notification.type == 'twitch_live' || notification.kind == 'twitch_live') {`,
      '      if (false) {',
    ]],
    NOTIF_TEST,
    PUSH_TEST,
  ],
  [
    'a Twitch PUSH-ág elvétele (a böngésző nyílna meg)',
    PUSH,
    [[
      `      if (type == 'twitch_live' || type == 'twitch' || isTwitchChannelUrl(url)) {`,
      '      if (false) {',
    ]],
    PUSH_LINT,
    PUSH_TEST,
  ],
  [
    'a Twitch-ág a böngésző-nyitás UTÁN (sosem érne oda)',
    PUSH,
    [[
      `      if (type == 'twitch_live' || type == 'twitch' || isTwitchChannelUrl(url)) {`,
      '      if (false) {',
    ], [
      `      await openInAppBrowser(context, url, title: message.notification?.title);`,
      `      await openInAppBrowser(context, url, title: message.notification?.title);\n      if (url.isNotEmpty) {`,
    ]],
    PUSH_LINT,
    PUSH_TEST,
  ],
  [
    'a PiP-ág elvétele a Twitch-oldalról (a kis ablakban az egész felület látszana)',
    SCREEN,
    [['        if (inPictureInPicture) {', '        if (false) {']],
    PIP_VIDEO_LINT,
    PIP_TEST,
  ],
  [
    'a rádiósáv elrejtésének elvétele a burokból',
    SHELL,
    [[
      `            bottomNavigationBar: HiddenInPictureInPicture(
              child: landscape`,
      '            bottomNavigationBar: landscape',
    ], [
      `                    ),
            ),
          );`,
      `                    ),
          );`,
    ]],
    SHELL_LINT,
    PIP_TEST,
  ],
  [
    'a natív „changed” jelzés elvétele (a felület nem tudná, hogy PiP-ben van)',
    ACTIVITY,
    [['            pipChannel?.invokeMethod("changed", isInPictureInPictureMode)', '            // (mutáció: nincs jelzés)']],
    NATIVE_LINT,
    PIP_TEST,
  ],
  [
    'a PiP-burok mindig kirajzolja a gyereket (nem rejt semmit)',
    SERVICE,
    [['builder: (context, active, _) => active ? const SizedBox.shrink() : child,', 'builder: (context, active, _) => child,']],
    HIDE_TEST,
    PIP_TEST,
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
fs.writeFileSync('tmp/mutation-twitch-live-pip-proof.txt', `${report.join('\n')}\n`, 'utf8');
process.exitCode = caught === mutations.length && untouched ? 0 : 1;
