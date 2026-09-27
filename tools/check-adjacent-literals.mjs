#!/usr/bin/env node
/**
 * **Összefűzött (több sorra tördelt) szöveg-literálok** ellenőrzése — a projekt
 * „A" hibaosztálya.
 *
 * MIÉRT KELL: az i18n-extraktor (`tools/extract-ui-strings.mjs`) egy több sorra
 * tördelt, **szomszédos literál** (Dart implicit összefűzés) esetén csak az
 * **első** darabot látja, ezért a `keys.json`-ba egy **töredék** kerül. A
 * futásidő viszont a **teljes** szöveget keresi a szótárban: ha a teljes szöveg
 * nincs kulcsként benne, angol felületen a szöveg **magyarul marad** — miközben
 * minden kapu zöld. Ez a hiba kétszer is megtörtént (374: nyers feliratok;
 * 376: egy felugró és egy saját képernyő szövege).
 *
 * A SZABÁLY: egy összefűzött literál-lánc **teljes** szövege legyen kulcs a
 * szótárban (`assets/i18n/en.json`). Ahol ez teljesül, az összefűzés rendben van
 * (a kézzel írt chunk adja a teljes kulcsot) — a szonda ezt **kimondja**, nem
 * csak elhallgatja.
 *
 * ⚠️ A `$`-t (interpolációt) tartalmazó lánc **kihagyva**: az futásidejű érték
 * (dátum, szám), nem szótár-kulcs.
 *
 * Használat:
 *   node tools/check-adjacent-literals.mjs          # kapu (exit 1, ha hiba)
 *   node tools/check-adjacent-literals.mjs --list   # a rendben lévők is
 */
import fs from 'node:fs';
import path from 'node:path';

const ROOTS = ['lib'];
const DICTIONARY_PATH = 'assets/i18n/en.json';

/** A kivételek: szándékos, nem feliratot adó összefűzés (névre szólón, indoklással). */
const EXEMPT = [
  {
    file: 'lib/services/wordpress_service.dart',
    reason: 'a szerveroldali válaszra illesztő rész-szövegek (nem feliratok)',
  },
  {
    file: 'lib/core/content/html_text.dart',
    reason: 'HTML-entitás táblák és tisztítás (nem feliratok)',
  },
];

/** Egy sor, ami CSAK egy literál (esetleg záró elválasztóval/zárójellel). */
const LITERAL_ONLY = /^'([^'\\]|\\.)*'[,;)\]]*$/;
/** Egy sor, ami CSAK egy literál, **elválasztó nélkül** (folytatás közepe). */
const LITERAL_INTERIOR = /^'([^'\\]|\\.)*'$/;
/** Egy sor, ami literállal **végződik** (a lánc első sora lehet: `return '…'`). */
const LITERAL_AT_END = /'([^'\\]|\\.)*'\s*$/;

/**
 * A Dart escape-ek feloldása.
 *
 * ⚠️ MIÉRT KELL: a szótárban a kulcs a **valódi** szöveg (a JSON `\n`-je valódi
 * sortörés), a forrásban viszont `\n` **escape** áll. Feloldás nélkül a
 * hosszú, sortörést tartalmazó bekezdések **hamis hiányt** adnak (ez a saját
 * mérőeszközöm hibája volt: 2 hamis találat az adatvédelmi képernyőn).
 */
function unescapeDart(text) {
  return text
    .replace(/\\n/g, '\n')
    .replace(/\\r/g, '\r')
    .replace(/\\t/g, '\t')
    .replace(/\\'/g, "'")
    .replace(/\\"/g, '"')
    .replace(/\\\\/g, '\\');
}

function walk(dir) {
  const out = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) out.push(...walk(full));
    else if (entry.name.endsWith('.dart')) out.push(full);
  }
  return out;
}

function literalBody(line) {
  const trimmed = line.trim();
  if (!LITERAL_ONLY.test(trimmed)) return null;
  const start = trimmed.indexOf("'");
  const end = trimmed.lastIndexOf("'");
  return unescapeDart(trimmed.slice(start + 1, end));
}

/** A sor **végén** álló literál tartalma (a lánc első sorához), vagy `null`. */
function trailingLiteralBody(line) {
  const trimmed = line.replace(/\s+$/, '');
  if (!LITERAL_AT_END.test(trimmed)) return null;
  const end = trimmed.length - 1;
  let start = end - 1;
  while (start >= 0) {
    if (trimmed[start] === "'" && trimmed[start - 1] !== '\\') break;
    start--;
  }
  if (start < 0) return null;
  return unescapeDart(trimmed.slice(start + 1, end));
}

/** Elválasztóval zárul-e (lista-elem / lezáró vessző) — ilyen sor a láncot zárja. */
const hasTrailingSeparator = (line) => /'[,;)\]]+\s*$/.test(line.trim());

/** Technikai szövegek (nem feliratok) — szándékosan kimaradnak. */
const TECHNICAL = [
  { test: (text) => /Mozilla\/|AppleWebKit|Gecko\//.test(text), reason: 'User-Agent fejléc' },
  { test: (text) => /^https?:\/\//.test(text), reason: 'URL' },
];

/**
 * Az összefűzött literál-láncok (2+ sor).
 *
 * ⚠️ A SZABÁLYOK (a 374-es kör és a saját hibáim tanulsága):
 *  * a lánc **első** sora literállal **végződik** (lehet `return '…'` is), de
 *    **nem** lista-elem (nem `'elem',`);
 *  * a folytatás sorai csak literálok, elválasztó nélkül;
 *  * a lánc az **elválasztóval** zárt sorban ér véget;
 *  * a térkép-kulcs (`'kulcs': …`) soha nem folytatás.
 */
function literalRuns(source) {
  const lines = source.split(/\r?\n/);
  const runs = [];
  for (let index = 0; index < lines.length; index++) {
    const first = trailingLiteralBody(lines[index]);
    if (first === null) continue;
    if (hasTrailingSeparator(lines[index])) continue;
    const parts = [first];
    let next = index + 1;
    while (next < lines.length) {
      const trimmed = lines[next].trim();
      const body = literalBody(lines[next]);
      if (body === null) break;
      if (/^'[^']*'\s*:/.test(trimmed)) break;
      parts.push(body);
      const terminal = hasTrailingSeparator(lines[next]);
      next++;
      if (terminal) break;
    }
    if (parts.length > 1) {
      runs.push({ line: index + 1, text: parts.join('') });
      index = next - 1;
    }
  }
  return runs;
}

const dictionary = JSON.parse(fs.readFileSync(DICTIONARY_PATH, 'utf8'));const exemptFiles = new Set(EXEMPT.map((entry) => entry.file));
const guarded = [];
const failures = [];
const exempt = [];
const technicalSkipped = [];

for (const file of ROOTS.flatMap((root) => walk(root))) {
  const relative = file.split(path.sep).join('/');
  const source = fs.readFileSync(file, 'utf8');
  for (const run of literalRuns(source)) {
    if (run.text.includes('$')) continue;
    const technical = TECHNICAL.find((entry) => entry.test(run.text));
    if (technical) {
      technicalSkipped.push({ file: relative, ...run, reason: technical.reason });
      continue;
    }
    if (exemptFiles.has(relative)) {
      exempt.push({ file: relative, ...run });
      continue;
    }
    if (Object.prototype.hasOwnProperty.call(dictionary, run.text)) {
      guarded.push({ file: relative, ...run });
      continue;
    }
    failures.push({ file: relative, ...run });
  }
}

if (process.argv.includes('--list')) {
  for (const hit of guarded) {
    console.log(`OK(kulcs)  ${hit.file}:${hit.line}  ${JSON.stringify(hit.text.slice(0, 70))}…`);
  }
  for (const hit of exempt) {
    console.log(`KIVÉTEL    ${hit.file}:${hit.line}`);
  }
  for (const hit of technicalSkipped) {
    console.log(`TECHNIKAI  ${hit.file}:${hit.line} — ${hit.reason}`);
  }
}
for (const hit of failures) {
  console.log(`HIÁNYZÓ KULCS  ${hit.file}:${hit.line}`);
  console.log(`    teljes szöveg: ${JSON.stringify(hit.text.slice(0, 160))}`);
}

console.log('');
console.log(`összefűzés kulcsként megvan: ${guarded.length}`);
console.log(`névre szóló kivétel:        ${exempt.length}`);
console.log(`technikai (nem felirat):    ${technicalSkipped.length}`);
console.log(
  failures.length === 0
    ? 'RENDBEN — minden összefűzött felirat teljes szövege kulcs a szótárban.'
    : `${failures.length} HIBA — ezeknek a teljes szövege nincs a szótárban (angolul magyarul maradnának).`,
);
process.exitCode = failures.length === 0 ? 0 : 1;
