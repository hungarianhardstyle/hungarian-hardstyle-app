#!/usr/bin/env node
/**
 * Mutációs bizonyíték: a „Partyface" feliratot őrző teszt TÉNYLEG elkapja-e a
 * visszaállítást?
 *
 * ⚠️ MIÉRT KÜLÖN SZKRIPT (saját hiba, 2026-09-26): az első próbálkozásom
 * `node -e`-vel futott, a shell-escape miatt viszont a `replace()` **le sem
 * futott** (SyntaxError), így a teszt „átment" — hamis bizonyíték. Ez a szkript
 * fájlból dolgozik, és a végén **bájtazonosan** visszaállít (SHA-256-tal igazolva).
 */
import { execSync } from 'node:child_process';
import crypto from 'node:crypto';
import fs from 'node:fs';

const FILE = 'assets/i18n/en.json';
const TEST = 'test/services/i18n_content_labels_test.dart';

/**
 * ⚠️ MÉRT ESZKÖZ-HIBA (2026-09-26): a `flutter` Windows-on `.bat`, ezért az
 * `execFileSync('flutter', …)` **ENOENT**-tel hasal el — és a „nem futott le"
 * eredmény **hamis „ELKAPVA"** lenne. Ezért shell-en át futtatunk, és a
 * spawn-hibát meg is különböztetjük.
 */
const runTest = () => {
  try {
    execSync(`flutter test ${TEST}`, { stdio: 'pipe' });
    return { passed: true, output: '' };
  } catch (error) {
    return { passed: false, output: `${error.stdout ?? ''}${error.stderr ?? ''}`.toString() };
  }
};

const hash = (buffer) => crypto.createHash('sha256').update(buffer).digest('hex').toUpperCase();
const original = fs.readFileSync(FILE);
const originalHash = hash(original);

const source = original.toString('utf8');
if (!source.includes('"Bulizó": "Partyface"')) {
  throw new Error('a szótárban nincs ott a "Bulizó": "Partyface" pár — a mutáció nem értelmezhető');
}

let caught = false;
try {
  fs.writeFileSync(
    FILE,
    source.replace('"Bulizó": "Partyface"', '"Bulizó": "Partygoer"'),
    'utf8',
  );
  console.log(`mutáció beírva: "Bulizó": "Partygoer" (a fájl most ${hash(fs.readFileSync(FILE)).slice(0, 12)}…)`);

  const result = runTest();
  if (result.passed) {
    console.log('EREDMÉNY: a teszt ÁTMENT — NEM KAPTA EL a mutációt');
  } else if (/ENOENT|not recognized/i.test(result.output)) {
    console.log(`ESZKÖZ-HIBA: a teszt le sem futott — ${result.output.slice(0, 120)}`);
    process.exitCode = 1;
  } else {
    caught = true;
    console.log('EREDMÉNY: a teszt ELBUKOTT — ELKAPTA a mutációt');
  }
} finally {
  fs.writeFileSync(FILE, original);
}

const restoredHash = hash(fs.readFileSync(FILE));
console.log(`visszaállítás bájtazonos: ${restoredHash === originalHash} (${restoredHash.slice(0, 12)}…)`);

if (!caught || restoredHash !== originalHash) {
  console.log('\nHIBA — a mutációs bizonyíték nem teljes');
  process.exitCode = 1;
} else {
  console.log('\nOK — a felirat-teszt elkapja a visszaállítást, és a szótár bájtazonos maradt');
}
