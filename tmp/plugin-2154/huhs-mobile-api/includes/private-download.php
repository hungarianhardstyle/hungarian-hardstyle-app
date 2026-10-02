<?php

if (!defined('ABSPATH')) exit;

function huhs_release_private_dir()
{
    $upload = wp_upload_dir();
    $directory = trailingslashit($upload['basedir']) . 'huhs-private-releases';
    if (!is_dir($directory)) wp_mkdir_p($directory);
    $htaccess = trailingslashit($directory) . '.htaccess';
    if (!is_file($htaccess)) {
        // Apache 2.4 first, Apache 2.2 fallback. Note: this only protects
        // Apache; an nginx/OpenResty host must block this directory in the
        // server config (e.g. `location ~* /huhs-private-releases/ { deny all; }`).
        file_put_contents(
            $htaccess,
            "<IfModule mod_authz_core.c>\nRequire all denied\n</IfModule>\n<IfModule !mod_authz_core.c>\nDeny from all\n</IfModule>\n"
        );
    }
    return $directory;
}

function huhs_release_private_variant($release_id, $variant)
{
    $allowed = array('free_wav', 'wav', 'mp3_320', 'mp3_96', 'mp3_128', 'radio_wav', 'radio_mp3_320', 'extended_wav', 'extended_mp3_320');
    if (!in_array($variant, $allowed, true)) return '';
    if ($variant === 'free_wav' && !get_post_meta($release_id, 'is_free', true)) return '';
    $lookup_variant = $variant === 'free_wav' ? 'wav' : $variant;
    $meta_key = in_array($lookup_variant, array('radio_wav', 'radio_mp3_320', 'extended_wav', 'extended_mp3_320'), true)
        ? 'private_' . str_replace(array('_wav', '_mp3_320'), array('_wav_path', '_mp3_320_path'), $lookup_variant)
        : 'private_' . $lookup_variant . '_path';
    $path = get_post_meta($release_id, $meta_key, true);
    if ($variant === 'mp3_96' && (!is_string($path) || !is_file($path))) {
        $path = huhs_release_ensure_mp3_96($release_id);
    }
    if ($variant === 'free_wav') {
        $path = get_post_meta($release_id, 'private_free_wav_path', true)
            ?: get_post_meta($release_id, 'private_wav_path', true)
            ?: get_post_meta($release_id, 'private_radio_wav_path', true);
    } elseif ($lookup_variant === 'wav') {
        $path = get_post_meta($release_id, 'private_wav_path', true) ?: get_post_meta($release_id, 'private_radio_wav_path', true);
    }
    if ($variant === 'mp3_320') $path = get_post_meta($release_id, 'private_mp3_320_path', true) ?: get_post_meta($release_id, 'private_radio_mp3_320_path', true);
    return is_string($path) && is_file($path) ? $path : '';
}

/**
 * Backfill the 96 kbps reward file from the already processed 128 kbps file.
 * Existing releases therefore do not need to be uploaded again.
 */
function huhs_release_ensure_mp3_96($release_id)
{
    $existing = get_post_meta($release_id, 'private_mp3_96_path', true);
    if (is_string($existing) && is_file($existing)) return $existing;
    $source = get_post_meta($release_id, 'private_mp3_128_path', true);
    if (!is_string($source) || !is_file($source) || !function_exists('shell_exec')) return '';
    $ffmpeg = trim((string) shell_exec('command -v ffmpeg 2>/dev/null'));
    if ($ffmpeg === '') return '';
    $lock_key = 'huhs_mp3_96_backfill_' . absint($release_id);
    if (get_transient($lock_key)) return '';
    set_transient($lock_key, 1, 5 * MINUTE_IN_SECONDS);
    $target = trailingslashit(dirname($source)) . 'release-' . absint($release_id) . '-96.mp3';
    shell_exec(escapeshellarg($ffmpeg) . ' -y -i ' . escapeshellarg($source) . ' -vn -codec:a libmp3lame -b:a 96k ' . escapeshellarg($target) . ' 2>/dev/null');
    delete_transient($lock_key);
    if (!is_file($target)) return '';
    update_post_meta($release_id, 'private_mp3_96_path', $target);
    return $target;
}

function huhs_release_download_filename($release_id, $variant, $path)
{
    $variant_labels = array(
        'free_wav' => 'Free-WAV',
        'wav' => 'WAV',
        'mp3_320' => 'MP3-320kbps',
        'mp3_96' => 'MP3-96kbps',
        'mp3_128' => 'MP3-128kbps',
        'radio_wav' => 'Radio-WAV',
        'radio_mp3_320' => 'Radio-MP3-320kbps',
        'extended_wav' => 'Extended-WAV',
        'extended_mp3_320' => 'Extended-MP3-320kbps',
    );
    $title = sanitize_file_name(remove_accents(wp_strip_all_tags(get_the_title($release_id))));
    if ($title === '') $title = 'huhs-release-' . absint($release_id);
    $label = isset($variant_labels[$variant]) ? $variant_labels[$variant] : sanitize_file_name($variant);
    $extension = str_ends_with(strtolower($path), '.wav') ? 'wav' : 'mp3';
    return $title . '-' . $label . '.' . $extension;
}

add_action('rest_api_init', function () {
    register_rest_route('huhs/v1', '/private-download-token', array(
        'methods' => 'POST',
        'callback' => 'huhs_release_create_download_token',
        'permission_callback' => function () { return current_user_can('manage_options'); },
    ));
});

function huhs_release_create_download_token(WP_REST_Request $request)
{
    $release_id = absint($request->get_param('releaseId'));
    $variant = sanitize_key((string) $request->get_param('variant'));
    if (!$release_id) return new WP_Error('not_found', 'A kért fájl nem érhető el.', array('status' => 404));

    // Release-date gate. This is the authoritative check for every private file
    // (paid WAV / 320 kbps, the rewarded-ad 96 kbps and the free WAV), because
    // the release date and the site timezone live here. Gating in this single
    // place also protects clients that are already installed and do not know
    // about the schedule yet.
    //
    // The 60-second preview is deliberately not affected: it is a separate
    // public attachment, so a fan can listen before the release date while the
    // paid and rewarded downloads stay closed.
    $release_date = sanitize_text_field((string) get_post_meta($release_id, 'release_date', true));
    if ($release_date === '') $release_date = get_the_date('Y-m-d', $release_id);
    if (huhs_release_is_upcoming($release_date)) {
        return new WP_Error(
            'release_not_available_yet',
            'Ez a kiadvány a megjelenési napján válik elérhetővé. Addig a 60 másodperces előzetes hallgatható.',
            array('status' => 403)
        );
    }

    $path = huhs_release_private_variant($release_id, $variant);
    if (!$path) return new WP_Error('not_found', 'A kért fájl nem érhető el.', array('status' => 404));
    $token = wp_generate_password(48, false, false);
    set_transient('huhs_private_download_' . hash('sha256', $token), array('path' => $path, 'release_id' => $release_id, 'variant' => $variant), 300);
    return rest_ensure_response(array(
        'download_url' => add_query_arg(array('huhs_download' => '1', 'token' => $token), home_url('/')),
        'expires_in' => 300,
    ));
}

add_action('template_redirect', function () {
    if (empty($_GET['huhs_download']) || empty($_GET['token'])) return;
    $token = sanitize_text_field(wp_unslash($_GET['token']));
    $key = 'huhs_private_download_' . hash('sha256', $token);
    $download = get_transient($key);
    delete_transient($key);
    if (!is_array($download) || empty($download['path']) || !is_file($download['path'])) {
        status_header(404);
        exit;
    }
    $path = $download['path'];
    $filename = huhs_release_download_filename($download['release_id'], $download['variant'], $path);
    nocache_headers();
    header('Content-Type: ' . (str_ends_with(strtolower($path), '.wav') ? 'audio/wav' : 'audio/mpeg'));
    header('Content-Length: ' . filesize($path));
    header('Content-Disposition: attachment; filename="' . $filename . '"');
    readfile($path);
    exit;
});
