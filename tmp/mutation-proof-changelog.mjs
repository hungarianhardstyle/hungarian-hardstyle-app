#!/usr/bin/env node
/**
 * Mutációs bizonyíték a **kiadási jegyzet** (Névjegy) fordítására — a tulajdonos
 * jelzése: *„a changelog az appban nem angol"* (angol felületen).
 *
 * Minden mutáció egy VALÓDI hiba-visszaállítás; mindegyiknek BUKNIA kell a
 * teszten. A visszaállítás bájtazonos (SHA-256-tal igazolva), és a végén a
 * helyreállított kör **újra zöld**.
 */
import { execSync } from 'node:child_process';
import crypto from 'node:crypto';
import fs from 'node:fs';

const TEST = 'test/services/i18n_changelog_test.dart';
const ABOUT = 'lib/screens/more/about_screen.dart';
const DICT = 'assets/i18n/en.json';

const sha = (text) => crypto.createHash('sha256').update(text, 'utf8').digest('hex');

function runTest() {
  try {
    execSync(`flutter test ${TEST}`, { stdio: 'pipe', encoding: 'utf8' });
    return { ok: true, output: '' };
  } catch (error) {
    if (error.status === undefined || error.status === null) {
      throw new Error(`a teszt nem futott le (spawn-hiba): ${error.message}`);
    }
    return { ok: false, output: `${error.stdout ?? ''}${error.stderr ?? ''}` };
  }
}

/** Egy szótár-kulcs törlése (a fordítás „elfelejtése"). */
function dropDictionaryKey(source) {
  const dictionary = JSON.parse(source);
  const key = Object.keys(dictionary).find((item) => item.startsWith('Javítva: angol felületen a kiadási jegyzet'));
  if (!key) throw new Error('nincs meg a keresett changelog-kulcs');
  delete dictionary[key];
  const sorted = {};
  for (const item of Object.keys(dictionary).sort((a, b) => a.localeCompare(b, 'hu'))) {
    sorted[item] = dictionary[item];
  }
  return `${JSON.stringify(sorted, null, 2)}\n`;
}

const mutations = [
  {
    label: 'a changelog sora újra NYERS (`Text(change)`)',
    file: ABOUT,
    transform: (source) => source.replace('child: Text(tr(context, change)),', 'child: Text(change),'),
  },
  {
    label: 'egy changelog-sor fordítása kivéve a szótárból',
    file: DICT,
    transform: dropDictionaryKey,
  },
  {
    label: 'a verzió-interpoláció újra nyers (nem sablon)',
    file: ABOUT,
    transform: (source) =>
      source.replace(
        "                        'Ehhez a verzióhoz ({n}) még nincs kiadási jegyzet.',",
        "                        'Ehhez a verzióhoz ($currentBuild) még nincs kiadási jegyzet.',",
      ),
  },
];

let caught = 0;
const results = [];

for (const mutation of mutations) {
  const original = fs.readFileSync(mutation.file, 'utf8');
  const originalHash = sha(original);
  const mutated = mutation.transform(original);
  if (mutated === original) {
    results.push(`HIBA  ${mutation.label} — a mutáció nem változtatott semmit`);
    continue;
  }

  fs.writeFileSync(mutation.file, mutated, 'utf8');
  const outcome = runTest();
  fs.writeFileSync(mutation.file, original, 'utf8');
  const restored = sha(fs.readFileSync(mutation.file, 'utf8')) === originalHash;

  if (!restored) {
    results.push(`HIBA  ${mutation.label} — a visszaállítás NEM bájtazonos`);
    continue;
  }
  if (outcome.ok) {
    results.push(`NEM KAPTA EL  ${mutation.label}`);
  } else {
    caught += 1;
    results.push(`ELKAPVA  ${mutation.label}`);
  }
}

console.log(results.join('\n'));
console.log(`\n${caught}/${mutations.length} mutáció elkapva`);

const final = runTest();
console.log(
  final.ok
    ? 'a helyreállított kör ÚJRA ZÖLD'
    : `HIBA: a helyreállított kör sem zöld:\n${final.output.slice(-600)}`,
);
process.exitCode = caught === mutations.length && final.ok ? 0 : 1;
