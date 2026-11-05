#!/usr/bin/env node
/**
 * A 406-os build beírása a kiadási jegyzetbe (jogi linkek a Névjegy alatt).
 *
 * Futás: node tmp/update-docs-406.mjs
 */
import fs from 'node:fs';

const file = 'docs/PLAY-KIADASI-JEGYZET.md';
const SIZE = '83 623 165 bájt';
const SHA = '645B92DE431BDACA12C64CFEDBAC636045D06B3894DFB6C57909CA0FB072FA4E';
const AAB = 'build/HUHS-v1.0.0+406-release.aab';

let text = fs.readFileSync(file, 'utf8');
const before = text;

const pairs = [
  ['## Aktuális kiadás: **405** (1.0.0), 2026-11-05', '## Aktuális kiadás: **406** (1.0.0), 2026-11-05'],
  ['A főoldali kiemelt hír képe: nem nagyít rá az arcokra, a fotó teljes egészében látszik.',
    'A Névjegy alatt elérhető a Felhasználási feltételek (ÁSZF) és az Adatkezelési tájékoztató; a főoldali kiemelt hír képe nem nagyít rá az arcokra.'],
  ['| A 405-ös Android-csomag | Ellenőrzött érték |', '| A 406-os Android-csomag | Ellenőrzött érték |'],
  ['| Fájl | `build/HUHS-v1.0.0+405-release.aab` |', `| Fájl | \`${AAB}\` |`],
  ['| Verzió | `1.0.0+405` — a csomag saját manifestjéből visszaolvasva |', '| Verzió | `1.0.0+406` — a csomag saját manifestjéből visszaolvasva |'],
  ['| Méret | 83 618 745 bájt |', `| Méret | ${SIZE} |`],
  ['| SHA-256 | `519D61256A521CBF44962715714729BD6CE7B09669587E885350B96B18E404B6` |', `| SHA-256 | \`${SHA}\` |`],
  ['1573/1573 Flutter-teszt sikeres', '1575/1575 Flutter-teszt sikeres'],
  ['aab: build/HUHS-v1.0.0+405-release.aab', `aab: ${AAB}`],
  ['sha256: 519D61256A521CBF44962715714729BD6CE7B09669587E885350B96B18E404B6', `sha256: ${SHA}`],
  ['currentBuild: 405', 'currentBuild: 406'],
  ['## 2c. A **405**-ös kiadás changelogja — mindhárom helyre (másolható)',
    '## 2c. A **406**-os kiadás changelogja — mindhárom helyre (másolható)'],
];

const applied = [];
for (const [from, to] of pairs) {
  if (!text.includes(from)) {
    applied.push(`NEM TALÁLTA: ${from.slice(0, 56)}`);
    continue;
  }
  text = text.replace(from, to);
  applied.push(`OK: ${to.slice(0, 56)}`);
}

// A 406-os Play-blokk a 405-ös blokk elé (a régi blokk megmarad archívumnak).
const anchor = '**Play Console → „Újdonságok" (405, magyar, 500 karakter alatt):**';
const block406 = [
  '**Play Console → „Újdonságok" (406, magyar, 500 karakter alatt):**',
  '',
  '```',
  '- ÚJ: a Névjegy alatt elérhető a Felhasználási feltételek (ÁSZF) és az Adatkezelési tájékoztató.',
  '```',
  '',
  '**Play Console → „Újdonságok" (406, angol):**',
  '',
  '```',
  '- NEW: Terms of Service and the Privacy policy are now linked from the About screen.',
  '```',
  '',
  anchor,
].join('\n');
if (text.includes(anchor) && !text.includes('(406, magyar')) {
  text = text.replace(anchor, block406);
  applied.push('OK: 406-os Play-blokk beszúrva');
}

// A per-build fejezet (### 406) a ### 405 elé.
const buildAnchor = '### 405 — a főoldali kiemelt hír képe nem nagyít rá az arcokra (app) + mobil web';
const buildSection = [
  '### 406 — a Felhasználási feltételek (ÁSZF) és az Adatkezelési tájékoztató a Névjegy alatt',
  '- **A tulajdonos kérdése (2026-11-05):** *„hol az app ÁSZF linkje?”*',
  '- **A MÉRT HELYZET:** a két jogi oldal **él** a WordPressben (HTTP 200):',
  '  `https://hungarianhardstyle.hu/altalanos-szerzodesi-feltetelek-aszf/` és',
  '  `https://hungarianhardstyle.hu/adatvedelmi-nyilatkozat/` — de az appban **egyetlen hivatkozás sem** volt rájuk (a kódban nincs nyomuk).',
  '- **A JAVÍTÁS:** `lib/core/legal/legal_links.dart` (egy forrás) + két sor a **Névjegy** alatt, a beépített böngészővel (`openInAppBrowser`).',
  '- **A kapu mérése:** `test/widgets/about_legal_links_test.dart` **2/2** (a két URL pontos egyezése + a feliratok és címek megjelenése), `flutter test` **1575/1575**, AAB **1.0.0+406** (' + SIZE + ', SHA-256 `' + SHA + '`).',
  '- **⚠️ Őszinte korlát:** a link megnyitását a telefonon kell látni; az oldalak tartalmáért (ÁSZF szövege) a WordPress a felelős — a link innentől elérhető.',
  '',
  buildAnchor,
].join('\n');
if (text.includes(buildAnchor) && !text.includes('### 406 —')) {
  text = text.replace(buildAnchor, buildSection);
  applied.push('OK: ### 406 fejezet beszúrva');
}

if (text !== before) fs.writeFileSync(file, text, 'utf8');
console.log(applied.join('\n'));
