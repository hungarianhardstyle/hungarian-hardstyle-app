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
}

function huhs_get_events()
{
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

        $data[] = huhs_build_event_response($event);
    }

    // Featured események előre, utána dátum szerint
    usort($data, function ($a, $b) {

        if ($a['featured'] === $b['featured']) {
            return strcmp($a['start_date'], $b['start_date']);
        }

        return $a['featured'] ? -1 : 1;

    });

    return rest_ensure_response($data);
}

function huhs_build_event_response($event)
{
    $flyer_id = (int) get_post_meta($event->ID, 'flyer_image', true);
    $flyer_url = esc_url_raw(get_post_meta($event->ID, 'flyer_image_url', true));
    $organizer_id = (int) get_post_meta($event->ID, 'organizer_id', true);
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
        'title'              => huhs_clean_title($event->post_title),
        'description'        => wpautop($event->post_content),
        'start_date'         => get_post_meta($event->ID, 'event_start_date', true),
        'start_time'         => get_post_meta($event->ID, 'event_start_time', true),
        'end_date'           => get_post_meta($event->ID, 'event_end_date', true),
        'end_time'           => get_post_meta($event->ID, 'event_end_time', true),
        'venue_name'         => get_post_meta($event->ID, 'venue_name', true),
        'venue_city'         => get_post_meta($event->ID, 'venue_city', true),
        'venue_zip'          => get_post_meta($event->ID, 'venue_zip', true),
        'venue_address'      => get_post_meta($event->ID, 'venue_address', true),
        'venue_country'      => get_post_meta($event->ID, 'venue_country', true),
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
