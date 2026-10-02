<?php

if (!defined('ABSPATH')) {
    exit;
}

/**
 * Boot timing probe.
 *
 * A REST request costs about 1.2 seconds on this host while the endpoint's own
 * work is only ~70 ms, so the time is spent in the WordPress/plugin bootstrap. We
 * need to know which phase costs it before optimising further.
 *
 * This file answers only to a request that carries the diagnostic query argument,
 * and then only adds response headers. The payload, the caches and every other
 * request are untouched, so it is safe to keep in the plugin.
 *
 * Usage: /wp-json/huhs/v1/posts?page=1&per_page=10&summary=true&huhs_diag=<marker>
 * Answer: X-HUHS-Boot: plugin_file=… plugins_loaded=… init=… rest_api_init=… response=… queries=… peak_mb=…
 */
if (!defined('HUHS_DIAGNOSTIC_MARKER')) {
    define('HUHS_DIAGNOSTIC_MARKER', 'huhs-boot-probe-2026');
}

function &huhs_diag_state() {
    static $state = null;
    if (null === $state) {
        $marker = isset($_GET['huhs_diag']) && is_string($_GET['huhs_diag']) ? $_GET['huhs_diag'] : '';
        $state = array(
            'enabled' => '' !== $marker && hash_equals(HUHS_DIAGNOSTIC_MARKER, $marker),
            // This file is loaded during the plugin loading phase, which already
            // tells us how far into that phase our own plugin sits.
            'plugin_file_at' => microtime(true),
            'marks' => array(),
        );
    }
    return $state;
}

function huhs_diag_mark($label) {
    $state = &huhs_diag_state();
    if (!$state['enabled'] || isset($state['marks'][$label])) {
        return;
    }
    $state['marks'][$label] = microtime(true);
}

$huhs_diag_ref = &huhs_diag_state();
if ($huhs_diag_ref['enabled']) {
    add_action('plugins_loaded', function () { huhs_diag_mark('plugins_loaded'); }, 0);
    add_action('init', function () { huhs_diag_mark('init'); }, 0);
    add_action('rest_api_init', function () { huhs_diag_mark('rest_api_init'); }, 0);
}

/**
 * Environment probe.
 *
 * The boot probe proved that most of a request is spent before any endpoint
 * code runs, but not what causes it. These facts separate the usual causes: an
 * opcode cache that is off, no persistent object cache, a bloated autoload
 * table, an oversized plugin list, or a cron table that has grown unchecked.
 *
 * Usage: /wp-json/huhs/v1/posts?per_page=1&huhs_diag=<marker>&probe=<random>
 * The probe value has to differ from the previous request, otherwise the
 * stored response is served and no header is produced.
 *
 * Answer: X-HUHS-Health: opcache=… object_cache=… plugins=… autoload=… …
 */
function huhs_diag_health_header()
{
    global $wpdb;
    $parts = array();

    // A plugin verzioja: ebbol lehet ellenorizni, hogy a feltoltott csomag
    // valoban kicserelodott-e. Kizarolag a titkos diag markerrel latszik.
    $parts[] = 'api=' . HUHS_API_VERSION;

    $opcache = 'missing';
    if (function_exists('opcache_get_status')) {
        $status = @opcache_get_status(false);
        if (is_array($status)) {
            $opcache = empty($status['opcache_enabled']) ? 'off' : 'on';
        } else {
            // opcache.restrict_api is set, so the status cannot be read.
            $opcache = 'restricted';
        }
    }
    $parts[] = 'opcache=' . $opcache;

    $parts[] = 'object_cache=' . ((function_exists('wp_using_ext_object_cache') && wp_using_ext_object_cache()) ? 'yes' : 'no');

    $names = array();
    foreach ((array) get_option('active_plugins', array()) as $plugin_file) {
        $dir = strtok((string) $plugin_file, '/');
        if (is_string($dir) && $dir !== '') $names[] = $dir;
    }
    $names = array_values(array_unique($names));
    $parts[] = 'plugins=' . count($names) . ':' . implode(',', $names);

    if (is_object($wpdb) && !empty($wpdb->options)) {
        // WordPress 6.6 replaced yes/no with auto-on/auto-off, so both spellings
        // have to count as autoloaded.
        $not_autoloaded = "autoload NOT IN ('no', 'off', 'auto-off')";
        $autoload = $wpdb->get_row(
            "SELECT COUNT(*) AS items, COALESCE(SUM(LENGTH(option_value)), 0) AS bytes FROM {$wpdb->options} WHERE {$not_autoloaded}",
            ARRAY_A
        );
        $parts[] = 'autoload=' . (int) ($autoload['items'] ?? 0) . 'opts/'
            . (int) round(((int) ($autoload['bytes'] ?? 0)) / 1024) . 'KB';

        $top = $wpdb->get_results(
            "SELECT option_name, LENGTH(option_value) AS bytes FROM {$wpdb->options} WHERE {$not_autoloaded} ORDER BY bytes DESC LIMIT 5",
            ARRAY_A
        );
        $top_parts = array();
        foreach ((array) $top as $row) {
            $top_parts[] = (string) ($row['option_name'] ?? '?') . ':' . (int) round(((int) ($row['bytes'] ?? 0)) / 1024) . 'KB';
        }
        $parts[] = 'top_autoload=' . implode(',', $top_parts);
    }

    $cron_count = 0;
    if (function_exists('_get_cron_array')) {
        foreach ((array) _get_cron_array() as $hooks) {
            foreach ((array) $hooks as $schedules) {
                $cron_count += count((array) $schedules);
            }
        }
    }
    $parts[] = 'cron=' . $cron_count;
    $parts[] = 'cron_disabled=' . ((defined('DISABLE_WP_CRON') && DISABLE_WP_CRON) ? 'yes' : 'no');

    // Kept as a literal because this file is loaded before push.php.
    $tokens = get_option('huhs_push_tokens', array());
    $parts[] = 'push_tokens=' . (is_array($tokens) ? count($tokens) : 0);

    // Az utolso kuldes eredmenye. Enelkul a "nem jott meg a push" nem
    // megkulonboztetheto a "meg kuldi"-tol; innen latszik a valasz.
    if (function_exists('huhs_push_diag_summary')) {
        $parts[] = huhs_push_diag_summary();
    }
    if (function_exists('huhs_push_diag_jobs')) {
        $parts[] = huhs_push_diag_jobs();
    }
    // A hír-push őre (2.14.12): látszik, hogy a kör lefutott-e, és hány cikkre
    // indított értesítést — a „nem ment ki semmi" így megkülönböztethető attól,
    // hogy „az ör le sem futott".
    if (function_exists('huhs_push_diag_news_scan')) {
        $parts[] = huhs_push_diag_news_scan();
    }
    // A küldés keretei (2.14.13): párhuzamosság, kör-keret és a PHP időkorlátja —
    // a kifutás sebességét ez a három szám együtt adja (mérés, nem tipp).
    if (function_exists('huhs_push_diag_limits')) {
        $parts[] = huhs_push_diag_limits();
    }

    $parts[] = 'memory_limit=' . ini_get('memory_limit');
    $parts[] = 'php=' . PHP_VERSION;

    // A push parhuzamos kuldese curl_multi-ra epul; ha nincs, a plugin
    // automatikusan a soros utra esik vissza. Ezt kulon kell tudni.
    $parts[] = 'curl=' . (function_exists('curl_init') ? 'yes' : 'no');
    $parts[] = 'curl_multi=' . (function_exists('curl_multi_init') ? 'yes' : 'no');

    // A header value cannot contain newlines, and an over-long one would be
    // dropped by the server, so keep it to printable ASCII and a sane length.
    $value = preg_replace('/[^\x20-\x7E]/', '', implode(' ', $parts));
    if (!is_string($value)) return '';
    return substr($value, 0, 1600);
}

function huhs_diag_emit($served, $result, $request, $server) {
    $state = &huhs_diag_state();
    if (!$state['enabled']) {
        return $served;
    }

    // $timestart is set by wp-settings.php before any plugin loads, so it marks
    // the very beginning of WordPress (not just the plugin phase).
    $wp_start = isset($GLOBALS['timestart']) ? (float) $GLOBALS['timestart'] : 0.0;
    $request_start = isset($_SERVER['REQUEST_TIME_FLOAT'])
        ? (float) $_SERVER['REQUEST_TIME_FLOAT']
        : $state['plugin_file_at'];
    $now = microtime(true);

    $since_request = static function ($value) use ($request_start) {
        return null === $value ? '-' : (string) max(0, (int) round(($value - $request_start) * 1000));
    };
    $since_wp = static function ($value) use ($wp_start) {
        return 0.0 >= $wp_start || null === $value ? '-' : (string) max(0, (int) round(($value - $wp_start) * 1000));
    };

    $marks = $state['marks'];

    // How long our own forty include files cost, measured from the first of them
    // to the end of the main plugin file. Reported as '-' when the mark is
    // missing, which is the case for a request that was served by the early
    // cache before the rest of the plugin finished loading.
    $our_files = '-';
    if (isset($marks['plugin_files_done'])) {
        $our_files = (string) max(0, (int) round(($marks['plugin_files_done'] - $state['plugin_file_at']) * 1000));
    }

    $header = 'request_to_plugins_loaded=' . $since_request($marks['plugins_loaded'] ?? null)
        . ' request_to_init=' . $since_request($marks['init'] ?? null)
        . ' request_to_rest_api_init=' . $since_request($marks['rest_api_init'] ?? null)
        . ' request_to_response=' . $since_request($now)
        . ' wp_to_plugins_loaded=' . $since_wp($marks['plugins_loaded'] ?? null)
        . ' wp_to_response=' . $since_wp($now)
        . ' plugin_file_at=' . $since_request($state['plugin_file_at'])
        . ' our_files_at=' . $since_request($marks['plugin_files_done'] ?? null)
        . ' our_files_ms=' . $our_files
        . ' queries=' . (function_exists('get_num_queries') ? (int) get_num_queries() : 0)
        . ' peak_mb=' . round(memory_get_peak_usage(true) / 1048576, 1);

    header('X-HUHS-Boot: ' . $header, true);

    $health = huhs_diag_health_header();
    if ($health !== '') {
        header('X-HUHS-Health: ' . $health, true);
    }

    return $served;
}
add_filter('rest_pre_serve_request', 'huhs_diag_emit', 100000, 4);
