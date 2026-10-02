<?php

if (!defined('ABSPATH')) {
    exit;
}

/**
 * Add conditional caching only to public, read-only HUHS API responses.
 * Admin, authenticated actions and download/token routes are deliberately
 * excluded so their existing behaviour and security headers remain unchanged.
 */
function huhs_add_public_cache_headers($response, $server, $request) {
    if (!$response instanceof WP_REST_Response || 'GET' !== $request->get_method()) {
        return $response;
    }

    $route = $request->get_route();
    // Egyetlen engedelylista-igazsag: a huhs_public_cache_route(). Korabban itt
    // egy masodik, kezzel masolt regex volt, es amikor a /poll/active bekerult a
    // cache-be, abbol kimaradt. Ezert a kerdoiv friss valasza fejlec nelkul ment
    // ki (se ETag, se 45 masodperc), es a hosting alatette a maga 300 masodperces
    // Cache-Controljat — igy egy epp megnyilo kerdoív akar ot percig keshetett.
    if (!huhs_public_cache_route($route)) {
        return $response;
    }

    $data = $response->get_data();
    $json = wp_json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    if (false === $json) {
        return $response;
    }

    $etag = '"' . md5($json) . '"';
    $last_modified = huhs_find_latest_modified_timestamp($data);
    huhs_apply_public_cache_headers($response, $etag, $last_modified);

    $if_none_match = trim((string) $request->get_header('if-none-match'));
    // Proxies may mark an otherwise identical validator as weak (W/). For
    // cache validation the entity-tag comparison is intentionally weak.
    $normalize_etag = static function ($value) {
        return preg_replace('/^W\//i', '', trim((string) $value));
    };
    $requested_etags = array_map('trim', explode(',', $if_none_match));
    $etag_matches = in_array('*', $requested_etags, true);
    if (!$etag_matches) {
        foreach ($requested_etags as $requested_etag) {
            if ($requested_etag !== '' && $normalize_etag($requested_etag) === $normalize_etag($etag)) {
                $etag_matches = true;
                break;
            }
        }
    }
    if ($if_none_match && $etag_matches) {
        $response->set_status(304);
        $response->set_data(null);
    }

    return $response;
}
// Run after other REST response filters so a matched validator cannot be
// changed back to 200 by a later response decorator.
add_filter('rest_post_dispatch', 'huhs_add_public_cache_headers', 9999, 3);

/**
 * Preserve a matched conditional response through the final REST serializer.
 * Some WordPress/OpenResty stacks normalize a 304 response during serving.
 */
function huhs_preserve_public_not_modified($served, $result, $request, $server) {
    if ($served || !$result instanceof WP_REST_Response || 'GET' !== $request->get_method()) {
        return $served;
    }

    $route = $request->get_route();
    if (!huhs_public_cache_route($route)) {
        return $served;
    }

    $if_none_match = trim((string) $request->get_header('if-none-match'));
    $etag = '';
    foreach ($result->get_headers() as $header_name => $header_value) {
        if (0 === strcasecmp((string) $header_name, 'ETag')) {
            $etag = (string) $header_value;
            break;
        }
    }
    $normalize_etag = static function ($value) {
        return preg_replace('/^W\//i', '', trim((string) $value));
    };
    $matches = false;
    foreach (explode(',', $if_none_match) as $requested_etag) {
        if ('*' === trim($requested_etag) || ($requested_etag !== '' && $normalize_etag($requested_etag) === $normalize_etag($etag))) {
            $matches = true;
            break;
        }
    }
    if (!$matches || '' === $etag) {
        return $served;
    }

    status_header(304);
    header('ETag: ' . $etag, true);
    header_remove('Content-Type');
    header_remove('Content-Length');
    header_remove('Content-Encoding');
    return true;
}
add_filter('rest_pre_serve_request', 'huhs_preserve_public_not_modified', 99999, 4);

function huhs_find_latest_modified_timestamp($value) {
    $latest = 0;
    if (is_array($value)) {
        foreach ($value as $key => $item) {
            if (is_string($item) && preg_match('/^(date_modified|modified|updated_at)$/', (string) $key)) {
                $timestamp = strtotime($item);
                if ($timestamp) {
                    $latest = max($latest, $timestamp);
                }
            } else {
                $latest = max($latest, huhs_find_latest_modified_timestamp($item));
            }
        }
    }
    return $latest;
}

/**
 * Server-side response cache for the public, read-only HUHS API routes.
 *
 * The conditional headers above only help clients and proxies: by the time they
 * are attached WordPress has already built the whole response, so every request
 * still runs the full queries and serialization (about a second each). This
 * section stores the built payload in a transient, so a repeat request --
 * including the app's ETag/HEAD revalidation -- is answered without running the
 * endpoint again.
 *
 * Safety:
 *  - only GET requests on the public allow-list of read-only routes; those all
 *    use permission_callback => '__return_true' and read no user context, so a
 *    cached payload can never leak between visitors,
 *  - the cached payload carries its own ETag, so an unchanged response is a 304
 *    without re-rendering,
 *  - content changes invalidate the cache immediately (save_post, post
 *    delete/trash/restore, term changes and huhs_* option updates). Post meta
 *    writes are deliberately not watched: the view counter writes meta on every
 *    article view, which would invalidate the cache constantly,
 *  - HUHS_PUBLIC_CACHE_TTL bounds anything that fires none of those hooks.
 */
if (!defined('HUHS_PUBLIC_CACHE_TTL')) {
    define('HUHS_PUBLIC_CACHE_TTL', 120);
}

if (!defined('HUHS_PUBLIC_CACHE_VERSION_OPTION')) {
    define('HUHS_PUBLIC_CACHE_VERSION_OPTION', 'huhs_public_cache_version');
}

if (!defined('HUHS_PUBLIC_CACHE_CONTROL')) {
    define('HUHS_PUBLIC_CACHE_CONTROL', 'public, max-age=45, s-maxage=45, stale-while-revalidate=60');
}

/** Hop-by-hop and cookie headers must never be replayed from the cache. */
function huhs_cacheable_response_headers($headers) {
    $skip = array('set-cookie', 'content-length', 'transfer-encoding', 'connection', 'keep-alive', 'date', 'server', 'content-encoding');
    $result = array();
    if (!is_array($headers)) {
        return $result;
    }
    foreach ($headers as $name => $value) {
        if (in_array(strtolower((string) $name), $skip, true)) {
            continue;
        }
        if (is_array($value)) {
            $value = implode(', ', array_map('strval', $value));
        }
        if (is_string($value) && '' !== $value) {
            $result[(string) $name] = $value;
        }
    }
    return $result;
}

function huhs_public_cache_route($route) {
    if (!is_string($route)) {
        return false;
    }
    // ⚠️ PRIVÁT AL-ÚTVONALAK KIZÁRÁSA (éles hiba javítása, 2.7.0).
    //
    // Az engedélylista **előtagra** illeszkedik, ezért a `/huhs/v1/artists/<id>/claim-emails`
    // végpont is beleesett — pedig az `manage_options`-szal védett, és a DJ
    // **privát** e-mail címét adja vissza. Mivel a gyorsítótár a
    // `rest_pre_dispatch`-ben (illetve a plugin betöltésekor, a hitelesítés
    // ELŐTT) kiszolgál, egy korábbi, hitelesített hívás válasza 120 másodpercig
    // **azonosítatlan** kérésre is kijöhetett volna. A fájl saját feltétele
    // szerint ide csak olyan útvonal kerülhet, amely `permission_callback =>
    // '__return_true'` és nem olvas felhasználó-specifikus adatot.
    //
    // Ezért ami „privát" a nevében/útjában, az soha nem cache-elhető. Az új
    // írás-végpontok szándékosan POST-ot és külön útvonalat használnak
    // (`/dj-profile/<id>`), így eleve kimaradnak.
    foreach (array('/claim-emails', '/dj-profile') as $private_fragment) {
        if (false !== strpos($route, $private_fragment)) {
            return false;
        }
    }
    // /poll/active and /prize/active are time-gated: the window state is
    // computed when the response is built, so the stored copy can keep a
    // just-opened poll/prize hidden, or a just-closed one visible, for at most
    // one cache lifetime (120 s). This is the SINGLE allow-list; every header
    // and 304 path calls this function (see the note at the top of the file).
    return (bool) preg_match('#^/huhs/v1/(posts|events|releases|artists|organizers|faq|translations|achievements/badges|poll/active|prize/active)(/|$)#', $route);
}

function huhs_public_cache_version() {
    $version = get_option(HUHS_PUBLIC_CACHE_VERSION_OPTION);
    if (!is_numeric($version)) {
        $version = 1;
        update_option(HUHS_PUBLIC_CACHE_VERSION_OPTION, $version, false);
    }
    return (int) $version;
}

function huhs_invalidate_public_cache() {
    update_option(HUHS_PUBLIC_CACHE_VERSION_OPTION, huhs_public_cache_version() + 1, false);
}

function huhs_invalidate_public_cache_on_option($option) {
    if (!is_string($option) || 0 !== strpos($option, 'huhs_')) {
        return;
    }
    // Never react to the counter itself, otherwise the bump would recurse.
    if (HUHS_PUBLIC_CACHE_VERSION_OPTION === $option) {
        return;
    }
    // A push konyvelesi opcioi nem valtoztatnak nyilvanos tartalmat, ezert nem
    // szabad miattuk a nyilvanos cache-t uriteni. Ez nem elmeleti: a
    // huhs_push_tokens minden app-telepesnel ir (updated_at), tehat eddig minden
    // uj regisztracio kiuritette a teljes nyilvanos cache-t; egy kuldési lanc
    // pedig koronkent irja a job opciot.
    if ('huhs_push_tokens' === $option || 'huhs_push_last_result' === $option) {
        return;
    }
    if (0 === strpos($option, 'huhs_push_job_')) {
        return;
    }
    // Ugyanez a biztonsagi háló könyvelésere es az aktiv feladatra.
    if ('huhs_push_active_job' === $option || 'huhs_push_resume_lock' === $option) {
        return;
    }
    if ('huhs_push_orphan_scan' === $option) {
        return;
    }
    huhs_invalidate_public_cache();
}

add_action('save_post', 'huhs_invalidate_public_cache');
add_action('deleted_post', 'huhs_invalidate_public_cache');
add_action('trashed_post', 'huhs_invalidate_public_cache');
add_action('untrashed_post', 'huhs_invalidate_public_cache');
add_action('edited_terms', 'huhs_invalidate_public_cache');
add_action('created_term', 'huhs_invalidate_public_cache');
add_action('delete_term', 'huhs_invalidate_public_cache');
add_action('updated_option', 'huhs_invalidate_public_cache_on_option', 10, 1);

function huhs_public_cache_key($route, $params) {
    if (is_array($params)) {
        // The revalidation marker and the cache buster are client-side noise and
        // must not fragment the cache.
        unset($params['_huhs_revalidate'], $params['_']);
        ksort($params);
    }
    return 'huhs_pc_' . md5(huhs_public_cache_version() . '|' . $route . '|' . wp_json_encode($params));
}

function huhs_public_cache_etag_matches_value($if_none_match, $etag) {
    $if_none_match = trim((string) $if_none_match);
    if ('' === $if_none_match) {
        return false;
    }
    $target = preg_replace('/^W\//i', '', trim((string) $etag));
    foreach (explode(',', $if_none_match) as $candidate) {
        $candidate = trim($candidate);
        if ('*' === $candidate) {
            return true;
        }
        if ('' !== $candidate && preg_replace('/^W\//i', '', $candidate) === $target) {
            return true;
        }
    }
    return false;
}

function huhs_public_cache_etag_matches($request, $etag) {
    return huhs_public_cache_etag_matches_value($request->get_header('if-none-match'), $etag);
}

/**
 * Headers every cached public response carries.
 *
 * `s-maxage` states the shared-cache (CDN/proxy) lifetime explicitly, and `Vary`
 * is normalised because a duplicated Accept-Encoding combined with the CORS
 * Origin fragment or block edge caching.
 */
function huhs_apply_public_cache_headers($response, $etag, $modified, $source = 'fresh') {
    $response->header('ETag', $etag);
    $response->header('Cache-Control', HUHS_PUBLIC_CACHE_CONTROL);
    $response->header('Vary', 'Accept-Encoding, Origin');
    // Tells us (and any future debugging) which layer produced the response:
    // early = served before the remaining plugins loaded, memory = REST layer
    // cache, fresh = rendered by the endpoint now.
    $response->header('X-HUHS-Cache', $source);
    if ($modified > 0) {
        $response->header('Last-Modified', gmdate('D, d M Y H:i:s', $modified) . ' GMT');
    }
    return $response;
}

/**
 * Keeps the tracking cookie out of the public JSON responses.
 *
 * The Facebook pixel sends a fresh `_fbp` cookie with every request, and any
 * `Set-Cookie` header makes Cloudflare (and other CDNs) refuse to cache the
 * response no matter what Cache-Control says. These routes return read-only JSON
 * for the mobile app, so the cookie has no consumer here; HTML pages keep it.
 */
function huhs_strip_public_response_cookies($served, $result, $request, $server) {
    if (!($request instanceof WP_REST_Request) || 'GET' !== $request->get_method()) {
        return $served;
    }
    if (!huhs_public_cache_route($request->get_route())) {
        return $served;
    }
    header_remove('Set-Cookie');
    return $served;
}
add_filter('rest_pre_serve_request', 'huhs_strip_public_response_cookies', 10, 4);

function huhs_serve_public_cache($result, $server, $request) {
    if (null !== $result || !($request instanceof WP_REST_Request)) {
        return $result;
    }
    if ('GET' !== $request->get_method()) {
        return $result;
    }
    $route = $request->get_route();
    if (!huhs_public_cache_route($route)) {
        return $result;
    }

    $cached = get_transient(huhs_public_cache_key($route, $request->get_query_params()));
    if (!is_array($cached) || !isset($cached['body'], $cached['etag'])) {
        return $result;
    }
    $modified = isset($cached['modified']) ? (int) $cached['modified'] : 0;

    if (huhs_public_cache_etag_matches($request, $cached['etag'])) {
        return huhs_apply_public_cache_headers(new WP_REST_Response(null, 304), $cached['etag'], $modified, 'memory');
    }
    return huhs_apply_public_cache_headers(new WP_REST_Response($cached['body'], 200), $cached['etag'], $modified, 'memory');
}
add_filter('rest_pre_dispatch', 'huhs_serve_public_cache', 10, 3);

function huhs_store_public_cache($response, $server, $request) {
    if (!($response instanceof WP_REST_Response) || !($request instanceof WP_REST_Request)) {
        return $response;
    }
    if ('GET' !== $request->get_method() || 200 !== (int) $response->get_status()) {
        return $response;
    }
    $route = $request->get_route();
    if (!huhs_public_cache_route($route)) {
        return $response;
    }

    $data = $response->get_data();
    $json = wp_json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    if (false === $json) {
        return $response;
    }

    set_transient(
        huhs_public_cache_key($route, $request->get_query_params()),
        array(
            'body' => $data,
            'json' => $json,
            'etag' => '"' . md5($json) . '"',
            'modified' => huhs_find_latest_modified_timestamp($data),
            'headers' => huhs_cacheable_response_headers($response->get_headers()),
        ),
        HUHS_PUBLIC_CACHE_TTL
    );
    return $response;
}
add_filter('rest_post_dispatch', 'huhs_store_public_cache', 9998, 3);

/**
 * Serves a cached public response while *this plugin's file is being loaded*.
 *
 * Measured on the live site: a REST request costs ~0.9-1.4 s, of which ~0.5-0.8 s
 * is loading the plugin files and ~0.3-0.4 s is the init/REST phase, while the
 * endpoint's own work is only ~0.07-0.18 s. Running here means the cached payload
 * is delivered before the remaining plugins load and before any init/REST
 * callback, so a cached API read costs roughly the plugin-file phase only.
 *
 * Safety:
 *  - only GET on the exact /wp-json/huhs/v1/<public route> paths, everything else
 *    returns immediately (a single strpos for the whole rest of the site),
 *  - only an already built payload is echoed, so the response is identical to the
 *    REST one; a miss falls through to WordPress unchanged,
 *  - the cached ETag drives the 304 answer, exactly like the REST path,
 *  - never emits cookies, and reuses the stored response headers.
 */
function huhs_try_serve_public_cache_early() {
    $method = isset($_SERVER['REQUEST_METHOD']) ? strtoupper((string) $_SERVER['REQUEST_METHOD']) : '';
    // HEAD matters: the app revalidates every cached surface with a conditional
    // HEAD request, so answering those here removes the biggest repeat cost.
    if ('GET' !== $method && 'HEAD' !== $method) {
        return;
    }
    $uri = isset($_SERVER['REQUEST_URI']) ? (string) $_SERVER['REQUEST_URI'] : '';
    $position = strpos($uri, '/wp-json/huhs/v1/');
    if (false === $position) {
        return;
    }
    $route = substr($uri, $position + strlen('/wp-json'));
    $query_at = strpos($route, '?');
    if (false !== $query_at) {
        $route = substr($route, 0, $query_at);
    }
    if (!huhs_public_cache_route($route)) {
        return;
    }

    $params = isset($_GET) && is_array($_GET) ? $_GET : array();
    if (function_exists('wp_unslash')) {
        $params = wp_unslash($params);
    }
    $cached = get_transient(huhs_public_cache_key($route, $params));
    if (!is_array($cached) || !isset($cached['etag'])) {
        return;
    }
    $payload = null;
    if (isset($cached['json']) && is_string($cached['json'])) {
        $payload = $cached['json'];
    } elseif (isset($cached['body'])) {
        $payload = wp_json_encode($cached['body'], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    }
    if (!is_string($payload) || '' === $payload) {
        return;
    }

    $etag = (string) $cached['etag'];
    $headers = isset($cached['headers']) && is_array($cached['headers']) ? $cached['headers'] : array();
    $not_modified = huhs_public_cache_etag_matches_value(
        isset($_SERVER['HTTP_IF_NONE_MATCH']) ? $_SERVER['HTTP_IF_NONE_MATCH'] : '',
        $etag
    );

    if (!headers_sent()) {
        foreach ($headers as $name => $value) {
            if (is_string($name) && is_string($value)) {
                header($name . ': ' . $value, true);
            }
        }
        header('ETag: ' . $etag, true);
        header('Cache-Control: ' . HUHS_PUBLIC_CACHE_CONTROL, true);
        header('Vary: Accept-Encoding, Origin', true);
        header('X-HUHS-Cache: early', true);
    }

    if ($not_modified) {
        if (!headers_sent()) {
            http_response_code(304);
            header_remove('Content-Type');
            header_remove('Content-Length');
        }
        exit;
    }

    if (!headers_sent()) {
        header('Content-Type: application/json; charset=UTF-8', true);
    }
    if ('HEAD' === $method) {
        // The web server drops the body of a HEAD response; sending none keeps the
        // behaviour identical to the REST path.
        exit;
    }
    echo $payload;
    exit;
}

huhs_try_serve_public_cache_early();
