<?php

if (!defined('ABSPATH')) {
    exit;
}

add_action('rest_api_init', function () {

    register_rest_route('huhs/v1', '/posts', array(
        'methods'             => 'GET',
        'callback'            => 'huhs_get_posts',
        'permission_callback' => '__return_true',
    ));

    register_rest_route('huhs/v1', '/posts/(?P<id>\d+)', array(
        'methods' => 'GET',
        'callback' => 'huhs_get_post_detail',
        'permission_callback' => '__return_true',
    ));

    register_rest_route('huhs/v1', '/posts/(?P<id>\d+)/view', array(
        'methods'             => 'POST',
        'callback'            => 'huhs_record_post_view',
        'permission_callback' => '__return_true',
    ));

});

function huhs_record_post_view(WP_REST_Request $request)
{
    $post_id = absint($request['id']);
    $post = get_post($post_id);

    if (!$post || $post->post_type !== 'post' || $post->post_status !== 'publish') {
        return new WP_Error('post_not_found', 'A hír nem található.', array('status' => 404));
    }

    // Use the already-installed Post Views Counter integration so the app
    // contributes to the same admin eye statistic as the website.
    if (!function_exists('pvc_view_post')) {
        return new WP_Error(
            'view_counter_unavailable',
            'A megtekintésszámláló nem érhető el.',
            array('status' => 503)
        );
    }

    pvc_view_post($post_id);

    return new WP_REST_Response(array(
        'id'      => $post_id,
        'recorded' => true,
    ), 200);
}

function huhs_get_post_detail(WP_REST_Request $request)
{
    $post = get_post(absint($request['id']));
    if (!$post || $post->post_type !== 'post' || $post->post_status !== 'publish') {
        return new WP_Error('post_not_found', 'A hír nem található.', array('status' => 404));
    }

    return new WP_REST_Response(huhs_build_post($post, true, huhs_request_lang($request)), 200);
}

function huhs_build_post($post, $include_related = true, $lang = 'hu')
{
    $translation = huhs_post_language_payload($post, $lang);

    return array(

        'id' => (int)$post->ID,

        'title' => $translation['title'],

        'date' => huhs_format_date($post->post_date),

        'is_sticky' => is_sticky($post->ID),

        'excerpt' => $translation['excerpt'],

        'content' => $translation['content'],

        // Nyelvjelző: `true` csak akkor, ha a cím és a törzs is angolul jött.
        // Magyar kérésnél (és hiányzó `lang`-nál) mindig `false`.
        'has_en' => $translation['has_en'],

        'featured_image' => huhs_featured_image($post->ID),

        'link' => get_permalink($post->ID),

        'category_ids' => wp_get_post_categories($post->ID),

        'categories' => wp_get_post_terms($post->ID, 'category', array('fields' => 'names')),

        'tags' => wp_get_post_terms($post->ID, 'post_tag', array('fields' => 'names')),

        'gallery_id' => huhs_get_gallery_id($post->post_content),

        'gallery_images' => huhs_get_gallery_images($post->post_content),

        // ÚJ
        'embeds' => huhs_get_embeds($post->post_content),

        'related_posts' => $include_related ? huhs_get_related_posts($post->post_content, (int) $post->ID) : array(),

    );
}

function huhs_get_posts(WP_REST_Request $request)
{
    $page = max(1, absint($request->get_param('page')));
    $per_page = absint($request->get_param('per_page'));
    $per_page = min(50, max(1, $per_page ?: 10));
    $search = sanitize_text_field((string) $request->get_param('search'));
    $category = absint($request->get_param('category'));
    $summary = filter_var($request->get_param('summary'), FILTER_VALIDATE_BOOLEAN);
    // A kért nyelv: `hu` (alap) vagy `en`. Hiányzó/érvénytelen érték → `hu`,
    // ezért a `lang` nélkül kérő régi appok változatlan választ kapnak.
    $lang = huhs_request_lang($request);
    $sticky_param = $request->get_param('sticky');
    $sticky_filter = ($sticky_param === null || $sticky_param === '')
        ? null
        : filter_var($sticky_param, FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE);
    $sticky_ids = array_values(array_filter(array_map('absint', (array) get_option('sticky_posts', array()))));

    if ($sticky_filter === true && !$sticky_ids) {
        return new WP_REST_Response(array(
            'items' => array(),
            'page' => $page,
            'per_page' => $per_page,
            'total' => 0,
            'total_pages' => 0,
            'has_more' => false,
        ), 200);
    }

    $query_args = array(
        'post_type'      => 'post',
        'post_status'    => 'publish',
        'posts_per_page' => $per_page,
        'paged'          => $page,
        'orderby'        => 'date',
        'order'          => 'DESC',
        's'              => $search,
        'cat'            => $category,
        'ignore_sticky_posts' => true,
        'no_found_rows'  => false,
    );

    if ($sticky_filter === true) {
        $query_args['post__in'] = $sticky_ids;
    } elseif ($sticky_filter === false && $sticky_ids) {
        $query_args['post__not_in'] = $sticky_ids;
    }

    $query = new WP_Query($query_args);

    $result = array();

    foreach ($query->posts as $post) {

        $result[] = $summary ? huhs_build_post_summary($post, $lang) : huhs_build_post($post, true, $lang);

    }

    $total_pages = (int) $query->max_num_pages;

    return new WP_REST_Response(array(
        'items'       => $result,
        'page'        => $page,
        'per_page'    => $per_page,
        'total'       => (int) $query->found_posts,
        'total_pages' => $total_pages,
        'has_more'    => $page < $total_pages,
    ), 200);
}

function huhs_build_post_summary($post, $lang = 'hu')
{
    $translation = huhs_post_language_payload($post, $lang);

    return array(
        'id' => (int) $post->ID,
        'title' => $translation['title'],
        'date' => huhs_format_date($post->post_date),

        'is_sticky' => is_sticky($post->ID),
        'excerpt' => $translation['excerpt'],
        // A lista-végpont szándékosan nem küldi a törzset (sávszélesség), és
        // ez a `lang=en`-nél sem változik: a `content` itt mindig üres.
        'content' => '',
        'has_en' => $translation['has_en'],
        'featured_image' => huhs_featured_image($post->ID),
        'link' => get_permalink($post->ID),
        'category_ids' => wp_get_post_categories($post->ID),
        'categories' => wp_get_post_terms($post->ID, 'category', array('fields' => 'names')),
        'tags' => wp_get_post_terms($post->ID, 'post_tag', array('fields' => 'names')),
        'gallery_id' => 0,
        'gallery_images' => array(),
        'embeds' => array(),
        'related_posts' => array(),
    );
}

function huhs_get_related_posts($content, $current_id)
{
    if (!preg_match_all('/\[(?:irp)\b[^\]]*\]/i', (string) $content, $matches)) {
        return array();
    }

    $ids = array();
    foreach ($matches[0] as $shortcode) {
        if (!preg_match('/\b(?:posts?|ids?|post_ids?)\s*=\s*["\']([^"\']+)["\']/i', $shortcode, $attribute)) {
            continue;
        }

        foreach (preg_split('/\s*,\s*/', $attribute[1]) as $value) {
            $id = absint($value);
            if ($id && $id !== (int) $current_id) {
                $ids[$id] = $id;
            }
        }
    }

    if (!$ids) return array();

    $related = get_posts(array(
        'post_type' => 'post',
        'post_status' => 'publish',
        'post__in' => array_values($ids),
        'posts_per_page' => count($ids),
        'orderby' => 'post__in',
    ));

    // A kapcsolódó cikkek szándékosan a magyar (`hu`) alakban maradnak: a
    // `lang` paraméter csak a hívó cikk saját címére/kivonatára/törzsére hat.
    return array_map(function ($post) {
        return huhs_build_post($post, false);
    }, $related);
}

/*
|--------------------------------------------------------------------------
| Nyelv (`lang`) — angol cikk-mezők fallback-kel
|--------------------------------------------------------------------------
*/

/**
 * A kért nyelv a `lang` paraméterből: `hu` (alap) vagy `en`.
 *
 * Hiányzó vagy ismeretlen érték esetén `hu`. Ez azért fontos, mert a régi
 * appok egyáltalán nem küldenek `lang`-ot: nekik pontosan a mai választ
 * kell kapniuk, és egy elgépelt érték sem adhat véletlenül angol szöveget.
 */
function huhs_request_lang(WP_REST_Request $request)
{
    $lang = strtolower(trim((string) $request->get_param('lang')));

    return $lang === 'en' ? 'en' : 'hu';
}

/**
 * A cikk címe/kivonata/törzse a kért nyelven, a `has_en` jelzővel.
 *
 * MAGYAR ÁG (`lang=hu`, illetve hiányzó `lang`) — bitre ugyanaz, mint a
 * 2.10.0-ban: a cím a `post_title`-ból, a törzs a `post_content`-ból, a
 * kivonat pedig a törzs első 40 szava. Ebben az ágban a fordítási meta
 * **egyáltalán nem olvasódik**, ezért a magyar válasz gyorsabb és
 * bájtra azonos marad.
 *
 * ANGOL ÁG (`lang=en`) — FALLBACK: az angol értéket CSAK akkor használjuk,
 * ha az tényleg létezik (a `trim` után nem üres). A cím és a törzs együtt
 * dönt: ha bármelyik hiányzik, a cikk gyakorlatilag nincs lefordítva, ezért
 * a válasz a **magyar** marad és `has_en = false`. Így a payload sosem lesz
 * kevert nyelvű, és a `has_en` egyértelműen megmondja az appnak, mit kapott
 * — a válasz pedig soha nem lesz üres. A kivonatnak saját angol mezője van;
 * ha az üres, az angol törzsből képezzük (magyar kivonatra csak akkor esünk
 * vissza, ha angol törzs sincs, de az a fenti kapu miatt nem fordulhat elő).
 *
 * A `link` szándékosan nem itt dől el: minden nyelven a magyar permalink
 * marad, mert nincs külön angol bejegyzés.
 */
function huhs_post_language_payload($post, $lang)
{
    $content_hu = huhs_clean_content($post->post_content);

    // Magyar alapérték — erre esik vissza minden hiányzó angol mező.
    $payload = array(
        'has_en'  => false,
        'title'   => huhs_clean_title($post->post_title),
        'excerpt' => huhs_make_excerpt($content_hu),
        'content' => $content_hu,
    );

    // Nem angol kérés: a magyar payload megy vissza, meta-olvasás nélkül.
    if ($lang !== 'en') {
        return $payload;
    }

    $title_en = trim((string) get_post_meta($post->ID, '_huhs_title_en', true));
    $excerpt_en = trim((string) get_post_meta($post->ID, '_huhs_excerpt_en', true));
    $content_en = trim((string) get_post_meta($post->ID, '_huhs_content_en', true));

    // FALLBACK-KAPU: csak akkor térünk át angolra, ha a fordítás érdemi része
    // (cím ÉS törzs) megvan. Különben marad a fenti magyar payload.
    if ($title_en === '' || $content_en === '') {
        return $payload;
    }

    $payload['has_en'] = true;
    $payload['title'] = huhs_clean_title($title_en);
    $payload['content'] = huhs_clean_content($content_en);
    $payload['excerpt'] = $excerpt_en !== ''
        ? huhs_make_excerpt($excerpt_en)
        : huhs_make_excerpt($payload['content']);

    return $payload;
}
