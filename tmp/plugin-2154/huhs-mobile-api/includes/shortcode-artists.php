<?php

if (!defined('ABSPATH')) {
    exit;
}

add_shortcode('huhs_djs', 'huhs_djs_shortcode');

function huhs_djs_shortcode($atts)
{
    $atts = shortcode_atts(array(
        'category' => '',
        'title'    => 'Magyar DJ-k',
    ), $atts, 'huhs_djs');

    $requested_category = sanitize_title($atts['category']);
    $query_args = array(
        'post_type'      => 'huhs_artist',
        'post_status'    => 'publish',
        'posts_per_page' => -1,
        'orderby'        => 'title',
        'order'          => 'ASC',
    );

    if ($requested_category !== '') {
        $query_args['tax_query'] = array(
            array(
                'taxonomy' => 'huhs_artist_category',
                'field'    => 'slug',
                'terms'    => $requested_category,
            ),
        );
    }

    $artists = get_posts($query_args);
    usort($artists, function ($left, $right) {
        $featured_compare = (int) get_post_meta($right->ID, 'featured', true)
            <=> (int) get_post_meta($left->ID, 'featured', true);

        return $featured_compare !== 0
            ? $featured_compare
            : strcasecmp($left->post_title, $right->post_title);
    });

    if (!$artists) {
        return '<p class="huhs-djs__empty">Jelenleg nincs megjeleníthető DJ ebben a kategóriában.</p>';
    }

    $groups = huhs_group_directory_artists($artists, $requested_category);

    ob_start();
    ?>
    <style>
        .huhs-djs{--huhs-red:#ef3b3a;--huhs-panel:#171717;--huhs-muted:#aaa;color:#f5f5f5;margin:32px auto;max-width:1180px}
        .huhs-djs__title{font-size:clamp(2rem,5vw,3.5rem);line-height:1.05;margin:0 0 34px}
        .huhs-djs__section{margin:0 0 46px}
        .huhs-djs__heading{align-items:center;display:flex;font-size:clamp(1.45rem,3vw,2rem);gap:14px;margin:0 0 20px}
        .huhs-djs__heading:after{background:linear-gradient(90deg,var(--huhs-red),transparent);content:"";height:2px;flex:1}
        .huhs-djs__grid{display:grid;gap:18px;grid-template-columns:repeat(auto-fill,minmax(220px,1fr))}
        .huhs-djs__card{background:var(--huhs-panel);border:1px solid rgba(255,255,255,.08);border-radius:16px;box-shadow:0 12px 30px rgba(0,0,0,.18);overflow:hidden;transition:transform .2s ease,border-color .2s ease}
        .huhs-djs__card:hover{border-color:rgba(239,59,58,.7);transform:translateY(-4px)}
        .huhs-djs__link{color:#fff!important;display:block;height:100%;text-decoration:none!important}
        .huhs-djs__image-wrap{aspect-ratio:1/1;background:#242424;overflow:hidden}
        .huhs-djs__image{height:100%;object-fit:cover;object-position:50% 25%;width:100%}
        .huhs-djs__placeholder{align-items:center;color:#777;display:flex;font-size:3rem;font-weight:900;height:100%;justify-content:center}
        .huhs-djs__body{padding:18px}
        .huhs-djs__name{font-size:1.25rem;line-height:1.2;margin:0 0 9px}
        .huhs-djs__meta{color:var(--huhs-muted);font-size:.92rem;line-height:1.45;margin:0 0 15px;min-height:1.4em}
        .huhs-djs__cta{color:var(--huhs-red);font-size:.9rem;font-weight:800;letter-spacing:.03em;text-transform:uppercase}
        @media (max-width:520px){.huhs-djs__grid{grid-template-columns:repeat(2,minmax(0,1fr));gap:12px}.huhs-djs__body{padding:14px}.huhs-djs__name{font-size:1.05rem}}
    </style>
    <div class="huhs-djs">
        <?php if ($atts['title'] !== '') : ?><h2 class="huhs-djs__title"><?php echo esc_html($atts['title']); ?></h2><?php endif; ?>

        <?php foreach ($groups as $group) : ?>
            <section class="huhs-djs__section">
                <?php if ($group['title'] !== '') : ?><h3 class="huhs-djs__heading"><?php echo esc_html($group['title']); ?></h3><?php endif; ?>
                <div class="huhs-djs__grid">
                    <?php foreach ($group['artists'] as $artist) : ?>
                        <?php echo huhs_render_artist_directory_card($artist); ?>
                    <?php endforeach; ?>
                </div>
            </section>
        <?php endforeach; ?>
    </div>
    <?php

    return ob_get_clean();
}

function huhs_group_directory_artists($artists, $requested_category)
{
    if ($requested_category !== '') {
        $term = get_term_by('slug', $requested_category, 'huhs_artist_category');
        return array(array(
            'title'   => $term && !is_wp_error($term) ? $term->name : '',
            'artists' => $artists,
        ));
    }

    $groups = array();
    $term_order = array('hardstyle', 'hardcore');
    $all_terms = get_terms(array(
        'taxonomy'   => 'huhs_artist_category',
        'hide_empty' => true,
    ));

    if (!is_wp_error($all_terms)) {
        usort($all_terms, function ($left, $right) use ($term_order) {
            $left_index = array_search($left->slug, $term_order, true);
            $right_index = array_search($right->slug, $term_order, true);
            $left_index = $left_index === false ? PHP_INT_MAX : $left_index;
            $right_index = $right_index === false ? PHP_INT_MAX : $right_index;
            return $left_index === $right_index
                ? strcasecmp($left->name, $right->name)
                : $left_index <=> $right_index;
        });

        foreach ($all_terms as $term) {
            $term_artists = array_values(array_filter($artists, function ($artist) use ($term) {
                return has_term($term->term_id, 'huhs_artist_category', $artist);
            }));

            if ($term_artists) {
                $groups[] = array('title' => $term->name, 'artists' => $term_artists);
            }
        }
    }

    $uncategorized = array_values(array_filter($artists, function ($artist) {
        $terms = get_the_terms($artist->ID, 'huhs_artist_category');
        return !$terms || is_wp_error($terms);
    }));

    if ($uncategorized) {
        $groups[] = array('title' => 'További DJ-k', 'artists' => $uncategorized);
    }

    return $groups;
}

function huhs_render_artist_directory_card($artist)
{
    $image_id = (int) get_post_meta($artist->ID, 'hero_image', true);
    $image_url = $image_id ? wp_get_attachment_image_url($image_id, 'medium_large') : '';
    if (!$image_url) {
        $image_url = get_the_post_thumbnail_url($artist->ID, 'medium_large');
    }
    if (!$image_url) {
        $image_id = (int) get_post_meta($artist->ID, 'logo', true);
        $image_url = $image_id ? wp_get_attachment_image_url($image_id, 'medium_large') : '';
    }

    $genres = get_post_meta($artist->ID, 'genre', true);
    if (is_array($genres)) {
        $genres = implode(', ', $genres);
    }
    $location = array_filter(array(
        get_post_meta($artist->ID, 'city', true),
        get_post_meta($artist->ID, 'country', true),
    ));
    $meta = $genres ?: implode(', ', $location);

    ob_start();
    ?>
    <article class="huhs-djs__card">
        <a class="huhs-djs__link" href="<?php echo esc_url(get_permalink($artist->ID)); ?>">
            <div class="huhs-djs__image-wrap">
                <?php if ($image_url) : ?>
                    <img class="huhs-djs__image" src="<?php echo esc_url($image_url); ?>" alt="<?php echo esc_attr($artist->post_title); ?>" loading="lazy">
                <?php else : ?>
                    <div class="huhs-djs__placeholder" aria-hidden="true">HUHS</div>
                <?php endif; ?>
            </div>
            <div class="huhs-djs__body">
                <h4 class="huhs-djs__name"><?php echo esc_html($artist->post_title); ?></h4>
                <p class="huhs-djs__meta"><?php echo esc_html($meta); ?></p>
                <span class="huhs-djs__cta">Adatlap megnyitása →</span>
            </div>
        </a>
    </article>
    <?php

    return ob_get_clean();
}
