/**
 * Az ANGOL cikk-mezők (rejtett post meta) + a `lang` paraméter — plugin 2.11.0.
 *
 * **A tulajdonos döntése (2026-09-25):** az app kap egy angol nyelvet. Az angol
 * cikkszöveget egy fordítási folyamat állítja elő, és **rejtett post metaba**
 * írja ugyanarra a cikkre. Az angol **nem jelenhet meg a webnyilvános oldalon**
 * (a téma nem olvassa ezeket a mezőket) — kizárólag az app API-ja adja ki, és
 * csak akkor, ha kérik (`lang=en`).
 *
 * **Amit ez a teszt őriz (mind forrás-lint, mert `php -l` nincs a gépen):**
 *  1. a három meta kulcs regisztrálva van a `post` típusra, `show_in_rest`
 *     engedéllyel és sanitize callbackkel — a védett kulcs írásához kell az
 *     `auth_callback` is (`edit_posts`);
 *  2. a **tartalom** szűrője HTML-t megtartó (`wp_kses_post`), NEM
 *     `sanitize_text_field` — az utóbbi minden bekezdést és linket kidobna;
 *  3. a `lang` paraméter **mindhárom** építőben megjelenik (lista,
 *     `summary=true` lista, részlet) és lefelé is átadódik;
 *  4. az angol ág **FALLBACK**: angol értéket csak nem üres meta esetén
 *     használunk, különben a magyar érték megy ki (a válasz sosem üres);
 *  5. a `has_en` jelző minden payloadban ott van;
 *  6. a verzió legalább 2.11.0, és a fejléc + a `HUHS_API_VERSION` egyezik;
 *  7. a plugin PHP-ja **soha nem írja ki** az angol meta kulcsokat — se a
 *     `lang=en` ágon kívül, se a webfelület számára.
 *
 * ⚠️ **ŐSZINTE KORLÁT:** a `php -l` nincs telepítve, ezért a PHP szintaktikát
 * nem lehet futtatni. Helyette ez a teszt (a) zárójel-egyensúlyt ellenőriz
 * (szöveg- és komment-állapotot követve), és (b) ha a repo `php-parser`
 * függősége elérhető, valódi PHP-parse-t is futtat. A viselkedést (WP nélkül)
 * nem tudjuk futtatni — az a WordPressen mérendő.
 */

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const PLUGIN_ROOT = path.join(__dirname, '..', '.tmp-api-260', 'huhs-mobile-api');

const META_KEYS = ['_huhs_title_en', '_huhs_excerpt_en', '_huhs_content_en'];

/** A regisztráció helye (a három kulcs itt születik). */
const META_FILE = 'includes/post-translation-meta.php';
/** A nyilvános végpontok (itt dől el a `lang`). */
const POSTS_FILE = 'includes/posts.php';
/** A 2.12.0 további nyelvet ismerő végpontjai + a WP-cron fordítás. */
const OTHER_CONTENT_FILES = [
  'includes/api-events.php',
  'includes/api-artists.php',
  'includes/api-organizers.php',
  'includes/api-releases.php',
  'includes/translation-cron.php',
];

function pluginFile(relative) {
  return fs.readFileSync(path.join(PLUGIN_ROOT, relative), 'utf8').replace(/\r\n/g, '\n');
}

/** A plugin összes PHP fájlja (relatív útvonal, `/` elválasztóval). */
function pluginPhpFiles() {
  const out = [];
  const walk = (dir) => {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      const full = path.join(dir, entry.name);
      if (entry.isDirectory()) {
        walk(full);
      } else if (entry.name.endsWith('.php')) {
        out.push(path.relative(PLUGIN_ROOT, full).split(path.sep).join('/'));
      }
    }
  };
  walk(PLUGIN_ROOT);
  return out.sort();
}

// ---------------------------------------------------------------------------
// 1. Meta-regisztráció
// ---------------------------------------------------------------------------

/** A `<kulcs> => '<szűrő>'` pár a közös mező-térképből (2.12.0). */
function fieldSanitizer(key) {
  const source = pluginFile(META_FILE);
  const match = new RegExp(`'${key}'\\s*=>\\s*'([a-z_]+)'`).exec(source);
  assert.ok(match, `megvan a(z) ${key} szűrője a ${META_FILE}-ban`);
  return match[1];
}

test('a három angol meta kulcs MINDEN támogatott típusra regisztrálva van', () => {
  const source = pluginFile(META_FILE);
  // A típusok egy helyen élnek (2.12.0): a cikkek mellett az esemény, a DJ,
  // a szervező és a kiadvány is.
  const listMatch = /function huhs_translation_post_types\(\)\s*\{([\s\S]*?)\}/.exec(source);
  assert.ok(listMatch, 'megvan a huhs_translation_post_types() függvény');
  const types = [...listMatch[1].matchAll(/'([a-z_]+)'/g)].map((m) => m[1]);
  assert.deepEqual(
    types,
    ['post', 'huhs_event', 'huhs_artist', 'huhs_organizer', 'huhs_release'],
    'a támogatott típusok: cikk, esemény, DJ, szervező, kiadvány',
  );

  // A regisztráció a listán és a közös mező-térképen megy át (nem másolt blokkok).
  assert.match(
    source,
    /foreach \(huhs_translation_post_types\(\) as \$post_type\)/,
    'a regisztráció végigmegy a típusokon',
  );
  assert.match(
    source,
    /register_post_meta\(\$post_type, \$meta_key, array\(/,
    'a register_post_meta a típust és a kulcsot paraméterként kapja',
  );
  for (const key of META_KEYS) {
    assert.match(source, new RegExp(`'${key}'\\s*=>\\s*'`), `${key}: benne van a mező-térképben`);
  }
});

test('a regisztráció REST-en írható: show_in_rest + sanitize_callback + auth_callback', () => {
  const source = pluginFile(META_FILE);
  const start = source.indexOf('function huhs_register_post_translation_meta(');
  assert.ok(start > 0, 'megvan a regisztráló függvény');
  const body = source.slice(start, source.indexOf('\n}', start));

  assert.match(body, /'type'\s*=>\s*'string'/, 'string típus');
  assert.match(body, /'single'\s*=>\s*true/, 'single');
  assert.match(
    body,
    /'show_in_rest'\s*=>\s*true/,
    'show_in_rest => true (enélkül a REST el sem fogadná az írást)',
  );
  assert.match(body, /'sanitize_callback'\s*=>\s*\$sanitize_callback/, 'van sanitize_callback');
  assert.match(
    body,
    /'auth_callback'\s*=>\s*\$auth_callback/,
    'van auth_callback (a védett kulcs írásához kötelező)',
  );
});

test('az auth_callback az `edit_posts` képességet kéri (a folyamat így tud írni)', () => {
  const source = pluginFile(META_FILE);
  const start = source.indexOf('function huhs_translation_meta_auth_callback');
  assert.ok(start > 0, 'megvan az auth_callback függvény');
  const body = source.slice(start, start + 400);
  assert.match(
    body,
    /user_can\(\$user_id,\s*'edit_posts'\)/,
    'a kapu az edit_posts (ennél szűkebb nem kell, tágabb beengedné a sima olvasókat)',
  );
});

test('a TARTALOM szűrője HTML-t megtartó (wp_kses_post), nem sanitize_text_field', () => {
  assert.equal(
    fieldSanitizer('_huhs_content_en'),
    'wp_kses_post',
    'a cikk törzse HTML: a wp_kses_post a helyes szűrő (a sanitize_text_field '
      + 'MINDEN taget kidobna, és a cikk egyetlen futó szöveggé esne szét)',
  );
});

test('a CÍM viszont sima szöveg (sanitize_text_field), a KIVONAT HTML-tartó', () => {
  assert.equal(
    fieldSanitizer('_huhs_title_en'),
    'sanitize_text_field',
    'a cím egyetlen sor, nem tartalmazhat HTML-t',
  );
  // A kivonat dokumentált döntés: a cikkből örökölhet egyszerű formázást,
  // ezért a testvérével azonos (HTML-t megtartó) szűrőt kap.
  assert.equal(
    fieldSanitizer('_huhs_excerpt_en'),
    'wp_kses_post',
    'a kivonat a törzzsel azonos szűrőt kap (dokumentált döntés)',
  );
});

// ---------------------------------------------------------------------------
// 1b. A 2.12.0: ugyanez a szabály az eseményre, DJ-re, szervezőre és kiadványra
// ---------------------------------------------------------------------------

test('a 2.12.0 végpontjai a KÖZÖS fordítási kaput használják', () => {
  const meta = pluginFile(META_FILE);
  // A kapu egy helyen él, és ugyanaz, mint a cikkeknél: cím ÉS törzs kell.
  const start = meta.indexOf('function huhs_translation_meta_values(');
  assert.ok(start > 0, 'megvan a közös huhs_translation_meta_values()');
  const body = meta.slice(start, meta.indexOf('\n}', start));
  assert.match(body, /if \(\$lang !== 'en'\) \{/, 'magyar ágon nem olvas metát');
  assert.match(
    body,
    /if \(\$title_en === '' \|\| \$content_en === ''\) \{/,
    'a FALLBACK-kapu ugyanaz, mint a cikkeknél (cím ÉS törzs kell)',
  );
  assert.match(
    body,
    /\$values\['has_en'\] = true;/,
    'angol ágon a has_en igazra vált (a payload jelzi, mit kap az app)',
  );

  // ⚠️ A KIADVÁNY szándékosan kimarad: az egyetlen szövege a **cím**, ami név
  // (kiadvány/szám címe), és a payloadban nincs leírás sem — fordítani való
  // prózai szöveg nincs. Ezért ott a kód nem is hívja a közös kaput.
  const contentFiles = OTHER_CONTENT_FILES.filter((file) => !file.includes('api-releases'));
  assert.deepEqual(
    contentFiles,
    [
      'includes/api-events.php',
      'includes/api-artists.php',
      'includes/api-organizers.php',
      'includes/translation-cron.php',
    ],
    'a nyelvet ismerő végpontok: esemény, DJ, szervező (+ a cron); a kiadvány nem',
  );

  for (const file of contentFiles) {
    if (file.endsWith('translation-cron.php')) continue;
    const source = pluginFile(file);
    assert.match(
      source,
      /huhs_translation_meta_values\(/,
      `${file}: a közös kaput használja (nem saját, eltérő szabályt)`,
    );
    assert.match(
      source,
      /huhs_request_lang\(\$request\)/,
      `${file}: a végpont a kérésből olvassa a nyelvet`,
    );
    assert.match(source, /'has_en'\s*=>/, `${file}: a payloadban ott a has_en jelző`);
  }

  // A kiadvány válasza változatlan (nincs benne fordítási meta).
  const releases = pluginFile('includes/api-releases.php');
  assert.equal(
    /huhs_translation_meta_values\(/.test(releases),
    false,
    'a kiadvány címe név: nem fordítjuk (nincs benne fordítási hívás)',
  );
});

test('a WP-cron fordítás API-kulcs NÉLKÜL nem csinál semmit', () => {
  const source = pluginFile('includes/translation-cron.php');
  assert.match(
    source,
    /function huhs_translation_enabled\(\)[\s\S]{0,200}return huhs_translation_api_key\(\) !== '';/,
    'a bekapcsolás feltétele a nem üres kulcs',
  );
  assert.match(source, /function huhs_translation_api_key\(\)/, 'a kulcs egy helyen olvasódik');
  assert.match(
    source,
    /get_option\('huhs_translation_api_key', ''\)/,
    'a kulcs opcióból jön (nem a kódban van)',
  );
  // A hálózati hívás CSAK a kulcs-ellenőrzés után, egyetlen helyen történik.
  const request = source.slice(source.indexOf('function huhs_translation_request('));
  assert.match(request, /if \(\$key === '' \|\| empty\(\$provider\['url'\]\)\) \{\s*return null;/,
    'kulcs nélkül visszatér, hívás előtt');
  assert.match(source, /huhs_translation_enabled\(\)/, 'a cron-ág is ellenőrzi a kulcsot');
});

test('a WP-cron az ÖRÖKÖLT OpenAI-kulcsot is elfogadja (nem kell új kulcs)', () => {
  const source = pluginFile('includes/translation-cron.php');
  // Az örökölt kulcs forrásai (a régi `translations.php` ugyanezt használta).
  assert.match(source, /get_option\('huhs_openai_api_key', ''\)/, 'az örökölt opciót is olvassa');
  assert.match(source, /defined\('HUHS_OPENAI_API_KEY'\)/, 'a konstansot is elfogadja');
  // Az ELSŐDLEGES kulcs nyer: az örökölt ág csak az elsődleges ÜRES esetén fut.
  const primaryAt = source.indexOf("get_option('huhs_translation_api_key', '')");
  const legacyAt = source.indexOf("get_option('huhs_openai_api_key', '')");
  assert.ok(primaryAt > 0 && legacyAt > primaryAt, 'az örökölt kulcs csak tartalék');
  assert.match(
    source,
    /if \(trim\(\$key\) !== ''\) \{\s*return trim\(\$key\);\s*\}/,
    'az elsődleges kulcs azonnal visszatér',
  );
  // A szolgáltató a kulcs forrását követi (különben 401 lenne az idegen végponton).
  assert.match(source, /function huhs_translation_api_key_is_legacy\(\)/, 'van örökség-felismerés');
  assert.match(
    source,
    /huhs_translation_api_key_is_legacy\(\)\s*\?\s*array\([\s\S]{0,160}api\.openai\.com\/v1\/chat\/completions/,
    'örökölt kulcsnál az OpenAI végpontja az alapérték',
  );
  assert.match(source, /api\.deepseek\.com\/chat\/completions/, 'az elsődleges kulcsnál marad a DeepSeek');
  // A kulcsot továbbra sem a kód tartalmazza, csak opció/konstans/szűrő.
  assert.doesNotMatch(source, /sk-[A-Za-z0-9]{10,}/, 'nincs kulcs a forrásban');
});

test('a fordítási válasz feldolgozása hálózat nélkül, hibára üres', () => {
  const source = pluginFile('includes/translation-cron.php');
  const start = source.indexOf('function huhs_translation_parse_response(');
  assert.ok(start > 0, 'megvan a válasz-feldolgozó');
  const body = source.slice(start, start + 1200);
  assert.match(body, /json_decode/, 'a választ JSON-ként értelmezi');
  assert.match(body, /'choices'\]\[0\]\['message'\]\['content'\]/, 'a csevegő-végpont alakját ismeri');
  assert.match(body, /\$empty = array\('title' => '', 'content' => '', 'excerpt' => ''\)/,
    'hibás válasznál üres mezők (nem írunk félkész fordítást)');
});

// ---------------------------------------------------------------------------
// 2. A `lang` paraméter mindhárom építőben
// ---------------------------------------------------------------------------

/** A `huhs_get_posts()` (lista-végpont) törzse. */
function listEndpoint() {
  const source = pluginFile(POSTS_FILE);
  const start = source.indexOf('function huhs_get_posts(WP_REST_Request $request)');
  assert.ok(start > 0, 'megvan a lista-végpont');
  const end = source.indexOf('function huhs_build_post_summary', start);
  assert.ok(end > start, 'véget ér a lista-végpont');
  return source.slice(start, end);
}

/** A `huhs_build_post()` (teljes építő) törzse. */
function fullBuilder() {
  const source = pluginFile(POSTS_FILE);
  const start = source.indexOf('function huhs_build_post($post, $include_related = true');
  assert.ok(start > 0, 'megvan a teljes építő');
  const end = source.indexOf('function huhs_get_posts', start);
  assert.ok(end > start, 'véget ér a teljes építő');
  return source.slice(start, end);
}

/** A `huhs_build_post_summary()` (summary=true építő) törzse. */
function summaryBuilder() {
  const source = pluginFile(POSTS_FILE);
  const start = source.indexOf('function huhs_build_post_summary(');
  assert.ok(start > 0, 'megvan a summary építő');
  const end = source.indexOf('function huhs_get_related_posts', start);
  assert.ok(end > start, 'véget ér a summary építő');
  return source.slice(start, end);
}

/** A `huhs_get_post_detail()` (részlet-végpont) törzse. */
function detailEndpoint() {
  const source = pluginFile(POSTS_FILE);
  const start = source.indexOf('function huhs_get_post_detail(WP_REST_Request $request)');
  assert.ok(start > 0, 'megvan a részlet-végpont');
  const end = source.indexOf('function huhs_build_post($post', start);
  assert.ok(end > start, 'véget ér a részlet-végpont');
  return source.slice(start, end);
}

/** A `huhs_post_language_payload()` (nyelv-feloldó) törzse. */
function languageResolver() {
  const source = pluginFile(POSTS_FILE);
  const start = source.indexOf('function huhs_post_language_payload(');
  assert.ok(start > 0, 'megvan a nyelv-feloldó');
  return source.slice(start);
}

test('a `lang` paraméter beolvasása közös helperen megy (hu az alap)', () => {
  const source = pluginFile(POSTS_FILE);
  assert.match(
    source,
    /function huhs_request_lang\(WP_REST_Request \$request\)[\s\S]{0,240}?\$request->get_param\('lang'\)/,
    'a lang paramétert a közös helper olvassa',
  );
  assert.match(
    source,
    /return \$lang === 'en' \? 'en' : 'hu';/,
    'hiányzó/érvénytelen érték → hu, ezért a régi appok (lang nélkül) sem változnak',
  );
});

test('a LISTA-végpont beolvassa és továbbadja a `lang`-ot', () => {
  const endpoint = listEndpoint();
  assert.match(endpoint, /\$lang = huhs_request_lang\(\$request\);/, 'a lista beolvassa a lang-ot');
  assert.match(
    endpoint,
    /\$result\[\] = \$summary \? huhs_build_post_summary\(\$post, \$lang\) : huhs_build_post\(\$post, true, \$lang\);/,
    'mindkét építő (summary és teljes) megkapja a lang-ot',
  );
});

test('a SUMMARY építő is megkapja a `lang`-ot', () => {
  const summary = summaryBuilder();
  assert.match(
    summary,
    /function huhs_build_post_summary\(\$post, \$lang = 'hu'\)/,
    'a summary építő lang paramétert vár (alap: hu — a régi hívás változatlan)',
  );
  assert.match(
    summary,
    /\$translation = huhs_post_language_payload\(\$post, \$lang\);/,
    'a summary is a nyelv-feloldón megy át',
  );
});

test('a RÉSZLET-végpont beolvassa és továbbadja a `lang`-ot', () => {
  const detail = detailEndpoint();
  assert.match(
    detail,
    /huhs_build_post\(\$post, true, huhs_request_lang\(\$request\)\)/,
    'a részlet-végpont a kérés nyelvét adja át a teljes építőnek',
  );
});

test('a TELJES építő lang paramétert vár és a nyelv-feloldót használja', () => {
  const full = fullBuilder();
  assert.match(
    full,
    /function huhs_build_post\(\$post, \$include_related = true, \$lang = 'hu'\)/,
    'a teljes építő harmadik paramétere a lang (alap: hu)',
  );
  assert.match(full, /\$translation = huhs_post_language_payload\(\$post, \$lang\);/);
  assert.match(full, /'title' => \$translation\['title'\],/);
  assert.match(full, /'excerpt' => \$translation\['excerpt'\],/);
  assert.match(full, /'content' => \$translation\['content'\],/);
});

test('a `link` minden nyelven a magyar permalink marad (nincs külön EN bejegyzés)', () => {
  assert.match(fullBuilder(), /'link' => get_permalink\(\$post->ID\),/);
  assert.match(summaryBuilder(), /'link' => get_permalink\(\$post->ID\),/);
  const resolver = languageResolver();
  assert.equal(
    /'link'\s*=>/.test(resolver),
    false,
    'a nyelv-feloldó nem nyúl a linkhez',
  );
});

// ---------------------------------------------------------------------------
// 3. Az angol ág FALLBACK (kód-alak, nem csak „létezik a paraméter")
// ---------------------------------------------------------------------------

test('a MAGYAR ág a lang=en kapu ELŐTT visszatér (meta-olvasás nélkül)', () => {
  const resolver = languageResolver();

  const hungarianGate = resolver.indexOf("if ($lang !== 'en') {");
  assert.ok(hungarianGate > 0, "megvan a `if ($lang !== 'en')` kapu");

  const firstMetaRead = resolver.indexOf('get_post_meta(');
  assert.ok(firstMetaRead > 0, 'van meta-olvasás az angol ágon');
  assert.ok(
    hungarianGate < firstMetaRead,
    'a magyar ág a meta-olvasás ELŐTT tér vissza — lang=hu nem olvassa az angol metát',
  );

  // A kapu után azonnal a magyar payload megy vissza.
  const afterGate = resolver.slice(hungarianGate, hungarianGate + 80);
  assert.match(afterGate, /if \(\$lang !== 'en'\) \{\s*\n\s*return \$payload;/, 'a kapu a magyar payloadot adja vissza');

  // A magyar payload a kapu ELŐTT épül fel, és mind a négy mezőt tartalmazza.
  const beforeGate = resolver.slice(0, hungarianGate);
  assert.match(beforeGate, /'has_en'\s*=>\s*false,/, 'a magyar alapérték has_en = false');
  assert.match(beforeGate, /'title'\s*=>\s*huhs_clean_title\(\$post->post_title\),/);
  assert.match(beforeGate, /'content'\s*=>\s*\$content_hu,/, 'a magyar törzs a post_content-ból jön');
  assert.match(beforeGate, /'excerpt'\s*=>\s*huhs_make_excerpt\(\$content_hu\),/);
});

test('az angol értéket CSAK nem üres meta esetén használjuk (fallback-kapu)', () => {
  const resolver = languageResolver();

  for (const key of META_KEYS) {
    assert.match(
      resolver,
      new RegExp(`trim\\(\\(string\\) get_post_meta\\(\\$post->ID, '${key}', true\\)\\);`),
      `${key}: a nyers meta trim-elve olvasódik (a csupa whitespace nem angol tartalom)`,
    );
  }

  const gate = resolver.search(/if \(\$title_en === '' \|\| \$content_en === ''\) \{/);
  assert.ok(gate > 0, 'megvan a fallback-kapu: cím ÉS törzs kell az angol ághoz');
  const afterGate = resolver.slice(gate, gate + 120);
  assert.match(afterGate, /return \$payload;/, 'a kapun belül a magyar payload tér vissza');

  // A kulcs: az angol ÉRTÉK-átvétel a kapu UTÁN van, tehát a kapu valóban fog.
  const titleAssign = resolver.indexOf("$payload['title'] = huhs_clean_title($title_en);");
  const contentAssign = resolver.indexOf("$payload['content'] = huhs_clean_content($content_en);");
  assert.ok(titleAssign > gate, 'a cím átvétele a fallback-kapu UTÁN történik');
  assert.ok(contentAssign > gate, 'a törzs átvétele a fallback-kapu UTÁN történik');
  assert.match(resolver, /\$payload\['has_en'\] = true;/);
});

test('a kivonatnak saját angol mezője van, üresen az angol törzsből képződik', () => {
  const resolver = languageResolver();
  const excerpt = resolver.indexOf("$payload['excerpt'] = $excerpt_en !== ''");
  assert.ok(excerpt > 0, 'a kivonat angol ága külön dönt');
  const after = resolver.slice(excerpt, excerpt + 200);
  assert.match(after, /\$excerpt_en !== ''/, 'csak nem üres angol kivonatot használunk');
  assert.match(after, /huhs_make_excerpt\(\$excerpt_en\)/, 'ha van angol kivonat, azt adjuk');
  assert.match(after, /huhs_make_excerpt\(\$payload\['content'\]\)/, 'ha nincs, az angol törzsből képezzük');
});

// ---------------------------------------------------------------------------
// 4. `has_en` minden payloadban
// ---------------------------------------------------------------------------

test('a `has_en` jelző minden válaszban ott van', () => {
  const full = fullBuilder();
  const summary = summaryBuilder();
  assert.match(full, /'has_en' => \$translation\['has_en'\],/, 'a teljes építő kiadja a has_en-t');
  assert.match(summary, /'has_en' => \$translation\['has_en'\],/, 'a summary építő is kiadja a has_en-t');

  const source = pluginFile(POSTS_FILE);
  assert.equal(
    (source.match(/'has_en' => \$translation\['has_en'\],/g) || []).length,
    2,
    'pontosan a két építő adja ki a has_en-t (a kapcsolódó cikkek nem külön payloadok)',
  );

  const resolver = languageResolver();
  assert.match(resolver, /'has_en'\s*=>\s*false,/, 'a magyar payload has_en = false');
  assert.match(resolver, /\$payload\['has_en'\] = true;/, 'az angol ág has_en = true');
});

// ---------------------------------------------------------------------------
// 5. Verzió (2.11.0) — a fejléc és a konstans egyezik
// ---------------------------------------------------------------------------

test('FORRÁS-LINT: a plugin verziója legalább 2.11.0, és a fejléc + konstans egyezik', () => {
  // ⚠️ Szándékosan NEM pontos verziót kérünk (a 2.8.0-nál ez el is tört):
  // az angol cikk-mezők a 2.11.0-ban kerültek be, minden további kiadás
  // emeli a verziót.
  const main = pluginFile('huhs-mobile-api.php');
  const header = main.match(/^\s*\*\s*Version:\s*(\d+)\.(\d+)\.(\d+)\s*$/m);
  assert.ok(header, 'van verzió a plugin fejlécében');
  const version = [Number(header[1]), Number(header[2]), Number(header[3])];
  assert.ok(
    version[0] > 2 || (version[0] === 2 && version[1] >= 11),
    `a verzió legalább 2.11.0 legyen, ez: ${version.join('.')}`,
  );
  const constant = main.match(/HUHS_API_VERSION',\s*'(\d+\.\d+\.\d+)'/);
  assert.ok(constant, 'van HUHS_API_VERSION konstans');
  assert.equal(
    constant[1],
    version.join('.'),
    'a fejléc verziója és a konstans ugyanaz (különben a diagnosztika hazudik)',
  );
});

test('a zenekar behúzza az új meta-fájlt', () => {
  const main = pluginFile('huhs-mobile-api.php');
  assert.match(
    main,
    /require_once HUHS_API_PATH \. 'includes\/post-translation-meta\.php';/,
    'a post-translation-meta.php be van húzva (enélkül a kulcsok nem regisztrálódnak)',
  );
});

// ---------------------------------------------------------------------------
// 6. A plugin PHP-ja SOHA nem írja ki az angol meta kulcsokat
// ---------------------------------------------------------------------------

test('egyetlen PHP fájl sem echo-zza az angol meta kulcsokat', () => {
  const output = /\becho\b|\bprint\b|\bprintf\b|\bvar_dump\b|\bprint_r\b|<\?=|\besc_html\b|\besc_attr\b|\besc_textarea\b/;
  const offenders = [];

  for (const file of pluginPhpFiles()) {
    const lines = pluginFile(file).split('\n');
    lines.forEach((line, index) => {
      if (!META_KEYS.some((key) => line.includes(key))) return;
      if (output.test(line)) {
        offenders.push(`${file}:${index + 1}: ${line.trim()}`);
      }
    });
  }

  assert.deepEqual(
    offenders,
    [],
    `az angol mezők nem juthatnak ki a webfelületre; találatok:\n${offenders.join('\n')}`,
  );
});

test('az angol kulcsokat CSAK a regisztráció és a lang=en ág ismeri', () => {
  const referencing = pluginPhpFiles().filter((file) => {
    const source = pluginFile(file);
    return META_KEYS.some((key) => source.includes(key));
  });

  assert.deepEqual(
    referencing.filter((file) => file !== META_FILE && file !== POSTS_FILE && !OTHER_CONTENT_FILES.includes(file)),
    [],
    'a témának/sablonnak/shortcode-nak nem szabad ezeket a kulcsokat ismernie',
  );
  // A cikkek és a 2.12.0 végpontok valóban ismerik őket.
  assert.ok(referencing.includes(META_FILE), 'a regisztráció ismeri a kulcsokat');
  assert.ok(referencing.includes(POSTS_FILE), 'a cikk-végpont ismeri a kulcsokat');

  // A posts.php-ban minden előfordulás a lang=en ágon belül van.
  const source = pluginFile(POSTS_FILE);
  const resolverStart = source.indexOf('function huhs_post_language_payload(');
  const resolver = source.slice(resolverStart);
  const gate = resolver.indexOf("if ($lang !== 'en') {");

  for (const key of META_KEYS) {
    let from = 0;
    for (;;) {
      const at = source.indexOf(key, from);
      if (at < 0) break;
      from = at + key.length;
      assert.ok(
        at > resolverStart && at - resolverStart > gate,
        `${key} előfordulása (${at}. bájt) a lang=en ágon belül van`,
      );
    }
  }
});

// ---------------------------------------------------------------------------
// 7. PHP szintaktika: zárójel-egyensúly (+ valódi parse, ha elérhető)
// ---------------------------------------------------------------------------

/**
 * Zárójel-egyensúly ellenőrzés: a `()`, `[]`, `{}` párokat számolja, de
 * figyelmen kívül hagyja a PHP kommenteket és a string-literálokat.
 */
function bracketBalance(source, label) {
  const stack = [];
  const closing = { ')': '(', ']': '[', '}': '{' };
  const problems = [];
  let state = 'code';
  let i = 0;

  while (i < source.length) {
    const c = source[i];
    const next = source[i + 1];

    if (state === 'code') {
      if (c === '/' && next === '/') { state = 'line'; i += 2; continue; }
      if (c === '#') { state = 'line'; i += 1; continue; }
      if (c === '/' && next === '*') { state = 'block'; i += 2; continue; }
      if (c === "'") { state = 'single'; i += 1; continue; }
      if (c === '"') { state = 'double'; i += 1; continue; }
      if (c === '(' || c === '[' || c === '{') { stack.push({ ch: c, at: i }); i += 1; continue; }
      if (c === ')' || c === ']' || c === '}') {
        const top = stack.pop();
        if (!top) {
          problems.push(`${label}: felesleges '${c}' a ${i}. karakternél`);
        } else if (top.ch !== closing[c]) {
          problems.push(`${label}: '${top.ch}' (${top.at}) helyett '${c}' záródik a ${i}. karakternél`);
        }
        i += 1;
        continue;
      }
      i += 1;
      continue;
    }

    if (state === 'line') {
      if (c === '\n') state = 'code';
      i += 1;
      continue;
    }

    if (state === 'block') {
      if (c === '*' && next === '/') { state = 'code'; i += 2; continue; }
      i += 1;
      continue;
    }

    // single / double: a backslash escape-et átugorjuk
    if (c === '\\') { i += 2; continue; }
    if ((state === 'single' && c === "'") || (state === 'double' && c === '"')) {
      state = 'code';
    }
    i += 1;
  }

  if (state === 'single' || state === 'double') problems.push(`${label}: lezáratlan string`);
  if (state === 'block') problems.push(`${label}: lezáratlan blokk-komment`);
  for (const open of stack) problems.push(`${label}: lezáratlan '${open.ch}' a ${open.at}. karakternél`);

  return problems;
}

test('FORRÁS-LINT: a megváltoztatott PHP fájlok zárójel-egyensúlya rendben van', () => {
  const files = ['huhs-mobile-api.php', META_FILE, POSTS_FILE];
  const problems = [];
  for (const file of files) {
    problems.push(...bracketBalance(pluginFile(file), file));
  }
  assert.deepEqual(problems, [], `zárójel-problémák:\n${problems.join('\n')}`);
});

test('FORRÁS-LINT: a PHP forrás valódi parse-olása (php-parser, ha elérhető)', (t) => {
  let PhpParser = null;
  try {
    // A repo `package.json`-jában szereplő függőség; ha nincs telepítve,
    // marad a fenti zárójel-egyensúly mint bizonyíték.
    PhpParser = require('php-parser');
  } catch (error) {
    t.diagnostic(`php-parser nem elérhető (${error.message}) — a zárójel-egyensúly marad a bizonyíték`);
    return;
  }

  const engine = new PhpParser.Engine({
    parser: { extractDoc: false, suppressErrors: false, version: 802 },
    ast: { withPositions: true },
  });

  for (const file of ['huhs-mobile-api.php', META_FILE, POSTS_FILE]) {
    const source = pluginFile(file);
    assert.doesNotThrow(
      () => engine.parseCode(source, file),
      `${file}: a PHP forrás parse-olható`,
    );
  }
});
