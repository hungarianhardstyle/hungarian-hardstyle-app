// MUTÁCIÓS BIZONYÍTÉK a 381-es kör kapuihoz (2026-09-28).
//
// A zöld kapu önmagában nem bizonyíték: ez a szkript a VALÓDI hibákat ülteti be,
// és megköveteli, hogy a tesztek elkapják őket. Minden mutáció után a fájl
// **bájtra** visszaáll, és a végén a helyreállított körnek zöldnek kell lennie.
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import fs from 'node:fs';

const mutations = [
  {
    title: 'a mélylinkről nyitott appban is felugrik az onboarding',
    file: 'lib/services/onboarding_state.dart',
    test: 'test/services/onboarding_state_test.dart',
    apply: (text) =>
      text.replace('!completed && !openedFromLink;', '!completed;'),
  },
  {
    title: 'a jelenlét tagonként többször is rögzíthető (pont-halmozás)',
    file: 'lib/services/event_checkin.dart',
    test: 'test/services/event_checkin_test.dart',
    apply: (text) =>
      text.replace(
        '  if (alreadyCheckedIn) return CheckInStatus.alreadyCheckedIn;',
        '  if (false) return CheckInStatus.alreadyCheckedIn;',
      ),
  },
  {
    title: 'az időablak gyakorlatilag végtelen (a lefotózott kód hetekkel később is jó)',
    file: 'lib/services/event_checkin.dart',
    test: 'test/services/event_checkin_test.dart',
    apply: (text) =>
      text.replace(
        'const Duration checkInOpenAfter = Duration(hours: 12);',
        'const Duration checkInOpenAfter = Duration(days: 365);',
      ),
  },
  {
    title: 'idegen domain linkjét is belsőnek hiszi az app',
    file: 'lib/services/content_link_route.dart',
    test: 'test/services/content_link_route_test.dart',
    apply: (text) =>
      text.replace(
        "  return clean == 'hungarianhardstyle.hu' || clean == 'www.hungarianhardstyle.hu';",
        '  return true;',
      ),
  },
  {
    title: 'az ismeretlen típusú választ is célpontnak veszi (zsákutca)',
    file: 'lib/services/content_link_resolver.dart',
    test: 'test/services/content_link_resolver_test.dart',
    apply: (text) =>
      text.replace(
        '  if (kind == null || id <= 0) return null;',
        '  if (id <= 0) return null;\n  return ContentLinkTarget(kind: kind ?? ContentLinkKind.news, id: id);',
      ),
  },
];

const originals = new Map();
for (const mutation of mutations) {
  if (!originals.has(mutation.file)) {
    originals.set(mutation.file, fs.readFileSync(mutation.file));
  }
}
const hashes = new Map(
  [...originals].map(([file, buffer]) => [
    file,
    createHash('sha256').update(buffer).digest('hex'),
  ]),
);

function runFlutter(testFile) {
  try {
    const output = execFileSync('flutter', ['test', testFile], {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'pipe'],
      maxBuffer: 64 * 1024 * 1024,
      shell: true,
    });
    return { failed: false, output };
  } catch (error) {
    return { failed: true, output: `${error.stdout ?? ''}${error.stderr ?? ''}` };
  }
}

let caught = 0;
let bad = 0;

try {
  for (const mutation of mutations) {
    const original = originals.get(mutation.file).toString('utf8');
    const mutated = mutation.apply(original);
    if (mutated === original) {
      console.log(`ELTER  ${mutation.title} — a minta nem illett`);
      bad += 1;
      continue;
    }
    fs.writeFileSync(mutation.file, mutated, 'utf8');
    const result = runFlutter(mutation.test);
    if (result.failed) {
      caught += 1;
      console.log(`OK     ${mutation.title} — ELKAPVA`);
    } else {
      bad += 1;
      console.log(`ELTER  ${mutation.title} — NEM bukott meg`);
    }
    fs.writeFileSync(mutation.file, original, 'utf8');
  }
} finally {
  for (const [file, buffer] of originals) fs.writeFileSync(file, buffer);
}

const restored = [...originals].every(
  (entry) =>
    createHash('sha256').update(fs.readFileSync(entry[0])).digest('hex') ===
    hashes.get(entry[0]),
);
const after = runFlutter('test/services');
console.log(`\nbájtazonos visszaállítás: ${restored ? 'IGEN' : 'NEM'}`);
console.log(`a helyreállított kör: ${after.failed ? 'BUKIK' : 'zöld'}`);
if (!restored || after.failed) bad += 1;
console.log(`${caught}/${mutations.length} mutáció elkapva${bad ? `, ${bad} hiba` : ''}`);
process.exitCode = bad === 0 ? 0 : 1;
