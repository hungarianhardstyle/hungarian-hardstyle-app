#!/usr/bin/env node
/**
 * Mutációs bizonyíték a tulajdonos **2026-09-26-i észrevételeire**:
 *  * `&amp;` a DJ-/szervező-leírásban (Goze, Nu-Clear, Subrage),
 *  * nyers feliratok („Ismerőseid is jönnek", „Éves e-mail-módosítási
 *    lehetőség", „Reklámmal feloldva", „Ismerősök: n", „Jelölj ki
 *    értesítéseket"/„Kijelölve: n"),
 *  * a magyar pont-értesítés szóismétlése („Új összösszpontszámod").
 *
 * Minden mutáció a javítás egy darabját veszi el; mindegyiknek BUKNIA kell a
 * teszten. A visszaállítás **bájtazonos** (SHA-256-tal igazolva), és a végén a
 * helyreállított kör **újra zöld**.
 */
import { execSync } from 'node:child_process';
import crypto from 'node:crypto';
import fs from 'node:fs';

const ARTIST = 'lib/models/artist.dart';
const SELECTION = 'lib/services/notification_selection_plan.dart';
const MUSIC = 'lib/screens/more/my_music_screen.dart';
const USERS = 'lib/screens/more/community_users_screen.dart';
const TEXTS = 'functions/notification-texts.js';

const TEST = 'test/services/html_entities_and_labels_test.dart';
const SELECTION_TEST = 'test/services/notification_selection_plan_test.dart';

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

const runTests = () => run(`flutter test ${TEST} ${SELECTION_TEST}`);

const mutations = [
  {
    label: 'a DJ-életrajz entitás-feloldása elvéve (újra &amp; látszana)',
    file: ARTIST,
    transform: (source) =>
      source.replace(
        "      biography: decodeHtmlEntities(_readString(json['biography'])),",
        "      biography: _readString(json['biography']),",
      ),
  },
  {
    label: 'az értesítés-kijelölés újra KÉSZ magyar szöveget ad',
    file: SELECTION,
    transform: (source) =>
      source.replace(
        "    count <= 0 ? 'Jelölj ki értesítéseket' : 'Kijelölve: {n}';",
        "    count <= 0 ? 'Jelölj ki értesítéseket' : 'Kijelölve: \$count';",
      ),
  },
  {
    label: 'a „Reklámmal feloldva" újra nyers ternary-ág',
    file: MUSIC,
    transform: (source) =>
      source.replace(
        "                            ? tr(context, 'Reklámmal feloldva')",
        "                            ? 'Reklámmal feloldva'",
      ),
  },
  {
    label: 'az „Ismerősök: n" újra nyers Text',
    file: USERS,
    transform: (source) =>
      source.replace(
        "Text(trArgs(context, 'Ismerősök: {n}', {'n': '\${friends.length}'}))",
        "Text('Ismerősök: \${friends.length}')",
      ),
  },
  {
    label: 'a magyar pont-értesítés szóismétlése visszakerül',
    file: TEXTS,
    transform: (source) =>
      source.replace(
        "      body: '+{delta} pont {reason}. Új összpontszámod: {points}.',",
        "      body: '+{delta} pont {reason}. Új összösszpontszámod: {points}.',",
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
    results.push(`HIBA  ${mutation.label} — a mutáció nem változtatott semmit (a horgony elavult?)`);
    continue;
  }

  fs.writeFileSync(mutation.file, mutated, 'utf8');
  const outcome = runTests();
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

const final = runTests();
console.log(final.ok ? 'a helyreállított kör ÚJRA ZÖLD' : `HIBA: a helyreállított kör sem zöld:\n${final.output.slice(-500)}`);
process.exitCode = caught === mutations.length && final.ok ? 0 : 1;
