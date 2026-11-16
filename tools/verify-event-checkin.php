<?php
/**
 * A BULIS BECSEKKOLÁS (plugin 2.15.0) — bizonyítás valódi PHP-n, stubolt WordPressen.
 *
 * MIT MÉR (lefutó kód, nem forrás-lint):
 *   1. az **időablak**: kezdés előtt 1 órával nyílik, a végén zár; záró idő nélkül
 *      a kezdéstől 10 óra; a 22:00 → 05:00 buli az éjfél utáni nap;
 *   2. a **kapu**: rossz kód → 403, ablakon kívül → 403 (a „state" jelzéssel),
 *      érvényes → ok, **ugyanaz a fiók másodszor** → `alreadyCheckedIn`, és a
 *      WordPress a **UID-t nem tárolja** (csak a sózott ujjlenyomatot);
 *   3. a **0-s idő csapda**: a sor LÉTEZÉSE dönt, nem az értéke;
 *   4. az **időbeosztás** értelmezése (két alak, hibás sor kimarad);
 *   5. a **nyilvános mezők nem adják ki a kódot**;
 *
 * Futtatás: php tools/verify-event-checkin.php /work/tmp/php-plugin/huhs-mobile-api
 * Kilépési kód: 0 = minden rendben.
 */

define('ABSPATH', __DIR__);
const HOUR_IN_SECONDS = 3600;
const DAY_IN_SECONDS = 86400;

$GLOBALS['opts'] = array();
$GLOBALS['meta'] = array();     // [post_id][key] => value
$GLOBALS['routes'] = array();
$GLOBALS['now'] = 0;

class WP_Error
{
    public $code; public $message; public $data;
    public function __construct($code = '', $message = '', $data = array())
    {
        $this->code = $code; $this->message = $message; $this->data = $data;
    }
}
class WP_Post { public $ID; public $post_type = 'huhs_event'; public $post_status = 'publish'; public $post_title = 'Hard Base'; }
class WP_REST_Request
{
    private $params; private $method;
    public function __construct($params = array(), $method = 'POST') { $this->params = $params; $this->method = $method; }
    public function get_param($k) { return $this->params[$k] ?? null; }
    public function get_method() { return $this->method; }
    public function offsetGet($k) { return $this->params[$k] ?? null; }
}
function add_action(...$a) { return true; }
function register_rest_route($ns, $route, $args = array()) { $GLOBALS['routes'][$route] = $args; return true; }
function get_option($n, $d = false) { return $GLOBALS['opts'][$n] ?? $d; }
function add_option($n, $v) { $GLOBALS['opts'][$n] = $v; return true; }
function wp_generate_password($len = 12) { return substr(bin2hex(random_bytes($len)), 0, $len); }
function wp_timezone() { return new DateTimeZone('Europe/Budapest'); }
function home_url($p = '') { return 'https://hungarianhardstyle.hu' . $p; }
function get_post($id) { $p = new WP_Post(); $p->ID = (int) $id; return $id > 0 ? $p : null; }
function get_post_status($id) { return 'publish'; }
function get_the_title($id) { return 'Hard Base'; }
function huhs_clean_title($t) { return $t; }
function sanitize_text_field($s) { return trim((string) $s); }
function esc_url_raw($u) { return (string) $u; }
function get_post_meta($id, $key, $single = true) { return $GLOBALS['meta'][$id][$key] ?? ''; }
function update_post_meta($id, $key, $value) { $GLOBALS['meta'][$id][$key] = $value; return true; }
function metadata_exists($t, $id, $key) { return array_key_exists($key, $GLOBALS['meta'][$id] ?? array()); }
function add_post_meta($id, $key, $value, $unique = false)
{
    if ($unique && metadata_exists('post', $id, $key)) return false;
    $GLOBALS['meta'][$id][$key] = $value;
    return true;
}
function rest_ensure_response($d) { return $d; }
function current_user_can($c) { return $c === 'manage_options'; }
class WPDBStub
{
    public $postmeta = 'wp_postmeta';
    public function prepare($q, ...$args) { return array($q, $args); }
    public function esc_like($s) { return $s; }
    public function get_var($prepared)
    {
        list(, $args) = $prepared;
        $id = $args[0];
        $count = 0;
        foreach (($GLOBALS['meta'][$id] ?? array()) as $k => $_) {
            if (strpos($k, '_huhs_checkin_entry_') === 0) $count++;
        }
        return $count;
    }
}
$wpdb = new WPDBStub();

require_once $argv[1] . '/includes/event-checkin.php';

$failures = 0;
$checks = 0;
function check($label, $ok, $detail = '')
{
    global $failures, $checks;
    $checks++;
    if (!$ok) $failures++;
    echo ($ok ? 'OK    ' : 'HIBA  ') . $label . ($detail !== '' ? " — $detail" : '') . "\n";
}
function ts($s) { return (new DateTimeImmutable($s, new DateTimeZone('Europe/Budapest')))->getTimestamp(); }

// 1) időablak
$w = huhs_checkin_window_from('2026-11-21', '22:00', '2026-11-22', '05:00');
check('a becsekkolás a kezdés előtt 1 órával nyílik', $w['opens'] === ts('2026-11-21 21:00'));
check('a becsekkolás a buli végén zár', $w['closes'] === ts('2026-11-22 05:00'));
$w2 = huhs_checkin_window_from('2026-11-21', '22:00', '', '');
check('záró idő nélkül a kezdéstől 10 óráig tart', $w2['closes'] === ts('2026-11-22 08:00'));
$w3 = huhs_checkin_window_from('2026-11-21', '22:00', '', '05:00');
check('záró dátum nélkül a 22:00 → 05:00 buli az éjfél utáni nap', $w3['closes'] === ts('2026-11-22 05:00'));
$w4 = huhs_checkin_window_from('', '22:00', '', '');
check('kezdő dátum nélkül nincs ablak (nem nyílik meg)', $w4['opens'] === 0 && huhs_checkin_state($w4, ts('2026-11-21 23:00')) === 'unknown');
check('az állapot: előtte / nyitva / után',
    huhs_checkin_state($w, ts('2026-11-21 20:59')) === 'before'
    && huhs_checkin_state($w, ts('2026-11-21 21:00')) === 'open'
    && huhs_checkin_state($w, ts('2026-11-22 05:00')) === 'open'
    && huhs_checkin_state($w, ts('2026-11-22 05:01')) === 'closed');

// 4) időbeosztás
$rows = huhs_parse_event_timetable("22:00 - 23:30 | Denoiser\n23:30 Adam Bass\n\nCsak név\n | \n");
check('az időbeosztás két alakot ért, a hibás sort kihagyja',
    count($rows) === 3 && $rows[0]['artist'] === 'Denoiser' && $rows[0]['time'] === '22:00 - 23:30'
    && $rows[1]['time'] === '23:30' && $rows[1]['artist'] === 'Adam Bass' && $rows[2]['time'] === '',
    json_encode($rows));
check('legfeljebb 40 sor', count(huhs_parse_event_timetable(implode("\n", array_fill(0, 60, '22:00 | X')))) === 40);

// 5) a nyilvános mezők nem adják ki a kódot
$event_id = 12992;
$code = huhs_event_checkin_code($event_id, true);
$public = json_encode(huhs_event_checkin_public_fields($event_id));
check('a nyilvános mezők nem tartalmazzák a titkos kódot', strpos($public, $code) === false && $code !== '', $public);
check('a QR-link a saját domainre mutat', huhs_event_checkin_url($event_id, $code) === "https://hungarianhardstyle.hu/checkin/$event_id/$code");

// 2) a kapu (a végpont a valódi `time()`-ot használja; az eseményt a MOSTANI időhöz igazítjuk)
$now = time();
update_post_meta($event_id, 'event_start_date', date('Y-m-d', $now - 1800));
update_post_meta($event_id, 'event_start_time', date('H:i', $now - 1800));
update_post_meta($event_id, 'event_end_date', date('Y-m-d', $now + 7200));
update_post_meta($event_id, 'event_end_time', date('H:i', $now + 7200));
$ok = huhs_event_checkin_api_record(new WP_REST_Request(array('code' => $code, 'uid' => 'user-A')));
check('érvényes kóddal, a buli alatt: sikeres becsekkolás', is_array($ok) && $ok['ok'] === true && $ok['alreadyCheckedIn'] === false, json_encode($ok));
$again = huhs_event_checkin_api_record(new WP_REST_Request(array('code' => $code, 'uid' => 'user-A')));
check('ugyanaz a fiók másodszor: alreadyCheckedIn (nincs dupla)', is_array($again) && $again['alreadyCheckedIn'] === true);
$other = huhs_event_checkin_api_record(new WP_REST_Request(array('code' => $code, 'uid' => 'user-B')));
check('másik fiók külön becsekkolhat, a létszám 2', is_array($other) && $other['count'] === 2, json_encode($other));
$bad = huhs_event_checkin_api_record(new WP_REST_Request(array('code' => 'rossz-kod', 'uid' => 'user-C')));
check('rossz kód: 403', $bad instanceof WP_Error && $bad->data['status'] === 403);
$empty = huhs_event_checkin_api_record(new WP_REST_Request(array('code' => $code, 'uid' => '')));
check('UID nélkül: 400', $empty instanceof WP_Error && $empty->data['status'] === 400);

$stored = json_encode($GLOBALS['meta'][$event_id]);
check('a WordPress NEM tárolja a UID-t (csak sózott ujjlenyomatot)', strpos($stored, 'user-A') === false && strpos($stored, 'user-B') === false);

// a 0-s időbélyeg csapda: a sor LÉTEZÉSE dönt
$key = HUHS_CHECKIN_META_PREFIX . huhs_checkin_player_hash($event_id, 'user-A');
$GLOBALS['meta'][$event_id][$key] = 0;
$zero = huhs_event_checkin_api_record(new WP_REST_Request(array('code' => $code, 'uid' => 'user-A')));
check('akkor is „már becsekkolt", ha a tárolt érték 0 (metadata_exists)', is_array($zero) && $zero['alreadyCheckedIn'] === true);

// ablakon kívül
update_post_meta($event_id, 'event_start_date', date('Y-m-d', $now + 86400 * 3));
update_post_meta($event_id, 'event_end_date', date('Y-m-d', $now + 86400 * 3));
$early = huhs_event_checkin_api_record(new WP_REST_Request(array('code' => $code, 'uid' => 'user-D')));
check('a buli előtt (több nappal): 403 és `before`', $early instanceof WP_Error && $early->data['status'] === 403 && ($early->data['state'] ?? '') === 'before');
update_post_meta($event_id, 'event_start_date', date('Y-m-d', $now - 86400 * 3));
update_post_meta($event_id, 'event_end_date', date('Y-m-d', $now - 86400 * 3));
$late = huhs_event_checkin_api_record(new WP_REST_Request(array('code' => $code, 'uid' => 'user-E')));
check('a buli után: 403 és `closed` (lefotózott QR nem használható)', $late instanceof WP_Error && ($late->data['state'] ?? '') === 'closed');

// új kód érvényteleníti a régit
$regen = huhs_event_checkin_code($event_id, true, true);
update_post_meta($event_id, 'event_start_date', date('Y-m-d', $now));
update_post_meta($event_id, 'event_end_date', date('Y-m-d', $now + 86400));
update_post_meta($event_id, 'event_start_time', '00:00');
update_post_meta($event_id, 'event_end_time', '23:59');
check('az újragenerált kód különbözik', $regen !== '' && $regen !== $code);
$old = huhs_event_checkin_api_record(new WP_REST_Request(array('code' => $code, 'uid' => 'user-F')));
check('a régi kód érvénytelen az újragenerálás után: 403', $old instanceof WP_Error && $old->data['status'] === 403);

echo "\n" . ($checks - $failures) . "/$checks ellenőrzés rendben\n";
if ($failures === 0) echo "EVENT-CHECKIN OK\n";
exit($failures === 0 ? 0 : 1);
