// A Play-jegyzet FRISSÍTÉSE a 2026-10-02-i MÉRT állapotra.
//
// MIÉRT SZKRPIT: a dokumentum több helyen mondja meg, melyik sávon mi van, és
// ezeket együtt kell átírni — a kézi szerkesztés itt könnyen félben marad.
// A mért forrás: `node tools/check-play-track.mjs` (2026-10-02).
import fs from 'node:fs';

const file = 'docs/PLAY-KIADASI-JEGYZET.md';
const before = fs.readFileSync(file, 'utf8');
let text = before;

/** [mit keresünk (literál), mire cseréljük, hányszor kell előfordulnia] */
const edits = [
  [
    'lastPublishedBuild: 382',
    'lastPublishedBuild: 384',
    1,
  ],
  [
    '> **Mérve** (`node tools/check-play-track.mjs`,\n> 2026-10-01): az **ÉLES (production) sávon a 382 van**, 100%-ban kigördülve; a **zárt teszt (alpha) a\n> 383-on**, a nyílt teszt (beta) a 377-en.',
    '> **Mérve** (`node tools/check-play-track.mjs`,\n> 2026-10-02): az **ÉLES (production) sávon már a 384 van**, 100%-ban kigördülve (a 384 kiadási\n> szövegével); a **zárt teszt (alpha) is a 384-en**, a nyílt teszt (beta) a 377-en.',
    1,
  ],
  [
    '> **Melyik blokk hova való (mérve, 2026-10-01):** az **éles** sávon a **382** van → **1. blokk**;\n> a **zárt teszten a 383** van 100%-ban kigördülve → ott a **383 → 387** lépéshez **ugyanaz az\n> 1. blokk** való (ez a néhány sor mind új a tesztelőknek); aki **361–380 közötti** buildről jön,\n> annak a **361–387 összesítő** (1b-2.); aki a **bétáról (377)**, annak a **355–387** összesítő (1b-3.).',
    '> **Melyik blokk hova való (mérve, 2026-10-02):** az **éles** sávon a **384** van → **1. blokk**\n> (384 → 387); a **zárt teszten is a 384** van 100%-ban kigördülve → **ugyanaz az 1. blokk** való\n> (a rádió-, Twitch- és kártya-újdonságok mind újak a tesztelőknek); aki **361–383 közötti** buildről\n> jön, annak a **361–387 összesítő** (1b-2.); aki a **bétáról (377)**, annak a **355–387** összesítő (1b-3.).',
    1,
  ],
  [
    '> **ÉLES (production) = 382** → ide (382 → 386) **ez a néhány sor** való.\n> **ZÁRT TESZT (alpha) = 383** (100%-ban kigördülve) → ide is **ez a néhány sor** való (383 → 386):\n> a rádió-, Twitch- és kis képernyő-újdonságok mind újak a tesztelőknek.',
    '> **ÉLES (production) = 384** → ide (384 → 387) **ez a néhány sor** való.\n> **ZÁRT TESZT (alpha) = 384** (100%-ban kigördülve) → ide is **ez a néhány sor** való (384 → 387):\n> a rádió-, Twitch-, kis képernyő- és kártya-újdonságok mind újak a tesztelőknek.',
    1,
  ],
  [
    '⏳ **A következő plugin-feltöltés: `build/huhs-mobile-api-2.14.14.zip`** — a 2.14.13-hoz képest\n**egyetlen érték** változott: a push kör-kerete **15 → 60 másodperc** (a mért `max_exec=600` alatt),\nezért a ~1025 eszköz egyetlen körben megy ki a több láncszem helyett. A 2.14.13 már fent van\n(`api=2.14.13`), a 2.14.14 **feltöltésre vár**.',
    '✅ **A WordPress-plugin 2.14.14 FENT VAN** (élesben mérve, 2026-10-02: `api=2.14.14`, és a fejléc\nmár az új keretet mutatja: **`push_limits=conc50/budget60/max_exec600`**, 1027 token) — a hír-push\nkör-kerete **15 → 60 másodperc**, ezért a ~1025 eszköz egyetlen körben megy ki a több láncszem helyett.\nA gyorsulás **mértéke** a következő valódi küldésnél látszik (a legutóbbi, 14:28-as kör még a régi\nkerettel futott: `recipients=1025 processed=75`).',
    1,
  ],
];

let failed = 0;
for (const [from, to, expected] of edits) {
  const count = text.split(from).length - 1;
  if (count !== expected) {
    console.log(`HIBA  a minta ${count}× szerepel (várt: ${expected}) — ${from.slice(0, 60)}…`);
    failed += 1;
    continue;
  }
  text = text.split(from).join(to);
  console.log(`OK    csere (${count}×): ${from.slice(0, 60).replace(/\n/g, ' ')}…`);
}

if (!failed) fs.writeFileSync(file, text, 'utf8');
console.log(failed ? `\nHIBA — ${failed} csere nem illeszkedett (a fájl VÁLTOZATLAN)` : `\nMINDEN CSERE RENDBEN (${before !== text ? 'a fájl frissült' : 'nem volt változás'})`);
process.exitCode = failed ? 1 : 0;
