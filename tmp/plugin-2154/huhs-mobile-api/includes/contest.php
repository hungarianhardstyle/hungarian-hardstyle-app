<?php
/**
 * DJ verseny (Hardstyle Revolution PRE-NYE, 2026-12-28).
 *
 * - A hardstylerevolution.hu oldalról jon a jelentkezes (DJ-nev, e-mail, SoundCloud-mix, foto, bio).
 * - Az uj jelentkezo "fuggoben" (pending) all: az adminban a Kozzetetel gomb = jovahagyas.
 * - Csak a jovahagyott (publikalt) jelentkezok latszanak az oldalon; ra lehet lajkolni es egyenkent megosztani.
 * - Az e-mail-cim soha nem kerul ki a nyilvanos API-ba.
 */

if (!defined('ABSPATH')) {
    exit;
}

define('HUHS_CONTEST_CLOUD', 'fjxo93em');
define('HUHS_CONTEST_LANDING', 'https://www.hardstylerevolution.hu/pre-nye-verseny.html');
// A jelentkezes es a szavazas hatarideje (a webhely idozonajaban). Szuroval felulirhato.
define('HUHS_CONTEST_ENTRIES_UNTIL', '2026-12-10 23:59:59');
define('HUHS_CONTEST_VOTING_UNTIL', '2026-12-25 23:59:59');

function huhs_contest_deadline($local, $filter)
{
    $local = (string) apply_filters($filter, $local);
    try {
        $date = new DateTimeImmutable($local, wp_timezone());
        return $date->getTimestamp();
    } catch (Exception $e) {
        return 0;
    }
}

function huhs_contest_entries_open()
{
    return time() <= huhs_contest_deadline(HUHS_CONTEST_ENTRIES_UNTIL, 'huhs_contest_entries_until');
}

function huhs_contest_voting_open()
{
    return time() <= huhs_contest_deadline(HUHS_CONTEST_VOTING_UNTIL, 'huhs_contest_voting_until');
}

function huhs_contest_salt()
{
    $salt = (string) get_option('huhs_contest_salt', '');
    if ($salt === '') {
        $salt = wp_generate_password(48, false, false);
        update_option('huhs_contest_salt', $salt, false);
    }
    return $salt;
}

function huhs_contest_is_soundcloud($url)
{
    return (bool) preg_match('#^https://(www\.|m\.|on\.)?soundcloud\.com/\S+$#i', (string) $url);
}

function huhs_contest_is_photo($url)
{
    return strpos((string) $url, 'https://res.cloudinary.com/' . HUHS_CONTEST_CLOUD . '/') === 0;
}

function huhs_contest_error($code, $message, $status)
{
    return new WP_Error($code, $message, array('status' => $status));
}

/* ---------- jelentkezo tipus + admin ---------- */

add_action('init', function () {
    register_post_type('huhs_contest', array(
        'labels' => array(
            'name' => 'DJ verseny',
            'singular_name' => 'Jelentkező',
            'all_items' => 'DJ verseny',
            'add_new_item' => 'Új jelentkező',
            'edit_item' => 'Jelentkező szerkesztése',
        ),
        'public' => false,
        'show_ui' => true,
        'show_in_menu' => 'huhs-mobile',
        'supports' => array('title'),
        'rewrite' => false,
    ));
});

add_action('add_meta_boxes', function () {
    add_meta_box('huhs_contest_box', 'Jelentkezés', 'huhs_contest_meta_box', 'huhs_contest', 'normal', 'high');
});

function huhs_contest_meta_box($post)
{
    wp_nonce_field('huhs_contest_save', 'huhs_contest_nonce');
    $mix = (string) get_post_meta($post->ID, '_huhs_contest_mix', true);
    $photo = (string) get_post_meta($post->ID, '_huhs_contest_photo', true);
    $bio = (string) get_post_meta($post->ID, '_huhs_contest_bio', true);
    $email = (string) get_post_meta($post->ID, '_huhs_contest_email', true);
    $likes = (int) get_post_meta($post->ID, '_huhs_contest_likes', true);
    ?>
    <p class="description"><strong>Jóváhagyás:</strong> a jobb oldali <em>Közzététel</em> gombbal. Csak a közzétett jelentkezők látszanak az oldalon. A DJ-név a fenti cím.<br><strong>Jóváhagyás előtt hallgasd meg a mixet:</strong> a warm up spotra csak <em>classic, euphoric vagy early hardstyle</em> jöhet szóba (RAW, Xtra-Raw és hardcore nem).</p>
    <?php if ($photo !== '') : ?>
        <p><img src="<?php echo esc_url($photo); ?>" alt="" style="max-width:200px;height:auto;border-radius:6px"></p>
    <?php endif; ?>
    <p><label><strong>Fotó (Cloudinary-link)</strong><br>
        <input class="widefat" type="url" name="huhs_contest_photo" value="<?php echo esc_attr($photo); ?>"></label></p>
    <p><label><strong>Mix (SoundCloud-link)</strong><br>
        <input class="widefat" type="url" name="huhs_contest_mix" value="<?php echo esc_attr($mix); ?>"></label>
        <?php if ($mix !== '') : ?><a href="<?php echo esc_url($mix); ?>" target="_blank" rel="noopener">Meghallgatás ↗</a><?php endif; ?></p>
    <p><label><strong>Bemutatkozás (legfeljebb 300 karakter)</strong><br>
        <textarea class="widefat" rows="3" name="huhs_contest_bio" maxlength="300"><?php echo esc_textarea($bio); ?></textarea></label></p>
    <p><strong>E-mail (nem látszik az oldalon):</strong> <?php echo $email !== '' ? '<a href="mailto:' . esc_attr($email) . '">' . esc_html($email) . '</a>' : '—'; ?></p>
    <p><strong>Lájkok:</strong> <?php echo $likes; ?></p>
    <p><label><input type="checkbox" name="huhs_contest_winner" value="1" <?php checked(get_post_meta($post->ID, '_huhs_contest_winner', true), '1'); ?>> <strong>Nyertes (kézi)</strong> – felülbírálja a lájkokat; a szavazás lezárása után ő lesz a nyertes. Csak egy jelentkező lehet.</label></p>
    <?php
}

add_action('save_post_huhs_contest', function ($post_id) {
    if (defined('DOING_AUTOSAVE') && DOING_AUTOSAVE) return;
    if (!isset($_POST['huhs_contest_nonce']) || !wp_verify_nonce(sanitize_text_field(wp_unslash($_POST['huhs_contest_nonce'])), 'huhs_contest_save')) return;
    if (!current_user_can('edit_post', $post_id)) return;

    $photo = esc_url_raw(wp_unslash($_POST['huhs_contest_photo'] ?? ''));
    if ($photo === '' || huhs_contest_is_photo($photo)) update_post_meta($post_id, '_huhs_contest_photo', $photo);
    $mix = esc_url_raw(wp_unslash($_POST['huhs_contest_mix'] ?? ''));
    if (huhs_contest_is_soundcloud($mix)) update_post_meta($post_id, '_huhs_contest_mix', $mix);
    if (!empty($_POST['huhs_contest_winner'])) {
        $others = get_posts(array('post_type' => 'huhs_contest', 'post_status' => 'any', 'posts_per_page' => -1, 'fields' => 'ids', 'meta_key' => '_huhs_contest_winner', 'meta_value' => '1'));
        foreach ($others as $other) {
            if ((int) $other !== (int) $post_id) delete_post_meta($other, '_huhs_contest_winner');
        }
        update_post_meta($post_id, '_huhs_contest_winner', '1');
    } else {
        delete_post_meta($post_id, '_huhs_contest_winner');
    }
    update_post_meta($post_id, '_huhs_contest_bio', mb_substr(sanitize_textarea_field(wp_unslash($_POST['huhs_contest_bio'] ?? '')), 0, 300));
});

add_filter('manage_huhs_contest_posts_columns', function () {
    return array(
        'cb' => '<input type="checkbox">',
        'title' => 'DJ-név',
        'huhs_photo' => 'Fotó',
        'huhs_mix' => 'Mix',
        'huhs_email' => 'E-mail',
        'huhs_likes' => 'Lájk',
        'date' => 'Beküldve',
    );
});

add_action('manage_huhs_contest_posts_custom_column', function ($column, $post_id) {
    if ($column === 'huhs_photo') {
        $photo = (string) get_post_meta($post_id, '_huhs_contest_photo', true);
        if ($photo !== '') echo '<img src="' . esc_url($photo) . '" alt="" style="width:56px;height:56px;object-fit:cover;border-radius:4px">';
    } elseif ($column === 'huhs_mix') {
        $mix = (string) get_post_meta($post_id, '_huhs_contest_mix', true);
        if ($mix !== '') echo '<a href="' . esc_url($mix) . '" target="_blank" rel="noopener">Meghallgatás ↗</a>';
    } elseif ($column === 'huhs_email') {
        echo esc_html((string) get_post_meta($post_id, '_huhs_contest_email', true));
    } elseif ($column === 'huhs_likes') {
        echo (int) get_post_meta($post_id, '_huhs_contest_likes', true);
        $w = huhs_contest_winner();
        if ($w && (int) $w->ID === (int) $post_id) echo ' 🏆 nyertes';
    }
}, 10, 2);

/* ---------- API ---------- */

add_action('rest_api_init', function () {
    register_rest_route('huhs/v1', '/contest/entries', array(
        array('methods' => 'GET', 'callback' => 'huhs_contest_list', 'permission_callback' => '__return_true'),
        array('methods' => 'POST', 'callback' => 'huhs_contest_submit', 'permission_callback' => '__return_true'),
    ));
    register_rest_route('huhs/v1', '/contest/like', array(
        'methods' => 'POST',
        'callback' => 'huhs_contest_like',
        'permission_callback' => '__return_true',
    ));
    register_rest_route('huhs/v1', '/contest/share/(?P<id>\d+)', array(
        'methods' => 'GET',
        'callback' => 'huhs_contest_share',
        'permission_callback' => '__return_true',
    ));
});

function huhs_contest_published($id)
{
    $post = get_post((int) $id);
    return ($post && $post->post_type === 'huhs_contest' && $post->post_status === 'publish') ? $post : null;
}

function huhs_contest_payload($post)
{
    return array(
        'id' => (int) $post->ID,
        'name' => wp_specialchars_decode($post->post_title, ENT_QUOTES),
        'photo' => (string) get_post_meta($post->ID, '_huhs_contest_photo', true),
        'mix' => (string) get_post_meta($post->ID, '_huhs_contest_mix', true),
        'bio' => (string) get_post_meta($post->ID, '_huhs_contest_bio', true),
        'likes' => (int) get_post_meta($post->ID, '_huhs_contest_likes', true),
    );
}

function huhs_contest_response($data)
{
    $response = new WP_REST_Response($data);
    // A lajkszam elo adat: se a bongeszo, se a tarhely ne tartsa vissza.
    $response->header('Cache-Control', 'no-store, max-age=0');
    return $response;
}

/**
 * A nyertes: a szavazás lezárása után a kézzel megjelölt jelentkező, különben a legtöbb lájkos
 * (döntetlennél a korábban jelentkező). A szavazás alatt még nincs nyertes.
 */
function huhs_contest_winner()
{
    if (huhs_contest_voting_open()) return null;
    $posts = get_posts(array(
        'post_type' => 'huhs_contest', 'post_status' => 'publish',
        'posts_per_page' => 200, 'orderby' => 'date', 'order' => 'ASC',
    ));
    if (!$posts) return null;
    foreach ($posts as $post) {
        if (get_post_meta($post->ID, '_huhs_contest_winner', true) === '1') return $post;
    }
    $best = null;
    $best_likes = -1;
    foreach ($posts as $post) {
        $likes = (int) get_post_meta($post->ID, '_huhs_contest_likes', true);
        if ($likes > $best_likes) { $best = $post; $best_likes = $likes; }
    }
    return $best;
}

/** A nyertes értesítése (egyszer): a nyertesnek és az adminnak. Cron + az API első hívása indítja. */
function huhs_contest_finalize()
{
    $winner = huhs_contest_winner();
    if (!$winner) return null;
    if ((int) get_option('huhs_contest_winner_mailed', 0) !== (int) $winner->ID) {
        update_option('huhs_contest_winner_mailed', (int) $winner->ID, false);   // előbb jelöljük, hogy két párhuzamos kérés ne küldjön kétszer
        $name = wp_specialchars_decode($winner->post_title, ENT_QUOTES);
        $email = (string) get_post_meta($winner->ID, '_huhs_contest_email', true);
        if (is_email($email)) {
            @wp_mail(
                $email,
                'Te nyerted a DJ versenyt – Hardstyle Revolution PRE-NYE',
                "Szia " . $name . "!\n\nGratulálunk, te nyerted a Hardstyle Revolution PRE-NYE DJ versenyét! Te kapod a warm up spotot 2026. december 28-án, a Kassa Hajó Bárban.\n\n"
                . "Emlékeztetőül: a warm up spotra csak classic, euphoric vagy early hardstyle jöhet szóba. RAW, Xtra-Raw vagy hardcore szettet nem játszhatsz – ha a bulin ezek valamelyikét játszod, a fellépésedet megszakítjuk.\n\n"
                . "A részletekről (időpont, technika) hamarosan felvesszük veled a kapcsolatot. Ha kérdésed van, írj az info@hungarianhardstyle.hu címre.\n\nHungarian Hardstyle"
            );
        }
        @wp_mail(get_option('admin_email'), '[DJ verseny] Nyertes: ' . $name, 'A DJ verseny nyertese: ' . $name . ' (' . (int) get_post_meta($winner->ID, '_huhs_contest_likes', true) . ' lájk). A nyertesnek elküldtük az értesítő levelet.');
    }
    return $winner;
}

add_action('huhs_contest_finalize', 'huhs_contest_finalize');
add_action('init', function () {
    $end = huhs_contest_deadline(HUHS_CONTEST_VOTING_UNTIL, 'huhs_contest_voting_until');
    if ($end && time() < $end && !wp_next_scheduled('huhs_contest_finalize')) {
        wp_schedule_single_event($end + 60, 'huhs_contest_finalize');
    }
});

function huhs_contest_list()
{
    $winner = huhs_contest_finalize();
    $posts = get_posts(array(
        'post_type' => 'huhs_contest',
        'post_status' => 'publish',
        'posts_per_page' => 200,
        'orderby' => 'date',
        'order' => 'ASC',
    ));
    $entries = array_map('huhs_contest_payload', $posts);
    usort($entries, function ($a, $b) {
        return $b['likes'] <=> $a['likes'];   // azonos lajknal marad a jelentkezes sorrendje
    });
    return huhs_contest_response(array(
        'entries' => $entries,
        'entries_open' => huhs_contest_entries_open(),
        'voting_open' => huhs_contest_voting_open(),
        'winner' => $winner ? array('id' => (int) $winner->ID, 'name' => wp_specialchars_decode($winner->post_title, ENT_QUOTES), 'photo' => (string) get_post_meta($winner->ID, '_huhs_contest_photo', true)) : null,
    ));
}

function huhs_contest_submit(WP_REST_Request $request)
{
    $params = $request->get_json_params();
    if (!is_array($params)) $params = array();

    // robot-csapda: csendben "sikeres"
    if (!empty($params['website'])) {
        return huhs_contest_response(array('ok' => true));
    }
    if (huhs_ip_rate_limited('contest_entry', 3, 3600)) {
        return huhs_contest_error('rate_limited', 'Túl sok jelentkezés erről a címről. Próbáld újra később.', 429);
    }
    if (!huhs_contest_entries_open()) {
        return huhs_contest_error('contest_closed', 'A jelentkezési határidő lejárt.', 403);
    }

    $name = trim(sanitize_text_field((string) ($params['dj_name'] ?? '')));
    $email = sanitize_email((string) ($params['email'] ?? ''));
    $mix = esc_url_raw(trim((string) ($params['mix'] ?? '')));
    $photo = esc_url_raw(trim((string) ($params['photo'] ?? '')));
    $bio = mb_substr(sanitize_textarea_field((string) ($params['bio'] ?? '')), 0, 300);
    $consent = filter_var($params['consent'] ?? false, FILTER_VALIDATE_BOOLEAN);

    if (mb_strlen($name) < 2 || mb_strlen($name) > 40) {
        return huhs_contest_error('invalid_name', 'Adj meg egy 2–40 karakteres DJ-nevet.', 400);
    }
    if (!is_email($email)) {
        return huhs_contest_error('invalid_email', 'Adj meg érvényes e-mail-címet.', 400);
    }
    if (!huhs_contest_is_soundcloud($mix)) {
        return huhs_contest_error('invalid_mix', 'A mixet SoundCloud-linkkel add meg.', 400);
    }
    if (!huhs_contest_is_photo($photo)) {
        return huhs_contest_error('invalid_photo', 'A fotó feltöltése nem sikerült.', 400);
    }
    if (!$consent) {
        return huhs_contest_error('consent_required', 'A jelentkezéshez szükséges a hozzájárulás.', 400);
    }

    $dupe = get_posts(array(
        'post_type' => 'huhs_contest',
        'post_status' => array('publish', 'pending', 'draft', 'private'),
        'posts_per_page' => 1,
        'fields' => 'ids',
        'meta_query' => array(
            'relation' => 'OR',
            array('key' => '_huhs_contest_email', 'value' => $email),
            array('key' => '_huhs_contest_mix', 'value' => $mix),
        ),
    ));
    if ($dupe) {
        return huhs_contest_error('already_entered', 'Erre az e-mail-címre vagy mixre már érkezett jelentkezés.', 409);
    }

    $id = wp_insert_post(array(
        'post_type' => 'huhs_contest',
        'post_status' => 'pending',
        'post_title' => $name,
    ), true);
    if (is_wp_error($id) || !$id) {
        return huhs_contest_error('save_failed', 'A jelentkezést most nem sikerült elmenteni.', 500);
    }
    update_post_meta($id, '_huhs_contest_email', $email);
    update_post_meta($id, '_huhs_contest_mix', $mix);
    update_post_meta($id, '_huhs_contest_photo', $photo);
    update_post_meta($id, '_huhs_contest_bio', $bio);
    update_post_meta($id, '_huhs_contest_likes', 0);

    // Értesítés az adminnak (ha a levélküldés nem megy, a jelentkezés akkor is elmentődött).
    @wp_mail(
        get_option('admin_email'),
        '[DJ verseny] Új jelentkező: ' . $name,
        "Új jelentkező érkezett a DJ versenyre.\n\nDJ-név: " . $name . "\nMix: " . $mix . "\n\nJóváhagyás: " . admin_url('edit.php?post_type=huhs_contest&post_status=pending')
    );

    return huhs_contest_response(array('ok' => true));
}

function huhs_contest_count_likes($post_id)
{
    global $wpdb;
    $count = (int) $wpdb->get_var($wpdb->prepare(
        "SELECT COUNT(*) FROM {$wpdb->postmeta} WHERE post_id = %d AND meta_key LIKE %s",
        $post_id,
        $wpdb->esc_like('_huhs_contest_v_') . '%'
    ));
    update_post_meta($post_id, '_huhs_contest_likes', $count);
    return $count;
}

function huhs_contest_like(WP_REST_Request $request)
{
    if (huhs_ip_rate_limited('contest_like', 90, 3600)) {
        return huhs_contest_error('rate_limited', 'Túl sok lájk. Próbáld újra később.', 429);
    }
    $params = $request->get_json_params();
    if (!is_array($params)) $params = array();

    $id = (int) ($params['entry'] ?? 0);
    $visitor = preg_replace('/[^A-Za-z0-9\-]/', '', (string) ($params['visitor'] ?? ''));
    $like = !isset($params['like']) || filter_var($params['like'], FILTER_VALIDATE_BOOLEAN);

    if (strlen($visitor) < 16 || strlen($visitor) > 64) {
        return huhs_contest_error('invalid_visitor', 'Érvénytelen kérés.', 400);
    }
    if (!huhs_contest_published($id)) {
        return huhs_contest_error('not_found', 'Ez a jelentkező nem található.', 404);
    }
    if (!huhs_contest_voting_open()) {
        return huhs_contest_error('voting_closed', 'A szavazás lezárult.', 403);
    }

    // Látogatónként egy lájk jelentkezőnként (sózott ujjlenyomat, személyt nem azonosít).
    $key = '_huhs_contest_v_' . substr(hash('sha256', huhs_contest_salt() . '|' . $visitor), 0, 40);
    $changed = $like ? add_post_meta($id, $key, 1, true) : delete_post_meta($id, $key);
    $likes = $changed ? huhs_contest_count_likes($id) : (int) get_post_meta($id, '_huhs_contest_likes', true);

    return huhs_contest_response(array('likes' => $likes, 'liked' => $like));
}

/**
 * Megoszthato oldal egy jelentkezohoz: a Facebook/Messenger/WhatsApp elonezet a DJ nevet es kepet mutatja,
 * a latogato pedig atkerul a versenyoldalra (a jelentkezohoz gorgetve).
 */
function huhs_contest_share(WP_REST_Request $request)
{
    $post = huhs_contest_published($request['id']);
    if (!$post) {
        return huhs_contest_error('not_found', 'Ez a jelentkező nem található.', 404);
    }
    $entry = huhs_contest_payload($post);
    $landing = HUHS_CONTEST_LANDING . '#e-' . $entry['id'];
    $self = rest_url('huhs/v1/contest/share/' . $entry['id']);
    $title = $entry['name'] . ' – DJ verseny | Hardstyle Revolution PRE-NYE';
    $desc = 'Hallgasd meg a mixét, és szavazz rá a Hardstyle Revolution PRE-NYE DJ versenyén! 2026. december 28., Kassa Hajó – Bár.';

    if (!headers_sent()) {
        status_header(200);
        header('Content-Type: text/html; charset=utf-8');
        header('Cache-Control: public, max-age=300');
    }
    echo '<!doctype html><html lang="hu"><head><meta charset="utf-8">'
        . '<title>' . esc_html($title) . '</title>'
        . '<meta name="viewport" content="width=device-width, initial-scale=1">'
        . '<meta name="robots" content="noindex">'
        . '<meta property="og:type" content="website">'
        . '<meta property="og:site_name" content="Hardstyle Revolution">'
        . '<meta property="og:title" content="' . esc_attr($title) . '">'
        . '<meta property="og:description" content="' . esc_attr($desc) . '">'
        . '<meta property="og:url" content="' . esc_url($self) . '">'
        . ($entry['photo'] !== '' ? '<meta property="og:image" content="' . esc_url($entry['photo']) . '">' : '')
        . '<meta name="twitter:card" content="summary_large_image">'
        . '</head><body><p><a href="' . esc_url($landing) . '">Tovább a DJ versenyre</a></p>'
        . '<script>location.replace(' . wp_json_encode($landing) . ');</script></body></html>';
    exit;
}
