<?php

if (!defined('ABSPATH')) {
    exit;
}

define('HUHS_PUSH_TOKENS_OPTION', 'huhs_push_tokens');
define('HUHS_PUSH_SERVICE_ACCOUNT_OPTION', 'huhs_firebase_service_account');
/**
 * Melyik hét összefoglalója ment már ki (2.14.8).
 *
 * MIÉRT kell: a heti kör többször is elindulhat (a hívó újrapróbál, vagy kézzel
 * is rákérdeznek) — a hét azonosítója (`2026-W40`) viszont determinisztikus,
 * ezért ebből lesz a „már kiment" jelölés.
 */
define('HUHS_PUSH_DIGEST_WEEK_OPTION', 'huhs_push_digest_week');

/**
 * Meddig számít „frissen kinyíltnak" egy szavazás/játék (2.14.11).
 *
 * ⚠️ MIÉRT KELL (mért kockázat): a 2.14.11 **feltöltésekor** a már meglévő,
 * régen megnyílt kérdőívekre/játékokra a biztonsági kör különben kiküldené az
 * értesítést — vagyis egy fél éve lezárt szavazásról szólna egy push. Ez a kapu
 * ezt zárja ki: csak a **frissen** (6 órán belül) kinyílt tartalom ér.
 */
define('HUHS_PUSH_OPEN_FRESH_WINDOW', 6 * HOUR_IN_SECONDS);

/**
 * A támogatott értesítés-nyelvek. A küldés **nyelvenként külön** megy ki, mert
 * a push szövegét a rendszer rajzolja ki — azt az app már nem tudja lefordítani.
 */
function huhs_push_languages()
{
    return array('hu', 'en');
}

/**
 * A token rekord nyelvének normalizálása (`hu`/`en`).
 *
 * ⚠️ Ismeretlen vagy **hiányzó** érték → magyar: a régi kliensek (amelyek még
 * nem küldenek nyelvet) a megszokott magyar szöveget kapják, nem némul el a
 * push. Ez a 2.14.6 előtti állapot pontos viselkedése.
 */
function huhs_push_normalize_language($value)
{
    $code = strtolower(trim((string) $value));
    if ($code === 'en' || strpos($code, 'en-') === 0 || strpos($code, 'en_') === 0) {
        return 'en';
    }
    return 'hu';
}

add_action('rest_api_init', function () {
    register_rest_route('huhs/v1', '/push/register', array(
        'methods' => 'POST',
        'callback' => 'huhs_push_register_token',
        'permission_callback' => '__return_true',
    ));
    register_rest_route('huhs/v1', '/push/preferences', array(
        'methods' => 'POST',
        'callback' => 'huhs_push_update_preferences',
        'permission_callback' => '__return_true',
    ));
    register_rest_route('huhs/v1', '/resolve', array(
        'methods' => 'GET',
        'callback' => 'huhs_resolve_content_target',
        // Nyilvános, CSAK OLVAS: a tartalom maga is nyilvános, és a megosztott
        // linket az app akkor is feloldja, ha a felhasználó nincs bejelentkezve.
        'permission_callback' => '__return_true',
    ));
    register_rest_route('huhs/v1', '/push/digest', array(
        'methods' => 'POST',
        'callback' => 'huhs_push_weekly_digest',
        // ⚠️ NEM nyilvános: ezt a Cloud Function hívja **szerver-szerver**, a
        // WordPress admin alkalmazás-jelszavával (ugyanaz, amit a vezérlőközpont
        // használ). Azért kell a WordPress oldaláról küldeni, mert a **token-tár
        // itt él** (1010 eszköz), a Firestore csak a regisztrált profilokét ismeri.
        'permission_callback' => function () {
            return current_user_can('manage_options');
        },
    ));
});

function huhs_push_register_token(WP_REST_Request $request)
{
    $params = $request->get_json_params();
    $token = sanitize_text_field((string) ($params['token'] ?? $request->get_param('token')));
    $platform = sanitize_key((string) ($params['platform'] ?? 'android'));
    // Nyelv (2.14.6): a kliens küldi (`hu`/`en`) — ebből lesz nyelvenkénti
    // emlékeztető. Hiányzó érték esetén magyar (a régi kliensek viselkedése).
    $language = huhs_push_normalize_language($params['language'] ?? '');

    if (strlen($token) < 20 || strlen($token) > 4096) {
        return new WP_Error('invalid_push_token', 'Érvénytelen FCM token.', array('status' => 400));
    }

    $tokens = get_option(HUHS_PUSH_TOKENS_OPTION, array());
    if (!is_array($tokens)) $tokens = array();

    $key = hash('sha256', $token);
    $existing = is_array($tokens[$key] ?? null) ? $tokens[$key] : array();
    $tokens[$key] = array_merge($existing, array(
        'token' => $token,
        'platform' => $platform,
        'language' => $language,
        'updated_at' => current_time('mysql', true),
    ));

    update_option(HUHS_PUSH_TOKENS_OPTION, $tokens, false);
    return new WP_REST_Response(array('registered' => true), 200);
}

function huhs_push_update_preferences(WP_REST_Request $request)
{
    $params = $request->get_json_params();
    $token = sanitize_text_field((string) ($params['token'] ?? $request->get_param('token')));
    if (strlen($token) < 20 || strlen($token) > 4096) {
        return new WP_Error('invalid_push_token', 'Érvénytelen FCM token.', array('status' => 400));
    }

    $tokens = get_option(HUHS_PUSH_TOKENS_OPTION, array());
    if (!is_array($tokens)) $tokens = array();
    $key = hash('sha256', $token);
    $record = is_array($tokens[$key] ?? null) ? $tokens[$key] : array();
    $tokens[$key] = array_merge($record, array(
        'token' => $token,
        // Nyelv (2.14.6): a beállítás-küldés is frissíti, mert a felhasználó a
        // nyelvet az appban váltja — a következő mentés így átállítja a
        // nyelvenkénti emlékeztetőt is.
        'language' => huhs_push_normalize_language($params['language'] ?? ($record['language'] ?? '')),
        'enabled' => filter_var($params['enabled'] ?? true, FILTER_VALIDATE_BOOLEAN),
        'news' => filter_var($params['news'] ?? true, FILTER_VALIDATE_BOOLEAN),
        'events' => filter_var($params['events'] ?? true, FILTER_VALIDATE_BOOLEAN),
        'releases' => filter_var($params['releases'] ?? true, FILTER_VALIDATE_BOOLEAN),
        'reminders' => filter_var($params['reminders'] ?? true, FILTER_VALIDATE_BOOLEAN),
        // Heti összefoglaló (2.14.8): külön kapcsoló, alapból BE — aki nem kér
        // belőle, az a többit változatlanul kapja.
        'digest' => filter_var($params['digest'] ?? true, FILTER_VALIDATE_BOOLEAN),
        // Kedvencelés (2.14.9): a kliens a KÖVETETT DJ-k/szervezők azonosítóit
        // küldi — ebből lesz a személyes célzás. Ha nem küldi (régi kliens),
        // marad a korábbi érték, illetve a „nincs kedvenc" állapot.
        'artists' => huhs_push_favorite_ids($params['artists'] ?? ($record['artists'] ?? array())),
        'organizers' => huhs_push_favorite_ids($params['organizers'] ?? ($record['organizers'] ?? array())),
        'updated_at' => current_time('mysql', true),
    ));
    update_option(HUHS_PUSH_TOKENS_OPTION, $tokens, false);
    return new WP_REST_Response(array('saved' => true), 200);
}

/**
 * A beérkező heti-összefoglaló szövegek tisztítása (2.14.8).
 *
 * Csak a támogatott nyelvek maradhatnak meg, és csak akkor, ha a **cím és a
 * törzs is** kitöltött — így egy hiányos payload nem küld üres értesítést.
 */
function huhs_push_digest_texts($raw)
{
    $texts = array();
    if (!is_array($raw)) return $texts;
    foreach (huhs_push_languages() as $language) {
        $entry = is_array($raw[$language] ?? null) ? $raw[$language] : array();
        $title = sanitize_text_field((string) ($entry['title'] ?? ''));
        $body = sanitize_textarea_field((string) ($entry['body'] ?? ''));
        if ($title === '' || $body === '') continue;
        $texts[$language] = array('title' => $title, 'body' => $body);
    }
    return $texts;
}

/** Nyelvenként hány eszköz kapná meg a heti összefoglalót (száraz méréshez). */
function huhs_push_digest_reach()
{
    $tokens = get_option(HUHS_PUSH_TOKENS_OPTION, array());
    if (!is_array($tokens)) $tokens = array();
    $reach = array();
    foreach (huhs_push_languages() as $language) {
        $reach[$language] = count(huhs_push_recipients($tokens, array('type' => 'digest'), $language));
    }
    $reach['total'] = count(huhs_push_recipients($tokens, array('type' => 'digest'), ''));
    return $reach;
}

/**
 * HETI ÖSSZEFOGLALÓ kiküldése MINDEN regisztrált eszközre (2.14.8).
 *
 * MIÉRT a WordPress küld: a token-tár itt él (~1010 eszköz, nyelvenként és
 * beállításonként), a Firestore viszont csak a **regisztrált profilok** tokeneit
 * ismeri (~45). A döntés (mi kerüljön a levélbe) a Cloud Functionben születik
 * (ott van a hírek/események összesítése és a nyelvtan), a **küldést** viszont a
 * bizonyított helyi lánc végzi — így minden eszköz elérhető, és nincs dupla push.
 *
 * Idempotencia: a hét azonosítója (`2026-W40`) az opcióban marad; ugyanarra a
 * hétre a második hívás **nem** küld újra.
 */
function huhs_push_weekly_digest(WP_REST_Request $request)
{
    $params = $request->get_json_params();
    $week = sanitize_text_field((string) ($params['week'] ?? ''));
    $texts = huhs_push_digest_texts($params['texts'] ?? array());
    $dryRun = filter_var($params['dry_run'] ?? false, FILTER_VALIDATE_BOOLEAN);

    if ($week === '') {
        return new WP_Error('invalid_week', 'Hiányzik a hét azonosítója (pl. 2026-W40).', array('status' => 400));
    }
    if (!$texts) {
        return new WP_Error('invalid_texts', 'Nincs küldhető szöveg (nyelvenként cím ÉS törzs kell).', array('status' => 400));
    }

    $reach = huhs_push_digest_reach();
    if ($dryRun) {
        return new WP_REST_Response(array(
            'ok' => true,
            'dryRun' => true,
            'week' => $week,
            'texts' => array_keys($texts),
            'reach' => $reach,
            'sent' => 0,
        ), 200);
    }

    if ((string) get_option(HUHS_PUSH_DIGEST_WEEK_OPTION, '') === $week) {
        return new WP_REST_Response(array(
            'ok' => true,
            'duplicate' => true,
            'week' => $week,
            'reach' => $reach,
            'sent' => 0,
        ), 200);
    }

    $sent = huhs_push_send_localized($texts, array(
        'type' => 'digest',
        'kind' => 'digest',
        'week' => $week,
    ));
    update_option(HUHS_PUSH_DIGEST_WEEK_OPTION, $week, false);

    return new WP_REST_Response(array(
        'ok' => true,
        'week' => $week,
        'texts' => array_keys($texts),
        'reach' => $reach,
        'sent' => (int) $sent,
    ), 200);
}

/**
 * Kedvenc-azonosítók tisztítása (2.14.9).
 *
 * Elfogad intet, számot szövegként és `{id: …}` objektumot is (a tartalom-meta
 * alakja JSON-tól függően változó), kiejti a érvényteleneket, egyszer számol, és
 * plafont tart — így egy elrontott kliens-payload nem hizlalja a token-rekordot.
 */
function huhs_push_favorite_ids($raw, $limit = 60)
{
    if (!is_array($raw)) return array();
    $ids = array();
    foreach ($raw as $entry) {
        if (is_array($entry)) {
            $entry = $entry['id'] ?? null;
        }
        $id = (int) $entry;
        if ($id <= 0) continue;
        $ids[$id] = true;
        if (count($ids) >= $limit) break;
    }
    return array_keys($ids);
}

/** A küldéshez tartozó DJ-/szervező-azonosítók (ha a payload megadja). */
function huhs_push_content_follow_ids($data)
{
    if (!is_array($data)) return array();
    return array_values(array_unique(array_merge(
        huhs_push_favorite_ids($data['artists'] ?? array()),
        huhs_push_favorite_ids($data['organizers'] ?? array())
    )));
}

/**
 * Egy TARTALOM (esemény/kiadvány) követendő azonosítói — mért meta-kulcsokkal:
 * az `artists` JSON-tömb (mindkét típusnál), a szervező az `organizer_id`.
 */
function huhs_push_content_follow_targets($post)
{
    if (!$post || empty($post->ID)) return array('artists' => array(), 'organizers' => array());
    $artists = json_decode((string) get_post_meta($post->ID, 'artists', true), true);
    $organizer = (int) get_post_meta($post->ID, 'organizer_id', true);
    return array(
        'artists' => huhs_push_favorite_ids(is_array($artists) ? $artists : array()),
        'organizers' => $organizer > 0 ? array($organizer) : array(),
    );
}

/**
 * MEGOSZTOTT TARTALOM-LINK FELOLDÁSA (2.14.10).
 *
 * MIÉRT: a megosztott link lehet **rövidlink** (csak azonosító: `?p=12505`) vagy
 * **szép permalink** (csak slug: `/events/hard-base-classic…/`, `/releases/…`,
 * `/djs/…`, illetve a hírnél `/2026/09/26/…`). Az app adatlapjai **azonosító**
 * alapján nyílnak, ezért a linket **típusra és azonosítóra** kell fordítani —
 * ezt végzi ez a végpont (a mérés szerint a hír `post`, a többi saját típus).
 *
 * ⚠️ Csak OLVAS és csak **publikált** tartalmat ad vissza; ismeretlen azonosítóra
 * vagy slugra `404`-et (`WP_Error`), hogy az app a főoldalt mutassa.
 */
function huhs_resolve_content_target(WP_REST_Request $request)
{
    $types = array(
        'huhs_event' => 'event',
        'huhs_release' => 'release',
        'huhs_artist' => 'artist',
        'post' => 'news',
    );
    $id = (int) ($request->get_param('p') ?? 0);
    $slug = sanitize_title((string) ($request->get_param('slug') ?? ''));

    $post = null;
    if ($id > 0) {
        $candidate = get_post($id);
        if ($candidate && isset($types[$candidate->post_type]) && $candidate->post_status === 'publish') {
            $post = $candidate;
        }
    } elseif ($slug !== '') {
        $found = get_posts(array(
            'name' => $slug,
            'post_type' => array_keys($types),
            'post_status' => 'publish',
            'posts_per_page' => 1,
            'fields' => 'all',
        ));
        if (!empty($found[0])) $post = $found[0];
    }

    if (!$post) {
        return new WP_Error('not_found', 'Nincs ilyen tartalom.', array('status' => 404));
    }

    return new WP_REST_Response(array(
        'ok' => true,
        'type' => $types[$post->post_type],
        'id' => (int) $post->ID,
        'title' => html_entity_decode(wp_strip_all_tags((string) get_the_title($post)), ENT_QUOTES | ENT_HTML5, 'UTF-8'),
        'url' => (string) get_permalink($post),
    ), 200);
}

function huhs_push_base64url($value)
{
    return rtrim(strtr(base64_encode($value), '+/', '-_'), '=');
}

function huhs_push_service_account()
{
    $account = get_option(HUHS_PUSH_SERVICE_ACCOUNT_OPTION, array());
    return is_array($account) ? $account : array();
}

function huhs_push_access_token()
{
    $cached = get_transient('huhs_firebase_access_token');
    if (is_string($cached) && $cached !== '') return $cached;

    $account = huhs_push_service_account();
    $project = sanitize_key((string) ($account['project_id'] ?? ''));
    $client_email = sanitize_email((string) ($account['client_email'] ?? ''));
    $private_key = (string) ($account['private_key'] ?? '');
    if (!$project || !$client_email || !$private_key || !function_exists('openssl_sign')) return '';

    $private_key = str_replace('\\n', "\n", $private_key);
    $now = time();
    $header = huhs_push_base64url(wp_json_encode(array('alg' => 'RS256', 'typ' => 'JWT')));
    $claims = huhs_push_base64url(wp_json_encode(array(
        'iss' => $client_email,
        'scope' => 'https://www.googleapis.com/auth/firebase.messaging',
        'aud' => 'https://oauth2.googleapis.com/token',
        'iat' => $now,
        'exp' => $now + 3600,
    )));
    $unsigned = $header . '.' . $claims;
    if (!openssl_sign($unsigned, $signature, $private_key, OPENSSL_ALGO_SHA256)) return '';

    $response = wp_remote_post('https://oauth2.googleapis.com/token', array(
        'timeout' => 15,
        'body' => array(
            'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
            'assertion' => $unsigned . '.' . huhs_push_base64url($signature),
        ),
    ));
    if (is_wp_error($response)) return '';

    $body = json_decode(wp_remote_retrieve_body($response), true);
    $access_token = (string) ($body['access_token'] ?? '');
    $expires_in = max(300, absint($body['expires_in'] ?? 3600) - 120);
    if ($access_token !== '') set_transient('huhs_firebase_access_token', $access_token, $expires_in);
    return $access_token;
}

function huhs_firebase_firestore_access_token()
{
    $cached = get_transient('huhs_firestore_access_token');
    if (is_string($cached) && $cached !== '') return $cached;
    $account = huhs_push_service_account();
    $client_email = sanitize_email((string) ($account['client_email'] ?? ''));
    $private_key = str_replace('\\n', "\n", (string) ($account['private_key'] ?? ''));
    if (!$client_email || !$private_key || !function_exists('openssl_sign')) return '';
    $now = time();
    $header = huhs_push_base64url(wp_json_encode(array('alg' => 'RS256', 'typ' => 'JWT')));
    $claims = huhs_push_base64url(wp_json_encode(array(
        'iss' => $client_email,
        'scope' => 'https://www.googleapis.com/auth/datastore',
        'aud' => 'https://oauth2.googleapis.com/token',
        'iat' => $now,
        'exp' => $now + 3600,
    )));
    $unsigned = $header . '.' . $claims;
    if (!openssl_sign($unsigned, $signature, $private_key, OPENSSL_ALGO_SHA256)) return '';
    $response = wp_remote_post('https://oauth2.googleapis.com/token', array(
        'timeout' => 15,
        'body' => array(
            'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
            'assertion' => $unsigned . '.' . huhs_push_base64url($signature),
        ),
    ));
    if (is_wp_error($response)) return '';
    $body = json_decode(wp_remote_retrieve_body($response), true);
    $access_token = (string) ($body['access_token'] ?? '');
    $expires_in = max(300, absint($body['expires_in'] ?? 3600) - 120);
    if ($access_token !== '') set_transient('huhs_firestore_access_token', $access_token, $expires_in);
    return $access_token;
}

/**
 * Queue the Play product sync outside the editor request.
 *
 * The sync fetches an OAuth token from Google and then writes to Firestore, so
 * running it from save_post kept the editor waiting for two network round trips
 * (each with a 15 second timeout) the editor does not need to see.
 */
function huhs_schedule_label_product_sync($release_id)
{
    $release_id = absint($release_id);
    if (!$release_id) return false;
    if (!wp_next_scheduled('huhs_label_product_sync', array($release_id))) {
        if (false === wp_schedule_single_event(time() + 2, 'huhs_label_product_sync', array($release_id))) {
            // Scheduling must not be the reason a product sync is lost.
            return huhs_queue_label_product_sync($release_id);
        }
    }
    // Non-blocking loopback request: the job runs now, not at the next cron tick.
    if (function_exists('spawn_cron')) spawn_cron();
    return true;
}

add_action('huhs_label_product_sync', function ($release_id) {
    huhs_queue_label_product_sync($release_id);
}, 10, 1);

function huhs_queue_label_product_sync($release_id, $retry_attempt = 1)
{
    $account = huhs_push_service_account();
    $project = sanitize_key((string) ($account['project_id'] ?? ''));
    $access_token = huhs_firebase_firestore_access_token();
    if (!$project || !$access_token) return false;
    $request_id = 'release-' . absint($release_id) . '-' . time() . '-' . wp_generate_password(8, false, false);
    $response = wp_remote_post(
        'https://firestore.googleapis.com/v1/projects/' . rawurlencode($project) . '/databases/hungarian-hardstyle/documents/label_product_sync_requests?documentId=' . rawurlencode($request_id),
        array(
            'timeout' => 15,
            'headers' => array(
                'Authorization' => 'Bearer ' . $access_token,
                'Content-Type' => 'application/json',
            ),
            'body' => wp_json_encode(array('fields' => array(
                'releaseId' => array('integerValue' => (string) absint($release_id)),
                'createdAt' => array('timestampValue' => gmdate('c')),
            )), JSON_UNESCAPED_SLASHES),
        )
    );
    $code = is_wp_error($response) ? 0 : (int) wp_remote_retrieve_response_code($response);
    if ($code < 200 || $code >= 300) {
        error_log('HUHS label product sync queue failed for release ' . absint($release_id) . ' (HTTP ' . $code . ')');
        huhs_schedule_label_product_sync_retry($release_id, $retry_attempt);
        return false;
    }
    return true;
}

function huhs_schedule_label_product_sync_retry($release_id, $attempt = 1)
{
    $release_id = absint($release_id);
    $attempt = absint($attempt);
    if (!$release_id || $attempt > 4) return;
    $delays = array(30, 90, 240, 600);
    $hook = 'huhs_label_product_sync_retry';
    if (!wp_next_scheduled($hook, array($release_id, $attempt))) {
        wp_schedule_single_event(time() + $delays[$attempt - 1], $hook, array($release_id, $attempt));
    }
}

add_action('huhs_label_product_sync_retry', function ($release_id, $attempt) {
    huhs_queue_label_product_sync($release_id, absint($attempt) + 1);
}, 10, 2);

function huhs_schedule_release_push_retry($release_id, $attempt = 1)
{
    $release_id = absint($release_id);
    $attempt = absint($attempt);
    if (!$release_id || $attempt > 4) return;
    $delays = array(30, 90, 240, 600);
    $hook = 'huhs_release_push_retry';
    if (!wp_next_scheduled($hook, array($release_id, $attempt))) {
        wp_schedule_single_event(time() + $delays[$attempt - 1], $hook, array($release_id, $attempt));
    }
}

add_action('huhs_release_push_retry', function ($release_id, $attempt) {
    huhs_push_publish_content($release_id, 'huhs_release', absint($attempt) + 1);
}, 10, 2);

/**
 * How long one request may spend talking to FCM, and how many follow-up runs
 * the chain may take. Both are safety rails, not tuning knobs.
 *
 * ⚠️ 2.14.14 — MIÉRT 15 → **60 másodperc** (éles mérés, 2026-10-02): a
 * 2.14.13-ban felvett diagnosztika (`push_limits=…`) kimutatta, hogy a szerver
 * **`max_exec=600`** — vagyis a 15 másodperces keret nem a hoszting korlátja
 * miatt volt ilyen rövid, hanem a régi (a szerkesztőt várakoztató) örökség
 * miatt. A hír-push szövege **cron-körben** készül (a szerkesztő csak ütemez),
 * ezért a hosszabb kör senkit nem blokkol:
 *   - 50 párhuzamos hívással a mért batch-idő ~1,7 s → ~1030 eszköz ≈ 36 s;
 *   - így a lista **egyetlen körben** kimegy (~2 perc helyett ~40 másodperc),
 *     és nem kell 5-6 láncszemre várni.
 * A **látogatót** terhelő biztonsági háló kerete változatlanul rövid
 * (`HUHS_PUSH_RESUME_BUDGET` = 5 s), tehát ez a döntés őt nem érinti.
 */
if (!defined('HUHS_PUSH_TIME_BUDGET')) define('HUHS_PUSH_TIME_BUDGET', 60);
if (!defined('HUHS_PUSH_MAX_RUNS')) define('HUHS_PUSH_MAX_RUNS', 40);
// A hir-ertesitesnek nem volt sem jelzese, sem ujraprobaja: ha az elso kuldes
// nem ment at, a hir neman elveszett. Ezert korlatozott ujraprobalkozas van.
if (!defined('HUHS_PUSH_NEWS_MAX_ATTEMPTS')) define('HUHS_PUSH_NEWS_MAX_ATTEMPTS', 3);
// Egyszerre ennyi FCM hivas fut (curl_multi). Eles meres: 15-tel egy 15
// masodperces kor ~240 eszkozt vitt el, es a Firebase egyetlen hibat sem adott
// vissza, ezert 25-re emeltuk (meg mindig boven a kvotain belul).
//
// ⚠️ 2.14.13 — MIÉRT 50 (éles mérés, 2026-10-01): a hír-push 1028 eszközt
// **~2 perc** alatt ért el (6 kör), mert egy 15 másodperces kör 25 párhuzamos
// hívással csak ~200-225 eszközt vitt el — a mért batch-idő ~1,7 s, tehát nem a
// sávszélesség, hanem az FCM oda-vissza út a szűk keresztmetszet. A kétszeres
// párhuzamosság feleannyi körbe viszi ugyanazt a listát (a kérés HOSSZÁT nem
// növeli, csak egyszerre több hívás fut), ezért a kifutás rövidebb lesz.
if (!defined('HUHS_PUSH_CONCURRENCY')) define('HUHS_PUSH_CONCURRENCY', 50);
// Egy FCM hivas felso idokorlatja a parhuzamos uton (a soros ut 15-ot hasznal).
if (!defined('HUHS_PUSH_HTTP_TIMEOUT')) define('HUHS_PUSH_HTTP_TIMEOUT', 10);
// A biztonsagi háló (lasd huhs_push_resume_pending_job): ha a cron-lanc elakad,
// egy beérkezo keres viszi tovabb a kort. Ez rovid, hogy a latogato se varjon
// sokaig, ha eppen o fizeti meg.
if (!defined('HUHS_PUSH_RESUME_BUDGET')) define('HUHS_PUSH_RESUME_BUDGET', 5);
// Ennyi masodpercnel surubben nem indul uj kör ugyanarra a feladatra.
if (!defined('HUHS_PUSH_RESUME_GAP')) define('HUHS_PUSH_RESUME_GAP', 10);
// Egy feladaton EGYSZERRE csak egy kör dolgozhat. Ez a foglalas addig el, es ha
// a folyamat elhal, magatol lejar (nem blokkolja orokre a kuldést).
if (!defined('HUHS_PUSH_JOB_LOCK_TIMEOUT')) define('HUHS_PUSH_JOB_LOCK_TIMEOUT', 60);

/**
 * Az utolso kuldes eredmenye.
 *
 * Enelkul a nem sikerult kuldes LATHATATLAN volt: a "nem ment ki semmi"
 * pontosan ugyanugy nezett ki, mint a "meg kuldi". Innen derul ki, hogy a
 * Firebase elutasította-e az uzeneteket, vagy el sem indult a kuldes.
 */
function huhs_push_record_result($result)
{
    $result['time'] = time();
    update_option('huhs_push_last_result', $result, false);
    return $result;
}

function huhs_push_last_result()
{
    $result = get_option('huhs_push_last_result', array());
    return is_array($result) ? $result : array();
}

/** Az utolso FCM hibavalasz (HTTP kod + status), hogy a hiba oka kideruljjon. */
function huhs_push_last_http_error($set = null)
{
    static $error = array('code' => 0, 'status' => '');
    if (is_array($set)) $error = $set;
    return $error;
}

/**
 * A push allapota a titkos diagnosztikai fejlecbe.
 *
 * Csak a huhs_diag=huhs-boot-probe-2026 markerrel latszik, es a statuszt
 * szurjuk, hogy fejlec-injektalas semmikepp ne tortenhessen.
 */
function huhs_push_diag_summary()
{
    $result = huhs_push_last_result();
    if (!$result) return 'push_last=none';

    $parts = array(
        'push_last=' . (string) ($result['type'] ?? '?') . '/' . (string) ($result['reason'] ?? '?'),
        'recipients=' . (int) ($result['recipients'] ?? 0),
        'processed=' . (int) ($result['processed'] ?? 0),
        'sent=' . (int) ($result['sent'] ?? 0),
        'failed=' . (int) ($result['failed'] ?? 0),
        'dead=' . (int) ($result['dead'] ?? 0),
        'http=' . (int) ($result['code'] ?? 0),
    );
    $status = preg_replace('/[^A-Za-z0-9_]/', '', (string) ($result['status'] ?? ''));
    if ($status !== '') $parts[] = 'status=' . $status;
    $time = (int) ($result['time'] ?? 0);
    if ($time > 0) $parts[] = 'at=' . wp_date('H:i', $time);

    return implode(' ', $parts);
}

/**
 * A folytato kor allapota — a legfontosabb hianyzo informacio.
 *
 * Ha egy kuldés felbeszakad, eddig nem lehetett megkulonboztetni azt, hogy a
 * kovetkezo kor NINCS betervezve, attol, hogy be van tervezve, de nem fut le
 * (mert a WP-Cron csak akkor lep, ha valami kérést indít). Ez a sor mindkettot
 * megmutatja, plusz azt, hogy egyaltalan van-e lejart cron-esemeny a site-on.
 */
function huhs_push_diag_jobs()
{
    $crons = function_exists('_get_cron_array') ? _get_cron_array() : array();
    if (!is_array($crons)) $crons = array();

    $now = time();
    $overdue = 0;
    $jobs = array();
    foreach ($crons as $timestamp => $hooks) {
        if ((int) $timestamp <= $now) $overdue++;
        if (!is_array($hooks) || !isset($hooks['huhs_push_continue'])) continue;
        foreach ((array) $hooks['huhs_push_continue'] as $event) {
            $key = (string) ($event['args'][0] ?? '');
            $job = get_option('huhs_push_job_' . $key, null);
            $jobs[] = ((int) $timestamp <= $now ? 'DUE' : 'in' . ((int) $timestamp - $now) . 's')
                . '/runs=' . (is_array($job) ? (int) ($job['runs'] ?? 0) : -1)
                . '/offset=' . (is_array($job) ? (int) ($job['offset'] ?? 0) : -1);
        }
    }

    return 'cron_overdue=' . $overdue
        . ' push_job=' . ($jobs ? implode(',', $jobs) : 'none')
        . ' push_active=' . huhs_push_diag_active_job($now);
}

/**
 * Az aktiv feladat allapota.
 *
 * Ez a legfontosabb megkulonboztetes: ha az aktiv feladat MEGVAN, de cron-esemeny
 * nincs, akkor a lanc elakadt (pontosan ez tortent elesben: `push_job=none`,
 * mikozben a feladat ott maradt) — a biztonsagi háló viszont ilyenkor is viszi
 * tovabb.
 */
function huhs_push_diag_active_job($now)
{
    $active = (string) get_option('huhs_push_active_job', '');
    if ($active === '') return 'none';

    $job = get_option('huhs_push_job_' . $active, null);
    if (!is_array($job)) return 'no-data';

    $last = (int) ($job['last_run'] ?? 0);
    return 'runs=' . (int) ($job['runs'] ?? 0)
        . '/offset=' . (int) ($job['offset'] ?? 0)
        . '/age=' . ($last > 0 ? max(0, (int) $now - $last) . 's' : '?');
}

/**
 * Work out who should receive this push.
 *
 * This is separated from sending because a broadcast to a large install base
 * does not fit into one request: the recipient list has to be reproducible when
 * the delivery is resumed later.
 */
function huhs_push_recipients($tokens, $data, $language = '')
{
    $type = (string) ($data['type'] ?? 'custom');
    // Nyelvi szűrő (2.14.6): üres érték = mindenki (a régi viselkedés).
    $only = $language === '' ? '' : huhs_push_normalize_language($language);
    $recipients = array();
    foreach ((array) $tokens as $key => $record) {
        if (!is_array($record)) continue;
        $token = (string) ($record['token'] ?? '');
        if ($token === '') continue;
        if ($only !== '' && huhs_push_normalize_language($record['language'] ?? '') !== $only) continue;
        if (array_key_exists('enabled', $record) && !$record['enabled']) continue;
        if ($type === 'news' && array_key_exists('news', $record) && !$record['news']) continue;
        if ($type === 'event' && array_key_exists('events', $record) && !$record['events']) continue;
        if ($type === 'release' && array_key_exists('releases', $record) && !$record['releases']) continue;
        // ⚠️ A `reminders` kapu KIZÁRÓLAG az esemény-emlékeztetőre vonatkozik
        // (`kind = reminder`). 2.14.8 előtt minden `kind`-os küldést szűrt, ezért
        // egy másik „kind" (pl. a heti összefoglaló) némán kimaradt volna azoknál,
        // akik az emlékeztetőt kikapcsolták.
        if (($data['kind'] ?? '') === 'reminder' && array_key_exists('reminders', $record) && !$record['reminders']) continue;
        if ($type === 'digest' && array_key_exists('digest', $record) && !$record['digest']) continue;
        // Szavazás/játék (2.14.11). A mai kliensek ezeket a kulcsokat NEM
        // küldik, ezért a szűrő csak akkor hat, ha egy jövőbeli kliens bevezeti
        // (pontosan a `digest` mintájára) — addig mindenki megkapja, aki az
        // értesítéseket egyáltalán nem kapcsolta ki. A nyereményjáték és a
        // GYÍK-játék ugyanazt a kapcsolót használja (`games`).
        if ($type === 'poll' && array_key_exists('polls', $record) && !$record['polls']) continue;
        if ($type === 'vote' && array_key_exists('votes', $record) && !$record['votes']) continue;
        if (($type === 'game' || $type === 'quiz') && array_key_exists('games', $record) && !$record['games']) continue;
        // Kedvenc-alapú célzás (2.14.9): CSAK akkor szűkít, ha a küldés megmondja
        // a tartalom szereplőit ÉS a rekordban van kedvenc. Aki még nem küldött
        // kedvenceket (minden 381 előtti kliens), az változatlanul mindent kap.
        $wanted = huhs_push_content_follow_ids($data);
        if ($wanted) {
            $follows = array_merge(
                huhs_push_favorite_ids($record['artists'] ?? array()),
                huhs_push_favorite_ids($record['organizers'] ?? array())
            );
            if ($follows && !array_intersect($follows, $wanted)) continue;
        }
        $recipients[$key] = $token;
    }
    return $recipients;
}

/**
 * Send one message and classify the answer.
 *
 * 'sent'   — accepted by FCM
 * 'dead'   — FCM says this token can never work again (app uninstalled or the
 *            token was refreshed); keeping it would slow down every later push
 * 'failed' — anything else, worth another try
 */
function huhs_push_message_body($token, $title, $body, $data)
{
    return wp_json_encode(array('message' => array(
        'token' => (string) $token,
        'notification' => array('title' => (string) $title, 'body' => (string) $body),
        'data' => array_map('strval', is_array($data) ? $data : array()),
        'android' => array('priority' => 'high'),
    )), JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
}

/**
 * FCM valasz besorolasa — EGYETLEN helyen.
 *
 * A parhuzamos es a soros kuldes ugyanezt hasznalja. Ez szandekos: korabban a
 * nyilvanos cache engedelylistaja tobb helyen elt, es pont ez okozott hibát.
 */
function huhs_push_classify_response($code, $body)
{
    $code = (int) $code;
    if ($code >= 200 && $code < 300) return 'sent';

    $payload = json_decode((string) $body, true);
    $status = is_array($payload) ? (string) ($payload['error']['status'] ?? '') : '';
    $error_code = is_array($payload) ? (string) ($payload['error']['details'][0]['errorCode'] ?? '') : '';
    if (404 === $code || 'NOT_FOUND' === $status || 'UNREGISTERED' === $error_code) return 'dead';

    // Az elso hiba oka: enelkul csak annyit lehetett tudni, hogy "nem ment ki".
    huhs_push_last_http_error(array('code' => $code, 'status' => $status !== '' ? $status : $error_code));
    return 'failed';
}

function huhs_push_send_one($token, $project, $access_token, $title, $body, $data)
{
    $response = wp_remote_post(
        'https://fcm.googleapis.com/v1/projects/' . rawurlencode($project) . '/messages:send',
        array(
            'timeout' => 15,
            'headers' => array(
                'Authorization' => 'Bearer ' . $access_token,
                'Content-Type' => 'application/json',
            ),
            'body' => huhs_push_message_body($token, $title, $body, $data),
        )
    );

    if (is_wp_error($response)) {
        huhs_push_last_http_error(array('code' => 0, 'status' => 'transport:' . $response->get_error_code()));
        return 'failed';
    }
    return huhs_push_classify_response(
        wp_remote_retrieve_response_code($response),
        wp_remote_retrieve_body($response)
    );
}

/** A tartalek ut: egyszerre egy eszkoz. Akkor fut, ha nincs curl_multi. */
function huhs_push_deliver_serial($recipients, $title, $body, $data, $project, $access_token, $budget = HUHS_PUSH_TIME_BUDGET)
{
    $sent = 0;
    $failed = 0;
    $processed = 0;
    $dead = array();
    $deadline = microtime(true) + $budget;

    foreach ($recipients as $key => $token) {
        // The first recipient is always attempted: a run that made no progress
        // would leave the follow-up chain stuck on the same offset forever.
        if ($processed > 0 && microtime(true) >= $deadline) break;

        $outcome = huhs_push_send_one($token, $project, $access_token, $title, $body, $data);
        $processed++;
        if ('sent' === $outcome) {
            $sent++;
        } elseif ('dead' === $outcome) {
            $dead[] = $key;
        } else {
            $failed++;
        }
    }

    return array(
        'sent' => $sent,
        'failed' => $failed,
        'processed' => $processed,
        'dead' => $dead,
        'remaining' => count($recipients) - $processed,
    );
}

/**
 * Parhuzamos kuldes curl_multi-val.
 *
 * Miert kell: az FCM-hez menő hivas eszkozonkent egy-egy teljes oda-vissza ut,
 * es a meres szerint ez a szuk keresztmetszet. 900 eszkoz sorban ~4-6 perc volt
 * (a hir ertesites ennyivel a kozzetetel utan erkezett meg), parhuzamosan pedig
 * nehany tiz masodperc.
 *
 * FONTOS: a kort KOTEGEKENT zarjuk le. Ha a hataridoben felbehagynank, a
 * feldolgozott elemek nem lennenek pontos elotag, es a folytato kor offsetje
 * kihagyna vagy megismetelne eszkozoket. Az elso koteget mindig lefuttatjuk,
 * hogy egy kor mindig haladjon.
 */
function huhs_push_deliver_parallel($recipients, $title, $body, $data, $project, $access_token, $budget = HUHS_PUSH_TIME_BUDGET)
{
    $url = 'https://fcm.googleapis.com/v1/projects/' . rawurlencode($project) . '/messages:send';
    $sent = 0;
    $failed = 0;
    $transport = 0;
    $processed = 0;
    $dead = array();
    $deadline = microtime(true) + $budget;

    foreach (array_chunk($recipients, HUHS_PUSH_CONCURRENCY, true) as $batch) {
        if ($processed > 0 && microtime(true) >= $deadline) break;

        $multi = curl_multi_init();
        $handles = array();
        foreach ($batch as $key => $token) {
            $handle = curl_init($url);
            curl_setopt_array($handle, array(
                CURLOPT_POST => true,
                CURLOPT_RETURNTRANSFER => true,
                CURLOPT_HTTPHEADER => array(
                    'Authorization: Bearer ' . $access_token,
                    'Content-Type: application/json',
                ),
                CURLOPT_POSTFIELDS => huhs_push_message_body($token, $title, $body, $data),
                CURLOPT_CONNECTTIMEOUT => 5,
                CURLOPT_TIMEOUT => HUHS_PUSH_HTTP_TIMEOUT,
                // A kotegek ugyanazt a kapcsolatot hasznaljak ujra.
                CURLOPT_TCP_KEEPALIVE => 1,
            ));
            curl_multi_add_handle($multi, $handle);
            $handles[$key] = $handle;
        }

        $running = null;
        do {
            $status = curl_multi_exec($multi, $running);
            if ($running > 0) curl_multi_select($multi, 1.0);
        } while ($running > 0 && CURLM_OK === $status);

        foreach ($handles as $key => $handle) {
            $code = (int) curl_getinfo($handle, CURLINFO_RESPONSE_CODE);
            if (0 === $code) {
                huhs_push_last_http_error(array('code' => 0, 'status' => 'transport:' . curl_errno($handle)));
                $failed++;
                $transport++;
            } else {
                $outcome = huhs_push_classify_response($code, (string) curl_multi_getcontent($handle));
                if ('sent' === $outcome) {
                    $sent++;
                } elseif ('dead' === $outcome) {
                    $dead[] = $key;
                } else {
                    $failed++;
                }
            }
            curl_multi_remove_handle($multi, $handle);
            curl_close($handle);
            $processed++;
        }
        curl_multi_close($multi);
    }

    return array(
        'sent' => $sent,
        'failed' => $failed,
        'transport' => $transport,
        'processed' => $processed,
        'dead' => $dead,
        'remaining' => count($recipients) - $processed,
    );
}

/**
 * Send to as many recipients as fit into the time budget.
 *
 * Returns how many the run got through so a follow-up can pick up exactly
 * there, plus the dead tokens the caller should forget.
 */
function huhs_push_deliver_slice($recipients, $title, $body, $data, $project, $access_token, $budget = HUHS_PUSH_TIME_BUDGET)
{
    // A `HUHS_PUSH_FORCE_SERIAL` kizarolag a teszteké: a párhuzamos út curl-t
    // használ, amit a stubolt WordPress-környezet nem tud fogni. Elesben nincs
    // bekapcsolva, ezért a viselkedés változatlan.
    $force_serial = defined('HUHS_PUSH_FORCE_SERIAL') && HUHS_PUSH_FORCE_SERIAL;
    if (!$force_serial && function_exists('curl_multi_init') && function_exists('curl_init')) {
        $result = huhs_push_deliver_parallel($recipients, $title, $body, $data, $project, $access_token, $budget);
        // Ha a parhuzamos ut egyetlen hivast sem tudott elinditani (nincs curl
        // a hosztingon, vagy minden kapcsolat elhalt), akkor a bevalt soros utra
        // esunk vissza. Igy a legrosszabb eset a mai mukodes, nem rosszabb.
        if (0 === $result['sent'] && $result['transport'] > 0 && $result['failed'] === $result['processed']) {
            error_log('HUHS push: the parallel path could not reach FCM, falling back to the serial one.');
            return huhs_push_deliver_serial($recipients, $title, $body, $data, $project, $access_token, $budget);
        }
        return $result;
    }
    return huhs_push_deliver_serial($recipients, $title, $body, $data, $project, $access_token, $budget);
}

/**
 * Forget tokens FCM reported as permanently invalid.
 *
 * A single write for the whole batch, because the token list is one option and
 * rewriting it once per dead token would be pointless traffic.
 */
function huhs_push_prune_tokens($keys)
{
    $keys = array_unique((array) $keys);
    if (!$keys) return 0;

    $tokens = get_option(HUHS_PUSH_TOKENS_OPTION, array());
    if (!is_array($tokens)) return 0;

    $removed = 0;
    foreach ($keys as $key) {
        if (isset($tokens[$key])) {
            unset($tokens[$key]);
            $removed++;
        }
    }
    if ($removed > 0) update_option(HUHS_PUSH_TOKENS_OPTION, $tokens, false);
    return $removed;
}

/**
 * Hand the rest of a broadcast to a scheduled follow-up and return immediately.
 */
function huhs_push_schedule_job($job)
{
    $dead = is_array($job['dead'] ?? null) ? $job['dead'] : array();

    if ((int) ($job['runs'] ?? 0) > HUHS_PUSH_MAX_RUNS) {
        huhs_push_prune_tokens($dead);
        error_log('HUHS push: giving up after ' . HUHS_PUSH_MAX_RUNS . ' runs, the token list may be unhealthy.');
        return false;
    }

    $key = wp_generate_password(12, false, false);
    $job['last_run'] = time();
    update_option('huhs_push_job_' . $key, $job, false);
    // Ezt a kulcsot keresi a biztonsagi haló (huhs_push_resume_pending_job).
    update_option('huhs_push_active_job', $key, false);

    // ⚠️ 2.14.13: a folytatás **1 másodpercre** (korábban 2) — éles mérés szerint
    // a hír-push kifutása ~2 perc volt 6 körrel, és ebből körönként ~3-5 másodperc
    // a várakozás volt. A küldést ez nem teszi sűrűbbé (egy kör 15 másodpercig
    // dolgozik), csak a körök közötti holtidőt rövidíti.
    if (false === wp_schedule_single_event(time() + 1, 'huhs_push_continue', array($key))) {
        // Nem toroljuk a feladatot: a biztonsagi haló így is folytatni tudja.
        error_log('HUHS push: could not schedule the follow-up run, the resume hook will take over.');
        return false;
    }

    // A non-blocking loopback only helps when this runs outside cron. Inside a
    // cron request WordPress guards spawn_cron() with DOING_CRON and it does
    // nothing, so the follow-up is picked up by the next request that triggers
    // WP-Cron (wp_cron() is hooked to init, and the app itself keeps making
    // requests). That is seconds on a live site, not minutes.
    if (function_exists('spawn_cron')) spawn_cron();
    return true;
}

add_action('huhs_push_continue', 'huhs_push_continue', 10, 2);
function huhs_push_continue($job_key, $budget = HUHS_PUSH_TIME_BUDGET)
{
    $job_key = preg_replace('/[^A-Za-z0-9]/', '', (string) $job_key);
    if ($job_key === '') return;

    $option = 'huhs_push_job_' . $job_key;
    $job = get_option($option, null);
    if (!is_array($job)) {
        // NEMA VEG: pontosan ez a hiba allitotta le elesben a kuldesi lancot
        // ugy, hogy kozben semmi nem jelzett rola.
        error_log('HUHS push: the follow-up run found no job data (' . $job_key . '), stopping.');
        if ((string) get_option('huhs_push_active_job', '') === $job_key) {
            delete_option('huhs_push_active_job');
        }
        return;
    }

    // ── VERSENYHELYZET ZARASA (éles hibajelzés: „némelyik push kétszer megy ki") ──
    //
    // Ugyanezt a feladatot a cron-esemény ÉS a biztonsági háló (minden kérés
    // `shutdown`-jában) is futtathatja. A háló abból következtetett, hogy a lánc
    // elakadt, hogy a `last_run` régi — a `last_run` viszont csak a kör VÉGÉN
    // íródott, egy kör pedig a 15 s-os keret miatt hosszabb, mint a 10 s-os
    // küszöb. Így egy ÉPPEN FUTÓ kör „elakadtnak" látszott, és a háló
    // ugyanarról az offsetről indított egy második kört: az éppen küldött
    // eszközök megkapták ugyanazt a push-t kétszer.
    //
    // Két védelem: (1) a kör ELEJÉN frissítjük a `last_run`-t (szívverés), így a
    // futó kör nem tűnik elakadtnak; (2) egy atomikus foglalás, amit a cron és a
    // háló is tiszteletben tart — egyszerre egy kör dolgozhat a feladaton.
    $lock_option = 'huhs_push_job_lock_' . $job_key;
    $lock = (int) get_option($lock_option, 0);
    if ($lock > time() - HUHS_PUSH_JOB_LOCK_TIMEOUT) {
        return;
    }
    update_option($lock_option, time(), false);
    $job['last_run'] = time();
    update_option($option, $job, false);

    $title = (string) ($job['title'] ?? '');
    $body = (string) ($job['body'] ?? '');
    $data = is_array($job['data'] ?? null) ? $job['data'] : array();
    $offset = max(0, (int) ($job['offset'] ?? 0));
    $dead = is_array($job['dead'] ?? null) ? $job['dead'] : array();
    $runs = max(0, (int) ($job['runs'] ?? 0));

    $account = huhs_push_service_account();
    $project = sanitize_key((string) ($account['project_id'] ?? ''));
    $access_token = huhs_push_access_token();
    if (!$project || !$access_token) {
        error_log('HUHS push: the follow-up run stopped, the service account or access token is missing.');
        delete_option($option);
        delete_option($lock_option);
        if ((string) get_option('huhs_push_active_job', '') === $job_key) {
            delete_option('huhs_push_active_job');
        }
        huhs_push_prune_tokens($dead);
        return;
    }

    $tokens = get_option(HUHS_PUSH_TOKENS_OPTION, array());
    $recipients = huhs_push_recipients(is_array($tokens) ? $tokens : array(), $data);
    $remaining = array_slice($recipients, $offset, null, true);

    $result = huhs_push_deliver_slice($remaining, $title, $body, $data, $project, $access_token, $budget);
    $dead = array_merge($dead, $result['dead']);

    // Minden kor lathatova valik: enelkul egy elakadt lanc ugyanugy nez ki,
    // mint egy el sem indult kuldes.
    $error = huhs_push_last_http_error();
    huhs_push_record_result(array(
        'type' => (string) ($data['type'] ?? 'custom'),
        'reason' => $result['sent'] > 0 ? 'ok' : 'undelivered',
        'recipients' => count($recipients),
        'processed' => $result['processed'],
        'sent' => $result['sent'],
        'failed' => $result['failed'],
        'dead' => count($dead),
        'code' => (int) ($error['code'] ?? 0),
        'status' => (string) ($error['status'] ?? ''),
        'runs' => $runs + 1,
    ));
    error_log(sprintf(
        'HUHS push run %d: %s offset=%d/%d processed=%d sent=%d failed=%d dead=%d http=%d/%s',
        $runs + 1,
        (string) ($data['type'] ?? 'custom'),
        $offset,
        count($recipients),
        $result['processed'],
        $result['sent'],
        $result['failed'],
        count($dead),
        (int) ($error['code'] ?? 0),
        (string) ($error['status'] ?? '')
    ));

    if ($result['remaining'] > 0) {
        update_option($option, array(
            'title' => $title,
            'body' => $body,
            'data' => $data,
            'offset' => $offset + $result['processed'],
            'dead' => $dead,
            'runs' => $runs + 1,
            'last_run' => time(),
        ), false);
        // A foglalast ELENGEDJUK: a kovetkezo kor kulon hivas lesz (1 masodperc
        // mulva — 2.14.13), es neki is be kell tudnia lepni.
        delete_option($lock_option);
        if (!wp_next_scheduled('huhs_push_continue', array($job_key))) {
            if (false === wp_schedule_single_event(time() + 1, 'huhs_push_continue', array($job_key))) {
                // Nem allunk meg: a biztonsagi haló a kovetkezo keresnel folytatja.
                error_log('HUHS push: could not schedule the next run, the resume hook will take over.');
            }
        }
        if (function_exists('spawn_cron')) spawn_cron();
        return;
    }

    delete_option($option);
    delete_option($lock_option);
    if ((string) get_option('huhs_push_active_job', '') === $job_key) {
        delete_option('huhs_push_active_job');
    }
    huhs_push_prune_tokens($dead);
}

/**
 * Fut-e most kuldési lánc?
 *
 * MIÉRT kell: ha egy nagy küldést a lánc visz ki (mert nem fért bele egy körbe),
 * akkor egy „újrapróbálkozás" a nulláról MÉG EGYSZER elküldené azoknak is, akik
 * már megkapták. Ezért az újrapróbát csak akkor indítjuk, ha nincs élő lánc.
 */
function huhs_push_has_pending_job($expected = array())
{
    $key = (string) get_option('huhs_push_active_job', '');
    if ($key === '') return false;
    $job = get_option('huhs_push_job_' . $key, null);
    if (!is_array($job)) {
        delete_option('huhs_push_active_job');
        return false;
    }
    $last_run = (int) ($job['last_run'] ?? 0);
    if ($last_run > 0 && $last_run < time() - DAY_IN_SECONDS) return false;
    // Csak a MAGÁÉT a küldését tekintjük folytatásnak: egy másik, éppen futó
    // kör nem jogosít fel arra, hogy ezt a küldést „elküldöttnek" könyveljük.
    if ($expected) {
        $data = is_array($job['data'] ?? null) ? $job['data'] : array();
        foreach ($expected as $field => $value) {
            if ((string) ($data[$field] ?? '') !== (string) $value) return false;
        }
    }
    return true;
}

/**
 * Biztonsagi háló a kuldesi lancnak.
 *
 * ELES MERES: a lanc 338 eszkoz utan megallt, mert a kovetkezo kor cron-esemenye
 * eltunt (`push_job=none`), mikozben a WP-Cron maga mukodott (`cron_overdue`
 * csokkent). A folytatas tehat nem varakozott, hanem elveszett — a kuldés fele
 * ertesites nelkul maradt.
 *
 * Ezert a valasz elkuldese UTAN (shutdown) megnezzuk, hogy van-e fuggoben levo
 * feladat, es ha az utolso kor 10 masodpercel ezelott futott, lefuttatjuk a
 * kovetkezot. Igy a sor minden olyan keresnel halad, ami egyaltalan eljut a
 * WordPressig, fuggetlenul attol, hogy a cron-esemeny megvan-e.
 *
 * A köre itt szandekosan Rovid (HUHS_PUSH_RESUME_BUDGET), mert ha eppen egy
 * latogato kérése fizeti meg, ne varjon sokaig. Zarral is vedjuk: egyszerre
 * csak egy keres futtathat kort.
 */
/**
 * Atvesz egy elarvult kuldési feladatot.
 *
 * A 2.4.118 elott a feladatnak nem volt `huhs_push_active_job` mutatoja, ezert
 * a biztonsagi háló nem talalta meg — pontosan ez tortent az elesben megszakadt
 * kuldessel (a feladat a DB-ben maradt, de semmi nem mutatott ra). Ez a lepes
 * a hianyzo mutatot potolja, ha a cron-tombben sincs esemeny ra.
 *
 * A scan szandekosan ritka (legfeljebb 5 percenkent egyszer, es csak akkor, ha
 * nincs aktiv feladat), hogy a lassu site-on ne adjon allando lekeredezest.
 */
function huhs_push_adopt_orphan_job()
{
    if ((string) get_option('huhs_push_active_job', '') !== '') return false;

    $scanned = (int) get_option('huhs_push_orphan_scan', 0);
    if ($scanned > time() - 5 * MINUTE_IN_SECONDS) return false;
    update_option('huhs_push_orphan_scan', time(), false);

    global $wpdb;
    $name = $wpdb->get_var(
        "SELECT option_name FROM {$wpdb->options} WHERE option_name LIKE 'huhs_push_job_%' ORDER BY option_id DESC LIMIT 1"
    );
    if (!is_string($name) || $name === '') return false;

    $job = get_option($name, null);
    if (!is_array($job)) {
        delete_option($name);
        return false;
    }

    // Egy nappal kesobb mar ne toljon a semmibol egy "uj hir" ertesitest.
    // A `> 0` azert kell: a 2.4.118 elott keszult feladatoknak nincs last_run
    // mezoje (0), azokat frissnek tekintjuk, nem toroljuk — kulonben pont az
    // elakadt kuldest dobnank el, amit vissza akarunk hozni.
    $last_run = (int) ($job['last_run'] ?? 0);
    if ($last_run > 0 && $last_run < time() - DAY_IN_SECONDS) {
        delete_option($name);
        return false;
    }

    update_option('huhs_push_active_job', substr($name, strlen('huhs_push_job_')), false);
    error_log('HUHS push: adopted an orphaned broadcast job (' . $name . ').');
    return true;
}

add_action('shutdown', 'huhs_push_resume_pending_job', 99);
function huhs_push_resume_pending_job()
{
    if (!function_exists('huhs_push_continue')) return;

    huhs_push_adopt_orphan_job();

    $key = (string) get_option('huhs_push_active_job', '');
    if ($key === '') return;

    $job = get_option('huhs_push_job_' . $key, null);
    if (!is_array($job)) {
        delete_option('huhs_push_active_job');
        return;
    }

    // A cron-lancnak kellene folytatnia; csak akkor lepunk be, ha elakadt.
    if ((int) ($job['last_run'] ?? 0) > time() - HUHS_PUSH_RESUME_GAP) return;

    // Atomikus zar: az add_option csak az elso kerest engedi be.
    if (!add_option('huhs_push_resume_lock', time(), '', false)) {
        $lock = (int) get_option('huhs_push_resume_lock');
        if ($lock > time() - 120) return;
        update_option('huhs_push_resume_lock', time(), false);
    }

    huhs_push_continue($key, HUHS_PUSH_RESUME_BUDGET);
    delete_option('huhs_push_resume_lock');
}

/**
 * Broadcast one notification.
 *
 * Contacting FCM is one blocking round trip per device, and this install has
 * close to a thousand registered devices. Sending the whole list inside one
 * request therefore cannot work: it used to keep the editor blocked for minutes
 * and, if the host killed the request, silently left most devices unnotified.
 * Each run now handles what fits into HUHS_PUSH_TIME_BUDGET seconds and the
 * remainder is delivered by scheduled follow-up runs until the list is done.
 */
function huhs_push_send($title, $body, $data = array(), $language = '')
{
    $title = html_entity_decode(wp_strip_all_tags((string) $title), ENT_QUOTES | ENT_HTML5, 'UTF-8');
    $body = html_entity_decode(wp_strip_all_tags((string) $body), ENT_QUOTES | ENT_HTML5, 'UTF-8');
    $type = (string) ($data['type'] ?? 'custom');
    $account = huhs_push_service_account();
    $project = sanitize_key((string) ($account['project_id'] ?? ''));
    $access_token = huhs_push_access_token();
    if (!$project || !$access_token) {
        // EZ VOLT A LEGNAGYOBB NEMA PONT: hianyzo szolgaltatasfiok vagy
        // sikertelen OAuth-hivas eseten minden ertesites nyomtalanul eltunt,
        // es a mentes is gyors maradt, tehat semmi nem utalt a hibara.
        error_log('HUHS push: skipped (' . $type . '), missing service account or access token.');
        huhs_push_record_result(array(
            'type' => $type,
            'reason' => 'no-credentials',
            'recipients' => 0,
            'processed' => 0,
            'sent' => 0,
            'failed' => 0,
            'dead' => 0,
            'code' => 0,
            'status' => '',
        ));
        return 0;
    }

    $tokens = get_option(HUHS_PUSH_TOKENS_OPTION, array());
    if (!is_array($tokens)) {
        error_log('HUHS push: skipped (' . $type . '), the token list is not an array.');
        huhs_push_record_result(array(
            'type' => $type,
            'reason' => 'no-token-list',
            'recipients' => 0,
            'processed' => 0,
            'sent' => 0,
            'failed' => 0,
            'dead' => 0,
            'code' => 0,
            'status' => '',
        ));
        return 0;
    }

    $recipients = huhs_push_recipients($tokens, $data, $language);
    if (!$recipients) {
        error_log('HUHS push: nothing to do (' . $type . '), no recipient matches the preferences.');
        huhs_push_record_result(array(
            'type' => $type,
            'reason' => 'no-recipients',
            'recipients' => 0,
            'processed' => 0,
            'sent' => 0,
            'failed' => 0,
            'dead' => 0,
            'code' => 0,
            'status' => '',
        ));
        return 0;
    }

    $result = huhs_push_deliver_slice($recipients, $title, $body, $data, $project, $access_token);
    $error = huhs_push_last_http_error();

    huhs_push_record_result(array(
        'type' => $type,
        'reason' => $result['sent'] > 0 ? 'ok' : 'undelivered',
        'recipients' => count($recipients),
        'processed' => $result['processed'],
        'sent' => $result['sent'],
        'failed' => $result['failed'],
        'dead' => count($result['dead']),
        'code' => (int) ($error['code'] ?? 0),
        'status' => (string) ($error['status'] ?? ''),
    ));
    error_log(sprintf(
        'HUHS push: %s recipients=%d processed=%d sent=%d failed=%d dead=%d http=%d/%s',
        $type,
        count($recipients),
        $result['processed'],
        $result['sent'],
        $result['failed'],
        count($result['dead']),
        (int) ($error['code'] ?? 0),
        (string) ($error['status'] ?? '')
    ));

    if ($result['remaining'] > 0) {
        huhs_push_schedule_job(array(
            'title' => $title,
            'body' => $body,
            'data' => $data,
            'offset' => $result['processed'],
            'dead' => $result['dead'],
            'runs' => 1,
        ));
    } else {
        huhs_push_prune_tokens($result['dead']);
    }

    return $result['sent'];
}

/**
 * Nyelvenkénti küldés (2.14.6).
 *
 * MIÉRT: a push szövegét a **rendszer** rajzolja ki, ezért az app már nem tudja
 * lefordítani — eddig minden eszköz a magyar szöveget kapta (az angol felületű
 * felhasználó is). Itt minden nyelvre külön kör indul, a címzettek nyelv szerint
 * szűrve; ha egy nyelvre nincs egyetlen eszköz sem, arra **nem** indul kör.
 *
 * ⚠️ A beállítás-szűrők (`enabled` / `events` / `reminders`) változatlanul
 * érvényesek, mert a szűrést a `huhs_push_send` → `huhs_push_recipients` végzi.
 *
 * @param array $texts `array('hu' => array('title' => …, 'body' => …), 'en' => …)`
 * @param array $data  a push adat-csomagja (típus, célpont)
 * @return int a ténylegesen elküldött értesítések száma
 */
function huhs_push_send_localized($texts, $data = array())
{
    $total = 0;
    foreach (huhs_push_languages() as $language) {
        $text = is_array($texts[$language] ?? null) ? $texts[$language] : array();
        $title = (string) ($text['title'] ?? '');
        $body = (string) ($text['body'] ?? '');
        if ($title === '' && $body === '') continue;
        // A token-lista itt dől el: ha az adott nyelvre nincs címzett, a hívás
        // nulla lesz és nem hagy maga után felesleges feladatot.
        $total += (int) huhs_push_send($title, $body, $data, $language);
    }
    return $total;
}

/**
 * Queue a custom push instead of keeping the authenticated REST request open
 * while FCM is contacted once for every registered device. The option lock
 * is created with add_option(), which is atomic for concurrent PHP requests.
 */
function huhs_push_queue_custom($title, $body, $data = array())
{
    $title = html_entity_decode(wp_strip_all_tags((string) $title), ENT_QUOTES | ENT_HTML5, 'UTF-8');
    $body = html_entity_decode(wp_strip_all_tags((string) $body), ENT_QUOTES | ENT_HTML5, 'UTF-8');
    $fingerprint = md5($title . "\n" . $body . "\n" . wp_json_encode($data));
    $lock_key = 'huhs_custom_push_lock_' . $fingerprint;
    $existing = get_option($lock_key, null);
    if (is_array($existing) && (time() - (int) ($existing['created_at'] ?? 0)) < 600) {
        return array('queued' => false, 'duplicate' => true, 'sent' => 0);
    }
    if ($existing !== null) delete_option($lock_key);
    if (!add_option($lock_key, array(
        'created_at' => time(),
        'title' => $title,
        'body' => $body,
        'data' => $data,
    ), '', false)) {
        return array('queued' => false, 'duplicate' => true, 'sent' => 0);
    }
    if (wp_schedule_single_event(time() + 1, 'huhs_custom_push_dispatch', array($fingerprint)) === false) {
        delete_option($lock_key);
        return new WP_Error('push_queue_failed', 'A push küldése nem ütemezhető.', array('status' => 503));
    }
    // WP-Cron runs the slow FCM loop outside the authenticated REST request.
    spawn_cron();
    return array('queued' => true, 'duplicate' => false, 'sent' => 0);
}

/**
 * Build one canonical custom-push target. The selected WordPress object is
 * authoritative; this prevents a stale/mismatched form selector from opening
 * a different content type in the app.
 */
function huhs_push_resolve_custom_target($target_type, $target_id, $target_url = '')
{
    $target_type = sanitize_key((string) $target_type);
    $target_id = absint($target_id);
    $url = esc_url_raw((string) $target_url);
    $payload_type = 'custom';
    $payload_id = 0;

    if ($target_id > 0) {
        $target_post = get_post($target_id);
        if ($target_post && $target_post->post_status === 'publish') {
            $type_map = array(
                'post' => 'news',
                'huhs_event' => 'event',
                'huhs_release' => 'release',
            );
            if (isset($type_map[$target_post->post_type])) {
                $payload_type = $type_map[$target_post->post_type];
                $payload_id = (int) $target_post->ID;
                $url = get_permalink($target_post) ?: $url;
            }
        }
    }

    if ($payload_id === 0 && $url !== '') {
        $scheme = strtolower((string) wp_parse_url($url, PHP_URL_SCHEME));
        $host = (string) wp_parse_url($url, PHP_URL_HOST);
        if (!in_array($scheme, array('http', 'https'), true) || $host === '' || !wp_http_validate_url($url)) {
            $url = '';
        } else {
            $resolved_id = url_to_postid($url);
            $resolved_post = $resolved_id ? get_post($resolved_id) : null;
            $type_map = array('post' => 'news', 'huhs_event' => 'event', 'huhs_release' => 'release');
            if ($resolved_post && $resolved_post->post_status === 'publish' && isset($type_map[$resolved_post->post_type])) {
                $payload_type = $type_map[$resolved_post->post_type];
                $payload_id = (int) $resolved_post->ID;
            }
        }
    }

    if ($payload_id === 0 && $url === '' && $target_type !== 'none' && $target_type !== 'custom') {
        return new WP_Error('invalid_push_target', 'A kiválasztott push-cél nem érvényes.', array('status' => 400));
    }

    return array(
        'type' => $payload_type,
        'id' => $payload_id > 0 ? (string) $payload_id : '',
        'url' => $url,
    );
}

add_action('huhs_custom_push_dispatch', function ($fingerprint) {
    $fingerprint = sanitize_key((string) $fingerprint);
    if ($fingerprint === '') return;
    $lock_key = 'huhs_custom_push_lock_' . $fingerprint;
    $job = get_option($lock_key, null);
    if (!is_array($job)) return;
    $sent = huhs_push_send($job['title'] ?? '', $job['body'] ?? '', is_array($job['data'] ?? null) ? $job['data'] : array());
    update_option($lock_key, array_merge($job, array('sent' => (int) $sent, 'completed_at' => time())), false);
}, 10, 1);

add_action('transition_post_status', 'huhs_push_on_publish', 10, 3);
function huhs_push_on_publish($new_status, $old_status, $post)
{
    if ($new_status !== 'publish' || $old_status === 'publish' || wp_is_post_revision($post) || !$post) return;

    if ($post->post_type === 'post') {
        // FCM is contacted once per registered device and every call is a
        // blocking round trip. Sending that from here kept the editor waiting
        // for the whole device list, which is why publishing an article was
        // slow while saving a draft was not.
        huhs_schedule_news_push($post);
    }

    if ($post->post_type === 'huhs_event' || $post->post_type === 'huhs_release') {
        // Post meta is saved after transition_post_status. Delay the check so
        // visible/featured fields from the editor are already committed.
        wp_schedule_single_event(
            time() + 5,
            'huhs_push_publish_content',
            array((int) $post->ID, (string) $post->post_type)
        );
    }
}

/**
 * Queue the "new article" notification outside the editor request.
 *
 * The publish transition runs inside the save request, so sending from there
 * would keep the editor blocked for one FCM round trip per registered device.
 */
function huhs_schedule_news_push($post)
{
    $post_id = isset($post->ID) ? (int) $post->ID : 0;
    if ($post_id <= 0) return false;

    // Egy fuggoben levo ertesites nem indithato ujra ugyanarra a kozzetetelre.
    // A jelzo viszont lejar: ha a folyamat elhal (fatal error), nem blokkolja
    // orokre a cikk ertesiteset.
    $pending_at = (int) get_post_meta($post_id, '_huhs_push_news_pending_at', true);
    if ($pending_at > 0 && $pending_at > time() - HOUR_IN_SECONDS) return true;

    // A token a KONKRET kozzetetelhez tartozik. Az ujraproba ugyanezt a tokent
    // hasznalja (tehat nem kuld ketszer), egy uj kozzetetel viszont uj tokent
    // kap — igy a vazlatba tett, majd ujra kozzetett cikk ertesitése megint
    // kimegy, ami a tulajdonos elvarasa volt.
    $token = wp_generate_password(12, false, false);
    update_post_meta($post_id, '_huhs_push_news_pending_at', (string) time());

    if (false === wp_schedule_single_event(time() + 1, 'huhs_push_publish_news', array($post_id, $token, 1))) {
        // A notification must not be lost just because scheduling failed.
        delete_post_meta($post_id, '_huhs_push_news_pending_at');
        huhs_push_send('Új hír', get_the_title($post), array('type' => 'news', 'id' => (string) $post_id));
        return false;
    }

    // Non-blocking loopback request: the notification goes out now instead of
    // waiting for the next cron tick.
    if (function_exists('spawn_cron')) spawn_cron();
    return true;
}

add_action('huhs_push_publish_news', 'huhs_push_publish_news', 10, 3);
function huhs_push_publish_news($post_id, $token = '', $attempt = 1)
{
    $post = get_post((int) $post_id);
    if (!$post || $post->post_type !== 'post' || $post->post_status !== 'publish' || wp_is_post_revision($post)) return;

    $token = (string) $token;

    // Erre a kozzetetelre mar elment az ertesites.
    if ($token !== '' && get_post_meta($post->ID, '_huhs_push_news_sent', true) === $token) {
        delete_post_meta($post->ID, '_huhs_push_news_pending_at');
        return;
    }

    $sent = huhs_push_send('Új hír', get_the_title($post), array('type' => 'news', 'id' => (string) $post->ID));
    // Ha a küldés folytatása ütemezve van (több eszköz, mint amennyi egy körbe
    // belefér), akkor a LÁNC viszi ki a többit: egy újrapróbálkozás a nulláról
    // még egyszer elküldené azoknak is, akik már megkapták.
    if ($sent > 0 || huhs_push_has_pending_job(array('type' => 'news', 'id' => (string) $post->ID))) {
        update_post_meta($post->ID, '_huhs_push_news_sent', $token);
        delete_post_meta($post->ID, '_huhs_push_news_pending_at');
        return;
    }

    // Semmi nem ment at. A hir-ertesitesnek eddig SE jelzese, SE ujraprobaja nem
    // volt, ezert egy nema hiba (rossz hitelesites, a Firebase minden tokent
    // elutasít) egyszeruen elveszítette az ertesitést. Csak akkor probalkozunk
    // ujra, ha egyaltalan volt kit ertesiteni.
    $last = huhs_push_last_result();
    if ((int) ($last['recipients'] ?? 0) <= 0) {
        delete_post_meta($post->ID, '_huhs_push_news_pending_at');
        return;
    }
    if ($attempt >= HUHS_PUSH_NEWS_MAX_ATTEMPTS) {
        delete_post_meta($post->ID, '_huhs_push_news_pending_at');
        error_log('HUHS push: news notification gave up for post ' . $post->ID . ' after ' . $attempt . ' attempts.');
        return;
    }

    error_log('HUHS push: news notification failed for post ' . $post->ID . ', retrying (attempt ' . ($attempt + 1) . ').');
    // Ugyanazzal a tokennel: az ujraproba nem kuldhet ketszer ugyanarra a
    // kozzetetelre.
    wp_schedule_single_event(time() + 300 * $attempt, 'huhs_push_publish_news', array((int) $post->ID, $token, $attempt + 1));
    if (function_exists('spawn_cron')) spawn_cron();
}

add_action('huhs_push_publish_content', 'huhs_push_publish_content', 10, 2);
function huhs_push_publish_content($post_id, $post_type, $retry_attempt = 1)
{
    $post = get_post((int) $post_id);
    if (!$post || $post->post_status !== 'publish') return;
    if (!in_array($post_type, array('huhs_event', 'huhs_release'), true)) return;
    if (!get_post_meta($post->ID, 'visible', true)) return;

    $marker = '_huhs_push_published_' . ($post_type === 'huhs_event' ? 'event' : 'release');
    $fingerprint = $post_type === 'huhs_release'
        ? md5(wp_json_encode(array(
            'title' => get_the_title($post),
            'release_date' => get_post_meta($post->ID, 'release_date', true),
            'preview_url' => get_post_meta($post->ID, 'preview_url', true),
            'products' => array(
                get_post_meta($post->ID, 'radio_wav_product_id', true),
                get_post_meta($post->ID, 'radio_mp3_product_id', true),
                get_post_meta($post->ID, 'extended_wav_product_id', true),
                get_post_meta($post->ID, 'extended_mp3_product_id', true),
            ),
        )))
        : 'published';
    if (get_post_meta($post->ID, $marker, true) === $fingerprint) return;

    $type = $post_type === 'huhs_event' ? 'event' : 'release';
    $title = $post_type === 'huhs_event' ? 'Új esemény' : 'Új release';
    // Kedvenc-alapú célzás (2.14.9): a küldés megmondja, mely DJ-k/szervezők
    // tartoznak a tartalomhoz — így aki KÖVETI valamelyiket, az biztos megkapja.
    // Aki még nem küldött kedvenceket (minden 381 előtti kliens), az változatlanul
    // mindent megkap, mert a szűrő csak akkor szűkít, ha a rekordban VAN kedvenc.
    $followers = huhs_push_content_follow_targets($post);
    $sent = huhs_push_send($title, get_the_title($post), array(
        'type' => $type,
        'id' => (string) $post->ID,
    ) + $followers);
    // Do not permanently mark the notification as sent when FCM returned no
    // successful delivery. This keeps a later controlled retry possible.
    // DE: ha a küldés folytatása él (nagy lista), akkor a lánc viszi ki a
    // többit — az újrapróbálkozás a nulláról dupla értesítést okozna.
    if ($sent > 0 || huhs_push_has_pending_job(array('type' => $type, 'id' => (string) $post->ID))) {
        update_post_meta($post->ID, $marker, $fingerprint);
    } elseif ($post_type === 'huhs_release') {
        huhs_schedule_release_push_retry($post->ID, $retry_attempt);
    }

    if ($post_type === 'huhs_event') {
        huhs_push_schedule_event_reminders($post);
    }
}

// A release can receive its audio, product IDs, or final metadata after it
// was already published. transition_post_status does not run for those
// updates, so queue the same deduplicated notification check after every real
// release save as well.
add_action('save_post_huhs_release', function ($post_id, $post, $update) {
    if (!$post || wp_is_post_revision($post_id) || wp_is_post_autosave($post_id) || $post->post_status !== 'publish') return;
    if (!get_post_meta($post_id, 'visible', true)) return;
    if (!wp_next_scheduled('huhs_push_publish_content', array((int) $post_id, 'huhs_release'))) {
        wp_schedule_single_event(time() + 5, 'huhs_push_publish_content', array((int) $post_id, 'huhs_release'));
    }
}, 20, 3);

/**
 * Az esemény kezdetének **valódi** időpontja (epoch másodperc), 0 ha nincs dátum.
 *
 * ⚠️ MIÉRT KELL (mért hiba, 2.14.6): a `strtotime($date . ' ' . $time)` a szerver
 * **UTC** időzónáját használja (a WordPress `date_default_timezone_set('UTC')`-t
 * hív), ezért egy `2026-10-17 23:00` helyi faliórát **UTC-ként** értelmezett: a
 * kapott időpont valójában **01:00 helyi idő** (nyáron +2 óra, télen +1). A
 * `wp_date('U', …)` ezen nem változtat. Az emlékeztetők ezért **később** mentek
 * ki a kelleténél (a „6 óra előtte" valójában ~4 óra előtte volt), a
 * megjelenített idő pedig rossz napot/órát mutatott volna.
 *
 * A helyes út: a faliórát a **site időzónájában** értelmezzük
 * (`date_create_immutable`), így az epoch valódi, és a `wp_date()` ugyanezt az
 * időzónát használva a helyes helyi időt írja ki.
 */
function huhs_push_event_start_timestamp($post)
{
    $date = (string) get_post_meta($post->ID, 'event_start_date', true);
    if ($date === '') return 0;
    $time = (string) (get_post_meta($post->ID, 'event_start_time', true) ?: '12:00');
    $parsed = date_create_immutable($date . ' ' . $time, wp_timezone());
    if (!$parsed) return 0;
    return (int) $parsed->getTimestamp();
}

function huhs_push_schedule_event_reminders($post)
{
    $date = get_post_meta($post->ID, 'event_start_date', true);
    if (!$date) return;
    $timestamp = huhs_push_event_start_timestamp($post);
    if (!$timestamp || $timestamp <= time()) return;

    foreach (array(
        'week' => $timestamp - WEEK_IN_SECONDS,
        'day_before' => $timestamp - DAY_IN_SECONDS,
        'hours_before' => $timestamp - 6 * HOUR_IN_SECONDS,
        // 2.14.7: a 2 órás ablak a 6 órás MELLÉ kerül — az utolsó órákban a
        // legvalószínűbb, hogy a tag még tervez, a délelőtti (6 órás) értesítést
        // pedig könnyű elfelejteni estig.
        'two_hours' => $timestamp - 2 * HOUR_IN_SECONDS,
    ) as $kind => $when) {
        if ($when > time() && !wp_next_scheduled('huhs_push_event_reminder', array($post->ID, $kind))) {
            wp_schedule_single_event($when, 'huhs_push_event_reminder', array($post->ID, $kind));
        }
    }
}

// WP-Cron may not run at the exact event timestamp. Keep a small recurring
// safety scan so the reminder is sent on the next site cron request instead
// of being lost permanently.
add_filter('cron_schedules', function ($schedules) {
    if (!isset($schedules['huhs_five_minutes'])) {
        $schedules['huhs_five_minutes'] = array(
            'interval' => 5 * MINUTE_IN_SECONDS,
            'display' => 'HUHS every five minutes',
        );
    }
    return $schedules;
});

add_action('init', function () {
    if (!wp_next_scheduled('huhs_push_event_reminder_scan')) {
        wp_schedule_event(time() + 60, 'huhs_five_minutes', 'huhs_push_event_reminder_scan');
    }
});

add_action('huhs_push_event_reminder_scan', 'huhs_push_scan_event_reminders');
function huhs_push_scan_event_reminders()
{
    // ⚠️ VALÓDI idő (2.14.6): eddig `current_time('timestamp')` volt — az a helyi
    // faliórát adja vissza „epochként", amihez a régi, szintén eltolt
    // `$timestamp` illett. Most mindkettő valódi epoch, ezért a `time()` a helyes.
    $now = time();

    // This scan runs every five minutes, forever, and WP-Cron does its work
    // inside an ordinary request: whichever visitor or app call triggers cron
    // pays for it. Loading every published event (up to 500 posts plus their
    // meta) was unnecessary — a reminder can only be due for an event starting
    // within the next week. The window below is deliberately wider than the
    // four reminder windows (week / one day / six hours / two hours) so nothing can fall
    // outside it, and an event with an unparsable date never produced a
    // reminder in the first place (strtotime returns false for it).
    //
    // The stored value is a local calendar date, so the bounds are built from
    // real time with the site timezone. $now cannot be used for that: it is a
    // locally shifted timestamp, not a real one.
    $today = wp_date('Y-m-d', time());
    $horizon = wp_date('Y-m-d', time() + 8 * DAY_IN_SECONDS);

    $events = get_posts(array(
        'post_type' => 'huhs_event',
        'post_status' => 'publish',
        'posts_per_page' => 500,
        'fields' => 'all',
        'meta_query' => array(
            array(
                'key' => 'event_start_date',
                'value' => array($today, $horizon),
                'compare' => 'BETWEEN',
                'type' => 'DATE',
            ),
        ),
    ));

    foreach ($events as $post) {
        $timestamp = huhs_push_event_start_timestamp($post);
        if (!$timestamp) continue;
        $kinds = array();
        // 2.14.7: a 2 órás ablak (a 6 órás előtt mérve, de a kettő nem fedi
        // egymást: [T-2h, T-1h) és [T-6h, T-5h) — egy eseményre mindkettő
        // legfeljebb egyszer fut, a `_huhs_push_reminder_sent_*` jelölő miatt).
        if ($now >= $timestamp - 2 * HOUR_IN_SECONDS && $now < $timestamp - HOUR_IN_SECONDS) {
            $kinds[] = 'two_hours';
        }
        if ($now >= $timestamp - 6 * HOUR_IN_SECONDS && $now < $timestamp - 5 * HOUR_IN_SECONDS) {
            $kinds[] = 'hours_before';
        }
        if ($now >= $timestamp - DAY_IN_SECONDS && $now < $timestamp - 23 * HOUR_IN_SECONDS) {
            $kinds[] = 'day_before';
        }
        if ($now >= $timestamp - WEEK_IN_SECONDS && $now < $timestamp - 6 * DAY_IN_SECONDS) {
            $kinds[] = 'week';
        }
        foreach ($kinds as $kind) {
            huhs_push_event_reminder($post->ID, $kind);
        }
    }
}

add_action('save_post_huhs_event', function ($post_id, $post, $update) {
    if (!$post || wp_is_post_revision($post_id) || wp_is_post_autosave($post_id) || $post->post_status !== 'publish') return;
    huhs_push_schedule_event_reminders($post);
}, 20, 3);

add_action('huhs_push_event_reminder', 'huhs_push_event_reminder', 10, 2);
function huhs_push_event_reminder($post_id, $kind)
{
    $post = get_post($post_id);
    if (!$post || $post->post_status !== 'publish') return;
    $marker = '_huhs_push_reminder_sent_' . sanitize_key($kind);
    if (get_post_meta($post_id, $marker, true)) return;
    $sent = huhs_push_send_localized(
        huhs_push_event_reminder_texts($post, $kind),
        array('type' => 'event', 'kind' => 'reminder', 'id' => (string) $post_id)
    );
    if ($sent > 0) update_post_meta($post_id, $marker, current_time('mysql', true));
}

/**
 * Az emlékeztető szövege **nyelvenként**, a **dátummal és a helyszínnel**
 * (2.14.6).
 *
 * MIÉRT: eddig a törzs csak az esemény címe volt („Esemény holnap" + cím), így
 * a felhasználó nem látta, **mikor** és **hol** van — pont az a két adat, ami
 * miatt egy emlékeztető hasznos. A cím az ablak nevét mondja meg, a törzs pedig
 * a tényeket: `{cím} — {dátum} · {helyszín}, {város}`.
 *
 * ⚠️ A dátum a **helyi (site) időzónában** készül (`wp_date`), ugyanúgy, ahogy az
 * ütemezés számol — különben nyáron/télen elcsúszna egy órával.
 */
function huhs_push_event_reminder_texts($post, $kind)
{
    $timestamp = huhs_push_event_start_timestamp($post);
    $venue = trim((string) get_post_meta($post->ID, 'venue_name', true));
    $city = trim((string) get_post_meta($post->ID, 'venue_city', true));
    $place = $venue !== '' && $city !== '' ? $venue . ', ' . $city : ($venue !== '' ? $venue : $city);
    $title = html_entity_decode(wp_strip_all_tags((string) get_the_title($post)), ENT_QUOTES | ENT_HTML5, 'UTF-8');

    $headlines = array(
        'week' => array('hu' => 'Esemény egy hét múlva', 'en' => 'Event in a week'),
        'day_before' => array('hu' => 'Esemény holnap', 'en' => 'Event tomorrow'),
        'hours_before' => array('hu' => 'Esemény ma', 'en' => 'Event today'),
        // 2.14.7: a 2 órás ablak szövege — a cím mondja meg, mennyi van hátra.
        'two_hours' => array('hu' => 'Esemény 2 óra múlva', 'en' => 'Event in 2 hours'),
    );
    $headline = $headlines[$kind] ?? $headlines['day_before'];

    $texts = array();
    foreach (huhs_push_languages() as $language) {
        $when = $timestamp > 0
            ? wp_date($language === 'en' ? 'M j, H:i' : 'Y.m.d. H:i', $timestamp)
            : '';
        $facts = array_values(array_filter(array($when, $place), function ($part) {
            return (string) $part !== '';
        }));
        $texts[$language] = array(
            'title' => (string) ($headline[$language] ?? $headline['hu']),
            'body' => $facts ? $title . ' — ' . implode(' · ', $facts) : $title,
        );
    }
    return $texts;
}

/**
 * A SZAVAZÁS/JÁTÉK „kinyílt" értesítés (2.14.11) — a döntés EGY helyen.
 *
 * MIÉRT: a kérdőív, a nyereményjáték, az éves szavazás és a GYÍK-játék
 * megnyílása eddig **némán** történt: aki éppen nem nyitotta ki az appot, el sem
 * tudta, hogy elindult. A meglévő tartalom-push csak a `post` / `huhs_event` /
 * `huhs_release` típusokra szól, ezért ezek kimaradtak — pedig pont ezekhez kell
 * a **napokon belüli** visszatérés (a szavazás és a játék időablakos).
 *
 * A négy típus egyetlen térképen él, hogy ne tudjanak széttartani, és hogy a
 * mérés pontosan ezt a térképet nézze:
 *   * `payload`     — a push adat-csomagjának típusa (ezt kapja a kliens);
 *   * `start`/`end` — a nyitást/zárást tároló meta-kulcs (`Y-m-d\TH:i`, helyi);
 *   * `question`    — a törzs forrása (a kérdés), ha van ilyen mező;
 *   * `enabled`     — kapcsoló-meta, ha a tartalom kikapcsolható (szavazás);
 *   * `needs_dates` — igaz, ha dátum nélkül a tartalom nem is lehet aktív;
 *   * `setting`     — a token-rekord beállítás-kulcsa (lásd `huhs_push_recipients`);
 *   * `texts`       — a CÍM nyelvenként (a törzs a tartalom címe/kérdése).
 */
function huhs_push_open_notice_types()
{
    return array(
        'huhs_poll' => array(
            'payload' => 'poll',
            'start' => '_huhs_poll_start',
            'end' => '_huhs_poll_end',
            'question' => '_huhs_poll_question',
            'setting' => 'polls',
            'texts' => array('hu' => 'Elindult a kérdőív', 'en' => 'The new poll is open'),
        ),
        'huhs_prize' => array(
            'payload' => 'game',
            'start' => '_huhs_prize_start',
            'end' => '_huhs_prize_end',
            'question' => '_huhs_prize_question',
            'setting' => 'games',
            'texts' => array('hu' => 'Elindult a nyereményjáték', 'en' => 'The prize game has started'),
        ),
        'huhs_vote_season' => array(
            'payload' => 'vote',
            'start' => '_huhs_vote_start',
            'end' => '_huhs_vote_end',
            'question' => '',
            'setting' => 'votes',
            // A kikapcsolt szezonra nem küldünk (a szerver `huhs_vote_active`
            // pontosan ugyanezt a kapcsolót nézi).
            'enabled' => '_huhs_vote_enabled',
            'texts' => array('hu' => 'Elindult az éves szavazás', 'en' => 'The annual voting is open'),
        ),
        'huhs_game' => array(
            'payload' => 'quiz',
            'start' => '_huhs_game_start',
            'end' => '_huhs_game_end',
            'question' => '',
            'setting' => 'games',
            // A GYÍK-játék dátum nélkül `draft` (`huhs_game_status`), tehát nem
            // is aktív — ilyenkor nincs mit hirdetni.
            'needs_dates' => true,
            'texts' => array('hu' => 'Elindult a játék', 'en' => 'The quiz game has started'),
        ),
    );
}

/**
 * Egy meta-mező **valódi** időpontja (epoch másodperc), 0 ha nincs/értelmezhetetlen.
 *
 * ⚠️ Ugyanaz a buktató, mint az esemény-emlékeztetőnél (2.14.6): a tárolt érték
 * **helyi falióra** (`Y-m-d\TH:i`), a szerver viszont UTC-n fut, ezért a
 * `strtotime()` rossz epochot adna (nyáron 2 órával, télen 1-gyel). A
 * `date_create_immutable(…, wp_timezone())` a site időzónájában értelmezi — így
 * az ütemezés és a megjelenített zárás is helyes.
 */
function huhs_push_meta_timestamp($post_id, $meta_key)
{
    $meta_key = trim((string) $meta_key);
    if ($meta_key === '') return 0;
    $raw = trim((string) get_post_meta($post_id, $meta_key, true));
    if ($raw === '') return 0;
    $parsed = date_create_immutable($raw, wp_timezone());
    if (!$parsed) return 0;
    return (int) $parsed->getTimestamp();
}

/** A tartalom megnyílásának pillanata: a beállított kezdés, vagy a közzététel. */
function huhs_push_open_moment($post, $config)
{
    $start = huhs_push_meta_timestamp($post->ID, (string) ($config['start'] ?? ''));
    if ($start > 0) return $start;
    if (!empty($config['needs_dates'])) return 0;
    // Nincs kezdés → a közzététel a nyitás (a naptár-dátum valódi epochja).
    $published = get_post_time('U', true, $post);
    return $published ? (int) $published : 0;
}

/** A tartalom kapcsolója (pl. a szezon `_huhs_vote_enabled` mezője). */
function huhs_push_open_enabled($post, $config)
{
    $key = (string) ($config['enabled'] ?? '');
    if ($key === '') return true;
    return (string) get_post_meta($post->ID, $key, true) === '1';
}

/**
 * A küldés ujjlenyomata: **tartalom + típus + kezdés**.
 *
 * Egy (tartalom, időablak) páros **egyszer** hirdethető. Ha a szerkesztő egy
 * ÚJ időablakot állít be (más kezdés), az új ujjlenyomat — és ezzel egy új,
 * szándékos hirdetés. A puszta szövegjavítás nem ad új értesítést.
 */
function huhs_push_open_fingerprint($post, $config)
{
    return md5(implode('|', array(
        (string) $post->post_type,
        (int) $post->ID,
        trim((string) get_post_meta($post->ID, (string) ($config['start'] ?? ''), true)),
    )));
}

/**
 * A hirdetés szövege nyelvenként: a cím mondja, MI nyílt ki, a törzs a tartalom
 * (kérdés vagy cím), a zárás idejével — ez a hiányzó „meddig szól" információ.
 */
function huhs_push_open_notice_texts($post, $config)
{
    $title = html_entity_decode(wp_strip_all_tags((string) get_the_title($post)), ENT_QUOTES | ENT_HTML5, 'UTF-8');
    $question_key = (string) ($config['question'] ?? '');
    $question = '';
    if ($question_key !== '') {
        $question = html_entity_decode(
            wp_strip_all_tags((string) get_post_meta($post->ID, $question_key, true)),
            ENT_QUOTES | ENT_HTML5,
            'UTF-8'
        );
    }
    $headline = is_array($config['texts'] ?? null) ? $config['texts'] : array();
    $end = huhs_push_meta_timestamp($post->ID, (string) ($config['end'] ?? ''));

    $texts = array();
    foreach (huhs_push_languages() as $language) {
        $body = $question !== '' ? $question : $title;
        // A kérdés angol változata a szerver oldali fordítás-tárból jön, ha van
        // (a fordítás nem része ennek a körnek, ezért hiány esetén a magyar
        // szöveg marad — sosem lesz üres a törzs).
        if ($language === 'en' && $question !== '' && function_exists('huhs_translation_text')) {
            $translated = trim((string) huhs_translation_text($post->ID, $language, $question_key, $question));
            if ($translated !== '') $body = $translated;
        }
        if ($body === '') $body = $title;
        if ($end > 0) {
            $formatted = wp_date($language === 'en' ? 'M j, H:i' : 'Y.m.d. H:i', $end);
            $body .= ' · ' . ($language === 'en' ? 'until ' : 'eddig: ') . $formatted;
        }
        $texts[$language] = array(
            'title' => (string) ($headline[$language] ?? $headline['hu'] ?? $title),
            'body' => $body,
        );
    }
    return $texts;
}

/**
 * A hirdetés ütemezése egy mentett tartalomra.
 *
 * A `time()`-hoz közeli nyitás **azonnali** (1 másodperc), a jövőbeli nyitás a
 * nyitás pillanatára kerül. A `spawn_cron()` csak akkor indul, ha a tartalom már
 * nyitva van — így a közzététel utáni másodpercekben megy ki az értesítés, a
 * szerkesztő viszont nem várja meg az FCM-köröket (a küldés a háttérben fut).
 */
function huhs_push_schedule_open_notice($post)
{
    if (!$post || ($post->post_status ?? '') !== 'publish') return false;
    $types = huhs_push_open_notice_types();
    $config = $types[(string) $post->post_type] ?? null;
    if (!$config) return false;
    if (!huhs_push_open_enabled($post, $config)) return false;

    $moment = huhs_push_open_moment($post, $config);
    if ($moment <= 0) return false;
    // Régen kinyílt tartalom: az értesítés elmarad (a frissességi kapu a küldés
    // oldalán is él, itt csak felesleges munkát spórolunk meg vele).
    if ($moment < time() - HUHS_PUSH_OPEN_FRESH_WINDOW) return false;

    $args = array((int) $post->ID, (string) $post->post_type);
    if (wp_next_scheduled('huhs_push_open_notice', $args)) return true;

    $when = max(time() + 1, $moment);
    if (false === wp_schedule_single_event($when, 'huhs_push_open_notice', $args)) return false;
    if ($moment <= time() && function_exists('spawn_cron')) spawn_cron();
    return true;
}

/**
 * A mentés utáni ütemezés — a meta MÁR a helyén van (a plugin saját
 * `save_post_{típus}` kezelője 10-es prioritáson írja, ez 20-on fut).
 */
function huhs_push_schedule_open_notice_from_save($post_id, $post = null, $update = null)
{
    if (defined('DOING_AUTOSAVE') && DOING_AUTOSAVE) return;
    if (function_exists('wp_is_post_revision') && (wp_is_post_revision($post_id) || wp_is_post_autosave($post_id))) return;
    if (!$post || !is_object($post)) $post = get_post($post_id);
    if (!$post) return;
    huhs_push_schedule_open_notice($post);
}

/**
 * A négy típus bekötése — a térképből, ezért új típus egy helyen vehető fel.
 */
function huhs_push_register_open_notice_hooks()
{
    foreach (array_keys(huhs_push_open_notice_types()) as $post_type) {
        add_action('save_post_' . $post_type, 'huhs_push_schedule_open_notice_from_save', 20, 3);
    }
}
huhs_push_register_open_notice_hooks();

/**
 * A hirdetés kiküldése.
 *
 * Idempotens: a `_huhs_push_open_sent` jelölő az ujjlenyomatot tárolja, ezért
 * ugyanarra az időablakra **egyszer** megy ki. A jelölő csak **sikeres** küldés
 * (vagy élő folytatás) után íródik — így egy átmeneti FCM-hiba nem veszíti el az
 * értesítést, viszont egy lezárt/elavult tartalom sem hirdethető meg utólag.
 */
add_action('huhs_push_open_notice', 'huhs_push_open_notice', 10, 2);
function huhs_push_open_notice($post_id, $post_type)
{
    $post_type = (string) $post_type;
    $post = get_post((int) $post_id);
    if (!$post || ($post->post_status ?? '') !== 'publish' || (string) $post->post_type !== $post_type) return;

    $types = huhs_push_open_notice_types();
    $config = $types[$post_type] ?? null;
    if (!$config) return;
    if (!huhs_push_open_enabled($post, $config)) return;

    $now = time();
    $moment = huhs_push_open_moment($post, $config);
    if ($moment <= 0 || $moment > $now) return;
    if ($now - $moment > HUHS_PUSH_OPEN_FRESH_WINDOW) return;

    $fingerprint = huhs_push_open_fingerprint($post, $config);
    if (get_post_meta($post->ID, '_huhs_push_open_sent', true) === $fingerprint) return;

    $data = array(
        'type' => (string) $config['payload'],
        'kind' => 'open',
        'id' => (string) $post->ID,
    );
    $sent = huhs_push_send_localized(huhs_push_open_notice_texts($post, $config), $data);
    if ($sent > 0 || huhs_push_has_pending_job($data)) {
        update_post_meta($post->ID, '_huhs_push_open_sent', $fingerprint);
    }
}

/**
 * Biztonsági kör: a WP-Cron nem biztos, hogy a nyitás pillanatában fut (a
 * látogatók hozzák), ezért ötpercenként megnézzük a frissen kinyílt tartalmakat.
 * A küldés maga idempotens, ezért ez nem tud duplázni.
 */
add_action('init', function () {
    if (!wp_next_scheduled('huhs_push_open_notice_scan')) {
        wp_schedule_event(time() + 120, 'huhs_five_minutes', 'huhs_push_open_notice_scan');
    }
});

add_action('huhs_push_open_notice_scan', 'huhs_push_scan_open_notices');
function huhs_push_scan_open_notices($limit = 20)
{
    foreach (huhs_push_open_notice_types() as $post_type => $config) {
        $posts = get_posts(array(
            'post_type' => $post_type,
            'post_status' => 'publish',
            'posts_per_page' => (int) $limit,
            'orderby' => 'date',
            'order' => 'DESC',
        ));
        foreach ((array) $posts as $post) {
            huhs_push_open_notice($post->ID, $post_type);
        }
    }
}

/*
|--------------------------------------------------------------------------
| A HÍR-PUSH ŐRE (2.14.12) — a cikk értesítése nem függ a közzététel útjától
|--------------------------------------------------------------------------
*/

/**
 * 🔴 A MÉRT HIBA (éles, 2026-09-30): a nap KÉT cikke után egyetlen push sem indult.
 *
 * A bizonyíték a titkos diagnosztikai fejlécből (`?huhs_diag=huhs-boot-probe-2026`):
 * a `push_last` rekord a mérés pillanatában (helyi idő **12:20**) még mindig
 * `news/ok … at=19:30` volt — vagyis a **korábbi nap** állapota —, függő
 * `huhs_push_publish_news` cron-esemény pedig nem létezett, miközben a WP-Cron ép
 * (`cron_disabled=no`, `cron_overdue` csak a visszatérő köröket mutatta), a
 * token-tár 1026 eszköz, és az FCM-fiók beállítva. **Ugyanarra a két cikkre**
 * kézzel indított kör viszont **1024 eszközt ért el, 0 hibával** — a küldési lánc
 * tehát bizonyítottan jó, a **közzététel-hook nem futott le**.
 *
 * ⚠️ MIÉRT NEM ELÉG A `transition_post_status` ÖNMAGÁBAN: ha a cikk nem a
 * szokásos szerkesztői úton jelenik meg (import, REST-hívás, közvetlen
 * adatbázis-írás), a hook nem hívódik meg — és a cikk értesítés nélkül marad.
 * Ezért az értesítést két réteg védi:
 *
 *   1. `save_post_post` — a szokásos **mentési** úton is elindul (a meglévő
 *      `transition_post_status` MELLETT; a jelölők miatt nem tud duplázni);
 *   2. az **ötpercenkénti ör**, amely a frissen publikált cikkeket nézi meg, és
 *      amelyikről még nem indult értesítés, arra elindítja — ugyanazon a
 *      bizonyított úton (`huhs_schedule_news_push`).
 *
 * ⚠️ FRISSESSÉGI KAPU (6 óra): a feltöltés pillanatában a RÉGI cikkekre nem megy
 * ki semmi — különben egy hete publikált cikkre is elmenne a hír-push. Ez a kapu
 * a DÖNTÉSBEN él (`huhs_push_news_watch_one`), nem csak a lekérdezésben.
 * ⚠️ KORLÁTOS PRÓBÁLKOZÁS: az ör egy cikkre legfeljebb kétszer, óránként egyszer
 * próbálkozik — egy tartósan hibás küldés így nem pörög a végtelenségig.
 */
if (!defined('HUHS_PUSH_NEWS_FRESH_WINDOW')) define('HUHS_PUSH_NEWS_FRESH_WINDOW', 21600); // 6 óra
if (!defined('HUHS_PUSH_NEWS_WATCHDOG_GAP')) define('HUHS_PUSH_NEWS_WATCHDOG_GAP', 3600); // 1 óra
if (!defined('HUHS_PUSH_NEWS_WATCHDOG_MAX_TRIES')) define('HUHS_PUSH_NEWS_WATCHDOG_MAX_TRIES', 2);

// 1) A szokásos MENTÉSI út (a `transition_post_status` mellett) — a 20-as
// prioritás a plugin saját mentése UTÁN fut, hogy a mezők már a helyükön legyenek.
add_action('save_post_post', function ($post_id, $post = null, $update = null) {
    if (defined('DOING_AUTOSAVE') && DOING_AUTOSAVE) return;
    if (!$post || wp_is_post_revision($post_id) || wp_is_post_autosave($post_id)) return;
    if ((string) ($post->post_type ?? '') !== 'post') return;
    if ((string) $post->post_status !== 'publish') return;
    huhs_push_news_watch_one($post);
}, 20, 3);

// 2) Az ötpercenkénti ör (a WP-Cron a látogatók kéréseivel fut).
add_action('init', function () {
    if (!wp_next_scheduled('huhs_push_news_scan')) {
        wp_schedule_event(time() + 180, 'huhs_five_minutes', 'huhs_push_news_scan');
    }
});

add_action('huhs_push_news_scan', 'huhs_push_scan_missing_news');

/**
 * Egy cikk értesítésének elindítása, ha még nem indult rá kör.
 *
 * Ez a **közös döntés** a két rétegnek (mentés-hook + ör), ezért a frissességi
 * kapu is itt él: régi cikkre egyik út sem hirdet.
 *
 * @return bool igaz, ha ütemezés történt
 */
function huhs_push_news_watch_one($post)
{
    $post_id = is_object($post) ? (int) $post->ID : (int) $post;
    if ($post_id <= 0) return false;

    // Már elment róla értesítés → nincs teendő.
    if ((string) get_post_meta($post_id, '_huhs_push_news_sent', true) !== '') return false;

    $now = time();

    // ⚠️ FRISSESSÉGI KAPU: csak a frissen publikált cikk hirdethető meg.
    $published = (int) get_post_time('U', true, $post_id);
    if ($published <= 0 || $published < $now - HUHS_PUSH_NEWS_FRESH_WINDOW) return false;

    // Éppen függőben van (a normál úton indult) → nem nyúlunk bele, nem duplázunk.
    $pending = (int) get_post_meta($post_id, '_huhs_push_news_pending_at', true);
    if ($pending > 0 && $pending > $now - HOUR_IN_SECONDS) return false;

    // Korlátos próbálkozás: cikkenként legfeljebb ennyi, és óránként egyszer.
    $tries = (int) get_post_meta($post_id, '_huhs_push_news_watchdog_tries', true);
    if ($tries >= HUHS_PUSH_NEWS_WATCHDOG_MAX_TRIES) return false;
    $last = (int) get_post_meta($post_id, '_huhs_push_news_watchdog_at', true);
    if ($last > 0 && $last > $now - HUHS_PUSH_NEWS_WATCHDOG_GAP) return false;

    update_post_meta($post_id, '_huhs_push_news_watchdog_tries', $tries + 1);
    update_post_meta($post_id, '_huhs_push_news_watchdog_at', $now);

    $queued = huhs_schedule_news_push(get_post($post_id));
    if ($queued) {
        error_log('HUHS push: the news watchdog queued the missing notification for post ' . $post_id . '.');
    }
    return (bool) $queued;
}

/**
 * Az ör köre: a frissen publikált cikkek, amelyekről még nem indult értesítés.
 *
 * A lekérdezés csak **szűkít** (a régi cikkeket el sem hozza); a döntés a
 * `huhs_push_news_watch_one`-ban van, ezért egy gyorsítótár vagy egy stub által
 * visszaadott régi cikk sem hirdetődik meg.
 *
 * @return int az elindított értesítések száma
 */
function huhs_push_scan_missing_news($limit = 10)
{
    $now = time();
    $posts = get_posts(array(
        'post_type' => 'post',
        'post_status' => 'publish',
        'posts_per_page' => (int) $limit,
        'orderby' => 'date',
        'order' => 'DESC',
        'date_query' => array(array(
            'after' => '-' . (int) (HUHS_PUSH_NEWS_FRESH_WINDOW / HOUR_IN_SECONDS) . ' hours',
        )),
    ));

    $scanned = 0;
    $queued = 0;
    foreach ((array) $posts as $post) {
        if (!is_object($post) || empty($post->ID)) continue;
        $scanned++;
        if (huhs_push_news_watch_one($post)) $queued++;
    }

    update_option('huhs_push_news_scan', array('time' => $now, 'scanned' => $scanned, 'queued' => $queued), false);
    return $queued;
}

/**
 * Az ör állapota a titkos diagnosztikai fejlécbe — hogy a „nem ment ki semmi"
 * megkülönböztethető legyen attól, hogy „az ör le sem futott".
 */
function huhs_push_diag_news_scan()
{
    $scan = get_option('huhs_push_news_scan', array());
    if (!is_array($scan) || empty($scan['time'])) return 'news_scan=none';
    return 'news_scan=' . wp_date('H:i', (int) $scan['time'])
        . '/s' . (int) ($scan['scanned'] ?? 0)
        . '/q' . (int) ($scan['queued'] ?? 0);
}

/**
 * A küldés keretei a diagnosztikai fejlécbe (2.14.13).
 *
 * MIÉRT: a kifutás sebességét három szám együtt adja — a párhuzamosság, az
 * egy körre szánt idő és a **PHP időkorlátja**. Az utóbbi eddig nem volt
 * látható, ezért a keret emelése találgatás lett volna; most mérhető.
 */
function huhs_push_diag_limits()
{
    $max_exec = (string) ini_get('max_execution_time');
    return 'push_limits=conc' . (int) HUHS_PUSH_CONCURRENCY
        . '/budget' . (int) HUHS_PUSH_TIME_BUDGET
        . '/max_exec' . ($max_exec === '' ? '?' : $max_exec);
}

add_action('admin_menu', function () {
    add_submenu_page('huhs-mobile', 'Push értesítések', 'Push értesítések', 'manage_options', 'huhs-push', 'huhs_push_admin_page');
});

add_action('admin_post_huhs_save_push_settings', function () {
    if (!current_user_can('manage_options')) wp_die('Nincs jogosultság.');
    check_admin_referer('huhs_save_push_settings');
    $account = array(
        'project_id' => sanitize_key(wp_unslash($_POST['project_id'] ?? '')),
        'client_email' => sanitize_email(wp_unslash($_POST['client_email'] ?? '')),
        'private_key' => sanitize_textarea_field(wp_unslash($_POST['private_key'] ?? '')),
    );

    if (!empty($_FILES['service_account_json']['tmp_name'])) {
        $json = file_get_contents($_FILES['service_account_json']['tmp_name']);
        $decoded = json_decode($json, true);
        $uploaded = is_array($decoded) ? array(
                'project_id' => sanitize_key((string) ($decoded['project_id'] ?? '')),
                'client_email' => sanitize_email((string) ($decoded['client_email'] ?? '')),
                'private_key' => sanitize_textarea_field((string) ($decoded['private_key'] ?? '')),
            ) : array();
        if (empty($uploaded['project_id']) || empty($uploaded['client_email']) || empty($uploaded['private_key'])) {
            wp_safe_redirect(admin_url('admin.php?page=huhs-push&error=invalid_json'));
            exit;
        }
        $account = $uploaded;
    }

    update_option(HUHS_PUSH_SERVICE_ACCOUNT_OPTION, $account, false);
    wp_safe_redirect(admin_url('admin.php?page=huhs-push&saved=1'));
    exit;
});

add_action('admin_post_huhs_send_custom_push', function () {
    if (!current_user_can('manage_options')) wp_die('Nincs jogosultság.');
    check_admin_referer('huhs_send_custom_push');
    $title = sanitize_text_field(wp_unslash($_POST['title'] ?? ''));
    $body = sanitize_textarea_field(wp_unslash($_POST['body'] ?? ''));
    $target = huhs_push_resolve_custom_target(
        wp_unslash($_POST['target_type'] ?? 'none'),
        $_POST['target_id'] ?? 0,
        wp_unslash($_POST['target_url'] ?? '')
    );
    if ($title !== '' && $body !== '') {
        if (is_wp_error($target)) {
            wp_safe_redirect(admin_url('admin.php?page=huhs-push&error=invalid_target'));
            exit;
        }
        huhs_push_queue_custom($title, $body, $target);
    }
    wp_safe_redirect(admin_url('admin.php?page=huhs-push&sent=1'));
    exit;
});

function huhs_push_admin_page()
{
    if (!current_user_can('manage_options')) return;
    $account = huhs_push_service_account();
    $tokens = get_option(HUHS_PUSH_TOKENS_OPTION, array());
    $push_news = get_posts(array(
        'post_type' => 'post',
        'post_status' => 'publish',
        'posts_per_page' => 30,
        'orderby' => 'date',
        'order' => 'DESC',
    ));
    $push_events = get_posts(array(
        'post_type' => 'huhs_event',
        'post_status' => 'publish',
        'posts_per_page' => 30,
        'orderby' => 'date',
        'order' => 'DESC',
    ));
    ?>
    <div class="wrap">
        <h1>HUHS Mobile push értesítések</h1>
        <p>Firebase szolgáltatásfiók adatai csak itt, a WordPress szerveren tárolhatók. Ezeket ne tedd az appba vagy a Git repóba.</p>
        <form method="post" enctype="multipart/form-data" action="<?php echo esc_url(admin_url('admin-post.php')); ?>">
            <input type="hidden" name="action" value="huhs_save_push_settings">
            <?php wp_nonce_field('huhs_save_push_settings'); ?>
            <p><strong>Egyszerű megoldás:</strong> töltsd fel a Firebase Console-ból letöltött szolgáltatásfiók JSON-fájlt.</p>
            <p><input type="file" name="service_account_json" accept="application/json,.json"></p>
            <p>Vagy töltsd ki kézzel a mezőket:</p>
            <table class="form-table"><tbody>
                <tr><th><label for="project_id">Firebase project ID</label></th><td><input class="regular-text" id="project_id" name="project_id" value="<?php echo esc_attr($account['project_id'] ?? ''); ?>"></td></tr>
                <tr><th><label for="client_email">Service account e-mail</label></th><td><input class="regular-text" id="client_email" name="client_email" value="<?php echo esc_attr($account['client_email'] ?? ''); ?>"></td></tr>
                <tr><th><label for="private_key">Private key</label></th><td><textarea class="large-text code" rows="8" id="private_key" name="private_key"><?php echo esc_textarea($account['private_key'] ?? ''); ?></textarea></td></tr>
            </tbody></table>
            <?php submit_button('Mentés'); ?>
        </form>
        <p>Regisztrált eszközök: <strong><?php echo esc_html(is_array($tokens) ? count($tokens) : 0); ?></strong></p>
        <hr>
        <h2>Egyedi push küldése</h2>
        <form method="post" action="<?php echo esc_url(admin_url('admin-post.php')); ?>">
            <input type="hidden" name="action" value="huhs_send_custom_push">
            <?php wp_nonce_field('huhs_send_custom_push'); ?>
            <p><label for="target_type">Megnyitandó tartalom</label>
                <select id="target_type" name="target_type">
                    <option value="none">Nincs cél</option>
                    <option value="news">Hír (azonosító)</option>
                    <option value="event">Esemény (azonosító)</option>
                    <option value="url">Egyedi link</option>
                </select>
            </p>
            <p><label for="target_id">Hír vagy esemény</label>
                <select id="target_id" name="target_id">
                    <option value="">Válassz tartalmat...</option>
                    <?php if ($push_news) : ?>
                        <optgroup label="Hírek">
                            <?php foreach ($push_news as $push_post) : ?>
                                <option value="<?php echo esc_attr($push_post->ID); ?>" data-target-type="news"><?php echo esc_html($push_post->post_title); ?></option>
                            <?php endforeach; ?>
                        </optgroup>
                    <?php endif; ?>
                    <?php if ($push_events) : ?>
                        <optgroup label="Események">
                            <?php foreach ($push_events as $push_event) : ?>
                                <option value="<?php echo esc_attr($push_event->ID); ?>" data-target-type="event"><?php echo esc_html($push_event->post_title); ?></option>
                            <?php endforeach; ?>
                        </optgroup>
                    <?php endif; ?>
                </select>
            </p>
            <p><label for="target_url">Egyedi link</label> <input class="regular-text" type="url" id="target_url" name="target_url" placeholder="https://..."></p>
            <table class="form-table"><tbody>
                <tr><th><label for="push_title">Cím</label></th><td><input class="regular-text" id="push_title" name="title" required></td></tr>
                <tr><th><label for="push_body">Üzenet</label></th><td><textarea class="large-text" rows="4" id="push_body" name="body" required></textarea></td></tr>
            </tbody></table>
            <?php submit_button('Push küldése', 'secondary'); ?>
        </form>
        <script>
        (function () {
            var type = document.getElementById('target_type');
            var target = document.getElementById('target_id');
            var url = document.getElementById('target_url');
            if (!type || !target || !url) return;
            target.addEventListener('change', function () {
                var option = target.options[target.selectedIndex];
                var selectedType = option ? option.getAttribute('data-target-type') : '';
                if (selectedType) type.value = selectedType;
            });
            url.addEventListener('input', function () {
                if (url.value.trim()) {
                    type.value = 'url';
                    target.value = '';
                }
            });
        }());
        </script>
    </div>
    <?php
}
