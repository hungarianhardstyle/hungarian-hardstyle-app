<?php

if (!defined('ABSPATH')) {
    exit;
}

add_action('rest_api_init', 'huhs_register_organizers_api');

function huhs_register_organizers_api()
{
    register_rest_route('huhs/v1', '/organizers', array(
        'methods'             => 'GET',
        'callback'            => 'huhs_get_organizers',
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
        ),
    ));

    register_rest_route('huhs/v1', '/organizers/(?P<id>\d+)', array(
        'methods'             => 'GET',
        'callback'            => 'huhs_get_organizer_detail',
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

function huhs_get_organizers(WP_REST_Request $request)
{
    $page = max(1, absint($request->get_param('page')));
    $per_page = min(50, max(1, absint($request->get_param('per_page')) ?: 20));
    $search = sanitize_text_field((string) $request->get_param('search'));
    $lang = huhs_request_lang($request);

    $query = new WP_Query(array(
        'post_type'      => 'huhs_organizer',
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
    ));

    $items = array_map(function ($organizer) use ($lang) {
        return huhs_build_organizer_response($organizer, false, $lang);
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

function huhs_get_organizer_detail(WP_REST_Request $request)
{
    $organizer_id = absint($request->get_param('id'));
    $organizer = get_post($organizer_id);

    if (
        !$organizer ||
        $organizer->post_type !== 'huhs_organizer' ||
        $organizer->post_status !== 'publish' ||
        !get_post_meta($organizer_id, 'visible', true)
    ) {
        return new WP_Error(
            'huhs_organizer_not_found',
            'A szervezői adatlap nem található.',
            array('status' => 404)
        );
    }

    return rest_ensure_response(huhs_build_organizer_response($organizer, true, huhs_request_lang($request)));
}

function huhs_build_organizer_response($organizer, $include_events = false, $lang = 'hu')
{
    $organizer_id = (int) $organizer->ID;
    // A kért nyelv (2.12.0): cím, leírás és kivonat.
    $translation = huhs_translation_meta_values(
        $organizer_id,
        $lang,
        $organizer->post_title,
        $organizer->post_content
    );
    $logo_id = (int) get_post_meta($organizer_id, 'logo', true);
    $logo_url = esc_url_raw(get_post_meta($organizer_id, 'logo_url', true));
    $featured_id = (int) get_post_thumbnail_id($organizer_id);
    $logo = $logo_id ? wp_get_attachment_image_url($logo_id, 'large') : $logo_url;
    $featured_image = $featured_id
        ? wp_get_attachment_image_url($featured_id, 'large')
        : $logo;
    $genre_value = get_post_meta($organizer_id, 'genre', true);
    $genres = is_array($genre_value)
        ? $genre_value
        : explode(',', (string) $genre_value);
    $genres = array_values(array_unique(array_filter(array_map('trim', $genres))));

    $data = array(
        'id'             => $organizer_id,
        'title'          => huhs_clean_title($translation['title']),
        'has_en'         => $translation['has_en'],
        'slug'           => $organizer->post_name,
        'description'    => huhs_clean_content($translation['content']),
        'excerpt'        => $translation['excerpt'] !== ''
            ? huhs_make_excerpt($translation['excerpt'], 30)
            : huhs_make_excerpt($translation['content'], 30),
        // ⚠️ 2.13.0: az ország/város név — determinisztikus névtár fordítja
        // (`translation-places.php`), nem az AI. A magyar ág változatlan.
        'city'           => huhs_translation_city_value(get_post_meta($organizer_id, 'city', true), $lang),
        'country'        => huhs_translation_country_value(get_post_meta($organizer_id, 'country', true), $lang),
        'genres'         => $genres,
        'logo'           => $logo ?: '',
        'featured_image' => $featured_image ?: '',
        'featured'       => (bool) get_post_meta($organizer_id, 'featured', true),
        'visible'        => (bool) get_post_meta($organizer_id, 'visible', true),
        'link'           => get_permalink($organizer_id),
        'social_links'   => array(
            'website'   => get_post_meta($organizer_id, 'website', true),
            'facebook'  => get_post_meta($organizer_id, 'facebook', true),
            'instagram' => get_post_meta($organizer_id, 'instagram', true),
            'tiktok'    => get_post_meta($organizer_id, 'tiktok', true),
        ),
    );

    if ($include_events) {
        $data['upcoming_events'] = huhs_get_organizer_upcoming_events($organizer_id, $lang);
    }

    return $data;
}

function huhs_get_organizer_upcoming_events($organizer_id, $lang = 'hu')
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
            array(
                'key'     => 'organizer_id',
                'value'   => (string) $organizer_id,
                'compare' => '=',
            ),
        ),
    ));

    // ⚠️ 2.13.0: a nyelvet **át kell adni** — az `array_map('huhs_build_event_response', …)`
    // csak egy argumentumot ad, ezért a `$lang` a függvény alapértékére (`hu`)
    // esett vissza, és a szervező adatlapján a közelgő események angol módban is
    // magyarul jelentek meg (mért hiba).
    return array_map(
        static function ($event) use ($lang) {
            return huhs_build_event_response($event, $lang);
        },
        $events
    );
}
