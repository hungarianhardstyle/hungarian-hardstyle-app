<?php

if (!defined('ABSPATH')) {
    exit;
}

add_action('rest_api_init', 'huhs_register_artists_api');

function huhs_register_artists_api()
{
    register_rest_route('huhs/v1', '/artists', array(
        'methods'             => 'GET',
        'callback'            => 'huhs_get_artists',
        'permission_callback' => '__return_true',
        'args'                => array(
            'page' => array(
                'sanitize_callback' => 'absint',
                'default' => 1,
            ),
            'per_page' => array(
                'sanitize_callback' => 'absint',
                'default' => 20,
            ),
            'search' => array(
                'sanitize_callback' => 'sanitize_text_field',
                'default' => '',
            ),
            'category' => array(
                'sanitize_callback' => function ($value) {
                    return sanitize_title((string) $value);
                },
                'default' => '',
            ),
        ),
    ));

    register_rest_route('huhs/v1', '/artists/(?P<id>\d+)', array(
        'methods'             => 'GET',
        'callback'            => 'huhs_get_artist_detail',
        'permission_callback' => '__return_true',
        'args'                => array(
            'id' => array(
                'sanitize_callback' => 'absint',
                'validate_callback' => function ($value) {
                    return absint($value) > 0;
                },
            ),
        ),
    ));
}

function huhs_get_artists(WP_REST_Request $request)
{
    $page = max(1, absint($request->get_param('page')));
    $per_page = min(50, max(1, absint($request->get_param('per_page')) ?: 20));
    $search = sanitize_text_field((string) $request->get_param('search'));
    $category = sanitize_title((string) $request->get_param('category'));

    $tax_query = array();
    if ($category !== '') {
        $tax_query[] = array(
            'taxonomy' => 'huhs_artist_category',
            'field'    => 'slug',
            'terms'    => $category,
        );
    }

    $query_args = array(
        'post_type'      => 'huhs_artist',
        'post_status'    => 'publish',
        'posts_per_page' => $per_page,
        'paged'          => $page,
        'orderby'        => array(
            'meta_value_num' => 'DESC',
            'title'          => 'ASC',
        ),
        'meta_key'       => 'featured',
        's'              => $search,
        'meta_query'     => array(
            array(
                'key'     => 'visible',
                'value'   => '1',
                'compare' => '=',
            ),
        ),
        'no_found_rows'  => false,
    );

    if ($tax_query) {
        $query_args['tax_query'] = $tax_query;
    }

    $query = new WP_Query($query_args);

    $items = array_map(function ($artist) {
        return huhs_build_artist_response($artist, false);
    }, $query->posts);

    $total_pages = (int) $query->max_num_pages;

    return rest_ensure_response(array(
        'items'       => $items,
        'page'        => $page,
        'per_page'    => $per_page,
        'total'       => (int) $query->found_posts,
        'total_pages' => $total_pages,
        'has_more'    => $page < $total_pages,
    ));
}

function huhs_get_artist_detail(WP_REST_Request $request)
{
    $artist_id = absint($request->get_param('id'));
    $artist = get_post($artist_id);

    if (
        !$artist ||
        $artist->post_type !== 'huhs_artist' ||
        $artist->post_status !== 'publish' ||
        !get_post_meta($artist_id, 'visible', true)
    ) {
        return new WP_Error(
            'huhs_artist_not_found',
            'A DJ adatlap nem talalhato.',
            array('status' => 404)
        );
    }

    return rest_ensure_response(huhs_build_artist_response($artist, true));
}

function huhs_build_artist_response($artist, $include_events = false)
{
    $artist_id = (int) $artist->ID;
    $genre_value = get_post_meta($artist_id, 'genre', true);
    $genres = is_array($genre_value)
        ? $genre_value
        : explode(',', (string) $genre_value);
    $genres = array_values(array_unique(array_filter(array_map('trim', $genres))));

    $logo_id = (int) get_post_meta($artist_id, 'logo', true);
    $hero_id = (int) get_post_meta($artist_id, 'hero_image', true);
    $logo_url = esc_url_raw(get_post_meta($artist_id, 'logo_url', true));
    $hero_url = esc_url_raw(get_post_meta($artist_id, 'hero_image_url', true));
    $featured_id = (int) get_post_thumbnail_id($artist_id);
    $logo = $logo_id ? wp_get_attachment_image_url($logo_id, 'medium') : $logo_url;
    $hero = $hero_id ? wp_get_attachment_image_url($hero_id, 'large') : $hero_url;
    $wordpress_featured_image = $featured_id
        ? wp_get_attachment_image_url($featured_id, 'large')
        : '';
    $profile_image = $hero ?: ($wordpress_featured_image ?: $logo);
    $category_terms = get_the_terms($artist_id, 'huhs_artist_category');
    $categories = array();
    $booking_via_huhs = (bool) get_post_meta($artist_id, 'booking_via_huhs', true);
    $booking_email = $booking_via_huhs
        ? 'info@hungarianhardstyle.hu'
        : sanitize_email(get_post_meta($artist_id, 'booking_email', true));

    if (is_array($category_terms)) {
        foreach ($category_terms as $term) {
            $categories[] = array(
                'id'   => (int) $term->term_id,
                'name' => $term->name,
                'slug' => $term->slug,
            );
        }
    }

    $data = array(
        'id'             => $artist_id,
        'title'          => huhs_clean_title($artist->post_title),
        'slug'           => $artist->post_name,
        'biography'      => huhs_clean_content($artist->post_content),
        'excerpt'        => huhs_make_excerpt($artist->post_content, 30),
        'real_name'      => get_post_meta($artist_id, 'real_name', true),
        'country'        => get_post_meta($artist_id, 'country', true),
        'city'           => get_post_meta($artist_id, 'city', true),
        'genres'         => $genres,
        'categories'     => $categories,
        'logo'           => $logo ?: '',
        'profile_image'  => $profile_image ?: '',
        'hero_image'     => $hero ?: '',
        'featured_image' => $profile_image ?: '',
        'featured'       => (bool) get_post_meta($artist_id, 'featured', true),
        'visible'        => (bool) get_post_meta($artist_id, 'visible', true),
        'link'           => get_permalink($artist_id),
        'booking_email'  => $booking_email,
        'booking_via_huhs'=> $booking_via_huhs,
        'social_links'   => array(
            'website'    => get_post_meta($artist_id, 'website', true),
            'facebook'   => get_post_meta($artist_id, 'facebook', true),
            'instagram'  => get_post_meta($artist_id, 'instagram', true),
            'tiktok'     => get_post_meta($artist_id, 'tiktok', true),
            'spotify'    => get_post_meta($artist_id, 'spotify', true),
            'soundcloud' => get_post_meta($artist_id, 'soundcloud', true),
            'youtube'    => get_post_meta($artist_id, 'youtube', true),
        ),
    );

    if ($include_events) {
        $data['upcoming_events'] = huhs_get_artist_upcoming_events($artist_id);
    }

    return $data;
}

function huhs_get_artist_upcoming_events($artist_id)
{
    $events = get_posts(array(
        'post_type'      => 'huhs_event',
        'post_status'    => 'publish',
        'posts_per_page' => -1,
        'meta_key'       => 'event_start_date',
        'orderby'        => 'meta_value',
        'order'          => 'ASC',
        'meta_query'     => array(
            array(
                'key'     => 'event_start_date',
                'value'   => current_time('Y-m-d'),
                'compare' => '>=',
                'type'    => 'DATE',
            ),
            array(
                'key'     => 'visible',
                'value'   => '1',
                'compare' => '=',
            ),
        ),
    ));

    $upcoming = array();

    foreach ($events as $event) {
        $artist_ids = json_decode(get_post_meta($event->ID, 'artists', true), true);
        if (!is_array($artist_ids)) {
            continue;
        }

        $artist_ids = array_map('intval', $artist_ids);
        if (!in_array((int) $artist_id, $artist_ids, true)) {
            continue;
        }

        $upcoming[] = huhs_build_event_response($event);
    }

    return $upcoming;
}
