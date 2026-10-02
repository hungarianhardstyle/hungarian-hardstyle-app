<?php

if (!defined('ABSPATH')) {
    exit;
}

/*
|--------------------------------------------------------------------------
| Events Custom Post Type
|--------------------------------------------------------------------------
*/

add_action('init', 'huhs_register_event_post_type');

function huhs_register_event_post_type()
{
    $labels = array(
        'name'               => 'Events',
        'singular_name'      => 'Event',
        'menu_name'          => 'Events',
        'name_admin_bar'     => 'Event',
        'add_new'            => 'Új esemény',
        'add_new_item'       => 'Új esemény hozzáadása',
        'edit_item'          => 'Esemény szerkesztése',
        'new_item'           => 'Új esemény',
        'view_item'          => 'Esemény megtekintése',
        'view_items'         => 'Események megtekintése',
        'search_items'       => 'Esemény keresése',
        'not_found'          => 'Nincs esemény.',
        'not_found_in_trash' => 'Nincs esemény a kukában.',
    );

    register_post_type('huhs_event', array(

        'labels' => $labels,

        // Nyilvános legyen
        'public' => true,

        // Maradjon az admin menüben úgy, ahogy most
        'show_ui' => true,

        'show_in_menu' => false,

        // Saját URL-ek
        'has_archive' => true,

        'rewrite' => array(
            'slug' => 'events',
            'with_front' => false,
        ),

        'publicly_queryable' => true,

        'exclude_from_search' => false,

        'show_in_rest' => true,

        'supports' => array(
            'title',
            'editor',
            'thumbnail',
        ),

        'menu_icon' => 'dashicons-calendar-alt',

    ));
}