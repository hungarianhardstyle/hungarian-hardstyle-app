<?php

if (!defined('ABSPATH')) exit;

/**
 * Kozvelemenykutatas - Kerdőív.
 *
 * Egy kerdés, legfeljebb tiz valaszlehetoseg, beallithato kezdo és zaro
 * idoponttal. Az app csak a ket datum kozott latja a kerdőívet, es csak
 * regisztralt felhasznalo szavazhat, egy fiok egyszer.
 *
 * Adatvedelem: a WordPress **soha** nem tarol felhasznalonevet, e-mail-címet
 * vagy Firebase UID-t. Minden szavazat csak egy sotolt ujjlenyomatot hagy
 * maga utan (`_huhs_poll_vote_<hash>`), amibol a duplikacio kiszurheto, de a
 * szavazo nem azonosithato. Az eredmeny csak osszesitve, kizarolag az admin
 * feluleten jelenik meg; publikus eredmeny-vegpont szandekosan nincs.
 */

if (!defined('HUHS_POLL_MAX_OPTIONS')) {
    define('HUHS_POLL_MAX_OPTIONS', 10);
}

/**
 * A szavazok ujjlenyomatanak soja. Egyszer generalodik, es a szerveren marad,
 * ezert a kliens nem tud mas felhasznalo neveben szavazni.
 */
function huhs_poll_salt()
{
    $salt = (string) get_option('huhs_poll_salt', '');
    if ($salt === '') {
        $salt = wp_generate_password(48, false, false);
        update_option('huhs_poll_salt', $salt, false);
    }
    return $salt;
}

function huhs_poll_voter_hash($poll_id, $uid)
{
    $uid = trim((string) $uid);
    if ($uid === '') return '';
    return hash('sha256', absint($poll_id) . '|' . $uid . '|' . huhs_poll_salt());
}

/**
 * A 2.4.113 elotti mentesek javitasa.
 *
 * Az update_post_meta() a meta ertekere wp_unslash()-t futtat, mert a WordPress
 * a $_POST-ot megslasheli. A json_encode() viszont a nem-ASCII karaktereket
 * \uXXXX alakra irja, es annak a backslashnek nincs parja, amit a wp_unslash()
 * lenyelhetne: egyszeruen torli. Igy az "Utálom" szoveg "Utu00e1lom" alakban
 * tarolodott, es ez kerult volna ki az appba is.
 *
 * Ez a fuggveny a hianyzo backslasht allitja vissza, tehat a REGI adat is
 * helyesen jelenik meg a WP adminban es az appban. A minta az opcionalis
 * backslasht is elfogadja, ezert ismetelt hivasra ugyanazt adja vissza, a mar
 * helyes adatot nem rontja el.
 */
function huhs_poll_repair_escapes($raw)
{
    $raw = (string) $raw;
    if ($raw === '' || strpos($raw, 'u') === false) return $raw;
    return (string) preg_replace_callback('/\\\\?u([0-9a-fA-F]{4})/', function ($match) {
        return '\\u' . $match[1];
    }, $raw);
}

/** A kerdőív valaszlehetosegei, uresek nelkul, legfeljebb tiz. */
function huhs_poll_options($poll_id)
{
    $stored = huhs_poll_repair_escapes(get_post_meta($poll_id, '_huhs_poll_options', true));
    $raw = json_decode($stored, true);
    $options = array();
    foreach ((array) $raw as $label) {
        $label = sanitize_text_field((string) $label);
        if ($label === '') continue;
        $options[] = $label;
        if (count($options) >= HUHS_POLL_MAX_OPTIONS) break;
    }
    return $options;
}

/**
 * 'before' | 'open' | 'closed'.
 *
 * A datumok a webhely idozonajaban ertendok, ugyanugy, mint a kiadvanyok
 * megjelenesi datuma. Hianyzo datum eseten a hatar nyitott: egy elgepelt datum
 * ne tegye hasznalhatatlanna a kerdőívet.
 */
function huhs_poll_window_state($poll_id)
{
    $start = trim((string) get_post_meta($poll_id, '_huhs_poll_start', true));
    $end = trim((string) get_post_meta($poll_id, '_huhs_poll_end', true));
    $now = current_time('Y-m-d\TH:i');
    if ($start !== '' && $now < $start) return 'before';
    if ($end !== '' && $now > $end) return 'closed';
    return 'open';
}

/** A jelenleg nyitott kerdőív, vagy 0. Egyszerre egy kerdőív lehet aktiv. */
function huhs_poll_active_id()
{
    $polls = get_posts(array(
        'post_type' => 'huhs_poll',
        'post_status' => 'publish',
        'posts_per_page' => 20,
        'orderby' => 'date',
        'order' => 'DESC',
    ));
    foreach ($polls as $poll) {
        if (huhs_poll_options($poll->ID) && huhs_poll_window_state($poll->ID) === 'open') {
            return (int) $poll->ID;
        }
    }
    return 0;
}

/**
 * Osszesitett szavazatszam valaszlehetosegenkent.
 *
 * Szandekosan a szavazatokbol szamoljuk ujra, nem kulon szamlalobol: így egy
 * megszakitott keres nem tud szamlalot es szavazatot eltero allapotban hagyni.
 */
function huhs_poll_results($poll_id)
{
    global $wpdb;
    $poll_id = absint($poll_id);
    $option_count = count(huhs_poll_options($poll_id));
    $counts = array_fill(0, max(1, $option_count), 0);
    $votes = $wpdb->get_results($wpdb->prepare(
        "SELECT meta_value FROM {$wpdb->postmeta} WHERE post_id = %d AND meta_key LIKE %s",
        $poll_id,
        $wpdb->esc_like('_huhs_poll_vote_') . '%'
    ));
    foreach ((array) $votes as $row) {
        $index = absint($row->meta_value);
        if ($index >= 0 && $index < count($counts)) $counts[$index]++;
    }
    return array('counts' => $counts, 'total' => array_sum($counts));
}

/*
|--------------------------------------------------------------------------
| Admin: kerdőív szerkesztese
|--------------------------------------------------------------------------
*/

/**
 * Egyszeri javitas a 2.4.113 elott mentett kerdőívekre.
 *
 * A read-oldali javitas onmagaban is helyes eredmenyt ad, de a tarolt adat
 * addig csonka maradna. Ez a lepes visszairja a tiszta szoveget, ezert a
 * tulajdonosnak NEM kell újramentenie a kerdőívet. A jelzo beallitasa utan
 * minden tovabbi keres egyetlen get_option().
 */
add_action('init', function () {
    if (get_option('huhs_poll_escape_repair') === HUHS_API_VERSION) return;
    $poll_ids = get_posts(array(
        'post_type' => 'huhs_poll',
        'post_status' => 'any',
        'posts_per_page' => 50,
        'fields' => 'ids',
        'no_found_rows' => true,
    ));
    foreach ($poll_ids as $poll_id) {
        $stored = (string) get_post_meta($poll_id, '_huhs_poll_options', true);
        if ($stored === '') continue;
        $labels = json_decode(huhs_poll_repair_escapes($stored), true);
        // Ha a tarolt JSON ennel is serultebb, nem nyulunk hozza: egy olvashatatlan
        // erteket nem irunk felul egy ures listaval.
        if (!is_array($labels)) continue;
        $clean = array();
        foreach ($labels as $label) {
            $label = sanitize_text_field((string) $label);
            if ($label !== '') $clean[] = $label;
        }
        if (!$clean) continue;
        update_post_meta($poll_id, '_huhs_poll_options', wp_slash(wp_json_encode($clean, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES)));
    }
    update_option('huhs_poll_escape_repair', HUHS_API_VERSION);
}, 20);

add_action('init', function () {
    register_post_type('huhs_poll', array(
        'labels' => array(
            'name' => 'Kérdőív',
            'singular_name' => 'Kérdőív',
            'add_new_item' => 'Új kérdőív',
            'edit_item' => 'Kérdőív szerkesztése',
        ),
        'public' => false,
        'show_ui' => true,
        'show_in_menu' => 'huhs-mobile',
        'supports' => array('title'),
        'rewrite' => false,
    ));
});

add_action('add_meta_boxes', function () {
    add_meta_box('huhs_poll_box', 'Kérdőív beállításai', 'huhs_poll_meta_box', 'huhs_poll', 'normal', 'high');
});

function huhs_poll_meta_box($post)
{
    wp_nonce_field('huhs_poll_save', 'huhs_poll_nonce');
    $question = (string) get_post_meta($post->ID, '_huhs_poll_question', true);
    $options = huhs_poll_options($post->ID);
    $start = (string) get_post_meta($post->ID, '_huhs_poll_start', true);
    $end = (string) get_post_meta($post->ID, '_huhs_poll_end', true);
    if ($question === '') $question = $post->post_title;
    ?>
    <p><label><strong>A kérdés</strong><br>
        <input class="widefat" type="text" name="huhs_poll_question" value="<?php echo esc_attr($question); ?>" placeholder="Melyik a kedvenc hardstyle alstílusod?"></label></p>
    <p><label><strong>Indulás</strong><br>
        <input class="widefat" type="datetime-local" name="huhs_poll_start" value="<?php echo esc_attr($start); ?>"></label></p>
    <p><label><strong>Zárás</strong><br>
        <input class="widefat" type="datetime-local" name="huhs_poll_end" value="<?php echo esc_attr($end); ?>"></label></p>
    <p class="description">A kérdőív az appban <strong>csak e két időpont között</strong> látszik. Publikus eredmény nincs; a szavazatszámot a HUHS Mobile &rarr; Kérdőív eredményei oldalon látod.</p>
    <hr>
    <h3>Válaszlehetőségek (legfeljebb <?php echo (int) HUHS_POLL_MAX_OPTIONS; ?>)</h3>
    <?php for ($index = 0; $index < HUHS_POLL_MAX_OPTIONS; $index++) : ?>
        <p class="huhs-poll-option">
            <input class="widefat" type="text" name="huhs_poll_options[]" value="<?php echo esc_attr($options[$index] ?? ''); ?>" placeholder="<?php echo $index + 1; ?>. válaszlehetőség<?php echo $index > 1 ? ' (nem kötelező)' : ''; ?>">
        </p>
    <?php endfor; ?>
    <?php
    $results = huhs_poll_results($post->ID);
    if ($results['total'] > 0) {
        echo '<hr><h3>Eddigi szavazatok</h3><ul>';
        foreach ($results['counts'] as $index => $count) {
            $label = $options[$index] ?? ('#' . ($index + 1));
            echo '<li>' . esc_html($label) . ': <strong>' . (int) $count . '</strong></li>';
        }
        echo '</ul><p><strong>Összesen: ' . (int) $results['total'] . ' szavazat</strong></p>';
    }
}

add_action('save_post_huhs_poll', function ($post_id) {
    if (!isset($_POST['huhs_poll_nonce']) || !wp_verify_nonce($_POST['huhs_poll_nonce'], 'huhs_poll_save')) return;
    if (defined('DOING_AUTOSAVE') && DOING_AUTOSAVE) return;
    if (!current_user_can('edit_post', $post_id)) return;

    $question = sanitize_text_field(wp_unslash($_POST['huhs_poll_question'] ?? ''));
    update_post_meta($post_id, '_huhs_poll_question', $question);

    $raw_options = (array) wp_unslash($_POST['huhs_poll_options'] ?? array());
    $options = array();
    foreach ($raw_options as $label) {
        $label = sanitize_text_field((string) $label);
        if ($label === '') continue;
        $options[] = $label;
        if (count($options) >= HUHS_POLL_MAX_OPTIONS) break;
    }
    // JSON_UNESCAPED_UNICODE: a nem-ASCII karakter maradjon nyers UTF-8, hogy a
    // json_encode() ne gyartson \uXXXX escape-et, amit az update_post_meta()
    // wp_unslash()-ja lenyelne. A wp_slash() pedig az idezojelet es a
    // backslasht vedi: a meta irasnal a WordPress ugyis wp_unslash()-ol.
    update_post_meta($post_id, '_huhs_poll_options', wp_slash(wp_json_encode($options, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES)));

    foreach (array('start' => '_huhs_poll_start', 'end' => '_huhs_poll_end') as $field => $meta_key) {
        $value = sanitize_text_field(wp_unslash($_POST['huhs_poll_' . $field] ?? ''));
        if ($value !== '' && !preg_match('/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/', $value)) $value = '';
        update_post_meta($post_id, $meta_key, $value);
    }
});

// Register after the main HUHS menu exists (priority 20), exactly like the
// achievements page: registering a submenu before its parent is created makes
// WordPress drop it, and the page then answers "Sorry, you are not allowed to
// access this page." — a front-end 404-looking dead end for the owner.
add_action('admin_menu', function () {
    add_submenu_page(
        'huhs-mobile',
        'Kérdőív eredményei',
        'Kérdőív eredményei',
        'manage_options',
        'huhs-poll-results',
        'huhs_poll_results_admin_page'
    );
}, 20);

/**
 * Kerdőív eredmenyei — legordulobol valaszthato.
 *
 * A szavazatok a kerdőív lezarasa utan is a WordPressben maradnak (a lezaras
 * csak az appban rejti el a kartyat), ezert itt minden korabbi kerdőív
 * eredmenye visszanezheto. A lista datum szerint, a legfrisseb elol.
 */
function huhs_poll_results_admin_page()
{
    if (!current_user_can('manage_options')) wp_die('Nincs jogosultság.');

    echo '<div class="wrap"><h1>Kérdőív eredményei</h1>';
    echo '<p>Az eredmény csak itt, az admin felületen látható; az appban szándékosan nem jelenik meg. '
        . 'A <strong>lezárult</strong> kérdőívek szavazatai is megmaradnak, ezért bármikor visszanézhetők.</p>';

    $polls = get_posts(array(
        'post_type' => 'huhs_poll',
        'post_status' => array('publish', 'draft'),
        'posts_per_page' => 200,
        'orderby' => 'date',
        'order' => 'DESC',
    ));
    if (!$polls) {
        echo '<p>Még nincs kérdőív.</p></div>';
        return;
    }

    $by_id = array();
    foreach ($polls as $item) {
        $by_id[(int) $item->ID] = $item;
    }

    $selected = isset($_GET['poll']) ? absint($_GET['poll']) : 0;
    if (!isset($by_id[$selected])) {
        // Alapertelmezes: a nyitott kerdőív, kulonben a legfrissebb.
        $selected = 0;
        foreach ($polls as $item) {
            if (huhs_poll_window_state($item->ID) === 'open') {
                $selected = (int) $item->ID;
                break;
            }
        }
        if (!$selected) $selected = (int) $polls[0]->ID;
    }

    $label_for = function ($poll) {
        $state = huhs_poll_window_state($poll->ID);
        $state_label = $state === 'open' ? 'nyitott' : ($state === 'before' ? 'még nem indult' : 'lezárult');
        $question = (string) get_post_meta($poll->ID, '_huhs_poll_question', true) ?: $poll->post_title;
        $results = huhs_poll_results($poll->ID);
        return $question . ' — ' . $state_label . ' · ' . (int) $results['total'] . ' szavazat';
    };

    echo '<form method="get" action="' . esc_url(admin_url('admin.php')) . '" style="margin:14px 0 22px">';
    echo '<input type="hidden" name="page" value="huhs-poll-results">';
    echo '<label for="huhs-poll-select" style="margin-right:8px"><strong>Kérdőív:</strong></label>';
    echo '<select id="huhs-poll-select" name="poll" onchange="this.form.submit()" style="min-width:420px;max-width:100%">';
    foreach ($polls as $item) {
        echo '<option value="' . (int) $item->ID . '"' . selected($selected, (int) $item->ID, false) . '>'
            . esc_html($label_for($item)) . '</option>';
    }
    echo '</select> <noscript><button type="submit" class="button">Megjelenítés</button></noscript>';
    echo '</form>';

    $poll = $by_id[$selected];
    $options = huhs_poll_options($poll->ID);
    $results = huhs_poll_results($poll->ID);
    $state = huhs_poll_window_state($poll->ID);
    $state_label = $state === 'open' ? 'nyitott' : ($state === 'before' ? 'még nem indult' : 'lezárult');

    echo '<h2 style="margin-bottom:4px">' . esc_html((string) get_post_meta($poll->ID, '_huhs_poll_question', true) ?: $poll->post_title) . '</h2>';
    echo '<p>Állapot: <strong>' . esc_html($state_label) . '</strong> &middot; indulás: '
        . esc_html((string) get_post_meta($poll->ID, '_huhs_poll_start', true) ?: 'nincs') . ' &middot; zárás: '
        . esc_html((string) get_post_meta($poll->ID, '_huhs_poll_end', true) ?: 'nincs') . '</p>';

    if (!$options) {
        echo '<p>Nincs válaszlehetőség.</p></div>';
        return;
    }

    echo '<table class="widefat striped" style="max-width:720px"><thead><tr><th>Válaszlehetőség</th><th style="width:120px">Szavazat</th><th style="width:90px">Arány</th></tr></thead><tbody>';
    foreach ($options as $index => $label) {
        $count = $results['counts'][$index] ?? 0;
        $share = $results['total'] > 0 ? round($count / $results['total'] * 100, 1) : 0;
        echo '<tr><td>' . esc_html($label) . '</td><td><strong>' . (int) $count . '</strong></td><td>' . esc_html((string) $share) . '%</td></tr>';
    }
    echo '</tbody><tfoot><tr><th>Összesen</th><th>' . (int) $results['total'] . '</th><th></th></tr></tfoot></table>';
    echo '</div>';
}

/*
|--------------------------------------------------------------------------
| REST
|--------------------------------------------------------------------------
*/

add_action('rest_api_init', function () {
    register_rest_route('huhs/v1', '/poll/active', array(
        'methods' => 'GET',
        'callback' => 'huhs_poll_api_active',
        'permission_callback' => '__return_true',
    ));

    // Only the Firebase function calls these, with the WordPress application
    // password, so the voter identity can never be supplied by a client.
    $server_only = function () { return current_user_can('manage_options'); };
    register_rest_route('huhs/v1', '/poll/vote', array(
        'methods' => 'POST',
        'callback' => 'huhs_poll_api_vote',
        'permission_callback' => $server_only,
    ));
    register_rest_route('huhs/v1', '/poll/status', array(
        'methods' => 'POST',
        'callback' => 'huhs_poll_api_status',
        'permission_callback' => $server_only,
    ));
});

function huhs_poll_api_active(WP_REST_Request $request = null)
{
    $poll_id = huhs_poll_active_id();
    if (!$poll_id) return rest_ensure_response(array('poll' => null));
    // A kért nyelv (2.14.0): a kérdés és a válaszlehetőségek meta-szövegek,
    // ezért a fordításuk a `_huhs_translation_fields_en` térképből jön.
    $lang = $request instanceof WP_REST_Request ? huhs_request_lang($request) : 'hu';
    $options = huhs_translation_list($poll_id, $lang, '_huhs_poll_options', huhs_poll_options($poll_id));
    $payload = array();
    foreach ($options as $index => $label) {
        $payload[] = array('index' => $index, 'label' => $label);
    }
    $question_hu = (string) get_post_meta($poll_id, '_huhs_poll_question', true) ?: get_the_title($poll_id);
    return rest_ensure_response(array('poll' => array(
        'id' => $poll_id,
        'question' => huhs_translation_text($poll_id, $lang, '_huhs_poll_question', $question_hu),
        'options' => $payload,
        'start' => (string) get_post_meta($poll_id, '_huhs_poll_start', true),
        'end' => (string) get_post_meta($poll_id, '_huhs_poll_end', true),
        // ⚠️ 2.14.5: a jelző a **kézi** angol szövegeket is számolja (eddig csak a
        // gépi fordítás számított, ezért egy kézzel beírt angol szöveg mellett is
        // `false` lett volna).
        'has_en' => huhs_translation_fields_has_english($poll_id),
    )));
}

function huhs_poll_api_status(WP_REST_Request $request)
{
    $poll_id = absint($request->get_param('pollId'));
    $hash = huhs_poll_voter_hash($poll_id, $request->get_param('uid'));
    if (!$poll_id || $hash === '') {
        return new WP_Error('invalid_poll_vote', 'Érvénytelen szavazat.', array('status' => 400));
    }
    // A szavazat sora akkor is letezik, ha az elso valaszlehetosegre (index 0)
    // szavaztak: a meta erteke ekkor a '0' szoveg, es a PHP-ban a (bool) '0'
    // FALSE. Emiatt a regi `(bool) get_post_meta(...)` azt mondta, hogy „nem
    // szavaztal", az app ujra kiadta a szavazolapot, es a felhasznalo azt
    // hitte, ujra tud szavazni — kozben a szerver a masodik szavazatot
    // elutasitotta (`add_post_meta(..., true)`), csak ezt senki nem látta.
    // A helyes kerdes nem az ertek, hanem a sor LETEZESE.
    return rest_ensure_response(array(
        'voted' => metadata_exists('post', $poll_id, '_huhs_poll_vote_' . $hash),
    ));
}

function huhs_poll_api_vote(WP_REST_Request $request)
{
    $poll_id = absint($request->get_param('pollId'));
    $option_index = absint($request->get_param('optionIndex'));
    $hash = huhs_poll_voter_hash($poll_id, $request->get_param('uid'));
    $options = huhs_poll_options($poll_id);

    if (!$poll_id || $hash === '' || !$options) {
        return new WP_Error('invalid_poll_vote', 'Érvénytelen szavazat.', array('status' => 400));
    }
    if (!isset($options[$option_index])) {
        return new WP_Error('invalid_poll_option', 'Érvénytelen válaszlehetőség.', array('status' => 400));
    }
    if (huhs_poll_window_state($poll_id) !== 'open') {
        return new WP_Error('poll_closed', 'A kérdőív jelenleg nem elérhető.', array('status' => 403));
    }

    // add_post_meta() with $unique = true fails when the key already exists, so
    // the same account cannot add a second vote. The result is derived from
    // these rows, so there is no separate counter that could drift.
    $added = add_post_meta($poll_id, '_huhs_poll_vote_' . $hash, $option_index, true);
    if (!$added) {
        return rest_ensure_response(array('ok' => true, 'alreadyVoted' => true));
    }
    return rest_ensure_response(array('ok' => true, 'alreadyVoted' => false));
}
