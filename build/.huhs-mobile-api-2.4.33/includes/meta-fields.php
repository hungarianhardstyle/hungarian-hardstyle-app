<?php

if (!defined('ABSPATH')) {
    exit;
}

/*
|--------------------------------------------------------------------------
| Text Field
|--------------------------------------------------------------------------
*/

function huhs_text_field($post, $key, $label, $placeholder = '')
{
    $value = get_post_meta($post->ID, $key, true);
    ?>

    <p>
        <label for="<?php echo esc_attr($key); ?>">
            <strong><?php echo esc_html($label); ?></strong>
        </label>

        <input
            type="text"
            id="<?php echo esc_attr($key); ?>"
            name="<?php echo esc_attr($key); ?>"
            value="<?php echo esc_attr($value); ?>"
            placeholder="<?php echo esc_attr($placeholder); ?>"
            class="widefat">
    </p>

    <?php
}

/*
|--------------------------------------------------------------------------
| Textarea
|--------------------------------------------------------------------------
*/

function huhs_textarea_field($post, $key, $label, $rows = 5)
{
    $value = get_post_meta($post->ID, $key, true);
    ?>

    <p>
        <label>
            <strong><?php echo esc_html($label); ?></strong>
        </label>

        <textarea
            name="<?php echo esc_attr($key); ?>"
            rows="<?php echo intval($rows); ?>"
            class="widefat"><?php echo esc_textarea($value); ?></textarea>
    </p>

    <?php
}

/*
|--------------------------------------------------------------------------
| Date Field
|--------------------------------------------------------------------------
*/

function huhs_date_field($post, $key, $label)
{
    $value = get_post_meta($post->ID, $key, true);
    ?>

    <p>
        <label>
            <strong><?php echo esc_html($label); ?></strong>
        </label>

        <input
            type="date"
            name="<?php echo esc_attr($key); ?>"
            value="<?php echo esc_attr($value); ?>"
            class="widefat">
    </p>

    <?php
}

/*
|--------------------------------------------------------------------------
| Time Field
|--------------------------------------------------------------------------
*/

function huhs_time_field($post, $key, $label)
{
    $value = get_post_meta($post->ID, $key, true);
    ?>

    <p>
        <label>
            <strong><?php echo esc_html($label); ?></strong>
        </label>

        <input
            type="time"
            name="<?php echo esc_attr($key); ?>"
            value="<?php echo esc_attr($value); ?>"
            class="widefat">
    </p>

    <?php
}

/*
|--------------------------------------------------------------------------
| Checkbox
|--------------------------------------------------------------------------
*/

function huhs_checkbox_field($post, $key, $label)
{
    $value = get_post_meta($post->ID, $key, true);
    ?>

    <p>
        <label>
            <input
                type="checkbox"
                name="<?php echo esc_attr($key); ?>"
                value="1"
                <?php checked($value, 1); ?>>

            <?php echo esc_html($label); ?>
        </label>
    </p>

    <?php
}

/*
|--------------------------------------------------------------------------
| Select
|--------------------------------------------------------------------------
*/

function huhs_select_field($post, $key, $label, $options = array())
{
    $value = get_post_meta($post->ID, $key, true);
    ?>

    <p>

        <label>
            <strong><?php echo esc_html($label); ?></strong>
        </label>

        <select
            name="<?php echo esc_attr($key); ?>"
            class="widefat">

            <?php foreach ($options as $optionValue => $optionLabel) : ?>

                <option
                    value="<?php echo esc_attr($optionValue); ?>"
                    <?php selected($value, $optionValue); ?>>

                    <?php echo esc_html($optionLabel); ?>

                </option>

            <?php endforeach; ?>

        </select>

    </p>

    <?php
}

/*
|--------------------------------------------------------------------------
| Organizer Select
|--------------------------------------------------------------------------
*/

function huhs_organizer_field($post, $key, $label)
{
    $selected = get_post_meta($post->ID, $key, true);

    $organizers = get_posts(array(
        'post_type' => 'huhs_organizer',
        'post_status' => 'publish',
        'posts_per_page' => -1,
        'orderby' => 'title',
        'order' => 'ASC',
    ));

    ?>

    <p>

        <label>
            <strong><?php echo esc_html($label); ?></strong>
        </label>

        <select
            name="<?php echo esc_attr($key); ?>"
            class="widefat">

            <option value="">-- Válassz szervezőt --</option>

            <?php foreach ($organizers as $organizer) : ?>

                <option
                    value="<?php echo esc_attr($organizer->ID); ?>"
                    <?php selected($selected, $organizer->ID); ?>>

                    <?php echo esc_html($organizer->post_title); ?>

                </option>

            <?php endforeach; ?>

        </select>

    </p>

    <?php
}

/*
|--------------------------------------------------------------------------
| Artists Select
|--------------------------------------------------------------------------
*/

function huhs_artists_field($post, $key, $label)
{
    $selected = get_post_meta($post->ID, $key, true);

    if (is_string($selected)) {
        $selected = json_decode($selected, true);
    }

    if (!is_array($selected)) {
        $selected = array();
    }

    $selected = array_map('intval', $selected);

    $artists = get_posts(array(
        'post_type' => 'huhs_artist',
        'post_status' => 'publish',
        'posts_per_page' => -1,
        'orderby' => 'title',
        'order' => 'ASC',
    ));

    ?>

    <p>
        <strong><?php echo esc_html($label); ?></strong>
    </p>

    <div style="max-height:220px;overflow:auto;border:1px solid #ccd0d4;padding:10px;background:#fff;">

        <?php foreach ($artists as $artist) : ?>

            <label style="display:block;margin-bottom:8px;">

                <input
                    type="checkbox"
                    name="<?php echo esc_attr($key); ?>[]"
                    value="<?php echo esc_attr($artist->ID); ?>"
                    <?php checked(in_array((int)$artist->ID, $selected, true)); ?>>

                <?php echo esc_html($artist->post_title); ?>

            </label>

        <?php endforeach; ?>

    </div>

    <?php
}

/*
|--------------------------------------------------------------------------
| Genre Checkboxes
|--------------------------------------------------------------------------
*/

function huhs_genres_field($post, $key, $label)
{
    $selected = get_post_meta($post->ID, $key, true);

    if (!is_array($selected)) {
        $selected = array_filter(explode(',', (string)$selected));
    }

    $genres = huhs_genre_options();

    echo '<p><strong>' . esc_html($label) . '</strong></p>';

    foreach ($genres as $genre) {
        ?>

        <label class="huhs-genre-option">

            <input
                type="checkbox"
                name="<?php echo esc_attr($key); ?>[]"
                value="<?php echo esc_attr($genre); ?>"
                <?php checked(in_array($genre, $selected, true)); ?>>

            <?php echo esc_html($genre); ?>

        </label>

        <?php
    }
}

function huhs_genre_options()
{
    return array(
        'Hardstyle',
        'Rawstyle',
        'Euphoric',
        'Classic Hardstyle',
        'Reverse Bass',
          'Hardcore',
          'Happy Hardcore',
          'Uptempo',
        'Frenchcore',
        'Early Hardcore',
        'Techno',
        'Hard Techno',
    );
}

/*
|--------------------------------------------------------------------------
| Image Field
|--------------------------------------------------------------------------
*/

function huhs_image_field($post, $key, $label)
{
    $image_id = get_post_meta($post->ID, $key, true);

    $image = '';

    if ($image_id) {
        $image = wp_get_attachment_image_url($image_id, 'medium');
    }

    ?>

    <p>
        <strong><?php echo esc_html($label); ?></strong>
    </p>

    <div class="huhs-image-field">

        <img
            id="<?php echo esc_attr($key); ?>_preview"
            src="<?php echo esc_url($image); ?>"
            style="max-width:220px;display:block;margin-bottom:10px;">

        <input
            type="hidden"
            id="<?php echo esc_attr($key); ?>"
            name="<?php echo esc_attr($key); ?>"
            value="<?php echo esc_attr($image_id); ?>">

        <button
            type="button"
            class="button huhs-image-upload"
            data-target="<?php echo esc_attr($key); ?>">

            Kép kiválasztása

        </button>

    </div>

    <?php
}
