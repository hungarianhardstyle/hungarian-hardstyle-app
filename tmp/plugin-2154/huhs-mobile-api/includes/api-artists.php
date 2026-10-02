<?php

if (!defined('ABSPATH')) {
    exit;
}

add_action('rest_api_init', 'huhs_register_artists_api');

function huhs_register_artists_api()
{
    register_rest_route('huhs/v1', '/artists', array(
        'methods'             => 'GET',
        'callback'            => 'huhs_get_artists',
        'permission_callback' => '__return_true',
        'args'                => array(
            'page' => array(
                'sanitize_callback' => 'absint',
                'default' => 1,
            ),
            'per_page' => array(
                'sanitize_callback' => 'absint',
                'default' => 20,
            ),
            'search' => array(
                'sanitize_callback' => 'sanitize_text_field',
                'default' => '',
            ),
            'category' => array(
                'sanitize_callback' => function ($value) {
                    return sanitize_title((string) $value);
                },
                'default' => '',
            ),
        ),
    ));

    register_rest_route('huhs/v1', '/artists/(?P<id>\d+)', array(
        'methods'             => 'GET',
        'callback'            => 'huhs_get_artist_detail',
        'permission_callback' => '__return_true',
        'args'                => array(
            'id' => array(
                'sanitize_callback' => 'absint',
                'validate_callback' => function ($value) {
                    return absint($value) > 0;
                },
            ),
        ),
    ));

    // ⚠️ PRIVÁT végpont: a DJ-adatlap claim-hez használt címek (nyilvános booking
    // + **privát** kapcsolattartó). A `contact_email` a beküldő **személyes**
    // címe, ezért a nyilvános `/artists/<id>` válaszból szándékosan kimarad —
    // csak a HUHS szervere kérdezheti le, a WordPress
    // admin-alkalmazásjelszavával (`current_user_can('manage_options')`).
    register_rest_route('huhs/v1', '/artists/(?P<id>\d+)/claim-emails', array(
        'methods'             => 'GET',
        'callback'            => 'huhs_get_artist_claim_emails',
        'permission_callback' => function () {
            return current_user_can('manage_options');
        },
        'args'                => array(
            'id' => array(
                'sanitize_callback' => 'absint',
                'validate_callback' => function ($value) {
                    return absint($value) > 0;
                },
            ),
        ),
    ));

    // Egyszeri, **idempotens** pótlás: a korábban jóváhagyott DJ-adatlapokra
    // átmásolja a beküldés privát címét (`contact_email`), különben a DJ nem
    // tudná claimelni a saját adatlapját (a jóváhagyás ezt korábban nem tette át).
    register_rest_route('huhs/v1', '/artists/claim-emails/backfill', array(
        'methods'             => WP_REST_Server::CREATABLE,
        'callback'            => 'huhs_backfill_artist_claim_emails',
        'permission_callback' => function () {
            return current_user_can('manage_options');
        },
    ));

    // ⚠️ A CLAIMELT (átvett) DJ-adatlap szerkesztése.
    //
    // MIÉRT KÜLÖN ÚTVONAL (`/dj-profile/...`) ÉS NEM `/artists/...`:
    //  1. a nyilvános gyorsítótár engedélylistája **előtagra** illeszkedik
    //     (`huhs_public_cache_route()`), ezért minden `/artists/...` alatti út
    //     cache-elhetőnek látszott — egy írás-végpontnak ott nincs helye;
    //  2. a `POST` szándékos: a gyorsítótár csak `GET`/`HEAD` választ tárol.
    //
    // A JOGOSULTSÁG: a végpontot a **HUHS szervere** hívja a WordPress
    // admin-alkalmazásjelszavával, ezért itt `manage_options` a kapu — azt, hogy
    // a hívó **magáé az adatlap**, a szerver oldalán a `artist_claims` gyűjtemény
    // dönti el (a Firebase-függvény ellenőrzi, mielőtt ide hív).
    register_rest_route('huhs/v1', '/dj-profile/(?P<id>\d+)', array(
        'methods'             => WP_REST_Server::CREATABLE,
        'callback'            => 'huhs_update_claimed_artist_profile',
        'permission_callback' => function () {
            return current_user_can('manage_options');
        },
        'args'                => array(
            'id' => array(
                'sanitize_callback' => 'absint',
                'validate_callback' => function ($value) {
                    return absint($value) > 0;
                },
            ),
        ),
    ));
}

/**
 * A DJ által szerkeszthető mezők: META-kulcs → típus.
 *
 * ⚠️ SZÁNDÉKOSAN SZŰK: a **foglalási e-mail** (`booking_email`) és a ház
 * döntései (`visible`, `featured`, `booking_via_huhs`), valamint a taxonómiák
 * (`genre`, `huhs_artist_category`) **nincsenek** itt. A booking e-mail az
 * adatlap-átvétel igazolása — ha a DJ átírhatná, egy másik fiók is átvehetné az
 * adatlapot. A `contact_email` (privát cím) szintén nem szerkeszthető innen.
 *
 * A sanitálás ugyanaz, mint a WordPress-admin mentésénél
 * (`artist-save.php` → `huhs_save_artist_meta`): szöveg → `sanitize_text_field`,
 * URL → `esc_url_raw`. A képek a beküldés útját követik (`logo_url`,
 * `hero_image_url` — Cloudinary URL-ek), ezért azokra külön, szigorú szabály van.
 */
function huhs_artist_editable_fields()
{
    return array(
        'real_name'  => 'text',
        'city'       => 'text',
        'country'    => 'text',
        'website'    => 'url',
        'facebook'   => 'url',
        'instagram'  => 'url',
        'tiktok'     => 'url',
        'spotify'    => 'url',
        'soundcloud' => 'url',
        'youtube'    => 'url',
    );
}

/** Egyetlen mező sanitálása a fenti típusok szerint. */
function huhs_artist_sanitize_editable_value($type, $value)
{
    $raw = is_string($value) ? trim(wp_unslash($value)) : '';
    if ('url' === $type) {
        return esc_url_raw($raw, array('http', 'https'));
    }
    return sanitize_text_field($raw);
}

/**
 * A kép-csere: csak **Cloudinary** kép URL fogadható el (a beküldés is ide tölt).
 * Üres érték = „ne nyúlj hozzá"; a törlés nem cél.
 */
function huhs_artist_sanitize_image_url($value)
{
    $raw = is_string($value) ? trim(wp_unslash($value)) : '';
    if ('' === $raw) {
        return '';
    }
    $url = esc_url_raw($raw, array('https'));
    $host = strtolower((string) wp_parse_url($url, PHP_URL_HOST));
    if ('res.cloudinary.com' !== $host) {
        return '';
    }
    return $url;
}

/**
 * A claimelt (átvett) DJ-adatlap szerkesztése — a HUHS szerverének hívására.
 *
 * Amit ír:
 *  - `title` → `post_title` (max 120 karakter),
 *  - `biography` → `post_content` (max 6000 karakter, `wpautop(esc_html())` —
 *    ugyanaz a minta, mint a natív admin írásánál: a szöveg nem tartalmazhat HTML-t),
 *  - a `huhs_artist_editable_fields()` mezői → post meta,
 *  - `logo_url` / `hero_image_url` → post meta, **és** a hozzá tartozó
 *    attachment-azonosító (`logo` / `hero_image`) **nullázása**: a nyilvános
 *    válasz az azonosítót előnyben részesíti, ezért enélkül a régi kép maradna.
 *
 * Amit NEM ír: `booking_email`, `contact_email`, `visible`, `featured`,
 * `booking_via_huhs`, `genre`, taxonómiák, slug, állapot.
 *
 * A válasz **ugyanaz a payload**, mint a nyilvános `/artists/<id>` végponté
 * (`huhs_build_artist_response(..., true)`), hogy az app egyből frissíthessen.
 */
function huhs_update_claimed_artist_profile(WP_REST_Request $request)
{
    $artist_id = absint($request->get_param('id'));
    $post = get_post($artist_id);

    if (!$post || $post->post_type !== 'huhs_artist') {
        return new WP_Error('huhs_artist_not_found', 'Nincs ilyen DJ-adatlap.', array('status' => 404));
    }

    $params = $request->get_json_params();
    if (!is_array($params)) {
        $params = $request->get_params();
    }
    if (!is_array($params)) {
        $params = array();
    }

    $updated = array();
    $post_fields = array();

    if (array_key_exists('title', $params)) {
        $title = sanitize_text_field(trim((string) wp_unslash($params['title'])));
        $title = function_exists('mb_substr') ? mb_substr($title, 0, 120) : substr($title, 0, 120);
        if ('' !== $title && $title !== $post->post_title) {
            $post_fields['post_title'] = $title;
            $updated[] = 'title';
        }
    }

    if (array_key_exists('biography', $params)) {
        $raw_bio = trim((string) wp_unslash($params['biography']));
        $raw_bio = function_exists('mb_substr') ? mb_substr($raw_bio, 0, 6000) : substr($raw_bio, 0, 6000);
        $content = '' === $raw_bio ? '' : wpautop(esc_html($raw_bio));
        if ($content !== $post->post_content) {
            $post_fields['post_content'] = $content;
            $updated[] = 'biography';
        }
    }

    if (!empty($post_fields)) {
        $post_fields['ID'] = $artist_id;
        $result = wp_update_post($post_fields, true);
        if (is_wp_error($result)) {
            return new WP_Error(
                'huhs_artist_profile_save_failed',
                'Az adatlap mentése nem sikerült.',
                array('status' => 500)
            );
        }
    }

    foreach (huhs_artist_editable_fields() as $meta_key => $type) {
        if (!array_key_exists($meta_key, $params)) {
            continue;
        }
        $value = huhs_artist_sanitize_editable_value($type, $params[$meta_key]);
        $limit = 'country' === $meta_key ? 80 : 160;
        $value = function_exists('mb_substr') ? mb_substr($value, 0, $limit) : substr($value, 0, $limit);
        if ((string) get_post_meta($artist_id, $meta_key, true) === $value) {
            continue;
        }
        update_post_meta($artist_id, $meta_key, $value);
        $updated[] = $meta_key;
    }

    foreach (array('logo_url' => 'logo', 'hero_image_url' => 'hero_image') as $url_key => $attachment_key) {
        if (!array_key_exists($url_key, $params)) {
            continue;
        }
        $url = huhs_artist_sanitize_image_url($params[$url_key]);
        if ('' === $url) {
            return new WP_Error(
                'huhs_artist_profile_invalid',
                'A kép csak Cloudinary-linkkel cserélhető.',
                array('status' => 400)
            );
        }
        update_post_meta($artist_id, $url_key, $url);
        // A nyilvános válasz az attachment-azonosítót előnyben részesíti: ha ez
        // megmarad, a régi kép látszana tovább.
        update_post_meta($artist_id, $attachment_key, 0);
        $updated[] = $url_key;
    }

    if (empty($updated)) {
        return new WP_Error(
            'huhs_artist_profile_invalid',
            'Nem érkezett menthető mező.',
            array('status' => 400)
        );
    }

    // A nyilvános válasz-gyorsítótár a post-mentésre magától ürül, a
    // meta-írásra viszont NEM (`http-cache.php`), ezért itt kifejezetten kérjük.
    if (function_exists('huhs_invalidate_public_cache')) {
        huhs_invalidate_public_cache();
    }

    clean_post_cache($artist_id);

    return new WP_REST_Response(array(
        'updated' => array_values(array_unique($updated)),
        'artist'  => huhs_build_artist_response(get_post($artist_id), true),
    ), 200);
}

/**
 * A claim-hez használt címek: nyilvános booking + privát kapcsolattartó.
 *
 * Kisbetűsítve adjuk vissza (a szerveroldali összehasonlítás így egyszerű), és
 * **nem** helyettesítjük a `booking_email`-t a ház címével: itt a valódi mező
 * számít, mert a claim azon is alapulhat, hogy a DJ a saját privát címével
 * jelentkezett be.
 */
function huhs_get_artist_claim_emails(WP_REST_Request $request)
{
    $artist_id = absint($request->get_param('id'));
    $post = get_post($artist_id);

    if (!$post || $post->post_type !== 'huhs_artist') {
        return new WP_Error('huhs_artist_not_found', 'Nincs ilyen DJ-adatlap.', array('status' => 404));
    }

    return new WP_REST_Response(array(
        'artistId'      => $artist_id,
        'booking_email' => strtolower((string) sanitize_email(get_post_meta($artist_id, 'booking_email', true))),
        'contact_email' => strtolower((string) sanitize_email(get_post_meta($artist_id, 'contact_email', true))),
    ), 200);
}

/**
 * A privát címek pótlása a meglévő adatlapokra (a beküldés → adatlap útból).
 *
 * SZÁNDÉKOSAN csak akkor ír, ha az adatlapnak **még nincs** ilyen mezője: egy
 * kézzel beírt (vagy javított) címet nem ír felül, ezért az ismételt futtatás
 * sem tesz kárt.
 */
function huhs_backfill_artist_claim_emails()
{
    $submission_ids = get_posts(array(
        'post_type'      => 'huhs_submission',
        'post_status'    => 'any',
        'posts_per_page' => -1,
        'fields'         => 'ids',
        'meta_query'     => array(
            array(
                'key'     => 'created_profile_id',
                'compare' => 'EXISTS',
            ),
        ),
    ));

    $updated = 0;
    $skipped = 0;

    foreach ($submission_ids as $submission_id) {
        $profile_id = (int) get_post_meta($submission_id, 'created_profile_id', true);
        $contact = (string) sanitize_email(get_post_meta($submission_id, 'contact_email', true));

        if (!$profile_id || $contact === '') {
            $skipped++;
            continue;
        }

        $post = get_post($profile_id);
        if (!$post || $post->post_type !== 'huhs_artist') {
            $skipped++;
            continue;
        }

        $existing = (string) sanitize_email(get_post_meta($profile_id, 'contact_email', true));
        if ($existing !== '') {
            $skipped++;
            continue;
        }

        update_post_meta($profile_id, 'contact_email', $contact);
        $updated++;
    }

    return new WP_REST_Response(array(
        'updated' => $updated,
        'skipped' => $skipped,
    ), 200);
}

function huhs_get_artists(WP_REST_Request $request)
{
    $page = max(1, absint($request->get_param('page')));
    $per_page = min(50, max(1, absint($request->get_param('per_page')) ?: 20));
    $search = sanitize_text_field((string) $request->get_param('search'));
    $category = sanitize_title((string) $request->get_param('category'));
    $lang = huhs_request_lang($request);

    $tax_query = array();
    if ($category !== '') {
        $tax_query[] = array(
            'taxonomy' => 'huhs_artist_category',
            'field'    => 'slug',
            'terms'    => $category,
        );
    }

    $query_args = array(
        'post_type'      => 'huhs_artist',
        'post_status'    => 'publish',
        'posts_per_page' => $per_page,
        'paged'          => $page,
        'orderby'        => array(
            'meta_value_num' => 'DESC',
            'title'          => 'ASC',
        ),
        'meta_key'       => 'featured',
        's'              => $search,
        'meta_query'     => array(
            array(
                'key'     => 'visible',
                'value'   => '1',
                'compare' => '=',
            ),
        ),
        'no_found_rows'  => false,
    );

    if ($tax_query) {
        $query_args['tax_query'] = $tax_query;
    }

    $query = new WP_Query($query_args);

    $items = array_map(function ($artist) use ($lang) {
        return huhs_build_artist_response($artist, false, $lang);
    }, $query->posts);

    $total_pages = (int) $query->max_num_pages;

    return rest_ensure_response(array(
        'items'       => $items,
        'page'        => $page,
        'per_page'    => $per_page,
        'total'       => (int) $query->found_posts,
        'total_pages' => $total_pages,
        'has_more'    => $page < $total_pages,
    ));
}

function huhs_get_artist_detail(WP_REST_Request $request)
{
    $artist_id = absint($request->get_param('id'));
    $artist = get_post($artist_id);

    if (
        !$artist ||
        $artist->post_type !== 'huhs_artist' ||
        $artist->post_status !== 'publish' ||
        !get_post_meta($artist_id, 'visible', true)
    ) {
        return new WP_Error(
            'huhs_artist_not_found',
            'A DJ adatlap nem talalhato.',
            array('status' => 404)
        );
    }

    return rest_ensure_response(huhs_build_artist_response($artist, true, huhs_request_lang($request)));
}

function huhs_build_artist_response($artist, $include_events = false, $lang = 'hu')
{
    $artist_id = (int) $artist->ID;
    // A kért nyelv (2.12.0): cím, bemutató (biography) és kivonat.
    $translation = huhs_translation_meta_values(
        $artist_id,
        $lang,
        $artist->post_title,
        $artist->post_content
    );
    $genre_value = get_post_meta($artist_id, 'genre', true);
    $genres = is_array($genre_value)
        ? $genre_value
        : explode(',', (string) $genre_value);
    $genres = array_values(array_unique(array_filter(array_map('trim', $genres))));

    $logo_id = (int) get_post_meta($artist_id, 'logo', true);
    $hero_id = (int) get_post_meta($artist_id, 'hero_image', true);
    $logo_url = esc_url_raw(get_post_meta($artist_id, 'logo_url', true));
    $hero_url = esc_url_raw(get_post_meta($artist_id, 'hero_image_url', true));
    $featured_id = (int) get_post_thumbnail_id($artist_id);
    $logo = $logo_id ? wp_get_attachment_image_url($logo_id, 'medium') : $logo_url;
    $hero = $hero_id ? wp_get_attachment_image_url($hero_id, 'large') : $hero_url;
    $wordpress_featured_image = $featured_id
        ? wp_get_attachment_image_url($featured_id, 'large')
        : '';
    $profile_image = $hero ?: ($wordpress_featured_image ?: $logo);
    $category_terms = get_the_terms($artist_id, 'huhs_artist_category');
    $categories = array();
    $booking_via_huhs = (bool) get_post_meta($artist_id, 'booking_via_huhs', true);
    $booking_email = $booking_via_huhs
        ? 'info@hungarianhardstyle.hu'
        : sanitize_email(get_post_meta($artist_id, 'booking_email', true));

    if (is_array($category_terms)) {
        foreach ($category_terms as $term) {
            $categories[] = array(
                'id'   => (int) $term->term_id,
                'name' => $term->name,
                'slug' => $term->slug,
            );
        }
    }

    $data = array(
        'id'             => $artist_id,
        'title'          => huhs_clean_title($translation['title']),
        'has_en'         => $translation['has_en'],
        'slug'           => $artist->post_name,
        'biography'      => huhs_clean_content($translation['content']),
        'excerpt'        => $translation['excerpt'] !== ''
            ? huhs_make_excerpt($translation['excerpt'], 30)
            : huhs_make_excerpt($translation['content'], 30),
        'real_name'      => get_post_meta($artist_id, 'real_name', true),
        // ⚠️ 2.13.0: az ország/város név — determinisztikus névtár fordítja
        // (`translation-places.php`), nem az AI. A magyar ág változatlan.
        'country'        => huhs_translation_country_value(get_post_meta($artist_id, 'country', true), $lang),
        'city'           => huhs_translation_city_value(get_post_meta($artist_id, 'city', true), $lang),
        'genres'         => $genres,
        'categories'     => $categories,
        'logo'           => $logo ?: '',
        'profile_image'  => $profile_image ?: '',
        'hero_image'     => $hero ?: '',
        'featured_image' => $profile_image ?: '',
        'featured'       => (bool) get_post_meta($artist_id, 'featured', true),
        'visible'        => (bool) get_post_meta($artist_id, 'visible', true),
        'link'           => get_permalink($artist_id),
        'booking_email'  => $booking_email,
        'booking_via_huhs'=> $booking_via_huhs,
        'social_links'   => array(
            'website'    => get_post_meta($artist_id, 'website', true),
            'facebook'   => get_post_meta($artist_id, 'facebook', true),
            'instagram'  => get_post_meta($artist_id, 'instagram', true),
            'tiktok'     => get_post_meta($artist_id, 'tiktok', true),
            'spotify'    => get_post_meta($artist_id, 'spotify', true),
            'soundcloud' => get_post_meta($artist_id, 'soundcloud', true),
            'youtube'    => get_post_meta($artist_id, 'youtube', true),
        ),
    );

    if ($include_events) {
        $data['upcoming_events'] = huhs_get_artist_upcoming_events($artist_id, $lang);
    }

    return $data;
}

function huhs_get_artist_upcoming_events($artist_id, $lang = 'hu')
{
    $events = get_posts(array(
        'post_type'      => 'huhs_event',
        'post_status'    => 'publish',
        'posts_per_page' => -1,
        'meta_key'       => 'event_start_date',
        'orderby'        => 'meta_value',
        'order'          => 'ASC',
        'meta_query'     => array(
            array(
                'key'     => 'event_start_date',
                'value'   => current_time('Y-m-d'),
                'compare' => '>=',
                'type'    => 'DATE',
            ),
            array(
                'key'     => 'visible',
                'value'   => '1',
                'compare' => '=',
            ),
        ),
    ));

    $upcoming = array();

    foreach ($events as $event) {
        $artist_ids = json_decode(get_post_meta($event->ID, 'artists', true), true);
        if (!is_array($artist_ids)) {
            continue;
        }

        $artist_ids = array_map('intval', $artist_ids);
        if (!in_array((int) $artist_id, $artist_ids, true)) {
            continue;
        }

        $upcoming[] = huhs_build_event_response($event, $lang);
    }

    return $upcoming;
}
