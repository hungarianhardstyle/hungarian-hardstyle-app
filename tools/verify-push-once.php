<?php
/**
 * PUSH MINDENKINEK — ÉS CSAK EGYSZER (plugin 2.14.29).
 *
 * A TULAJDONOS NÉGY KÉRÉSE (2026-11-05):
 *   1. *„Új hírek pusht mindenki megkapjon, ne csak aki regelt”*
 *   2. *„Új event, új kiadvány pusht mindenki megkapjon, ne csak aki regelt”*
 *   3. *„event emlékeztetőket is ugyanígy”*
 *   4. *„néha 2-3 push is kimegy egy készülékre, ez hiba”*
 *
 * MIT MÉR (lefutó PHP, stubolt FCM-mel):
 *   A) a címzettek köre a **token-tárból** jön (a vendégek is benne vannak) —
 *      hír, esemény, kiadvány és emlékeztető egyaránt;
 *   B) a **regisztrált/bejelentkezett** állapot nem szűrő (nincs olyan mező, ami
 *      csak a regisztráltakat engedné át);
 *   C) ugyanaz az **eszköz** (ugyanaz az FCM-token több kulcson) egy körben
 *      **egy** üzenetet kap;
 *   D) az **emlékeztető** nem megy ki kétszer, ha a cron-esemény ÉS az ötperces
 *      scan ugyanabba az ablakba esik (foglalás a küldés előtt);
 *   E) az **esemény/kiadvány** push-ja sem megy ki kétszer ugyanerre a tartalomra;
 *   F) a diagnosztika kimondja a duplikált tokenek számát (`push_dup=`).
 *
 * Futtatás (a konténerben, a kibontott csomagon):
 *   php tools/verify-push-once.php /work/tmp/php-plugin/huhs-mobile-api
 *
 * Kilépési kód: 0 = minden rendben, 1 = eltérés.
 */

define('ABSPATH', __DIR__);
define('HUHS_PUSH_FORCE_SERIAL', true);

if (!defined('MINUTE_IN_SECONDS')) define('MINUTE_IN_SECONDS', 60);
if (!defined('HOUR_IN_SECONDS')) define('HOUR_IN_SECONDS', 3600);
if (!defined('DAY_IN_SECONDS')) define('DAY_IN_SECONDS', 86400);
if (!defined('WEEK_IN_SECONDS')) define('WEEK_IN_SECONDS', 604800);

$GLOBALS['huhs_options'] = array();
$GLOBALS['huhs_meta'] = array();
$GLOBALS['huhs_posts'] = array();
$GLOBALS['huhs_remote'] = array();
$GLOBALS['huhs_scheduled'] = array();
$GLOBALS['huhs_transients'] = array();
$GLOBALS['huhs_hooks'] = array();

// --- WordPress-stubok ------------------------------------------------------
function add_action($hook, $callback = null, $priority = 10, $args = 1) { return true; }
function add_filter(...$args) { return true; }
function register_rest_route(...$args) { return true; }
function get_option($name, $default = false)
{
    return array_key_exists($name, $GLOBALS['huhs_options']) ? $GLOBALS['huhs_options'][$name] : $default;
}
function update_option($name, $value, $autoload = null) { $GLOBALS['huhs_options'][$name] = $value; return true; }
function delete_option($name) { unset($GLOBALS['huhs_options'][$name]); return true; }
function add_option($name, $value, $deprecated = '', $autoload = null)
{
    if (array_key_exists($name, $GLOBALS['huhs_options'])) return false;
    $GLOBALS['huhs_options'][$name] = $value;
    return true;
}
function get_transient($name) { return $GLOBALS['huhs_transients'][$name] ?? false; }
function set_transient($name, $value, $expiration = 0) { $GLOBALS['huhs_transients'][$name] = $value; return true; }
function delete_transient($name) { unset($GLOBALS['huhs_transients'][$name]); return true; }
function current_user_can($cap) { return false; }
function is_admin() { return false; }
function apply_filters($hook, $value) { return $value; }
function do_action(...$args) { return true; }
function add_menu_page(...$args) { return true; }
function current_time($type = 'mysql', $gmt = 0) { return gmdate('Y-m-d H:i:s'); }
function wp_timezone() { return new DateTimeZone('Europe/Budapest'); }
function esc_html($v) { return (string) $v; }
function esc_url_raw($v) { return (string) $v; }
function wp_json_encode($v) { return json_encode($v); }
function wp_strip_all_tags($v) { return strip_tags((string) $v); }
function wp_generate_password($length = 12, $special = true, $extra = true) { return substr(str_repeat('a1b2c3', 4), 0, $length); }
function sanitize_key($v) { return strtolower(preg_replace('/[^a-z0-9_\-]/i', '', (string) $v)); }
function absint($v) { return abs((int) $v); }
function wp_is_post_revision($v) { return false; }
function wp_is_post_autosave($v) { return false; }
function wp_next_scheduled($hook, $args = array()) { return false; }
function wp_schedule_single_event($when, $hook, $args = array())
{
    $GLOBALS['huhs_scheduled'][] = array('when' => $when, 'hook' => $hook, 'args' => $args);
    return true;
}
function wp_schedule_event($when, $recurrence, $hook, $args = array()) { return true; }
function spawn_cron() { return true; }
function wp_date($format, $timestamp = null) { return gmdate($format, $timestamp ?? time()); }
function get_post($id = 0) { return $GLOBALS['huhs_posts'][(int) $id] ?? null; }
function get_the_title($post = null) { return is_object($post) ? (string) ($post->post_title ?? '') : ''; }
function get_permalink($post = null) { return ''; }
function get_post_meta($post_id, $key, $single = false) { return $GLOBALS['huhs_meta'][(int) $post_id][$key] ?? ''; }
function update_post_meta($post_id, $key, $value) { $GLOBALS['huhs_meta'][(int) $post_id][$key] = $value; return true; }
function delete_post_meta($post_id, $key) { unset($GLOBALS['huhs_meta'][(int) $post_id][$key]); return true; }
function get_posts($args = array()) { return array(); }
function get_post_time($type, $gmt = false, $post = null) { return time(); }
function classify_http_status($code) { return $code; }
function sanitize_email($value) { return trim((string) $value); }
function sanitize_text_field($value) { return trim(strip_tags((string) $value)); }
function wp_unslash($value) { return $value; }
function get_bloginfo($key = '') { return 'Hungarian Hardstyle'; }
function site_url($path = '') { return 'https://hungarianhardstyle.hu' . $path; }
function home_url($path = '') { return 'https://hungarianhardstyle.hu' . $path; }
function get_post_type($post = null) { return is_object($post) ? (string) $post->post_type : ''; }
function did_action($hook) { return 0; }

class WP_Error
{
    public $code;
    public $message;
    public function __construct($code = '', $message = '', $data = array()) { $this->code = $code; $this->message = $message; }
    public function get_error_code() { return $this->code; }
    public function get_error_message() { return $this->message; }
}
function is_wp_error($thing) { return $thing instanceof WP_Error; }

function wp_remote_post($url, $args = array())
{
    $GLOBALS['huhs_remote'][] = array('url' => (string) $url, 'body' => $args['body'] ?? '');
    return array('response' => array('code' => 200), 'body' => '{"name":"projects/hungarian-hardstyle/messages/1"}');
}
function wp_remote_retrieve_response_code($response) { return (int) ($response['response']['code'] ?? 0); }
function wp_remote_retrieve_body($response) { return (string) ($response['body'] ?? ''); }

$pluginDir = rtrim($argv[1] ?? '', '/');
if ($pluginDir === '' || !is_file($pluginDir . '/includes/push.php')) {
    fwrite(STDERR, "HIBA: nincs ilyen plugin-könyvtár: {$pluginDir}\n");
    exit(1);
}
require_once $pluginDir . '/includes/push.php';

$checks = 0;
$failures = 0;
function check($label, $condition, $detail = '')
{
    global $checks, $failures;
    $checks++;
    if ($condition) {
        echo "OK   {$label}\n";
        return;
    }
    $failures++;
    echo "HIBA {$label}" . ($detail !== '' ? " — {$detail}" : '') . "\n";
}

function reset_world()
{
    $GLOBALS['huhs_options'] = array();
    $GLOBALS['huhs_meta'] = array();
    $GLOBALS['huhs_posts'] = array();
    $GLOBALS['huhs_remote'] = array();
    $GLOBALS['huhs_scheduled'] = array();
    $GLOBALS['huhs_transients'] = array('huhs_firebase_access_token' => 'stub-token');
    $GLOBALS['huhs_options'][HUHS_PUSH_SERVICE_ACCOUNT_OPTION] = array(
        'project_id' => 'hungarian-hardstyle',
        'client_email' => 'push@hungarian-hardstyle.iam.gserviceaccount.com',
        'private_key' => 'stub',
    );
}

/** Eszközök a token-tárban (a „vendég" = nincs regisztráció, csak token). */
function seed_devices($count, $language = 'hu')
{
    $tokens = array();
    for ($i = 1; $i <= $count; $i++) {
        $tokens['dev' . $i] = array('token' => 'token-dev-' . $i . '-aaaaaaaaaaaa', 'language' => $language);
    }
    $GLOBALS['huhs_options'][HUHS_PUSH_TOKENS_OPTION] = $tokens;
    return $tokens;
}

function sent_tokens()
{
    $out = array();
    foreach ($GLOBALS['huhs_remote'] as $request) {
        if (strpos($request['url'], 'fcm.googleapis.com') === false) continue;
        $decoded = json_decode((string) $request['body'], true);
        $token = (string) ($decoded['message']['token'] ?? '');
        if ($token !== '') $out[] = $token;
    }
    return $out;
}

function seed_post($id, $post_type, $title, $meta = array())
{
    $GLOBALS['huhs_posts'][$id] = (object) array(
        'ID' => $id,
        'post_type' => $post_type,
        'post_status' => 'publish',
        'post_title' => $title,
    );
    foreach ($meta as $key => $value) $GLOBALS['huhs_meta'][$id][$key] = $value;
}

// --- A) Mindenki (a vendégek is): hír, esemény, kiadvány, emlékeztető ------
reset_world();
seed_devices(5);
check('a token-tárban lévő MINDEN eszköz címzett (vendégek is, nincs regisztráció-szűrő)',
    count(huhs_push_recipients(get_option(HUHS_PUSH_TOKENS_OPTION), array('type' => 'custom'))) === 5);
foreach (array('news', 'event', 'release') as $type) {
    $recipients = huhs_push_recipients(get_option(HUHS_PUSH_TOKENS_OPTION), array('type' => $type));
    check("a(z) {$type} típus minden eszköznek megy (5/5)", count($recipients) === 5, (string) count($recipients));
}
$reminder = huhs_push_recipients(
    get_option(HUHS_PUSH_TOKENS_OPTION),
    array('type' => 'event', 'kind' => 'reminder')
);
check('az EMLÉKEZTETŐ is minden eszköznek megy (5/5)', count($reminder) === 5, (string) count($reminder));

// --- B) Ugyanaz az eszköz többször a tárban → EGY üzenet -------------------
reset_world();
$GLOBALS['huhs_options'][HUHS_PUSH_TOKENS_OPTION] = array(
    'regA' => array('token' => 'SAME-TOKEN-1', 'language' => 'hu', 'uid' => 'user-1'),
    'regB' => array('token' => 'SAME-TOKEN-1', 'language' => 'hu', 'uid' => 'user-1'),
    'guestC' => array('token' => 'SAME-TOKEN-2', 'language' => 'hu'),
    'other' => array('token' => 'OTHER-TOKEN-3', 'language' => 'hu'),
);
$recipients = huhs_push_recipients(get_option(HUHS_PUSH_TOKENS_OPTION), array('type' => 'news'));
check('a duplikált token (ugyanaz az eszköz két kulcson) EGYSZER szerepel',
    count($recipients) === 3, json_encode(array_values($recipients)));
check('a dedupe a token ÉRTÉKÉre megy, nem a kulcsra',
    count(array_unique(array_values($recipients))) === count($recipients));

reset_world();
$GLOBALS['huhs_options'][HUHS_PUSH_TOKENS_OPTION] = array(
    'a' => array('token' => 'DUP', 'language' => 'hu'),
    'b' => array('token' => 'DUP', 'language' => 'hu'),
    'c' => array('token' => 'DUP', 'language' => 'hu'),
);
$recipients = huhs_push_recipients(get_option(HUHS_PUSH_TOKENS_OPTION), array('type' => 'event'));
check('három azonos token → egyetlen üzenet (nem 2-3 push egy készülékre)',
    count($recipients) === 1, (string) count($recipients));

// --- C) A diagnosztika kimondja a duplikátumok számát ---------------------
check('a diagnosztika megmutatja a duplikált tokenek számát (push_dup=2)',
    huhs_push_diag_duplicate_tokens() === 2, (string) huhs_push_diag_duplicate_tokens());
check('a `push_dup=` benne van a diagnosztikai sorban',
    strpos(huhs_push_diag_jobs(), 'push_dup=') !== false, huhs_push_diag_jobs());

// --- D) Az EMLÉKEZTETŐ nem megy ki kétszer --------------------------------
reset_world();
seed_devices(4);
seed_post(9001, 'huhs_event', 'Hardstyle Revolution', array(
    'event_start_date' => wp_date('Y-m-d', time() + 3 * DAY_IN_SECONDS),
    'event_start_time' => '22:00',
    'visible' => '1',
));
huhs_push_event_reminder(9001, 'day_before');
$first = count(sent_tokens());
check('az emlékeztető első hívásra kimegy mindenkinek (4/4)', $first === 4, (string) $first);
huhs_push_event_reminder(9001, 'day_before');
$second = count(sent_tokens());
check('a MÁSODIK hívás (cron + scan ugyanabban az ablakban) NEM küld újra',
    $second === $first, 'összes üzenet: ' . $second);
check('az „elküldve” jelölő beíródott', get_post_meta(9001, '_huhs_push_reminder_sent_day_before', true) !== '');

// --- E) Az esemény-push sem megy ki kétszer ugyanarra ---------------------
reset_world();
seed_devices(4);
seed_post(9002, 'huhs_event', 'Új esemény teszt', array(
    'visible' => '1',
    'event_start_date' => wp_date('Y-m-d', time() + 10 * DAY_IN_SECONDS),
    'event_start_time' => '23:00',
));
huhs_push_publish_content(9002, 'huhs_event');
$first = count(sent_tokens());
check('az esemény-push első hívásra kimegy mindenkinek (4/4)', $first === 4, (string) $first);
huhs_push_publish_content(9002, 'huhs_event');
check('a MÁSODIK hívás (transition + mentés-hook) NEM küldi ki újra',
    count(sent_tokens()) === $first, 'összes üzenet: ' . count(sent_tokens()));

// --- F) Ha semmi nem ment ki, a foglalás elenged (lesz újrapróba) --------
reset_world();
seed_devices(3);
seed_post(9003, 'huhs_event', 'Néma esemény', array('visible' => '1'));
$GLOBALS['huhs_transients'] = array(); // nincs access token → nem megy ki semmi
huhs_push_event_reminder(9003, 'two_hours');
check('sikertelen küldésnél a foglalás elenged (nincs „örökre lezárt” emlékeztető)',
    get_option('huhs_push_reminder_claim_9003_two_hours', null) === null);
check('és a jelölő sem íródott ki (lesz újrapróba)',
    get_post_meta(9003, '_huhs_push_reminder_sent_two_hours', true) === '');

// --- Összegzés -----------------------------------------------------------
$ok = $failures === 0;
echo "\n{$checks} ellenőrzés, {$failures} hiba\n";
if ($ok) echo "PUSH-ONCE OK\n";
exit($ok ? 0 : 1);
