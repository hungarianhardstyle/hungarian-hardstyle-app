<?php

if (!defined('ABSPATH')) {
    exit;
}

define('HUHS_STARTUP_ANNOUNCEMENT_OPTION', 'huhs_startup_announcement');

/**
 * A főoldali **Twitch-kártya** beállítása (2.14.15, a tulajdonos jelzése).
 *
 * MIÉRT: a tulajdonos a **plugin adminjában** kereste a Twitch-beharangozó
 * beállítást (*„nem látok sehol olyan opciót, ahol meg tudok adni twitch stream
 * beharangozót"*), a kártya felülírása viszont eddig **csak a Firestore-ban**
 * (`app_settings/twitch`) volt elérhető. Mostantól itt állítható, és a
 * Twitch-figyelő kör (5 percenként) **átszinkronizálja** a Firestore-ba — így a
 * már kint lévő appok is azonnal látják, új build nélkül.
 */
define('HUHS_TWITCH_CARD_OPTION', 'huhs_twitch_card');

add_action('rest_api_init', function () {
    register_rest_route('huhs/v1', '/admin', array(
        array(
            'methods' => WP_REST_Server::READABLE,
            'callback' => 'huhs_admin_api_read',
            'permission_callback' => 'huhs_admin_api_permission',
        ),
        array(
            'methods' => WP_REST_Server::CREATABLE,
            'callback' => 'huhs_admin_api_write',
            'permission_callback' => 'huhs_admin_api_permission',
        ),
    ));
    register_rest_route('huhs/v1', '/startup-announcement', array(
        'methods' => WP_REST_Server::READABLE,
        'callback' => 'huhs_startup_announcement_read',
        'permission_callback' => '__return_true',
    ));
    // A főoldali Twitch-kártya beállítása — a Cloud Function ezt olvassa, és a
    // Firestore-ba írja (a kártya a Firestore-ból dolgozik, lásd a fenti leírást).
    register_rest_route('huhs/v1', '/twitch-card', array(
        'methods' => WP_REST_Server::READABLE,
        'callback' => 'huhs_twitch_card_read',
        'permission_callback' => '__return_true',
    ));
});

add_action('admin_menu', function () {
    add_submenu_page(
        'huhs-mobile',
        'Twitch beharangozó',
        'Twitch beharangozó',
        'manage_options',
        'huhs-twitch-card',
        'huhs_twitch_card_page'
    );
    add_submenu_page(
        'huhs-mobile',
        'Indítási kép',
        'Indítási kép',
        'manage_options',
        'huhs-startup-announcement',
        'huhs_startup_announcement_page'
    );
});

add_action('admin_post_huhs_save_twitch_card', function () {
    if (!current_user_can('manage_options')) {
        wp_die('Nincs jogosultság.');
    }
    check_admin_referer('huhs_save_twitch_card');
    $stored = get_option(HUHS_TWITCH_CARD_OPTION, null);
    $value = huhs_twitch_card_normalize(array(
        'imageUrl' => esc_url_raw(wp_unslash($_POST['imageUrl'] ?? '')),
        'headerText' => sanitize_text_field(wp_unslash($_POST['headerText'] ?? '')),
        'enabled' => !empty($_POST['enabled']),
        'showWhenOffline' => !empty($_POST['showWhenOffline']),
        // Az első mentés jelölése: ilyenkor a kép jelenléte bekapcsolja a kártyát.
        'configured' => $stored !== null,
    ));
    update_option(HUHS_TWITCH_CARD_OPTION, $value, false);
    wp_safe_redirect(admin_url('admin.php?page=huhs-twitch-card&saved=1'));
    exit;
});

/**
 * A Twitch-kártya beállításának tisztítása.
 *
 * ⚠️ A `showWhenOffline` csak **képpel együtt** értelmes: a Twitch mozgó
 * előnézete élő adás nélkül nem mond semmit, ezért kép nélkül nem jelenik meg a
 * kártya — ezt itt kényszerítjük ki, hogy az adminban ne lehessen „üres" kártyát
 * bekapcsolni.
 */
function huhs_twitch_card_normalize($value)
{
    // ⚠️ A WordPress `esc_url_raw` a tiltott protokollokat (pl. `javascript:`)
    // már kidobja — itt viszont **kifejezetten** http(s)-t követelünk, mert ez az
    // érték az appba **kép-URL-ként** megy ki. (A mérés is ezt a szabályt nézi,
    // így nem a WordPress-stub viselkedésétől függ.)
    $url = esc_url_raw(trim((string) ($value['imageUrl'] ?? '')));
    $scheme = strtolower((string) wp_parse_url($url, PHP_URL_SCHEME));
    $value['imageUrl'] = in_array($scheme, array('http', 'https'), true) ? $url : '';
    $value['headerText'] = mb_substr(trim((string) ($value['headerText'] ?? '')), 0, 80);
    // ⚠️ MÉRT HIBA NYOMÁN (2026-10-02): a tulajdonos feltöltött egy képet, de az
    // „Engedélyezve” pipa üresen maradt — így a kártya **némán elrejtve** maradt,
    // és azt hitte, elromlott. Az ELSŐ mentésnél ezért a **kép jelenléte maga a
    // szándék**: ilyenkor a kártya bekapcsol. Utána a pipa a mérvadó (ha később
    // kikapcsolja, az tiszteletben marad).
    $configured = !empty($value['configured']);
    $value['enabled'] = !empty($value['enabled']) || (!$configured && $value['imageUrl'] !== '');
    $value['showWhenOffline'] = !empty($value['showWhenOffline']) && $value['imageUrl'] !== '';
    // A mentés után már ismert a szándék: a következő mentésnél a pipa dönt.
    $value['configured'] = true;
    // ⚠️ KICSINYÍTETT VÁLTOZAT (2.14.17, a tulajdonos jelzése: *„meg ez a twitch
    // kártya a főoldalon 100 év mire betölt”*). A mért kép **1179 KB** volt, míg a
    // WordPress saját kicsinyítései: `-1024x576` = **327 KB**, `-768x432` =
    // **200 KB**, `-300x169` = **38 KB** (`tmp/probe-twitch-card-image-sizes.mjs`).
    // Ezért megkeressük a média-elem kicsinyített változatát, és azt adjuk ki az
    // appnak (`imageUrlSmall`) — a kártya ezt tölti le.
    $value['imageUrlSmall'] = huhs_twitch_card_small_image($value['imageUrl']);
    return $value;
}

/**
 * A beállított kép **kicsinyített** változata (WordPress `medium_large`, majd
 * `large`), ha a kép a médiatárból való. Ha nem található, üres string.
 */
function huhs_twitch_card_small_image($url)
{
    $url = trim((string) $url);
    if ($url === '' || !function_exists('attachment_url_to_postid')) {
        return '';
    }
    $attachment_id = attachment_url_to_postid($url);
    if (!$attachment_id) {
        return '';
    }
    foreach (array('medium_large', 'large') as $size) {
        $src = wp_get_attachment_image_src($attachment_id, $size);
        if (is_array($src) && !empty($src[0]) && $src[0] !== $url) {
            $small = esc_url_raw((string) $src[0]);
            $scheme = strtolower((string) wp_parse_url($small, PHP_URL_SCHEME));
            if (in_array($scheme, array('http', 'https'), true)) {
                return $small;
            }
        }
    }
    return '';
}

function huhs_twitch_card_value()
{
    $stored = get_option(HUHS_TWITCH_CARD_OPTION, null);
    // ⚠️ Ha a tulajdonos **még nem nyitotta meg** ezt az oldalt, a kártya
    // alapból BE van kapcsolva (mint az appban) — különben a szinkronizálás
    // kikapcsolná az élő adás kártyáját, amit senki nem kért.
    if ($stored === null) {
        return array(
            'imageUrl' => '',
            'imageUrlSmall' => '',
            'headerText' => '',
            'enabled' => true,
            'showWhenOffline' => false,
        );
    }
    $value = is_array($stored) ? $stored : array();
    return huhs_twitch_card_normalize(array(
        'imageUrl' => (string) ($value['imageUrl'] ?? ''),
        'headerText' => (string) ($value['headerText'] ?? ''),
        'enabled' => !empty($value['enabled']),
        'showWhenOffline' => !empty($value['showWhenOffline']),
        // ⚠️ A 2.14.16 ELŐTT mentett beállításban ez a jelölő **nincs benne** —
        // ilyenkor a kép jelenléte maga a szándék (lásd a normalize-t), ezért a
        // tulajdonos meglévő beállítása **azonnal** látszódni kezd, újramentés
        // nélkül.
        'configured' => !empty($value['configured']),
    ));
}

function huhs_twitch_card_read()
{
    $response = new WP_REST_Response(huhs_twitch_card_value());
    $response->header('Cache-Control', 'no-store, no-cache, must-revalidate, max-age=0');
    return $response;
}

function huhs_twitch_card_page()
{
    $value = huhs_twitch_card_value();
    ?>
    <div class="wrap">
        <h1>Twitch beharangozó</h1>
        <p>
            A főoldali Twitch-kártya beállítása. A kártya <strong>élő adásnál mindig</strong> megjelenik;
            az itteni képpel és felirattal viszont <strong>előre is behirdethető</strong> — akkor is látszik,
            ha éppen nem megy adás. A beállítás legfeljebb <strong>5 percen belül</strong> jut el az appokhoz
            (a Twitch-figyelő kör szinkronizálja), új app-verzió nem kell hozzá.
        </p>
        <?php if (!empty($_GET['saved'])) : ?><div class="notice notice-success"><p>Beállítás mentve.</p></div><?php endif; ?>
        <?php if (!$value['enabled'] && $value['imageUrl'] !== '') : ?>
            <div class="notice notice-warning">
                <p>
                    <strong>A kártya most KI van kapcsolva.</strong> Van feltöltött kép, de az „Engedélyezve” nincs bepipálva —
                    így a kártya <em>sem élő adásnál, sem előre</em> nem jelenik meg.
                    Pipáld be az „Engedélyezve” mezőt, és mentsd el újra.
                </p>
            </div>
        <?php endif; ?>
        <form method="post" action="<?php echo esc_url(admin_url('admin-post.php')); ?>">
            <input type="hidden" name="action" value="huhs_save_twitch_card">
            <?php wp_nonce_field('huhs_save_twitch_card'); ?>
            <table class="form-table"><tbody>
                <tr>
                    <th><label for="huhs-twitch-image">Kép</label></th>
                    <td>
                        <input class="large-text" type="url" id="huhs-twitch-image" name="imageUrl" value="<?php echo esc_attr($value['imageUrl']); ?>" placeholder="https://...">
                        <p><button type="button" class="button huhs-image-upload" data-target="huhs-twitch-image" data-value="url">Feltöltés vagy kiválasztás</button></p>
                        <img id="huhs-twitch-image_preview" src="<?php echo esc_url($value['imageUrl']); ?>" alt="" style="display:block;max-width:420px;max-height:240px;object-fit:contain;">
                        <p class="description">Ha üres, a kártya a Twitch <strong>élő előnézetét</strong> használja (az csak adás közben mutat valamit).</p>
                    </td>
                </tr>
                <tr>
                    <th><label for="huhs-twitch-header">Felirat</label></th>
                    <td><input class="regular-text" maxlength="80" type="text" id="huhs-twitch-header" name="headerText" value="<?php echo esc_attr($value['headerText']); ?>" placeholder="Következő adás: péntek 20:00"></td>
                </tr>
                <tr>
                    <th>Megjelenítés</th>
                    <td>
                        <label><input type="checkbox" name="enabled" value="1" <?php checked($value['enabled']); ?>> Engedélyezve</label>
                        <p><label><input type="checkbox" name="showWhenOffline" value="1" <?php checked($value['showWhenOffline']); ?>> Élő adás nélkül is látszódjon (a fenti képpel)</label></p>
                        <p class="description">Az „élő adás nélkül is” bekapcsolásához <strong>kép is kell</strong> — kép nélkül mentéskor kikapcsol.</p>
                    </td>
                </tr>
            </tbody></table>
            <?php submit_button('Mentés'); ?>
        </form>
    </div>
    <?php
}

add_action('admin_post_huhs_save_startup_announcement', function () {
    if (!current_user_can('manage_options')) {
        wp_die('Nincs jogosultság.');
    }
    check_admin_referer('huhs_save_startup_announcement');
    $value = array(
        'imageUrl' => esc_url_raw(wp_unslash($_POST['imageUrl'] ?? '')),
        'enabled' => !empty($_POST['enabled']),
        'buttonLabel' => sanitize_text_field(wp_unslash($_POST['buttonLabel'] ?? '')),
        'buttonUrl' => esc_url_raw(wp_unslash($_POST['buttonUrl'] ?? '')),
    );
    $value = huhs_startup_announcement_normalize($value);
    if ($value['enabled'] && $value['imageUrl'] === '') {
        wp_safe_redirect(admin_url('admin.php?page=huhs-startup-announcement&error=missing_image'));
        exit;
    }
    update_option(HUHS_STARTUP_ANNOUNCEMENT_OPTION, $value, false);
    wp_safe_redirect(admin_url('admin.php?page=huhs-startup-announcement&saved=1'));
    exit;
});

function huhs_admin_api_permission()
{
    return current_user_can('manage_options');
}

function huhs_admin_api_read(WP_REST_Request $request)
{
    $action = sanitize_key((string) $request->get_param('action'));
    if ($action === 'dashboard') {
        return array(
            'artists' => (int) (wp_count_posts('huhs_artist')->publish ?? 0),
            'organizers' => (int) (wp_count_posts('huhs_organizer')->publish ?? 0),
            'events' => (int) (wp_count_posts('huhs_event')->publish ?? 0),
            'submissions' => (int) (wp_count_posts('huhs_submission')->pending ?? 0),
            'apiVersion' => HUHS_API_VERSION,
        );
    }
    if ($action === 'games') {
        $status_labels = array(
            'draft' => 'Piszkozat',
            'scheduled' => 'Időzítve',
            'active' => 'Aktív',
            'closed' => 'Lezárult',
            'results_expired' => 'Eredmények lejártak',
        );
        $items = array();
        foreach (get_posts(array(
            'post_type' => 'huhs_game',
            'post_status' => array('publish', 'future', 'draft', 'pending', 'private'),
            'posts_per_page' => -1,
            'orderby' => 'date',
            'order' => 'DESC',
        )) as $game) {
            $type = sanitize_key((string) get_post_meta($game->ID, '_huhs_game_type', true));
            $stats = get_post_meta($game->ID, '_huhs_game_stats', true);
            $stats = is_array($stats) ? $stats : array();
            $questions = function_exists('huhs_game_questions_json') ? huhs_game_questions_json($game->ID) : array();
            $timeline = function_exists('huhs_game_timeline_items') ? huhs_game_timeline_items($game->ID) : array();
            $status = huhs_game_status($game->ID);
            $items[] = array(
                'id' => (int) $game->ID,
                'title' => get_the_title($game),
                'type' => $type,
                'type_label' => HUHS_GAME_TYPES[$type] ?? 'Játék',
                'status' => $status,
                'status_label' => $status_labels[$status] ?? 'Ismeretlen',
                'artwork' => huhs_game_resolved_artwork($type, get_post_meta($game->ID, '_huhs_game_artwork', true)),
                'start_at' => get_post_meta($game->ID, '_huhs_game_start', true),
                'end_at' => get_post_meta($game->ID, '_huhs_game_end', true),
                'results_until' => get_post_meta($game->ID, '_huhs_game_results_until', true),
                'reward_points' => max(0, (int) get_post_meta($game->ID, '_huhs_game_reward_points', true)),
                'question_count' => count($questions),
                'timeline_count' => count($timeline),
                'submissions' => max(0, (int) ($stats['submissions'] ?? 0)),
                'correct_answers' => max(0, (int) ($stats['correct_answers'] ?? 0)),
                'total_answers' => max(0, (int) ($stats['total_answers'] ?? 0)),
                'stats_updated_at' => sanitize_text_field((string) ($stats['updated_at'] ?? '')),
            );
        }
        return array('items' => $items);
    }
    if ($action === 'settings') {
        return array(
            'apiVersion' => HUHS_API_VERSION,
            'baseUrl' => rest_url('huhs/v1'),
            'imageUpload' => 'Cloudinary',
            'moderatedSubmissions' => true,
        );
    }
    if ($action === 'voting_seasons') {
        $seasons = get_posts(array('post_type' => 'huhs_vote_season', 'post_status' => array('publish', 'draft'), 'posts_per_page' => -1, 'orderby' => 'date', 'order' => 'DESC'));
        $items = array();
        foreach ($seasons as $season) $items[] = huhs_vote_season_payload($season->ID, false);
        return array('seasons' => array_values(array_filter($items)));
    }
    // A KERDOIVEK listaja a valasztohoz (a mobil admin legorduloben valaszthat).
    //
    // Ugyanaz a minta, mint a WordPress-oldali „Kérdőív eredményei" oldalon: a
    // legfrissebb elol, a cimkeben az allapot es a szavazatszam — így a regi
    // kerdőívek eredmenye is visszanezheto.
    if ($action === 'polls') {
        $polls = get_posts(array(
            'post_type' => 'huhs_poll',
            'post_status' => array('publish', 'draft'),
            'posts_per_page' => 200,
            'orderby' => 'date',
            'order' => 'DESC',
        ));
        $items = array();
        foreach ($polls as $poll) {
            $results = huhs_poll_results($poll->ID);
            $items[] = array(
                'id' => (int) $poll->ID,
                'question' => (string) get_post_meta($poll->ID, '_huhs_poll_question', true)
                    ?: get_the_title($poll),
                'state' => huhs_poll_window_state($poll->ID),
                'votes' => max(0, (int) $results['total']),
            );
        }
        return array('polls' => $items);
    }
    if ($action === 'voting_summary') {
        $season_id = absint($request->get_param('seasonId'));
        if (!$season_id || get_post_type($season_id) !== 'huhs_vote_season') return new WP_Error('invalid_voting_season', 'Érvényes szavazási évad szükséges.', array('status' => 400));
        $summary = huhs_vote_firestore_summary($season_id);
        if (is_wp_error($summary)) return $summary;
        $season = huhs_vote_season_payload($season_id, false);
        return array_merge($summary, array(
            'seasonId' => $season_id,
            'season' => $season,
            // Keep the category list at the top level as well. This makes
            // the admin contract explicit and keeps older mobile clients
            // compatible with the detailed summary response.
            'categories' => (array) ($season['categories'] ?? array()),
        ));
    }
    // A KERDOIV eredmenye — szandekosan kulon action a `voting_summary`-tol.
    //
    // A mobil admin-osszesito korabban a `voting_summary`-t kerte a kerdőívhez,
    // ezert az ÉVES SZAVAZAS adatait mutatta a kerdőív helyett. A ketto teljesen
    // mas: az éves szavazas jeloltekre megy (Firestore-osszesites), a kerdőív
    // pedig egyetlen kerdes valaszlehetosegeire (meta-sorokbol ujraszamolva).
    //
    // `pollId` nelkul a NYITOTT kerdőívet, ha nincs, a legfrissebbet adja — így a
    // mobil admin legalabb egy kerdőívet mindig lat, es a regi kerdőívek is
    // visszanezhetok ugyanazon a vegponton.
    if ($action === 'poll_results') {
        $poll_id = absint($request->get_param('pollId'));
        if ($poll_id && get_post_type($poll_id) !== 'huhs_poll') {
            return new WP_Error('invalid_poll', 'Érvényes kérdőív szükséges.', array('status' => 400));
        }
        if (!$poll_id) $poll_id = (int) huhs_poll_active_id();
        if (!$poll_id) {
            $latest = get_posts(array(
                'post_type' => 'huhs_poll',
                'post_status' => array('publish', 'draft'),
                'posts_per_page' => 1,
                'orderby' => 'date',
                'order' => 'DESC',
                'fields' => 'ids',
                'no_found_rows' => true,
            ));
            $poll_id = $latest ? (int) $latest[0] : 0;
        }
        if (!$poll_id) return array('poll' => null);

        $options = huhs_poll_options($poll_id);
        $results = huhs_poll_results($poll_id);
        $total = max(0, (int) $results['total']);
        $items = array();
        foreach ($options as $index => $label) {
            $count = (int) ($results['counts'][$index] ?? 0);
            $items[] = array(
                'index' => $index,
                'label' => $label,
                'count' => $count,
                // A szazalek a KLIENSEN is kiszamithato, de itt adjuk, hogy a
                // felulet ne szamolhasson mast, mint az admin oldal.
                'percent' => $total > 0 ? (int) round($count * 100 / $total) : 0,
            );
        }
        return array('poll' => array(
            'id' => $poll_id,
            'question' => (string) get_post_meta($poll_id, '_huhs_poll_question', true)
                ?: get_the_title($poll_id),
            'state' => huhs_poll_window_state($poll_id),
            'start' => (string) get_post_meta($poll_id, '_huhs_poll_start', true),
            'end' => (string) get_post_meta($poll_id, '_huhs_poll_end', true),
            'total' => $total,
            'options' => $items,
        ));
    }
    // A NYEREMENYJATEK admin-nezete: ugyanaz, amit a WordPress „Nyereményjáték"
    // oldal mutat (legordulo, valaszlehetosegek, resztvevok) — csak az appban.
    //
    // FONTOS: a nyilvanos `/prize/active` SZANDEKOSAN nem adja ki a helyes
    // valaszt a sorsolas elott; ez a vegpont `manage_options` mogott van, ezert
    // itt az admin LATHATJA (kulonben nem tudna ellenorizni a sajat jatekat).
    // UID-t es hash-t viszont itt sem adunk ki: az appnak nem kell.
    if ($action === 'prize_games') {
        $games = get_posts(array(
            'post_type' => 'huhs_prize',
            'post_status' => array('publish', 'draft'),
            'posts_per_page' => 200,
            'orderby' => 'date',
            'order' => 'DESC',
        ));
        $items = array();
        foreach ($games as $game) {
            $summary = huhs_prize_summary($game->ID);
            $winner = huhs_prize_winner($game->ID);
            $items[] = array(
                'id' => (int) $game->ID,
                'question' => (string) get_post_meta($game->ID, '_huhs_prize_question', true)
                    ?: get_the_title($game),
                'state' => huhs_prize_window_state($game->ID),
                'players' => max(0, (int) $summary['total']),
                'correct' => max(0, (int) $summary['correct']),
                'winner' => $winner ? (string) ($winner['name'] ?? '') : '',
            );
        }
        return array('prizes' => $items);
    }
    if ($action === 'prize_results') {
        $prize_id = absint($request->get_param('prizeId'));
        if ($prize_id && get_post_type($prize_id) !== 'huhs_prize') {
            return new WP_Error('invalid_prize', 'Érvényes nyereményjáték szükséges.', array('status' => 400));
        }
        // `prizeId` nelkul a nyitott jatekot, ha nincs, a frissen kihirdetett
        // nyertest, vegul a legfrissebbet adja — igy a mobil admin mindig lat
        // valamit, es a regi jatekok is visszanezhetok.
        if (!$prize_id) $prize_id = (int) huhs_prize_active_id();
        if (!$prize_id) $prize_id = (int) huhs_prize_recent_winner_id();
        if (!$prize_id) {
            $latest = get_posts(array(
                'post_type' => 'huhs_prize',
                'post_status' => array('publish', 'draft'),
                'posts_per_page' => 1,
                'orderby' => 'date',
                'order' => 'DESC',
                'fields' => 'ids',
                'no_found_rows' => true,
            ));
            $prize_id = $latest ? (int) $latest[0] : 0;
        }
        if (!$prize_id) return array('prize' => null);

        $answers = huhs_prize_answers($prize_id);
        $entries = huhs_prize_entries($prize_id);
        $summary = huhs_prize_summary($prize_id);
        $total = max(0, (int) $summary['total']);
        $counts = array();
        foreach ($entries as $entry) {
            $index = isset($entry['answer']) ? (int) $entry['answer'] : -1;
            $counts[$index] = (int) ($counts[$index] ?? 0) + 1;
        }
        $answer_items = array();
        foreach ($answers as $index => $label) {
            $count = (int) ($counts[$index] ?? 0);
            $answer_items[] = array(
                'index' => (int) $index,
                'label' => (string) $label,
                'count' => $count,
                // A szazalekot itt szamoljuk, hogy a felulet ne szamolhasson
                // mast, mint a WordPress-oldali admin.
                'percent' => $total > 0 ? (int) round($count * 100 / $total) : 0,
            );
        }
        $winner = huhs_prize_winner($prize_id);
        $winner_hash = (string) get_post_meta($prize_id, '_huhs_prize_winner_hash', true);
        $participants = array();
        foreach ($entries as $entry) {
            $index = isset($entry['answer']) ? (int) $entry['answer'] : -1;
            $name = trim((string) ($entry['name'] ?? ''));
            $participants[] = array(
                'name' => $name !== '' ? $name : 'névtelen játékos',
                'answerIndex' => $index,
                'answerLabel' => (string) ($answers[$index] ?? ('#' . ($index + 1))),
                'correct' => !empty($entry['correct']),
                'at' => (string) ($entry['at'] ?? ''),
                'winner' => $winner_hash !== '' && $winner_hash === (string) ($entry['hash'] ?? ''),
            );
        }
        // A legfrissebb jatekos elol (a meta-sorok sorrendje a jatek menete).
        $participants = array_reverse($participants);

        return array('prize' => array(
            'id' => $prize_id,
            'question' => (string) get_post_meta($prize_id, '_huhs_prize_question', true)
                ?: get_the_title($prize_id),
            'state' => huhs_prize_window_state($prize_id),
            'start' => (string) get_post_meta($prize_id, '_huhs_prize_start', true),
            'end' => (string) get_post_meta($prize_id, '_huhs_prize_end', true),
            'prizeType' => (string) get_post_meta($prize_id, '_huhs_prize_type', true),
            'prizeDescription' => (string) get_post_meta($prize_id, '_huhs_prize_description', true),
            'correctIndex' => (int) get_post_meta($prize_id, '_huhs_prize_correct', true),
            'players' => $total,
            'correct' => max(0, (int) $summary['correct']),
            'displayDays' => (int) huhs_prize_display_days($prize_id),
            'winner' => $winner ? array(
                'name' => (string) ($winner['name'] ?? ''),
                'drawnAt' => (string) ($winner['drawn_at'] ?? ''),
            ) : null,
            'answers' => $answer_items,
            'participants' => $participants,
        ));
    }
    if ($action === 'push') {
        $tokens = get_option(HUHS_PUSH_TOKENS_OPTION, array());
        $account = huhs_push_service_account();
        $targets = array();
        foreach (get_posts(array(
            'post_type' => array('post', 'huhs_event', 'huhs_release'),
            'post_status' => 'publish',
            'posts_per_page' => 60,
            'orderby' => 'date',
            'order' => 'DESC',
        )) as $post) {
            $types = array('post' => 'news', 'huhs_event' => 'event', 'huhs_release' => 'release');
            if (!isset($types[$post->post_type])) continue;
            $targets[] = array(
                'id' => (int) $post->ID,
                'type' => $types[$post->post_type],
                'title' => sanitize_text_field(get_the_title($post)),
                'url' => esc_url_raw(get_permalink($post) ?: ''),
            );
        }
        return array(
            'registeredDevices' => is_array($tokens) ? count($tokens) : 0,
            'configured' => !empty($account['project_id']) && !empty($account['client_email']) && !empty($account['private_key']),
            'targets' => $targets,
        );
    }
    if ($action === 'newsletter') {
        $settings = get_option(HUHS_MAILCHIMP_OPTION, array());
        return array(
            'configured' => !empty($settings['api_key']) && !empty($settings['audience_id']),
            'audienceId' => sanitize_text_field((string) ($settings['audience_id'] ?? '')),
            'dataCenter' => sanitize_key((string) ($settings['data_center'] ?? '')),
        );
    }
    if ($action === 'shortcodes') {
        return array('items' => array(
            array('name' => '[huhs_djs]', 'description' => 'Teljes DJ-gyűjtő.'),
            array('name' => '[huhs_djs category="hardstyle"]', 'description' => 'Hardstyle DJ-k.'),
            array('name' => '[huhs_djs category="hardcore"]', 'description' => 'Hardcore DJ-k.'),
            array('name' => '[huhs_events]', 'description' => 'Közelgő események.'),
            array('name' => '[huhs_events include_past="true"]', 'description' => 'Események archívummal.'),
        ));
    }
    if ($action === 'about') {
        return array(
            'project' => 'Hungarian Hardstyle',
            'developer' => 'Denoiser',
            'apiVersion' => HUHS_API_VERSION,
            'website' => 'https://hungarianhardstyle.hu',
        );
    }
    if ($action === 'startup') {
        return huhs_startup_announcement_value();
    }
    if ($action === 'resource') {
        $post_id = absint($request->get_param('id'));
        $post_type = sanitize_key((string) $request->get_param('type'));
        $fields = huhs_admin_resource_fields($post_type);
        if (!$post_id) {
            // LÉTREHOZÁS: még nincs bejegyzés, ezért csak a mező-definíciókat adjuk
            // vissza (üres értékkel). Így az app UGYANAZT az űrlapot tudja használni
            // a létrehozáshoz és a szerkesztéshez — nincs két, szétszakadó út.
            if (!huhs_admin_is_creatable_type($post_type) || !$fields) {
                return new WP_Error(
                    'invalid_admin_resource',
                    'Ebből a típusból nem hozható létre elem az appból.',
                    array('status' => 404)
                );
            }
            return array(
                'id' => 0,
                'title' => '',
                'content' => '',
                'status' => 'draft',
                'creatable' => true,
                'fields' => array_map(function ($field) {
                    $field['value'] = '';
                    return $field;
                }, $fields),
            );
        }
        $post = get_post($post_id);
        if (!$post || $post->post_type !== $post_type || !$fields || !current_user_can('edit_post', $post_id)) {
            return new WP_Error('invalid_admin_resource', 'Az elem nem szerkeszthető.', array('status' => 404));
        }
        return array(
            'id' => $post_id,
            'title' => $post->post_title,
            'content' => $post->post_content,
            'status' => $post->post_status,
            'fields' => array_map(function ($field) use ($post_id) {
                $field['value'] = get_post_meta($post_id, $field['key'], true);
                $options = huhs_admin_resource_field_options($field['key']);
                if ($options) {
                    $field['options'] = $options;
                }
                return $field;
            }, $fields),
        );
    }
    if ($action === 'trash') {
        $items = array();
        foreach (huhs_trash_post_types() as $post_type) {
            foreach (get_posts(array(
                'post_type' => $post_type,
                'post_status' => 'trash',
                'posts_per_page' => -1,
                'orderby' => 'modified',
                'order' => 'DESC',
            )) as $post) {
                $items[] = array(
                    'id' => (int) $post->ID,
                    'title' => get_the_title($post),
                    'type' => $post_type,
                    'modified' => get_post_modified_time(DATE_ATOM, false, $post),
                );
            }
        }
        return array('items' => $items);
    }
    return new WP_Error('invalid_admin_action', 'Ismeretlen admin művelet.', array('status' => 400));
}

function huhs_admin_api_write(WP_REST_Request $request)
{
    $params = $request->get_json_params();
    $action = sanitize_key((string) ($params['action'] ?? ''));
    if ($action === 'send_push') {
        $title = sanitize_text_field((string) ($params['title'] ?? ''));
        $body = sanitize_textarea_field((string) ($params['body'] ?? ''));
        if ($title === '' || $body === '') {
            return new WP_Error('missing_push_content', 'A cím és az üzenet kötelező.', array('status' => 400));
        }
        $target = huhs_push_resolve_custom_target(
            $params['targetType'] ?? 'none',
            $params['targetId'] ?? 0,
            $params['url'] ?? ''
        );
        if (is_wp_error($target)) return $target;
        return huhs_push_queue_custom($title, $body, $target);
    }
    // NYEREMÉNYJÁTÉK — a törölt fiók kivétele (2.14.18).
    //
    // A tulajdonos kérése: *„ha valaki törli a regisztrációját az appban,
    // kerüljön ki a neve a nyereményjátékból is, ne nyerhessen jegyet”*. A
    // törlést a Cloud Function kéri (a fiók törlésekor), a játékos azonosítója
    // pedig a Firebase UID — a sózott hash miatt csak itt lehet feloldani.
    if ($action === 'prize_forget') {
        $uid = sanitize_text_field((string) ($params['uid'] ?? ''));
        if ($uid === '') {
            return new WP_Error('missing_uid', 'Hiányzó felhasználó-azonosító.', array('status' => 400));
        }
        return huhs_prize_forget_player($uid);
    }
    if ($action === 'empty_trash') {        $deleted = 0;
        foreach (huhs_trash_post_types() as $post_type) {
            $ids = get_posts(array(
                'post_type' => $post_type,
                'post_status' => 'trash',
                'posts_per_page' => -1,
                'fields' => 'ids',
            ));
            foreach ($ids as $post_id) {
                huhs_delete_submission_attachments($post_id);
                if (wp_delete_post($post_id, true)) {
                    $deleted++;
                }
            }
        }
        return array('deleted' => $deleted);
    }
    if ($action === 'restore') {
        $post_id = absint($params['id'] ?? 0);
        if (!$post_id || get_post_status($post_id) !== 'trash' || !in_array(get_post_type($post_id), huhs_trash_post_types(), true)) {
            return new WP_Error('invalid_trash_item', 'A lomtárelem nem állítható vissza.', array('status' => 400));
        }
        return array('restored' => (bool) wp_untrash_post($post_id));
    }
    if ($action === 'save_settings') {
        foreach (array('blogname', 'blogdescription', 'timezone_string', 'date_format', 'time_format') as $key) {
            if (array_key_exists($key, $params)) {
                update_option($key, sanitize_text_field((string) $params[$key]));
            }
        }
        return array('saved' => true);
    }
    if ($action === 'save_startup') {
        $value = array(
            'imageUrl' => esc_url_raw((string) ($params['imageUrl'] ?? '')),
            'enabled' => filter_var($params['enabled'] ?? false, FILTER_VALIDATE_BOOLEAN),
            'buttonLabel' => sanitize_text_field((string) ($params['buttonLabel'] ?? '')),
            'buttonUrl' => esc_url_raw((string) ($params['buttonUrl'] ?? '')),
        );
        $value = huhs_startup_announcement_normalize($value);
        if ($value['enabled'] && $value['imageUrl'] === '') {
            return new WP_Error('missing_startup_image', 'Bekapcsolva kép URL szükséges.', array('status' => 400));
        }
        update_option(HUHS_STARTUP_ANNOUNCEMENT_OPTION, $value, false);
        return array('saved' => true) + $value;
    }
    if ($action === 'save_resource') {
        $post_id = absint($params['id'] ?? 0);
        $post_type = sanitize_key((string) ($params['type'] ?? ''));
        $fields = huhs_admin_resource_fields($post_type);
        if (!$fields) {
            return new WP_Error('invalid_admin_resource', 'Az elem nem szerkeszthető.', array('status' => 404));
        }
        $values = is_array($params['meta'] ?? null) ? $params['meta'] : array();
        if (!$post_id) {
            // LÉTREHOZÁS a natív adminból (kérdőív / nyereményjáték / kvíz).
            if (!huhs_admin_is_creatable_type($post_type)) {
                return new WP_Error(
                    'invalid_admin_resource',
                    'Ebből a típusból nem hozható létre elem az appból.',
                    array('status' => 404)
                );
            }
            $error = huhs_admin_validate_resource_values($post_type, $values);
            if ($error !== '') {
                return new WP_Error('invalid_admin_resource_values', $error, array('status' => 400));
            }
            $created = wp_insert_post(array(
                'post_type' => $post_type,
                'post_status' => huhs_admin_created_status($params['status'] ?? ''),
                'post_title' => huhs_admin_resource_title($post_type, $values, (string) ($params['title'] ?? '')),
            ), true);
            if (is_wp_error($created)) {
                return $created;
            }
            $post_id = (int) $created;
            foreach ($fields as $field) {
                $key = $field['key'];
                if (!array_key_exists($key, $values)) {
                    continue;
                }
                update_post_meta($post_id, $key, huhs_admin_encode_meta_value($field, $values[$key]));
            }
            huhs_admin_normalize_resource_meta($post_id, $post_type, $values);
            return array('saved' => true, 'id' => $post_id, 'created' => true);
        }
        $post = get_post($post_id);
        if (!$post || $post->post_type !== $post_type || !current_user_can('edit_post', $post_id)) {
            return new WP_Error('invalid_admin_resource', 'Az elem nem szerkeszthető.', array('status' => 404));
        }
        if ($values) {
            $error = huhs_admin_validate_resource_values($post_type, $values);
            if ($error !== '') {
                return new WP_Error('invalid_admin_resource_values', $error, array('status' => 400));
            }
        }
        $content = $post->post_content;
        if (!empty($params['contentChanged'])) {
            $content = wpautop(esc_html(wp_unslash((string) ($params['content'] ?? ''))));
        }
        $updated = wp_update_post(array(
            'ID' => $post_id,
            'post_title' => sanitize_text_field((string) ($params['title'] ?? $post->post_title)),
            'post_content' => $content,
        ), true);
        if (is_wp_error($updated)) {
            return $updated;
        }
        foreach ($fields as $field) {
            $key = $field['key'];
            if (!array_key_exists($key, $values)) {
                continue;
            }
            update_post_meta($post_id, $key, huhs_admin_encode_meta_value($field, $values[$key]));
        }
        huhs_admin_normalize_resource_meta($post_id, $post_type, $values);
        return array('saved' => true, 'id' => $post_id);
    }
    return new WP_Error('invalid_admin_action', 'Ismeretlen admin művelet.', array('status' => 400));
}

function huhs_admin_resource_fields($post_type)
{
    $common = array(
        array('key' => 'featured', 'label' => 'Kiemelt', 'type' => 'bool'),
        array('key' => 'visible', 'label' => 'Látható az appban', 'type' => 'bool'),
    );
    if ($post_type === 'huhs_event') {
        return array_merge(array(
            array('key' => 'event_start_date', 'label' => 'Kezdő dátum', 'type' => 'text'),
            array('key' => 'event_start_time', 'label' => 'Kezdő idő', 'type' => 'text'),
            array('key' => 'event_end_date', 'label' => 'Záró dátum', 'type' => 'text'),
            array('key' => 'event_end_time', 'label' => 'Záró idő', 'type' => 'text'),
            array('key' => 'venue_name', 'label' => 'Helyszín', 'type' => 'text'),
            array('key' => 'venue_city', 'label' => 'Város', 'type' => 'text'),
            array('key' => 'venue_zip', 'label' => 'Irányítószám', 'type' => 'text'),
            array('key' => 'venue_address', 'label' => 'Cím', 'type' => 'text'),
            array('key' => 'venue_country', 'label' => 'Ország', 'type' => 'text'),
            array('key' => 'google_maps', 'label' => 'Google Maps', 'type' => 'url'),
            array('key' => 'facebook_event_url', 'label' => 'Facebook esemény', 'type' => 'url'),
            array('key' => 'ticket_type', 'label' => 'Jegytípus', 'type' => 'text'),
            array('key' => 'ticket_url', 'label' => 'Jegyvásárlás', 'type' => 'url'),
            array('key' => 'genre', 'label' => 'Műfajok', 'type' => 'text'),
            array('key' => 'organizer_id', 'label' => 'Szervező ID', 'type' => 'int'),
            array('key' => 'artists', 'label' => 'DJ ID-k (vesszővel)', 'type' => 'ids'),
            array('key' => 'status', 'label' => 'Esemény állapota', 'type' => 'text'),
            array('key' => 'flyer_image', 'label' => 'Flyer média ID', 'type' => 'int'),
        ), $common);
    }
    if ($post_type === 'huhs_artist') {
        return array_merge(array(
            array('key' => 'real_name', 'label' => 'Polgári név', 'type' => 'text'),
            array('key' => 'country', 'label' => 'Ország', 'type' => 'text'),
            array('key' => 'city', 'label' => 'Város', 'type' => 'text'),
            array('key' => 'website', 'label' => 'Website', 'type' => 'url'),
            array('key' => 'genre', 'label' => 'Műfajok', 'type' => 'text'),
            array('key' => 'facebook', 'label' => 'Facebook', 'type' => 'url'),
            array('key' => 'instagram', 'label' => 'Instagram', 'type' => 'url'),
            array('key' => 'tiktok', 'label' => 'TikTok', 'type' => 'url'),
            array('key' => 'spotify', 'label' => 'Spotify', 'type' => 'url'),
            array('key' => 'soundcloud', 'label' => 'SoundCloud', 'type' => 'url'),
            array('key' => 'youtube', 'label' => 'YouTube', 'type' => 'url'),
            array('key' => 'booking_email', 'label' => 'Booking e-mail', 'type' => 'email'),
            // ⚠️ A **privát** (kapcsolattartó) e-mail: NEM publikus, a nyilvános
            // adatlapról szándékosan kimarad — viszont az adminnak látnia és
            // javítania kell tudnia (a tulajdonos jelzése, 2026-09-24: „nem tudom
            // átírni egy artist/dj privát mail címét se a WP Apiban se a natív
            // huhs vezérlőben, meg látni se látom sehol"). Ez a mező az admin
            // űrlapon keresztül olvasható és írható; a `type: 'email'` miatt a
            // mentés `sanitize_email`-en megy át.
            array('key' => 'contact_email', 'label' => 'Privát e-mail (kapcsolattartó, az adatlap átvételéhez)', 'type' => 'email'),
            array('key' => 'booking_via_huhs', 'label' => 'Booking a Hungarian Hardstyle-on keresztül', 'type' => 'bool'),
            array('key' => 'hero_image', 'label' => 'Profilkép média ID', 'type' => 'int'),
            array('key' => 'logo', 'label' => 'Logó média ID', 'type' => 'int'),
        ), $common);
    }
    if ($post_type === 'huhs_organizer') {
        return array_merge(array(
            array('key' => 'website', 'label' => 'Website', 'type' => 'url'),
            array('key' => 'facebook', 'label' => 'Facebook', 'type' => 'url'),
            array('key' => 'instagram', 'label' => 'Instagram', 'type' => 'url'),
            array('key' => 'tiktok', 'label' => 'TikTok', 'type' => 'url'),
            array('key' => 'email', 'label' => 'E-mail', 'type' => 'email'),
            array('key' => 'phone', 'label' => 'Telefon', 'type' => 'text'),
            array('key' => 'city', 'label' => 'Város', 'type' => 'text'),
            array('key' => 'country', 'label' => 'Ország', 'type' => 'text'),
            array('key' => 'genre', 'label' => 'Műfajok', 'type' => 'text'),
            array('key' => 'logo', 'label' => 'Logó média ID', 'type' => 'int'),
        ), $common);
    }
    if ($post_type === 'huhs_release') {
        return array_merge(array(
            array('key' => 'radio_audio_url', 'label' => 'Radio source URL', 'type' => 'url'),
            array('key' => 'extended_audio_url', 'label' => 'Extended source URL', 'type' => 'url'),
            array('key' => 'radio_wav_product_id', 'label' => 'Radio WAV Play product ID', 'type' => 'text'),
            array('key' => 'radio_wav_price', 'label' => 'Radio WAV price', 'type' => 'text'),
            array('key' => 'radio_mp3_product_id', 'label' => 'Radio MP3 320 Play product ID', 'type' => 'text'),
            array('key' => 'radio_mp3_price', 'label' => 'Radio MP3 320 price', 'type' => 'text'),
            array('key' => 'extended_wav_product_id', 'label' => 'Extended WAV Play product ID', 'type' => 'text'),
            array('key' => 'extended_wav_price', 'label' => 'Extended WAV price', 'type' => 'text'),
            array('key' => 'extended_mp3_product_id', 'label' => 'Extended MP3 320 Play product ID', 'type' => 'text'),
            array('key' => 'extended_mp3_price', 'label' => 'Extended MP3 320 price', 'type' => 'text'),
            array('key' => 'genre', 'label' => 'Műfaj', 'type' => 'text'),
            array('key' => 'artists', 'label' => 'Előadó ID-k (vesszővel)', 'type' => 'ids'),
            array('key' => 'cover', 'label' => 'Borító média ID', 'type' => 'int'),
            array('key' => 'preview_url', 'label' => 'Preview MP3 URL', 'type' => 'url'),
            array('key' => 'spotify', 'label' => 'Spotify', 'type' => 'url'),
            array('key' => 'apple_music', 'label' => 'Apple Music', 'type' => 'url'),
            array('key' => 'beatport', 'label' => 'Beatport', 'type' => 'url'),
            array('key' => 'hardstyle_com', 'label' => 'Hardstyle.com', 'type' => 'url'),
            array('key' => 'youtube', 'label' => 'YouTube', 'type' => 'url'),
        ), $common);
    }
    // A natív adminból létrehozható „interakciós” típusok (kérdőív, nyereményjáték,
    // kvíz) mezői. A kulcs mindig a valódi meta-kulcs, ezért a mentés nem tud
    // elcsúszni a WordPress-oldali űrlaptól (lásd includes/admin-create.php).
    $interaction = huhs_admin_interaction_fields($post_type);
    if ($interaction) {
        return $interaction;
    }
    return array();
}

function huhs_admin_resource_field_options($key)
{
    if ($key === 'artists') {
        return array_map(function ($post) {
            return array('id' => (int) $post->ID, 'label' => $post->post_title);
        }, get_posts(array(
            'post_type' => 'huhs_artist',
            'post_status' => 'publish',
            'posts_per_page' => -1,
            'orderby' => 'title',
            'order' => 'ASC',
        )));
    }
    if ($key === 'organizer_id') {
        return array_map(function ($post) {
            return array('id' => (int) $post->ID, 'label' => $post->post_title);
        }, get_posts(array(
            'post_type' => 'huhs_organizer',
            'post_status' => 'publish',
            'posts_per_page' => -1,
            'orderby' => 'title',
            'order' => 'ASC',
        )));
    }
    return array();
}

function huhs_startup_announcement_value()
{
    $value = get_option(HUHS_STARTUP_ANNOUNCEMENT_OPTION, array());
    return huhs_startup_announcement_normalize(array(
        'imageUrl' => esc_url_raw((string) ($value['imageUrl'] ?? '')),
        'enabled' => !empty($value['enabled']),
        'buttonLabel' => sanitize_text_field((string) ($value['buttonLabel'] ?? '')),
        'buttonUrl' => esc_url_raw((string) ($value['buttonUrl'] ?? '')),
    ));
}

function huhs_startup_announcement_normalize($value)
{
    $value['buttonLabel'] = mb_substr(trim((string) ($value['buttonLabel'] ?? '')), 0, 40);
    $button_url = trim((string) ($value['buttonUrl'] ?? ''));
    $parts = wp_parse_url($button_url);
    $valid_url = $button_url !== ''
        && is_array($parts)
        && strtolower((string) ($parts['scheme'] ?? '')) === 'https'
        && !empty($parts['host'])
        && wp_http_validate_url($button_url);
    $value['buttonUrl'] = $valid_url && $value['buttonLabel'] !== '' ? esc_url_raw($button_url) : '';
    if ($value['buttonUrl'] === '') {
        $value['buttonLabel'] = '';
    }
    return $value;
}

function huhs_startup_announcement_read()
{
    $response = new WP_REST_Response(huhs_startup_announcement_value());
    $response->header('Cache-Control', 'no-store, no-cache, must-revalidate, max-age=0');
    return $response;
}

function huhs_startup_announcement_page()
{
    $value = huhs_startup_announcement_value();
    ?>
    <div class="wrap">
        <h1>Indítási kép</h1>
        <p>A kép az alkalmazás következő indításakor minden felhasználónál megjelenik, amíg ki nem kapcsolod vagy el nem távolítod.</p>
        <?php if (!empty($_GET['saved'])) : ?><div class="notice notice-success"><p>Beállítás mentve.</p></div><?php endif; ?>
        <?php if (!empty($_GET['error'])) : ?><div class="notice notice-error"><p>Bekapcsolva kép URL szükséges.</p></div><?php endif; ?>
        <form method="post" action="<?php echo esc_url(admin_url('admin-post.php')); ?>">
            <input type="hidden" name="action" value="huhs_save_startup_announcement">
            <?php wp_nonce_field('huhs_save_startup_announcement'); ?>
            <table class="form-table"><tbody>
                <tr>
                    <th><label for="huhs-startup-image">Kép</label></th>
                    <td>
                        <input class="large-text" type="url" id="huhs-startup-image" name="imageUrl" value="<?php echo esc_attr($value['imageUrl']); ?>">
                        <p><button type="button" class="button huhs-image-upload" data-target="huhs-startup-image" data-value="url">Feltöltés vagy kiválasztás</button></p>
                        <img id="huhs-startup-image_preview" src="<?php echo esc_url($value['imageUrl']); ?>" alt="" style="display:block;max-width:420px;max-height:240px;object-fit:contain;">
                    </td>
                </tr>
                <tr>
                    <th><label for="huhs-startup-button-label">Gomb felirata</label></th>
                    <td><input class="regular-text" maxlength="40" type="text" id="huhs-startup-button-label" name="buttonLabel" value="<?php echo esc_attr($value['buttonLabel']); ?>" placeholder="Jegyek vagy Esemény"></td>
                </tr>
                <tr>
                    <th><label for="huhs-startup-button-url">Gomb linkje</label></th>
                    <td><input class="large-text" type="url" id="huhs-startup-button-url" name="buttonUrl" value="<?php echo esc_attr($value['buttonUrl']); ?>" placeholder="https://..."><p class="description">Csak HTTPS-link használható. Ha üres, a gomb nem jelenik meg.</p></td>
                </tr>
                <tr><th>Megjelenítés</th><td><label><input type="checkbox" name="enabled" value="1" <?php checked($value['enabled']); ?>> Engedélyezve</label></td></tr>
            </tbody></table>
            <?php submit_button('Mentés'); ?>
        </form>
    </div>
    <?php
}
