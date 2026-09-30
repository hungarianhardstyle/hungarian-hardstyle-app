// MUTÁCIÓS BIZONYÍTÉK a naptár-exporthoz (2026-09-28).
//
// A kapu (`test/services/event_calendar_test.dart` + `test/widgets/
// event_calendar_button_test.dart`) akkor ér valamit, ha a VALÓDI hibát elkapja.
// Hat mutáció:
//   1. az escape-elés elvétele        -> a naptár hibás bejegyzést importál;
//   2. a sor-felbontás elvétele       -> a hosszú sorokat a naptár elvágja;
//   3. az egész napos zárás nem kizáró -> egy nappal rövidebb/hosszabb esemény;
//   4. a hibás zárás nem igazodik a kezdéshez -> negatív hosszú bejegyzés;
//   5. dátum nélkül is bejegyzés születik -> 1970-es buli a naptárban;
//   6. a `sharePositionOrigin` elvétele -> iPhone-on NÉMÁN nem jelenik meg a
//      megosztó lap (ezt a 382-es kör mérte meg a megosztás gombnál);
//   7. az „Ott leszek" utáni naptár-felajánlás elvétele -> a szándékolt útvonal
//      eltűnik (a felhasználó csak a fejléc gombját találja).
//
// A szkript a valódi fájlokat a végén bájtazonosan visszaállítja (és ellenőrzi).
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const REPO = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const TESTS = [
  'test/services/event_calendar_test.dart',
  'test/widgets/event_calendar_button_test.dart',
];
const FILES = [
  'lib/services/event_calendar.dart',
  'lib/widgets/calendar_export_button.dart',
  'lib/screens/events/event_detail_screen.dart',
];

const originals = new Map(FILES.map((file) => [file, fs.readFileSync(path.join(REPO, file))]));
const hashes = new Map(
  FILES.map((file) => [
    file,
    createHash('sha256').update(originals.get(file)).digest('hex'),
  ]),
);

function runTests() {
  const result = spawnSync('flutter', ['test', ...TESTS], {
    cwd: REPO,
    encoding: 'utf8',
    shell: true,
    maxBuffer: 64 * 1024 * 1024,
  });
  const output = `${result.stdout ?? ''}${result.stderr ?? ''}`;
  const failed = result.status !== 0 || /Some tests failed/.test(output);
  return { failed, output };
}

/** A bukott tesztek nevei (a bizonyítékhoz). */
function failedNames(output) {
  return [...output.matchAll(/^\s*(?:C:\\[^\n]*?): (.+)$/gm)]
    .map((match) => match[1].trim())
    .filter((name, index, all) => all.indexOf(name) === index)
    .slice(0, 2)
    .join(' | ');
}

const mutations = [
  {
    title: 'az escape-elés elvétele (`;` `,` `\\` nyersen megy a naptárba)',
    file: 'lib/services/event_calendar.dart',
    apply: (text) =>
      text.replace(
        `  return value
      .replaceAll('\\\\', r'\\\\')
      .replaceAll(';', r'\\;')
      .replaceAll(',', r'\\,')
      .replaceAll('\\r\\n', r'\\n')
      .replaceAll('\\n', r'\\n')
      .replaceAll('\\r', r'\\n');`,
        '  return value;',
      ),
  },
  {
    title: 'a sor-felbontás elvétele (75 oktettnél hosszabb sorok maradnak)',
    file: 'lib/services/event_calendar.dart',
    apply: (text) =>
      text.replace(
        `List<String> foldIcsLine(String line, {int limit = 75}) {
  final out = <String>[];`,
        `List<String> foldIcsLine(String line, {int limit = 75}) {
  return <String>[line];
  // ignore: dead_code
  final out = <String>[];`,
      ),
  },
  {
    title: 'az egész napos zárás nem kizáró (a DTEND a záró napra esik)',
    file: 'lib/services/event_calendar.dart',
    apply: (text) =>
      text.replace(
        'end = (endDay ?? startDay).add(const Duration(days: 1));',
        'end = (endDay ?? startDay);',
      ),
  },
  {
    title: 'a kezdés előtti zárás nem igazodik a kezdéshez (negatív hossz)',
    file: 'lib/services/event_calendar.dart',
    apply: (text) =>
      text.replace(
        'if (!end.isAfter(start)) end = start.add(eventCalendarFallbackDuration);',
        'if (false) end = start.add(eventCalendarFallbackDuration);',
      ),
  },
  {
    title: 'dátum nélkül is születik bejegyzés (1970-es buli a naptárban)',
    file: 'lib/services/event_calendar.dart',
    apply: (text) =>
      text.replace(
        'final startDay = _parseDay(event.startDate);',
        'final startDay = _parseDay(event.startDate) ?? DateTime(1970, 1, 1);',
      ),
  },
  {
    title: 'a `sharePositionOrigin` elvétele (iPhone-on néma megosztó lap)',
    file: 'lib/widgets/calendar_export_button.dart',
    apply: (text) =>
      text.replace('      sharePositionOrigin: origin,\n', ''),
  },
  {
    title: 'az „Ott leszek" utáni naptár-felajánlás elvétele',
    file: 'lib/screens/events/event_detail_screen.dart',
    apply: (text) => text.replace("      if (mounted && state == 'attending') {", '      if (false) {'),
  },
];

const baseline = runTests();
console.log(`alapállapot: ${baseline.failed ? 'BUKIK (hiba!)' : 'zöld'}`);
let bad = baseline.failed ? 1 : 0;
let caught = 0;

try {
  for (const mutation of mutations) {
    const filePath = path.join(REPO, mutation.file);
    const original = originals.get(mutation.file).toString('utf8');
    const mutated = mutation.apply(original);
    if (mutated === original) {
      console.log(`ELTER  ${mutation.title} — a minta nem illett`);
      bad += 1;
      continue;
    }
    fs.writeFileSync(filePath, mutated, 'utf8');
    const result = runTests();
    if (result.failed) {
      caught += 1;
      const names = failedNames(result.output);
      console.log(`OK     ${mutation.title} — ELKAPVA${names ? ` (${names})` : ''}`);
    } else {
      bad += 1;
      console.log(`ELTER  ${mutation.title} — NEM bukott meg`);
    }
    fs.writeFileSync(filePath, original, 'utf8');
  }
} finally {
  for (const file of FILES) fs.writeFileSync(path.join(REPO, file), originals.get(file));
}

const restored = FILES.every(
  (file) =>
    createHash('sha256').update(fs.readFileSync(path.join(REPO, file))).digest('hex') ===
    hashes.get(file),
);
const after = runTests();
console.log(`\nbájtazonos visszaállítás: ${restored ? 'IGEN' : 'NEM'}`);
console.log(`a helyreállított kör: ${after.failed ? 'BUKIK' : 'zöld'}`);
if (!restored || after.failed) bad += 1;
console.log(`${caught}/${mutations.length} mutáció elkapva${bad ? `, ${bad} hiba` : ''}`);
process.exitCode = bad === 0 ? 0 : 1;
