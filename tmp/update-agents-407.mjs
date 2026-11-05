#!/usr/bin/env node
/**
 * A 407-es bejegyzés az AGENTS.md elejére (a kép visszaállítása).
 *
 * Futás: node tmp/update-agents-407.mjs
 */
import fs from 'node:fs';

const file = 'AGENTS.md';
let text = fs.readFileSync(file, 'utf8');
if (text.includes('A **407**-ES BUILD')) {
  console.log('már benne van');
  process.exit(0);
}

const entry = `# Hungarian Hardstyle App - Project Context for AI Agents

### 🟡 A **407**-ES BUILD — A KIEMELT HÍR KÉPE VISSZAÁLLT A RÉGI KINÉZETRE (2026-11-05)

- **A TULAJDONOS JELZÉSE:** *„ne hari de így az app főoldal cikk kép kurvaszar, inkább legyen a régi vissza”* — a **405**-ben bevezetett elmosott háttér + \`contain\` **nem tetszett**.
- **A JAVÍTÁS:** a \`FeaturedNewsImageBand\` **kikerült** a \`lib/widgets/featured_news_card.dart\`-ból (a \`dart:ui\` importtal együtt); a kártya ismét a régi, egyszerű **\`BoxFit.cover\`**. A kártya mérete és szerkezete (kép balra 5/12, szöveg jobbra 7/12) változatlan.
- **A MÉRÉS:** \`test/widgets/featured_card_image_test.dart\` **4/4** — \`cover\` van, és **nincs** \`ImageFiltered\` / \`BoxFit.contain\` / \`FeaturedNewsImageBand\` (ha valaki visszahozná, a kapu pirosra vált); a geometria dokumentálva: 149×250 px sávban a kép **31%-a** látszik. \`flutter test\` **1574/1574**, \`flutter analyze\` **0 hiba**, AAB **1.0.0+407** = 83 624 058 bájt, SHA-256 \`8F96C144CD36341F25F5E01D90B75906D461431CAC7E2D5FD85DB6AADF65714F\`, \`tmp/verify-aab.mjs\` → **MINDEN ELLENŐRZÉS RENDBEN**; \`check-play-notes.mjs\` zöld (\`currentBuild=407\`).
- **A jogi link is a valóban publikált oldalra mutat:** \`lib/core/legal/legal_links.dart\` → \`https://hungarianhardstyle.hu/app-felhasznalasi-feltetelek/\` (a Play „kereskedői állapot" mezőjébe való URL is ez).
- **📌 A TULAJDONOS LÉPÉSE:** a **407** feltöltése (Play zárt teszt), ha a régi képkinézetet akarja a telefonon.
- **⚠️ TANULSÁG A KÖVETKEZŐ KÖRÖKRE:** az app vizuális változtatását **előbb** kell egyeztetni (kép/screenshot), mert a build-visszaállítás külön kört és külön csomagot jelent.

`;

text = text.replace('# Hungarian Hardstyle App - Project Context for AI Agents\n', entry);
fs.writeFileSync(file, text, 'utf8');
console.log('AGENTS.md frissítve (407)');
