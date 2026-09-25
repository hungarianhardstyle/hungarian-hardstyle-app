#!/usr/bin/env node
/**
 * Mennyi a lefordítandó szöveg? (csak olvas, becslés)
 *
 * A tulajdonos kérése: „valahogy megkéne oldani az angol nyelvet az appban" —
 * a döntéshez előbb a MENNYISÉGET kell tudni: hány felhasználói szöveg van a
 * Dart-kódban, és az hány karakter. Ez a szkript a `lib/**` alatti string
 * literálokat szedi ki, és három kategóriába sorolja:
 *
 *  - `hungarian`: tartalmaz magyar ékezetet (á é í ó ö ő ú ü ű) — szinte biztos
 *    felhasználói szöveg;
 *  - `words`: nincs ékezet, de van benne szóköz és kisbetű — valószínűleg
 *    mondat/címke (lehet naplóüzenet is);
 *  - `technical`: rövid, szóköz nélküli (kulcs, azonosító, útvonal) — ezt nem
 *    kell fordítani.
 *
 * ⚠️ Ez BECSLÉS, nem kész lista: a napló-/hibaszövegeket is beszámolja, ezért
 * a valódi fordítási mennyiség ennél kevesebb. A költség-becsléshez a Google
 * Cloud Translation névleges díját (20 USD / 1 millió karakter) használjuk.
 *
 * Futtatás: node tools/check-translation-volume.mjs [--json]
 */
import fs from 'node:fs';
import path from 'node:path';

/** Magyar ékezetes betűk (a magyar szöveg legjobb jele). */
export const HUNGARIAN = /[áéíóöőúüűÁÉÍÓÖŐÚÜŰ]/;

/** A Google Cloud Translation névleges díja: USD / 1 000 000 karakter. */
export const USD_PER_MILLION_CHARS = 20;

/** Egy string literál besorolása (tiszta függvény). */
export function classify(text) {
  if (HUNGARIAN.test(text)) return 'hungarian';
  if (/\s/.test(text) && /[a-záéíóöőúüű]/.test(text) && text.length >= 4) {
    return 'words';
  }
  return 'technical';
}

/** A Dart-forrásból string literálok kigyűjtése (durva, de mérhető). */
export function extractStrings(source) {
  const found = [];
  const re = /'(?:[^'\\\n]|\\.)*'|"(?:[^"\\\n]|\\.)*"/g;
  let match;
  while ((match = re.exec(source)) !== null) {
    const raw = match[0].slice(1, -1);
    if (!raw) continue;
    // A `$`-os interpolációt kivesszük: a változó nem fordítási szöveg.
    const text = raw.replace(/\$\{[^}]*\}/g, ' ').replace(/\$\w+/g, ' ').trim();
    if (text.length < 2) continue;
    found.push(text);
  }
  return found;
}

/** Egy könyvtár összes forrásfájljának feldolgozása. */
export function walk(dir, files = [], extension = '.dart') {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      if (entry.name === 'node_modules' || entry.name.startsWith('.')) continue;
      walk(full, files, extension);
    } else if (entry.name.endsWith(extension) && !entry.name.endsWith('.test.cjs')) {
      files.push(full);
    }
  }
  return files;
}

export function summarize(entries) {
  const stats = {
    hungarian: { count: 0, chars: 0 },
    words: { count: 0, chars: 0 },
    technical: { count: 0, chars: 0 },
    files: 0,
    unique: 0,
  };
  const seen = new Set();
  for (const { file, text } of entries) {
    if (!seen.has(file)) {
      seen.add(file);
      stats.files += 1;
    }
    const kind = classify(text);
    stats[kind].count += 1;
    stats[kind].chars += [...text].length;
  }
  stats.unique = new Set(entries.map((entry) => entry.text)).size;
  return stats;
}

export function costUsd(chars, rate = USD_PER_MILLION_CHARS) {
  return (chars / 1_000_000) * rate;
}

export function selfTest() {
  const checks = [];
  const check = (label, ok) => checks.push({ label, ok });
  check('a magyar ékezetet felismeri', classify('Új üzenet') === 'hungarian');
  check('a mondatot szövegnek veszi', classify('Add meg a neved') === 'words');
  check('a kulcsot technikainak veszi', classify('chat_jump_newest') === 'technical');
  const strings = extractStrings("final a = 'Szia világ'; final b = 'key'; final c = 'xx \$y';");
  check('a literálokat kiszedi', strings.length === 3);
  check('az interpolációt kiveszi', strings[2] === 'xx');
  const summary = summarize([
    { file: 'a.dart', text: 'Új üzenet' },
    { file: 'a.dart', text: 'Add meg a neved' },
    { file: 'b.dart', text: 'key' },
  ]);
  check('fájlonként számol', summary.files === 2);
  check('a magyar kategóriát számolja', summary.hungarian.count === 1);
  check('a költség arányos', Math.abs(costUsd(1_000_000) - 20) < 0.001);
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

  const dirArg = process.argv.find((arg) => arg.startsWith('--dir='));
  const dir = dirArg ? dirArg.slice('--dir='.length) : 'lib';
  const extension = dirArg ? '.js' : '.dart';
  const files = walk(dir, [], extension);
  const entries = [];
  for (const file of files) {
    const source = fs.readFileSync(file, 'utf8');
    for (const text of extractStrings(source)) entries.push({ file, text });
  }
  const stats = summarize(entries);
  const translate = stats.hungarian.chars + stats.words.chars;
  const uniqueTranslate = new Set(
    entries
      .filter((entry) => classify(entry.text) !== 'technical')
      .map((entry) => entry.text),
  );
  const uniqueChars = [...uniqueTranslate].reduce((sum, text) => sum + [...text].length, 0);

  if (process.argv.includes('--json')) {
    console.log(
      JSON.stringify({ dir, stats, translate, uniqueChars, unique: uniqueTranslate.size }, null, 2),
    );
    return 0;
  }
  console.log(`Könyvtár: ${dir} (${extension} fájlok)`);
  console.log(`Fájlok: ${files.length}`);
  console.log(`string literál összesen: ${entries.length} (ebből egyedi: ${stats.unique})\n`);
  console.log('kategóriánként:');
  for (const kind of ['hungarian', 'words', 'technical']) {
    const item = stats[kind];
    console.log(
      `  ${kind.padEnd(10)} ${String(item.count).padStart(6)} db  ${String(item.chars).padStart(8)} karakter`,
    );
  }
  console.log(`\nfordítandó (magyar + szöveges): ${translate} karakter`);
  console.log(`ebből egyedi szöveg:            ${uniqueChars} karakter (${uniqueTranslate.size} db)`);
  console.log(
    `\nköltség-becslés (${USD_PER_MILLION_CHARS} USD / 1M karakter, Google Cloud Translation):`,
  );
  console.log(`  teljes lista:   ${costUsd(translate).toFixed(2)} USD`);
  console.log(`  egyedi szöveg:  ${costUsd(uniqueChars).toFixed(2)} USD`);
  const prices = [5, 10, 20];
  console.log('\nha a szöveg ennek a többszöröse lenne (a naplók/hibák miatt):');
  for (const factor of prices) {
    console.log(
      `  ${factor}×: ${(translate * factor).toLocaleString('hu-HU')} karakter → ${costUsd(translate * factor).toFixed(2)} USD`,
    );
  }
  return 0;
}

if (process.argv[1] && process.argv[1].endsWith('check-translation-volume.mjs')) {
  process.exitCode = main();
}
