<?php

if (!defined('ABSPATH')) {
    exit;
}

add_action('save_post_huhs_artist', 'huhs_save_artist_meta');

function huhs_save_artist_meta($post_id)
{
    if (
        !isset($_POST['huhs_artist_nonce']) ||
        !wp_verify_nonce($_POST['huhs_artist_nonce'], 'huhs_artist_save')
    ) {
        return;
    }

    if (defined('DOING_AUTOSAVE') && DOING_AUTOSAVE) {
        return;
    }

    if (!current_user_can('edit_post', $post_id)) {
        return;
    }

    $fields = array(
        'real_name',
        'country',
        'city',
        'website',
        'genre',
        'facebook',
        'instagram',
        'tiktok',
        'spotify',
        'soundcloud',
        'youtube',
        'booking_email',
        'logo',
        'hero_image',
    );

    foreach ($fields as $field) {

        if (!isset($_POST[$field])) {
            continue;
        }

        $value = $_POST[$field];

        if ($field === 'booking_email') {
            update_post_meta($post_id, $field, sanitize_email($value));
            continue;
        }

        if ($field === 'website') {
            update_post_meta($post_id, $field, esc_url_raw($value));
            continue;
        }

        if (is_array($value)) {

            update_post_meta(
                $post_id,
                $field,
                implode(',', array_map('sanitize_text_field', $value))
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

    update_post_meta(
        $post_id,
        'booking_via_huhs',
        isset($_POST['booking_via_huhs']) ? 1 : 0
    );
}
