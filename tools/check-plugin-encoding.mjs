#!/usr/bin/env node
/*
 * A WordPress-plugin forrasanak KODOLAS-ELLENORZESE.
 *
 * MIERT KELL: a plugin fajljai UTF-8-at varnak. Ha egy fajlba ANSI/CP1250
 * bajtok kerulnek (ez pontosan megtortent: a `faq.php` docblockjaban negy
 * bajt — 0x97 helyett „—", 0x84 helyett „„"), akkor
 *   - a WordPress plugin-szerkesztoje es a bongeszo mojibake-et mutat,
 *   - egy `strlen()`/`substr()` alapu kod nem azt meri, amit hisz,
 *   - es a hiba CSENDBEN megy at minden mas ellenorzesen.
 *
 * Ez a kapu ezt fogja meg, meg a csomagolas ELOTT.
 *
 * Futtatas: node tools/check-plugin-encoding.mjs [plugin-forras-mappa]
 */

import fs from 'node:fs';
import path from 'node:path';

function resolveSourceDir() {
  const explicit = process.argv[2];
  if (explicit) return explicit;
  const candidates = fs
    .readdirSync('.')
    .filter((name) => /^\.tmp-api-/.test(name))
    .map((name) => path.join(name, 'huhs-mobile-api'))
    .filter((candidate) => fs.existsSync(candidate))
    .map((candidate) => ({ candidate, mtime: fs.statSync(candidate).mtimeMs }))
    .sort((a, b) => b.mtime - a.mtime);
  if (!candidates.length) {
    console.error('HIBA  nem talalok .tmp-api-*/huhs-mobile-api munkafat');
    process.exit(2);
  }
  return candidates[0].candidate;
}

const sourceDir = resolveSourceDir();
const SCAN_EXT = new Set(['.php', '.js', '.css', '.json', '.txt', '.md']);

/** Az UTF-8 szigorú dekódolasa: hibás bajt esetén a pozíciót adja vissza. */
function invalidBytePositions(buffer) {
  const bad = [];
  for (let i = 0; i < buffer.length; i++) {
    const c = buffer[i];
    if (c < 0x80) continue;
    const len = c >= 0xf0 ? 4 : c >= 0xe0 ? 3 : c >= 0xc0 ? 2 : 0;
    if (len === 0) {
      bad.push(i);
      continue;
    }
    let ok = true;
    for (let j = 1; j < len; j++) {
      const cont = buffer[i + j];
      if (cont === undefined || cont < 0x80 || cont > 0xbf) {
        ok = false;
        break;
      }
    }
    if (ok) {
      i += len - 1;
    } else {
      bad.push(i);
    }
  }
  return bad;
}

const files = [];
const walk = (entry) => {
  const stat = fs.statSync(entry);
  if (stat.isDirectory()) {
    for (const child of fs.readdirSync(entry)) walk(path.join(entry, child));
    return;
  }
  if (SCAN_EXT.has(path.extname(entry).toLowerCase())) files.push(entry);
};
walk(sourceDir);

let failures = 0;
let checked = 0;
for (const file of files) {
  const buffer = fs.readFileSync(file);
  checked++;
  const bad = invalidBytePositions(buffer);
  if (!bad.length) continue;
  failures++;
  const rel = path.relative(sourceDir, file).replace(/\\/g, '/');
  console.log(`HIBA  ${rel}: ${bad.length} ervenytelen UTF-8 bajt (${bad.slice(0, 10).join(', ')})`);
  for (const pos of bad.slice(0, 5)) {
    const from = Math.max(0, pos - 45);
    const snippet = buffer.subarray(from, Math.min(buffer.length, pos + 15)).toString('latin1');
    console.log(`        @${pos} 0x${buffer[pos].toString(16)} …${snippet.replace(/\r?\n/g, '⏎')}`);
  }
  console.log('        (a fajl ANSI/CP1250 bajtot tartalmaz — UTF-8-ra kell javitani)');
}

if (!failures) {
  console.log(`OK    minden vizsgalt fajl ervenyes UTF-8 (${checked} fajl)`);
}
console.log(`\n${failures === 0 ? checked : checked - failures}/${checked} fajl ervenyes UTF-8`);
process.exit(failures === 0 ? 0 : 1);
