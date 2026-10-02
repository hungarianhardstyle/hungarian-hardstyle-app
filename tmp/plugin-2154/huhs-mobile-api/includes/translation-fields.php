<?php

if (!defined('ABSPATH')) {
    exit;
}

/*
|--------------------------------------------------------------------------
| Meta-alapú szövegek fordítása (plugin 2.14.0)
|--------------------------------------------------------------------------
|
| MIÉRT KELL (mérve, 2026-09-25, a tulajdonos jelzése): a **kérdőív**, a
| **nyereményjáték** és a **GYÍK** szövegei angol módban is magyarul jöttek.
| Ennek az az oka, hogy ezeknek a típusoknak a szövege **nem** a bejegyzés
| címében/törzsében van (amit a 2.12.0 fordít), hanem **post metában**:
|
|   * `_huhs_poll_question`, `_huhs_poll_options` (lista)
|   * `_huhs_prize_question`, `_huhs_prize_answers` (lista),
|     `_huhs_prize_type`, `_huhs_prize_description`
|
| A megoldás ugyanaz a minta, mint a címnél/törzsnél: a fordítás **külön
| metába** kerül (`_huhs_translation_fields_en`, JSON), és a végpontok a kért
| nyelven olvassák. A magyar forrás **változatlan** marad, ezért a magyar ág
| bájtazonos, és egy hiányzó fordításnál automatikusan a magyar szöveg megy ki
| (sosem lesz üres a válasz).
|
| ⚠️ A GYÍK ezt a réteget **nem** használja: ott a kérdés a cím, a válasz a
| törzs, ezért az a 2.12.0-s közös kapun megy (`huhs_translation_meta_values`).
*/

/** A fordítási mezők tárolója (egy JSON objektum bejegyzésenként). */
const HUHS_TRANSLATION_FIELDS_META = '_huhs_translation_fields_en';

/**
 * A tárolt mező-fordítás **séma-verziója** (2026-09-26, 2.14.3).
 *
 * ⚠️ MIÉRT KELL: a 2.14.2-ig a beíró `wp_slash()` nélkül mentett, ezért a
 * WordPress `update_metadata()` unslash-e **szétroncsolta a JSON-escape-eket**
 * (`\r\n` → `rn`, `\u00e9` → `u00e9`) — ez **élesben** meg is jelent (a
 * nyeremény leírásában „October 17!rnrnParticipate…"). A javított író önmagában
 * nem elég: a **meglévő, hibás** fordításokat újra kell generálni. A verziójelölő
 * ezt teszi lehetővé: a `huhs_translation_fields_current()` csak akkor mondja
 * „naprakész"-nek az elemet, ha **ebben a verzióban** készült — különben a pótló
 * kör egyszer újrafordítja (kis halmaz: kérdőív, nyeremény, játékok).
 */
const HUHS_TRANSLATION_FIELDS_VERSION = 2;

/** A tárolt séma-verzió meta-kulcsa. */
const HUHS_TRANSLATION_FIELDS_VERSION_META = '_huhs_translation_fields_version';

/** A mezők forrás-ujjlenyomata (a „megváltozott a magyar szöveg" esethez). */
const HUHS_TRANSLATION_FIELDS_HASH_META = '_huhs_translation_fields_hash';

/*
|--------------------------------------------------------------------------
| KÉZI angol mezők (plugin 2.14.5)
|--------------------------------------------------------------------------
|
| A tulajdonos kérése (2026-09-26): *„ha felteszek egy kérdőívet, a beírt
| válaszok lehetnének angolok, angol módban"* — majd a kérdésre választva
| egyértelművé tette, hogy **saját angol szöveget** akar beírni, nem csak a
| gépi fordítást akarja látni.
|
| A tárolás ugyanaz a minta, mint a GYÍK kategória-neveinél (`_huhs_name_en`):
| a magyar `_huhs_poll_question` **kézi angol párja** `_huhs_poll_question_en`.
| A kiolvasás sorrendje mindenhol:
|
|   1. **kézi angol** (ha ki van töltve),
|   2. gépi fordítás (`_huhs_translation_fields_en`),
|   3. a magyar szöveg (tartalék).
|
| Így a kézi szöveg **felülírja** a gépit, de egy üresen hagyott mezőnél nem
| törik el semmi: marad a gépi fordítás, és végső esetben a magyar.
| A magyar ág (nem-angol kérés) **érintetlen**: ott továbbra is a magyar megy ki.
*/

/** A kézi angol mező utótagja (`_huhs_poll_question` → `_huhs_poll_question_en`). */
const HUHS_TRANSLATION_MANUAL_SUFFIX = '_en';

/** A KÉZI angol szöveg egy mezőhöz (üres string, ha nincs kitöltve). */
function huhs_translation_manual_text($post_id, $meta_key)
{
    $value = get_post_meta($post_id, $meta_key . HUHS_TRANSLATION_MANUAL_SUFFIX, true);
    if (is_array($value) || is_object($value)) {
        return '';
    }

    return trim((string) $value);
}

/** A KÉZI angol lista egy mezőhöz (üres tömb, ha nincs kitöltve). */
function huhs_translation_manual_list($post_id, $meta_key)
{
    $raw = get_post_meta($post_id, $meta_key . HUHS_TRANSLATION_MANUAL_SUFFIX, true);
    if ($raw === '' || $raw === null || $raw === false) {
        return array();
    }

    return huhs_translation_field_list_values($raw);
}

/**
 * A KÉZI angol kvíz-kérdések (`_huhs_game_questions_en`).
 *
 * ⚠️ A szerkezet **ugyanaz**, mint a magyaré (`prompt` + `options`), a `correct`
 * index viszont **számítatlanság**: a helyes választ mindig a magyar szerkezet
 * adja, ezért az angol oldalról **soha nem** vesszük át.
 */
function huhs_translation_manual_questions($post_id)
{
    $raw = get_post_meta(
        $post_id,
        '_huhs_game_questions' . HUHS_TRANSLATION_MANUAL_SUFFIX,
        true
    );
    if (is_string($raw)) {
        // Ugyanaz a „megjavított escape" olvasó, mint a listáknál: a WordPress
        // meta régi, roncsolt alakjait (`rn`, `u00e9`) is kezeljük.
        $decoded = function_exists('huhs_poll_repair_escapes')
            ? huhs_poll_repair_escapes($raw)
            : $raw;
        $decoded = json_decode((string) $decoded, true);
        $raw = is_array($decoded) ? $decoded : array();
    }
    if (!is_array($raw)) {
        return array();
    }

    $out = array();
    foreach (array_values($raw) as $question) {
        if (!is_array($question)) {
            $out[] = array();
            continue;
        }
        $options = array();
        foreach (array_values((array) ($question['options'] ?? array())) as $option) {
            $options[] = is_scalar($option) ? trim((string) $option) : '';
        }
        $out[] = array(
            'prompt' => is_scalar($question['prompt'] ?? '') ? trim((string) $question['prompt']) : '',
            'options' => $options,
        );
    }

    return $out;
}

/**
 * Van-e **bármilyen** angol változat ehhez az elemhez? (kézi VAGY gépi)
 *
 * Ez a `has_en` jelző helyes kérdése a 2.14.5 óta: eddig csak a **gépi**
 * fordítás számított, ezért egy kézzel beírt angol szöveg mellett a válasz
 * `has_en = false` lett volna — az app pedig azt hihette, nincs angol változat.
 */
function huhs_translation_fields_has_english($post_id)
{
    $post = get_post($post_id);
    $post_type = $post instanceof WP_Post ? $post->post_type : '';

    foreach (huhs_translation_field_specs($post_type) as $meta_key => $shape) {
        if ($shape === 'questions') {
            foreach (huhs_translation_manual_questions($post_id) as $question) {
                if ((string) ($question['prompt'] ?? '') !== '') {
                    return true;
                }
                foreach ((array) ($question['options'] ?? array()) as $option) {
                    if ((string) $option !== '') {
                        return true;
                    }
                }
            }
            continue;
        }
        if ($shape === 'list') {
            if (huhs_translation_manual_list($post_id, $meta_key)) {
                return true;
            }
            continue;
        }
        if (huhs_translation_manual_text($post_id, $meta_key) !== '') {
            return true;
        }
    }

    return huhs_translation_fields_current($post_id);
}

/**
 * A mező-fordítás **saját** hiba-jelölői.
 *
 * ⚠️ MIÉRT KÜLÖN (és nem a közös `_huhs_translation_failed`): a közös jelölő a
 * **cím/törzs** fordítását is blokkolná, pedig a kettő független — egy
 * nyereményjátéknál a mezőfordítás hibázhat úgy, hogy a cím/törzs rendben van.
 */
const HUHS_TRANSLATION_FIELDS_FAILED_META = '_huhs_translation_fields_failed';
const HUHS_TRANSLATION_FIELDS_FAILED_AT_META = '_huhs_translation_fields_failed_at';

/**
 * Típusonként azok a meta-kulcsok, amelyek **szöveges tartalmat** hordoznak.
 *
 * A `text` egyetlen szöveg, a `list` pedig JSON-ben tárolt szöveglista
 * (a WordPressben így élnek a válaszlehetőségek).
 *
 * ⚠️ A `huhs_game` `_huhs_game_questions` mezője **szándékosan kimarad**: az egy
 * beágyazott szerkezet (kérdés + válaszok + helyes válasz), amit ez a réteg nem
 * tud biztonságosan leképezni — az külön kör.
 */
function huhs_translation_field_specs($post_type = '')
{
    $specs = array(
        'huhs_poll' => array(
            '_huhs_poll_question' => 'text',
            '_huhs_poll_options' => 'list',
        ),
        'huhs_prize' => array(
            '_huhs_prize_question' => 'text',
            '_huhs_prize_answers' => 'list',
            '_huhs_prize_type' => 'text',
            '_huhs_prize_description' => 'text',
        ),
        'huhs_game' => array(
            '_huhs_game_summary' => 'text',
            // ⚠️ 2.14.2: a kvíz kérdései/válaszai is fordulnak — a beágyazott
            // szerkezetet a `huhs_translation_source_fields()` bontja lapos
            // kulcsokra, a `correct` index soha nem kerül a kérésbe.
            '_huhs_game_questions' => 'questions',
        ),
    );

    if ($post_type === '') {
        return $specs;
    }

    return isset($specs[$post_type]) ? $specs[$post_type] : array();
}

/** Azok a típusok, amelyeknek **meta-szövegük** van (nem a törzsük). */
function huhs_translation_field_post_types()
{
    return array_keys(huhs_translation_field_specs());
}

/**
 * Egy JSON-ben tárolt szöveglista beolvasása (string → lista).
 *
 * A WordPressben a lista `wp_json_encode`-nal kerül a metába, és előfordulhat
 * escaping-elt alak is, ezért mindkettőt kezeljük.
 */
function huhs_translation_field_list_values($stored)
{
    if (is_array($stored)) {
        $values = $stored;
    } else {
        $decoded = function_exists('huhs_poll_repair_escapes')
            ? huhs_poll_repair_escapes($stored)
            : $stored;
        $values = json_decode((string) $decoded, true);
    }

    if (!is_array($values)) {
        return array();
    }

    $out = array();
    foreach ($values as $value) {
        if (!is_scalar($value)) {
            continue;
        }
        $text = trim((string) $value);
        if ($text !== '') {
            $out[] = $text;
        }
    }

    return $out;
}

/**
 * A bejegyzés fordítható **magyar** mezői: `meta_kulcs => szöveg vagy lista`.
 *
 * Üres érték nem kerül bele: ha nincs mit fordítani, a hívó ezt üres tömbbel
 * látja, és nem indít felesleges kérést.
 *
 * ⚠️ A `questions` alak (2.14.2) **lapos kulcsokra bontja** a beágyazott
 * kérdés-szerkezetet (`_huhs_game_questions.0.prompt`,
 * `_huhs_game_questions.0.option.1`, …). Így a szolgáltató **soha nem lát
 * szerkezetet** (csak szövegeket), a `correct` index pedig **hozzá sem kerül** a
 * kéréshez — ezért nem tud elcsúszni a helyes válasz.
 */
function huhs_translation_source_fields($post_id)
{
    $post = get_post($post_id);
    if (!$post instanceof WP_Post) {
        return array();
    }

    $fields = array();
    foreach (huhs_translation_field_specs($post->post_type) as $meta_key => $shape) {
        if ($shape === 'questions') {
            foreach (huhs_translation_game_question_texts($post_id) as $flat_key => $text) {
                if ($text !== '') {
                    $fields[$flat_key] = $text;
                }
            }
            continue;
        }

        $raw = get_post_meta($post_id, $meta_key, true);
        if ($shape === 'list') {
            $values = huhs_translation_field_list_values($raw);
            if ($values) {
                $fields[$meta_key] = $values;
            }
            continue;
        }

        $text = trim((string) $raw);
        if ($text !== '') {
            $fields[$meta_key] = $text;
        }
    }

    return $fields;
}

/**
 * A kvíz kérdéseinek szövegei **lapos kulcsokkal** (2.14.2).
 *
 * A kulcs alakja pontosan ugyanaz, mint amit a kiolvasó használ, ezért a
 * fordítás és a visszaolvasás nem tud szétcsúszni. A `correct` index
 * **szándékosan nem** kerül bele.
 */
function huhs_translation_game_question_texts($post_id)
{
    if (!function_exists('huhs_game_questions_json')) {
        return array();
    }

    $out = array();
    foreach (array_values(huhs_game_questions_json($post_id)) as $index => $question) {
        $prompt = trim((string) ($question['prompt'] ?? ''));
        if ($prompt !== '') {
            $out["_huhs_game_questions.{$index}.prompt"] = $prompt;
        }
        foreach (array_values((array) ($question['options'] ?? array())) as $option_index => $option) {
            $text = trim((string) $option);
            if ($text !== '') {
                $out["_huhs_game_questions.{$index}.option.{$option_index}"] = $text;
            }
        }
    }

    return $out;
}

/**
 * A kvíz kérdései a kért nyelven (2.14.2) — **elemenként** visszaesve a magyarra.
 *
 * A `correct` index és a szerkezet **változatlan**: csak a `prompt` és az
 * `options` szövegei cserélődnek. Nem-angol kérésre a bemenet bájtazonos.
 *
 * ⚠️ 2.14.5: a **kézi** angol kérdések (`_huhs_game_questions_en`) elsőbbséget
 * élveznek a gépi fordítással szemben — a szerkezet (és így a helyes válasz
 * indexe) viszont **mindig** a magyar bejegyzésből jön.
 */
function huhs_translation_game_questions($post_id, $lang = 'hu')
{
    if (!function_exists('huhs_game_questions_json')) {
        return array();
    }

    $questions = array_values(huhs_game_questions_json($post_id));
    if ($lang !== 'en' || !$questions) {
        return $questions;
    }

    $manual = huhs_translation_manual_questions($post_id);

    foreach ($questions as $index => $question) {
        $prompt = (string) ($question['prompt'] ?? '');
        $manual_prompt = (string) ($manual[$index]['prompt'] ?? '');
        $questions[$index]['prompt'] = $manual_prompt !== ''
            ? $manual_prompt
            : huhs_translation_text(
                $post_id,
                $lang,
                "_huhs_game_questions.{$index}.prompt",
                $prompt
            );
        $options = array();
        foreach (array_values((array) ($question['options'] ?? array())) as $option_index => $option) {
            $manual_option = (string) ($manual[$index]['options'][$option_index] ?? '');
            $options[] = $manual_option !== ''
                ? $manual_option
                : huhs_translation_text(
                    $post_id,
                    $lang,
                    "_huhs_game_questions.{$index}.option.{$option_index}",
                    (string) $option
                );
        }
        $questions[$index]['options'] = $options;
    }

    return $questions;
}

/** A magyar mezők ujjlenyomata (a változás-követéshez). */
function huhs_translation_fields_source_hash($post_id)
{
    return md5((string) wp_json_encode(huhs_translation_source_fields($post_id)));
}

/** A beírt fordítások (nyers tömb; üres tömb, ha még nincs). */
function huhs_translation_stored_fields($post_id)
{
    // ⚠️ NINCS kérés-szintű `static` gyorsítótár: a beíró UGYANABBAN a
    // kérésben olvassa vissza (a pótló kör ír, majd rögtön számol), és egy
    // elavult cache azt eredményezné, hogy a frissen lefordított elem
    // **újra várólistásnak** látszik — vagyis minden körben felesleges API-hívás
    // menne rá. A `get_post_meta` a WordPress meta-cache-éből így is olcsó.
    $raw = (string) get_post_meta($post_id, HUHS_TRANSLATION_FIELDS_META, true);
    if ($raw === '') {
        return array();
    }

    $decoded = json_decode($raw, true);

    return is_array($decoded) ? $decoded : array();
}

/**
 * Ez a **pontos** mező-halmaz nemrég hibázott-e? (késleltetéssel)
 *
 * Ugyanaz az elv, mint a cím/törzs ágon: egy átmeneti szolgáltató-hiba nem
 * jelölheti meg az elemet örökre, de a végtelen újrapróbálkozást sem engedjük.
 */
function huhs_translation_fields_failed_recently($post_id, $hash)
{
    if ($hash === ''
        || (string) get_post_meta($post_id, HUHS_TRANSLATION_FIELDS_FAILED_META, true) !== $hash) {
        return false;
    }

    $at = (int) get_post_meta($post_id, HUHS_TRANSLATION_FIELDS_FAILED_AT_META, true);
    if ($at <= 0) {
        return false;
    }

    $delay = (int) apply_filters('huhs_translation_retry_delay', 6 * HOUR_IN_SECONDS);

    return (time() - $at) < max(60, $delay);
}

/** A mező-fordítás hibájának jelölése. */
function huhs_translation_mark_fields_failed($post_id, $hash)
{
    update_post_meta($post_id, HUHS_TRANSLATION_FIELDS_FAILED_META, (string) $hash);
    update_post_meta($post_id, HUHS_TRANSLATION_FIELDS_FAILED_AT_META, time());
}

/**
 * A mező fordítása a kért nyelven — **magyar kulcs, angol érték** elven.
 *
 * Nem-angol kérésre (és hiányzó fordításra) az **eredeti** érték megy vissza,
 * ezért a magyar válasz bájtazonos, és nem lesz üres mező.
 *
 * ⚠️ 2.14.5: a sorrend **kézi angol → gépi fordítás → magyar**. A kézi szöveget
 * a tulajdonos írja be (WP-admin mező, `_huhs_*_en`), és az **elsőbbséget élvez**
 * a gépi fordítással szemben.
 */
function huhs_translation_text($post_id, $lang, $meta_key, $fallback)
{
    if ($lang !== 'en') {
        return $fallback;
    }

    $manual = huhs_translation_manual_text($post_id, $meta_key);
    if ($manual !== '') {
        return $manual;
    }

    $stored = huhs_translation_stored_fields($post_id);
    if (!isset($stored[$meta_key]) || !is_string($stored[$meta_key])) {
        return $fallback;
    }

    $value = trim($stored[$meta_key]);

    return $value === '' ? $fallback : $value;
}

/**
 * Ugyanaz listára: **elemenként** esik vissza (kézi → gépi → magyar).
 *
 * ⚠️ Az **index-hez igazodás** itt kritikus: a kérdőív szavazatai és a
 * nyereményjáték válaszai **sorszám** alapján mennek (a szavazat egy index), ezért
 * az angol lista sosem csúsztathatja el a sorrendet — az `i.` angol szöveg mindig
 * az `i.` magyar helyére kerül.
 */
function huhs_translation_list($post_id, $lang, $meta_key, $fallback_list)
{
    $fallback = array_values(array_filter(array_map('strval', (array) $fallback_list), 'strlen'));
    if ($lang !== 'en') {
        return $fallback;
    }

    $manual = huhs_translation_manual_list($post_id, $meta_key);
    $stored = huhs_translation_stored_fields($post_id);
    $machine = isset($stored[$meta_key]) && is_array($stored[$meta_key])
        ? array_values($stored[$meta_key])
        : array();

    $length = max(count($fallback), count($manual), count($machine));
    if ($length === 0) {
        return $fallback;
    }

    $out = array();
    for ($index = 0; $index < $length; $index++) {
        $value = '';
        foreach (array($manual, $machine) as $source) {
            if (!isset($source[$index]) || !is_scalar($source[$index])) {
                continue;
            }
            $candidate = trim((string) $source[$index]);
            if ($candidate !== '') {
                $value = $candidate;
                break;
            }
        }
        $out[] = $value === '' ? (string) ($fallback[$index] ?? '') : $value;
    }

    return $out ? $out : $fallback;
}

/**
 * Megvan-e már a **teljes** fordítás ehhez a bejegyzéshez?
 *
 * Csak akkor igaz, ha minden nem üres magyar mezőhöz van nem üres fordítás —
 * ugyanaz az elv, mint a cím/törzs kapujánál (részleges fordítás nem elég).
 */
function huhs_translation_fields_complete($post_id)
{
    $source = huhs_translation_source_fields($post_id);
    if (!$source) {
        return false;
    }

    $stored = huhs_translation_stored_fields($post_id);
    foreach ($source as $meta_key => $value) {
        if (!isset($stored[$meta_key])) {
            return false;
        }
        if (is_array($value)) {
            $translated = huhs_translation_list($post_id, 'en', $meta_key, $value);
            if (count($translated) !== count($value)) {
                return false;
            }
            continue;
        }
        if (trim((string) $stored[$meta_key]) === '') {
            return false;
        }
    }

    return true;
}

/**
 * Naprakész-e a mező-fordítás? (megvan MINDEN mező, a forrás ugyanaz, ÉS a
 * tárolt séma-verzió a jelenlegi)
 *
 * Ez a „nincs mit tenni" állapot: a mentés-ág ezzel spórolja meg a felesleges
 * API-hívást, a pótló kör pedig ezzel dönti el, hogy várólistás-e az elem.
 *
 * ⚠️ A verzió-ellenőrzés azért kell, hogy a **régi, hibás escape-ekkel** mentett
 * fordítások (2.14.2 és előtte: `rn` / `u00e9`) egyszer **maguktól** újra
 * elkészüljenek — lásd a `HUHS_TRANSLATION_FIELDS_VERSION` fejlécét.
 */
function huhs_translation_fields_current($post_id)
{
    if (!huhs_translation_fields_complete($post_id)) {
        return false;
    }

    if ((int) get_post_meta($post_id, HUHS_TRANSLATION_FIELDS_VERSION_META, true)
        !== HUHS_TRANSLATION_FIELDS_VERSION) {
        return false;
    }

    return (string) get_post_meta($post_id, HUHS_TRANSLATION_FIELDS_HASH_META, true)
        === huhs_translation_fields_source_hash($post_id);
}

/* ---- A szolgáltató hívása (meta-mezők) ---------------------------------- */
/** A mező-fordítás rendszer-üzenete: ugyanaz a kulcs-halmaz, szigorú JSON. */
function huhs_translation_fields_system_prompt()
{
    return 'You translate Hungarian website content of a Hungarian Hardstyle music app into English. '
        . 'The user message is a JSON object with a "fields" key. Answer with a single JSON object that has '
        . 'exactly one key, "fields", whose value is an object with the SAME keys as the input object. '
        . 'Translate every value into English. A value that is a list of strings must stay a list of the same '
        . 'length, with each element translated. Keep brand names, artist names and release titles unchanged '
        . '(Hungarian Hardstyle, HUHS, festival and label names). Never return an empty string: if a text is '
        . 'already English, repeat it unchanged.';
}

/** A mező-fordítás kérése (hálózat). Hiba esetén `null`. */
function huhs_translation_request_fields($fields)
{
    $provider = huhs_translation_provider();
    $key = huhs_translation_api_key();
    if ($key === '' || empty($provider['url']) || !$fields) {
        return null;
    }

    $body = array(
        'model'    => (string) ($provider['model'] ?? 'deepseek-chat'),
        'messages' => array(
            array('role' => 'system', 'content' => huhs_translation_fields_system_prompt()),
            array('role' => 'user', 'content' => wp_json_encode(array('fields' => $fields))),
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

    return huhs_translation_parse_fields_response((string) wp_remote_retrieve_body($response), $fields);
}

/**
 * A válasz feldolgozása **hálózat nélkül** — ezért tesztelhető.
 *
 * A kimenet csak azokat a kulcsokat tartalmazza, amelyeket kértünk, és csak
 * akkor, ha nem üres (`text`) vagy a lista hossza egyezik (`list`). Így egy
 * félreértett válasz nem írhat félkész fordítást.
 */
function huhs_translation_parse_fields_response($raw, $requested)
{
    $empty = array();
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

    $fields = isset($payload['fields']) && is_array($payload['fields']) ? $payload['fields'] : $payload;

    $out = array();
    foreach ((array) $requested as $meta_key => $source) {
        if (!array_key_exists($meta_key, $fields)) {
            continue;
        }
        $value = $fields[$meta_key];

        if (is_array($source)) {
            if (!is_array($value)) {
                continue;
            }
            $translated = array();
            foreach (array_values($value) as $item) {
                if (!is_scalar($item)) {
                    continue;
                }
                $text = trim((string) $item);
                if ($text !== '') {
                    $translated[] = $text;
                }
            }
            if (count($translated) === count($source)) {
                $out[$meta_key] = $translated;
            }
            continue;
        }

        if (!is_scalar($value)) {
            continue;
        }
        $text = trim((string) $value);
        if ($text !== '') {
            $out[$meta_key] = $text;
        }
    }

    return $out;
}

/**
 * A meta-szövegek fordítása egy bejegyzésre.
 *
 * @return string 'disabled' | 'empty' | 'uptodate' | 'failed' | 'partial' | 'translated'
 */
function huhs_run_field_translation($post_id, $force = false)
{
    if (!huhs_translation_enabled()) {
        return 'disabled';
    }

    $post = get_post($post_id);
    if (!$post instanceof WP_Post || !huhs_translation_field_specs($post->post_type)) {
        return 'empty';
    }

    $source = huhs_translation_source_fields($post_id);
    if (!$source) {
        return 'empty';
    }

    $hash = huhs_translation_fields_source_hash($post_id);
    // ⚠️ `$force` (2.14.4): a tárolt fordítás nem dönt — a sérült (régi
    // escape-ekkel mentett) szöveget akarjuk lecserélni.
    if (!$force && huhs_translation_fields_current($post_id)) {
        return 'uptodate';
    }

    // Ugyanaz a hiba-késleltetés, mint a cím/törzs ágon: ne pörögjön végtelenül.
    if (huhs_translation_fields_failed_recently($post_id, $hash)) {
        return 'failed';
    }

    $translated = huhs_translation_request_fields($source);
    if ($translated === null || !$translated) {
        huhs_translation_mark_fields_failed($post_id, $hash);
        return 'failed';
    }

    // Meglévő fordítás megőrzése: csak a hiányzó/új kulcsokat írjuk felül.
    $stored = huhs_translation_stored_fields($post_id);
    foreach ($translated as $meta_key => $value) {
        $stored[$meta_key] = $value;
    }
    // ⚠️ `wp_slash()` KELL (mért éles hiba, 2026-09-26): a WordPress
    // `update_metadata()` **`wp_unslash()`-ol**, ezért a `wp_json_encode()` írta
    // escape-ekből (`\r\n`, `\uXXXX`, `\"`) elveszne a backslash — a tárolt
    // szöveg `rnrn` / `u00e9` szemétté válna (a nyeremény leírásában ez **élesben**
    // meg is jelent: „October 17!rnrnParticipate…"). Ugyanez a minta van a plugin
    // más helyein is (`poll.php`, `prize.php`).
    update_post_meta($post_id, HUHS_TRANSLATION_FIELDS_META, wp_slash(wp_json_encode($stored)));
    update_post_meta($post_id, HUHS_TRANSLATION_FIELDS_HASH_META, wp_slash($hash));
    update_post_meta($post_id, HUHS_TRANSLATION_FIELDS_VERSION_META, HUHS_TRANSLATION_FIELDS_VERSION);
    delete_post_meta($post_id, HUHS_TRANSLATION_FIELDS_FAILED_META);
    delete_post_meta($post_id, HUHS_TRANSLATION_FIELDS_FAILED_AT_META);

    return huhs_translation_fields_complete($post_id) ? 'translated' : 'partial';
}
