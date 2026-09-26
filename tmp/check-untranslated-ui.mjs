#!/usr/bin/env node
/**
 * Szonda: **megjelenítési helyen álló, NEM fordított** feliratok keresése.
 *
 * MIÉRT KELL (mért eset, 2026-09-26 — a tulajdonos jelzése): a „My purchased music"
 * fejlécében angol módban is „11 letöltött zene" állt, mert a kiírás
 * `'${_downloaded.length} letöltött zene'` volt. Ezt a hibaosztályt SEM a
 * szótár-kapu (`tools/check-i18n.mjs`), SEM a `tmp/audit-raw-labels.mjs` nem
 * látja: az extraktor a `$`-t tartalmazó literált kihagyja, a raw-label audit
 * regexe pedig eleve kizárja a `$`-t.
 *
 * A LÉNYEG (két szűrő együtt):
 *   1. **HOL** áll a literál: csak a **megjelenítő helyeket** nézzük (`Text`,
 *      `AppText`, `label:`, `tooltip:`, `title:`, `hintText:`, `helperText:`,
 *      `_message(…)`, SnackBar `content:` stb.) — így a `Key('…')`, a Hero `tag:`,
 *      az URL-ek és a JSON-átalakítások eleve kiesnek.
 *   2. **MI** áll benne: magyar ékezet VAGY magyar funkciószó. A csak-interpolált,
 *      szöveg nélküli alak (`'$item'`, `'${x}'`) nem felirat.
 * Rendben van, ha a literál **fordító hívásban** áll, vagy ha a szöveg
 * **szótári kulcs** (a megjelenítés fordítja — pl. a tárolt hibaüzenetek).
 *
 * ⚠️ A TALÁLAT KONTEXTUSÁT MINDIG KI KELL ÍRNI (a saját tanulságom: a heurisztika
 * nem bizonyíték) — ezért minden találatnál ott a forrássor és a burkoló hívás.
 *
 * Használat: node tmp/check-untranslated-ui.mjs [--all|--file <path>]
 */
import fs from 'node:fs';
import path from 'node:path';

const args = process.argv.slice(2);
const ALL = args.includes('--all');
const FILE_FILTER = args.includes('--file') ? args[args.indexOf('--file') + 1] : null;
const ROOTS = ALL ? ['lib'] : ['lib/screens', 'lib/widgets'];

const dictionary = JSON.parse(fs.readFileSync('assets/i18n/en.json', 'utf8'));

const walk = (dir) => fs.readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
  const full = path.join(dir, entry.name);
  if (entry.isDirectory()) return walk(full);
  return entry.name.endsWith('.dart') ? [full] : [];
});

/** Ezek a hívások fordítanak (a bennük álló literál rendben van). */
const TRANSLATING = new Set(['tr', 'trArgs', 'AppText']);
const TRANSLATING_MEMBERS = new Set(['AppStrings.tr', 'AppStrings.trArgs']);

/** Megjelenítő helyek: itt a literál a felhasználónak látszik. */
const DISPLAY_CALLS = new Set([
  'Text', 'SelectableText', 'TextSpan', 'RichText', 'Chip', 'AppBar', 'SnackBar',
  'DropdownMenuItem', 'Tooltip', 'ListTile', '_message', '_showMessage', '_showSnackBar',
  'showSnackBar', 'showDialog', 'AlertDialog', 'InputDecoration', 'TextButton', 'ElevatedButton',
  'OutlinedButton', 'FilledButton', 'ActionChip', 'FilterChip', 'ChoiceChip', 'MenuItemButton',
  'showModalBottomSheet', 'Dialog', 'Card', 'Badge', 'Semantics',
]);
/** Megjelenítő **nevesített paraméterek** (a hívás nevétől függetlenül). */
const DISPLAY_PARAMS = /(?:^|[\s(,])(label|tooltip|title|subtitle|hintText|helperText|errorText|counterText|semanticLabel|message|content|header|placeholder|text|caption|description|emptyLabel|confirmLabel|cancelLabel)\s*:\s*$/;

const looksHungarian = (text) => /[áéíóöőúüűÁÉÍÓÖŐÚÜŰ]/.test(text);

/** Magyar funkciószavak — akkor is felismeri a magyar feliratot, ha nincs ékezet. */
const HUNGARIAN_WORDS = [
  ' a ', ' az ', ' egy ', ' nem ', ' meg ', ' van ', ' nincs ', ' vagy ', ' hogy ', ' ez ',
  ' ezt ', ' ebben ', ' mint ', ' csak ', ' mar ', ' már ', ' tovább ', ' vissza ', ' elott ',
  ' előtt ', ' utan ', ' után ', ' kell ', ' lehet ', ' lesz ', ' volt ', ' minden ', ' tolt ',
  ' tölt ', ' letolt', ' letölt', ' zenek ', ' zenét ', ' zene ', ' sikerult ', ' sikerült ',
];
const looksLikeHungarianSentence = (text) => {
  const padded = ` ${text.toLowerCase()} `;
  return HUNGARIAN_WORDS.some((word) => padded.includes(word));
};

/** A literál szövege önmagában is elég-e a felismeréshez? */
const isLabelText = (text) => {
  const withoutPlaceholders = text.replace(/\$\{[^}]*\}|\$[A-Za-z_][A-Za-z0-9_]*/g, '').trim();
  if (withoutPlaceholders.length < 2) return false;          // csak interpoláció: nem felirat
  if (!/[A-Za-zÁÉÍÓÖŐÚÜŰáéíóöőúüű]{2}/.test(withoutPlaceholders)) return false;
  return looksHungarian(text) || looksLikeHungarianSentence(withoutPlaceholders);
};

const enclosingCall = (lines, lineIndex, columnIndex) => {
  // ⚠️ 12 sor visszafelé: a **többsoros** (összefűzött) literálok folytatásai
  // különben „gazdátlan" találatként jelentek meg (mért hamis pozitív: az
  // adatvédelmi képernyő bekezdései, amik valójában `AppText(...)`-ben vannak).
  const window = [
    ...lines.slice(Math.max(0, lineIndex - 12), lineIndex),
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

/**
 * A literálok kigyűjtése egy sorból — **beágyazott** idézőjelekkel is.
 *
 * ⚠️ MÉRT HIBA AZ ELSŐ VÁLTOZATBAN: a naiv `'([^']*)'` regex a
 * `'Ok: ${report.data()['reason'] ?? 'egyéb'}'` sorban **kettévágta** a literált
 * (a `'reason'` és az `'egyéb'` külön darab lett), ezért a magyar „Ok: … egyéb"
 * felirat **nem** került a listára. A helyes szabály: az idézőjel csak akkor zár,
 * ha **nem** `${…}` blokk belsejében vagyunk (a blokkban idézőjel állhat).
 */
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
        // Interpolációs blokk: a benne lévő idézőjelek nem zárnak.
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
    if (closed) out.push({ text, index: i });
    i = j + 1;
  }
  return out;
};

const findings = [];
const skipped = [];

for (const file of ROOTS.flatMap(walk)) {
  const normalized = file.replaceAll('\\', '/');
  if (FILE_FILTER && !normalized.includes(FILE_FILTER)) continue;
  const lines = fs.readFileSync(file, 'utf8').split('\n');
  lines.forEach((line, lineIndex) => {
    const trimmed = line.trim();
    if (trimmed.startsWith('//') || trimmed.startsWith('///')) return;
    for (const literal of literalsOf(line)) {
      const { text } = literal;
      if (!isLabelText(text)) continue;
      if (Object.prototype.hasOwnProperty.call(dictionary, text)) {
        skipped.push({ file: normalized, line: lineIndex + 1, text, reason: 'szótári kulcs (a megjelenítés fordítja)' });
        continue;
      }
      const before = line.slice(0, literal.index);
      if (/'[^']*'\s*:\s*$/.test(before)) {
        skipped.push({ file: normalized, line: lineIndex + 1, text, reason: 'const térkép érték' });
        continue;
      }
      const call = enclosingCall(lines, lineIndex, literal.index);
      if (TRANSLATING.has(call) || TRANSLATING_MEMBERS.has(call)) continue;
      const namedParam = DISPLAY_PARAMS.test(before);
      const display = DISPLAY_CALLS.has(call) || namedParam;
      const entry = {
        file: normalized,
        line: lineIndex + 1,
        text,
        call: call || '(nincs)',
        source: trimmed,
        context: lines
          .slice(Math.max(0, lineIndex - 4), Math.min(lines.length, lineIndex + 5))
          .map((raw, offset) => `${Math.max(1, lineIndex - 3) + offset}: ${raw}`),
      };
      if (display) findings.push(entry);
      else skipped.push({ ...entry, reason: `nem megjelenítő hely: [${entry.call}]` });
    }
  });
}

const report = [];
const say = (line = '') => { report.push(line); console.log(line); };
say(`NEM fordított felirat megjelenítési helyen: ${findings.length}`);
const byFile = new Map();
for (const item of findings) {
  if (!byFile.has(item.file)) byFile.set(item.file, []);
  byFile.get(item.file).push(item);
}
for (const [file, items] of [...byFile].sort((a, b) => b[1].length - a[1].length)) {
  say(`\n${file}  (${items.length})`);
  for (const item of items) {
    say(`  ${item.line} [${item.call}] ${JSON.stringify(item.text)}`);
    say(`      ${item.source}`);
  }
}
say(`\n(kihagyva: ${skipped.length} — szótári kulcs / const térkép / nem megjelenítő hely)`);
if (args.includes('--skipped')) {
  // A „nem megjelenítő hely" kategória a **látens** magyar feliratok lelőhelye
  // (pl. egy szolgáltatás `return '…'` felirata, amit a UI fordít nélkül ír ki).
  const latent = skipped.filter((item) => item.reason?.startsWith('nem megjelenítő hely'));
  say(`\n--- látens (nem megjelenítő hívásban álló) magyar literálok: ${latent.length} ---`);
  for (const item of latent) {
    say(`  ${item.file}:${item.line} [${item.call}] ${JSON.stringify(item.text)}`);
    say(`      ${item.source ?? ''}`);
  }
}
// UTF-8-ban, a `write` eszközzel olvashatóan (a PowerShell-átirányítás UTF-16-ot ad).
fs.writeFileSync('tmp/untranslated-ui.txt', `${report.join('\n')}\n`, 'utf8');
// A javításhoz a **környezet** is kell (a találat sora önmagában félrevezet).
const contextReport = findings.map((item) => [
  `${item.file}:${item.line} [${item.call}] ${JSON.stringify(item.text)}`,
  ...item.context,
  '',
].join('\n'));
fs.writeFileSync('tmp/untranslated-ui-context.txt', `${contextReport.join('\n')}\n`, 'utf8');
fs.writeFileSync('tmp/untranslated-ui.json', `${JSON.stringify(findings, null, 2)}\n`, 'utf8');
process.exitCode = findings.length ? 1 : 0;
