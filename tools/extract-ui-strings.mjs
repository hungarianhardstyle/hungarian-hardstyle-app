#!/usr/bin/env node
/**
 * A fordításra szánt UI-szövegek kigyűjtése a `lib/`-ből.
 *
 * A szótár kulcsa a **magyar szöveg**, ezért a kulcshalmazt a kódból kell
 * venni — kézzel összeírt lista elavulna. Ugyanezeket a szabályokat használja a
 * körbefordító (`wrap-ui-strings.mjs`), így a szótár és a kód nem húzhat szét.
 *
 * Használat:
 *   node tools/extract-ui-strings.mjs                # összegzés
 *   node tools/extract-ui-strings.mjs --json         # teljes kulcslista (stdout)
 *   node tools/extract-ui-strings.mjs --write        # tmp/i18n/keys.json + chunkok
 *   node tools/extract-ui-strings.mjs --self-test
 */
import fs from 'node:fs';
import path from 'node:path';

import {
  EXCLUDED_FILES,
  dartFiles,
  isTranslationTarget,
  isUiLayerFile,
  isUiLayerTarget,
  isWrappedContext,
  stringLiterals,
} from './lib/i18n-targets.mjs';

/** A `keys.json` és a chunk-könyvtár helye. */
export const KEYS_PATH = 'tmp/i18n/keys.json';
export const CHUNK_DIR = 'tmp/i18n/chunks';
export const CHUNK_SIZE = 60;

/**
 * A Dart a **szomszédos** string-literálokat összefűzi (`'a ' 'b'` → `'a b'`), a
 * vesszővel elválasztottakat viszont nem. A futásidejű szöveg ezért a fűzött
 * változat, és a szótárnak **azt** kell ismernie — különben a fordítás csendben
 * nem érvényesül (mérve: 10 ilyen hely volt a 361/362-ben).
 *
 * @returns {{value: string, endLine: number, endColumn: number}|null} a fűzött
 *   érték és az UTOLSÓ töredék vége, ha a literál többsoros fűzésben áll.
 */
export function joinedLiteral(lines, index, literal) {
  // CSAK akkor fűzés, ha a literál után a sorban nincs más (főleg **vessző** nem).
  if (lines[index].slice(literal.end).trim() !== '') return null;

  let value = literal.value;
  let endLine = index;
  let endColumn = literal.end;
  let cursor = index;

  while (cursor + 1 < lines.length) {
    const next = lines[cursor + 1];
    if (!/^\s*'/.test(next) && !/^\s*"/.test(next)) break;
    const [part] = stringLiterals(next);
    if (!part || part.start !== next.search(/['"]/)) break;
    value += part.value;
    cursor += 1;
    endLine = cursor;
    endColumn = part.end;
    if (next.slice(part.end).trim() !== '') break;
  }

  if (endLine === index) return null;
  return { value, endLine, endColumn };
}
/**
 * A literal ELŐTTI kontextus: az adott sor prefixe + az előző **nem üres** sorok
 * (legfeljebb 120 karakterig). Erre azért van szükség, mert a gyakori
 * `Text(\n  'szöveg',\n)` alakban a `Text(` egy korábbi sorban van.
 */
export function contextBefore(lines, index, start, limit = 120) {
  let context = lines[index].slice(0, start);
  for (let back = index - 1; back >= 0 && context.length < limit; back -= 1) {
    const previous = lines[back].trim();
    if (!previous || previous.startsWith('//')) break;
    context = `${previous} ${context}`;
  }
  return context;
}

/**
 * A fűzési csoport FOLYTATÁSA-e ez a sor?
 *
 * ⚠️ MIÉRT KELL (mért hiba, 2026-09-25): a Dart a szomszédos literálokat
 * összefűzi, ezért a **csoport első** tagja a futásidejű szöveg. Ha a folytatásokat
 * is külön célnak vesszük, a bekötő **darabokra vágja** a szöveget:
 *   `'A ' tr(context, 'B ') tr(context, 'C')` → szintaktikai hiba (519 hiba).
 */
export function isContinuation(lines, index) {
  if (index === 0) return false;
  const previous = lines[index - 1];
  const parts = stringLiterals(previous);
  if (parts.length !== 1) return false;
  return previous.slice(parts[0].end).trim() === '' && /^\s*['"]/.test(lines[index]);
}

/** Egy fájl összes célzott literálja (sorrendben, ismétlődéssel). */
export function targetsInSource(source, file = '') {
  const hits = [];
  const lines = source.split('\n');
  for (let index = 0; index < lines.length; index += 1) {
    const line = lines[index];
    const trimmed = line.trimStart();
    if (trimmed.startsWith('//') || trimmed.startsWith('///')) continue;
    // A fűzési csoport folytatása nem önálló cél (a csoport első tagja az).
    if (isContinuation(lines, index)) continue;
    for (const literal of stringLiterals(line)) {
      const before = contextBefore(lines, index, literal.start);
      // ⚠️ A Dart a szomszédos literálokat ÖSSZEFŰZI: a **futásidejű** szöveg a
      // fűzött változat, ezért a szótár kulcsa is az (különben a fordítás csendben
      // nem érvényesül — mérve 10 ilyen hely volt a 361/362-ben).
      const joined = joinedLiteral(lines, index, literal);
      const value = joined ? joined.value : literal.value;
      const after = joined
        ? lines[joined.endLine].slice(joined.endColumn)
        : line.slice(literal.end);
      const uiLayer = isUiLayerFile(file)
        && isUiLayerTarget({ value, before, after });
      if (!isTranslationTarget({ value, before }) && !uiLayer) continue;
      // ⚠️ A `uiLayerOnly` jelző: az ilyen szöveg CSAK a UI-réteg szabályával cél,
      // és a bekötése **hatókör-felismerést** igényel (van-e `BuildContext` a
      // környező metódusban). A soronkénti bekötő ezért **kihagyja** — mérve: a
      // vak szabály 501 cserét és **402 hibát** adott (mező-inicializálók,
      // `const`-helyek), ezért a második kör külön, hatókör-felismerő körben megy.
      const uiLayerOnly = uiLayer && !isTranslationTarget({ value, before });
      hits.push({
        file,
        line: index + 1,
        value,
        quote: literal.quote,
        start: literal.start,
        end: joined ? joined.endColumn : literal.end,
        // A fűzött töredékeket EGYÜTT kell bekötni (a `tr(context, 'a' 'b')`
        // érvényes, a `tr(context, 'a') 'b'` viszont nem).
        spansLines: joined ? joined.endLine - index : 0,
        uiLayerOnly,
        // Már be van kötve (`tr(context, …)` / `AppText(…)`) → kulcs, de nem
        // szerkesztendő. A wrapper ezt a jelzőt használja az idempotenciához.
        wrapped: isWrappedContext(before) || /(?:^|[\s(,{[])(?:AppText)\s*\(\s*$/.test(before),
      });
    }
  }
  return hits;
}

/** Az összes célzott literál a `lib/`-ben. */
export function collectTargets(root = 'lib') {
  const hits = [];
  for (const file of dartFiles(root)) {
    if (EXCLUDED_FILES.includes(file)) continue;
    hits.push(...targetsInSource(fs.readFileSync(file, 'utf8'), file));
  }
  return hits;
}

/** Egyedi szövegek + előfordulásaik. */
export function uniqueKeys(hits) {
  const map = new Map();
  for (const hit of hits) {
    const entry = map.get(hit.value);
    if (entry) entry.count += 1;
    else map.set(hit.value, { value: hit.value, count: 1, files: new Set([hit.file]) });
    map.get(hit.value).files.add(hit.file);
  }
  return [...map.values()]
    .map((entry) => ({ value: entry.value, count: entry.count, files: [...entry.files].sort() }))
    .sort((a, b) => (b.count - a.count) || a.value.localeCompare(b.value, 'hu'));
}

/** Chunkokba osztás (a fordítás párhuzamosítható legyen). */
export function chunkKeys(keys, size = CHUNK_SIZE) {
  const chunks = [];
  for (let index = 0; index < keys.length; index += size) {
    chunks.push(keys.slice(index, index + size));
  }
  return chunks;
}

export function selfTest() {
  const checks = [];
  const check = (label, ok) => checks.push({ label, ok });

  const hit = (line) => targetsInSource(line, 'x.dart');
  check('a Text(...) szövege cél', hit("            Text('Közösség'),").length === 1);
  check('a label: szövege cél', hit("  label: 'Közösség',").length === 1);
  check('a tooltip: szövege cél', hit("  tooltip: 'Értesítések',").length === 1);
  check('az interpolált szöveg NEM cél', hit("            Text('Szia \$nev'),").length === 0);
  check('az URL NEM cél', hit("  label: 'https://pelda.hu/hir',").length === 0);
  check('az útvonal NEM cél', hit("  label: 'assets/images/x.png',").length === 0);
  check('az azonosító (snake_case) NEM cél', hit("  label: 'live_feed_posts',").length === 0);
  check('a sima azonosító NEM cél', hit("  label: 'home',").length === 0);
  check('a megjegyzésben lévő szöveg NEM cél', hit("    // Text('Közösség')").length === 0);
  check('az egyszavas ékezetes szöveg cél', hit("            Text('Törlés'),").length === 1);
  check('a nagybetűs egyszó cél (Vissza)', hit("            Text('Vissza'),").length === 1);
  check('a kisbetűs azonosító NEM cél', hit("  label: 'vissza',").length === 0);
  check('a csupa nagybetűs kód NEM cél', hit("  label: 'EN',").length === 0);
  check(
    'a TÖBBSOROS Text( is cél',
    hit("            Text(\n              'Közösség',").length === 1,
  );
  check('az escape-elt szöveg NEM cél', hit(String.raw`  label: 'Első sor\nMásodik',`).length === 0);
  check(
    'a MÁR bekötött sablon is kulcs (a # nem szűri ki)',
    hit("  trArgs(context, 'Beküldés #{id}', {'id': '1'})").length === 1,
  );
  check(
    'a nem-UI kontextus NEM cél',
    hit("  final x = 'Közösség és barátai';").length === 0,
  );
  check('a chat üzenet fájlja kizárt', EXCLUDED_FILES.includes('lib/widgets/chat_message_text.dart'));

  const chunks = chunkKeys([{ value: 'a' }, { value: 'b' }, { value: 'c' }], 2);
  check('a chunkolás helyes', chunks.length === 2 && chunks[1].length === 1);
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

  const hits = collectTargets();
  const keys = uniqueKeys(hits);

  if (process.argv.includes('--json')) {
    console.log(JSON.stringify(keys, null, 2));
    return 0;
  }

  if (process.argv.includes('--write')) {
    fs.mkdirSync(path.dirname(KEYS_PATH), { recursive: true });
    fs.writeFileSync(KEYS_PATH, `${JSON.stringify(keys, null, 2)}\n`, 'utf8');
    fs.rmSync(CHUNK_DIR, { recursive: true, force: true });
    fs.mkdirSync(CHUNK_DIR, { recursive: true });
    const chunks = chunkKeys(keys);
    chunks.forEach((chunk, index) => {
      const name = `chunk-${String(index + 1).padStart(2, '0')}.json`;
      fs.writeFileSync(
        path.join(CHUNK_DIR, name),
        `${JSON.stringify(chunk.map((entry) => entry.value), null, 2)}\n`,
        'utf8',
      );
    });
    console.log(`kulcsok: ${keys.length} → ${KEYS_PATH}`);
    console.log(`chunkok: ${chunks.length} db (${CHUNK_SIZE} szöveg/chunk) → ${CHUNK_DIR}`);
    const characters = keys.reduce((sum, entry) => sum + [...entry.value].length, 0);
    console.log(`összes karakter: ${characters}`);
    return 0;
  }

  const perFile = new Map();
  for (const hit of hits) perFile.set(hit.file, (perFile.get(hit.file) ?? 0) + 1);
  const characters = keys.reduce((sum, entry) => sum + [...entry.value].length, 0);
  console.log(`célzott literál: ${hits.length} db, ${perFile.size} fájlban`);
  console.log(`egyedi szöveg: ${keys.length} (${characters} karakter)`);
  console.log('\na 12 leggyakoribb:');
  for (const entry of keys.slice(0, 12)) {
    console.log(`  ${String(entry.count).padStart(3)}×  ${JSON.stringify(entry.value)}`);
  }
  console.log('\na 10 legtöbb szöveget tartalmazó fájl:');
  for (const [file, count] of [...perFile.entries()].sort((a, b) => b[1] - a[1]).slice(0, 10)) {
    console.log(`  ${String(count).padStart(3)}  ${file}`);
  }
  return 0;
}

if (process.argv[1] && process.argv[1].endsWith('extract-ui-strings.mjs')) {
  process.exitCode = main();
}
