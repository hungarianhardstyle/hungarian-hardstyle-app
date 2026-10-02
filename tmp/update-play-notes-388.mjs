// A Play-jegyzet átállítása a 388-as buildre (mért értékekkel).
import fs from 'node:fs';

const file = 'docs/PLAY-KIADASI-JEGYZET.md';
const before = fs.readFileSync(file, 'utf8');
let text = before;

const edits = [
  ['currentBuild: 387', 'currentBuild: 388', 1],
  ['aab: build/HUHS-v1.0.0+387-release.aab', 'aab: build/HUHS-v1.0.0+388-release.aab', 1],
  [
    'sha256: 8FF303D82BDFD10263725372CCA3A4DE8181CB4D355357A9EF725900583FAE02',
    'sha256: 31C5CA3F17190D253788E8178D8923A841FD1EDDB036CA859887EFF6C5081E90',
    1,
  ],
  [
    '| Fájl | `build/HUHS-v1.0.0+387-release.aab` |',
    '| Fájl | `build/HUHS-v1.0.0+388-release.aab` |',
    1,
  ],
  [
    '| Verziókód | **387** (a merge-elt release manifestből visszaolvasva) |',
    '| Verziókód | **388** (a merge-elt release manifestből visszaolvasva) |',
    1,
  ],
  [
    '| Méret | 83 413 848 bájt (79,5 MiB)',
    '| Méret | 83 416 226 bájt (79,6 MiB)',
    1,
  ],
  [
    '| SHA-256 | `8FF303D82BDFD10263725372CCA3A4DE8181CB4D355357A9EF725900583FAE02` |',
    '| SHA-256 | `31C5CA3F17190D253788E8178D8923A841FD1EDDB036CA859887EFF6C5081E90` |',
    1,
  ],
  [
    '**⚠️ A 387 a feltöltendő csomag** (versionCode **387**, `1.0.0`)',
    '**⚠️ A 388 a feltöltendő csomag** (versionCode **388**, `1.0.0`)',
    1,
  ],
  ['a 387-nél kisebb kódú csomagot a Play', 'a 388-nál kisebb kódú csomagot a Play', 1],
  ['a 387 a 382 minden javítását', 'a 388 a 382 minden javítását', 1],
];

let failed = 0;
for (const [from, to, expected] of edits) {
  const count = text.split(from).length - 1;
  if (count !== expected) {
    console.log(`HIBA  a minta ${count}× szerepel (várt: ${expected}) — ${from.slice(0, 60)}`);
    failed += 1;
    continue;
  }
  text = text.split(from).join(to);
  console.log(`OK    ${from.slice(0, 60).replace(/\n/g, ' ')}…`);
}
if (!failed) fs.writeFileSync(file, text, 'utf8');
console.log(failed ? `\nHIBA — ${failed} csere nem illeszkedett` : '\nMINDEN CSERE RENDBEN');
process.exitCode = failed ? 1 : 0;
