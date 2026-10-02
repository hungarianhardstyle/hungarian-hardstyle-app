<?php

if (!defined('ABSPATH')) {
    exit;
}

add_action('init', 'huhs_register_faq');
add_action('admin_init', 'huhs_seed_v3_faq_once');
add_action('admin_init', 'huhs_seed_games_faq_once');

function huhs_seed_games_faq_once()
{
    if (!current_user_can('manage_options') || get_option('huhs_faq_games_seeded_1')) {
        return;
    }

    $category = term_exists('App és közösség', 'huhs_faq_category');
    $category_id = is_array($category) ? (int) $category['term_id'] : (is_int($category) ? $category : 0);
    $existing = get_page_by_path('huhs-jatekok', OBJECT, 'huhs_faq');
    $post_id = $existing ? (int) $existing->ID : 0;
    if (!$post_id) {
        $post_id = wp_insert_post(array(
            'post_type' => 'huhs_faq',
            'post_status' => 'publish',
            'post_title' => 'Milyen játékok vannak az appban?',
            'post_name' => 'huhs-jatekok',
            'post_content' => 'Az appban időszakosan elérhető HUHS-játékokat találhatsz, például kvízt és Hardstyle idővonalat. A teljesítésért és a helyes válaszokért achievement pont is járhat. A játék állapotát és eredményeit az app jelzi.',
            'menu_order' => 95,
        ), true);
    }
    if (!is_wp_error($post_id) && $category_id > 0) {
        wp_set_object_terms((int) $post_id, array($category_id), 'huhs_faq_category');
    }
    update_option('huhs_faq_games_seeded_1', 1, false);
}

/**
 * Az ELSO GYIK-seed (v3) — mar csak azert fut, hogy a REGI, hibas szoveg ne
 * maradjon bent egy friss telepitesen.
 *
 * A TARTALMAT MAR NEM EZ IRJA: a `faq-human.php` v4 migracio adja a
 * felhasznalonak szolo szovegeket. Ez a fuggveny ezert csak jelzi, hogy
 * lefutott — a bejegyzeseket a v4 kesziti el.
 *
 * A v3 egyetlen ismert TARGYI HIBAJA: a „Hogyan mukodnek az achievement
 * pontok?" azt allitotta, hogy cikkkommentert naponta OT alkalom jar — a kodban
 * a plafon HAROM. Ezert a szoveget itt mar NEM irjuk le ujra.
 */
function huhs_seed_v3_faq_once()
{
    if (!current_user_can('manage_options') || get_option('huhs_faq_v3_seeded_1')) {
        return;
    }
    update_option('huhs_faq_v3_seeded_1', 1, false);
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
    // A kért nyelv (2.14.0): a GYÍK kérdése a cím, a válasza a törzs, ezért ez a
    // végpont ugyanazt a közös kaput használja, mint a cikkek.
    $lang = huhs_request_lang($request);
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
        $translation = huhs_translation_meta_values(
            $post->ID,
            $lang,
            get_the_title($post),
            wp_strip_all_tags(apply_filters('the_content', $post->post_content))
        );
        $items[] = array(
            'id' => (int) $post->ID,
            'question' => (string) $translation['title'],
            'answer' => (string) $translation['content'],
            'category' => ($terms && !is_wp_error($terms)) ? huhs_translation_faq_category_name($terms[0], $lang) : '',
            'order' => (int) $post->menu_order,
            // Nyelvjelző, ugyanúgy, mint a többi végponton (a régi app figyelmen
            // kívül hagyja).
            'has_en' => $translation['has_en'],
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

/**
 * A GYÍK **kategória-neve** a kért nyelven (plugin 2.14.0).
 *
 * A kategória egy taxonómia-nevel, ezért nem a cikk-fordítás fordítja. A sorrend:
 *  1. a terminus saját angol neve (`_huhs_name_en` term meta) — ha a tulajdonos
 *     kézzel megadja;
 *  2. a beépített névtár (a mért 8 kategória, 2026-09-25);
 *  3. különben az eredeti név (nem tippelünk).
 * Magyar kérésre az eredeti név megy vissza, átalakítás nélkül.
 */
function huhs_translation_faq_category_name($term, $lang)
{
    $name = is_object($term) ? (string) ($term->name ?? '') : (string) $term;
    if ($lang !== 'en' || $name === '') {
        return $name;
    }

    $term_id = is_object($term) ? (int) ($term->term_id ?? 0) : 0;
    if ($term_id > 0) {
        $custom = trim((string) get_term_meta($term_id, '_huhs_name_en', true));
        if ($custom !== '') {
            return $custom;
        }
    }

    $map = huhs_translation_faq_category_names();
    $key = huhs_translation_place_key($name);

    return isset($map[$key]) ? $map[$key] : $name;
}

/** A GYÍK kategóriáinak angol nevei (a mért készlet, 2026-09-25). */
function huhs_translation_faq_category_names()
{
    return array(
        'első lépések' => 'Getting Started',
        'közösség' => 'Community',
        'hírek és értesítések' => 'News and Notifications',
        'zene és kiadványok' => 'Music and Releases',
        'játékok' => 'Games',
        'szavazás és nyereményjáték' => 'Voting and Giveaways',
        'segítség és adatvédelem' => 'Help and Privacy',
        'app és közösség' => 'App and Community',
    );
}
