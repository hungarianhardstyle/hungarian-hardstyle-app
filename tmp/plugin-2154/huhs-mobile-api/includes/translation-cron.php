<?php

if (!defined('ABSPATH')) {
    exit;
}

/*
|--------------------------------------------------------------------------
| Automatikus fordítás új tartalomnál — plugin 2.12.0 (WP-cron)
|--------------------------------------------------------------------------
|
| A cél: ha egy cikk, esemény, DJ, szervező vagy kiadvány megjelenik, akkor az
| angol változat **magától** bekerüljön a fordítási metába (ugyanaz a három kulcs,
| amit a `post-translation-meta.php` regisztrál), hogy az app `lang=en` kérése
| azonnal angolul válaszoljon.
|
| ⚠️ API-KULCS NÉLKÜL EZ A FÁJL **NEM CSINÁL SEMMIT.** A kulcsot a
| `huhs_translation_api_key` opció (vagy a `huhs_translation_api_key` szűrő)
| adja; ha üres, a folyamat **el sem indul**, külső hívást nem indít, és nem is
| naplóz hibát. Ez szándékos: a fordítás szolgáltatás igénybe vétele a tulajdonos
| döntése, és kulcs nélkül a plugin nem hívhat idegen szolgáltatást.
|
| ⚠️ ÖRÖKSÉG-KULCS: ha az elsődleges kulcs üres, de a korábbi próbálkozás
| OpenAI-kulcsa megvan (`huhs_openai_api_key` opció vagy `HUHS_OPENAI_API_KEY`
| konstans), akkor **azt** használjuk, és a szolgáltató az OpenAI csevegő-végpontja
| lesz — így a plugin feltöltése után nem kell új kulcsot szerezni. Ha mindkettő
| megvan, az elsődleges (`huhs_translation_api_key`) nyer.
|
| A szolgáltató (a kulcs megadása után) a `huhs_translation_provider` szűrővel
| választható; az alapértelmezett a DeepSeek csevegő-végpontja, mert a tulajdonos
| ezt a szolgáltatót használja. A kérés alakja egyszerű: a magyar szövegeket
| egyetlen JSON-ben adjuk át, és angol JSON-t kérünk vissza (a rendszer-üzenet
| szigorúan megköti a kimenetet, hogy a válasz gépi ellenőrzéssel feldolgozható
| legyen). A válasz feldolgozása `huhs_translation_parse_response()`-ban van,
| ami **nem** hív hálózatot, ezért teszttel mérhető.
|
| A fordítás **soha** nem blokkolhatja a publikálást: minden hálózati hívás
| `wp_remote_post` időkorláttal, a hibák pedig csendben (legfeljebb egy
| figyelmeztetéssel) elnyelődnek — a cikk attól még megjelenik.
|
| ⚠️ 2.13.0: a mentés-ág megkapja az **ujjlenyomat-ellenőrzést** (ugyanarra a
| magyar szövegre nem fordítunk kétszer), a hiányzó fordításokat pedig az
| `includes/translation-sweep.php` pótolja óránként — a plugin előtt létrejött
| tartalom is magától angolul jelenik meg.
*/

add_action('save_post', 'huhs_schedule_translation_on_publish', 20, 3);

/**
 * A fordítás ütemezése publikáláskor (vagy frissítéskor).
 *
 * Csak a támogatott típusokra, csak publikált állapotban, és csak ha van kulcs.
 * A `wp_next_scheduled` ellenőrzés miatt egy cikkenként egyszer fut.
 */
function huhs_schedule_translation_on_publish($post_id, $post = null, $update = false)
{
    unset($update);

    if (!huhs_translation_enabled()) {
        return;
    }

    if (wp_is_post_revision($post_id) || wp_is_post_autosave($post_id)) {
        return;
    }

    $post = $post instanceof WP_Post ? $post : get_post($post_id);
    if (!$post instanceof WP_Post) {
        return;
    }

    if (!in_array($post->post_type, huhs_translation_all_post_types(), true)) {
        return;
    }

    if ($post->post_status !== 'publish') {
        return;
    }

    if (wp_next_scheduled('huhs_translate_post', array($post_id))) {
        return;
    }

    // ⚠️ 2.13.0: ha EBBEN a szövegben már megvan az angol fordítás (ujjlenyomat
    // egyezik), nem ütemezünk — egy díszítő mentés így nem költ API-hívást, és a
    // kézzel javított angol szöveget sem írja felül a semmiért.
    if (function_exists('huhs_translation_is_current')
        && in_array($post->post_type, huhs_translation_post_types(), true)
        && huhs_translation_is_current($post_id, huhs_translation_source_hash($post))) {
        return;
    }

    // Ugyanez a meta-szöveges típusokra (kérdőív, nyereményjáték, játék).
    if (function_exists('huhs_translation_field_specs')
        && huhs_translation_field_specs($post->post_type)
        && huhs_translation_fields_current($post_id)) {
        return;
    }

    // Kis késleltetés: a mentés befejeződjön, mielőtt a cron dolgozik.
    wp_schedule_single_event(time() + 60, 'huhs_translate_post', array($post_id));
}

add_action('huhs_translate_post', 'huhs_run_translation');

/**
 * Van-e bekapcsolt fordítás? (kulcs + szolgáltató)
 *
 * A kulcsot szűrővel is lehet adni (`huhs_translation_api_key`), így a
 * `wp-config.php`-ba tett konstanssal is működik a kód módosítása nélkül.
 */
function huhs_translation_enabled()
{
    return huhs_translation_api_key() !== '';
}

function huhs_translation_api_key()
{
    $key = (string) apply_filters('huhs_translation_api_key', get_option('huhs_translation_api_key', ''));
    if (trim($key) !== '') {
        return trim($key);
    }

    // ⚠️ ÖRÖKSÉG-KULCS (2026-09-25): a tulajdonos korábbi próbálkozásának
    // OpenAI-kulcsa (`huhs_openai_api_key` opció vagy `HUHS_OPENAI_API_KEY`
    // konstans) — a régi `includes/translations.php` ezt használta. Ha az megvan,
    // akkor **nem kell új kulcsot szerezni**: a szolgáltató ilyenkor az OpenAI
    // csevegő-végpontja lesz (lásd `huhs_translation_provider()`), és a fordítás
    // a plugin feltöltése után magától elindul.
    $legacy = defined('HUHS_OPENAI_API_KEY')
        ? (string) HUHS_OPENAI_API_KEY
        : (string) get_option('huhs_openai_api_key', '');

    return trim((string) apply_filters('huhs_translation_legacy_api_key', $legacy));
}

/**
 * Az ÖRÖKSÉG-kulcs van-e használatban? (azaz az elsődleges kulcs üres)
 *
 * Ebből dől el a szolgáltató alapértéke: OpenAI-kulccsal az OpenAI végpontja
 * kell, különben a kulcsot egy idegen szolgáltatónak küldenénk (401).
 */
function huhs_translation_api_key_is_legacy()
{
    $primary = (string) apply_filters('huhs_translation_api_key', get_option('huhs_translation_api_key', ''));
    if (trim($primary) !== '') {
        return false;
    }

    return huhs_translation_api_key() !== '';
}

/**
 * A szolgáltató leírása (végpont + modell + kulcs-fejléc).
 *
 * A szűrővel más szolgáltató is beköthető (OpenAI, Google), a válasz feldolgozása
 * viszont a `huhs_translation_parse_response()`-on megy át, ezért a szűrőnek
 * olyan választ kell adnia, amit az értelmezni tud.
 *
 * Az alapérték a kulcs forrását követi: örökölt OpenAI-kulcsnál az OpenAI
 * csevegő-végpontja (a válasz alakja ugyanaz: `choices[0].message.content`).
 */
function huhs_translation_provider()
{
    $default = huhs_translation_api_key_is_legacy()
        ? array(
            'url'     => 'https://api.openai.com/v1/chat/completions',
            'model'   => 'gpt-4o-mini',
            'timeout' => 45,
        )
        : array(
            'url'     => 'https://api.deepseek.com/chat/completions',
            'model'   => 'deepseek-chat',
            'timeout' => 45,
        );

    return apply_filters('huhs_translation_provider', $default);
}

/**
 * A fordítás lefuttatása egy bejegyzésre (WP-cron hívja).
 *
 * A magyar szövegeket a bejegyzésből olvassuk, a választ pedig a fordítási
 * metába írjuk. Ha bármi hiányzik (kulcs, szöveg, érvényes válasz), a
 * fordítási metához **nem nyúlunk** — így a magyar válasz marad az appnak.
 *
 * ⚠️ 2.13.0: a függvény **státuszt ad vissza** (a pótló kör ebből számol), és
 * két belső meta jelet vezet:
 *   * `_huhs_translation_hash`        — erre a magyar szövegre készült a fordítás;
 *   * `_huhs_translation_failed[_at]` — ez a szöveg nemrég hibázott (ne pörögjön).
 *
 * @return string 'disabled' | 'invalid' | 'empty' | 'uptodate' | 'failed' | 'partial' | 'translated'
 */
function huhs_run_translation($post_id, $force = false)
{
    if (!huhs_translation_enabled()) {
        return 'disabled';
    }

    $post = get_post($post_id);
    if (!$post instanceof WP_Post || !in_array($post->post_type, huhs_translation_all_post_types(), true)) {
        return 'invalid';
    }

    $statuses = array();

    // 1) A cím és a törzs (cikkek, események, DJ-k, szervezők, kiadványok, GYÍK).
    if (in_array($post->post_type, huhs_translation_post_types(), true)) {
        $title = trim((string) $post->post_title);
        $content = trim((string) $post->post_content);
        if ($title !== '' && $content !== '') {
            $statuses[] = huhs_run_content_translation($post, $title, $content, $force);
        }
    }

    // 2) A meta-szövegek (kérdőív, nyereményjáték, játék-összefoglaló) — 2.14.0.
    if (function_exists('huhs_translation_field_specs') && huhs_translation_field_specs($post->post_type)) {
        $statuses[] = huhs_run_field_translation($post_id, $force);
    }

    if (!$statuses) {
        return 'empty';
    }

    // A legrosszabb eredményt adjuk vissza (a pótló kör ebből számol): egy
    // hibázó rész akkor is látszik, ha a másik rész elkészült.
    foreach (array('failed', 'partial', 'translated', 'uptodate') as $candidate) {
        if (in_array($candidate, $statuses, true)) {
            return $candidate;
        }
    }

    return $statuses[0];
}

/**
 * A cím/törzs fordítása — a 2.13.0-i logika változatlanul (külön függvényben,
 * mert a `huhs_run_translation` 2.14.0-tól a meta-mezőket is fordítja).
 *
 * @return string 'empty' | 'uptodate' | 'failed' | 'partial' | 'translated'
 */
function huhs_run_content_translation($post, $title, $content, $force = false)
{
    $post_id = (int) $post->ID;
    $hash = huhs_translation_source_hash($post);

    // Erre a szövegre már megvan a fordítás — nincs mit tenni.
    // ⚠️ `$force` (2.14.4): kényszerített újragenerálás — a tárolt (esetleg
    // sérült) fordítás ilyenkor nem dönt, mert épp azt akarjuk lecserélni.
    if (!$force && huhs_translation_is_current($post_id, $hash)) {
        return 'uptodate';
    }

    // Ugyanez a szöveg nemrég hibázott: a késleltetésig nem próbáljuk újra.
    if (huhs_translation_failed_recently($post_id, $hash)) {
        return 'failed';
    }

    $response = huhs_translation_request(array(
        'title'   => $title,
        'content' => $content,
    ));

    if ($response === null) {
        huhs_translation_mark_failed($post_id, $hash);
        return 'failed';
    }

    // ⚠️ Teljesen üres válasz (pl. értelmezhetetlen JSON) = hiba, nem „részleges":
    // így a pótló kör is hibaként számol vele, és a napló nem hígul.
    if ($response['title'] === '' && $response['content'] === '' && $response['excerpt'] === '') {
        huhs_translation_mark_failed($post_id, $hash);
        return 'failed';
    }

    // ⚠️ `wp_slash()`: a WordPress `update_metadata()` unslash-el, ezért a
    // fordításban lévő backslash (és ezzel pl. egy `\"` vagy `\n`) elveszne.
    // A mért éles eset a JSON-mezőket érintette (`rnrn` / `u00e9`), de itt is
    // ugyanaz a minta kell — a HTML is tartalmazhat backslasht.
    if ($response['title'] !== '') {
        update_post_meta($post_id, '_huhs_title_en', wp_slash($response['title']));
    }
    if ($response['content'] !== '') {
        update_post_meta($post_id, '_huhs_content_en', wp_slash($response['content']));
    }
    if ($response['excerpt'] !== '') {
        update_post_meta($post_id, '_huhs_excerpt_en', wp_slash($response['excerpt']));
    }

    // ⚠️ „Kész" csak akkor, ha **ez a válasz** adta mindkettőt (cím ÉS törzs) —
    // ugyanaz a kapu, mint a kiolvasóé. A MEGLÉVŐ metát nem szabad nézni: egy
    // megváltozott magyar szövegnél a régi angol még ott van, és attól még nem
    // „kész" az új fordítás. (Mérve: a régi metára épített ellenőrzés a fél
    // választ `translated`-nek hazudta, és az elavult angolt jelölte késznek.)
    $done = $response['title'] !== '' && $response['content'] !== '';

    if (!$done) {
        huhs_translation_mark_failed($post_id, $hash);
        return 'partial';
    }

    update_post_meta($post_id, HUHS_TRANSLATION_HASH_META, $hash);
    delete_post_meta($post_id, HUHS_TRANSLATION_FAILED_META);
    delete_post_meta($post_id, HUHS_TRANSLATION_FAILED_AT_META);

    return 'translated';
}

/**
 * A szolgáltató hívása — hálózat. Hiba esetén `null` (nem dob, nem naplóz zajt).
 */
function huhs_translation_request($texts)
{
    $provider = huhs_translation_provider();
    $key = huhs_translation_api_key();

    if ($key === '' || empty($provider['url'])) {
        return null;
    }

    $body = array(
        'model'    => (string) ($provider['model'] ?? 'deepseek-chat'),
        'messages' => array(
            array(
                'role'    => 'system',
                'content' => huhs_translation_system_prompt(),
            ),
            array(
                'role'    => 'user',
                'content' => wp_json_encode(array(
                    'title'   => (string) ($texts['title'] ?? ''),
                    'content' => (string) ($texts['content'] ?? ''),
                )),
            ),
        ),
        'response_format' => array('type' => 'json_object'),
        'temperature'     => 0,
    );

    $response = wp_remote_post((string) $provider['url'], array(
        'timeout' => (int) ($provider['timeout'] ?? 45),
        'headers' => array(
            'content-type'  => 'application/json',
            'authorization' => 'Bearer ' . $key,
        ),
        'body'    => wp_json_encode($body),
    ));

    if (is_wp_error($response)) {
        return null;
    }

    if ((int) wp_remote_retrieve_response_code($response) !== 200) {
        return null;
    }

    return huhs_translation_parse_response((string) wp_remote_retrieve_body($response));
}

/**
 * A rendszer-üzenet: szigorú JSON ki/be, hogy a válasz gépi ellenőrzéssel
 * feldolgozható legyen (a magyar szöveg marad a kulcs, az angol az érték).
 */
function huhs_translation_system_prompt()
{
    return 'You translate Hungarian website content of a Hungarian Hardstyle music app into English. '
        . 'Answer with a single JSON object with exactly the keys "title", "content" and "excerpt". '
        . 'Keep the HTML structure of "content" (paragraphs, links, lists) intact, keep brand names '
        . '(Hungarian Hardstyle, HUHS, artist, festival and release names) unchanged, and never return '
        . 'an empty string: if a text is already English, repeat it unchanged.';
}

/**
 * A szolgáltató válaszának feldolgozása — **hálózat nélkül**, ezért tesztelhető.
 *
 * Elfogadja a csevegő-végpont alakját (`choices[0].message.content`, ami maga is
 * JSON-szöveg), és a `null`/hibás válaszra üres mezőket ad — így a hívó nem ír
 * félkész fordítást a metába.
 *
 * @return array{title: string, content: string, excerpt: string}
 */
function huhs_translation_parse_response($raw)
{
    $empty = array('title' => '', 'content' => '', 'excerpt' => '');

    $decoded = json_decode((string) $raw, true);
    if (!is_array($decoded)) {
        return $empty;
    }

    $payload = $decoded;
    if (isset($decoded['choices'][0]['message']['content'])) {
        $inner = json_decode((string) $decoded['choices'][0]['message']['content'], true);
        if (!is_array($inner)) {
            return $empty;
        }
        $payload = $inner;
    }

    return array(
        'title'   => trim(wp_strip_all_tags((string) ($payload['title'] ?? ''))),
        'content' => trim((string) ($payload['content'] ?? '')),
        'excerpt' => trim((string) ($payload['excerpt'] ?? '')),
    );
}
