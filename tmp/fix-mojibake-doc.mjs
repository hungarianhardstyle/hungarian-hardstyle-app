#!/usr/bin/env node
/**
 * A PowerShell `Set-Content -Encoding UTF8` okozta **dupla kódolás** visszafejtése.
 *
 * ⚠️ MÉRT SAJÁT HIBA (2026-09-26): a `docs/PLAY-KIADASI-JEGYZET.md`-be a
 * `Get-Content -Raw` + `Set-Content -Encoding UTF8` párossal írtam (a SHA
 * helyőrzőjének cseréjéhez) — a PowerShell a fájlt a **rendszer ANSI kódlapján**
 * olvasta, majd UTF-8-ként (BOM-mal) írta vissza, ezért a magyar szöveg
 * `kiadĂˇsi` alakú lett, és a git szerint **az egész fájl** megváltozott.
 *
 * A visszafejtés: a jelenlegi szöveget a **feltételezett eredeti kódlapon**
 * kódoljuk vissza, majd UTF-8-ként olvassuk. Több jelöltet próbálunk, és csak
 * azt fogadjuk el, amelyik **valódi magyar szöveget** ad (ellenőrző szövegek).
 *
 * Használat: node tmp/fix-mojibake-doc.mjs [--write]
 */
import fs from 'node:fs';

const FILE = 'docs/PLAY-KIADASI-JEGYZET.md';
const probes = ['kiadási jegyzet', 'Újdonságok', 'nyelvváltó', 'megjelenések'];
const badMarkers = ['Ă', 'â€', 'Ĺ', 'Ăś'];

const raw = fs.readFileSync(FILE);
const text = raw.toString('utf8').replace(/^\uFEFF/, '');
const startsWithBom = raw[0] === 0xef && raw[1] === 0xbb && raw[2] === 0xbf;

console.log(`BOM a fájl elején: ${startsWithBom}`);
console.log(`jelenlegi hossz: ${raw.length} bájt`);

// A `latin1` minden bájtot 1:1 leképez (0x00–0xFF), ezért a PowerShell
// ANSI-olvasása pontosan visszafordítható vele.
const candidates = [
  ['latin1', (value) => Buffer.from(value, 'latin1').toString('utf8')],
  ['cp1252-közeli', (value) => Buffer.from(value, 'latin1').toString('utf8')],
];

let fixed = null;
for (const [name, convert] of candidates) {
  const attempt = convert(text);
  const hasProbes = probes.every((probe) => attempt.includes(probe));
  const hasBad = badMarkers.some((marker) => attempt.includes(marker));
  console.log(`\n[${name}] próba: magyar szövegek megvannak: ${hasProbes}, mojibake-maradvány: ${hasBad}`);
  console.log(`  első sor: ${JSON.stringify(attempt.split('\n')[0].slice(0, 60))}`);
  if (hasProbes && !hasBad && fixed === null) fixed = attempt;
}

if (fixed === null) {
  console.log('\nHIBA — egyik visszafejtés sem adott tiszta magyar szöveget.');
  process.exit(1);
}

console.log(`\nvisszafejtett hossz: ${Buffer.byteLength(fixed, 'utf8')} bájt`);
if (process.argv.includes('--write')) {
  fs.writeFileSync(FILE, fixed, 'utf8');
  console.log('kiírva (UTF-8, BOM nélkül)');
} else {
  console.log('(próba — a kiíráshoz add meg a --write kapcsolót)');
}
