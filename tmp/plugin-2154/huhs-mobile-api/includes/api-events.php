<?php

if (!defined('ABSPATH')) {
    exit;
}

/*
|--------------------------------------------------------------------------
| Events REST API
|--------------------------------------------------------------------------
*/

add_action('rest_api_init', 'huhs_register_events_api');

function huhs_register_events_api()
{
    register_rest_route('huhs/v1', '/events', array(
        'methods'             => 'GET',
        'callback'            => 'huhs_get_events',
        'permission_callback' => '__return_true',
    ));
    register_rest_route('huhs/v1', '/events/(?P<id>\d+)', array(
        'methods'             => 'GET',
        'callback'            => 'huhs_get_event',
        'permission_callback' => '__return_true',
        'args'                => array(
            'id' => array('required' => true, 'sanitize_callback' => 'absint'),
        ),
    ));
}

function huhs_get_events(WP_REST_Request $request)
{
    $summary = filter_var($request->get_param('summary'), FILTER_VALIDATE_BOOLEAN);
    $lang = huhs_request_lang($request);
    $include_past = filter_var($request->get_param('include_past'), FILTER_VALIDATE_BOOLEAN);
    $page_param = $request->get_param('page');
    $per_page_param = $request->get_param('per_page');
    $paginated = $page_param !== null || $per_page_param !== null;
    $page = max(1, (int) ($page_param ?: 1));
    $per_page = min(25, max(1, (int) ($per_page_param ?: 12)));
    $events = get_posts(array(
        'post_type'      => 'huhs_event',
        'post_status'    => 'publish',
        'posts_per_page' => -1,
        'orderby'        => 'meta_value',
        'meta_key'       => 'event_start_date',
        'order'          => 'ASC',
    ));

    $data = array();

    foreach ($events as $event) {

        // Csak a látható események
        if (!get_post_meta($event->ID, 'visible', true)) {
            continue;
        }

        $date = get_post_meta($event->ID, 'event_end_date', true) ?: get_post_meta($event->ID, 'event_start_date', true);
        if (!$include_past && $date && strtotime($date) < current_time('timestamp')) continue;
        $data[] = $summary ? huhs_build_event_summary($event, $lang) : huhs_build_event_response($event, $lang);
    }

    // Featured események előre, utána dátum szerint
    usort($data, function ($a, $b) {

        if ($a['featured'] === $b['featured']) {
            return strcmp($a['start_date'], $b['start_date']);
        }

        return $a['featured'] ? -1 : 1;

    });

    if (!$paginated) {
        return rest_ensure_response($data);
    }

    $total = count($data);
    $offset = ($page - 1) * $per_page;
    return rest_ensure_response(array(
        'items' => array_slice($data, $offset, $per_page),
        'page' => $page,
        'per_page' => $per_page,
        'total' => $total,
        'has_more' => $offset + $per_page < $total,
    ));
}

function huhs_get_event(WP_REST_Request $request)
{
    $event = get_post((int) $request['id']);
    if (!$event || $event->post_type !== 'huhs_event' || $event->post_status !== 'publish' || !get_post_meta($event->ID, 'visible', true)) {
        return new WP_Error('huhs_event_not_found', 'Az esemény nem található.', array('status' => 404));
    }
    return rest_ensure_response(huhs_build_event_response($event, huhs_request_lang($request)));
}

function huhs_build_event_summary($event, $lang = 'hu')
{
    $flyer_id = (int) get_post_meta($event->ID, 'flyer_image', true);
    $flyer_url = esc_url_raw(get_post_meta($event->ID, 'flyer_image_url', true));
    $translation = huhs_translation_meta_values($event->ID, $lang, $event->post_title, '');
    return array(
        'id' => (int) $event->ID,
        'title' => huhs_clean_title($translation['title']),
        'has_en' => $translation['has_en'],
        'description' => '',
        'start_date' => get_post_meta($event->ID, 'event_start_date', true),
        'start_time' => get_post_meta($event->ID, 'event_start_time', true),
        'end_date' => get_post_meta($event->ID, 'event_end_date', true),
        'end_time' => get_post_meta($event->ID, 'event_end_time', true),
        'venue_name' => get_post_meta($event->ID, 'venue_name', true),
        'venue_city' => get_post_meta($event->ID, 'venue_city', true),
        'venue_zip' => get_post_meta($event->ID, 'venue_zip', true),
        'venue_address' => '', 'venue_country' => '', 'google_maps' => '',
        'facebook_event_url' => get_post_meta($event->ID, 'facebook_event_url', true),
        'genres' => array(), 'ticket_type' => '', 'ticket_url' => '',
        'organizer' => array('id' => (int) get_post_meta($event->ID, 'organizer_id', true), 'name' => ''),
        'artists' => array(),
        'flyer' => $flyer_id ? wp_get_attachment_image_url($flyer_id, 'medium') : $flyer_url,
        'featured' => (bool) get_post_meta($event->ID, 'featured', true),
        'visible' => (bool) get_post_meta($event->ID, 'visible', true),
        'status' => get_post_meta($event->ID, 'status', true),
    );
}

function huhs_build_event_response($event, $lang = 'hu')
{
    $flyer_id = (int) get_post_meta($event->ID, 'flyer_image', true);
    $flyer_url = esc_url_raw(get_post_meta($event->ID, 'flyer_image_url', true));
    $organizer_id = (int) get_post_meta($event->ID, 'organizer_id', true);
    // A kért nyelv (2.12.0): a magyar ág bitre ugyanaz, mint eddig.
    $translation = huhs_translation_meta_values(
        $event->ID,
        $lang,
        $event->post_title,
        $event->post_content
    );
    $artists = array();
    $artist_ids = json_decode(get_post_meta($event->ID, 'artists', true), true);

    if (is_array($artist_ids)) {
        foreach ($artist_ids as $artist_id) {
            $artists[] = array(
                'id'   => (int) $artist_id,
                'name' => get_the_title($artist_id),
            );
        }
    }

    $genre_value = get_post_meta($event->ID, 'genre', true);
    $genres = is_array($genre_value)
        ? $genre_value
        : explode(',', (string) $genre_value);
    $genres = array_values(array_unique(array_filter(array_map('trim', $genres))));

    // ⚠️ 2.13.0: a helyszín országa/városa **név**, nem prózai szöveg, ezért nem
    // az AI fordítja, hanem a determinisztikus névtár (`translation-places.php`).
    // A magyar ág bájtazonos: a függvények `hu`-ra az eredeti értéket adják.
    $venue_city = huhs_translation_city_value(get_post_meta($event->ID, 'venue_city', true), $lang);
    $venue_country = huhs_translation_country_value(get_post_meta($event->ID, 'venue_country', true), $lang);

    $google_maps = get_post_meta($event->ID, 'google_maps', true);
    if (!$google_maps) {
        $google_maps = huhs_event_maps_url(array(
            get_post_meta($event->ID, 'venue_name', true),
            get_post_meta($event->ID, 'venue_zip', true),
            get_post_meta($event->ID, 'venue_city', true),
            get_post_meta($event->ID, 'venue_address', true),
            get_post_meta($event->ID, 'venue_country', true),
        ));
    }

    return array(
        'id'                 => (int) $event->ID,
        'title'              => huhs_clean_title($translation['title']),
        'has_en'             => $translation['has_en'],
        'description'        => wpautop($translation['content']),
        'start_date'         => get_post_meta($event->ID, 'event_start_date', true),
        'start_time'         => get_post_meta($event->ID, 'event_start_time', true),
        'end_date'           => get_post_meta($event->ID, 'event_end_date', true),
        'end_time'           => get_post_meta($event->ID, 'event_end_time', true),
        'venue_name'         => get_post_meta($event->ID, 'venue_name', true),
        'venue_city'         => $venue_city,
        'venue_zip'          => get_post_meta($event->ID, 'venue_zip', true),
        'venue_address'      => get_post_meta($event->ID, 'venue_address', true),
        'venue_country'      => $venue_country,
        'google_maps'        => $google_maps,
        'facebook_event_url' => get_post_meta($event->ID, 'facebook_event_url', true),
        'genres'             => $genres,
        'ticket_type'        => get_post_meta($event->ID, 'ticket_type', true),
        'ticket_url'         => get_post_meta($event->ID, 'ticket_url', true),
        'organizer'          => array(
            'id'   => $organizer_id,
            'name' => $organizer_id ? huhs_clean_title(get_the_title($organizer_id)) : '',
        ),
        'artists'            => $artists,
        'flyer'              => $flyer_id ? wp_get_attachment_image_url($flyer_id, 'large') : $flyer_url,
        'featured'           => (bool) get_post_meta($event->ID, 'featured', true),
        'visible'            => (bool) get_post_meta($event->ID, 'visible', true),
        'status'             => get_post_meta($event->ID, 'status', true),
    );
}
