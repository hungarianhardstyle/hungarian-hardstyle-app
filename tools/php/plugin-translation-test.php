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

$STATE = array(
    'options' => array(),
    'meta' => array(),
    'http' => array(),
    'response' => null,
    'actions' => array(),
    'scheduled' => array(),
    'posts' => array(),
);

class WP_Post
{
    public $ID;
    public $post_type;
    public $post_title;
    public $post_content;

    public function __construct($data)
    {
        foreach ($data as $key => $value) {
            $this->$key = $value;
        }
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
    $GLOBALS['STATE']['actions'][] = array('hook' => $hook, 'callback' => $callback);
    return true;
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
huhs_run_translation(6);
check('HTTP 500 esetén NINCS meta-írás', count($GLOBALS['STATE']['meta']) === 0);

reset_state(array('huhs_openai_api_key' => 'sk-legacy-option'));
$GLOBALS['STATE']['posts'][7] = new WP_Post(array(
    'ID' => 7,
    'post_type' => 'huhs_event',
    'post_title' => 'Esemény',
    'post_content' => 'Leírás',
));
$GLOBALS['STATE']['response'] = array('code' => 200, 'body' => 'nem json');
huhs_run_translation(7);
check('értelmezhetetlen válaszból NINCS meta-írás (nincs félkész fordítás)', count($GLOBALS['STATE']['meta']) === 0);

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

echo "\n{$checks} ellenőrzés, {$failures} hiba\n";
exit($failures === 0 ? 0 : 1);
