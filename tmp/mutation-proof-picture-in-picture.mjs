#!/usr/bin/env node
/**
 * MUTÁCIÓS BIZONYÍTÉK a kis képernyő (PiP) kapuihoz (2026-10-02).
 *
 * MIÉRT: a zöld teszt önmagában nem bizonyíték — a mutáció azt méri, hogy a
 * kapu **tényleg elkapja-e** a visszaállított hibát. Minden mutáció után a
 * célzott teszt-fájl fut, és a **bukó teszt nevét** is mérjük (nem elég, hogy
 * „valami elhasalt").
 *
 * ⚠️ A fájlokat a helyükön írjuk át, majd **bájtazonosan visszaállítjuk** — a
 * végén a sha256-oknak egyezniük kell a kiindulással. Ha nem egyeznek, a
 * bizonyíték érvénytelen (és a szkript hibával lép ki).
 *
 * Használat: node tmp/mutation-proof-picture-in-picture.mjs
 */
import { execFileSync } from 'node:child_process';
import crypto from 'node:crypto';
import fs from 'node:fs';

const TEST = 'test/services/webview_picture_in_picture_test.dart';
// ⚠️ MÉRT ESZKÖZ-HIBA (2026-10-02): a `flutter` a gépen `flutter.bat`.
//  1. `execFileSync('flutter', …)` → **ENOENT** (a `.bat` nem futtatható így);
//  2. `execFileSync('flutter.bat', …)` → **EINVAL** (a Node biztonsági okból
//     nem indít `.bat`-ot `shell` nélkül);
//  3. `cmd /c flutter …` → **ez a helyes út** (mért: a teszt tényleg lefut).
// Az első futás ezért adott 0/13-at: minden „elhasalt”, de nem a teszt bukott.
const FLUTTER = 'cmd';
const FLUTTER_ARGS = (test) => ['/c', 'flutter', 'test', test];
const SCREEN = 'lib/screens/twitch/twitch_screen.dart';
const SERVICE = 'lib/services/webview_picture_in_picture.dart';
const ACTIVITY = 'android/app/src/main/kotlin/hu/hungarianhardstyle/app/MainActivity.kt';

const digest = (file) => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const targets = [TEST, SCREEN, SERVICE, ACTIVITY];
const before = Object.fromEntries(targets.map((file) => [file, digest(file)]));

/** [cím, fájl, mit cserélünk, mire, melyik tesztnek kell buknia] */
const mutations = [
  [
    'az életciklus-figyelő felvétele elvéve (nem lenne, aki háttérbe kerüléskor kérjen)',
    SCREEN,
    'WidgetsBinding.instance.addObserver(this);',
    '// (mutáció: nincs figyelő)',
    'a Twitch-oldal figyeli az életciklust',
  ],
  [
    'a háttérbe kerülésre adott reakció elvéve (a kapu nem hívja a hidat)',
    SCREEN,
    'unawaited(enterStreamPictureInPicture(_controller));',
    '// (mutáció: nincs kis képernyő kérés)',
    'a Twitch-oldal figyeli az életciklust',
  ],
  [
    'a kapu minden állapotra enged (inactive-ra is belépne — iOS párbeszédnél zavarna)',
    SERVICE,
    "  return state == AppLifecycleState.paused || state == AppLifecycleState.hidden;",
    '  return true;',
    'inactive-ra NEM lép be',
  ],
  [
    'a kapu a lecsatolt/előtér állapotra is belépne',
    SERVICE,
    "  return state == AppLifecycleState.paused || state == AppLifecycleState.hidden;",
    "  return state != AppLifecycleState.resumed;",
    'előtérben és lecsatolva sem lép be',
  ],
  [
    'a WebKit-ág kivétele a hidat nem sikeressé teszi (iOS-en nem indulna PiP)',
    SERVICE,
    "      video.webkitSetPresentationMode('picture-in-picture');",
    '      // (mutáció: a WebKit hívás elvéve)',
    'iOS-en a WebKit saját módját hívja',
  ],
  [
    'a szabványos út kerül előre (a WebKit-ág már nem érvényesülne)',
    SERVICE,
    "    if (typeof video.webkitSetPresentationMode === 'function') {",
    "    if (typeof video.requestPictureInPicture === 'function') { video.requestPictureInPicture(); return 'standard'; }\n    if (typeof video.webkitSetPresentationMode === 'function') {",
    'a szabványos API a tartalék út',
  ],
  [
    'a „nincs videó" válasz sikernek számítana (nem lenne tartalék út)',
    SERVICE,
    "    result == WebviewPipResult.webkit || result == WebviewPipResult.standard;",
    '    result != WebviewPipResult.empty;',
    'a „nincs videó" nem siker',
  ],
  [
    'a kérés-kapu nem nyílik újra előtérbe kerüléskor (másodszor nem lenne PiP)',
    SERVICE,
    "    if (state == AppLifecycleState.resumed) {\n      _requested = false;\n      return false;\n    }",
    '    if (state == AppLifecycleState.resumed) {\n      return false;\n    }',
    'visszatérés előtérbe újra engedi',
  ],
  [
    'az iOS inline beállítás elvéve (a videó teljes képernyőre váltana, PiP nem lenne)',
    SCREEN,
    '          allowsInlineMediaPlayback: true,',
    '          allowsInlineMediaPlayback: false,',
    'az iOS WebView inline lejátszással',
  ],
  [
    'a koppintás-kényszer visszaállítása iOS-en (az autoplay nem érvényesülne)',
    SCREEN,
    '          mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},',
    '          mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{PlaybackMediaTypes.video},',
    'az iOS WebView inline lejátszással',
  ],
  [
    'a platform-csomag kivétele a függőségek közül (nem fordulna le)',
    'pubspec.yaml',
    '  webview_flutter_wkwebview: ^3.26.1',
    '  # (mutáció: a platform-csomag elvéve)',
    'a platform-csomag közvetlen függőség',
  ],
  [
    'a natív „enter" művelet elvétele (a felület gombja nem érne célt Androidon)',
    ACTIVITY,
    '                    "enter" -> result.success(enterPictureInPictureNow())',
    '                    // (mutáció: nincs enter művelet)',
    'a natív oldal „enter" művelete',
  ],
  [
    'az Android-verzió kapuja elvéve a natív belépésből (API 26 alatt összeomlana)',
    ACTIVITY,
    '        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false',
    '        // (mutáció: nincs verzió-kapu)',
    'a natív oldal „enter" művelete',
  ],
];

const failures = [];
const report = [];
const say = (line) => {
  console.log(line);
  report.push(line);
};

let caught = 0;
for (const [index, [title, file, from, to, expectedFailure]] of mutations.entries()) {
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
    output = execFileSync(FLUTTER, FLUTTER_ARGS(TEST), { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
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
    say(`ELTER  ${title} → NEM bukott el a várt teszt («${expectedFailure}»), failed=${failed}`);
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
fs.writeFileSync('tmp/mutation-pip-proof.txt', `${report.join('\n')}\n`, 'utf8');
process.exitCode = caught === mutations.length && untouched ? 0 : 1;
