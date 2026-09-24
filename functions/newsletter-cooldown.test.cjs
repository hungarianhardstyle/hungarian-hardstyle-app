/**
 * Hírlevél-feliratkozás: ugyanarra az e-mail-címre ne menjen ki korlátlanul a
 * megerősítő levél — plugin 2.10.0.
 *
 * **A tulajdonos jelzése (2026-09-24):** *„hírlevél feliratkozásnál ugyanazt az
 * email címet bármennyiszer be tudják küldeni és kimegy az ellenőrző mail is,
 * kéne valami ellenörzés erre, ha már feliratkozott"* — és a megerősítés:
 * *„mailchimpre megy a feliratkozás"*.
 *
 * **A mért gyökér (a kódból):** a `/newsletter/subscribe` végpont a Mailchimp
 * `members/{hash}` állapotát kiolvasta ugyan, de **csak a `subscribed`** esetben
 * állt meg. Ha a cím `pending` (kiment a megerősítő levél, de nem kattintottak),
 * akkor **minden beküldés** egy új `PUT status=pending` hívást indított a
 * Mailchimpre — és a Mailchimp ilyenkor **újra kiküldi** a megerősítő levelet.
 * Vagyis egy felületen korlátlanul lehetett levelet generálni ugyanarra a címre
 * (a szavazási ág pedig hozzájárulásnál szintén ezt a végpontot hívja).
 *
 * **A javítás:** e-mailenkénti várakozás (WP transient, alapból 15 perc) — a
 * Mailchimp-hívást meg sem indítjuk a várakozáson belül, a válasz viszont
 * sikeres (`already_requested`), hogy a régi app se lásson hibát.
 *
 * ⚠️ Amit ez a teszt **őriz**: a védelem a Mailchimp-hívás ELŐTT legyen, a
 * várakozás csak SIKERES kérés után induljon, és a válasz mindhárom ágban
 * sikeres (`subscribed => true`) maradjon.
 */

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const PLUGIN_ROOT = path.join(__dirname, '..', '.tmp-api-260', 'huhs-mobile-api');

function pluginFile(relative) {
  return fs
    .readFileSync(path.join(PLUGIN_ROOT, relative), 'utf8')
    .replace(/\r\n/g, '\n');
}

/** A `huhs_newsletter_subscribe()` teljes törzse. */
function subscribeBody() {
  const source = pluginFile('includes/newsletter.php');
  const start = source.indexOf('function huhs_newsletter_subscribe(');
  assert.ok(start > 0, 'megvan a feliratkozás végpont');
  const end = source.indexOf("add_action('admin_menu'", start);
  assert.ok(end > start, 'a végpont törzse lehatárolható');
  return source.slice(start, end);
}

/** A `huhs_ip_rate_limited()` helper — az IP-korlát maradjon meg. */
function rateLimitCall() {
  return subscribeBody().indexOf("huhs_ip_rate_limited('newsletter_subscribe'");
}

test('a végpont az IP-korlátot megtartja (a cím-védelem mellett)', () => {
  assert.ok(rateLimitCall() > 0, 'az IP-alapú korlát nem tűnt el');
});

test('e-mailenkénti várakozás van, és az a Mailchimp-hívás ELŐTT dönt', () => {
  const body = subscribeBody();
  const cooldownKey = body.indexOf("'huhs_newsletter_requested_'");
  assert.ok(cooldownKey > 0, 'a várakozás kulcsa a cím hash-éből készül');

  // A kulcs a címhez kötött (nem az IP-hez), különben más címeket is blokkolna.
  assert.match(
    body,
    /'huhs_newsletter_requested_'\s*\.\s*\$subscriber_hash/,
    'a várakozás a címhez (subscriber_hash) kötődik',
  );

  const earlyReturn = body.indexOf("'already_requested' => true");
  assert.ok(earlyReturn > 0, 'van korai, sikeres válasz a várakozáshoz');

  // ⚠️ A feltétel PONTOS alakja is őrzött: a „csak pozíciót néző" ellenőrzés
  // átengedné azt a mutációt, amely a kaput kikapcsolja (pl. `if (false && …)`).
  assert.match(
    body,
    /if \(\$cooldown > 0 && \$last_requested > 0\) \{/,
    'a várakozás kapuja valóban a várakozást figyeli (nem kiiktatott feltétel)',
  );
  assert.match(
    body,
    /\$last_requested = \(int\) get_transient\(\$cooldown_key\);/,
    'a várakozás a transientből, a címhez tartozó kulccsal jön',
  );

  const firstWrite = Math.min(
    ...[body.indexOf('wp_remote_post('), body.indexOf('wp_remote_request(')].filter(
      (index) => index > 0,
    ),
  );
  assert.ok(
    earlyReturn < firstWrite,
    'a várakozás ELLENŐRZÉSE megelőzi a Mailchimp-írásokat (különben kimegy a levél)',
  );
  assert.ok(
    body.indexOf('get_transient($cooldown_key)') < earlyReturn,
    'a várakozást a transientből olvassuk ki',
  );
  assert.ok(
    body.indexOf("'retry_after' =>") < firstWrite,
    'a válasz megmondja, mennyi van hátra',
  );
});

test('a várakozás hossza állítható, és van alapértéke', () => {
  const body = subscribeBody();
  assert.match(
    body,
    /apply_filters\(\s*'huhs_newsletter_resend_cooldown'/,
    'a várakozás szűrővel állítható',
  );
  assert.match(
    body,
    /apply_filters\(\s*'huhs_newsletter_resend_cooldown',\s*15 \* MINUTE_IN_SECONDS\s*\)/,
    'az alapérték 15 perc',
  );
});

test('a várakozás csak SIKERES Mailchimp-válasz után indul', () => {
  const body = subscribeBody();
  const setIndex = body.indexOf('set_transient($cooldown_key, time(), $cooldown)');
  const errorReturn = body.indexOf("new WP_Error('newsletter_failed'");
  assert.ok(setIndex > 0, 'a sikeres kérés beállítja a várakozást');
  assert.ok(
    errorReturn > 0 && errorReturn < setIndex,
    'egy hibás kísérlet NEM zárja ki a címest a valódi újrapróbálkozásból',
  );
  assert.match(
    body.slice(setIndex - 200, setIndex),
    /if \(\$cooldown > 0\)/,
    'kikapcsolt védelemnél (0) nem írunk transientet',
  );
});

test('a már feliratkozott cím továbbra is korán, levél nélkül tér vissza', () => {
  const body = subscribeBody();
  const subscribed = body.indexOf("$existing_status === 'subscribed'");
  assert.ok(subscribed > 0, 'a Mailchimp `subscribed` állapotát figyeljük');
  assert.match(
    body.slice(subscribed, subscribed + 400),
    /'already_subscribed' => true/,
    'a feliratkozott cím jelzést kap',
  );
  assert.ok(
    subscribed < body.indexOf("'huhs_newsletter_requested_'"),
    'a feliratkozott ellenőrzés az első (nem küldünk felesleges levelet)',
  );
});

test('a válasz mindhárom ágban sikeres (a régi app ne lásson hibát)', () => {
  const body = subscribeBody();
  const successResponses = body.match(/new WP_REST_Response\(/g) ?? [];
  assert.equal(successResponses.length, 3, 'három sikeres ág: megerősítve / várakozik / kiment');
  const subscribedFlags = body.match(/'subscribed' => true/g) ?? [];
  assert.equal(subscribedFlags.length, 3, 'mindhárom válaszban `subscribed => true` van');
  assert.match(body, /'state' => 'subscribed'/);
  assert.match(body, /'state' => 'confirmation_pending'/);
  assert.match(body, /'state' => 'confirmation_sent'/);
});

test('a plugin verziója 2.10.0 (mindkét helyen)', () => {
  const main = pluginFile('huhs-mobile-api.php');
  assert.match(main, /Version:\s*2\.10\.0/);
  assert.match(main, /define\('HUHS_API_VERSION',\s*'2\.10\.0'\)/);
});
