#!/usr/bin/env node
/**
 * Mutációs bizonyíték az **értesítések nyelvére** — a tulajdonos jelzése:
 * *„a notifyok még mindig magyarul vannak az angol felületen vagy lassan áll
 * át"* → *„nagyon lassan"*.
 *
 * Minden mutáció egy VALÓDI hiba-visszaállítás; mindegyiknek BUKNIA kell a
 * teszten. A visszaállítás bájtazonos (SHA-256-tal igazolva), és a végén a
 * helyreállított kör **újra zöld**.
 */
import { execSync } from 'node:child_process';
import crypto from 'node:crypto';
import fs from 'node:fs';

const TEST = 'test/services/notification_language_test.dart';
const SCREEN = 'lib/screens/notifications/notification_center_screen.dart';
const LOCALIZER = 'lib/core/i18n/notification_texts.dart';

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

const mutations = [
  {
    label: 'a NotificationCenter újra NYERSEN írja ki a tárolt szöveget',
    file: SCREEN,
    transform: (source) => source
      .replaceAll('localized.title', 'item.title')
      .replaceAll('localized.body', 'item.body'),
  },
  {
    label: 'a fordító mindig a tárolt szöveget adja vissza (nincs átfordítás)',
    file: LOCALIZER,
    transform: (source) =>
      source.replace(
        "    final entry = _kindEntry(type);\n    if (entry == null) {",
        "    final entry = _kindEntry(type);\n    if (true || entry == null) {",
      ),
  },
  {
    label: 'a beágyazott indoklás (achievement `{reason}`) fordítása elvéve',
    file: LOCALIZER,
    transform: (source) =>
      source.replace('        return _translateEmbedded(value, language);', '        return value;'),
  },
  {
    label: 'a küldő nevének levágása újra csak a MAGYAR utótagra működik',
    file: SCREEN,
    transform: (source) =>
      source.replace(
        String.raw`              RegExp(r'\s+(üzenetet küldött|sent you a message)\s*$'),`,
        String.raw`              RegExp(r' üzenetet küldött$'),`,
      ),
  },
  {
    label: 'az „archivált törlés" cím újra NYERS ternary-ág',
    file: SCREEN,
    // ⚠️ A fájlok CRLF-esek: a többsoros horgonyt a fájl saját sorvégére kell
    // igazítani, különben a mutáció „nem talál" (a saját mérőeszközöm hibája).
    transform: (source) => {
      const eol = source.includes('\r\n') ? '\r\n' : '\n';
      const from = [
        '            archived',
        "                ? 'Archivált értesítések törlése'",
      ].join(eol);
      const to = "            archived ? 'Archivált értesítések törlése'";
      return source.replace(from, to);
    },
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
