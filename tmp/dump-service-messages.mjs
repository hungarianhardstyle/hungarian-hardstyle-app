#!/usr/bin/env node
/**
 * A `lib/services` **felületre jutó magyar üzeneteinek** listája — a fordításhoz.
 *
 * Kimenet: `tmp/service-messages.json` (fájl, sor, szöveg, van-e kulcsa).
 * Használat: node tmp/dump-service-messages.mjs
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
for (const file of walk('lib/services').concat(walk('lib/models'))) {
  const lines = fs.readFileSync(file, 'utf8').split(/\r?\n/);
  lines.forEach((line, index) => {
    const trimmed = line.trim();
    if (trimmed.startsWith('//') || trimmed.startsWith('///')) return;
    for (const match of line.matchAll(/'((?:[^'\\]|\\.)*)'/g)) {
      const text = match[1];
      if (text.length < 3) continue;
      if (!HUNGARIAN.test(text) && !WORDS.test(text)) continue;
      // Csak a **felületre jutó üzenet-jellegű** szövegek (kivétel, validátor,
      // `return '…'`, `message = '…'`): a napló-/debug-szövegek nem feliratok.
      const before = line.slice(0, match.index);
      const isMessage =
        /(StateError|ArgumentError|Exception|FormatException)\s*\(?\s*$/.test(before) ||
        /return\s*$/.test(before) ||
        /(message|_message|error|reason|notice|label|title|subtitle|body)\s*[:=]\s*$/.test(before);
      if (!isMessage) continue;
      rows.push({
        file: file.replaceAll('\\', '/'),
        line: index + 1,
        text,
        isKey: Object.prototype.hasOwnProperty.call(dictionary, text),
        source: trimmed.slice(0, 120),
      });
    }
  });
}

const missing = rows.filter((row) => !row.isKey);
const unique = [...new Set(missing.map((row) => row.text))];
const report = [
  `összes felületre jutó magyar üzenet (services+models): ${rows.length}`,
  `ebből nincs szótári kulcsa: ${missing.length}`,
  `egyedi, még fordítatlan szöveg: ${unique.length}`,
  '',
  '--- a lista ---',
  ...unique.map((text) => JSON.stringify(text)),
];
fs.writeFileSync('tmp/service-messages.txt', `${report.join('\n')}\n`, 'utf8');
fs.writeFileSync('tmp/service-messages.json', JSON.stringify(rows, null, 2), 'utf8');
console.log(report.slice(0, 3).join('\n'));

