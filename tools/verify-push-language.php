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
function get_option($name, $default = false) { return $default; }
function update_option(...$args) { return true; }
function delete_option(...$args) { return true; }
function get_post_meta($postId, $key, $single = false)
{
    return $GLOBALS['huhs_meta'][$postId][$key] ?? '';
}
function update_post_meta($postId, $key, $value) { $GLOBALS['huhs_meta'][$postId][$key] = $value; return true; }
function get_post($id) { return (object) array('ID' => (int) $id, 'post_status' => 'publish'); }
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

// --- Összegzés -------------------------------------------------------------
$ok = $failures === 0;
echo "\n{$checks} ellenőrzés, {$failures} hiba\n";
if ($ok) echo "PUSH-NYELV OK\n";
exit($ok ? 0 : 1);
