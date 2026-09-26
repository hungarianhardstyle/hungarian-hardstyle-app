#!/usr/bin/env node
/**
 * Szonda: a **nyers, interpolált** (vagy összefűzött) feliratok keresése.
 *
 * MIÉRT KELL (mért eset, 2026-09-26 — a tulajdonos jelzése): a „My purchased music"
 * fejlécében angol módban is „11 letöltött zene" állt, mert a kiírás
 * `'${_downloaded.length} letöltött zene'` volt. Ezt a hibaosztályt SEM a
 * szótár-kapu (`tools/check-i18n.mjs`), SEM a `tmp/audit-raw-labels.mjs` nem
 * látja: az extraktor a `$`-t tartalmazó literált kihagyja (nem tudja, mi lesz a
 * helyőrző értéke), a raw-label audit regexe pedig eleve kizárja a `$`-t.
 *
 * A LÉNYEG: nem az számít, hogy a literál interpolált-e, hanem hogy a
 * **megjelenítő burkolóban** van-e (`tr`, `trArgs`, `AppText`, `AppStrings.tr`,
 * `AppStrings.trArgs`). Ezért a szkript a literál **körülvevő hívását** keresi
 * (zárójel-számlálással, az előző sorokat is figyelve) — pontosan úgy, ahogy a
 * `tmp/audit-raw-labels.mjs` teszi (ott ez a rész már bizonyítottan helyes).
 *
 * ⚠️ A TALÁLAT KONTEXTUSÁT MINDIG KI KELL ÍRNI (a saját tanulságom: a heurisztika
 * nem bizonyíték) — ezért minden találatnál ott a forrássor és a burkoló hívás.
 *
 * Használat: node tmp/probe-raw-interpolated.mjs [--all]
 *   --all  a teljes lib/-et nézi (alapból csak a megjelenítő réteget)
 */
import fs from 'node:fs';
import path from 'node:path';

const ALL = process.argv.includes('--all');
const ROOTS = ALL
  ? ['lib']
  : ['lib/screens', 'lib/widgets'];

const walk = (dir) => fs.readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
  const full = path.join(dir, entry.name);
  if (entry.isDirectory()) return walk(full);
  return entry.name.endsWith('.dart') ? [full] : [];
});

/** Ezek a hívások fordítanak (a bennük álló literál rendben van). */
const TRANSLATING = new Set(['tr', 'trArgs', 'AppText']);
const TRANSLATING_MEMBERS = new Set(['AppStrings.tr', 'AppStrings.trArgs']);

/** Nem megjelenítő hívások (az argumentumuk nem felirat). */
const NON_UI_CALLS = new Set([
  'StateError', 'Exception', 'ArgumentError', 'AssertionError', 'FormatException', 'Error',
  'contains', 'startsWith', 'endsWith', 'indexOf', 'lastIndexOf', 'replaceAll', 'replaceFirst',
  'split', 'allMatches', 'RegExp', 'debugPrint', 'print', 'jsonEncode', 'jsonDecode',
  'Uri.parse', 'setString', 'getString', 'putIfAbsent', 'remove', 'add', 'addAll',
]);

/** A literálot körülvevő hívás neve (a megelőző sorokat is figyelve). */
const enclosingCall = (lines, lineIndex, columnIndex) => {
  const window = [
    ...lines.slice(Math.max(0, lineIndex - 3), lineIndex),
    lines[lineIndex].slice(0, columnIndex),
  ].join('\n');
  let depth = 0;
  for (let i = window.length - 1; i >= 0; i -= 1) {
    const ch = window[i];
    if (ch === ')') depth += 1;
    else if (ch === '(') {
      if (depth === 0) {
        const match = /([A-Za-z_][A-Za-z0-9_.]*)\s*$/.exec(window.slice(0, i));
        return match ? match[1] : '';
      }
      depth -= 1;
    }
  }
  return '';
};

const looksHungarian = (text) => /[áéíóöőúüűÁÉÍÓÖŐÚÜŰ]/.test(text);

/**
 * A literálok kigyűjtése egy sorból: `'…'` és `"…"` alak, a `$`-t is beleértve.
 * A `$` utáni `{…}` blokkon belüli idézőjeleket nem bontjuk szét — a közelítés
 * itt elég, mert csak a literál szövegét nézzük.
 */
const literalsOf = (line) => {
  const out = [];
  for (const match of line.matchAll(/'((?:[^'\\]|\\.)*)'|"((?:[^"\\]|\\.)*)"/g)) {
    const text = match[1] ?? match[2] ?? '';
    out.push({ text, index: match.index, interpolated: /\$\{?[A-Za-z_]/.test(text) });
  }
  return out;
};

const findings = [];
const skipped = [];

for (const file of ROOTS.flatMap(walk)) {
  const source = fs.readFileSync(file, 'utf8');
  const lines = source.split('\n');
  lines.forEach((line, lineIndex) => {
    const trimmed = line.trim();
    if (trimmed.startsWith('//') || trimmed.startsWith('///')) return;
    for (const literal of literalsOf(line)) {
      const { text } = literal;
      if (text.length < 2) continue;
      if (!looksHungarian(text) && !literal.interpolated) continue;
      const before = line.slice(0, literal.index);
      // `'kulcs': 'érték'` — const térkép/adatlista: a megjelenítés fordítja.
      if (/'[^']*'\s*:\s*$/.test(before)) {
        skipped.push({ file, line: lineIndex + 1, text, reason: 'const térkép érték' });
        continue;
      }
      const call = enclosingCall(lines, lineIndex, literal.index);
      if (TRANSLATING.has(call) || TRANSLATING_MEMBERS.has(call)) continue;
      if (NON_UI_CALLS.has(call)) {
        skipped.push({ file, line: lineIndex + 1, text, reason: `nem megjelenítő hívás: ${call}` });
        continue;
      }
      // Ha a literál NEM interpolált, azt a tmp/audit-raw-labels.mjs méri — itt csak
      // az interpolált/összefűzött alak érdekes, de a magyar ékezetes nyers literál
      // is ide kerül (mert az is nyers felirat).
      findings.push({
        file: file.replaceAll('\\', '/'),
        line: lineIndex + 1,
        text,
        call: call || '(nincs)',
        source: trimmed,
      });
    }
  });
}

console.log(`Nyers (nem fordító hívásban álló) magyar/interpolált literálok: ${findings.length}`);
const byFile = new Map();
for (const item of findings) {
  if (!byFile.has(item.file)) byFile.set(item.file, []);
  byFile.get(item.file).push(item);
}
for (const [file, items] of byFile) {
  console.log(`\n${file}  (${items.length})`);
  for (const item of items) {
    console.log(`  ${item.line} [${item.call}] ${JSON.stringify(item.text)}`);
    console.log(`      ${item.source}`);
  }
}
console.log(`\n(kihagyva: ${skipped.length} — const térkép érték / nem megjelenítő hívás)`);
process.exitCode = findings.length ? 1 : 0;
