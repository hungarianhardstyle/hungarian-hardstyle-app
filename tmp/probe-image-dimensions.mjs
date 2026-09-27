#!/usr/bin/env node
/**
 * **A beépített képek felbontása** (a Play „bittérkép-optimalizálás" jelzéséhez).
 *
 * MIÉRT: a méret önmagában nem minden — a **dekódolt** bittérkép memóriája a
 * felbontásból jön (szélesség × magasság × 4 bájt). Egy 1024×1024-es navigációs
 * ikon a képernyőn 24 képponton látszik, a memóriában viszont 4 MB.
 *
 * Használat: node tmp/probe-image-dimensions.mjs
 */
import fs from 'node:fs';
import path from 'node:path';

/** PNG fejléc: szélesség/magasság a 16. bájttól (big-endian). */
function pngSize(buffer) {
  if (buffer.length < 24 || buffer.readUInt32BE(0) !== 0x89504e47) return null;
  return { width: buffer.readUInt32BE(16), height: buffer.readUInt32BE(20) };
}

/** JPEG: a SOF szegmens keresése. */
function jpegSize(buffer) {
  let index = 2;
  while (index < buffer.length - 9) {
    if (buffer[index] !== 0xff) {
      index++;
      continue;
    }
    const marker = buffer[index + 1];
    const length = buffer.readUInt16BE(index + 2);
    if (marker >= 0xc0 && marker <= 0xcf && marker !== 0xc4 && marker !== 0xc8 && marker !== 0xcc) {
      return { height: buffer.readUInt16BE(index + 5), width: buffer.readUInt16BE(index + 7) };
    }
    index += 2 + length;
  }
  return null;
}

const roots = ['assets'];
const found = [];
const walk = (dir) => {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(full);
    else if (/\.(png|jpe?g|webp)$/i.test(entry.name)) found.push(full);
  }
};
for (const root of roots) if (fs.existsSync(root)) walk(root);

let decodedTotal = 0;
let bytesTotal = 0;
console.log('fájl'.padEnd(42), 'bájt'.padStart(9), 'felbontás'.padStart(12), 'memória'.padStart(10));
const rows = [];
for (const file of found) {
  const buffer = fs.readFileSync(file);
  const size = file.endsWith('.png') ? pngSize(buffer) : jpegSize(buffer);
  const decoded = size ? size.width * size.height * 4 : 0;
  decodedTotal += decoded;
  bytesTotal += buffer.length;
  rows.push({ file, bytes: buffer.length, size, decoded });
}
rows.sort((a, b) => b.decoded - a.decoded);
for (const row of rows) {
  console.log(
    row.file.padEnd(42),
    String(row.bytes).padStart(9),
    `${row.size ? `${row.size.width}×${row.size.height}` : '?'}`.padStart(12),
    `${(row.decoded / 1024 / 1024).toFixed(2)} MB`.padStart(10),
  );
}
console.log('');
console.log(`összes fájl: ${rows.length}, együtt ${(bytesTotal / 1024 / 1024).toFixed(2)} MB`);
console.log(`dekódolt memória összesen: ${(decodedTotal / 1024 / 1024).toFixed(2)} MB`);
