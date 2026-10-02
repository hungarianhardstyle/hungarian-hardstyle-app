<?php

if (!defined('ABSPATH')) {
    exit;
}

define('HUHS_GAME_TYPES', array(
    'daily_challenge' => 'Napi kihívás',
    'hardstyle_quiz' => 'Hardstyle kvíz',
    'festival_quiz' => 'Fesztivál kvíz',
    'hungarian_hardstyle_quiz' => 'Magyar Hardstyle kvíz',
    'guess_track' => 'Találd ki a zenét',
    'guess_artist' => 'Találd ki az előadót',
    'timeline' => 'Hardstyle idővonal',
    'who_is_dj' => 'Ki a DJ?',
    'cover_recognition' => 'Ismerd fel a borítót',
));

define('HUHS_GAME_ARTWORK_OPTION', 'huhs_game_type_artwork');

function huhs_game_is_quiz_type($type) {
    return in_array($type, array('hardstyle_quiz', 'festival_quiz', 'hungarian_hardstyle_quiz'), true);
}

/**
 * A játéktípus neve a kért nyelven (plugin 2.14.1).
 *
 * MIÉRT NÉVTÁR (és nem API): a játéktípus neve **nem prózai szöveg**, hanem a
 * plugin saját, rögzített címkéje (`HUHS_GAME_TYPES`) — ugyanaz a helyzet, mint
 * az ország-/városneveknél (`translation-places.php`) és a GYÍK
 * kategória-neveinél. Ezért determinisztikus, nincs hívás és nincs költség, a
 * magyar ág pedig **bájtazonos** marad.
 *
 * ⚠️ MÉRT HIBA, amit ez javít (2026-09-26, éles): a `title`/`type_label` a
 * `HUHS_GAME_TYPES`-ból jött, ezért angol módban is **magyarul** ment ki (a
 * 2.14.0 csak az összefoglalót fordította, és azt sem olvasta ki a végpont).
 */
function huhs_game_type_labels_en() {
    return array(
        'daily_challenge' => 'Daily Challenge',
        'hardstyle_quiz' => 'Hardstyle Quiz',
        'festival_quiz' => 'Festival Quiz',
        'hungarian_hardstyle_quiz' => 'Hungarian Hardstyle Quiz',
        'guess_track' => 'Guess the Track',
        'guess_artist' => 'Guess the Artist',
        'timeline' => 'Hardstyle Timeline',
        'who_is_dj' => 'Who Is the DJ?',
        'cover_recognition' => 'Recognise the Cover',
    );
}

function huhs_game_type_label($type, $lang = 'hu') {
    $types = defined('HUHS_GAME_TYPES') ? HUHS_GAME_TYPES : array();
    $fallback = isset($types[$type]) ? $types[$type] : 'Játék';
    if ($lang !== 'en') {
        return $fallback;
    }

    $names = huhs_game_type_labels_en();

    return isset($names[$type]) ? $names[$type] : $fallback;
}

add_action('init', function () {
    register_post_type('huhs_game', array(
        'labels' => array(
            'name' => 'Játékok',
            'singular_name' => 'Játék',
            'add_new' => 'Új játék',
            'add_new_item' => 'Új játék létrehozása',
            'edit_item' => 'Játék szerkesztése',
            'all_items' => 'Játékok',
        ),
        'public' => false,
        'show_ui' => true,
        'show_in_menu' => false,
        'menu_icon' => 'dashicons-games',
        'supports' => array('title', 'editor', 'thumbnail'),
        'capability_type' => 'post',
        'map_meta_cap' => true,
    ));
});

function huhs_game_datetime($value) {
    $value = sanitize_text_field((string) $value);
    if ($value === '') return null;
    try {
        return new DateTimeImmutable($value, wp_timezone());
    } catch (Exception $error) {
        return null;
    }
}

function huhs_game_artwork_defaults() {
    $saved = get_option(HUHS_GAME_ARTWORK_OPTION, array());
    if (!is_array($saved)) $saved = array();
    $defaults = array();
    foreach (HUHS_GAME_TYPES as $type => $label) {
        $defaults[$type] = esc_url_raw($saved[$type] ?? '');
    }
    return $defaults;
}

function huhs_game_resolved_artwork($type, $artwork = '') {
    $artwork = esc_url_raw($artwork);
    if ($artwork !== '') return $artwork;
    $defaults = huhs_game_artwork_defaults();
    return $defaults[$type] ?? '';
}

function huhs_game_normalize_questions($raw) {
    $questions = array();
    foreach ((array) $raw as $question) {
        $prompt = sanitize_textarea_field(wp_unslash($question['prompt'] ?? ''));
        $raw_options = (array) ($question['options'] ?? array());
        $correct_source = absint($question['correct'] ?? 0);
        $options = array();
        $correct = -1;
        foreach ($raw_options as $index => $option) {
            $option = sanitize_text_field(wp_unslash($option));
            if ($option === '') continue;
            if ((string) $index === (string) $correct_source) $correct = count($options);
            $options[] = $option;
        }
        if ($prompt === '' && !$options) continue;
        $questions[] = array(
            'prompt' => $prompt,
            'options' => array_slice($options, 0, 6),
            'correct' => $correct,
        );
    }
    return array_values($questions);
}

function huhs_game_normalize_timeline_items($raw) {
    $items = array();
    foreach ((array) $raw as $item) {
        $artist = sanitize_text_field(wp_unslash($item['artist'] ?? ''));
        $label = sanitize_text_field(wp_unslash($item['track_title'] ?? $item['label'] ?? ''));
        $date = sanitize_text_field(wp_unslash($item['date'] ?? ''));
        if ($artist === '' && $label === '' && $date === '') continue;
        $id = sanitize_key($item['id'] ?? '');
        if (!preg_match('/^[a-f0-9]{16}$/', $id)) $id = substr(hash('sha256', $artist . '|' . $label . '|' . $date), 0, 16);
        $items[] = array('id' => $id, 'artist' => $artist, 'track_title' => $label, 'date' => $date);
    }
    return array_values($items);
}

function huhs_game_timeline_items($post_id) {
    $items = json_decode((string) get_post_meta($post_id, '_huhs_game_timeline_items', true), true);
    return is_array($items) ? huhs_game_normalize_timeline_items($items) : array();
}

function huhs_game_timeline_order_is_correct($post_id, $ordered_ids) {
    $items = huhs_game_timeline_items($post_id);
    $ordered_ids = array_values(array_filter(array_map('sanitize_key', (array) $ordered_ids)));
    if (count($items) < 2 || count($ordered_ids) !== count($items) || count(array_unique($ordered_ids)) !== count($ordered_ids)) return false;
    $by_id = array();
    foreach ($items as $item) $by_id[$item['id']] = $item;
    foreach ($ordered_ids as $id) if (!isset($by_id[$id])) return false;
    usort($items, function ($left, $right) { return strcmp($left['date'], $right['date']); });
    return $ordered_ids === array_column($items, 'id');
}

function huhs_game_reward_bands($raw) {
    $bands = array();
    foreach ((array) $raw as $band) {
        $min = max(0, min(100, (int) ($band['min'] ?? 0)));
        $max = max(0, min(100, (int) ($band['max'] ?? 0)));
        $points = max(0, (int) ($band['points'] ?? 0));
        if ($max < $min) continue;
        $bands[] = array('min' => $min, 'max' => $max, 'points' => $points);
    }
    usort($bands, function ($left, $right) { return $left['min'] <=> $right['min']; });
    return array_values($bands);
}

function huhs_game_reward_bands_json($post_id) {
    $bands = json_decode((string) get_post_meta($post_id, '_huhs_game_reward_bands', true), true);
    return is_array($bands) ? huhs_game_reward_bands($bands) : array();
}

function huhs_game_media_values($raw) {
    return array(
        'audio_url' => esc_url_raw(wp_unslash($raw['audio_url'] ?? '')),
        'audio_start' => max(0, (float) ($raw['audio_start'] ?? 0)),
        'audio_end' => max(0, (float) ($raw['audio_end'] ?? 0)),
        'artist_clue_mode' => in_array(($raw['artist_clue_mode'] ?? ''), array('image', 'audio'), true) ? $raw['artist_clue_mode'] : 'image',
        'artist_image_url' => esc_url_raw(wp_unslash($raw['artist_image_url'] ?? '')),
    );
}

function huhs_game_restore_legacy_question_text($value) {
    if (!is_string($value)) return $value;
    return preg_replace_callback('/u([0-9a-fA-F]{4})/', function ($match) {
        $decoded = json_decode('"\\u' . $match[1] . '"');
        return is_string($decoded) ? $decoded : $match[0];
    }, $value);
}

function huhs_game_questions_json($post_id) {
    $questions = json_decode((string) get_post_meta($post_id, '_huhs_game_questions', true), true);
    if (!is_array($questions)) return array();
    foreach ($questions as &$question) {
        if (isset($question['prompt'])) $question['prompt'] = huhs_game_restore_legacy_question_text($question['prompt']);
        if (isset($question['options']) && is_array($question['options'])) {
            foreach ($question['options'] as &$option) $option = huhs_game_restore_legacy_question_text($option);
            unset($option);
        }
    }
    unset($question);
    return $questions;
}

function huhs_game_media_json($post_id) {
    $media = json_decode((string) get_post_meta($post_id, '_huhs_game_media', true), true);
    return is_array($media) ? huhs_game_media_values($media) : huhs_game_media_values(array());
}

function huhs_game_private_dir() {
    $base = function_exists('huhs_release_private_dir') ? huhs_release_private_dir() : trailingslashit(wp_upload_dir()['basedir']) . 'huhs-private-releases';
    $directory = trailingslashit(dirname($base)) . 'huhs-private-games';
    if (!is_dir($directory)) wp_mkdir_p($directory);
    $htaccess = trailingslashit($directory) . '.htaccess';
    if (!is_file($htaccess)) file_put_contents($htaccess, "Deny from all\n");
    return $directory;
}

function huhs_game_process_audio($post_id) {
    $post_id = absint($post_id);
    if (!$post_id || get_post_type($post_id) !== 'huhs_game') return false;
    $media = huhs_game_media_json($post_id);
    $type = get_post_meta($post_id, '_huhs_game_type', true);
    $needs_audio = $type === 'guess_track' || ($type === 'guess_artist' && $media['artist_clue_mode'] === 'audio');
    if (!$needs_audio) return false;
    $lock = 'huhs_game_audio_processing_' . $post_id;
    if (get_transient($lock)) return false;
    set_transient($lock, 1, 15 * MINUTE_IN_SECONDS);
    try {
        $attachment_id = attachment_url_to_postid($media['audio_url']);
        $source = $attachment_id ? get_attached_file($attachment_id) : '';
        $upload_base = realpath(wp_upload_dir()['basedir']);
        $source_real = $source ? realpath($source) : false;
        if (!$source_real || !$upload_base || strpos($source_real, trailingslashit($upload_base)) !== 0) throw new RuntimeException('A kiválasztott MP3 nem érvényes médiatárfájl.');
        $start = max(0, (float) $media['audio_start']);
        $duration = (float) $media['audio_end'] - $start;
        if ($duration <= 0 || $duration > 10) throw new RuntimeException('A zenerészlet hossza érvénytelen.');
        $ffmpeg = trim((string) (function_exists('shell_exec') ? shell_exec('command -v ffmpeg 2>/dev/null') : ''));
        if ($ffmpeg === '') throw new RuntimeException('Az MP3-feldolgozó nem érhető el.');
        $directory = huhs_game_private_dir();
        $target = trailingslashit($directory) . 'game-' . $post_id . '-clip.mp3';
        $old = get_post_meta($post_id, '_huhs_game_audio_clip_path', true);
        if (is_string($old) && $old !== $target && is_file($old)) @unlink($old);
        $command = escapeshellarg($ffmpeg) . ' -y -ss ' . escapeshellarg((string) $start) . ' -i ' . escapeshellarg($source_real) . ' -t ' . escapeshellarg((string) $duration) . ' -vn -map_metadata -1 -codec:a libmp3lame -b:a 96k ' . escapeshellarg($target) . ' 2>/dev/null';
        shell_exec($command);
        if (!is_file($target) || filesize($target) < 1024) throw new RuntimeException('A zenerészlet feldolgozása nem sikerült.');
        update_post_meta($post_id, '_huhs_game_audio_clip_path', $target);
        update_post_meta($post_id, '_huhs_game_audio_status', 'ready');
        delete_post_meta($post_id, '_huhs_game_audio_error');
        return true;
    } catch (Throwable $error) {
        update_post_meta($post_id, '_huhs_game_audio_status', 'failed');
        update_post_meta($post_id, '_huhs_game_audio_error', sanitize_text_field($error->getMessage()));
        return false;
    } finally {
        delete_transient($lock);
    }
}

add_action('huhs_game_process_audio', 'huhs_game_process_audio');

function huhs_game_status($post_id, $now = null) {
    $now = $now ?: new DateTimeImmutable('now', wp_timezone());
    $start = huhs_game_datetime(get_post_meta($post_id, '_huhs_game_start', true));
    $end = huhs_game_datetime(get_post_meta($post_id, '_huhs_game_end', true));
    $results_until = huhs_game_datetime(get_post_meta($post_id, '_huhs_game_results_until', true));
    if (!$start || !$end || !$results_until) return 'draft';
    if ($now < $start) return 'scheduled';
    if ($now < $end) return 'active';
    if ($now < $results_until) return 'closed';
    return 'results_expired';
}

function huhs_game_validation_error($post_id, $values) {
    $type = sanitize_key($values['type'] ?? '');
    $artwork = huhs_game_resolved_artwork($type, $values['artwork'] ?? '');
    $start = huhs_game_datetime($values['start'] ?? '');
    $end = huhs_game_datetime($values['end'] ?? '');
    $results_until = huhs_game_datetime($values['results_until'] ?? '');
    if (!isset(HUHS_GAME_TYPES[$type])) return 'Válassz érvényes játéktípust.';
    if ($artwork === '') return 'Játékkép nélkül a játék nem időzíthető.';
    if ($type === 'timeline') {
        $items = (array) ($values['timeline_items'] ?? array());
        if (count($items) < 3 || count($items) > 5) return 'Az idővonalhoz legalább 3, legfeljebb 5 tracket adj meg.';
        $dates = array();
        foreach ($items as $item) {
            if (trim((string) ($item['artist'] ?? '')) === '') return 'Minden idővonal-elemhez adj meg előadót.';
            if (trim((string) ($item['track_title'] ?? '')) === '') return 'Minden idővonal-elemhez adj meg trackcímet.';
            $date = trim((string) ($item['date'] ?? ''));
            if (!preg_match('/^\d{4}-(0[1-9]|1[0-2])$/', $date)) return 'Az idővonalnál év és hónap kell YYYY-MM formátumban, például 2010-05.';
            if (in_array($date, $dates, true)) return 'Az idővonal elemeihez adj meg különböző dátumokat.';
            $dates[] = $date;
        }
    } else {
        $questions = (array) ($values['questions'] ?? array());
        if (!$questions) return 'Legalább egy kérdés szükséges.';
        foreach ($questions as $question) {
            if (trim((string) ($question['prompt'] ?? '')) === '') return 'Minden kérdéshez adj meg kérdést.';
            $option_count = count((array) ($question['options'] ?? array()));
            if (huhs_game_is_quiz_type($type)) {
                if ($option_count < 2 || $option_count > 6) return 'Minden kvízkérdéshez 2–6 válaszlehetőség kell.';
            } elseif ($option_count < 3 || $option_count > 5) {
                return 'Ehhez a játékhoz kérdésenként 3–5 válaszlehetőség kell.';
            }
            if (!isset($question['correct']) || (int) $question['correct'] < 0 || (int) $question['correct'] >= count($question['options'])) return 'Minden kérdésnél jelöld meg a helyes választ.';
        }
    }
    if (huhs_game_is_quiz_type($type)) {
        $bands = huhs_game_reward_bands($values['reward_bands'] ?? array());
        if (!$bands) return 'A kvízhez legalább egy jutalomsávot adj meg.';
        $last_max = -1;
        foreach ($bands as $band) {
            if ($band['min'] <= $last_max) return 'A kvíz jutalomsávjai nem fedhetik át egymást.';
            $last_max = $band['max'];
        }
    } elseif ((int) ($values['reward_points'] ?? 0) < 0) {
        return 'A jutalompont nem lehet negatív.';
    }
    $media = (array) ($values['media'] ?? array());
    if ($type === 'guess_track') {
        if (empty($media['audio_url'])) return 'A zenefelismerős játékhoz tölts fel MP3-at.';
        if ((float) ($media['audio_end'] ?? 0) <= (float) ($media['audio_start'] ?? 0) || ((float) $media['audio_end'] - (float) $media['audio_start']) > 10) return 'A lejátszandó zenerészlet legyen 0–10 másodperc közötti.';
    }
    if ($type === 'guess_artist') {
        if (($media['artist_clue_mode'] ?? 'image') === 'image' && empty($media['artist_image_url'])) return 'Képes előadófelismeréshez adj meg képrészletet.';
        if (($media['artist_clue_mode'] ?? 'image') === 'audio') {
            if (empty($media['audio_url'])) return 'Zenes előadófelismeréshez tölts fel MP3-at.';
            if ((float) ($media['audio_end'] ?? 0) <= (float) ($media['audio_start'] ?? 0) || ((float) $media['audio_end'] - (float) $media['audio_start']) > 10) return 'A lejátszandó zenerészlet legyen 0–10 másodperc közötti.';
        }
    }
    if (!$start || !$end || !$results_until || $start >= $end || $end >= $results_until) {
        return 'A kezdésnek a befejezés előtt, az eredmények lejáratának pedig a befejezés után kell lennie.';
    }
    $games = get_posts(array(
        'post_type' => 'huhs_game',
        'post_status' => array('publish', 'future'),
        'posts_per_page' => -1,
        'post__not_in' => $post_id ? array($post_id) : array(),
        'fields' => 'ids',
    ));
    foreach ($games as $game_id) {
        $other_start = huhs_game_datetime(get_post_meta($game_id, '_huhs_game_start', true));
        $other_end = huhs_game_datetime(get_post_meta($game_id, '_huhs_game_end', true));
        if ($other_start && $other_end && $start < $other_end && $end > $other_start) {
            return 'Az aktív időszak átfed egy másik játékkal.';
        }
    }
    return '';
}

add_filter('wp_insert_post_data', function ($data, $postarr) {
    if (($data['post_type'] ?? '') !== 'huhs_game' || empty($_POST['huhs_game_nonce']) || !wp_verify_nonce($_POST['huhs_game_nonce'], 'huhs_game_save')) return $data;
    if (!in_array($data['post_status'] ?? '', array('publish', 'future'), true)) return $data;
    $values = array(
        'type' => sanitize_key(wp_unslash($_POST['huhs_game_type'] ?? '')),
        'artwork' => esc_url_raw(wp_unslash($_POST['huhs_game_artwork'] ?? '')),
        'start' => sanitize_text_field(wp_unslash($_POST['huhs_game_start'] ?? '')),
        'end' => sanitize_text_field(wp_unslash($_POST['huhs_game_end'] ?? '')),
        'results_until' => sanitize_text_field(wp_unslash($_POST['huhs_game_results_until'] ?? '')),
        'questions' => huhs_game_normalize_questions($_POST['huhs_game_questions'] ?? array()),
        'timeline_items' => huhs_game_normalize_timeline_items($_POST['huhs_game_timeline_items'] ?? array()),
        'reward_points' => max(0, (int) ($_POST['huhs_game_reward_points'] ?? 0)),
        'reward_bands' => huhs_game_reward_bands($_POST['huhs_game_reward_bands'] ?? array()),
        'media' => huhs_game_media_values($_POST['huhs_game_media'] ?? array()),
    );
    $error = huhs_game_validation_error(absint($postarr['ID'] ?? 0), $values);
    if ($error === '') return $data;
    $data['post_status'] = 'draft';
    set_transient('huhs_game_save_error_' . get_current_user_id(), $error, MINUTE_IN_SECONDS);
    return $data;
}, 10, 2);

add_action('admin_notices', function () {
    $key = 'huhs_game_save_error_' . get_current_user_id();
    $error = get_transient($key);
    if (!$error) return;
    delete_transient($key);
    echo '<div class="notice notice-error"><p>Játék piszkozatként maradt: ' . esc_html($error) . '</p></div>';
});

add_action('admin_menu', function () {
    add_submenu_page('huhs-mobile', 'Játékok', 'Játékok', 'edit_posts', 'edit.php?post_type=huhs_game');
    add_submenu_page('huhs-mobile', 'Új játék', 'Új játék', 'edit_posts', 'post-new.php?post_type=huhs_game');
    add_submenu_page('huhs-mobile', 'Játék eredmények', 'Játék eredmények', 'manage_options', 'huhs-game-results', 'huhs_game_results_page');
    add_submenu_page('huhs-mobile', 'Játékképek', 'Játékképek', 'manage_options', 'huhs-game-images', 'huhs_game_images_page');
}, 25);

add_action('admin_enqueue_scripts', function ($hook) {
    if ($hook === 'huhs-mobile_page_huhs-game-images') wp_enqueue_media();
});

add_action('admin_post_huhs_save_game_images', function () {
    if (!current_user_can('manage_options')) wp_die('Nincs jogosultság.');
    check_admin_referer('huhs_save_game_images');
    $saved = array();
    foreach (HUHS_GAME_TYPES as $type => $label) {
        $saved[$type] = esc_url_raw(wp_unslash($_POST['artwork'][$type] ?? ''));
    }
    update_option(HUHS_GAME_ARTWORK_OPTION, $saved, false);
    wp_safe_redirect(admin_url('admin.php?page=huhs-game-images&saved=1'));
    exit;
});

function huhs_game_images_page() {
    $defaults = huhs_game_artwork_defaults();
    ?>
    <div class="wrap"><h1>Játékképek</h1>
    <?php if (!empty($_GET['saved'])) : ?><div class="notice notice-success"><p>Az alapértelmezett játékképek elmentve.</p></div><?php endif; ?>
    <p>Ezek a képek töltődnek be automatikusan, ha az adott játékhoz nem adsz meg külön képet.</p>
    <form method="post" action="<?php echo esc_url(admin_url('admin-post.php')); ?>">
      <input type="hidden" name="action" value="huhs_save_game_images"><?php wp_nonce_field('huhs_save_game_images'); ?>
      <table class="widefat striped"><thead><tr><th>Játéktípus</th><th>Kép URL</th></tr></thead><tbody>
      <?php foreach (HUHS_GAME_TYPES as $type => $label) : ?><tr>
        <td><strong><?php echo esc_html($label); ?></strong><br><code><?php echo esc_html($type); ?></code></td>
        <td><input class="widefat huhs-game-image" data-type="<?php echo esc_attr($type); ?>" name="artwork[<?php echo esc_attr($type); ?>]" value="<?php echo esc_attr($defaults[$type]); ?>"><button type="button" class="button huhs-game-media">Médiatár</button></td>
      </tr><?php endforeach; ?></tbody></table>
      <p><button class="button button-primary">Mentés</button></p>
    </form></div>
    <script>(function($){$('.huhs-game-media').on('click',function(){var b=$(this),f=b.prev('.huhs-game-image'),p=wp.media({title:'Játékkép kiválasztása',button:{text:'Használom'},multiple:false});p.on('select',function(){f.val(p.state().get('selection').first().toJSON().url);});p.open();});})(jQuery);</script>
    <?php
}

function huhs_game_results_page() {
    if (!current_user_can('manage_options')) wp_die('Nincs jogosultság.');

    $games = get_posts(array(
        'post_type' => 'huhs_game',
        'post_status' => array('publish', 'future', 'draft', 'pending', 'private'),
        'posts_per_page' => -1,
        'orderby' => 'date',
        'order' => 'DESC',
    ));
    $selected_id = absint($_GET['game_id'] ?? 0);
    $selected = $selected_id ? get_post($selected_id) : null;
    if (!$selected || $selected->post_type !== 'huhs_game') $selected = null;

    echo '<div class="wrap"><h1>Játék eredmények</h1>';
    echo '<p>Az oldal csak összesített, név nélküli adatokat mutat. A lejárt játékok is választhatók.</p>';
    echo '<form method="get" style="margin:16px 0 24px">';
    echo '<input type="hidden" name="page" value="huhs-game-results">';
    echo '<label for="huhs-game-result-select"><strong>Játék kiválasztása</strong></label> ';
    echo '<select id="huhs-game-result-select" name="game_id" onchange="this.form.submit()">';
    echo '<option value="">Válassz játékot</option>';
    foreach ($games as $game) {
        $type = get_post_meta($game->ID, '_huhs_game_type', true);
        $label = HUHS_GAME_TYPES[$type] ?? 'Játék';
        $title = get_the_title($game->ID);
        $date = get_post_meta($game->ID, '_huhs_game_start', true);
        $option_label = $label . ($title !== '' ? ' – ' . $title : '') . ($date !== '' ? ' (' . $date . ')' : '');
        echo '<option value="' . (int) $game->ID . '" ' . selected($selected_id, $game->ID, false) . '>' . esc_html($option_label) . '</option>';
    }
    echo '</select></form>';

    if (!$selected) {
        echo '<p>Válassz egy játékot az összesítő megtekintéséhez.</p></div>';
        return;
    }

    $stats = get_post_meta($selected->ID, '_huhs_game_stats', true);
    $stats = is_array($stats) ? $stats : array();
    $submissions = max(0, (int) ($stats['submissions'] ?? 0));
    $correct_answers = max(0, (int) ($stats['correct_answers'] ?? 0));
    $updated_at = sanitize_text_field((string) ($stats['updated_at'] ?? ''));
    $status = huhs_game_status($selected->ID);
    $status_labels = array('draft' => 'Piszkozat', 'scheduled' => 'Időzítve', 'active' => 'Aktív', 'closed' => 'Lezárult', 'results_expired' => 'Eredmények lejártak');
    echo '<h2>' . esc_html(HUHS_GAME_TYPES[get_post_meta($selected->ID, '_huhs_game_type', true)] ?? 'Játék') . '</h2>';
    echo '<p><strong>Állapot:</strong> ' . esc_html($status_labels[$status] ?? $status) . '</p>';
    echo '<table class="widefat striped" style="max-width:700px"><tbody>';
    echo '<tr><th>Beküldők száma</th><td>' . number_format_i18n($submissions) . '</td></tr>';
    echo '<tr><th>Helyes válaszok száma</th><td>' . number_format_i18n($correct_answers) . '</td></tr>';
    if ($updated_at !== '') echo '<tr><th>Utolsó frissítés</th><td>' . esc_html($updated_at) . '</td></tr>';
    echo '</tbody></table>';
    if ($submissions === 0 && $correct_answers === 0) echo '<p class="description">Ehhez a játékhoz még nem érkezett beküldött eredmény.</p>';
    echo '</div>';
}

add_action('add_meta_boxes', function () {
    add_meta_box('huhs-game-settings', 'Játék beállításai', 'huhs_game_settings_box', 'huhs_game', 'normal', 'high');
});

function huhs_game_settings_box($post) {
    wp_nonce_field('huhs_game_save', 'huhs_game_nonce');
    $get = function ($key) use ($post) { return get_post_meta($post->ID, '_huhs_game_' . $key, true); };
    $questions = huhs_game_questions_json($post->ID);
    if (!$questions) $questions = array(array('prompt' => '', 'options' => array('', ''), 'correct' => -1));
    $timeline_items = huhs_game_timeline_items($post->ID);
    if (!$timeline_items) $timeline_items = array(array('artist' => '', 'track_title' => '', 'date' => ''), array('artist' => '', 'track_title' => '', 'date' => ''), array('artist' => '', 'track_title' => '', 'date' => ''));
    $reward_points = max(0, (int) $get('reward_points'));
    $reward_bands = huhs_game_reward_bands_json($post->ID);
    if (!$reward_bands) $reward_bands = array(array('min' => 0, 'max' => 49, 'points' => 0), array('min' => 50, 'max' => 69, 'points' => 5), array('min' => 70, 'max' => 79, 'points' => 10), array('min' => 80, 'max' => 89, 'points' => 20), array('min' => 90, 'max' => 99, 'points' => 30), array('min' => 100, 'max' => 100, 'points' => 50));
    ?>
    <p><label>Játéktípus<br><select class="widefat" name="huhs_game_type"><option value="">Válassz</option><?php foreach (HUHS_GAME_TYPES as $key => $label) : ?><option value="<?php echo esc_attr($key); ?>" <?php selected($get('type'), $key); ?>><?php echo esc_html($label); ?></option><?php endforeach; ?></select></label></p>
    <p><label>Játékkép URL-je<br><input class="widefat" id="huhs-game-artwork" type="url" name="huhs_game_artwork" value="<?php echo esc_attr($get('artwork')); ?>"></label> <button type="button" class="button huhs-game-artwork-media">Médiatár</button><br><span class="description">Üresen hagyva a kiválasztott játéktípus alapértelmezett képe használatos.</span></p>
    <p><label>Kezdés<br><input type="datetime-local" name="huhs_game_start" value="<?php echo esc_attr($get('start')); ?>"></label></p>
    <p><label>Befejezés<br><input type="datetime-local" name="huhs_game_end" value="<?php echo esc_attr($get('end')); ?>"></label></p>
    <p><label>Eredmények lejárata<br><input type="datetime-local" name="huhs_game_results_until" value="<?php echo esc_attr($get('results_until')); ?>"></label></p>
    <p><label>Rövid leírás / CTA<br><textarea class="widefat" rows="3" name="huhs_game_summary"><?php echo esc_textarea($get('summary')); ?></textarea></label></p>
    <div id="huhs-game-reward-settings" style="border:1px solid #ccd0d4;padding:10px;margin:12px 0"><h4>Achievement jutalmazás</h4><p class="description">Kvíznél a helyes válaszok százaléka alapján választódik ki a jutalomsáv. Más játéknál a helyes teljesítéshez járó fix pontot adhatod meg.</p><div class="huhs-game-fixed-reward"><label>Fix jutalom pontban<br><input type="number" min="0" step="1" name="huhs_game_reward_points" value="<?php echo (int) $reward_points; ?>"></label></div><div class="huhs-game-quiz-reward"><p><strong>Százalékos jutalomsávok</strong></p><?php foreach ($reward_bands as $band_index => $band) : ?><p><label>Minimum % <input type="number" min="0" max="100" name="huhs_game_reward_bands[<?php echo (int) $band_index; ?>][min]" value="<?php echo (int) $band['min']; ?>"></label> <label>Maximum % <input type="number" min="0" max="100" name="huhs_game_reward_bands[<?php echo (int) $band_index; ?>][max]" value="<?php echo (int) $band['max']; ?>"></label> <label>Achievement pont <input type="number" min="0" step="1" name="huhs_game_reward_bands[<?php echo (int) $band_index; ?>][points]" value="<?php echo (int) $band['points']; ?>"></label></p><?php endforeach; ?></div></div>
    <?php $media = huhs_game_media_json($post->ID); ?>
    <div id="huhs-game-media-settings" style="border:1px solid #ccd0d4;padding:10px;margin:12px 0"><h4>Játékhoz tartozó felismerési anyag</h4><p class="description">A teljes MP3 csak adminforrás. A játékoshoz később kizárólag a biztonságosan kivágott, legfeljebb 10 másodperces részlet kerülhet.</p><div class="huhs-game-audio-fields"><p><label>Forrás MP3<br><input class="widefat" id="huhs-game-audio-url" type="url" name="huhs_game_media[audio_url]" value="<?php echo esc_attr($media['audio_url']); ?>"></label> <button type="button" class="button huhs-game-media-picker" data-target="huhs-game-audio-url">MP3 kiválasztása</button></p><p><label>Részlet kezdete (mp)<br><input type="number" min="0" max="86400" step="0.1" name="huhs_game_media[audio_start]" value="<?php echo esc_attr($media['audio_start']); ?>"></label> <label>Részlet vége (mp)<br><input type="number" min="0" max="86400" step="0.1" name="huhs_game_media[audio_end]" value="<?php echo esc_attr($media['audio_end'] ?: 10); ?>"></label></p></div><div class="huhs-game-artist-fields"><p><label>Előadófelismerés módja<br><select id="huhs-game-artist-mode" name="huhs_game_media[artist_clue_mode]"><option value="image" <?php selected($media['artist_clue_mode'], 'image'); ?>>Képrészlet</option><option value="audio" <?php selected($media['artist_clue_mode'], 'audio'); ?>>10 másodperces zenerészlet</option></select></label></p><p class="huhs-game-artist-image"><label>Képrészlet URL-je<br><input class="widefat" id="huhs-game-artist-image-url" type="url" name="huhs_game_media[artist_image_url]" value="<?php echo esc_attr($media['artist_image_url']); ?>"></label> <button type="button" class="button huhs-game-media-picker" data-target="huhs-game-artist-image-url">Kép kiválasztása</button></p></div></div>
    <div id="huhs-game-timeline-settings" style="border:1px solid #ccd0d4;padding:10px;margin:12px 0"><h4>Idővonal elemei</h4><p class="description">Adj meg 3–5 tracket. Az előadó és a track címe megjelenik az appban, az év és hónap csak az ellenőrzéshez kell. A helyes sorrendet a szerver ellenőrzi.</p><?php foreach ($timeline_items as $item_index => $item) : ?><div class="huhs-game-timeline-item" style="border-top:1px solid #ccd0d4;padding:10px 0"><p><label>Előadó<br><input class="widefat" type="text" name="huhs_game_timeline_items[<?php echo (int) $item_index; ?>][artist]" value="<?php echo esc_attr($item['artist'] ?? ''); ?>" placeholder="Például: Denoiser"></label></p><p><label>Track címe<br><input class="widefat" type="text" name="huhs_game_timeline_items[<?php echo (int) $item_index; ?>][track_title]" value="<?php echo esc_attr($item['track_title'] ?? ''); ?>" placeholder="Például: első album"></label></p><p><label>Megjelenés éve és hónapja<br><input type="month" name="huhs_game_timeline_items[<?php echo (int) $item_index; ?>][date]" value="<?php echo esc_attr($item['date'] ?? ''); ?>"></label></p></div><?php endforeach; ?><button type="button" class="button" id="huhs-game-add-timeline-item">+ Elem hozzáadása</button></div>
    <div id="huhs-game-quiz-settings"><hr><h4>Kérdések és válaszok</h4>
    <?php foreach ($questions as $question_index => $question) : ?><div class="huhs-game-question" style="border:1px solid #ccd0d4;padding:10px;margin:10px 0"><p><label>Kérdés<br><textarea class="widefat" name="huhs_game_questions[<?php echo (int) $question_index; ?>][prompt]" rows="2"><?php echo esc_textarea($question['prompt'] ?? ''); ?></textarea></label></p><p>Válaszlehetőségek (2–6), a helyes választ jelöld:</p><?php for ($option_index = 0; $option_index < 6; $option_index++) : ?><p><label><input type="radio" name="huhs_game_questions[<?php echo (int) $question_index; ?>][correct]" value="<?php echo (int) $option_index; ?>" <?php checked((int) ($question['correct'] ?? -1), $option_index); ?>> <input type="text" class="widefat" name="huhs_game_questions[<?php echo (int) $question_index; ?>][options][<?php echo (int) $option_index; ?>]" value="<?php echo esc_attr($question['options'][$option_index] ?? ''); ?>" placeholder="Válasz <?php echo (int) ($option_index + 1); ?>"></label></p><?php endfor; ?></div><?php endforeach; ?>
    <button type="button" class="button" id="huhs-game-add-question">+ Kérdés hozzáadása</button></div>
    <template id="huhs-game-timeline-template"><div class="huhs-game-timeline-item" style="border-top:1px solid #ccd0d4;padding:10px 0"><p><label>Előadó<br><input class="widefat" type="text" name="huhs_game_timeline_items[__INDEX__][artist]" placeholder="Például: Denoiser"></label></p><p><label>Track címe<br><input class="widefat" type="text" name="huhs_game_timeline_items[__INDEX__][track_title]" placeholder="Például: első album"></label></p><p><label>Megjelenés éve és hónapja<br><input type="month" name="huhs_game_timeline_items[__INDEX__][date]"></label></p></div></template>
    <template id="huhs-game-question-template"><div class="huhs-game-question" style="border:1px solid #ccd0d4;padding:10px;margin:10px 0"><p><label>Kérdés<br><textarea class="widefat" name="huhs_game_questions[__INDEX__][prompt]" rows="2"></textarea></label></p><p>Válaszlehetőségek (kvíznél 2–6, más játéknál 3–5), a helyes választ jelöld:</p><?php for ($option_index = 0; $option_index < 6; $option_index++) : ?><p><label><input type="radio" name="huhs_game_questions[__INDEX__][correct]" value="<?php echo (int) $option_index; ?>"> <input type="text" class="widefat" name="huhs_game_questions[__INDEX__][options][<?php echo (int) $option_index; ?>]" value="" placeholder="Válasz <?php echo (int) ($option_index + 1); ?>"></label></p><?php endfor; ?></div></template>
    <p class="description">Jelenlegi státusz: <strong><?php echo esc_html(array('draft' => 'Piszkozat', 'scheduled' => 'Időzítve', 'active' => 'Aktív', 'closed' => 'Lezárult', 'results_expired' => 'Eredmények lejártak')[huhs_game_status($post->ID)]); ?></strong></p>
    <script>(function($){var defaults=<?php echo wp_json_encode(huhs_game_artwork_defaults()); ?>,type=$('[name="huhs_game_type"]'),field=$('#huhs-game-artwork'),media=$('#huhs-game-media-settings'),timeline=$('#huhs-game-timeline-settings'),quiz=$('#huhs-game-quiz-settings'),reward=$('#huhs-game-reward-settings');function refresh(){var value=type.val(),artistMode=$('#huhs-game-artist-mode').val(),isQuiz=<?php echo wp_json_encode(array('hardstyle_quiz','festival_quiz','hungarian_hardstyle_quiz')); ?>.indexOf(value)!==-1;media.toggle(value==='guess_track'||value==='guess_artist');media.find('.huhs-game-audio-fields').toggle(value==='guess_track'||(value==='guess_artist'&&artistMode==='audio'));media.find('.huhs-game-artist-fields').toggle(value==='guess_artist');media.find('.huhs-game-artist-image').toggle(value==='guess_artist'&&artistMode==='image');timeline.toggle(value==='timeline');quiz.toggle(value!=='timeline');reward.find('.huhs-game-fixed-reward').toggle(!isQuiz);reward.find('.huhs-game-quiz-reward').toggle(isQuiz);}function addTemplate(templateId,buttonId,selector,max){var template=document.getElementById(templateId),button=document.getElementById(buttonId),next=document.querySelectorAll(selector).length;button.addEventListener('click',function(){var count=document.querySelectorAll(selector).length;if(count>=max){button.disabled=true;return;}template.insertAdjacentHTML('beforebegin',template.innerHTML.split('__INDEX__').join(String(next++)));if(document.querySelectorAll(selector).length>=max)button.disabled=true;});}type.on('change',function(){if(!field.val())field.val(defaults[type.val()]||'');refresh();});$('#huhs-game-artist-mode').on('change',refresh);$('.huhs-game-artwork-media').on('click',function(){var p=wp.media({title:'Játékkép kiválasztása',button:{text:'Használom'},multiple:false});p.on('select',function(){field.val(p.state().get('selection').first().toJSON().url);});p.open();});$('.huhs-game-media-picker').on('click',function(){var target=$('#'+$(this).data('target')),audio=$(this).data('target').indexOf('audio')!==-1;var p=wp.media({title:audio?'MP3 kiválasztása':'Kép kiválasztása',button:{text:'Használom'},library:{type:audio?'audio':'image'},multiple:false});p.on('select',function(){target.val(p.state().get('selection').first().toJSON().url);});p.open();});addTemplate('huhs-game-timeline-template','huhs-game-add-timeline-item','.huhs-game-timeline-item',5);addTemplate('huhs-game-question-template','huhs-game-add-question','.huhs-game-question',99);refresh();})(jQuery);</script>
    <?php
}

add_action('save_post_huhs_game', function ($post_id) {
    if (defined('DOING_AUTOSAVE') && DOING_AUTOSAVE) return;
    if (!current_user_can('edit_post', $post_id) || !isset($_POST['huhs_game_nonce']) || !wp_verify_nonce($_POST['huhs_game_nonce'], 'huhs_game_save')) return;
    $values = array(
        'type' => sanitize_key(wp_unslash($_POST['huhs_game_type'] ?? '')),
        'artwork' => esc_url_raw(wp_unslash($_POST['huhs_game_artwork'] ?? '')),
        'start' => sanitize_text_field(wp_unslash($_POST['huhs_game_start'] ?? '')),
        'end' => sanitize_text_field(wp_unslash($_POST['huhs_game_end'] ?? '')),
        'results_until' => sanitize_text_field(wp_unslash($_POST['huhs_game_results_until'] ?? '')),
        'summary' => sanitize_textarea_field(wp_unslash($_POST['huhs_game_summary'] ?? '')),
        'questions' => huhs_game_normalize_questions($_POST['huhs_game_questions'] ?? array()),
        'timeline_items' => huhs_game_normalize_timeline_items($_POST['huhs_game_timeline_items'] ?? array()),
        'reward_points' => max(0, (int) ($_POST['huhs_game_reward_points'] ?? 0)),
        'reward_bands' => huhs_game_reward_bands($_POST['huhs_game_reward_bands'] ?? array()),
        'media' => huhs_game_media_values($_POST['huhs_game_media'] ?? array()),
    );
    $stored_questions = huhs_game_questions_json($post_id);
    if (!$values['questions']) $values['questions'] = $stored_questions;
    foreach ($values as $key => $value) {
        $stored_value = in_array($key, array('questions', 'timeline_items', 'reward_bands', 'media'), true)
            ? wp_slash(wp_json_encode($value, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES))
            : $value;
        update_post_meta($post_id, '_huhs_game_' . $key, $stored_value);
    }
    $error = huhs_game_validation_error($post_id, $values);
    update_post_meta($post_id, '_huhs_game_validation_error', $error);
    $audio_type = $values['type'] === 'guess_track' || ($values['type'] === 'guess_artist' && $values['media']['artist_clue_mode'] === 'audio');
    if ($audio_type && !wp_next_scheduled('huhs_game_process_audio', array($post_id))) wp_schedule_single_event(time() + 5, 'huhs_game_process_audio', array($post_id));
});

/**
 * A játék nyilvános payloadja a kért nyelven (2.14.1, kvíz 2.14.2).
 *
 * ⚠️ A `$lang` **opcionális** (alap: `hu`), ezért egyetlen régi hívó sem tört el.
 * A magyar ág bájtazonos: a `huhs_translation_text()` nem-angol kérésre az
 * eredeti (magyar) metaértéket adja vissza, a típus-név pedig a `HUHS_GAME_TYPES`.
 *
 * ⚠️ 2.14.2: a **kérdések és a válaszlehetőségek is** fordulnak
 * (`huhs_translation_game_questions()`), a `correct` index viszont a nyilvános
 * payloadba **nem** kerülhet (a helyes válasz a játékos elől rejtve marad).
 */
function huhs_game_public_payload($post, $lang = 'hu') {
    $type = get_post_meta($post->ID, '_huhs_game_type', true);
    $summary_hu = (string) get_post_meta($post->ID, '_huhs_game_summary', true);
    $type_label = huhs_game_type_label($type, $lang);
    $media = huhs_game_media_json($post->ID);
    $questions = array_map(function ($question) {
        return array('prompt' => $question['prompt'] ?? '', 'options' => array_values($question['options'] ?? array()));
    }, huhs_translation_game_questions($post->ID, $lang));
    $timeline_items = array_map(function ($item) {
        return array('id' => $item['id'] ?? '', 'artist' => $item['artist'] ?? '', 'track_title' => $item['track_title'] ?? ($item['label'] ?? ''));
    }, huhs_game_timeline_items($post->ID));
    return array(
        'id' => (int) $post->ID,
        'title' => $type_label,
        'type' => $type,
        'type_label' => $type_label,
        'summary' => huhs_translation_text($post->ID, $lang, '_huhs_game_summary', $summary_hu),
        'artwork' => huhs_game_resolved_artwork($type, get_post_meta($post->ID, '_huhs_game_artwork', true)),
        'start_at' => get_post_meta($post->ID, '_huhs_game_start', true),
        'end_at' => get_post_meta($post->ID, '_huhs_game_end', true),
        'results_until' => get_post_meta($post->ID, '_huhs_game_results_until', true),
        'status' => huhs_game_status($post->ID),
        'questions' => $questions,
        'timeline_items' => $timeline_items,
        'reward_points' => max(0, (int) get_post_meta($post->ID, '_huhs_game_reward_points', true)),
        'reward_bands' => huhs_game_is_quiz_type($type) ? huhs_game_reward_bands_json($post->ID) : array(),
        'clue_mode' => $type === 'guess_artist' ? $media['artist_clue_mode'] : ($type === 'guess_track' ? 'audio' : ''),
        'clue_image_url' => $type === 'guess_artist' && $media['artist_clue_mode'] === 'image' ? $media['artist_image_url'] : '',
        'audio_ready' => ($type === 'guess_track' || ($type === 'guess_artist' && $media['artist_clue_mode'] === 'audio')) && get_post_meta($post->ID, '_huhs_game_audio_status', true) === 'ready',
    );
}

function huhs_game_create_clip_token(WP_REST_Request $request) {
    $game_id = absint($request['id']);
    $game = get_post($game_id);
    if (!$game || $game->post_type !== 'huhs_game' || $game->post_status !== 'publish' || huhs_game_status($game_id) !== 'active') return new WP_Error('not_available', 'A játék hangrészlete most nem érhető el.', array('status' => 404));
    $path = get_post_meta($game_id, '_huhs_game_audio_clip_path', true);
    if (!is_string($path) || !is_file($path)) {
        huhs_game_process_audio($game_id);
        $path = get_post_meta($game_id, '_huhs_game_audio_clip_path', true);
    }
    if (!is_string($path) || !is_file($path)) return new WP_Error('not_ready', 'A hangrészlet még feldolgozás alatt áll.', array('status' => 409));
    $token = wp_generate_password(48, false, false);
    set_transient('huhs_private_download_' . hash('sha256', $token), array('path' => $path, 'release_id' => $game_id, 'variant' => 'game_clip'), 300);
    return rest_ensure_response(array('download_url' => add_query_arg(array('huhs_download' => '1', 'token' => $token), home_url('/')), 'expires_in' => 300));
}

add_action('rest_api_init', function () {
    register_rest_route('huhs/v1', '/games/active', array(
        'methods' => WP_REST_Server::READABLE,
        'permission_callback' => '__return_true',
        'callback' => function ($request) {
            $lang = huhs_request_lang($request);
            $games = get_posts(array('post_type' => 'huhs_game', 'post_status' => 'publish', 'posts_per_page' => -1, 'orderby' => 'date', 'order' => 'ASC'));
            foreach ($games as $game) if (huhs_game_status($game->ID) === 'active') return rest_ensure_response(huhs_game_public_payload($game, $lang));
            return rest_ensure_response(null);
        },
    ));

    register_rest_route('huhs/v1', '/games/results/latest', array(
        'methods' => WP_REST_Server::READABLE,
        'permission_callback' => '__return_true',
        'callback' => function ($request) {
            $lang = huhs_request_lang($request);
            $games = get_posts(array('post_type' => 'huhs_game', 'post_status' => 'publish', 'posts_per_page' => -1, 'orderby' => 'date', 'order' => 'DESC'));
            foreach ($games as $game) {
                if (huhs_game_status($game->ID) === 'closed') return rest_ensure_response(huhs_game_public_payload($game, $lang));
            }
            return rest_ensure_response(null);
        },
    ));

    register_rest_route('huhs/v1', '/games/(?P<id>\d+)', array(
        'methods' => WP_REST_Server::READABLE,
        'permission_callback' => '__return_true',
        'callback' => function ($request) {
            $game = get_post(absint($request['id']));
            if (!$game || $game->post_type !== 'huhs_game' || $game->post_status !== 'publish') return new WP_Error('not_found', 'A játék nem található.', array('status' => 404));
            $status = huhs_game_status($game->ID);
            if (!in_array($status, array('active', 'closed'), true)) return new WP_Error('not_available', 'A játék jelenleg nem érhető el.', array('status' => 404));
            return rest_ensure_response(huhs_game_public_payload($game, huhs_request_lang($request)));
        },
    ));

    // This endpoint is only for the trusted Firebase server proxy. Correct
    // answers never belong in a public app request.
    register_rest_route('huhs/v1', '/games/(?P<id>\d+)/private', array(
        'methods' => WP_REST_Server::READABLE,
        'permission_callback' => function () { return current_user_can('edit_posts'); },
        'callback' => function ($request) {
            $game = get_post(absint($request['id']));
            if (!$game || $game->post_type !== 'huhs_game') return new WP_Error('not_found', 'A játék nem található.', array('status' => 404));
            // ⚠️ A `lang` itt is átmegy (2.14.1): a Firebase-proxy eddig nem
            // küldött nyelvet, ezért az alapérték (`hu`) ugyanazt adja, mint
            // eddig — de ha küld, a nyilvános mezők (összefoglaló, típus-név,
            // kérdések) is a kért nyelven jönnek. A `correct` index itt MARAD
            // (ez a megbízható szerver-oldali útvonal).
            $lang = huhs_request_lang($request);
            return rest_ensure_response(array_merge(huhs_game_public_payload($game, $lang), array('questions' => huhs_translation_game_questions($game->ID, $lang), 'timeline_items' => huhs_game_timeline_items($game->ID), 'media' => huhs_game_media_json($game->ID))));
        },
    ));

    register_rest_route('huhs/v1', '/games/(?P<id>\d+)/validate-timeline', array(
        'methods' => WP_REST_Server::CREATABLE,
        'permission_callback' => function () { return current_user_can('edit_posts'); },
        'callback' => function ($request) {
            $game_id = absint($request['id']);
            $game = get_post($game_id);
            if (!$game || $game->post_type !== 'huhs_game') return new WP_Error('not_found', 'A játék nem található.', array('status' => 404));
            return rest_ensure_response(array('correct' => huhs_game_timeline_order_is_correct($game_id, $request->get_param('ordered_ids'))));
        },
    ));

    register_rest_route('huhs/v1', '/games/(?P<id>\d+)/clip-token', array(
        'methods' => WP_REST_Server::CREATABLE,
        'permission_callback' => function () { return current_user_can('edit_posts'); },
        'callback' => 'huhs_game_create_clip_token',
    ));

    register_rest_route('huhs/v1', '/games/(?P<id>\d+)/stats', array(
        'methods' => WP_REST_Server::CREATABLE,
        'permission_callback' => function () { return current_user_can('edit_posts'); },
        'callback' => function ($request) {
            $game_id = absint($request['id']);
            $game = get_post($game_id);
            if (!$game || $game->post_type !== 'huhs_game') return new WP_Error('not_found', 'A játék nem található.', array('status' => 404));
            $submissions = max(0, (int) $request->get_param('submissions'));
            $correct_answers = max(0, (int) $request->get_param('correct_answers'));
            $total_answers = max($correct_answers, (int) $request->get_param('total_answers'));
            $updated_at = current_time('mysql', true);
            update_post_meta($game_id, '_huhs_game_stats', array(
                'submissions' => $submissions,
                'correct_answers' => $correct_answers,
                'total_answers' => $total_answers,
                'updated_at' => $updated_at,
            ));
            return rest_ensure_response(array('ok' => true));
        },
    ));
});
