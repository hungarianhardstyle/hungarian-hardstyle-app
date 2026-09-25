#!/usr/bin/env node
/**
 * A `context`-hibák javítása: `tr(context, …)` → `AppStrings.tr(…)`.
 *
 * MIÉRT (mért, 2026-09-25): a hatókör-felismerő bekötő a UI-réteg 342 szövegét
 * kötötte be, és **~53 helyen** tévedett — ott nincs `BuildContext` (statikus
 * segédfüggvény, illetve **osztály-szintű `const` inicializáló**, ahol a
 * `context` példány-mezőre hivatkozna). Ahelyett hogy ezeket visszavonnánk, a
 * **kontextus nélküli** fordítót használjuk: az érték a hívás pillanatában
 * fordul (jellemzően `build` közben), és nem kell `context`.
 *
 * A hibákat az **analyzer** adja (nem tippelünk): a `'context'`-et említő
 * hibahelyeken a megelőző `tr(`/`trArgs(` hívást írjuk át.
 *
 * Használat:
 *   node tools/fix-context-fallout.mjs            # száraz (csak jelent)
 *   node tools/fix-context-fallout.mjs --apply     # javít (körről körre)
 *   node tools/fix-context-fallout.mjs --self-test
 */
import fs from 'node:fs';

import { analyzeErrors, offsetOf } from './fix-const-fallout.mjs';

export const APP_STRINGS_IMPORT = "import '../core/i18n/app_strings.dart';";

/**
 * A `'context'`-et említő hibák (ezek a mi esetünk).
 *
 * ⚠️ Az `instance_member_access_from_static` szövege **nem** tartalmazza a
 * `context` szót, pedig pont ez a hiba: statikus metódusban a `context`
 * példány-mezőre hivatkozik (mért kihagyás: 2 hely).
 *
 * ⚠️ A bekötött `tr(context, …)` **`await` utáni** helyeken `info` szintű
 * `use_build_context_synchronously` jelzést ad (mért: 12 hely) — ez nem hiba,
 * de a projekt mércéje a tiszta analyzer, ezért ugyanígy `AppStrings.tr`-re
 * váltunk (ott nincs `context`, tehát a jelzés is elmúlik).
 */
export function contextErrors(errors) {
  return errors.filter(
    (error) => /context/i.test(error.message)
      || error.code === 'instance_member_access_from_static'
      || error.code === 'use_build_context_synchronously',
  );
}

/**
 * A bekötés után **feleslegessé vált** `tr.dart` importok.
 *
 * MIÉRT: ha egy fájlban minden `tr(context, …)` `AppStrings.tr(…)`-re váltott,
 * a `tr.dart` import használatlan marad (`unused_import` warning) — a mért
 * eset 2 fájl (`achievement_service.dart`, `chat_mention_plan.dart`).
 */
export function unusedTrImports(diagnostics) {
  return diagnostics.filter(
    (entry) => entry.code === 'unused_import' && /tr\.dart/.test(entry.message),
  );
}

/**
 * A `tr(context, …)` → `AppStrings.tr(…)` átírás egy pozíción.
 *
 * ⚠️ A `context` **argumentumot is el kell vinni** (mért hiba: az első változat
 * csak a `tr(`-t írta át, így `AppStrings.tr(context, 'X')` maradt — az
 * `AppStrings.tr` viszont **egy** paraméteres, ezért új hiba lett belőle).
 */
export function rewriteAt(source, position) {
  const window = source.slice(Math.max(0, position - 24), position);
  const match = /\btr(Args)?\(\s*$/.exec(window);
  if (!match) return null;
  const name = match[1] ? 'AppStrings.trArgs' : 'AppStrings.tr';
  const start = position - window.length + match.index;
  // A `context` + a mögötte álló vessző és szóközök elvitele.
  let end = position + 'context'.length;
  while (source[end] === ' ' || source[end] === '\t') end += 1;
  if (source[end] !== ',') return null;
  end += 1;
  while (source[end] === ' ' || source[end] === '\t') end += 1;
  return { start, end, text: `${name}(` };
}

/** Az import biztosítása (a fájl `lib/…` alatt van). */
export function ensureImport(source, file) {
  const depth = file.replace(/\\/g, '/').split('/').length - 2; // lib/ után hány szint
  const relative = `${'../'.repeat(depth)}core/i18n/app_strings.dart`;
  const line = `import '${relative}';`;
  if (source.includes(line)) return source;
  const lines = source.split('\n');
  const imports = lines
    .map((text, index) => ({ text, index }))
    .filter((entry) => /^import\s+['"]/.test(entry.text));
  if (!imports.length) return `${line}\n${source}`;
  const relatives = imports.filter((entry) => /^import\s+'\.\.?\//.test(entry.text));
  const pool = relatives.length ? relatives : imports;
  const target = pool.find((entry) => entry.text.localeCompare(line) > 0);
  const at = target ? target.index : pool[pool.length - 1].index + 1;
  lines.splice(at, 0, line);
  return lines.join('\n');
}

/**
 * A feleslegessé vált `tr.dart` import sor eltávolítása (a fájlban legfeljebb egy
 * ilyen sor van, mert az `insertImport` nem duplikál).
 */
export function removeUnusedTrImport(source, file) {
  const depth = file.replace(/\\/g, '/').split('/').length - 2;
  const line = `import '${'../'.repeat(depth)}core/i18n/tr.dart';`;
  if (!source.includes(line)) return { source, removed: false };
  // ⚠️ Csak akkor vesszük ki, ha tényleg nincs benne `tr(`/`trArgs(` hívás:
  // a `tr.dart` a `tr`/`trArgs` **top-level** függvényeket adja. A negatív
  // lookbehind azért kell, mert a `AppStrings.tr(` is illeszkedne a `\btr\(`-re
  // (mért hiba: az első változat ezért nem távolított el semmit).
  if (/(?<![.\w$])tr(Args)?\s*\(/.test(source)) return { source, removed: false };
  const lines = source.split('\n');
  // ⚠️ A fájlok egy része **CRLF** sorvégű (mért: `chat_mention_plan.dart`), ezért
  // a szigorú egyezés `\r` miatt elbukna — a sor **levágott** alakját hasonlítjuk.
  const at = lines.findIndex((entry) => entry.trim() === line);
  if (at < 0) return { source, removed: false };
  lines.splice(at, 1);
  return { source: lines.join('\n'), removed: true };
}

export function selfTest() {
  const checks = [];
  const check = (label, ok) => checks.push({ label, ok });
  const source = "    label: tr(context, 'Mentés'),";
  const position = source.indexOf('context');
  const edit = rewriteAt(source, position);
  check('a tr(context, …) átírása', edit?.text === 'AppStrings.tr(');
  check(
    'a `context` argumentum is elmegy',
    edit && `${source.slice(0, edit.start)}${edit.text}${source.slice(edit.end)}` === "    label: AppStrings.tr('Mentés'),",
  );
  const args = "    x: trArgs(context, '{n} nap', {'n': '1'}),";
  const argsEdit = rewriteAt(args, args.indexOf('context'));
  check('a trArgs átírása', argsEdit?.text === 'AppStrings.trArgs(');
  check(
    'a trArgs-nál is elmegy a context',
    argsEdit && `${args.slice(0, argsEdit.start)}${argsEdit.text}${args.slice(argsEdit.end)}`
      === "    x: AppStrings.trArgs('{n} nap', {'n': '1'}),",
  );
  check('a nem-tr hívás nem találat', rewriteAt('foo(context, 1)', 3) === null);
  check(
    'az import bekerül a mélységnek megfelelően',
    ensureImport("import 'x.dart';\n", 'lib/screens/a/b.dart').includes("import '../../core/i18n/app_strings.dart';"),
  );
  check('a meglévő importot nem duplikálja', (() => {
    const once = ensureImport("import 'a.dart';\n", 'lib/screens/b.dart');
    return ensureImport(once, 'lib/screens/b.dart') === once;
  })());
  const unused = removeUnusedTrImport(
    "import 'a.dart';\nimport '../core/i18n/tr.dart';\n\nconst x = 1;\n",
    'lib/services/x.dart',
  );
  check('a feleslegessé vált tr-import eltűnik', unused.removed && !unused.source.includes('tr.dart'));
  const kept = removeUnusedTrImport(
    "import '../core/i18n/tr.dart';\n\nfinal y = tr(context, 'A');\n",
    'lib/services/x.dart',
  );
  check('a használt tr-import MEGMARAD', !kept.removed && kept.source.includes('tr.dart'));
  const appStrings = removeUnusedTrImport(
    "import '../core/i18n/tr.dart';\n\nfinal z = AppStrings.tr('A');\n",
    'lib/services/x.dart',
  );
  check(
    'az AppStrings.tr( nem téveszti meg (a tr-import kimegy)',
    appStrings.removed && !appStrings.source.includes('tr.dart'),
  );
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
  const maxRounds = 4;
  for (let round = 1; round <= maxRounds; round += 1) {
    const { errors, diagnostics } = analyzeErrors('lib');
    const relevant = contextErrors(diagnostics);
    const unused = unusedTrImports(diagnostics);
    console.log(
      `\n=== ${round}. kör: ${errors.length} hiba, ebből context-es: ${relevant.length},`
      + ` felesleges tr-import: ${unused.length} ===`,
    );
    if (!relevant.length && !unused.length) {
      console.log('Nincs több `context`-hiba és felesleges import.');
      return 0;
    }
    if (!apply) {
      for (const error of relevant.slice(0, 5)) console.log(`  ${error.file}:${error.line}:${error.column}`);
      console.log('  [száraz] az íráshoz add hozzá a --apply kapcsolót.');
      return 0;
    }

    const byFile = new Map();
    for (const error of relevant) {
      const source = fs.readFileSync(error.file, 'utf8');
      const position = offsetOf(source, error.line, error.column);
      const edit = rewriteAt(source, position);
      if (!edit) continue;
      if (!byFile.has(error.file)) byFile.set(error.file, new Map());
      byFile.get(error.file).set(edit.start, edit);
    }
    let changed = 0;
    for (const [file, edits] of byFile) {
      let source = fs.readFileSync(file, 'utf8');
      for (const edit of [...edits.values()].sort((a, b) => b.start - a.start)) {
        source = `${source.slice(0, edit.start)}${edit.text}${source.slice(edit.end)}`;
        changed += 1;
      }
      source = ensureImport(source, file);
      fs.writeFileSync(file, source, 'utf8');
    }
    console.log(`  átírva: ${changed} hívás, ${byFile.size} fájlban`);
    let removed = 0;
    for (const entry of new Set(unused.map((diagnostic) => diagnostic.file))) {
      const source = fs.readFileSync(entry, 'utf8');
      const result = removeUnusedTrImport(source, entry);
      if (!result.removed) continue;
      fs.writeFileSync(entry, result.source, 'utf8');
      removed += 1;
    }
    if (removed) console.log(`  felesleges tr-import eltávolítva: ${removed} fájlból`);
  }
  const { errors } = analyzeErrors('lib');
  console.log(`\nA körök végén: ${errors.length} hiba`);
  return errors.length ? 1 : 0;
}

if (process.argv[1] && process.argv[1].endsWith('fix-context-fallout.mjs')) {
  process.exitCode = main();
}
