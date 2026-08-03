<?php

if (!defined('ABSPATH')) {
    exit;
}

/*
|--------------------------------------------------------------------------
| Artists Custom Post Type
|--------------------------------------------------------------------------
*/

add_action('init', 'huhs_register_artist_post_type');

function huhs_register_artist_post_type()
{
    $labels = array(
        'name'                  => 'Artists',
        'singular_name'         => 'Artist',
        'menu_name'             => 'Artists',
        'name_admin_bar'        => 'Artist',
        'add_new'               => 'Új artist',
        'add_new_item'          => 'Új artist hozzáadása',
        'edit_item'             => 'Artist szerkesztése',
        'new_item'              => 'Új artist',
        'view_item'             => 'Artist megtekintése',
        'search_items'          => 'Artist keresése',
        'not_found'             => 'Nincs artist.',
        'not_found_in_trash'    => 'Nincs artist a kukában.',
    );

    register_post_type('huhs_artist', array(

        'labels' => $labels,

        'public' => true,

        'publicly_queryable' => true,

        'show_ui' => true,

        'show_in_menu' => false,

        'supports' => array(
            'title',
            'thumbnail',
            'editor',
        ),

        'menu_icon' => 'dashicons-groups',

        'has_archive' => true,

        'rewrite' => array(
            'slug' => 'djs',
            'with_front' => false,
        ),

        'show_in_rest' => true,

    ));

    register_taxonomy('huhs_artist_category', array('huhs_artist'), array(
        'labels' => array(
            'name'          => 'DJ kategóriák',
            'singular_name' => 'DJ kategória',
            'search_items'  => 'DJ kategóriák keresése',
            'all_items'     => 'Összes DJ kategória',
            'edit_item'     => 'DJ kategória szerkesztése',
            'update_item'   => 'DJ kategória frissítése',
            'add_new_item'  => 'Új DJ kategória',
            'new_item_name' => 'Új DJ kategória neve',
            'menu_name'     => 'DJ kategóriák',
        ),
        'public'            => true,
        'hierarchical'      => true,
        'show_ui'           => true,
        'show_admin_column' => true,
        'show_in_rest'      => true,
        'rewrite'           => array(
            'slug'       => 'dj-kategoria',
            'with_front' => false,
        ),
    ));
}

add_action('init', 'huhs_create_default_artist_categories', 20);

function huhs_create_default_artist_categories()
{
    if (!taxonomy_exists('huhs_artist_category')) {
        return;
    }

    $categories = array(
        'hardstyle' => 'Hardstyle',
        'hardcore'  => 'Hardcore',
    );

    foreach ($categories as $slug => $name) {
        if (!term_exists($slug, 'huhs_artist_category')) {
            wp_insert_term($name, 'huhs_artist_category', array('slug' => $slug));
        }
    }
}
/*
|--------------------------------------------------------------------------
| Artist Meta Box
|--------------------------------------------------------------------------
*/

add_action('add_meta_boxes', 'huhs_add_artist_meta_box');

function huhs_add_artist_meta_box()
{
    add_meta_box(
        'huhs_artist_details',
        'Artist adatai',
        'huhs_artist_meta_box_callback',
        'huhs_artist',
        'normal',
        'high'
    );
}

function huhs_artist_meta_box_callback($post)
{
    wp_nonce_field('huhs_artist_save', 'huhs_artist_nonce');

    echo '<h3>🌍 Alapadatok</h3>';

    huhs_text_field($post, 'real_name', 'Valódi név');
    huhs_text_field($post, 'country', 'Ország');
    huhs_text_field($post, 'city', 'Város');
    huhs_text_field($post, 'website', 'Weboldal');

    echo '<hr>';

    echo '<h3>🎵 Zenei adatok</h3>';

    huhs_genres_field($post, 'genre', 'Műfajok');

    echo '<hr>';

    echo '<h3>🌐 Közösségi oldalak</h3>';

    huhs_text_field($post, 'facebook', 'Facebook');
    huhs_text_field($post, 'instagram', 'Instagram'); 
    huhs_text_field($post, 'tiktok', 'TikTok');
    huhs_text_field($post, 'spotify', 'Spotify');
    huhs_text_field($post, 'soundcloud', 'SoundCloud');
    huhs_text_field($post, 'youtube', 'YouTube');

    echo '<hr>';
    echo '<h3>Fellépés kérése</h3>';
    huhs_text_field($post, 'booking_email', 'Nyilvános booking e-mail');
    huhs_checkbox_field($post, 'booking_via_huhs', 'Fellépés szervezése a Hungarian Hardstyle-on keresztül (info@hungarianhardstyle.hu)');

    echo '<hr>';
    echo '<hr>';

    echo '<h3>🖼️ Képek</h3>';

    huhs_image_field($post, 'logo', 'Logó');

    huhs_image_field($post, 'hero_image', 'Profilkép');

    echo '<h3>📱 Mobilalkalmazás</h3>';

    huhs_checkbox_field($post, 'featured', '⭐ Kiemelt előadó');
    huhs_checkbox_field($post, 'visible', '📱 Publikálás az alkalmazásban');
}
