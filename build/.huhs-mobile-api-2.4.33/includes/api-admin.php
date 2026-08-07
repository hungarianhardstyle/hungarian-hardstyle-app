<?php

if (!defined('ABSPATH')) {
    exit;
}

define('HUHS_STARTUP_ANNOUNCEMENT_OPTION', 'huhs_startup_announcement');

add_action('rest_api_init', function () {
    register_rest_route('huhs/v1', '/admin', array(
        array(
            'methods' => WP_REST_Server::READABLE,
            'callback' => 'huhs_admin_api_read',
            'permission_callback' => 'huhs_admin_api_permission',
        ),
        array(
            'methods' => WP_REST_Server::CREATABLE,
            'callback' => 'huhs_admin_api_write',
            'permission_callback' => 'huhs_admin_api_permission',
        ),
    ));
    register_rest_route('huhs/v1', '/startup-announcement', array(
        'methods' => WP_REST_Server::READABLE,
        'callback' => 'huhs_startup_announcement_read',
        'permission_callback' => '__return_true',
    ));
});

add_action('admin_menu', function () {
    add_submenu_page(
        'huhs-mobile',
        'Indítási kép',
        'Indítási kép',
        'manage_options',
        'huhs-startup-announcement',
        'huhs_startup_announcement_page'
    );
});

add_action('admin_post_huhs_save_startup_announcement', function () {
    if (!current_user_can('manage_options')) {
        wp_die('Nincs jogosultság.');
    }
    check_admin_referer('huhs_save_startup_announcement');
    $value = array(
        'imageUrl' => esc_url_raw(wp_unslash($_POST['imageUrl'] ?? '')),
        'enabled' => !empty($_POST['enabled']),
    );
    if ($value['enabled'] && $value['imageUrl'] === '') {
        wp_safe_redirect(admin_url('admin.php?page=huhs-startup-announcement&error=missing_image'));
        exit;
    }
    update_option(HUHS_STARTUP_ANNOUNCEMENT_OPTION, $value, false);
    wp_safe_redirect(admin_url('admin.php?page=huhs-startup-announcement&saved=1'));
    exit;
});

function huhs_admin_api_permission()
{
    return current_user_can('manage_options');
}

function huhs_admin_api_read(WP_REST_Request $request)
{
    $action = sanitize_key((string) $request->get_param('action'));
    if ($action === 'dashboard') {
        return array(
            'artists' => (int) (wp_count_posts('huhs_artist')->publish ?? 0),
            'organizers' => (int) (wp_count_posts('huhs_organizer')->publish ?? 0),
            'events' => (int) (wp_count_posts('huhs_event')->publish ?? 0),
            'submissions' => (int) (wp_count_posts('huhs_submission')->pending ?? 0),
            'apiVersion' => HUHS_API_VERSION,
        );
    }
    if ($action === 'settings') {
        return array(
            'apiVersion' => HUHS_API_VERSION,
            'baseUrl' => rest_url('huhs/v1'),
            'imageUpload' => 'Cloudinary',
            'moderatedSubmissions' => true,
        );
    }
    if ($action === 'push') {
        $tokens = get_option(HUHS_PUSH_TOKENS_OPTION, array());
        $account = huhs_push_service_account();
        return array(
            'registeredDevices' => is_array($tokens) ? count($tokens) : 0,
            'configured' => !empty($account['project_id']) && !empty($account['client_email']) && !empty($account['private_key']),
        );
    }
    if ($action === 'newsletter') {
        $settings = get_option(HUHS_MAILCHIMP_OPTION, array());
        return array(
            'configured' => !empty($settings['api_key']) && !empty($settings['audience_id']),
            'audienceId' => sanitize_text_field((string) ($settings['audience_id'] ?? '')),
            'dataCenter' => sanitize_key((string) ($settings['data_center'] ?? '')),
        );
    }
    if ($action === 'shortcodes') {
        return array('items' => array(
            array('name' => '[huhs_djs]', 'description' => 'Teljes DJ-gyűjtő.'),
            array('name' => '[huhs_djs category="hardstyle"]', 'description' => 'Hardstyle DJ-k.'),
            array('name' => '[huhs_djs category="hardcore"]', 'description' => 'Hardcore DJ-k.'),
            array('name' => '[huhs_events]', 'description' => 'Közelgő események.'),
            array('name' => '[huhs_events include_past="true"]', 'description' => 'Események archívummal.'),
        ));
    }
    if ($action === 'about') {
        return array(
            'project' => 'Hungarian Hardstyle',
            'developer' => 'Denoiser',
            'apiVersion' => HUHS_API_VERSION,
            'website' => 'https://hungarianhardstyle.hu',
        );
    }
    if ($action === 'startup') {
        return huhs_startup_announcement_value();
    }
    if ($action === 'resource') {
        $post_id = absint($request->get_param('id'));
        $post_type = sanitize_key((string) $request->get_param('type'));
        $fields = huhs_admin_resource_fields($post_type);
        $post = get_post($post_id);
        if (!$post || $post->post_type !== $post_type || !$fields || !current_user_can('edit_post', $post_id)) {
            return new WP_Error('invalid_admin_resource', 'Az elem nem szerkeszthető.', array('status' => 404));
        }
        return array(
            'id' => $post_id,
            'title' => $post->post_title,
            'content' => $post->post_content,
            'status' => $post->post_status,
            'fields' => array_map(function ($field) use ($post_id) {
                $field['value'] = get_post_meta($post_id, $field['key'], true);
                $options = huhs_admin_resource_field_options($field['key']);
                if ($options) {
                    $field['options'] = $options;
                }
                return $field;
            }, $fields),
        );
    }
    if ($action === 'trash') {
        $items = array();
        foreach (huhs_trash_post_types() as $post_type) {
            foreach (get_posts(array(
                'post_type' => $post_type,
                'post_status' => 'trash',
                'posts_per_page' => -1,
                'orderby' => 'modified',
                'order' => 'DESC',
            )) as $post) {
                $items[] = array(
                    'id' => (int) $post->ID,
                    'title' => get_the_title($post),
                    'type' => $post_type,
                    'modified' => get_post_modified_time(DATE_ATOM, false, $post),
                );
            }
        }
        return array('items' => $items);
    }
    return new WP_Error('invalid_admin_action', 'Ismeretlen admin művelet.', array('status' => 400));
}

function huhs_admin_api_write(WP_REST_Request $request)
{
    $params = $request->get_json_params();
    $action = sanitize_key((string) ($params['action'] ?? ''));
    if ($action === 'send_push') {
        $title = sanitize_text_field((string) ($params['title'] ?? ''));
        $body = sanitize_textarea_field((string) ($params['body'] ?? ''));
        if ($title === '' || $body === '') {
            return new WP_Error('missing_push_content', 'A cím és az üzenet kötelező.', array('status' => 400));
        }
        return array('sent' => huhs_push_send($title, $body, array('type' => 'custom')));
    }
    if ($action === 'empty_trash') {
        $deleted = 0;
        foreach (huhs_trash_post_types() as $post_type) {
            $ids = get_posts(array(
                'post_type' => $post_type,
                'post_status' => 'trash',
                'posts_per_page' => -1,
                'fields' => 'ids',
            ));
            foreach ($ids as $post_id) {
                huhs_delete_submission_attachments($post_id);
                if (wp_delete_post($post_id, true)) {
                    $deleted++;
                }
            }
        }
        return array('deleted' => $deleted);
    }
    if ($action === 'restore') {
        $post_id = absint($params['id'] ?? 0);
        if (!$post_id || get_post_status($post_id) !== 'trash' || !in_array(get_post_type($post_id), huhs_trash_post_types(), true)) {
            return new WP_Error('invalid_trash_item', 'A lomtárelem nem állítható vissza.', array('status' => 400));
        }
        return array('restored' => (bool) wp_untrash_post($post_id));
    }
    if ($action === 'save_settings') {
        foreach (array('blogname', 'blogdescription', 'timezone_string', 'date_format', 'time_format') as $key) {
            if (array_key_exists($key, $params)) {
                update_option($key, sanitize_text_field((string) $params[$key]));
            }
        }
        return array('saved' => true);
    }
    if ($action === 'save_startup') {
        $value = array(
            'imageUrl' => esc_url_raw((string) ($params['imageUrl'] ?? '')),
            'enabled' => filter_var($params['enabled'] ?? false, FILTER_VALIDATE_BOOLEAN),
        );
        if ($value['enabled'] && $value['imageUrl'] === '') {
            return new WP_Error('missing_startup_image', 'Bekapcsolva kép URL szükséges.', array('status' => 400));
        }
        update_option(HUHS_STARTUP_ANNOUNCEMENT_OPTION, $value, false);
        return array('saved' => true) + $value;
    }
    if ($action === 'save_resource') {
        $post_id = absint($params['id'] ?? 0);
        $post_type = sanitize_key((string) ($params['type'] ?? ''));
        $fields = huhs_admin_resource_fields($post_type);
        $post = get_post($post_id);
        if (!$post || $post->post_type !== $post_type || !$fields || !current_user_can('edit_post', $post_id)) {
            return new WP_Error('invalid_admin_resource', 'Az elem nem szerkeszthető.', array('status' => 404));
        }
        $content = $post->post_content;
        if (!empty($params['contentChanged'])) {
            $content = wpautop(esc_html(wp_unslash((string) ($params['content'] ?? ''))));
        }
        $updated = wp_update_post(array(
            'ID' => $post_id,
            'post_title' => sanitize_text_field((string) ($params['title'] ?? $post->post_title)),
            'post_content' => $content,
        ), true);
        if (is_wp_error($updated)) {
            return $updated;
        }
        $values = is_array($params['meta'] ?? null) ? $params['meta'] : array();
        foreach ($fields as $field) {
            $key = $field['key'];
            if (!array_key_exists($key, $values)) {
                continue;
            }
            $value = $values[$key];
            if ($field['type'] === 'bool') {
                $value = filter_var($value, FILTER_VALIDATE_BOOLEAN) ? 1 : 0;
            } elseif ($field['type'] === 'int') {
                $value = absint($value);
            } elseif ($field['type'] === 'url') {
                $value = esc_url_raw((string) $value);
            } elseif ($field['type'] === 'email') {
                $value = sanitize_email((string) $value);
            } elseif ($field['type'] === 'ids') {
                $value = wp_json_encode(array_values(array_filter(array_map(
                    'absint',
                    preg_split('/[\s,]+/', (string) $value)
                ))));
            } else {
                $value = sanitize_text_field((string) $value);
            }
            update_post_meta($post_id, $key, $value);
        }
        return array('saved' => true, 'id' => $post_id);
    }
    return new WP_Error('invalid_admin_action', 'Ismeretlen admin művelet.', array('status' => 400));
}

function huhs_admin_resource_fields($post_type)
{
    $common = array(
        array('key' => 'featured', 'label' => 'Kiemelt', 'type' => 'bool'),
        array('key' => 'visible', 'label' => 'Látható az appban', 'type' => 'bool'),
    );
    if ($post_type === 'huhs_event') {
        return array_merge(array(
            array('key' => 'event_start_date', 'label' => 'Kezdő dátum', 'type' => 'text'),
            array('key' => 'event_start_time', 'label' => 'Kezdő idő', 'type' => 'text'),
            array('key' => 'event_end_date', 'label' => 'Záró dátum', 'type' => 'text'),
            array('key' => 'event_end_time', 'label' => 'Záró idő', 'type' => 'text'),
            array('key' => 'venue_name', 'label' => 'Helyszín', 'type' => 'text'),
            array('key' => 'venue_city', 'label' => 'Város', 'type' => 'text'),
            array('key' => 'venue_zip', 'label' => 'Irányítószám', 'type' => 'text'),
            array('key' => 'venue_address', 'label' => 'Cím', 'type' => 'text'),
            array('key' => 'venue_country', 'label' => 'Ország', 'type' => 'text'),
            array('key' => 'google_maps', 'label' => 'Google Maps', 'type' => 'url'),
            array('key' => 'facebook_event_url', 'label' => 'Facebook esemény', 'type' => 'url'),
            array('key' => 'ticket_type', 'label' => 'Jegytípus', 'type' => 'text'),
            array('key' => 'ticket_url', 'label' => 'Jegyvásárlás', 'type' => 'url'),
            array('key' => 'genre', 'label' => 'Műfajok', 'type' => 'text'),
            array('key' => 'organizer_id', 'label' => 'Szervező ID', 'type' => 'int'),
            array('key' => 'artists', 'label' => 'DJ ID-k (vesszővel)', 'type' => 'ids'),
            array('key' => 'status', 'label' => 'Esemény állapota', 'type' => 'text'),
            array('key' => 'flyer_image', 'label' => 'Flyer média ID', 'type' => 'int'),
        ), $common);
    }
    if ($post_type === 'huhs_artist') {
        return array_merge(array(
            array('key' => 'real_name', 'label' => 'Polgári név', 'type' => 'text'),
            array('key' => 'country', 'label' => 'Ország', 'type' => 'text'),
            array('key' => 'city', 'label' => 'Város', 'type' => 'text'),
            array('key' => 'website', 'label' => 'Website', 'type' => 'url'),
            array('key' => 'genre', 'label' => 'Műfajok', 'type' => 'text'),
            array('key' => 'facebook', 'label' => 'Facebook', 'type' => 'url'),
            array('key' => 'instagram', 'label' => 'Instagram', 'type' => 'url'),
            array('key' => 'tiktok', 'label' => 'TikTok', 'type' => 'url'),
            array('key' => 'spotify', 'label' => 'Spotify', 'type' => 'url'),
            array('key' => 'soundcloud', 'label' => 'SoundCloud', 'type' => 'url'),
            array('key' => 'youtube', 'label' => 'YouTube', 'type' => 'url'),
            array('key' => 'booking_email', 'label' => 'Booking e-mail', 'type' => 'email'),
            array('key' => 'booking_via_huhs', 'label' => 'Booking a Hungarian Hardstyle-on keresztül', 'type' => 'bool'),
            array('key' => 'hero_image', 'label' => 'Profilkép média ID', 'type' => 'int'),
            array('key' => 'logo', 'label' => 'Logó média ID', 'type' => 'int'),
        ), $common);
    }
    if ($post_type === 'huhs_organizer') {
        return array_merge(array(
            array('key' => 'website', 'label' => 'Website', 'type' => 'url'),
            array('key' => 'facebook', 'label' => 'Facebook', 'type' => 'url'),
            array('key' => 'instagram', 'label' => 'Instagram', 'type' => 'url'),
            array('key' => 'tiktok', 'label' => 'TikTok', 'type' => 'url'),
            array('key' => 'email', 'label' => 'E-mail', 'type' => 'email'),
            array('key' => 'phone', 'label' => 'Telefon', 'type' => 'text'),
            array('key' => 'city', 'label' => 'Város', 'type' => 'text'),
            array('key' => 'country', 'label' => 'Ország', 'type' => 'text'),
            array('key' => 'genre', 'label' => 'Műfajok', 'type' => 'text'),
            array('key' => 'logo', 'label' => 'Logó média ID', 'type' => 'int'),
        ), $common);
    }
    if ($post_type === 'huhs_release') {
        return array_merge(array(
            array('key' => 'genre', 'label' => 'Műfaj', 'type' => 'text'),
            array('key' => 'artists', 'label' => 'Előadó ID-k (vesszővel)', 'type' => 'ids'),
            array('key' => 'cover', 'label' => 'Borító média ID', 'type' => 'int'),
            array('key' => 'preview_url', 'label' => 'Preview MP3 URL', 'type' => 'url'),
            array('key' => 'spotify', 'label' => 'Spotify', 'type' => 'url'),
            array('key' => 'apple_music', 'label' => 'Apple Music', 'type' => 'url'),
            array('key' => 'beatport', 'label' => 'Beatport', 'type' => 'url'),
            array('key' => 'hardstyle_com', 'label' => 'Hardstyle.com', 'type' => 'url'),
            array('key' => 'youtube', 'label' => 'YouTube', 'type' => 'url'),
        ), $common);
    }
    return array();
}

function huhs_admin_resource_field_options($key)
{
    if ($key === 'artists') {
        return array_map(function ($post) {
            return array('id' => (int) $post->ID, 'label' => $post->post_title);
        }, get_posts(array(
            'post_type' => 'huhs_artist',
            'post_status' => 'publish',
            'posts_per_page' => -1,
            'orderby' => 'title',
            'order' => 'ASC',
        )));
    }
    if ($key === 'organizer_id') {
        return array_map(function ($post) {
            return array('id' => (int) $post->ID, 'label' => $post->post_title);
        }, get_posts(array(
            'post_type' => 'huhs_organizer',
            'post_status' => 'publish',
            'posts_per_page' => -1,
            'orderby' => 'title',
            'order' => 'ASC',
        )));
    }
    return array();
}

function huhs_startup_announcement_value()
{
    $value = get_option(HUHS_STARTUP_ANNOUNCEMENT_OPTION, array());
    return array(
        'imageUrl' => esc_url_raw((string) ($value['imageUrl'] ?? '')),
        'enabled' => !empty($value['enabled']),
    );
}

function huhs_startup_announcement_read()
{
    $response = new WP_REST_Response(huhs_startup_announcement_value());
    $response->header('Cache-Control', 'no-store, no-cache, must-revalidate, max-age=0');
    return $response;
}

function huhs_startup_announcement_page()
{
    $value = huhs_startup_announcement_value();
    ?>
    <div class="wrap">
        <h1>Indítási kép</h1>
        <p>A kép az alkalmazás következő indításakor minden felhasználónál megjelenik, amíg ki nem kapcsolod vagy el nem távolítod.</p>
        <?php if (!empty($_GET['saved'])) : ?><div class="notice notice-success"><p>Beállítás mentve.</p></div><?php endif; ?>
        <?php if (!empty($_GET['error'])) : ?><div class="notice notice-error"><p>Bekapcsolva kép URL szükséges.</p></div><?php endif; ?>
        <form method="post" action="<?php echo esc_url(admin_url('admin-post.php')); ?>">
            <input type="hidden" name="action" value="huhs_save_startup_announcement">
            <?php wp_nonce_field('huhs_save_startup_announcement'); ?>
            <table class="form-table"><tbody>
                <tr>
                    <th><label for="huhs-startup-image">Kép</label></th>
                    <td>
                        <input class="large-text" type="url" id="huhs-startup-image" name="imageUrl" value="<?php echo esc_attr($value['imageUrl']); ?>">
                        <p><button type="button" class="button huhs-image-upload" data-target="huhs-startup-image" data-value="url">Feltöltés vagy kiválasztás</button></p>
                        <img id="huhs-startup-image_preview" src="<?php echo esc_url($value['imageUrl']); ?>" alt="" style="display:block;max-width:420px;max-height:240px;object-fit:contain;">
                    </td>
                </tr>
                <tr><th>Megjelenítés</th><td><label><input type="checkbox" name="enabled" value="1" <?php checked($value['enabled']); ?>> Engedélyezve</label></td></tr>
            </tbody></table>
            <?php submit_button('Mentés'); ?>
        </form>
    </div>
    <?php
}
