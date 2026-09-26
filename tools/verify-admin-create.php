<?php
/**
 * A natív admin LÉTREHOZÓ logikájának bizonyítása — valódi PHP, WordPress nélkül.
 *
 * MIÉRT: a tulajdonos kérése, hogy az appból lehessen új kérdőívet,
 * nyereményjátékot és kvízt létrehozni. A `includes/admin-create.php` ezért
 * **tiszta függvényeket** tartalmaz (validáció, normalizálás, meta-kódolás),
 * amiket itt stubolt WordPress-környezetben futtatunk. Ha valaki a validációt
 * „kiiktatja", ez a harness **elhasal** — vagyis a hiba nem tud visszakúszni.
 *
 * Futtatás (a repository gyökeréből):
 *   & 'C:\Users\deero\Documents\Hun HS Newsroom\tools\php\php.exe' tools/verify-admin-create.php
 *   & '…\php.exe' tools/verify-admin-create.php <plugin-könyvtár>   # kézi megadás
 *
 * ⚠️ **MÉRT SAJÁT HIBA (javítva, 2026-09-26):** a harness a plugin forrását
 * **egy beégetett, elavult útvonalról** töltötte be (`.tmp-api-24115`, azaz a
 * **2.5.9**-es példány), ezért a 41 ellenőrzés a **régi** fájlt mérte — a friss
 * változtatásokról semmit nem mondott. Mostantól a munkapéldányt a főfájl
 * `Version:` sora alapján, **verzió szerint** választja ki (a legfrissebbet), és
 * a mért útvonalat + verziót **ki is írja** — így a kimenet önmagát igazolja.
 *
 * Kilépési kód: 0 = minden rendben, 1 = eltérés.
 */

define('ABSPATH', __DIR__);

// --- WordPress-stubok (csak a tiszta logikához kellenek) --------------------
function sanitize_text_field($value) { return trim(preg_replace('/\s+/u', ' ', (string) $value)); }
function sanitize_textarea_field($value) { return trim((string) $value); }
function sanitize_key($value) { return strtolower(preg_replace('/[^a-z0-9_\-]/i', '', (string) $value)); }
function sanitize_email($value) { return trim((string) $value); }
function esc_url_raw($value) { return trim((string) $value); }
function absint($value) { return abs((int) $value); }
function wp_json_encode($value, $flags = 0) { return json_encode($value, $flags); }
function wp_slash($value) { return $value; }

$GLOBALS['huhs_test_meta'] = array();
function update_post_meta($post_id, $key, $value) { $GLOBALS['huhs_test_meta'][$post_id][$key] = $value; }
function delete_post_meta($post_id, $key) { unset($GLOBALS['huhs_test_meta'][$post_id][$key]); }

define('HUHS_GAME_TYPES', array(
    'hardstyle_quiz' => 'Hardstyle kvíz',
    'festival_quiz' => 'Fesztivál kvíz',
    'hungarian_hardstyle_quiz' => 'Magyar Hardstyle kvíz',
    'timeline' => 'Hardstyle idővonal',
));

require_once huhs_test_plugin_source() . '/includes/admin-create.php';

/**
 * A mérendő plugin-munkapéldány (a legfrissebb verziójú `.tmp-api-*` példány).
 *
 * ⚠️ MIÉRT ÍGY: a korábbi beégetett útvonal **elavult** volt (2.5.9), ezért a
 * mérés a régi kódot nézte — pont az a hibaosztály, amit kerülünk („a mérés
 * tárgya nem az, amit hiszünk"). Az explicit paraméter felülírja.
 */
function huhs_test_plugin_source()
{
    global $argv;

    $explicit = trim((string) ($argv[1] ?? ''));
    if ($explicit !== '') {
        if (!is_file($explicit . '/includes/admin-create.php')) {
            fwrite(STDERR, "HIBA  nincs ilyen plugin-könyvtár: {$explicit}\n");
            exit(2);
        }
        $head = (string) @file_get_contents($explicit . '/huhs-mobile-api.php', false, null, 0, 2048);
        preg_match('/^\s*\*\s*Version:\s*([0-9.]+)/mi', $head, $match);
        echo 'mért forrás: ' . $explicit . ' (verzió ' . ($match[1] ?? '?') . ", kézzel megadva)\n";
        return $explicit;
    }

    $candidates = array();
    foreach ((array) glob(__DIR__ . '/../.tmp-api-*/huhs-mobile-api/huhs-mobile-api.php') as $main) {
        $head = (string) @file_get_contents($main, false, null, 0, 2048);
        if (preg_match('/^\s*\*\s*Version:\s*([0-9.]+)/mi', $head, $match)) {
            $candidates[$match[1]] = dirname($main);
        }
    }
    if (!$candidates) {
        fwrite(STDERR, "HIBA  nincs plugin-munkapéldány (.tmp-api-*/huhs-mobile-api)\n");
        exit(2);
    }

    $versions = array_keys($candidates);
    usort($versions, 'version_compare');
    $latest = (string) end($versions);
    $root = $candidates[$latest];
    $relative = str_replace('\\', '/', substr($root, strlen(dirname(__DIR__)) + 1));
    echo "mért forrás: {$relative} (verzió {$latest}, a legfrissebb munkapéldány)\n";

    return $root;
}

// --- A harness -------------------------------------------------------------
$checks = 0;
$failures = 0;

function check($label, $condition, $detail = '')
{
    global $checks, $failures;
    $checks++;
    if ($condition) {
        echo "OK    {$label}\n";
        return;
    }
    $failures++;
    echo "HIBA  {$label}" . ($detail !== '' ? " — {$detail}" : '') . "\n";
}

// 1) Lista-kezelés: minden bemeneti alakot elfogad, üres sorokat eldob.
check('lista: JSON-tömböt elfogad', huhs_admin_text_list_values('["Igen","Nem"]') === array('Igen', 'Nem'));
check('lista: valódi tömböt elfogad', huhs_admin_text_list_values(array('A', 'B')) === array('A', 'B'));
check('lista: soronkénti szöveget elfogad', huhs_admin_text_list_values("A\nB\n") === array('A', 'B'));
check('lista: az üres sorokat eldobja', huhs_admin_text_list_values("A\n\n  \nB") === array('A', 'B'));
check('lista: a beágyazott tömböt kihagyja', huhs_admin_text_list_values(array('A', array('B'))) === array('A'));

// 2) Kérdések: minden sort MEGTART (hogy a hiba megnevezhesse a sort).
$questions = huhs_admin_question_values(array(
    array('prompt' => 'Kérdés 1', 'options' => array('A', 'B'), 'correct' => 1),
    array('prompt' => '', 'options' => array('A'), 'correct' => 5),
));
check('kérdések: minden sort megtart', count($questions) === 2);
check('kérdések: a helyes válasz indexét átveszi', $questions[0]['correct'] === 1);
check('kérdések: a hibás sort nem dobja el csendben', $questions[1]['prompt'] === '' && $questions[1]['correct'] === 5);

// 3) Kérdőív-validáció.
check(
    'kérdőív: üres kérdés = hiba',
    huhs_admin_validate_resource_values('huhs_poll', array('_huhs_poll_question' => ' ', '_huhs_poll_options' => array('A', 'B'))) !== ''
);
check(
    'kérdőív: 1 válasz = hiba',
    huhs_admin_validate_resource_values('huhs_poll', array('_huhs_poll_question' => 'K?', '_huhs_poll_options' => array('A'))) !== ''
);
check(
    'kérdőív: 7 válasz = hiba',
    huhs_admin_validate_resource_values('huhs_poll', array('_huhs_poll_question' => 'K?', '_huhs_poll_options' => range(1, 7))) !== ''
);
check(
    'kérdőív: 2 válasz = rendben',
    huhs_admin_validate_resource_values('huhs_poll', array('_huhs_poll_question' => 'K?', '_huhs_poll_options' => array('A', 'B'))) === ''
);

// 4) Nyereményjáték-validáció + a 0-alapú index átfordítása.
$prize_ok = array(
    '_huhs_prize_question' => 'Melyik évben?',
    '_huhs_prize_answers' => array('2019', '2020', '2021', '2022'),
    '_huhs_prize_correct' => '2',
);
check('nyereményjáték: érvényes bemenet = rendben', huhs_admin_validate_resource_values('huhs_prize', $prize_ok) === '');
check(
    'nyereményjáték: 2 válasz = hiba (legalább 3 kell)',
    huhs_admin_validate_resource_values('huhs_prize', array('_huhs_prize_question' => 'K?', '_huhs_prize_answers' => array('A', 'B'), '_huhs_prize_correct' => 1)) !== ''
);
check(
    'nyereményjáték: a helyes válasz a tartományon kívül = hiba',
    huhs_admin_validate_resource_values('huhs_prize', array('_huhs_prize_question' => 'K?', '_huhs_prize_answers' => array('A', 'B', 'C'), '_huhs_prize_correct' => 4)) !== ''
);
$GLOBALS['huhs_test_meta'] = array();
huhs_admin_normalize_resource_meta(42, 'huhs_prize', $prize_ok);
check(
    'nyereményjáték: az 1-alapú „2” a 0-alapú 1-es indexet tárolja',
    ($GLOBALS['huhs_test_meta'][42]['_huhs_prize_correct'] ?? null) === 1,
    var_export($GLOBALS['huhs_test_meta'][42]['_huhs_prize_correct'] ?? null, true)
);

// 5) Kvíz-validáció.
$quiz_ok = array(
    '_huhs_game_type' => 'hardstyle_quiz',
    '_huhs_game_questions' => array(
        array('prompt' => '1. kérdés', 'options' => array('A', 'B'), 'correct' => 0),
        array('prompt' => '2. kérdés', 'options' => array('A', 'B', 'C'), 'correct' => 2),
    ),
);
check('kvíz: érvényes bemenet = rendben', huhs_admin_validate_resource_values('huhs_game', $quiz_ok) === '');
check(
    'kvíz: ismeretlen típus = hiba',
    huhs_admin_validate_resource_values('huhs_game', array('_huhs_game_type' => 'nem_letezik', '_huhs_game_questions' => $quiz_ok['_huhs_game_questions'])) !== ''
);
check(
    'kvíz: a WordPressben maradó típus (idővonal) = hiba',
    huhs_admin_validate_resource_values('huhs_game', array('_huhs_game_type' => 'timeline', '_huhs_game_questions' => $quiz_ok['_huhs_game_questions'])) !== ''
);
check(
    'kvíz: kérdés nélkül = hiba',
    huhs_admin_validate_resource_values('huhs_game', array('_huhs_game_type' => 'hardstyle_quiz', '_huhs_game_questions' => array())) !== ''
);
$bad_row = huhs_admin_validate_resource_values('huhs_game', array(
    '_huhs_game_type' => 'festival_quiz',
    '_huhs_game_questions' => array(
        array('prompt' => 'Jó kérdés', 'options' => array('A', 'B'), 'correct' => 0),
        array('prompt' => 'Hibás kérdés', 'options' => array('A'), 'correct' => 0),
    ),
));
check('kvíz: a hibás sor MEG VAN NEVEZVE a hibaüzenetben', strpos($bad_row, '2.') !== false, $bad_row);
check(
    'kvíz: a helyes válasz nincs megjelölve = hiba',
    huhs_admin_validate_resource_values('huhs_game', array(
        '_huhs_game_type' => 'hardstyle_quiz',
        '_huhs_game_questions' => array(array('prompt' => 'K?', 'options' => array('A', 'B'), 'correct' => -1)),
    )) !== ''
);

// 6) Meta-kódolás.
check(
    'meta: a lista JSON-ként tárolódik (mint a WordPress-űrlapon)',
    huhs_admin_encode_meta_value(array('type' => 'text_list'), array('A', 'B')) === '["A","B"]'
);
$encoded = huhs_admin_encode_meta_value(array('type' => 'questions'), $quiz_ok['_huhs_game_questions']);
check('meta: a kérdések JSON-ként tárolódnak', json_decode($encoded, true)[1]['correct'] === 2);
check('meta: az int absint', huhs_admin_encode_meta_value(array('type' => 'int'), '-5') === 5);
check('meta: a select kulcsot tisztít', huhs_admin_encode_meta_value(array('type' => 'select'), 'Hardstyle QUIZ!') === 'hardstylequiz');
check('meta: a textarea megőrzi a szöveget', huhs_admin_encode_meta_value(array('type' => 'textarea'), "Sor 1\nSor 2") === "Sor 1\nSor 2");

// 7) Állapot és cím.
check('állapot: üres = publish (nem csendes piszkozat)', huhs_admin_created_status('') === 'publish');
check('állapot: kérésre piszkozat', huhs_admin_created_status('draft') === 'draft');
check('állapot: ismeretlen érték = publish', huhs_admin_created_status('törölj mindent') === 'publish');
check('cím: a kérdésből jön', huhs_admin_resource_title('huhs_poll', array('_huhs_poll_question' => 'Tetszik az app?')) === 'Tetszik az app?');
check('cím: üres bemenetre tartalék', huhs_admin_resource_title('huhs_poll', array()) === 'Új elem');

// 8) A mezők kulcsa = a valódi meta-kulcs (ez védi a WordPress-oldali egyezést).
$poll_fields = huhs_admin_interaction_fields('huhs_poll');
$poll_keys = array_column($poll_fields, 'key');
check(
    // ⚠️ 2.14.5: a KÉZI angol mezők (`_huhs_*_en`) a magyar párjuk MELLETT
    // vannak — így a tulajdonos egy helyen látja mindkettőt.
    'mezők: a kérdőív kulcsai a valódi meta-kulcsok (a kézi angol mezőkkel)',
    $poll_keys === array(
        '_huhs_poll_question',
        '_huhs_poll_question_en',
        '_huhs_poll_options',
        '_huhs_poll_options_en',
        '_huhs_poll_start',
        '_huhs_poll_end'
    ),
    implode(',', $poll_keys)
);
$en_options_field = null;
foreach ($poll_fields as $field) {
    if ($field['key'] === '_huhs_poll_options_en') {
        $en_options_field = $field;
    }
}
check(
    // A kézi angol válaszlista OPCIONÁLIS: nem lehet kötelező kitölteni.
    'mezők: a kézi angol válaszlista opcionális (min = 0)',
    $en_options_field !== null && (int) $en_options_field['min'] === 0,
    json_encode($en_options_field)
);
$prize_keys = array_column(huhs_admin_interaction_fields('huhs_prize'), 'key');
check(
    'mezők: a nyereményjáték kulcsai a valódi meta-kulcsok (a kézi angol mezőkkel)',
    $prize_keys === array(
        '_huhs_prize_question',
        '_huhs_prize_question_en',
        '_huhs_prize_answers',
        '_huhs_prize_answers_en',
        '_huhs_prize_correct',
        '_huhs_prize_start',
        '_huhs_prize_end',
        '_huhs_prize_type',
        '_huhs_prize_type_en',
        '_huhs_prize_description',
        '_huhs_prize_description_en',
        '_huhs_prize_display_days'
    ),
    implode(',', $prize_keys)
);
$game_fields = huhs_admin_interaction_fields('huhs_game');
$game_keys = array_column($game_fields, 'key');
check('mezők: a kvíz kulcsai közt ott a kérdés-lista', in_array('_huhs_game_questions', $game_keys, true));
check('mezők: a kvíz rövid leírásának van kézi angol párja', in_array('_huhs_game_summary_en', $game_keys, true));
check(
    // ⚠️ MÉRT OK: a natív szerkesztő EGYETLEN kérdéslistát tart (`_questions`),
    // ezért egy második `questions` típusú mező felülírná a magyar kérdéseket.
    // Ez a check ezt a csapdát zárja be.
    'mezők: a kvíznél PONTOSAN EGY kérdés-lista mező van (nincs felülíró angol pár)',
    count(array_filter($game_fields, function ($field) {
        return ($field['type'] ?? '') === 'questions';
    })) === 1
);
$type_field = null;
foreach ($game_fields as $field) {
    if ($field['key'] === '_huhs_game_type') {
        $type_field = $field;
    }
}
check('mezők: a kvíz típusa legördülő, és CSAK a kvíz-típusokat kínálja', $type_field !== null
    && $type_field['type'] === 'select'
    && count($type_field['options']) === 3
    && $type_field['options'][0]['value'] === 'hardstyle_quiz');
check('mezők: ismeretlen típusra nincs mező', huhs_admin_interaction_fields('huhs_event') === array());

// 8b) A KÉZI angol válaszok sorrend-korlátja (2.14.5).
check(
    'kérdőív: az angol válaszok nem lehetnek többen, mint a magyarok',
    huhs_admin_validate_resource_values('huhs_poll', array(
        '_huhs_poll_question' => 'K?',
        '_huhs_poll_options' => array('A', 'B'),
        '_huhs_poll_options_en' => array('A', 'B', 'C'),
    )) !== ''
);
check(
    'kérdőív: ugyanannyi (vagy kevesebb) angol válasz = rendben',
    huhs_admin_validate_resource_values('huhs_poll', array(
        '_huhs_poll_question' => 'K?',
        '_huhs_poll_options' => array('A', 'B'),
        '_huhs_poll_options_en' => array('A'),
    )) === ''
);
check(
    'nyereményjáték: az angol válaszok nem lehetnek többen, mint a magyarok',
    huhs_admin_validate_resource_values('huhs_prize', array(
        '_huhs_prize_question' => 'K?',
        '_huhs_prize_answers' => array('A', 'B', 'C'),
        '_huhs_prize_answers_en' => array('A', 'B', 'C', 'D'),
        '_huhs_prize_correct' => 1,
    )) !== ''
);

// 9) Létrehozható típusok.
check('típus: a kérdőív létrehozható', huhs_admin_is_creatable_type('huhs_poll'));
check('típus: a nyereményjáték létrehozható', huhs_admin_is_creatable_type('huhs_prize'));
check('típus: a kvíz létrehozható', huhs_admin_is_creatable_type('huhs_game'));
check('típus: a sima bejegyzés NEM hozható létre innen', !huhs_admin_is_creatable_type('post'));

echo "\n";
echo ($checks - $failures) . "/{$checks} ellenőrzés rendben" . ($failures ? " — {$failures} HIBA" : '') . "\n";
exit($failures ? 1 : 0);
