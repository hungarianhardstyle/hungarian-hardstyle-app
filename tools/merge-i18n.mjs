#!/usr/bin/env node
/**
 * A chunkonként készült angol fordítások összevonása a szótárba.
 *
 * Bemenet:
 *   - `tmp/i18n/keys.json`      — a célzott magyar szövegek (a kód adja)
 *   - `tmp/i18n/en/chunk-*.json`— chunkonkénti fordítások (magyar → angol)
 *   - `assets/i18n/en.json`     — a meglévő szótár (a kézzel írt mag)
 *
 * Kimenet: `assets/i18n/en.json` — a **kulcs szerint rendezve** (stabil diff),
 * a chunkok felülírják a magot, a mag olyan kulcsai viszont megmaradnak, amik
 * a célzott halmazban nincsenek (nem ártanak: csak akkor élnek, ha a kód
 * pontosan azt a szöveget kéri).
 *
 * Használat:
 *   node tools/merge-i18n.mjs             # száraz futás
 *   node tools/merge-i18n.mjs --write     # írás
 *   node tools/merge-i18n.mjs --self-test
 */
import fs from 'node:fs';
import path from 'node:path';

export const KEYS_PATH = 'tmp/i18n/keys.json';
export const CHUNK_DIR = 'tmp/i18n/en';
export const DICTIONARY_PATH = 'assets/i18n/en.json';

/**
 * Egy szótár-objektumba vonja a magot és a chunkokat.
 * A chunkok nyernek; a mag a chunkban nem szereplő kulcsokat adja.
 */
export function mergeDictionaries({ seed = {}, chunks = [] } = {}) {
  const merged = { ...seed };
  const conflicts = [];
  for (const chunk of chunks) {
    for (const [key, value] of Object.entries(chunk ?? {})) {
      const text = String(value ?? '');
      if (!text.trim()) continue;
      if (merged[key] !== undefined && merged[key] !== text && seed[key] !== undefined) {
        // A mag és a chunk eltér — a chunk nyer, de jelezzük.
        conflicts.push({ key, seed: merged[key], chunk: text });
      }
      merged[key] = text;
    }
  }
  const sorted = {};
  for (const key of Object.keys(merged).sort((a, b) => a.localeCompare(b, 'hu'))) {
    sorted[key] = merged[key];
  }
  return { dictionary: sorted, conflicts };
}

/** A célzott kulcsok, amikre nincs angol (a `keys.json` szerint). */
export function missingKeys(keys, dictionary) {
  return keys.map((entry) => entry.value ?? entry).filter((key) => !dictionary[key]);
}

/** Chunk-fájlok beolvasása (szám szerint rendezve). */
export function readChunks(dir = CHUNK_DIR) {
  if (!fs.existsSync(dir)) return [];
  return fs
    .readdirSync(dir)
    .filter((name) => /^chunk-\d+\.json$/.test(name))
    .sort()
    .map((name) => {
      const raw = fs.readFileSync(path.join(dir, name), 'utf8');
      try {
        return { name, data: JSON.parse(raw) };
      } catch (error) {
        throw new Error(`${name}: érvénytelen JSON (${error.message})`);
      }
    });
}

export function selfTest() {
  const checks = [];
  const check = (label, ok) => checks.push({ label, ok });

  const { dictionary, conflicts } = mergeDictionaries({
    seed: { A: 'a', B: 'seed' },
    chunks: [{ B: 'chunk', C: 'c' }],
  });
  check('a chunk felülírja a magot', dictionary.B === 'chunk');
  check('a mag megmarad, ha nincs a chunkban', dictionary.A === 'a');
  check('a chunk új kulcsa bekerül', dictionary.C === 'c');
  check('a kulcsok rendezettek', Object.keys(dictionary).join('') === 'ABC');
  check('az ütközést jelzi', conflicts.length === 1 && conflicts[0].key === 'B');

  const empty = mergeDictionaries({ seed: {}, chunks: [{ A: '  ' }] });
  check('az üres fordítás kiesik', empty.dictionary.A === undefined);

  check(
    'a hiányzó kulcsokat megtalálja',
    missingKeys([{ value: 'A' }, { value: 'Z' }], { A: 'a' }).join('') === 'Z',
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

  const keys = fs.existsSync(KEYS_PATH)
    ? JSON.parse(fs.readFileSync(KEYS_PATH, 'utf8'))
    : [];
  const seed = fs.existsSync(DICTIONARY_PATH)
    ? JSON.parse(fs.readFileSync(DICTIONARY_PATH, 'utf8'))
    : {};
  const chunks = readChunks();
  const { dictionary, conflicts } = mergeDictionaries({
    seed,
    chunks: chunks.map((chunk) => chunk.data),
  });
  const missing = missingKeys(keys, dictionary);

  console.log(`chunkok: ${chunks.length} db (${chunks.map((c) => c.name).join(', ') || 'nincs'})`);
  console.log(`mag: ${Object.keys(seed).length} kulcs`);
  console.log(`összevont szótár: ${Object.keys(dictionary).length} kulcs`);
  console.log(`célzott kulcs: ${keys.length}, ebből fordítatlan: ${missing.length}`);
  if (conflicts.length) {
    console.log(`\na mag és a chunk eltér (${conflicts.length}), a chunk nyert:`);
    for (const conflict of conflicts.slice(0, 10)) {
      console.log(`  ${JSON.stringify(conflict.key)}: ${JSON.stringify(conflict.seed)} → ${JSON.stringify(conflict.chunk)}`);
    }
  }
  if (missing.length) {
    console.log('\nfordítatlan célzott szövegek (első 20):');
    for (const key of missing.slice(0, 20)) console.log(`  ${JSON.stringify(key)}`);
  }

  if (!process.argv.includes('--write')) {
    console.log('\nAz íráshoz add hozzá a --write kapcsolót.');
    return 0;
  }
  fs.writeFileSync(DICTIONARY_PATH, `${JSON.stringify(dictionary, null, 2)}\n`, 'utf8');
  console.log(`\nSzótár kiírva: ${DICTIONARY_PATH}`);
  return 0;
}

if (process.argv[1] && process.argv[1].endsWith('merge-i18n.mjs')) {
  process.exitCode = main();
}
