#!/usr/bin/env node
/**
 * Audit: a **fordítás nélkül kiírt feliratok** keresése a UI-rétegben.
 *
 * MIÉRT KELL (mért eset, 2026-09-26): a More menü „DJ-k" felirata **nyersen**
 * ment ki (`_item(icon, 'DJ-k', …)`), ezért angol módban magyar maradt — pedig a
 * szótárban **már benne volt** a fordítása (`DJ-k → DJs`). A kapu
 * (`tools/check-i18n.mjs`) ezt azért nem fogta meg, mert az extraktor a
 * **szabályos** alakokat ismeri (`Text('…')`, `label:`, `AppText(…)`), az
 * **argumentum-pozícióban** álló literált viszont nem.
 *
 * A LÉNYEG: nem az számít, hogy a literál „argumentum-pozícióban" van-e, hanem
 * hogy **a megjelenítő burkolóban** van-e (`tr`, `trArgs`, `AppStrings.tr`,
 * `AppStrings.trArgs`, `AppText`). Ezért a szkript megkeresi a literált
 * **körülvevő hívást** (zárójel-számlálással, az előző sorokat is figyelve).
 *
 * ⚠️ TANULSÁG A SAJÁT ELSŐ VÁLTOZATOMBÓL: a naiv „előtte `,` vagy `(` áll"
 * szabály **474 hamis pozitívot** adott, mert a `tr(context, 'X')` belsejében a
 * literál előtt is `,` áll. A mérés csak a **burkoló** ismeretével helyes.
 *
 * Használat: node tmp/audit-raw-labels.mjs
 */
import fs from 'node:fs';
import path from 'node:path';

const ROOTS = ['lib/screens', 'lib/widgets'];
const dictionary = JSON.parse(fs.readFileSync('assets/i18n/en.json', 'utf8'));

/** Ezek a hívások fordítanak (a bennük álló literál rendben van). */
const TRANSLATING = new Set(['tr', 'trArgs', 'AppText']);
const TRANSLATING_MEMBERS = new Set(['AppStrings.tr', 'AppStrings.trArgs']);

/** A `Text('…')` NEM fordít (a második körben `AppText` lett) — külön kategória. */
const walk = (dir) => fs.readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
  const full = path.join(dir, entry.name);
  if (entry.isDirectory()) return walk(full);
  return entry.name.endsWith('.dart') ? [full] : [];
});

/** A literálot körülvevő hívás neve (a megelőző sorokat is figyelve). */
const enclosingCall = (lines, lineIndex, columnIndex) => {
  const window = [...lines.slice(Math.max(0, lineIndex - 3), lineIndex), lines[lineIndex].slice(0, columnIndex)].join('\n');
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

/** A nem megjelenítő hívások (ezek argumentuma nem felirat). */
const NON_UI_CALLS = new Set([
  'StateError', 'Exception', 'ArgumentError', 'AssertionError', 'FormatException', 'Error',
  'contains', 'startsWith', 'endsWith', 'indexOf', 'lastIndexOf', 'replaceAll', 'replaceFirst',
  'split', 'allMatches', 'RegExp', 'debugPrint', 'print',
]);

const looksHungarian = (text) => /[áéíóöőúüűÁÉÍÓÖŐÚÜŰ]/.test(text);

const rawTranslated = [];   // a szótárban VAN fordítás, mégis nyersen megy ki
const rawTextWidget = [];   // `Text('…')` — nem fordít
const suspects = [];        // nincs a szótárban, de magyar feliratnak látszik
const dataValues = [];      // const térkép értéke (a megjelenítés fordítja — by design)

for (const file of ROOTS.flatMap(walk)) {
  const lines = fs.readFileSync(file, 'utf8').split('\n');
  lines.forEach((line, lineIndex) => {
    const trimmed = line.trim();
    if (trimmed.startsWith('//') || trimmed.startsWith('///')) return;
    for (const match of line.matchAll(/'([^'\\$\n]{2,90})'/g)) {
      const text = match[1];
      const before = line.slice(0, match.index);
      // ⚠️ `'kulcs': 'érték'` — const térkép/adatlista: a megjelenítés fordítja.
      if (/'[^']*'\s*:\s*$/.test(before)) {
        dataValues.push({ file: file.replaceAll('\\', '/'), line: lineIndex + 1, text });
        continue;
      }
      const call = enclosingCall(lines, lineIndex, match.index);
      if (NON_UI_CALLS.has(call)) continue;
      const translating = TRANSLATING.has(call) || TRANSLATING_MEMBERS.has(call);
      const entry = { file: file.replaceAll('\\', '/'), line: lineIndex + 1, text, call: call || '(nincs)' };

      if (translating) continue;
      if (call === 'Text') {
        if (Object.prototype.hasOwnProperty.call(dictionary, text)) rawTextWidget.push(entry);
        continue;
      }
      if (Object.prototype.hasOwnProperty.call(dictionary, text)) rawTranslated.push(entry);
      else if (looksHungarian(text) && text.length <= 40 && !text.endsWith(' ')) suspects.push(entry);
    }
  });
}

const print = (label, list) => {
  console.log(`\n${label}: ${list.length}`);
  for (const item of list.slice(0, 25)) {
    console.log(`  ${item.file}:${item.line} [${item.call}] ${JSON.stringify(item.text)}`);
  }
  if (list.length > 25) console.log(`  … és további ${list.length - 25}`);
};

print('BUG — a szótárban VAN fordítás, de a hely nyersen írja ki (nem fordító hívásban)', rawTranslated);
print('GYANÚS — `Text(\'…\')`, ami nem fordít (a szótárban van fordítása)', rawTextWidget);
print('GYANÚS — nincs a szótárban, de magyar feliratnak látszik', suspects);
console.log(`\n(by design, kihagyva: ${dataValues.length} const térkép/lista érték — a megjelenítés fordítja)`);

process.exitCode = rawTranslated.length ? 1 : 0;
