/**
 * A kerdőív-szavazat szerveroldali Allapot-kerdesenek ellenorzese.
 *
 * A tulajdonos esete: „még mindig tudok többször szavazni, ha újranyitom az
 * appot". A kliens oldal (a `hasVotedProvider`) friss valaszt kert, tehat a
 * hiba a SZERVEREN volt: a `/poll/status` vegpont azt kerdezte, mit TARTALMAZ
 * a szavazat sora, nem azt, hogy LETEZIK-e.
 *
 * A WordPress ezt a szavazatot `_huhs_poll_vote_<sha256>` meta-sorkent tarolja,
 * es az ertek a valasztott valasz INDEXE. A PHP-ban viszont a `(bool) '0'`
 * FALSE, ezert aki az ELSO valaszlehetosegre szavazott (index 0), arra a
 * vegpont „nem szavaztal"-t adott:
 *
 *   - az app ujra kiadta a szavazolapot,
 *   - a felhasznalo azt hitte, ujra szavazott,
 *   - kozben a szerver a masodik szavazatot ELUTASITOTTA, mert az
 *     `add_post_meta(..., true)` egyedi sora mar letezett.
 *
 * Ez a szimulacio a PHP viselkedeset utanozza (string -> bool kaszt, illetve
 * `metadata_exists`), es a JAVITATLAN pluginre szandekosan elhasal.
 *
 * Futtatas: `node tools/verify-poll-status.mjs [plugin-mappa]`
 */

import fs from 'node:fs';
import path from 'node:path';

const pluginDir = process.argv[2] || '.tmp-api-24115/huhs-mobile-api';
const pollFile = path.join(pluginDir, 'includes', 'poll.php');

let failed = 0;
let checked = 0;
const results = [];

function check(label, condition, detail) {
  checked++;
  if (condition) {
    results.push(`OK    ${label}`);
  } else {
    failed++;
    results.push(`HIBA  ${label}${detail ? ` — ${detail}` : ''}`);
  }
}

// --- A PHP viselkedes utanzasa -------------------------------------------

// A `(bool) get_post_meta($id, $key, true)` eredmenye: a META ERTEKE dont.
// PHP-ban a '0' sztring hamis, a '1'..'9' igaz, a hianyzó sor ures sztring.
function phpBoolCast(metaValue) {
  if (metaValue === undefined || metaValue === null || metaValue === '') return false;
  if (metaValue === '0') return false; // <-- EZ a hiba
  return true;
}

// A javitas: a sor LETEZESE dont, fuggetlenul az ertektol.
function metadataExists(metaValue) {
  return metaValue !== undefined && metaValue !== null && metaValue !== '';
}

// A `huhs_poll_api_vote()` egyedisege: add_post_meta(..., true).
function addPostMetaUnique(store, key, value) {
  if (store.has(key)) return false; // mar letezik -> a masodik szavazat elutasítva
  store.set(key, String(value));
  return true;
}

// --- 1. A hiba pontosan az elso valaszlehetosegre jott elo ----------------

for (const index of [0, 1, 2, 3]) {
  check(
    `a regi (bool) kaszt a(z) ${index}. indexre ${index === 0 ? 'FALSE (hiba)' : 'TRUE'}`,
    phpBoolCast(String(index)) === (index !== 0),
    `phpBoolCast('${index}') = ${phpBoolCast(String(index))}`,
  );
}

// --- 2. A javitas minden indexre helyes ----------------------------------

for (const index of [0, 1, 2, 3, 9]) {
  check(
    `a metadata_exists a(z) ${index}. indexre TRUE`,
    metadataExists(String(index)) === true,
  );
}

// --- 3. A teljes lanc: szavazas -> ujranyitas -> status ------------------

{
  const store = new Map();
  const key = '_huhs_poll_vote_' + 'a'.repeat(64);

  const added = addPostMetaUnique(store, key, 0); // az elso válasz választva
  check('az elso szavazat rogzitodik (index 0)', added === true);

  // Ujranyitas: a kliens frissen lekerdezi az allapotot.
  const oldAnswer = phpBoolCast(store.get(key));
  const newAnswer = metadataExists(store.get(key));
  check('a REGI valasz ujranyitas utan: „nem szavaztal" (ez volt a hiba)', oldAnswer === false);
  check('az UJ valasz ujranyitas utan: „szavaztal"', newAnswer === true);

  // Es a lenyeg: a masodik szavazatot a szerver sosem fogadta el.
  const second = addPostMetaUnique(store, key, 2);
  check('a masodik szavazatot a szerver elutasitja (nincs dupla szavazat)', second === false);
  check('a tarolt ertek valtozatlan (0 marad)', store.get(key) === '0');
}

// --- 4. A valodi plugin-forras a javitast tartalmazza --------------------

const source = fs.readFileSync(pollFile, 'utf8');

const statusStart = source.indexOf('function huhs_poll_api_status');
const statusEnd = source.indexOf('function huhs_poll_api_vote', statusStart);
check('a /poll/status fuggveny megtalalhato', statusStart >= 0 && statusEnd > statusStart);
const statusBody = statusStart >= 0 && statusEnd > statusStart
  ? source.slice(statusStart, statusEnd)
  : '';
// A hibát leíró komment szó szerint tartalmazza a régi alakot, ezért a
// forrás-lint csak a KÓD-sorokat vizsgálja.
const statusCodeOnly = statusBody
  .split('\n')
  .filter((line) => {
    const trimmed = line.trim();
    return !trimmed.startsWith('//') && !trimmed.startsWith('*') && !trimmed.startsWith('/*');
  })
  .join('\n');

check(
  'a /poll/status a sor letezeset kerdezi (metadata_exists)',
  statusCodeOnly.includes('metadata_exists('),
);
check(
  'a /poll/status NEM a meta erteket kasztolja bool-lá',
  !/\(bool\)\s*get_post_meta/.test(statusCodeOnly),
);
check(
  'a vegpont valtozatlanul a sotolt ujjlenyomatot hasznalja',
  statusBody.includes("'_huhs_poll_vote_' . $hash"),
);
check(
  'a szavazat rogzitese tovabbra is egyedi (add_post_meta ... true)',
  /add_post_meta\(\$poll_id, '_huhs_poll_vote_' \. \$hash, \$option_index, true\)/.test(source),
);

// --- 4b. A KERDOIV eredmenye kulon admin-muvelet (nem az eves szavazas) ---
//
// A tulajdonos jelzese: „A kérdőívnél rossz szavazási összesítő van az
// adminnak, az éves szavazást mutatja". A gyoker az volt, hogy a mobil admin a
// `voting_summary` muveletet kerte a kerdőívhez — az viszont az ÉVES SZAVAZAS
// jelöltjeit összesíti. Ezert van kulon `poll_results` (es a valasztohoz
// `polls`) muvelet.

const adminFile = path.join(pluginDir, 'includes', 'api-admin.php');
const adminSource = fs.readFileSync(adminFile, 'utf8');

check(
  'letezik a sajat poll_results admin-muvelet',
  adminSource.includes("$action === 'poll_results'"),
);
check(
  'letezik a kerdőívek listaja a valasztohoz (polls)',
  adminSource.includes("$action === 'polls'"),
);
check(
  'a poll_results a SAJAT kerdőív-adataibol szamol (huhs_poll_results)',
  /if \(\$action === 'poll_results'\)[\s\S]*?huhs_poll_results\(/.test(adminSource),
);
check(
  'a poll_results a kerdőív válaszlehetosegeit adja vissza (nem jelolteket)',
  /if \(\$action === 'poll_results'\)[\s\S]*?'options' => \$items/.test(adminSource),
);
{
  const section = adminSource.slice(
    adminSource.indexOf("$action === 'poll_results'"),
    adminSource.indexOf("$action === 'push'"),
  );
  const codeOnly = section
    .split('\n')
    .filter((line) => {
      const trimmed = line.trim();
      return !trimmed.startsWith('//') && !trimmed.startsWith('*') && !trimmed.startsWith('/*');
    })
    .join('\n');
  check(
    'a poll_results NEM az eves szavazas összesítőjét hasznalja',
    !codeOnly.includes('huhs_vote_firestore_summary'),
    'a jeloltekre vonatkozo összesítés a voting_summary-ban marad',
  );
}

// --- 5. A plugin verzioja -------------------------------------------------

const mainFile = fs.readFileSync(path.join(pluginDir, 'huhs-mobile-api.php'), 'utf8');
const versionMatch = /Version:\s*([0-9.]+)/.exec(mainFile);
const version = versionMatch ? versionMatch[1] : '';
const versionParts = version.split('.').map((part) => Number(part) || 0);
const atLeast = (a, b) => a[0] > b[0] || (a[0] === b[0] && (a[1] > b[1] || (a[1] === b[1] && a[2] >= b[2])));
check(
  `a plugin verzioja legalabb 2.5.1 (talalt: ${version || 'nincs'})`,
  versionParts.length === 3 && atLeast(versionParts, [2, 5, 1]),
);

console.log(results.join('\n'));
console.log(`\n${checked - failed}/${checked} ellenorzes rendben`);
process.exit(failed === 0 ? 0 : 1);
