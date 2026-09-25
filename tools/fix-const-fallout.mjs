#!/usr/bin/env node
/**
 * A `tr(context, …)` bevezetése után megmaradt `const`-hibák javítása.
 *
 * MIÉRT ESZKÖZ ÉS NEM KÉZI MUNKA: a hibahelyeket a **fordító** adja meg
 * (`flutter analyze`), nem tippelünk. Minden hibahelyhez megkeressük a hozzá
 * tartozó, még nyitott `const` kifejezést, és **csak azt** a `const` kulcsszót
 * vesszük ki. A `const` elhagyása futásidőben nem változtat semmit (csak
 * fordítási optimalizálás), és a ciklus addig megy, amíg az analyzer hibát jelez
 * — így a láncolt (`const` a `const`-ban) esetek is lejönnek.
 *
 * Használat:
 *   node tools/fix-const-fallout.mjs             # száraz (csak jelent)
 *   node tools/fix-const-fallout.mjs --apply     # javít (körről körre)
 *   node tools/fix-const-fallout.mjs --self-test
 */
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';

/**
 * `flutter analyze lib` futtatása; a hibák kiolvasása.
 *
 * ⚠️ Nem csak a `error` sorokat olvassuk: a bekötés **info** szintű
 * `use_build_context_synchronously` jelzést és **warning** szintű
 * `unused_import`-ot is okozhat, és ettől a projekt „tiszta analyzer" mércéje
 * elromlik. Ezért a `diagnostics` **mindhárom** szintet tartalmazza, az
 * `errors` pedig változatlanul csak a hibákat (a meglévő hívók ezt várják).
 */
export function analyzeErrors(target = 'lib') {
  const result = spawnSync(`flutter analyze ${target}`, {
    encoding: 'utf8',
    shell: true,
    maxBuffer: 64 * 1024 * 1024,
  });
  const output = `${result.stdout ?? ''}${result.stderr ?? ''}`;
  const diagnostics = [];
  for (const line of output.split('\n')) {
    const match = /^\s*(error|warning|info)\s+-\s+(.*?)\s+-\s+(.*?):(\d+):(\d+)\s+-\s+(\S+)\s*$/.exec(line);
    if (!match) continue;
    diagnostics.push({
      severity: match[1],
      message: match[2],
      file: match[3].replaceAll('\\', '/'),
      line: Number(match[4]),
      column: Number(match[5]),
      code: match[6],
    });
  }
  const errors = diagnostics.filter((entry) => entry.severity === 'error');
  return { errors, diagnostics, output };
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
  return offset + column - 1;
}

const IDENT = /[A-Za-z0-9_$.]/;

/**
 * A megadott pozícióhoz tartozó, még nyitott `const` kulcsszó pozíciója.
 *
 * Hátulról indulunk: a hibát tartalmazó kifejezés nyitó zárójelét keressük
 * (a zárójel-párok visszafelé számolva), majd a konstruktor neve előtt nézzük a
 * `const`-ot. Ha ott nincs, kijjebb lépünk (a `const` a külső kifejezésen lehet).
 */
export function findConstKeyword(source, position) {
  let cursor = position;
  for (let depth = 0; depth < 12; depth += 1) {
    const open = enclosingOpenBracket(source, cursor);
    if (open < 0) return -1;
    // A nyitó zárójel előtti név (konstruktor) és a `const` keresése.
    let index = open - 1;
    while (index >= 0 && /\s/.test(source[index])) index -= 1;
    // ⚠️ TÍPUSOS literál: `<String, String>{ … }` — a zárójel előtt `>` áll, azt a
    // hozzá tartozó `<`-ig át kell ugrani (a mérés szerint a 35 const-hiba
    // többsége ilyen típusos térkép volt).
    if (source[index] === '>') {
      let depth = 0;
      for (; index >= 0; index -= 1) {
        if (source[index] === '>') depth += 1;
        else if (source[index] === '<') {
          depth -= 1;
          if (depth === 0) break;
        }
      }
      index -= 1;
      while (index >= 0 && /\s/.test(source[index])) index -= 1;
      // A deklaráció-előtag átugrása: `static const _labels = <…>{ … }`
      // (a `=` UTÁN áll a név, ezért először az `=`-t keressük).
      if (source[index] === '=') {
        index -= 1;
        while (index >= 0 && /\s/.test(source[index])) index -= 1;
        if (index >= 0 && IDENT.test(source[index])) {
          while (index >= 0 && IDENT.test(source[index])) index -= 1;
          while (index >= 0 && /\s/.test(source[index])) index -= 1;
        }
        if (index >= 4 && source.slice(index - 4, index + 1) === 'const') return index - 4;
      }
    }
    if (index >= 0 && IDENT.test(source[index])) {
      const tokenEnd = index;
      while (index >= 0 && IDENT.test(source[index])) index -= 1;
      // ⚠️ A gyűjtemény-literálnál (`const [ … ]`) a zárójel előtti szó maga a
      // `const` — ezt az első változat „konstruktor-névnek" hitte és elhagyta.
      if (source.slice(index + 1, tokenEnd + 1) === 'const') return index + 1;
    }
    while (index >= 0 && /\s/.test(source[index])) index -= 1;
    if (index >= 2 && source.slice(index - 4, index + 1) === 'const') {
      return index - 4;
    }
    // Nincs itt `const` — kijjebb lépünk (a `const` a befoglaló kifejezésen lehet).
    cursor = open;
  }
  return -1;
}

/** A pozíciót befoglaló, még nyitott zárójel ((), [], {}) pozíciója. */
export function enclosingOpenBracket(source, position) {
  let depth = 0;
  for (let index = position - 1; index >= 0; index -= 1) {
    const char = source[index];
    if (char === ')' || char === ']' || char === '}') {
      depth += 1;
      continue;
    }
    if (char === '(' || char === '[' || char === '{') {
      if (depth === 0) return index;
      depth -= 1;
    }
  }
  return -1;
}

/** A hibákhoz tartozó `const` eltávolítások (fájlonként, jobbról balra). */
export function planConstRemovals(errors) {
  const removals = new Map();
  for (const error of errors) {
    const source = fs.readFileSync(error.file, 'utf8');
    const position = offsetOf(source, error.line, error.column);
    const at = findConstKeyword(source, position);
    if (at < 0) continue;
    if (!removals.has(error.file)) removals.set(error.file, new Set());
    removals.get(error.file).add(at);
  }
  return removals;
}

/** A `missing_const_final_var_or_type` javítása: `final` beszúrása a név elé. */
export function planFinalInsertions(errors) {
  const insertions = new Map();
  for (const error of errors) {
    if (error.code !== 'missing_const_final_var_or_type') continue;
    const source = fs.readFileSync(error.file, 'utf8');
    const position = offsetOf(source, error.line, error.column);
    // A hiba a névre mutat: elé kerül a `final `.
    if (!insertions.has(error.file)) insertions.set(error.file, new Set());
    insertions.get(error.file).add(position);
  }
  return insertions;
}

export function selfTest() {
  const checks = [];
  const check = (label, ok) => checks.push({ label, ok });

  const one = "const Text(tr(context, 'x'))";
  check('az egyszerű const megtalálása', findConstKeyword(one, one.indexOf('tr(')) === 0);

  const outer = "const Column(children: [Text(tr(context, 'x'))])";
  check(
    'a külső const megtalálása (láncolt)',
    findConstKeyword(outer, outer.indexOf('tr(')) === 0,
  );

  const inner = "Column(children: [const Text(tr(context, 'x'))])";
  check(
    'a belső const megtalálása',
    findConstKeyword(inner, inner.indexOf('tr(')) === inner.indexOf('const'),
  );

  const list = "const [\n  Text(tr(context, 'x')),\n]";
  check('a const lista megtalálása', findConstKeyword(list, list.indexOf('tr(')) === 0);

  const typed = "static const _labels = <String, String>{\n  'a': AppStrings.tr('X'),\n};";
  check(
    'a TÍPUSOS literál const-ja is megtalálható',
    findConstKeyword(typed, typed.indexOf('AppStrings')) === typed.indexOf('const'),
  );

  const none = "Column(children: [Text(tr(context, 'x'))])";
  check('const nélkül nincs találat', findConstKeyword(none, none.indexOf('tr(')) === -1);

  check('az offset-számítás jó', offsetOf('abc\ndef', 2, 1) === 4);
  check(
    'a zárójel-keresés a legbelső nyitó zárójelet adja',
    enclosingOpenBracket('f(a, g(b))', 7) === 6 && enclosingOpenBracket('f(a, g(b))', 3) === 1,
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
  const maxRounds = Number(
    (process.argv.find((arg) => arg.startsWith('--rounds=')) ?? '--rounds=6').slice('--rounds='.length),
  );

  for (let round = 1; round <= maxRounds; round += 1) {
    const { errors } = analyzeErrors();
    console.log(`\n=== ${round}. kör: ${errors.length} hiba ===`);
    if (!errors.length) {
      console.log('Nincs több `const`-hiba.');
      return 0;
    }
    const counts = new Map();
    for (const error of errors) counts.set(error.code, (counts.get(error.code) ?? 0) + 1);
    for (const [code, count] of counts) console.log(`  ${code}: ${count}`);

    const removals = planConstRemovals(errors);
    let planned = 0;
    for (const set of removals.values()) planned += set.size;
    // ⚠️ A DEKLARÁCIÓBÓL lett `const` (`final`-lal helyettesítve) néha `final` NÉLKÜL
    // marad (a `const` a kifejezésen volt, nem a deklaráción) — az analyzer ezt
    // `missing_const_final_var_or_type` néven jelzi. Ilyenkor a név elé `final` kell.
    const insertions = planFinalInsertions(errors);
    let plannedFinal = 0;
    for (const set of insertions.values()) plannedFinal += set.size;
    console.log(`  tervezett const-eltávolítás: ${planned}, final-beszúrás: ${plannedFinal}`);
    if (!planned && !plannedFinal) {
      console.log('  ⚠️ egyik hibához sem találtam const kulcsszót — kézi vizsgálat kell.');
      return 1;
    }
    if (!apply) {
      console.log('  [száraz] az íráshoz add hozzá a --apply kapcsolót.');
      return 0;
    }
    // ⚠️ A két fajta javítás UGYANABBÓL a forrásból számolt pozíciókon ül, ezért
    // egy menetben, **jobbról balra** kell alkalmazni — különben az első írás
    // eltolja a második pozícióit.
    const files = new Set([...removals.keys(), ...insertions.keys()]);
    for (const file of files) {
      const removeAt = removals.get(file) ?? new Set();
      const insertAt = new Set([...(insertions.get(file) ?? [])].filter((at) => !removeAt.has(at)));
      const source = fs.readFileSync(file, 'utf8');
      let updated = source;
      const edits = [
        ...[...removeAt].map((at) => ({ kind: 'remove', at })),
        ...[...insertAt].map((at) => ({ kind: 'insert', at })),
      ].sort((a, b) => b.at - a.at);
      for (const edit of edits) {
        const at = edit.at;
        if (edit.kind === 'insert') {
          updated = `${updated.slice(0, at)}final ${updated.slice(at)}`;
          continue;
        }
        // ⚠️ DEKLARÁCIÓ (`const NAME = …`, `static const NAME = …`): itt a `const`
        // elvétele érvénytelen kódot ad (`static _x = …`), ezért **`final`-ra**
        // cseréljük. Kifejezésben (`const Foo(...)`, `const [...]`) viszont
        // elhagyjuk a kulcsszót.
        let cursor = at + 'const'.length;
        while (updated[cursor] === ' ') cursor += 1;
        const rest = updated.slice(cursor);
        const isDeclaration = /^[A-Za-z_$][A-Za-z0-9_$]*\s*=/.test(rest);
        if (isDeclaration) {
          updated = `${updated.slice(0, at)}final${updated.slice(at + 'const'.length)}`;
          continue;
        }
        let end = at + 'const'.length;
        while (updated[end] === ' ') end += 1;
        updated = `${updated.slice(0, at)}${updated.slice(end)}`;
      }
      if (updated !== source) fs.writeFileSync(file, updated, 'utf8');
    }
  }
  const { errors } = analyzeErrors();
  console.log(`\nA körök végén: ${errors.length} hiba`);
  return errors.length ? 1 : 0;
}

if (process.argv[1] && process.argv[1].endsWith('fix-const-fallout.mjs')) {
  process.exitCode = main();
}
