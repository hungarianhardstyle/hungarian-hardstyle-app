#!/usr/bin/env node
/**
 * A NATIV (appon beluli) HUHS Vezérlőközpont menüjének ellenőrzése.
 *
 * A TULAJDONOS JELZÉSE: „a natív huhs adminban nincsenek ott a nyereményjáték,
 * kviz, és a kérdőiv meg a hozzá tartozó menüpontok".
 *
 * A hiba gyökere az volt, hogy a plugin admin-végpontjai (`polls`, `poll_results`,
 * `prize_games`, `prize_results`, `settings`, `newsletter`, `shortcodes`) éltek, a
 * `wordpress_admin_screen.dart` `_load()`-ja egy részüket még be is töltötte, de a
 * MENÜBEN (`_sections`) nem szerepeltek — így elérhetetlenek voltak. Pontosan ez a
 * néma hibaosztály: a szerver tudja, az app nem kínálja fel.
 *
 * Ez a kapu ezért KÉT oldalt köt össze:
 *   1. kiolvassa a plugin összes `$action === '...'` ágát (`api-admin.php`);
 *   2. kiolvassa az app menüjét (`_sections`), a „csak megnyitó" pontokat
 *      (`_openingSections`) és a `_load()` által kezelt szakaszokat;
 *   3. megköveteli, hogy minden OLVASÓ végpont vagy közvetlen menüpont legyen,
 *      vagy egy megnyitó menüpont mögötti képernyő használja (ezt a célscreen
 *      forrásából igazolja) — kivéve a dokumentált kivétellistát;
 *   4. rögzíti, hogy a „kvíz" és a „kérdőív"/„nyereményjáték" menüpont valóban ott van.
 *
 * Futtatás (a repository gyökeréből):
 *   node tools/verify-native-admin-menu.mjs [plugin-mappa]
 */

import fs from 'node:fs';
import path from 'node:path';

const pluginDir = process.argv[2] || '.tmp-api-24115/huhs-mobile-api';
const adminApiFile = path.join(pluginDir, 'includes', 'api-admin.php');
const screenFile = 'lib/screens/community/wordpress_admin_screen.dart';
const pollScreenFile = 'lib/screens/poll/poll_results_screen.dart';
const prizeScreenFile = 'lib/screens/community/prize_admin_screen.dart';

const results = [];
let checked = 0;
let failed = 0;

function check(label, ok, detail) {
  checked += 1;
  if (ok) results.push(`OK    ${label}`);
  else {
    failed += 1;
    results.push(`HIBA  ${label}${detail ? ` — ${detail}` : ''}`);
  }
}

for (const file of [adminApiFile, screenFile, pollScreenFile, prizeScreenFile]) {
  if (!fs.existsSync(file)) {
    console.error(`Nincs meg: ${file}`);
    process.exit(2);
  }
}

const adminApiSource = fs.readFileSync(adminApiFile, 'utf8');
const screenSource = fs.readFileSync(screenFile, 'utf8');
const pollScreenSource = fs.readFileSync(pollScreenFile, 'utf8');
const prizeScreenSource = fs.readFileSync(prizeScreenFile, 'utf8');

/** A plugin összes admin-művelete. */
const pluginActions = [...new Set([...adminApiSource.matchAll(/\$action === '([a-z_]+)'/g)].map((match) => match[1]))];

/** Csak az OLVASÓ műveletek: a write-ágak nem menüpontok. */
const writeActions = new Set([
  'send_push',
  'empty_trash',
  'restore',
  'save_settings',
  'save_startup',
  'save_resource',
]);
const readActions = pluginActions.filter((action) => !writeActions.has(action));

/** A `_sections` menü térkép kulcsai és címkéi. */
const sectionsBlock = screenSource.match(/static const _sections = <String, String>\{([\s\S]*?)\n  \};/);
const sectionEntries = new Map(
  [...(sectionsBlock?.[1] || '').matchAll(/'([a-z_]+)':\s*'([^']*)'/g)].map((match) => [match[1], match[2]]),
);

/** A „csak megnyitó" menüpontok és a hozzájuk tartozó builder. */
const openingBlock = screenSource.match(/static const _openingSections = <String, WidgetBuilder>\{([\s\S]*?)\n  \};/);
const openingEntries = new Map(
  [...(openingBlock?.[1] || '').matchAll(/'([a-z_]+)':\s*(\w+)/g)].map((match) => [match[1], match[2]]),
);

/** A `_load()` által kezelt (nem `/wp/v2/...`) szakaszok. */
const loadBlock = screenSource.match(/Future<dynamic> _load\(\) async \{([\s\S]*?)\n  \}/);
const loadSource = loadBlock?.[1] || '';
const loadHandled = new Set([...loadSource.matchAll(/_section == '([a-z_]+)'/g)].map((match) => match[1]));

const exceptions = new Map([
  ['voting_seasons', 'az éves szavazás szezonjainak adminja szándékosan a WordPressben marad'],
  ['resource', 'belső művelet a szerkesztéshez/törléshez (nem önálló menüpont)'],
  ['polls', 'a „Kérdőív" menüpont mögötti képernyő használja'],
  ['poll_results', 'a „Kérdőív" menüpont mögötti képernyő használja'],
  ['prize_games', 'a „Nyereményjáték" menüpont mögötti képernyő használja'],
  ['prize_results', 'a „Nyereményjáték" menüpont mögötti képernyő használja'],
]);

check('megvan a `_sections` menü az app admin képernyőjén', sectionEntries.size > 0, `${sectionEntries.size} menüpont`);
check('megvan az `_openingSections` (saját képernyőt nyitó pontok)', openingEntries.size > 0, `${openingEntries.size} pont`);

// 1) Minden olvasó végpont elérhető-e valahonnan?
for (const action of readActions) {
  const direct = sectionEntries.has(action);
  const opening = openingEntries.has(action);
  const handled = loadHandled.has(action);
  const allowed = exceptions.has(action);
  const viaScreen =
    (action === 'polls' || action === 'poll_results') && pollScreenSource.includes(`action=${action}`);
  const viaPrizeScreen =
    (action === 'prize_games' || action === 'prize_results') && prizeScreenSource.includes(`action=${action}`);
  check(
    `a(z) „${action}" admin-végpont elérhető a natív adminból`,
    direct || opening || handled || allowed || viaScreen || viaPrizeScreen,
    direct || opening || handled ? '' : (allowed ? '' : 'nincs menüpont, nincs kezelő ág, és nincs kivétel indoklás'),
  );
}

// 2) A tulajdonos által hiányolt menüpontok.
check('van „Kvíz és játékok" menüpont (a huhs_game kvízek)', (sectionEntries.get('games') || '').includes('Kvíz'), sectionEntries.get('games'));
check('van „Kérdőív" menüpont', sectionEntries.has('poll_results'), sectionEntries.get('poll_results'));
check('van „Nyereményjáték" menüpont', sectionEntries.has('prize_results'), sectionEntries.get('prize_results'));
check('van „Szavazási állás" menüpont', sectionEntries.has('voting_summary'));

// 3) A menüpont a HELYES képernyőt nyitja-e?
const openers = {
  voting_summary: ['_openVotingSummary', 'VotingSummaryScreen'],
  poll_results: ['_openPollResults', 'PollResultsScreen'],
  prize_results: ['_openPrizeAdmin', 'PrizeAdminScreen'],
};
for (const [section, [builder, screen]] of Object.entries(openers)) {
  check(
    `a(z) „${section}" menüpont a(z) ${screen} képernyőt nyitja`,
    openingEntries.get(section) === builder && new RegExp(`${builder}\\(BuildContext context\\) => const ${screen}\\(\\)`).test(screenSource),
  );
}
check(
  'a megnyitó pontokat egyetlen közös térkép kezeli (nincs szétszórt if)',
  screenSource.includes('final builder = _openingSections[section];'),
);
check('a „Kérdőív" képernyő a saját poll-végpontokat használja', pollScreenSource.includes('action=polls') && pollScreenSource.includes('action=poll_results'));
check('a „Nyereményjáték" képernyő a prize-végpontokat használja', prizeScreenSource.includes('action=prize_games') && prizeScreenSource.includes('action=prize_results'));

// 4) Az app nem hivatkozhat olyan szakaszra, ami nem létezik a menüben.
for (const section of [...openingEntries.keys()]) {
  check(`az „${section}" nyitó pont szerepel a menüben is`, sectionEntries.has(section));
}

// 5) LÉTREHOZÁS a natív adminból (kérdőív / nyereményjáték / kvíz).
//
// A tulajdonos kérése: „most már tudok hozzáadni kvizt, nyereményjátékot és
// kérdőívet natív adminból?” — ez a szakasz azt méri, hogy a három útvonal
// (szerver-mezők + app-belépési pont + a mezőtípusok ismerete) **együtt** megvan.
const createFile = path.join(pluginDir, 'includes', 'admin-create.php');
const editorFile = 'lib/screens/community/admin_resource_editor_screen.dart';
check('megvan a szerveroldali létrehozó fájl (admin-create.php)', fs.existsSync(createFile), createFile);
check('megvan az app szerkesztő képernyője', fs.existsSync(editorFile), editorFile);

if (fs.existsSync(createFile) && fs.existsSync(editorFile)) {
  const createSource = fs.readFileSync(createFile, 'utf8');
  const editorSource = fs.readFileSync(editorFile, 'utf8');
  const createSurfaces = {
    huhs_poll: { source: pollScreenSource, key: 'poll-create' },
    huhs_prize: { source: prizeScreenSource, key: 'prize-create' },
    huhs_game: { source: screenSource, key: 'game-create' },
  };
  for (const [type, surface] of Object.entries(createSurfaces)) {
    check(`a(z) „${type}" szerepel a létrehozható típusok között`, createSource.includes(`'${type}'`));
    check(
      `a(z) „${type}" létrehozásához van gomb az appban (${surface.key})`,
      surface.source.includes(`Key('${surface.key}')`) && surface.source.includes(`type: '${type}'`),
    );
  }
  const adminApiSource = fs.readFileSync(adminApiFile, 'utf8');
  check(
    'a szerver engedi az `id = 0`-t (létrehozás)',
    adminApiSource.includes('wp_insert_post') && adminApiSource.includes('if (!$post_id) {'),
  );
  check('a kvízhez CSAK a kvíz-típusok választhatók', createSource.includes('HUHS_ADMIN_QUIZ_TYPES'));

  // A mezőtípusok egyezése: amit a szerver küldhet, azt az appnak ismernie kell.
  const serverTypes = new Set(
    [...`${createSource}\n${fs.readFileSync(adminApiFile, 'utf8')}`.matchAll(/'type'\s*=>\s*'([a-z_]+)'/g)].map((match) => match[1]),
  );
  const appTypes = new Set([...editorSource.matchAll(/case '([a-z_]+)':/g)].map((match) => match[1]));
  const knownElsewhere = new Set(['bool', 'text', 'url', 'email', 'int', 'ids']); // a meglévő űrlap kezeli
  for (const type of [...serverTypes].sort()) {
    check(
      `a(z) „${type}" mezőtípust ismeri az app szerkesztője`,
      appTypes.has(type) || knownElsewhere.has(type),
      `app által ismert: ${[...appTypes].sort().join(', ')}`,
    );
  }
}

console.log(results.join('\n'));
console.log('');
console.log(`${checked - failed}/${checked} ellenőrzés rendben${failed ? ` — ${failed} HIBA` : ''}`);
process.exit(failed ? 1 : 0);
