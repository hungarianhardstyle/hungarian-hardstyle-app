<?php

if (!defined('ABSPATH')) {
    exit;
}

add_action('init', 'huhs_register_faq');

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
