<?php

if (!defined('ABSPATH')) {
    exit;
}

add_action('admin_enqueue_scripts', 'huhs_admin_assets');

function huhs_admin_assets()
{
    wp_enqueue_media();

    wp_enqueue_script(
        'huhs-admin',
        HUHS_API_URL . 'assets/admin.js',
        array('jquery'),
        HUHS_API_VERSION,
        true
    );
}