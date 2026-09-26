/**
 * A JÁTÉK nyilvános válaszának NYELVE — forrás-lint (plugin 2.14.1).
 *
 * **A MÉRT ÉLES HIBA (2026-09-26):** `GET /huhs/v1/games/results/latest?lang=en`
 * a **magyar** összefoglalót adta vissza (`„Teszteld a hardstyle tudásod!…”`),
 * mert a `huhs_game_public_payload()` **nem kapott nyelvet**, és a
 * `title`/`type_label` a magyar `HUHS_GAME_TYPES`-ból ment ki. A 2.14.0 tehát a
 * játék összefoglalóját **lefordította és eltárolta**, de a végpont **nem
 * olvasta ki** — ez a régi hibaosztály („fordítás megvan, olvasó nincs”).
 *
 * ⚠️ Amit ez a lint **őriz**:
 *  1. minden nyilvános játék-végpont átadja a kért nyelvet;
 *  2. az összefoglaló a nyelvi olvasón át megy ki, a **valódi magyar meta** a
 *     tartalék (nem üres string, nem nyers meta);
 *  3. a játéktípus neve **névtárból** fordul, és a magyar ág **változatlan**;
 *  4. a kérdés-szerkezet (`_huhs_game_questions`) **szándékosan nem** fordul
 *     (beágyazott szerkezet — dokumentált korlát), ezért azt a lint **elvárja**
 *     fordítás nélkül.
 *
 * A valódi viselkedést (a végpont futását) a PHP-harness 15. szakasza méri:
 * `tools/php/plugin-translation-test.php`.
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

const games = () => pluginFile('includes/games.php');

/** A `huhs_game_public_payload()` függvény teste (függvényhatárokkal). */
function payloadSection() {
  const source = games();
  const start = source.indexOf('function huhs_game_public_payload(');
  const end = source.indexOf('function huhs_game_create_clip_token(');
  assert.ok(start > 0 && end > start, 'megvan a játék nyilvános payloadja');
  return source.slice(start, end);
}

test('a játék összefoglalója a nyelvi olvasón át megy ki', () => {
  const section = payloadSection();
  assert.match(
    section,
    /'summary'\s*=>\s*huhs_translation_text\(\$post->ID,\s*\$lang,\s*'_huhs_game_summary',\s*\$summary_hu\)/,
    'a nyers meta helyett a nyelvi olvasó adja az összefoglalót',
  );
  assert.match(
    section,
    /\$summary_hu\s*=\s*\(string\)\s*get_post_meta\(\$post->ID,\s*'_huhs_game_summary',\s*true\)/,
    'a tartalék a valódi magyar metaérték',
  );
  assert.equal(
    /'summary'\s*=>\s*get_post_meta\(/.test(section),
    false,
    'a nyers meta-olvasás (a 2.14.0 mért hibája) nem térhet vissza',
  );
});

test('a játéktípus neve névtárból fordul, magyarul változatlan', () => {
  const source = games();
  assert.match(
    source,
    /function huhs_game_type_label\(\$type,\s*\$lang = 'hu'\)/,
    'van nyelv-függvény a típus-névre (alapértékkel, hogy a régi hívók ne törjenek el)',
  );
  assert.match(
    source,
    /if \(\$lang !== 'en'\) \{\s*return \$fallback;/,
    'nem-angol kérésre a magyar címke megy vissza (bájtazonos magyar ág)',
  );
  assert.match(source, /function huhs_game_type_labels_en\(\)/);
  // ⚠️ A névtár **használatát** is meg kell követelni: enélkül a függvény
  // létezne, a magyar ág is rendben lenne, de angolul mégis magyar címke menne
  // ki (ezt a saját mutációs bizonyítékom kapta el: „NEM KAPTA EL").
  assert.match(
    source,
    /return isset\(\$names\[\$type\]\) \? \$names\[\$type\] : \$fallback;/,
    'a függvény a névtárból adja az angol címkét (nem a magyar tartalékot)',
  );
  assert.match(payloadSection(), /'title'\s*=>\s*\$type_label/);
  assert.match(payloadSection(), /'type_label'\s*=>\s*\$type_label/);
  assert.equal(
    /'title'\s*=>\s*HUHS_GAME_TYPES\[/.test(payloadSection()),
    false,
    'a magyar címke közvetlen kiírása nem térhet vissza',
  );
});

test('a típus-névtár minden típust lefed', () => {
  const source = games();
  const huTypes = [...(/define\('HUHS_GAME_TYPES',\s*array\(([\s\S]*?)\)\);/.exec(source)?.[1] ?? '')
    .matchAll(/'([a-z_]+)'\s*=>/g)].map((match) => match[1]);
  const enTypes = [...(/function huhs_game_type_labels_en\(\)[\s\S]*?return array\(([\s\S]*?)\);/.exec(source)?.[1] ?? '')
    .matchAll(/'([a-z_]+)'\s*=>/g)].map((match) => match[1]);
  assert.ok(huTypes.length >= 8, `a magyar típuslista megvan (${huTypes.length})`);
  assert.deepEqual(
    enTypes.slice().sort(),
    huTypes.slice().sort(),
    'az angol névtár pontosan ugyanazokat a típusokat fedi',
  );
});

test('a nyilvános játék-végpontok átadják a kért nyelvet', () => {
  const source = games();
  for (const route of ["'/games/active'", "'/games/results/latest'", "'/games/(?P<id>\\d+)'"]) {
    const at = source.indexOf(route);
    assert.ok(at > 0, `megvan a ${route} útvonal`);
    const section = source.slice(at, at + 900);
    assert.match(section, /huhs_request_lang\(\$request\)/, `a ${route} átadja a nyelvet`);
  }
});

test('a kérdés-szerkezet szándékosan nem fordul (dokumentált korlát)', () => {
  const section = payloadSection();
  assert.match(
    section,
    /'questions'\s*=>\s*\$questions/,
    'a kérdések a saját olvasójukból jönnek (nem a nyelvi olvasóból)',
  );
  assert.equal(
    /_huhs_game_questions/.test(section),
    false,
    'a beágyazott kérdés-szerkezetet nem vezetjük át a lapos mező-fordítón',
  );
});

test('a plugin verziója legalább 2.14.1 (a javítás a csomagban van)', () => {
  const main = pluginFile('huhs-mobile-api.php');
  const header = main.match(/^\s*\*\s*Version:\s*(\d+)\.(\d+)\.(\d+)\s*$/m);
  assert.ok(header, 'van verzió a fejlécben');
  const version = [Number(header[1]), Number(header[2]), Number(header[3])];
  assert.ok(
    version[0] > 2 || (version[0] === 2 && (version[1] > 14 || (version[1] === 14 && version[2] >= 1))),
    `a verzió legalább 2.14.1 legyen, ez: ${version.join('.')}`,
  );
  const constant = main.match(/HUHS_API_VERSION',\s*'(\d+\.\d+\.\d+)'/);
  assert.ok(constant, 'van HUHS_API_VERSION konstans');
  assert.equal(constant[1], version.join('.'), 'a fejléc és a konstans egyezik');
});
