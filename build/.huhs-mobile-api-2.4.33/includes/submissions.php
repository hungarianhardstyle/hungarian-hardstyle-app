<?php

if (!defined('ABSPATH')) {
    exit;
}

/*
|--------------------------------------------------------------------------
| Event Submissions Custom Post Type
|--------------------------------------------------------------------------
*/

add_action('init', 'huhs_register_submission_post_type');

function huhs_register_submission_post_type()
{
    $labels = array(
        'name'               => 'Beküldések',
        'singular_name'      => 'Beküldés',
        'menu_name'          => 'Beküldések',
        'name_admin_bar'     => 'Beküldés',
        'add_new'            => 'Új beküldés',
        'add_new_item'       => 'Új beküldés',
        'edit_item'          => 'Beküldés szerkesztése',
        'new_item'           => 'Új beküldés',
        'view_item'          => 'Beküldés megtekintése',
        'search_items'       => 'Beküldés keresése',
        'not_found'          => 'Nincs beküldés.',
        'not_found_in_trash' => 'Nincs beküldés a kukában.',
    );

    register_post_type('huhs_submission', array(

        'labels' => $labels,

        'public' => false,

        'show_ui' => true,

        'show_in_menu' => false,

        'supports' => array(
            'title',
            'editor',
        ),

        'menu_icon' => 'dashicons-email',

        'has_archive' => false,

        'rewrite' => false,

        'show_in_rest' => true,

    ));
}

/*
|--------------------------------------------------------------------------
| Public Event Submission REST API
|--------------------------------------------------------------------------
*/

add_action('rest_api_init', 'huhs_register_event_submission_api');

function huhs_register_event_submission_api()
{
    register_rest_route('huhs/v1', '/event-submission-options', array(
        'methods'             => 'GET',
        'callback'            => 'huhs_get_event_submission_options',
        'permission_callback' => '__return_true',
    ));

    register_rest_route('huhs/v1', '/event-submissions', array(
        'methods'             => 'POST',
        'callback'            => 'huhs_create_event_submission',
        'permission_callback' => 'huhs_submission_api_permission',
    ));

    register_rest_route('huhs/v1', '/profile-submission-options', array(
        'methods'             => 'GET',
        'callback'            => 'huhs_get_profile_submission_options',
        'permission_callback' => '__return_true',
    ));

    register_rest_route('huhs/v1', '/artist-submissions', array(
        'methods'             => 'POST',
        'callback'            => 'huhs_create_artist_submission',
        'permission_callback' => 'huhs_submission_api_permission',
    ));

    register_rest_route('huhs/v1', '/organizer-submissions', array(
        'methods'             => 'POST',
        'callback'            => 'huhs_create_organizer_submission',
        'permission_callback' => 'huhs_submission_api_permission',
    ));
}

function huhs_submission_api_permission(WP_REST_Request $request)
{
    if (!is_user_logged_in() || !current_user_can('edit_posts')) {
        return new WP_Error(
            'huhs_submission_forbidden',
            'A beküldéshez hitelesített WordPress-felhasználó szükséges.',
            array('status' => 401)
        );
    }

    return true;
}

function huhs_get_event_submission_options()
{
    return rest_ensure_response(array(
        'genres' => huhs_genre_options(),
    ));
}

function huhs_get_profile_submission_options()
{
    return rest_ensure_response(array(
        'genres' => huhs_genre_options(),
        'artist_categories' => array(
            array('name' => 'Hardstyle', 'slug' => 'hardstyle'),
            array('name' => 'Hardcore', 'slug' => 'hardcore'),
        ),
    ));
}

function huhs_create_event_submission(WP_REST_Request $request)
{
    $params = huhs_submission_params($request);

    // Honeypot: normal app clients always leave this field empty.
    if (!empty($params['website'])) {
        return rest_ensure_response(array(
            'success' => true,
            'message' => 'Köszönjük, az eseményt elküldtük ellenőrzésre.',
        ));
    }

    $rate_limit_key = 'huhs_submission_' . md5(huhs_submission_client_address());
    $submission_count = (int) get_transient($rate_limit_key);

    if ($submission_count >= 5) {
        return new WP_Error(
            'huhs_submission_rate_limited',
            'Túl sok beküldés érkezett. Kérjük, próbáld újra később.',
            array('status' => 429)
        );
    }

    $title = sanitize_text_field($params['title'] ?? '');
    $start_date = sanitize_text_field($params['start_date'] ?? '');
    $start_time = sanitize_text_field($params['start_time'] ?? '');
    $end_date = sanitize_text_field($params['end_date'] ?? '');
    $end_time = sanitize_text_field($params['end_time'] ?? '');
    $venue_name = sanitize_text_field($params['venue_name'] ?? '');
    $venue_city = sanitize_text_field($params['venue_city'] ?? '');
    $venue_zip = sanitize_text_field($params['venue_zip'] ?? '');
    $venue_address = sanitize_text_field($params['venue_address'] ?? '');
    $organizer_name = sanitize_text_field($params['organizer_name'] ?? '');
    $organizer_id = absint($params['organizer_id'] ?? 0);
    $contact_email = sanitize_email($params['contact_email'] ?? '');
    $event_url = esc_url_raw($params['event_url'] ?? '');
    $description = sanitize_textarea_field($params['description'] ?? '');
    $flyer_url = esc_url_raw($params['flyer_url'] ?? '');
    $genre_values = isset($params['genres']) && is_array($params['genres'])
        ? array_map('sanitize_text_field', $params['genres'])
        : array();
    $genres = array_values(array_intersect(huhs_genre_options(), $genre_values));

    if ($title === '' || $start_date === '' || $venue_name === '' || $venue_city === '' || $venue_zip === '' || $venue_address === '' || $contact_email === '' || !$genres) {
        return new WP_Error(
            'huhs_submission_missing_fields',
            'Az eseménynév, dátum, helyszín, legalább egy műfaj és a kapcsolattartó e-mail megadása kötelező.',
            array('status' => 400)
        );
    }

    if (!preg_match('/^\d+$/', $venue_zip)) {
        return new WP_Error('huhs_submission_invalid_postal_code', 'Az irányítószám csak számokat tartalmazhat.', array('status' => 400));
    }

    if (!is_email($contact_email)) {
        return new WP_Error(
            'huhs_submission_invalid_email',
            'A megadott e-mail-cím nem érvényes.',
            array('status' => 400)
        );
    }

    if (!huhs_submission_valid_date($start_date)) {
        return new WP_Error(
            'huhs_submission_invalid_date',
            'A dátum formátuma nem megfelelő.',
            array('status' => 400)
        );
    }

    if ($start_time !== '' && !preg_match('/^(?:[01]\d|2[0-3]):[0-5]\d$/', $start_time)) {
        return new WP_Error(
            'huhs_submission_invalid_time',
            'Az időpont formátuma nem megfelelő.',
            array('status' => 400)
        );
    }

    if (($end_date === '') !== ($end_time === '')) {
        return new WP_Error('huhs_submission_invalid_end', 'Az esemény végét nappal és időponttal együtt add meg.', array('status' => 400));
    }
    if ($end_date !== '' && (!huhs_submission_valid_date($end_date) || !preg_match('/^(?:[01]\d|2[0-3]):[0-5]\d$/', $end_time))) {
        return new WP_Error('huhs_submission_invalid_end', 'Az esemény vége nem érvényes.', array('status' => 400));
    }
    if ($end_date !== '' && strtotime($end_date . ' ' . ($end_time ?: '00:00')) <= strtotime($start_date . ' ' . ($start_time ?: '00:00'))) {
        return new WP_Error('huhs_submission_invalid_end', 'Az esemény vége nem lehet a kezdés előtt vagy azzal egy időben.', array('status' => 400));
    }
    if ($flyer_url !== '' && !huhs_is_cloudinary_url($flyer_url)) {
        return new WP_Error('huhs_submission_invalid_image_url', 'A képlink nem érvényes Cloudinary-kép.', array('status' => 400));
    }

    $image_validation = huhs_validate_submission_image($request);
    if (is_wp_error($image_validation)) {
        return $image_validation;
    }

    $content_lines = array(
        'Esemény dátuma: ' . $start_date,
        'Kezdés: ' . ($start_time ?: 'nincs megadva'),
        'Helyszín: ' . $venue_name,
        'Irányítószám: ' . $venue_zip,
        'Város: ' . ($venue_city ?: 'nincs megadva'),
        'Szervező: ' . ($organizer_name ?: 'nincs megadva'),
        'Műfajok: ' . implode(', ', $genres),
        'Kapcsolattartó: ' . $contact_email,
        'Eseménylink: ' . ($event_url ?: 'nincs megadva'),
        '',
        'Leírás:',
        $description ?: 'nincs megadva',
    );

    $submission_id = wp_insert_post(array(
        'post_type'    => 'huhs_submission',
        'post_status'  => 'pending',
        'post_title'   => $title,
        'post_content' => implode("\n", $content_lines),
    ), true);

    if (is_wp_error($submission_id)) {
        return new WP_Error(
            'huhs_submission_save_failed',
            'A beküldést most nem sikerült elmenteni. Kérjük, próbáld újra.',
            array('status' => 500)
        );
    }

    $meta = array(
        'submission_type'  => 'event',
        'event_start_date' => $start_date,
        'event_start_time' => $start_time,
        'event_end_date'   => $end_date,
        'event_end_time'   => $end_time,
        'venue_name'       => $venue_name,
        'venue_city'       => $venue_city,
        'venue_zip'        => $venue_zip,
        'venue_address'    => $venue_address,
        'organizer_name'   => $organizer_name,
        'organizer_id'     => $organizer_id,
        'genres'           => implode(',', $genres),
        'contact_email'    => $contact_email,
        'event_url'        => $event_url,
        'description'      => $description,
        'event_flyer_url'  => $flyer_url,
        'submission_source'=> 'flutter_app',
    );

    foreach ($meta as $key => $value) {
        update_post_meta($submission_id, $key, $value);
    }

    $image_id = huhs_store_submission_image($request, $submission_id, 'event_flyer');
    if (is_wp_error($image_id)) {
        wp_delete_post($submission_id, true);
        return $image_id;
    }
    if ($flyer_url !== '') {
        update_post_meta($submission_id, 'submission_image_url', $flyer_url);
    }

    set_transient($rate_limit_key, $submission_count + 1, HOUR_IN_SECONDS);

    $admin_email = sanitize_email(get_option('admin_email'));
    if ($admin_email) {
        wp_mail(
            $admin_email,
            'Új eseménybeküldés: ' . $title,
            'Új esemény érkezett az alkalmazásból. Ellenőrzés: ' . admin_url('post.php?post=' . $submission_id . '&action=edit')
        );
    }
    if (function_exists('huhs_push_send')) {
        huhs_push_send(
            'Új eseménybeküldés',
            $title,
            array('type' => 'submission', 'kind' => 'event', 'id' => (string) $submission_id)
        );
    }

    return new WP_REST_Response(array(
        'success' => true,
        'id'      => (int) $submission_id,
        'message' => 'Köszönjük, az eseményt elküldtük ellenőrzésre.',
    ), 201);
}

function huhs_is_cloudinary_url($url)
{
    $host = strtolower((string) wp_parse_url($url, PHP_URL_HOST));
    return $host !== '' && (substr($host, -14) === 'cloudinary.com');
}

function huhs_submission_image_url($submission_id, $keys)
{
    foreach ((array) $keys as $key) {
        $url = esc_url_raw(get_post_meta($submission_id, $key, true));
        if ($url !== '' && huhs_is_cloudinary_url($url)) {
            return $url;
        }
    }

    return '';
}

function huhs_submission_valid_date($value)
{
    if (!preg_match('/^(\d{4})-(\d{2})-(\d{2})$/', $value, $matches)) {
        return false;
    }

    return checkdate((int) $matches[2], (int) $matches[3], (int) $matches[1]);
}

function huhs_submission_client_address()
{
    $address = isset($_SERVER['REMOTE_ADDR'])
        ? sanitize_text_field(wp_unslash($_SERVER['REMOTE_ADDR']))
        : 'unknown';

    return $address ?: 'unknown';
}

function huhs_validate_submission_image(WP_REST_Request $request, $field = 'image')
{
    $files = $request->get_file_params();
    if (empty($files[$field])) {
        return true;
    }

    $file = $files[$field];
    if (!isset($file['error']) || (int) $file['error'] !== UPLOAD_ERR_OK) {
        return new WP_Error(
            'huhs_submission_image_upload_failed',
            'A képet nem sikerült feltölteni.',
            array('status' => 400)
        );
    }

    if (empty($file['size']) || (int) $file['size'] > 5 * MB_IN_BYTES) {
        return new WP_Error(
            'huhs_submission_image_too_large',
            'A kép legfeljebb 5 MB lehet.',
            array('status' => 400)
        );
    }

    require_once ABSPATH . 'wp-admin/includes/file.php';
    $allowed_mimes = array(
        'jpg|jpeg' => 'image/jpeg',
        'png'      => 'image/png',
        'webp'     => 'image/webp',
    );
    $checked = wp_check_filetype_and_ext(
        $file['tmp_name'],
        sanitize_file_name($file['name']),
        $allowed_mimes
    );

    if (empty($checked['type']) || empty($checked['ext'])) {
        return new WP_Error(
            'huhs_submission_image_invalid_type',
            'Csak JPG, PNG vagy WebP kép tölthető fel.',
            array('status' => 400)
        );
    }

    return true;
}

function huhs_store_submission_image(WP_REST_Request $request, $submission_id, $role, $field = 'image')
{
    $files = $request->get_file_params();
    if (empty($files[$field])) {
        return 0;
    }

    require_once ABSPATH . 'wp-admin/includes/file.php';
    require_once ABSPATH . 'wp-admin/includes/media.php';
    require_once ABSPATH . 'wp-admin/includes/image.php';

    $file = $files[$field];
    $file['name'] = sanitize_file_name($file['name']);
    $attachment_id = media_handle_sideload($file, $submission_id);

    if (is_wp_error($attachment_id)) {
        return new WP_Error(
            'huhs_submission_image_save_failed',
            'A képet most nem sikerült elmenteni.',
            array('status' => 500)
        );
    }

    $meta_prefix = $field === 'image' ? 'submission_image' : 'submission_' . sanitize_key($field);
    update_post_meta($submission_id, $meta_prefix . '_id', (int) $attachment_id);
    update_post_meta($submission_id, $meta_prefix . '_role', sanitize_key($role));
    update_post_meta(
        $submission_id,
        $meta_prefix . '_url',
        esc_url_raw(wp_get_attachment_url($attachment_id))
    );

    return (int) $attachment_id;
}

/*
|--------------------------------------------------------------------------
| Artist and Organizer Submissions
|--------------------------------------------------------------------------
*/

function huhs_create_artist_submission(WP_REST_Request $request)
{
    $params = huhs_submission_params($request);
    $honeypot = huhs_profile_submission_honeypot($params);
    if ($honeypot) {
        return $honeypot;
    }

    $rate_limit = huhs_profile_submission_rate_limit('artist');
    if (is_wp_error($rate_limit)) {
        return $rate_limit;
    }

    $name = sanitize_text_field($params['name'] ?? '');
    $real_name = sanitize_text_field($params['real_name'] ?? '');
    $city = sanitize_text_field($params['city'] ?? '');
    $country = sanitize_text_field($params['country'] ?? '');
    $biography = sanitize_textarea_field($params['biography'] ?? '');
    $contact_email = sanitize_email($params['contact_email'] ?? '');
    $booking_email = sanitize_email($params['booking_email'] ?? '');
    $booking_via_huhs = !empty($params['booking_via_huhs']);
    $profile_image_url = esc_url_raw($params['profile_image_url'] ?? '');
    $logo_url = esc_url_raw($params['logo_url'] ?? '');
    $genres = huhs_submission_allowed_values($params['genres'] ?? array(), huhs_genre_options());
    $category_slugs = huhs_submission_allowed_values(
        $params['categories'] ?? array(),
        array('hardstyle', 'hardcore')
    );
    $links = huhs_submission_social_links($params, array(
        'website', 'facebook', 'instagram', 'tiktok', 'spotify', 'soundcloud', 'youtube',
    ));

    if ($name === '' || $contact_email === '' || !$genres || !$category_slugs) {
        return new WP_Error(
            'huhs_artist_submission_missing_fields',
            'A DJ-név, legalább egy kategória, legalább egy műfaj és a kapcsolattartó e-mail megadása kötelező.',
            array('status' => 400)
        );
    }

    if (!is_email($contact_email)) {
        return new WP_Error(
            'huhs_artist_submission_invalid_email',
            'A megadott e-mail-cím nem érvényes.',
            array('status' => 400)
        );
    }

    if (!$booking_via_huhs && $booking_email !== '' && !is_email($booking_email)) {
        return new WP_Error(
            'huhs_artist_submission_invalid_booking_email',
            'A megadott booking e-mail-cím nem érvényes.',
            array('status' => 400)
        );
    }

    $image_validation = huhs_validate_submission_image($request);
    if (is_wp_error($image_validation)) {
        return $image_validation;
    }

    $logo_validation = huhs_validate_submission_image($request, 'logo');
    if (is_wp_error($logo_validation)) {
        return $logo_validation;
    }

    $category_names = array_map(function ($slug) {
        return $slug === 'hardcore' ? 'Hardcore' : 'Hardstyle';
    }, $category_slugs);
    $lines = array(
        'Típus: DJ / előadó',
        'DJ-név: ' . $name,
        'Valódi név: ' . ($real_name ?: 'nincs megadva'),
        'Kategóriák: ' . implode(', ', $category_names),
        'Műfajok: ' . implode(', ', $genres),
        'Hely: ' . implode(', ', array_filter(array($city, $country))),
        'Kapcsolattartó: ' . $contact_email,
        'HUHS-on keresztüli fellépésszervezés: ' . ($booking_via_huhs ? 'igen' : 'nem'),
        'Nyilvános booking e-mail: ' . ($booking_via_huhs ? 'info@hungarianhardstyle.hu' : ($booking_email ?: 'nincs megadva')),
        'Profilkép link: ' . ($profile_image_url ?: 'nincs megadva'),
        'DJ-logó link: ' . ($logo_url ?: 'nincs megadva'),
        '',
        'Bemutatkozás:',
        $biography ?: 'nincs megadva',
        '',
        'Linkek:',
    );
    foreach ($links as $key => $url) {
        $lines[] = ucfirst($key) . ': ' . $url;
    }

    $meta = array_merge(array(
        'submission_type'  => 'artist',
        'artist_name'      => $name,
        'real_name'        => $real_name,
        'categories'       => implode(',', $category_slugs),
        'genres'           => implode(',', $genres),
        'city'             => $city,
        'country'          => $country,
        'biography'        => $biography,
        'contact_email'    => $contact_email,
        'booking_email'    => $booking_via_huhs ? '' : $booking_email,
        'booking_via_huhs' => $booking_via_huhs ? 1 : 0,
        'profile_image_url'=> $profile_image_url,
        'logo_url'        => $logo_url,
        'submission_source'=> 'flutter_app',
    ), $links);

    return huhs_save_profile_submission(
        '[DJ] ' . $name,
        $lines,
        $meta,
        'artist',
        $request,
        array(
            'image' => 'artist_profile',
            'logo'  => 'artist_logo',
        )
    );
}

function huhs_create_organizer_submission(WP_REST_Request $request)
{
    $params = huhs_submission_params($request);
    $honeypot = huhs_profile_submission_honeypot($params);
    if ($honeypot) {
        return $honeypot;
    }

    $rate_limit = huhs_profile_submission_rate_limit('organizer');
    if (is_wp_error($rate_limit)) {
        return $rate_limit;
    }

    $name = sanitize_text_field($params['name'] ?? '');
    $city = sanitize_text_field($params['city'] ?? '');
    $country = sanitize_text_field($params['country'] ?? '');
    $description = sanitize_textarea_field($params['description'] ?? '');
    $contact_email = sanitize_email($params['contact_email'] ?? '');
    $logo_url = esc_url_raw($params['logo_url'] ?? '');
    $genres = huhs_submission_allowed_values($params['genres'] ?? array(), huhs_genre_options());
    $links = huhs_submission_social_links($params, array(
        'website', 'facebook', 'instagram', 'tiktok',
    ));

    if ($name === '' || $contact_email === '' || !$genres) {
        return new WP_Error(
            'huhs_organizer_submission_missing_fields',
            'A szervező neve, legalább egy műfaj és a kapcsolattartó e-mail megadása kötelező.',
            array('status' => 400)
        );
    }

    if (!is_email($contact_email)) {
        return new WP_Error(
            'huhs_organizer_submission_invalid_email',
            'A megadott e-mail-cím nem érvényes.',
            array('status' => 400)
        );
    }

    $image_validation = huhs_validate_submission_image($request);
    if (is_wp_error($image_validation)) {
        return $image_validation;
    }

    $lines = array(
        'Típus: szervező',
        'Név: ' . $name,
        'Hely: ' . implode(', ', array_filter(array($city, $country))),
        'Kapcsolattartó: ' . $contact_email,
        'Logó link: ' . ($logo_url ?: 'nincs megadva'),
        '',
        'Bemutatkozás:',
        $description ?: 'nincs megadva',
        '',
        'Linkek:',
    );
    foreach ($links as $key => $url) {
        $lines[] = ucfirst($key) . ': ' . $url;
    }

    $meta = array_merge(array(
        'submission_type'  => 'organizer',
        'organizer_name'   => $name,
        'city'             => $city,
        'country'          => $country,
        'description'      => $description,
        'contact_email'    => $contact_email,
        'logo_url'         => $logo_url,
        'genres'           => implode(',', $genres),
        'submission_source'=> 'flutter_app',
    ), $links);

    return huhs_save_profile_submission(
        '[Szervező] ' . $name,
        $lines,
        $meta,
        'organizer',
        $request,
        array('image' => 'organizer_logo')
    );
}

function huhs_submission_params(WP_REST_Request $request)
{
    $params = $request->get_json_params();
    if (is_array($params)) {
        return $params;
    }

    $params = $request->get_body_params();
    if (!empty($params['payload']) && is_string($params['payload'])) {
        $payload = json_decode(wp_unslash($params['payload']), true);
        if (is_array($payload)) {
            return $payload;
        }
    }

    return is_array($params) ? $params : array();
}

function huhs_profile_submission_honeypot($params)
{
    if (empty($params['website_check'])) {
        return null;
    }

    return rest_ensure_response(array(
        'success' => true,
        'message' => 'Köszönjük, a beküldést elküldtük ellenőrzésre.',
    ));
}

function huhs_profile_submission_rate_limit($scope)
{
    $key = 'huhs_' . sanitize_key($scope) . '_submission_' . md5(huhs_submission_client_address());
    $count = (int) get_transient($key);

    if ($count >= 5) {
        return new WP_Error(
            'huhs_profile_submission_rate_limited',
            'Túl sok beküldés érkezett. Kérjük, próbáld újra később.',
            array('status' => 429)
        );
    }

    set_transient($key, $count + 1, HOUR_IN_SECONDS);
    return true;
}

function huhs_submission_allowed_values($values, $allowed)
{
    if (!is_array($values)) {
        return array();
    }

    $values = array_map('sanitize_text_field', $values);
    return array_values(array_intersect($allowed, $values));
}

function huhs_submission_social_links($params, $keys)
{
    $links = array();
    foreach ($keys as $key) {
        $url = esc_url_raw($params[$key] ?? '');
        if ($url !== '') {
            $links[$key] = $url;
        }
    }
    return $links;
}

function huhs_save_profile_submission(
    $title,
    $content_lines,
    $meta,
    $type,
    WP_REST_Request $request = null,
    $image_roles = array()
)
{
    $submission_id = wp_insert_post(array(
        'post_type'    => 'huhs_submission',
        'post_status'  => 'pending',
        'post_title'   => sanitize_text_field($title),
        'post_content' => implode("\n", $content_lines),
    ), true);

    if (is_wp_error($submission_id)) {
        return new WP_Error(
            'huhs_profile_submission_save_failed',
            'A beküldést most nem sikerült elmenteni. Kérjük, próbáld újra.',
            array('status' => 500)
        );
    }

    foreach ($meta as $key => $value) {
        update_post_meta($submission_id, sanitize_key($key), $value);
    }

    foreach (array('profile_image_url', 'logo_url') as $url_key) {
        $url = esc_url_raw($meta[$url_key] ?? '');
        if ($url !== '' && huhs_is_cloudinary_url($url)) {
            $prefix = $url_key === 'logo_url' ? 'submission_logo' : 'submission_image';
            update_post_meta($submission_id, $prefix . '_url', $url);
        }
    }

    $stored_image_ids = array();
    if ($request) {
        foreach ($image_roles as $field => $role) {
            $image_id = huhs_store_submission_image($request, $submission_id, $role, $field);
            if (is_wp_error($image_id)) {
                foreach ($stored_image_ids as $stored_image_id) {
                    wp_delete_attachment($stored_image_id, true);
                }
                wp_delete_post($submission_id, true);
                return $image_id;
            }
            if ($image_id) {
                $stored_image_ids[] = $image_id;
            }
        }
    }

    $admin_email = sanitize_email(get_option('admin_email'));
    if ($admin_email) {
        wp_mail(
            $admin_email,
            'Új ' . ($type === 'artist' ? 'DJ' : 'szervező') . ' beküldés',
            'Új beküldés érkezett az alkalmazásból. Ellenőrzés: ' . admin_url('post.php?post=' . $submission_id . '&action=edit')
        );
    }

    return new WP_REST_Response(array(
        'success' => true,
        'id'      => (int) $submission_id,
        'message' => 'Köszönjük, a beküldést elküldtük ellenőrzésre.',
    ), 201);
}

add_filter('manage_huhs_submission_posts_columns', 'huhs_submission_admin_columns');

function huhs_submission_admin_columns($columns)
{
    $columns['huhs_submission_type'] = 'Típus';
    $columns['huhs_submission_contact'] = 'Kapcsolattartó';
    return $columns;
}

add_action('manage_huhs_submission_posts_custom_column', 'huhs_submission_admin_column_value', 10, 2);

function huhs_submission_admin_column_value($column, $post_id)
{
    if ($column === 'huhs_submission_type') {
        $type = get_post_meta($post_id, 'submission_type', true);
        $labels = array('artist' => 'DJ', 'organizer' => 'Szervező', 'event' => 'Esemény');
        echo esc_html($labels[$type] ?? 'Esemény');
    }

    if ($column === 'huhs_submission_contact') {
        echo esc_html(get_post_meta($post_id, 'contact_email', true));
    }
}

add_action('add_meta_boxes_huhs_submission', 'huhs_submission_approval_meta_box');

function huhs_submission_approval_meta_box()
{
    remove_meta_box('submitdiv', 'huhs_submission', 'side');

    add_meta_box(
        'huhs_submission_approval',
        'Jóváhagyás',
        'huhs_submission_approval_meta_box_content',
        'huhs_submission',
        'side',
        'high'
    );
}

function huhs_submission_approval_meta_box_content($post)
{
    $type = get_post_meta($post->ID, 'submission_type', true);
    $created_profile_id = (int) get_post_meta($post->ID, 'created_profile_id', true);
    $image_id = (int) get_post_meta($post->ID, 'submission_image_id', true);
    $logo_id = (int) get_post_meta($post->ID, 'submission_logo_id', true);
    $image_url = esc_url_raw(get_post_meta($post->ID, 'submission_image_url', true));
    $logo_url = esc_url_raw(get_post_meta($post->ID, 'submission_logo_url', true));

    if (!$image_id && $image_url !== '' && huhs_is_cloudinary_url($image_url)) {
        echo '<p><strong>Beküldött kép</strong></p>';
        echo '<img src="' . esc_url($image_url) . '" alt="" style="max-width:100%;height:auto;border-radius:6px;">';
        echo '<p><a href="' . esc_url($image_url) . '" target="_blank" rel="noopener">Kép megnyitása</a></p>';
    }

    if (!$logo_id && $logo_url !== '' && huhs_is_cloudinary_url($logo_url)) {
        echo '<p><strong>Beküldött DJ-logó</strong></p>';
        echo '<img src="' . esc_url($logo_url) . '" alt="" style="max-width:100%;height:auto;border-radius:6px;">';
        echo '<p><a href="' . esc_url($logo_url) . '" target="_blank" rel="noopener">Logó megnyitása</a></p>';
    }

    if ($image_id) {
        echo '<p><strong>Beküldött kép</strong></p>';
        echo wp_kses_post(wp_get_attachment_image($image_id, 'medium', false, array(
            'style' => 'max-width:100%;height:auto;border-radius:6px;',
        )));
        echo '<p><a href="' . esc_url(get_edit_post_link($image_id)) . '">Kép megnyitása a médiatárban</a></p>';
    }

    if ($logo_id) {
        echo '<p><strong>Beküldött DJ-logó</strong></p>';
        echo wp_kses_post(wp_get_attachment_image($logo_id, 'medium', false, array(
            'style' => 'max-width:100%;height:auto;border-radius:6px;',
        )));
        echo '<p><a href="' . esc_url(get_edit_post_link($logo_id)) . '">Logó megnyitása a médiatárban</a></p>';
    }

    if ($created_profile_id) {
        echo '<p><strong>A piszkozat létrejött.</strong></p>';
        echo '<p><a class="button" href="' . esc_url(get_edit_post_link($created_profile_id)) . '">Piszkozat szerkesztése</a></p>';
        return;
    }

    if (!in_array($type, array('artist', 'organizer', 'event'), true)) {
        echo '<p>Ez a beküldéstípus nem hagyható jóvá.</p>';
        return;
    }

    $approval_url = wp_nonce_url(
        add_query_arg(
            array(
                'action'        => 'huhs_approve_profile_submission',
                'submission_id' => $post->ID,
            ),
            admin_url('admin-post.php')
        ),
        'huhs_approve_profile_submission_' . $post->ID
    );

    echo '<p>A gomb létrehozza a tartalmat <strong>piszkozatként</strong>. Publikálás előtt ellenőrizd a képet, a linkeket és a leírást.</p>';
    echo '<p><a class="button button-primary" href="' . esc_url($approval_url) . '">Jóváhagyás és piszkozat létrehozása</a></p>';
}

add_action('admin_post_huhs_approve_profile_submission', 'huhs_approve_profile_submission');

add_action('rest_api_init', function () {
    register_rest_route('huhs/v1', '/submissions/(?P<id>\d+)/approve', array(
        'methods'             => WP_REST_Server::CREATABLE,
        'permission_callback' => function () {
            return current_user_can('manage_options');
        },
        'callback'            => function (WP_REST_Request $request) {
            $profile_id = huhs_approve_profile_submission(absint($request['id']), false);
            if (is_wp_error($profile_id)) {
                return $profile_id;
            }
            return rest_ensure_response(array('approved' => true, 'profile_id' => $profile_id));
        },
    ));
});

function huhs_approve_profile_submission($submission_id_override = 0, $redirect = true)
{
    $submission_id = $submission_id_override ?: (isset($_GET['submission_id']) ? absint($_GET['submission_id']) : 0);

    if (!$submission_id || !current_user_can('manage_options')) {
        wp_die('Nincs jogosultságod ehhez a művelethez.');
    }

    if ($redirect) {
        check_admin_referer('huhs_approve_profile_submission_' . $submission_id);
    }

    $existing_profile_id = (int) get_post_meta($submission_id, 'created_profile_id', true);
    if ($existing_profile_id) {
        if ($redirect) {
            wp_safe_redirect(get_edit_post_link($existing_profile_id, 'raw'));
            exit;
        }
        return $existing_profile_id;
    }

    $type = get_post_meta($submission_id, 'submission_type', true);
    if (!in_array($type, array('artist', 'organizer', 'event'), true)) {
        wp_die('Ez a beküldéstípus nem alakítható piszkozattá.');
    }

    $is_artist = $type === 'artist';
    $is_event = $type === 'event';
    $title = $is_event
        ? get_the_title($submission_id)
        : get_post_meta($submission_id, $is_artist ? 'artist_name' : 'organizer_name', true);
    $content = get_post_meta($submission_id, $is_artist ? 'biography' : 'description', true);

    $profile_id = wp_insert_post(array(
        'post_type'    => $is_event ? 'huhs_event' : ($is_artist ? 'huhs_artist' : 'huhs_organizer'),
        'post_status'  => 'draft',
        'post_title'   => sanitize_text_field($title),
        'post_content' => sanitize_textarea_field($content),
    ), true);

    if (is_wp_error($profile_id)) {
        wp_die(esc_html($profile_id->get_error_message()));
    }

    if ($is_event) {
        foreach (array('event_start_date', 'event_start_time', 'event_end_date', 'event_end_time', 'venue_name', 'venue_city', 'venue_zip', 'venue_address', 'organizer_id') as $key) {
            $value = get_post_meta($submission_id, $key, true);
            if ($value !== '') {
                update_post_meta($profile_id, $key, $value);
            }
        }

        update_post_meta($profile_id, 'genre', get_post_meta($submission_id, 'genres', true));
        update_post_meta($profile_id, 'facebook_event_url', get_post_meta($submission_id, 'event_url', true));
        update_post_meta($profile_id, 'google_maps', huhs_event_maps_url(array(
            get_post_meta($profile_id, 'venue_name', true),
            get_post_meta($profile_id, 'venue_zip', true),
            get_post_meta($profile_id, 'venue_city', true),
            get_post_meta($profile_id, 'venue_address', true),
            get_post_meta($profile_id, 'venue_country', true),
        )));
        update_post_meta($profile_id, 'status', 'upcoming');
    } else {
        $common_fields = array('city', 'country', 'facebook', 'instagram', 'tiktok');
        $type_fields = $is_artist
            ? array('real_name', 'website', 'spotify', 'soundcloud', 'youtube', 'booking_email', 'booking_via_huhs')
            : array('website', 'genre');

        foreach (array_merge($common_fields, $type_fields) as $key) {
            $value = get_post_meta($submission_id, $key, true);
            if ($value !== '') {
                update_post_meta($profile_id, $key, $value);
            }
        }
    }

    if ($is_artist) {
        update_post_meta($profile_id, 'genre', get_post_meta($submission_id, 'genres', true));
        $categories = array_filter(explode(',', get_post_meta($submission_id, 'categories', true)));
        if ($categories) {
            wp_set_object_terms($profile_id, $categories, 'huhs_artist_category', false);
        }
    }

    $image_id = (int) get_post_meta($submission_id, 'submission_image_id', true);
    if ($image_id) {
        wp_update_post(array('ID' => $image_id, 'post_parent' => $profile_id));
        if ($is_event) {
            update_post_meta($profile_id, 'flyer_image', $image_id);
        } elseif ($is_artist) {
            update_post_meta($profile_id, 'hero_image', $image_id);
        } else {
            update_post_meta($profile_id, 'logo', $image_id);
        }
        set_post_thumbnail($profile_id, $image_id);
    }

    $submission_image_url = $is_event
        ? huhs_submission_image_url($submission_id, array('submission_image_url', 'event_flyer_url'))
        : ($is_artist
            ? huhs_submission_image_url($submission_id, array('submission_image_url', 'profile_image_url'))
            : huhs_submission_image_url($submission_id, array('submission_image_url', 'logo_url')));
    if ($submission_image_url !== '') {
        if ($is_event) {
            update_post_meta($profile_id, 'flyer_image_url', $submission_image_url);
        } elseif ($is_artist) {
            update_post_meta($profile_id, 'hero_image_url', $submission_image_url);
        } else {
            update_post_meta($profile_id, 'logo_url', $submission_image_url);
        }
    }

    if ($is_artist) {
        $logo_id = (int) get_post_meta($submission_id, 'submission_logo_id', true);
        if ($logo_id) {
            wp_update_post(array('ID' => $logo_id, 'post_parent' => $profile_id));
            update_post_meta($profile_id, 'logo', $logo_id);
        }
        $submission_logo_url = huhs_submission_image_url($submission_id, array('submission_logo_url', 'logo_url'));
        if ($submission_logo_url !== '') {
            update_post_meta($profile_id, 'logo_url', $submission_logo_url);
        }
    }

    update_post_meta($profile_id, 'featured', 0);
    update_post_meta($profile_id, 'visible', 0);
    update_post_meta($submission_id, 'created_profile_id', $profile_id);
    update_post_meta($submission_id, 'approval_status', 'approved_to_draft');
    wp_update_post(array('ID' => $submission_id, 'post_status' => 'publish'));

    if ($redirect) {
        wp_safe_redirect(get_edit_post_link($profile_id, 'raw'));
        exit;
    }
    return $profile_id;
}
