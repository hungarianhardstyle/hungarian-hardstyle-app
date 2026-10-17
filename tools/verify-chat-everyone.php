<?php
/**
 * A „@mindenki” CHAT-PUSH SZÉLES KÜLDÉSE (2.14.19) — PHP stub-harness.
 *
 * MIÉRT: a tulajdonos kérése (2026-10-04): *„hír push, esemény push, chaten
 * @mindenki push üzenetet megkaphatnák azok is, akik nem regisztráltak az
 * appba”*. MÉRVE: a hír- és esemény-push **már** eljut hozzájuk (a plugin
 * token-tára 1070 eszköz, a regisztrált profilok száma 47), a `@mindenki`
 * viszont eddig **csak** a Firestore-profilon ment — ezért a vendégek kimaradtak.
 *
 * Ez a kör a plugin oldalát méri: a nyelvenkénti szöveg tisztítását, a széles
 * push sorba állítását (a chat-adatokkal együtt), a `chat` beállítás-kapcsoló
 * tiszteletben tartását, és azt, hogy a régi (egynyelvű) út **változatlan**.
 *
 * Futtatás: php tools/verify-chat-everyone.php /path/to/huhs-mobile-api
 */

$root = rtrim((string) ($argv[1] ?? ''), '/');
if ($root === '' || !is_dir($root)) {
    fwrite(STDERR, "Használat: php verify-chat-everyone.php <plugin-mappa>\n");
    exit(2);
}

/* --- WordPress stubok (csak a méréshez kell ennyi) ------------------------ */

// ⚠️ MÉRT HIBA (2026-10-04): a `push.php` elején `defined('ABSPATH') || exit;`
// áll — ABSPATH nélkül a szkript **csendben, üres kimenettel** kilépett (0 kóddal),
// ezért a mérés először semmit nem mutatott. A konstansot a betöltés előtt kell
// definiálni.
if (!defined('ABSPATH')) define('ABSPATH', __DIR__ . '/');
// A push.php a WordPress idő-konstansait használja (a betöltéskor is).
if (!defined('HOUR_IN_SECONDS')) define('HOUR_IN_SECONDS', 3600);
if (!defined('DAY_IN_SECONDS')) define('DAY_IN_SECONDS', 86400);
if (!defined('WEEK_IN_SECONDS')) define('WEEK_IN_SECONDS', 604800);
if (!defined('MINUTE_IN_SECONDS')) define('MINUTE_IN_SECONDS', 60);

$GLOBALS['huhs_options'] = array();
$GLOBALS['huhs_scheduled'] = array();

function sanitize_text_field($text) { return trim(strip_tags((string) $text)); }
function sanitize_textarea_field($text) { return trim(strip_tags((string) $text)); }
function sanitize_key($key) { return preg_replace('/[^a-z0-9_\-]/', '', strtolower((string) $key)); }
function wp_strip_all_tags($text) { return strip_tags((string) $text); }
function esc_url_raw($value) { return (string) $value; }
function esc_attr($value) { return htmlspecialchars((string) $value, ENT_QUOTES); }
function wp_unslash($value) { return is_string($value) ? stripslashes($value) : $value; }
function wp_json_encode($value) { return json_encode($value); }
function get_option($name, $default = false) { return $GLOBALS['huhs_options'][$name] ?? $default; }
function update_option($name, $value, $autoload = null) { $GLOBALS['huhs_options'][$name] = $value; return true; }
function add_option($name, $value, $deprecated = '', $autoload = null) {
    if (array_key_exists($name, $GLOBALS['huhs_options'])) return false;
    $GLOBALS['huhs_options'][$name] = $value;
    return true;
}
function delete_option($name) { unset($GLOBALS['huhs_options'][$name]); return true; }
function wp_schedule_single_event($timestamp, $hook, $args = array()) {
    $GLOBALS['huhs_scheduled'][] = array('hook' => $hook, 'args' => $args);
    return true;
}
function spawn_cron() { return true; }
function apply_filters($hook, $value) { return $value; }
function add_action(...$args) { return true; }
function add_filter(...$args) { return true; }
function register_rest_route(...$args) { return true; }
function __return_true() { return true; }
function is_wp_error($thing) { return $thing instanceof WP_Error; }
function get_post($post_id) { return null; }
function get_permalink($post_id) { return ''; }
function url_to_postid($url) { return 0; }
function wp_http_validate_url($url) { return (bool) filter_var($url, FILTER_VALIDATE_URL); }
function wp_parse_url($url, $component = -1) { return parse_url($url, $component); }
function current_time($format) { return date('Y-m-d H:i:s'); }
function wp_next_scheduled($hook) { return false; }
function wp_get_scheduled_event($hook) { return false; }
function wp_clear_scheduled_hook($hook) { return true; }
function get_transient($name) { return false; }
function set_transient($name, $value, $ttl = 0) { return true; }
function delete_transient($name) { return true; }
function get_the_title($post_id) { return ''; }
function get_post_type($post_id) { return ''; }
function get_post_meta($post_id, $key, $single = false) { return $single ? '' : array(); }
function wp_mail(...$args) { return true; }

class WP_Error {
    public function __construct(public $code = '', public $message = '', public $data = null) {}
    public function get_error_code() { return $this->code; }
    public function get_error_message() { return $this->message; }
}
class WP_REST_Request {
    private $params;
    public function __construct(array $params = array()) { $this->params = $params; }
    public function get_json_params() { return $this->params; }
    public function get_param($key) { return $this->params[$key] ?? null; }
}
class WP_REST_Response {
    public function __construct(private $data = null) {}
    public function get_data() { return $this->data; }
}

require_once $root . '/includes/push.php';

/* --- mérés ---------------------------------------------------------------- */

$failures = 0;
function check($label, $ok, $detail = '')
{
    global $failures;
    if (!$ok) $failures++;
    echo ($ok ? 'OK   ' : 'HIBA ') . $label . ($detail !== '' ? ' — ' . $detail : '') . "\n";
}

// 1) A nyelvenkénti szövegek tisztítása: hu+en marad, üres/ismeretlen kimarad.
$texts = huhs_push_clean_texts(array(
    'hu' => array('title' => 'Megemlítettek a Chatben', 'body' => 'Deeroy: szia'),
    'en' => array('title' => 'You were mentioned in the Chat', 'body' => 'Deeroy: hi'),
    'de' => array('title' => 'Sollte wegfallen', 'body' => 'x'),
    'xx' => array('title' => 'Ismeretlen nyelv', 'body' => 'y'),
));
check('a hu és en szöveg megmarad', isset($texts['hu'], $texts['en']));
check('az ismeretlen nyelv (de/xx) kimarad', !isset($texts['de']) && !isset($texts['xx']),
    implode(',', array_keys($texts)));
check('az üres szöveg kimarad', huhs_push_clean_texts(array('hu' => array('title' => '', 'body' => '   '))) === array());
check('nem tömb bemenetre üres listát ad', huhs_push_clean_texts('nem-tomb') === array());

// 2) A széles push sorba állítása a chat-adatokkal.
$data = array('type' => 'chat_everyone', 'id' => 'abc123', 'url' => '');
$queued = huhs_push_queue_custom('Megemlítettek a Chatben', 'Deeroy: szia', $data, $texts);
check('a push sorba állt (nem hiba)', is_array($queued) && ($queued['queued'] ?? false) === true,
    json_encode($queued));
$lock_keys = array_values(array_filter(array_keys($GLOBALS['huhs_options']), function ($key) {
    return strpos((string) $key, 'huhs_custom_push_lock_') === 0;
}));
check('létrejött a feladat (option lock)', count($lock_keys) === 1, implode(',', $lock_keys));
$job = $GLOBALS['huhs_options'][$lock_keys[0]] ?? array();
check('a feladat tárolja a nyelvenkénti szöveget', is_array($job['texts'] ?? null) && count($job['texts']) === 2);
check('a feladat tárolja a chat-adatokat', ($job['data']['type'] ?? '') === 'chat_everyone'
    && ($job['data']['id'] ?? '') === 'abc123', json_encode($job['data'] ?? null));
check('a küldés ütemezve van', count($GLOBALS['huhs_scheduled']) === 1
    && ($GLOBALS['huhs_scheduled'][0]['hook'] ?? '') === 'huhs_custom_push_dispatch');

// 3) Ugyanaz a push 10 percen belül NEM megy ki kétszer (a meglévő dedupe él).
$again = huhs_push_queue_custom('Megemlítettek a Chatben', 'Deeroy: szia', $data, $texts);
check('a második azonos push duplikátumnak számít', ($again['duplicate'] ?? false) === true,
    json_encode($again));

// 4) MÁS szöveg viszont új push (a fingerprint a szöveget is figyeli).
$other = huhs_push_queue_custom('Megemlítettek a Chatben', 'Deeroy: szia', $data,
    array('hu' => array('title' => 'Megemlítettek a Chatben', 'body' => 'Deeroy: másik üzenet')));
check('a megváltozott szöveg új push', ($other['queued'] ?? false) === true, json_encode($other));

// 5) A régi, egynyelvű út VÁLTOZATLAN (Twitch/heti összefoglaló).
$legacy = huhs_push_queue_custom('Élő adás', 'Megy a stream', array('type' => 'custom'));
check('az egynyelvű push is sorba áll', ($legacy['queued'] ?? false) === true, json_encode($legacy));
$legacy_keys = array_values(array_filter(array_keys($GLOBALS['huhs_options']), function ($key) {
    return strpos((string) $key, 'huhs_custom_push_lock_') === 0;
}));
$legacy_job = null;
foreach ($legacy_keys as $key) {
    $candidate = $GLOBALS['huhs_options'][$key];
    if (($candidate['title'] ?? '') === 'Élő adás') $legacy_job = $candidate;
}
check('az egynyelvű feladatnak nincs nyelvenkénti szövege', $legacy_job !== null
    && ($legacy_job['texts'] ?? array()) === array());

// 6) A `chat` beállítás-kapcsoló tiszteletben tartása a címzett-szűrőben.
$tokens = array(
    'a' => array('token' => 'tok-a'),
    'b' => array('token' => 'tok-b', 'chat' => false),
    'c' => array('token' => 'tok-c', 'enabled' => false),
    'd' => array('token' => 'tok-d', 'chat' => true),
);
$recipients = huhs_push_recipients($tokens, array('type' => 'chat_everyone'));
check('a chat-push eléri azt, aki nem állított semmit', isset($recipients['a']));
check('a chat-push eléri azt, akinél be van kapcsolva', isset($recipients['d']));
check('aki a chat-értesítést kikapcsolta, NEM kapja', !isset($recipients['b']));
check('aki az összes értesítést kikapcsolta, NEM kapja', !isset($recipients['c']));
check('a címzettek száma 2', count($recipients) === 2, (string) count($recipients));

// 7) Az admin végpont bekötése (a functions innen küldi a széles chat-pusht).
$admin_source = file_get_contents($root . '/includes/api-admin.php');
check('az admin végpont olvassa a nyelvenkénti szöveget',
    strpos($admin_source, "huhs_push_clean_texts(\$params['texts']") !== false);
check('az admin végpont közvetlen típust is elfogad (chat)',
    strpos($admin_source, "\$explicitType = sanitize_key((string) (\$params['type']") !== false);
check('az admin végpont átadja a szövegeket a sornak',
    strpos($admin_source, 'huhs_push_queue_custom($title, $body, $target, $texts)') !== false);
// ⚠️ A chat-push a `postId` kulcsot is kiküldi: az app ezt olvassa a
// koppintáskor (`_canOpenTarget`), a WordPress-posztok viszont `id`-t kapnak —
// enélkül a chat-értesítés koppintásra nem nyílna meg.
check('az admin végpont a chat-pushoz postId-t is tesz',
    strpos($admin_source, "\$target['postId'] = \$target['id'];") !== false);

// 8) A küldő kör nyelvenként küld, ha vannak szövegek (forrás-lint).
$push_source = file_get_contents($root . '/includes/push.php');
check('a küldő kör nyelvenkénti küldést használ, ha van szöveg',
    strpos($push_source, 'huhs_push_send_localized($texts, $data)') !== false);
check('a küldő kör a régi utat tartja szöveg nélkül',
    strpos($push_source, "huhs_push_send(\$job['title'] ?? '', \$job['body'] ?? '', \$data)") !== false);

echo "\n" . ($failures === 0 ? 'CHAT-EVERYONE OK' : $failures . ' HIBA') . "\n";
exit($failures === 0 ? 0 : 1);
