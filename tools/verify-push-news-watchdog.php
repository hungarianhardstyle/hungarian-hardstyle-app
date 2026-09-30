<?php
/**
 * A HÍR-PUSH ŐRE (plugin 2.14.12) — bizonyítás valódi PHP-n, WordPress nélkül.
 *
 * MIÉRT: éles mérés szerint (2026-09-30) a nap két cikke után EGYETLEN push sem
 * indult: a `push_last` rekord a méréskor a korábbi nap állapota volt, függő
 * cron-esemény nem létezett, viszont a küldési lánc bizonyítottan jó (kézzel
 * indítva 1024 eszközt ért el, 0 hibával). A közzététel-hook tehát nem futott le.
 *
 * MIT MÉR (nem forrás-lint, hanem **lefutó** kód):
 *   1. friss, még nem hirdetett cikk → az ör elindítja az értesítést (a meglévő,
 *      bizonyított úton: `huhs_schedule_news_push` → `huhs_push_publish_news`);
 *   2. a TELJES küldési lánc stubolt FCM-mel: `Új hír` cím, a cikk címe a
 *      törzsben, `type=news` + a cikk azonosítója az adatcsomagban;
 *   3. idempotencia: függő kör közben nem indul új, és a sikeres küldés után
 *      (jelölő) sem;
 *   4. FRISSESSÉGI KAPU: a 6 óránál régebbi cikkre nem megy ki semmi (a feltöltés
 *      pillanatában sem) — és nem is ír jelölőt;
 *   5. vázlat (nem publikált) cikkre nem indul kör;
 *   6. korlátos próbálkozás: a keret elfogyása és az órás hézag is véd;
 *   7. a mentés-hook (`save_post_post`) ugyanezt a döntést használja;
 *   8. a diagnosztikai sor (`news_scan=…`) mérhetővé teszi, hogy a kör lefutott-e.
 *
 * Futtatás (a konténerben, a kibontott csomagon):
 *   php tools/verify-push-news-watchdog.php /work/tmp/php-plugin/huhs-mobile-api
 *
 * Kilépési kód: 0 = minden rendben, 1 = eltérés.
 */

define('ABSPATH', __DIR__);

// A stubolt környezet nem tudja fogni a curl-t, ezért a küldés a soros úton megy.
define('HUHS_PUSH_FORCE_SERIAL', true);

if (!defined('MINUTE_IN_SECONDS')) define('MINUTE_IN_SECONDS', 60);
if (!defined('HOUR_IN_SECONDS')) define('HOUR_IN_SECONDS', 3600);
if (!defined('DAY_IN_SECONDS')) define('DAY_IN_SECONDS', 86400);
if (!defined('WEEK_IN_SECONDS')) define('WEEK_IN_SECONDS', 604800);

// --- WordPress-stubok (csak ami ehhez a méréshez kell) ---------------------
$GLOBALS['huhs_meta'] = array();
$GLOBALS['huhs_titles'] = array();
$GLOBALS['huhs_post_types'] = array();
$GLOBALS['huhs_post_status'] = array();
$GLOBALS['huhs_publish_time'] = array();
$GLOBALS['huhs_posts'] = array();
$GLOBALS['huhs_options'] = array();
$GLOBALS['huhs_transients'] = array();
$GLOBALS['huhs_scheduled'] = array();
$GLOBALS['huhs_hooks'] = array();
$GLOBALS['huhs_cron_events'] = array();
$GLOBALS['huhs_remote'] = array();
$GLOBALS['huhs_spawned'] = 0;

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
function wp_generate_password($length = 12, $special = true, $extra = true) { return substr(str_repeat('x7k2q9', 8), 0, (int) $length); }
function wp_strip_all_tags($value) { return strip_tags((string) $value); }
function wp_strip_all_tags_list($value) { return $value; }
function sanitize_key($value) { return strtolower(preg_replace('/[^A-Za-z0-9_\-]/', '', (string) $value)); }
function esc_url_raw($value) { return trim((string) $value); }
function esc_html($value) { return htmlspecialchars((string) $value); }
function get_the_title($post) { return $GLOBALS['huhs_titles'][$post->ID] ?? ''; }
function wp_is_post_revision($post_id) { return false; }
function wp_is_post_autosave($post_id) { return false; }
function get_permalink($post = null) { return 'https://hungarianhardstyle.hu/'; }
function get_post_time($format, $gmt = false, $post = null)
{
    $id = is_object($post) ? (int) $post->ID : (int) $post;
    $timestamp = (int) ($GLOBALS['huhs_publish_time'][$id] ?? 0);
    return $format === 'U' ? $timestamp : date('Y-m-d H:i:s', $timestamp);
}
function get_post_meta($post_id, $key, $single = false)
{
    $value = $GLOBALS['huhs_meta'][$post_id][$key] ?? '';
    return $single ? $value : (array) $value;
}
function update_post_meta($post_id, $key, $value) { $GLOBALS['huhs_meta'][$post_id][$key] = $value; return true; }
function delete_post_meta($post_id, $key) { unset($GLOBALS['huhs_meta'][$post_id][$key]); return true; }
function get_post($id)
{
    $id = (int) $id;
    if (!isset($GLOBALS['huhs_post_types'][$id])) return null;
    return (object) array(
        'ID' => $id,
        'post_status' => $GLOBALS['huhs_post_status'][$id] ?? 'publish',
        'post_type' => $GLOBALS['huhs_post_types'][$id],
    );
}
function get_posts($args = array())
{
    $type = (string) ($args['post_type'] ?? '');
    $out = array();
    foreach ($GLOBALS['huhs_posts'] as $post) {
        if ($type !== '' && (string) $post->post_type !== $type) continue;
        if (isset($args['post_status']) && (string) $post->post_status !== (string) $args['post_status']) continue;
        $out[] = $post;
    }
    return $out;
}
function wp_timezone() { return new DateTimeZone('Europe/Budapest'); }
function wp_date($format, $timestamp = null, $timezone = null)
{
    $zone = $timezone instanceof DateTimeZone ? $timezone : wp_timezone();
    $moment = new DateTime('@' . (int) ($timestamp ?? time()));
    $moment->setTimezone($zone);
    return $moment->format($format);
}
function current_time($type = 'mysql', $gmt = 0)
{
    return $type === 'timestamp' ? time() : wp_date($type, time());
}
function wp_schedule_single_event($when, $hook, $args = array())
{
    $GLOBALS['huhs_scheduled'][] = array('when' => (int) $when, 'hook' => $hook, 'args' => $args);
    $GLOBALS['huhs_cron_events'][] = array('when' => (int) $when, 'hook' => $hook, 'args' => $args);
    return true;
}
function wp_schedule_event($when, $recurrence, $hook, $args = array())
{
    $GLOBALS['huhs_cron_events'][] = array('when' => (int) $when, 'hook' => $hook, 'args' => $args, 'recurrence' => $recurrence);
    return true;
}
function wp_next_scheduled($hook, $args = array())
{
    foreach ($GLOBALS['huhs_cron_events'] as $event) {
        if ($event['hook'] !== $hook) continue;
        if (wp_json_encode($event['args']) !== wp_json_encode($args)) continue;
        return (int) $event['when'];
    }
    return false;
}
function spawn_cron($gmt = null) { $GLOBALS['huhs_spawned'] = (int) ($GLOBALS['huhs_spawned'] ?? 0) + 1; return true; }

class WP_Error
{
    public $code;
    public $message;
    public function __construct($code = '', $message = '', $data = array())
    {
        $this->code = $code;
        $this->message = $message;
    }
    public function get_error_code() { return $this->code; }
    public function get_error_message() { return $this->message; }
}

function is_wp_error($thing) { return $thing instanceof WP_Error; }

/** A hálózat stubja: minden FCM-kérés rögzül (a szöveg és az adatcsomag mérhető). */
function wp_remote_post($url, $args = array())
{
    $GLOBALS['huhs_remote'][] = array('url' => (string) $url, 'body' => $args['body'] ?? '', 'headers' => $args['headers'] ?? array());
    return array('response' => array('code' => 200), 'body' => '{"name":"projects/hungarian-hardstyle/messages/1"}');
}
function wp_remote_retrieve_response_code($response) { return (int) ($response['response']['code'] ?? 0); }
function wp_remote_retrieve_body($response) { return (string) ($response['body'] ?? ''); }

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

function sent_messages()
{
    $out = array();
    foreach ($GLOBALS['huhs_remote'] as $request) {
        if (strpos($request['url'], 'fcm.googleapis.com') === false) continue;
        $decoded = json_decode((string) $request['body'], true);
        if (!is_array($decoded)) continue;
        $out[] = array(
            'token' => (string) ($decoded['message']['token'] ?? ''),
            'title' => (string) ($decoded['message']['notification']['title'] ?? ''),
            'body' => (string) ($decoded['message']['notification']['body'] ?? ''),
            'data' => (array) ($decoded['message']['data'] ?? array()),
        );
    }
    return $out;
}

function reset_send_state()
{
    $GLOBALS['huhs_remote'] = array();
    $GLOBALS['huhs_scheduled'] = array();
    $GLOBALS['huhs_options']['huhs_push_last_result'] = array();
}

function seed_post($id, $post_type, $title, $meta = array(), $status = 'publish', $published_at = null)
{
    $GLOBALS['huhs_post_types'][$id] = $post_type;
    $GLOBALS['huhs_post_status'][$id] = $status;
    $GLOBALS['huhs_titles'][$id] = $title;
    $GLOBALS['huhs_publish_time'][$id] = $published_at ?? time();
    foreach ($meta as $key => $value) $GLOBALS['huhs_meta'][$id][$key] = $value;
    $GLOBALS['huhs_posts'][] = (object) array('ID' => $id, 'post_type' => $post_type, 'post_status' => $status);
}

// --- 0) A küldési lánc előfeltételei (stubolt FCM) --------------------------
$GLOBALS['huhs_options'][HUHS_PUSH_SERVICE_ACCOUNT_OPTION] = array(
    'project_id' => 'hungarian-hardstyle',
    'client_email' => 'push@hungarian-hardstyle.iam.gserviceaccount.com',
    'private_key' => 'stub',
);
$GLOBALS['huhs_transients']['huhs_firebase_access_token'] = 'stub-access-token';
$GLOBALS['huhs_options'][HUHS_PUSH_TOKENS_OPTION] = array(
    'hu-1' => array('token' => 'token-hu-aaaaaaaaaaaaaaaa', 'language' => 'hu'),
    'en-1' => array('token' => 'token-en-bbbbbbbbbbbbbbbb', 'language' => 'en'),
);

// --- 1) A valódi eset: friss cikk, amelyről a hook nem indított kört --------
// (Pontosan ez történt élesben: a cikk publikált, de egyetlen értesítés sem indult.)
$GLOBALS['huhs_posts'] = array();
reset_send_state();
seed_post(9001, 'post', 'Zany egy különleges, 8 órás szóló szettel érkezik a Memorylane-re.', array(), 'publish', time() - 300);
$queued = huhs_push_scan_missing_news();
$pending_marker = (int) get_post_meta(9001, '_huhs_push_news_pending_at', true);
$scheduled = array_values(array_filter($GLOBALS['huhs_scheduled'], function ($event) {
    return $event['hook'] === 'huhs_push_publish_news';
}));
check('friss, még nem hirdetett cikk → az ör elindítja az értesítést', $queued === 1, (string) $queued);
check('a függő jelölő beíródott (innen tudja a lánc, hogy fut)', $pending_marker > 0);
check('a küldés a bizonyított útra került (`huhs_push_publish_news`)', count($scheduled) === 1,
    json_encode(array_map(function ($event) { return $event['hook']; }, $GLOBALS['huhs_scheduled'])));
check('a küldés AZONNAL (1 másodperc) ütemezve, nem vár a következő ötpercre',
    (int) ($scheduled[0]['when'] ?? 0) <= time() + 2);

// A lánc második fele: maga a küldés (a szokásos hír-push függvénye).
$token = (string) ($scheduled[0]['args'][1] ?? '');
huhs_push_publish_news(9001, $token, 1);
$messages = sent_messages();
check('a cikk értesítése MINDEN eszközre kimegy (stubolt FCM)', count($messages) === 2, (string) count($messages));
$by_token = array();
foreach ($messages as $message) $by_token[$message['token']] = $message;
$hungarian = $by_token['token-hu-aaaaaaaaaaaaaaaa'] ?? array();
check('a cím a szokásos „Új hír"', ($hungarian['title'] ?? '') === 'Új hír', $hungarian['title'] ?? '');
check('a törzs a cikk címe', ($hungarian['body'] ?? '') === $GLOBALS['huhs_titles'][9001], $hungarian['body'] ?? '');
$data = $hungarian['data'] ?? array();
check('az adatcsomag `news` típusú és a cikket nyitja meg',
    ($data['type'] ?? '') === 'news' && ($data['id'] ?? '') === '9001', json_encode($data));
check('a sikeres küldés jelölője beíródott (nincs ismétlés)',
    (string) get_post_meta(9001, '_huhs_push_news_sent', true) !== ''
    && (int) get_post_meta(9001, '_huhs_push_news_pending_at', true) === 0);

// --- 2) Idempotencia --------------------------------------------------------
reset_send_state();
check('a jelölő után az ör sem indít új kört', huhs_push_scan_missing_news() === 0);
check('és nincs új FCM-hívás sem', count(sent_messages()) === 0, (string) count(sent_messages()));

// Függő kör közben sem indul második.
$GLOBALS['huhs_posts'] = array();
reset_send_state();
seed_post(9002, 'post', 'Második friss cikk', array(), 'publish', time() - 120);
check('az első kör elindítja', huhs_push_scan_missing_news() === 1);
reset_send_state();
check('a függő kör alatt az ör NEM indít másodikat', huhs_push_scan_missing_news() === 0);
check('(a függő jelölő a régi, tehát a lánc viszi ki)', (int) get_post_meta(9002, '_huhs_push_news_pending_at', true) > 0);

// ⚠️ A FÜGGŐ KÖR védelme ÖNMAGÁBAN mérve: a korlátos próbálkozás hézag-kapuja
// (óránként egyszer) különben elfedi. Ezért itt a hézag LEJÁRT, a kör viszont fut:
// ilyenkor is tilos másodikat indítani (különben a cikk kétszer menne ki).
$GLOBALS['huhs_posts'] = array();
reset_send_state();
seed_post(9012, 'post', 'Futó kör, lejárt hézaggal', array(), 'publish', time() - 300);
check('az első kör elindítja (futó lánc)', huhs_push_scan_missing_news() === 1);
$GLOBALS['huhs_meta'][9012]['_huhs_push_news_watchdog_at'] = time() - 2 * HOUR_IN_SECONDS;
reset_send_state();
check('lejárt hézag MELLETT is véd a függő kör (nincs dupla küldés)',
    huhs_push_scan_missing_news() === 0 && count(sent_messages()) === 0);

// ⚠️ A JELÖLŐ védelme ÖNMAGÁBAN mérve — ugyanazért, mert a hézag-kapu elfedi.
$GLOBALS['huhs_posts'] = array();
reset_send_state();
seed_post(9013, 'post', 'Már értesített cikk', array(
    '_huhs_push_news_sent' => 'mar-kiment',
    '_huhs_push_news_watchdog_at' => time() - 2 * HOUR_IN_SECONDS,
), 'publish', time() - 300);
check('a már értesített cikkre akkor sem megy ki újra, ha a hézag lejárt',
    huhs_push_scan_missing_news() === 0 && count(sent_messages()) === 0);
check('és nem is ír függő jelölőt', (int) get_post_meta(9013, '_huhs_push_news_pending_at', true) === 0);

// --- 3) FRISSESSÉGI KAPU (a legfontosabb kockázat) --------------------------
$GLOBALS['huhs_posts'] = array();
reset_send_state();
seed_post(9003, 'post', 'Hét órával ezelőtt publikált cikk', array(), 'publish', time() - 7 * HOUR_IN_SECONDS);
check('a 6 óránál régebbi cikkre NEM indul kör (nincs utólagos hirdetés)', huhs_push_scan_missing_news() === 0);
check('és nem is ír jelölőt', (int) get_post_meta(9003, '_huhs_push_news_pending_at', true) === 0
    && (string) get_post_meta(9003, '_huhs_push_news_sent', true) === '');
seed_post(9004, 'post', 'Öt órával ezelőtt publikált cikk', array(), 'publish', time() - 5 * HOUR_IN_SECONDS);
check('5 órás cikk → még hirdethető (a kapu 6 óra)', huhs_push_news_watch_one(get_post(9004)) === true);

// --- 4) Nem publikált tartalom ---------------------------------------------
$GLOBALS['huhs_posts'] = array();
reset_send_state();
seed_post(9005, 'post', 'Vázlat cikk', array(), 'draft', time() - 60);
check('vázlatra nem indul kör', huhs_push_scan_missing_news() === 0);
check('és nem is ír jelölőt', (int) get_post_meta(9005, '_huhs_push_news_pending_at', true) === 0);

// --- 5) Korlátos próbálkozás ------------------------------------------------
$GLOBALS['huhs_posts'] = array();
reset_send_state();
seed_post(9006, 'post', 'Friss cikk, kimerült kerettel', array(
    '_huhs_push_news_watchdog_tries' => HUHS_PUSH_NEWS_WATCHDOG_MAX_TRIES,
), 'publish', time() - 60);
check('a keret elfogyása után nem próbálkozik tovább', huhs_push_news_watch_one(get_post(9006)) === false);

seed_post(9007, 'post', 'Friss cikk, friss ör-próbával', array(
    '_huhs_push_news_watchdog_at' => time() - 60,
), 'publish', time() - 60);
check('órán belüli próbálkozás után sem indít újat', huhs_push_news_watch_one(get_post(9007)) === false);

seed_post(9008, 'post', 'Friss cikk, régi ör-próbával', array(
    '_huhs_push_news_watchdog_at' => time() - 2 * HOUR_IN_SECONDS,
), 'publish', time() - 60);
check('egy óránál régebbi próbálkozás után viszont újra (a lánc pótlása)', huhs_push_news_watch_one(get_post(9008)) === true);

// --- 6) A mentés-hook ugyanezt a döntést használja --------------------------
$hooks = array();
foreach ($GLOBALS['huhs_hooks'] as $entry) $hooks[$entry['hook']] = $entry;
check('a `save_post_post` hook be van kötve', isset($hooks['save_post_post']));
check('a mentés-hook a plugin saját mentése UTÁN fut (20 > 10)', ($hooks['save_post_post']['priority'] ?? 0) === 20);
check('az ötperces ör be van kötve (`huhs_push_news_scan`)',
    isset($hooks['huhs_push_news_scan']) && in_array('huhs_push_scan_missing_news', (array) $hooks['huhs_push_news_scan']['callback'], true));
check('az ör az `init`-ben regisztrálódik az ötperces ütemezésre',
    strpos($pushSource, "wp_schedule_event(time() + 180, 'huhs_five_minutes', 'huhs_push_news_scan')") !== false);

// A mentés-hook döntése ugyanaz: friss, jelölő nélküli cikk → kör; jelölt cikk → semmi.
$GLOBALS['huhs_posts'] = array();
reset_send_state();
$callback = $hooks['save_post_post']['callback'];
seed_post(9009, 'post', 'Mentés-hookkal publikált cikk', array(), 'publish', time() - 30);
$callback(9009, get_post(9009), true);
check('a mentés-hook friss cikkre elindítja az értesítést',
    (int) get_post_meta(9009, '_huhs_push_news_pending_at', true) > 0);
$before = (int) get_post_meta(9009, '_huhs_push_news_pending_at', true);
$callback(9009, get_post(9009), true);
check('a mentés-hook ismételt futása nem indít másodikat',
    (int) get_post_meta(9009, '_huhs_push_news_pending_at', true) === $before);
seed_post(9010, 'post', 'Vázlat', array(), 'draft', time());
$callback(9010, get_post(9010), true);
check('a mentés-hook vázlatra nem indít kört',
    (int) get_post_meta(9010, '_huhs_push_news_pending_at', true) === 0);

// --- 7) A diagnosztika mérhetővé teszi a kört ------------------------------
$GLOBALS['huhs_options']['huhs_push_news_scan'] = array();
check('kör nélkül a diagnosztika ezt kimondja', huhs_push_diag_news_scan() === 'news_scan=none');
$GLOBALS['huhs_posts'] = array();
reset_send_state();
seed_post(9011, 'post', 'Diagnosztika cikk', array(), 'publish', time() - 30);
huhs_push_scan_missing_news();
$diag = huhs_push_diag_news_scan();
check('a kör után a diagnosztikában látszik az idő és a szám',
    strpos($diag, 'news_scan=') === 0 && strpos($diag, '/s1') !== false && strpos($diag, '/q1') !== false, $diag);
check('a diagnosztikai sor a fejlécbe is bekerül (a `diagnostics.php` hívja)',
    strpos((string) file_get_contents($pluginDir . '/includes/diagnostics.php'), 'huhs_push_diag_news_scan') !== false);

// --- Összegzés -------------------------------------------------------------
$ok = $failures === 0;
echo "\n{$checks} ellenőrzés, {$failures} hiba\n";
if ($ok) echo "PUSH-NEWS OK\n";
exit($ok ? 0 : 1);
