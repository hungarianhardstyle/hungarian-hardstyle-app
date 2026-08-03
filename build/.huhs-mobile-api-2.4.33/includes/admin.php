<?php

if (!defined('ABSPATH')) {
    exit;
}

/*
|--------------------------------------------------------------------------
| Admin Menu
|--------------------------------------------------------------------------
*/

add_action('admin_menu', 'huhs_mobile_admin_menu');

function huhs_mobile_admin_menu()
{
    add_menu_page(
        'HUHS Mobile',
        'HUHS Mobile',
        'manage_options',
        'huhs-mobile',
        'huhs_dashboard_page',
        'dashicons-smartphone',
        25
    );

    // Dashboard
    add_submenu_page(
        'huhs-mobile',
        'Dashboard',
        'Dashboard',
        'manage_options',
        'huhs-mobile',
        'huhs_dashboard_page'
    );

    // Artists
    add_submenu_page(
        'huhs-mobile',
        'Artists',
        'Artists',
        'manage_options',
        'edit.php?post_type=huhs_artist'
    );

    // Organizers
    add_submenu_page(
        'huhs-mobile',
        'Organizers',
        'Organizers',
        'manage_options',
        'edit.php?post_type=huhs_organizer'
    );

    // Events
    add_submenu_page(
        'huhs-mobile',
        'Events',
        'Events',
        'manage_options',
        'edit.php?post_type=huhs_event'
    );

    // Submissions
    add_submenu_page(
        'huhs-mobile',
        'Beküldések',
        'Beküldések',
        'manage_options',
        'edit.php?post_type=huhs_submission'
    );

    // Shortcodes
    add_submenu_page(
        'huhs-mobile',
        'Shortcode-ok',
        'Shortcode-ok',
        'manage_options',
        'huhs-shortcodes',
        'huhs_shortcodes_page'
    );

    // Radio
    add_submenu_page(
        'huhs-mobile',
        'Radio',
        'Radio',
        'manage_options',
        'huhs-radio',
        'huhs_radio_page'
    );

    // Settings
    add_submenu_page(
        'huhs-mobile',
        'Settings',
        'Settings',
        'manage_options',
        'huhs-settings',
        'huhs_settings_page'
    );

    add_submenu_page(
        'huhs-mobile',
        'Lomtár',
        'Lomtár',
        'manage_options',
        'huhs-trash',
        'huhs_trash_page'
    );

    add_submenu_page(
        'huhs-mobile',
        'About',
        'About',
        'manage_options',
        'huhs-about',
        'huhs_about_page'
    );
}

/*
|--------------------------------------------------------------------------
| Dashboard
|--------------------------------------------------------------------------
*/

function huhs_dashboard_page()
{
    ?>
    <div class="wrap">

        <h1>HUHS Mobile Dashboard</h1>

        <div style="display:flex;gap:20px;flex-wrap:wrap;margin-top:30px;">

            <div style="background:#fff;padding:20px;border:1px solid #ddd;width:220px;">
                <h2>Artists</h2>
                <p style="font-size:32px;font-weight:bold;">
                    <?php echo wp_count_posts('huhs_artist')->publish ?? 0; ?>
                </p>
            </div>

            <div style="background:#fff;padding:20px;border:1px solid #ddd;width:220px;">
                <h2>Organizers</h2>
                <p style="font-size:32px;font-weight:bold;">
                    <?php echo wp_count_posts('huhs_organizer')->publish ?? 0; ?>
                </p>
            </div>

            <div style="background:#fff;padding:20px;border:1px solid #ddd;width:220px;">
                <h2>Events</h2>
                <p style="font-size:32px;font-weight:bold;">
                    <?php echo wp_count_posts('huhs_event')->publish ?? 0; ?>
                </p>
            </div>

            <div style="background:#fff;padding:20px;border:1px solid #ddd;width:220px;">
                <h2>Beküldések</h2>
                <p style="font-size:32px;font-weight:bold;">
                    <?php echo wp_count_posts('huhs_submission')->pending ?? 0; ?>
                </p>
            </div>

            <div style="background:#fff;padding:20px;border:1px solid #ddd;width:220px;">
                <h2>Shortcode-ok</h2>
                <p>DJ- és eseménygyűjtő oldalak kódjai.</p>
                <a class="button button-primary" href="<?php echo esc_url(admin_url('admin.php?page=huhs-shortcodes')); ?>">Megnyitás</a>
            </div>

        </div>

    </div>
    <?php
}

/*
|--------------------------------------------------------------------------
| Radio
|--------------------------------------------------------------------------
*/

function huhs_radio_page()
{
    ?>
    <div class="wrap">
        <h1>Hardstyle Radio</h1>

        <p>Itt lehet majd beállítani a rádió streamet vagy Spotify playlistet.</p>
    </div>
    <?php
}

/*
|--------------------------------------------------------------------------
| Settings
|--------------------------------------------------------------------------
*/

function huhs_settings_page()
{
    ?>
    <div class="wrap">
        <h1>HUHS Mobile Settings</h1>

        <p>Itt lesznek az alkalmazás beállításai.</p>
    </div>
    <?php
}

/*
|--------------------------------------------------------------------------
| Shortcode Reference
|--------------------------------------------------------------------------
*/

function huhs_shortcodes_page()
{
    $shortcodes = array(
        array(
            'title'       => 'Teljes DJ-gyűjtő',
            'code'        => '[huhs_djs]',
            'description' => 'Minden publikált DJ kártyás listája, Hardstyle és Hardcore kategóriák szerint csoportosítva.',
        ),
        array(
            'title'       => 'Csak Hardstyle DJ-k',
            'code'        => '[huhs_djs category="hardstyle"]',
            'description' => 'Csak a Hardstyle kategóriába sorolt DJ-k.',
        ),
        array(
            'title'       => 'Csak Hardcore DJ-k',
            'code'        => '[huhs_djs category="hardcore"]',
            'description' => 'Csak a Hardcore kategóriába sorolt DJ-k.',
        ),
        array(
            'title'       => 'DJ-gyűjtő saját címmel',
            'code'        => '[huhs_djs title="Magyar hard dance DJ-k"]',
            'description' => 'A title paraméterrel átírható a gyűjtőoldal főcíme. Üres címhez használd: title="".',
        ),
        array(
            'title'       => 'Teljes közelgő eseménygyűjtő',
            'code'        => '[huhs_events]',
            'description' => 'Minden látható, közelgő esemény kártyás listája dátum szerinti sorrendben.',
        ),
        array(
            'title'       => 'Korlátozott eseménylista',
            'code'        => '[huhs_events limit="6"]',
            'description' => 'Csak a következő megadott számú eseményt jeleníti meg.',
        ),
        array(
            'title'       => 'Korábbi eseményekkel együtt',
            'code'        => '[huhs_events include_past="true"]',
            'description' => 'A múltbeli eseményeket is megjeleníti. Archív oldalhoz használható.',
        ),
        array(
            'title'       => 'Eseménygyűjtő saját címmel',
            'code'        => '[huhs_events title="Közelgő bulik"]',
            'description' => 'A title paraméterrel átírható a lista főcíme. Üres címhez használd: title="".',
        ),
    );
    ?>
    <div class="wrap huhs-shortcodes-admin">
        <h1>HUHS shortcode-ok</h1>
        <p class="description">Illeszd a kiválasztott kódot egy WordPress oldal Shortcode blokkjába. A listák automatikusan a HUHS Mobile tartalmaiból épülnek fel.</p>
        <p><strong>Automatikus gyűjtőoldalak:</strong> <a href="<?php echo esc_url(get_post_type_archive_link('huhs_artist')); ?>" target="_blank" rel="noopener">DJ-k</a> · <a href="<?php echo esc_url(get_post_type_archive_link('huhs_event')); ?>" target="_blank" rel="noopener">Események</a></p>

        <style>
            .huhs-shortcodes-admin{max-width:1100px}
            .huhs-shortcodes-grid{display:grid;gap:18px;grid-template-columns:repeat(auto-fit,minmax(320px,1fr));margin-top:26px}
            .huhs-shortcode-card{background:#fff;border:1px solid #dcdcde;border-radius:10px;box-shadow:0 1px 2px rgba(0,0,0,.04);padding:20px}
            .huhs-shortcode-card h2{font-size:17px;margin:0 0 10px}
            .huhs-shortcode-card p{min-height:42px}
            .huhs-shortcode-row{align-items:center;background:#f0f0f1;border-radius:7px;display:flex;gap:10px;padding:10px}
            .huhs-shortcode-row code{background:transparent;flex:1;font-size:13px;overflow-wrap:anywhere;padding:0}
            .huhs-copy-status{color:#008a20;font-weight:600;margin-left:8px}
        </style>

        <div class="huhs-shortcodes-grid">
            <?php foreach ($shortcodes as $item) : ?>
                <section class="huhs-shortcode-card">
                    <h2><?php echo esc_html($item['title']); ?></h2>
                    <p><?php echo esc_html($item['description']); ?></p>
                    <div class="huhs-shortcode-row">
                        <code><?php echo esc_html($item['code']); ?></code>
                        <button type="button" class="button huhs-copy-shortcode" data-code="<?php echo esc_attr($item['code']); ?>">Másolás</button>
                    </div>
                </section>
            <?php endforeach; ?>
        </div>

        <p id="huhs-copy-status" class="huhs-copy-status" aria-live="polite"></p>

        <script>
            document.addEventListener('click', function (event) {
                var button = event.target.closest('.huhs-copy-shortcode');
                if (!button) return;

                navigator.clipboard.writeText(button.dataset.code).then(function () {
                    document.getElementById('huhs-copy-status').textContent = 'A shortcode a vágólapra került.';
                });
            });
        </script>
    </div>
    <?php
}

function huhs_about_page()
{
    if (!current_user_can('manage_options')) {
        wp_die('Nincs jogosultságod ehhez az oldalhoz.');
    }
    ?>
    <div class="wrap">
        <h1>HUHS Mobile About</h1>
        <table class="widefat striped" style="max-width:720px;margin-top:20px;">
            <tbody>
                <tr><td><strong>Fejlesztő / karbantartó</strong></td><td>Denoiser</td></tr>
                <tr><td><strong>Projekt</strong></td><td>Hungarian Hardstyle</td></tr>
                <tr><td><strong>API-verzió</strong></td><td><?php echo esc_html(HUHS_API_VERSION); ?></td></tr>
                <tr><td><strong>Weboldal</strong></td><td><a href="https://hungarianhardstyle.hu" target="_blank" rel="noopener">hungarianhardstyle.hu</a></td></tr>
            </tbody>
        </table>
    </div>
    <?php
}

function huhs_trash_post_types()
{
    return array('huhs_submission', 'huhs_artist', 'huhs_organizer', 'huhs_event');
}

function huhs_trash_page()
{
    if (!current_user_can('manage_options')) {
        wp_die('Nincs jogosultságod ehhez az oldalhoz.');
    }

    $items = array();
    foreach (huhs_trash_post_types() as $post_type) {
        $items[$post_type] = get_posts(array(
            'post_type'      => $post_type,
            'post_status'    => 'trash',
            'posts_per_page' => -1,
            'orderby'        => 'modified',
            'order'          => 'DESC',
        ));
    }

    $labels = array(
        'huhs_submission' => 'Beküldések',
        'huhs_artist'     => 'DJ-k',
        'huhs_organizer'  => 'Szervezők',
        'huhs_event'      => 'Események',
    );
    ?>
    <div class="wrap">
        <h1>HUHS Mobile Lomtár</h1>
        <p>A törölt HUHS-tartalmak itt visszaállíthatók vagy véglegesen törölhetők.</p>
        <form method="post" action="<?php echo esc_url(admin_url('admin-post.php')); ?>">
            <input type="hidden" name="action" value="huhs_trash_action">
            <?php wp_nonce_field('huhs_trash_action'); ?>
            <p>
                <button class="button" name="trash_mode" value="restore">Kijelöltek visszaállítása</button>
                <button class="button button-link-delete" name="trash_mode" value="delete" onclick="return confirm('A kijelölt elemek végleg törlődnek. Folytatod?');">Kijelöltek végleges törlése</button>
                <button class="button button-link-delete" name="trash_mode" value="empty" onclick="return confirm('A teljes HUHS-lomtár végleg kiürül. Folytatod?');">Teljes lomtár ürítése</button>
            </p>
            <?php foreach ($items as $post_type => $posts) : ?>
                <h2><?php echo esc_html($labels[$post_type]); ?> (<?php echo count($posts); ?>)</h2>
                <?php if (!$posts) : ?>
                    <p>Nincs törölt elem.</p>
                <?php else : ?>
                    <table class="widefat striped" style="max-width:1000px;margin-bottom:24px;">
                        <thead><tr><th style="width:32px;"><input type="checkbox" onclick="var checked=this.checked; document.querySelectorAll('.huhs-trash-<?php echo esc_attr($post_type); ?>').forEach(function(c){c.checked=checked;});"></th><th>Cím</th><th>Törölve</th></tr></thead>
                        <tbody>
                        <?php foreach ($posts as $post) : ?>
                            <tr>
                                <td><input class="huhs-trash-<?php echo esc_attr($post_type); ?>" type="checkbox" name="post_ids[]" value="<?php echo (int) $post->ID; ?>"></td>
                                <td><?php echo esc_html($post->post_title ?: '(névtelen)'); ?></td>
                                <td><?php echo esc_html(get_the_modified_date('', $post)); ?></td>
                            </tr>
                        <?php endforeach; ?>
                        </tbody>
                    </table>
                <?php endif; ?>
            <?php endforeach; ?>
        </form>
    </div>
    <?php
}

add_action('admin_post_huhs_trash_action', 'huhs_handle_trash_action');

function huhs_handle_trash_action()
{
    if (!current_user_can('manage_options')) {
        wp_die('Nincs jogosultságod ehhez a művelethez.');
    }
    check_admin_referer('huhs_trash_action');

    $mode = sanitize_key($_POST['trash_mode'] ?? '');
    $ids = array_map('absint', (array) ($_POST['post_ids'] ?? array()));
    if ($mode === 'empty') {
        $ids = array();
        foreach (huhs_trash_post_types() as $post_type) {
            $ids = array_merge($ids, get_posts(array('post_type' => $post_type, 'post_status' => 'trash', 'posts_per_page' => -1, 'fields' => 'ids')));
        }
    }

    foreach (array_unique(array_filter($ids)) as $post_id) {
        if (!in_array(get_post_type($post_id), huhs_trash_post_types(), true) || get_post_status($post_id) !== 'trash') {
            continue;
        }
        if ($mode === 'restore') {
            wp_untrash_post($post_id);
        } elseif ($mode === 'delete') {
            huhs_delete_submission_attachments($post_id);
            wp_delete_post($post_id, true);
        }
    }

    wp_safe_redirect(admin_url('admin.php?page=huhs-trash'));
    exit;
}

function huhs_delete_submission_attachments($post_id)
{
    if (get_post_type($post_id) !== 'huhs_submission') {
        return;
    }
    foreach (array('submission_image_id', 'submission_logo_id') as $key) {
        $attachment_id = absint(get_post_meta($post_id, $key, true));
        if ($attachment_id && (int) wp_get_post_parent_id($attachment_id) === (int) $post_id) {
            wp_delete_attachment($attachment_id, true);
        }
    }
}
