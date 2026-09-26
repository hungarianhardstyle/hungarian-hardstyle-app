import fs from 'node:fs';

const doc = fs.readFileSync('docs/PLAY-KIADASI-JEGYZET.md', 'utf8');
const blocks = [...doc.matchAll(/```play-notes\r?\n([\s\S]*?)```/g)].map((m) =>
  m[1].replace(/\r\n/g, '\n').trimEnd(),
);
const pairs = [
  ['tmp/play-374.txt', 0],
  ['tmp/play-361-374.txt', 2],
  ['tmp/play-355-374.txt', 3],
];
let bad = 0;
for (const [file, index] of pairs) {
  const content = fs.readFileSync(file, 'utf8').replace(/\r\n/g, '\n').trimEnd();
  const same = content === blocks[index];
  if (!same) bad += 1;
  console.log(`${same ? 'OK  ' : 'ELTER'} ${file} = ${index + 1}. blokk (${content.length} karakter)`);
}
console.log(`\n${pairs.length - bad}/${pairs.length} másolat egyezik a dokumentummal`);
process.exitCode = bad ? 1 : 0;
