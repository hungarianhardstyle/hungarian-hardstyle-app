<?php

if (!defined('ABSPATH')) {
    exit;
}

/*
|--------------------------------------------------------------------------
| Event Meta Boxes
|--------------------------------------------------------------------------
*/

add_action('add_meta_boxes', 'huhs_add_event_meta_boxes');
add_action('add_meta_boxes', 'huhs_add_cloudinary_preview_meta_boxes');

function huhs_add_cloudinary_preview_meta_boxes()
{
    foreach (array('huhs_artist', 'huhs_organizer', 'huhs_event') as $post_type) {
        add_meta_box(
            'huhs_cloudinary_preview',
            'Cloudinary-kép előnézete',
            'huhs_cloudinary_preview_meta_box_callback',
            $post_type,
            'side',
            'default'
        );
    }
}

function huhs_cloudinary_preview_meta_box_callback($post)
{
    foreach (array('hero_image_url', 'logo_url', 'flyer_image_url') as $key) {
        $url = esc_url_raw(get_post_meta($post->ID, $key, true));
        if ($url === '' || !function_exists('huhs_is_cloudinary_url') || !huhs_is_cloudinary_url($url)) {
            continue;
        }

        echo '<p><strong>' . esc_html($key) . '</strong></p>';
        echo '<img src="' . esc_url($url) . '" alt="" style="max-width:100%;height:auto;border-radius:6px;">';
        echo '<p><a href="' . esc_url($url) . '" target="_blank" rel="noopener">Kép megnyitása</a></p>';
    }
}

function huhs_add_event_meta_boxes()
{
    add_meta_box(
        'huhs_event_details',
        'Event Details',
        'huhs_event_details_callback',
        'huhs_event',
        'normal',
        'high'
    );
}

function huhs_event_details_callback($post)
{
    wp_nonce_field('huhs_event_save', 'huhs_event_nonce');

    ?>

    <style>

        .huhs-row{
            display:flex;
            gap:20px;
            margin-bottom:18px;
        }

        .huhs-col{
            flex:1;
        }

        .huhs-col label{
            display:block;
            font-weight:bold;
            margin-bottom:6px;
        }

        .huhs-col input,
        .huhs-col select,
        .huhs-col textarea{
            width:100%;
        }

        .huhs-col input[type="checkbox"]{
            width:auto;
            margin:0;
        }

        .huhs-genre-option{
            display:flex !important;
            align-items:center;
            gap:8px;
            font-weight:normal !important;
            margin-bottom:8px !important;
        }

        h2.huhs-title{
            margin-top:25px;
            margin-bottom:15px;
            border-bottom:1px solid #ddd;
            padding-bottom:6px;
        }

    </style>

    <h2 class="huhs-title">📅 Dátum</h2>

    <div class="huhs-row">

    <div class="huhs-col">
        <?php huhs_date_field($post, 'event_start_date', 'Kezdés dátuma'); ?>
    </div>

    <div class="huhs-col">
        <?php huhs_time_field($post, 'event_start_time', 'Kezdés időpontja'); ?>
    </div>

    </div>

    <div class="huhs-row">

    <div class="huhs-col">
        <?php huhs_date_field($post, 'event_end_date', 'Befejezés dátuma'); ?>
    </div>

    <div class="huhs-col">
        <?php huhs_time_field($post, 'event_end_time', 'Befejezés időpontja'); ?>
    </div>

</div>

    <h2 class="huhs-title">📍 Helyszín</h2>

<div class="huhs-row">

    <div class="huhs-col">
        <?php huhs_text_field($post, 'venue_name', 'Helyszín neve'); ?>
    </div>

</div>

<div class="huhs-row">

    <div class="huhs-col">
        <?php huhs_text_field($post, 'venue_city', 'Város'); ?>
    </div>

    <div class="huhs-col">
        <?php huhs_text_field($post, 'venue_zip', 'Irányítószám'); ?>
    </div>

</div>

    <div class="huhs-row">

        <div class="huhs-col">
            <?php huhs_text_field($post, 'venue_address', 'Cím'); ?>
        </div>

        <div class="huhs-col">
            <?php huhs_text_field($post, 'venue_country', 'Ország'); ?>
        </div>

    </div>

    <div class="huhs-row">

        <div class="huhs-col">
            <?php huhs_text_field($post, 'google_maps', 'Google Maps URL'); ?>
        </div>

        <div class="huhs-col">
            <?php huhs_text_field($post, 'facebook_event_url', 'Facebook Event URL'); ?>
            <?php huhs_genres_field($post, 'genre', 'Műfajok / stílusok'); ?>
        </div>

    </div>

    <h2 class="huhs-title">🎟 Jegyek</h2>

    <div class="huhs-row">

        <div class="huhs-col">

            <?php

huhs_select_field(
    $post,
    'ticket_type',
    'Belépés',
    array(
        'free' => 'Ingyenes',
        'paid' => 'Jegyvásárlás szükséges',
    )
);

?>

        </div>

        <div class="huhs-col">

    <?php huhs_text_field($post, 'ticket_url', 'Jegy link'); ?>

        </div>

    </div>
    <h2 class="huhs-title">👤 Szervező</h2>

    <?php
     huhs_organizer_field(
     $post,
     'organizer_id',
     'Szervező'
);
?>

    <h2 class="huhs-title">👥 Fellépők</h2>

    <?php

     huhs_artists_field(
     $post,
     'artists',
     'Válaszd ki a fellépőket'
);

?>
<h2 class="huhs-title">🖼️ Képek</h2>

<?php

huhs_image_field(
    $post,
    'flyer_image',
    'Flyer'
);

?>
    <h2 class="huhs-title">📱 Mobil App</h2>

    <p>

        <label>

            <?php huhs_checkbox_field($post, 'featured', 'Kiemelt esemény'); ?>

            Kiemelt esemény

        </label>

    </p>

    <p>

        <label>

            <?php huhs_checkbox_field($post, 'visible', 'Megjelenjen az alkalmazásban'); ?>

            Megjelenjen az alkalmazásban

        </label>

    </p>

    <p>

        <label>Státusz</label>

        <select name="status">

            <option value="upcoming">Upcoming</option>

            <option value="selling_fast">Selling Fast</option>

            <option value="sold_out">Sold Out</option>

            <option value="cancelled">Cancelled</option>

        </select>

    </p>

    <?php
}
