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
        'show_in_menu' => false,
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
    $candidate_rows = json_decode((string) get_post_meta($post->ID, '_huhs_vote_candidates', true), true);
    if (!is_array($candidate_rows)) {
        $candidate_rows = array();
        $legacy = get_posts(array('post_type' => 'huhs_vote_candidate', 'post_status' => array('publish', 'draft'), 'posts_per_page' => -1, 'meta_key' => '_huhs_vote_season', 'meta_value' => $post->ID));
        foreach ($legacy as $item) {
            $category = get_post_meta($item->ID, '_huhs_vote_category', true);
            $candidate_rows[$category][] = array('name' => $item->post_title, 'artist' => get_post_meta($item->ID, '_huhs_vote_artist', true), 'spotify' => get_post_meta($item->ID, '_huhs_vote_spotify', true), 'youtube' => get_post_meta($item->ID, '_huhs_vote_youtube', true));
        }
    }
    foreach (HUHS_VOTING_CATEGORIES as $key => $label) if (!isset($candidate_rows[$key])) $candidate_rows[$key] = array();
    ?>
    <p><label>Év<br><input class="widefat" type="number" name="huhs_vote_year" value="<?php echo esc_attr($fields['year']); ?>"></label></p>
    <p><label>Kezdés<br><input class="widefat" type="datetime-local" name="huhs_vote_start" value="<?php echo esc_attr($fields['start']); ?>"></label></p>
    <p><label>Zárás<br><input class="widefat" type="datetime-local" name="huhs_vote_end" value="<?php echo esc_attr($fields['end']); ?>"></label></p>
    <p><label><input type="checkbox" name="huhs_vote_enabled" value="1" <?php checked($fields['enabled'], '1'); ?>> Megjelenjen az app főoldalán</label></p>
    <p><label><input type="checkbox" name="huhs_vote_results_published" value="1" <?php checked($fields['results_published'], '1'); ?>> Eredmények publikálva</label></p>
    <hr><h3>Jelöltek</h3>
    <?php foreach (HUHS_VOTING_CATEGORIES as $key => $label) : ?>
        <div class="huhs-vote-category" style="margin:16px 0;padding:12px;border:1px solid #ccd0d4;">
            <strong><?php echo esc_html($label); ?></strong>
            <div class="huhs-vote-rows" data-category="<?php echo esc_attr($key); ?>">
                <?php foreach ($candidate_rows[$key] as $row) : ?>
                    <?php $row = is_array($row) ? $row : array(); ?>
                    <p class="huhs-vote-row"><input class="widefat" name="huhs_vote_candidates[<?php echo esc_attr($key); ?>][]" value="<?php echo esc_attr($row['name'] ?? ''); ?>" placeholder="Jelölt neve"></p>
                    <?php if ($key === 'hungarian_track') : ?><p class="huhs-vote-row"><input class="widefat" name="huhs_vote_track_artists[]" value="<?php echo esc_attr($row['artist'] ?? ''); ?>" placeholder="Előadó (opcionális)"><input class="widefat" type="url" name="huhs_vote_track_spotify[]" value="<?php echo esc_attr($row['spotify'] ?? ''); ?>" placeholder="Spotify (opcionális)"><input class="widefat" type="url" name="huhs_vote_track_youtube[]" value="<?php echo esc_attr($row['youtube'] ?? ''); ?>" placeholder="YouTube (opcionális)"></p><?php endif; ?>
                <?php endforeach; ?>
            </div>
            <button type="button" class="button huhs-vote-add" data-category="<?php echo esc_attr($key); ?>">+ Jelölt hozzáadása</button>
        </div>
    <?php endforeach; ?>
    <script>
    (function () {
        document.querySelectorAll('.huhs-vote-add').forEach(function (button) {
            button.addEventListener('click', function () {
                var category = button.dataset.category;
                var rows = document.querySelector('.huhs-vote-rows[data-category="' + category + '"]');
                var row = document.createElement('p');
                row.className = 'huhs-vote-row';
                row.innerHTML = '<input class="widefat" name="huhs_vote_candidates[' + category + '][]" placeholder="Jelölt neve">';
                rows.appendChild(row);
            });
        });
    }());
    </script>
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
    <p class="huhs-vote-track-field"><label>Előadó (zenénél)<br><input class="widefat" name="huhs_vote_artist" value="<?php echo esc_attr($artist); ?>"></label></p>
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
    if (isset($_POST['huhs_vote_candidates']) && is_array($_POST['huhs_vote_candidates'])) {
        $rows = array();
        foreach (HUHS_VOTING_CATEGORIES as $category => $label) {
            $rows[$category] = array();
            foreach ((array) ($_POST['huhs_vote_candidates'][$category] ?? array()) as $index => $name) {
                $name = sanitize_text_field(wp_unslash($name));
                if ($name === '') continue;
                $item = array('name' => $name, 'type' => $category === 'hungarian_track' ? 'track' : ($category === 'hungarian_organizer' ? 'organizer' : 'dj'));
                if ($category === 'hungarian_track') {
                    $item['artist'] = sanitize_text_field(wp_unslash($_POST['huhs_vote_track_artists'][$index] ?? ''));
                    $item['spotify'] = esc_url_raw(wp_unslash($_POST['huhs_vote_track_spotify'][$index] ?? ''));
                    $item['youtube'] = esc_url_raw(wp_unslash($_POST['huhs_vote_track_youtube'][$index] ?? ''));
                }
                $rows[$category][] = $item;
            }
        }
        update_post_meta($post_id, '_huhs_vote_candidates', wp_json_encode($rows, JSON_UNESCAPED_UNICODE));
    }
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
    $configured = json_decode((string) get_post_meta($season->ID, '_huhs_vote_candidates', true), true);
    if (is_array($configured)) {
        $categories = array();
        foreach (HUHS_VOTING_CATEGORIES as $key => $label) {
            $categories[$key] = array('key' => $key, 'label' => $label, 'candidates' => array());
            foreach ((array) ($configured[$key] ?? array()) as $index => $candidate) {
                $candidate = is_array($candidate) ? $candidate : array();
                $categories[$key]['candidates'][] = array('id' => absint(crc32($season->ID . ':' . $key . ':' . $index . ':' . ($candidate['name'] ?? ''))), 'name' => sanitize_text_field($candidate['name'] ?? ''), 'artist' => sanitize_text_field($candidate['artist'] ?? ''), 'type' => sanitize_key($candidate['type'] ?? 'dj'), 'image' => '', 'spotify' => esc_url_raw($candidate['spotify'] ?? ''), 'youtube' => esc_url_raw($candidate['youtube'] ?? ''));
            }
        }
        return array('active' => true, 'seasonId' => (int) $season->ID, 'year' => (int) get_post_meta($season->ID, '_huhs_vote_year', true), 'title' => $season->post_title, 'categories' => array_values($categories));
    }
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
