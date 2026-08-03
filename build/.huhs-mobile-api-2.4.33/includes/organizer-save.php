<?php

if (!defined('ABSPATH')) {
    exit;
}

add_action('save_post_huhs_organizer', 'huhs_save_organizer_meta');

function huhs_save_organizer_meta($post_id)
{
    if (
        !isset($_POST['huhs_organizer_nonce']) ||
        !wp_verify_nonce($_POST['huhs_organizer_nonce'], 'huhs_organizer_save')
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
        'website',
        'facebook',
        'instagram',
        'tiktok',
        'email',
        'phone',
        'city',
        'country',
    );

    foreach ($fields as $field) {

        if (isset($_POST[$field])) {

            update_post_meta(
                $post_id,
                $field,
                sanitize_text_field($_POST[$field])
            );

        }

    }

    if (isset($_POST['logo'])) {
        update_post_meta($post_id, 'logo', absint($_POST['logo']));
    }

    $genres = isset($_POST['genre']) && is_array($_POST['genre'])
        ? array_values(array_intersect(
            huhs_genre_options(),
            array_map('sanitize_text_field', wp_unslash($_POST['genre']))
        ))
        : array();
    update_post_meta($post_id, 'genre', implode(',', $genres));

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
}
