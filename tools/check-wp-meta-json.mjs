#!/usr/bin/env node
/*
 * Két dolgot ellenőriz a HUHS Mobile API forrásán:
 *
 * 1. FORRÁS-LINT: olyan post meta írást keres, amiben a saját kódunk generál
 *    backslasht (json_encode), de a wp_slash() hiányzik. Az update_post_meta()
 *    ugyanis wp_unslash()-ol, ezért az ilyen érték megcsonkul.
 *
 * 2. FUTÁSIDEJŰ SZIMULÁCIÓ: végigjátssza a WordPress viselkedését
 *    (json_encode -> update_post_meta wp_unslash -> json_decode), és igazolja,
 *    hogy (a) a 2.4.113-as hiba pontosan az "Utu00e1lom" szöveget adja,
 *    (b) a javítás visszaállítja a helyes "Utálom" szöveget,
 *    (c) az új mentési út (wp_slash + JSON_UNESCAPED_UNICODE) sértetlenül tárol.
 *
 * Futtatás: node tools/check-wp-meta-json.mjs [plugin-forras-mappa]
 */

import fs from 'node:fs';
import path from 'node:path';

const sourceDir = process.argv[2] || '.tmp-api-24114/huhs-mobile-api';
const META_WRITERS = ['update_post_meta', 'add_post_meta', 'update_metadata', 'add_metadata'];

let failures = 0;
const fail = (message) => {
  failures++;
  console.log(`HIBA  ${message}`);
};
const ok = (message) => console.log(`OK    ${message}`);

/* ------------------------------------------------------------------ */
/* 1. Forrás-lint                                                      */
/* ------------------------------------------------------------------ */

const phpFiles = [];
const walk = (entry) => {
  const stat = fs.statSync(entry);
  if (stat.isDirectory()) {
    for (const child of fs.readdirSync(entry)) walk(path.join(entry, child));
    return;
  }
  if (entry.endsWith('.php')) phpFiles.push(entry);
};
walk(sourceDir);

/** A hívás teljes argumentumlistája, zárójel-számlálással (több soros híváshoz is). */
function callArguments(code, openParenIndex) {
  let depth = 0;
  let inSingle = false;
  let inDouble = false;
  for (let i = openParenIndex; i < code.length; i++) {
    const ch = code[i];
    if (inSingle) {
      if (ch === '\\') i++;
      else if (ch === "'") inSingle = false;
      continue;
    }
    if (inDouble) {
      if (ch === '\\') i++;
      else if (ch === '"') inDouble = false;
      continue;
    }
    if (ch === "'") inSingle = true;
    else if (ch === '"') inDouble = true;
    else if (ch === '(') depth++;
    else if (ch === ')') {
      depth--;
      if (depth === 0) return code.slice(openParenIndex + 1, i);
    }
  }
  return code.slice(openParenIndex + 1);
}

/** Az argumentumlista felső szintű vesszőinél vág. */
function splitArguments(args) {
  const parts = [];
  let depth = 0;
  let inSingle = false;
  let inDouble = false;
  let current = '';
  for (let i = 0; i < args.length; i++) {
    const ch = args[i];
    if (inSingle) {
      current += ch;
      if (ch === '\\') current += args[++i] ?? '';
      else if (ch === "'") inSingle = false;
      continue;
    }
    if (inDouble) {
      current += ch;
      if (ch === '\\') current += args[++i] ?? '';
      else if (ch === '"') inDouble = false;
      continue;
    }
    if (ch === "'") { inSingle = true; current += ch; continue; }
    if (ch === '"') { inDouble = true; current += ch; continue; }
    if (ch === '(' || ch === '[') depth++;
    if (ch === ')' || ch === ']') depth--;
    if (ch === ',' && depth === 0) { parts.push(current); current = ''; continue; }
    current += ch;
  }
  parts.push(current);
  return parts.map((part) => part.trim());
}

const SOURCE_ALLOWLIST = [
  // A json_encode() itt kizárólag egész számokat ír, az nem tartalmaz backslasht.
  { file: 'api-admin.php', needle: 'preg_split' },
  { file: 'releases.php', needle: "array_map('absint'" },
  { file: 'meta-save.php', needle: "array_map('intval'" },
];

let scanned = 0;
for (const file of phpFiles) {
  const code = fs.readFileSync(file, 'utf8');
  for (const writer of META_WRITERS) {
    let index = code.indexOf(writer + '(');
    while (index !== -1) {
      const previous = code[index - 1];
      const isFunctionName = previous === undefined || !/[A-Za-z0-9_$>]/.test(previous);
      if (!isFunctionName) {
        index = code.indexOf(writer + '(', index + 1);
        continue;
      }
      scanned++;
      const args = splitArguments(callArguments(code, index + writer.length));
      const value = args.slice(2).join(','); // meta kulcs után az érték
      const encodesJson = /json_encode/.test(value);
      if (encodesJson) {
        const base = path.basename(file);
        const allowed = SOURCE_ALLOWLIST.some((entry) => entry.file === base && value.includes(entry.needle));
        const slashed = /wp_slash\s*\(/.test(value);
        const unescapedUnicode = /JSON_UNESCAPED_UNICODE/.test(value);
        const line = code.slice(0, index).split('\n').length;
        if (allowed) {
          ok(`${base}:${line} json_encode csak egész számokkal (kivétel a listán)`);
        } else if (!slashed) {
          fail(`${base}:${line} ${writer}() json_encode értéket ír wp_slash() nélkül — a wp_unslash() csonkítja`);
        } else if (!unescapedUnicode) {
          fail(`${base}:${line} ${writer}() JSON_UNESCAPED_UNICODE nélkül — a \\uXXXX escape backslashje elveszik`);
        } else {
          ok(`${base}:${line} ${writer}() wp_slash + JSON_UNESCAPED_UNICODE`);
        }
      }
      index = code.indexOf(writer + '(', index + 1);
    }
  }
}
console.log(`\n${scanned} meta-írás vizsgálva ${phpFiles.length} PHP fájlban\n`);

/* ------------------------------------------------------------------ */
/* 2. Futásidejű szimuláció                                            */
/* ------------------------------------------------------------------ */

/** A PHP json_encode() alapértelmezett viselkedése: nem-ASCII és "/" escape-elve. */
function phpJsonEncode(data, { unescapedUnicode = false, unescapedSlashes = false } = {}) {
  let json = JSON.stringify(data);
  if (!unescapedSlashes) json = json.replace(/\//g, '\\/');
  if (!unescapedUnicode) {
    let out = '';
    for (const character of json) {
      const codePoint = character.codePointAt(0);
      if (codePoint > 0x7f && codePoint <= 0xffff) out += '\\u' + codePoint.toString(16).padStart(4, '0');
      else if (codePoint > 0xffff) {
        const offset = codePoint - 0x10000;
        out += '\\u' + (0xd800 + (offset >> 10)).toString(16).padStart(4, '0');
        out += '\\u' + (0xdc00 + (offset & 0x3ff)).toString(16).padStart(4, '0');
      } else out += character;
    }
    json = out;
  }
  return json;
}

/** A WordPress wp_unslash() / stripslashes() lényege: a backslash és a mögötte álló karakter. */
const wpUnslash = (value) => String(value).replace(/\\([\s\S])/g, '$1');

/** A plugin új wp_slash()-ének megfelelője a mentési oldalon. */
const wpSlash = (value) => String(value).replace(/([\\'"])/g, '\\$1');

/** A plugin huhs_poll_repair_escapes() függvényének pontos megfelelője. */
const repairEscapes = (raw) =>
  String(raw).includes('u') ? String(raw).replace(/\\?u([0-9a-fA-F]{4})/g, '\\u$1') : String(raw);

const decode = (raw) => {
  try {
    return JSON.parse(raw);
  } catch {
    return null;
  }
};

const LABELS = ['Igen', 'Nem', 'Lehetne jobb', 'Utálom', 'Minek ez?'];

// (a) A 2.4.113 pontosan ezt a hibát okozta.
const brokenStored = wpUnslash(phpJsonEncode(LABELS));
console.log(`2.4.113 tárolt érték: ${brokenStored}`);
if (decode(brokenStored)[3] !== 'Utu00e1lom') {
  fail(`a hiba szimulációja nem az "Utu00e1lom" szöveget adta, hanem: ${decode(brokenStored)[3]}`);
} else {
  ok('a 2.4.113-as hiba pontosan az "Utu00e1lom" szöveget adja (egyezik a WP adminban látottal)');
}

// (b) A javítás a régi, csonka adatot is helyreállítja.
const repaired = decode(repairEscapes(brokenStored));
if (JSON.stringify(repaired) !== JSON.stringify(LABELS)) {
  fail(`a javítás nem állította helyre a régi adatot: ${JSON.stringify(repaired)}`);
} else {
  ok(`a javítás helyreállítja a régi adatot: ${JSON.stringify(repaired)}`);
}

// (c) A javítás ismételhető, a már helyes adatot nem rontja el.
const once = repairEscapes(brokenStored);
if (repairEscapes(once) !== once) fail('a javítás nem idempotens');
else ok('a javítás idempotens (a helyes adatot nem rontja el)');

const healthyStored = wpUnslash(phpJsonEncode(LABELS, { unescapedUnicode: true, unescapedSlashes: true }));
if (JSON.stringify(decode(repairEscapes(healthyStored))) !== JSON.stringify(LABELS)) {
  fail('a javítás elrontja a már helyes, ékezetes adatot');
} else {
  ok('a javítás a már helyes, ékezetes adatot érintetlenül hagyja');
}

// (d) Az új mentési út: wp_slash + JSON_UNESCAPED_UNICODE.
for (const labels of [LABELS, ['A "jobb" verzió', 'C:\\Temp', 'Drum & bass', 'Fehér zaj', '🎧 Hardstyle']]) {
  const stored = wpUnslash(wpSlash(phpJsonEncode(labels, { unescapedUnicode: true, unescapedSlashes: true })));
  const decoded = decode(stored);
  if (JSON.stringify(decoded) !== JSON.stringify(labels)) {
    fail(`az új mentési út nem sértetlen: ${JSON.stringify(labels)} -> ${JSON.stringify(decoded)}`);
  } else {
    ok(`az új mentési út sértetlen: ${JSON.stringify(labels)}`);
  }
}

// (e) Miért kell a wp_slash: enélkül egy idezojel az EGÉSZ listát megzavarja.
const quoted = ['A "jobb" verzió', 'Nem'];
const withoutSlashRaw = phpJsonEncode(quoted, { unescapedUnicode: true, unescapedSlashes: true });
if (decode(wpUnslash(withoutSlashRaw)) !== null) {
  fail('a wp_slash hiányát a szimuláció nem tudta hibaként kimutatni');
} else {
  ok('wp_slash nélkül egy idézőjel már olvashatatlan JSON-t ad (ezért kell a wp_slash)');
}

// (f) Az egyszeri migráció: a csonka tárolt értékből tiszta tárolt érték lesz.
const migrated = wpUnslash(wpSlash(phpJsonEncode(decode(repairEscapes(brokenStored)), {
  unescapedUnicode: true,
  unescapedSlashes: true,
})));
if (JSON.stringify(decode(migrated)) !== JSON.stringify(LABELS)) {
  fail(`a migráció nem ad tiszta tárolt értéket: ${migrated}`);
} else {
  ok(`a migráció tiszta tárolt értéket ad: ${migrated}`);
}
if (repairEscapes(migrated) !== migrated) {
  fail('a migráció után a read-oldali javítás megváltoztatná az értéket');
} else {
  ok('a migráció után a read-oldali javítás már nem változtat semmit');
}

/* ------------------------------------------------------------------ */
/* 3. Az engedélylista nem lehet megduplázva                           */
/* ------------------------------------------------------------------ */

/*
 * A 2.4.113-ban a /poll/active bekerült a huhs_public_cache_route()
 * engedélylistájába, de a http-cache.php tetején maradt egy kezzel másolt,
 * második regex, ami nem tartalmazta. Ezért a kérdőív friss válasza fejléc
 * nélkül ment ki (se ETag, se 45 másodperc), és a hosting a maga 300
 * másodperces Cache-Controlját tette alá. Egy engedélylista lehet.
 */
let allowlists = 0;
for (const file of phpFiles) {
  const code = fs.readFileSync(file, 'utf8');
  const matches = code.match(/preg_match\(\s*'#\^\/huhs\/v1\/\(/g) || [];
  const matchesDouble = code.match(/preg_match\(\s*"#\^\/huhs\/v1\/\(/g) || [];
  allowlists += matches.length + matchesDouble.length;
}
if (allowlists !== 1) {
  fail(`a nyilvános cache engedélylistája ${allowlists} helyen szerepel — pontosan 1 kell (huhs_public_cache_route)`);
} else {
  ok('a nyilvános cache engedélylistája egyetlen helyen szerepel');
}
if (fs.readFileSync(path.join(sourceDir, 'includes/http-cache.php'), 'utf8').includes('huhs_public_cache_route($route)')) {
  ok('a friss válasz fejlécei a közös huhs_public_cache_route() engedélylistát használják');
} else {
  fail('a friss válasz fejlécei nem a közös engedélylistát használják');
}

/* ------------------------------------------------------------------ */
/* 4. Admin almenü csak a szülő-menü UTÁN regisztrálhat                */
/* ------------------------------------------------------------------ */

/*
 * A WordPress az admin-oldal azonosítóját a szülő-menü ismeretében számolja.
 * Ha egy almenü az előtt regisztrálódik, hogy a szülő-menü létrejönne, a
 * WordPress eldobja, és a címre ez jön: „Sorry, you are not allowed to access
 * this page." — pontosan ez történt a „Kérdőív eredményei" oldallal (a
 * poll.php az admin.php ELŐTT töltődik be). A javítás: admin_menu priority 20.
 */
const submenuPriority = (code) => {
  const match = code.match(/add_action\(\s*'admin_menu'\s*,[\s\S]{0,600}?\}\s*,\s*(\d+)\s*\)\s*;/);
  return match ? Number(match[1]) : 10;
};

const adminMenuProblems = (files) => {
  const problems = [];
  for (const { name, code } of files) {
    if (!/add_submenu_page\s*\(/.test(code)) continue;
    if (name === 'admin.php') continue; // ez hozza létre a szülő-menüt
    const priority = submenuPriority(code);
    if (priority < 20) problems.push(`${name} (priority ${priority})`);
  }
  return problems;
};

{
  const mainFile = fs.readFileSync(path.join(sourceDir, 'huhs-mobile-api.php'), 'utf8');
  const includeOrder = [...mainFile.matchAll(/require_once HUHS_API_PATH \. 'includes\/([^']+)'/g)].map((m) => m[1]);
  const adminIndex = includeOrder.indexOf('admin.php');

  const beforeParent = includeOrder.slice(0, adminIndex).map((name) => ({
    name,
    code: fs.existsSync(path.join(sourceDir, 'includes', name)) ? fs.readFileSync(path.join(sourceDir, 'includes', name), 'utf8') : '',
  }));
  const afterParent = includeOrder.slice(adminIndex + 1).map((name) => ({
    name,
    code: fs.existsSync(path.join(sourceDir, 'includes', name)) ? fs.readFileSync(path.join(sourceDir, 'includes', name), 'utf8') : '',
  }));

  const broken = adminMenuProblems(beforeParent);
  if (broken.length) {
    fail(`admin almenü a szülő-menü ELŐTT, priority nélkül: ${broken.join(', ')} — a WordPress eldobja az oldalt`);
  } else {
    ok('a szülő-menü előtt betöltődő fájlok almenüje priority 20-szal regisztrál');
  }

  // A detektor működésének bizonyítéka: a javítás ELŐTTI minta (priority 10).
  const beforeFix = [{
    name: 'poll.php',
    code: "add_action('admin_menu', function () {\n    add_submenu_page('huhs-mobile', 'Kérdőív eredményei', 'Kérdőív eredményei', 'manage_options', 'huhs-poll-results', 'huhs_poll_results_admin_page');\n});",
  }];
  if (adminMenuProblems(beforeFix).length !== 1) {
    fail('a detektor nem ismeri fel a javítás előtti (priority 10) esetet');
  } else {
    ok('a detektor felismeri a javítás előtti esetet (priority 10)');
  }

  const afterParentProblems = adminMenuProblems(afterParent.filter((entry) => entry.code));
  void afterParentProblems;
}

console.log(failures === 0 ? '\nMINDEN ELLENŐRZÉS RENDBEN' : `\n${failures} HIBA`);
process.exit(failures === 0 ? 0 : 1);