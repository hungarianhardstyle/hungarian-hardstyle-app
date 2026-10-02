<?php

if (!defined('ABSPATH')) {
    exit;
}

/*
|--------------------------------------------------------------------------
| Angol cikk-mezők (rejtett post meta) — plugin 2.11.0
|--------------------------------------------------------------------------
|
| Az app angol nyelvéhez a cikkek angol szövegét egy fordítási folyamat
| állítja elő, és három rejtett (vezető aláhúzásos) post metaba írja:
|
|   _huhs_title_en    – a cikk címe angolul
|   _huhs_excerpt_en  – a cikk kivonata angolul
|   _huhs_content_en  – a cikk törzse angolul (HTML)
|
| A WP REST API csak akkor fogadja el az írást a védett kulcsokra, ha a meta
| regisztrálva van `show_in_rest => true`-val ÉS van `auth_callback`. A
| folyamat egy szerkesztői/admin felhasználó alkalmazás-jelszavával ír, ezért
| a kapu az `edit_posts` képesség.
|
| ⚠️ A WEBNYILVÁNOS OLDAL SZÁNDÉKOSAN NEM OLVASSA EZEKET A MEZŐKET. A téma,
| a sablonok és a shortcode-ok változatlanok: az angol szöveg egyelőre
| kizárólag az app API-ján (`lang=en`) jön ki, a cikkek magyar permalinkje
| pedig ugyanaz marad (nincs külön angol bejegyzés).
|
| Sanitize döntés (és miért):
|   * `_huhs_title_en`   → `sanitize_text_field`
|     A cím egyetlen sor, nem tartalmazhat HTML-t; a `sanitize_text_field`
|     kiszűri a tageket és a sortöréseket, és UTF-8-ban hagyja az ékezetet.
|   * `_huhs_content_en` → `wp_kses_post`
|     A törzs HTML (bekezdések, linkek, listák). A `sanitize_text_field`
|     használata MINDEN tageket kidobna, és a cikk egyetlen futó szöveggé
|     esne szét — ezért itt kötelező a `wp_kses_post`.
|   * `_huhs_excerpt_en` → `wp_kses_post`
|     A kivonat a cikkből örökölhet egyszerű formázást (`<strong>`, `<em>`).
|     A `sanitize_textarea_field` megőrizné ugyan a sortöréseket, de a
|     tageket kidobná; mivel a kivonatot az app a törzzsel azonos módon
|     jeleníti meg, a testvérével azonos szűrőt (`wp_kses_post`) kap, hogy a
|     két mező viselkedése ne térjen el. A HTML-t itt is meg kell tartani.
*/

add_action('init', 'huhs_register_post_translation_meta');

/**
 * A `custom-fields` támogatás biztosítása a fordítási típusoknak.
 *
 * ⚠️ MIÉRT KELL (mérve, 2026-09-25): a WordPress a `meta` mezőt **csak akkor**
 * teszi bele a REST-válaszba — és csak akkor fogadja el írásra —, ha a
 * post-típus támogatja a `custom-fields`-et. A `huhs_event`, `huhs_artist`,
 * `huhs_organizer` és `huhs_release` típusnál ez nem volt bekapcsolva, ezért a
 * REST-en küldött angol meta **csendben elveszett**: a `POST` **200-at adott**,
 * a visszaolvasás viszont **üres** lett (a `post` típusnál ugyanaz a hívás
 * működött — ez volt a kontroll). A szerveroldali útvonalakat (a WP-cron
 * `update_post_meta`-ja, a végpontok `get_post_meta`-ja) ez nem érinti, ezért a
 * hiba csak a **kívülről írt** fordításoknál jelentkezett.
 *
 * A `init` 99-es prioritása szándékos: a post-típusok rendszerint a 10-es
 * prioritáson regisztrálódnak, és a `custom-fields` jelzőt csak a létező
 * típusra lehet bekapcsolni (ezt a `post_type_exists` őrzi).
 */
function huhs_enable_translation_meta_custom_fields()
{
    foreach (huhs_translation_post_types() as $post_type) {
        if (post_type_exists($post_type)) {
            add_post_type_support($post_type, 'custom-fields');
        }
    }
}

add_action('init', 'huhs_enable_translation_meta_custom_fields', 99);

/**
 * A fordítást támogató post típusok — **egy helyen** (plugin 2.12.0).
 *
 * A 2.11.0 csak a cikkeket (`post`) tudta; a 2.12.0 ugyanezt a három meta mezőt
 * a **huhs_event**, **huhs_artist**, **huhs_organizer** és **huhs_release**
 * típusra is regisztrálja. A meta kulcsa post-onként él, ezért nincs ütközés:
 * ugyanaz a `_huhs_title_en` egy eseménynél az esemény angol címét jelenti.
 *
 * ⚠️ A lista **egy** forrás: a regisztráció és a fordítási folyamat is ezt
 * használja, ezért nem tud széthúzni (ha új típus kerül be, mindkettő látja).
 */
function huhs_translation_post_types()
{
    return array('post', 'huhs_event', 'huhs_artist', 'huhs_organizer', 'huhs_release', 'huhs_faq');
}

/**
 * **Minden** fordítási típus: a cím/törzs típusok **és** a meta-szöveges típusok
 * (kérdőív, nyereményjáték, játék) — plugin 2.14.0.
 *
 * A pótló kör és a mentés-ág ezt használja, ezért egy új típus nem tud
 * „kiesni": elég a `huhs_translation_field_specs()`-be felvenni.
 */
function huhs_translation_all_post_types()
{
    $types = huhs_translation_post_types();
    if (function_exists('huhs_translation_field_post_types')) {
        $types = array_merge($types, huhs_translation_field_post_types());
    }

    return array_values(array_unique($types));
}

function huhs_register_post_translation_meta()
{
    $auth_callback = 'huhs_translation_meta_auth_callback';

    // Mező → sanitize. A döntés indoklása a fájl fejlécében van.
    $fields = array(
        '_huhs_title_en'   => 'sanitize_text_field',
        '_huhs_excerpt_en' => 'wp_kses_post',
        '_huhs_content_en' => 'wp_kses_post',
    );

    foreach (huhs_translation_post_types() as $post_type) {
        foreach ($fields as $meta_key => $sanitize_callback) {
            register_post_meta($post_type, $meta_key, array(
                'type'              => 'string',
                'single'            => true,
                'show_in_rest'      => true,
                'sanitize_callback' => $sanitize_callback,
                'auth_callback'     => $auth_callback,
            ));
        }
    }
}

/**
 * A fordítási meta a kért nyelven, a `has_en` kapuval — a 2.12.0 közös szabálya.
 *
 * UGYANAZ A KAPU, MINT A CIKKEKNÉL (`huhs_post_language_payload`): angolra csak
 * akkor váltunk, ha a **cím ÉS a törzs** is megvan (`trim` után nem üres),
 * különben a magyar érték marad és `has_en = false`. Így egy részleges fordítás
 * nem ad kevert nyelvű választ, és a válasz soha nem lesz üres.
 *
 * A formázás **nem** itt történik: a hívó adja a magyar értékeket pontosan úgy,
 * ahogy eddig (pl. `wpautop($post->post_content)`), a visszakapott értéket pedig
 * ugyanúgy formázza — így a magyar ág bájtra azonos marad a 2.11.0-éval.
 *
 * @param int    $post_id     A bejegyzés azonosítója.
 * @param string $lang        `hu` vagy `en` (`huhs_request_lang`).
 * @param string $title_hu    A magyar cím (már formázva).
 * @param string $content_hu  A magyar törzs/leírás (már formázva).
 * @param string $excerpt_hu  A magyar kivonat (ha van ilyen mező).
 * @return array{has_en: bool, title: string, content: string, excerpt: string}
 */
function huhs_translation_meta_values($post_id, $lang, $title_hu, $content_hu, $excerpt_hu = '')
{
    $values = array(
        'has_en'  => false,
        'title'   => (string) $title_hu,
        'content' => (string) $content_hu,
        'excerpt' => (string) $excerpt_hu,
    );

    // Nem angol kérés: a magyar payload megy vissza, meta-olvasás nélkül.
    if ($lang !== 'en') {
        return $values;
    }

    $title_en = trim((string) get_post_meta($post_id, '_huhs_title_en', true));
    $content_en = trim((string) get_post_meta($post_id, '_huhs_content_en', true));

    // FALLBACK-KAPU: csak akkor váltunk angolra, ha a fordítás érdemi része
    // (cím ÉS törzs) megvan. Különben marad a magyar payload.
    if ($title_en === '' || $content_en === '') {
        return $values;
    }

    $values['has_en'] = true;
    $values['title'] = $title_en;
    $values['content'] = $content_en;
    $values['excerpt'] = trim((string) get_post_meta($post_id, '_huhs_excerpt_en', true));

    return $values;
}

/**
 * A védett (aláhúzással kezdődő) fordítási meta írásának engedélyezése.
 *
 * A WordPress a vezető aláhúzásos kulcsokat „protected" metának tekinti, és
 * alapból elutasítja a REST-en keresztüli írást. A fordítási folyamat egy
 * szerkesztői/admin felhasználó alkalmazás-jelszavával dolgozik, ezért az
 * `edit_posts` képesség a helyes kapu — ennél szűkebb (pl. `manage_options`)
 * nem kell, tágabb (`read`) viszont beengedné a sima előfizetőket is.
 *
 * Az OLVASÁST ez a callback nem érinti: a nyilvános `huhs/v1` végpontok a
 * saját `lang` paraméterük alapján döntenek (lásd includes/posts.php).
 */
function huhs_translation_meta_auth_callback($allowed, $meta_key, $post_id, $user_id)
{
    return user_can($user_id, 'edit_posts');
}
