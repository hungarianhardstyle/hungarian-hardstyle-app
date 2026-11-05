#!/usr/bin/env node
/**
 * A 406-os bejegyzés az AGENTS.md elejére (a PowerShell/node -e elrontja az
 * ékezetes, idézőjeles szöveget, ezért ez a fájl UTF-8-ban dolgozik).
 *
 * Futás: node tmp/update-agents-406.mjs
 */
import fs from 'node:fs';

const file = 'AGENTS.md';
let text = fs.readFileSync(file, 'utf8');
if (text.includes('A **406**-OS BUILD')) {
  console.log('már benne van');
  process.exit(0);
}

const entry = `# Hungarian Hardstyle App - Project Context for AI Agents

### 🟡 A **406**-OS BUILD — AZ ÁSZF ÉS AZ ADATKEZELÉS A NÉVJEGY ALATT (MÉRVE, 2026-11-05)

- **A TULAJDONOS KÉRDÉSE:** *„hol az app ÁSZF linkje?”*
- **A MÉRT HELYZET:** mindkét jogi oldal **él** a WordPressben (HTTP 200): \`/altalanos-szerzodesi-feltetelek-aszf/\` és \`/adatvedelmi-nyilatkozat/\` — de az appban **egyetlen hivatkozás sem** volt rájuk. A Play/App Store és az előfizetés is megköveteli, hogy a feltételek elérhetők legyenek.
- **A JAVÍTÁS:** \`lib/core/legal/legal_links.dart\` (egy forrás) + két sor a **Névjegy** alatt, a beépített böngészővel (\`openInAppBrowser\`).
- **A MÉRÉS:** \`test/widgets/about_legal_links_test.dart\` **2/2** (a két URL pontos egyezése + a feliratok/címek megjelenése), \`flutter test\` **1575/1575**, AAB **1.0.0+406** = 83 623 165 bájt, SHA-256 \`645B92DE431BDACA12C64CFEDBAC636045D06B3894DFB6C57909CA0FB072FA4E\`, \`tmp/verify-aab.mjs\` → **MINDEN ELLENŐRZÉS RENDBEN**; \`node tools/check-play-notes.mjs\` zöld (\`currentBuild=406\`).
- **⚠️ ŐSZINTE KORLÁT:** a link megnyitását a telefonon kell látni; az ÁSZF **tartalmáért** a WordPress-oldal felelős, innentől viszont elérhető az appból is.
- **📌 A TULAJDONOS LÉPÉSE:** a **406** feltöltése (Play zárt teszt), és a Play Console-ban az „Adatvédelmi irányelv" mezőben a fenti adatvédelmi URL szerepeljen.

`;

text = text.replace('# Hungarian Hardstyle App - Project Context for AI Agents\n', entry);
fs.writeFileSync(file, text, 'utf8');
console.log('AGENTS.md frissítve (406)');
