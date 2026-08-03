<?php

if (!defined('ABSPATH')) {
    exit;
}

define('HUHS_PUSH_TOKENS_OPTION', 'huhs_push_tokens');
define('HUHS_PUSH_SERVICE_ACCOUNT_OPTION', 'huhs_firebase_service_account');

add_action('rest_api_init', function () {
    register_rest_route('huhs/v1', '/push/register', array(
        'methods' => 'POST',
        'callback' => 'huhs_push_register_token',
        'permission_callback' => '__return_true',
    ));
    register_rest_route('huhs/v1', '/push/preferences', array(
        'methods' => 'POST',
        'callback' => 'huhs_push_update_preferences',
        'permission_callback' => '__return_true',
    ));
});

function huhs_push_register_token(WP_REST_Request $request)
{
    $params = $request->get_json_params();
    $token = sanitize_text_field((string) ($params['token'] ?? $request->get_param('token')));
    $platform = sanitize_key((string) ($params['platform'] ?? 'android'));

    if (strlen($token) < 20 || strlen($token) > 4096) {
        return new WP_Error('invalid_push_token', 'Érvénytelen FCM token.', array('status' => 400));
    }

    $tokens = get_option(HUHS_PUSH_TOKENS_OPTION, array());
    if (!is_array($tokens)) $tokens = array();

    $key = hash('sha256', $token);
    $existing = is_array($tokens[$key] ?? null) ? $tokens[$key] : array();
    $tokens[$key] = array_merge($existing, array(
        'token' => $token,
        'platform' => $platform,
        'updated_at' => current_time('mysql', true),
    ));

    if (count($tokens) > 500) {
        uasort($tokens, function ($left, $right) {
            return strcmp((string) ($right['updated_at'] ?? ''), (string) ($left['updated_at'] ?? ''));
        });
        $tokens = array_slice($tokens, 0, 500, true);
    }

    update_option(HUHS_PUSH_TOKENS_OPTION, $tokens, false);
    return new WP_REST_Response(array('registered' => true), 200);
}

function huhs_push_update_preferences(WP_REST_Request $request)
{
    $params = $request->get_json_params();
    $token = sanitize_text_field((string) ($params['token'] ?? $request->get_param('token')));
    if (strlen($token) < 20 || strlen($token) > 4096) {
        return new WP_Error('invalid_push_token', 'Érvénytelen FCM token.', array('status' => 400));
    }

    $tokens = get_option(HUHS_PUSH_TOKENS_OPTION, array());
    if (!is_array($tokens)) $tokens = array();
    $key = hash('sha256', $token);
    $record = is_array($tokens[$key] ?? null) ? $tokens[$key] : array();
    $tokens[$key] = array_merge($record, array(
        'token' => $token,
        'enabled' => filter_var($params['enabled'] ?? true, FILTER_VALIDATE_BOOLEAN),
        'news' => filter_var($params['news'] ?? true, FILTER_VALIDATE_BOOLEAN),
        'events' => filter_var($params['events'] ?? true, FILTER_VALIDATE_BOOLEAN),
        'reminders' => filter_var($params['reminders'] ?? true, FILTER_VALIDATE_BOOLEAN),
        'updated_at' => current_time('mysql', true),
    ));
    update_option(HUHS_PUSH_TOKENS_OPTION, $tokens, false);
    return new WP_REST_Response(array('saved' => true), 200);
}

function huhs_push_base64url($value)
{
    return rtrim(strtr(base64_encode($value), '+/', '-_'), '=');
}

function huhs_push_service_account()
{
    $account = get_option(HUHS_PUSH_SERVICE_ACCOUNT_OPTION, array());
    return is_array($account) ? $account : array();
}

function huhs_push_access_token()
{
    $cached = get_transient('huhs_firebase_access_token');
    if (is_string($cached) && $cached !== '') return $cached;

    $account = huhs_push_service_account();
    $project = sanitize_key((string) ($account['project_id'] ?? ''));
    $client_email = sanitize_email((string) ($account['client_email'] ?? ''));
    $private_key = (string) ($account['private_key'] ?? '');
    if (!$project || !$client_email || !$private_key || !function_exists('openssl_sign')) return '';

    $private_key = str_replace('\\n', "\n", $private_key);
    $now = time();
    $header = huhs_push_base64url(wp_json_encode(array('alg' => 'RS256', 'typ' => 'JWT')));
    $claims = huhs_push_base64url(wp_json_encode(array(
        'iss' => $client_email,
        'scope' => 'https://www.googleapis.com/auth/firebase.messaging',
        'aud' => 'https://oauth2.googleapis.com/token',
        'iat' => $now,
        'exp' => $now + 3600,
    )));
    $unsigned = $header . '.' . $claims;
    if (!openssl_sign($unsigned, $signature, $private_key, OPENSSL_ALGO_SHA256)) return '';

    $response = wp_remote_post('https://oauth2.googleapis.com/token', array(
        'timeout' => 15,
        'body' => array(
            'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
            'assertion' => $unsigned . '.' . huhs_push_base64url($signature),
        ),
    ));
    if (is_wp_error($response)) return '';

    $body = json_decode(wp_remote_retrieve_body($response), true);
    $access_token = (string) ($body['access_token'] ?? '');
    if ($access_token !== '') set_transient('huhs_firebase_access_token', $access_token, 3500);
    return $access_token;
}

function huhs_push_send($title, $body, $data = array())
{
    $title = html_entity_decode(wp_strip_all_tags((string) $title), ENT_QUOTES | ENT_HTML5, 'UTF-8');
    $body = html_entity_decode(wp_strip_all_tags((string) $body), ENT_QUOTES | ENT_HTML5, 'UTF-8');
    $account = huhs_push_service_account();
    $project = sanitize_key((string) ($account['project_id'] ?? ''));
    $access_token = huhs_push_access_token();
    if (!$project || !$access_token) return 0;

    $tokens = get_option(HUHS_PUSH_TOKENS_OPTION, array());
    if (!is_array($tokens)) return 0;
    $sent = 0;

    foreach ($tokens as $key => $record) {
        $token = (string) ($record['token'] ?? '');
        if ($token === '') continue;
        if (array_key_exists('enabled', $record) && !$record['enabled']) continue;
        $type = (string) ($data['type'] ?? 'custom');
        if ($type === 'news' && array_key_exists('news', $record) && !$record['news']) continue;
        if ($type === 'event' && array_key_exists('events', $record) && !$record['events']) continue;
        if (!empty($data['kind']) && array_key_exists('reminders', $record) && !$record['reminders']) continue;
        $response = wp_remote_post(
            'https://fcm.googleapis.com/v1/projects/' . rawurlencode($project) . '/messages:send',
            array(
                'timeout' => 15,
                'headers' => array(
                    'Authorization' => 'Bearer ' . $access_token,
                    'Content-Type' => 'application/json',
                ),
                'body' => wp_json_encode(array('message' => array(
                    'token' => $token,
                    'notification' => array('title' => (string) $title, 'body' => (string) $body),
                    'data' => array_map('strval', $data),
                    'android' => array('priority' => 'high'),
                )), JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES),
            )
        );

        if (!is_wp_error($response) && wp_remote_retrieve_response_code($response) >= 200 && wp_remote_retrieve_response_code($response) < 300) {
            $sent++;
        }
    }

    return $sent;
}

add_action('transition_post_status', 'huhs_push_on_publish', 10, 3);
function huhs_push_on_publish($new_status, $old_status, $post)
{
    if ($new_status !== 'publish' || $old_status === 'publish' || wp_is_post_revision($post) || !$post) return;

    if ($post->post_type === 'post') {
        huhs_push_send('Új hír', get_the_title($post), array('type' => 'news', 'id' => (string) $post->ID));
    }

    if ($post->post_type === 'huhs_event') {
        huhs_push_send('Új esemény', get_the_title($post), array('type' => 'event', 'id' => (string) $post->ID));
        huhs_push_schedule_event_reminders($post);
    }
}

function huhs_push_schedule_event_reminders($post)
{
    $date = get_post_meta($post->ID, 'event_start_date', true);
    $time = get_post_meta($post->ID, 'event_start_time', true) ?: '12:00';
    if (!$date) return;
    $timestamp = wp_date('U', strtotime($date . ' ' . $time), wp_timezone());
    if (!$timestamp || $timestamp <= time()) return;

    foreach (array(
        'week' => $timestamp - WEEK_IN_SECONDS,
        'day_before' => $timestamp - DAY_IN_SECONDS,
        'hours_before' => $timestamp - 6 * HOUR_IN_SECONDS,
    ) as $kind => $when) {
        if ($when > time() && !wp_next_scheduled('huhs_push_event_reminder', array($post->ID, $kind))) {
            wp_schedule_single_event($when, 'huhs_push_event_reminder', array($post->ID, $kind));
        }
    }
}

// WP-Cron may not run at the exact event timestamp. Keep a small recurring
// safety scan so the reminder is sent on the next site cron request instead
// of being lost permanently.
add_filter('cron_schedules', function ($schedules) {
    if (!isset($schedules['huhs_five_minutes'])) {
        $schedules['huhs_five_minutes'] = array(
            'interval' => 5 * MINUTE_IN_SECONDS,
            'display' => 'HUHS every five minutes',
        );
    }
    return $schedules;
});

add_action('init', function () {
    if (!wp_next_scheduled('huhs_push_event_reminder_scan')) {
        wp_schedule_event(time() + 60, 'huhs_five_minutes', 'huhs_push_event_reminder_scan');
    }
});

add_action('huhs_push_event_reminder_scan', 'huhs_push_scan_event_reminders');
function huhs_push_scan_event_reminders()
{
    $now = current_time('timestamp');
    $events = get_posts(array(
        'post_type' => 'huhs_event',
        'post_status' => 'publish',
        'posts_per_page' => 500,
        'fields' => 'all',
    ));

    foreach ($events as $post) {
        $date = get_post_meta($post->ID, 'event_start_date', true);
        $time = get_post_meta($post->ID, 'event_start_time', true) ?: '12:00';
        if (!$date) continue;
        $timestamp = wp_date('U', strtotime($date . ' ' . $time), wp_timezone());
        if (!$timestamp) continue;
        $timestamp = (int) $timestamp;
        $kinds = array();
        if ($now >= $timestamp - 6 * HOUR_IN_SECONDS && $now < $timestamp - 5 * HOUR_IN_SECONDS) {
            $kinds[] = 'hours_before';
        }
        if ($now >= $timestamp - DAY_IN_SECONDS && $now < $timestamp - 23 * HOUR_IN_SECONDS) {
            $kinds[] = 'day_before';
        }
        if ($now >= $timestamp - WEEK_IN_SECONDS && $now < $timestamp - 6 * DAY_IN_SECONDS) {
            $kinds[] = 'week';
        }
        foreach ($kinds as $kind) {
            huhs_push_event_reminder($post->ID, $kind);
        }
    }
}

add_action('save_post_huhs_event', function ($post_id, $post, $update) {
    if (!$post || wp_is_post_revision($post_id) || wp_is_post_autosave($post_id) || $post->post_status !== 'publish') return;
    huhs_push_schedule_event_reminders($post);
}, 20, 3);

add_action('huhs_push_event_reminder', 'huhs_push_event_reminder', 10, 2);
function huhs_push_event_reminder($post_id, $kind)
{
    $post = get_post($post_id);
    if (!$post || $post->post_status !== 'publish') return;
    $marker = '_huhs_push_reminder_sent_' . sanitize_key($kind);
    if (get_post_meta($post_id, $marker, true)) return;
    $sent = huhs_push_send(
        $kind === 'week'
            ? 'Esemény egy hét múlva'
            : ($kind === 'day_before' ? 'Esemény holnap' : 'Esemény ma'),
        get_the_title($post),
        array('type' => 'event', 'kind' => 'reminder', 'id' => (string) $post_id)
    );
    if ($sent > 0) update_post_meta($post_id, $marker, current_time('mysql', true));
}

add_action('admin_menu', function () {
    add_submenu_page('huhs-mobile', 'Push értesítések', 'Push értesítések', 'manage_options', 'huhs-push', 'huhs_push_admin_page');
});

add_action('admin_post_huhs_save_push_settings', function () {
    if (!current_user_can('manage_options')) wp_die('Nincs jogosultság.');
    check_admin_referer('huhs_save_push_settings');
    $account = array(
        'project_id' => sanitize_key(wp_unslash($_POST['project_id'] ?? '')),
        'client_email' => sanitize_email(wp_unslash($_POST['client_email'] ?? '')),
        'private_key' => sanitize_textarea_field(wp_unslash($_POST['private_key'] ?? '')),
    );

    if (!empty($_FILES['service_account_json']['tmp_name'])) {
        $json = file_get_contents($_FILES['service_account_json']['tmp_name']);
        $decoded = json_decode($json, true);
        $uploaded = is_array($decoded) ? array(
                'project_id' => sanitize_key((string) ($decoded['project_id'] ?? '')),
                'client_email' => sanitize_email((string) ($decoded['client_email'] ?? '')),
                'private_key' => sanitize_textarea_field((string) ($decoded['private_key'] ?? '')),
            ) : array();
        if (empty($uploaded['project_id']) || empty($uploaded['client_email']) || empty($uploaded['private_key'])) {
            wp_safe_redirect(admin_url('admin.php?page=huhs-push&error=invalid_json'));
            exit;
        }
        $account = $uploaded;
    }

    update_option(HUHS_PUSH_SERVICE_ACCOUNT_OPTION, $account, false);
    wp_safe_redirect(admin_url('admin.php?page=huhs-push&saved=1'));
    exit;
});

add_action('admin_post_huhs_send_custom_push', function () {
    if (!current_user_can('manage_options')) wp_die('Nincs jogosultság.');
    check_admin_referer('huhs_send_custom_push');
    $title = sanitize_text_field(wp_unslash($_POST['title'] ?? ''));
    $body = sanitize_textarea_field(wp_unslash($_POST['body'] ?? ''));
    $target_type = sanitize_key(wp_unslash($_POST['target_type'] ?? 'none'));
    $target_id = absint($_POST['target_id'] ?? 0);
    $url = '';
    if (in_array($target_type, array('news', 'event'), true) && $target_id > 0) {
        $target_post = get_post($target_id);
        $expected_type = $target_type === 'news' ? 'post' : 'huhs_event';
        if (!$target_post || $target_post->post_status !== 'publish' || $target_post->post_type !== $expected_type) {
            $target_id = 0;
        } else {
            $url = get_permalink($target_id) ?: '';
        }
    } elseif ($target_type === 'url') {
        $url = esc_url_raw(wp_unslash($_POST['target_url'] ?? ''));
    }
    $payload_type = $target_type === 'none' ? 'custom' : $target_type;
    $payload_id = $target_id;
    if ($target_type === 'url' && $url !== '') {
        $resolved_id = url_to_postid($url);
        $resolved_post = $resolved_id ? get_post($resolved_id) : null;
        if ($resolved_post && $resolved_post->post_status === 'publish') {
            if ($resolved_post->post_type === 'post') {
                $payload_type = 'news';
                $payload_id = (int) $resolved_post->ID;
            } elseif ($resolved_post->post_type === 'huhs_event') {
                $payload_type = 'event';
                $payload_id = (int) $resolved_post->ID;
            }
        }
    }
    if ($title !== '' && $body !== '') {
        huhs_push_send($title, $body, array(
            'type' => $payload_type,
            'id' => $payload_id > 0 ? (string) $payload_id : '',
            'url' => $url,
        ));
    }
    wp_safe_redirect(admin_url('admin.php?page=huhs-push&sent=1'));
    exit;
});

function huhs_push_admin_page()
{
    if (!current_user_can('manage_options')) return;
    $account = huhs_push_service_account();
    $tokens = get_option(HUHS_PUSH_TOKENS_OPTION, array());
    $push_news = get_posts(array(
        'post_type' => 'post',
        'post_status' => 'publish',
        'posts_per_page' => 30,
        'orderby' => 'date',
        'order' => 'DESC',
    ));
    $push_events = get_posts(array(
        'post_type' => 'huhs_event',
        'post_status' => 'publish',
        'posts_per_page' => 30,
        'orderby' => 'date',
        'order' => 'DESC',
    ));
    ?>
    <div class="wrap">
        <h1>HUHS Mobile push értesítések</h1>
        <p>Firebase szolgáltatásfiók adatai csak itt, a WordPress szerveren tárolhatók. Ezeket ne tedd az appba vagy a Git repóba.</p>
        <form method="post" enctype="multipart/form-data" action="<?php echo esc_url(admin_url('admin-post.php')); ?>">
            <input type="hidden" name="action" value="huhs_save_push_settings">
            <?php wp_nonce_field('huhs_save_push_settings'); ?>
            <p><strong>Egyszerű megoldás:</strong> töltsd fel a Firebase Console-ból letöltött szolgáltatásfiók JSON-fájlt.</p>
            <p><input type="file" name="service_account_json" accept="application/json,.json"></p>
            <p>Vagy töltsd ki kézzel a mezőket:</p>
            <table class="form-table"><tbody>
                <tr><th><label for="project_id">Firebase project ID</label></th><td><input class="regular-text" id="project_id" name="project_id" value="<?php echo esc_attr($account['project_id'] ?? ''); ?>"></td></tr>
                <tr><th><label for="client_email">Service account e-mail</label></th><td><input class="regular-text" id="client_email" name="client_email" value="<?php echo esc_attr($account['client_email'] ?? ''); ?>"></td></tr>
                <tr><th><label for="private_key">Private key</label></th><td><textarea class="large-text code" rows="8" id="private_key" name="private_key"><?php echo esc_textarea($account['private_key'] ?? ''); ?></textarea></td></tr>
            </tbody></table>
            <?php submit_button('Mentés'); ?>
        </form>
        <p>Regisztrált eszközök: <strong><?php echo esc_html(is_array($tokens) ? count($tokens) : 0); ?></strong></p>
        <hr>
        <h2>Egyedi push küldése</h2>
        <form method="post" action="<?php echo esc_url(admin_url('admin-post.php')); ?>">
            <input type="hidden" name="action" value="huhs_send_custom_push">
            <?php wp_nonce_field('huhs_send_custom_push'); ?>
            <p><label for="target_type">Megnyitandó tartalom</label>
                <select id="target_type" name="target_type">
                    <option value="none">Nincs cél</option>
                    <option value="news">Hír (azonosító)</option>
                    <option value="event">Esemény (azonosító)</option>
                    <option value="url">Egyedi link</option>
                </select>
            </p>
            <p><label for="target_id">Hír vagy esemény</label>
                <select id="target_id" name="target_id">
                    <option value="">Válassz tartalmat...</option>
                    <?php if ($push_news) : ?>
                        <optgroup label="Hírek">
                            <?php foreach ($push_news as $push_post) : ?>
                                <option value="<?php echo esc_attr($push_post->ID); ?>" data-target-type="news"><?php echo esc_html($push_post->post_title); ?></option>
                            <?php endforeach; ?>
                        </optgroup>
                    <?php endif; ?>
                    <?php if ($push_events) : ?>
                        <optgroup label="Események">
                            <?php foreach ($push_events as $push_event) : ?>
                                <option value="<?php echo esc_attr($push_event->ID); ?>" data-target-type="event"><?php echo esc_html($push_event->post_title); ?></option>
                            <?php endforeach; ?>
                        </optgroup>
                    <?php endif; ?>
                </select>
            </p>
            <p><label for="target_url">Egyedi link</label> <input class="regular-text" type="url" id="target_url" name="target_url" placeholder="https://..."></p>
            <table class="form-table"><tbody>
                <tr><th><label for="push_title">Cím</label></th><td><input class="regular-text" id="push_title" name="title" required></td></tr>
                <tr><th><label for="push_body">Üzenet</label></th><td><textarea class="large-text" rows="4" id="push_body" name="body" required></textarea></td></tr>
            </tbody></table>
            <?php submit_button('Push küldése', 'secondary'); ?>
        </form>
    </div>
    <?php
}
