#!/usr/bin/env node
/**
 * Mutációs bizonyíték a **2026-09-27-i fordítási körhöz**:
 *   * a `WAV (ingyenes)` (ékezet nélküli magyar címke a modellben),
 *   * a `@mindenki` értesítés (a „mindenkit" nem kerülhet a névbe),
 *   * a LEGACY (szóismétléses) pont-szöveg,
 *   * a kivétel-üzenetek (`userFacingError`).
 *
 * Minden mutációnál visszaállítjuk a hibát, és elvárjuk, hogy a kapuk **bukjanak**;
 * majd bájtazonosan visszaállítunk, és a helyreállított körnek **zöldnek** kell
 * lennie.
 *
 * Használat: node tmp/mutation-proof-translation-round2.mjs
 */
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';

const TESTS = [
  'test/services/i18n_accent_free_labels_test.dart',
  'test/services/notification_language_test.dart',
  'test/services/i18n_untranslated_ui_test.dart',
  'test/services/music_background_playback_test.dart',
];
const eolOf = (source) => (source.includes('\r\n') ? '\r\n' : '\n');

const MUTATIONS = [
  {
    name: 'a szótárból eltűnik a „WAV (ingyenes)" kulcs',
    file: 'assets/i18n/en.json',
    find: ['  "WAV (ingyenes)": "WAV (free)",'],
    replace: ['  "WAV (ingyenes) — ELTÁVOLÍTVA": "WAV (free)",'],
  },
  {
    name: 'a médiametaadat újra fordítás nélkül megy ki',
    file: 'lib/screens/more/my_music_screen.dart',
    find: ['    album: AppStrings.tr(entry.variantLabel),'],
    replace: ['    album: entry.variantLabel,'],
  },
  {
    name: 'a változatnév a listában újra fordítás nélkül megy ki',
    file: 'lib/screens/more/my_music_screen.dart',
    find: ['                        tr(context, entry.variantLabel),'],
    replace: ['                        entry.variantLabel,'],
  },
  {
    name: 'a `userFacingError` újra fordítás nélkül adja vissza a magyar üzenetet',
    file: 'lib/core/errors/user_facing_error.dart',
    find: [
      'String userFacingError(Object? error) =>',
      '    AppStrings.tr(_hungarianUserFacingError(error));',
    ],
    replace: [
      'String userFacingError(Object? error) =>',
      '    _hungarianUserFacingError(error);',
    ],
  },
  {
    name: 'a `kind` nem kerül át a fordítónak (a „mindenkit" a névbe jut)',
    file: 'lib/screens/notifications/notification_center_screen.dart',
    find: [
      '      final localized = NotificationTexts.localize(',
      '        type: item.type,',
      '        kind: item.kind,',
    ],
    replace: [
      '      final localized = NotificationTexts.localize(',
      '        type: item.type,',
    ],
  },
  {
    name: 'a LEGACY (szóismétléses) sablon kikerül a fordítóból',
    file: 'lib/core/i18n/notification_texts.dart',
    find: [
      "      'hu': '+{delta} pont {reason}. Új összösszpontszámod: {points}.',",
    ],
    replace: [
      "      'hu': '+{delta} pont {reason}. Új összpontszámod: {points}.',",
    ],
  },
  {
    name: 'a rokon típusok (chat_everyone) kikerülnek a fordításból',
    file: 'lib/core/i18n/notification_texts.dart',
    find: ["    'chat_mention': ['chat_everyone'],"],
    replace: ["    'chat_mention': <String>[],"],
  },
];

const testsPass = () => {
  try {
    execFileSync('flutter', ['test', ...TESTS], { stdio: 'pipe', shell: true });
    return true;
  } catch {
    return false;
  }
};

console.log('--- kiinduló állapot ---');
const baseline = testsPass();
console.log(`a kapuk a kiinduló állapotban: ${baseline ? 'ZÖLD' : 'BUKIK'}`);

const results = [];
for (const mutation of MUTATIONS) {
  const source = fs.readFileSync(mutation.file, 'utf8');
  const eol = eolOf(source);
  const find = mutation.find.join(eol);
  const hits = source.split(find).length - 1;
  if (hits !== 1) {
    results.push('NEM MÉRHETŐ');
    console.log(`\n${mutation.name}\n  NEM MÉRHETŐ — a minta ${hits}× szerepel (1 kell)`);
    continue;
  }
  fs.writeFileSync(mutation.file, source.replace(find, mutation.replace.join(eol)), 'utf8');
  const caught = !testsPass();
  fs.writeFileSync(mutation.file, source, 'utf8');
  const restored = fs.readFileSync(mutation.file, 'utf8') === source;
  results.push(caught ? 'ELKAPVA' : 'NEM KAPTA EL');
  console.log(
    `\n${mutation.name}\n  ${caught ? 'ELKAPVA' : 'NEM KAPTA EL'}${restored ? '' : ' — ⚠️ a visszaállítás nem bájtazonos!'}`,
  );
}

console.log('\n--- helyreállított állapot ---');
const after = testsPass();
console.log(`a kapuk a helyreállítás után: ${after ? 'ZÖLD' : 'BUKIK'}`);

const caught = results.filter((value) => value === 'ELKAPVA').length;
console.log(`\n${caught}/${MUTATIONS.length} mutáció elkapva`);
process.exitCode = caught === MUTATIONS.length && baseline && after ? 0 : 1;
