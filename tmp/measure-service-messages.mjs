#!/usr/bin/env node
/**
 * Mérés: a **kivétel-/validátor-üzenetek** osztálya (`lib/services`) — hány van,
 * mennyi közülük **interpolált**, és mennyi az, ami a felületre is kijut.
 *
 * MIÉRT: a `WAV (ingyenes)` jelzés megmutatta, hogy az „ékezet = magyar" szabály
 * mellett is maradhat magyar szöveg. A `lib/models`-ben **1** ilyen van (ez az),
 * a `lib/services`-ben viszont **sok** — ez a következő kör mérete.
 *
 * Használat: node tmp/measure-service-messages.mjs
 */
import fs from 'node:fs';
import path from 'node:path';

const HUNGARIAN = /[áéíóöőúüűÁÉÍÓÖŐÚÜŰ]/;
const WORDS = /(^|[^a-zöüóőúéáí])(ingyenes|ingyen|zene|zenek|kell|nem|van|vagy|lesz|marad|fiok|torles)([^a-zöüóőúéáí]|$)/i;
const dictionary = JSON.parse(fs.readFileSync('assets/i18n/en.json', 'utf8'));

const walk = (dir, out = []) => {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(full, out);
    else if (entry.name.endsWith('.dart')) out.push(full);
  }
  return out;
};

const rows = [];
for (const file of walk('lib/services')) {
  const lines = fs.readFileSync(file, 'utf8').split(/\r?\n/);
  lines.forEach((line, index) => {
    const trimmed = line.trim();
    if (trimmed.startsWith('//') || trimmed.startsWith('///')) return;
    for (const match of line.matchAll(/'((?:[^'\\]|\\.)*)'/g)) {
      const text = match[1];
      if (text.length < 3) continue;
      if (!HUNGARIAN.test(text) && !WORDS.test(text)) continue;
      // Csak a felhasználónak szóló (üzenet-jellegű) szövegek: StateError,
      // ArgumentError, `return '…'`, `message = '…'`.
      const before = line.slice(0, match.index);
      const isMessage =
        /(StateError|ArgumentError|Exception|FormatException|return |message\s*[:=]|=>)\s*$/.test(before) ||
        /(StateError|ArgumentError)\(/.test(before);
      if (!isMessage) continue;
      rows.push({
        file: file.replaceAll('\\', '/'),
        line: index + 1,
        text,
        interpolated: /\$\{?[A-Za-z_]/.test(text),
        isKey: Object.prototype.hasOwnProperty.call(dictionary, text),
      });
    }
  });
}

const plain = rows.filter((row) => !row.interpolated);
const interpolated = rows.filter((row) => row.interpolated);
const keys = rows.filter((row) => row.isKey);
console.log(`felületre jutó (üzenet-jellegű) magyar szöveg a lib/services-ben: ${rows.length}`);
console.log(`  ebből sima (nem interpolált): ${plain.length} — szótári kulcs belőle: ${keys.length}`);
console.log(`  ebből interpolált: ${interpolated.length}`);
console.log('\npéldák (sima, MÉG NINCS kulcsa):');
for (const row of plain.filter((r) => !r.isKey).slice(0, 12)) {
  console.log(`  ${row.file}:${row.line} ${JSON.stringify(row.text)}`);
}
console.log('\npéldák (interpolált):');
for (const row of interpolated.slice(0, 8)) {
  console.log(`  ${row.file}:${row.line} ${JSON.stringify(row.text)}`);
}
const byFile = new Map();
for (const row of rows) byFile.set(row.file, (byFile.get(row.file) ?? 0) + 1);
console.log('\na legtöbb ilyen szöveg fájlonként:');
for (const [file, count] of [...byFile].sort((a, b) => b[1] - a[1]).slice(0, 10)) {
  console.log(`  ${count.toString().padStart(3)}  ${file}`);
}
