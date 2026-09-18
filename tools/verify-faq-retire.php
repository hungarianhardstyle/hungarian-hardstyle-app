<?php
/**
 * A GYIK-nyugdijazas VISELKEDESENEK bizonyitasa — valodi PHP, WordPress nelkul.
 *
 * MIERT KELL EZ: a `tools/verify-faq-content.mjs` csak FORRAS-SZOVEGET nez, ezert
 * egy „csak a feltetelt kiiktatom" jellegu hibat nem feltetlenul vesz eszre.
 * Itt a VALODI `huhs_faq_v4_retire_stale()` fuggvenyt futtatjuk stubolt
 * tarhellyal, es a viselkedest merjuk:
 *
 *   1. az uj listaban szereplo bejegyzeshez NEM nyul;
 *   2. a regi, gepi bejegyzes VAZLATBA kerul (+ `_huhs_faq_retired_by`);
 *   3. a tulajdonos kezzel irt bejegyzese PUBLIKALT marad, es megjelolodik
 *      `_huhs_faq_kept_by_hand`-dal — ez a legfontosabb: a migracio nem dobja el
 *      a tulajdonos sajat szoveget;
 *   4. a futo ujrafuttatas idempotens (masodszorra mar nincs mit nyugdijazni);
 *   5. a kezzel irt bejegyzes a MASODIK futasban is vedett marad.
 *
 * Futtatas (a php.exe nincs a PATH-ban, ezert teljes utvonal kell):
 *   php tools/verify-faq-retire.php [plugin-forras-mappa]
 */

$sourceDir = $argv[1] ?? null;
if ($sourceDir === null) {
    // Automatikusan a legfrissebb .tmp-api-… munkafa — ugyanaz a minta, mint a
    // tools/check-wp-meta-json.mjs-nel (egy beégetett útvonal csendben elavul).
    $candidates = glob(__DIR__ . '/../.tmp-api-*', GLOB_ONLYDIR) ?: array();
    $best = null;
    $bestTime = -1;
    foreach ($candidates as $candidate) {
        $dir = $candidate . '/huhs-mobile-api';
        if (!is_dir($dir)) continue;
        $time = filemtime($dir);
        if ($time > $bestTime) {
            $bestTime = $time;
            $best = $dir;
        }
    }
    if ($best === null) {
        fwrite(STDERR, "HIBA  nem talalok .tmp-api-*/huhs-mobile-api munkafat\n");
        exit(2);
    }
    $sourceDir = $best;
}

$file = rtrim($sourceDir, '/\\') . '/includes/faq-human.php';
if (!is_file($file)) {
    fwrite(STDERR, "HIBA  nincs ilyen fajl: {$file}\n");
    exit(2);
}

$source = file_get_contents($file);

$failures = 0;
$checks = 0;
function check($label, $ok, $detail = '')
{
    global $failures, $checks;
    $checks++;
    if ($ok) {
        echo "OK    {$label}\n";
        return;
    }
    $failures++;
    echo "HIBA  {$label}" . ($detail !== '' ? " — {$detail}" : '') . "\n";
}

/* --- A valodi fuggveny kiemelese es betoltese ------------------------- */

$marker = 'function huhs_faq_v4_retire_stale(';
$start = strpos($source, $marker);
check('megvan a nyugdijazo fuggveny a forrasban', $start !== false);
if ($start === false) {
    echo "\n" . ($checks - $failures) . "/{$checks} ellenorzes rendben\n";
    exit(1);
}

// Zarojelegalapú kiemeles. A fuggveny testeben nincs kapcsos zarojelel a
// szoveges literálokban, ezert a szamlalas biztonsagos.
$braceStart = strpos($source, '{', $start);
$depth = 0;
$end = null;
for ($i = $braceStart, $len = strlen($source); $i < $len; $i++) {
    if ($source[$i] === '{') $depth++;
    if ($source[$i] === '}') {
        $depth--;
        if ($depth === 0) {
            $end = $i;
            break;
        }
    }
}
check('a fuggveny teljes egeszeben kiemelheto', $end !== null);
if ($end === null) {
    echo "\n" . ($checks - $failures) . "/{$checks} ellenorzes rendben\n";
    exit(1);
}
$functionCode = substr($source, $start, $end - $start + 1);

$versionMatch = array();
preg_match("/define\(\s*'HUHS_FAQ_CONTENT_VERSION'\s*,\s*(\d+)\s*\)/", $source, $versionMatch);
$contentVersion = isset($versionMatch[1]) ? (int) $versionMatch[1] : 0;
check('a migracio verzioja ismert', $contentVersion > 0);
defined('HUHS_FAQ_CONTENT_VERSION') || define('HUHS_FAQ_CONTENT_VERSION', $contentVersion);

/* --- Stubolt WordPress tárhely ---------------------------------------- */

$GLOBALS['faq_posts'] = array();
$GLOBALS['faq_meta'] = array();

function faq_reset_store()
{
    $GLOBALS['faq_posts'] = array(
        11 => array('post_name' => 'uj-kerdes', 'post_status' => 'publish', 'post_title' => 'Uj kerdes'),
        12 => array('post_name' => 'reg-gepi', 'post_status' => 'publish', 'post_title' => 'Regi gepi bejegyzes'),
        13 => array('post_name' => 'kezzel-irt', 'post_status' => 'publish', 'post_title' => 'Tulajdonos kezzel irt bejegyzese'),
        14 => array('post_name' => 'mar-vazlat', 'post_status' => 'draft', 'post_title' => 'Mar vazlatban levo'),
    );
    $GLOBALS['faq_meta'] = array(
        13 => array('_huhs_faq_human_edited' => '1'),
    );
}

function get_posts($args = array())
{
    if (($args['post_type'] ?? '') !== 'huhs_faq') return array();
    $wantStatus = $args['post_status'] ?? 'publish';
    $ids = array();
    foreach ($GLOBALS['faq_posts'] as $id => $post) {
        if ($post['post_status'] === $wantStatus) $ids[] = $id;
    }
    return $ids;
}

function get_post_field($field, $id)
{
    if ($field === 'post_name') return $GLOBALS['faq_posts'][$id]['post_name'] ?? '';
    return '';
}

function get_post_meta($id, $key, $single = false)
{
    return $GLOBALS['faq_meta'][$id][$key] ?? '';
}

function update_post_meta($id, $key, $value)
{
    $GLOBALS['faq_meta'][$id][$key] = $value;
    return true;
}

function wp_update_post($args)
{
    $id = (int) ($args['ID'] ?? 0);
    if (!isset($GLOBALS['faq_posts'][$id])) return 0;
    if (isset($args['post_status'])) $GLOBALS['faq_posts'][$id]['post_status'] = $args['post_status'];
    return $id;
}

function get_the_title($id)
{
    return $GLOBALS['faq_posts'][$id]['post_title'] ?? '';
}

eval($functionCode);
check('a fuggveny betoltodott (nincs PHP hiba)', function_exists('huhs_faq_v4_retire_stale'));

/* --- 1. futas ---------------------------------------------------------- */

faq_reset_store();
$result = huhs_faq_v4_retire_stale(array('uj-kerdes'));

check(
    'az uj listaban szereplo bejegyzeshez nem nyul',
    $GLOBALS['faq_posts'][11]['post_status'] === 'publish'
        && !isset($GLOBALS['faq_meta'][11]['_huhs_faq_retired_by'])
);
check(
    'a regi gepi bejegyzes VAZLATBA kerul',
    $GLOBALS['faq_posts'][12]['post_status'] === 'draft',
    'status: ' . $GLOBALS['faq_posts'][12]['post_status']
);
check(
    'a vazlatba tett bejegyzes megjelolodik (_huhs_faq_retired_by)',
    (int) ($GLOBALS['faq_meta'][12]['_huhs_faq_retired_by'] ?? 0) === $contentVersion
);
check(
    'a TULAJDONOS kezzel irt bejegyzese PUBLIKALT marad',
    $GLOBALS['faq_posts'][13]['post_status'] === 'publish',
    'status: ' . $GLOBALS['faq_posts'][13]['post_status']
);
check(
    'a kezzel irt bejegyzes nem kap nyugdij-jelolest',
    !isset($GLOBALS['faq_meta'][13]['_huhs_faq_retired_by'])
);
check(
    'a kezzel irt bejegyzes megkapja a megtartas jelolest (_huhs_faq_kept_by_hand)',
    (int) ($GLOBALS['faq_meta'][13]['_huhs_faq_kept_by_hand'] ?? 0) === $contentVersion
);
check(
    'a mar vazlatban levo bejegyzeshez nem nyul',
    $GLOBALS['faq_posts'][14]['post_status'] === 'draft'
        && !isset($GLOBALS['faq_meta'][14]['_huhs_faq_retired_by'])
);
check(
    'a visszatero tomb csak a vazlatba tett bejegyzest sorolja fel',
    $result['retired'] === array('Regi gepi bejegyzes'),
    'retired: ' . implode(', ', $result['retired'])
);
check(
    'a visszatero tomb a kezzel irtat „megtartott"-kent sorolja fel',
    $result['kept'] === array('Tulajdonos kezzel irt bejegyzese'),
    'kept: ' . implode(', ', $result['kept'])
);

/* --- 2. futas: idempotencia ------------------------------------------- */

$second = huhs_faq_v4_retire_stale(array('uj-kerdes'));

check(
    'a masodik futas mar nem nyugdijaz semmit (idempotens)',
    $second['retired'] === array(),
    'retired: ' . implode(', ', $second['retired'])
);
check(
    'a kezzel irt bejegyzes a MASODIK futasban is vedett',
    $GLOBALS['faq_posts'][13]['post_status'] === 'publish'
        && $second['kept'] === array('Tulajdonos kezzel irt bejegyzese')
);
check(
    'a masodik futas sem alakitja at az uj listat',
    $GLOBALS['faq_posts'][11]['post_status'] === 'publish'
);

echo "\n" . ($checks - $failures) . "/{$checks} ellenorzes rendben\n";
exit($failures === 0 ? 0 : 1);
