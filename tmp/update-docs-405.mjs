#!/usr/bin/env node
/**
 * A kiadási jegyzet 405-re állítása (a PowerShell kódolása elrontja az ékezetes
 * cseréket, ezért ez a fájl UTF-8-ban, Node-dal dolgozik).
 *
 * Futás: node tmp/update-docs-405.mjs
 */
import fs from 'node:fs';

const file = 'docs/PLAY-KIADASI-JEGYZET.md';
const SIZE = '83 618 745 bájt';
const SHA = '519D61256A521CBF44962715714729BD6CE7B09669587E885350B96B18E404B6';
const AAB = 'build/HUHS-v1.0.0+405-release.aab';

let text = fs.readFileSync(file, 'utf8');
const before = text;

const pairs = [
  ['| A 404-es Android-csomag | Ellenőrzött érték |', '| A 405-ös Android-csomag | Ellenőrzött érték |'],
  ['| Fájl | `build/HUHS-v1.0.0+404-release.aab` |', `| Fájl | \`${AAB}\` |`],
  ['| Verzió | `1.0.0+404` — a csomag saját manifestjéből visszaolvasva |', '| Verzió | `1.0.0+405` — a csomag saját manifestjéből visszaolvasva |'],
  ['| Méret | 83 621 334 bájt |', `| Méret | ${SIZE} |`],
  ['| SHA-256 | `5C73EF5EB8C989EA25ECF9A4557C7EB14183C2A437E66D2D9A6884817CBB9545` |', `| SHA-256 | \`${SHA}\` |`],
  ['aab: build/HUHS-v1.0.0+404-release.aab', `aab: ${AAB}`],
  ['sha256: 5C73EF5EB8C989EA25ECF9A4557C7EB14183C2A437E66D2D9A6884817CBB9545', `sha256: ${SHA}`],
  ['1568/1568 Flutter-teszt sikeres', '1573/1573 Flutter-teszt sikeres'],
  ['Biztonsági kiadás az eMudhra-tanúsítványokkal kapcsolatos Firebase/Dart javítással.',
    'A főoldali kiemelt hír képe: nem nagyít rá az arcokra, a fotó teljes egészében látszik.'],
];

const applied = [];
for (const [from, to] of pairs) {
  if (!text.includes(from)) {
    applied.push(`NEM TALÁLTA: ${from.slice(0, 60)}`);
    continue;
  }
  text = text.replace(from, to);
  applied.push(`OK: ${to.slice(0, 60)}`);
}

if (text !== before) fs.writeFileSync(file, text, 'utf8');
console.log(applied.join('\n'));
