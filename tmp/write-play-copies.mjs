import fs from 'node:fs';

const doc = fs.readFileSync('docs/PLAY-KIADASI-JEGYZET.md', 'utf8');
const blocks = [...doc.matchAll(/```play-notes\r?\n([\s\S]*?)```/g)].map((m) =>
  m[1].replace(/\r\n/g, '\n').trimEnd(),
);

// A blokkokat kiírjuk UTF-8 fájlokba (a PowerShell-átirányítás UTF-16-ot adna).
const targets = [
  ['tmp/play-376.txt', 0],
  ['tmp/play-361-376.txt', 2],
  ['tmp/play-355-376.txt', 3],
];
for (const [file, index] of targets) {
  fs.writeFileSync(file, `${blocks[index]}\n`, 'utf8');
}

let bad = 0;
for (const [file, index] of targets) {
  const content = fs.readFileSync(file, 'utf8').replace(/\r\n/g, '\n').trimEnd();
  const same = content === blocks[index];
  if (!same) bad += 1;
  console.log(`${same ? 'OK  ' : 'ELTER'} ${file} = ${index + 1}. blokk (${content.length} karakter)`);
}
console.log(`\n${targets.length - bad}/${targets.length} másolat egyezik a dokumentummal`);
process.exitCode = bad ? 1 : 0;
