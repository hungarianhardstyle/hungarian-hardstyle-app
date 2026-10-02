<?php
/**
 * A NYEREMÉNYJÁTÉKBÓL VALÓ TÖRLÉS ellenőrzése (2.14.18) — PHP stub-harness.
 *
 * MIÉRT: a tulajdonos kérése (2026-10-02): *„ha valaki törli a regisztrációját az
 * appban, kerüljön ki a neve a nyereményjátékból is, ne nyerhessen jegyet”*.
 * A játékos bejegyzése egy **sózott hash** alatt van a játék posztján, ezért a
 * törlést csak itt, a WordPress oldalán lehet elvégezni — ezt a viselkedést méri
 * ez a kör: CSAK a törölt játékos sora tűnik el, a nyertes jelölése is törlődik,
 * és minden más játékos érintetlen marad.
 *
 * Futtatás: php tools/verify-prize-forget.php /path/to/huhs-mobile-api
 */

$root = rtrim((string) ($argv[1] ?? ''), '/');
if ($root === '' || !is_dir($root)) {
    fwrite(STDERR, "Használat: php verify-prize-forget.php <plugin-mappa>\n");
    exit(2);
}

/* --- WordPress stubok (csak a méréshez kell ennyi) ------------------------ */

$GLOBALS['huhs_meta'] = array();      // [post_id][key] => value
$GLOBALS['huhs_posts'] = array();     // post_id => post_type
$GLOBALS['huhs_options'] = array();
$GLOBALS['huhs_deleted'] = array();   // napló: mit töröltünk

function absint($value) { return abs((int) $value); }
function sanitize_text_field($text) { return trim(strip_tags((string) $text)); }
function sanitize_key($key) { return preg_replace('/[^a-z0-9_\-]/', '', strtolower((string) $key)); }
function wp_unslash($value) { return is_string($value) ? stripslashes($value) : $value; }
function get_option($name, $default = false) { return $GLOBALS['huhs_options'][$name] ?? $default; }
function update_option($name, $value, $autoload = null) { $GLOBALS['huhs_options'][$name] = $value; return true; }
function current_time($format) { return date($format === 'Y-m-d H:i:s' ? 'Y-m-d H:i:s' : $format); }
function add_action(...$args) { return true; }
function add_filter(...$args) { return true; }
function add_meta_box(...$args) { return true; }
function register_post_type(...$args) { return true; }
function wp_nonce_field(...$args) { return ''; }
function esc_attr($value) { return htmlspecialchars((string) $value, ENT_QUOTES); }
function esc_html($value) { return htmlspecialchars((string) $value, ENT_QUOTES); }
function esc_url($value) { return (string) $value; }
function get_post_type($post_id) { return $GLOBALS['huhs_posts'][(int) $post_id] ?? null; }
function get_post($post_id) {
    $id = (int) $post_id;
    if (!isset($GLOBALS['huhs_posts'][$id])) return null;
    return (object) array('ID' => $id, 'post_type' => $GLOBALS['huhs_posts'][$id], 'post_status' => 'publish', 'post_title' => 'Teszt játék');
}
function get_posts($args = array()) {
    $out = array();
    foreach ($GLOBALS['huhs_posts'] as $id => $type) {
        if (($args['post_type'] ?? null) === $type) $out[] = $id;
    }
    return $out;
}
function get_post_meta($post_id, $key, $single = false) {
    return $GLOBALS['huhs_meta'][(int) $post_id][$key] ?? ($single ? '' : array());
}
function update_post_meta($post_id, $key, $value) {
    $GLOBALS['huhs_meta'][(int) $post_id][$key] = $value;
    return true;
}
function add_post_meta($post_id, $key, $value, $unique = false) {
    if ($unique && isset($GLOBALS['huhs_meta'][(int) $post_id][$key])) return false;
    return update_post_meta($post_id, $key, $value);
}
function delete_post_meta($post_id, $key) {
    unset($GLOBALS['huhs_meta'][(int) $post_id][$key]);
    $GLOBALS['huhs_deleted'][] = array((int) $post_id, (string) $key);
    return true;
}
function metadata_exists($meta_type, $post_id, $key) {
    return isset($GLOBALS['huhs_meta'][(int) $post_id][$key]);
}
function huhs_poll_repair_escapes($value) { return $value; }
function wp_slash($value) { return $value; }

// A REST-végpontok regisztrációja (a prize.php betöltésekor fut) — nem kell hozzá
// valódi WordPress, csak hogy ne haljon el a betöltés.
function register_rest_route(...$args) { return true; }
function __return_true() { return true; }
function is_wp_error($thing) { return $thing instanceof WP_Error; }
class WP_Error {
    public function __construct(public $code = '', public $message = '', public $data = null) {}
}
class WP_REST_Response {
    public function __construct(private $data = null) {}
    public function get_data() { return $this->data; }
}
class WP_REST_Request {
    private $params;
    public function __construct(array $params = array()) { $this->params = $params; }
    public function get_json_params() { return $this->params; }
}

require_once $root . '/includes/prize.php';

/* --- mérés ---------------------------------------------------------------- */

$failures = 0;
function check($label, $ok, $detail = '')
{
    global $failures;
    if (!$ok) $failures++;
    echo ($ok ? 'OK   ' : 'HIBA ') . $label . ($detail !== '' ? ' — ' . $detail : '') . "\n";
}

$PRIZE_A = 101;
$PRIZE_B = 202;
$GLOBALS['huhs_posts'][$PRIZE_A] = 'huhs_prize';
$GLOBALS['huhs_posts'][$PRIZE_B] = 'huhs_prize';
$GLOBALS['huhs_options']['huhs_prize_salt'] = 'teszt-so';

$target = 'uid-torolt-jatekos';
$other = 'uid-marad-jatekos';

$target_hash_a = huhs_prize_player_hash($PRIZE_A, $target);
$other_hash_a = huhs_prize_player_hash($PRIZE_A, $other);
$target_hash_b = huhs_prize_player_hash($PRIZE_B, $target);

check('a játékos-hash sózott (nem a nyers uid)', $target_hash_a !== $target && strlen($target_hash_a) === 64);

// Két játék: az egyikben a törölt játékos a NYERTES is, a másikban csak játékos.
update_post_meta($PRIZE_A, '_huhs_prize_entry_' . $target_hash_a, json_encode(array('name' => 'Törölt Játékos', 'correct' => true)));
update_post_meta($PRIZE_A, '_huhs_prize_entry_' . $other_hash_a, json_encode(array('name' => 'Maradó Játékos', 'correct' => true)));
update_post_meta($PRIZE_B, '_huhs_prize_entry_' . $target_hash_b, json_encode(array('name' => 'Törölt Játékos', 'correct' => true)));
update_post_meta($PRIZE_A, '_huhs_prize_winner_hash', $target_hash_a);
update_post_meta($PRIZE_A, '_huhs_prize_winner_name', 'Törölt Játékos');
update_post_meta($PRIZE_A, '_huhs_prize_winner_uid', $target);
update_post_meta($PRIZE_A, '_huhs_prize_winner_at', '2026-10-02 12:00:00');

$result = huhs_prize_forget_player($target);

check('a törölt játékos bejegyzése minden játékból eltűnt', $result['forgotten'] === 2, 'forgotten=' . $result['forgotten']);
check('a nyertes jelölése is törlődött', $result['winnersCleared'] === 1, 'winnersCleared=' . $result['winnersCleared']);
check('az érintett játékok listája helyes', $result['prizes'] === array($PRIZE_A, $PRIZE_B), implode(',', $result['prizes']));

check('a törölt játékos sora tényleg nincs meg (A)', !metadata_exists('post', $PRIZE_A, '_huhs_prize_entry_' . $target_hash_a));
check('a törölt játékos sora tényleg nincs meg (B)', !metadata_exists('post', $PRIZE_B, '_huhs_prize_entry_' . $target_hash_b));
check('a MÁSIK játékos sora ÉRINTETLEN', metadata_exists('post', $PRIZE_A, '_huhs_prize_entry_' . $other_hash_a));
check('a nyertes neve is törlődött', get_post_meta($PRIZE_A, '_huhs_prize_winner_name', true) === '');
check('a nyertes uid-ja is törlődött', get_post_meta($PRIZE_A, '_huhs_prize_winner_uid', true) === '');

// Idempotencia: másodszor már nincs mit törölni.
$again = huhs_prize_forget_player($target);
check('a művelet idempotens (másodszor 0)', $again['forgotten'] === 0 && $again['winnersCleared'] === 0,
    json_encode($again));

// Üres azonosító: nem töröl semmit, nem hibázik.
$empty = huhs_prize_forget_player('   ');
check('üres azonosítóval nem töröl semmit', $empty['forgotten'] === 0 && $empty['winnersCleared'] === 0);

// A végpont bekötése (a `prize_forget` művelet az admin végponton).
$admin_source = file_get_contents($root . '/includes/api-admin.php');
check('az admin végpont ismeri a prize_forget műveletet', strpos($admin_source, "=== 'prize_forget'") !== false);
check('a végpont a játékos törlését hívja', strpos($admin_source, 'huhs_prize_forget_player($uid)') !== false);
check('hiányzó uid esetén hibát ad', strpos($admin_source, "'missing_uid'") !== false);

echo "\n" . ($failures === 0 ? 'PRIZE-FORGET OK' : $failures . ' HIBA') . "\n";
exit($failures === 0 ? 0 : 1);
