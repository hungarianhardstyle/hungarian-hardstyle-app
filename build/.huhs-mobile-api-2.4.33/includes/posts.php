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

});

function huhs_get_post_detail(WP_REST_Request $request)
{
    $post = get_post(absint($request['id']));
    if (!$post || $post->post_type !== 'post' || $post->post_status !== 'publish') {
        return new WP_Error('post_not_found', 'A hír nem található.', array('status' => 404));
    }

    return new WP_REST_Response(huhs_build_post($post), 200);
}

function huhs_build_post($post, $include_related = true)
{
    $content = huhs_clean_content($post->post_content);

    return array(

        'id' => (int)$post->ID,

        'title' => huhs_clean_title($post->post_title),

        'date' => huhs_format_date($post->post_date),

        'excerpt' => huhs_make_excerpt($content),

        'content' => $content,

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

    $query = new WP_Query(array(
        'post_type'      => 'post',
        'post_status'    => 'publish',
        'posts_per_page' => $per_page,
        'paged'          => $page,
        'orderby'        => 'date',
        'order'          => 'DESC',
        's'              => $search,
        'cat'            => $category,
        'no_found_rows'  => false,
    ));

    $result = array();

    foreach ($query->posts as $post) {

        $result[] = huhs_build_post($post);

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

    return array_map(function ($post) {
        return huhs_build_post($post, false);
    }, $related);
}
