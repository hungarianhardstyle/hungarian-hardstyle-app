<?php

if (!defined('ABSPATH')) {
    exit;
}

add_filter('template_include', 'huhs_public_archive_template', 99);

function huhs_public_archive_template($template)
{
    if (is_post_type_archive('huhs_artist')) {
        $artist_template = HUHS_API_PATH . 'templates/archive-artists.php';
        return file_exists($artist_template) ? $artist_template : $template;
    }

    if (is_post_type_archive('huhs_event')) {
        $event_template = HUHS_API_PATH . 'templates/archive-events.php';
        return file_exists($event_template) ? $event_template : $template;
    }

    return $template;
}
