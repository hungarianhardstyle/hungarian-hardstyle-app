<?php

if (!defined('ABSPATH')) exit;

add_action('rest_api_init', function () {
    register_rest_route('huhs/v1', '/releases', array('methods' => 'GET', 'callback' => 'huhs_get_releases', 'permission_callback' => '__return_true'));
    register_rest_route('huhs/v1', '/releases/(?P<id>\d+)', array(
        'methods' => 'GET',
        'callback' => 'huhs_get_release_detail',
        'permission_callback' => '__return_true',
        'args' => array(
            'id' => array(
                'sanitize_callback' => 'absint',
                'validate_callback' => function ($value) { return absint($value) > 0; },
            ),
        ),
    ));
    register_rest_route('huhs/v1', '/releases/(?P<id>\d+)/play-products', array(
        'methods' => WP_REST_Server::CREATABLE,
        'callback' => 'huhs_update_release_play_products',
        'permission_callback' => function () {
            return current_user_can('manage_options');
        },
        'args' => array(
            'id' => array('sanitize_callback' => 'absint', 'validate_callback' => function ($value) { return absint($value) > 0; }),
            'products' => array('required' => true),
        ),
    ));
});

function huhs_get_release_detail(WP_REST_Request $request)
{
    $post = get_post(absint($request['id']));
    if (!$post || $post->post_type !== 'huhs_release' || $post->post_status !== 'publish' ||
        !get_post_meta($post->ID, 'visible', true)) {
        return new WP_Error('release_not_found', 'A kiadvány nem található.', array('status' => 404));
    }
    return rest_ensure_response(huhs_build_release_response($post, huhs_request_lang($request)));
}

function huhs_get_releases(WP_REST_Request $request)
{
    $search = sanitize_text_field((string) $request->get_param('search'));
    $artist_id = absint($request->get_param('artist'));
    $summary = filter_var($request->get_param('summary'), FILTER_VALIDATE_BOOLEAN);
    $lang = huhs_request_lang($request);
    $query = new WP_Query(array('post_type' => 'huhs_release', 'post_status' => 'publish', 'posts_per_page' => 100, 'orderby' => 'date', 'order' => 'DESC', 's' => $search, 'meta_query' => array(array('key' => 'visible', 'value' => '1', 'compare' => '='))));
    $items = array();
    foreach ($query->posts as $post) {
        $release = $summary ? huhs_build_release_summary($post, $lang) : huhs_build_release_response($post, $lang);
        if ($artist_id && !in_array($artist_id, array_column($release['artists'], 'id'), true)) continue;
        $items[] = $release;
    }
    return rest_ensure_response(array('items' => $items));
}

function huhs_build_release_summary($post, $lang = 'hu')
{
    // A kiadvány egyetlen szövege a **cím**, ami név (kiadvány/ szám címe) — azt
    // szándékosan nem fordítjuk, és a payloadban nincs leírás sem. A `$lang`
    // paraméter ezért csak a hívói felület egységessége miatt van itt.
    unset($lang);
    $id = (int) $post->ID;
    $cover_id = absint(get_post_meta($id, 'cover', true));
    $artist_ids = json_decode((string) get_post_meta($id, 'artists', true), true);
    $artists = array();
    foreach ((array) $artist_ids as $artist_id) {
        $artist = get_post(absint($artist_id));
        if ($artist && $artist->post_type === 'huhs_artist') $artists[] = array('id' => (int) $artist->ID, 'name' => huhs_clean_title($artist->post_title));
    }
    $release_date = sanitize_text_field((string) get_post_meta($id, 'release_date', true));
    if ($release_date === '') $release_date = get_the_date('Y-m-d', $post);
    $products = array();
    foreach (array(
        'radio_wav' => array('Radio WAV', 'radio_wav_product_id'),
        'radio_mp3_320' => array('Radio MP3 320 kbps', 'radio_mp3_product_id'),
        'extended_wav' => array('Extended WAV', 'extended_wav_product_id'),
        'extended_mp3_320' => array('Extended MP3 320 kbps', 'extended_mp3_product_id'),
    ) as $type => $definition) {
        $product_id = sanitize_text_field(get_post_meta($id, $definition[1], true));
        if ($product_id !== '') $products[] = array('id' => $product_id, 'type' => $type, 'label' => $definition[0]);
    }
    foreach (array('wav' => 'WAV / lossless', 'mp3_320' => 'MP3 320 kbps') as $key => $label) {
        $product_id = sanitize_text_field(get_post_meta($id, $key . '_product_id', true));
        if ($product_id !== '') $products[] = array('id' => $product_id, 'type' => $key, 'label' => $label);
    }
    return array(
        'id' => $id, 'title' => huhs_clean_title($post->post_title), 'release_date' => $release_date,
        // The release date gate is decided here, once, for both the list and the
        // detail payload: the app must not have to re-derive it from a date
        // string in its own timezone. `presave_url` is only exposed while the
        // release is upcoming, so an old link cannot resurface after launch.
        'is_upcoming' => huhs_release_is_upcoming($release_date),
        'presave_url' => huhs_release_is_upcoming($release_date) ? esc_url_raw(get_post_meta($id, 'presave_url', true)) : '',
        'is_free' => (bool) get_post_meta($id, 'is_free', true), 'free_external_link' => '',
        'cover' => $cover_id ? wp_get_attachment_image_url($cover_id, 'medium') : '',
        'genre' => sanitize_text_field(get_post_meta($id, 'genre', true)), 'artists' => $artists,
        // Product IDs are lightweight catalog keys needed for background
        // Billing warm-up; prices and full product details stay detail-only.
        'tracks' => array(), 'links' => array(), 'products' => $products, 'product_prices' => array(),
        'versions' => array(), 'audio_status' => sanitize_key(get_post_meta($id, 'audio_processing_status', true)),
    );
}

function huhs_build_release_response($post, $lang = 'hu')
{
    // A cím itt NÉV (kiadvány/szám címe) — nem fordítjuk; lásd a summary feletti
    // magyarázatot. A `$lang` csak a hívói felület egységessége miatt van itt.
    unset($lang);
    $id = (int) $post->ID;
    $artist_ids = json_decode((string) get_post_meta($id, 'artists', true), true);
    $artists = array();
    foreach ((array) $artist_ids as $artist_id) {
        $artist = get_post(absint($artist_id));
        if ($artist && $artist->post_type === 'huhs_artist') $artists[] = array('id' => (int) $artist->ID, 'name' => huhs_clean_title($artist->post_title));
    }
    $preview = esc_url_raw(get_post_meta($id, 'preview_url', true));
    $tracks = $preview ? array(array('title' => huhs_clean_title($post->post_title), 'preview_url' => $preview)) : array();
    $products = array();
    $product_prices = array();
    foreach (array(
        'radio_wav' => array('Radio WAV', 'radio_wav_product_id', 'radio_wav_price'),
        'radio_mp3_320' => array('Radio MP3 320 kbps', 'radio_mp3_product_id', 'radio_mp3_price'),
        'extended_wav' => array('Extended WAV', 'extended_wav_product_id', 'extended_wav_price'),
        'extended_mp3_320' => array('Extended MP3 320 kbps', 'extended_mp3_product_id', 'extended_mp3_price'),
    ) as $type => $definition) {
        $product_id = sanitize_text_field(get_post_meta($id, $definition[1], true));
        $product_prices[$type] = sanitize_text_field(get_post_meta($id, $definition[2], true));
        if ($product_id !== '') $products[] = array('id' => $product_id, 'type' => $type, 'label' => $definition[0], 'price' => sanitize_text_field(get_post_meta($id, $definition[2], true)));
    }
    // Backward compatibility for releases created with the old single-source editor.
    foreach (array('wav' => 'WAV / lossless', 'mp3_320' => 'MP3 320 kbps') as $key => $label) {
        $product_id = sanitize_text_field(get_post_meta($id, $key . '_product_id', true));
        if ($product_id !== '') $products[] = array('id' => $product_id, 'type' => $key, 'label' => $label, 'price' => sanitize_text_field(get_post_meta($id, $key . '_price', true)));
    }
    $cover_id = absint(get_post_meta($id, 'cover', true));
    $links = array();
    foreach (array('spotify', 'apple_music', 'beatport', 'hardstyle_com', 'youtube') as $key) {
        $value = esc_url_raw(get_post_meta($id, $key, true));
        if ($value !== '') $links[$key] = $value;
    }
    $versions = array();
    foreach (array('radio' => 'radio_audio_url', 'extended' => 'extended_audio_url') as $type => $meta_key) {
        $source = esc_url_raw(get_post_meta($id, $meta_key, true));
        $available = $source !== '' || trim((string) get_post_meta($id, 'private_' . $type . '_wav_path', true)) !== '';
        if ($available) $versions[] = array('type' => $type, 'available' => true);
    }
    $release_date = sanitize_text_field((string) get_post_meta($id, 'release_date', true));
    if ($release_date === '') $release_date = get_the_date('Y-m-d', $post);
    $is_free = (bool) get_post_meta($id, 'is_free', true);
    $free_external_link = $is_free ? esc_url_raw(get_post_meta($id, 'free_external_link', true)) : '';
    $is_upcoming = huhs_release_is_upcoming($release_date);
    return array('id' => $id, 'title' => huhs_clean_title($post->post_title), 'release_date' => $release_date, 'is_upcoming' => $is_upcoming, 'presave_url' => $is_upcoming ? esc_url_raw(get_post_meta($id, 'presave_url', true)) : '', 'is_free' => $is_free, 'free_external_link' => $free_external_link, 'cover' => $cover_id ? wp_get_attachment_image_url($cover_id, 'large') : '', 'genre' => sanitize_text_field(get_post_meta($id, 'genre', true)), 'artists' => $artists, 'tracks' => $tracks, 'links' => $links, 'products' => $products, 'product_prices' => $product_prices, 'versions' => $versions, 'audio_status' => sanitize_key(get_post_meta($id, 'audio_processing_status', true)));
}

function huhs_update_release_play_products(WP_REST_Request $request)
{
    $post_id = absint($request['id']);
    $post = get_post($post_id);
    if (!$post || $post->post_type !== 'huhs_release') return new WP_Error('not_found', 'A release nem található.', array('status' => 404));
    $products = $request->get_param('products');
    if (!is_object($products) && !is_array($products)) return new WP_Error('invalid_products', 'Érvénytelen Play-terméklista.', array('status' => 400));
    $products = (array) $products;
    $allowed = array('radio_wav', 'radio_mp3_320', 'extended_wav', 'extended_mp3_320');
    foreach ($allowed as $type) {
        if (!array_key_exists($type, $products)) continue;
        $value = sanitize_text_field((string) $products[$type]);
        if ($value === '' || !preg_match('/^[a-z0-9_.]{1,40}$/', $value)) return new WP_Error('invalid_product_id', 'Érvénytelen Play-termékazonosító.', array('status' => 400));
        update_post_meta($post_id, $type === 'radio_mp3_320' ? 'radio_mp3_product_id' : ($type === 'extended_mp3_320' ? 'extended_mp3_product_id' : $type . '_product_id'), $value);
    }
    return rest_ensure_response(array('ok' => true, 'release_id' => $post_id));
}
