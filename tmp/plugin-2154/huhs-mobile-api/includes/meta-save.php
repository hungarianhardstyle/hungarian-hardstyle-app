<?php

if (!defined('ABSPATH')) {
    exit;
}

/*
|--------------------------------------------------------------------------
| Save Event Meta
|--------------------------------------------------------------------------
*/

add_action('save_post_huhs_event', 'huhs_save_event_meta');

function huhs_save_event_meta($post_id)
{
    if (
        !isset($_POST['huhs_event_nonce']) ||
        !wp_verify_nonce($_POST['huhs_event_nonce'], 'huhs_event_save')
    ) {
        return;
    }

    if (defined('DOING_AUTOSAVE') && DOING_AUTOSAVE) {
        return;
    }

    if (!current_user_can('edit_post', $post_id)) {
        return;
    }

    $fields = [

        'event_start_date',
        'event_start_time',

        'event_end_date',
        'event_end_time',

        'venue_name',
        'venue_city',
        'venue_zip',
        'venue_address',
        'venue_country',

        'google_maps',

        'facebook_event_url',

        'genre',

        'ticket_type',
        'ticket_url',

        'organizer_id',

        'artists',

        'status',

        'flyer_image',

        'hero_image',

    ];

foreach ($fields as $field) {

    if (!isset($_POST[$field])) {
        continue;
    }

    $value = $_POST[$field];

    if ($field === 'genre' && is_array($value)) {
        update_post_meta(
            $post_id,
            $field,
            implode(',', array_map('sanitize_text_field', $value))
        );
        continue;
    }

    if (is_array($value)) {

        update_post_meta(
            $post_id,
            $field,
            wp_json_encode(array_map('intval', $value))
        );

    } else {

        update_post_meta(
            $post_id,
            $field,
            sanitize_text_field($value)
        );

    }

}

    update_post_meta(
        $post_id,
        'featured',
        isset($_POST['featured']) ? 1 : 0
    );

    update_post_meta(
        $post_id,
        'visible',
        isset($_POST['visible']) ? 1 : 0
    );
// Flyer legyen a WordPress kiemelt képe is
if (!trim((string) get_post_meta($post_id, 'google_maps', true))) {
    update_post_meta($post_id, 'google_maps', huhs_event_maps_url(array(
        get_post_meta($post_id, 'venue_name', true),
        get_post_meta($post_id, 'venue_zip', true),
        get_post_meta($post_id, 'venue_city', true),
        get_post_meta($post_id, 'venue_address', true),
        get_post_meta($post_id, 'venue_country', true),
    )));
}

$flyer_id = get_post_meta($post_id, 'flyer_image', true);

if (!empty($flyer_id)) {
    set_post_thumbnail($post_id, (int) $flyer_id);
}
}
