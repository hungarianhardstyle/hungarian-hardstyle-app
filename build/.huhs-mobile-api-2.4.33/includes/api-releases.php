<?php

if (!defined('ABSPATH')) exit;

add_action('rest_api_init', function () {
    register_rest_route('huhs/v1', '/releases', array('methods' => 'GET', 'callback' => 'huhs_get_releases', 'permission_callback' => '__return_true'));
});

function huhs_get_releases(WP_REST_Request $request)
{
    $search = sanitize_text_field((string) $request->get_param('search'));
    $artist_id = absint($request->get_param('artist'));
    $query = new WP_Query(array('post_type' => 'huhs_release', 'post_status' => 'publish', 'posts_per_page' => 100, 'orderby' => 'date', 'order' => 'DESC', 's' => $search, 'meta_query' => array(array('key' => 'visible', 'value' => '1', 'compare' => '='))));
    $items = array();
    foreach ($query->posts as $post) {
        $release = huhs_build_release_response($post);
        if ($artist_id && !in_array($artist_id, array_column($release['artists'], 'id'), true)) continue;
        $items[] = $release;
    }
    return rest_ensure_response(array('items' => $items));
}

function huhs_build_release_response($post)
{
    $id = (int) $post->ID;
    $artist_ids = json_decode((string) get_post_meta($id, 'artists', true), true);
    $artists = array();
    foreach ((array) $artist_ids as $artist_id) {
        $artist = get_post(absint($artist_id));
        if ($artist && $artist->post_type === 'huhs_artist') $artists[] = array('id' => (int) $artist->ID, 'name' => huhs_clean_title($artist->post_title));
    }
    $preview = esc_url_raw(get_post_meta($id, 'preview_url', true));
    $tracks = $preview ? array(array('title' => huhs_clean_title($post->post_title), 'preview_url' => $preview)) : array();
    $cover_id = absint(get_post_meta($id, 'cover', true));
    $links = array();
    foreach (array('spotify', 'apple_music', 'beatport', 'hardstyle_com', 'youtube') as $key) {
        $value = esc_url_raw(get_post_meta($id, $key, true));
        if ($value !== '') $links[$key] = $value;
    }
    return array('id' => $id, 'title' => huhs_clean_title($post->post_title), 'cover' => $cover_id ? wp_get_attachment_image_url($cover_id, 'large') : '', 'genre' => sanitize_text_field(get_post_meta($id, 'genre', true)), 'artists' => $artists, 'tracks' => $tracks, 'links' => $links);
}
