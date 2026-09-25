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
}

class WP_REST_Request
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
    $GLOBALS['STATE']['meta'][$postId][$key] = $value;
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

/* ---- A VALÓDI plugin-fájlok betöltése ------------------------------------ */

require $pluginDir . '/includes/post-translation-meta.php';
require $pluginDir . '/includes/translation-cron.php';
require $pluginDir . '/includes/translation-places.php';
require $pluginDir . '/includes/translation-sweep.php';

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
    $sweepOneType === array('huhs_event') && huhs_translation_sweep_types('nincs_ilyen') === huhs_translation_post_types()
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
    'a status végpont megadja a típusokat és a várólistát (kulcs nélkül is)',
    isset($statusData['pending']['huhs_release']) && count($statusData['types']) === 5,
    json_encode($statusData['pending'])
);

echo "\n{$checks} ellenőrzés, {$failures} hiba\n";
exit($failures === 0 ? 0 : 1);
