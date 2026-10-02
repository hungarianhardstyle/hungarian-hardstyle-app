// A Play-másolatok **bájtazonosságának** mérése a dokumentum blokkjaival.
//
// MIÉRT: a tulajdonos a `tmp/play-*.txt` fájlokból másol a Play Console-ra, ezért
// a másolatnak **bájtra** egyeznie kell a dokumentumban lévő blokkal — a „hasonló”
// szöveg itt kevés.
//
// Használat: node tmp/check-play-copy.mjs tmp/play-393-eles.txt
import fs from 'node:fs';

const file = process.argv[2];
if (!file) {
  console.log('Használat: node tmp/check-play-copy.mjs <masolat.txt>');
  process.exit(2);
}
const doc = fs.readFileSync('docs/PLAY-KIADASI-JEGYZET.md', 'utf8').replace(/\r\n/g, '\n');
const blocks = [...doc.matchAll(/```play-notes\n([\s\S]*?)```/g)].map((m) => m[1].trimEnd());
const copy = fs.readFileSync(file, 'utf8').replace(/\r\n/g, '\n').trimEnd();

const index = blocks.findIndex((block) => block === copy);
if (index >= 0) {
  console.log(`OK   ${file} = a dokumentum ${index + 1}. blokkja (${copy.length} karakter)`);
  // Hány másolat egyezik összesen? (mindig a dokumentum `currentBuild`-jére)
  const build = (doc.match(/^currentBuild:\s*(\d+)/m) ?? [])[1] ?? '';
  const copies = fs
    .readdirSync('tmp')
    .filter((name) => /^play-.*\.txt$/.test(name) && build !== '' && name.includes(build));
  let same = 0;
  for (const name of copies) {
    const text = fs.readFileSync(`tmp/${name}`, 'utf8').replace(/\r\n/g, '\n').trimEnd();
    if (blocks.includes(text)) same += 1;
  }
  console.log(`a ${build}-es másolatokból ${same}/${copies.length} egyezik a dokumentummal`);
  process.exit(0);
}

console.log(`HIBA a(z) ${file} NEM egyezik egyetlen dokumentum-blokkal sem`);
const closest = blocks
  .map((block, i) => ({ i, distance: Math.abs(block.length - copy.length) }))
  .sort((a, b) => a.distance - b.distance)[0];
console.log(`  a legközelebbi blokk a ${closest.i + 1}. (hossz-elérés: ${closest.distance} karakter)`);
process.exit(1);
