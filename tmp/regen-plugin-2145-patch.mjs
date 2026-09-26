#!/usr/bin/env node
/**
 * A 2.14.5 **patch** előállítása a KIADOTT 2.14.4 és a jelenlegi forrás között.
 *
 * A bázis a **kiadott** `build/huhs-mobile-api-2.14.4.zip` (ezt töltötte fel a
 * tulajdonos 2026-09-26-án) — kibontva `tmp/plugin-2144-recon/`-ba, hogy a patch
 * pontosan a futó állapothoz mérődjön. A kiadott ZIP-hez NEM nyúlunk.
 *
 * A 2.14.5 a tulajdonos kérése: **kézi angol mezők** a natív adminban (kérdőív,
 * nyereményjáték, játék-összefoglaló) + a `has_en` jelző helyes számítása.
 */
import { execFileSync } from 'node:child_process';
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';

const ZIP = 'build/huhs-mobile-api-2.14.4.zip';
const BASE = 'tmp/plugin-2144-recon';
const OLD = `${BASE}/huhs-mobile-api`;
const NEW = '.tmp-api-260/huhs-mobile-api';
const OUT = 'docs/plugin-2.14.5-manual-english.patch';

if (!fs.existsSync(ZIP)) throw new Error(`nincs meg a kiadott 2.14.4 csomag: ${ZIP}`);

fs.rmSync(BASE, { recursive: true, force: true });
fs.mkdirSync(BASE, { recursive: true });
execFileSync('tar', ['-xf', ZIP, '-C', BASE]);
console.log(`kibontva: ${BASE}`);

const oldMain = fs.readFileSync(`${OLD}/huhs-mobile-api.php`, 'utf8');
if (!/Version:\s*2\.14\.4/.test(oldMain)) throw new Error('a bázis nem a kiadott 2.14.4');
if (!fs.readFileSync(`${OLD}/includes/translation-fields.php`, 'utf8')
  .includes('HUHS_TRANSLATION_FIELDS_VERSION_META')) {
  throw new Error('a bázisból hiányzik a 2.14.4 verzió-kapuja');
}
if (fs.readFileSync(`${OLD}/includes/translation-fields.php`, 'utf8')
  .includes('HUHS_TRANSLATION_MANUAL_SUFFIX')) {
  throw new Error('a bázis MÁR tartalmazza a kézi angol réteget — nem a kiadott állapot');
}

// A jelenlegi forrás ellenőrzése (a patch csak akkor értelmes, ha a javítás bent van).
const newFields = fs.readFileSync(`${NEW}/includes/translation-fields.php`, 'utf8');
for (const needle of [
  'HUHS_TRANSLATION_MANUAL_SUFFIX',
  'huhs_translation_manual_text',
  'huhs_translation_manual_list',
  'huhs_translation_fields_has_english',
]) {
  if (!newFields.includes(needle)) throw new Error(`a forrásból hiányzik: ${needle}`);
}
if (!fs.readFileSync(`${NEW}/includes/admin-create.php`, 'utf8').includes("'_huhs_poll_options_en'")) {
  throw new Error('a forrásból hiányzik a kérdőív angol válasz mezője');
}

let diff = '';
try {
  diff = execFileSync('git', ['diff', '--no-index', OLD, NEW], {
    encoding: 'utf8',
    maxBuffer: 64 * 1024 * 1024,
  });
} catch (error) {
  diff = String(error.stdout ?? '');
  if (!diff) throw new Error(`a diff nem futott le: ${error.message}`);
}

let normalized = diff;
for (const [from, to] of [
  [`a/${OLD}/`, 'a/huhs-mobile-api/'],
  [`b/${NEW}/`, 'b/huhs-mobile-api/'],
  [`a/${NEW}/`, 'a/huhs-mobile-api/'],
  [`b/${OLD}/`, 'b/huhs-mobile-api/'],
  [`${OLD}/`, 'huhs-mobile-api/'],
  [`${NEW}/`, 'huhs-mobile-api/'],
]) {
  normalized = normalized.split(from).join(to);
}
if (normalized.includes('.tmp-api-260') || normalized.includes('plugin-2144-recon')) {
  throw new Error('a patch fejlécében temp-könyvtár maradt');
}

fs.writeFileSync(OUT, normalized, 'utf8');
const files = [...normalized.matchAll(/^diff --git a\/(\S+)/gm)].map((match) => match[1]);
const plus = (normalized.match(/^\+(?!\+\+)/gm) || []).length;
const minus = (normalized.match(/^-(?!--)/gm) || []).length;
const bytes = fs.readFileSync(OUT);
console.log(`fájlok (${files.length}): ${files.join(', ')}`);
console.log(`+${plus} / -${minus} sor`);
console.log(`méret: ${bytes.length} bájt, SHA-256 ${crypto.createHash('sha256').update(bytes).digest('hex').toUpperCase()}`);

// A patch alkalmazhatóságának ellenőrzése a kiadott bázisra (tiszta könyvtárban).
const CHECK = 'tmp/patchcheck-2145';
fs.rmSync(CHECK, { recursive: true, force: true });
fs.mkdirSync(CHECK, { recursive: true });
execFileSync('tar', ['-xf', ZIP, '-C', CHECK]);
const apply = execFileSync('git', ['apply', '--check', path.resolve(OUT)], {
  cwd: CHECK,
  encoding: 'utf8',
  stdio: ['ignore', 'pipe', 'pipe'],
});
console.log(`git apply --check a kiadott 2.14.4-re: exit 0${apply ? ` (${apply.trim()})` : ''}`);
