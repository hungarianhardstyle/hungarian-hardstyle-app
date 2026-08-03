<?php

if (!defined('ABSPATH')) {
    exit;
}

add_filter('use_block_editor_for_post_type', 'huhs_disable_gutenberg', 10, 2);

function huhs_disable_gutenberg($use_block_editor, $post_type)
{
    $disabled = array(
        'huhs_artist',
        'huhs_organizer',
        'huhs_event',
        'huhs_submission',
    );

    if (in_array($post_type, $disabled, true)) {
        return false;
    }

    return $use_block_editor;
}