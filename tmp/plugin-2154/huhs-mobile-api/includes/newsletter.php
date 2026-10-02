<?php

if (!defined('ABSPATH')) {
    exit;
}

define('HUHS_MAILCHIMP_OPTION', 'huhs_mailchimp_settings');

add_action('rest_api_init', function () {
    register_rest_route('huhs/v1', '/newsletter/subscribe', array(
        'methods' => 'POST',
        'callback' => 'huhs_newsletter_subscribe',
        'permission_callback' => '__return_true',
    ));
});

function huhs_newsletter_subscribe(WP_REST_Request $request)
{
    if (huhs_ip_rate_limited('newsletter_subscribe', 5, 60)) {
        return new WP_Error('rate_limited', 'Túl sok feliratkozási kérés. Próbáld újra később.', array('status' => 429));
    }
    $params = $request->get_json_params();
    $email = sanitize_email((string) ($params['email'] ?? $request->get_param('email')));
    $consent = filter_var($params['consent'] ?? $request->get_param('consent'), FILTER_VALIDATE_BOOLEAN);

    if (!is_email($email)) {
        return new WP_Error('invalid_email', 'Adj meg érvényes e-mail-címet.', array('status' => 400));
    }
    if (!$consent) {
        return new WP_Error('consent_required', 'A feliratkozáshoz szükséges a hozzájárulás.', array('status' => 400));
    }

    $settings = get_option(HUHS_MAILCHIMP_OPTION, array());
    $api_key = trim((string) ($settings['api_key'] ?? ''));
    $audience_id = sanitize_text_field((string) ($settings['audience_id'] ?? ''));
    $data_center = sanitize_key((string) ($settings['data_center'] ?? ''));
    if ($data_center === '' && preg_match('/-([a-z0-9]+)$/i', $api_key, $match)) {
        $data_center = strtolower($match[1]);
    }

    if ($api_key === '' || $audience_id === '' || $data_center === '') {
        return new WP_Error('newsletter_not_configured', 'A hírlevél-feliratkozás még nincs beállítva.', array('status' => 503));
    }

    $base_url = 'https://' . rawurlencode($data_center) . '.api.mailchimp.com/3.0/lists/' . rawurlencode($audience_id) . '/members';
    $auth_headers = array(
        'Authorization' => 'Basic ' . base64_encode('hu-hs:' . $api_key),
        'Content-Type' => 'application/json',
    );
    $subscriber_hash = md5(strtolower($email));

    // A new double-opt-in contact must be created with POST + status=pending.
    // PUT + status_if_new only applies the pending status when the member is
    // new, and does not reliably start the confirmation flow for existing
    // pending/unsubscribed members.
    $existing = wp_remote_get($base_url . '/' . $subscriber_hash, array(
        'timeout' => 15,
        'headers' => $auth_headers,
    ));
    $existing_status = '';
    if (!is_wp_error($existing) && wp_remote_retrieve_response_code($existing) >= 200 && wp_remote_retrieve_response_code($existing) < 300) {
        $existing_data = json_decode(wp_remote_retrieve_body($existing), true);
        $existing_status = sanitize_key((string) ($existing_data['status'] ?? ''));
        if ($existing_status === 'subscribed') {
            return new WP_REST_Response(array('subscribed' => true, 'already_subscribed' => true, 'double_opt_in' => false, 'state' => 'subscribed'), 200);
        }
    }

    // CÍM-ALAPÚ ÚJRAKÜLDÉS-VÉDELEM (2026-09-24): ugyanarra a címre a megerősítő
    // e-mailt nem küldjük ki minden egyes beküldésre. Enélkül a felület
    // korlátlanul tudott megerősítő levelet generálni ugyanarra a címre (a
    // tulajdonos jelzése). A Mailchimp-hívást itt MEG SEM indítjuk, ezért nem
    // megy ki levél; a válasz viszont sikeres, hogy a régi app se lásson hibát.
    // A várakozás szűrővel állítható: `huhs_newsletter_resend_cooldown`.
    $cooldown = (int) apply_filters('huhs_newsletter_resend_cooldown', 15 * MINUTE_IN_SECONDS);
    $cooldown_key = 'huhs_newsletter_requested_' . $subscriber_hash;
    $last_requested = (int) get_transient($cooldown_key);
    if ($cooldown > 0 && $last_requested > 0) {
        $retry_after = max(60, ($last_requested + $cooldown) - time());
        return new WP_REST_Response(array(
            'subscribed' => true,
            'already_requested' => true,
            'double_opt_in' => false,
            'state' => 'confirmation_pending',
            'retry_after' => $retry_after,
        ), 200);
    }

    if ($existing_status === '') {
        $response = wp_remote_post($base_url, array(
            'timeout' => 15,
            'headers' => $auth_headers,
            'body' => wp_json_encode(array(
                'email_address' => $email,
                'status' => 'pending',
            )),
        ));
    } else {
        // Re-request confirmation for a pending/unsubscribed contact.
        $response = wp_remote_request($base_url . '/' . $subscriber_hash, array(
            'method' => 'PUT',
            'timeout' => 15,
            'headers' => $auth_headers,
            'body' => wp_json_encode(array(
                'email_address' => $email,
                'status' => 'pending',
            )),
        ));
    }

    if (is_wp_error($response)) {
        return new WP_Error('newsletter_unavailable', 'A hírlevél-szolgáltatás nem érhető el.', array('status' => 502));
    }

    $status = wp_remote_retrieve_response_code($response);
    if ($status < 200 || $status >= 300) {
        $mailchimp_error = json_decode(wp_remote_retrieve_body($response), true);
        error_log('HUHS Mailchimp subscribe failed: HTTP ' . $status . ' / ' . wp_json_encode(array(
            'title' => $mailchimp_error['title'] ?? '',
            'detail' => $mailchimp_error['detail'] ?? '',
            'email_hash' => $subscriber_hash,
        )));
        return new WP_Error('newsletter_failed', 'A feliratkozás nem sikerült.', array('status' => 502));
    }

    // Csak a SIKERES kérés után indul a várakozás, hogy egy hibás kísérlet ne
    // zárja ki a címest a valódi újrapróbálkozásból.
    if ($cooldown > 0) {
        set_transient($cooldown_key, time(), $cooldown);
    }

    return new WP_REST_Response(array('subscribed' => true, 'already_requested' => false, 'double_opt_in' => true, 'state' => 'confirmation_sent'), 200);
}

add_action('admin_menu', function () {
    add_submenu_page('huhs-mobile', 'Hírlevél', 'Hírlevél', 'manage_options', 'huhs-newsletter', 'huhs_newsletter_admin_page');
});

add_action('admin_post_huhs_save_newsletter_settings', function () {
    if (!current_user_can('manage_options')) wp_die('Nincs jogosultság.');
    check_admin_referer('huhs_save_newsletter_settings');
    update_option(HUHS_MAILCHIMP_OPTION, array(
        'api_key' => sanitize_text_field(wp_unslash($_POST['api_key'] ?? '')),
        'audience_id' => sanitize_text_field(wp_unslash($_POST['audience_id'] ?? '')),
        'data_center' => sanitize_key(wp_unslash($_POST['data_center'] ?? '')),
    ), false);
    wp_safe_redirect(admin_url('admin.php?page=huhs-newsletter&saved=1'));
    exit;
});

function huhs_newsletter_admin_page()
{
    if (!current_user_can('manage_options')) return;
    $settings = get_option(HUHS_MAILCHIMP_OPTION, array());
    ?>
    <div class="wrap">
        <h1>HUHS hírlevél</h1>
        <p>A Mailchimp-kulcs csak a WordPress szerveren tárolódik, az app nem kapja meg.</p>
        <form method="post" action="<?php echo esc_url(admin_url('admin-post.php')); ?>">
            <input type="hidden" name="action" value="huhs_save_newsletter_settings">
            <?php wp_nonce_field('huhs_save_newsletter_settings'); ?>
            <table class="form-table"><tbody>
                <tr><th><label for="mailchimp_api_key">Mailchimp API-kulcs</label></th><td><input class="regular-text" type="password" id="mailchimp_api_key" name="api_key" value="<?php echo esc_attr($settings['api_key'] ?? ''); ?>" autocomplete="new-password"></td></tr>
                <tr><th><label for="mailchimp_audience_id">Audience ID</label></th><td><input class="regular-text" id="mailchimp_audience_id" name="audience_id" value="<?php echo esc_attr($settings['audience_id'] ?? ''); ?>"></td></tr>
                <tr><th><label for="mailchimp_data_center">Data center</label></th><td><input class="small-text" id="mailchimp_data_center" name="data_center" value="<?php echo esc_attr($settings['data_center'] ?? ''); ?>" placeholder="us21"><p class="description">Ha üres, az API-kulcs végződéséből próbáljuk felismerni.</p></td></tr>
            </tbody></table>
            <?php submit_button('Mentés'); ?>
        </form>
    </div>
    <?php
}
