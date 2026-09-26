#!/usr/bin/env node
/**
 * A CI-ből letöltött **aláírás nélküli iOS IPA** ellenőrzése (csak olvasás).
 *
 * MIÉRT: a sideloadolt build akkor hasznos, ha **tényleg a mostani kód** van benne
 * (a hírek címke-/kategória-fordítása és a mai app-tartalom). Ez a szkript ezt
 * **méri**, nem feltételezi: a csomagban lévő szótárat, az `Info.plist`
 * kulcsait és a changelog-sorokat nézi.
 *
 * ⚠️ Az `Info.plist` az iOS-ben **bináris plist**, ezért nem JSON-ként olvassuk:
 * a kulcsokat/szövegeket a nyers bájtokban keressük (ASCII és UTF-16LE alakban
 * is), és ezt a korlátot a kimenet is kimondja.
 *
 * Használat: node tmp/verify-ios-ipa.mjs [ipa-útvonal] [kibontási könyvtár] [build]
 */
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';

const ipa = process.argv[2] ?? 'build/ios-ipa/Runner-unsigned.ipa';
const outDir = process.argv[3] ?? 'tmp/ipa-check';
const build = Number.parseInt(process.argv[4] ?? '370', 10);

if (!fs.existsSync(ipa)) {
  console.log(`HIBA  nincs ilyen IPA: ${ipa}`);
  process.exit(1);
}

fs.rmSync(outDir, { recursive: true, force: true });
fs.mkdirSync(outDir, { recursive: true });
execFileSync('tar', ['-xf', ipa, '-C', outDir]);

const app = path.join(outDir, 'Payload', 'Runner.app');
const checks = [];
const check = (label, ok, detail = '') => checks.push({ label, ok, detail });

const read = (relative) => {
  const full = path.join(app, relative);
  return fs.existsSync(full) ? fs.readFileSync(full) : Buffer.alloc(0);
};

// ⚠️ MÉRT ESZKÖZ-HIBA (javítva, a 370-es körben): a Dart AOT-snapshot a
// **csak Latin-1 karakterekből** álló szöveget **egy bájtos** alakban tárolja
// (nem UTF-8-ként!), a `—` (U+2014) viszont két bájtos stringet kényszerít ki.
// Ezért a „Javítva: az értesítésben a cikk …" sor keresése **hamis bukást**
// adott (a sor benne volt, csak latin1 alakban). Mindhárom kódolást mérjük.
const contains = (buffer, needle) =>
  buffer.includes(Buffer.from(needle, 'utf8'))
  || buffer.includes(Buffer.from(needle, 'utf16le'))
  || buffer.includes(Buffer.from(needle, 'latin1'));

check('a csomag `Payload/Runner.app`-ot tartalmaz', fs.existsSync(app));

const plist = read('Info.plist');
for (const [label, needle] of [
  ['a verzió 1.0.0', '1.0.0'],
  [`a build-szám ${build}`, String(build)],
  ['a bundle azonosító a miénk', 'hu.hungarianhardstyle.app'],
  ['a háttér-hang engedélyezve (UIBackgroundModes)', 'UIBackgroundModes'],
  ['az ATT-leírás megvan (NSUserTrackingUsageDescription)', 'NSUserTrackingUsageDescription'],
  ['az AdMob iOS app ID be van égetve', 'ca-app-pub-7714662594685378~6550697484'],
]) {
  check(`Info.plist: ${label}`, contains(plist, needle));
}

// A szótár — ez bizonyítja, hogy a mostani (címkéket is fordító) kód van benne.
// ⚠️ MÉRT HELY: iOS-en a Flutter-assets az `App.framework` alatt van (nem a
// `Runner.app` gyökerében), ezért az útvonal `Frameworks/App.framework/...`.
const dictionaryPath = 'Frameworks/App.framework/flutter_assets/assets/i18n/en.json';
const raw = read(dictionaryPath).toString('utf8');
let keys = 0;
let chipKeys = {};
try {
  const dictionary = JSON.parse(raw);
  keys = Object.keys(dictionary).length;
  chipKeys = {
    'Partyajánló': dictionary['Partyajánló'],
    'fesztivál': dictionary['fesztivál'],
    'Zene': dictionary['Zene'],
    'Hírek': dictionary['Hírek'],
    'Kezdő ütem': dictionary['Kezdő ütem'],
    '{n} pont': dictionary['{n} pont'],
    'Közösség': dictionary['Közösség'],
  };
} catch {
  keys = 0;
}
check(`a szótár benne van és teljes (${keys} kulcs)`, keys >= 960, `${dictionaryPath}`);
check(
  'a hírek címke-/kategória-fordításai és az Achievement-nevek is benne vannak',
  chipKeys['Partyajánló'] === 'Party Guide' && chipKeys['fesztivál'] === 'festival'
    && chipKeys['Zene'] === 'Music' && chipKeys['Hírek'] === 'News'
    && chipKeys['Kezdő ütem'] === 'First Beat' && chipKeys['{n} pont'] === '{n} points'
    && chipKeys['Közösség'] === 'Community',
  JSON.stringify(chipKeys),
);

// A changelog a Dart AOT csomagban él (a magyar ékezetek miatt UTF-16LE-ként).
const framework = read('Frameworks/App.framework/App');
check(
  'a 370 sora benne van (az értesítésbe kerülő cikk címe is a választott nyelven)',
  contains(framework, 'az értesítésben a cikk (és a kiadás, esemény, DJ) címe is a választott nyelven jelenik meg'),
);
check(
  'a 370 „már meglévő értesítések" sora is benne van',
  contains(framework, 'A már meglévő értesítéseknél is átfordul a cím'),
);
check(
  'a 369 sora benne van (az értesítések nyelve)',
  contains(framework, 'angol felületen az értesítések szövege azonnal a választott nyelven jelenik meg'),
);
check(
  'a 368 sora benne van (a kiadási jegyzet is angolul)',
  contains(framework, 'a kiadási jegyzet (Névjegy → Újdonságok) is angolul jelenik meg'),
);
check(
  'a 367 sora benne van (a játék-eredmény fejléc angolul)',
  contains(framework, 'a játék eredményei képernyő fejléce'),
);
check(
  'a 367 válasz-előnézet sora is benne van',
  contains(framework, 'a válasz-előnézet is angolul szól'),
);
check(
  'a 365 changelog-sora benne van (a hírlista magától frissül)',
  contains(framework, 'a főoldal és a Hírek fül listája magától frissül'),
);
check(
  'a 366 sora is benne van (a kiadvány-dátum és a „Megjelenései" angolul)',
  contains(framework, 'a kiadványok dátum-címkéje'),
);
check(
  'a 366 nyelvváltás-sora is benne van',
  contains(framework, 'nyelvváltáskor a betöltött tartalom'),
);
check(
  'a 365 „Partyface" sora is benne van',
  contains(framework, 'szerepkör felirata mostantól'),
);
check(
  'a 365 chat-ugrás sora is benne van',
  contains(framework, 'a válasz idézetére koppintva az app ODAUGRLIK'),
);
check(
  'a korábbi (364) changelog-sor is benne van (a címke-fordítás említésével)',
  contains(framework, 'Angol felületen a hírek kategória- és címke-nevei'),
);
// ⚠️ Az `App Check` debug-zászlót szándékosan NEM próbáljuk szövegként keresni:
// a CI a `--dart-define=HUHS_APP_CHECK_DEBUG_IOS=true`-t mindig átadja, a zászló
// hatása viszont a futásidejű szolgáltató-választás (a token a készüléken
// keletkezik), ezért a csomagból nem mérhető megbízhatóan. A helyes mérés a
// készüléken történik (a korábbi körben a napló + a Firebase-konzol igazolta).
check('a futtatható `Runner` bináris megvan', read('Runner').length > 0);

let failed = 0;
for (const entry of checks) {
  if (!entry.ok) failed += 1;
  console.log(`${entry.ok ? 'OK  ' : 'HIBA'} ${entry.label}${entry.detail && !entry.ok ? ` — ${entry.detail}` : ''}`);
}
console.log(
  `\n${checks.length - failed}/${checks.length} ellenőrzés rendben`
  + `\n⚠️ Az Info.plist mérése nyers bájt-keresés (bináris plist), nem strukturált parse.`,
);
process.exitCode = failed ? 1 : 0;
