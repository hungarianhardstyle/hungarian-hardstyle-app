<?php

if (!defined('ABSPATH')) {
    exit;
}

/*
|--------------------------------------------------------------------------
| Önjavító fordítás-pótlás (sweep) — plugin 2.13.0
|--------------------------------------------------------------------------
|
| MIÉRT KELL (mérve, 2026-09-25): a 2.12.0 automatikus fordítása a **mentésre**
| épül (`save_post` → WP-cron). Ez két esetben nem elég:
|
|  1. a plugin előtt létrejött tartalom (mérve: 6 régi esemény és a régebbi
|     cikkek angol nélkül maradtak — a mentésük már megtörtént, mielőtt a
|     fordítás létezett);
|  2. ha egy mentés idején a szolgáltató hibázott (nincs újrapróbálkozás).
|
| Erre való ez a fájl: **óránként** végigmegy a publikált tartalmakon, és amelyik
| elemen van magyar szöveg, de nincs angol fordítás, azt lefordítja. Így a
| hiányzó angol **magától** pótlódik, a tulajdonos nem nyúl semmihez.
|
| ⚠️ NEM NYÚL A MEGLÉVŐ FORDÍTÁSHOZ. A pótlás csak azt az elemet fordítja,
| amelyiken **nincs** `_huhs_content_en`. A magyar szöveg **megváltozását** a
| mentés (`save_post`) kezeli — ott a `_huhs_translation_hash` dönti el, hogy
| kell-e újra fordítani.
|
| ⚠️ A KÖLTSÉG KORLÁTOZVA: futásonként típusonként legfeljebb `limit` elem, és
| legfeljebb `budget` másodperc (a WP-cron egy látogató kérésében fut!). A
| tartós hibát a `_huhs_translation_failed` + `_huhs_translation_failed_at`
| jegyzi, és csak késleltetés után próbálja újra (nem pörög végtelenül).
|
| ⚠️ NINCS MELLÉKHATÁS: a pótlás közvetlenül a fordítást hívja (meta-írás), nem
| `wp_update_post`-ot — ezért nem indul tőle értesítés (push), és a
| `save_post`-lánc sem fut le. Ez szándékos: a pótlás nem hozhat létre
| felhasználói értesítést.
*/

const HUHS_TRANSLATION_HASH_META = '_huhs_translation_hash';
const HUHS_TRANSLATION_FAILED_META = '_huhs_translation_failed';
const HUHS_TRANSLATION_FAILED_AT_META = '_huhs_translation_failed_at';

/**
 * A magyar forrás ujjlenyomata (cím + törzs).
 *
 * Ebből dől el, hogy a meglévő angol **erre a szövegre** készült-e. A `md5`
 * elég: nem biztonsági, hanem változás-követési célra van.
 */
function huhs_translation_source_hash($post)
{
    $title = trim((string) $post->post_title);
    $content = trim((string) $post->post_content);

    return md5($title . "\n" . $content);
}

/** Az utoljára fordított forrás ujjlenyomata (ha volt ilyen). */
function huhs_translation_stored_hash($post_id)
{
    return (string) get_post_meta($post_id, HUHS_TRANSLATION_HASH_META, true);
}

/**
 * A meglevő angol fordítás **erre a magyar szövegre** készült-e?
 *
 * Csak akkor igaz, ha az ujjlenyomat egyezik ÉS a fordítás érdemi része
 * (cím+törzs) megvan — vagyis ugyanaz a kapu, amit a kiolvasó is használ.
 */
function huhs_translation_is_current($post_id, $hash)
{
    if ($hash === '' || huhs_translation_stored_hash($post_id) !== $hash) {
        return false;
    }

    return trim((string) get_post_meta($post_id, '_huhs_title_en', true)) !== ''
        && trim((string) get_post_meta($post_id, '_huhs_content_en', true)) !== '';
}

/**
 * Ezt a pontos szöveget mostanában már megpróbáltuk és hibázott?
 *
 * A késleltetés (`huhs_translation_retry_delay`, alap 6 óra) azért kell, mert
 * egy átmeneti szolgáltató-hiba nem jelölheti meg az elemet örökre.
 */
function huhs_translation_failed_recently($post_id, $hash)
{
    if ($hash === '' || (string) get_post_meta($post_id, HUHS_TRANSLATION_FAILED_META, true) !== $hash) {
        return false;
    }

    $at = (int) get_post_meta($post_id, HUHS_TRANSLATION_FAILED_AT_META, true);
    if ($at <= 0) {
        return false;
    }

    $delay = (int) apply_filters('huhs_translation_retry_delay', 6 * HOUR_IN_SECONDS);

    return (time() - $at) < max(60, $delay);
}

/** A tartós hiba jelölése (ujjlenyomat + időpont). */
function huhs_translation_mark_failed($post_id, $hash)
{
    update_post_meta($post_id, HUHS_TRANSLATION_FAILED_META, (string) $hash);
    update_post_meta($post_id, HUHS_TRANSLATION_FAILED_AT_META, time());
}

/**
 * A fordításra váró elemek egy típusból (WP_Query szinten szűrve).
 *
 * A szűrő a `_huhs_content_en` **hiányára** szól, ezért a lista a pótlás
 * előrehaladtával magától ürül — nincs szükség "kurzor" állapotra.
 *
 * @param string $post_type A típus.
 * @param int    $limit     Legfeljebb ennyi elem.
 * @param bool   $force     Kényszerített újragenerálás (a mentett fordítás nem
 *                          dönt): a „megjavult íróval írjuk újra" esetre.
 * @return WP_Post[]
 */
function huhs_translation_pending_posts($post_type, $limit = 5, $force = false)
{
    if (!in_array($post_type, huhs_translation_all_post_types(), true)) {
        return array();
    }

    $query = array(
        'post_type' => $post_type,
        'post_status' => 'publish',
        'posts_per_page' => max(1, (int) $limit),
        'orderby' => 'ID',
        'order' => 'ASC',
        'suppress_filters' => false,
    );

    if ($force) {
        // ⚠️ 2.14.4: kényszerített újragenerálás. A mentett fordítás itt nem
        // dönthet (ez a lényeg), ezért csak az számít, hogy van-e fordítható
        // forrás. Erre a javító útra akkor van szükség, ha a TÁROLT fordítás
        // sérült (pl. a 2.14.2 előtti escape-hiba `rn`/`u00e9` szemete), és a
        // forrás-ujjlenyomat változatlansága miatt magától nem indulna újra.
        $posts = get_posts($query);
        $usable = array();
        foreach ($posts as $post) {
            if ($post instanceof WP_Post && huhs_translation_post_has_source($post)) {
                $usable[] = $post;
            }
        }
        return $usable;
    }

    // A várólista két forrásból állhat: a **cím/törzs** fordításából és a
    // **meta-szövegek** fordításából (2.14.0). A SQL csak előszűrő (bármelyik
    // hiányzik), a pontos döntést a `huhs_translation_post_needs_work()` adja —
    // így egy megváltozott forrás vagy egy nemrég hibázott elem is helyesen
    // kerül ki/be.
    $meta_query = array('relation' => 'OR');
    if (in_array($post_type, huhs_translation_post_types(), true)) {
        $meta_query[] = array('key' => '_huhs_content_en', 'compare' => 'NOT EXISTS');
        $meta_query[] = array('key' => '_huhs_content_en', 'value' => '', 'compare' => '=');
    }
    if (huhs_translation_field_specs($post_type)) {
        $meta_query[] = array('key' => HUHS_TRANSLATION_FIELDS_META, 'compare' => 'NOT EXISTS');
        $meta_query[] = array('key' => HUHS_TRANSLATION_FIELDS_META, 'value' => '', 'compare' => '=');
        // ⚠️ 2.14.4 — A SÉMA-VERZIÓ KAPUJA (mért éles hiba javítása).
        //
        // A fenti két ág csak a **soha nem fordított** elemeket hozza be, a
        // verzió-kapu (`huhs_translation_fields_current()`) viszont pont a
        // **már lefordított**, de RÉGI sémával (hibás escape-ekkel) mentett
        // elemeket akarja újragenerálni. Enélkül a kapu **elérhetetlen** volt:
        // a pótló kör 0 elemet vizsgált a nyeremény/kérdőív/játék típusokban,
        // ezért a nyeremény leírásában élesben ott maradt az `rnrn`
        // (mérve 2026-09-26: `pending = {huhs_prize: 0}`, miközben a tárolt
        // leírás roncsolt volt).
        //
        // A `NOT EXISTS` a 2.14.3 előtt mentett elemeket hozza be (nincs
        // verzió-jelölőjük), a `<` (NUMERIC) pedig egy **korábbi** verzióval
        // írtakat — így a kapu egy későbbi verzió-emelésnél is működik.
        // ⚠️ Szándékosan nem `!=`: annak a join-viselkedése a hiányzó metára
        // WordPress-verziófüggő, a `<` + `NOT EXISTS` viszont egyértelmű.
        $meta_query[] = array(
            'key' => HUHS_TRANSLATION_FIELDS_VERSION_META,
            'compare' => 'NOT EXISTS',
        );
        $meta_query[] = array(
            'key' => HUHS_TRANSLATION_FIELDS_VERSION_META,
            'value' => (string) HUHS_TRANSLATION_FIELDS_VERSION,
            'compare' => '<',
            'type' => 'NUMERIC',
        );
    }

    $query['meta_query'] = $meta_query;
    $posts = get_posts($query);

    $pending = array();
    foreach ($posts as $post) {
        if (!$post instanceof WP_Post) {
            continue;
        }
        if (huhs_translation_post_needs_work($post)) {
            $pending[] = $post;
        }
    }

    return $pending;
}

/** Van-e egyáltalán fordítható (nem üres) magyar forrása az elemnek? */
function huhs_translation_post_has_source($post)
{
    if (!$post instanceof WP_Post) {
        return false;
    }

    if (in_array($post->post_type, huhs_translation_post_types(), true)
        && trim((string) $post->post_title) !== ''
        && trim((string) $post->post_content) !== '') {
        return true;
    }

    if (function_exists('huhs_translation_source_fields')
        && huhs_translation_field_specs($post->post_type)
        && huhs_translation_source_fields($post->ID)) {
        return true;
    }

    return false;
}

/**
 * Kell-e ezzel az elemmel még foglalkozni? (a pótló kör döntése)
 *
 *  * **cím/törzs**: van nem üres magyar szöveg, és nincs naprakész fordítás;
 *  * **meta-szöveg**: van nem üres magyar mező, és nincs naprakész fordítás;
 *  * a nemrég hibázott rész kimarad (késleltetés), hogy ne pörögjön végtelenül.
 */
function huhs_translation_post_needs_work($post)
{
    if (!$post instanceof WP_Post) {
        return false;
    }

    if (in_array($post->post_type, huhs_translation_post_types(), true)) {
        $title = trim((string) $post->post_title);
        $content = trim((string) $post->post_content);
        if ($title !== '' && $content !== '') {
            $hash = huhs_translation_source_hash($post);
            if (!huhs_translation_is_current($post->ID, $hash)
                && !huhs_translation_failed_recently($post->ID, $hash)) {
                return true;
            }
        }
    }

    if (function_exists('huhs_translation_field_specs') && huhs_translation_field_specs($post->post_type)) {
        if (huhs_translation_source_fields($post->ID) && !huhs_translation_fields_current($post->ID)) {
            $hash = huhs_translation_fields_source_hash($post->ID);
            if (!huhs_translation_fields_failed_recently($post->ID, $hash)) {
                return true;
            }
        }
    }

    return false;
}

/** Hány elem vár fordításra típusonként (a `status` végpontnak). */
function huhs_translation_pending_counts($limit_per_type = 200)
{
    $counts = array();
    foreach (huhs_translation_all_post_types() as $post_type) {
        $counts[$post_type] = count(huhs_translation_pending_posts($post_type, $limit_per_type));
    }

    return $counts;
}

/**
 * A pótlás lefuttatása — a WP-cron (óránként) és a REST-végpont is ezt hívja.
 *
 * @param array $args {
 *     @type string|array $type   Egy típus, típuslista, vagy üres = mind.
 *     @type int          $limit  Típusonkénti felső korlát (alap 5, max 20).
 *     @type int          $budget Másodpercben mért keret (alap 20, max 60).
 * }
 * @return array{enabled: bool, checked: int, translated: int, failed: int, skipped: int, by_type: array, pending: array}
 */
function huhs_translation_sweep($args = array())
{
    $types = huhs_translation_sweep_types($args['type'] ?? '');
    $limit = (int) ($args['limit'] ?? 5);
    $limit = max(1, min(20, $limit));
    $budget = (int) ($args['budget'] ?? 20);
    $budget = max(0, min(60, $budget));
    // 2.14.4: kényszerített újragenerálás (a mentett fordítás nem dönt) — a
    // sérült tárolt szövegek javítására. Csak admin-végpontról érhető el.
    $force = !empty($args['force']);

    $result = array(
        'enabled' => huhs_translation_enabled(),
        'checked' => 0,
        'translated' => 0,
        'failed' => 0,
        'skipped' => 0,
        'by_type' => array(),
        'pending' => array(),
    );

    // Kulcs nélkül a pótlás sem indul (mint a mentés-ágon): nincs hívás, nincs írás.
    if (!$result['enabled']) {
        return $result;
    }

    $deadline = time() + $budget;

    foreach ($types as $post_type) {
        $type_stats = array('checked' => 0, 'translated' => 0, 'failed' => 0, 'skipped' => 0);

        if (time() >= $deadline) {
            $result['by_type'][$post_type] = $type_stats;
            continue;
        }

        foreach (huhs_translation_pending_posts($post_type, $limit, $force) as $post) {
            if (time() >= $deadline) {
                break;
            }

            $status = huhs_run_translation($post->ID, $force);
            $type_stats['checked']++;
            $result['checked']++;

            if ($status === 'translated') {
                $type_stats['translated']++;
                $result['translated']++;
            } elseif ($status === 'failed' || $status === 'partial') {
                $type_stats['failed']++;
                $result['failed']++;
            } else {
                $type_stats['skipped']++;
                $result['skipped']++;
            }
        }

        $result['by_type'][$post_type] = $type_stats;
    }

    $result['pending'] = huhs_translation_pending_counts();

    return $result;
}

/** A sweep típuslistája: egy típus, lista, vagy mind (érvénytelen érték = mind). */
function huhs_translation_sweep_types($requested)
{
    $all = huhs_translation_all_post_types();

    if (is_array($requested)) {
        $requested = array_values(array_intersect($all, $requested));
        return $requested ? $requested : $all;
    }

    $requested = sanitize_key((string) $requested);
    if ($requested === '' || !in_array($requested, $all, true)) {
        return $all;
    }

    return array($requested);
}

/* ---- REST: állapot és pótlás (csak admin) -------------------------------- */

add_action('rest_api_init', 'huhs_register_translation_sweep_api');

/**
 * Két végpont, szándékosan külön:
 *  - `GET /translations/status`  — csak olvas: mi vár még fordításra;
 *  - `POST /translations/sweep`  — lefuttatja a pótlást (ez ír).
 *
 * A jogosultság `manage_options`: ugyanaz a kapu, mint a többi admin-végponté
 * (a HUHS szervere az admin alkalmazás-jelszavával hívja).
 */
function huhs_register_translation_sweep_api()
{
    register_rest_route('huhs/v1', '/translations/status', array(
        'methods' => 'GET',
        'callback' => 'huhs_translation_status_endpoint',
        'permission_callback' => function () {
            return current_user_can('manage_options');
        },
    ));

    register_rest_route('huhs/v1', '/translations/sweep', array(
        'methods' => WP_REST_Server::CREATABLE,
        'callback' => 'huhs_translation_sweep_endpoint',
        'permission_callback' => function () {
            return current_user_can('manage_options');
        },
        'args' => array(
            'type' => array('sanitize_callback' => 'sanitize_key'),
            'limit' => array('sanitize_callback' => 'absint'),
            'budget' => array('sanitize_callback' => 'absint'),
            'force' => array('sanitize_callback' => 'rest_sanitize_boolean'),
        ),
    ));
}

/** Az állapot: be van-e kapcsolva, melyik szolgáltató, mi vár fordításra. */
function huhs_translation_status_endpoint()
{
    $provider = huhs_translation_provider();

    return rest_ensure_response(array(
        'enabled' => huhs_translation_enabled(),
        'provider' => array(
            'url' => (string) ($provider['url'] ?? ''),
            'model' => (string) ($provider['model'] ?? ''),
        ),
        'types' => huhs_translation_all_post_types(),
        'pending' => huhs_translation_pending_counts(),
    ));
}

/** A pótlás futtatása a kérés paramétereivel. */
function huhs_translation_sweep_endpoint(WP_REST_Request $request)
{
    return rest_ensure_response(huhs_translation_sweep(array(
        'type' => $request->get_param('type'),
        'limit' => $request->get_param('limit') ?: 5,
        'budget' => $request->get_param('budget') ?: 20,
        // 2.14.4: `force=1` — a megadott típus elemeit akkor is újrafordítja, ha
        // a tárolt fordítás naprakésznek látszik (sérült tárolt szöveg javítása).
        'force' => $request->get_param('force'),
    )));
}

/* ---- WP-cron: óránkénti önjavítás --------------------------------------- */

add_action('init', 'huhs_schedule_translation_sweep');

/**
 * Az óránkénti pótlás ütemezése.
 *
 * A `huhs_translation_sweep_enabled` szűrővel kikapcsolható (a fordítás
 * működik tovább a mentés-ágon), a `huhs_translation_sweep_limit` /
 * `huhs_translation_sweep_budget` szűrőkkel pedig szabályozható a költség.
 */
function huhs_schedule_translation_sweep()
{
    if (!apply_filters('huhs_translation_sweep_enabled', true)) {
        return;
    }

    if (wp_next_scheduled('huhs_translation_sweep_event')) {
        return;
    }

    wp_schedule_event(time() + 5 * MINUTE_IN_SECONDS, 'hourly', 'huhs_translation_sweep_event');
}

add_action('huhs_translation_sweep_event', 'huhs_run_translation_sweep_event');

/** A cron-kör: kis adag, hogy egy látogató kérése ne lassuljon észrevehetően. */
function huhs_run_translation_sweep_event()
{
    if (!huhs_translation_enabled()) {
        return;
    }

    huhs_translation_sweep(array(
        'limit' => (int) apply_filters('huhs_translation_sweep_limit', 3),
        'budget' => (int) apply_filters('huhs_translation_sweep_budget', 20),
    ));
}
