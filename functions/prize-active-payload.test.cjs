/**
 * A NYEREMÉNYJÁTÉK nyilvános válaszának bizonyítása — plugin 2.8.0.
 *
 * **A tulajdonos jelzése (2026-09-24):** *„a nyereményjátékba nem kerül bele a
 * játék leírása"*.
 *
 * **A mért gyökér:** a WordPress a **nyitott** játéknál szándékosan üres
 * stringet küldött a `prize_type` / `prize_description` mezőkben, és csak a
 * sorsolás után adta ki őket. A mező saját súgója viszont azt ígéri, hogy
 * *„Részletek, amit a nyertes és a játékosok látnak"*, és a tulajdonos is ezt
 * várja — ezért a nyitott ág is kiküldi a metaértékeket.
 *
 * ⚠️ Amit ez a teszt **őriz**: a **helyes válasz** továbbra sem mehet ki a
 * játék lezárása előtt (a `_huhs_prize_correct` meta és a nyertes-hash sem).
 */

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const PLUGIN_ROOT = path.join(__dirname, '..', '.tmp-api-260', 'huhs-mobile-api');

function pluginFile(relative) {
  return fs
    .readFileSync(path.join(PLUGIN_ROOT, relative), 'utf8')
    .replace(/\r\n/g, '\n');
}

/** A `huhs_prize_api_active()` függvény nyitott ága. */
function openBranch() {
  const source = pluginFile('includes/prize.php');
  const start = source.indexOf("'state' => 'open'");
  assert.ok(start > 0, 'megvan a nyitott ag a nyeremény-végpontban');
  return source.slice(start - 900, start + 1200);
}

/** A `huhs_prize_api_active()` függvény kihirdetett (nyertes) ága. */
function drawnBranch() {
  const source = pluginFile('includes/prize.php');
  const start = source.indexOf("'state' => 'drawn'");
  assert.ok(start > 0, 'megvan a kihirdetett ag');
  return source.slice(start - 400, start + 900);
}

test('a nyitott játék kiküldi a nyeremény típusát', () => {
  const branch = openBranch();
  assert.match(
    branch,
    /'prize_type'\s*=>\s*\(string\)\s*get_post_meta\(\$prize_id,\s*'_huhs_prize_type'/,
    'a nyitott ág a metaértéket küldi, nem üres stringet',
  );
  assert.equal(
    /'prize_type'\s*=>\s*''/.test(branch),
    false,
    'a korábbi „szándékosan üres" viselkedés nem térhet vissza',
  );
});

test('a nyitott játék kiküldi a nyeremény leírását', () => {
  const branch = openBranch();
  assert.match(
    branch,
    /'prize_description'\s*=>\s*\(string\)\s*get_post_meta\(\$prize_id,\s*'_huhs_prize_description'/,
  );
  assert.equal(/[^_]_prize_description'\s*=>\s*''/.test(branch), false);
});

test('a sorsolás után is kimegy a nyeremény (a viselkedés nem sérült)', () => {
  const branch = drawnBranch();
  assert.match(branch, /'_huhs_prize_type'/);
  assert.match(branch, /'_huhs_prize_description'/);
});

test('a HELYES válasz továbbra sem megy ki a játék lezárása előtt', () => {
  const source = pluginFile('includes/prize.php');
  const start = source.indexOf('function huhs_prize_api_active()');
  const end = source.indexOf('function huhs_prize_api_status');
  const section = source.slice(start, end);
  assert.ok(section.length > 0, 'megvan a nyilvános végpont');
  assert.equal(
    section.includes('_huhs_prize_correct'),
    false,
    'a helyes válasz indexe nem kerülhet a nyilvános válaszba',
  );
  assert.equal(
    /player_hash|participant_hash|uid/.test(section),
    false,
    'a nyilvános végpont nem ad ki játékos-azonosítót',
  );
});

test('a nyilvános válasz csak indexet és címkét ad a válaszokról', () => {
  const branch = openBranch();
  assert.match(branch, /array\('index' => \$index, 'label' => \$label\)/);
});

test('a plugin verziója 2.8.0 (a javítás a csomagban van)', () => {
  const main = pluginFile('huhs-mobile-api.php');
  assert.match(main, /^\s*\*\s*Version:\s*2\.8\.0\s*$/m);
  assert.match(main, /HUHS_API_VERSION',\s*'2\.8\.0'/);
  assert.equal(
    /Version:\s*2\.7\.0/.test(main),
    false,
    'a régi verzió nem maradhat a fejlécben',
  );
});
