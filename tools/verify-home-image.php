<?php
/**
 * A főoldali kiemelt kép mobil nézete — bizonyítás valódi PHP-n (plugin 2.14.26).
 *
 * MIÉRT: a tulajdonos jelzése szerint *„mobil webes nézetben az utolsó cikk képe
 * a főoldalon elég fura”*. A mért ok a TÉMA CSS-ében van: a kiemelt csúszka kép-
 * kerete FIX 507 px magas (`.walkerpress-slide-box .slide-image`), és erre nincs
 * media query. Telefonon ez 390×507-es ÁLLÓ ablak, a 1200×630-as képből csak a
 * középső rész látszik (nagyított arcok, levágott fejek). A javítás egy mobilra
 * szűkített 16:9 ablak.
 *
 * MIT MÉR (nem forrás-lint, hanem lefutó kód + számolt geometria):
 *   1. a stílus a `wp_enqueue_scripts`-en, a helyes fájllal és **verzióval**
 *      (cache-busting) kerül be — a hívó ténylegesen lefut;
 *   2. a főoldalon igen, MÁS oldalon nem töltődik be;
 *   3. a stílus csak mobilon (≤767 px) ír felül, és `aspect-ratio`-t használ
 *      (nem fix magasságot) — a táblagép/asztali elrendezés érintetlen;
 *   4. a geometria: 390 px széles kijelzőn a látható képhányad 40% → 93% közé esik
 *      (a 1200×630-as kép `cover` viselkedésével számolva).
 *
 * Futtatás (a konténerben, a kibontott csomagon):
 *   php tools/verify-home-image.php /work/tmp/php-plugin/huhs-mobile-api
 *
 * Kilépési kód: 0 = minden rendben, 1 = eltérés.
 */

define('ABSPATH', __DIR__);
define('HUHS_API_PATH', rtrim($argv[1] ?? '', '/') . '/');
define('HUHS_API_URL', 'https://hungarianhardstyle.hu/wp-content/plugins/huhs-mobile-api/');
define('HUHS_API_VERSION', 'test-version');

if (HUHS_API_PATH === '/') {
    fwrite(STDERR, "HIBA: nincs plugin-könyvtár\n");
    exit(1);
}

// --- WordPress-stubok (csak ami ehhez a méréshez kell) ---------------------
$GLOBALS['huhs_hooks'] = array();
$GLOBALS['huhs_styles'] = array();
$GLOBALS['huhs_is_admin'] = false;
$GLOBALS['huhs_is_front'] = true;
$GLOBALS['huhs_filters'] = array();

function add_action($hook, $callback, $priority = 10, $args = 1)
{
    $GLOBALS['huhs_hooks'][$hook][] = array('callback' => $callback, 'priority' => $priority);
    if ($hook === 'wp_enqueue_scripts') {
        $GLOBALS['huhs_enqueue_priority'] = $priority;
    }
    return true;
}
function add_filter($hook, $callback, $priority = 10, $args = 1) { return true; }
function apply_filters($hook, $value)
{
    return array_key_exists($hook, $GLOBALS['huhs_filters']) ? $GLOBALS['huhs_filters'][$hook] : $value;
}
function is_admin() { return (bool) $GLOBALS['huhs_is_admin']; }
function is_front_page() { return (bool) $GLOBALS['huhs_is_front']; }
function wp_enqueue_style($handle, $src = '', $deps = array(), $version = false, $media = 'all')
{
    $GLOBALS['huhs_styles'][] = array(
        'handle' => (string) $handle,
        'src' => (string) $src,
        'deps' => (array) $deps,
        'version' => (string) $version,
        'media' => (string) $media,
    );
    return true;
}

$checks = 0;
$failures = 0;
function check($label, $condition, $detail = '')
{
    global $checks, $failures;
    $checks++;
    if ($condition) {
        echo "OK   {$label}\n";
        return;
    }
    $failures++;
    echo "HIBA {$label}" . ($detail !== '' ? " — {$detail}" : '') . "\n";
}

/** Futtatja a regisztrált csatolót (így a hívó valódi kódja fut le). */
function run_enqueue()
{
    $GLOBALS['huhs_styles'] = array();
    foreach ((array) ($GLOBALS['huhs_hooks']['wp_enqueue_scripts'] ?? array()) as $entry) {
        call_user_func($entry['callback']);
    }
    return $GLOBALS['huhs_styles'];
}

// --- 0) A fájlok a KIADOTT csomagban vannak --------------------------------
$cssPath = HUHS_API_PATH . 'assets/home-featured-image.css';
$phpPath = HUHS_API_PATH . 'includes/home-images.php';
check('a stílus a kiadott csomagban van (assets/home-featured-image.css)', is_file($cssPath));
check('a betöltő kód a kiadott csomagban van (includes/home-images.php)', is_file($phpPath));
$mainSource = (string) file_get_contents(HUHS_API_PATH . 'huhs-mobile-api.php');
check('a fő plugin-fájl betölti az új includes fájlt',
    strpos($mainSource, "require_once HUHS_API_PATH . 'includes/home-images.php';") !== false);

// --- 1) A hívó lefut, a főoldalon betölt --------------------------------
require_once $phpPath;
check('a stílus a `wp_enqueue_scripts` horgon van regisztrálva',
    isset($GLOBALS['huhs_hooks']['wp_enqueue_scripts']));
$styles = run_enqueue();
$style = $styles[0] ?? array();
check('a főoldalon betöltődik PONTOSAN egy stílus', count($styles) === 1, (string) count($styles));
check('a fogantyú beszédes (`huhs-home-featured-image`)',
    ($style['handle'] ?? '') === 'huhs-home-featured-image', $style['handle'] ?? '');
check('a fájl a plugin assets könyvtárából jön',
    ($style['src'] ?? '') === HUHS_API_URL . 'assets/home-featured-image.css', $style['src'] ?? '');
check('a verzió a plugin verziója (cache-busting feltöltés után)',
    ($style['version'] ?? '') === HUHS_API_VERSION, $style['version'] ?? '');

// --- 2) MÁS oldalon nem töltődik be -------------------------------------
$GLOBALS['huhs_is_front'] = false;
$stylesOther = run_enqueue();
check('más oldalon (nem főoldal) NEM töltődik be', count($stylesOther) === 0, (string) count($stylesOther));
$GLOBALS['huhs_filters']['huhs_home_featured_image_only_front'] = false;
$stylesForced = run_enqueue();
check('a szűrővel minden oldalra kiterjeszthető (nem kikapcsolt, csak szűkített)',
    count($stylesForced) === 1, (string) count($stylesForced));
$GLOBALS['huhs_filters'] = array();
$GLOBALS['huhs_is_front'] = true;

// --- 3) A stílus tartalma: mobilra szűkített, arányos ablak --------------
$css = (string) file_get_contents($cssPath);
check('van mobil media query (max-width: 767px)',
    strpos($css, '@media (max-width: 767px)') !== false);
check('a csúszka képkeretét írja felül (`.walkerpress-slide-box .slide-image`)',
    strpos($css, '.walkerpress-slide-box .slide-image') !== false);
check('ARÁNYT használ (aspect-ratio: 16 / 9), nem fix magasságot',
    strpos($css, 'aspect-ratio: 16 / 9') !== false);
check('a fix magasságot feloldja (height: auto)',
    strpos($css, 'height: auto') !== false);
check('a képet felső harmadra igazítja (a fejek nem vágódnak le)',
    strpos($css, 'object-position: center 25%') !== false);
check('a felülírás MOBILRA zárt (a desktop/tablet elrendezés érintetlen)',
    strpos($css, '@media (min-width: 768px)') === false && substr_count($css, '@media') === 1,
    'media blokkok: ' . substr_count($css, '@media'));

// --- 3b) A SORREND CSAPDÁJA (2.14.27) ------------------------------------
//
// ⚠️ ÉLES MÉRÉS (2026-11-05, a feltöltött 2.14.26 után): a szabály bent volt a
// Boost által összevont CSS-ben, de a téma `height:507px` szabálya **utána**
// következett, és ugyanolyan súlyú volt (2 osztály) → a téma nyert, vagyis a
// javítás **nem hatott**. Mostantól a mi szabályunk **3 osztályos**, tehát a
// sorrendtől függetlenül nyer; a stílus pedig 99-es prioritással tölt be.
$ourSelector = '.walkerpress-slider .walkerpress-slide-box .slide-image';
$themeSelector = '.walkerpress-slide-box .slide-image'; // a téma mért szabálya
$classCount = function ($selector) {
    $classes = preg_match_all('/\.[A-Za-z0-9_-]+/', $selector, $match);
    return (int) $classes;
};
$ourWeight = $classCount($ourSelector);
$themeWeight = $classCount($themeSelector);
check('a saját szelektor ERŐSEBB a témáénál (sorrendtől függetlenül nyer)',
    strpos($css, $ourSelector) !== false && $ourWeight > $themeWeight,
    'saját=' . $ourWeight . ' osztály, téma=' . $themeWeight . ' osztály');
check('a 99-es prioritással tölt be (a téma stílusai után)',
    ($GLOBALS['huhs_enqueue_priority'] ?? null) === 99,
    'prioritás=' . var_export($GLOBALS['huhs_enqueue_priority'] ?? null, true));

// --- 3c) A plugin KIADÁSJEGYZÉKE (readme.txt) ---------------------------
$readmePath = HUHS_API_PATH . 'readme.txt';
$mainHeader = (string) file_get_contents(HUHS_API_PATH . 'huhs-mobile-api.php');
preg_match('/^\s*\*\s*Version:\s*(\S+)/m', $mainHeader, $versionMatch);
$pluginVersion = (string) ($versionMatch[1] ?? '');
check('van kiadásjegyzék a csomagban (readme.txt)', is_file($readmePath));
$readme = is_file($readmePath) ? (string) file_get_contents($readmePath) : '';
check('a kiadásjegyzékben van `== Changelog ==` szakasz',
    strpos($readme, '== Changelog ==') !== false);
check('a `Stable tag` a plugin verziója (' . ($pluginVersion !== '' ? $pluginVersion : '?') . ')',
    $pluginVersion !== '' && strpos($readme, 'Stable tag: ' . $pluginVersion) !== false,
    $pluginVersion);
check('a legfrissebb kiadás bejegyzése benne van (`= ' . ($pluginVersion !== '' ? $pluginVersion : '?') . ' =`)',
    $pluginVersion !== '' && strpos($readme, '= ' . $pluginVersion . ' =') !== false,
    $pluginVersion);

// --- 4) A geometria (számolt, mért bemenetekkel) -------------------------
/**
 * Mennyi látszik a képből `cover` esetén?
 *
 * Bemenetek a MÉRT valóság: a téma keretmagassága 507 px (a weblapon olvasott
 * CSS-ből), a kép 1200×630 (a legutóbbi cikk borítóképe), a telefon szélessége
 * 390 px (iPhone-töréspont).
 */
function visible_width_fraction($imageWidth, $imageHeight, $boxWidth, $boxHeight)
{
    if ($boxWidth <= 0 || $boxHeight <= 0) return 0.0;
    $scale = max($boxWidth / $imageWidth, $boxHeight / $imageHeight);
    $renderedWidth = $imageWidth * $scale;
    if ($renderedWidth <= 0) return 0.0;
    return min(1.0, $boxWidth / $renderedWidth);
}

$boxWidth = 390;
$imageWidth = 1200;
$imageHeight = 630;
$beforeHeight = 507;                 // a téma fix magassága (mért, a weblapon)
// ⚠️ A 16:9 ablakot NEM beégetett számból vesszük, hanem a KIADOTT CSS-ből
// olvassuk ki — így a mutáció (a szabály törlése) ezt a mérést is pirosra váltja.
$ratioMatch = array();
preg_match('/aspect-ratio:\s*(\d+)\s*\/\s*(\d+)/', $css, $ratioMatch);
$ratioWidth = (int) ($ratioMatch[1] ?? 0);
$ratioHeight = (int) ($ratioMatch[2] ?? 0);
$afterHeight = ($ratioWidth > 0 && $ratioHeight > 0)
    ? (int) round($boxWidth * $ratioHeight / $ratioWidth)
    : 0;

$before = visible_width_fraction($imageWidth, $imageHeight, $boxWidth, $beforeHeight);
$after = $afterHeight > 0 ? visible_width_fraction($imageWidth, $imageHeight, $boxWidth, $afterHeight) : 0.0;

printf("     mért geometria: 390×%d px előtte → a kép %.0f%%-a látszik; 390×%d px utána → %.0f%%\n",
    $beforeHeight, $before * 100, $afterHeight, $after * 100);

check('a JELENLEGI állapot romlott (a kép kevesebb mint fele látszik)',
    $before < 0.5, sprintf('%.2f', $before));
check('a javítás után a kép túlnyomó része látszik (>90%)',
    $after > 0.9, sprintf('%.2f', $after));
check('a képkeret aránya 16:9 lesz (219 px magas 390 px szélesen)',
    $afterHeight === 219, (string) $afterHeight);

// --- Összegzés -----------------------------------------------------------
$ok = $failures === 0;
echo "\n{$checks} ellenőrzés, {$failures} hiba\n";
if ($ok) echo "HOME-IMAGE OK\n";
exit($ok ? 0 : 1);
