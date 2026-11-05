#!/usr/bin/env node
/**
 * 407: a kiemelt hír képének visszaállítása + a jogi link a PUBLIKÁLT app-ÁSZF-re.
 *
 * Futás: node tmp/prepare-407.mjs
 */
import fs from 'node:fs';

// 1) A Névjegy ÁSZF-sora a valóban publikált, app-specifikus oldalra mutasson
//    (a tulajdonos „done” jelzése után ellenőrizve: HTTP 200, publikált oldal).
const legalPath = 'lib/core/legal/legal_links.dart';
let legal = fs.readFileSync(legalPath, 'utf8');
legal = legal.replace(
  'https://hungarianhardstyle.hu/altalanos-szerzodesi-feltetelek-aszf/',
  'https://hungarianhardstyle.hu/app-felhasznalasi-feltetelek/',
);
legal = legal.replace(
  '/// Általános Szerződési Feltételek (élő oldal: HTTP 200, 2026-11-05).',
  '/// Az ALKALMAZÁS Általános Szerződési Feltételei (élő oldal: HTTP 200, 2026-11-05;\n/// ez az URL kell a Play „kereskedői állapot” képernyőjének ÁSZF-mezőjébe is).',
);
fs.writeFileSync(legalPath, legal, 'utf8');

// 2) A jogi link tesztje is az új URL-t várja.
const testPath = 'test/widgets/about_legal_links_test.dart';
let test = fs.readFileSync(testPath, 'utf8');
test = test.replace(
  "'https://hungarianhardstyle.hu/altalanos-szerzodesi-feltetelek-aszf/'",
  "'https://hungarianhardstyle.hu/app-felhasznalasi-feltetelek/'",
);
fs.writeFileSync(testPath, test, 'utf8');

// 3) Changelog 407 + angol fordítás.
const changeHu = 'Visszaállítottuk a Kezdőlapon a kiemelt hír képét a korábbi kinézetre.';
const changeEn = 'Restored the previous look of the featured news photo on the Home screen.';
const changelogPath = 'lib/data/app_changelog.dart';
let changelog = fs.readFileSync(changelogPath, 'utf8');
if (!changelog.includes('build: 407')) {
  changelog = changelog.replace(
    'const appChangelog = <AppReleaseNotes>[\n',
    "const appChangelog = <AppReleaseNotes>[\n  AppReleaseNotes(\n    version: '1.0.0',\n    build: 407,\n    changes: [\n      '" + changeHu + "',\n    ],\n  ),\n",
  );
  fs.writeFileSync(changelogPath, changelog, 'utf8');
}

const dictPath = 'assets/i18n/en.json';
const dict = JSON.parse(fs.readFileSync(dictPath, 'utf8'));
let added = 0;
if (!Object.prototype.hasOwnProperty.call(dict, changeHu)) {
  dict[changeHu] = changeEn;
  added += 1;
}
fs.writeFileSync(dictPath, JSON.stringify(dict, null, 2) + '\n', 'utf8');

// 4) Verzió.
const pubspecPath = 'pubspec.yaml';
let pubspec = fs.readFileSync(pubspecPath, 'utf8');
pubspec = pubspec.replace(/^version: .*$/m, 'version: 1.0.0+407');
fs.writeFileSync(pubspecPath, pubspec, 'utf8');

console.log('legal url:', /app-felhasznalasi-feltetelek/.test(fs.readFileSync(legalPath, 'utf8')));
console.log('changelog 407:', fs.readFileSync(changelogPath, 'utf8').includes('build: 407'));
console.log('szótár +', added);
console.log('pubspec:', /^version: .*$/m.exec(pubspec)[0]);
