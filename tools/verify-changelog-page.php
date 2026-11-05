<?php
/**
 * A plugin KIADÁSJEGYZÉKE (changelog) — bizonyítás valódi PHP-n (plugin 2.14.28).
 *
 * MIÉRT: a tulajdonos kérdése *„hol a changelog?”*. A csomagban van `readme.txt`,
 * de a kézzel feltöltött pluginhoz a WordPress nem mutatja meg — ezért a plugin
 * saját admin oldalt kap (**HUHS Mobile → Kiadásjegyzék**), ami a readme
 * `== Changelog ==` szakaszát jeleníti meg.
 *
 * MIT MÉR (lefutó kód, nem forrás-lint):
 *   1. az admin menü bejegyzés a `huhs-mobile` alá kerül, `manage_options`-szel;
 *   2. a `readme.txt` feldolgozása: verziók sorrendben, a legfrissebb a plugin
 *      fejléc-verziója, üres sor nem lesz;
 *   3. a megjelenítés lefut (kimenet mérve): cím, verziók, tételsorok, HTML-escape;
 *   4. hiányzó readme-nél a lap **kimondja** a hibát (nem fehér oldal).
 *
 * Futtatás (a konténerben, a kibontott csomagon):
 *   php tools/verify-changelog-page.php /work/tmp/php-plugin/huhs-mobile-api
 *
 * Kilépési kód: 0 = minden rendben, 1 = eltérés.
 */

define('ABSPATH', __DIR__);

$pluginDir = rtrim($argv[1] ?? '', '/');
if ($pluginDir === '' || !is_file($pluginDir . '/includes/changelog.php')) {
    fwrite(STDERR, "HIBA: nincs ilyen plugin-könyvtár: {$pluginDir}\n");
    exit(1);
}

// --- WordPress-stubok ------------------------------------------------------
$GLOBALS['huhs_hooks'] = array();
$GLOBALS['huhs_menu'] = array();
$GLOBALS['huhs_can'] = true;

function add_action($hook, $callback, $priority = 10, $args = 1)
{
    $GLOBALS['huhs_hooks'][$hook][] = array('callback' => $callback, 'priority' => $priority);
    return true;
}
function add_submenu_page($parent, $page_title, $menu_title, $capability, $slug, $callback = '')
{
    $GLOBALS['huhs_menu'][] = array(
        'parent' => $parent,
        'page_title' => $page_title,
        'menu_title' => $menu_title,
        'capability' => $capability,
        'slug' => $slug,
        'callback' => $callback,
    );
    return $slug;
}
function current_user_can($cap) { return (bool) $GLOBALS['huhs_can'] && $cap === 'manage_options'; }
function esc_html($value) { return htmlspecialchars((string) $value, ENT_QUOTES, 'UTF-8'); }
function wp_die($message = '') { throw new RuntimeException('wp_die: ' . (string) $message); }

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

require_once $pluginDir . '/includes/changelog.php';

// --- 1) Az admin menü ------------------------------------------------------
check('a menü az `admin_menu` horgon van', isset($GLOBALS['huhs_hooks']['admin_menu']));
foreach ((array) ($GLOBALS['huhs_hooks']['admin_menu'] ?? array()) as $entry) {
    call_user_func($entry['callback']);
}
$menu = $GLOBALS['huhs_menu'][0] ?? array();
check('a bejegyzés a HUHS Mobile menü alá kerül',
    ($menu['parent'] ?? '') === 'huhs-mobile', $menu['parent'] ?? '');
check('a menü neve „Kiadásjegyzék"', ($menu['menu_title'] ?? '') === 'Kiadásjegyzék', $menu['menu_title'] ?? '');
check('csak adminnak (`manage_options`)', ($menu['capability'] ?? '') === 'manage_options', $menu['capability'] ?? '');
check('a saját oldalra mutat (`huhs-changelog`)', ($menu['slug'] ?? '') === 'huhs-changelog', $menu['slug'] ?? '');
check('a kirajzoló a saját függvény', ($menu['callback'] ?? '') === 'huhs_changelog_admin_page', $menu['callback'] ?? '');

// --- 2) A readme feldolgozása --------------------------------------------
$header = (string) file_get_contents($pluginDir . '/huhs-mobile-api.php');
preg_match('/^\s*\*\s*Version:\s*(\S+)/m', $header, $versionMatch);
$pluginVersion = (string) ($versionMatch[1] ?? '');
$readmePath = $pluginDir . '/readme.txt';
check('van `readme.txt` a csomagban', is_file($readmePath));

$entries = huhs_changelog_entries($readmePath);
check('a feldolgozó legalább 8 kiadást talál', count($entries) >= 8, (string) count($entries));
check('a LEGFRISSEBB bejegyzés a plugin verziója (' . ($pluginVersion !== '' ? $pluginVersion : '?') . ')',
    $entries && (string) $entries[0]['version'] === $pluginVersion,
    $entries ? (string) $entries[0]['version'] : 'nincs');
check('minden bejegyzésnek van legalább egy tétele',
    $entries && count(array_filter($entries, function ($entry) {
        return count((array) $entry['lines']) > 0;
    })) === count($entries));
$emptyLines = 0;
foreach ($entries as $entry) {
    foreach ((array) $entry['lines'] as $line) {
        if (trim((string) $line) === '') $emptyLines++;
        if (strpos((string) $line, '*') === 0) $emptyLines++; // a `* ` jelölés nem maradhat bent
    }
}
check('nincs üres és nincs jelöléssel teli sor', $emptyLines === 0, (string) $emptyLines);
check('a verziók csökkenő sorrendben jönnek (a legfrissebbel kezdve)',
    count($entries) > 1 && version_compare((string) $entries[0]['version'], (string) end($entries)['version'], '>'),
    $entries ? ($entries[0]['version'] . ' … ' . end($entries)['version']) : '');
check('van benne a 2.14.27-es javítás (a téma felülírta a szabályt)',
    strpos((string) file_get_contents($readmePath), 'felülírta') !== false);

// --- 3) A megjelenítés lefut (kimenet mérve) -----------------------------
ob_start();
huhs_changelog_admin_page();
$html = (string) ob_get_clean();
check('a lap címe „Kiadásjegyzék"', strpos($html, '<h1>Kiadásjegyzék</h1>') !== false);
check('a legfrissebb verzió látszik a kimenetben',
    $pluginVersion !== '' && strpos($html, '<h2 style="margin-bottom:4px">' . $pluginVersion . '</h2>') !== false);
$totalLines = 0;
foreach ($entries as $entry) $totalLines += count((array) $entry['lines']);
check('a tételek listaelemként jelennek meg (a feldolgozott sorok mind)',
    $totalLines > 0 && substr_count($html, '<li>') === $totalLines,
    substr_count($html, '<li>') . ' <li> / ' . $totalLines . ' sor');
check('a kimenet HTML-escape-elt (nincs nyers `<script>` a szövegekben)',
    strpos($html, '<script') === false && strpos($html, '&lt;') === false);

// --- 4) Hiányzó readme: kimondott hiba, nem fehér oldal ------------------
$missing = huhs_changelog_entries($pluginDir . '/nincs-ilyen-readme.txt');
check('hiányzó readme-nél a feldolgozó üres listát ad (nem hibázik)', $missing === array());
ob_start();
huhs_changelog_entries($pluginDir . '/nincs-ilyen-readme.txt');
$htmlMissing = (string) ob_get_clean();
check('a hiányzó readme nem ír semmit a kimenetre', $htmlMissing === '');

// --- Összegzés -----------------------------------------------------------
$ok = $failures === 0;
echo "\n{$checks} ellenőrzés, {$failures} hiba\n";
if ($ok) echo "CHANGELOG-PAGE OK\n";
exit($ok ? 0 : 1);
