// Az ÉLES sávhoz tartozó Play-szöveg kiírása (`tmp/play-<build>-eles.txt`).
//
// MIÉRT külön: a `write-play-copies.mjs` a dokumentum első, 3., 4. és 6. blokkját
// írja (1. blokk, két összesítő, zárt teszt) — az ÉLES sávhoz tartozó **2b.**
// blokk (a 8.) külön másolat, és a tulajdonos ezt másolja a Playre.
//
// Használat: node tmp/write-play-eles-copy.mjs
import fs from 'node:fs';

const doc = fs.readFileSync('docs/PLAY-KIADASI-JEGYZET.md', 'utf8').replace(/\r\n/g, '\n');
const build = (doc.match(/^currentBuild:\s*(\d+)\s*$/m) ?? [])[1];
if (!build) {
  console.log('HIBA  nincs `currentBuild` a meta fejlécben');
  process.exit(1);
}
const blocks = [...doc.matchAll(/```play-notes\n([\s\S]*?)```/g)].map((match) => match[1].trimEnd());
if (blocks.length < 8) {
  console.log(`HIBA  nincs 2b. blokk (a blokkok száma: ${blocks.length})`);
  process.exit(1);
}
const target = `tmp/play-${build}-eles.txt`;
fs.writeFileSync(target, `${blocks[7]}\n`, 'utf8');
console.log(`OK   ${target} = a 2b. blokk (${blocks[7].length} karakter)`);
