<?php
/**
 * A NYELVENKÉNTI ESEMÉNY-EMLÉKEZTETŐ bizonyítása (plugin 2.14.6) — valódi PHP,
 * WordPress nélkül, saját stubokkal.
 *
 * MIT MÉR:
 *   1. `huhs_push_normalize_language` — ismeretlen/hiányzó érték magyar marad
 *      (a régi kliensek nem némulnak el), az `en*` angol;
 *   2. `huhs_push_recipients(..., $language)` — a nyelvi szűrő a beállítás-szűrők
 *      (`enabled`, `reminders`) MELLETT működik, nem helyettük;
 *   3. `huhs_push_event_start_timestamp` — a helyi falióra **valódi** epochot ad
 *      (nyáron +2 óra): a régi `strtotime`-alapú számítás 01:00-nak hitte a
 *      23:00-s eseményt;
 *   4. `huhs_push_event_reminder_texts` — magyar ÉS angol szöveg, a törzsben a
 *      **dátummal és a helyszínnel**.
 *
 * Futtatás (a konténerben, a kibontott csomagon):
 *   php tools/verify-push-language.php /work/tmp/php-plugin/huhs-mobile-api
 *
 * Kilépési kód: 0 = minden rendben, 1 = eltérés.
 */

define('ABSPATH', __DIR__);

// ⚠️ MÉRT HIBA (2026-09-28): az ütemezés mérése először elhasalt, mert a
// WordPress idő-konstansai (`WEEK_IN_SECONDS` stb.) a stub-környezetben nem
// léteznek — a valódi WordPressben ezek a core-ban vannak. Ez a kapu fogta meg,
// ezért itt definiáljuk őket (a plugin forrását NEM írjuk át miattuk).
if (!defined('MINUTE_IN_SECONDS')) define('MINUTE_IN_SECONDS', 60);
if (!defined('HOUR_IN_SECONDS')) define('HOUR_IN_SECONDS', 3600);
if (!defined('DAY_IN_SECONDS')) define('DAY_IN_SECONDS', 86400);
if (!defined('WEEK_IN_SECONDS')) define('WEEK_IN_SECONDS', 604800);

// --- WordPress-stubok (csak ami ehhez a méréshez kell) ---------------------
$GLOBALS['huhs_meta'] = array();
$GLOBALS['huhs_titles'] = array();
// 2.14.7: az ÜTEMEZÉS és a biztonsági kör méréséhez — a `get_posts` a
// meta_query-t szándékosan NEM szűri (azt a lenti megjegyzés magyarázza).
$GLOBALS['huhs_scheduled'] = array();
$GLOBALS['huhs_posts'] = array();
$GLOBALS['huhs_kinds'] = array();

function add_action(...$args) { return true; }
function add_filter(...$args) { return true; }
function register_rest_route(...$args) { return true; }
// ⚠️ 2.14.8: a beállítások VALÓDI tárolót kapnak — a heti összefoglaló
// idempotenciáját („erre a hétre már kiment") csak így lehet mérni; a korábbi
// stub mindig az alapértéket adta vissza.
$GLOBALS['huhs_options'] = array();
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
function current_user_can($cap) { return $cap === 'manage_options'; }
function sanitize_text_field($value) { return trim(preg_replace('/[\r\n\t]+/', ' ', strip_tags((string) $value))); }
function sanitize_textarea_field($value) { return trim(strip_tags((string) $value)); }

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
}
class WP_REST_Response
{
    public $data;
    public $status;
    public function __construct($data = null, $status = 200)
    {
        $this->data = $data;
        $this->status = $status;
    }
    public function get_data() { return $this->data; }
    public function get_status() { return $this->status; }
}
class WP_REST_Request
{
    private $params;
    public function __construct($params = array()) { $this->params = $params; }
    public function get_json_params() { return $this->params; }
    public function get_param($key) { return $this->params[$key] ?? null; }
}
function get_post_meta($postId, $key, $single = false)
{
    return $GLOBALS['huhs_meta'][$postId][$key] ?? '';
}
function update_post_meta($postId, $key, $value) { $GLOBALS['huhs_meta'][$postId][$key] = $value; return true; }
function get_post($id)
{
    // 2.14.10: a `post_type` is kell a link-feloldáshoz, és a **nem létező**
    // azonosító `null`-t ad (mint a valódi WordPress) — a `huhs_missing_posts`
    // jelöli azokat az azonosítókat, amelyekről a teszt tudja, hogy nincsenek.
    if (!empty($GLOBALS['huhs_missing_posts'][(int) $id])) return null;
    return (object) array(
        'ID' => (int) $id,
        'post_status' => 'publish',
        'post_type' => $GLOBALS['huhs_post_types'][(int) $id] ?? 'post',
    );
}
function sanitize_title($value)
{
    $clean = strtolower(trim((string) $value));
    return preg_replace('/[^a-z0-9\-]/', '-', $clean);
}
function get_permalink($post) { return 'https://hungarianhardstyle.hu/t/' . $post->ID . '/'; }
function get_posts($args = array()) { return $GLOBALS['huhs_posts']; }
function wp_schedule_single_event($when, $hook, $args = array())
{
    $GLOBALS['huhs_scheduled'][] = array('when' => $when, 'hook' => $hook, 'args' => $args);
    return true;
}
function wp_next_scheduled(...$args) { return false; }
function get_the_title($post) { return $GLOBALS['huhs_titles'][$post->ID] ?? ''; }
function wp_timezone() { return new DateTimeZone('Europe/Budapest'); }
function wp_date($format, $timestamp = null, $timezone = null)
{
    // ⚠️ A VALÓDI `wp_date()` a **site időzónáját** használja, ha nincs megadva —
    // a stubnak is így kell viselkednie, különben a mérés hamis eltérést ad.
    $zone = $timezone instanceof DateTimeZone ? $timezone : wp_timezone();
    $moment = new DateTime('@' . (int) ($timestamp ?? time()));
    $moment->setTimezone($zone);
    return $moment->format($format);
}
function wp_strip_all_tags($value) { return strip_tags((string) $value); }
function sanitize_key($value)
{
    // ⚠️ A `huhs_push_event_reminder()` az ELSŐ lépésben a küldés fajtáját
    // sanitizálja, ezért ez a stub pontosan megmutatja, MELYIK ablak indult el —
    // a küldési lánc lefutása nélkül (a jelölőket a mérés előre beállítja).
    $GLOBALS['huhs_kinds'][] = (string) $value;
    return strtolower(preg_replace('/[^A-Za-z0-9_\-]/', '', (string) $value));
}
function current_time($type = 'mysql', $gmt = 0) { return date('Y-m-d H:i:s'); }

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

// --- 1) Nyelv-normalizálás -------------------------------------------------
check('en → en', huhs_push_normalize_language('en') === 'en');
check('EN → en (kis/nagybetű mindegy)', huhs_push_normalize_language('EN') === 'en');
check('en-GB → en', huhs_push_normalize_language('en-GB') === 'en');
check('en_US → en', huhs_push_normalize_language('en_US') === 'en');
check('hu → hu', huhs_push_normalize_language('hu') === 'hu');
check('üres → hu (régi kliens nem némul el)', huhs_push_normalize_language('') === 'hu');
check('ismeretlen (de) → hu', huhs_push_normalize_language('de') === 'hu');

// --- 2) Nyelvi szűrő a beállítások mellett --------------------------------
$tokens = array(
    'a' => array('token' => 'token-aaaaaaaaaaaaaaaaaaaa', 'language' => 'hu'),
    'b' => array('token' => 'token-bbbbbbbbbbbbbbbbbbbb', 'language' => 'en'),
    'c' => array('token' => 'token-cccccccccccccccccccc', 'language' => 'hu', 'enabled' => false),
    'd' => array('token' => 'token-dddddddddddddddddddd', 'language' => 'hu', 'reminders' => false),
    'e' => array('token' => 'token-eeeeeeeeeeeeeeeeeeee'),
);
$data = array('type' => 'event', 'kind' => 'reminder', 'id' => '12505');
$hu = huhs_push_recipients($tokens, $data, 'hu');
$en = huhs_push_recipients($tokens, $data, 'en');
$all = huhs_push_recipients($tokens, $data, '');
check('magyar kör: a magyar ÉS a nyelv nélküli (régi kliens) engedélyezett eszközök', array_keys($hu) === array('a', 'e'), implode(',', array_keys($hu)));
check('angol kör: csak az angol eszköz', array_keys($en) === array('b'), implode(',', array_keys($en)));
check('nyelv nélküli rekord magyarnak számít', isset($hu['e']) && !isset($en['e']));
check('nyelvi szűrő nélkül minden engedélyezett (kivéve reminders=false)', array_keys($all) === array('a', 'b', 'e'), implode(',', array_keys($all)));
check('a kikapcsolt értesítés a nyelvi körből is kimarad', !isset($hu['c']));

// --- 3) Az esemény kezdetének valódi időpontja ----------------------------
$post = (object) array('ID' => 12505);
$GLOBALS['huhs_meta'][12505] = array(
    'event_start_date' => '2026-10-17',
    'event_start_time' => '23:00',
    'venue_name' => 'Stenk',
    'venue_city' => 'Budapest',
);
$GLOBALS['huhs_titles'][12505] = 'Hard Base Classic';

$timestamp = huhs_push_event_start_timestamp($post);
check('a falióra a site időzónájában értelmeződik (CEST: 23:00 = 21:00 UTC)',
    gmdate('c', $timestamp) === '2026-10-17T21:00:00+00:00', gmdate('c', $timestamp));
check('a megjelenített helyi idő helyes', wp_date('Y.m.d. H:i', $timestamp, wp_timezone()) === '2026.10.17. 23:00',
    wp_date('Y.m.d. H:i', $timestamp, wp_timezone()));
check('a régi (strtotime) számítás MÁST adott — a javítás nem kozmetika',
    (int) strtotime('2026-10-17 23:00') !== $timestamp,
    (string) strtotime('2026-10-17 23:00') . ' vs ' . $timestamp);

// Téli időszámítás: 2026-12-05 23:00 = 22:00 UTC (CET).
$GLOBALS['huhs_meta'][12505]['event_start_date'] = '2026-12-05';
$winter = huhs_push_event_start_timestamp($post);
check('téli (CET) falióra is helyes (23:00 = 22:00 UTC)',
    gmdate('c', $winter) === '2026-12-05T22:00:00+00:00', gmdate('c', $winter));
$GLOBALS['huhs_meta'][12505]['event_start_date'] = '2026-10-17';

check('hiányzó dátum → 0', huhs_push_event_start_timestamp((object) array('ID' => 999)) === 0);

// --- 4) Az emlékeztető szövegei -------------------------------------------
$texts = huhs_push_event_reminder_texts($post, 'day_before');
check('magyar cím: „Esemény holnap"', ($texts['hu']['title'] ?? '') === 'Esemény holnap', $texts['hu']['title'] ?? '');
check('angol cím: „Event tomorrow"', ($texts['en']['title'] ?? '') === 'Event tomorrow', $texts['en']['title'] ?? '');
check('a magyar törzs tartalmazza a címet, a dátumot és a helyszínt',
    strpos($texts['hu']['body'], 'Hard Base Classic') === 0
    && strpos($texts['hu']['body'], '2026.10.17. 23:00') !== false
    && strpos($texts['hu']['body'], 'Stenk, Budapest') !== false,
    $texts['hu']['body']);
check('az angol törzs ugyanazokat a tényeket adja, angol dátumformával',
    strpos($texts['en']['body'], 'Oct 17, 23:00') !== false
    && strpos($texts['en']['body'], 'Stenk, Budapest') !== false,
    $texts['en']['body']);
check('mind a négy ablaknak megvan a magyar és az angol címe', (function () use ($post) {
    foreach (array('week', 'day_before', 'hours_before', 'two_hours') as $kind) {
        $text = huhs_push_event_reminder_texts($post, $kind);
        if (($text['hu']['title'] ?? '') === '' || ($text['en']['title'] ?? '') === '') return false;
    }
    return true;
})());

// Helyszín nélkül ne maradjon lógó elválasztó.
$GLOBALS['huhs_meta'][12505]['venue_name'] = '';
$GLOBALS['huhs_meta'][12505]['venue_city'] = '';
$noPlace = huhs_push_event_reminder_texts($post, 'hours_before');
check('helyszín nélkül csak a dátum marad (nincs lógó „·")',
    $noPlace['hu']['body'] === 'Hard Base Classic — 2026.10.17. 23:00', $noPlace['hu']['body']);

// --- 5) A NÉGY emlékeztető-ablak ütemezése (2.14.7) -----------------------
$GLOBALS['huhs_meta'][12505]['event_start_date'] = '2026-10-17';
$GLOBALS['huhs_meta'][12505]['event_start_time'] = '23:00';
$start = huhs_push_event_start_timestamp($post);
$GLOBALS['huhs_scheduled'] = array();
huhs_push_schedule_event_reminders($post);
$offsets = array();
foreach ($GLOBALS['huhs_scheduled'] as $entry) {
    if (($entry['hook'] ?? '') !== 'huhs_push_event_reminder') continue;
    $offsets[(string) ($entry['args'][1] ?? '')] = $start - (int) $entry['when'];
}
check('négy emlékeztetőt ütemez (week / day_before / hours_before / two_hours)',
    count($offsets) === 4
    && !array_diff(array('week', 'day_before', 'hours_before', 'two_hours'), array_keys($offsets)),
    implode(', ', array_keys($offsets)));
check('a 2 órás ablak PONTOSAN 2 órával előtte van', ($offsets['two_hours'] ?? 0) === 7200,
    (string) ($offsets['two_hours'] ?? 'nincs ilyen ablak'));
check('a 6 órás ablak pontosan 6 órával előtte van', ($offsets['hours_before'] ?? 0) === 21600,
    (string) ($offsets['hours_before'] ?? 'nincs'));
check('az 1 napos és az 1 hetes ablak változatlan',
    ($offsets['day_before'] ?? 0) === 86400 && ($offsets['week'] ?? 0) === 604800,
    ($offsets['day_before'] ?? '-') . ' / ' . ($offsets['week'] ?? '-'));

// --- 6) A biztonsági kör ugyanezt a négy ablakot nézi ---------------------
//
// ⚠️ A `get_posts` stub szándékosan NEM szűr a meta_query dátumára (az a szűrő a
// valódi WordPressben él), ezért itt az ABLAK-számítás a mért dolog: az esemény
// kezdetét állítjuk be, és azt mérjük, melyik ablak indul el.
function scanKinds($postId, $offsetSeconds)
{
    $target = time() + $offsetSeconds;
    $GLOBALS['huhs_meta'][$postId]['event_start_date'] = wp_date('Y-m-d', $target);
    $GLOBALS['huhs_meta'][$postId]['event_start_time'] = wp_date('H:i', $target);
    // A jelölők előre beállítva: a küldés nem indul el, de a `sanitize_key`
    // rögzíti az ablak nevét — pontosan ezt mérjük.
    foreach (array('week', 'day_before', 'hours_before', 'two_hours') as $kind) {
        $GLOBALS['huhs_meta'][$postId]['_huhs_push_reminder_sent_' . $kind] = '2026-01-01 00:00:00';
    }
    $GLOBALS['huhs_posts'] = array((object) array('ID' => $postId, 'post_status' => 'publish'));
    $GLOBALS['huhs_kinds'] = array();
    huhs_push_scan_event_reminders();
    return $GLOBALS['huhs_kinds'];
}

$inTwoHours = scanKinds(12505, 5400); // 1,5 óra múlva kezdődik
check('1,5 órával előtte a 2 ÓRÁS ablak indul (és semmi más)',
    $inTwoHours === array('two_hours'), implode(', ', $inTwoHours));
$inSixHours = scanKinds(12505, 5 * 3600 + 1800); // 5,5 óra múlva
check('5,5 órával előtte a 6 órás ablak indul (és semmi más)',
    $inSixHours === array('hours_before'), implode(', ', $inSixHours));
$betweenWindows = scanKinds(12505, 9000); // 2,5 óra múlva: a két ablak KÖZÖTT
check('a két ablak között (2,5 óra) EGYIK sem indul el',
    $betweenWindows === array(), implode(', ', $betweenWindows));
$lateWindow = scanKinds(12505, 2700); // 45 perc múlva: a 2 órás ablaka már lezárult
check('45 perccel előtte már egyik ablak sem indul (nincs késői küldés)',
    $lateWindow === array(), implode(', ', $lateWindow));

// --- 7) A 2 órás ablak szövege --------------------------------------------
$twoHours = huhs_push_event_reminder_texts($post, 'two_hours');
check('a 2 órás ablak magyar címe: „Esemény 2 óra múlva"',
    ($twoHours['hu']['title'] ?? '') === 'Esemény 2 óra múlva', $twoHours['hu']['title'] ?? '');
check('a 2 órás ablak angol címe: „Event in 2 hours"',
    ($twoHours['en']['title'] ?? '') === 'Event in 2 hours', $twoHours['en']['title'] ?? '');
check('a NÉGY ablak címe KÜLÖNBÖZŐ (nem ugyanaz a szöveg négy ablakon)', (function () use ($post) {
    $titles = array();
    foreach (array('week', 'day_before', 'hours_before', 'two_hours') as $kind) {
        $text = huhs_push_event_reminder_texts($post, $kind);
        $titles[] = $text['hu']['title'];
        $titles[] = $text['en']['title'];
    }
    return count(array_unique($titles)) === 8;
})());

// --- 8) HETI ÖSSZEFOGLALÓ minden eszközre (2.14.8) -------------------------
$pushSource = file_get_contents($pluginDir . '/includes/push.php');

$cleaned = huhs_push_digest_texts(array(
    'hu' => array('title' => 'Heti összefoglaló', 'body' => '2 új hír · 1 esemény'),
    'en' => array('title' => 'Weekly recap', 'body' => '2 new stories'),
    'de' => array('title' => 'Woche', 'body' => 'x'),
));
check('a szövegek csak a támogatott nyelvekre szűrődnek', array_keys($cleaned) === array('hu', 'en'), implode(',', array_keys($cleaned)));
check('hiányos pár (nincs törzs) kimarad', huhs_push_digest_texts(array('hu' => array('title' => 'Csak cím'))) === array());
check('üres payload → nincs küldhető szöveg', huhs_push_digest_texts(array()) === array());
$trimmed = huhs_push_digest_texts(array('hu' => array('title' => "<b>Cím</b>\n", 'body' => '<i>Törzs</i>')));
check('a címből kikerül a tördelés és a HTML', ($trimmed['hu']['title'] ?? '') === 'Cím', $trimmed['hu']['title'] ?? '');

$noWeek = huhs_push_weekly_digest(new WP_REST_Request(array('texts' => array('hu' => array('title' => 'A', 'body' => 'B')))));
check('hiányzó hét → hiba', $noWeek instanceof WP_Error && $noWeek->get_error_code() === 'invalid_week');
$noTexts = huhs_push_weekly_digest(new WP_REST_Request(array('week' => '2026-W40')));
check('nincs küldhető szöveg → hiba', $noTexts instanceof WP_Error && $noTexts->get_error_code() === 'invalid_texts');

// A célzás: nyelvenként, a beállítások tiszteletben tartásával.
$GLOBALS['huhs_options'][HUHS_PUSH_TOKENS_OPTION] = array(
    'a' => array('token' => str_repeat('a', 24), 'language' => 'hu'),
    'b' => array('token' => str_repeat('b', 24), 'language' => 'hu', 'digest' => false),
    'c' => array('token' => str_repeat('c', 24), 'language' => 'en'),
    'd' => array('token' => str_repeat('d', 24), 'language' => 'en', 'enabled' => false),
    'e' => array('token' => str_repeat('e', 24), 'language' => 'hu', 'reminders' => false),
);
$tokens = $GLOBALS['huhs_options'][HUHS_PUSH_TOKENS_OPTION];
$reach = huhs_push_digest_reach();
check('az elérés nyelvenként: hu 2, en 1', $reach['hu'] === 2 && $reach['en'] === 1 && $reach['total'] === 3, json_encode($reach));
check('aki kikapcsolta az értesítéseket, kimarad', count(huhs_push_recipients($tokens, array('type' => 'digest'), 'en')) === 1);
check('a `digest = false` kimarad a heti összefoglalóból', count(huhs_push_recipients($tokens, array('type' => 'digest'), 'hu')) === 2);
// ⚠️ A 2.14.8-ban javított hiba: a `reminders` kapu eddig MINDEN `kind`-os
// küldést szűrt — aki az emlékeztetőt kikapcsolta, a heti összefoglalót is
// elvesztette volna. Mostantól csak a `kind = reminder` esetén szűr.
check('a `reminders = false` NEM zárja ki a heti összefoglalót', count(huhs_push_recipients($tokens, array('type' => 'digest', 'kind' => 'digest'), '')) === 3);
check('a `reminders = false` KIZÁR az esemény-emlékeztetőből', count(huhs_push_recipients($tokens, array('type' => 'event', 'kind' => 'reminder'), '')) === 3);

$dryTexts = array(
    'hu' => array('title' => 'Heti összefoglaló', 'body' => '2 új hír · 1 esemény'),
    'en' => array('title' => 'Weekly recap', 'body' => '2 new stories · 1 upcoming event'),
);
$dry = huhs_push_weekly_digest(new WP_REST_Request(array('week' => '2026-W40', 'dry_run' => true, 'texts' => $dryTexts)));
$dryData = $dry instanceof WP_REST_Response ? $dry->get_data() : array();
check('száraz kör: nem küld, de megméri az elérést',
    ($dryData['dryRun'] ?? false) === true && ($dryData['sent'] ?? -1) === 0 && ($dryData['reach']['total'] ?? 0) === 3,
    json_encode($dryData));

$GLOBALS['huhs_options'][HUHS_PUSH_DIGEST_WEEK_OPTION] = '2026-W40';
$dup = huhs_push_weekly_digest(new WP_REST_Request(array('week' => '2026-W40', 'texts' => $dryTexts)));
$dupData = $dup instanceof WP_REST_Response ? $dup->get_data() : array();
check('ugyanarra a hétre nem megy ki kétszer', ($dupData['duplicate'] ?? false) === true && ($dupData['sent'] ?? -1) === 0, json_encode($dupData));

check('a végpont CSAK adminnak nyílik (nem nyilvános)',
    strpos($pushSource, "'/push/digest'") !== false
    && strpos($pushSource, "current_user_can('manage_options')") !== false,
    'a /push/digest route védelme');
check('a küldés a helyi, nyelvenkénti láncon megy ki',
    strpos($pushSource, 'huhs_push_send_localized($texts, array(') !== false);
check('a hét jelölése a küldés UTÁN íródik',
    strpos($pushSource, 'update_option(HUHS_PUSH_DIGEST_WEEK_OPTION') > strpos($pushSource, 'huhs_push_send_localized($texts'));
check('a beállítás-küldés ismeri a `digest` kapcsolót',
    strpos($pushSource, "'digest' => filter_var(\$params['digest'] ?? true") !== false);

// --- 9) KEDVENC-ALAPÚ CÉLZÁS (2.14.9) ---------------------------------------
$ids = huhs_push_favorite_ids(array(7, '12', 0, -3, 'abc', array('id' => 21), array('name' => 'x'), 7));
check('a kedvenc-azonosítók tisztítása (int, szöveg, objektum, ismétlődés nélkül)',
    $ids === array(7, 12, 21), json_encode($ids));
check('a plafon érvényes', count(huhs_push_favorite_ids(range(1, 200))) === 60);
check('a nem tömb bemenet üres listát ad', huhs_push_favorite_ids('nem-tomb') === array());

$GLOBALS['huhs_meta'][7001]['artists'] = json_encode(array(7, array('id' => 12)));
$GLOBALS['huhs_meta'][7001]['organizer_id'] = '3';
$targetsForContent = huhs_push_content_follow_targets((object) array('ID' => 7001));
check('a tartalom szereplői a MÉRT meta-kulcsokból jönnek',
    $targetsForContent['artists'] === array(7, 12) && $targetsForContent['organizers'] === array(3),
    json_encode($targetsForContent));
check('üres/meta nélküli tartalom: nincs célzás', huhs_push_content_follow_targets((object) array('ID' => 9999)) === array('artists' => array(), 'organizers' => array()));

// A szűrő: aki KÖVETI a tartalmat, bent marad; aki kedvel (mást), az kimarad;
// aki még nem küldött kedvenceket, az VÁLTOZATLANUL mindent megkap.
$GLOBALS['huhs_options'][HUHS_PUSH_TOKENS_OPTION] = array(
    'follows' => array('token' => str_repeat('f', 24), 'language' => 'hu', 'artists' => array(7)),
    'followsOrg' => array('token' => str_repeat('o', 24), 'language' => 'hu', 'organizers' => array(3)),
    'other' => array('token' => str_repeat('x', 24), 'language' => 'hu', 'artists' => array(99)),
    'legacy' => array('token' => str_repeat('l', 24), 'language' => 'hu'),
);
$favoriteTokens = $GLOBALS['huhs_options'][HUHS_PUSH_TOKENS_OPTION];
$releaseData = array('type' => 'release', 'id' => '7001') + $targetsForContent;
$targeted = array_keys(huhs_push_recipients($favoriteTokens, $releaseData, ''));
sort($targeted);
check('a követő DJ ÉS a követő szervező is megkapja a tartalmat',
    in_array('follows', $targeted, true) && in_array('followsOrg', $targeted, true), implode(',', $targeted));
check('aki MÁST kedvel, az kimarad (ez a személyes célzás lényege)',
    !in_array('other', $targeted, true), implode(',', $targeted));
check('aki még nem küldött kedvenceket, az továbbra is mindent megkap (visszafelé kompatibilis)',
    in_array('legacy', $targeted, true), implode(',', $targeted));
check('célzás nélküli küldés (nincs szereplő a payloadban) → mindenki',
    count(huhs_push_recipients($favoriteTokens, array('type' => 'release'), '')) === 4);
check('a heti összefoglalót a kedvencek NEM szűkítik',
    count(huhs_push_recipients($favoriteTokens, array('type' => 'digest', 'kind' => 'digest'), '')) === 4);

check('a tartalom-push átadja a szereplőket',
    strpos($pushSource, '$followers = huhs_push_content_follow_targets($post);') !== false
    && strpos($pushSource, ') + $followers);') !== false);
check('a beállítás-küldés tárolja a kedvenceket',
    strpos($pushSource, "'artists' => huhs_push_favorite_ids(\$params['artists']") !== false
    && strpos($pushSource, "'organizers' => huhs_push_favorite_ids(\$params['organizers']") !== false);

// --- 10) MEGOSZTOTT LINK FELOLDÁSA (2.14.10) --------------------------------
$GLOBALS['huhs_post_types'] = array(12505 => 'huhs_event', 12699 => 'huhs_release', 42 => 'huhs_artist', 777 => 'post', 888 => 'page');
// A 99999 NEM létezik — a stub innen tudja (a valódi `get_post()` null-t ad rá).
$GLOBALS['huhs_missing_posts'] = array(99999 => true);
$GLOBALS['huhs_titles'][12699] = 'Goze &amp; Change of Pace';
$resolve = function ($params) {
    return huhs_resolve_content_target(new WP_REST_Request($params));
};
$resolved = array();
foreach (array(12505, 12699, 42, 777) as $id) {
    $answer = $resolve(array('p' => $id));
    $resolved[$id] = $answer instanceof WP_REST_Response ? $answer->get_data() : array();
}
check('az esemény-azonosító eseményt ad',
    ($resolved[12505]['type'] ?? '') === 'event' && $resolved[12505]['id'] === 12505, json_encode($resolved[12505] ?? array()));
check('a kiadvány és a DJ is a saját típusát adja',
    ($resolved[12699]['type'] ?? '') === 'release' && ($resolved[42]['type'] ?? '') === 'artist');
check('a hír (`post`) hírként oldódik fel', ($resolved[777]['type'] ?? '') === 'news');
check('a cím HTML-feloldással jön (nem `&amp;`)',
    ($resolved[12699]['title'] ?? '') === 'Goze & Change of Pace', $resolved[12699]['title'] ?? '');
check('ismeretlen típus (page) nem oldódik fel', $resolve(array('p' => 888)) instanceof WP_Error);
check('ismeretlen azonosító 404-es hiba', (function () use ($resolve) {
    $answer = $resolve(array('p' => 99999));
    return $answer instanceof WP_Error && $answer->get_error_code() === 'not_found';
})());

// Slug-alapú feloldás (a szép permalinkhez): a `get_posts` stub adja a találatot.
$GLOBALS['huhs_posts'] = array((object) array('ID' => 12505, 'post_status' => 'publish', 'post_type' => 'huhs_event'));
$bySlug = $resolve(array('slug' => 'hard-base-classic'));
check('a slugból is megvan a típus és az azonosító',
    ($bySlug instanceof WP_REST_Response) && ($bySlug->get_data()['id'] ?? 0) === 12505 && ($bySlug->get_data()['type'] ?? '') === 'event');
$GLOBALS['huhs_posts'] = array();
check('nem létező slug → 404', $resolve(array('slug' => 'nincs-ilyen')) instanceof WP_Error);
check('a feloldó végpont nyilvános, de CSAK OLVAS',
    strpos($pushSource, "'/resolve'") !== false
    && strpos($pushSource, "'methods' => 'GET',\n        'callback' => 'huhs_resolve_content_target'") !== false);

// --- Összegzés -------------------------------------------------------------
$ok = $failures === 0;
echo "\n{$checks} ellenőrzés, {$failures} hiba\n";
if ($ok) echo "PUSH-NYELV OK\n";
exit($ok ? 0 : 1);
