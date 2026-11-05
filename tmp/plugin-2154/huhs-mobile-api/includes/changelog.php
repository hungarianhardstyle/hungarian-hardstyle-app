<?php
/**
 * Kiadásjegyzék (changelog) az adminban (plugin 2.14.28).
 *
 * A TULAJDONOS KÉRDÉSE: *„hol a changelog?”* — a csomagban van `readme.txt`
 * (2.14.19 → 2.14.28), de a kézzel feltöltött pluginhoz a WordPress **nem**
 * mutatja meg a readme-t, ezért a plugin saját admin oldalt kap: **HUHS Mobile →
 * Kiadásjegyzék**. A tartalmat a `readme.txt` `== Changelog ==` szakaszából
 * olvassa (egy forrás, nincs kézi másolás).
 */

defined('ABSPATH') || exit;

add_action('admin_menu', function () {
    add_submenu_page(
        'huhs-mobile',
        'Kiadásjegyzék',
        'Kiadásjegyzék',
        'manage_options',
        'huhs-changelog',
        'huhs_changelog_admin_page'
    );
}, 20);

/**
 * A readme.txt `== Changelog ==` szakasza soronként.
 *
 * @return array `array(array('version' => '2.14.28', 'lines' => array(…)), …)`
 */
function huhs_changelog_entries($path = '')
{
    if ($path === '') {
        $path = dirname(__DIR__) . '/readme.txt';
    }
    if (!is_file($path)) return array();

    $source = (string) file_get_contents($path);
    $pos = strpos($source, '== Changelog ==');
    if ($pos === false) return array();
    $body = substr($source, $pos + strlen('== Changelog =='));

    $entries = array();
    $current = null;
    foreach (preg_split('/\r?\n/', $body) as $line) {
        $line = rtrim($line);
        if (preg_match('/^=\s*([0-9][0-9A-Za-z.\-]*)\s*=$/', $line, $match)) {
            if (is_array($current)) $entries[] = $current;
            $current = array('version' => $match[1], 'lines' => array());
            continue;
        }
        if ($current === null) continue;
        if ($line === '') continue;
        $text = trim(preg_replace('/^\*\s*/', '', $line));
        if ($text !== '') $current['lines'][] = $text;
    }
    if (is_array($current)) $entries[] = $current;
    return $entries;
}

/** A legfrissebb bejegyzés verziója (a fejléc ellenőrzéséhez). */
function huhs_changelog_latest_version()
{
    $entries = huhs_changelog_entries();
    return $entries ? (string) $entries[0]['version'] : '';
}

function huhs_changelog_admin_page()
{
    if (!current_user_can('manage_options')) {
        wp_die('Nincs jogosultság.');
    }
    $entries = huhs_changelog_entries();
    echo '<div class="wrap"><h1>Kiadásjegyzék</h1>';
    echo '<p style="max-width:60ch">A plugin kiadásai, a legfrissebbel kezdve. '
        . 'A szöveg forrása a csomagban lévő <code>readme.txt</code> — ugyanaz, amit '
        . 'a Play-kiadásjegyzet is tartalmaz.</p>';
    if (!$entries) {
        echo '<p><strong>Nem található kiadásjegyzék.</strong> A csomagban nincs '
            . '<code>readme.txt</code>, vagy hiányzik belőle a <code>== Changelog ==</code> szakasz.</p></div>';
        return;
    }
    foreach ($entries as $entry) {
        echo '<h2 style="margin-bottom:4px">' . esc_html((string) $entry['version']) . '</h2><ul style="margin-top:4px">';
        foreach ((array) $entry['lines'] as $line) {
            echo '<li>' . esc_html((string) $line) . '</li>';
        }
        echo '</ul>';
    }
    echo '</div>';
}
