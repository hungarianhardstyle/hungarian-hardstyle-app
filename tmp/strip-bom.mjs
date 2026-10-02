// A PowerShell `Set-Content -Encoding utf8` BOM-ot tesz a fájl elejére (a projekt
// visszatérő hibája) — ez a szkript **bájt szinten** szedi le, minden mást
// érintetlenül hagyva, és megmondja, mi változott.
import fs from 'node:fs';
import crypto from 'node:crypto';

const file = process.argv[2] ?? 'pubspec.yaml';
const before = fs.readFileSync(file);
const hasBom = before.length >= 3 && before[0] === 0xef && before[1] === 0xbb && before[2] === 0xbf;
if (!hasBom) {
  console.log(`nincs BOM: ${file}`);
} else {
  fs.writeFileSync(file, before.subarray(3));
  console.log(`BOM eltávolítva: ${file}`);
}
const after = fs.readFileSync(file);
console.log(`méret: ${before.length} → ${after.length} bájt`);
console.log(`sha256: ${crypto.createHash('sha256').update(after).digest('hex')}`);
