/**
 * A DJ-adatlap PRIVÁT (kapcsolattartó) e-mail címének láthatósága és javíthatósága
 * — plugin 2.9.0.
 *
 * **A tulajdonos jelzése (2026-09-24):** *„kérésre nem tudom átírni egy artist/dj
 * privát mail címét se a WP Apiban se a natív huhs vezérlőben. Meg látni se látom
 * sehol, pedig igény lenne mindkettőre, főleg ha elbaszta a delikvens."*
 *
 * **A mért gyökér:** a `contact_email` meta (ez a privát cím, ami a beküldésből
 * kerül át, és az adatlap átvételét is igazolja):
 *  * a **natív admin** mezőlistájából (`huhs_admin_resource_fields('huhs_artist')`)
 *    hiányzott — pedig a `booking_email` benne volt,
 *  * a **WordPress admin** DJ-meta-boxából (`huhs_artist_meta_box_callback`)
 *    szintén hiányzott,
 *  * és a mentés (`huhs_save_artist_meta`) sem ismerte.
 *
 * **A javítás:** mindhárom helyre bekerült — a natív adminban a mező
 * szerver-vezérelt, ezért **nem kellett új app**.
 *
 * ⚠️ Amit ez a teszt **őriz**: a privát cím továbbra sem kerülhet a **nyilvános**
 * adatlap válaszába (`huhs_build_artist_response`) — az csak a védett
 * `claim-emails` végponton jön ki.
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

/** A `huhs_admin_resource_fields()` DJ-ága. */
function artistAdminFields() {
  const source = pluginFile('includes/api-admin.php');
  const start = source.indexOf("$post_type === 'huhs_artist'");
  assert.ok(start > 0, 'megvan a DJ-ág az admin mezőlistában');
  const end = source.indexOf("$post_type === 'huhs_organizer'", start);
  return source.slice(start, end);
}

test('a natív admin mezőlistája tartalmazza a privát e-mailt', () => {
  const section = artistAdminFields();
  assert.match(
    section,
    /'key'\s*=>\s*'contact_email'/,
    'a privát cím mezőként szerepel (különben se látni, se írni nem lehet)',
  );
  assert.match(
    section,
    /'key'\s*=>\s*'contact_email'[\s\S]{0,200}?'type'\s*=>\s*'email'/,
    "a típusa `email`, ezért a mentés `sanitize_email`-en megy át",
  );
  assert.match(section, /'key'\s*=>\s*'booking_email'/, 'a nyilvános cím is a helyén van');
});

test('a WordPress admin DJ-meta-boxa is mutatja a privát e-mailt', () => {
  const box = pluginFile('includes/artists.php');
  assert.match(box, /huhs_text_field\(\$post,\s*'contact_email'/);
  assert.match(box, /huhs_text_field\(\$post,\s*'booking_email'/);
});

test('a WP admin mentése is írja a privát e-mailt, sanitize_email-lel', () => {
  const save = pluginFile('includes/artist-save.php');
  assert.match(save, /'contact_email',/, 'benne van a mentett mezők listájában');
  assert.match(
    save,
    /if \(\$field === 'booking_email' \|\| \$field === 'contact_email'\)[\s\S]{0,120}sanitize_email/,
    'a privát cím is e-mail szűrőn megy át',
  );
});

test('a PRIVÁT cím nem kerülhet a nyilvános adatlap válaszába', () => {
  const api = pluginFile('includes/api-artists.php');
  const start = api.indexOf('function huhs_build_artist_response');
  assert.ok(start > 0, 'megvan a nyilvános válasz építője');
  const end = api.indexOf('function huhs_get_artist_upcoming_events', start);
  const section = api.slice(start, end);
  assert.equal(
    section.includes("'contact_email'"),
    false,
    'a nyilvános payload nem tartalmazhat privát címet',
  );
  assert.match(section, /'booking_email'/, 'a nyilvános booking cím viszont marad');
});

test('a privát cím a védett claim-emails végponton továbbra is kijön', () => {
  const api = pluginFile('includes/api-artists.php');
  assert.match(api, /'contact_email'\s*=>\s*strtolower\(\(string\)\s*sanitize_email\(get_post_meta/);
});

test('a plugin verziója 2.9.0', () => {
  const main = pluginFile('huhs-mobile-api.php');
  assert.match(main, /^\s*\*\s*Version:\s*2\.9\.0\s*$/m);
  assert.match(main, /HUHS_API_VERSION',\s*'2\.9\.0'/);
});
