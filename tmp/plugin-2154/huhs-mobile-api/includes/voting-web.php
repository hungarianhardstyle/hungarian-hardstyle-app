<?php
if (!defined('ABSPATH')) exit;

add_action('rest_api_init', function () {
    register_rest_route('huhs/v1', '/voting/ballot-catalog', array(
        'methods' => 'GET',
        'permission_callback' => '__return_true',
        'callback' => function () {
            $response = rest_ensure_response(huhs_vote_active());
            $response->header('Cache-Control', 'no-store, max-age=0');
            return $response;
        },
    ));
});

add_action('template_redirect', function () {
    $path = wp_parse_url($_SERVER['REQUEST_URI'] ?? '', PHP_URL_PATH);
    $target = home_url('/eves-szavazas/');
    if (!is_string($path) || untrailingslashit($path) !== untrailingslashit(wp_parse_url($target, PHP_URL_PATH))) return;

    status_header(200);
    nocache_headers();
    header('Referrer-Policy: no-referrer');
    header('X-Robots-Tag: noindex');
    $season = huhs_vote_active();
    $active = !empty($season['active']);
    $year = !empty($season['year']) ? (int) $season['year'] : (int) wp_date('Y');
    $title = $active && !empty($season['title']) ? $season['title'] : 'Éves szavazás';
    if (!preg_match('/\b' . $year . '\b/', $title)) {
        $title .= ' ' . $year;
    }
    $results = !empty($season['results_approved']) ? esc_url($season['results_url'] ?? '') : '';
    ?>
<!doctype html>
<html lang="hu">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title><?php echo esc_html($title); ?> · Hungarian Hardstyle</title>
    <style><?php readfile(HUHS_API_PATH . 'assets/voting-web.css'); ?></style>
</head>
<body>
<main id="huhs-vote" data-return="<?php echo esc_url($target); ?>">
    <header class="vote-hero">
        <a class="vote-brand" href="<?php echo esc_url(home_url('/')); ?>">HUNGARIAN HARDSTYLE</a>
        <h1><?php echo esc_html($title); ?></h1>
        <p>Válaszd ki az év kedvenceit a hazai és a nemzetközi színtérről.</p>
    </header>
    <section class="vote-panel" aria-label="Szavazás állapota">
        <p id="vote-message" role="status" aria-live="polite"><?php echo $active ? 'A szavazáshoz e-mailes belépés szükséges.' : 'Jelenleg nincs aktív szavazás.'; ?></p>
        <?php if (!$active && $results !== '') : ?><a href="<?php echo $results; ?>">Eredmények megtekintése</a><?php endif; ?>
        <?php if ($active) : ?>
        <form id="vote-email" hidden>
            <label for="vote-address">E-mail-cím</label>
            <input id="vote-address" type="email" autocomplete="email" required maxlength="254">
            <p class="vote-hint">Ha már van fiókod az appban, annak az e-mail-címét add meg.</p>
            <button type="submit">Belépési link kérése</button>
        </form>
        <button id="vote-signout" class="vote-secondary" type="button" hidden>Kijelentkezés</button>
        <noscript>A szavazáshoz engedélyezd a JavaScriptet.</noscript>
        <?php endif; ?>
    </section>
    <?php if ($active) : ?>
    <form id="vote-ballot" hidden>
        <div id="vote-categories"></div>
        <button type="submit">Szavazat áttekintése</button>
    </form>
    <dialog id="vote-review" aria-labelledby="vote-review-title">
        <h2 id="vote-review-title">Így fogsz szavazni</h2>
        <div id="vote-summary"></div>
        <form method="dialog" class="vote-actions">
            <button value="cancel" class="vote-secondary">Vissza a szavazólaphoz</button>
            <button value="confirm">Szavazat leadása</button>
        </form>
    </dialog>
    <?php endif; ?>
</main>
<?php if ($active) : ?>
<script type="application/json" id="vote-season"><?php echo wp_json_encode($season, JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS | JSON_HEX_QUOT); ?></script>
<script type="module"><?php readfile(HUHS_API_PATH . 'assets/voting-web.js'); ?></script>
<?php endif; ?>
</body>
</html>
    <?php
    exit;
}, 0);
