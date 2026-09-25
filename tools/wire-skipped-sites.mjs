#!/usr/bin/env node
/**
 * A **kimaradt** (nincs `BuildContext` a hatókörben) UI-szövegek bekötése a
 * `context` nélküli fordítóval (`AppStrings.tr(…)`).
 *
 * MIÉRT KÜLÖN ESZKÖZ: a `tools/wrap-ui-strings.mjs` szándékosan kihagyja ezeket
 * (a `context`-es alak ott nem fordítható le). A `context` nélküli alak viszont
 * **mindenhol** működik — az érték a hívás pillanatában fordul.
 *
 * ⚠️ AMI NEM MEGY EZZEL: az **állandó kifejezésben** álló szöveg (osztály-szintű
 * `static const` térkép/lista, top-level `const`). Ott a `AppStrings.tr(…)`
 * hívást a fordító elutasítja (`const_eval_method_invocation`). Azt **nem**
 * találgatjuk: az **analyzer** mondja meg, és az eszköz azokat a helyeket
 * **visszaállítja** — ezekhez a fordítás a **megjelenítés helyén** kell
 * (`AppText(…)` a nézetben). A visszaállított helyek listája a kimenet.
 *
 * ⚠️ A VISSZAÁLLÍTÁS POZÍCIÓ-KEZELÉSE (mért hibaosztály): a beszúrt hívások
 * eltolják a pozíciókat, ezért minden bekötés **egyedi jelölőt** kap
 * (`/*i18n-skip*​/`), az analyzer hibájából pedig a **legközelebbi előtte lévő
 * jelölőig** lépünk vissza — így nem kell pozíciót számolni.
 *
 * Használat:
 *   node tools/wire-skipped-sites.mjs             # száraz (csak jelent)
 *   node tools/wire-skipped-sites.mjs --apply     # beköt + visszaállít (körről körre)
 *   node tools/wire-skipped-sites.mjs --cleanup   # a jelölők eltávolítása
 *   node tools/wire-skipped-sites.mjs --self-test
 */
import fs from 'node:fs';

import { analyzeErrors } from './fix-const-fallout.mjs';
import { ensureImport } from './fix-context-fallout.mjs';
import { dartFiles } from './lib/i18n-targets.mjs';
import { planEdits } from './wrap-ui-strings.mjs';

export const MARKER = '/*i18n-skip*/';

/** A konstans-kifejezésben hívott függvény hibaosztályai. */
export const CONST_ERROR_CODES = [
  'const_eval_method_invocation',
  'const_with_non_constant_argument',
  'invalid_constant',
  'non_constant_map_value',
  'non_constant_list_element',
  'non_constant_default_value',
  'const_constructor_param_type_mismatch',
];

/** A kimaradt helyek bekötése `AppStrings.tr(/*i18n-skip*​/'…')` alakra. */
export function planSkippedWraps(source, file) {
  const { skipped } = planEdits(source, file);
  return skipped.map((entry) => ({
    start: entry.start,
    end: entry.end,
    text: `AppStrings.tr(${MARKER}${entry.raw})`,
    line: entry.line,
    value: entry.value,
  }));
}

/** Sor + oszlop → abszolút pozíció (a konstans-hibákhoz). */
export function offsetOf(source, line, column) {
  let offset = 0;
  let current = 1;
  while (current < line) {
    const next = source.indexOf('\n', offset);
    if (next < 0) break;
    offset = next + 1;
    current += 1;
  }
  return offset + column - 1;
}

/** Egy string-literál (idézőjellel) átugrása: a záró idézőjel UTÁNI pozíció. */
export function skipStringLiteral(source, start) {
  const quote = source[start];
  let index = start + 1;
  while (index < source.length) {
    if (source[index] === '\\') {
      index += 2;
      continue;
    }
    if (source[index] === quote) return index + 1;
    index += 1;
  }
  return -1;
}

/** A hívás záró zárójelének pozíciója (string-literálok átugrásával). */
export function endOfCall(source, callStart) {
  const open = source.indexOf('(', callStart);
  if (open < 0) return -1;
  let depth = 0;
  let index = open;
  while (index < source.length) {
    const char = source[index];
    if (char === "'" || char === '"') {
      const next = skipStringLiteral(source, index);
      if (next < 0) return -1;
      index = next;
      continue;
    }
    if (char === '(') depth += 1;
    else if (char === ')') {
      depth -= 1;
      if (depth === 0) return index;
    }
    index += 1;
  }
  return -1;
}

/**
 * A hiba előtti **legközelebbi** jelölő visszaállítása: a
 * `AppStrings.tr(/*i18n-skip*​/'…')` helyére az eredeti literál kerül.
 *
 * ⚠️ Az analyzer a hívást jelzi (a `AppStrings`-nél vagy a `tr`-nél), ezért a
 * jelölő a hiba pozíciója **után** van — előbb azt keressük, és csak akkor
 * lépünk hátra, ha a kettő között záró zárójel van (az már másik hívás).
 *
 * @returns {{start: number, end: number, text: string}|null}
 */
export function rollbackEditFor(source, position) {
  let markerAt = source.indexOf(MARKER, position);
  const between = markerAt < 0 ? ')' : source.slice(position, markerAt);
  if (markerAt < 0 || between.includes(')')) markerAt = source.lastIndexOf(MARKER, position);
  if (markerAt < 0) return null;
  const callStart = source.lastIndexOf('AppStrings.tr(', markerAt);
  if (callStart < 0) return null;
  const literalStart = markerAt + MARKER.length;
  const close = endOfCall(source, callStart);
  if (close < 0 || close < literalStart) return null;
  return { start: callStart, end: close + 1, text: source.slice(literalStart, close) };
}

/** A jelölők eltávolítása (a bekötés után). */
export function stripMarkers(source) {
  return source.split(`AppStrings.tr(${MARKER}`).join('AppStrings.tr(');
}

export function selfTest() {
  const checks = [];
  const check = (label, ok) => checks.push({ label, ok });

  // ⚠️ UI-réteg fájl kell (a szabály csak ott cél): `lib/screens/…`, és olyan
  // szerkezet, ami valóban `uiLayerOnly` cél (a térkép-ÉRTÉK igen, az értékadás nem).
  const wraps = planSkippedWraps(
    "class A {\n  static const Map<String, String> labels = {\n    'a': 'Hiba történt',\n  };\n}\n",
    'lib/screens/x.dart',
  );
  check('a kimaradt helyre AppStrings.tr kerül', wraps.length === 1);
  check('a bekötés jelölőt kap', wraps[0].text.startsWith(`AppStrings.tr(${MARKER}`));
  check('a bekötés az eredeti literált tartja', wraps[0].text.endsWith("'Hiba történt')"));

  const applied = `static const t = AppStrings.tr(${MARKER}'Hiba történt');\n`;
  // Az analyzer a hívás elejét jelzi (a `AppStrings`-nél).
  const position = applied.indexOf('AppStrings.tr(');
  const rollback = rollbackEditFor(applied, position);
  check('a visszaállítás megtalálja a hívást', rollback !== null);
  check(
    'a visszaállítás az eredeti literált adja',
    rollback && `${applied.slice(0, rollback.start)}${rollback.text}${applied.slice(rollback.end)}`
      === "static const t = 'Hiba történt';\n",
  );
  // ⚠️ Záró zárójel a literálban: a hívás végét zárójel-számlálással kell megtalálni.
  const tricky = `final x = AppStrings.tr(${MARKER}'Ez (zárójel) van benne');\n`;
  const trickyEdit = rollbackEditFor(tricky, tricky.indexOf('AppStrings.tr('));
  check(
    'a zárójelet tartalmazó literál is helyesen áll vissza',
    trickyEdit && `${tricky.slice(0, trickyEdit.start)}${trickyEdit.text}${tricky.slice(trickyEdit.end)}`
      === "final x = 'Ez (zárójel) van benne';\n",
  );
  check('jelölő nélkül nincs visszaállítás', rollbackEditFor('final x = 1;', 5) === null);
  check('a jelölő eltűnik a tisztításkor', !stripMarkers(applied).includes(MARKER));
  check(
    'a tisztítás a hívást meghagyja',
    stripMarkers(applied).includes("AppStrings.tr('Hiba történt')"),
  );
  check('az offset-számítás jó', offsetOf('aaa\nbbb', 2, 2) === 5);
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

  const files = dartFiles('lib').map((file) => file.replaceAll('\\', '/'));
  const apply = process.argv.includes('--apply');

  if (process.argv.includes('--cleanup')) {
    let changed = 0;
    for (const file of files) {
      const source = fs.readFileSync(file, 'utf8');
      const cleaned = stripMarkers(source);
      if (cleaned === source) continue;
      fs.writeFileSync(file, cleaned, 'utf8');
      changed += 1;
    }
    console.log(`jelölő eltávolítva: ${changed} fájlból`);
    return 0;
  }

  // 1) A kimaradt helyek bekötése (ha még nincs bekötve).
  let planned = 0;
  const report = [];
  for (const file of files) {
    const source = fs.readFileSync(file, 'utf8');
    const edits = planSkippedWraps(source, file);
    if (!edits.length) continue;
    planned += edits.length;
    report.push({ file, count: edits.length });
    if (!apply) continue;
    let updated = source;
    for (const edit of [...edits].sort((a, b) => b.start - a.start)) {
      updated = `${updated.slice(0, edit.start)}${edit.text}${updated.slice(edit.end)}`;
    }
    updated = ensureImport(updated, file);
    fs.writeFileSync(file, updated, 'utf8');
  }
  console.log(`\nbekötendő kimaradt hely: ${planned} (${report.length} fájlban)`);
  for (const entry of report) console.log(`  ${String(entry.count).padStart(3)}  ${entry.file}`);
  if (!apply) {
    console.log('\n[száraz] az íráshoz add hozzá a --apply kapcsolót.');
    return 0;
  }

  // 2) A konstans-kifejezésben álló helyek visszaállítása — az analyzer mondja meg.
  const rolledBack = new Map();
  for (let round = 1; round <= 6; round += 1) {
    const { errors } = analyzeErrors('lib');
    const relevant = errors.filter((error) => CONST_ERROR_CODES.includes(error.code));
    console.log(`\n=== ${round}. kör: ${errors.length} hiba, ebből konstans-kifejezés: ${relevant.length} ===`);
    if (!relevant.length) break;
    const byFile = new Map();
    for (const error of relevant) {
      const source = fs.readFileSync(error.file, 'utf8');
      const position = offsetOf(source, error.line, error.column);
      const edit = rollbackEditFor(source, position);
      if (!edit) continue;
      if (!byFile.has(error.file)) byFile.set(error.file, new Map());
      byFile.get(error.file).set(edit.start, edit);
      rolledBack.set(`${error.file}:${error.line}`, {
        file: error.file,
        line: error.line,
        value: edit.text,
      });
    }
    if (!byFile.size) {
      console.log('  ⚠️ egy hibahelyhez sem találtam jelölőt — kézi vizsgálat kell.');
      break;
    }
    let reverted = 0;
    for (const [file, edits] of byFile) {
      let source = fs.readFileSync(file, 'utf8');
      for (const edit of [...edits.values()].sort((a, b) => b.start - a.start)) {
        source = `${source.slice(0, edit.start)}${edit.text}${source.slice(edit.end)}`;
        reverted += 1;
      }
      fs.writeFileSync(file, source, 'utf8');
    }
    console.log(`  visszaállítva: ${reverted} hely`);
  }

  // 3) A jelölők eltávolítása a megmaradt (helyes) bekötésekből.
  let cleaned = 0;
  for (const file of files) {
    const source = fs.readFileSync(file, 'utf8');
    const stripped = stripMarkers(source);
    if (stripped === source) continue;
    fs.writeFileSync(file, stripped, 'utf8');
    cleaned += 1;
  }
  console.log(`\njelölő eltávolítva: ${cleaned} fájlból`);
  if (rolledBack.size) {
    console.log('\n⚠️ A konstans-kifejezésben álló helyek (a fordítás a MEGJELENÍTÉS helyén kell):');
    for (const entry of rolledBack.values()) {
      console.log(`  ${entry.file}:${entry.line}  ${JSON.stringify(entry.value)}`);
    }
  }
  const { errors } = analyzeErrors('lib');
  console.log(`\nA körök végén: ${errors.length} hiba`);
  return errors.length ? 1 : 0;
}

if (process.argv[1] && process.argv[1].endsWith('wire-skipped-sites.mjs')) {
  process.exitCode = main();
}
