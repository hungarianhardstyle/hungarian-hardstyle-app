<?php
/**
 * Plugin Name: HUHS Release Catalog
 * Description: Designos, nyilvános HUHS release-katalógus a mobil API alapján.
 * Version: 1.3.0
 * Author: Hungarian Hardstyle
 */

if (!defined('ABSPATH')) exit;

/**
 * Allow a CDN/browser to reuse public HUHS API responses. The API remains
 * authoritative; short max-age values prevent release/news changes from
 * being hidden for long while avoiding repeated cold requests.
 */
function huhs_release_catalog_rest_cache_headers($response, $server, $request) {
    if ($request->get_method() !== 'GET') return $response;
    $route = (string) $request->get_route();
    if (strpos($route, '/huhs/v1/') !== 0) return $response;

    $seconds = (strpos($route, '/posts') !== false || strpos($route, '/events') !== false)
        ? 45
        : 300;
    $response->header('Cache-Control', 'public, max-age=' . $seconds . ', stale-while-revalidate=60');
    $response->header('Vary', 'Accept-Encoding');
    return $response;
}
add_filter('rest_post_dispatch', 'huhs_release_catalog_rest_cache_headers', 10, 3);

function huhs_release_catalog_app_url($release_id) {
    $store_url = 'https://play.google.com/store/apps/details?id=hu.hungarianhardstyle.app';
    return apply_filters('huhs_release_catalog_app_url', $store_url, (int) $release_id);
}

function huhs_release_catalog_get_releases() {
    $cached = get_transient('huhs_release_catalog_items');
    if (is_array($cached)) return $cached;

    $response = wp_remote_get(rest_url('huhs/v1/releases'), array(
        'timeout' => 10,
        'headers' => array('Accept' => 'application/json'),
    ));
    if (is_wp_error($response) || wp_remote_retrieve_response_code($response) < 200 || wp_remote_retrieve_response_code($response) >= 300) {
        return array();
    }
    $body = json_decode(wp_remote_retrieve_body($response), true);
    $items = is_array($body['items'] ?? null) ? $body['items'] : array();
    set_transient('huhs_release_catalog_items', $items, MINUTE_IN_SECONDS);
    return $items;
}

function huhs_release_catalog_price($value) {
    $price = preg_replace('/[^0-9]/', '', (string) $value);
    return $price === '' ? '' : number_format_i18n((int) $price) . ' Ft';
}

function huhs_release_catalog_is_free($release) {
    return !empty($release['is_free']) || !empty($release['isFree']);
}

function huhs_release_catalog_section($title, $items, $free = false) {
    if (!$items) return '';

    ob_start();
    ?>
    <section class="huhs-release-section <?php echo $free ? 'huhs-release-section--free' : 'huhs-release-section--paid'; ?>">
        <h2 class="huhs-release-section__title"><?php echo esc_html($title); ?></h2>
        <div class="huhs-release-grid">
            <?php foreach ($items as $release) :
                $release_id = absint($release['id'] ?? 0);
                $title_text = sanitize_text_field($release['title'] ?? 'HUHS release');
                $cover = esc_url($release['cover'] ?? '');
                $artists = array();
                foreach ((array) ($release['artists'] ?? array()) as $artist) {
                    $name = sanitize_text_field($artist['name'] ?? '');
                    if ($name !== '') $artists[] = $name;
                }
                $genre = sanitize_text_field($release['genre'] ?? '');
                $date = sanitize_text_field($release['release_date'] ?? '');
                $products = array();
                if (!$free) {
                    foreach ((array) ($release['products'] ?? array()) as $product) {
                        $id = sanitize_text_field($product['id'] ?? '');
                        $type = sanitize_key($product['type'] ?? '');
                        $price = huhs_release_catalog_price($product['price'] ?? '');
                        if ($id !== '' && $price !== '') {
                            $products[$type] = array(
                                'label' => sanitize_text_field($product['label'] ?? $type),
                                'price' => $price,
                            );
                        }
                    }
                }
                $app_url = huhs_release_catalog_app_url($release_id);
                ?>
                <article class="huhs-release-card">
                    <a class="huhs-release-card__image-link" href="<?php echo esc_url($app_url); ?>" target="_blank" rel="noopener">
                        <?php if ($cover) : ?><img class="huhs-release-card__cover" src="<?php echo $cover; ?>" alt="<?php echo esc_attr($title_text); ?>" loading="lazy"><?php endif; ?>
                    </a>
                    <div class="huhs-release-card__content">
                        <h3 class="huhs-release-card__title"><a href="<?php echo esc_url($app_url); ?>" target="_blank" rel="noopener"><?php echo esc_html($title_text); ?></a></h3>
                        <?php if ($artists) : ?><p class="huhs-release-card__artists"><?php echo esc_html(implode(' · ', $artists)); ?></p><?php endif; ?>
                        <div class="huhs-release-card__facts">
                            <?php if ($date) : ?><span><?php echo esc_html($date); ?></span><?php endif; ?>
                            <?php if ($genre) : ?><span><?php echo esc_html($genre); ?></span><?php endif; ?>
                        </div>
                        <?php if ($free) : ?>
                            <p class="huhs-release-card__availability">Ingyenesen elérhető</p>
                        <?php elseif ($products) : ?>
                            <div class="huhs-release-card__products">
                                <?php foreach ($products as $product) : ?>
                                    <span><?php echo esc_html($product['label']); ?> <strong><?php echo esc_html($product['price']); ?></strong></span>
                                <?php endforeach; ?>
                            </div>
                            <small class="huhs-release-card__vat">Az ár bruttó, az ÁFÁ-t tartalmazza.</small>
                        <?php else : ?>
                            <p class="huhs-release-card__availability">A vásárlás az alkalmazásban érhető el.</p>
                        <?php endif; ?>
                        <a class="huhs-release-card__button" href="<?php echo esc_url($app_url); ?>" target="_blank" rel="noopener">Megnyitás az appban <span aria-hidden="true">→</span></a>
                    </div>
                </article>
            <?php endforeach; ?>
        </div>
    </section>
    <?php
    return ob_get_clean();
}

function huhs_release_catalog_shortcode($atts) {
    $atts = shortcode_atts(array('limit' => 0), $atts, 'huhs_release_catalog');
    $items = huhs_release_catalog_get_releases();
    $limit = absint($atts['limit']);
    if ($limit > 0) $items = array_slice($items, 0, $limit);

    $free_items = array_values(array_filter($items, 'huhs_release_catalog_is_free'));
    $paid_items = array_values(array_filter($items, function ($release) {
        return !huhs_release_catalog_is_free($release);
    }));
    ob_start();
    ?>
    <div class="huhs-release-catalog">
        <?php if (!$items) : ?>
            <p class="huhs-release-catalog__empty">A kiadványok jelenleg nem tölthetők be.</p>
        <?php else : ?>
            <?php echo huhs_release_catalog_section('Fizetős kiadványok', $paid_items); ?>
            <?php echo huhs_release_catalog_section('Ingyenes kiadványok', $free_items, true); ?>
        <?php endif; ?>
    </div>
    <?php
    return ob_get_clean();
}
add_shortcode('huhs_release_catalog', 'huhs_release_catalog_shortcode');

function huhs_release_catalog_body_class($classes) {
    if (is_singular() && has_shortcode((string) get_post_field('post_content', get_queried_object_id()), 'huhs_release_catalog')) {
        $classes[] = 'huhs-release-catalog-page';
    }
    return $classes;
}
add_filter('body_class', 'huhs_release_catalog_body_class');

function huhs_release_catalog_styles() {
    if (!has_shortcode((string) get_post_field('post_content', get_queried_object_id()), 'huhs_release_catalog')) return;
    wp_register_style('huhs-release-catalog', false);
    wp_enqueue_style('huhs-release-catalog');
    wp_add_inline_style('huhs-release-catalog', '.huhs-release-catalog-page .google-auto-placed,.huhs-release-catalog-page ins.adsbygoogle{display:none!important}.huhs-release-catalog{max-width:1180px;margin:28px auto;color:#f5f5f5}.huhs-release-section{margin:0 0 42px}.huhs-release-section__title{margin:0 0 18px;color:#f2383d;font-size:clamp(24px,3vw,34px);line-height:1.2}.huhs-release-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(280px,1fr));gap:24px}.huhs-release-card{display:flex!important;min-width:0;min-height:590px!important;overflow:hidden;flex-direction:column;border:1px solid #642b2b!important;border-radius:18px;background:#171717!important;box-shadow:0 8px 24px rgba(80,0,0,.22);color:#f5f5f5;padding:0!important}.huhs-release-card__image-link{display:block;aspect-ratio:16/10;overflow:hidden;background:#242424}.huhs-release-card__cover{display:block;width:100%;height:100%;object-fit:cover}.huhs-release-card__content{display:flex;min-width:0;flex:1;flex-direction:column;padding:20px}.huhs-release-card__title{display:-webkit-box;min-height:52px;margin:0 0 12px;font-size:21px;line-height:1.25;overflow:hidden;-webkit-box-orient:vertical;-webkit-line-clamp:2}.huhs-release-card__title a{color:#f5f5f5!important;text-decoration:none}.huhs-release-card__artists{display:-webkit-box;min-height:24px;margin:0 0 12px;color:#c3baba;overflow:hidden;-webkit-box-orient:vertical;-webkit-line-clamp:1}.huhs-release-card__facts{display:flex;flex-wrap:wrap;gap:8px;min-height:28px;margin-bottom:16px;color:#aaa;font-size:14px}.huhs-release-card__facts span{border-left:2px solid #f2383d;padding-left:8px}.huhs-release-card__products{display:grid;gap:7px;margin:0 0 7px}.huhs-release-card__products span{display:flex;justify-content:space-between;gap:12px;border-bottom:1px solid #3a2929;padding:6px 0;color:#d7cccc;font-size:14px}.huhs-release-card__products strong{color:#ff5959;white-space:nowrap}.huhs-release-card__vat,.huhs-release-card__availability{margin:0;color:#aaa;font-size:14px}.huhs-release-card__button{align-self:flex-start;margin-top:auto;border-radius:10px;background:#f2383d;padding:11px 16px;color:#160606;text-decoration:none;font-weight:700}.huhs-release-card__button span{margin-left:8px}.huhs-release-catalog__empty{padding:20px;border:1px solid #642b2b;border-radius:18px;background:#171717}@media(max-width:620px){.huhs-release-catalog{margin:22px 0}.huhs-release-grid{grid-template-columns:1fr;gap:18px}.huhs-release-card{min-height:0!important}.huhs-release-card__image-link{aspect-ratio:16/9}.huhs-release-card__content{min-height:300px;padding:18px}.huhs-release-card__button{width:100%;box-sizing:border-box;text-align:center}}');
}
add_action('wp_enqueue_scripts', 'huhs_release_catalog_styles');
