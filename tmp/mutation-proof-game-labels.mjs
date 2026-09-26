#!/usr/bin/env node
/**
 * Mutációs bizonyíték a JÁTÉK-EREDMÉNY és a SZÓKÖZZEL KÖRBEvETT KULCSOK körére
 * (2026-09-26, a tulajdonos jelzése: *„a játék eredményei fejléc is magyar maradt,
 * angolra kapcsolva"*).
 *
 * Minden mutáció egy VALÓDI hiba-visszaállítás, és mindegyiknek BUKNIA kell a
 * teszten. A visszaállítás **bájtazonos** (SHA-256-tal igazolva), és a végén a
 * helyreállított kör **újra zöld** — különben a „nem futott le" nem bizonyíték.
 *
 * ⚠️ A `flutter` Windows-on `.bat`, ezért `execSync`-kel (shell-en át) fut, és a
 * spawn-hibát megkülönböztetjük a valódi bukástól (a korábbi körök tanulsága).
 */
import { execSync } from 'node:child_process';
import crypto from 'node:crypto';
import fs from 'node:fs';

const TEST = 'test/services/i18n_game_labels_test.dart';

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

const GAME = 'lib/screens/games/game_screen.dart';
const HOME = 'lib/screens/home/home_screen.dart';
const COMMUNITY = 'lib/screens/community/community_screen.dart';
const STRINGS = 'lib/core/i18n/app_strings.dart';

const mutations = [
  {
    label: 'a játék-eredmény fejléc újra NYERS (a tulajdonos jelzése)',
    file: GAME,
    from: [
      '        title: Text(',
      "          widget.resultsOnly ? tr(context, 'Játék eredményei') : game.title,",
      '        ),',
    ].join('\n'),
    to: "        title: Text(widget.resultsOnly ? 'Játék eredményei' : game.title),",
  },
  {
    label: 'a főoldali „JÁTÉK EREDMÉNYEI" jelvény újra NYERS ternary-ág',
    file: HOME,
    from: [
      '                    resultsOnly',
      "                        ? tr(context, 'JÁTÉK EREDMÉNYEI')",
      "                        : tr(context, 'JÁTÉK'),",
    ].join('\n'),
    to: "                    resultsOnly ? 'JÁTÉK EREDMÉNYEI' : tr(context, 'JÁTÉK'),",
  },
  {
    label: 'a tárolt hibaüzenet kiírása fordítás NÉLKÜL',
    file: GAME,
    from: '            Text(tr(context, _resultsError!), textAlign: TextAlign.center),',
    to: '            Text(_resultsError!, textAlign: TextAlign.center),',
  },
  {
    label: 'a zárás-dátum zárójeles címkéje újra NYERS interpoláció',
    file: GAME,
    from: [
      "    return trArgs(context, ' (eddig: {d})', {",
      "      'd':",
      "          '${date.year}. ${twoDigits(date.month)}. ${twoDigits(date.day)}. '",
      "          '${twoDigits(date.hour)}:${twoDigits(date.minute)}',",
      '    });',
    ].join('\n'),
    to: [
      "    return ' (eddig: ${date.year}. ${twoDigits(date.month)}. ${twoDigits(date.day)}. '",
      "        '${twoDigits(date.hour)}:${twoDigits(date.minute)})';",
    ].join('\n'),
  },
  {
    label: 'a chat válasz-előnézete újra NYERS interpolált szöveg',
    file: COMMUNITY,
    from: [
      "                        ? trArgs(context, 'Válasz {name} üzenetére: {text}', {",
      "                            'name': replyToName!,",
      "                            'text': replyToText!,",
      '                          })',
    ].join('\n'),
    to: "                        ? 'Válasz $replyToName üzenetére: $replyToText'",
  },
  {
    label: 'a szótár vágott-kulcsú keresése elvéve (a „ szóközös " kulcsok elérhetetlenek)',
    file: STRINGS,
    from: '    final translated = _english[hungarian] ?? _english[hungarian.trim()];',
    to: '    final translated = _english[hungarian];',
  },
];

let caught = 0;
const results = [];

for (const mutation of mutations) {
  const original = fs.readFileSync(mutation.file, 'utf8');
  const originalHash = sha(original);
  // ⚠️ A fájlok a lemezen CRLF-esek (git autocrlf), ezért a többsoros
  // horgonyokat a fájl saját sorvégére igazítjuk — különben „nem található"
  // lenne, és a bizonyíték hamis képet adna.
  const eol = original.includes('\r\n') ? '\r\n' : '\n';
  const from = mutation.from.replace(/\n/g, eol);
  const to = mutation.to.replace(/\n/g, eol);
  if (!original.includes(from)) {
    results.push(`HIBA  ${mutation.label} — a keresett forrás-rész nem található`);
    continue;
  }

  fs.writeFileSync(mutation.file, original.replace(from, to), 'utf8');
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
    : `HIBA: a helyreállított kör sem zöld:\n${final.output.slice(-800)}`,
);

process.exitCode = caught === mutations.length && final.ok ? 0 : 1;
