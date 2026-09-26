#!/usr/bin/env node
/**
 * Audit: a **fordĂ­tĂˇs nĂ©lkĂĽl kiĂ­rt feliratok** keresĂ©se a UI-rĂ©tegben.
 *
 * MIĂ‰RT KELL (mĂ©rt eset, 2026-09-26): a More menĂĽ â€žDJ-k" felirata **nyersen**
 * ment ki (`_item(icon, 'DJ-k', â€¦)`), ezĂ©rt angol mĂłdban magyar maradt â€” pedig a
 * szĂłtĂˇrban **mĂˇr benne volt** a fordĂ­tĂˇsa (`DJ-k â†’ DJs`). A kapu
 * (`tools/check-i18n.mjs`) ezt azĂ©rt nem fogta meg, mert az extraktor a
 * **szabĂˇlyos** alakokat ismeri (`Text('â€¦')`, `label:`, `AppText(â€¦)`), az
 * **argumentum-pozĂ­ciĂłban** ĂˇllĂł literĂˇlt viszont nem.
 *
 * A LĂ‰NYEG: nem az szĂˇmĂ­t, hogy a literĂˇl â€žargumentum-pozĂ­ciĂłban" van-e, hanem
 * hogy **a megjelenĂ­tĹ‘ burkolĂłban** van-e (`tr`, `trArgs`, `AppStrings.tr`,
 * `AppStrings.trArgs`, `AppText`). EzĂ©rt a szkript megkeresi a literĂˇlt
 * **kĂ¶rĂĽlvevĹ‘ hĂ­vĂˇst** (zĂˇrĂłjel-szĂˇmlĂˇlĂˇssal, az elĹ‘zĹ‘ sorokat is figyelve).
 *
 * âš ď¸Ź TANULSĂG A SAJĂT ELSĹ VĂLTOZATOMBĂ“L: a naiv â€želĹ‘tte `,` vagy `(` Ăˇll"
 * szabĂˇly **474 hamis pozitĂ­vot** adott, mert a `tr(context, 'X')` belsejĂ©ben a
 * literĂˇl elĹ‘tt is `,` Ăˇll. A mĂ©rĂ©s csak a **burkolĂł** ismeretĂ©vel helyes.
 *
 * HasznĂˇlat: node tools/audit-raw-labels.mjs
 */
import fs from 'node:fs';
import path from 'node:path';

const ROOTS = ['lib/screens', 'lib/widgets'];
const dictionary = JSON.parse(fs.readFileSync('assets/i18n/en.json', 'utf8'));

/** Ezek a hĂ­vĂˇsok fordĂ­tanak (a bennĂĽk ĂˇllĂł literĂˇl rendben van). */
const TRANSLATING = new Set(['tr', 'trArgs', 'AppText']);
const TRANSLATING_MEMBERS = new Set(['AppStrings.tr', 'AppStrings.trArgs']);

/** A `Text('â€¦')` NEM fordĂ­t (a mĂˇsodik kĂ¶rben `AppText` lett) â€” kĂĽlĂ¶n kategĂłria. */
const walk = (dir) => fs.readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
  const full = path.join(dir, entry.name);
  if (entry.isDirectory()) return walk(full);
  return entry.name.endsWith('.dart') ? [full] : [];
});

/** A literĂˇlot kĂ¶rĂĽlvevĹ‘ hĂ­vĂˇs neve (a megelĹ‘zĹ‘ sorokat is figyelve). */
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

/** A nem megjelenĂ­tĹ‘ hĂ­vĂˇsok (ezek argumentuma nem felirat). */
const NON_UI_CALLS = new Set([
  'StateError', 'Exception', 'ArgumentError', 'AssertionError', 'FormatException', 'Error',
  'contains', 'startsWith', 'endsWith', 'indexOf', 'lastIndexOf', 'replaceAll', 'replaceFirst',
  'split', 'allMatches', 'RegExp', 'debugPrint', 'print',
]);

const looksHungarian = (text) => /[ĂˇĂ©Ă­ĂłĂ¶Ĺ‘ĂşĂĽĹ±ĂĂ‰ĂŤĂ“Ă–ĹĂšĂśĹ°]/.test(text);

const rawTranslated = [];   // a szĂłtĂˇrban VAN fordĂ­tĂˇs, mĂ©gis nyersen megy ki
const rawTextWidget = [];   // `Text('â€¦')` â€” nem fordĂ­t
const suspects = [];        // nincs a szĂłtĂˇrban, de magyar feliratnak lĂˇtszik
const dataValues = [];      // const tĂ©rkĂ©p Ă©rtĂ©ke (a megjelenĂ­tĂ©s fordĂ­tja â€” by design)

for (const file of ROOTS.flatMap(walk)) {
  const lines = fs.readFileSync(file, 'utf8').split('\n');
  lines.forEach((line, lineIndex) => {
    const trimmed = line.trim();
    if (trimmed.startsWith('//') || trimmed.startsWith('///')) return;
    for (const match of line.matchAll(/'([^'\\$\n]{2,90})'/g)) {
      const text = match[1];
      const before = line.slice(0, match.index);
      // âš ď¸Ź `'kulcs': 'Ă©rtĂ©k'` â€” const tĂ©rkĂ©p/adatlista: a megjelenĂ­tĂ©s fordĂ­tja.
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
  if (list.length > 25) console.log(`  â€¦ Ă©s tovĂˇbbi ${list.length - 25}`);
};

print('BUG â€” a szĂłtĂˇrban VAN fordĂ­tĂˇs, de a hely nyersen Ă­rja ki (nem fordĂ­tĂł hĂ­vĂˇsban)', rawTranslated);
print('GYANĂšS â€” `Text(\'â€¦\')`, ami nem fordĂ­t (a szĂłtĂˇrban van fordĂ­tĂˇsa)', rawTextWidget);
print('GYANĂšS â€” nincs a szĂłtĂˇrban, de magyar feliratnak lĂˇtszik', suspects);
console.log(`\n(by design, kihagyva: ${dataValues.length} const tĂ©rkĂ©p/lista Ă©rtĂ©k â€” a megjelenĂ­tĂ©s fordĂ­tja)`);

process.exitCode = rawTranslated.length ? 1 : 0;
