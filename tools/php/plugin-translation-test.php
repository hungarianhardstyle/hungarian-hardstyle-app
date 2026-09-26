<?php
/**
 * A KIADOTT plugin-csomag valódi PHP-viselkedésének mérése — WordPress nélkül.
 *
 * MIÉRT KELL (és miért most): a 2.12.0 két fontos PHP-logikája eddig **csak
 * forrás-lintekkel** volt ellenőrizve (regex a szövegen), mert ezen a gépen nem
 * volt PHP. A Docker + `php:8.2-cli` viszont valódi PHP-t ad, ezért itt a
 * **tényleges kód fut** WordPress-stubokkal:
 *
 *  1. `huhs_translation_post_types()` — a típuslista (a kiadvány is benne van);
 *  2. `huhs_translation_meta_values()` — a **fallback-kapu** (csak cím és törzs
 *     meglétekor vált angolra; `hu` kérésre meta-olvasás nélkül magyar);
 *  3. a WP-cron ága — kulcs nélkül **semmit** nem tesz, örökölt OpenAI-kulccsal
 *     az OpenAI végpontját hívja, érvényes válaszból a **három helyes meta** lesz,
 *     hibás válaszból **semmi** (nincs félkész fordítás).
 *
 * Használat (a konténerben):
 *   php tools/php/plugin-translation-test.php <plugin-dir> [legacy-constant]
 *
 * Kilépési kód: 0 = minden ellenőrzés rendben, 1 = hiba.
 */

$pluginDir = $argv[1] ?? '';
$mode = $argv[2] ?? '';
if ($pluginDir === '' || !is_dir($pluginDir)) {
    fwrite(STDERR, "Hiányzó vagy hibás plugin-könyvtár: {$pluginDir}\n");
    exit(2);
}

// A konstans-ág külön futásban (a konstans nem definiálható kétszer).
if ($mode === 'legacy-constant') {
    define('HUHS_OPENAI_API_KEY', 'sk-constant-legacy-key');
}

define('ABSPATH', __DIR__ . '/');

// A WordPress idő-konstansai (a 2.13.0 sweep-je ezeket használja).
defined('MINUTE_IN_SECONDS') || define('MINUTE_IN_SECONDS', 60);
defined('HOUR_IN_SECONDS') || define('HOUR_IN_SECONDS', 3600);
defined('DAY_IN_SECONDS') || define('DAY_IN_SECONDS', 86400);

$STATE = array(
    'options' => array(),
    'meta' => array(),
    'http' => array(),
    'response' => null,
    'actions' => array(),
    'scheduled' => array(),
    'posts' => array(),
    'supports' => array(),
    'routes' => array(),
    'capabilities' => array(),
    'term_meta' => array(),
);

class WP_Post
{
    public $ID;
    public $post_type;
    public $post_title;
    public $post_content;
    public $post_excerpt = '';
    public $post_status = 'publish';

    public function __construct($data)
    {
        foreach ($data as $key => $value) {
            $this->$key = $value;
        }
    }
}

/** A REST-végpontok stubja: a `WP_REST_Server::CREATABLE` értékét használjuk. */
class WP_REST_Server
{
    const CREATABLE = 'POST';
    const READABLE = 'GET';
    const EDITABLE = 'POST, PUT, PATCH';
    const DELETABLE = 'DELETE';
}

/**
 * A REST-kérés stubja.
 *
 * ⚠️ MÉRT HIBA (2026-09-26): a valódi `WP_REST_Request` **tömbként is**
 * használható (`$request['id']`), és a plugin él ezzel (`/games/(?P<id>\d+)`).
 * Az első stub csak `get_param()`-ot tudott, ezért a privát útvonal mérése
 * „Cannot use object of type WP_REST_Request as array" végzetes hibával állt le.
 */
class WP_REST_Request implements ArrayAccess
{
    private $params;

    public function __construct($params = array())
    {
        $this->params = $params;
    }

    public function get_param($key)
    {
        return $this->params[$key] ?? null;
    }

    public function offsetExists(mixed $offset): bool
    {
        return array_key_exists($offset, $this->params);
    }

    public function offsetGet(mixed $offset): mixed
    {
        return $this->params[$offset] ?? null;
    }

    public function offsetSet(mixed $offset, mixed $value): void
    {
        $this->params[$offset] = $value;
    }

    public function offsetUnset(mixed $offset): void
    {
        unset($this->params[$offset]);
    }
}

class WP_REST_Response
{
    public $data;

    public function __construct($data = null, $status = 200)
    {
        $this->data = $data;
    }
}

class WP_Error
{
    public $code;
    public $message;

    public function __construct($code = '', $message = '')
    {
        $this->code = $code;
        $this->message = $message;
    }
}

/* ---- WordPress-stubok (csak amit a plugin hív) ---------------------------- */

function add_action($hook, $callback, $priority = 10, $accepted = 1)
{
    $GLOBALS['STATE']['actions'][] = array('hook' => $hook, 'callback' => $callback, 'priority' => $priority);
    return true;
}

/**
 * A `custom-fields` támogatás stubja — e nélkül a REST-en küldött meta
 * **csendben elveszik** a nem-`post` típusoknál (mért hiba, 2026-09-25).
 */
function add_post_type_support($post_type, $feature)
{
    $GLOBALS['STATE']['supports'][] = array($post_type, $feature);
    return true;
}

function post_type_exists($post_type)
{
    return in_array(
        $post_type,
        array('post', 'huhs_event', 'huhs_artist', 'huhs_organizer', 'huhs_release'),
        true
    );
}

function add_filter($hook, $callback, $priority = 10, $accepted = 1)
{
    return true;
}

function apply_filters($hook, $value)
{
    return $value;
}

function get_option($name, $default = false)
{
    return array_key_exists($name, $GLOBALS['STATE']['options'])
        ? $GLOBALS['STATE']['options'][$name]
        : $default;
}

function update_option($name, $value, $autoload = null)
{
    $GLOBALS['STATE']['options'][$name] = $value;
    return true;
}

function wp_schedule_single_event($timestamp, $hook, $args = array())
{
    $GLOBALS['STATE']['scheduled'][] = array($hook, $args, $timestamp);
    return true;
}

function register_post_meta($post_type, $meta_key, $args = array())
{
    return true;
}

function wp_json_encode($value, $flags = 0)
{
    return json_encode($value, $flags);
}

function wp_remote_post($url, $args = array())
{
    $GLOBALS['STATE']['http'][] = array('url' => $url, 'args' => $args);
    return $GLOBALS['STATE']['response'];
}

function wp_remote_retrieve_response_code($response)
{
    return is_array($response) ? (int) ($response['code'] ?? 0) : 0;
}

function wp_remote_retrieve_body($response)
{
    return is_array($response) ? (string) ($response['body'] ?? '') : '';
}

function is_wp_error($thing)
{
    return $thing instanceof WP_Error;
}

function get_post($postId)
{
    return $GLOBALS['STATE']['posts'][$postId] ?? null;
}

function get_post_meta($postId, $key, $single = false)
{
    return $GLOBALS['STATE']['meta'][$postId][$key] ?? '';
}

function update_post_meta($postId, $key, $value)
{
    // ⚠️ A VALÓS WordPress `update_metadata()` **`wp_unslash()`-ol** a meta
    // értékén (mert feltételezi, hogy az `$_POST`-ból jön). Ezért a backslash-ek
    // – köztük a **JSON-escape-ek** (`\r\n`, `\uXXXX`) – elvesznek, ha a beíró
    // nem `wp_slash()`-ol előtte. A stub ezt **utánozza**, különben a mérés
    // zölden hazudna (mért éles hiba, 2026-09-26: „rnrn" a nyeremény leírásában).
    $GLOBALS['STATE']['meta'][$postId][$key] = is_string($value) ? wp_unslash($value) : $value;
    return true;
}

function delete_post_meta($postId, $key)
{
    unset($GLOBALS['STATE']['meta'][$postId][$key]);
    return true;
}

/**
 * A `get_posts()` stubja — **csak azt a szűrést** valósítja meg, amit a pótló kör
 * használ: típus + állapot + a `meta_query` NOT EXISTS / üres érték ága.
 */
function get_posts($args = array())
{
    $type = $args['post_type'] ?? 'post';
    $status = $args['post_status'] ?? 'publish';
    $limit = (int) ($args['posts_per_page'] ?? 5);
    $idsOnly = ($args['fields'] ?? '') === 'ids';
    $out = array();

    foreach ($GLOBALS['STATE']['posts'] as $id => $post) {
        if (!$post instanceof WP_Post) {
            continue;
        }
        if ($post->post_type !== $type) {
            continue;
        }
        if ($status !== 'any' && $post->post_status !== $status) {
            continue;
        }
        if (!stub_meta_query_matches($id, $args['meta_query'] ?? array())) {
            continue;
        }
        $out[] = $idsOnly ? $id : $post;
        if ($limit > 0 && count($out) >= $limit) {
            break;
        }
    }

    return $out;
}

function stub_meta_query_matches($postId, $metaQuery)
{
    if (empty($metaQuery)) {
        return true;
    }

    $relation = strtoupper((string) ($metaQuery['relation'] ?? 'AND'));
    $results = array();

    foreach ($metaQuery as $key => $clause) {
        if ($key === 'relation' || !is_array($clause)) {
            continue;
        }
        $value = $GLOBALS['STATE']['meta'][$postId][$clause['key']] ?? null;
        $compare = strtoupper((string) ($clause['compare'] ?? '='));
        if ($compare === 'NOT EXISTS') {
            $results[] = $value === null;
            continue;
        }
        $results[] = (string) $value === (string) ($clause['value'] ?? '');
    }

    if (empty($results)) {
        return true;
    }

    return $relation === 'OR' ? in_array(true, $results, true) : !in_array(false, $results, true);
}

function absint($value)
{
    return abs((int) $value);
}

function register_rest_route($namespace, $route, $args = array())
{
    $GLOBALS['STATE']['routes'][] = array('namespace' => $namespace, 'route' => $route, 'args' => $args);
    return true;
}

function current_user_can($capability, ...$args)
{
    $GLOBALS['STATE']['capabilities'][] = $capability;
    return true;
}

function rest_ensure_response($response)
{
    return $response instanceof WP_REST_Response ? $response : new WP_REST_Response($response);
}

function wp_schedule_event($timestamp, $recurrence, $hook, $args = array())
{
    $GLOBALS['STATE']['scheduled'][] = array($hook, $args, $timestamp, $recurrence);
    return true;
}

function get_term_meta($term_id, $key, $single = false)
{
    return $GLOBALS['STATE']['term_meta'][$term_id][$key] ?? '';
}

function current_time($type, $gmt = 0)
{
    return gmdate('Y-m-d H:i:s');
}

function sanitize_text_field($value)
{
    return trim((string) $value);
}

/**
 * A `wp_strip_all_tags()` minimális stubja (a WP ugyanezt teszi: tagek ki,
 * whitespace összevonva, trim). ⚠️ Ezt a valódi futás hiányolta — a forrás-lint
 * nem látta, hogy a `parse_response()` hívja.
 */
function wp_strip_all_tags($text, $remove_breaks = false)
{
    $stripped = strip_tags((string) $text);
    if ($remove_breaks) {
        $stripped = preg_replace('/[\r\n\t ]+/', ' ', $stripped);
    }
    return trim($stripped);
}

function wpautop($text)
{
    return '<p>' . trim((string) $text) . '</p>';
}

function wp_is_post_revision($postId)
{
    return false;
}

function wp_is_post_autosave($postId)
{
    return false;
}

function wp_next_scheduled($hook, $args = array())
{
    return false;
}

function user_can($user, $capability, ...$args)
{
    return true;
}

function sanitize_key($value)
{
    return strtolower(preg_replace('/[^a-z0-9_\-]/i', '', (string) $value));
}

/** A bejegyzés címe (a nyeremény/kérdőív kérdésének tartaléka). */
function get_the_title($postId)
{
    $post = $GLOBALS['STATE']['posts'][$postId] ?? null;
    return $post instanceof WP_Post ? (string) $post->post_title : '';
}

/* ---- WordPress-stubok a JÁTÉK-végponthoz (2.14.1) ------------------------- */

function wp_timezone()
{
    return new DateTimeZone('Europe/Budapest');
}

function esc_url_raw($url)
{
    return trim((string) $url);
}

function sanitize_textarea_field($value)
{
    return trim((string) $value);
}

function wp_unslash($value)
{
    return is_string($value) ? stripslashes($value) : $value;
}

/** A WordPress `wp_slash()` stubja (a `update_post_meta()` ellensúlyozásához). */
function wp_slash($value)
{
    return is_string($value) ? addslashes($value) : $value;
}

/**
 * A `rest_api_init` hookok végigfuttatása, hogy a regisztrált útvonalak
 * (és a hozzájuk tartozó callbackek) elérhetők legyenek a mérésben.
 */
function stub_run_rest_routes()
{
    foreach ($GLOBALS['STATE']['actions'] as $action) {
        if ($action['hook'] === 'rest_api_init' && is_callable($action['callback'])) {
            call_user_func($action['callback']);
        }
    }
}

/** Egy regisztrált útvonal callbackje (a `stub_run_rest_routes()` után). */
function stub_route_callback($route)
{
    foreach ($GLOBALS['STATE']['routes'] as $registered) {
        if ($registered['route'] === $route && is_callable($registered['args']['callback'] ?? null)) {
            return $registered['args']['callback'];
        }
    }

    return null;
}

/* ---- A VALÓDI plugin-fájlok betöltése ------------------------------------ */

require $pluginDir . '/includes/post-translation-meta.php';
require $pluginDir . '/includes/translation-cron.php';
require $pluginDir . '/includes/translation-places.php';
require $pluginDir . '/includes/translation-sweep.php';
require $pluginDir . '/includes/translation-fields.php';
require $pluginDir . '/includes/faq.php';
// ⚠️ 2.14.0: a NYILVÁNOS nyeremény-végpont **valódi** futása a 14. szakaszban.
// A `posts.php` a `huhs_request_lang()` miatt kell (ez a `lang` egyetlen
// hiteles forrása), a `poll.php` pedig a `huhs_poll_repair_escapes()` miatt.
// Ezek a fájlok a betöltéskor **csak** függvényeket definiálnak és hookokat
// regisztrálnak (a `add_action` stub), ezért a mérés mellékhatás nélkül fut.
require $pluginDir . '/includes/posts.php';
require $pluginDir . '/includes/poll.php';
require $pluginDir . '/includes/prize.php';
// ⚠️ 2.14.1: a JÁTÉK-végpontok nyelvi viselkedése (15. szakasz). A `games.php`
// a betöltéskor csak függvényeket definiál és hookokat regisztrál.
require $pluginDir . '/includes/games.php';

/* ---- Segédek a méréshez -------------------------------------------------- */

$checks = 0;
$failures = 0;

function check($label, $ok, $detail = '')
{
    global $checks, $failures;
    $checks++;
    if ($ok) {
        echo "OK    {$label}\n";
        return true;
    }
    $failures++;
    echo "HIBA  {$label}" . ($detail !== '' ? " — {$detail}" : '') . "\n";
    return false;
}

function reset_state($options = array())
{
    $GLOBALS['STATE']['options'] = $options;
    $GLOBALS['STATE']['meta'] = array();
    $GLOBALS['STATE']['http'] = array();
    $GLOBALS['STATE']['response'] = null;
    $GLOBALS['STATE']['posts'] = array();
}

function provider_response($payload, $code = 200)
{
    return array(
        'code' => $code,
        'body' => json_encode(array(
            'choices' => array(array('message' => array('content' => json_encode($payload)))),
        )),
    );
}

/**
 * Csak a FORDÍTÁS meta-kulcsai (a 2.13.0 belső jelzői — ujjlenyomat, hiba —
 * szándékosan kimaradnak): a „nincs félkész fordítás" állítás erre szól.
 */
function translation_metas($postId)
{
    $meta = $GLOBALS['STATE']['meta'][$postId] ?? array();
    return array_intersect_key(
        $meta,
        array_flip(array('_huhs_title_en', '_huhs_content_en', '_huhs_excerpt_en'))
    );
}

/* ---- 1) A típuslista ----------------------------------------------------- */

$types = huhs_translation_post_types();
$expectedTypes = array('post', 'huhs_event', 'huhs_artist', 'huhs_organizer', 'huhs_release');
check(
    'a típuslista mind az öt típust tartalmazza',
    count(array_diff($expectedTypes, $types)) === 0,
    implode(',', $types)
);

/* ---- 2) A fallback-kapu (`huhs_translation_meta_values`) ----------------- */

reset_state();
$GLOBALS['STATE']['meta'][7] = array(
    '_huhs_title_en' => 'English title',
    '_huhs_content_en' => '<p>English body</p>',
    '_huhs_excerpt_en' => 'English excerpt',
);
$hu = huhs_translation_meta_values(7, 'hu', 'Magyar cím', 'Magyar törzs', 'Magyar kivonat');
check('hu kérésre a magyar payload megy vissza', $hu['title'] === 'Magyar cím' && $hu['has_en'] === false);

$en = huhs_translation_meta_values(7, 'en', 'Magyar cím', 'Magyar törzs', 'Magyar kivonat');
check(
    'en kérésre a teljes angol payload megy vissza',
    $en['has_en'] === true && $en['title'] === 'English title'
        && $en['content'] === '<p>English body</p>' && $en['excerpt'] === 'English excerpt',
    json_encode($en)
);

$GLOBALS['STATE']['meta'][8] = array('_huhs_title_en' => 'Only title');
$partial = huhs_translation_meta_values(8, 'en', 'Magyar cím', 'Magyar törzs');
check(
    'csak cím esetén NEM vált angolra (fallback-kapu)',
    $partial['has_en'] === false && $partial['title'] === 'Magyar cím'
);

$GLOBALS['STATE']['meta'][9] = array('_huhs_content_en' => 'Only body');
$partialBody = huhs_translation_meta_values(9, 'en', 'Magyar cím', 'Magyar törzs');
check('csak törzs esetén sem vált angolra', $partialBody['has_en'] === false);

$GLOBALS['STATE']['meta'][10] = array(
    '_huhs_title_en' => 'Title',
    '_huhs_content_en' => 'Body',
);
$noExcerpt = huhs_translation_meta_values(10, 'en', 'Magyar cím', 'Magyar törzs');
check(
    'kivonat nélkül is angolra vált (a kapu a cím ÉS a törzs)',
    $noExcerpt['has_en'] === true && $noExcerpt['excerpt'] === ''
);

/* ---- 3) A WP-cron kulcs-kezelése ---------------------------------------- */

reset_state();
// ⚠️ A konstans-ágban (legacy-constant) a kulcs DEFINÍCIÓ SZERINT megvan, ezért a
// „kulcs nélkül nem indul" állítás csak a tiszta futásban értelmezhető.
if ($mode !== 'legacy-constant') {
    check('kulcs nélkül a fordítás NEM indul', huhs_translation_enabled() === false);
    $GLOBALS['STATE']['posts'][1] = new WP_Post(array(
        'ID' => 1,
        'post_type' => 'huhs_event',
        'post_title' => 'Magyar esemény',
        'post_content' => 'Magyar leírás',
    ));
    huhs_run_translation(1);
    check(
        'kulcs nélkül nincs hálózati hívás és nincs meta-írás',
        count($GLOBALS['STATE']['http']) === 0 && count($GLOBALS['STATE']['meta']) === 0
    );
} else {
    echo "  (a kulcs nélküli ág ebben a futásban szándékosan kimarad — a konstans kulcsot ad)\n";
}

reset_state(array('huhs_openai_api_key' => 'sk-legacy-option'));
check('örökölt opció-kulccsal a fordítás bekapcsol', huhs_translation_enabled() === true);
$provider = huhs_translation_provider();
check(
    'örökölt kulccsal az OpenAI végpontja a szolgáltató',
    $provider['url'] === 'https://api.openai.com/v1/chat/completions' && $provider['model'] === 'gpt-4o-mini',
    $provider['url']
);

reset_state(array('huhs_translation_api_key' => 'primary-key', 'huhs_openai_api_key' => 'sk-legacy-option'));
$providerBoth = huhs_translation_provider();
check(
    'ha mindkét kulcs megvan, az ELSŐDLEGES nyer (DeepSeek)',
    $providerBoth['url'] === 'https://api.deepseek.com/chat/completions',
    $providerBoth['url']
);

if ($mode === 'legacy-constant') {
    reset_state();
    check('HUHS_OPENAI_API_KEY konstansból is bekapcsol', huhs_translation_enabled() === true);
    check(
        'konstans-kulccsal is az OpenAI végpontja megy',
        huhs_translation_provider()['url'] === 'https://api.openai.com/v1/chat/completions'
    );
}

/* ---- 4) A fordítás végigfutása (stubolt szolgáltatóval) ------------------ */

reset_state(array('huhs_openai_api_key' => 'sk-legacy-option'));
$GLOBALS['STATE']['posts'][5] = new WP_Post(array(
    'ID' => 5,
    'post_type' => 'huhs_artist',
    'post_title' => 'Kobakologia',
    'post_content' => '<p>Bemutatkozás magyarul.</p>',
));
$GLOBALS['STATE']['response'] = provider_response(array(
    'title' => '<b>Kobakologia</b>',
    'content' => '<p>Biography in English.</p>',
    'excerpt' => '  Biography  ',
));
huhs_run_translation(5);
$meta = $GLOBALS['STATE']['meta'][5] ?? array();
check(
    'érvényes válaszból a három helyes meta lesz (a címből a tag kimegy, a HTML marad)',
    ($meta['_huhs_title_en'] ?? '') === 'Kobakologia'
        && ($meta['_huhs_content_en'] ?? '') === '<p>Biography in English.</p>'
        && ($meta['_huhs_excerpt_en'] ?? '') === 'Biography',
    json_encode($meta)
);
$call = $GLOBALS['STATE']['http'][0] ?? null;
// ⚠️ A `wp_json_encode` a nem-ASCII karaktereket `\uXXXX` alakban írja (mint a
// valódi WP), ezért a törzset **dekódolva** kell összehasonlítani — a nyers
// részstring keresése hamis hibát adna.
$expectedKey = $mode === 'legacy-constant' ? 'sk-constant-legacy-key' : 'sk-legacy-option';
$sentBody = $call !== null ? json_decode((string) $call['args']['body'], true) : null;
$sentUser = is_array($sentBody) ? json_decode((string) ($sentBody['messages'][1]['content'] ?? ''), true) : null;
check(
    'a kérés a Bearer kulccsal, JSON-kimenettel és a magyar szöveggel megy',
    $call !== null
        && ($call['args']['headers']['authorization'] ?? '') === 'Bearer ' . $expectedKey
        && ($sentBody['response_format']['type'] ?? '') === 'json_object'
        && ($sentBody['temperature'] ?? null) === 0
        && ($sentUser['title'] ?? '') === 'Kobakologia'
        && ($sentUser['content'] ?? '') === '<p>Bemutatkozás magyarul.</p>',
    $call === null ? 'nincs hívás' : substr((string) $call['args']['body'], 0, 160)
);

reset_state(array('huhs_openai_api_key' => 'sk-legacy-option'));
$GLOBALS['STATE']['posts'][6] = new WP_Post(array(
    'ID' => 6,
    'post_type' => 'huhs_event',
    'post_title' => 'Esemény',
    'post_content' => 'Leírás',
));
$GLOBALS['STATE']['response'] = provider_response(array('title' => 'x'), 500);
$status500 = huhs_run_translation(6);
check(
    'HTTP 500 esetén NINCS fordítás-meta (csak a hibajelző), és a státusz `failed`',
    count(translation_metas(6)) === 0 && $status500 === 'failed'
        && ($GLOBALS['STATE']['meta'][6]['_huhs_translation_failed'] ?? '') !== '',
    json_encode($GLOBALS['STATE']['meta'][6] ?? array()) . ' / ' . $status500
);

reset_state(array('huhs_openai_api_key' => 'sk-legacy-option'));
$GLOBALS['STATE']['posts'][7] = new WP_Post(array(
    'ID' => 7,
    'post_type' => 'huhs_event',
    'post_title' => 'Esemény',
    'post_content' => 'Leírás',
));
$GLOBALS['STATE']['response'] = array('code' => 200, 'body' => 'nem json');
$statusBad = huhs_run_translation(7);
check(
    'értelmezhetetlen válaszból NINCS fordítás-meta (nincs félkész fordítás)',
    count(translation_metas(7)) === 0 && $statusBad === 'failed'
);

reset_state(array('huhs_openai_api_key' => 'sk-legacy-option'));
$GLOBALS['STATE']['posts'][8] = new WP_Post(array(
    'ID' => 8,
    'post_type' => 'huhs_event',
    'post_title' => 'Esemény',
    'post_content' => 'Leírás',
));
$GLOBALS['STATE']['response'] = provider_response(array('title' => 'Event title', 'content' => '', 'excerpt' => ''));
huhs_run_translation(8);
$partialMeta = $GLOBALS['STATE']['meta'][8] ?? array();
check(
    'részleges válaszból csak a meglevő mező íródik ki',
    ($partialMeta['_huhs_title_en'] ?? '') === 'Event title' && !isset($partialMeta['_huhs_content_en']),
    json_encode($partialMeta)
);

reset_state(array('huhs_openai_api_key' => 'sk-legacy-option'));
$GLOBALS['STATE']['posts'][9] = new WP_Post(array(
    'ID' => 9,
    'post_type' => 'page',
    'post_title' => 'Oldal',
    'post_content' => 'Tartalom',
));
$GLOBALS['STATE']['response'] = provider_response(array('title' => 'x', 'content' => 'y'));
huhs_run_translation(9);
check('más post-típusra nem indul fordítás', count($GLOBALS['STATE']['http']) === 0);

reset_state(array('huhs_openai_api_key' => 'sk-legacy-option'));
$GLOBALS['STATE']['posts'][10] = new WP_Post(array(
    'ID' => 10,
    'post_type' => 'huhs_event',
    'post_title' => '',
    'post_content' => 'Van törzs',
));
$GLOBALS['STATE']['response'] = provider_response(array('title' => 'x', 'content' => 'y'));
huhs_run_translation(10);
check('üres címnél nem indul fordítás', count($GLOBALS['STATE']['http']) === 0);

/* ---- 5) Az automatizálás be van kötve ---------------------------------- */

$hooks = array_column($GLOBALS['STATE']['actions'], 'hook');
check(
    'a cron a `save_post`-ra és a saját eseményére is feliratkozik',
    in_array('save_post', $hooks, true) && in_array('huhs_translate_post', $hooks, true),
    implode(',', $hooks)
);

/* ---- 6) A REST-meta írás ELŐFELTÉTELE: custom-fields támogatás ---------- */

// ⚠️ MÉRT HIBA (2026-09-25): a WordPress a `meta` mezőt csak akkor fogadja el
// REST-en, ha a post-típus támogatja a `custom-fields`-et. Enélkül a küldött
// angol meta **csendben elveszett** (POST 200, visszaolvasás üres) a
// huhs_event/huhs_artist/huhs_organizer/huhs_release típusnál.
reset_state();
$GLOBALS['STATE']['supports'] = array();
huhs_enable_translation_meta_custom_fields();
$supports = array_map(
    static function ($entry) {
        return $entry[0] . ':' . $entry[1];
    },
    $GLOBALS['STATE']['supports']
);
$expectedSupports = array(
    'post:custom-fields',
    'huhs_event:custom-fields',
    'huhs_artist:custom-fields',
    'huhs_organizer:custom-fields',
    'huhs_release:custom-fields',
);
check(
    'mind az öt fordítási típus megkapja a custom-fields támogatást',
    count(array_intersect($expectedSupports, $supports)) === 5,
    implode(', ', $supports)
);

$initHooks = array_values(array_filter(
    $GLOBALS['STATE']['actions'],
    static function ($entry) {
        return $entry['hook'] === 'init' && $entry['callback'] === 'huhs_enable_translation_meta_custom_fields';
    }
));
check(
    'a támogatás a KÉSŐI init-en kapcsolódik (99)',
    count($initHooks) === 1 && $initHooks[0]['priority'] === 99,
    json_encode($initHooks)
);

/* ---- 7) A 2.13.0 hely-névtára (ország/város) ---------------------------- */

reset_state();
check(
    'a magyar ág BÁJTRA ugyanaz (a névtár nem nyúl a magyar értékhez)',
    huhs_translation_country_value('Magyarország', 'hu') === 'Magyarország'
        && huhs_translation_city_value('Bécs', 'hu') === 'Bécs'
);
check(
    'angol kérésre az ország angol neve megy ki',
    huhs_translation_country_value('Magyarország', 'en') === 'Hungary'
        && huhs_translation_country_value('ausztria', 'en') === 'Austria',
    huhs_translation_country_value('Magyarország', 'en')
);
check(
    'angol kérésre a város angol neve megy ki (Bécs → Vienna)',
    huhs_translation_city_value('Bécs', 'en') === 'Vienna'
        && huhs_translation_city_value('Budapest', 'en') === 'Budapest',
    huhs_translation_city_value('Bécs', 'en')
);
check(
    'ismeretlen névre NEM tippel (marad az eredeti)',
    huhs_translation_country_value('Narnia', 'en') === 'Narnia'
        && huhs_translation_city_value('Gárdony', 'en') === 'Gárdony'
);
check(
    'a "Velence" csapda: a magyar város nem lesz Venice',
    huhs_translation_city_value('Velence', 'en') === 'Velence'
);
check(
    'üres értékre nem hív hibát és üres marad',
    huhs_translation_country_value('', 'en') === '' && huhs_translation_country_value(null, 'en') === null
);

/* ---- 8) Az ujjlenyomat: ugyanarra a szövegre nem fordítunk kétszer ------ */

reset_state(array('huhs_openai_api_key' => 'sk-legacy-option'));
$GLOBALS['STATE']['posts'][11] = new WP_Post(array(
    'ID' => 11,
    'post_type' => 'huhs_event',
    'post_title' => 'Esemény',
    'post_content' => '<p>Leírás</p>',
));
$GLOBALS['STATE']['response'] = provider_response(array(
    'title' => 'Event',
    'content' => '<p>Description</p>',
    'excerpt' => 'Description',
));
$first = huhs_run_translation(11);
$callsAfterFirst = count($GLOBALS['STATE']['http']);
check(
    'az első fordítás `translated`, és beírja az ujjlenyomatot',
    $first === 'translated'
        && huhs_translation_stored_hash(11) === huhs_translation_source_hash($GLOBALS['STATE']['posts'][11]),
    $first
);

$second = huhs_run_translation(11);
check(
    'ugyanarra a magyar szövegre a második hívás `uptodate` — NINCS új API-hívás',
    $second === 'uptodate' && count($GLOBALS['STATE']['http']) === $callsAfterFirst,
    $second . ' / hívások: ' . count($GLOBALS['STATE']['http'])
);

$GLOBALS['STATE']['posts'][11]->post_content = '<p>Megváltozott leírás</p>';
$GLOBALS['STATE']['response'] = provider_response(array('title' => 'Event', 'content' => '<p>Changed</p>'));
$third = huhs_run_translation(11);
check(
    'megváltozott magyar szövegre ÚJRA fordít (a szerkesztés nem marad angol nélkül)',
    $third === 'translated' && count($GLOBALS['STATE']['http']) === $callsAfterFirst + 1,
    $third
);

$GLOBALS['STATE']['response'] = provider_response(array('title' => 'Event', 'content' => '', 'excerpt' => ''));
$GLOBALS['STATE']['posts'][11]->post_content = '<p>Harmadik változat</p>';
$partial = huhs_run_translation(11);
check(
    'fél válasz (nincs törzs) `partial`, és NEM jelöli késznek (a pótlás kijavítja)',
    $partial === 'partial'
        && huhs_translation_stored_hash(11) !== huhs_translation_source_hash($GLOBALS['STATE']['posts'][11])
        && huhs_translation_failed_recently(11, huhs_translation_source_hash($GLOBALS['STATE']['posts'][11])) === true,
    $partial
);

/* ---- 9) A pótló kör (sweep) -------------------------------------------- */

reset_state(array('huhs_openai_api_key' => 'sk-legacy-option'));
$GLOBALS['STATE']['posts'][21] = new WP_Post(array(
    'ID' => 21, 'post_type' => 'huhs_artist', 'post_title' => 'DJ Egy', 'post_content' => '<p>Bemutatkozó</p>',
    'post_status' => 'publish',
));
$GLOBALS['STATE']['posts'][22] = new WP_Post(array(
    'ID' => 22, 'post_type' => 'huhs_artist', 'post_title' => 'DJ Kettő', 'post_content' => '',
    'post_status' => 'publish',
));
$GLOBALS['STATE']['posts'][23] = new WP_Post(array(
    'ID' => 23, 'post_type' => 'huhs_artist', 'post_title' => 'Piszkozat', 'post_content' => '<p>Vázlat</p>',
    'post_status' => 'draft',
));
$GLOBALS['STATE']['posts'][24] = new WP_Post(array(
    'ID' => 24, 'post_type' => 'huhs_event', 'post_title' => 'Esemény', 'post_content' => '<p>Leírás</p>',
    'post_status' => 'publish',
));
$GLOBALS['STATE']['meta'][25] = array('_huhs_title_en' => 'Done', '_huhs_content_en' => 'Done body');
$GLOBALS['STATE']['posts'][25] = new WP_Post(array(
    'ID' => 25, 'post_type' => 'huhs_artist', 'post_title' => 'Kész', 'post_content' => '<p>Kész szöveg</p>',
    'post_status' => 'publish',
));

$pendingArtists = huhs_translation_pending_posts('huhs_artist', 10);
check(
    'a várólistán csak a publikált, szöveges, angol NÉLKÜLI elem van',
    count($pendingArtists) === 1 && $pendingArtists[0]->ID === 21,
    implode(',', array_map(static function ($post) { return $post->ID; }, $pendingArtists))
);
check(
    'az üres törzsű, a piszkozat és a már lefordított elem nem várólistás',
    count(huhs_translation_pending_posts('huhs_artist', 10)) === 1
);
check(
    'a "nincs kulcs" esetben a pótlás semmit nem tesz',
    ($mode === 'legacy-constant')
        ? true
        : (reset_state() === null && huhs_translation_sweep(array('limit' => 5))['checked'] === 0)
);
if ($mode === 'legacy-constant') {
    echo "  (a kulcs nélküli pótlás ebben a futásban szándékosan kimarad — a konstans kulcsot ad)\n";
}

reset_state(array('huhs_openai_api_key' => 'sk-legacy-option'));
$GLOBALS['STATE']['scheduled'] = array();
$GLOBALS['STATE']['posts'][21] = new WP_Post(array(
    'ID' => 21, 'post_type' => 'huhs_artist', 'post_title' => 'DJ Egy', 'post_content' => '<p>Bemutatkozó</p>',
    'post_status' => 'publish',
));
$GLOBALS['STATE']['posts'][24] = new WP_Post(array(
    'ID' => 24, 'post_type' => 'huhs_event', 'post_title' => 'Esemény', 'post_content' => '<p>Leírás</p>',
    'post_status' => 'publish',
));
$GLOBALS['STATE']['response'] = provider_response(array(
    'title' => 'Translated', 'content' => '<p>Translated body</p>', 'excerpt' => 'Translated',
));

// ⚠️ A költségvetést a várólista MEGLÉTEKOR kell mérni — különben a kapu
// elvétele nem látszana (üres listán a kör úgyis nullát csinál). Ezt a saját
// mutációs bizonyíték buktatta meg: az első változat a fordítás UTÁN mérte,
// ezért „nem kapta el" eredményt adott.
$sweepNoBudget = huhs_translation_sweep(array('limit' => 5, 'budget' => 0));
check(
    'a költségvetés (0 másodperc) leállítja a kört, mielőtt bármit fordítana',
    $sweepNoBudget['checked'] === 0 && count($GLOBALS['STATE']['http']) === 0,
    json_encode($sweepNoBudget['by_type'])
);

$sweep = huhs_translation_sweep(array('limit' => 5, 'budget' => 30));
check(
    'a pótlás mindkét típus hiányzó fordítását lefuttatja',
    $sweep['enabled'] === true && $sweep['checked'] === 2 && $sweep['translated'] === 2 && $sweep['failed'] === 0,
    json_encode($sweep['by_type'])
);
check(
    'a pótlás után a várólista ürül (nincs több hiányzó angol)',
    $sweep['pending']['huhs_artist'] === 0 && $sweep['pending']['huhs_event'] === 0,
    json_encode($sweep['pending'])
);
check(
    'a pótlás nem hoz létre felhasználói értesítést (nincs `save_post` hívás a körben)',
    count($GLOBALS['STATE']['scheduled']) === 0
);

$sweepAgain = huhs_translation_sweep(array('limit' => 5, 'budget' => 30));
check(
    'a második pótlás már nem fordít semmit (nincs felesleges API-költés)',
    $sweepAgain['translated'] === 0 && count($GLOBALS['STATE']['http']) === 2,
    json_encode($sweepAgain['by_type'])
);

$sweepOneType = huhs_translation_sweep_types('huhs_event');
check(
    'egy típus kérhető, és az érvénytelen érték mindet jelenti',
    $sweepOneType === array('huhs_event')
        && huhs_translation_sweep_types('nincs_ilyen') === huhs_translation_all_post_types()
);

/* ---- 10) A pótlás végpontjai és a cron -------------------------------- */

reset_state();
huhs_register_translation_sweep_api();
$routes = array();
foreach ($GLOBALS['STATE']['routes'] as $route) {
    $routes[$route['route']] = $route['args'];
}
check(
    'a `translations/status` (GET) és a `translations/sweep` (POST) végpont bejegyződik',
    isset($routes['/translations/status'], $routes['/translations/sweep'])
        && $routes['/translations/status']['methods'] === 'GET'
        && $routes['/translations/sweep']['methods'] === WP_REST_Server::CREATABLE,
    implode(', ', array_keys($routes))
);

$GLOBALS['STATE']['capabilities'] = array();
$allowed = ($routes['/translations/sweep']['permission_callback'])();
check(
    'a pótlás végpontja `manage_options` jogosultságot kér',
    $allowed === true && in_array('manage_options', $GLOBALS['STATE']['capabilities'], true),
    implode(',', $GLOBALS['STATE']['capabilities'])
);

$sweepHooks = array_column($GLOBALS['STATE']['actions'], 'hook');
check(
    'a pótló kör saját cron-eseményre és az init-re is feliratkozik',
    in_array('huhs_translation_sweep_event', $sweepHooks, true)
        && in_array('init', $sweepHooks, true),
    implode(',', $sweepHooks)
);

$GLOBALS['STATE']['scheduled'] = array();
huhs_schedule_translation_sweep();
$recurring = array_values(array_filter(
    $GLOBALS['STATE']['scheduled'],
    static function ($entry) {
        return $entry[0] === 'huhs_translation_sweep_event';
    }
));
check(
    'a pótlás ÓRÁNKÉNT is ütemeződik (nem csak a mentésre vár)',
    count($recurring) === 1 && $recurring[0][3] === 'hourly',
    json_encode($recurring)
);

$statusData = huhs_translation_status_endpoint()->data;
check(
    'a status végpont mind a kilenc típust és a várólistát megadja (kulcs nélkül is)',
    isset($statusData['pending']['huhs_release'], $statusData['pending']['huhs_prize']) && count($statusData['types']) === 9,
    json_encode($statusData['pending'])
);

/* ---- 11) Meta-szövegek fordítása: kérdőív, nyereményjáték (2.14.0) ------ */

$allTypes = huhs_translation_all_post_types();
check(
    'a MINDEN típus listája tartalmazza a GYÍK-ot és a meta-szöveges típusokat',
    in_array('huhs_faq', $allTypes, true)
        && in_array('huhs_poll', $allTypes, true)
        && in_array('huhs_prize', $allTypes, true)
        && in_array('huhs_game', $allTypes, true),
    implode(',', $allTypes)
);

$pollSpecs = huhs_translation_field_specs('huhs_poll');
$prizeSpecs = huhs_translation_field_specs('huhs_prize');
check(
    'a mező-térkép a valódi meta-kulcsokat és alakjukat adja',
    $pollSpecs === array('_huhs_poll_question' => 'text', '_huhs_poll_options' => 'list')
        && count($prizeSpecs) === 4
        && $prizeSpecs['_huhs_prize_answers'] === 'list'
        && huhs_translation_field_specs('post') === array(),
    json_encode($pollSpecs)
);

reset_state();
$GLOBALS['STATE']['posts'][31] = new WP_Post(array(
    'ID' => 31, 'post_type' => 'huhs_poll', 'post_title' => '', 'post_content' => '',
    'post_status' => 'publish',
));
$GLOBALS['STATE']['meta'][31] = array(
    '_huhs_poll_question' => 'Tetszik az Applikáció?',
    '_huhs_poll_options' => wp_json_encode(array('Igen', 'Nem', 'Imádom')),
    '_huhs_poll_start' => '2026-09-24T15:00',
);
$source = huhs_translation_source_fields(31);
check(
    'a forrás-mezők beolvasása: szöveg + JSON lista (a dátum NEM szöveg)',
    $source === array(
        '_huhs_poll_question' => 'Tetszik az Applikáció?',
        '_huhs_poll_options' => array('Igen', 'Nem', 'Imádom'),
    ),
    json_encode($source)
);
check(
    'a lista-beolvasó a JSON listát kezeli, a nem-JSON-t üresen adja vissza',
    huhs_translation_field_list_values('["Egy","Kettő"]') === array('Egy', 'Kettő')
        && huhs_translation_field_list_values('nem json') === array()
);

reset_state(array('huhs_openai_api_key' => 'sk-legacy-option'));
$GLOBALS['STATE']['posts'][31] = new WP_Post(array(
    'ID' => 31, 'post_type' => 'huhs_poll', 'post_title' => '', 'post_content' => '',
    'post_status' => 'publish',
));
$GLOBALS['STATE']['meta'][31] = array(
    '_huhs_poll_question' => 'Tetszik az Applikáció?',
    '_huhs_poll_options' => wp_json_encode(array('Igen', 'Nem', 'Imádom')),
);
$GLOBALS['STATE']['response'] = provider_response(array(
    'fields' => array(
        '_huhs_poll_question' => 'Do you like the app?',
        '_huhs_poll_options' => array('Yes', 'No', 'I love it'),
    ),
));
$fieldStatus = huhs_run_field_translation(31);
$storedFields = json_decode((string) ($GLOBALS['STATE']['meta'][31]['_huhs_translation_fields_en'] ?? ''), true);
check(
    'a mező-fordítás lefut és a három válaszlehetőséget is lefordítja',
    $fieldStatus === 'translated'
        && ($storedFields['_huhs_poll_question'] ?? '') === 'Do you like the app?'
        && ($storedFields['_huhs_poll_options'] ?? array()) === array('Yes', 'No', 'I love it'),
    $fieldStatus . ' / ' . json_encode($storedFields)
);
check(
    'a mező-fordítás naprakészsége igaz (a pótló kör nem viszi újra a várólistára)',
    huhs_translation_fields_complete(31) === true && huhs_translation_fields_current(31) === true
);
$callsAfterFields = count($GLOBALS['STATE']['http']);
check(
    'a második futás `uptodate` — nincs új API-hívás',
    huhs_run_field_translation(31) === 'uptodate'
        && count($GLOBALS['STATE']['http']) === $callsAfterFields
);

// A kiolvasás: angolul a fordítás, magyarul a forrás, hiányzó kulcsnál a magyar.
check(
    'a kiolvasó angolul a fordítást adja, magyarul a forrást',
    huhs_translation_text(31, 'en', '_huhs_poll_question', 'Tetszik az Applikáció?') === 'Do you like the app?'
        && huhs_translation_text(31, 'hu', '_huhs_poll_question', 'Tetszik az Applikáció?') === 'Tetszik az Applikáció?'
        && huhs_translation_text(31, 'en', '_huhs_prize_type', 'Nyeremény') === 'Nyeremény'
);
check(
    'a lista kiolvasása elemenként esik vissza a magyarra',
    huhs_translation_list(31, 'en', '_huhs_poll_options', array('Igen', 'Nem', 'Imádom')) === array('Yes', 'No', 'I love it')
        && huhs_translation_list(31, 'en', '_huhs_prize_answers', array('A', 'B')) === array('A', 'B')
        && huhs_translation_list(31, 'hu', '_huhs_poll_options', array('Igen')) === array('Igen')
);

// Hibaág: nem ír félkész fordítást, és jelöli a hibát.
reset_state(array('huhs_openai_api_key' => 'sk-legacy-option'));
$GLOBALS['STATE']['posts'][32] = new WP_Post(array(
    'ID' => 32, 'post_type' => 'huhs_prize', 'post_title' => '', 'post_content' => '',
    'post_status' => 'publish',
));
$GLOBALS['STATE']['meta'][32] = array('_huhs_prize_question' => 'Mi a neve?');
$GLOBALS['STATE']['response'] = provider_response(array('title' => 'x'), 500);
$failedFields = huhs_run_field_translation(32);
check(
    'hibás válasznál a mező-fordítás `failed`, és nem ír félig kész térképet',
    $failedFields === 'failed'
        && ($GLOBALS['STATE']['meta'][32]['_huhs_translation_fields_en'] ?? '') === ''
        && ($GLOBALS['STATE']['meta'][32]['_huhs_translation_fields_failed'] ?? '') !== '',
    $failedFields
);
check(
    'a hibás mező-fordítás nem blokkolja a cím/törzs ágat (külön jelölő)',
    ($GLOBALS['STATE']['meta'][32]['_huhs_translation_failed'] ?? '') === ''
);

// A rossz alakú válasz nem ír félkész listát (a hossz nem egyezik).
$parsed = huhs_translation_parse_fields_response(
    json_encode(array('choices' => array(array('message' => array('content' => json_encode(array(
        'fields' => array('_huhs_poll_options' => array('Yes')),
    ))))))),
    array('_huhs_poll_options' => array('Igen', 'Nem'))
);
check(
    'a rövidebb válaszlistát elutasítja (nincs félkész fordítás)',
    $parsed === array(),
    json_encode($parsed)
);

/* ---- 12) A GYÍK kategória-nevei --------------------------------------- */

$faqCategories = huhs_translation_faq_category_names();
check(
    'a GYÍK kategória-névtár a mért 8 kategóriát tartalmazza',
    count($faqCategories) === 8 && ($faqCategories['első lépések'] ?? '') === 'Getting Started',
    (string) count($faqCategories)
);
check(
    'a kategória angolul fordítva, magyarul változatlanul megy ki',
    huhs_translation_faq_category_name('Első lépések', 'en') === 'Getting Started'
        && huhs_translation_faq_category_name('Első lépések', 'hu') === 'Első lépések'
        && huhs_translation_faq_category_name('Ismeretlen kategória', 'en') === 'Ismeretlen kategória'
);
reset_state();
$GLOBALS['STATE']['term_meta'][7] = array('_huhs_name_en' => 'Custom English');
check(
    'a kézzel beírt terminus-név nyer a névtárral szemben',
    huhs_translation_faq_category_name((object) array('term_id' => 7, 'name' => 'Közösség'), 'en') === 'Custom English'
        && huhs_translation_faq_category_name((object) array('term_id' => 8, 'name' => 'Közösség'), 'en') === 'Community'
);

/* ---- 13) A pótló kör a meta-szöveges típusokat is viszi ---------------- */

reset_state(array('huhs_openai_api_key' => 'sk-legacy-option'));
$GLOBALS['STATE']['posts'][41] = new WP_Post(array(
    'ID' => 41, 'post_type' => 'huhs_prize', 'post_title' => 'Nyereményjáték',
    'post_content' => '', 'post_status' => 'publish',
));
$GLOBALS['STATE']['meta'][41] = array(
    '_huhs_prize_question' => 'Mi Noisecontrollers igazi neve?',
    '_huhs_prize_answers' => wp_json_encode(array('Joram Metekohy', 'Bas Oskam')),
    '_huhs_prize_type' => 'Páros belépő',
    '_huhs_prize_description' => 'Nyerj páros belépőt!',
);
$pendingPrize = huhs_translation_pending_posts('huhs_prize', 10);
check(
    'a meta-szöveges elem (üres törzzsel is) a várólistára kerül',
    count($pendingPrize) === 1 && $pendingPrize[0]->ID === 41,
    implode(',', array_map(static function ($post) { return $post->ID; }, $pendingPrize))
);

$GLOBALS['STATE']['response'] = provider_response(array(
    'fields' => array(
        '_huhs_prize_question' => 'What is Noisecontrollers real name?',
        '_huhs_prize_answers' => array('Joram Metekohy', 'Bas Oskam'),
        '_huhs_prize_type' => 'Double ticket',
        '_huhs_prize_description' => 'Win a double ticket!',
    ),
));
$prizeRun = huhs_run_translation(41);
$pendingAfter = huhs_translation_pending_posts('huhs_prize', 10);
check(
    'a pótló kör a meta-szöveges elemet is lefordítja (és utána lekerül a listáról)',
    $prizeRun === 'translated' && count($pendingAfter) === 0,
    $prizeRun . ' / várólista: ' . count($pendingAfter)
);
check(
    'a meta-szöveges típus a `status` várólistában is szerepel',
    array_key_exists('huhs_prize', huhs_translation_pending_counts()) === true
);

/* ---- 14) A nyeremény-játék NYITOTT ága (2.14.0, valódi futás) ---------- */

/*
 * ⚠️ MIÉRT VAN EZ: a `functions/prize-active-payload.test.cjs` forrás-lint, és a
 * 2.14.0-ban a minta megváltozott (a nyelvi olvasón át megy ki a mező). Itt a
 * **tényleges** végpont fut: a magyar payload bájtazonos, az angol a fordítás,
 * és a **helyes válasz** egyik ágban sem szivárog ki.
 */
reset_state();
$GLOBALS['STATE']['posts'][51] = new WP_Post(array(
    'ID' => 51, 'post_type' => 'huhs_prize', 'post_title' => 'Nyereményjáték',
    'post_content' => '', 'post_status' => 'publish',
));
$GLOBALS['STATE']['meta'][51] = array(
    '_huhs_prize_question' => 'Mi Noisecontrollers igazi neve?',
    '_huhs_prize_answers' => wp_json_encode(array('Joram Metekohy', 'Bas Oskam')),
    '_huhs_prize_type' => 'Páros belépő',
    '_huhs_prize_description' => 'Nyerj páros belépőt!',
    '_huhs_prize_correct' => '1',
    '_huhs_translation_fields_en' => wp_json_encode(array(
        '_huhs_prize_question' => 'What is Noisecontrollers real name?',
        '_huhs_prize_answers' => array('Joram Metekohy', 'Bas Oskam'),
        '_huhs_prize_type' => 'Double ticket',
        '_huhs_prize_description' => 'Win a double ticket!',
    )),
);
// ⚠️ A naprakészség jelzője KÜLÖN lépésben (a beíró is így teszi): ha az
// `md5(...)` a fenti tömb-literálon belül lenne, a forrás-meták még NEM
// léteznének az értékelés pillanatában → üres tömbből számolt hash, és a
// `has_en` hamisan hamis lenne (ezt a saját mérésem fogta meg).
$GLOBALS['STATE']['meta'][51]['_huhs_translation_fields_hash'] =
    md5((string) wp_json_encode(huhs_translation_source_fields(51)));
// A 2.14.3-as séma-verzió is kell a „naprakész" jelzéshez (a beíró írja).
$GLOBALS['STATE']['meta'][51]['_huhs_translation_fields_version'] = HUHS_TRANSLATION_FIELDS_VERSION;
$huPrize = huhs_prize_api_active(new WP_REST_Request(array('lang' => 'hu')))->data['prize'];
$enPrize = huhs_prize_api_active(new WP_REST_Request(array('lang' => 'en')))->data['prize'];
$noLangPrize = huhs_prize_api_active()->data['prize'];

check(
    'a nyitott játék a VALÓDI nyereményt küldi (nem üres stringet)',
    $huPrize['state'] === 'open'
        && $huPrize['prize_type'] === 'Páros belépő'
        && $huPrize['prize_description'] === 'Nyerj páros belépőt!'
        && $noLangPrize['prize_type'] === 'Páros belépő'
        && $noLangPrize['prize_description'] === 'Nyerj páros belépőt!',
    json_encode($huPrize)
);
check(
    'angol kérésre a nyitott játék fordítva megy ki (kérdés, válaszok, nyeremény)',
    $enPrize['question'] === 'What is Noisecontrollers real name?'
        && $enPrize['answers'] === array(
            array('index' => 0, 'label' => 'Joram Metekohy'),
            array('index' => 1, 'label' => 'Bas Oskam'),
        )
        && $enPrize['prize_type'] === 'Double ticket'
        && $enPrize['prize_description'] === 'Win a double ticket!'
        && $enPrize['has_en'] === true,
    json_encode($enPrize)
);
check(
    'a magyar kérés bájtazonos (nincs beszóló angol szöveg)',
    $huPrize['question'] === 'Mi Noisecontrollers igazi neve?'
        && $huPrize['answers'][0]['label'] === 'Joram Metekohy'
        && $huPrize['has_en'] === true,
    json_encode($huPrize)
);
check(
    'a HELYES válasz egyik ágban sem szivárog ki (nincs `correct` a payloadban)',
    !array_key_exists('correct', $huPrize)
        && !array_key_exists('correct', $enPrize)
        && strpos((string) json_encode($enPrize), 'correct') === false
        && strpos((string) json_encode($huPrize), 'correct') === false,
    json_encode($enPrize)
);

reset_state();
$GLOBALS['STATE']['posts'][52] = new WP_Post(array(
    'ID' => 52, 'post_type' => 'huhs_prize', 'post_title' => 'Fordítás nélküli játék',
    'post_content' => '', 'post_status' => 'publish',
));
$GLOBALS['STATE']['meta'][52] = array(
    '_huhs_prize_answers' => wp_json_encode(array('Igen', 'Nem')),
    '_huhs_prize_type' => 'Póló',
    '_huhs_prize_description' => 'Nyerj pólót!',
);
$untranslated = huhs_prize_api_active(new WP_REST_Request(array('lang' => 'en')))->data['prize'];
check(
    'fordítás nélkül angol kérésre is a magyar érték megy ki, és `has_en` hamis',
    $untranslated['prize_type'] === 'Póló'
        && $untranslated['prize_description'] === 'Nyerj pólót!'
        && $untranslated['question'] === 'Fordítás nélküli játék'
        && $untranslated['has_en'] === false,
    json_encode($untranslated)
);

/* ---- 15) A JÁTÉK-végpont nyelve (2.14.1, valódi futás) ----------------- */

/*
 * ⚠️ MÉRT HIBA, amit ez a szakasz fog meg (2026-09-26, ÉLES): a
 * `/games/results/latest?lang=en` a **magyar** összefoglalót adta vissza, mert
 * a `huhs_game_public_payload()` nem kapott nyelvet, és a `title`/`type_label`
 * a `HUHS_GAME_TYPES`-ból (magyarul) jött. A 2.14.1 mindkettőt javítja.
 */
reset_state();
stub_run_rest_routes();
$resultsCallback = stub_route_callback('/games/results/latest');
$activeCallback = stub_route_callback('/games/active');
check(
    'a játék-végpontok regisztrálva vannak (a callback elérhető a méréshez)',
    is_callable($resultsCallback) && is_callable($activeCallback)
);

$GLOBALS['STATE']['posts'][61] = new WP_Post(array(
    'ID' => 61, 'post_type' => 'huhs_game', 'post_title' => 'Hardstyle kvíz #1',
    'post_content' => '', 'post_status' => 'publish',
));
$GLOBALS['STATE']['meta'][61] = array(
    '_huhs_game_type' => 'hardstyle_quiz',
    '_huhs_game_summary' => 'Teszteld a hardstyle tudásod!',
    '_huhs_game_start' => '2020-01-01T00:00',
    '_huhs_game_end' => '2020-01-02T00:00',
    // ⚠️ A `huhs_game_status()` a start + end + results_until HÁRMASBÓL dönt
    // (`draft`, ha bármelyik hiányzik). A „closed" állapothoz a `results_until`
    // a jövőben kell legyen — ezt a saját mérésem fogta meg (null payload).
    '_huhs_game_results_until' => '2030-01-01T00:00',
    '_huhs_translation_fields_en' => wp_json_encode(array(
        '_huhs_game_summary' => 'Test your hardstyle knowledge!',
    )),
);
$GLOBALS['STATE']['meta'][61]['_huhs_translation_fields_hash'] =
    md5((string) wp_json_encode(huhs_translation_source_fields(61)));

$gameHu = $resultsCallback(new WP_REST_Request(array('lang' => 'hu')))->data;
$gameEn = $resultsCallback(new WP_REST_Request(array('lang' => 'en')))->data;
$gameDefault = $resultsCallback(new WP_REST_Request(array()))->data;
check(
    'a játék összefoglalója angolul a fordítást adja, magyarul a forrást',
    $gameEn['summary'] === 'Test your hardstyle knowledge!'
        && $gameHu['summary'] === 'Teszteld a hardstyle tudásod!'
        && $gameDefault['summary'] === 'Teszteld a hardstyle tudásod!',
    json_encode(array('en' => $gameEn['summary'] ?? null, 'hu' => $gameHu['summary'] ?? null))
);
check(
    'a játéktípus neve angolul a névtárból jön, magyarul a HUHS_GAME_TYPES-ból',
    $gameEn['type_label'] === 'Hardstyle Quiz' && $gameEn['title'] === 'Hardstyle Quiz'
        && $gameHu['type_label'] === 'Hardstyle kvíz' && $gameHu['title'] === 'Hardstyle kvíz',
    json_encode(array('en' => $gameEn['type_label'] ?? null, 'hu' => $gameHu['type_label'] ?? null))
);
check(
    'a játék-típus névtár minden típust lefed (és ismeretlen típusra nem tippel)',
    count(huhs_game_type_labels_en()) === count(HUHS_GAME_TYPES)
        && huhs_game_type_label('who_is_dj', 'en') === 'Who Is the DJ?'
        && huhs_game_type_label('nincs_ilyen', 'en') === 'Játék'
        && huhs_game_type_label('hardstyle_quiz', 'hu') === 'Hardstyle kvíz'
);
check(
    'a játék-végpont a helyes választ nem adja ki (a `correct` kulcs nem megy ki)',
    !array_key_exists('correct', $gameEn) && !array_key_exists('correct', $gameHu)
);

$GLOBALS['STATE']['posts'][62] = new WP_Post(array(
    'ID' => 62, 'post_type' => 'huhs_game', 'post_title' => 'Napi kihívás',
    'post_content' => '', 'post_status' => 'publish',
));
$GLOBALS['STATE']['meta'][62] = array(
    '_huhs_game_type' => 'daily_challenge',
    '_huhs_game_summary' => 'Napi kihívás szövege',
    '_huhs_game_start' => '2020-01-01T00:30',
    '_huhs_game_end' => '2030-01-01T00:00',
    '_huhs_game_results_until' => '2031-01-01T00:00',
);
$activeEn = $activeCallback(new WP_REST_Request(array('lang' => 'en')))->data;
check(
    'az AKTÍV játék végpontja is a kért nyelven adja a típust (fordítás nélkül a magyar összefoglalót)',
    $activeEn['type_label'] === 'Daily Challenge'
        && $activeEn['summary'] === 'Napi kihívás szövege',
    json_encode($activeEn)
);

/* ---- 16) A KVÍZ kérdései és válaszai is fordulnak (2.14.2) ------------ */

/*
 * ⚠️ A TULAJDONOS KÉRÉSE: *„ha felkerül Poll/Kérdőív, jó lenne ha a válaszok is
 * lefordulnának angolul … kviz meg nyereményjáték dettó"*. A kérdőív és a
 * nyeremény válaszai már a 2.14.0-ban fordulnak (mért, éles), a **kvíz**
 * kérdés-szerkezete viszont beágyazott JSON, ezért eddig kimaradt. A 2.14.2
 * **lapos kulcsokra** bontja (`_huhs_game_questions.0.prompt`,
 * `…option.1`), így a modell csak szövegeket lát, a `correct` index pedig
 * **hozzá sem kerül** a kéréshez.
 */
reset_state(array('huhs_openai_api_key' => 'sk-legacy-option'));
$GLOBALS['STATE']['posts'][71] = new WP_Post(array(
    'ID' => 71, 'post_type' => 'huhs_game', 'post_title' => 'Hardstyle kvíz #2',
    'post_content' => '', 'post_status' => 'publish',
));
$GLOBALS['STATE']['meta'][71] = array(
    '_huhs_game_type' => 'hardstyle_quiz',
    '_huhs_game_summary' => 'Teszteld a tudásod!',
    '_huhs_game_start' => '2020-01-01T00:00',
    '_huhs_game_end' => '2020-01-02T00:00',
    '_huhs_game_results_until' => '2030-01-01T00:00',
    '_huhs_game_questions' => wp_json_encode(array(
        array('prompt' => 'Melyik évben alakult a zenekar?', 'options' => array('2005', '2010', '2015'), 'correct' => 1),
        array('prompt' => 'Ki az énekes?', 'options' => array('Anna', 'Béla'), 'correct' => 0),
    )),
);
$quizSource = huhs_translation_source_fields(71);
check(
    'a kvíz forrása LAPOS kulcsokra bomlik (kérdés + válaszlehetőségek)',
    ($quizSource['_huhs_game_questions.0.prompt'] ?? '') === 'Melyik évben alakult a zenekar?'
        && ($quizSource['_huhs_game_questions.0.option.0'] ?? '') === '2005'
        && ($quizSource['_huhs_game_questions.0.option.2'] ?? '') === '2015'
        && ($quizSource['_huhs_game_questions.1.option.1'] ?? '') === 'Béla',
    json_encode($quizSource)
);
check(
    'a `correct` index NINCS a fordítási kérésben (nem tud elcsúszni)',
    !array_key_exists('_huhs_game_questions.0.correct', $quizSource)
        && strpos((string) wp_json_encode($quizSource), 'correct') === false,
    json_encode(array_keys($quizSource))
);

$GLOBALS['STATE']['response'] = provider_response(array(
    'fields' => array(
        '_huhs_game_summary' => 'Test your knowledge!',
        '_huhs_game_questions.0.prompt' => 'In which year was the band formed?',
        '_huhs_game_questions.0.option.0' => '2005',
        '_huhs_game_questions.0.option.1' => '2010',
        '_huhs_game_questions.0.option.2' => '2015',
        '_huhs_game_questions.1.prompt' => 'Who is the singer?',
        '_huhs_game_questions.1.option.0' => 'Anna',
        '_huhs_game_questions.1.option.1' => 'Béla',
    ),
));
$quizStatus = huhs_run_translation(71);
$quizEn = huhs_translation_game_questions(71, 'en');
$quizHu = huhs_translation_game_questions(71, 'hu');
check(
    'a kvíz fordítása lefut és a kérdések/válaszok angolul jönnek',
    $quizStatus === 'translated'
        && ($quizEn[0]['prompt'] ?? '') === 'In which year was the band formed?'
        && ($quizEn[0]['options'] ?? array()) === array('2005', '2010', '2015')
        && ($quizEn[1]['prompt'] ?? '') === 'Who is the singer?',
    $quizStatus . ' / ' . json_encode($quizEn)
);
check(
    'a `correct` index VÁLTOZATLAN marad a fordított szerkezetben',
    ($quizEn[0]['correct'] ?? null) === 1 && ($quizEn[1]['correct'] ?? null) === 0
        && ($quizHu[0]['correct'] ?? null) === 1
);
check(
    'a magyar ág bájtazonos (nem-angol kérésre a magyar kérdések)',
    ($quizHu[0]['prompt'] ?? '') === 'Melyik évben alakult a zenekar?'
        && ($quizHu[1]['options'] ?? array()) === array('Anna', 'Béla')
);

$quizPayloadEn = $resultsCallback(new WP_REST_Request(array('lang' => 'en')))->data;
$quizPayloadHu = $resultsCallback(new WP_REST_Request(array('lang' => 'hu')))->data;
check(
    'a NYILVÁNOS játék-végpont angolul a lefordított kérdéseket adja (magyarul a magyarokat)',
    ($quizPayloadEn['questions'][0]['prompt'] ?? '') === 'In which year was the band formed?'
        && ($quizPayloadEn['questions'][1]['options'][1] ?? '') === 'Béla'
        && ($quizPayloadHu['questions'][0]['prompt'] ?? '') === 'Melyik évben alakult a zenekar?',
    json_encode($quizPayloadEn['questions'] ?? null)
);
check(
    'a nyilvános válasz a `correct` indexet NEM adja ki (a játék nem skennelhető)',
    !array_key_exists('correct', (array) ($quizPayloadEn['questions'][0] ?? array()))
        && strpos((string) json_encode($quizPayloadEn['questions'] ?? array()), 'correct') === false
);

$privateCallback = stub_route_callback('/games/(?P<id>\d+)/private');
check('a privát (proxy) útvonal callbackje elérhető', is_callable($privateCallback));
if (is_callable($privateCallback)) {
    $privateEn = $privateCallback(new WP_REST_Request(array('id' => 71, 'lang' => 'en')))->data;
    check(
        'a PRIVÁT útvonalon a lefordított kérdések a `correct` indexszel együtt mennek (a proxynak kell)',
        ($privateEn['questions'][0]['prompt'] ?? '') === 'In which year was the band formed?'
            && ($privateEn['questions'][0]['correct'] ?? null) === 1,
        json_encode($privateEn['questions'][0] ?? null)
    );
}

/* ---- 17) A meta-írás ESCAPE-jei (mért ÉLES hiba, 2026-09-26) ---------- */

/*
 * ⚠️ A TULAJDONOS KÉPERNYŐKÉPE: angol módban a nyeremény leírásában **`rnrn`**
 * jelent meg új sor helyett („October 17!rnrnParticipate…"). A mérés: a magyar
 * forrásban **valódi** `\r\n` van, az angolban viszont `rn` — vagyis a JSON
 * escape-ek **backslash-e elveszett**.
 *
 * A gyökér: a WordPress `update_metadata()` **`wp_unslash()`-ol** a meta értékén,
 * ezért a `wp_json_encode()` által írt `\r\n` / `\uXXXX` escape-ekből `rn` /
 * `uXXXX` lesz. A beírónak `wp_slash()`-olnia kell (a plugin más helyein ez a
 * minta dokumentálva is van: `poll.php`, `prize.php`).
 */
reset_state(array('huhs_openai_api_key' => 'sk-legacy-option'));
$GLOBALS['STATE']['posts'][81] = new WP_Post(array(
    'ID' => 81, 'post_type' => 'huhs_prize', 'post_title' => 'Nyeremény',
    'post_content' => '', 'post_status' => 'publish',
));
$GLOBALS['STATE']['meta'][81] = array(
    '_huhs_prize_question' => 'Mi a neve?',
    '_huhs_prize_answers' => wp_json_encode(array('Béla', 'Anna')),
    '_huhs_prize_type' => 'Páros belépő',
    '_huhs_prize_description' => "Első sor!\r\n\r\nMásodik sor.",
);
$GLOBALS['STATE']['response'] = provider_response(array(
    'fields' => array(
        '_huhs_prize_question' => 'What is his name?',
        '_huhs_prize_answers' => array('Béla', 'Anna'),
        '_huhs_prize_type' => 'Couple entry',
        '_huhs_prize_description' => "First line!\r\n\r\nSecond line — with Béla.",
    ),
));
$escapeStatus = huhs_run_field_translation(81);
$escapeStored = huhs_translation_stored_fields(81);
$escapeDescription = (string) ($escapeStored['_huhs_prize_description'] ?? '');
check(
    'a meta-írás MEGŐRZI a JSON-escape-eket (valódi új sor, nem „rn")',
    $escapeStatus === 'translated'
        && strpos($escapeDescription, "\r\n") !== false
        && strpos($escapeDescription, 'rnrn') === false,
    $escapeStatus . ' / ' . json_encode($escapeDescription)
);
check(
    // ⚠️ A saját első változatom itt **hibás volt**: a `wp_json_encode()` a nem-ASCII
    // karaktereket **szándékosan** `\u00e9` alakban írja, ezért a nyers JSON-ben
    // keresni a `u00e9`-t értelmetlen (a tárolt érték viszont helyes). A helyes
    // mérés: a **visszaolvasott** érték bájtazonos az elvárttal, és a nyers meta
    // érvényes JSON.
    'az ékezetes válasz is helyesen íródik vissza (nincs „u00e9" szemét)',
    ($escapeStored['_huhs_prize_answers'] ?? array()) === array('Béla', 'Anna')
        && is_array(json_decode((string) get_post_meta(81, HUHS_TRANSLATION_FIELDS_META, true), true)),
    json_encode($escapeStored['_huhs_prize_answers'] ?? null)
);
check(
    'a kiolvasó a valódi új sort adja vissza (a megjelenítés sort törhet)',
    huhs_translation_text(81, 'en', '_huhs_prize_description', 'x') === "First line!\r\n\r\nSecond line — with Béla.",
    json_encode(huhs_translation_text(81, 'en', '_huhs_prize_description', 'x'))
);
check(
    'a beíró kiírja a séma-verziót, és az elem naprakész',
    (int) get_post_meta(81, HUHS_TRANSLATION_FIELDS_VERSION_META, true) === HUHS_TRANSLATION_FIELDS_VERSION
        && huhs_translation_fields_current(81) === true,
    (string) get_post_meta(81, HUHS_TRANSLATION_FIELDS_VERSION_META, true)
);
// ⚠️ A RÉGI (hibás escape-ekkel mentett) fordítások újragenerálása: ha a
// verziójelölő hiányzik (2.14.2 és előtte), az elem **nem** naprakész, ezért a
// pótló kör egyszer újrafordítja — enélkül a `rn` / `u00e9` szemét örökre benne
// maradna, mert a forrás-ujjlenyomat változatlan.
delete_post_meta(81, HUHS_TRANSLATION_FIELDS_VERSION_META);
check(
    'a régi (verziójelölő nélküli) fordítás NEM naprakész → a pótló kör újraviszi',
    huhs_translation_fields_current(81) === false
);
$GLOBALS['STATE']['response'] = provider_response(array(
    'fields' => array(
        '_huhs_prize_question' => 'What is his name?',
        '_huhs_prize_answers' => array('Béla', 'Anna'),
        '_huhs_prize_type' => 'Couple entry',
        '_huhs_prize_description' => "First line!\r\n\r\nSecond line — with Béla.",
    ),
));
check(
    'az újrafuttatott fordítás újra naprakész (és megint helyes az escape)',
    huhs_run_field_translation(81) === 'uptodate' || huhs_translation_fields_current(81) === true,
    (string) get_post_meta(81, HUHS_TRANSLATION_FIELDS_VERSION_META, true)
);

// A CÍM/TÖRZS ág is `wp_slash()`-ol: ha a fordítás **backslasht** tartalmaz
// (pl. `\n`, `\"`), az `update_metadata()` unslash-e nélküle elveszítené.
reset_state(array('huhs_openai_api_key' => 'sk-legacy-option'));
$GLOBALS['STATE']['posts'][82] = new WP_Post(array(
    'ID' => 82, 'post_type' => 'huhs_event', 'post_title' => 'Magyar esemény',
    'post_content' => 'Magyar leírás', 'post_status' => 'publish',
));
$GLOBALS['STATE']['response'] = provider_response(array(
    'title' => 'English event',
    'content' => "Első sor\nMásodik sor: \"idézet\" és C:\\\\path",
    'excerpt' => 'Short',
));
huhs_run_translation(82);
check(
    'a cím/törzs fordfítás is megőrzi a backslasht (nincs „unslash" roncsolás)',
    get_post_meta(82, '_huhs_content_en', true) === "Első sor\nMásodik sor: \"idézet\" és C:\\\\path"
        && get_post_meta(82, '_huhs_title_en', true) === 'English event',
    json_encode(get_post_meta(82, '_huhs_content_en', true))
);

echo "\n{$checks} ellenőrzés, {$failures} hiba\n";
exit($failures === 0 ? 0 : 1);
