<?php
/**
 * Plugin Name: HUHS Mobile API
 * Plugin URI: https://hungarianhardstyle.hu
 * Description: Mobile API for the Hungarian Hardstyle mobilalkalmazáshoz.
 * Version: 2.4.33
 * Author: Denoiser
 */

if (!defined('ABSPATH')) {
    exit;
}

define('HUHS_API_VERSION', '2.4.33');
define('HUHS_API_PATH', plugin_dir_path(__FILE__));
define('HUHS_API_URL', plugin_dir_url(__FILE__));

/*
|--------------------------------------------------------------------------
| Core
|--------------------------------------------------------------------------
*/

require_once HUHS_API_PATH . 'includes/helpers.php';
require_once HUHS_API_PATH . 'includes/gallery.php';
require_once HUHS_API_PATH . 'includes/posts.php';
require_once HUHS_API_PATH . 'includes/faq.php';

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

require_once HUHS_API_PATH . 'includes/meta-fields.php';
require_once HUHS_API_PATH . 'includes/meta-boxes.php';
require_once HUHS_API_PATH . 'includes/meta-save.php';
require_once HUHS_API_PATH . 'includes/editor.php';
require_once HUHS_API_PATH . 'includes/admin-assets.php';
require_once HUHS_API_PATH . 'includes/shortcode-events.php';
require_once HUHS_API_PATH . 'includes/shortcode-artists.php';
require_once HUHS_API_PATH . 'includes/public-archives.php';
require_once HUHS_API_PATH . 'includes/single-event.php';
require_once HUHS_API_PATH . 'includes/public-profiles.php';
