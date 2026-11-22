<?php

if (!defined('ABSPATH')) {
    exit;
}

/*
|--------------------------------------------------------------------------
| Bulis becsekkolás QR-kóddal + időbeosztás (plugin 2.15.0)
|--------------------------------------------------------------------------
|
| A szabályok (a szerver dönt, nem a kliens):
|  - eseményenként EGY titkos kód (`_huhs_checkin_code`), ebből készül a QR:
|    https://hungarianhardstyle.hu/checkin/<eseményId>/<kód>
|  - a becsekkolás CSAK a buli ideje alatt érvényes (a kezdéstől a
|    végéig; záró idő nélkül a kezdéstől 10 óráig) — egy lefotózott QR-rel
|    otthonról nem lehet pontot gyűjteni;
|  - egy fiók eseményenként EGYSZER csekkol be. A WordPress csak a sózott
|    ujjlenyomatot tárolja (`_huhs_checkin_<sha256>`), UID-t és e-mailt nem
|    (ugyanaz a minta, mint a kérdőívnél);
|  - a becsekkolás végpontját csak a Firebase hívja (alkalmazás-jelszóval),
|    a pontot és a jelvényt a Firebase írja jóvá.
*/

const HUHS_CHECKIN_OPENS_BEFORE = 0;          // a buli kezdetekor nyílik
const HUHS_CHECKIN_DEFAULT_LENGTH = 36000;    // záró idő nélkül: 10 óra
const HUHS_CHECKIN_META_PREFIX = '_huhs_checkin_entry_';
const HUHS_CHECKIN_GPS_RADIUS = 250;           // méter: ennyin belül számít „a helyszínen”

/**
 * A helyalapú becsekkolás beállítása (2.16.6): kapcsoló + a helyszín koordinátája.
 * Érvénytelen koordinátánál kikapcsoltnak számít. A koordinátát NEM adjuk a
 * nyilvános válaszba; a távolságot a szerver (Firebase) méri.
 *
 * @return array{enabled:bool, lat:float, lng:float, radius:int}
 */
function huhs_event_checkin_gps($event_id)
{
    $lat = (string) get_post_meta($event_id, 'checkin_lat', true);
    $lng = (string) get_post_meta($event_id, 'checkin_lng', true);
    $valid = is_numeric($lat) && is_numeric($lng)
        && (float) $lat >= -90 && (float) $lat <= 90
        && (float) $lng >= -180 && (float) $lng <= 180;
    $on = (string) get_post_meta($event_id, 'checkin_gps', true) === '1';
    return array(
        'enabled' => $on && $valid,
        'lat' => $valid ? (float) $lat : 0.0,
        'lng' => $valid ? (float) $lng : 0.0,
        'radius' => HUHS_CHECKIN_GPS_RADIUS,
    );
}

/** A becsekkolás sójának lekérése (első használatkor jön létre, a szerveren marad). */
function huhs_checkin_salt()
{
    $salt = (string) get_option('huhs_checkin_salt', '');
    if ($salt === '') {
        $salt = wp_generate_password(48, false, false);
        add_option('huhs_checkin_salt', $salt, '', false);
    }
    return $salt;
}

function huhs_checkin_player_hash($event_id, $uid)
{
    return hash('sha256', huhs_checkin_salt() . '|' . (int) $event_id . '|' . (string) $uid);
}

/** Az esemény becsekkolási kódja; kérésre létrehozza (vagy újragenerálja). */
function huhs_event_checkin_code($event_id, $create = false, $regenerate = false)
{
    $code = (string) get_post_meta($event_id, '_huhs_checkin_code', true);
    if ($regenerate || ($create && $code === '')) {
        $code = strtolower(wp_generate_password(20, false, false));
        update_post_meta($event_id, '_huhs_checkin_code', $code);
    }
    return $code;
}

function huhs_event_checkin_url($event_id, $code)
{
    if ($code === '') return '';
    return home_url('/checkin/' . (int) $event_id . '/' . rawurlencode($code));
}

/** A naptári dátum + idő valódi időbélyege a webhely időzónájában. */
function huhs_checkin_timestamp($date, $time, $fallback_time)
{
    $date = trim((string) $date);
    if ($date === '') return 0;
    $time = trim((string) $time) !== '' ? trim((string) $time) : $fallback_time;
    $parsed = date_create_immutable($date . ' ' . $time, wp_timezone());
    return $parsed ? (int) $parsed->getTimestamp() : 0;
}

/**
 * A becsekkolási ablak. Tiszta függvény (a dátumokat paraméterként kapja), hogy
 * WordPress nélkül is mérhető legyen.
 *
 * @return array{opens:int, closes:int}
 */
function huhs_checkin_window_from($start_date, $start_time, $end_date, $end_time)
{
    $start = huhs_checkin_timestamp($start_date, $start_time, '20:00');
    if ($start === 0) return array('opens' => 0, 'closes' => 0);
    $end = 0;
    if (trim((string) $end_date) !== '' || trim((string) $end_time) !== '') {
        // Záró dátum nélkül a kezdő napra értjük; ha az idő a kezdés előtt van
        // (22:00 → 05:00), az éjfél utáni nap.
        $end = huhs_checkin_timestamp(
            trim((string) $end_date) !== '' ? $end_date : $start_date,
            $end_time,
            '23:59'
        );
        if ($end !== 0 && $end <= $start) $end += DAY_IN_SECONDS;
    }
    if ($end === 0) $end = $start + HUHS_CHECKIN_DEFAULT_LENGTH;
    return array('opens' => $start - HUHS_CHECKIN_OPENS_BEFORE, 'closes' => $end);
}

function huhs_event_checkin_window($event_id)
{
    return huhs_checkin_window_from(
        get_post_meta($event_id, 'event_start_date', true),
        get_post_meta($event_id, 'event_start_time', true),
        get_post_meta($event_id, 'event_end_date', true),
        get_post_meta($event_id, 'event_end_time', true)
    );
}

/** `before` / `open` / `closed` / `unknown` */
function huhs_checkin_state(array $window, $now)
{
    if ($window['opens'] === 0) return 'unknown';
    if ($now < $window['opens']) return 'before';
    if ($now > $window['closes']) return 'closed';
    return 'open';
}

function huhs_event_checkin_count($event_id)
{
    global $wpdb;
    return (int) $wpdb->get_var($wpdb->prepare(
        "SELECT COUNT(*) FROM {$wpdb->postmeta} WHERE post_id = %d AND meta_key LIKE %s",
        (int) $event_id,
        $wpdb->esc_like(HUHS_CHECKIN_META_PREFIX) . '%'
    ));
}

/**
 * Az időbeosztás sorai. Egy sor: `22:00 - 23:30 | Denoiser` vagy `22:00 Denoiser`.
 * A hibás/üres sorokat kihagyja (nem tippel).
 *
 * @return array<int, array{time:string, artist:string}>
 */
/** Az időbeosztás megjelenési ideje (webhely-idő); üres = azonnal látszik. */
function huhs_event_timetable_visible($event_id)
{
    $from = trim((string) get_post_meta($event_id, 'event_timetable_from', true));
    if ($from === '') {
        return true;
    }
    try {
        $at = new DateTimeImmutable($from, wp_timezone());
    } catch (Exception $e) {
        return true;
    }
    return time() >= $at->getTimestamp();
}

function huhs_parse_event_timetable($raw)
{
    $rows = array();
    foreach (preg_split('/\r\n|\r|\n/', (string) $raw) as $line) {
        $line = trim($line);
        if ($line === '') continue;
        if (strpos($line, '|') !== false) {
            list($time, $artist) = array_map('trim', explode('|', $line, 2));
        } elseif (preg_match('/^(\d{1,2}[:.]\d{2}(?:\s*[-–]\s*\d{1,2}[:.]\d{2})?)\s+(.+)$/u', $line, $m)) {
            $time = trim($m[1]);
            $artist = trim($m[2]);
        } else {
            $time = '';
            $artist = $line;
        }
        if ($artist === '') continue;
        $rows[] = array(
            'time' => sanitize_text_field(str_replace('.', ':', $time)),
            'artist' => sanitize_text_field($artist),
        );
        if (count($rows) >= 40) break;
    }
    return $rows;
}

/** A nyilvános esemény-válaszba kerülő mezők (kód NÉLKÜL — az titok). */
function huhs_event_checkin_public_fields($event_id)
{
    $window = huhs_event_checkin_window($event_id);
    $badge_url = esc_url_raw((string) get_post_meta($event_id, 'checkin_badge_url', true));
    return array(
        'timetable' => huhs_event_timetable_visible($event_id) ? huhs_parse_event_timetable(get_post_meta($event_id, 'event_timetable', true)) : array(),
        'checkin_enabled' => huhs_event_checkin_code($event_id) !== '',
        'checkin_gps' => huhs_event_checkin_gps($event_id)['enabled'],
        'checkin_opens' => $window['opens'] ? gmdate('c', $window['opens']) : '',
        'checkin_closes' => $window['closes'] ? gmdate('c', $window['closes']) : '',
        'checkin_badge_name' => sanitize_text_field((string) get_post_meta($event_id, 'checkin_badge_name', true)),
        'checkin_badge_url' => preg_match('#^https?://#i', $badge_url) ? $badge_url : '',
    );
}

/*
|--------------------------------------------------------------------------
| REST — csak a szerver (Firebase) hívja
|--------------------------------------------------------------------------
*/

add_action('rest_api_init', function () {
    $server_only = function () {
        return current_user_can('manage_options');
    };
    register_rest_route('huhs/v1', '/events/(?P<id>\d+)/checkin', array(
        'methods' => 'POST',
        'callback' => 'huhs_event_checkin_api_record',
        'permission_callback' => $server_only,
    ));
    // A helyalapú becsekkolás beállítása (koordináta, sugár, ablak): csak a Firebase kéri.
    register_rest_route('huhs/v1', '/events/(?P<id>\d+)/checkin-gps', array(
        'methods' => 'GET',
        'callback' => 'huhs_event_checkin_api_gps',
        'permission_callback' => $server_only,
    ));
    // A natív admin (HUHS Vezérlőközpont) ezzel kéri le / generálja újra a QR-t.
    register_rest_route('huhs/v1', '/events/(?P<id>\d+)/checkin-code', array(
        'methods' => array('GET', 'POST'),
        'callback' => 'huhs_event_checkin_api_code',
        'permission_callback' => $server_only,
    ));
});

function huhs_event_checkin_api_record(WP_REST_Request $request)
{
    $event_id = (int) $request['id'];
    $event = get_post($event_id);
    if (!$event || $event->post_type !== 'huhs_event' || $event->post_status !== 'publish') {
        return new WP_Error('huhs_checkin_not_found', 'Ez az esemény nem található.', array('status' => 404));
    }
    $uid = trim((string) $request->get_param('uid'));
    $code = strtolower(trim((string) $request->get_param('code')));
    if ($uid === '' || strlen($uid) > 128) {
        return new WP_Error('huhs_checkin_bad_user', 'Érvénytelen felhasználó.', array('status' => 400));
    }
    // `gps_verified`: a Firebase már megmérte a távolságot (csak ő hívja ezt a végpontot,
    // alkalmazás-jelszóval); ilyenkor a QR-kód nem kell, de csak ha az esemény GPS-es.
    $gps_verified = filter_var($request->get_param('gps_verified'), FILTER_VALIDATE_BOOLEAN);
    if ($gps_verified) {
        if (!huhs_event_checkin_gps($event_id)['enabled']) {
            return new WP_Error('huhs_checkin_gps_off', 'Ennél a bulinál nincs helyalapú becsekkolás.', array('status' => 403));
        }
    } else {
        $expected = huhs_event_checkin_code($event_id);
        if ($expected === '' || $code === '' || !hash_equals($expected, $code)) {
            return new WP_Error('huhs_checkin_bad_code', 'Ez a QR-kód nem ehhez a bulihoz tartozik.', array('status' => 403));
        }
    }
    $state = huhs_checkin_state(huhs_event_checkin_window($event_id), time());
    if ($state !== 'open') {
        $message = $state === 'before'
            ? 'A becsekkolás a buli kezdetekor nyílik.'
            : 'Ennek a bulinak a becsekkolása már lezárult.';
        return new WP_Error('huhs_checkin_closed', $message, array('status' => 403, 'state' => $state));
    }
    $meta_key = HUHS_CHECKIN_META_PREFIX . huhs_checkin_player_hash($event_id, $uid);
    // A sor LÉTEZÉSE dönt, nem az értéke (a kérdőív `(bool) '0'` tanulsága).
    $already = metadata_exists('post', $event_id, $meta_key);
    if (!$already) {
        add_post_meta($event_id, $meta_key, time(), true);
    }
    $fields = huhs_event_checkin_public_fields($event_id);
    return rest_ensure_response(array(
        'ok' => true,
        'alreadyCheckedIn' => $already,
        'eventId' => $event_id,
        'title' => huhs_clean_title($event->post_title),
        'badgeName' => $fields['checkin_badge_name'],
        'badgeUrl' => $fields['checkin_badge_url'],
        'count' => huhs_event_checkin_count($event_id),
    ));
}

function huhs_event_checkin_api_gps(WP_REST_Request $request)
{
    $event_id = (int) $request['id'];
    $event = get_post($event_id);
    if (!$event || $event->post_type !== 'huhs_event' || $event->post_status !== 'publish') {
        return new WP_Error('huhs_checkin_not_found', 'Ez az esemény nem található.', array('status' => 404));
    }
    $gps = huhs_event_checkin_gps($event_id);
    $window = huhs_event_checkin_window($event_id);
    return rest_ensure_response(array(
        'enabled' => $gps['enabled'],
        'lat' => $gps['lat'],
        'lng' => $gps['lng'],
        'radius' => $gps['radius'],
        'state' => huhs_checkin_state($window, time()),
    ));
}

function huhs_event_checkin_api_code(WP_REST_Request $request)
{
    $event_id = (int) $request['id'];
    $event = get_post($event_id);
    if (!$event || $event->post_type !== 'huhs_event') {
        return new WP_Error('huhs_checkin_not_found', 'Ez az esemény nem található.', array('status' => 404));
    }
    $regenerate = $request->get_method() === 'POST'
        && filter_var($request->get_param('regenerate'), FILTER_VALIDATE_BOOLEAN);
    if ($regenerate) huhs_event_checkin_code($event_id, true, true);
    return rest_ensure_response(huhs_event_checkin_code_payload($event_id));
}

/** A QR adatai (a natív admin és a REST közös válasza). */
function huhs_event_checkin_code_payload($event_id)
{
    $code = huhs_event_checkin_code($event_id, get_post_status($event_id) === 'publish');
    $window = huhs_event_checkin_window($event_id);
    return array(
        'eventId' => (int) $event_id,
        'title' => huhs_clean_title(get_the_title($event_id)),
        'url' => huhs_event_checkin_url($event_id, $code),
        'count' => huhs_event_checkin_count($event_id),
        'state' => huhs_checkin_state($window, time()),
        'opens' => $window['opens'] ? gmdate('c', $window['opens']) : '',
        'closes' => $window['closes'] ? gmdate('c', $window['closes']) : '',
    );
}

/*
|--------------------------------------------------------------------------
| WordPress admin: „Becsekkolás és időbeosztás" doboz az eseményen
|--------------------------------------------------------------------------
*/

add_action('admin_enqueue_scripts', function ($hook) {
    if (($hook === 'post.php' || $hook === 'post-new.php')) { wp_enqueue_media(); }
});

add_action('add_meta_boxes', function () {
    add_meta_box(
        'huhs_event_checkin',
        'Becsekkolás (QR) és időbeosztás',
        'huhs_event_checkin_meta_box',
        'huhs_event',
        'normal',
        'high'
    );
});

// 2.15.1: az általános „Egyéni mezők” doboz az eseményeknél csak zavart (a mezőket
// a saját dobozaink kezelik). Elrejtjük; az adatok nem érintettek, és ha valaki
// mégis kell, a „Képernyő beállításai” alatt újra bekapcsolható.
add_action('add_meta_boxes_huhs_event', function () {
    remove_meta_box('postcustom', 'huhs_event', 'normal');
}, 99);

function huhs_event_checkin_meta_box($post)
{
    wp_nonce_field('huhs_event_checkin_save', 'huhs_event_checkin_nonce');
    $code = huhs_event_checkin_code($post->ID, $post->post_status === 'publish');
    $url = huhs_event_checkin_url($post->ID, $code);
    $state = huhs_checkin_state(huhs_event_checkin_window($post->ID), time());
    $state_label = array(
        'before' => 'még nem nyílt meg (a buli kezdetekor nyílik)',
        'open' => 'NYITVA — most lehet becsekkolni',
        'closed' => 'lezárult',
        'unknown' => 'nincs kezdő dátum, ezért nem nyílik meg',
    );
    ?>
    <p><strong>Időbeosztás</strong> (soronként egy fellépő, pl. <code>22:00 - 23:30 | Denoiser</code>)</p>
    <textarea name="event_timetable" rows="6" class="widefat"><?php
        echo esc_textarea((string) get_post_meta($post->ID, 'event_timetable', true));
    ?></textarea>
    <p><label>Mikortól látszódjon az appban (üres = azonnal)<br><input type="datetime-local" name="event_timetable_from" value="<?php echo esc_attr((string) get_post_meta($post->ID, 'event_timetable_from', true)); ?>"></label></p>
    <p class="description">A buli napján az app Kezdőlapján, a „Ma este” kártyán és az esemény adatlapján jelenik meg.</p>

    <hr>
    <p><strong>Helyalapú becsekkolás (GPS)</strong> — a QR mellett az app „Itt vagyok a helyszínen” gombja is becsekkolja a látogatót, ha a telefonja a helyszín közelében van (<?php echo (int) HUHS_CHECKIN_GPS_RADIUS; ?> m). Alapból ki van kapcsolva.</p>
    <p><label><input type="checkbox" name="checkin_gps" value="1" <?php checked((string) get_post_meta($post->ID, 'checkin_gps', true), '1'); ?>> Helyalapú becsekkolás engedélyezése</label></p>
    <p>
        <label>Helyszín szélessége (pl. 47.4979)<br>
            <input type="text" name="checkin_lat" value="<?php echo esc_attr((string) get_post_meta($post->ID, 'checkin_lat', true)); ?>" placeholder="47.4979">
        </label>
        <label style="margin-left:12px">Helyszín hosszúsága (pl. 19.0402)<br>
            <input type="text" name="checkin_lng" value="<?php echo esc_attr((string) get_post_meta($post->ID, 'checkin_lng', true)); ?>" placeholder="19.0402">
        </label>
    </p>
    <p class="description">A koordinátát a Google Térképen a helyszínre jobb gombbal kattintva másolhatod ki. A telefon pozícióját a szerver csak az ellenőrzéshez használja, nem tárolja.</p>

    <hr>
    <p><strong>Becsekkolási jelvény</strong> (a becsekkolók ezt kapják; ha üres, általános „Ott voltam” jelvény jár)</p>
    <p>
        <label>Jelvény neve<br>
            <input type="text" class="widefat" name="checkin_badge_name" value="<?php
                echo esc_attr((string) get_post_meta($post->ID, 'checkin_badge_name', true));
            ?>" placeholder="pl. Hard Base 2026 – ott voltam">
        </label>
    </p>
    <p>
        <label>Jelvény képe<br>
            <input type="url" class="widefat" id="huhs-checkin-badge-url" name="checkin_badge_url" value="<?php
                echo esc_attr((string) get_post_meta($post->ID, 'checkin_badge_url', true));
            ?>" placeholder="https://hungarianhardstyle.hu/wp-content/uploads/...">
        </label>
    </p>
    <p>
        <a href="#" class="button" id="huhs-checkin-badge-pick">Kép feltöltése / kiválasztása</a>
        <img id="huhs-checkin-badge-preview" src="<?php
            echo esc_url((string) get_post_meta($post->ID, 'checkin_badge_url', true));
        ?>" alt="" style="max-width:96px;max-height:96px;vertical-align:middle;margin-left:10px;<?php
            echo get_post_meta($post->ID, 'checkin_badge_url', true) ? '' : 'display:none;';
        ?>">
    </p>
    <script>
    (function () {
        var btn = document.getElementById('huhs-checkin-badge-pick');
        if (!btn) { return; }
        var frame;
        btn.addEventListener('click', function (e) {
            e.preventDefault();
            if (typeof wp === 'undefined' || !wp.media) { alert('A médiatár nem töltődött be — frissítsd az oldalt.'); return; }
            if (!frame) {
                frame = wp.media({ title: 'Becsekkolási jelvény', button: { text: 'Használom' }, library: { type: 'image' }, multiple: false });
                frame.on('select', function () {
                    var a = frame.state().get('selection').first().toJSON();
                    document.getElementById('huhs-checkin-badge-url').value = a.url;
                    var p = document.getElementById('huhs-checkin-badge-preview');
                    p.src = a.url; p.style.display = '';
                });
            }
            frame.open();
        });
    })();
    </script>

    <hr>
    <?php if ($url === '') : ?>
        <p>A QR-kód az esemény <strong>közzététele</strong> után jön létre.</p>
    <?php else : ?>
        <p><strong>Becsekkolási QR</strong> — állapot: <?php echo esc_html($state_label[$state]); ?> ·
            becsekkolt: <strong><?php echo (int) huhs_event_checkin_count($post->ID); ?></strong> fő</p>
        <div id="huhs-checkin-qr" data-url="<?php echo esc_attr($url); ?>" style="background:#fff;display:inline-block;padding:12px"></div>
        <p><code style="word-break:break-all"><?php echo esc_html($url); ?></code></p>
        <p>
            <a href="#" class="button" id="huhs-checkin-qr-download">QR letöltése (PNG)</a>
            <label style="margin-left:12px">
                <input type="checkbox" name="huhs_checkin_regenerate" value="1">
                Új kód generálása (a régi QR érvénytelenné válik)
            </label>
        </p>
        <p class="description">Nyomtasd ki vagy vetítsd ki a bejáratnál. A kód csak a buli ideje alatt ad pontot, fiókonként egyszer.</p>
        <script src="<?php echo esc_url(HUHS_API_URL . 'assets/qrcode.js?v=' . HUHS_API_VERSION); ?>"></script>
        <script>
        (function () {
            var box = document.getElementById('huhs-checkin-qr');
            if (!box || typeof qrcode !== 'function') return;
            var qr = qrcode(0, 'M');
            qr.addData(box.getAttribute('data-url'));
            qr.make();
            box.innerHTML = qr.createImgTag(8, 4, 'Becsekkolási QR');
            var link = document.getElementById('huhs-checkin-qr-download');
            if (link) {
                link.href = qr.createDataURL(16, 4);
                link.setAttribute('download', 'huhs-checkin-<?php echo (int) $post->ID; ?>.png');
            }
        })();
        </script>
    <?php endif;
}

add_action('save_post_huhs_event', 'huhs_save_event_checkin_meta', 20);

function huhs_save_event_checkin_meta($post_id)
{
    if (!isset($_POST['huhs_event_checkin_nonce'])
        || !wp_verify_nonce($_POST['huhs_event_checkin_nonce'], 'huhs_event_checkin_save')) {
        return;
    }
    if (defined('DOING_AUTOSAVE') && DOING_AUTOSAVE) return;
    if (!current_user_can('edit_post', $post_id)) return;

    if (isset($_POST['event_timetable_from'])) {
        $from = sanitize_text_field(wp_unslash($_POST['event_timetable_from']));
        update_post_meta($post_id, 'event_timetable_from', preg_match('/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/', $from) ? $from : '');
    }
    if (isset($_POST['event_timetable'])) {
        update_post_meta($post_id, 'event_timetable', sanitize_textarea_field(wp_unslash($_POST['event_timetable'])));
    }
    update_post_meta($post_id, 'checkin_gps', !empty($_POST['checkin_gps']) ? '1' : '0');
    foreach (array('checkin_lat' => 90.0, 'checkin_lng' => 180.0) as $key => $limit) {
        if (!isset($_POST[$key])) continue;
        $raw = str_replace(',', '.', trim(sanitize_text_field(wp_unslash($_POST[$key]))));
        $ok = $raw !== '' && is_numeric($raw) && abs((float) $raw) <= $limit;
        update_post_meta($post_id, $key, $ok ? (string) (float) $raw : '');
    }
    if (isset($_POST['checkin_badge_name'])) {
        update_post_meta($post_id, 'checkin_badge_name', sanitize_text_field(wp_unslash($_POST['checkin_badge_name'])));
    }
    if (isset($_POST['checkin_badge_url'])) {
        $badge = esc_url_raw(wp_unslash($_POST['checkin_badge_url']), array('http', 'https'));
        update_post_meta($post_id, 'checkin_badge_url', $badge);
    }
    if (!empty($_POST['huhs_checkin_regenerate'])) {
        huhs_event_checkin_code($post_id, true, true);
    } elseif (get_post_status($post_id) === 'publish') {
        huhs_event_checkin_code($post_id, true);
    }
}

/*
|--------------------------------------------------------------------------
| Weboldali tartalék: ha a QR-t a telefon kamerája nyitja meg app nélkül
|--------------------------------------------------------------------------
| Telepített appnál az Android App Link az appot nyitja (a `/checkin` útvonal a
| manifestben). Ha nincs app, ez az oldal mondja meg, mit kell tenni.
*/

add_action('template_redirect', function () {
    $path = (string) wp_parse_url((string) ($_SERVER['REQUEST_URI'] ?? ''), PHP_URL_PATH);
    if (!preg_match('#^/checkin/(\d+)/[A-Za-z0-9]+/?$#', $path)) return;
    status_header(200);
    nocache_headers();
    header('Content-Type: text/html; charset=utf-8');
    $play = 'https://play.google.com/store/apps/details?id=hu.hungarianhardstyle.app';
    echo '<!doctype html><html lang="hu"><head><meta charset="utf-8">'
        . '<meta name="viewport" content="width=device-width,initial-scale=1">'
        . '<meta name="robots" content="noindex"><title>Becsekkolás – Hungarian Hardstyle</title>'
        . '<style>body{background:#0b0b0d;color:#fff;font-family:system-ui,sans-serif;'
        . 'display:flex;min-height:100vh;align-items:center;justify-content:center;margin:0;padding:24px}'
        . 'main{max-width:420px;text-align:center}a{display:inline-block;margin-top:16px;padding:14px 22px;'
        . 'background:#e1061b;color:#fff;border-radius:10px;text-decoration:none;font-weight:700}</style></head>'
        . '<body><main><h1>Becsekkolás</h1>'
        . '<p>A becsekkoláshoz a <strong>Hungarian Hardstyle</strong> app kell. '
        . 'Telepítsd, lépj be, majd a Kezdőlap „Ma este” kártyáján olvasd be újra ezt a QR-kódot.</p>'
        . '<a href="' . esc_url($play) . '">Hungarian Hardstyle app</a></main></body></html>';
    exit;
}, 1);
