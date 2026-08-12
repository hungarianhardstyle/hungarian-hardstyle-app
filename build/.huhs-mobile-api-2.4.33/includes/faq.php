<?php

if (!defined('ABSPATH')) {
    exit;
}

add_action('init', 'huhs_register_faq');
add_action('admin_init', 'huhs_seed_v1_faq_once');

/**
 * Add the current app guidance once without changing existing editorial FAQ
 * entries. The WordPress editor remains the source of truth after seeding.
 */
function huhs_seed_v1_faq_once()
{
    if (!current_user_can('manage_options') || get_option('huhs_faq_v1_seeded_1')) {
        return;
    }

    $category = term_exists('App és közösség', 'huhs_faq_category');
    if (!$category || is_wp_error($category)) {
        $category = wp_insert_term('App és közösség', 'huhs_faq_category');
    }
    $category_id = is_array($category)
        ? (int) $category['term_id']
        : (is_int($category) ? $category : 0);

    $items = array(
        array(
            'slug' => 'label-preview-es-vasarlas',
            'title' => 'Hogyan működik a Label preview és a vásárlás?',
            'content' => 'A Label oldalon legfeljebb 60 másodperces preview hallgatható meg. A teljes WAV master nem nyilvános. A WAV/lossless és 320 kbps MP3 változat Google Play-vásárlással tölthető le; a 128 kbps MP3 jutalmazott reklám megtekintése után oldható fel.',
        ),
        array(
            'slug' => 'label-radio-es-extended-verzio',
            'title' => 'Mi a Radio és az Extended verzió?',
            'content' => 'Egy kiadványhoz külön Radio és Extended változat is tartozhat, ha ezeket a kiadvány szerkesztője feltöltötte. Az elérhető verziók a kiadvány adatlapján jelennek meg.',
        ),
        array(
            'slug' => 'huhs-szavazas',
            'title' => 'Hogyan működik az éves HUHS szavazás?',
            'content' => 'Szavazni csak regisztrált, bejelentkezett felhasználóként lehet. A kategóriák külön választási limiteket használhatnak: magyar hardstyle DJ 5, magyar hardcore DJ 3, magyar zene 2, magyar szervező 1, külföldi DJ 3 jelölt.',
        ),
        array(
            'slug' => 'baratok-es-esemenyreszvetel',
            'title' => 'Mit láthatok a barátaimról és az eseményekről?',
            'content' => 'A regisztrált felhasználók publikus profilokat nézhetnek meg, ismerősnek jelölhetik egymást, és az eseményeknél jelezhetik, hogy ott lesznek-e. Az eseményeken a megosztott részvételi állapotok és az ismerősök részvétele látható.',
        ),
        array(
            'slug' => 'bekuldesek-es-jovahagyas',
            'title' => 'Mi történik a DJ-, szervező- és eseménybeküldéssel?',
            'content' => 'A beküldések ellenőrzésre kerülnek, és nem jelennek meg automatikusan publikált tartalomként. A szerkesztőség az adminisztrációban ellenőrzi, javítja és külön dönt a közzétételről.',
        ),
        array(
            'slug' => 'profil-es-fiok-torlese',
            'title' => 'Hogyan törölhetem a profilomat?',
            'content' => 'A saját profilod adatlapján a Profil törlése művelettel kezdeményezheted a fiók törlését. A törlés megerősítést kér, és az alkalmazás közösségi adataid eltávolítását is kezeli.',
        ),
    );

    foreach ($items as $item) {
        $existing = get_page_by_path($item['slug'], OBJECT, 'huhs_faq');
        if ($existing) {
            continue;
        }
        $post_id = wp_insert_post(array(
            'post_type' => 'huhs_faq',
            'post_status' => 'publish',
            'post_title' => $item['title'],
            'post_name' => $item['slug'],
            'post_content' => $item['content'],
            'menu_order' => 100,
        ), true);
        if (!is_wp_error($post_id) && $category_id > 0) {
            wp_set_object_terms($post_id, array($category_id), 'huhs_faq_category');
        }
    }

    update_option('huhs_faq_v1_seeded_1', 1, false);
}

function huhs_register_faq()
{
    register_post_type('huhs_faq', array(
        'labels' => array(
            'name' => 'GYIK',
            'singular_name' => 'GYIK bejegyzés',
            'add_new_item' => 'Új GYIK bejegyzés',
            'edit_item' => 'GYIK bejegyzés szerkesztése',
        ),
        'public' => false,
        'show_ui' => true,
        'show_in_menu' => 'huhs-mobile',
        'supports' => array('title', 'editor', 'page-attributes'),
        'show_in_rest' => false,
        'capability_type' => 'post',
        'map_meta_cap' => true,
    ));

    register_taxonomy('huhs_faq_category', 'huhs_faq', array(
        'labels' => array(
            'name' => 'GYIK kategóriák',
            'singular_name' => 'GYIK kategória',
        ),
        'public' => false,
        'show_ui' => true,
        'show_admin_column' => true,
        'show_in_rest' => false,
        'hierarchical' => true,
    ));
}

add_action('rest_api_init', 'huhs_register_faq_api');

function huhs_register_faq_api()
{
    register_rest_route('huhs/v1', '/faq', array(
        'methods' => WP_REST_Server::READABLE,
        'permission_callback' => '__return_true',
        'callback' => 'huhs_get_faq',
        'args' => array(
            'search' => array('sanitize_callback' => 'sanitize_text_field'),
            'category' => array('sanitize_callback' => 'sanitize_title'),
            'page' => array('default' => 1, 'sanitize_callback' => 'absint'),
            'per_page' => array('default' => 50, 'sanitize_callback' => 'absint'),
        ),
    ));
}

function huhs_get_faq(WP_REST_Request $request)
{
    $page = max(1, (int) $request->get_param('page'));
    $per_page = min(100, max(1, (int) $request->get_param('per_page')));
    $tax_query = array();
    $category = $request->get_param('category');

    if ($category) {
        $tax_query[] = array(
            'taxonomy' => 'huhs_faq_category',
            'field' => 'slug',
            'terms' => $category,
        );
    }

    $query = new WP_Query(array(
        'post_type' => 'huhs_faq',
        'post_status' => 'publish',
        's' => (string) $request->get_param('search'),
        'posts_per_page' => $per_page,
        'paged' => $page,
        'orderby' => array('menu_order' => 'ASC', 'title' => 'ASC'),
        'order' => 'ASC',
        'tax_query' => $tax_query,
    ));

    $items = array();
    foreach ($query->posts as $post) {
        $terms = get_the_terms($post, 'huhs_faq_category');
        $items[] = array(
            'id' => (int) $post->ID,
            'question' => get_the_title($post),
            'answer' => wp_strip_all_tags(apply_filters('the_content', $post->post_content)),
            'category' => ($terms && !is_wp_error($terms)) ? (string) $terms[0]->name : '',
            'order' => (int) $post->menu_order,
        );
    }

    return rest_ensure_response(array(
        'items' => $items,
        'page' => $page,
        'per_page' => $per_page,
        'total' => (int) $query->found_posts,
        'total_pages' => (int) $query->max_num_pages,
    ));
}
