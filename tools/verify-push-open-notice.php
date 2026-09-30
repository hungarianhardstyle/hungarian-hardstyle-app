<?php
/**
 * A SZAVAZÁS/JÁTÉK „kinyílt" ÉRTESÍTÉS bizonyítása (plugin 2.14.11) — valódi PHP,
 * WordPress nélkül, saját stubokkal.
 *
 * MIT MÉR (nem forrás-lint, hanem **lefutó** kód):
 *   1. a négy időablakos típus EGY térképe (`huhs_push_open_notice_types`):
 *      kérdőív, nyereményjáték, éves szavazás, GYÍK-játék — mindegyikhez
 *      payload, kezdés/zárás meta, beállítás-kulcs és magyar+angol cím;
 *   2. a nyitás pillanata: a tárolt **helyi** falióra (`Y-m-d\TH:i`) valódi
 *      epochot ad (nyáron +2 óra) — ugyanaz a buktató, mint a 2.14.6-os
 *      esemény-emlékeztetőnél;
 *   3. a **frissességi kapu**: a 2.14.11 feltöltésekor a régen kinyílt tartalom
 *      NEM hirdethető meg (különben egy fél éve lezárt kérdőívre is elmenne);
 *   4. a küldés **teljes lánca** stubolt FCM-mel: magyar eszköz magyar szöveget,
 *      angol eszköz angolt kap, a törzsben a kérdéssel és a zárás idejével;
 *   5. idempotencia: ugyanarra az időablakra EGYSZER megy ki (jelölő), viszont
 *      egy új időablak új hirdetés;
 *   6. a beállítás-kapuk (`polls` / `games` / `votes`) csak akkor szűkítenek, ha
 *      a kliens küldi őket — a mai kliensek nem némulnak el;
 *   7. az ütemezés: jövőbeli nyitás a nyitás pillanatára, már nyitott tartalom
 *      azonnalira, ismételt mentés nem ütemez kétszer.
 *
 * Futtatás (a konténerben, a kibontott csomagon):
 *   php tools/verify-push-open-notice.php /work/tmp/php-plugin/huhs-mobile-api
 *
 * Kilépési kód: 0 = minden rendben, 1 = eltérés.
 */

define('ABSPATH', __DIR__);

// A stubolt WordPress-környezet nem tudja fogni a curl-t, ezért a küldés a
// soros úton megy (a pluginban erre van a kifejezett teszt-kapcsoló).
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
function sanitize_key($value) { return strtolower(preg_replace('/[^A-Za-z0-9_\-]/', '', (string) $value)); }
function esc_url_raw($value) { return trim((string) $value); }
function get_the_title($post) { return $GLOBALS['huhs_titles'][$post->ID] ?? ''; }
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
        if ($type === '' || (string) $post->post_type === $type) $out[] = $post;
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
/**
 * A VALÓDI `wp_next_scheduled` a hook+argumentum párosra keres — a stub is így
 * tesz, különben a „nem ütemezünk kétszer" állítás nem lenne mérhető.
 */
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

/**
 * A hálózat stubja: MINDEN `wp_remote_post` itt landol, és a kéréseket
 * rögzítjük — így a küldés szövege, célnyelve és adatcsomagja mérhető.
 */
function wp_remote_post($url, $args = array())
{
    $body = $args['body'] ?? '';
    $GLOBALS['huhs_remote'][] = array('url' => (string) $url, 'body' => $body, 'headers' => $args['headers'] ?? array());
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

/** A rögzített FCM-kérésekből a notification cím/törzs és az adatcsomag. */
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
    $GLOBALS['huhs_options']['huhs_push_last_result'] = array();
}

/** Egy tartalom felvétele a stub-tárba (publikált, adott típussal). */
function seed_post($id, $post_type, $title, $meta = array(), $status = 'publish', $published_at = null)
{
    $GLOBALS['huhs_post_types'][$id] = $post_type;
    $GLOBALS['huhs_post_status'][$id] = $status;
    $GLOBALS['huhs_titles'][$id] = $title;
    $GLOBALS['huhs_publish_time'][$id] = $published_at ?? time();
    foreach ($meta as $key => $value) $GLOBALS['huhs_meta'][$id][$key] = $value;
    $GLOBALS['huhs_posts'][] = (object) array('ID' => $id, 'post_type' => $post_type, 'post_status' => $status);
}

/** Helyi falióra-érték (`Y-m-d\TH:i`) egy eltolással a mostani időhöz képest. */
function local_clock($offset_seconds)
{
    return wp_date('Y-m-d\TH:i', time() + (int) $offset_seconds);
}

// --- 0) A küldési lánc előfeltételei (stubolt FCM) --------------------------
$GLOBALS['huhs_options'][HUHS_PUSH_SERVICE_ACCOUNT_OPTION] = array(
    'project_id' => 'hungarian-hardstyle',
    'client_email' => 'push@hungarian-hardstyle.iam.gserviceaccount.com',
    'private_key' => 'stub',
);
// A hozzáférési token a gyorsítótárból jön — így az OAuth-kör nem kell a méréshez.
$GLOBALS['huhs_transients']['huhs_firebase_access_token'] = 'stub-access-token';
$GLOBALS['huhs_options'][HUHS_PUSH_TOKENS_OPTION] = array(
    'hu-1' => array('token' => 'token-hu-aaaaaaaaaaaaaaaa', 'language' => 'hu'),
    'en-1' => array('token' => 'token-en-bbbbbbbbbbbbbbbb', 'language' => 'en'),
);

// --- 1) A térkép: négy időablakos típus, egy helyen -------------------------
$types = huhs_push_open_notice_types();
check('négy időablakos típus van (kérdőív, nyereményjáték, szavazás, játék)', count($types) === 4, (string) count($types));
$expected_types = array('huhs_poll', 'huhs_prize', 'huhs_vote_season', 'huhs_game');
check('mind a négy várt post_type szerepel', array_keys($types) === $expected_types, implode(',', array_keys($types)));
$payloads = array();
foreach ($types as $config) $payloads[] = (string) ($config['payload'] ?? '');
check('a payload-típusok pontosan poll/game/vote/quiz', $payloads === array('poll', 'game', 'vote', 'quiz'), implode(',', $payloads));
$missing_parts = array();
foreach ($types as $type => $config) {
    foreach (array('payload', 'start', 'end', 'setting') as $field) {
        if (empty($config[$field])) $missing_parts[] = $type . '.' . $field;
    }
    foreach (array('hu', 'en') as $language) {
        if (empty($config['texts'][$language])) $missing_parts[] = $type . '.' . $language;
    }
    if (($config['texts']['hu'] ?? '') === ($config['texts']['en'] ?? '')) $missing_parts[] = $type . '.fordítás';
}
check('minden típushoz tartozik payload, kezdés, zárás, beállítás és KÉT nyelvű cím', $missing_parts === array(), implode(',', $missing_parts));
check('a GYÍK-játék dátum nélkül nem hirdethető (a `huhs_game_status` így `draft`)',
    !empty($types['huhs_game']['needs_dates']) && empty($types['huhs_poll']['needs_dates']));
check('a szavazás a szezon kapcsolóját nézi', ($types['huhs_vote_season']['enabled'] ?? '') === '_huhs_vote_enabled');

// --- 2) A nyitás pillanata (helyi falióra → valódi epoch) -------------------
$summer = huhs_push_meta_timestamp(1, '_stub');
$GLOBALS['huhs_meta'][1]['_stub'] = '2026-10-17T23:00';
check('nyári idő: 2026-10-17 23:00 helyi = 21:00Z', huhs_push_meta_timestamp(1, '_stub') === strtotime('2026-10-17 21:00:00 UTC'),
    (string) huhs_push_meta_timestamp(1, '_stub'));
$GLOBALS['huhs_meta'][1]['_stub'] = '2026-12-05T23:00';
check('téli idő: 2026-12-05 23:00 helyi = 22:00Z', huhs_push_meta_timestamp(1, '_stub') === strtotime('2026-12-05 22:00:00 UTC'),
    (string) huhs_push_meta_timestamp(1, '_stub'));
$GLOBALS['huhs_meta'][1]['_stub'] = '';
check('üres dátum → 0 (nyitott határ)', huhs_push_meta_timestamp(1, '_stub') === 0);
$GLOBALS['huhs_meta'][1]['_stub'] = 'nem-datum';
check('értelmezhetetlen dátum → 0 (nem tippelünk)', huhs_push_meta_timestamp(1, '_stub') === 0);
unset($GLOBALS['huhs_meta'][1]);

seed_post(101, 'huhs_poll', 'Kedvenc fellépőd?', array(), 'publish', time() - 3600);
check('kezdés nélkül a KÖZZÉTÉTEL a nyitás pillanata',
    huhs_push_open_moment(get_post(101), $types['huhs_poll']) === (int) $GLOBALS['huhs_publish_time'][101]);
seed_post(102, 'huhs_game', 'GYÍK kvíz', array(), 'publish', time() - 3600);
check('dátum nélküli játéknál nincs nyitás (nem is aktív)',
    huhs_push_open_moment(get_post(102), $types['huhs_game']) === 0);
$GLOBALS['huhs_meta'][102]['_huhs_game_start'] = local_clock(-600);
check('dátummal a kezdés a nyitás', huhs_push_open_moment(get_post(102), $types['huhs_game']) > 0);

// --- 3) Kapcsolók -----------------------------------------------------------
$GLOBALS['huhs_meta'][103]['_huhs_vote_enabled'] = '1';
seed_post(103, 'huhs_vote_season', 'Éves szavazás 2026');
check('bekapcsolt szezon → engedett', huhs_push_open_enabled(get_post(103), $types['huhs_vote_season']) === true);
$GLOBALS['huhs_meta'][103]['_huhs_vote_enabled'] = '0';
check('kikapcsolt szezon → NEM engedett', huhs_push_open_enabled(get_post(103), $types['huhs_vote_season']) === false);
check('kapcsoló nélküli típus mindig engedett', huhs_push_open_enabled(get_post(101), $types['huhs_poll']) === true);

// --- 4) Ujjlenyomat: egy időablak egyszer hirdethető ------------------------
$GLOBALS['huhs_meta'][101]['_huhs_poll_start'] = '2026-10-01T10:00';
$first = huhs_push_open_fingerprint(get_post(101), $types['huhs_poll']);
check('ugyanaz az időablak ugyanaz az ujjlenyomat', $first === huhs_push_open_fingerprint(get_post(101), $types['huhs_poll']));
$GLOBALS['huhs_titles'][101] = 'Kedvenc fellépőd? (javított helyesírás)';
check('a szövegjavítás NEM ad új hirdetést', $first === huhs_push_open_fingerprint(get_post(101), $types['huhs_poll']));
$GLOBALS['huhs_meta'][101]['_huhs_poll_start'] = '2026-11-01T10:00';
check('az ÚJ időablak új hirdetést ad', $first !== huhs_push_open_fingerprint(get_post(101), $types['huhs_poll']));

// --- 5) A küldés TELJES lánca (stubolt FCM) ---------------------------------
// Frissen kinyílt kérdőív: 30 perccel ezelőtt nyílt, 2 nap múlva zárul.
seed_post(201, 'huhs_poll', 'Melyik a kedvenc stílusod?', array(
    '_huhs_poll_start' => local_clock(-1800),
    '_huhs_poll_end' => local_clock(2 * DAY_IN_SECONDS),
    '_huhs_poll_question' => 'Melyik a kedvenc stílusod?',
));
reset_send_state();
huhs_push_open_notice(201, 'huhs_poll');
$messages = sent_messages();
check('frissen kinyílt kérdőív → kimegy az értesítés', count($messages) === 2, (string) count($messages));
$by_token = array();
foreach ($messages as $message) $by_token[$message['token']] = $message;
$hungarian = $by_token['token-hu-aaaaaaaaaaaaaaaa'] ?? array();
$english = $by_token['token-en-bbbbbbbbbbbbbbbb'] ?? array();
check('a magyar eszköz magyar címet kap', ($hungarian['title'] ?? '') === 'Elindult a kérdőív', $hungarian['title'] ?? '');
check('az angol eszköz ANGOL címet kap', ($english['title'] ?? '') === 'The new poll is open', $english['title'] ?? '');
check('a törzs a kérdés', ($hungarian['body'] ?? '') === 'Melyik a kedvenc stílusod? · eddig: ' . wp_date('Y.m.d. H:i', huhs_push_meta_timestamp(201, '_huhs_poll_end')),
    $hungarian['body'] ?? '');
check('a törzsben ott a ZÁRÁS ideje (helyi időzónában)',
    strpos((string) ($hungarian['body'] ?? ''), wp_date('Y.m.d. H:i', huhs_push_meta_timestamp(201, '_huhs_poll_end'))) !== false);
check('az angol törzs az `until` szót használja', strpos((string) ($english['body'] ?? ''), 'until ') !== false, $english['body'] ?? '');
$data = $hungarian['data'] ?? array();
check('az adatcsomag típusa `poll` és `kind=open`',
    ($data['type'] ?? '') === 'poll' && ($data['kind'] ?? '') === 'open' && ($data['id'] ?? '') === '201', json_encode($data));
check('a jelölő beíródott (idempotencia alapja)',
    get_post_meta(201, '_huhs_push_open_sent', true) === huhs_push_open_fingerprint(get_post(201), $types['huhs_poll']));

reset_send_state();
huhs_push_open_notice(201, 'huhs_poll');
check('MÁSODSZOR ugyanarra az ablakra nem megy ki (nincs új FCM-hívás)', count(sent_messages()) === 0, (string) count(sent_messages()));

// ⚠️ A LEGFONTOSABB KOCKÁZAT: a 2.14.11 feltöltésekor a RÉGI tartalom nem hirdethető meg.
seed_post(202, 'huhs_prize', 'Nyereményjáték: fesztiválbelépő', array(
    '_huhs_prize_start' => local_clock(-7 * HOUR_IN_SECONDS),
    '_huhs_prize_end' => local_clock(-2 * HOUR_IN_SECONDS),
    '_huhs_prize_question' => 'Melyik évben alakult a zenekar?',
));
reset_send_state();
huhs_push_open_notice(202, 'huhs_prize');
check('7 órával ezelőtt kinyílt (már lezárt) játék → NEM megy ki (frissességi kapu)',
    count(sent_messages()) === 0, (string) count(sent_messages()));
check('a frissességi kapu a küldés előtt dönt (nincs jelölő sem)',
    get_post_meta(202, '_huhs_push_open_sent', true) === '');

seed_post(203, 'huhs_prize', 'Nyereményjáték: következő hónap', array(
    '_huhs_prize_start' => local_clock(3 * DAY_IN_SECONDS),
    '_huhs_prize_end' => local_clock(10 * DAY_IN_SECONDS),
));
reset_send_state();
huhs_push_open_notice(203, 'huhs_prize');
check('jövőbeli nyitás → most NEM megy ki', count(sent_messages()) === 0, (string) count(sent_messages()));

seed_post(204, 'huhs_poll', 'Vázlat kérdőív', array('_huhs_poll_start' => local_clock(-600)), 'draft');
reset_send_state();
huhs_push_open_notice(204, 'huhs_poll');
check('nem publikált tartalom → nem megy ki', count(sent_messages()) === 0, (string) count(sent_messages()));

seed_post(205, 'huhs_vote_season', 'Éves szavazás 2026', array(
    '_huhs_vote_start' => local_clock(-600),
    '_huhs_vote_enabled' => '0',
));
reset_send_state();
huhs_push_open_notice(205, 'huhs_vote_season');
check('kikapcsolt szezon → nem megy ki', count(sent_messages()) === 0, (string) count(sent_messages()));
$GLOBALS['huhs_meta'][205]['_huhs_vote_enabled'] = '1';
huhs_push_open_notice(205, 'huhs_vote_season');
$vote_messages = sent_messages();
check('bekapcsolt szezon → kimegy, `vote` típussal',
    count($vote_messages) === 2 && (($vote_messages[0]['data']['type'] ?? '') === 'vote'), (string) count($vote_messages));

// A GYÍK-játék (másik payload, ugyanaz a lánc).
seed_post(206, 'huhs_game', 'GYÍK: találd ki a tracket', array(
    '_huhs_game_start' => local_clock(-900),
    '_huhs_game_end' => local_clock(4 * HOUR_IN_SECONDS),
));
reset_send_state();
huhs_push_open_notice(206, 'huhs_game');
$game_messages = sent_messages();
check('frissen kinyílt játék → kimegy, `quiz` típussal',
    count($game_messages) === 2 && (($game_messages[0]['data']['type'] ?? '') === 'quiz'), (string) count($game_messages));

// --- 6) Beállítás-kapuk (visszafelé kompatibilis) ---------------------------
$gated = array(
    'off' => array('token' => 'token-off-cccccccccccccc', 'language' => 'hu', 'polls' => false, 'games' => false, 'votes' => false),
    'on' => array('token' => 'token-on-dddddddddddddd', 'language' => 'hu', 'polls' => true, 'games' => true, 'votes' => true),
);
$GLOBALS['huhs_options'][HUHS_PUSH_TOKENS_OPTION] = $gated;
check('kikapcsolt `polls` eszköz kimarad a kérdőív-pushból',
    count(huhs_push_recipients($gated, array('type' => 'poll'), '')) === 1);
check('kikapcsolt `games` eszköz kimarad a játék-pushból',
    count(huhs_push_recipients($gated, array('type' => 'game'), '')) === 1
    && count(huhs_push_recipients($gated, array('type' => 'quiz'), '')) === 1);
check('kikapcsolt `votes` eszköz kimarad a szavazás-pushból',
    count(huhs_push_recipients($gated, array('type' => 'vote'), '')) === 1);
$legacy = array(
    'legacy-1' => array('token' => 'token-legacy-eeeeeeeeee', 'language' => 'hu'),
    'legacy-2' => array('token' => 'token-legacy-ffffffffffff', 'language' => 'en'),
);
check('aki még nem küldött ilyen kapcsolót (minden mai kliens), az VÁLTOZATLANUL megkapja',
    count(huhs_push_recipients($legacy, array('type' => 'poll'), '')) === 2
    && count(huhs_push_recipients($legacy, array('type' => 'quiz'), '')) === 2);
$disabled = array('x' => array('token' => 'token-x-gggggggggggggg', 'language' => 'hu', 'enabled' => false));
check('a fő kapcsoló (`enabled = false`) továbbra is kizár',
    count(huhs_push_recipients($disabled, array('type' => 'poll'), '')) === 0);
$GLOBALS['huhs_options'][HUHS_PUSH_TOKENS_OPTION] = array(
    'hu-1' => array('token' => 'token-hu-aaaaaaaaaaaaaaaa', 'language' => 'hu'),
    'en-1' => array('token' => 'token-en-bbbbbbbbbbbbbbbb', 'language' => 'en'),
);

// --- 7) Ütemezés ------------------------------------------------------------
$GLOBALS['huhs_scheduled'] = array();
$GLOBALS['huhs_cron_events'] = array();
seed_post(301, 'huhs_prize', 'Jövő havi játék', array(
    '_huhs_prize_start' => local_clock(3 * DAY_IN_SECONDS),
    '_huhs_prize_end' => local_clock(10 * DAY_IN_SECONDS),
));
$scheduled_open = huhs_push_schedule_open_notice(get_post(301));
$open_moment = huhs_push_meta_timestamp(301, '_huhs_prize_start');
$scheduled_entry = $GLOBALS['huhs_scheduled'][0] ?? array();
check('jövőbeli nyitás → ütemezve a NYITÁS pillanatára',
    $scheduled_open === true && ($scheduled_entry['hook'] ?? '') === 'huhs_push_open_notice'
    && (int) ($scheduled_entry['when'] ?? 0) === $open_moment,
    json_encode($scheduled_entry));
check('a jövőbeli nyitás NEM indít azonnali cron-kört', (int) ($GLOBALS['huhs_spawned'] ?? 0) === 0);
$GLOBALS['huhs_scheduled'] = array();
check('ismételt mentés nem ütemez kétszer', huhs_push_schedule_open_notice(get_post(301)) === true
    && count($GLOBALS['huhs_scheduled']) === 0);

$GLOBALS['huhs_spawned'] = 0;
seed_post(302, 'huhs_poll', 'Most nyílt kérdőív', array('_huhs_poll_start' => local_clock(-60)));
$immediate = huhs_push_schedule_open_notice(get_post(302));
$immediate_entry = $GLOBALS['huhs_cron_events'][count($GLOBALS['huhs_cron_events']) - 1] ?? array();
check('már nyitott tartalom → azonnali (1 másodperc) ütemezés',
    $immediate === true && (int) ($immediate_entry['when'] ?? 0) <= time() + 2
    && (int) ($immediate_entry['when'] ?? 0) > time() - 2, json_encode($immediate_entry));
check('és el is indul a cron-kör (a szerkesztő nem várja meg az FCM-köröket)',
    (int) ($GLOBALS['huhs_spawned'] ?? 0) === 1);

$GLOBALS['huhs_scheduled'] = array();
seed_post(303, 'huhs_prize', 'Régi játék', array('_huhs_prize_start' => local_clock(-9 * HOUR_IN_SECONDS)));
check('régen kinyílt tartalomra nem ütemezünk (nincs utólagos hirdetés)',
    huhs_push_schedule_open_notice(get_post(303)) === false && count($GLOBALS['huhs_scheduled']) === 0);

$GLOBALS['huhs_scheduled'] = array();
seed_post(304, 'huhs_poll', 'Vázlat', array(), 'draft');
check('vázlatra nem ütemezünk', huhs_push_schedule_open_notice(get_post(304)) === false);

// --- 8) A biztonsági kör ----------------------------------------------------
// ⚠️ MÉRT HIBA A KÖRBEN: elsőre 6 üzenet jött 2 helyett, mert a stub `get_posts`
// a KORÁBBI szakaszokban felvett összes posztot visszaadta — a kör tehát nem az
// egyetlen frissen kinyílt tartalmat mérte. A mérés ezért izolált: csak a
// vizsgált poszt van a tárban. (A kapu jó volt: a számlálás bukott meg.)
$GLOBALS['huhs_posts'] = array();
reset_send_state();
seed_post(401, 'huhs_poll', 'Kör-találat kérdőív', array('_huhs_poll_start' => local_clock(-1200)));
huhs_push_scan_open_notices();
$scan_messages = sent_messages();
check('a biztonsági kör kiküldi a frissen kinyílt, még nem hirdetett tartalmat',
    count($scan_messages) === 2, (string) count($scan_messages));
check('a kör küldése is a kérdőív típusát viszi',
    ($scan_messages[0]['data']['type'] ?? '') === 'poll' && ($scan_messages[0]['data']['kind'] ?? '') === 'open');
reset_send_state();
huhs_push_scan_open_notices();
check('a biztonsági kör sem tud duplázni (a jelölő véd)', count(sent_messages()) === 0);

// --- 9) Forrás-lint (a bekötés és a kulcsok) --------------------------------
$hooks = array();
foreach ($GLOBALS['huhs_hooks'] as $entry) $hooks[$entry['hook']] = $entry;
$missing_hooks = array();
foreach ($expected_types as $post_type) {
    if (!isset($hooks['save_post_' . $post_type])) $missing_hooks[] = 'save_post_' . $post_type;
}
check('mind a négy típus mentés-hookja be van kötve (a térképből)', $missing_hooks === array(), implode(',', $missing_hooks));
check('a mentés-hook a plugin saját mentése UTÁN fut (20 > 10), hogy a meta már a helyén legyen',
    ($hooks['save_post_huhs_poll']['priority'] ?? 0) === 20);
check('a biztonsági kör az `init`-ben regisztrálódik az ötperces ütemezésre',
    strpos($pushSource, "wp_schedule_event(time() + 120, 'huhs_five_minutes', 'huhs_push_open_notice_scan')") !== false
    && strpos($pushSource, "add_action('huhs_push_open_notice_scan', 'huhs_push_scan_open_notices')") !== false);
check('a küldés a KÖZÖS nyelvenkénti láncot használja',
    strpos($pushSource, '$sent = huhs_push_send_localized(huhs_push_open_notice_texts($post, $config), $data);') !== false);
check('a jelölő a sikeres küldés (vagy élő folytatás) után íródik',
    strpos($pushSource, "if (\$sent > 0 || huhs_push_has_pending_job(\$data)) {") !== false);
check('a `save_post_*` kezelő nem hirdet vázlatot/autosave-ot',
    strpos($pushSource, "if (defined('DOING_AUTOSAVE') && DOING_AUTOSAVE) return;") !== false);

// --- Összegzés -------------------------------------------------------------
$ok = $failures === 0;
echo "\n{$checks} ellenőrzés, {$failures} hiba\n";
if ($ok) echo "PUSH-OPEN OK\n";
exit($ok ? 0 : 1);
