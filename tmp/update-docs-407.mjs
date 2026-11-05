#!/usr/bin/env node
/**
 * A 407-es build (a kiemelt hír képének visszaállítása) beírása a kiadási jegyzetbe.
 *
 * Futás: node tmp/update-docs-407.mjs
 */
import fs from 'node:fs';

const file = 'docs/PLAY-KIADASI-JEGYZET.md';
const SIZE = '83 624 058 bájt';
const SHA = '8F96C144CD36341F25F5E01D90B75906D461431CAC7E2D5FD85DB6AADF65714F';
const AAB = 'build/HUHS-v1.0.0+407-release.aab';

let text = fs.readFileSync(file, 'utf8');
const before = text;
const applied = [];

const pairs = [
  ['## Aktuális kiadás: **406** (1.0.0), 2026-11-05', '## Aktuális kiadás: **407** (1.0.0), 2026-11-05'],
  ['A Névjegy alatt elérhető a Felhasználási feltételek (ÁSZF) és az Adatkezelési tájékoztató; a főoldali kiemelt hír képe nem nagyít rá az arcokra.',
    'A Kezdőlapon a kiemelt hír képe visszakapta a korábbi kinézetet; a Névjegy alatt elérhető a Felhasználási feltételek (ÁSZF) és az Adatkezelési tájékoztató.'],
  ['| A 406-os Android-csomag | Ellenőrzött érték |', '| A 407-es Android-csomag | Ellenőrzött érték |'],
  ['| Fájl | `build/HUHS-v1.0.0+406-release.aab` |', `| Fájl | \`${AAB}\` |`],
  ['| Verzió | `1.0.0+406` — a csomag saját manifestjéből visszaolvasva |', '| Verzió | `1.0.0+407` — a csomag saját manifestjéből visszaolvasva |'],
  ['| Méret | 83 623 165 bájt |', `| Méret | ${SIZE} |`],
  ['| SHA-256 | `645B92DE431BDACA12C64CFEDBAC636045D06B3894DFB6C57909CA0FB072FA4E` |', `| SHA-256 | \`${SHA}\` |`],
  ['1575/1575 Flutter-teszt sikeres', '1574/1574 Flutter-teszt sikeres'],
  ['aab: build/HUHS-v1.0.0+406-release.aab', `aab: ${AAB}`],
  ['sha256: 645B92DE431BDACA12C64CFEDBAC636045D06B3894DFB6C57909CA0FB072FA4E', `sha256: ${SHA}`],
  ['currentBuild: 406', 'currentBuild: 407'],
  ['## 2c. A **406**-os kiadás changelogja — mindhárom helyre (másolható)',
    '## 2c. A **407**-es kiadás changelogja — mindhárom helyre (másolható)'],
];

for (const [from, to] of pairs) {
  if (!text.includes(from)) {
    applied.push(`NEM TALÁLTA: ${from.slice(0, 50)}`);
    continue;
  }
  text = text.replace(from, to);
  applied.push('OK');
}

const anchor = '**Play Console → „Újdonságok" (406, magyar, 500 karakter alatt):**';
const block = [
  '**Play Console → „Újdonságok" (407, magyar, 500 karakter alatt):**',
  '',
  '```',
  '- Visszaállítottuk a Kezdőlapon a kiemelt hír képét a korábbi kinézetre.',
  '```',
  '',
  '**Play Console → „Újdonságok" (407, angol):**',
  '',
  '```',
  '- Restored the previous look of the featured news photo on the Home screen.',
  '```',
  '',
  anchor,
].join('\n');
if (text.includes(anchor) && !text.includes('(407, magyar')) {
  text = text.replace(anchor, block);
  applied.push('407-es Play-blokk OK');
}

const buildAnchor = '### 406 — a Felhasználási feltételek (ÁSZF) és az Adatkezelési tájékoztató a Névjegy alatt';
const section = [
  '### 407 — a kiemelt hír képe visszaállt a RÉGI kinézetre (a tulajdonos döntése)',
  '- **A tulajdonos jelzése (2026-11-05):** *„ne hari de így az app főoldal cikk kép kurvaszar, inkább legyen a régi vissza”* — a 405-ben bevezetett elmosott háttér + `contain` **nem tetszett**.',
  '- **A JAVÍTÁS:** a `FeaturedNewsImageBand` kikerült; a kártya ismét a régi, egyszerű `BoxFit.cover`-t használja (a `dart:ui` blur import is törölve). A kártya mérete és szerkezete (kép balra 5/12, szöveg jobbra 7/12) **változatlan**.',
  '- **A kapu mérése:** `test/widgets/featured_card_image_test.dart` **4/4** — a kártya `cover`-t használ, **nincs** `ImageFiltered`/`contain`/`FeaturedNewsImageBand`, és a geometria továbbra is dokumentálva van (149×250 px sávban a kép **31%-a** látszik — tudatos döntés). `flutter test` **1574/1574**, `flutter analyze` **0 hiba**.',
  '- **A jogi link is a valóban publikált oldalra mutat:** `lib/core/legal/legal_links.dart` → `https://hungarianhardstyle.hu/app-felhasznalasi-feltetelek/` (a tulajdonos által publikált, app-specifikus ÁSZF; HTTP 200, publikált oldal).',
  '- **Csomag:** AAB **1.0.0+407** (' + SIZE + ', SHA-256 `' + SHA + '`), `tmp/verify-aab.mjs` → **MINDEN ELLENŐRZÉS RENDBEN**.',
  '- **⚠️ Őszinte korlát:** a vizuális ítélet a tulajdonosé; a 405-ös elmosott háttér **nem** kerül vissza, hacsak nem kéri.',
  '',
  buildAnchor,
].join('\n');
if (text.includes(buildAnchor) && !text.includes('### 407 —')) {
  text = text.replace(buildAnchor, section);
  applied.push('### 407 fejezet OK');
}

if (text !== before) fs.writeFileSync(file, text, 'utf8');
console.log(applied.join('\n'));
