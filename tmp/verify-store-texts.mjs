// A javasolt áruházi szövegek karakter-száma (a Play korlátaihoz mérve).
// A dokumentum blokkjai: 1) a MOSTANI rövid leírás, 2) a JAVASOLT rövid, 3) a JAVASOLT hosszú.
import fs from 'node:fs';

const doc = fs.readFileSync('docs/PLAY-ARUHAZ-LISTA-SZOVEGEK.md', 'utf8');
const blocks = [...doc.matchAll(/```\n([\s\S]*?)```/g)].map((m) => m[1].replace(/\n$/, ''));
const expectations = [
  { label: 'mostani rövid leírás', limit: 80 },
  { label: 'javasolt rövid leírás', limit: 80 },
  { label: 'javasolt hosszú leírás', limit: 4000 },
];
let failures = 0;
blocks.forEach((text, index) => {
  const rule = expectations[index];
  const length = [...text].length;
  const ok = !rule || length <= rule.limit;
  if (!ok) failures += 1;
  console.log(
    `${ok ? 'OK  ' : 'HIBA'} ${rule ? rule.label : `blokk #${index + 1}`}: ${length} karakter` +
      (rule ? ` (korlát ${rule.limit})` : ''),
  );
});
console.log(`\n${blocks.length - failures}/${blocks.length} szöveg belefér a Play korlátaiba`);
process.exitCode = failures ? 1 : 0;
