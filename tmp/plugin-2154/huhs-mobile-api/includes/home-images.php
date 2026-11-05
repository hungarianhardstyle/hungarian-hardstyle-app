<?php
/**
 * A főoldali kiemelt kép mobil nézete (plugin 2.14.26).
 *
 * A TULAJDONOS JELZÉSE: *„mobil webes nézetben az utolsó cikk képe a főoldalon
 * elég fura, lehet azon javítani?”*
 *
 * MÉRT OK: a téma a kiemelt csúszka képkeretét FIX 507 px magasra állítja
 * (`.walkerpress-slide-box .slide-image`), és nincs rá media query. Telefonon
 * (390 px széles kijelző) ez 390×507-es álló ablak, a 1200×630-as borítóképből
 * csak a középső ~40% látszik — az arcok nagyítva, a fejek levágva. A javítás egy
 * kis, mobilra szűkített CSS (16:9 ablak), amit csak a főoldalon töltünk be.
 */

defined('ABSPATH') || exit;

add_action('wp_enqueue_scripts', 'huhs_home_featured_image_style');
function huhs_home_featured_image_style()
{
    if (is_admin()) return;

    // Csak a főoldalon: a kiemelt csúszka ott van, minden más oldal érintetlen.
    // (Ha a téma később másutt is használná ezt a blokkot, a szűrő kikapcsolható.)
    $only_front = (bool) apply_filters('huhs_home_featured_image_only_front', true);
    if ($only_front && function_exists('is_front_page') && !is_front_page()) return;

    wp_enqueue_style(
        'huhs-home-featured-image',
        HUHS_API_URL . 'assets/home-featured-image.css',
        array(),
        HUHS_API_VERSION
    );
}
