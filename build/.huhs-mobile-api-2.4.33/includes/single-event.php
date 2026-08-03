<?php

if (!defined('ABSPATH')) {
    exit;
}

add_filter('the_content', 'huhs_render_single_event_content', 20);

function huhs_render_single_event_content($content)
{
    if (!is_singular('huhs_event') || !in_the_loop() || !is_main_query()) {
        return $content;
    }

    $event_id = get_the_ID();
    $flyer_id = (int) get_post_meta($event_id, 'flyer_image', true);
    $organizer_id = (int) get_post_meta($event_id, 'organizer_id', true);
    $artist_ids = json_decode(get_post_meta($event_id, 'artists', true), true);
    $artist_ids = is_array($artist_ids) ? array_map('intval', $artist_ids) : array();

    $date = trim(get_post_meta($event_id, 'event_start_date', true));
    $time = trim(get_post_meta($event_id, 'event_start_time', true));
    $venue = array_filter(array(
        get_post_meta($event_id, 'venue_name', true),
        get_post_meta($event_id, 'venue_zip', true),
        get_post_meta($event_id, 'venue_city', true),
        get_post_meta($event_id, 'venue_address', true),
    ));
    $ticket_url = get_post_meta($event_id, 'ticket_url', true);
    $maps_url = get_post_meta($event_id, 'google_maps', true);
    if (!$maps_url) {
        $maps_url = huhs_event_maps_url($venue);
    }
    $genre_value = get_post_meta($event_id, 'genre', true);
    $genres = is_array($genre_value) ? $genre_value : explode(',', (string) $genre_value);
    $genres = array_values(array_unique(array_filter(array_map('trim', $genres))));

    ob_start();
    ?>
    <style>
        .huhs-single-event{max-width:960px;margin:0 auto;color:inherit}
        .huhs-single-event__flyer{width:100%;height:auto;display:block;border-radius:16px;margin:0 0 28px}
        .huhs-single-event__meta{padding:20px 22px;margin:0 0 26px;background:rgba(128,128,128,.10);border-radius:14px}
        .huhs-single-event__meta p{margin:8px 0}
        .huhs-single-event__section{margin:26px 0}
        .huhs-single-event__names{display:flex;flex-wrap:wrap;gap:8px;margin:10px 0 0;padding:0;list-style:none}
        .huhs-single-event__names li{padding:8px 12px;border-radius:999px;background:rgba(214,0,0,.12);border:1px solid rgba(214,0,0,.35)}
        .huhs-single-event__genres{display:flex;flex-wrap:wrap;gap:8px;margin:10px 0 0;padding:0;list-style:none}
        .huhs-single-event__genres li{padding:8px 12px;border-radius:999px;background:rgba(214,0,0,.12);border:1px solid rgba(214,0,0,.35)}
        .huhs-single-event__buttons{display:flex;flex-wrap:wrap;gap:12px;margin:26px 0}
        .huhs-single-event__button{display:inline-block;padding:12px 18px;border-radius:9px;background:#d60000;color:#fff!important;text-decoration:none;font-weight:700}
    </style>
    <div class="huhs-single-event">
        <?php if ($flyer_id) : ?>
            <?php echo wp_get_attachment_image($flyer_id, 'large', false, array('class' => 'huhs-single-event__flyer')); ?>
        <?php endif; ?>

        <div class="huhs-single-event__meta">
            <?php if ($date) : ?><p><strong>📅 Dátum:</strong> <?php echo esc_html(trim($date . ' ' . $time)); ?></p><?php endif; ?>
            <?php if ($venue) : ?><p><strong>📍 Helyszín:</strong> <?php echo esc_html(implode(', ', $venue)); ?></p><?php endif; ?>
            <?php if ($organizer_id) : ?><p><strong>👥 Szervező:</strong> <a href="<?php echo esc_url(get_permalink($organizer_id)); ?>"><?php echo esc_html(get_the_title($organizer_id)); ?></a></p><?php endif; ?>
        </div>

        <?php if ($genres) : ?>
            <section class="huhs-single-event__section">
                <h2>Műfajok / stílusok</h2>
                <ul class="huhs-single-event__genres">
                    <?php foreach ($genres as $genre) : ?>
                        <li><?php echo esc_html($genre); ?></li>
                    <?php endforeach; ?>
                </ul>
            </section>
        <?php endif; ?>

        <div class="huhs-single-event__description"><?php echo $content; ?></div>

        <?php if ($artist_ids) : ?>
            <section class="huhs-single-event__section">
                <h2>Fellépők</h2>
                <ul class="huhs-single-event__names">
                    <?php foreach ($artist_ids as $artist_id) : ?>
                        <li><a href="<?php echo esc_url(get_permalink($artist_id)); ?>"><?php echo esc_html(get_the_title($artist_id)); ?></a></li>
                    <?php endforeach; ?>
                </ul>
            </section>
        <?php endif; ?>

        <?php if ($ticket_url || $maps_url) : ?>
            <div class="huhs-single-event__buttons">
                <?php if ($ticket_url) : ?><a class="huhs-single-event__button" href="<?php echo esc_url($ticket_url); ?>" target="_blank" rel="noopener">🎟 Jegyek</a><?php endif; ?>
                <?php if ($maps_url) : ?><a class="huhs-single-event__button" href="<?php echo esc_url($maps_url); ?>" target="_blank" rel="noopener">📍 Google Maps</a><?php endif; ?>
            </div>
        <?php endif; ?>
    </div>
    <?php

    return ob_get_clean();
}
