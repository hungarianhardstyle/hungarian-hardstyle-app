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
 *
 * **2.14.0 (2026-09-26) — a minta a nyelvi olvasóra állítva.** A tulajdonos
 * jelzése (*„a nyereményjáték tartalma magyar maradt"*) után a nyitott ág a
 * `prize_type` / `prize_description` értéket **a nyelvi olvasón** keresztül adja
 * ki (`huhs_translation_text($prize_id, $lang, '_huhs_prize_*', <magyar meta>)`).
 * Ez **nem** gyengíti a fenti szabályt: a magyar érték a **harmadik
 * argumentum**, ezért a teszt most **azt is** megköveteli, hogy a tartalék a
 * valódi `get_post_meta(...)` legyen — üres string nem lehet. A viselkedést
 * (magyar/angol payload, a helyes válasz hiánya) a PHP-harness is méri:
 * `tools/php/plugin-translation-test.php`, 14. szakasz.
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

/** A `huhs_prize_api_active()` függvény nyitott ága.
 *
 * ⚠️ 2.14.0: NEM fix karakterszámú ablak (a régi `slice(-900, +1200)` a
 * hosszabb, több soros `huhs_translation_text(...)` hívásoknál **levágta** a
 * mezőket — ez hamis bukást adott). A határ most a függvény kezdete, illetve a
 * nyertes-ág első sora.
 */
function openBranch() {
  const source = pluginFile('includes/prize.php');
  const stateAt = source.indexOf("'state' => 'open'");
  assert.ok(stateAt > 0, 'megvan a nyitott ag a nyeremény-végpontban');
  const start = source.lastIndexOf('function huhs_prize_api_active', stateAt);
  const end = source.indexOf('huhs_prize_recent_winner_id', stateAt);
  assert.ok(start > 0 && end > stateAt, 'a nyitott ág határai megvannak');
  return source.slice(start, end);
}

/** A `huhs_prize_api_active()` függvény kihirdetett (nyertes) ága. */
function drawnBranch() {
  const source = pluginFile('includes/prize.php');
  const start = source.indexOf("'state' => 'drawn'");
  assert.ok(start > 0, 'megvan a kihirdetett ag');
  return source.slice(start - 400, start + 900);
}

/**
 * A nyitott ág egy mezője (2.14.0): a nyelvi olvasón keresztül megy ki, és a
 * **tartalék a valódi magyar metaérték** — nem üres string.
 *
 * A minta szándékosan szigorú: a `huhs_translation_text(...)` **harmadik**
 * argumentuma a magyar érték, ezért a `get_post_meta` ott kell legyen. Ha
 * valaki „leegyszerűsíti" a hívást egy üres tartalékra, az teszt **elbukik**.
 */
function assertFieldViaReader(branch, field, metaKey) {
  const viaReader = new RegExp(
    `'${field}'\\s*=>\\s*huhs_translation_text\\(\\s*\\$prize_id,\\s*\\$lang,\\s*'\\${metaKey}',\\s*`
      + `\\(string\\)\\s*get_post_meta\\(\\$prize_id,\\s*'\\${metaKey}',\\s*true\\)`,
  );
  assert.match(
    branch,
    viaReader,
    `a nyitott ág a(z) ${field} mezőt a nyelvi olvasón át, a valódi metaértékkel adja ki`,
  );
  assert.equal(
    new RegExp(`'${field}'\\s*=>\\s*''`).test(branch),
    false,
    `a(z) ${field} nem lehet üres string (a korábbi „szándékosan üres" viselkedés nem térhet vissza)`,
  );
}

test('a nyitott játék kiküldi a nyeremény típusát', () => {
  assertFieldViaReader(openBranch(), 'prize_type', '_huhs_prize_type');
});

test('a nyitott játék kiküldi a nyeremény leírását', () => {
  assertFieldViaReader(openBranch(), 'prize_description', '_huhs_prize_description');
});

test('a nyitott játék a válaszokat is elemenként fordítja', () => {
  const branch = openBranch();
  assert.match(
    branch,
    /huhs_translation_list\(\$prize_id,\s*\$lang,\s*'_huhs_prize_answers',\s*huhs_prize_answers\(\$prize_id\)\)/,
    'a válaszlista a nyelvi olvasón át megy ki (a magyar a tartalék)',
  );
  assert.match(
    branch,
    /'has_en'\s*=>\s*huhs_translation_fields_current\(\$prize_id\)/,
    'a válasz megmondja, hogy van-e kész angol fordítás',
  );
});

test('a sorsolás után is kimegy a nyeremény (a viselkedés nem sérült)', () => {
  const branch = drawnBranch();
  assert.match(branch, /'_huhs_prize_type'/);
  assert.match(branch, /'_huhs_prize_description'/);
});

test('a HELYES válasz továbbra sem megy ki a játék lezárása előtt', () => {
  const source = pluginFile('includes/prize.php');
  // ⚠️ 2.14.0: a nyilvános végpont aláírása `WP_REST_Request $request = null`
  // (a `lang` miatt) — a keresés ezért a zárójel NÉLKÜL történik, különben a
  // teszt egy létező függvényt „nem találna meg" (hamis bukás, mért hiba).
  const start = source.indexOf('function huhs_prize_api_active');
  const end = source.indexOf('function huhs_prize_api_status');
  assert.ok(start > 0 && end > start, 'megvan a nyilvános végpont');
  const section = source.slice(start, end);
  assert.equal(
    section.includes('_huhs_prize_correct'),
    false,
    'a helyes válasz indexe nem kerülhet a nyilvános válaszba',
  );
  assert.equal(
    /player_hash|participant_hash/.test(section),
    false,
    'a nyilvános végpont nem ad ki játékos-azonosítót',
  );
  assert.equal(
    /\$uid\b/.test(section),
    false,
    'a nyilvános végpont nem ad ki játékos-azonosítót',
  );
});

test('a nyilvános válasz csak indexet és címkét ad a válaszokról', () => {
  const branch = openBranch();
  assert.match(branch, /array\('index' => \$index, 'label' => \$label\)/);
});

test('a plugin verziója legalább 2.8.0 (a javítás a csomagban van)', () => {
  // ⚠️ Szándékosan NEM pontos verziót kérünk: a nyeremény-leírás a 2.8.0-ban
  // került be, és minden további plugin-kiadás (2.9.0, 2.10.0, …) emeli a
  // verziót. A pontos egyezés minden új kiadásnál eltörné ezt a tesztet
  // anélkül, hogy bármi elromlott volna.
  const main = pluginFile('huhs-mobile-api.php');
  const header = main.match(/^\s*\*\s*Version:\s*(\d+)\.(\d+)\.(\d+)\s*$/m);
  assert.ok(header, 'van verzió a plugin fejlécében');
  const version = [Number(header[1]), Number(header[2]), Number(header[3])];
  assert.ok(
    version[0] > 2 || (version[0] === 2 && version[1] >= 8),
    `a verzió legalább 2.8.0 legyen, ez: ${version.join('.')}`,
  );
  const constant = main.match(/HUHS_API_VERSION',\s*'(\d+\.\d+\.\d+)'/);
  assert.ok(constant, 'van HUHS_API_VERSION konstans');
  assert.equal(constant[1], version.join('.'), 'a fejléc és a konstans egyezik');
  assert.equal(
    /Version:\s*2\.7\.0/.test(main),
    false,
    'a régi verzió nem maradhat a fejlécben',
  );
});
