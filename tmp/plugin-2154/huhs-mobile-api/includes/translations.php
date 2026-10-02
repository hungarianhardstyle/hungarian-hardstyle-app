<?php

if (!defined('ABSPATH')) {
    exit;
}

function huhs_translation_table()
{
    global $wpdb;
    return $wpdb->prefix . 'huhs_translations';
}

function huhs_translation_install()
{
    global $wpdb;
    require_once ABSPATH . 'wp-admin/includes/upgrade.php';
    $table = huhs_translation_table();
    $charset = $wpdb->get_charset_collate();
    dbDelta("CREATE TABLE {$table} (
        id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
        source_hash char(64) NOT NULL,
        source_type varchar(40) NOT NULL,
        locale varchar(10) NOT NULL,
        source_text longtext NOT NULL,
        translated_text longtext NOT NULL,
        model varchar(80) NOT NULL,
        created_at datetime NOT NULL,
        updated_at datetime NOT NULL,
        PRIMARY KEY  (id),
        UNIQUE KEY source_locale (source_hash,locale),
        KEY source_type (source_type)
    ) {$charset};");
}

add_action('rest_api_init', function () {
    register_rest_route('huhs/v1', '/translations', array(
        'methods' => 'POST',
        'callback' => 'huhs_translate_text',
        'permission_callback' => '__return_true',
    ));
});

add_action('plugins_loaded', function () {
    if (get_option('huhs_translation_schema_version') !== '1') {
        huhs_translation_install();
        update_option('huhs_translation_schema_version', '1', false);
    }
});

function huhs_translation_api_key()
{
    if (defined('HUHS_OPENAI_API_KEY')) {
        return trim((string) HUHS_OPENAI_API_KEY);
    }
    return trim((string) get_option('huhs_openai_api_key', ''));
}

function huhs_translate_text(WP_REST_Request $request)
{
    $locale = sanitize_key((string) $request->get_param('locale'));
    $source_type = sanitize_key((string) $request->get_param('source_type'));
    $source = (string) $request->get_param('source');
    $source_hash = strtolower(sanitize_text_field((string) $request->get_param('source_hash')));
    $format = sanitize_key((string) $request->get_param('format'));

    if ($locale !== 'en' || !in_array($source_type, array('ui', 'post', 'event', 'artist', 'organizer', 'faq'), true)) {
        return new WP_Error('translation_invalid_request', 'Érvénytelen fordítási kérés.', array('status' => 400));
    }
    if ($source === '' || strlen($source) > 120000) {
        return new WP_Error('translation_invalid_source', 'Érvénytelen fordítási forrás.', array('status' => 400));
    }
    $computed_hash = hash('sha256', $source);
    if ($source_hash === '') {
        $source_hash = $computed_hash;
    }
    if (!preg_match('/^[a-f0-9]{64}$/', $source_hash)) {
        return new WP_Error('translation_invalid_source', 'Invalid translation source.', array('status' => 400));
    }
    if (!hash_equals($computed_hash, $source_hash)) {
        return new WP_Error('translation_hash_mismatch', 'A fordítási forrás hash-e hibás.', array('status' => 400));
    }

    global $wpdb;
    $table = huhs_translation_table();
    $cached = $wpdb->get_row($wpdb->prepare(
        "SELECT translated_text, model FROM {$table} WHERE source_hash = %s AND locale = %s LIMIT 1",
        $source_hash,
        $locale
    ), ARRAY_A);
    if ($cached) {
        $cached_data = null;
        if ($format === 'json') {
            $cached_data = json_decode($cached['translated_text'], true);
        }
        return rest_ensure_response(array(
            'locale' => $locale,
            'source_hash' => $source_hash,
            'text' => $cached['translated_text'],
            'data' => $cached_data,
            'cached' => true,
            'model' => $cached['model'],
        ));
    }

    $rate_key = 'huhs_translation_' . md5((string) ($_SERVER['REMOTE_ADDR'] ?? 'unknown'));
    $rate_count = (int) get_transient($rate_key);
    if ($rate_count >= 5) {
        return new WP_Error('translation_rate_limited', 'Too many translation requests.', array('status' => 429));
    }
    set_transient($rate_key, $rate_count + 1, MINUTE_IN_SECONDS);

    $api_key = huhs_translation_api_key();
    if ($api_key === '') {
        return new WP_Error('translation_unconfigured', 'Az angol fordítás jelenleg nincs konfigurálva.', array('status' => 503));
    }

    $model = defined('HUHS_OPENAI_TRANSLATION_MODEL')
        ? (string) HUHS_OPENAI_TRANSLATION_MODEL
        : 'gpt-5-mini';
    $prompt = $format === 'json'
        ? "Translate the following Hungarian {$source_type} JSON for the Hungarian Hardstyle mobile app into natural, polished native English. Humanize wording instead of translating word-for-word. Keep the exact JSON structure and keys. Translate values only. Preserve factual meaning, names, dates, URLs, HTML tags, embeds and shortcodes exactly. Do not add facts or marketing claims. Return only valid JSON.\n\nSOURCE JSON:\n" . $source
        : "Rewrite the following Hungarian {$source_type} content as natural, polished native English for the Hungarian Hardstyle mobile app. Humanize it instead of translating word-for-word. Preserve factual meaning, names, dates, URLs, HTML tags, embeds and shortcodes exactly. Do not add facts, claims or marketing promises. Return only the translated content.\n\nSOURCE:\n" . $source;
    $response = wp_remote_post('https://api.openai.com/v1/responses', array(
        'timeout' => 45,
        'headers' => array(
            'Authorization' => 'Bearer ' . $api_key,
            'Content-Type' => 'application/json',
        ),
        'body' => wp_json_encode(array(
            'model' => $model,
            'store' => false,
            'input' => $prompt,
        )),
    ));
    if (is_wp_error($response)) {
        return new WP_Error('translation_provider_error', 'A fordító szolgáltatás nem érhető el.', array('status' => 502));
    }
    $status = wp_remote_retrieve_response_code($response);
    $body = json_decode(wp_remote_retrieve_body($response), true);
    if ($status < 200 || $status >= 300) {
        return new WP_Error('translation_provider_error', 'A fordító szolgáltatás hibát adott.', array('status' => 502));
    }
    $translated = trim((string) ($body['output_text'] ?? ''));
    if ($translated === '' && !empty($body['output']) && is_array($body['output'])) {
        foreach ($body['output'] as $item) {
            foreach (($item['content'] ?? array()) as $content) {
                if (($content['type'] ?? '') === 'output_text' && !empty($content['text'])) {
                    $translated .= (string) $content['text'];
                }
            }
        }
        $translated = trim($translated);
    }
    if ($translated === '') {
        return new WP_Error('translation_empty', 'A fordító üres választ adott.', array('status' => 502));
    }

    $translation_data = null;
    if ($format === 'json') {
        $json_text = trim($translated);
        $json_text = preg_replace('/^```(?:json)?\s*|\s*```$/i', '', $json_text);
        $decoded = json_decode($json_text, true);
        if (!is_array($decoded)) {
            return new WP_Error('translation_invalid_json', 'A fordĂ­tĂł Ă©rvĂ©nytelen JSON vĂˇlaszt adott.', array('status' => 502));
        }
        $translation_data = $decoded;
        $translated = wp_json_encode($decoded, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    }

    $now = current_time('mysql', true);
    $wpdb->replace($table, array(
        'source_hash' => $source_hash,
        'source_type' => $source_type,
        'locale' => $locale,
        'source_text' => $source,
        'translated_text' => $translated,
        'model' => $model,
        'created_at' => $now,
        'updated_at' => $now,
    ), array('%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s'));

    return rest_ensure_response(array(
        'locale' => $locale,
        'source_hash' => $source_hash,
        'text' => $translated,
        'data' => $translation_data,
        'cached' => false,
        'model' => $model,
    ));
}
