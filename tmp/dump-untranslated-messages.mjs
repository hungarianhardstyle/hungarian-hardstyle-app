#!/usr/bin/env node
/**
 * A **még fordítatlan** felületi üzenetek egy listában (services + models +
 * `user_facing_error.dart`) — a fordítás bemenete.
 *
 * Kimenet: `tmp/untranslated-messages.txt` (UTF-8, a `write` eszközzel olvasható).
 * Használat: node tmp/dump-untranslated-messages.mjs
 */
import fs from 'node:fs';

const HUNGARIAN = /[áéíóöőúüűÁÉÍÓÖŐÚÜŰ]/;
const WORDS = /(^|[^a-zöüóőúéáí])(ingyenes|ingyen|zene|zenek|kell|nem|van|vagy|lesz|marad|fiok|torles)([^a-zöüóőúéáí]|$)/i;
const dictionary = JSON.parse(fs.readFileSync('assets/i18n/en.json', 'utf8'));

const FILES = [
  'lib/core/errors/user_facing_error.dart',
  ...fs
    .readdirSync('lib/services')
    .filter((name) => name.endsWith('.dart'))
    .map((name) => `lib/services/${name}`),
  ...fs
    .readdirSync('lib/models')
    .filter((name) => name.endsWith('.dart'))
    .map((name) => `lib/models/${name}`),
];

/** A literálok egy sorban (a `${…}` blokkban lévő idézőjelek nem zárnak). */
const literalsOf = (line) => {
  const out = [];
  let i = 0;
  while (i < line.length) {
    const quote = line[i];
    if (quote !== "'" && quote !== '"') {
      i += 1;
      continue;
    }
    let j = i + 1;
    let text = '';
    let closed = false;
    while (j < line.length) {
      const ch = line[j];
      if (ch === '\\') {
        text += line.slice(j, j + 2);
        j += 2;
        continue;
      }
      if (ch === '$' && line[j + 1] === '{') {
        let depth = 1;
        let k = j + 2;
        while (k < line.length && depth > 0) {
          if (line[k] === '{') depth += 1;
          else if (line[k] === '}') depth -= 1;
          k += 1;
        }
        text += line.slice(j, k);
        j = k;
        continue;
      }
      if (ch === quote) {
        closed = true;
        break;
      }
      text += ch;
      j += 1;
    }
    if (closed) out.push({ text, index: i, atEnd: line.slice(j + 1).trim().isEmpty, quote });
    i = j + 1;
  }
  return out;
};

const rows = [];
const seen = new Set();
for (const file of FILES) {
  if (!fs.existsSync(file)) continue;
  const lines = fs.readFileSync(file, 'utf8').split(/\r?\n/);
  const continuation = new Set();
  lines.forEach((line, index) => {
    if (continuation.has(index)) return;
    const trimmed = line.trim();
    if (trimmed.startsWith('//') || trimmed.startsWith('///')) return;
    for (const literal of literalsOf(line)) {
      let text = literal.text;
      let current = index;
      let continues = literal.atEnd;
      while (continues) {
        current += 1;
        if (current >= lines.length) break;
        const next = lines[current].trimLeft();
        if (!next.startsWith(literal.quote)) break;
        const inner = next.slice(1);
        const end = inner.indexOf(literal.quote);
        if (end < 0) break;
        text += inner.slice(0, end);
        continuation.add(current);
        continues = inner.slice(end + 1).trim().isEmpty;
      }
      if (text.length < 3) continue;
      if (!HUNGARIAN.test(text) && !WORDS.test(text)) continue;
      if (Object.prototype.hasOwnProperty.call(dictionary, text)) continue;
      // Csak a felületre jutó (üzenet-jellegű) szövegek.
      const before = line.slice(0, literal.index);
      const isMessage =
        /(StateError|ArgumentError|Exception|FormatException)\s*\(?\s*$/.test(before) ||
        /return\s*$/.test(before) ||
        /(message|_message|error|reason|notice|label|title|subtitle|body)\s*[:=]\s*$/.test(before);
      if (!isMessage) continue;
      const key = text;
      if (seen.has(key)) continue;
      seen.add(key);
      rows.push({ file: file.replaceAll('\\', '/'), line: index + 1, text, interpolated: /\$\{?[A-Za-z_]/.test(text) });
    }
  });
}

const plain = rows.filter((row) => !row.interpolated);
const interpolated = rows.filter((row) => row.interpolated);
const report = [
  `fordítatlan felületi üzenet: ${rows.length} (sima: ${plain.length}, interpolált: ${interpolated.length})`,
  '',
  '--- SIMA (szótár-kulcs lesz) ---',
  ...plain.map((row) => JSON.stringify(row.text)),
  '',
  '--- INTERPOLÁLT (sablon kell) ---',
  ...interpolated.map((row) => `${row.file}:${row.line} ${JSON.stringify(row.text)}`),
];
fs.writeFileSync('tmp/untranslated-messages.txt', `${report.join('\n')}\n`, 'utf8');
fs.writeFileSync('tmp/untranslated-messages.json', JSON.stringify(rows, null, 2), 'utf8');
console.log(report.slice(0, 1)[0]);
