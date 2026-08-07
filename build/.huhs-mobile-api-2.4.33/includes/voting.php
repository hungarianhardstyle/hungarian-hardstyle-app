<?php

if (!defined('ABSPATH')) {
    exit;
}

define('HUHS_VOTING_CATEGORIES', array(
    'hungarian_hardstyle_dj' => 'Legjobb magyar hardstyle DJ',
    'hungarian_hardcore_dj' => 'Legjobb magyar hardcore DJ',
    'hungarian_track' => 'Legjobb magyar hardstyle zene',
    'hungarian_organizer' => 'Legjobb magyar szervező',
    'international_dj' => 'Legjobb külföldi DJ',
));

add_action('init', function () {
    register_post_type('huhs_vote_season', array(
        'labels' => array('name' => 'Szavazási szezonok', 'singular_name' => 'Szavazási szezon'),
        'public' => false,
        'show_ui' => true,
        'show_in_menu' => 'huhs-mobile',
        'supports' => array('title'),
        'capability_type' => 'post',
        'map_meta_cap' => true,
    ));
    register_post_type('huhs_vote_candidate', array(
        'labels' => array('name' => 'Szavazási jelöltek', 'singular_name' => 'Szavazási jelölt'),
        'public' => false,
        'show_ui' => true,
        'show_in_menu' => 'huhs-mobile',
        'supports' => array('title', 'thumbnail'),
        'capability_type' => 'post',
        'map_meta_cap' => true,
    ));
});

add_action('add_meta_boxes', function () {
    add_meta_box('huhs-vote-season-data', 'Szezon beállításai', 'huhs_vote_season_box', 'huhs_vote_season');
    add_meta_box('huhs-vote-candidate-data', 'Jelölt adatai', 'huhs_vote_candidate_box', 'huhs_vote_candidate');
});

function huhs_vote_season_box($post)
{
    wp_nonce_field('huhs_vote_save', 'huhs_vote_nonce');
    $fields = array(
        'year' => get_post_meta($post->ID, '_huhs_vote_year', true),
        'enabled' => get_post_meta($post->ID, '_huhs_vote_enabled', true),
        'start' => get_post_meta($post->ID, '_huhs_vote_start', true),
        'end' => get_post_meta($post->ID, '_huhs_vote_end', true),
        'results_published' => get_post_meta($post->ID, '_huhs_vote_results_published', true),
    );
    ?>
    <p><label>Év<br><input class="widefat" type="number" name="huhs_vote_year" value="<?php echo esc_attr($fields['year']); ?>"></label></p>
    <p><label>Kezdés<br><input class="widefat" type="datetime-local" name="huhs_vote_start" value="<?php echo esc_attr($fields['start']); ?>"></label></p>
    <p><label>Zárás<br><input class="widefat" type="datetime-local" name="huhs_vote_end" value="<?php echo esc_attr($fields['end']); ?>"></label></p>
    <p><label><input type="checkbox" name="huhs_vote_enabled" value="1" <?php checked($fields['enabled'], '1'); ?>> Megjelenjen az app főoldalán</label></p>
    <p><label><input type="checkbox" name="huhs_vote_results_published" value="1" <?php checked($fields['results_published'], '1'); ?>> Eredmények publikálva</label></p>
    <?php
}

function huhs_vote_candidate_box($post)
{
    wp_nonce_field('huhs_vote_save', 'huhs_vote_nonce');
    $seasons = get_posts(array('post_type' => 'huhs_vote_season', 'post_status' => array('publish', 'draft'), 'posts_per_page' => -1, 'orderby' => 'date', 'order' => 'DESC'));
    $season = get_post_meta($post->ID, '_huhs_vote_season', true);
    $category = get_post_meta($post->ID, '_huhs_vote_category', true);
    $type = get_post_meta($post->ID, '_huhs_vote_type', true);
    $artist = get_post_meta($post->ID, '_huhs_vote_artist', true);
    $image = get_post_meta($post->ID, '_huhs_vote_image', true);
    $spotify = get_post_meta($post->ID, '_huhs_vote_spotify', true);
    $youtube = get_post_meta($post->ID, '_huhs_vote_youtube', true);
    ?>
    <p><label>Szezon<br><select class="widefat" name="huhs_vote_season"><option value="">Válassz</option><?php foreach ($seasons as $item) : ?><option value="<?php echo esc_attr($item->ID); ?>" <?php selected($season, $item->ID); ?>><?php echo esc_html($item->post_title); ?></option><?php endforeach; ?></select></label></p>
    <p class="description">Kategóriánként tetszőleges számú jelöltet adhatsz hozzá; minden jelölt külön bejegyzés legyen.</p>
    <p><label>Kategória<br><select class="widefat" name="huhs_vote_category"><?php foreach (HUHS_VOTING_CATEGORIES as $key => $label) : ?><option value="<?php echo esc_attr($key); ?>" <?php selected($category, $key); ?>><?php echo esc_html($label); ?></option><?php endforeach; ?></select></label></p>
    <p><label>Típus<br><select class="widefat" name="huhs_vote_type"><option value="dj" <?php selected($type, 'dj'); ?>>DJ</option><option value="organizer" <?php selected($type, 'organizer'); ?>>Szervező</option><option value="track" <?php selected($type, 'track'); ?>>Zene</option></select></label></p>
    <p><label>Előadó (zenénél)<br><input class="widefat" name="huhs_vote_artist" value="<?php echo esc_attr($artist); ?>"></label></p>
    <p><label>Borító / kép URL<br><input class="widefat" type="url" name="huhs_vote_image" value="<?php echo esc_attr($image); ?>"></label></p>
    <p class="huhs-vote-track-field"><label>Spotify URL (a Legjobb magyar zene kategóriában kötelező)<br><input class="widefat" type="url" name="huhs_vote_spotify" value="<?php echo esc_attr($spotify); ?>"></label></p>
    <p class="huhs-vote-track-field"><label>YouTube URL (opcionális)<br><input class="widefat" type="url" name="huhs_vote_youtube" value="<?php echo esc_attr($youtube); ?>"></label></p>
    <script>
    (function () {
        var type = document.querySelector('[name="huhs_vote_type"]');
        var category = document.querySelector('[name="huhs_vote_category"]');
        var fields = document.querySelectorAll('.huhs-vote-track-field');
        function update() {
            var visible = type && category && type.value === 'track' && category.value === 'hungarian_track';
            fields.forEach(function (field) { field.style.display = visible ? '' : 'none'; });
        }
        if (type) type.addEventListener('change', update);
        if (category) category.addEventListener('change', update);
        update();
    }());
    </script>
    <?php
}

add_action('save_post_huhs_vote_season', 'huhs_vote_save_season');
add_action('save_post_huhs_vote_candidate', 'huhs_vote_save_candidate');

function huhs_vote_save_season($post_id)
{
    if (!huhs_vote_can_save($post_id)) return;
    foreach (array('year' => 'absint', 'start' => 'sanitize_text_field', 'end' => 'sanitize_text_field') as $key => $sanitize) {
        update_post_meta($post_id, '_huhs_vote_' . $key, call_user_func($sanitize, wp_unslash($_POST['huhs_vote_' . $key] ?? '')));
    }
    update_post_meta($post_id, '_huhs_vote_enabled', empty($_POST['huhs_vote_enabled']) ? '0' : '1');
    update_post_meta($post_id, '_huhs_vote_results_published', empty($_POST['huhs_vote_results_published']) ? '0' : '1');
}

function huhs_vote_save_candidate($post_id)
{
    if (!huhs_vote_can_save($post_id)) return;
    $category = sanitize_key(wp_unslash($_POST['huhs_vote_category'] ?? ''));
    $type = sanitize_key(wp_unslash($_POST['huhs_vote_type'] ?? ''));
    $fields = array('season' => 'absint', 'artist' => 'sanitize_text_field', 'image' => 'esc_url_raw');
    foreach ($fields as $key => $sanitize) update_post_meta($post_id, '_huhs_vote_' . $key, call_user_func($sanitize, wp_unslash($_POST['huhs_vote_' . $key] ?? '')));
    update_post_meta($post_id, '_huhs_vote_category', $category);
    update_post_meta($post_id, '_huhs_vote_type', $type);
    $is_track = $category === 'hungarian_track' && $type === 'track';
    update_post_meta($post_id, '_huhs_vote_spotify', $is_track ? esc_url_raw(wp_unslash($_POST['huhs_vote_spotify'] ?? '')) : '');
    update_post_meta($post_id, '_huhs_vote_youtube', $is_track ? esc_url_raw(wp_unslash($_POST['huhs_vote_youtube'] ?? '')) : '');
}

function huhs_vote_can_save($post_id)
{
    return !defined('DOING_AUTOSAVE') || !DOING_AUTOSAVE ? current_user_can('edit_post', $post_id) && isset($_POST['huhs_vote_nonce']) && wp_verify_nonce($_POST['huhs_vote_nonce'], 'huhs_vote_save') : false;
}

add_action('rest_api_init', function () {
    register_rest_route('huhs/v1', '/voting/active', array('methods' => 'GET', 'callback' => 'huhs_vote_active', 'permission_callback' => '__return_true'));
});

function huhs_vote_active()
{
    $seasons = get_posts(array('post_type' => 'huhs_vote_season', 'post_status' => 'publish', 'posts_per_page' => 1, 'meta_key' => '_huhs_vote_enabled', 'meta_value' => '1', 'orderby' => 'date', 'order' => 'DESC'));
    if (!$seasons) return array('active' => false);
    $season = $seasons[0];
    $now = current_time('timestamp');
    $start = strtotime((string) get_post_meta($season->ID, '_huhs_vote_start', true));
    $end = strtotime((string) get_post_meta($season->ID, '_huhs_vote_end', true));
    if (($start && $now < $start) || ($end && $now > $end)) return array('active' => false);
    $items = get_posts(array('post_type' => 'huhs_vote_candidate', 'post_status' => 'publish', 'posts_per_page' => -1, 'meta_key' => '_huhs_vote_season', 'meta_value' => $season->ID, 'orderby' => 'title', 'order' => 'ASC'));
    $categories = array();
    foreach (HUHS_VOTING_CATEGORIES as $key => $label) $categories[$key] = array('key' => $key, 'label' => $label, 'candidates' => array());
    foreach ($items as $item) {
        $key = get_post_meta($item->ID, '_huhs_vote_category', true);
        if (!isset($categories[$key])) continue;
        $type = get_post_meta($item->ID, '_huhs_vote_type', true);
        $is_track = $key === 'hungarian_track' && $type === 'track';
        $categories[$key]['candidates'][] = array('id' => (int) $item->ID, 'name' => get_the_title($item), 'artist' => get_post_meta($item->ID, '_huhs_vote_artist', true), 'type' => $type, 'image' => esc_url_raw(get_post_meta($item->ID, '_huhs_vote_image', true)), 'spotify' => $is_track ? esc_url_raw(get_post_meta($item->ID, '_huhs_vote_spotify', true)) : '', 'youtube' => $is_track ? esc_url_raw(get_post_meta($item->ID, '_huhs_vote_youtube', true)) : '');
    }
    return array('active' => true, 'seasonId' => (int) $season->ID, 'year' => (int) get_post_meta($season->ID, '_huhs_vote_year', true), 'title' => $season->post_title, 'categories' => array_values($categories));
}
