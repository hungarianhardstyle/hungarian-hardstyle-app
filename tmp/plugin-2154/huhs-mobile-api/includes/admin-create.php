<?php
/**
 * Natív admin: ÚJ kérdőív / nyereményjáték / kvíz létrehozása az appból.
 *
 * MIÉRT: a tulajdonos kérése — *„most már tudok hozzáadni kvizt, nyereményjátékot
 * és kérdőívet natív adminból?”* A válasz az volt, hogy **nem**: a
 * `huhs_admin_resource_fields()` csak az esemény/DJ/szervező/release típusokhoz
 * adott mezőket, a `save_resource` pedig kizárólag MEGLÉVŐ bejegyzést mentett.
 *
 * Ez a fájl ezt a hiányt tölti be, DE szigorúan a meglévő szerkezettel:
 *  * a mezők kulcsa **mindig a valódi meta-kulcs** (pl. `_huhs_poll_options`),
 *    így a mentés nem tud elcsúszni a WordPress-oldali űrlaptól;
 *  * a validáció **tiszta függvényekben** van (nincs WP-hívás), ezért PHP-harnessszel
 *    bizonyítható: `tools/verify-admin-create.php`;
 *  * a **haladó** beállítások (jutalomsávok, idővonal-elemek, hang-borítók,
 *    „találd ki a zenét” típusok) szándékosan a WordPress adminban maradnak —
 *    a natív admin a **kvíz** típusokat hozza létre.
 *
 * A kvíz-kérdések szerkezete megegyezik a WordPress-oldalival:
 *   [ { prompt: '…', options: ['…','…'], correct: 0 }, … ]
 */

if (!defined('ABSPATH')) {
    exit;
}

/** A natív adminból LÉTREHOZHATÓ típusok. */
define('HUHS_ADMIN_CREATABLE_TYPES', array(
    'huhs_event',
    'huhs_artist',
    'huhs_organizer',
    'huhs_poll',
    'huhs_prize',
    'huhs_game',
));

/** A natív adminból létrehozható kvíz-típusok (a többi játéktípus a WordPressben marad). */
define('HUHS_ADMIN_QUIZ_TYPES', array(
    'hardstyle_quiz',
    'festival_quiz',
    'hungarian_hardstyle_quiz',
));

/** Igaz, ha ebből a típusból az app LÉTRE is hozhat elemet. */
function huhs_admin_is_creatable_type($post_type)
{
    return in_array(sanitize_key((string) $post_type), HUHS_ADMIN_CREATABLE_TYPES, true);
}

/**
 * A három „interakciós” típus mezői.
 *
 * A `type` értékek közül a `text_list`, a `questions`, a `select` és a `textarea`
 * ÚJ — ezeket az app is ismeri (`lib/screens/community/admin_resource_editor_screen.dart`).
 *
 * ⚠️ **2.14.5 — KÉZI ANGOL MEZŐK:** a tulajdonos kérése szerint (*„ha felteszek
 * egy kérdőívet, a beírt válaszok lehetnének angolok, angol módban"*) minden
 * szöveges mezőnek van **opcionális angol párja** (`_huhs_*_en`). Ha ki van
 * töltve, az jelenik meg angol módban; ha üres, marad a gépi fordítás, és végső
 * esetben a magyar szöveg (lásd `includes/translation-fields.php`).
 *
 * ⚠️ A kvíz `questions` mezőjének **szándékosan nincs** angol párja a natív
 * adminban: a szerkesztő egyetlen kérdéslistát tart (`_questions`), ezért egy
 * második ilyen mező **felülírná a magyar kérdéseket** — a kérdések angol
 * változata továbbra is a gépi fordítással készül (a kiolvasó a kézi
 * `_huhs_game_questions_en` metát ismeri, ha valaki a WordPressben tölti ki).
 */
function huhs_admin_interaction_fields($post_type)
{
    if ($post_type === 'huhs_poll') {
        return array(
            array('key' => '_huhs_poll_question', 'label' => 'Kérdés', 'type' => 'text'),
            array('key' => '_huhs_poll_question_en', 'label' => 'Kérdés angolul (opcionális)', 'type' => 'text'),
            array('key' => '_huhs_poll_options', 'label' => 'Válaszlehetőségek (2–6)', 'type' => 'text_list', 'min' => 2, 'max' => 6),
            array('key' => '_huhs_poll_options_en', 'label' => 'Válaszlehetőségek angolul (opcionális, ugyanabban a sorrendben)', 'type' => 'text_list', 'min' => 0, 'max' => 6),
            array('key' => '_huhs_poll_start', 'label' => 'Kezdés (pl. 2026-09-20T18:00)', 'type' => 'text'),
            array('key' => '_huhs_poll_end', 'label' => 'Zárás (pl. 2026-09-27T20:00)', 'type' => 'text'),
        );
    }
    if ($post_type === 'huhs_prize') {
        return array(
            array('key' => '_huhs_prize_question', 'label' => 'Kvízkérdés', 'type' => 'text'),
            array('key' => '_huhs_prize_question_en', 'label' => 'Kvízkérdés angolul (opcionális)', 'type' => 'text'),
            array('key' => '_huhs_prize_answers', 'label' => 'Válaszlehetőségek (3–5)', 'type' => 'text_list', 'min' => 3, 'max' => 5),
            array('key' => '_huhs_prize_answers_en', 'label' => 'Válaszlehetőségek angolul (opcionális, ugyanabban a sorrendben)', 'type' => 'text_list', 'min' => 0, 'max' => 5),
            array('key' => '_huhs_prize_correct', 'label' => 'A helyes válasz sorszáma (1-től)', 'type' => 'int'),
            array('key' => '_huhs_prize_start', 'label' => 'Kezdés (pl. 2026-09-20T18:00)', 'type' => 'text'),
            array('key' => '_huhs_prize_end', 'label' => 'Zárás (pl. 2026-09-27T20:00)', 'type' => 'text'),
            array('key' => '_huhs_prize_type', 'label' => 'Nyeremény megnevezése', 'type' => 'text'),
            array('key' => '_huhs_prize_type_en', 'label' => 'Nyeremény megnevezése angolul (opcionális)', 'type' => 'text'),
            array('key' => '_huhs_prize_description', 'label' => 'Nyeremény leírása', 'type' => 'textarea'),
            array('key' => '_huhs_prize_description_en', 'label' => 'Nyeremény leírása angolul (opcionális)', 'type' => 'textarea'),
            array('key' => '_huhs_prize_display_days', 'label' => 'A nyertes ennyi napig látszik (0 = örökre)', 'type' => 'int'),
        );
    }
    if ($post_type === 'huhs_game') {
        return array(
            array(
                'key' => '_huhs_game_type',
                'label' => 'Játék típusa',
                'type' => 'select',
                'options' => array_map(
                    function ($type) {
                        return array('value' => $type, 'label' => HUHS_GAME_TYPES[$type] ?? $type);
                    },
                    HUHS_ADMIN_QUIZ_TYPES
                ),
            ),
            array('key' => '_huhs_game_summary', 'label' => 'Rövid leírás', 'type' => 'textarea'),
            array('key' => '_huhs_game_summary_en', 'label' => 'Rövid leírás angolul (opcionális)', 'type' => 'textarea'),
            array('key' => '_huhs_game_artwork', 'label' => 'Borítókép (média ID vagy URL)', 'type' => 'text'),
            array('key' => '_huhs_game_start', 'label' => 'Kezdés (pl. 2026-09-20T18:00)', 'type' => 'text'),
            array('key' => '_huhs_game_end', 'label' => 'Zárás (pl. 2026-09-27T20:00)', 'type' => 'text'),
            array('key' => '_huhs_game_results_until', 'label' => 'Eredmények eddig látszanak', 'type' => 'text'),
            array('key' => '_huhs_game_reward_points', 'label' => 'Jutalom pontban (kvíznél a sávok helyett fix)', 'type' => 'int'),
            array('key' => '_huhs_game_questions', 'label' => 'Kérdések', 'type' => 'questions'),
        );
    }
    return array();
}

/** Lista-jellegű mező értékei: JSON-tömb, valódi tömb vagy soronkénti szöveg is jöhet. */
function huhs_admin_text_list_values($raw)
{
    if (is_string($raw)) {
        $decoded = json_decode($raw, true);
        $raw = is_array($decoded) ? $decoded : preg_split('/\r?\n/', $raw);
    }
    if (!is_array($raw)) {
        return array();
    }
    $values = array();
    foreach ($raw as $item) {
        if (is_array($item) || is_object($item)) {
            continue;
        }
        $value = trim(sanitize_text_field((string) $item));
        if ($value !== '') {
            $values[] = $value;
        }
    }
    return array_values($values);
}

/**
 * Kvíz-kérdések. Minden sort MEGTARTUNK (akkor is, ha hibás), hogy a validáció
 * meg tudja nevezni a hibás sor számát — a csendes eldobás pont az a hibaosztály,
 * amit kerülünk.
 */
function huhs_admin_question_values($raw)
{
    if (is_string($raw)) {
        $raw = json_decode($raw, true);
    }
    if (!is_array($raw)) {
        return array();
    }
    $questions = array();
    foreach ($raw as $item) {
        if (!is_array($item)) {
            continue;
        }
        $questions[] = array(
            'prompt' => trim(sanitize_text_field((string) ($item['prompt'] ?? ''))),
            'options' => huhs_admin_text_list_values($item['options'] ?? array()),
            'correct' => isset($item['correct']) ? (int) $item['correct'] : -1,
        );
    }
    return $questions;
}

/** A létrehozás/mentés előtti ellenőrzés. Üres string = rendben. */
function huhs_admin_validate_resource_values($post_type, $values)
{
    if ($post_type === 'huhs_poll') {
        if (trim((string) ($values['_huhs_poll_question'] ?? '')) === '') {
            return 'A kérdőív kérdése kötelező.';
        }
        $options = huhs_admin_text_list_values($values['_huhs_poll_options'] ?? array());
        if (count($options) < 2) {
            return 'A kérdőívhez legalább 2 válaszlehetőség kell.';
        }
        if (count($options) > 6) {
            return 'A kérdőívhez legfeljebb 6 válaszlehetőség adható.';
        }
        // ⚠️ 2.14.5: a kézi angol válaszok **ugyanabban a sorrendben** mennek ki,
        // ezért nem lehet belőlük több, mint magyar — különben a szavazat
        // indexéhez nem tartozna magyar pár.
        $en_options = huhs_admin_text_list_values($values['_huhs_poll_options_en'] ?? array());
        if (count($en_options) > count($options)) {
            return 'Az angol válaszlehetőségek nem lehetnek többen, mint a magyarok.';
        }
    }
    if ($post_type === 'huhs_prize') {
        if (trim((string) ($values['_huhs_prize_question'] ?? '')) === '') {
            return 'A nyereményjáték kvízkérdése kötelező.';
        }
        $answers = huhs_admin_text_list_values($values['_huhs_prize_answers'] ?? array());
        if (count($answers) < 3) {
            return 'A nyereményjátékhoz legalább 3 válaszlehetőség kell.';
        }
        if (count($answers) > 5) {
            return 'A nyereményjátékhoz legfeljebb 5 válaszlehetőség adható.';
        }
        $choice = (int) ($values['_huhs_prize_correct'] ?? 0);
        if ($choice < 1 || $choice > count($answers)) {
            return 'Jelöld meg a helyes választ (1–' . count($answers) . ').';
        }
        // ⚠️ 2.14.5: ugyanaz a sorrend-korlát, mint a kérdőívnél.
        $en_answers = huhs_admin_text_list_values($values['_huhs_prize_answers_en'] ?? array());
        if (count($en_answers) > count($answers)) {
            return 'Az angol válaszlehetőségek nem lehetnek többen, mint a magyarok.';
        }
    }
    if ($post_type === 'huhs_game') {
        $type = sanitize_key((string) ($values['_huhs_game_type'] ?? ''));
        if (!in_array($type, HUHS_ADMIN_QUIZ_TYPES, true)) {
            return 'Válaszd ki a kvíz típusát.';
        }
        $questions = huhs_admin_question_values($values['_huhs_game_questions'] ?? array());
        if (count($questions) < 1) {
            return 'A kvízhez legalább 1 kérdés kell.';
        }
        foreach ($questions as $index => $question) {
            $row = $index + 1;
            if (trim((string) $question['prompt']) === '') {
                return 'A(z) ' . $row . '. kérdés szövege üres.';
            }
            $count = count($question['options']);
            if ($count < 2 || $count > 6) {
                return 'A(z) ' . $row . '. kérdéshez 2–6 válaszlehetőség kell.';
            }
            if ($question['correct'] < 0 || $question['correct'] >= $count) {
                return 'A(z) ' . $row . '. kérdésnél jelöld meg a helyes választ.';
            }
        }
    }
    return '';
}

/** A lista/kérdés mezők tárolt alakja (a WordPress-oldali űrlappal azonos JSON). */
function huhs_admin_encode_meta_value($field, $value)
{
    $type = (string) ($field['type'] ?? 'text');
    if ($type === 'text_list') {
        return wp_slash(wp_json_encode(huhs_admin_text_list_values($value), JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES));
    }
    if ($type === 'questions') {
        return wp_slash(wp_json_encode(huhs_admin_question_values($value), JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES));
    }
    if ($type === 'bool') {
        return filter_var($value, FILTER_VALIDATE_BOOLEAN) ? 1 : 0;
    }
    if ($type === 'int') {
        return absint($value);
    }
    if ($type === 'url') {
        return esc_url_raw((string) $value);
    }
    if ($type === 'email') {
        return sanitize_email((string) $value);
    }
    if ($type === 'ids') {
        return wp_json_encode(array_values(array_filter(array_map('absint', preg_split('/[\s,]+/', (string) $value)))));
    }
    if ($type === 'textarea') {
        return sanitize_textarea_field((string) $value);
    }
    if ($type === 'select') {
        return sanitize_key((string) $value);
    }
    return sanitize_text_field((string) $value);
}

/**
 * A létrehozás utáni, típus-specifikus helyreigazítás.
 *
 * MIÉRT kell: a `_huhs_prize_correct` a WordPressben **0-alapú index**, a natív
 * űrlapon viszont 1-től számozunk (ahogy az ember számol) — a kettőt itt
 * fordítjuk le Egy Helyen, nem a kliensen.
 */
function huhs_admin_normalize_resource_meta($post_id, $post_type, $values)
{
    if ($post_type === 'huhs_prize') {
        $answers = huhs_admin_text_list_values($values['_huhs_prize_answers'] ?? array());
        $choice = (int) ($values['_huhs_prize_correct'] ?? 0);
        $index = max(0, min(max(0, count($answers) - 1), $choice - 1));
        update_post_meta($post_id, '_huhs_prize_correct', $index);
    }
    if ($post_type === 'huhs_game') {
        // A WordPress-oldali mentő is törli a korábbi validációs hibát.
        delete_post_meta($post_id, '_huhs_game_validation_error');
    }
}

/** A bejegyzés címe a típusnak megfelelő mezőből (a listában ez látszik). */
function huhs_admin_resource_title($post_type, $values, $fallback = '')
{
    foreach (array('_huhs_poll_question', '_huhs_prize_question', '_huhs_game_summary') as $key) {
        $value = trim((string) ($values[$key] ?? ''));
        if ($value !== '') {
            return $value;
        }
    }
    $title = trim((string) $fallback);
    return $title !== '' ? $title : 'Új elem';
}

/**
 * A létrehozott bejegyzés állapota.
 *
 * MIÉRT `publish` az alap: a tulajdonos azért hoz létre kvízt/nyereményjátékot,
 * hogy az **megjelenjen** — egy csendes „piszkozat" pont az a fajta néma hiba,
 * amiből aztán „nem működik az app" lesz. Aki később akarja, az appban
 * „Piszkozat"-ot választ.
 */
function huhs_admin_created_status($raw)
{
    $status = sanitize_key((string) $raw);
    return in_array($status, array('publish', 'draft', 'private'), true) ? $status : 'publish';
}
