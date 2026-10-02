<?php
/**
 * A PUSH-KIFUTÁS SEBESSÉGE (plugin 2.14.13) — bizonyítás valódi PHP-n.
 *
 * MIÉRT: a tulajdonos jelzése (2026-10-01): *„ja de mégis megy — csak lassan
 * jött"*. Az éles mérés ezt pontosan megmutatta: a hír-push **1028 eszközt
 * ~2 perc alatt** ért el, mert egy 15 másodperces kör 25 párhuzamos hívással
 * csak ~200-225 eszközt vitt el (a mért batch-idő ~1,7 s — nem a sávszélesség,
 * hanem az FCM oda-vissza út a szűk keresztmetszet). A javítás ezért a
 * **kereteket** igazítja a méréshez, nem a küldés logikáját cseréli:
 *
 *   1. párhuzamosság 25 → **50** (feleannyi kör ugyanarra a listára);
 *   2. a folytató kör 2 → **1 másodperc** múlva (körök közötti holtidő);
 *   3. a keretek **láthatóvá válnak** a diagnosztikai fejlécben
 *      (`push_limits=conc…/budget…/max_exec…`) — a PHP időkorlátja eddig nem
 *      volt mérhető, ezért a kör-keret emelése találgatás lett volna.
 *
 * MIT MÉR (nem forrás-lint, hanem **lefutó** kód):
 *   1. a keretek értéke és a köteg-méret a párhuzamos úton;
 *   2. a folytató kör **1 másodpercre** ütemezése — MINDKÉT helyen (a feladat
 *      létrehozásakor és a kör végén);
 *   3. a lánc pontossága: a folytatás a **jó offsetről** indul, a körök együtt
 *      sem küldenek kétszer ugyanarra az eszközre, és a végén a feladat
 *      megszűnik (nincs örökre nyitva maradt lánc);
 *   4. a diagnosztika kiírja a három keretet, és a fejlécbe is bekerül.
 *
 * Futtatás (a konténerben, a kibontott csomagon):
 *   php tools/verify-push-speed.php /work/tmp/php-plugin/huhs-mobile-api
 *
 * Kilépési kód: 0 = minden rendben, 1 = eltérés.
 */

define('ABSPATH', __DIR__);

if (!defined('MINUTE_IN_SECONDS')) define('MINUTE_IN_SECONDS', 60);
if (!defined('HOUR_IN_SECONDS')) define('HOUR_IN_SECONDS', 3600);
if (!defined('DAY_IN_SECONDS')) define('DAY_IN_SECONDS', 86400);

// A stubolt környezet nem tudja fogni a curl-t, ezért a küldés a soros úton megy.
define('HUHS_PUSH_FORCE_SERIAL', true);

// --- WordPress-stubok ------------------------------------------------------
$GLOBALS['huhs_options'] = array();
$GLOBALS['huhs_transients'] = array();
$GLOBALS['huhs_scheduled'] = array();
$GLOBALS['huhs_cron_events'] = array();
$GLOBALS['huhs_hooks'] = array();
$GLOBALS['huhs_remote'] = array();
$GLOBALS['huhs_meta'] = array();

function add_action($hook, $callback = null, $priority = 10, $args = 1)
{
    $GLOBALS['huhs_hooks'][] = array('hook' => $hook, 'callback' => $callback, 'priority' => $priority);
    return true;
}
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
function current_user_can($cap) { return $cap === 'manage_options'; }
function sanitize_text_field($value) { return trim(preg_replace('/[\r\n\t]+/', ' ', strip_tags((string) $value))); }
function sanitize_textarea_field($value) { return trim(strip_tags((string) $value)); }
function sanitize_email($value) { return trim((string) $value); }
function absint($value) { return abs((int) $value); }
function wp_json_encode($value, $flags = 0) { return json_encode($value, $flags); }
function wp_generate_password($length = 12, $special = true, $extra = true) { return substr(str_repeat('k3x8q1', 8), 0, (int) $length); }
function wp_strip_all_tags($value) { return strip_tags((string) $value); }
function sanitize_key($value) { return strtolower(preg_replace('/[^A-Za-z0-9_\-]/', '', (string) $value)); }
function esc_url_raw($value) { return trim((string) $value); }
function get_the_title($post) { return ''; }
function get_post_time($format, $gmt = false, $post = null) { return time(); }
function get_post_meta($post_id, $key, $single = false) { return $single ? '' : array(); }
function update_post_meta($post_id, $key, $value) { return true; }
function delete_post_meta($post_id, $key) { return true; }
function get_post($id) { return null; }
function get_posts($args = array()) { return array(); }
function wp_timezone() { return new DateTimeZone('Europe/Budapest'); }
function wp_date($format, $timestamp = null, $timezone = null)
{
    $zone = $timezone instanceof DateTimeZone ? $timezone : wp_timezone();
    $moment = new DateTime('@' . (int) ($timestamp ?? time()));
    $moment->setTimezone($zone);
    return $moment->format($format);
}
function current_time($type = 'mysql', $gmt = 0) { return $type === 'timestamp' ? time() : wp_date($type, time()); }
function wp_schedule_single_event($when, $hook, $args = array())
{
    $GLOBALS['huhs_scheduled'][] = array('when' => (int) $when, 'hook' => $hook, 'args' => $args);
    $GLOBALS['huhs_cron_events'][] = array('when' => (int) $when, 'hook' => $hook, 'args' => $args);
    return true;
}
function wp_schedule_event($when, $recurrence, $hook, $args = array()) { return true; }
function wp_next_scheduled($hook, $args = array())
{
    foreach ($GLOBALS['huhs_cron_events'] as $event) {
        if ($event['hook'] !== $hook) continue;
        if (wp_json_encode($event['args']) !== wp_json_encode($args)) continue;
        return (int) $event['when'];
    }
    return false;
}
function spawn_cron($gmt = null) { return true; }
function wp_remote_post($url, $args = array())
{
    $GLOBALS['huhs_remote'][] = array('url' => (string) $url, 'body' => $args['body'] ?? '');
    return array('response' => array('code' => 200), 'body' => '{"name":"projects/p/messages/1"}');
}
function wp_remote_retrieve_response_code($response) { return (int) ($response['response']['code'] ?? 0); }
function wp_remote_retrieve_body($response) { return (string) ($response['body'] ?? ''); }
function is_wp_error($thing) { return false; }
class WP_Error { public function __construct($a = '', $b = '', $c = array()) {} }

$pluginDir = rtrim($argv[1] ?? '', '/');
if ($pluginDir === '' || !is_file($pluginDir . '/includes/push.php')) {
    fwrite(STDERR, "HIBA: nincs ilyen plugin-könyvtár: {$pluginDir}\n");
    exit(1);
}
$pushSource = (string) file_get_contents($pluginDir . '/includes/push.php');
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

/** A rögzített FCM-kérésekből a címzettek (token) listája. */
function sent_tokens()
{
    $out = array();
    foreach ($GLOBALS['huhs_remote'] as $request) {
        if (strpos($request['url'], 'fcm.googleapis.com') === false) continue;
        $decoded = json_decode((string) $request['body'], true);
        $out[] = (string) ($decoded['message']['token'] ?? '');
    }
    return $out;
}

/** Token-tár előkészítése N eszközzel (nyelv váltakozva, hogy a szűrő ne egyszerűsítsen). */
function seed_tokens($count)
{
    $tokens = array();
    for ($i = 1; $i <= $count; $i++) {
        $tokens['k' . $i] = array(
            'token' => 'token-' . str_pad((string) $i, 4, '0', STR_PAD_LEFT) . '-aaaaaaaaaaaaaaaa',
            'language' => $i % 2 === 0 ? 'en' : 'hu',
            'updated_at' => gmdate('Y-m-d H:i:s', time() - $i),
        );
    }
    $GLOBALS['huhs_options'][HUHS_PUSH_TOKENS_OPTION] = $tokens;
    return $tokens;
}

/** A nyitva lévő küldési feladat (ha van). */
function open_job()
{
    foreach ($GLOBALS['huhs_options'] as $name => $value) {
        if (strpos($name, 'huhs_push_job_') === 0) {
            return array('key' => preg_replace('/^huhs_push_job_/', '', $name), 'job' => $value);
        }
    }
    return null;
}

// --- 0) A küldés előfeltételei (stubolt FCM) --------------------------------
$GLOBALS['huhs_options'][HUHS_PUSH_SERVICE_ACCOUNT_OPTION] = array(
    'project_id' => 'hungarian-hardstyle',
    'client_email' => 'push@hungarian-hardstyle.iam.gserviceaccount.com',
    'private_key' => 'stub',
);
$GLOBALS['huhs_transients']['huhs_firebase_access_token'] = 'stub-access-token';

// --- 1) A keretek (mért értékek) --------------------------------------------
check('a párhuzamosság 50 (a mért 25-ről emelve)', HUHS_PUSH_CONCURRENCY === 50, (string) HUHS_PUSH_CONCURRENCY);
// ⚠️ 2.14.14: a keret 15 → **60 másodperc**, mert a 2.14.13 diagnosztikája
// kimutatta a szerver valódi korlátját (`push_limits=…/max_exec600`). Így a
// ~1030 eszköz egyetlen körben kimegy (~36 s), nem 5-6 láncszemben.
check('az egy körre szánt idő 60 másodperc (a mért max_exec=600 alatt)',
    HUHS_PUSH_TIME_BUDGET === 60, (string) HUHS_PUSH_TIME_BUDGET);
check('a keret négyszeres margóval a szerver korlátja alatt van',
    HUHS_PUSH_TIME_BUDGET * 4 <= 600, (string) (HUHS_PUSH_TIME_BUDGET * 4));
check('a folytató kör kerete rövid (5 másodperc, hogy a látogató ne várjon)',
    HUHS_PUSH_RESUME_BUDGET === 5, (string) HUHS_PUSH_RESUME_BUDGET);
check('a párhuzamos út a konstans szerinti kötegekben dolgozik',
    strpos($pushSource, 'array_chunk($recipients, HUHS_PUSH_CONCURRENCY, true)') !== false);
check('a folytatás MINDKÉT helyen 1 másodpercre van ütemezve (2.14.13 — korábban 2)',
    substr_count($pushSource, "wp_schedule_single_event(time() + 1, 'huhs_push_continue'") === 2,
    (string) substr_count($pushSource, "wp_schedule_single_event(time() + 1, 'huhs_push_continue'"));

// --- 2) A feladat létrehozása: a folytatás 1 másodperc ----------------------
seed_tokens(40);
$GLOBALS['huhs_remote'] = array();
$GLOBALS['huhs_scheduled'] = array();
$GLOBALS['huhs_cron_events'] = array();
$scheduled = huhs_push_schedule_job(array(
    'title' => 'Új hír',
    'body' => 'Teszt cikk',
    'data' => array('type' => 'news', 'id' => '99'),
    'offset' => 0,
    'dead' => array(),
    'runs' => 1,
));
check('a feladat létrejön és a folytatás ütemeződik', $scheduled === true);
$job = open_job();
check('a feladat adatai a tárban vannak', is_array($job) && (int) ($job['job']['offset'] ?? -1) === 0);
$delay = (int) ($GLOBALS['huhs_scheduled'][0]['when'] ?? 0) - time();
check('a folytató kör 1 másodpercre van ütemezve', $delay <= 1, 'delay=' . $delay . 's');

// --- 3) Egy rövid kör: halad, de nem végez — és NEM ismétel -----------------
// ⚠️ A keret **-1 másodperc**: a soros út az első címzettet MINDIG megpróbálja
// (különben a lánc ugyanazon az offseten ragadna), utána viszont a lejárt
// határidő miatt megáll. (A `0.001` KEVÉS volt: a stubolt FCM-válasz olyan
// gyors, hogy mind a 40 eszköz belefért 1 ezredmásodpercbe — a mérés volt rossz.)
$key = (string) ($job['key'] ?? '');
$GLOBALS['huhs_remote'] = array();
huhs_push_continue($key, -1);
$first = sent_tokens();
check('a rövid kör pontosan egy eszközt visz el', count($first) === 1, (string) count($first));
$job = open_job();
check('a feladat offsetje az elküldött darabszámra lépett',
    is_array($job) && (int) ($job['job']['offset'] ?? -1) === 1, json_encode($job['job'] ?? null));
$GLOBALS['huhs_scheduled'] = array();
$GLOBALS['huhs_cron_events'] = array();
huhs_push_continue($key, -1);
$second = sent_tokens();
check('a második kör is halad (nem ragad ugyanarra az offsetre)', count($second) === 2, (string) count($second));
check('a körök NEM küldenek kétszer ugyanarra az eszközre',
    count($second) === count(array_unique($second)), implode(',', $second));
$next_delay = (int) ($GLOBALS['huhs_scheduled'][0]['when'] ?? 0) - time();
check('a kör VÉGÉN is 1 másodpercre ütemeződik a következő kör', $next_delay <= 1, 'delay=' . $next_delay . 's');
check('a foglalás (lock) elengedve, hogy a következő kör beléphessen',
    get_option('huhs_push_job_lock_' . $key, null) === null);

// --- 4) A záró kör: mindenki megkapja, a feladat megszűnik ------------------
$GLOBALS['huhs_remote'] = array();
$GLOBALS['huhs_scheduled'] = array();
$GLOBALS['huhs_cron_events'] = array();
huhs_push_continue($key, 999);
$rest = sent_tokens();
check('a záró kör a maradék eszközöket viszi', count($rest) === 38, (string) count($rest));
check('a záró kör sem ismétel (nincs duplikáció a teljes listán)',
    count(array_unique(array_merge($first, $rest))) === 39, (string) count(array_unique(array_merge($first, $rest))));
check('a feladat megszűnt (nincs örökre nyitva maradt lánc)', open_job() === null);
check('az aktív feladat mutatója is törölve', (string) get_option('huhs_push_active_job', '') === '');
check('a záró kör nem ütemez felesleges folytatást', count($GLOBALS['huhs_scheduled']) === 0);

// --- 5) A diagnosztika kiírja a kereteket -----------------------------------
$limits = huhs_push_diag_limits();
check('a diagnosztika tartalmazza a párhuzamosságot', strpos($limits, 'conc50') !== false, $limits);
check('a diagnosztika tartalmazza a kör-keretet', strpos($limits, 'budget60') !== false, $limits);
check('a diagnosztika tartalmazza a PHP időkorlátját (mérés, nem tipp)',
    strpos($limits, 'max_exec') !== false, $limits);
// ⚠️ A kapu a KONKRÉT hívást méri, nem azt, hogy a név szerepel-e a fájlban —
// a mutációs bizonyíték első futása pont ezt a gyengeséget jelezte: a nevet
// önmagában egy „elrejtett" hívás is tartalmazza.
$diagSource = (string) file_get_contents($pluginDir . '/includes/diagnostics.php');
check('a diagnosztikai sor a fejlécbe is bekerül (a `diagnostics.php` hívja)',
    strpos($diagSource, "function_exists('huhs_push_diag_limits')") !== false
    && strpos($diagSource, '$parts[] = huhs_push_diag_limits();') !== false
    && substr_count($diagSource, 'huhs_push_diag_limits') === 2);

// --- Összegzés -------------------------------------------------------------
$ok = $failures === 0;
echo "\n{$checks} ellenőrzés, {$failures} hiba\n";
if ($ok) echo "PUSH-SPEED OK\n";
exit($ok ? 0 : 1);
