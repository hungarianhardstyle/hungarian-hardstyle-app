<?php

if (!defined('ABSPATH')) {
    exit;
}

/**
 * Gutenberg blokkok renderelése és tisztítása
 */
function huhs_clean_content($content)
{
    if (function_exists('do_blocks')) {
        $content = do_blocks($content);
    }

    // Final Tiles shortcode eltávolítása
    $content = preg_replace(
        '/\[FinalTilesGallery\s+id=[\'"]?\d+[\'"]?\]/i',
        '',
        $content
    );

    // Gutenberg kommentek törlése
    $content = preg_replace('/<!--\s*wp:.*?-->/', '', $content);
    $content = preg_replace('/<!--\s*\/wp:.*?-->/', '', $content);

    // Üres sorok
    $content = preg_replace("/(\r\n|\r|\n){2,}/", "\n", $content);

    return trim($content);
}

/**
 * Cím tisztítása
 */
function huhs_clean_title($title)
{
    return html_entity_decode(
        $title,
        ENT_QUOTES | ENT_HTML5,
        'UTF-8'
    );
}

/**
 * Rövid kivonat
 */
function huhs_make_excerpt($html, $words = 40)
{
    return wp_trim_words(
        wp_strip_all_tags($html),
        $words
    );
}

/**
 * ISO dátum
 */
function huhs_format_date($mysqlDate)
{
    return mysql2date('c', $mysqlDate);
}

/**
 * Igaz, ha a kiadvany megjelenesi datuma meg nem erkezett el.
 *
 * A datum a webhely idozonajaban ertendo, es a kiadvany a megjelenesi napjan
 * 00:00-kor valik elerhetove. Ez a fuggveny az egyetlen hely, ahol ez a dontes
 * megszuletik: a nyilvanos API ebbol adja az `is_upcoming` mezot, a letoltesi
 * token vegpont pedig ezzel zarja ki a korai hozzaferest. Igy a datum-kezeles
 * nem duplikalodik a kliensben es a Firebase-fuggvenyekben, ahol idozona-elteres
 * miatt elterhetne.
 *
 * Ervenytelen vagy ures datum eseten hamisat ad vissza, vagyis a kiadvany
 * elerheto marad. Ez szandekos: egy elgepelt datum ne zarja ki a vasarlokat.
 */
function huhs_release_is_upcoming($release_date)
{
    $release_date = trim((string) $release_date);
    if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $release_date)) {
        return false;
    }
    return $release_date > current_time('Y-m-d');
}

function huhs_event_maps_url($parts)
{
    $query = implode(', ', array_filter(array_map('trim', (array) $parts)));
    return $query === '' ? '' : esc_url_raw(add_query_arg(
        array('api' => '1', 'query' => $query),
        'https://www.google.com/maps/search/'
    ));
}

/**
 * Kiemelt kép
 */
function huhs_featured_image($postId)
{
    $image = get_the_post_thumbnail_url($postId, 'large');

    return $image ?: '';
}

/**
 * YouTube, Spotify, SoundCloud linkek felismerése
 */
function huhs_get_embeds($content)
{
    $embeds = array();
    $seen = array();

    $addEmbed = static function ($type, $url) use (&$embeds, &$seen) {
        $url = html_entity_decode(trim($url), ENT_QUOTES | ENT_HTML5, 'UTF-8');
        $key = $type . ':' . $url;

        if ($url === '' || isset($seen[$key])) {
            return;
        }

        $seen[$key] = true;
        $embeds[] = array(
            'type' => $type,
            'url'  => $url,
        );
    };

    // YouTube
    preg_match_all(
        '/https?:\/\/(?:www\.)?(?:youtube\.com\/(?:watch\?[^\s"<]*v=[A-Za-z0-9_-]+[^\s"<]*|embed\/[A-Za-z0-9_-]+[^\s"<]*|shorts\/[A-Za-z0-9_-]+[^\s"<]*|live\/[A-Za-z0-9_-]+[^\s"<]*)|youtu\.be\/[A-Za-z0-9_-]+[^\s"<]*)/i',
        $content,
        $youtube
    );

    foreach ($youtube[0] as $url) {
        $addEmbed('youtube', $url);
    }

    // Spotify
    preg_match_all(
        '/https?:\/\/open\.spotify\.com\/[^\s"<]+/i',
        $content,
        $spotify
    );

    foreach ($spotify[0] as $url) {
        $addEmbed('spotify', $url);
    }

    // SoundCloud
    preg_match_all(
        '/https?:\/\/(?:www\.)?soundcloud\.com\/[^\s"<]+/i',
        $content,
        $soundcloud
    );

    foreach ($soundcloud[0] as $url) {
        $addEmbed('soundcloud', $url);
    }

    // Social links become embeds only when WordPress stores them as embed
    // blocks. Plain Instagram/TikTok links in article text stay normal links.
    if (function_exists('parse_blocks')) {
        $walkBlocks = null;
        $walkBlocks = static function ($blocks) use (&$walkBlocks, $addEmbed) {
            foreach ($blocks as $block) {
                if (($block['blockName'] ?? '') === 'core/embed') {
                    $url = $block['attrs']['url'] ?? '';

                    if (preg_match('/^https?:\/\/(?:www\.)?instagram\.com\/(?:p|reel|reels|tv)\/[A-Za-z0-9_-]+/i', $url)) {
                        $addEmbed('instagram', $url);
                    } elseif (preg_match('/^https?:\/\/(?:www\.)?tiktok\.com\/@[^\/\s]+\/video\/\d+/i', $url)) {
                        $addEmbed('tiktok', $url);
                    }
                }

                if (!empty($block['innerBlocks'])) {
                    $walkBlocks($block['innerBlocks']);
                }
            }
        };

        $walkBlocks(parse_blocks($content));
    }

    // Legacy embeds saved directly as provider blockquotes.
    preg_match_all(
        '/instagram-media[^>]*data-instgrm-permalink=["\'](https?:\/\/(?:www\.)?instagram\.com\/(?:p|reel|reels|tv)\/[A-Za-z0-9_-]+[^"\']*)/i',
        $content,
        $legacyInstagram
    );

    foreach ($legacyInstagram[1] as $url) {
        $addEmbed('instagram', $url);
    }

    preg_match_all(
        '/tiktok-embed[^>]*cite=["\'](https?:\/\/(?:www\.)?tiktok\.com\/@[^\/"\']+\/video\/\d+[^"\']*)/i',
        $content,
        $legacyTikTok
    );

    foreach ($legacyTikTok[1] as $url) {
        $addEmbed('tiktok', $url);
    }

    return $embeds;
}

/**
 * IP-célzott, transient-alapú rate limit a nyílt (hitelesítés nélküli)
 * végpontokhoz. Spam/abuse/költség-visszaélés ellen véd.
 */
function huhs_ip_rate_limited($key, $limit, $window_seconds)
{
    $ip = isset($_SERVER['REMOTE_ADDR']) ? sanitize_text_field(wp_unslash($_SERVER['REMOTE_ADDR'])) : 'unknown';
    $bucket = floor(time() / $window_seconds);
    $transient = 'huhs_rl_' . substr(hash('sha256', $key . '|' . $ip . '|' . $bucket), 0, 40);
    $count = (int) get_transient($transient);
    if ($count >= $limit) {
        return true;
    }
    set_transient($transient, $count + 1, $window_seconds * 2);
    return false;
}
