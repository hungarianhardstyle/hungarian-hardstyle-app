<?php

if (!defined('ABSPATH')) exit;

function huhs_release_private_dir()
{
    $upload = wp_upload_dir();
    $directory = trailingslashit($upload['basedir']) . 'huhs-private-releases';
    if (!is_dir($directory)) wp_mkdir_p($directory);
    $htaccess = trailingslashit($directory) . '.htaccess';
    if (!is_file($htaccess)) file_put_contents($htaccess, "Deny from all\n");
    return $directory;
}

function huhs_release_private_variant($release_id, $variant)
{
    $allowed = array('wav', 'mp3_320', 'mp3_128', 'radio', 'extended');
    if (!in_array($variant, $allowed, true)) return '';
    $path = get_post_meta($release_id, 'private_' . $variant . '_path', true);
    return is_string($path) && is_file($path) ? $path : '';
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
    $path = huhs_release_private_variant($release_id, $variant);
    if (!$release_id || !$path) return new WP_Error('not_found', 'A kért fájl nem érhető el.', array('status' => 404));
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
    nocache_headers();
    header('Content-Type: ' . (str_ends_with(strtolower($path), '.wav') ? 'audio/wav' : 'audio/mpeg'));
    header('Content-Length: ' . filesize($path));
    header('Content-Disposition: attachment; filename="huhs-release-' . absint($download['release_id']) . '-' . sanitize_file_name($download['variant']) . '.' . (str_ends_with(strtolower($path), '.wav') ? 'wav' : 'mp3') . '"');
    readfile($path);
    exit;
});
