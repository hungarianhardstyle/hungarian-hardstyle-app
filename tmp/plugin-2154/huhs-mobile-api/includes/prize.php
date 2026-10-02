<?php

if (!defined('ABSPATH')) exit;

/**
 * Nyeremenyjatek.
 *
 * A Kviztol es a Kozvelemenykutatastol (Kerdőív) FUGGETLEN rendszer: sajat
 * menupont, sajat adatmodell, sajat REST vegpontok.
 *
 * Egy jatek: egy kerdés, 3-5 valaszlehetoseg, EGY helyes valasz, kezdo es zaro
 * idopont, nyeremeny tipusa es leirasa, kep, valamint az, hogy a nyertes hany
 * napig latszodjon.
 *
 * A jatekos EGYSZER jatszhat. A valaszt és a helyességet a szerver donti el, es
 * a dontes a jatek bejegyzesen marad (`_huhs_prize_entry_<hash>` meta-sor),
 * ezert a lezaras utan is visszanezheto, ki mit valaszolt.
 *
 * Adatvedelem: a WordPress **soha** nem tarol e-mail-címet es nem tarol nyers
 * Firebase UID-t. A jatekos egy sotolt ujjlenyomat (`<sha256>`), a megjelenitett
 * nev pedig a kozossegi profilbol erkezik a rogzites pillanataban. E-mail-cím
 * csak a NYERTES ertesitesehez kell, es azt is a Firebase kerdezi le a sajat
 * adatbazisabol — ide nem kerul be.
 *
 * A sorsolas a Firebase-ben tortenik (ott van kriptografiai veletlen), de az
 * eredmeny ide iranyodik vissza, es a `huhs_prize_set_winner()` **idempotens**:
 * ha mar van nyertes, nem irja felul.
 */

if (!defined('HUHS_PRIZE_MIN_ANSWERS')) {
    define('HUHS_PRIZE_MIN_ANSWERS', 3);
}
if (!defined('HUHS_PRIZE_MAX_ANSWERS')) {
    define('HUHS_PRIZE_MAX_ANSWERS', 5);
}

/* -------------------------------------------------------------------------
 * Alapok: ido, ujjlenyomat, allapot
 * ---------------------------------------------------------------------- */

/** A jatekosok ujjlenyomatanak soja. Egyszer generalodik, a szerveren marad. */
function huhs_prize_salt()
{
    $salt = (string) get_option('huhs_prize_salt', '');
    if ($salt === '') {
        $salt = wp_generate_password(48, false, false);
        update_option('huhs_prize_salt', $salt, false);
    }
    return $salt;
}

/** Sotolt ujjlenyomat: a duplikacio kiszurheto, a jatekos nem azonosithato. */
function huhs_prize_player_hash($prize_id, $uid)
{
    $uid = trim((string) $uid);
    if ($uid === '') return '';
    return hash('sha256', absint($prize_id) . '|' . $uid . '|' . huhs_prize_salt());
}

/** A jatek valaszlehetosegei (3-5, uresek nelkul). */
function huhs_prize_answers($prize_id)
{
    $stored = huhs_poll_repair_escapes(get_post_meta($prize_id, '_huhs_prize_answers', true));
    $raw = json_decode($stored, true);
    $answers = array();
    foreach ((array) $raw as $label) {
        $label = sanitize_text_field((string) $label);
        if ($label === '') continue;
        $answers[] = $label;
        if (count($answers) >= HUHS_PRIZE_MAX_ANSWERS) break;
    }
    return $answers;
}

/**
 * A jatek allapota a webhely idozonajaban: before / open / closed.
 *
 * Ugyanaz a minta, mint a kerdőívé: az app NEM szamol datumot, ezert egy
 * elallitott keszülék-ido nem tudja kitolni az ablakot. Hianyzo datum -> nyitott
 * hatar, hogy egy elgepelt datum ne tegye hasznalhatatlanna a jatekot.
 */
function huhs_prize_window_state($prize_id)
{
    $now = current_time('Y-m-d\TH:i');
    $start = trim((string) get_post_meta($prize_id, '_huhs_prize_start', true));
    $end = trim((string) get_post_meta($prize_id, '_huhs_prize_end', true));
    if ($start !== '' && $now < $start) return 'before';
    if ($end !== '' && $now > $end) return 'closed';
    return 'open';
}

/**
 * A jatek lezarasanak idopontja (a beallitott zaras), vagy 0.
 *
 * Ez kell a nyertes megjelenitesi ablakanahoz: a zaras utan meg ennyi napig
 * latszik a nyertes, utana az appban a kartya eltunik.
 */
function huhs_prize_closed_at($prize_id)
{
    $end = trim((string) get_post_meta($prize_id, '_huhs_prize_end', true));
    if ($end === '') return 0;
    $timestamp = strtotime($end);
    return $timestamp ? (int) $timestamp : 0;
}

/** Hany napig latszodjon a nyertes a lezaras utan (0 = soha nem tünik el). */
function huhs_prize_display_days($prize_id)
{
    $days = get_post_meta($prize_id, '_huhs_prize_display_days', true);
    if ($days === '' || $days === null) return 7;
    return max(0, min(365, absint($days)));
}

/** Igaz, ha a nyertes meg a megjelenitesi ablakban van. */
function huhs_prize_winner_visible($prize_id)
{
    if ((string) get_post_meta($prize_id, '_huhs_prize_winner_uid', true) === '') return false;
    $days = huhs_prize_display_days($prize_id);
    if ($days === 0) return true;
    $closed_at = huhs_prize_closed_at($prize_id);
    if (!$closed_at) return true;
    return time() <= $closed_at + ($days * DAY_IN_SECONDS);
}

/** A nyertes adatai (nev + a sorsolas ideje), vagy null. */
function huhs_prize_winner($prize_id)
{
    $name = trim((string) get_post_meta($prize_id, '_huhs_prize_winner_name', true));
    if ($name === '') return null;
    return array(
        'name' => $name,
        'drawn_at' => (string) get_post_meta($prize_id, '_huhs_prize_winner_at', true),
    );
}

/** Az aktiv jatek azonositoja: nyitott ablak, egyebkent 0. */
function huhs_prize_active_id()
{
    $prizes = get_posts(array(
        'post_type' => 'huhs_prize',
        'post_status' => 'publish',
        'posts_per_page' => 50,
        'orderby' => 'date',
        'order' => 'DESC',
        'fields' => 'ids',
        'no_found_rows' => true,
    ));
    foreach ($prizes as $prize_id) {
        if (huhs_prize_window_state($prize_id) === 'open') return (int) $prize_id;
    }
    return 0;
}

/**
 * A legutobbi lezart jatek, amelynek a nyertese meg latszodhat.
 *
 * Ez teszi lehetove, hogy a lezaras utan az app a nyertest mutassa a jatek
 * helyett (a beallitott napokig).
 */
function huhs_prize_recent_winner_id()
{
    $prizes = get_posts(array(
        'post_type' => 'huhs_prize',
        'post_status' => 'publish',
        'posts_per_page' => 50,
        'orderby' => 'date',
        'order' => 'DESC',
        'fields' => 'ids',
        'no_found_rows' => true,
    ));
    foreach ($prizes as $prize_id) {
        if (huhs_prize_window_state($prize_id) !== 'closed') continue;
        if (huhs_prize_winner_visible($prize_id)) return (int) $prize_id;
    }
    return 0;
}

/* -------------------------------------------------------------------------
 * Reszvetel
 * ---------------------------------------------------------------------- */

/** Egy jatekos bejegyzese (valasz + helyesseg + nev), vagy null. */
function huhs_prize_entry($prize_id, $uid)
{
    $hash = huhs_prize_player_hash($prize_id, $uid);
    if ($hash === '') return null;
    $stored = huhs_poll_repair_escapes(get_post_meta($prize_id, '_huhs_prize_entry_' . $hash, true));
    $decoded = json_decode((string) $stored, true);
    if (!is_array($decoded)) return null;
    return $decoded;
}

/**
 * A jatek osszes bejegyzese.
 *
 * A bejegyzesek a jatek bejegyzesen meta-sorkent maradnak, ezert a lezaras utan
 * is visszanezhetok — ez kell az admin oldalhoz.
 */
function huhs_prize_entries($prize_id)
{
    global $wpdb;
    $prize_id = absint($prize_id);
    $rows = $wpdb->get_results($wpdb->prepare(
        "SELECT meta_key, meta_value FROM {$wpdb->postmeta} WHERE post_id = %d AND meta_key LIKE %s ORDER BY meta_id ASC",
        $prize_id,
        $wpdb->esc_like('_huhs_prize_entry_') . '%'
    ));
    $entries = array();
    foreach ((array) $rows as $row) {
        $decoded = json_decode(huhs_poll_repair_escapes($row->meta_value), true);
        if (!is_array($decoded)) continue;
        $decoded['hash'] = str_replace('_huhs_prize_entry_', '', (string) $row->meta_key);
        $entries[] = $decoded;
    }
    return $entries;
}

/** Osszesites: hany jatekos, hany helyes. */
function huhs_prize_summary($prize_id)
{
    $entries = huhs_prize_entries($prize_id);
    $correct = 0;
    foreach ($entries as $entry) {
        if (!empty($entry['correct'])) $correct++;
    }
    return array('total' => count($entries), 'correct' => $correct);
}

/**
 * Egy valasz rogzitese. Visszaadja az eredmenyt.
 *
 * A helyességet ITT, a szerveren dontjuk el: a kliens csak a valasztott indexet
 * küldi, a helyes valasz soha nem megy ki az appba a jatek elott.
 *
 * @return array|WP_Error
 */
function huhs_prize_record_entry($prize_id, $uid, $answer_index, $display_name)
{
    $prize_id = absint($prize_id);
    $hash = huhs_prize_player_hash($prize_id, $uid);
    $answers = huhs_prize_answers($prize_id);
    $answer_index = absint($answer_index);

    if (!$prize_id || $hash === '' || !$answers) {
        return new WP_Error('invalid_prize_entry', 'Érvénytelen játék vagy résztvevő.', array('status' => 400));
    }
    if (!isset($answers[$answer_index])) {
        return new WP_Error('invalid_prize_answer', 'Érvénytelen válaszlehetőség.', array('status' => 400));
    }
    if (huhs_prize_window_state($prize_id) !== 'open') {
        return new WP_Error('prize_closed', 'A nyereményjáték jelenleg nem elérhető.', array('status' => 403));
    }

    $existing = huhs_prize_entry($prize_id, $uid);
    if ($existing) {
        return array(
            'ok' => true,
            'alreadyPlayed' => true,
            'correct' => !empty($existing['correct']),
            'answerIndex' => isset($existing['answer']) ? (int) $existing['answer'] : null,
        );
    }

    $correct_index = (int) get_post_meta($prize_id, '_huhs_prize_correct', true);
    $entry = array(
        'answer' => $answer_index,
        'correct' => $answer_index === $correct_index,
        'name' => sanitize_text_field((string) $display_name),
        // A Firebase UID-t azert taroljuk, hogy a sorsolas UTAN a nyertes e-mail-cimet
        // meg tudjuk keresni a Firebase Auth-ban (ott van a cim, nem itt) — es hogy a
        // nyertes hash-e visszafejtheto legyen emberi azonositora. Ez a sor SOHA nem
        // megy ki az appba: a `/prize/participants` vegpont csak application
        // password-del hivhato (lasd a REST regisztraciot lentebb).
        'uid' => (string) $uid,
        'at' => current_time('Y-m-d H:i:s'),
    );
    // wp_slash + JSON_UNESCAPED_UNICODE: az update_post_meta() wp_unslash()-ol,
    // ezert a sajat magunk generalta escape-et kulonben lenyelne. Reszletek:
    // AGENTS.md "a WordPress post meta lenyeli a json_encode escape-et".
    update_post_meta(
        $prize_id,
        '_huhs_prize_entry_' . $hash,
        wp_slash(wp_json_encode($entry, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES))
    );

    return array(
        'ok' => true,
        'alreadyPlayed' => false,
        'correct' => $entry['correct'],
        'answerIndex' => $answer_index,
    );
}

/** A helyesen valaszolok hash-ei (a sorsolashoz). */
function huhs_prize_correct_hashes($prize_id)
{
    $hashes = array();
    foreach (huhs_prize_entries($prize_id) as $entry) {
        if (!empty($entry['correct'])) $hashes[] = (string) ($entry['hash'] ?? '');
    }
    return array_values(array_filter($hashes));
}

/**
 * A nyertes beirasa — IDEMPOTENS.
 *
 * Ha mar van nyertes, nem irja felul, csak visszajelzi. Ez azert kell, mert a
 * sorsolo fuggveny otpercenkent lefut, es egy ujrainditas nem hozhat letre
 * masodik nyertest.
 *
 * @return array|WP_Error
 */
function huhs_prize_set_winner($prize_id, $uid, $display_name, $drawn_at = '')
{
    $prize_id = absint($prize_id);
    if (!$prize_id || (string) get_post_type($prize_id) !== 'huhs_prize') {
        return new WP_Error('invalid_prize', 'Érvénytelen játék.', array('status' => 400));
    }
    $existing = huhs_prize_winner($prize_id);
    if ($existing) {
        return array('ok' => true, 'alreadyDrawn' => true, 'winner' => $existing['name']);
    }
    $name = sanitize_text_field((string) $display_name);
    if ($name === '') {
        return new WP_Error('invalid_winner', 'A nyertes neve üres.', array('status' => 400));
    }
    $hash = huhs_prize_player_hash($prize_id, $uid);
    update_post_meta($prize_id, '_huhs_prize_winner_hash', $hash);
    update_post_meta($prize_id, '_huhs_prize_winner_name', $name);
    update_post_meta($prize_id, '_huhs_prize_winner_uid', wp_slash((string) $uid));
    update_post_meta(
        $prize_id,
        '_huhs_prize_winner_at',
        $drawn_at !== '' ? sanitize_text_field($drawn_at) : current_time('Y-m-d H:i:s')
    );
    return array('ok' => true, 'alreadyDrawn' => false, 'winner' => $name);
}

/* -------------------------------------------------------------------------
 * Admin: jatek szerkesztese
 * ---------------------------------------------------------------------- */

add_action('init', function () {
    register_post_type('huhs_prize', array(
        'label' => 'Nyereményjáték',
        'labels' => array(
            'name' => 'Nyereményjátékok',
            'singular_name' => 'Nyereményjáték',
            'add_new_item' => 'Új nyereményjáték',
            'edit_item' => 'Nyereményjáték szerkesztése',
        ),
        'public' => false,
        'show_ui' => true,
        'show_in_menu' => 'huhs-mobile',
        'supports' => array('title'),
        'rewrite' => false,
    ));
});

add_action('add_meta_boxes', function () {
    add_meta_box('huhs_prize_box', 'Nyereményjáték beállításai', 'huhs_prize_meta_box', 'huhs_prize', 'normal', 'high');
});

function huhs_prize_meta_box($post)
{
    wp_nonce_field('huhs_prize_save', 'huhs_prize_nonce');
    $question = (string) get_post_meta($post->ID, '_huhs_prize_question', true);
    $answers = huhs_prize_answers($post->ID);
    $correct = (int) get_post_meta($post->ID, '_huhs_prize_correct', true);
    $start = (string) get_post_meta($post->ID, '_huhs_prize_start', true);
    $end = (string) get_post_meta($post->ID, '_huhs_prize_end', true);
    $type = (string) get_post_meta($post->ID, '_huhs_prize_type', true);
    $description = (string) get_post_meta($post->ID, '_huhs_prize_description', true);
    $days = huhs_prize_display_days($post->ID);
    if ($question === '') $question = $post->post_title;
    ?>
    <p><label><strong>A kérdés</strong><br>
        <input class="widefat" type="text" name="huhs_prize_question" value="<?php echo esc_attr($question); ?>" placeholder="Melyik évben alakult a HUHS?"></label></p>
    <p><label><strong>Indulás</strong><br>
        <input class="widefat" type="datetime-local" name="huhs_prize_start" value="<?php echo esc_attr($start); ?>"></label></p>
    <p><label><strong>Zárás</strong><br>
        <input class="widefat" type="datetime-local" name="huhs_prize_end" value="<?php echo esc_attr($end); ?>"></label></p>
    <p class="description">A játék az appban <strong>csak e két időpont között</strong> játszható. A zárás után a sorsolás automatikusan lefut.</p>
    <hr>
    <h3>Válaszlehetőségek (<?php echo (int) HUHS_PRIZE_MIN_ANSWERS; ?>–<?php echo (int) HUHS_PRIZE_MAX_ANSWERS; ?>)</h3>
    <p class="description">Jelöld be, melyik a <strong>helyes</strong> válasz. Csak az nyerhet, aki jól válaszol.</p>
    <?php for ($index = 0; $index < HUHS_PRIZE_MAX_ANSWERS; $index++) : ?>
        <p>
            <label style="display:flex;align-items:center;gap:8px">
                <input type="radio" name="huhs_prize_correct" value="<?php echo (int) $index; ?>" <?php checked($correct, $index); ?>>
                <input class="widefat" type="text" name="huhs_prize_answers[]" value="<?php echo esc_attr($answers[$index] ?? ''); ?>" placeholder="<?php echo $index + 1; ?>. válaszlehetőség<?php echo $index >= HUHS_PRIZE_MIN_ANSWERS ? ' (nem kötelező)' : ''; ?>">
            </label>
        </p>
    <?php endfor; ?>
    <hr>
    <h3>A nyeremény</h3>
    <p><label><strong>Nyeremény típusa</strong><br>
        <input class="widefat" type="text" name="huhs_prize_type" value="<?php echo esc_attr($type); ?>" placeholder="Vinyl / póló / belépő"></label></p>
    <p><label><strong>Nyeremény leírása</strong><br>
        <textarea class="widefat" rows="3" name="huhs_prize_description" placeholder="Részletek, amit a nyertes és a játékosok látnak"><?php echo esc_textarea($description); ?></textarea></label></p>
    <p><label><strong>A nyertes hány napig látszódjon</strong><br>
        <input type="number" min="0" max="365" name="huhs_prize_display_days" value="<?php echo (int) $days; ?>">
        nap</label></p>
    <p class="description">A zárás után ennyi napig mutatja az app a nyertes nevét és a nyereményt. A <strong>0</strong> azt jelenti, hogy soha nem tűnik el.</p>
    <?php
    $summary = huhs_prize_summary($post->ID);
    $winner = huhs_prize_winner($post->ID);
    if ($summary['total'] > 0 || $winner) {
        echo '<hr><h3>Eddigi játék</h3><ul>';
        echo '<li>Játszott: <strong>' . (int) $summary['total'] . '</strong></li>';
        echo '<li>Helyes válasz: <strong>' . (int) $summary['correct'] . '</strong></li>';
        if ($winner) {
            echo '<li>Nyertes: <strong>' . esc_html($winner['name']) . '</strong> (' . esc_html($winner['drawn_at']) . ')</li>';
        }
        echo '</ul><p>A részletes listát a <strong>HUHS Mobile &rarr; Nyereményjáték</strong> oldalon látod.</p>';
    }
}

add_action('save_post_huhs_prize', function ($post_id) {
    if (!isset($_POST['huhs_prize_nonce']) || !wp_verify_nonce($_POST['huhs_prize_nonce'], 'huhs_prize_save')) return;
    if (defined('DOING_AUTOSAVE') && DOING_AUTOSAVE) return;
    if (!current_user_can('edit_post', $post_id)) return;

    $question = sanitize_text_field(wp_unslash($_POST['huhs_prize_question'] ?? ''));
    update_post_meta($post_id, '_huhs_prize_question', $question);

    $raw_answers = (array) wp_unslash($_POST['huhs_prize_answers'] ?? array());
    $answers = array();
    foreach ($raw_answers as $label) {
        $label = sanitize_text_field((string) $label);
        if ($label === '') continue;
        $answers[] = $label;
        if (count($answers) >= HUHS_PRIZE_MAX_ANSWERS) break;
    }
    update_post_meta($post_id, '_huhs_prize_answers', wp_slash(wp_json_encode($answers, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES)));

    $correct = absint(wp_unslash($_POST['huhs_prize_correct'] ?? 0));
    if ($correct >= count($answers)) $correct = 0;
    update_post_meta($post_id, '_huhs_prize_correct', $correct);

    foreach (array('start' => '_huhs_prize_start', 'end' => '_huhs_prize_end') as $field => $meta_key) {
        $value = sanitize_text_field(wp_unslash($_POST['huhs_prize_' . $field] ?? ''));
        if ($value !== '' && !preg_match('/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/', $value)) $value = '';
        update_post_meta($post_id, $meta_key, $value);
    }

    update_post_meta($post_id, '_huhs_prize_type', sanitize_text_field(wp_unslash($_POST['huhs_prize_type'] ?? '')));
    update_post_meta($post_id, '_huhs_prize_description', sanitize_textarea_field(wp_unslash($_POST['huhs_prize_description'] ?? '')));
    update_post_meta($post_id, '_huhs_prize_display_days', max(0, min(365, absint(wp_unslash($_POST['huhs_prize_display_days'] ?? 7)))));
});

/* -------------------------------------------------------------------------
 * Admin oldal: resztvevok, legordulobol valaszthato jatekkal
 * ---------------------------------------------------------------------- */

// Register after the main HUHS menu exists (priority 20), exactly like the poll
// results page: a submenu registered before its parent is created makes
// WordPress drop it, and the page then answers "Sorry, you are not allowed to
// access this page."
add_action('admin_menu', function () {
    add_submenu_page(
        'huhs-mobile',
        'Nyereményjáték',
        'Nyereményjáték',
        'manage_options',
        'huhs-prize',
        'huhs_prize_admin_page'
    );
}, 20);

/**
 * Nyeremenyjatek admin oldal.
 *
 * A tulajdonos keresere: lassa, KI jatszott, helyes valaszt adott-e, es a
 * REGI jatekok adatai is maradjanak meg. Ezert a resztvevok a jatek
 * bejegyzesen maradnak, es a lista egy legordulobol valaszthato.
 */
function huhs_prize_admin_page()
{
    if (!current_user_can('manage_options')) wp_die('Nincs jogosultság.');

    echo '<div class="wrap"><h1>Nyereményjáték</h1>';
    echo '<p>Itt látod, ki játszott, melyik választ adta, és hogy helyes volt-e. '
        . 'A <strong>lezárult</strong> játékok adatai is megmaradnak, ezért bármikor visszanézhetők. '
        . 'E-mail-címet a rendszer nem tárol.</p>';

    $prizes = get_posts(array(
        'post_type' => 'huhs_prize',
        'post_status' => array('publish', 'draft'),
        'posts_per_page' => 200,
        'orderby' => 'date',
        'order' => 'DESC',
    ));
    if (!$prizes) {
        echo '<p>Még nincs nyereményjáték. Hozz létre egyet a <strong>HUHS Mobile &rarr; Nyereményjátékok &rarr; Új nyereményjáték</strong> menüben.</p></div>';
        return;
    }

    $by_id = array();
    foreach ($prizes as $item) {
        $by_id[(int) $item->ID] = $item;
    }

    $selected = isset($_GET['prize']) ? absint($_GET['prize']) : 0;
    if (!isset($by_id[$selected])) {
        // Alapertelmezes: a nyitott jatek, kulonben a legfrissebb.
        $selected = 0;
        foreach ($prizes as $item) {
            if (huhs_prize_window_state($item->ID) === 'open') {
                $selected = (int) $item->ID;
                break;
            }
        }
        if (!$selected) $selected = (int) $prizes[0]->ID;
    }

    $state_label_for = function ($prize_id) {
        $state = huhs_prize_window_state($prize_id);
        if ($state === 'open') return 'nyitott';
        if ($state === 'before') return 'még nem indult';
        return 'lezárult';
    };

    $label_for = function ($prize) use ($state_label_for) {
        $question = (string) get_post_meta($prize->ID, '_huhs_prize_question', true) ?: $prize->post_title;
        $summary = huhs_prize_summary($prize->ID);
        return $question . ' — ' . $state_label_for($prize->ID) . ' · '
            . (int) $summary['total'] . ' résztvevő · ' . (int) $summary['correct'] . ' helyes';
    };

    echo '<form method="get" action="' . esc_url(admin_url('admin.php')) . '" style="margin:14px 0 22px">';
    echo '<input type="hidden" name="page" value="huhs-prize">';
    echo '<label for="huhs-prize-select" style="margin-right:8px"><strong>Játék:</strong></label>';
    echo '<select id="huhs-prize-select" name="prize" onchange="this.form.submit()" style="min-width:420px;max-width:100%">';
    foreach ($prizes as $item) {
        echo '<option value="' . (int) $item->ID . '"' . selected($selected, (int) $item->ID, false) . '>'
            . esc_html($label_for($item)) . '</option>';
    }
    echo '</select> <noscript><button type="submit" class="button">Megjelenítés</button></noscript>';
    echo '</form>';

    $prize = $by_id[$selected];
    $answers = huhs_prize_answers($prize->ID);
    $correct_index = (int) get_post_meta($prize->ID, '_huhs_prize_correct', true);
    $summary = huhs_prize_summary($prize->ID);
    $winner = huhs_prize_winner($prize->ID);
    $question = (string) get_post_meta($prize->ID, '_huhs_prize_question', true) ?: $prize->post_title;

    echo '<h2 style="margin-bottom:4px">' . esc_html($question) . '</h2>';
    echo '<p>Állapot: <strong>' . esc_html($state_label_for($prize->ID)) . '</strong> &middot; indulás: '
        . esc_html((string) get_post_meta($prize->ID, '_huhs_prize_start', true) ?: 'nincs') . ' &middot; zárás: '
        . esc_html((string) get_post_meta($prize->ID, '_huhs_prize_end', true) ?: 'nincs') . '</p>';

    $type = (string) get_post_meta($prize->ID, '_huhs_prize_type', true);
    $description = (string) get_post_meta($prize->ID, '_huhs_prize_description', true);
    if ($type !== '' || $description !== '') {
        echo '<p><strong>Nyeremény:</strong> ' . esc_html($type !== '' ? $type : '—');
        if ($description !== '') echo ' &middot; ' . esc_html($description);
        echo '</p>';
    }

    echo '<p>Résztvevők: <strong>' . (int) $summary['total'] . '</strong> &middot; helyes válasz: <strong>'
        . (int) $summary['correct'] . '</strong> &middot; a nyertes látszik: <strong>'
        . (int) huhs_prize_display_days($prize->ID) . '</strong> napig</p>';

    if ($winner) {
        echo '<div class="notice notice-success inline" style="margin:10px 0"><p>🏆 <strong>Nyertes: '
            . esc_html($winner['name']) . '</strong> — sorsolva: ' . esc_html($winner['drawn_at']) . '</p></div>';
    } elseif (huhs_prize_window_state($prize->ID) === 'closed') {
        echo '<div class="notice notice-warning inline" style="margin:10px 0"><p>A játék lezárult, de <strong>még nincs nyertes</strong>. '
            . 'A sorsolás automatikusan lefut, amint van legalább egy helyes válasz.</p></div>';
    }

    if (!$answers) {
        echo '<p>Nincs válaszlehetőség beállítva.</p></div>';
        return;
    }

    echo '<h3>Válaszlehetőségek</h3>';
    echo '<table class="widefat striped" style="max-width:720px"><thead><tr><th>Válaszlehetőség</th><th style="width:110px">Helyes</th><th style="width:110px">Választották</th></tr></thead><tbody>';
    $entries = huhs_prize_entries($prize->ID);
    foreach ($answers as $index => $label) {
        $picked = 0;
        foreach ($entries as $entry) {
            if (isset($entry['answer']) && (int) $entry['answer'] === $index) $picked++;
        }
        echo '<tr><td>' . esc_html($label) . '</td><td>'
            . ($index === $correct_index ? '<strong>✔ igen</strong>' : '—')
            . '</td><td>' . (int) $picked . '</td></tr>';
    }
    echo '</tbody></table>';

    echo '<h3 style="margin-top:22px">Résztvevők</h3>';
    if (!$entries) {
        echo '<p>Még senki nem játszott ebben a játékban.</p></div>';
        return;
    }

    $winner_hash = (string) get_post_meta($prize->ID, '_huhs_prize_winner_hash', true);
    echo '<table class="widefat striped" style="max-width:900px"><thead><tr>'
        . '<th>Játékos</th><th>Válasz</th><th style="width:110px">Helyes</th><th style="width:170px">Mikor</th>'
        . '</tr></thead><tbody>';
    foreach ($entries as $entry) {
        $answer_index = isset($entry['answer']) ? (int) $entry['answer'] : -1;
        $answer_label = $answers[$answer_index] ?? ('#' . ($answer_index + 1));
        $name = trim((string) ($entry['name'] ?? ''));
        $is_winner = $winner_hash !== '' && $winner_hash === (string) ($entry['hash'] ?? '');
        echo '<tr>';
        echo '<td>' . ($is_winner ? '🏆 ' : '') . esc_html($name !== '' ? $name : 'névtelen játékos') . '</td>';
        echo '<td>' . esc_html($answer_label) . '</td>';
        echo '<td>' . (!empty($entry['correct']) ? '<strong>✔ igen</strong>' : '✖ nem') . '</td>';
        echo '<td>' . esc_html((string) ($entry['at'] ?? '')) . '</td>';
        echo '</tr>';
    }
    echo '</tbody></table></div>';
}

/* -------------------------------------------------------------------------
 * REST
 * ---------------------------------------------------------------------- */

add_action('rest_api_init', function () {
    register_rest_route('huhs/v1', '/prize/active', array(
        'methods' => 'GET',
        'callback' => 'huhs_prize_api_active',
        'permission_callback' => '__return_true',
    ));

    // Only the Firebase function calls these, with the WordPress application
    // password, so the player identity can never be supplied by a client.
    $server_only = function () { return current_user_can('manage_options'); };
    register_rest_route('huhs/v1', '/prize/enter', array(
        'methods' => 'POST',
        'callback' => 'huhs_prize_api_enter',
        'permission_callback' => $server_only,
    ));
    register_rest_route('huhs/v1', '/prize/status', array(
        'methods' => 'POST',
        'callback' => 'huhs_prize_api_status',
        'permission_callback' => $server_only,
    ));
    register_rest_route('huhs/v1', '/prize/pending', array(
        'methods' => 'GET',
        'callback' => 'huhs_prize_api_pending',
        'permission_callback' => $server_only,
    ));
    register_rest_route('huhs/v1', '/prize/participants', array(
        'methods' => 'GET',
        'callback' => 'huhs_prize_api_participants',
        'permission_callback' => $server_only,
    ));
    register_rest_route('huhs/v1', '/prize/winner', array(
        'methods' => 'POST',
        'callback' => 'huhs_prize_api_winner',
        'permission_callback' => $server_only,
    ));
});

/**
 * A jelenleg latszodo jatek.
 *
 * Ket esetben ad adatot: ha nyitott a jatek (akkor a kerdest es a
 * valaszlehetosegeket), vagy ha lezarult ES a nyertes meg a megjelenitesi
 * ablakban van (akkor a nyertest — a kerdest es a valaszokat NEM).
 *
 * A helyes valasz SOHA nem megy ki az appba a sorsolas elott, kulonben a
 * jatekos be tudna skennelni.
 */
function huhs_prize_api_active(WP_REST_Request $request = null)
{
    // A kért nyelv (2.14.0): a kérdés, a válaszok, a nyeremény neve és leírása
    // meta-szövegek — a fordításuk a `_huhs_translation_fields_en` térképből jön.
    $lang = $request instanceof WP_REST_Request ? huhs_request_lang($request) : 'hu';
    $prize_id = huhs_prize_active_id();
    if ($prize_id) {
        $answers = huhs_translation_list($prize_id, $lang, '_huhs_prize_answers', huhs_prize_answers($prize_id));
        if (!$answers) return rest_ensure_response(array('prize' => null));
        $payload = array();
        foreach ($answers as $index => $label) {
            $payload[] = array('index' => $index, 'label' => $label);
        }
        $question_hu = (string) get_post_meta($prize_id, '_huhs_prize_question', true) ?: get_the_title($prize_id);
        return rest_ensure_response(array('prize' => array(
            'id' => $prize_id,
            'state' => 'open',
            'question' => huhs_translation_text($prize_id, $lang, '_huhs_prize_question', $question_hu),
            'answers' => $payload,
            'start' => (string) get_post_meta($prize_id, '_huhs_prize_start', true),
            'end' => (string) get_post_meta($prize_id, '_huhs_prize_end', true),
            // ⚠️ A nyeremény részletei **a játék alatt is** kimennek (2026-09-24,
            // plugin 2.8.0). KORÁBBAN szándékosan üresek voltak, és csak a
            // sorsolás után jelentek meg — a tulajdonos viszont jelezte, hogy a
            // kitöltött „Nyeremény leírása" nem kerül bele a játékba. A mező
            // saját súgója is azt ígéri, hogy „a nyertes és a játékosok látják",
            // ezért a két viselkedés közül ez a helyes: a játékos lássa, miért
            // játszik. A **helyes válasz** továbbra sem megy ki.
            'prize_type' => huhs_translation_text(
                $prize_id,
                $lang,
                '_huhs_prize_type',
                (string) get_post_meta($prize_id, '_huhs_prize_type', true)
            ),
            'prize_description' => huhs_translation_text(
                $prize_id,
                $lang,
                '_huhs_prize_description',
                (string) get_post_meta($prize_id, '_huhs_prize_description', true)
            ),
            // ⚠️ 2.14.5: a kézi angol mezőket is számolja (lásd poll.php).
            'has_en' => huhs_translation_fields_has_english($prize_id),
            'winner' => null,
        )));
    }

    $winner_id = huhs_prize_recent_winner_id();
    if (!$winner_id) return rest_ensure_response(array('prize' => null));
    $winner = huhs_prize_winner($winner_id);
    if (!$winner) return rest_ensure_response(array('prize' => null));
    $winner_question_hu = (string) get_post_meta($winner_id, '_huhs_prize_question', true) ?: get_the_title($winner_id);
    return rest_ensure_response(array('prize' => array(
        'id' => $winner_id,
        'state' => 'drawn',
        'question' => huhs_translation_text($winner_id, $lang, '_huhs_prize_question', $winner_question_hu),
        'answers' => array(),
        'start' => (string) get_post_meta($winner_id, '_huhs_prize_start', true),
        'end' => (string) get_post_meta($winner_id, '_huhs_prize_end', true),
        'prize_type' => huhs_translation_text(
            $winner_id,
            $lang,
            '_huhs_prize_type',
            (string) get_post_meta($winner_id, '_huhs_prize_type', true)
        ),
        'prize_description' => huhs_translation_text(
            $winner_id,
            $lang,
            '_huhs_prize_description',
            (string) get_post_meta($winner_id, '_huhs_prize_description', true)
        ),
        'winner' => array('name' => $winner['name'], 'drawn_at' => $winner['drawn_at']),
    )));
}

/** Ez a fiok jatszott-e mar, es ha igen, helyes volt-e. */
function huhs_prize_api_status(WP_REST_Request $request)
{
    $prize_id = absint($request->get_param('prizeId'));
    $hash = huhs_prize_player_hash($prize_id, $request->get_param('uid'));
    if (!$prize_id || $hash === '') {
        return new WP_Error('invalid_prize', 'Érvénytelen játék.', array('status' => 400));
    }
    $entry = huhs_prize_entry($prize_id, $request->get_param('uid'));
    return rest_ensure_response(array(
        'played' => $entry !== null,
        'correct' => $entry !== null && !empty($entry['correct']),
        'answerIndex' => $entry !== null && isset($entry['answer']) ? (int) $entry['answer'] : null,
    ));
}

/** Valasz rogzitese. A helyességet a szerver donti el. */
function huhs_prize_api_enter(WP_REST_Request $request)
{
    $result = huhs_prize_record_entry(
        $request->get_param('prizeId'),
        $request->get_param('uid'),
        $request->get_param('answerIndex'),
        $request->get_param('displayName')
    );
    if (is_wp_error($result)) return $result;
    return rest_ensure_response($result);
}

/**
 * A lezart, meg nem sorsolt jatekok.
 *
 * Ezt kerdezi a Firebase sorsolo fuggveny otpercenkent. Csak a nyitott
 * eredmenyeket adja vissza, hogy a hivas olcso legyen.
 */
function huhs_prize_api_pending()
{
    $prizes = get_posts(array(
        'post_type' => 'huhs_prize',
        'post_status' => 'publish',
        'posts_per_page' => 20,
        'orderby' => 'date',
        'order' => 'ASC',
        'fields' => 'ids',
        'no_found_rows' => true,
    ));
    $pending = array();
    foreach ($prizes as $prize_id) {
        if (huhs_prize_window_state($prize_id) !== 'closed') continue;
        if (huhs_prize_winner($prize_id)) continue;
        $pending[] = array(
            'id' => (int) $prize_id,
            'question' => (string) get_post_meta($prize_id, '_huhs_prize_question', true) ?: get_the_title($prize_id),
            'prize_type' => (string) get_post_meta($prize_id, '_huhs_prize_type', true),
            'prize_description' => (string) get_post_meta($prize_id, '_huhs_prize_description', true),
            'correct_count' => (int) huhs_prize_summary($prize_id)['correct'],
        );
    }
    return rest_ensure_response(array('pending' => $pending));
}

/**
 * A helyesen valaszolok — a sorsolashoz.
 *
 * Ez a vegpont KIZAROLAG a Firebase sorsolo fuggvenynek szol, ezert
 * `manage_options` jogosultsag vedi (a Firebase application password-del hivja).
 * Ezen az egyetlen szerver-szerver uton megkapja a jatekos Firebase UID-jat is,
 * mert a sorsolas utan a NYERTES E-MAIL-CIMET a Firebase Auth-bol kell
 * kikeresni — ott van a cim, a WordPress szandekosan nem tarol e-mail-cimet.
 *
 * Az app SOHA nem latja ezt a valaszt: a `/prize/active` nyilvanos vegpont nem
 * tartalmaz sem UID-t, sem hash-t, sem a helyes valaszt.
 */
function huhs_prize_api_participants(WP_REST_Request $request)
{
    $prize_id = absint($request->get_param('prizeId'));
    if (!$prize_id || (string) get_post_type($prize_id) !== 'huhs_prize') {
        return new WP_Error('invalid_prize', 'Érvénytelen játék.', array('status' => 400));
    }
    $players = array();
    foreach (huhs_prize_entries($prize_id) as $entry) {
        if (empty($entry['correct'])) continue;
        $players[] = array(
            'hash' => (string) ($entry['hash'] ?? ''),
            'name' => (string) ($entry['name'] ?? ''),
            'uid' => (string) ($entry['uid'] ?? ''),
        );
    }
    return rest_ensure_response(array(
        'prizeId' => $prize_id,
        'correctCount' => count($players),
        'players' => $players,
        'hashes' => array_values(array_filter(array_column($players, 'hash'))),
    ));
}

/**
 * A nyertes beirasa (idempotens).
 *
 * A Firebase sorsol, de az eredmeny ide iranyodik vissza, hogy az admin oldal
 * es az app is a WordPressbol lassa. Ha mar van nyertes, nem irja felul.
 */
function huhs_prize_api_winner(WP_REST_Request $request)
{
    $result = huhs_prize_set_winner(
        $request->get_param('prizeId'),
        $request->get_param('uid'),
        $request->get_param('displayName'),
        (string) $request->get_param('drawnAt')
    );
    if (is_wp_error($result)) return $result;
    return rest_ensure_response($result);
}
