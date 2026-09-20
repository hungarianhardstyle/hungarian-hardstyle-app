<?php
/**
 * A DUPLA PUSH bizonyítása — valódi PHP, WordPress nélkül.
 *
 * A tulajdonos jelzése: „nézzünk rá arra, hogy LEHETSÉGES, némelyik push kétszer
 * megy ki". A mérés megtalálta a mechanizmust a `includes/push.php`-ban:
 *
 *   A küldési láncot a cron-esemény ÉS a biztonsági háló (minden kérés
 *   `shutdown`-jában) is futtathatja. A háló abból következtetett az elakadásra,
 *   hogy a `last_run` régi — viszont a `last_run` csak a kör VÉGÉN íródott, egy
 *   kör pedig a 15 s-os keret miatt hosszabb, mint a 10 s-os küszöb. Így egy
 *   ÉPPEN FUTÓ kör „elakadtnak" látszott, és a háló ugyanarról az offsetről
 *   indított egy második kört: az éppen küldött eszközök kétszer kapták a pusht.
 *
 * Ez a harness ezt a helyzetet IDÉZI: az FCM-stub az ELSO kézbesítés közben
 * meghívja a biztonsági hálót (mintha egy látogató kérése éppen lezárult volna),
 * és megszámolja, melyik eszköz hány push-t kapott.
 *
 * Két futás:
 *   1. JAVÍTOTT kód (foglalás + szívverés)  -> egy eszköz SE kap kétszer;
 *   2. RÉGI viselkedés (a foglalás nélkül)  -> a dupla MEGJELENIK (a kapu fog).
 *
 * Futtatás (a repository gyökeréből):
 *   & 'C:\Users\deero\Documents\Hun HS Newsroom\tools\php\php.exe' tools/verify-push-dedupe.php
 *
 * Kilépési kód: 0 = minden rendben, 1 = eltérés.
 */

define('ABSPATH', __DIR__);
// A párhuzamos út curl-t használ, amit a stubok nem látnak: a teszthez a soros utat
// kényszerítjük (élesben ez a kapcsoló nincs bekapcsolva).
define('HUHS_PUSH_FORCE_SERIAL', true);

// --- WordPress-stubok ------------------------------------------------------
$GLOBALS['huhs_options'] = array();
$GLOBALS['huhs_meta'] = array();
$GLOBALS['huhs_scheduled'] = array();
$GLOBALS['huhs_log'] = array();
$GLOBALS['fcm_deliveries'] = array();
$GLOBALS['resume_during_send'] = false;
$GLOBALS['resume_callback'] = null;
$GLOBALS['fcm_fail'] = false;

function get_option($name, $default = false)
{
    return array_key_exists($name, $GLOBALS['huhs_options']) ? $GLOBALS['huhs_options'][$name] : $default;
}
function update_option($name, $value, $autoload = null)
{
    $GLOBALS['huhs_options'][$name] = $value;
    return true;
}
function add_option($name, $value, $deprecated = '', $autoload = null)
{
    if (array_key_exists($name, $GLOBALS['huhs_options'])) return false;
    $GLOBALS['huhs_options'][$name] = $value;
    return true;
}
function delete_option($name)
{
    unset($GLOBALS['huhs_options'][$name]);
    return true;
}
function get_transient($name) { return false; }
function set_transient($name, $value, $ttl = 0) { $GLOBALS['huhs_options']['transient_' . $name] = $value; return true; }
function current_time($type, $gmt = 0) { return $gmt ? gmdate('Y-m-d H:i:s') : date('Y-m-d H:i:s'); }
// A plugin a WordPress hook-rendszerere epul: eleg csak osszegyujteni a hookokat.
$GLOBALS['huhs_hooks'] = array();
function add_action($hook, $callback, $priority = 10, $accepted_args = 1) { $GLOBALS['huhs_hooks'][$hook] = $callback; return true; }
function add_filter($hook, $callback, $priority = 10, $accepted_args = 1) { $GLOBALS['huhs_hooks'][$hook] = $callback; return true; }
function register_rest_route($namespace, $route, $args = array()) { return true; }
function add_submenu_page() { return true; }
function check_admin_referer($action) { return true; }
function current_user_can($cap) { return true; }
function wp_die($message) { return true; }
function admin_url($path = '') { return 'https://example.test/wp-admin/' . $path; }
function wp_safe_redirect($url) { return true; }
function wp_unslash($value) { return $value; }
function sanitize_email($value) { return trim((string) $value); }
function sanitize_textarea_field($value) { return trim((string) $value); }
function esc_html($value) { return (string) $value; }
function esc_attr($value) { return (string) $value; }
function esc_url($value) { return (string) $value; }
function wp_kses_post($value) { return (string) $value; }
function __($text, $domain = '') { return $text; }
function get_rest_url($path = '') { return 'https://example.test/wp-json/' . $path; }
function wp_remote_retrieve_response_message($response) { return ''; }
function sanitize_key($value) { return strtolower(preg_replace('/[^a-z0-9_\-]/i', '', (string) $value)); }
function sanitize_text_field($value) { return trim(preg_replace('/\s+/u', ' ', (string) $value)); }
function wp_json_encode($value, $flags = 0) { return json_encode($value, $flags); }
function wp_generate_password($length = 12, $special = true, $extra = false) { return substr(str_repeat('k', $length), 0, $length); }
function absint($value) { return abs((int) $value); }
function wp_strip_all_tags($value) { return strip_tags((string) $value); }
function wp_schedule_single_event($timestamp, $hook, $args = array(), $wp_error = false)
{
    $GLOBALS['huhs_scheduled'][] = array('hook' => $hook, 'args' => $args, 'time' => $timestamp);
    return true;
}
function wp_next_scheduled($hook, $args = array()) { return false; }
function spawn_cron($gmt = 0) { return true; }
// Az `error_log()` PHP-beepitett, ezert nem irhato felul: a naplót fajlba
// tereljuk, hogy a teszt kimenete tiszta legyen.
ini_set('error_log', sys_get_temp_dir() . DIRECTORY_SEPARATOR . 'huhs-push-dedupe-test.log');
function is_wp_error($thing) { return $thing instanceof WP_Error; }
function wp_remote_retrieve_response_code($response) { return (int) ($response['code'] ?? 0); }
function wp_remote_retrieve_body($response) { return (string) ($response['body'] ?? ''); }

class WP_Error
{
    private $code;
    public function __construct($code = '', $message = '', $data = null) { $this->code = $code; }
    public function get_error_code() { return $this->code; }
}

/**
 * Az FCM-stub: minden kézbesítést megszámol, és az ELSO kézbesítés közben
 * meghívja a biztonsági hálót — pontosan azt a pillanatot idézve, amikor egy
 * másik kérés `shutdown`-ja belefut a még futó körbe.
 */
function wp_remote_post($url, $args = array())
{
    if (strpos($url, 'oauth2.googleapis.com') !== false) {
        return array('code' => 200, 'body' => wp_json_encode(array('access_token' => 'test-token', 'expires_in' => 3600)));
    }
    $body = json_decode((string) ($args['body'] ?? ''), true);
    $token = (string) ($body['message']['token'] ?? '');
    if ($token !== '') {
        if ($GLOBALS['fcm_fail']) {
            // Az FCM elutasítja: ilyenkor NEM szabad késznek jelölni a küldést.
            return array('code' => 500, 'body' => wp_json_encode(array('error' => array('status' => 'INTERNAL'))));
        }
        if (!isset($GLOBALS['fcm_deliveries'][$token])) $GLOBALS['fcm_deliveries'][$token] = 0;
        $GLOBALS['fcm_deliveries'][$token]++;
        if ($GLOBALS['resume_during_send'] && is_callable($GLOBALS['resume_callback'])) {
            // Csak EGYSZER hívjuk be, különben végtelen ciklus lenne.
            $GLOBALS['resume_during_send'] = false;
            call_user_func($GLOBALS['resume_callback']);
        }
    }
    return array('code' => 200, 'body' => '{}');
}

// Időállandók (a plugin ezeket a WordPress-ből kapja).
define('MINUTE_IN_SECONDS', 60);
define('HOUR_IN_SECONDS', 3600);
define('DAY_IN_SECONDS', 86400);

require_once __DIR__ . '/../.tmp-api-24115/huhs-mobile-api/includes/push.php';

// --- A harness -------------------------------------------------------------
$checks = 0;
$failures = 0;

function check($label, $condition, $detail = '')
{
    global $checks, $failures;
    $checks++;
    if ($condition) {
        echo "OK    {$label}\n";
        return;
    }
    $failures++;
    echo "HIBA  {$label}" . ($detail !== '' ? " - {$detail}" : '') . "\n";
}

function seed_tokens($count)
{
    $tokens = array();
    for ($index = 1; $index <= $count; $index++) {
        $token = 'tok-' . $index;
        $tokens[hash('sha256', $token)] = array('token' => $token, 'enabled' => true, 'updated_at' => current_time('mysql', true));
    }
    update_option(HUHS_PUSH_TOKENS_OPTION, $tokens, false);
}

function seed_job($offset = 0, $type = 'news', $id = '9')
{
    update_option('huhs_push_job_TESTJOB', array(
        'title' => 'Teszt cim',
        'body' => 'Teszt uzenet',
        'data' => array('type' => $type, 'id' => (string) $id),
        'offset' => $offset,
        'dead' => array(),
        'runs' => 0,
        'last_run' => time(),
    ), false);
    update_option('huhs_push_active_job', 'TESTJOB', false);
}

function reset_world()
{
    $GLOBALS['huhs_options'] = array();
    $GLOBALS['huhs_log'] = array();
    $GLOBALS['fcm_deliveries'] = array();
    $GLOBALS['resume_during_send'] = false;
    $GLOBALS['fcm_fail'] = false;
    update_option(HUHS_PUSH_SERVICE_ACCOUNT_OPTION, array(
        'project_id' => 'demo-huhs',
        'client_email' => 'stub@demo-huhs.iam.gserviceaccount.com',
        // VALODI (futásidőben generált) kulcs: enélkül az aláírás elhasal, és a
        // küldés el sem indulna — akkor a teszt nem a duplázást mérné.
        'private_key' => test_private_key(),
    ), false);
}

function test_private_key()
{
    static $pem = null;
    if ($pem !== null) return $pem;
    // Windows PHP-nal az OpenSSL csak akkor tud kulcsot generalni, ha megkapja a
    // konfiguraciot (kulonben „Cannot get key from parameter 1").
    $config = dirname(PHP_BINARY) . DIRECTORY_SEPARATOR . 'extras' . DIRECTORY_SEPARATOR . 'ssl' . DIRECTORY_SEPARATOR . 'openssl.cnf';
    $config_args = is_file($config) ? array('config' => $config) : array();
    $resource = openssl_pkey_new($config_args + array(
        'private_key_bits' => 2048,
        'private_key_type' => OPENSSL_KEYTYPE_RSA,
    ));
    if ($resource === false) {
        fwrite(STDERR, "Nem sikerult teszt kulcsot generalni: " . openssl_error_string() . "\n");
        exit(2);
    }
    openssl_pkey_export($resource, $exported, null, $config_args);
    $pem = (string) $exported;
    return $pem;
}

/**
 * A forgatókönyv: 3 eszköz, egy feladat az elején, és a küldés KÖZBEN lefut a
 * biztonsági háló (ez a versenyhelyzet).
 *
 * @param bool $legacy true = a foglalás nélküli (régi) viselkedés szimulálása.
 */
function run_scenario($legacy)
{
    reset_world();
    seed_tokens(3);
    seed_job(0);

    $GLOBALS['resume_callback'] = function () use ($legacy) {
        if ($legacy) {
            // A RÉGI kód nem ismert foglalást: a háló a `last_run`-ra hagyatkozott,
            // ami a kör végéig régi maradt.
            delete_option('huhs_push_job_lock_TESTJOB');
            $job = get_option('huhs_push_job_TESTJOB', array());
            $job['last_run'] = time() - 60;
            update_option('huhs_push_job_TESTJOB', $job, false);
        }
        huhs_push_resume_pending_job();
    };
    $GLOBALS['resume_during_send'] = true;

    // Egy kör, rövid kerettel: az elso eszkoz kimegy, majd (a stubban) befut a háló.
    huhs_push_continue('TESTJOB', 0);

    $deliveries = $GLOBALS['fcm_deliveries'];
    $doubled = array();
    foreach ($deliveries as $token => $count) {
        if ($count > 1) $doubled[] = $token . '=' . $count;
    }
    return array('deliveries' => $deliveries, 'doubled' => $doubled, 'log' => $GLOBALS['huhs_log']);
}

// 1) A JAVÍTOTT kód: a küldés közben befutó háló NEM indít második kört.
$fixed = run_scenario(false);
check('javított: a küldés közben befutó háló nem indít második kört', count($fixed['doubled']) === 0, implode(',', $fixed['doubled']));
check('javított: az eszköz pontosan EGY push-t kapott', ($fixed['deliveries']['tok-1'] ?? 0) === 1, 'tok-1=' . ($fixed['deliveries']['tok-1'] ?? 0));
check('javított: a foglalás a kör végén felszabadul', get_option('huhs_push_job_lock_TESTJOB', 0) === 0 || get_option('huhs_push_job_lock_TESTJOB', 0) === false);
check('javított: a kör szívverése friss (nem tűnik elakadtnak)', (int) (get_option('huhs_push_job_TESTJOB', array())['last_run'] ?? 0) > time() - 5);

// 2) A RÉGI viselkedés: a kapu BIZONYÍTOTTAN elkapja a duplát.
$legacy = run_scenario(true);
check('régi viselkedés: a dupla push MEGJELENIK (a kapu fog)', count($legacy['doubled']) > 0, 'nem lett dupla - a teszt nem bizonyítana semmit');
check('régi viselkedés: ugyanaz az eszköz kétszer kapta', ($legacy['deliveries']['tok-1'] ?? 0) === 2, 'tok-1=' . ($legacy['deliveries']['tok-1'] ?? 0));

// 3) Az újrapróbálkozás nem indul, ha a lánc viszi ki a küldést.
reset_world();
seed_tokens(3);
seed_job(1, 'news', '4242');
$GLOBALS['huhs_meta'] = array();
$GLOBALS['huhs_post'] = (object) array('ID' => 4242, 'post_type' => 'post', 'post_status' => 'publish');
function get_post($id = 0) { return $GLOBALS['huhs_post'] ?? null; }
function get_the_title($post = null) { return 'Teszt hir'; }
function wp_is_post_revision($post) { return false; }
function get_post_meta($post_id, $key, $single = false) { return $GLOBALS['huhs_meta'][$post_id][$key] ?? ''; }
function update_post_meta($post_id, $key, $value) { $GLOBALS['huhs_meta'][$post_id][$key] = $value; }
function delete_post_meta($post_id, $key) { unset($GLOBALS['huhs_meta'][$post_id][$key]); }

check('a lánc-felismerés a saját küldést látja', huhs_push_has_pending_job(array('type' => 'news', 'id' => '4242')) === true);
check('más küldést NEM tekint a sajátjának', huhs_push_has_pending_job(array('type' => 'news', 'id' => '777')) === false);

$GLOBALS['huhs_scheduled'] = array();
huhs_push_publish_news(4242, 'token-abc', 1);
$retry_scheduled = false;
foreach ($GLOBALS['huhs_scheduled'] as $event) {
    if ($event['hook'] === 'huhs_push_publish_news') $retry_scheduled = true;
}
check('élő láncnál NINCS újrapróbálkozás (nincs dupla küldés)', $retry_scheduled === false);
check('élő láncnál a küldés késznek jelölve', ($GLOBALS['huhs_meta'][4242]['_huhs_push_news_sent'] ?? '') === 'token-abc');

// 4) Ha nincs élő lánc, a sikertelen küldés újrapróbálkozik (nem veszik el).
reset_world();
seed_tokens(3);
$GLOBALS['huhs_meta'] = array();
$GLOBALS['huhs_scheduled'] = array();
// Az FCM elutasít mindent: volt kit ertesiteni (3 eszkoz), de egy sem ment at.
$GLOBALS['fcm_fail'] = true;
huhs_push_publish_news(4242, 'token-abc', 1);
$retry_scheduled = false;
foreach ($GLOBALS['huhs_scheduled'] as $event) {
    if ($event['hook'] === 'huhs_push_publish_news') $retry_scheduled = true;
}
check('élő lánc nélkül a hiba után ÚJRApróbálkozik (nincs néma elvesztés)', $retry_scheduled === true);
check('sikertelen küldést nem jelöl késznek', ($GLOBALS['huhs_meta'][4242]['_huhs_push_news_sent'] ?? '') === '');

echo "\n" . ($checks - $failures) . "/{$checks} ellenorzes rendben\n";
exit($failures > 0 ? 1 : 0);
