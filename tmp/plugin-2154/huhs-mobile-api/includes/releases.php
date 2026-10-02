<?php

if (!defined('ABSPATH')) exit;

add_action('init', function () {
    register_post_type('huhs_release', array(
        'labels' => array('name' => 'Release-ek', 'singular_name' => 'Release', 'add_new_item' => 'Uj release hozzaadasa', 'edit_item' => 'Release szerkesztese'),
        'public' => true,
        'show_ui' => true,
        'show_in_menu' => false,
        'show_in_rest' => true,
        'supports' => array('title'),
        'rewrite' => array('slug' => 'releases', 'with_front' => false),
    ));
});

add_action('add_meta_boxes', function () {
    add_meta_box('huhs_release_details', 'Release adatai', 'huhs_release_meta_box', 'huhs_release', 'normal', 'high');
});

function huhs_release_meta_box($post)
{
    wp_nonce_field('huhs_release_save', 'huhs_release_nonce');
    huhs_image_field($post, 'cover', 'Borito');
    huhs_artists_field($post, 'artists', 'Eloadok');
    huhs_text_field($post, 'genre', 'Mufaj');
    $release_date = get_post_meta($post->ID, 'release_date', true);
    echo '<p><label for="release_date"><strong>Megjelenesi datum</strong></label></p>';
    echo '<input class="widefat" type="date" id="release_date" name="release_date" value="' . esc_attr($release_date) . '">';
    foreach (array('spotify' => 'Spotify link', 'apple_music' => 'Apple Music link', 'beatport' => 'Beatport link', 'hardstyle_com' => 'Hardstyle.com link', 'youtube' => 'YouTube link') as $key => $label) huhs_text_field($post, $key, $label);

    echo '<hr><h3>Radio verzio</h3>';
    huhs_audio_url_field($post, 'radio_audio_url', 'Radio verzio feltoltese');
    huhs_text_field($post, 'radio_wav_product_id', 'Radio WAV Google Play product ID');
    huhs_text_field($post, 'radio_wav_price', 'Radio WAV ar');
    huhs_text_field($post, 'radio_mp3_product_id', 'Radio 320 kbps MP3 Google Play product ID');
    huhs_text_field($post, 'radio_mp3_price', 'Radio 320 kbps MP3 ar');
    echo '<p><em>A Radio verziobol keszul a 60 masodperces preview. A forrasbol FFmpeg keszit privat, megvasarolhato WAV- es 320 kbps MP3-fajlt.</em></p>';

    echo '<hr><h3>Ingyenes kiadvány</h3>';
    huhs_checkbox_field($post, 'is_free', 'Ingyenes kiadvány (reklám megtekintése után tölthető le)');
    huhs_audio_url_field($post, 'free_audio_url', 'Ingyenes MP3/WAV feltöltése');
    huhs_text_field($post, 'free_external_link', 'Ingyenes külső link (pl. Hypeddit)');
    echo '<p><em>Az ingyenes kiadvány reklámos letöltése WAV marad. Ha nincs külön ingyenes forrás, a Radio verzió használható.</em></p>';

    echo '<hr><h3>Extended verzio</h3>';
    huhs_audio_url_field($post, 'extended_audio_url', 'Extended verzio feltoltese');
    huhs_text_field($post, 'extended_wav_product_id', 'Extended WAV Google Play product ID');
    huhs_text_field($post, 'extended_wav_price', 'Extended WAV ar');
    huhs_text_field($post, 'extended_mp3_product_id', 'Extended 320 kbps MP3 Google Play product ID');
    huhs_text_field($post, 'extended_mp3_price', 'Extended 320 kbps MP3 ar');
    echo '<p><em>Mindket verzio teljes forrasa feldolgozas utan torlodik. A megvasarolhato WAV es 320 kbps MP3 fajlok nem jelennek meg a nyilvanos API-ban.</em></p>';

    if (function_exists('huhs_queue_label_product_sync')) {
        echo '<hr><p><strong>Play-termekek</strong></p>';
        echo '<p>A gomb csak ezt a release-t kuldi ujra Play-termek szinkronra. A product ID-k sikeres szinkron utan automatikusan visszairodnak.</p>';
        echo '<input type="hidden" name="huhs_retry_action" value="huhs_retry_play_products">';
        echo '<input type="hidden" name="huhs_retry_release_id" value="' . absint($post->ID) . '">';
        wp_nonce_field('huhs_retry_play_products_' . $post->ID, 'huhs_retry_play_products_nonce');
        echo '<button type="submit" class="button button-primary" formaction="' . esc_url(admin_url('admin-post.php')) . '" formmethod="post" name="action" value="huhs_retry_play_products" formnovalidate>Play-termekek letrehozasa / ujraprobalasa</button>';
    }

    $preview_url = esc_url(get_post_meta($post->ID, 'preview_url', true));
    if ($preview_url) echo '<p><strong>Elkeszult preview:</strong> <a href="' . $preview_url . '" target="_blank" rel="noopener">Lejatszas</a></p>';

    echo '<hr><h3>Megjelenes elotti elorendeles</h3>';
    huhs_text_field($post, 'presave_url', 'PRESAVE link', 'https://...');
    echo '<p><em>A PRESAVE link csak a megjelenesi datum ELOTT latszik az appban, utana automatikusan eltunik, es a megszokott hallgatasi linkek maradnak. A kiadvany a megjelenesi napjan 00:00-kor valik megvasarolhatova es letolthetove; a 60 masodperces preview addig is hallgathato.</em></p>';

    huhs_checkbox_field($post, 'visible', 'Publikalas az alkalmazasban');
}

add_action('admin_post_huhs_retry_play_products', function () {
    $post_id = absint($_POST['huhs_retry_release_id'] ?? 0);
    if (!$post_id || get_post_type($post_id) !== 'huhs_release') wp_die('Ervenytelen release.');
    check_admin_referer('huhs_retry_play_products_' . $post_id, 'huhs_retry_play_products_nonce');
    if (!current_user_can('edit_post', $post_id)) wp_die('Nincs jogosultsagod ehhez a release-hez.');

    $queued = function_exists('huhs_queue_label_product_sync')
        ? huhs_queue_label_product_sync($post_id)
        : false;
    $redirect = add_query_arg(
        array('post' => $post_id, 'action' => 'edit', 'huhs_play_sync' => $queued ? 'queued' : 'failed'),
        admin_url('post.php')
    );
    wp_safe_redirect($redirect);
    exit;
});

add_action('admin_notices', function () {
    if (($_GET['huhs_play_sync'] ?? '') === 'queued') {
        echo '<div class="notice notice-success is-dismissible"><p>A release Play-termek szinkronja elindult.</p></div>';
    } elseif (($_GET['huhs_play_sync'] ?? '') === 'failed') {
        echo '<div class="notice notice-error is-dismissible"><p>A Play-termek szinkron inditasa nem sikerult. Ellenorizd a Firebase-kapcsolatot.</p></div>';
    }
});

function huhs_audio_url_field($post, $key, $label)
{
    $value = get_post_meta($post->ID, $key, true);
    echo '<p><label for="' . esc_attr($key) . '"><strong>' . esc_html($label) . '</strong></label></p>';
    echo '<input class="widefat" type="url" id="' . esc_attr($key) . '" name="' . esc_attr($key) . '" value="' . esc_attr($value) . '">';
    echo '<p><button type="button" class="button huhs-image-upload" data-target="' . esc_attr($key) . '" data-value="url">WAV/MP3 kivalasztasa</button></p>';
}

add_action('save_post_huhs_release', function ($post_id) {
    if (!isset($_POST['huhs_release_nonce']) || !wp_verify_nonce($_POST['huhs_release_nonce'], 'huhs_release_save')) return;
    if (defined('DOING_AUTOSAVE') && DOING_AUTOSAVE) return;
    if (!current_user_can('edit_post', $post_id)) return;
    update_post_meta($post_id, 'cover', absint($_POST['cover'] ?? 0));
    update_post_meta($post_id, 'artists', wp_json_encode(array_map('absint', (array) ($_POST['artists'] ?? array()))));
    update_post_meta($post_id, 'genre', sanitize_text_field(wp_unslash($_POST['genre'] ?? '')));
    $release_date = sanitize_text_field(wp_unslash($_POST['release_date'] ?? ''));
    if ($release_date !== '' && !preg_match('/^\d{4}-\d{2}-\d{2}$/', $release_date)) $release_date = '';
    update_post_meta($post_id, 'release_date', $release_date);

    $new_radio_url = esc_url_raw(wp_unslash($_POST['radio_audio_url'] ?? ''));
    $new_extended_url = esc_url_raw(wp_unslash($_POST['extended_audio_url'] ?? ''));
    $new_free_url = esc_url_raw(wp_unslash($_POST['free_audio_url'] ?? ''));
    $old_radio_url = esc_url_raw(get_post_meta($post_id, 'radio_audio_url', true));
    $old_extended_url = esc_url_raw(get_post_meta($post_id, 'extended_audio_url', true));
    $old_free_url = esc_url_raw(get_post_meta($post_id, 'free_audio_url', true));
    $audio_changed = $new_radio_url !== $old_radio_url || $new_extended_url !== $old_extended_url || $new_free_url !== $old_free_url;
    if ($audio_changed) {
        $old_preview = esc_url_raw(get_post_meta($post_id, 'preview_url', true));
        $old_preview_id = $old_preview ? attachment_url_to_postid($old_preview) : 0;
        if ($old_preview_id) wp_delete_attachment($old_preview_id, true);
        delete_post_meta($post_id, 'preview_url');
        delete_post_meta($post_id, 'audio_processing_status');
    }
    update_post_meta($post_id, 'radio_audio_url', $new_radio_url);
    update_post_meta($post_id, 'extended_audio_url', $new_extended_url);
    update_post_meta($post_id, 'free_audio_url', $new_free_url);
    foreach (array('radio' => $new_radio_url, 'extended' => $new_extended_url, 'free' => $new_free_url) as $source_type => $source_url) {
        $attachment_id = $source_url ? attachment_url_to_postid($source_url) : 0;
        update_post_meta($post_id, 'huhs_' . $source_type . '_audio_attachment_id', $attachment_id);
    }
    update_post_meta($post_id, 'is_free', isset($_POST['is_free']) ? 1 : 0);
    update_post_meta($post_id, 'free_external_link', esc_url_raw(wp_unslash($_POST['free_external_link'] ?? '')));
    foreach (array('radio_wav_product_id', 'radio_wav_price', 'radio_mp3_product_id', 'radio_mp3_price', 'extended_wav_product_id', 'extended_wav_price', 'extended_mp3_product_id', 'extended_mp3_price') as $key) {
        update_post_meta($post_id, $key, sanitize_text_field(wp_unslash($_POST[$key] ?? '')));
    }
    foreach (array('spotify', 'apple_music', 'beatport', 'hardstyle_com', 'youtube') as $key) update_post_meta($post_id, $key, esc_url_raw(wp_unslash($_POST[$key] ?? '')));
    update_post_meta($post_id, 'presave_url', esc_url_raw(wp_unslash($_POST['presave_url'] ?? '')));
    update_post_meta($post_id, 'visible', isset($_POST['visible']) ? 1 : 0);
    $processing_status = get_post_meta($post_id, 'audio_processing_status', true);
    if ($audio_changed || $processing_status === 'failed') {
        huhs_release_generate_preview($post_id);
    } elseif ($processing_status === 'ready' && function_exists('huhs_schedule_label_product_sync')) {
        huhs_schedule_label_product_sync($post_id);
    }
});

function huhs_release_generate_preview($post_id)
{
    $radio_url = esc_url_raw(get_post_meta($post_id, 'radio_audio_url', true));
    $extended_url = esc_url_raw(get_post_meta($post_id, 'extended_audio_url', true));
    $free_url = esc_url_raw(get_post_meta($post_id, 'free_audio_url', true));
    if ($radio_url === '') $radio_url = $free_url;
    if ($radio_url === '' && $extended_url === '') $radio_url = esc_url_raw(get_post_meta($post_id, 'audio_url', true));
    if (($radio_url === '' && $extended_url === '') || !function_exists('shell_exec')) return;
    update_post_meta($post_id, 'audio_processing_status', 'queued');
    if (!wp_next_scheduled('huhs_release_process_audio', array((int) $post_id))) wp_schedule_single_event(time() + 5, 'huhs_release_process_audio', array((int) $post_id));
}

add_action('huhs_release_process_audio', 'huhs_release_process_audio');

function huhs_release_process_audio($post_id)
{
    $lock_key = 'huhs_audio_processing_' . absint($post_id);
    if (get_transient($lock_key)) return;
    set_transient($lock_key, 1, 15 * MINUTE_IN_SECONDS);
    try {
    $radio_url = esc_url_raw(get_post_meta($post_id, 'radio_audio_url', true));
    $extended_url = esc_url_raw(get_post_meta($post_id, 'extended_audio_url', true));
    $free_url = esc_url_raw(get_post_meta($post_id, 'free_audio_url', true));
    if ($radio_url === '') $radio_url = $free_url;
    if ($radio_url === '' && $extended_url === '') $radio_url = esc_url_raw(get_post_meta($post_id, 'audio_url', true));
    if (($radio_url === '' && $extended_url === '') || !function_exists('shell_exec')) {
        update_post_meta($post_id, 'audio_processing_status', 'failed');
        update_post_meta($post_id, 'audio_processing_error', 'missing-source-or-shell-exec');
        return;
    }
    if (get_post_meta($post_id, 'audio_processing_status', true) === 'ready') return;
    $sources = array();
    foreach (array('radio' => $radio_url, 'extended' => $extended_url) as $variant => $url) {
        $attachment_id = absint(get_post_meta($post_id, 'huhs_' . $variant . '_audio_attachment_id', true));
        if (!$attachment_id && $url) $attachment_id = attachment_url_to_postid($url);
        $source = $attachment_id ? get_attached_file($attachment_id) : '';
        if ($source && is_file($source)) $sources[$variant] = array('id' => $attachment_id, 'path' => $source);
    }
    if (!$sources) {
        update_post_meta($post_id, 'audio_processing_status', 'failed');
        update_post_meta($post_id, 'audio_processing_error', 'source-attachment-not-found');
        return;
    }
    $ffmpeg = trim((string) shell_exec('command -v ffmpeg 2>/dev/null'));
    if ($ffmpeg === '') {
        update_post_meta($post_id, 'audio_processing_status', 'failed');
        update_post_meta($post_id, 'audio_processing_error', 'ffmpeg-not-found');
        return;
    }
    $upload = wp_upload_dir();
    $private_dir = function_exists('huhs_release_private_dir') ? huhs_release_private_dir() : '';
    if ($private_dir === '') {
        update_post_meta($post_id, 'audio_processing_status', 'failed');
        update_post_meta($post_id, 'audio_processing_error', 'private-directory-unavailable');
        return;
    }
    if ($private_dir !== '') {
        foreach (array('wav', 'mp3_320', 'mp3_96', 'mp3_128', 'radio_wav', 'radio_mp3_320', 'extended_wav', 'extended_mp3_320', 'radio', 'extended') as $variant) {
            $old = get_post_meta($post_id, 'private_' . $variant . '_path', true);
            if (is_string($old) && is_file($old)) unlink($old);
            delete_post_meta($post_id, 'private_' . $variant . '_path');
        }
        foreach ($sources as $variant => $source_data) {
            $source = $source_data['path'];
            $wav_path = trailingslashit($private_dir) . 'release-' . (int) $post_id . '-' . $variant . '.wav';
            $mp3_path = trailingslashit($private_dir) . 'release-' . (int) $post_id . '-' . $variant . '-320.mp3';
            shell_exec(escapeshellarg($ffmpeg) . ' -y -i ' . escapeshellarg($source) . ' -vn -c:a pcm_s16le ' . escapeshellarg($wav_path) . ' 2>/dev/null');
            shell_exec(escapeshellarg($ffmpeg) . ' -y -i ' . escapeshellarg($source) . ' -vn -codec:a libmp3lame -b:a 320k ' . escapeshellarg($mp3_path) . ' 2>/dev/null');
            if (!is_file($wav_path) || !is_file($mp3_path)) {
                update_post_meta($post_id, 'audio_processing_status', 'failed');
                update_post_meta($post_id, 'audio_processing_error', 'ffmpeg-conversion-failed-' . $variant);
                return;
            }
            update_post_meta($post_id, 'private_' . $variant . '_wav_path', $wav_path);
            update_post_meta($post_id, 'private_' . $variant . '_mp3_320_path', $mp3_path);
            if ($variant === 'radio') {
                $mp3_128 = trailingslashit($private_dir) . 'release-' . (int) $post_id . '-128.mp3';
                shell_exec(escapeshellarg($ffmpeg) . ' -y -i ' . escapeshellarg($source) . ' -vn -codec:a libmp3lame -b:a 128k ' . escapeshellarg($mp3_128) . ' 2>/dev/null');
                if (!is_file($mp3_128)) {
                    update_post_meta($post_id, 'audio_processing_status', 'failed');
                    update_post_meta($post_id, 'audio_processing_error', 'ffmpeg-conversion-failed-mp3-128');
                    return;
                }
                update_post_meta($post_id, 'private_mp3_128_path', $mp3_128);
                $mp3_96 = trailingslashit($private_dir) . 'release-' . (int) $post_id . '-96.mp3';
                shell_exec(escapeshellarg($ffmpeg) . ' -y -i ' . escapeshellarg($source) . ' -vn -codec:a libmp3lame -b:a 96k ' . escapeshellarg($mp3_96) . ' 2>/dev/null');
                if (!is_file($mp3_96)) {
                    update_post_meta($post_id, 'audio_processing_status', 'failed');
                    update_post_meta($post_id, 'audio_processing_error', 'ffmpeg-conversion-failed-mp3-96');
                    return;
                }
                update_post_meta($post_id, 'private_mp3_96_path', $mp3_96);
            }
        }
    }
    if (empty($sources['radio'])) {
        foreach ($sources as $source_data) wp_delete_attachment($source_data['id'], true);
        update_post_meta($post_id, 'audio_processing_status', 'ready');
        delete_post_meta($post_id, 'audio_processing_error');
        if (function_exists('huhs_queue_label_product_sync')) huhs_queue_label_product_sync($post_id);
        return;
    }
    $filename = wp_unique_filename($upload['path'], 'huhs-release-' . $post_id . '-preview-' . time() . '.mp3');
    $target = trailingslashit($upload['path']) . $filename;
    shell_exec(escapeshellarg($ffmpeg) . ' -y -ss 30 -i ' . escapeshellarg($sources['radio']['path']) . ' -t 60 -vn -codec:a libmp3lame ' . escapeshellarg($target) . ' 2>/dev/null');
    if (!is_file($target)) {
        update_post_meta($post_id, 'audio_processing_status', 'failed');
        update_post_meta($post_id, 'audio_processing_error', 'preview-generation-failed');
        return;
    }
    $attachment = wp_insert_attachment(array('post_mime_type' => 'audio/mpeg', 'post_title' => 'Release preview ' . $post_id, 'post_status' => 'inherit'), $target, $post_id);
    if (!is_wp_error($attachment)) {
        $preview_url = wp_get_attachment_url($attachment);
        update_post_meta($post_id, 'preview_url', $preview_url ?: trailingslashit($upload['url']) . $filename);
        delete_post_meta($post_id, 'audio_url');
        update_post_meta($post_id, 'audio_processing_status', 'ready');
        delete_post_meta($post_id, 'audio_processing_error');
        if (function_exists('huhs_queue_label_product_sync')) huhs_queue_label_product_sync($post_id);
    } else {
        update_post_meta($post_id, 'audio_processing_status', 'failed');
        update_post_meta($post_id, 'audio_processing_error', 'preview-attachment-failed');
        return;
    }
    foreach ($sources as $source_data) wp_delete_attachment($source_data['id'], true);
    } finally {
        delete_transient($lock_key);
    }
}
