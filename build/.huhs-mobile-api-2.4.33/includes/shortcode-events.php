<?php

if (!defined('ABSPATH')) {
    exit;
}

add_shortcode('huhs_events', 'huhs_events_shortcode');

function huhs_events_shortcode($atts)
{
    $atts = shortcode_atts(array(
        'title'        => 'Események',
        'limit'        => '-1',
        'include_past' => 'false',
    ), $atts, 'huhs_events');

    $limit = (int) $atts['limit'];
    $limit = $limit > 0 ? min($limit, 100) : -1;
    $include_past = filter_var($atts['include_past'], FILTER_VALIDATE_BOOLEAN);
    $meta_query = array(
        array(
            'key'     => 'visible',
            'value'   => '1',
            'compare' => '=',
        ),
    );

    if (!$include_past) {
        $meta_query[] = array(
            'key'     => 'event_start_date',
            'value'   => current_time('Y-m-d'),
            'compare' => '>=',
            'type'    => 'DATE',
        );
    }

    $events = get_posts(array(
        'post_type'      => 'huhs_event',
        'post_status'    => 'publish',
        'posts_per_page' => $limit,
        'meta_key'       => 'event_start_date',
        'orderby'        => 'meta_value',
        'order'          => 'ASC',
        'meta_query'     => $meta_query,
    ));

    if (!$events) {
        return '<p class="huhs-events__empty">Jelenleg nincs megjeleníthető esemény.</p>';
    }

    ob_start();
    ?>
    <style>
        .huhs-events{--huhs-red:#ef3b3a;--huhs-panel:#171717;--huhs-muted:#aaa;color:#f5f5f5;margin:32px auto;max-width:1180px}
        .huhs-events__title{font-size:clamp(2rem,5vw,3.5rem);line-height:1.05;margin:0 0 34px}
        .huhs-events__grid{display:grid;gap:22px;grid-template-columns:repeat(auto-fill,minmax(280px,1fr))}
        .huhs-event-card{background:var(--huhs-panel);border:1px solid rgba(255,255,255,.08);border-radius:18px;box-shadow:0 14px 34px rgba(0,0,0,.2);display:flex;flex-direction:column;overflow:hidden;transition:transform .2s ease,border-color .2s ease}
        .huhs-event-card:hover{border-color:rgba(239,59,58,.7);transform:translateY(-4px)}
        .huhs-event-card__image-link{aspect-ratio:16/10;background:#242424;display:block;overflow:hidden;position:relative}
        .huhs-event-card__image{height:100%;object-fit:cover;width:100%}
        .huhs-event-card__placeholder{align-items:center;color:#777;display:flex;font-size:2rem;font-weight:900;height:100%;justify-content:center}
        .huhs-event-card__badge{background:var(--huhs-red);border-radius:999px;color:#fff;font-size:.75rem;font-weight:800;left:14px;padding:7px 11px;position:absolute;text-transform:uppercase;top:14px}
        .huhs-event-card__body{display:flex;flex:1;flex-direction:column;padding:20px}
        .huhs-event-card__title{font-size:1.3rem;line-height:1.25;margin:0 0 16px}
        .huhs-event-card__title a{color:#fff!important;text-decoration:none!important}
        .huhs-event-card__genres{display:flex;flex-wrap:wrap;gap:6px;margin:0 0 16px}
        .huhs-event-card__genre{background:rgba(239,59,58,.12);border:1px solid rgba(239,59,58,.4);border-radius:999px;color:#f5b0b0;font-size:.78rem;font-weight:700;padding:5px 9px}
        .huhs-event-card__facts{color:var(--huhs-muted);display:grid;gap:8px;font-size:.95rem;margin:0 0 16px}
        .huhs-event-card__fact{align-items:flex-start;display:flex;gap:9px}
        .huhs-event-card__description{color:#ddd;line-height:1.55;margin:0 0 20px}
        .huhs-event-card__actions{display:flex;flex-wrap:wrap;gap:10px;margin-top:auto}
        .huhs-event-card__button{background:var(--huhs-red);border-radius:9px;color:#fff!important;display:inline-block;font-size:.9rem;font-weight:800;padding:10px 14px;text-decoration:none!important}
        .huhs-event-card__button--secondary{background:#292929;border:1px solid rgba(255,255,255,.12)}
        @media (max-width:520px){.huhs-events__grid{grid-template-columns:1fr}.huhs-event-card__body{padding:17px}}
    </style>
    <div class="huhs-events">
        <?php if ($atts['title'] !== '') : ?><h2 class="huhs-events__title"><?php echo esc_html($atts['title']); ?></h2><?php endif; ?>
        <div class="huhs-events__grid">
            <?php foreach ($events as $event) : ?>
                <?php echo huhs_render_event_directory_card($event); ?>
            <?php endforeach; ?>
        </div>
    </div>
    <?php

    return ob_get_clean();
}

function huhs_render_event_directory_card($event)
{
    $flyer_id = (int) get_post_meta($event->ID, 'flyer_image', true);
    $flyer = $flyer_id ? wp_get_attachment_image_url($flyer_id, 'large') : '';
    if (!$flyer) {
        $flyer = get_the_post_thumbnail_url($event->ID, 'large');
    }

    $start_date = get_post_meta($event->ID, 'event_start_date', true);
    $start_time = get_post_meta($event->ID, 'event_start_time', true);
    $venue_name = get_post_meta($event->ID, 'venue_name', true);
    $venue_city = get_post_meta($event->ID, 'venue_city', true);
    $ticket = get_post_meta($event->ID, 'ticket_url', true);
    $is_featured = (bool) get_post_meta($event->ID, 'featured', true);
    $permalink = get_permalink($event->ID);
    $venue = implode(', ', array_filter(array($venue_name, $venue_city)));
    $description = wp_trim_words(wp_strip_all_tags($event->post_content), 24);
    $genre_value = get_post_meta($event->ID, 'genre', true);
    $genres = is_array($genre_value) ? $genre_value : explode(',', (string) $genre_value);
    $genres = array_values(array_unique(array_filter(array_map('trim', $genres))));

    ob_start();
    ?>
    <article class="huhs-event-card">
        <a class="huhs-event-card__image-link" href="<?php echo esc_url($permalink); ?>">
            <?php if ($flyer) : ?>
                <img class="huhs-event-card__image" src="<?php echo esc_url($flyer); ?>" alt="<?php echo esc_attr($event->post_title); ?>" loading="lazy">
            <?php else : ?>
                <div class="huhs-event-card__placeholder" aria-hidden="true">HUHS EVENT</div>
            <?php endif; ?>
            <?php if ($is_featured) : ?><span class="huhs-event-card__badge">Kiemelt esemény</span><?php endif; ?>
        </a>
        <div class="huhs-event-card__body">
            <h3 class="huhs-event-card__title"><a href="<?php echo esc_url($permalink); ?>"><?php echo esc_html($event->post_title); ?></a></h3>
            <?php if ($genres) : ?><div class="huhs-event-card__genres" aria-label="Műfajok / stílusok"><?php foreach ($genres as $genre) : ?><span class="huhs-event-card__genre"><?php echo esc_html($genre); ?></span><?php endforeach; ?></div><?php endif; ?>
            <div class="huhs-event-card__facts">
                <?php if ($start_date) : ?><div class="huhs-event-card__fact"><span aria-hidden="true">📅</span><span><?php echo esc_html(huhs_event_directory_date($start_date)); ?><?php echo $start_time ? ' · ' . esc_html($start_time) : ''; ?></span></div><?php endif; ?>
                <?php if ($venue) : ?><div class="huhs-event-card__fact"><span aria-hidden="true">📍</span><span><?php echo esc_html($venue); ?></span></div><?php endif; ?>
            </div>
            <?php if ($description) : ?><p class="huhs-event-card__description"><?php echo esc_html($description); ?></p><?php endif; ?>
            <div class="huhs-event-card__actions">
                <a class="huhs-event-card__button" href="<?php echo esc_url($permalink); ?>">Részletek</a>
                <?php if ($ticket) : ?><a class="huhs-event-card__button huhs-event-card__button--secondary" href="<?php echo esc_url($ticket); ?>" target="_blank" rel="noopener">Jegyvásárlás</a><?php endif; ?>
            </div>
        </div>
    </article>
    <?php

    return ob_get_clean();
}

function huhs_event_directory_date($value)
{
    $timestamp = strtotime($value . ' 12:00:00');
    return $timestamp ? wp_date('Y. F j.', $timestamp) : $value;
}
