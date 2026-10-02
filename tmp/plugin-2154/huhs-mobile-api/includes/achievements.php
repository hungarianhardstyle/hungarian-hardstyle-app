<?php

if (!defined('ABSPATH')) exit;

define('HUHS_ACHIEVEMENT_OPTION', 'huhs_achievement_badges');
define('HUHS_ACHIEVEMENT_VERSION_OPTION', 'huhs_achievement_badges_updated_at');

// Keep old links working. Some previously generated admin links omitted
// admin.php?page= and opened the public site's 404 template instead.
add_action('init', function () {
    $path = parse_url(wp_unslash($_SERVER['REQUEST_URI'] ?? ''), PHP_URL_PATH);
    if (rtrim((string) $path, '/') !== '/wp-admin/huhs-achievements') return;
    wp_safe_redirect(admin_url('admin.php?page=huhs-achievements'));
    exit;
});

function huhs_achievement_default_badges() {
    return array(
        array('slug' => 'starter', 'name' => 'Kezdő ütem', 'min_points' => 0, 'description' => 'A HUHS közösség alapjelvénye.', 'image_url' => '', 'sort_order' => 10, 'active' => 1),
        array('slug' => 'first-step', 'name' => 'Első lépés', 'min_points' => 100, 'description' => 'Az első közösségi mérföldkő.', 'image_url' => '', 'sort_order' => 20, 'active' => 1),
        array('slug' => 'regular', 'name' => 'Rendszeres látogató', 'min_points' => 300, 'description' => 'Rendszeresen jelen van a közösségben.', 'image_url' => '', 'sort_order' => 30, 'active' => 1),
        array('slug' => 'hardstyle-face', 'name' => 'Hardstyle arc', 'min_points' => 700, 'description' => 'Láthatóan aktív HUHS-közösségi tag.', 'image_url' => '', 'sort_order' => 40, 'active' => 1),
        array('slug' => 'community', 'name' => 'Közösségi ember', 'min_points' => 1500, 'description' => 'Sokat tesz a közösségi jelenlétért.', 'image_url' => '', 'sort_order' => 50, 'active' => 1),
        array('slug' => 'scene-veteran', 'name' => 'Scene veteran', 'min_points' => 3000, 'description' => 'Hosszú távon aktív színtértag.', 'image_url' => '', 'sort_order' => 60, 'active' => 1),
        array('slug' => 'huhs-legend', 'name' => 'HUHS legenda', 'min_points' => 6000, 'description' => 'Kiemelkedő, tartós közösségi aktivitás.', 'image_url' => '', 'sort_order' => 70, 'active' => 1),
    );
}

function huhs_achievement_badges() {
    $badges = get_option(HUHS_ACHIEVEMENT_OPTION, null);
    if (!is_array($badges) || !$badges) $badges = huhs_achievement_default_badges();
    $updated_at = max(1, (int) get_option(HUHS_ACHIEVEMENT_VERSION_OPTION, 1));
    $badges = array_values(array_filter(array_map(function ($badge) use ($updated_at) {
        if (!is_array($badge) || sanitize_key($badge['slug'] ?? '') === '') return null;
        return array(
            'slug' => sanitize_key($badge['slug']),
            'name' => sanitize_text_field($badge['name'] ?? 'HUHS jelvény'),
            'min_points' => max(0, (int) ($badge['min_points'] ?? 0)),
            'description' => sanitize_text_field($badge['description'] ?? ''),
            'image_url' => esc_url_raw($badge['image_url'] ?? ''),
            'sort_order' => (int) ($badge['sort_order'] ?? 0),
            'active' => !empty($badge['active']) ? 1 : 0,
            'updated_at' => $updated_at,
        );
    }, $badges)));
    usort($badges, function ($a, $b) { return $a['min_points'] <=> $b['min_points'] ?: $a['sort_order'] <=> $b['sort_order']; });
    return $badges;
}

// Register after the main HUHS menu exists; registering before its parent can
// make WordPress drop this submenu from the admin menu.
add_action('admin_menu', function () {
    add_submenu_page('huhs-mobile', 'Achievementek', 'Achievementek', 'edit_posts', 'huhs-achievements', 'huhs_achievement_admin_page');
}, 20);

add_action('admin_enqueue_scripts', function ($hook) {
    if ($hook !== 'huhs-mobile_page_huhs-achievements') return;
    wp_enqueue_media();
    wp_enqueue_script('jquery');
});

add_action('admin_post_huhs_save_achievements', function () {
    if (!current_user_can('edit_posts')) wp_die('Nincs jogosultság.');
    check_admin_referer('huhs_save_achievements');
    $raw = $_POST['badges'] ?? array();
    $saved = array();
    foreach ((array) $raw as $badge) {
        $slug = sanitize_key(wp_unslash($badge['slug'] ?? ''));
        if ($slug === '') continue;
        $saved[] = array(
            'slug' => $slug,
            'name' => sanitize_text_field(wp_unslash($badge['name'] ?? 'HUHS jelvény')),
            'min_points' => max(0, absint($badge['min_points'] ?? 0)),
            'description' => sanitize_text_field(wp_unslash($badge['description'] ?? '')),
            'image_url' => esc_url_raw(wp_unslash($badge['image_url'] ?? '')),
            'sort_order' => absint($badge['sort_order'] ?? 0),
            'active' => !empty($badge['active']) ? 1 : 0,
        );
    }
    update_option(HUHS_ACHIEVEMENT_OPTION, $saved ?: huhs_achievement_default_badges(), false);
    update_option(HUHS_ACHIEVEMENT_VERSION_OPTION, time(), false);
    wp_safe_redirect(admin_url('admin.php?page=huhs-achievements&saved=1'));
    exit;
});

function huhs_achievement_admin_page() {
    $badges = huhs_achievement_badges();
    ?>
    <div class="wrap"><h1>Achievementek és jelvények</h1>
    <?php if (!empty($_GET['saved'])) : ?><div class="notice notice-success"><p>Achievement-beállítások elmentve.</p></div><?php endif; ?>
    <p>A grafikát te töltheted fel a médiatárba, majd a kép URL-jét rendeld a jelvényhez. A pontokat nem ez az oldal írja, azokat a Firebase szerver számolja.</p>
    <div class="notice notice-info inline"><p><strong>Aktuális pontozási szabály:</strong> a bejelentkezett felhasználó minden sikeresen elküldött cikkhozzászólásért 1 achievement pontot kaphat, naponta legfeljebb 5 alkalommal. A napi limit és a duplikációvédelem szerveroldalon működik; kijelentkezett felhasználó nem kap pontot.</p></div>
    <form method="post" action="<?php echo esc_url(admin_url('admin-post.php')); ?>">
      <input type="hidden" name="action" value="huhs_save_achievements"><?php wp_nonce_field('huhs_save_achievements'); ?>
      <table class="widefat striped"><thead><tr><th>Slug</th><th>Név</th><th>Minimum pont</th><th>Leírás</th><th>Kép URL</th><th>Aktív</th></tr></thead><tbody>
      <?php foreach ($badges as $index => $badge) : ?><tr>
        <?php foreach (array('slug', 'name', 'min_points', 'description') as $field) : ?><td><input class="widefat" name="badges[<?php echo (int) $index; ?>][<?php echo esc_attr($field); ?>]" value="<?php echo esc_attr($badge[$field]); ?>"></td><?php endforeach; ?>
        <td><input class="widefat huhs-achievement-image" name="badges[<?php echo (int) $index; ?>][image_url]" value="<?php echo esc_attr($badge['image_url']); ?>"><button type="button" class="button huhs-achievement-media">Médiatár</button></td>
        <td><input type="hidden" name="badges[<?php echo (int) $index; ?>][active]" value="0"><input type="checkbox" name="badges[<?php echo (int) $index; ?>][active]" value="1" <?php checked($badge['active'], 1); ?>></td>
      </tr><?php endforeach; ?></tbody></table>
      <p><button class="button button-primary">Mentés</button></p>
    </form></div>
    <script>(function($){$('.huhs-achievement-media').on('click',function(){var b=$(this),f=b.prev('.huhs-achievement-image'),p=wp.media({title:'Jelvénygrafika kiválasztása',button:{text:'Használom'},multiple:false});p.on('select',function(){f.val(p.state().get('selection').first().toJSON().url);});p.open();});})(jQuery);</script>
    <?php
}

add_action('rest_api_init', function () {
    register_rest_route('huhs/v1', '/achievements/badges', array(
        'methods' => WP_REST_Server::READABLE,
        'permission_callback' => '__return_true',
        'callback' => function () {
            $response = new WP_REST_Response(array_values(array_filter(huhs_achievement_badges(), function ($badge) { return !empty($badge['active']); })));
            $response->header('Cache-Control', 'no-cache, no-store, must-revalidate');
            return $response;
        },
    ));
});
