<?php
/**
 * Plugin Name: HUHS Mobile API
 * Plugin URI: https://hungarianhardstyle.hu
 * Description: Mobile API for the Hungarian Hardstyle mobilalkalmazáshoz.
 * Version: 2.14.16
 * Author: Denoiser
 */

if (!defined('ABSPATH')) {
    exit;
}

define('HUHS_API_VERSION', '2.14.16');
define('HUHS_API_PATH', plugin_dir_path(__FILE__));
define('HUHS_API_URL', plugin_dir_url(__FILE__));

/*
|--------------------------------------------------------------------------
| Core
|--------------------------------------------------------------------------
*/

require_once HUHS_API_PATH . 'includes/helpers.php';
require_once HUHS_API_PATH . 'includes/http-cache.php';
require_once HUHS_API_PATH . 'includes/diagnostics.php';
require_once HUHS_API_PATH . 'includes/gallery.php';
require_once HUHS_API_PATH . 'includes/posts.php';
require_once HUHS_API_PATH . 'includes/faq.php';
require_once HUHS_API_PATH . 'includes/faq-human.php';
require_once HUHS_API_PATH . 'includes/releases.php';
require_once HUHS_API_PATH . 'includes/private-download.php';
require_once HUHS_API_PATH . 'includes/api-releases.php';
require_once HUHS_API_PATH . 'includes/achievements.php';
require_once HUHS_API_PATH . 'includes/poll.php';
require_once HUHS_API_PATH . 'includes/prize.php';

/*
|--------------------------------------------------------------------------
| HUHS Mobile
|--------------------------------------------------------------------------
*/

require_once HUHS_API_PATH . 'includes/admin.php';
require_once HUHS_API_PATH . 'includes/api-admin.php';

require_once HUHS_API_PATH . 'includes/artists.php';
require_once HUHS_API_PATH . 'includes/artist-save.php';
require_once HUHS_API_PATH . 'includes/api-artists.php';
require_once HUHS_API_PATH . 'includes/organizers.php';
require_once HUHS_API_PATH . 'includes/organizer-save.php';
require_once HUHS_API_PATH . 'includes/api-organizers.php';
require_once HUHS_API_PATH . 'includes/events.php';
require_once HUHS_API_PATH . 'includes/api-events.php';
require_once HUHS_API_PATH . 'includes/submissions.php';
require_once HUHS_API_PATH . 'includes/push.php';
require_once HUHS_API_PATH . 'includes/newsletter.php';
require_once HUHS_API_PATH . 'includes/voting.php';
require_once HUHS_API_PATH . 'includes/games.php';
// A natív admin létrehozó-végpontjai (kérdőív / nyereményjáték / kvíz) — szándékosan
// a games.php UTÁN, mert a mező-definíciók a HUHS_GAME_TYPES listát használják.
require_once HUHS_API_PATH . 'includes/admin-create.php';

require_once HUHS_API_PATH . 'includes/meta-fields.php';
// Az angol cikk-mezők (rejtett post meta) REST-regisztrációja — a fordítási
// folyamat ezekre ír alkalmazás-jelszóval; a webfelület nem olvassa őket.
require_once HUHS_API_PATH . 'includes/post-translation-meta.php';
// Automatikus fordítás új tartalomnál (WP-cron, plugin 2.12.0). API-kulcs
// nélkül szándékosan nem csinál semmit: nem hív külső szolgáltatást.
require_once HUHS_API_PATH . 'includes/translation-cron.php';
// Ország-/helységnevek angolul (determinisztikus névtár — nincs API-hívás).
require_once HUHS_API_PATH . 'includes/translation-places.php';
// Meta-alapú szövegek (kérdőív, nyereményjáték, GYÍK) fordítása (plugin 2.14.0).
require_once HUHS_API_PATH . 'includes/translation-fields.php';
// A hiányzó fordítások pótlása óránként (plugin 2.13.0) + admin végpontok.
// Ez teszi teljessé az automatikát: a plugin előtt létrejött tartalom is
// magától angolul jelenik meg, a tulajdonos nem nyúl semmihez.
require_once HUHS_API_PATH . 'includes/translation-sweep.php';
require_once HUHS_API_PATH . 'includes/meta-boxes.php';
require_once HUHS_API_PATH . 'includes/meta-save.php';
require_once HUHS_API_PATH . 'includes/editor.php';
require_once HUHS_API_PATH . 'includes/admin-assets.php';
require_once HUHS_API_PATH . 'includes/shortcode-events.php';
require_once HUHS_API_PATH . 'includes/shortcode-artists.php';
require_once HUHS_API_PATH . 'includes/public-archives.php';
require_once HUHS_API_PATH . 'includes/single-event.php';
require_once HUHS_API_PATH . 'includes/public-profiles.php';

/*
|--------------------------------------------------------------------------
| Boot probe
|--------------------------------------------------------------------------
|
| Marks the end of this plugin's own file loading. The boot probe already knows
| when the first of these files was reached, so this mark shows how much of the
| plugin phase our own forty files cost — the number needed before deciding
| whether splitting the admin-only includes into a lazy load is worth it.
|
| It does nothing unless the diagnostic marker is present in the request.
*/

if (function_exists('huhs_diag_mark')) {
    huhs_diag_mark('plugin_files_done');
}
