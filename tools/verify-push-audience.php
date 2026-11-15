<?php
/**
 * A PUSH CÍMZETTJEI ÉS A DUPLIKÁCIÓ (plugin 2.14.29) — valódi PHP, WP-stubokkal.
 *
 * A mérés a valódi `includes/push.php` függvényeit futtatja:
 *   1. új esemény/kiadvány: MINDEN engedélyezett eszköz címzett (a kedvenc-
 *      alapú szűrő nem ejthet ki senkit);
 *   2. nyelvenkénti emlékeztető több körben: az EREDETI címzettlista és nyelv
 *      marad, új token nem keveredik be, eszközönként pontosan egy push;
 *   3. folyamatban lévő emlékeztető nem indul újra; a jelölő atomikusan foglal.
 *
 * Futtatás: php tools/verify-push-audience.php /work/tmp/php-plugin/huhs-mobile-api
 * Kilépési kód: 0 = minden rendben, 1 = eltérés.
 */

define('ABSPATH', __DIR__);
define('HUHS_PUSH_FORCE_SERIAL', true);
// Minden hívás csak az ELSŐ címzettet viszi el, így a lánc tényleg több körös lesz.
define('HUHS_PUSH_TIME_BUDGET', -1);
if (!defined('MINUTE_IN_SECONDS')) define('MINUTE_IN_SECONDS', 60);
if (!defined('HOUR_IN_SECONDS')) define('HOUR_IN_SECONDS', 3600);
if (!defined('DAY_IN_SECONDS')) define('DAY_IN_SECONDS', 86400);
if (!defined('WEEK_IN_SECONDS')) define('WEEK_IN_SECONDS', 604800);

$GLOBALS['huhs_options'] = array();
$GLOBALS['huhs_meta'] = array();
$GLOBALS['huhs_transients'] = array();
$GLOBALS['huhs_scheduled'] = array();
$GLOBALS['huhs_cron_events'] = array();
$GLOBALS['huhs_remote'] = array();
$GLOBALS['huhs_titles'] = array(12505 => 'Hard Base Classic');
$GLOBALS['huhs_fail_fcm'] = false;

function add_action(...$args) { return true; }
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
function current_user_can($cap) { return $cap === 'manage_options'; }
function sanitize_text_field($value) { return trim(preg_replace('/[\r\n\t]+/', ' ', strip_tags((string) $value))); }
function sanitize_textarea_field($value) { return trim(strip_tags((string) $value)); }
function sanitize_key($value) { return strtolower(preg_replace('/[^A-Za-z0-9_\-]/', '', (string) $value)); }
function absint($value) { return abs((int) $value); }
function wp_json_encode($value, $flags = 0) { return json_encode($value, $flags); }
function wp_generate_password($length = 12, $special = true, $extra = true)
{
    static $counter = 0;
    $counter++;
    return substr('job' . $counter . 'abcdefgh', 0, (int) $length);
}
function wp_strip_all_tags($value) { return strip_tags((string) $value); }
function wp_schedule_single_event($when, $hook, $args = array())
{
    $event = array('when' => (int) $when, 'hook' => $hook, 'args' => $args);
    $GLOBALS['huhs_scheduled'][] = $event;
    $GLOBALS['huhs_cron_events'][] = $event;
    return true;
}
function wp_next_scheduled($hook, $args = array())
{
    foreach ($GLOBALS['huhs_cron_events'] as $event) {
        if ($event['hook'] === $hook && wp_json_encode($event['args']) === wp_json_encode($args)) return (int) $event['when'];
    }
    return false;
}
function spawn_cron($gmt = null) { return true; }
function current_time($type = 'mysql', $gmt = 0) { return $type === 'timestamp' ? time() : gmdate('Y-m-d H:i:s'); }
function wp_timezone() { return new DateTimeZone('Europe/Budapest'); }
function wp_date($format, $timestamp = null, $timezone = null)
{
    $zone = $timezone instanceof DateTimeZone ? $timezone : wp_timezone();
    $moment = new DateTime('@' . (int) ($timestamp ?? time()));
    $moment->setTimezone($zone);
    return $moment->format($format);
}
function get_the_title($post) { return $GLOBALS['huhs_titles'][$post->ID] ?? ''; }
function get_post($id)
{
    if ((int) $id !== 12505) return null;
    return (object) array('ID' => 12505, 'post_status' => 'publish', 'post_type' => 'huhs_event');
}
function get_post_meta($post_id, $key, $single = false) { return $GLOBALS['huhs_meta'][$post_id][$key] ?? ''; }
function update_post_meta($post_id, $key, $value) { $GLOBALS['huhs_meta'][$post_id][$key] = $value; return true; }
function delete_post_meta($post_id, $key) { unset($GLOBALS['huhs_meta'][$post_id][$key]); return true; }
function add_post_meta($post_id, $key, $value, $unique = false)
{
    if ($unique && array_key_exists($key, $GLOBALS['huhs_meta'][$post_id] ?? array())) return false;
    $GLOBALS['huhs_meta'][$post_id][$key] = $value;
    return true;
}
function is_wp_error($thing) { return false; }
class WP_Error { public function __construct($a = '', $b = '', $c = array()) {} }
function wp_remote_post($url, $args = array())
{
    $GLOBALS['huhs_remote'][] = array('url' => (string) $url, 'body' => $args['body'] ?? '');
    if ($GLOBALS['huhs_fail_fcm'] && strpos($url, 'fcm.googleapis.com') !== false) {
        return array('response' => array('code' => 500), 'body' => '{"error":{"status":"INTERNAL"}}');
    }
    return array('response' => array('code' => 200), 'body' => '{"name":"projects/p/messages/1"}');
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
    $GLOBALS['huhs_cron_events'] = array();
    $GLOBALS['huhs_options'][HUHS_PUSH_SERVICE_ACCOUNT_OPTION] = array(
        'project_id' => 'hungarian-hardstyle',
        'client_email' => 'push@example.test',
        'private_key' => 'stub',
    );
    $GLOBALS['huhs_transients']['huhs_firebase_access_token'] = 'stub-access-token';
    $GLOBALS['huhs_fail_fcm'] = false;
}

function seed_languages()
{
    $GLOBALS['huhs_options'][HUHS_PUSH_TOKENS_OPTION] = array(
        'hu-1' => array('token' => 'token-hu-1-aaaaaaaaaaaaaaaa', 'language' => 'hu'),
        'hu-2' => array('token' => 'token-hu-2-bbbbbbbbbbbbbbbb', 'language' => 'hu'),
        'en-1' => array('token' => 'token-en-1-cccccccccccccccc', 'language' => 'en'),
        'en-2' => array('token' => 'token-en-2-dddddddddddddddd', 'language' => 'en'),
    );
}

function finish_all_jobs()
{
    $rounds = 0;
    while (huhs_push_live_jobs() && $rounds < 20) {
        foreach (huhs_push_live_jobs() as $key) huhs_push_continue($key, -1);
        $rounds++;
    }
    return $rounds;
}

// --- 1) Új esemény/kiadvány: a kedvenc-lista NEM szűkítheti a közönséget ------
$audience = array(
    'follows' => array('token' => str_repeat('a', 24), 'language' => 'hu', 'artists' => array(7)),
    'other' => array('token' => str_repeat('b', 24), 'language' => 'hu', 'artists' => array(99)),
    'legacy' => array('token' => str_repeat('c', 24), 'language' => 'hu'),
    'off' => array('token' => str_repeat('d', 24), 'language' => 'hu', 'enabled' => false),
);
$release = array('type' => 'release', 'id' => '123', 'artists' => array(7));
$event = array('type' => 'event', 'id' => '12505', 'artists' => array(7), 'organizers' => array(3));
check('új kiadvány: MINDEN engedélyezett eszköz címzett (nem csak a DJ követői)',
    count(huhs_push_recipients($audience, $release, '')) === 3,
    implode(',', array_keys(huhs_push_recipients($audience, $release, ''))));
check('új esemény: MINDEN engedélyezett eszköz címzett (más DJ-t követő is)',
    count(huhs_push_recipients($audience, $event, '')) === 3,
    implode(',', array_keys(huhs_push_recipients($audience, $event, ''))));
check('a kikapcsolt értesítés továbbra is kimarad (a felhasználói kapcsoló él)',
    !array_key_exists('off', huhs_push_recipients($audience, $event, '')));

// --- 2) A lokalizált emlékeztető TÖBB KÖRBEN sem dupláz és nem kever nyelvet ---
reset_send_state();
seed_languages();
$GLOBALS['huhs_options']['huhs_push_chain_index'] = array();
huhs_push_send_localized(array(
    'hu' => array('title' => 'Esemény 2 óra múlva', 'body' => 'Hard Base Classic'),
    'en' => array('title' => 'Event in 2 hours', 'body' => 'Hard Base Classic'),
), array('type' => 'event', 'kind' => 'reminder', 'id' => '12505'));
$initialJobs = huhs_push_live_jobs();
check('a két nyelv KÜLÖN feladatot kap', count($initialJobs) === 2, implode(',', $initialJobs));
$snapshots = array();
foreach ($initialJobs as $key) {
    $job = get_option('huhs_push_job_' . $key, array());
    $snapshots[$key] = array(
        'language' => (string) ($job['language'] ?? ''),
        'recipients' => is_array($job['recipients'] ?? null) ? $job['recipients'] : array(),
    );
}
$languages = array_values(array_map(function ($entry) { return $entry['language']; }, $snapshots));
sort($languages);
check('a feladat megőrzi a nyelvet (hu + en)', $languages === array('en', 'hu'), implode(',', $languages));
$recipientCounts = array_values(array_map(function ($entry) { return count($entry['recipients']); }, $snapshots));
sort($recipientCounts);
check('a feladat az EREDETI címzettlistát is tárolja (2 magyar + 2 angol)',
    $recipientCounts === array(2, 2), json_encode($recipientCounts));

// Új eszköz és a token-tár sorrendjének megváltoztatása a folytatás ELŐTT.
$GLOBALS['huhs_options'][HUHS_PUSH_TOKENS_OPTION]['hu-new'] = array(
    'token' => 'token-new-zzzzzzzzzzzzzzzz',
    'language' => 'hu',
);
finish_all_jobs();
$messages = sent_messages();
$perToken = array();
foreach ($messages as $message) $perToken[$message['token']][] = $message['title'];
check('minden EREDETI eszköz PONTOSAN EGY emlékeztetőt kap', count($messages) === 4
    && count($perToken['token-hu-1-aaaaaaaaaaaaaaaa'] ?? array()) === 1
    && count($perToken['token-hu-2-bbbbbbbbbbbbbbbb'] ?? array()) === 1
    && count($perToken['token-en-1-cccccccccccccccc'] ?? array()) === 1
    && count($perToken['token-en-2-dddddddddddddddd'] ?? array()) === 1,
    json_encode($perToken));
check('a magyar eszközök magyar, az angol eszköz angol szöveget kap',
    ($perToken['token-hu-1-aaaaaaaaaaaaaaaa'][0] ?? '') === 'Esemény 2 óra múlva'
    && ($perToken['token-hu-2-bbbbbbbbbbbbbbbb'][0] ?? '') === 'Esemény 2 óra múlva'
    && ($perToken['token-en-1-cccccccccccccccc'][0] ?? '') === 'Event in 2 hours'
    && ($perToken['token-en-2-dddddddddddddddd'][0] ?? '') === 'Event in 2 hours',
    json_encode($perToken));
check('a folytatásba került ÚJ token nem kapja meg a már futó kört (nincs elcsúszás)',
    !array_key_exists('token-new-zzzzzzzzzzzzzzzz', $perToken), implode(',', array_keys($perToken)));
check('a befejezett feladatok eltűnnek (nincs újraindítható lánc)', huhs_push_live_jobs() === array());

// --- 3) Az emlékeztető nem indul újra folyamatban lévő küldés mellett ---------
$GLOBALS['huhs_options'][HUHS_PUSH_TOKENS_OPTION] = array(
    'hu-1' => array('token' => 'token-hu-1-aaaaaaaaaaaaaaaa', 'language' => 'hu'),
    'en-1' => array('token' => 'token-en-1-cccccccccccccccc', 'language' => 'en'),
);
$GLOBALS['huhs_meta'][12505] = array(
    'event_start_date' => wp_date('Y-m-d', time() + 7200),
    'event_start_time' => wp_date('H:i', time() + 7200),
    'venue_name' => 'Stenk',
    'venue_city' => 'Budapest',
);
reset_send_state();
$GLOBALS['huhs_options']['huhs_push_chain_index'] = array();
huhs_push_event_reminder(12505, 'two_hours');
$firstCount = count(sent_messages());
check('az első emlékeztető elindul és a jelölő beíródik',
    $firstCount === 2 && (string) get_post_meta(12505, '_huhs_push_reminder_sent_two_hours', true) !== '',
    'küldések=' . $firstCount . ', jelölő=' . (string) get_post_meta(12505, '_huhs_push_reminder_sent_two_hours', true));
$jobsAfterFirst = huhs_push_live_jobs();
huhs_push_event_reminder(12505, 'two_hours');
check('a második hívás NEM indít új emlékeztetőt és nem küld újra',
    count(sent_messages()) === $firstCount && huhs_push_live_jobs() === $jobsAfterFirst,
    'előtte=' . $firstCount . ', utána=' . count(sent_messages()));

// Sikertelen első szelet: a feladat folyamatban van, a következő scan nem dupláz.
$GLOBALS['huhs_meta'][12505]['_huhs_push_reminder_sent_two_hours'] = '';
reset_send_state();
$GLOBALS['huhs_options']['huhs_push_chain_index'] = array();
$GLOBALS['huhs_fail_fcm'] = true;
huhs_push_event_reminder(12505, 'two_hours');
$failedFirstCount = count(sent_messages());
$failedJobs = huhs_push_live_jobs();
check('sikertelen szeletnél a jelölő NEM marad bent (később újra lehet próbálni)',
    $failedFirstCount === 2 && (string) get_post_meta(12505, '_huhs_push_reminder_sent_two_hours', true) === ''
    && count($failedJobs) > 0,
    'küldések=' . $failedFirstCount . ', jelölő=' . (string) get_post_meta(12505, '_huhs_push_reminder_sent_two_hours', true));
huhs_push_event_reminder(12505, 'two_hours');
check('sikertelen, de FOLYMATBAN lévő kör NEM indul újra a scan miatt',
    count(sent_messages()) === $failedFirstCount && huhs_push_live_jobs() === $failedJobs,
    'előtte=' . $failedFirstCount . ', utána=' . count(sent_messages()));

echo "\n{$checks} ellenőrzés, {$failures} hiba\n";
if ($failures === 0) echo "PUSH-AUDIENCE OK\n";
exit($failures > 0 ? 1 : 0);
