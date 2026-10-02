<?php

if (!defined('ABSPATH')) {
    exit;
}

/*
|--------------------------------------------------------------------------
| Organizers Custom Post Type
|--------------------------------------------------------------------------
*/

add_action('init', 'huhs_register_organizer_post_type');

function huhs_register_organizer_post_type()
{
    $labels = array(
        'name'               => 'Organizers',
        'singular_name'      => 'Organizer',
        'menu_name'          => 'Organizers',
        'name_admin_bar'     => 'Organizer',
        'add_new'            => 'Új szervező',
        'add_new_item'       => 'Új szervező hozzáadása',
        'edit_item'          => 'Szervező szerkesztése',
        'new_item'           => 'Új szervező',
        'view_item'          => 'Szervező megtekintése',
        'search_items'       => 'Szervező keresése',
        'not_found'          => 'Nincs szervező.',
        'not_found_in_trash' => 'Nincs szervező a kukában.',
    );

    register_post_type('huhs_organizer', array(

        'labels' => $labels,

        'public' => true,

        'publicly_queryable' => true,

        'show_ui' => true,

        'show_in_menu' => false,

        'supports' => array(
            'title',
            'editor',
            'thumbnail',
        ),

        'menu_icon' => 'dashicons-building',

        'has_archive' => true,

        'rewrite' => array(
            'slug' => 'organizers',
            'with_front' => false,
        ),

        'show_in_rest' => true,

    ));
}

/*
|--------------------------------------------------------------------------
| Organizer Meta Box
|--------------------------------------------------------------------------
*/

add_action('add_meta_boxes', 'huhs_add_organizer_meta_box');

function huhs_add_organizer_meta_box()
{
    add_meta_box(
        'huhs_organizer_details',
        'Szervező adatai',
        'huhs_organizer_meta_box_callback',
        'huhs_organizer',
        'normal',
        'high'
    );
}

function huhs_organizer_meta_box_callback($post)
{
    wp_nonce_field('huhs_organizer_save', 'huhs_organizer_nonce');

    echo '<h3>🌐 Kapcsolatok</h3>';

    huhs_text_field($post, 'website', 'Weboldal');
    huhs_text_field($post, 'facebook', 'Facebook');
    huhs_text_field($post, 'instagram', 'Instagram');
    huhs_text_field($post, 'tiktok', 'TikTok');
    huhs_text_field($post, 'email', 'Email');
    huhs_text_field($post, 'phone', 'Telefonszám');

    echo '<hr>';

    echo '<h3>📍 Helyszín</h3>';

    huhs_text_field($post, 'city', 'Város');
    huhs_text_field($post, 'country', 'Ország');

    huhs_genres_field($post, 'genre', 'Zenei műfajok / stílusok');

    echo '<hr>';

    echo '<h3>Logó</h3>';

    huhs_image_field($post, 'logo', 'Szervező logója');

    echo '<hr>';

    echo '<h3>📱 Mobilalkalmazás</h3>';

    huhs_checkbox_field($post, 'featured', '⭐ Kiemelt szervező');
    huhs_checkbox_field($post, 'visible', '📱 Publikálás az alkalmazásban');
}
