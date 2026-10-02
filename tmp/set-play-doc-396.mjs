// A Play-jegyzet 396-ra állítása: minden 395-ös hivatkozás, ami a KIADÁSRA vonatkozik.
import fs from 'node:fs';

const file = 'docs/PLAY-KIADASI-JEGYZET.md';
let source = fs.readFileSync(file, 'utf8');
const before = source;

const pairs = [
  ['(versionCode **395**, `1.0.0`) — a 389-hez képest:', '(versionCode **396**, `1.0.0`) — a 389-hez képest:'],
  ['a **zárt tesztre** (389 → 395) az **1. blokk** (és a\n> `tmp/play-395-zart.txt`); az **ÉLES** sávra (384 → 395) a **2b. blokk** (`tmp/play-395-eles.txt`);\n> a **bétára** (377) a **355–395** összesítő (1b-3.) való.\n> ⚠️ **A 385–394-et NE tárd fel újra** — a 395 mindegyiket tartalmazza.',
   'a **zárt tesztre** (389 → 396) az **1. blokk** (és a\n> `tmp/play-396-zart.txt`); az **ÉLES** sávra (384 → 396) a **2b. blokk** (`tmp/play-396-eles.txt`);\n> a **bétára** (377) a **355–396** összesítő (1b-3.) való.\n> ⚠️ **A 385–395-et NE tárd fel újra** — a 396 mindegyiket tartalmazza.'],
  ['| `build/HUHS-v1.0.0+395-release.aab` |', '| `build/HUHS-v1.0.0+396-release.aab` |'],
  ['| **395** (a merge-elt release manifestből visszaolvasva) |', '| **396** (a merge-elt release manifestből visszaolvasva) |'],
  ['> **⚠️ A 395 a feltöltendő csomag** (versionCode **395**, `1.0.0`)', '> **⚠️ A 396 a feltöltendő csomag** (versionCode **396**, `1.0.0`)'],
  ['a 395-nél kisebb kódú csomagot a', 'a 396-nál kisebb kódú csomagot a'],
  ['**A 390–394-et nem kell feltölteni** (a 395 mindegyiket tartalmazza).', '**A 390–395-öt nem kell feltölteni** (a 396 mindegyiket tartalmazza).'],
  ['a 395 azokat is tartalmazza) — a 395 újdonságai', 'a 396 azokat is tartalmazza) — a 396 újdonságai'],
  ['## 1b-2. Play Console — a **361–395** összesítő', '## 1b-2. Play Console — a **361–396** összesítő'],
  ['## 1b-3. Play Console — a **BÉTA** sávhoz (**355–395** összesítő)', '## 1b-3. Play Console — a **BÉTA** sávhoz (**355–396** összesítő)'],
  ['amelyek a **361–395** között készültek', 'amelyek a **361–396** között készültek'],
  ['**Ezt használd, ha a 395-öt a béta', '**Ezt használd, ha a 396-ot a béta'],
];

let applied = 0;
for (const [from, to] of pairs) {
  if (source.includes(from)) {
    source = source.split(from).join(to);
    applied += 1;
  } else {
    console.log(`NEM található: ${from.slice(0, 60)}…`);
  }
}
fs.writeFileSync(file, source, 'utf8');
console.log(`alkalmazva: ${applied}/${pairs.length}, változott: ${source !== before}`);
