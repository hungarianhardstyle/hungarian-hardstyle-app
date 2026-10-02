<?php
/**
 * A TWITCH-BEHARANGOZÓ admin-beállítása (plugin 2.14.15) — bizonyítás valódi PHP-n.
 *
 * MIÉRT: a tulajdonos jelzése (2026-10-02): *„a huhs-mobile-api-2.14.14-ben nem
 * látok sehol olyan opciót, ahol meg tudok adni twitch stream beharangozót,
 * holott azt írtad van"*. **Igaza volt:** a kártya felülírása csak a
 * Firestore-ban (`app_settings/twitch`) volt elérhető, a plugin adminjában nem.
 * A 2.14.15 ezért behozza oda, és a Twitch-figyelő kör szinkronizálja a
 * Firestore-ba — így a már kint lévő appok is látják, új build nélkül.
 *
 * MIT MÉR (nem forrás-lint, hanem **lefutó** kód):
 *   1. a **REST-végpont** (`/huhs/v1/twitch-card`) létezik, nyilvános olvasással;
 *   2. az **admin menü** tartalmazza a „Twitch beharangozó" oldalt;
 *   3. a **mentés-hook** be van kötve (`admin_post_huhs_save_twitch_card`);
 *   4. a **tisztítás** szabályai: a felirat legfeljebb 80 karakter, csak
 *      http(s) kép-URL maradhat meg, és az „élő adás nélkül is" **kép nélkül
 *      kikapcsol** (különben üres kártyát lehetne bekapcsolni);
 *   5. a **beolvasás** alapértéke: ha a tulajdonos még nem nyitotta meg az
 *      oldalt, a kártya **be van kapcsolva** (nem rontja el a működő élő kártyát).
 *
 * Futtatás (a konténerben, a kibontott csomagon):
 *   php tools/verify-twitch-card.php /work/tmp/php-plugin/huhs-mobile-api
 *
 * Kilépési kód: 0 = minden rendben, 1 = eltérés.
 */

define('ABSPATH', __DIR__);

// --- WordPress-stubok ------------------------------------------------------
$GLOBALS['huhs_options'] = array();
$GLOBALS['huhs_hooks'] = array();
$GLOBALS['huhs_routes'] = array();
$GLOBALS['huhs_submenus'] = array();

function add_action($hook, $callback = null, $priority = 10, $args = 1)
{
    $GLOBALS['huhs_hooks'][] = array('hook' => $hook, 'callback' => $callback, 'priority' => $priority);
    return true;
}
function add_filter(...$args) { return true; }
function register_rest_route($namespace, $route, $args = array())
{
    $GLOBALS['huhs_routes'][] = array('namespace' => $namespace, 'route' => $route, 'args' => $args);
    return true;
}
function add_submenu_page($parent, $page_title, $menu_title, $capability, $slug, $callback = null)
{
    $GLOBALS['huhs_submenus'][] = array(
        'parent' => $parent,
        'title' => $menu_title,
        'slug' => $slug,
        'callback' => $callback,
    );
    return $slug;
}
function get_option($name, $default = false)
{
    return array_key_exists($name, $GLOBALS['huhs_options']) ? $GLOBALS['huhs_options'][$name] : $default;
}
function update_option($name, $value, $autoload = null)
{
    $GLOBALS['huhs_options'][$name] = $value;
    return true;
}
function esc_url_raw($url) { return trim((string) $url); }
function sanitize_text_field($text) { return trim(strip_tags((string) $text)); }
function sanitize_key($key) { return preg_replace('/[^a-z0-9_\-]/', '', strtolower((string) $key)); }
function wp_unslash($value) { return is_string($value) ? stripslashes($value) : $value; }
function wp_parse_url($url, $component = -1) { return parse_url($url, $component); }
function wp_http_validate_url($url) { return (bool) filter_var($url, FILTER_VALIDATE_URL); }
// ⚠️ 2.14.17: a kártya kicsinyített képéhez kell a médiatár-feloldás.
function attachment_url_to_postid($url) {
    return (int) ($GLOBALS['huhs_attachment_map'][$url] ?? 0);
}
function wp_get_attachment_image_src($id, $size = 'thumbnail') {
    $sizes = $GLOBALS['huhs_attachment_sizes'][$id] ?? array();
    if (!isset($sizes[$size])) return false;
    return array($sizes[$size], 768, 432, false);
}
function absint($value) { return abs((int) $value); }
function __return_true() { return true; }
function admin_url($path = '') { return 'https://example.test/wp-admin/' . ltrim($path, '/'); }
function current_user_can(...$args) { return true; }

class WP_Error
{
    public function __construct(public $code = '', public $message = '', public $data = null) {}
}
/**
 * A WordPress REST-konstansai — a regisztrált útvonalak metódusai ezekből állnak
 * össze (a stub nélkül a `rest_api_init` closure „Class not found"-dal halna el,
 * és a mérés hamis pirosat adna).
 */
class WP_REST_Server
{
    public const READABLE = 'GET';
    public const CREATABLE = 'POST';
    public const EDITABLE = 'POST, PUT, PATCH';
    public const DELETABLE = 'DELETE';
    public const ALLMETHODS = 'GET, POST, PUT, PATCH, DELETE';
}
class WP_REST_Response
{
    private $headers = array();
    public function __construct(private $data = null) {}
    public function header($key, $value) { $this->headers[$key] = $value; return $this; }
    public function get_data() { return $this->data; }
    public function get_headers() { return $this->headers; }
}

// --- A mért fájl betöltése (a SZÁLLÍTANDÓ csomagból) -----------------------
$pluginDir = $argv[1] ?? '/work/tmp/php-plugin/huhs-mobile-api';
$target = $pluginDir . '/includes/api-admin.php';
if (!file_exists($target)) {
    fwrite(STDERR, "HIBA  nincs meg a fájl: $target\n");
    exit(1);
}
require_once $target;

$fail = 0;
function check($label, $ok, $detail = '')
{
    global $fail;
    if (!$ok) $fail++;
    echo ($ok ? 'OK   ' : 'HIBA ') . $label . ($detail !== '' ? " — $detail" : '') . "\n";
}

echo "=== 1) A REST-végpont és az admin-oldal léte ===\n";
// A regisztrált útvonalak begyűjtése: a `rest_api_init` hook futtatása.
foreach ($GLOBALS['huhs_hooks'] as $hook) {
    if ($hook['hook'] === 'rest_api_init' && is_callable($hook['callback'])) {
        call_user_func($hook['callback']);
    }
}
$route = null;
foreach ($GLOBALS['huhs_routes'] as $entry) {
    if ($entry['route'] === '/twitch-card') $route = $entry;
}
check('a /twitch-card végpont regisztrálva van', $route !== null, $route ? $route['namespace'] . $route['route'] : 'nincs');
if ($route) {
    $single = isset($route['args'][0]) ? $route['args'][0] : $route['args'];
    check('a végpont olvasásra való (READABLE)', !empty($single['methods']));
    check('a végpont nyilvánosan olvasható (a figyelő így éri el)',
        ($single['permission_callback'] ?? '') === '__return_true');
    check('a végpontnak van visszahívása', is_callable($single['callback'] ?? null), (string) ($single['callback'] ?? ''));
}

foreach ($GLOBALS['huhs_hooks'] as $hook) {
    if ($hook['hook'] === 'admin_menu' && is_callable($hook['callback'])) {
        call_user_func($hook['callback']);
    }
}
$menu = null;
foreach ($GLOBALS['huhs_submenus'] as $entry) {
    if ($entry['slug'] === 'huhs-twitch-card') $menu = $entry;
}
check('az admin menüben megvan a „Twitch beharangozó" oldal', $menu !== null,
    $menu ? $menu['title'] . ' (' . $menu['slug'] . ')' : 'nincs');
check('az oldal a HUHS Mobile menü alatt van', $menu && $menu['parent'] === 'huhs-mobile');
check('az oldal kirajzolója létezik', $menu && is_callable($menu['callback']));

$saveHook = null;
foreach ($GLOBALS['huhs_hooks'] as $hook) {
    if ($hook['hook'] === 'admin_post_huhs_save_twitch_card') $saveHook = $hook;
}
check('a mentés-hook be van kötve (admin_post_huhs_save_twitch_card)', $saveHook !== null);

echo "\n=== 2) A beállítás tisztítása ===\n";
$clean = huhs_twitch_card_normalize(array(
    'imageUrl' => 'https://example.test/plakat.jpg',
    'headerText' => str_repeat('a', 120),
    'enabled' => true,
    'showWhenOffline' => true,
));
check('a felirat legfeljebb 80 karakter', mb_strlen($clean['headerText']) === 80, (string) mb_strlen($clean['headerText']));
check('a kép URL-je megmarad', $clean['imageUrl'] === 'https://example.test/plakat.jpg');
check('képpel az „élő adás nélkül is" bekapcsolható', $clean['showWhenOffline'] === true);

$noImage = huhs_twitch_card_normalize(array(
    'imageUrl' => '',
    'headerText' => 'Következő adás',
    'enabled' => true,
    'showWhenOffline' => true,
));
check('KÉP NÉLKÜL az „élő adás nélkül is" kikapcsol (nincs mit mutatni)',
    $noImage['showWhenOffline'] === false, var_export($noImage['showWhenOffline'], true));

$badUrl = huhs_twitch_card_normalize(array(
    'imageUrl' => 'javascript:alert(1)',
    'enabled' => true,
    'showWhenOffline' => true,
));
check('a nem URL képérték nem megy át (és az offline kapcsoló sem)',
    $badUrl['imageUrl'] === '' && $badUrl['showWhenOffline'] === false,
    $badUrl['imageUrl'] . ' / ' . var_export($badUrl['showWhenOffline'], true));

echo "\n=== 2b) A kicsinyített kép (2.14.17 — „100 év mire betölt”) ===\n";
// A médiatárban lévő kép: a WordPress `medium_large` változatát adjuk ki.
$GLOBALS['huhs_attachment_map'] = array('https://example.test/plakat.jpg' => 42);
$GLOBALS['huhs_attachment_sizes'] = array(
    42 => array('medium_large' => 'https://example.test/plakat-768x432.jpg'),
);
$withSmall = huhs_twitch_card_normalize(array(
    'imageUrl' => 'https://example.test/plakat.jpg',
    'enabled' => true,
    'showWhenOffline' => true,
));
check('a médiatárban lévő képhez megvan a kicsinyített változat',
    ($withSmall['imageUrlSmall'] ?? '') === 'https://example.test/plakat-768x432.jpg',
    var_export($withSmall['imageUrlSmall'] ?? null, true));

// Nem a médiatárból való kép: nincs kicsinyített változat (nem tippelünk).
$GLOBALS['huhs_attachment_map'] = array();
$foreign = huhs_twitch_card_normalize(array(
    'imageUrl' => 'https://mas.example.test/kulso.jpg',
    'enabled' => true,
    'showWhenOffline' => true,
));
check('külső képnél nincs kicsinyített változat (nem tippelünk)',
    ($foreign['imageUrlSmall'] ?? 'x') === '', var_export($foreign['imageUrlSmall'] ?? null, true));

// Csak `large` van: azt adjuk (a `medium_large` hiányzik).
$GLOBALS['huhs_attachment_map'] = array('https://example.test/plakat.jpg' => 42);
$GLOBALS['huhs_attachment_sizes'] = array(
    42 => array('large' => 'https://example.test/plakat-1024x576.jpg'),
);
$onlyLarge = huhs_twitch_card_normalize(array(
    'imageUrl' => 'https://example.test/plakat.jpg',
    'enabled' => true,
    'showWhenOffline' => true,
));
check('ha csak a „large” van meg, azt adja ki',
    ($onlyLarge['imageUrlSmall'] ?? '') === 'https://example.test/plakat-1024x576.jpg',
    var_export($onlyLarge['imageUrlSmall'] ?? null, true));

// A kicsinyített cím is http(s) kell legyen (az appba kép-URL-ként megy ki).
$GLOBALS['huhs_attachment_sizes'] = array(
    42 => array('medium_large' => 'javascript:alert(2)'),
);
$badSmall = huhs_twitch_card_normalize(array(
    'imageUrl' => 'https://example.test/plakat.jpg',
    'enabled' => true,
    'showWhenOffline' => true,
));
check('a nem http(s) kicsinyített cím nem megy át',
    ($badSmall['imageUrlSmall'] ?? 'x') === '', var_export($badSmall['imageUrlSmall'] ?? null, true));
$GLOBALS['huhs_attachment_sizes'] = array();

// ⚠️ MÉRT HIBA NYOMÁN (2026-10-02): a tulajdonos feltöltött egy képet, az
// „Engedélyezve” pipa viszont üresen maradt — a kártya némán elrejtve maradt.
// Az első mentésnél ezért a kép jelenléte maga a szándék.
$firstSave = huhs_twitch_card_normalize(array(
    'imageUrl' => 'https://example.test/plakat.jpg',
    'headerText' => 'Következő adás',
    'enabled' => false,
    'showWhenOffline' => true,
    'configured' => false,
));
check('ELSŐ mentésnél a kép bekapcsolja a kártyát (a hiányzó pipa nem rejti el)',
    $firstSave['enabled'] === true, var_export($firstSave['enabled'], true));

$laterSave = huhs_twitch_card_normalize(array(
    'imageUrl' => 'https://example.test/plakat.jpg',
    'enabled' => false,
    'showWhenOffline' => true,
    'configured' => true,
));
check('KÉSŐBBI mentésnél a pipa a mérvadó (a kikapcsolás tiszteletben marad)',
    $laterSave['enabled'] === false, var_export($laterSave['enabled'], true));
check('a mentés megjegyzi, hogy a szándék már ismert',
    $firstSave['configured'] === true && $laterSave['configured'] === true);

echo "\n=== 3) A beolvasás alapértéke ===\n";
$default = huhs_twitch_card_value();
check('a még be nem állított kártya BE van kapcsolva (nem rontja el az élő kártyát)',
    $default['enabled'] === true, var_export($default['enabled'], true));
check('a még be nem állított kártyánál nincs kép és nincs offline mód',
    $default['imageUrl'] === '' && $default['showWhenOffline'] === false);

update_option(HUHS_TWITCH_CARD_OPTION, array(
    'imageUrl' => 'https://example.test/eloadas.jpg',
    'headerText' => 'Következő adás: péntek 20:00',
    'enabled' => true,
    'showWhenOffline' => true,
));
$stored = huhs_twitch_card_value();
check('a mentett érték visszaolvasható', $stored['imageUrl'] === 'https://example.test/eloadas.jpg'
    && $stored['showWhenOffline'] === true && $stored['headerText'] === 'Következő adás: péntek 20:00');

$response = huhs_twitch_card_read();
$data = $response->get_data();
check('a végpont a mentett értéket adja vissza', $data['headerText'] === 'Következő adás: péntek 20:00');
$headers = $response->get_headers();
check('a végpont nem enged gyorsítótárazni (a beállítás azonnal érvényes)',
    isset($headers['Cache-Control']) && strpos($headers['Cache-Control'], 'no-store') !== false,
    $headers['Cache-Control'] ?? '(nincs)');

echo "\n=== 4) A szállítandó fájl forrás-lintje ===\n";
$source = (string) file_get_contents($target);
check('a mentés a beépített WordPress-tisztítást használja',
    strpos($source, 'check_admin_referer(\'huhs_save_twitch_card\')') !== false
        && strpos($source, "current_user_can('manage_options')") !== false);
check('a beállítás külön opcióban él (nem keveredik a többivel)',
    strpos($source, "define('HUHS_TWITCH_CARD_OPTION', 'huhs_twitch_card')") !== false);
check('a kép a meglévő médiatár-gombot használja (huhs-image-upload)',
    strpos($source, 'huhs-image-upload') !== false);

echo "\n" . ($fail === 0 ? 'MINDEN ELLENŐRZÉS RENDBEN' : "$fail ELLENŐRZÉS BUKOTT") . "\n";
exit($fail === 0 ? 0 : 1);
