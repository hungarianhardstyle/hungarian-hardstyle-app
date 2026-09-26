#!/usr/bin/env node
/**
 * MUTÁCIÓS BIZONYÍTÉK (2026-09-26): a javított `label_release_availability`
 * ellenőrzés **nem lett üres** — egy VALÓDI duplikációt továbbra is elkap.
 *
 * MIÉRT KELL: a tesztek
 *  1. hamisan buktak (a `305` rész-szöveget a timestamp is tartalmazhatta — mért
 *     0,8%), ezért az ellenőrzés a **feldolgozott** listát számolja;
 *  2. ez viszont csak akkor ér valamit, ha a valódi hibát (nincs kihagyás a
 *     `markMissing`-ben) **el is kapja**. Ezt méri ez a szkript.
 */
import { execSync } from 'node:child_process';
import crypto from 'node:crypto';
import fs from 'node:fs';

const TEST = 'test/services/label_release_availability_test.dart';
const SERVICE = 'lib/services/label_release_availability.dart';
const sha = (text) => crypto.createHash('sha256').update(text, 'utf8').digest('hex');

function run(command) {
  try {
    execSync(command, { stdio: 'pipe', encoding: 'utf8' });
    return { ok: true, output: '' };
  } catch (error) {
    if (error.status === undefined || error.status === null) {
      throw new Error(`a parancs nem futott le (spawn-hiba): ${error.message}`);
    }
    return { ok: false, output: `${error.stdout ?? ''}${error.stderr ?? ''}` };
  }
}

const original = fs.readFileSync(SERVICE, 'utf8');
const hash = sha(original);

// A VALÓDI hiba visszaállítása: a `markMissing` nem hagyja ki a már jelöltet.
const mutated = original.replace('    if (active.contains(releaseId)) return;\n', '');
if (mutated === original) {
  console.log('HIBA  a mutáció nem változtatott semmit (a horgony elavult?)');
  process.exitCode = 1;
} else {
  fs.writeFileSync(SERVICE, mutated, 'utf8');
  const outcome = run(`flutter test ${TEST}`);
  fs.writeFileSync(SERVICE, original, 'utf8');
  const restored = sha(fs.readFileSync(SERVICE, 'utf8')) === hash;
  const caught = !outcome.ok;
  console.log(`${caught ? 'ELKAPVA  ' : 'NEM KAPTA EL  '}a duplikáció kihagyásának elvétele (markMissing)`);
  console.log(restored ? 'a visszaállítás bájtazonos' : 'HIBA: a visszaállítás NEM bájtazonos');
  const final = run(`flutter test ${TEST}`);
  console.log(final.ok ? 'a helyreállított kör ÚJRA ZÖLD' : 'HIBA: a helyreállított kör sem zöld');
  process.exitCode = caught && restored && final.ok ? 0 : 1;
}
