#!/usr/bin/env node
/**
 * A célzott magyar UI-szövegek bekötése a fordítóba — KÉT biztonságos módon.
 *
 * 1. **`Text(`-helyek (mérve 581):** a widget `AppText`-re cserélődik, a szöveg
 *    a konstruktorban marad → a `const` widget-fák **nem törnek el**. A fordítás
 *    az `AppText.build`-ben történik. ⚠️ A `Text(` gyakran **korábbi sorban**
 *    van (`Text(\n  'szöveg',\n)`), ezért az átalakítás **abszolút
 *    forrás-pozíciókkal** dolgozik, nem soronként: a nyitó sorban lévő `Text`
 *    azonosítót cseréli, akármelyik sorban van.
 * 2. **Nevesített paraméterek (mérve 202: tooltip, labelText, title, label,
 *    hintText, helperText, description, subtitle, message):** a szöveg
 *    `tr(context, '…')` lesz. Itt a `const` előtag néhol eltávolítandó — ezt a
 *    `flutter analyze` mondja meg pontosan (nincs találgatás).
 *
 * A literal **tartalma nem változik**, ezért a szótár kulcshalmaza ugyanaz
 * marad (`tools/extract-ui-strings.mjs` újrafuttatva ugyanazt adja).
 *
 * Használat:
 *   node tools/wrap-ui-strings.mjs             # száraz futás (alap)
 *   node tools/wrap-ui-strings.mjs --apply     # írás
 *   node tools/wrap-ui-strings.mjs --report    # fájlonkénti bontás
 *   node tools/wrap-ui-strings.mjs --self-test
 */
import fs from 'node:fs';
import path from 'node:path';

import { targetsInSource } from './extract-ui-strings.mjs';

export const APP_TEXT_IMPORT = 'widgets/app_text.dart';
export const TR_IMPORT = 'core/i18n/tr.dart';

/** A literal előtt (akár több sorral korábban) `Text(` áll-e? */
export function findTextIdentifier(source, position) {
  const windowStart = Math.max(0, position - 300);
  const window = source.slice(windowStart, position);
  const match = /(?:^|[\s(,{[])(Text)\s*\(\s*$/.exec(window);
  if (!match) return -1;
  return windowStart + match.index + match[0].indexOf('Text');
}

/** A literal körbefordítása `tr(context, '…')`-ra. */
export function wrapLiteral(rawLiteral) {
  return `tr(context, ${rawLiteral})`;
}

/** Relatív import-út a `lib/`-en belül (a projekt stílusa: `core/…`, `../../widgets/…`). */
export function relativeImportFor(file, target) {
  const from = path.posix.dirname(file.replaceAll('\\', '/'));
  const relative = path.posix.relative(from, `lib/${target}`);
  return `import '${relative}';`;
}

/** Egy fájl összes szerkesztése (abszolút pozíciókkal). */
export function planEdits(source, file = 'x.dart') {
  const edits = [];
  let appText = 0;
  let tr = 0;
  for (const hit of targetsInSource(source, file)) {
    const position = offsetOf(source, hit.line, hit.start);
    const textStart = findTextIdentifier(source, position);
    if (textStart >= 0) {
      edits.push({ start: textStart, end: textStart + 4, text: 'AppText', kind: 'app-text', value: hit.value });
      appText += 1;
      continue;
    }
    edits.push({
      start: position,
      end: position + (hit.end - hit.start),
      text: wrapLiteral(source.slice(position, position + (hit.end - hit.start))),
      kind: 'tr',
      value: hit.value,
    });
    tr += 1;
  }
  return { edits, appText, tr };
}

/** Sor + oszlop → abszolút pozíció. */
export function offsetOf(source, line, column) {
  let offset = 0;
  let current = 1;
  while (current < line) {
    const next = source.indexOf('\n', offset);
    if (next < 0) break;
    offset = next + 1;
    current += 1;
  }
  return offset + column;
}

/** A szerkesztések alkalmazása jobbról balra (a pozíciók így nem csúsznak). */
export function applyEdits(source, edits) {
  let result = source;
  for (const edit of [...edits].sort((a, b) => b.start - a.start)) {
    result = `${result.slice(0, edit.start)}${edit.text}${result.slice(edit.end)}`;
  }
  return result;
}

/** Az import beszúrása a meglévő import-blokkba (nem duplikál). */
export function insertImport(source, importLine) {
  if (source.includes(importLine)) return { source, added: false };
  const lines = source.split('\n');
  const imports = lines
    .map((line, index) => ({ line, index }))
    .filter((entry) => /^import\s+['"]/.test(entry.line));
  if (!imports.length) {
    const insertAt = lines.findIndex((line) => line.trim() && !line.startsWith('//'));
    lines.splice(insertAt < 0 ? 0 : insertAt, 0, importLine, '');
    return { source: lines.join('\n'), added: true };
  }
  const relatives = imports.filter((entry) => /^import\s+'\.\.?\//.test(entry.line));
  const pool = relatives.length ? relatives : imports;
  const target = pool.find((entry) => entry.line.localeCompare(importLine) > 0);
  const at = target ? target.index : pool[pool.length - 1].index + 1;
  lines.splice(at, 0, importLine);
  return { source: lines.join('\n'), added: true };
}

/** Egy fájl teljes átalakítása (a tesztek ezt hívják). */
export function transformSource(source, file = 'lib/x.dart') {
  const { edits, appText, tr } = planEdits(source, file);
  if (!edits.length) return { source, appText, tr, changed: 0 };
  let updated = applyEdits(source, edits);
  if (appText) updated = insertImport(updated, relativeImportFor(file, APP_TEXT_IMPORT)).source;
  if (tr) updated = insertImport(updated, relativeImportFor(file, TR_IMPORT)).source;
  return { source: updated, appText, tr, changed: edits.length };
}

export function selfTest() {
  const checks = [];
  const check = (label, ok) => checks.push({ label, ok });

  const one = transformSource("            Text('Közösség'),\n", 'lib/a.dart');
  check('a Text AppText-re cserélődik', one.source.includes("AppText('Közösség')"));
  check('a Text-hez AppText import kerül', one.source.includes("import 'widgets/app_text.dart';"));
  check('a tr import NEM kerül be feleslegesen', !one.source.includes('i18n/tr.dart'));

  const multi = transformSource("            Text(\n              'Közösség',\n            ),\n", 'lib/a.dart');
  check('a TÖBBSOROS Text( is AppText lesz', multi.source.includes('AppText(\n'));
  check('a többsoros szöveg nem változik', multi.source.includes("'Közösség',"));

  const tooltip = transformSource("  tooltip: 'Értesítések',\n", 'lib/a.dart');
  check('a nevesített paraméter tr(...) lesz', tooltip.source.includes("tooltip: tr(context, 'Értesítések'),"));
  check('a tr-hez tr import kerül', tooltip.source.includes("import 'core/i18n/tr.dart';"));

  const already = "            Text(tr(context, 'Közösség')),\n";
  check('a már körbefordított sor nem változik', transformSource(already, 'lib/a.dart').changed === 0);

  const constLine = transformSource("    const Text('Közösség'),\n", 'lib/a.dart');
  check('a const megmarad (AppText)', constLine.source.includes("const AppText('Közösség')"));

  const selectable = transformSource("  SelectableText('Közösség'),\n", 'lib/a.dart');
  check(
    'a SelectableText szövege tr(...) lesz (nem AppText)',
    selectable.source.includes("SelectableText(tr(context, 'Közösség'))"),
  );

  const two = transformSource("  label: 'Első',\n  child: Text('Második'),\n", 'lib/a.dart');
  check(
    'két találat egy fájlban helyesen cserélődik',
    two.source.includes("label: tr(context, 'Első'),") && two.source.includes("AppText('Második')"),
  );

  check(
    'a relativ import út jó (mély fájl)',
    relativeImportFor('lib/screens/community/community_screen.dart', APP_TEXT_IMPORT)
      === "import '../../widgets/app_text.dart';",
  );
  check(
    'a relativ import út jó (gyökér)',
    relativeImportFor('lib/main.dart', TR_IMPORT) === "import 'core/i18n/tr.dart';",
  );

  const source = "import 'dart:async';\n\nimport '../../widgets/event_card.dart';\n\nvoid main() {}\n";
  const inserted = insertImport(source, "import '../../widgets/app_text.dart';");
  check('az import bekerül', inserted.added && inserted.source.includes('app_text.dart'));
  check(
    'az import ábécésorrendben kerül be',
    inserted.source.indexOf('app_text.dart') < inserted.source.indexOf('event_card.dart'),
  );
  check('a másodszori beszúrás nem duplikál', insertImport(inserted.source, "import '../../widgets/app_text.dart';").added === false);

  check('az offset-számítás jó', offsetOf('aaa\nbbb\nccc', 2, 1) === 5);
  return checks;
}

function main() {
  if (process.argv.includes('--self-test')) {
    const checks = selfTest();
    for (const check of checks) console.log(`${check.ok ? 'OK  ' : 'HIBA'} ${check.label}`);
    const failed = checks.filter((check) => !check.ok).length;
    console.log(`\n${checks.length - failed}/${checks.length} önteszt rendben`);
    return failed ? 1 : 0;
  }

  const apply = process.argv.includes('--apply');
  const files = [];
  (function walk(dir) {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      const full = path.join(dir, entry.name).replaceAll('\\', '/');
      if (entry.isDirectory()) walk(full);
      else if (entry.name.endsWith('.dart')) files.push(full);
    }
  })('lib');

  let appText = 0;
  let tr = 0;
  let filesChanged = 0;
  const report = [];
  for (const file of files) {
    const source = fs.readFileSync(file, 'utf8');
    const result = transformSource(source, file);
    if (!result.changed) continue;
    if (apply) fs.writeFileSync(file, result.source, 'utf8');
    appText += result.appText;
    tr += result.tr;
    filesChanged += 1;
    report.push({ file, changed: result.changed, appText: result.appText, tr: result.tr });
  }

  report.sort((a, b) => b.changed - a.changed);
  if (process.argv.includes('--report')) {
    for (const entry of report) {
      console.log(`  ${String(entry.changed).padStart(3)}  ${entry.file}  (AppText ${entry.appText}, tr ${entry.tr})`);
    }
  }
  console.log(
    `${apply ? 'ALKALMAZVA' : '[száraz]'} fájl: ${filesChanged}, `
    + `AppText-csere: ${appText}, tr(...)-csere: ${tr}, összesen: ${appText + tr}`,
  );
  if (!apply) console.log('Az íráshoz add hozzá a --apply kapcsolót.');
  return 0;
}

if (process.argv[1] && process.argv[1].endsWith('wrap-ui-strings.mjs')) {
  process.exitCode = main();
}
