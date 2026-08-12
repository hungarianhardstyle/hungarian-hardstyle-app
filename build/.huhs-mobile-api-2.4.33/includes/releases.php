<?php

if (!defined('ABSPATH')) exit;

add_action('init', function () {
    register_post_type('huhs_release', array(
        'labels' => array('name' => 'Release-ek', 'singular_name' => 'Release', 'add_new_item' => 'Új release hozzáadása', 'edit_item' => 'Release szerkesztése'),
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
    huhs_image_field($post, 'cover', 'Borító');
    huhs_artists_field($post, 'artists', 'Előadók');
    huhs_text_field($post, 'genre', 'Műfaj');
    foreach (array('spotify' => 'Spotify link', 'apple_music' => 'Apple Music link', 'beatport' => 'Beatport link', 'hardstyle_com' => 'Hardstyle.com link', 'youtube' => 'YouTube link') as $key => $label) huhs_text_field($post, $key, $label);
    huhs_audio_url_field($post, 'audio_url', 'MP3 vagy WAV feltöltése – csak a 60 mp-es preview elkészítéséhez');
    huhs_text_field($post, 'wav_product_id', 'Google Play WAV/lossless product ID');
    huhs_text_field($post, 'wav_price', 'WAV/lossless price');
    huhs_text_field($post, 'mp3_product_id', 'Google Play 320 kbps MP3 product ID');
    huhs_text_field($post, 'mp3_price', '320 kbps MP3 price');
    huhs_audio_url_field($post, 'radio_audio_url', 'Radio version source');
    huhs_audio_url_field($post, 'extended_audio_url', 'Extended version source');
    $preview_url = esc_url(get_post_meta($post->ID, 'preview_url', true));
    if ($preview_url) echo '<p><strong>Elkészült preview:</strong> <a href="' . $preview_url . '" target="_blank" rel="noopener">Lejátszás</a></p>';
    echo '<p><em>A feltöltött teljes MP3/WAV a preview elkészülése után automatikusan törlődik.</em></p>';
    huhs_checkbox_field($post, 'visible', 'Publikálás az alkalmazásban');
}

function huhs_audio_url_field($post, $key, $label)
{
    $value = get_post_meta($post->ID, $key, true);
    echo '<p><label for="' . esc_attr($key) . '"><strong>' . esc_html($label) . '</strong></label></p>';
    echo '<input class="widefat" type="url" id="' . esc_attr($key) . '" name="' . esc_attr($key) . '" value="' . esc_attr($value) . '">';
    echo '<p><button type="button" class="button huhs-image-upload" data-target="' . esc_attr($key) . '" data-value="url">MP3 kiválasztása</button></p>';
}

add_action('save_post_huhs_release', function ($post_id) {
    if (!isset($_POST['huhs_release_nonce']) || !wp_verify_nonce($_POST['huhs_release_nonce'], 'huhs_release_save')) return;
    if (defined('DOING_AUTOSAVE') && DOING_AUTOSAVE) return;
    if (!current_user_can('edit_post', $post_id)) return;
    update_post_meta($post_id, 'cover', absint($_POST['cover'] ?? 0));
    update_post_meta($post_id, 'artists', wp_json_encode(array_map('absint', (array) ($_POST['artists'] ?? array()))));
    update_post_meta($post_id, 'genre', sanitize_text_field(wp_unslash($_POST['genre'] ?? '')));
    $new_audio_url = esc_url_raw(wp_unslash($_POST['audio_url'] ?? ''));
    $current_preview = esc_url_raw(get_post_meta($post_id, 'preview_url', true));
    if ($new_audio_url !== '' && $new_audio_url === $current_preview) $new_audio_url = '';
    if ($new_audio_url !== '') {
        $old_preview = esc_url_raw(get_post_meta($post_id, 'preview_url', true));
        $old_preview_id = $old_preview ? attachment_url_to_postid($old_preview) : 0;
        if ($old_preview_id) wp_delete_attachment($old_preview_id, true);
        delete_post_meta($post_id, 'preview_url');
    }
    update_post_meta($post_id, 'audio_url', $new_audio_url);
    update_post_meta($post_id, 'wav_product_id', sanitize_text_field(wp_unslash($_POST['wav_product_id'] ?? '')));
    update_post_meta($post_id, 'wav_price', sanitize_text_field(wp_unslash($_POST['wav_price'] ?? '')));
    update_post_meta($post_id, 'mp3_product_id', sanitize_text_field(wp_unslash($_POST['mp3_product_id'] ?? '')));
    update_post_meta($post_id, 'mp3_price', sanitize_text_field(wp_unslash($_POST['mp3_price'] ?? '')));
    update_post_meta($post_id, 'radio_audio_url', esc_url_raw(wp_unslash($_POST['radio_audio_url'] ?? '')));
    update_post_meta($post_id, 'extended_audio_url', esc_url_raw(wp_unslash($_POST['extended_audio_url'] ?? '')));
    foreach (array('spotify', 'apple_music', 'beatport', 'hardstyle_com', 'youtube') as $key) update_post_meta($post_id, $key, esc_url_raw(wp_unslash($_POST[$key] ?? '')));
    update_post_meta($post_id, 'visible', isset($_POST['visible']) ? 1 : 0);
    huhs_release_generate_preview($post_id);
});

function huhs_release_generate_preview($post_id)
{
    $audio_url = esc_url_raw(get_post_meta($post_id, 'audio_url', true));
    if ($audio_url === '' || get_post_meta($post_id, 'preview_url', true) !== '' || !function_exists('shell_exec')) return;
    $attachment_id = attachment_url_to_postid($audio_url);
    $source = $attachment_id ? get_attached_file($attachment_id) : '';
    $ffmpeg = trim((string) shell_exec('command -v ffmpeg 2>/dev/null'));
    if (!$source || !is_file($source) || $ffmpeg === '') return;
    $upload = wp_upload_dir();
    $filename = wp_unique_filename($upload['path'], 'huhs-release-' . $post_id . '-preview-' . time() . '.mp3');
    $target = trailingslashit($upload['path']) . $filename;
    shell_exec(escapeshellarg($ffmpeg) . ' -y -ss 30 -i ' . escapeshellarg($source) . ' -t 60 -vn -codec:a libmp3lame ' . escapeshellarg($target) . ' 2>/dev/null');
    if (!is_file($target)) return;
    $attachment = wp_insert_attachment(array('post_mime_type' => 'audio/mpeg', 'post_title' => 'Release preview ' . $post_id, 'post_status' => 'inherit'), $target, $post_id);
    if (!is_wp_error($attachment)) {
        $preview_url = wp_get_attachment_url($attachment);
        update_post_meta($post_id, 'preview_url', $preview_url ?: trailingslashit($upload['url']) . $filename);
        if ($attachment_id && $attachment_id !== (int) $attachment) wp_delete_attachment($attachment_id, true);
        delete_post_meta($post_id, 'audio_url');
    }
}
