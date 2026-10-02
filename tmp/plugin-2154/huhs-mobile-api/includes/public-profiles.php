<?php

if (!defined('ABSPATH')) {
    exit;
}

add_action('init', 'huhs_flush_profile_rewrites_once', 99);

function huhs_flush_profile_rewrites_once()
{
    if (get_option('huhs_profile_rewrite_version') === HUHS_API_VERSION) {
        return;
    }

    flush_rewrite_rules(false);
    update_option('huhs_profile_rewrite_version', HUHS_API_VERSION, false);
}

add_filter('the_content', 'huhs_render_public_profile_content', 20);

function huhs_render_public_profile_content($content)
{
    if (!is_singular(array('huhs_artist', 'huhs_organizer')) || !in_the_loop() || !is_main_query()) {
        return $content;
    }

    $profile_id = get_the_ID();
    $is_artist = get_post_type($profile_id) === 'huhs_artist';
    $image_id = (int) get_post_meta($profile_id, $is_artist ? 'hero_image' : 'logo', true);
    $logo_id = $is_artist ? (int) get_post_meta($profile_id, 'logo', true) : 0;
    $logo_url = $is_artist ? esc_url_raw(get_post_meta($profile_id, 'logo_url', true)) : '';

    if (!$image_id) {
        $image_id = get_post_thumbnail_id($profile_id);
    }

    $fields = $is_artist
        ? array('real_name' => 'Valódi név', 'genre' => 'Műfajok', 'city' => 'Város', 'country' => 'Ország')
        : array('city' => 'Város', 'country' => 'Ország');

    $links = $is_artist
        ? array('website' => 'Weboldal', 'facebook' => 'Facebook', 'instagram' => 'Instagram', 'tiktok' => 'TikTok', 'spotify' => 'Spotify', 'soundcloud' => 'SoundCloud', 'youtube' => 'YouTube')
        : array('website' => 'Weboldal', 'facebook' => 'Facebook', 'instagram' => 'Instagram', 'tiktok' => 'TikTok');

    ob_start();
    ?>
    <style>
        .huhs-profile{max-width:900px;margin:0 auto}
        .huhs-profile__image{width:100%;height:auto;display:block;border-radius:16px;margin:0 0 26px}
        .huhs-profile__logo{width:96px;height:96px;object-fit:contain;border-radius:14px;background:#171717;padding:8px;margin:0 0 24px}
        .huhs-profile__facts{padding:18px 22px;margin:0 0 24px;border-radius:14px;background:rgba(128,128,128,.10)}
        .huhs-profile__facts p{margin:7px 0}
        .huhs-profile__links{display:flex;flex-wrap:wrap;gap:10px;margin:26px 0}
        .huhs-profile__link{display:inline-block;padding:10px 15px;border-radius:8px;background:#d60000;color:#fff!important;text-decoration:none;font-weight:700}
    </style>
    <div class="huhs-profile">
        <?php if ($image_id) : ?><?php echo wp_get_attachment_image($image_id, 'large', false, array('class' => 'huhs-profile__image')); ?><?php endif; ?>
        <?php if ($is_artist && ($logo_id || $logo_url)) : ?>
            <?php if ($logo_id) : ?>
                <?php echo wp_get_attachment_image($logo_id, 'medium', false, array('class' => 'huhs-profile__logo')); ?>
            <?php else : ?>
                <img class="huhs-profile__logo" src="<?php echo esc_url($logo_url); ?>" alt="<?php echo esc_attr(get_the_title($profile_id)); ?> logó">
            <?php endif; ?>
        <?php endif; ?>

        <div class="huhs-profile__facts">
            <?php if ($is_artist) : ?>
                <?php $category_terms = get_the_terms($profile_id, 'huhs_artist_category'); ?>
                <?php if (is_array($category_terms) && $category_terms) : ?>
                    <p><strong>Kategória:</strong> <?php echo esc_html(implode(', ', wp_list_pluck($category_terms, 'name'))); ?></p>
                <?php endif; ?>
            <?php endif; ?>
            <?php foreach ($fields as $key => $label) : ?>
                <?php $value = get_post_meta($profile_id, $key, true); ?>
                <?php if (is_array($value)) { $value = implode(', ', $value); } ?>
                <?php if ($value) : ?><p><strong><?php echo esc_html($label); ?>:</strong> <?php echo esc_html($value); ?></p><?php endif; ?>
            <?php endforeach; ?>
        </div>

        <div class="huhs-profile__description"><?php echo $content; ?></div>

        <div class="huhs-profile__links">
            <?php foreach ($links as $key => $label) : ?>
                <?php $url = get_post_meta($profile_id, $key, true); ?>
                <?php if ($url) : ?><a class="huhs-profile__link" href="<?php echo esc_url($url); ?>" target="_blank" rel="noopener"><?php echo esc_html($label); ?></a><?php endif; ?>
            <?php endforeach; ?>
        </div>

        <?php $booking_via_huhs = $is_artist && get_post_meta($profile_id, 'booking_via_huhs', true); ?>
        <?php $booking_email = $booking_via_huhs ? 'info@hungarianhardstyle.hu' : sanitize_email(get_post_meta($profile_id, 'booking_email', true)); ?>
        <?php if ($is_artist && $booking_email) : ?>
            <div class="huhs-profile__facts">
                <p><strong><?php echo $booking_via_huhs ? 'Fellépés szervezése a Hungarian Hardstyle-on keresztül' : 'Fellépés kérése'; ?>:</strong> <a href="mailto:<?php echo esc_attr($booking_email); ?>"><?php echo esc_html($booking_email); ?></a></p>
            </div>
        <?php endif; ?>
    </div>
    <?php

    return ob_get_clean();
}
