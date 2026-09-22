const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const {
  ARTIST_PROFILE_LIMITS,
  ARTIST_SOCIAL_KEYS,
  normalizeArtistProfileUpdate,
  artistEditAllowed,
  artistEditErrorMessage,
} = require('./artist-profile-plan');

/**
 * A CLAIMELT (ÁTVETT) DJ-ADATLAP SZERKESZTÉSÉNEK bizonyítása.
 *
 * A tulajdonos kérése (2026-09-22): *„Aki claimelte a dj adatlapját, tudja
 * szerkeszteni is."* A kérdező ablakban: **szövegek + közösségi linkek +
 * képcsere**.
 *
 * A döntés (mi mehet ki, mi nem) itt, tisztán mérhető — a WordPress-írás a
 * plugin új végpontján történik.
 */

const PLUGIN_ROOT = path.join(
  __dirname,
  '..',
  '.tmp-api-260',
  'huhs-mobile-api',
);

function pluginFile(relative) {
  return fs
    .readFileSync(path.join(PLUGIN_ROOT, relative), 'utf8')
    .replace(/\r\n/g, '\n');
}

test('szöveges mezők: vágás, üres érték, hossz-korlát', () => {
  const ok = normalizeArtistProfileUpdate({
    title: '  DJ Példa  ',
    realName: 'Példa Béla',
    city: 'Budapest',
    country: 'HU',
    biography: 'Első sor\nMásodik sor',
  });
  assert.equal(ok.ok, true);
  assert.deepEqual(ok.fields, {
    title: 'DJ Példa',
    real_name: 'Példa Béla',
    city: 'Budapest',
    country: 'HU',
    biography: 'Első sor\nMásodik sor',
  });

  const tooLong = normalizeArtistProfileUpdate({
    title: 'x'.repeat(ARTIST_PROFILE_LIMITS.title + 1),
  });
  assert.equal(tooLong.ok, false);
  assert.equal(tooLong.error, 'title-too-long');
  assert.match(tooLong.message, /legfeljebb 120 karakter/);

  const bioLong = normalizeArtistProfileUpdate({
    biography: 'x'.repeat(ARTIST_PROFILE_LIMITS.biography + 1),
  });
  assert.equal(bioLong.error, 'biography-too-long');
});

test('üres név nem megy ki (a post_title nem lehet üres)', () => {
  const result = normalizeArtistProfileUpdate({ title: '   ', city: 'Pécs' });
  assert.equal(result.ok, true);
  assert.equal('title' in result.fields, false);
  assert.equal(result.fields.city, 'Pécs');
});

test('vezérlőkaraktert nem fogadunk el', () => {
  const result = normalizeArtistProfileUpdate({ city: 'Buda\u0007pest' });
  assert.equal(result.ok, false);
  assert.equal(result.error, 'control-chars');
});

test('linkek: teljes http(s) cím kell, üres érték töröl', () => {
  const ok = normalizeArtistProfileUpdate({
    socialLinks: {
      website: 'https://peldadj.hu',
      instagram: 'http://instagram.com/peldadj',
      facebook: '',
    },
  });
  assert.equal(ok.ok, true);
  assert.equal(ok.fields.website, 'https://peldadj.hu/');
  assert.equal(ok.fields.instagram, 'http://instagram.com/peldadj');
  assert.equal(ok.fields.facebook, '', 'az üres érték törli a linket');

  for (const bad of [
    'javascript:alert(1)',
    'data:text/html;base64,AAAA',
    'peldadj.hu',
    'https://',
    '   ',
  ]) {
    const result = normalizeArtistProfileUpdate({ socialLinks: { website: bad } });
    if (bad.trim() === '') continue;
    assert.equal(result.ok, false, `nem szabad átengedni: ${bad}`);
    assert.equal(result.error, 'link-invalid');
  }

  const long = normalizeArtistProfileUpdate({
    socialLinks: { website: `https://peldadj.hu/${'x'.repeat(400)}` },
  });
  assert.equal(long.error, 'link-invalid');
});

test('a közösségi kulcsok zárt listából jönnek (ismeretlen eldobva)', () => {
  const result = normalizeArtistProfileUpdate({
    socialLinks: { website: 'https://a.hu', nemLetezo: 'https://b.hu' },
  });
  assert.equal(result.ok, true);
  assert.deepEqual(Object.keys(result.fields), ['website']);
  assert.deepEqual(ARTIST_SOCIAL_KEYS, [
    'website',
    'facebook',
    'instagram',
    'tiktok',
    'spotify',
    'soundcloud',
    'youtube',
  ]);
});

test('kép: csak a saját Cloudinary-fiókunkról, https-sel', () => {
  const ok = normalizeArtistProfileUpdate({
    profileImageUrl:
      'https://res.cloudinary.com/fjxo93em/image/upload/v1/huhs/dj.jpg',
    coverImageUrl:
      'https://res.cloudinary.com/fjxo93em/image/upload/v1/huhs/cover.jpg',
  });
  assert.equal(ok.ok, true);
  assert.match(ok.fields.logo_url, /^https:\/\/res\.cloudinary\.com\//);
  assert.match(ok.fields.hero_image_url, /^https:\/\/res\.cloudinary\.com\//);

  for (const bad of [
    'https://valaki-mas.hu/kep.jpg',
    'http://res.cloudinary.com/fjxo93em/image/upload/x.jpg',
    'https://evil.com/?u=res.cloudinary.com',
    '',
  ]) {
    const result = normalizeArtistProfileUpdate({ profileImageUrl: bad });
    assert.equal(result.ok, false, `nem szabad átengedni: ${bad}`);
    assert.equal(result.error, 'image-not-cloudinary');
  }
});

test('⚠️ a booking e-mail és a ház döntései NEM szerkeszthetők innen', () => {
  // Ez a lényeg: a booking e-mail igazolja az átvételt — ha a DJ átírhatná,
  // egy másik fiók is átvehetné az adatlapot.
  const result = normalizeArtistProfileUpdate({
    title: 'Új név',
    booking_email: 'tamadó@sajatdomain.hu',
    contact_email: 'mas@gmail.com',
    visible: true,
    featured: true,
    booking_via_huhs: false,
    genre: 'hardstyle',
    slug: 'hackelt-slug',
  });
  assert.equal(result.ok, true);
  assert.deepEqual(result.fields, { title: 'Új név' });
  assert.equal('booking_email' in result.fields, false);
  assert.equal('contact_email' in result.fields, false);
  assert.equal('visible' in result.fields, false);
  assert.equal('featured' in result.fields, false);
  assert.equal('booking_via_huhs' in result.fields, false);
  assert.equal('genre' in result.fields, false);
});

test('üres bemenet nem indít írást', () => {
  for (const input of [{}, { ismeretlen: 'x' }, null, undefined, 'szöveg']) {
    const result = normalizeArtistProfileUpdate(input);
    assert.equal(result.ok, false);
    assert.equal(result.error, 'empty');
    assert.equal(result.message, 'Nem érkezett menthető adat.');
  }
});

test('rossz típus (szám/lista) nem megy ki szövegként', () => {
  assert.equal(normalizeArtistProfileUpdate({ title: 42 }).error, 'invalid-type');
  assert.equal(
    normalizeArtistProfileUpdate({ socialLinks: ['https://a.hu'] }).error,
    'invalid-type',
  );
});

test('ki szerkesztheti: csak az átvevő fiók', () => {
  assert.deepEqual(artistEditAllowed({ claimUid: 'u1', callerUid: 'u1' }), {
    allowed: true,
    reason: '',
  });
  assert.deepEqual(artistEditAllowed({ claimUid: 'u1', callerUid: 'u2' }), {
    allowed: false,
    reason: 'not-owner',
  });
  assert.deepEqual(artistEditAllowed({ claimUid: '', callerUid: 'u2' }), {
    allowed: false,
    reason: 'not-claimed',
  });
  assert.equal(artistEditAllowed({}).allowed, false);
  assert.match(artistEditErrorMessage('not-owner'), /másik fiókhoz tartozik/);
  assert.match(artistEditErrorMessage('not-claimed'), /nincs átvéve/);
});

test('FORRÁS-LINT: a szerver a tiszta szabályt használja, és ELLENŐRZI az átvételt', () => {
  const source = fs.readFileSync(path.join(__dirname, 'index.js'), 'utf8');
  const start = source.indexOf('exports.updateClaimedArtistProfile');
  assert.ok(start > 0, 'nincs updateClaimedArtistProfile callable');
  const body = source.slice(start, start + 3600);

  // 1. Bejelentkezés kell (vendég nem szerkeszthet).
  assert.match(body, /sign_in_provider === 'anonymous'/);
  // 2. Az átvétel ellenőrzése a Firestore-ból, a tiszta szabállyal.
  assert.match(body, /collection\('artist_claims'\)\.doc\(String\(artistId\)\)\.get\(\)/);
  assert.match(body, /artistEditAllowed\(\{/);
  assert.match(body, /artistEditErrorMessage\(guard\.reason\)/);
  // 3. A bemenet a tiszta modulon megy át (nem közvetlenül a WP-nek).
  assert.match(body, /normalizeArtistProfileUpdate\(data\?\.fields\)/);
  assert.match(body, /JSON\.stringify\(normalized\.fields\)/);
  // 4. A PRIVÁT WordPress-útvonal (nem a nyilvános `/artists`).
  assert.match(body, /\/dj-profile\/\$\{artistId\}/);
  // 5. A hívó uid-je a HITELESÍTETT tokenből jön (nem a kliens küldi).
  assert.match(body, /callerUid: context\.auth\.uid/);
  assert.ok(
    !/data\?\.uid/.test(body),
    'a kliens nem mondhatja meg, ki ő',
  );
});

test('FORRÁS-LINT: a plugin új végpontja POST + manage_options, és a gyorsítótárból KIZÁRT', () => {
  const api = pluginFile('includes/api-artists.php');
  const route = api.slice(api.indexOf("'/dj-profile/(?P<id>\\d+)'"));
  assert.ok(route.length > 0, 'nincs /dj-profile útvonal');
  assert.match(route, /WP_REST_Server::CREATABLE/);
  assert.match(route, /current_user_can\('manage_options'\)/);
  // A mezőnevek a WP mezőnevei, és a tiltott mezők nincsenek a listában.
  const fields = api.slice(
    api.indexOf('function huhs_artist_editable_fields()'),
    api.indexOf('function huhs_artist_sanitize_editable_value'),
  );
  for (const writable of ['real_name', 'city', 'country', 'website', 'instagram']) {
    assert.match(fields, new RegExp(`'${writable}'`));
  }
  for (const forbidden of ['booking_email', 'contact_email', 'visible', 'featured', 'genre']) {
    assert.ok(
      !fields.includes(`'${forbidden}'`),
      `${forbidden} nem lehet a szerkeszthető mezők között`,
    );
  }
  // A kép-csere csak Cloudinary linket fogad el, és nullázza az attachmentet.
  assert.match(api, /res\.cloudinary\.com/);
  assert.match(api, /update_post_meta\(\$artist_id, \$attachment_key, 0\)/);
  // A meta-írás NEM üríti a gyorsítót magától — itt kifejezetten kérjük.
  assert.match(api, /huhs_invalidate_public_cache\(\)/);

  // ⚠️ A gyorsítótár engedélylistája a privát al-útvonalakat kizárja.
  const cache = pluginFile('includes/http-cache.php');
  const fn = cache.slice(
    cache.indexOf('function huhs_public_cache_route($route)'),
    cache.indexOf('function huhs_public_cache_version()'),
  );
  assert.match(fn, /'\/claim-emails'/);
  assert.match(fn, /'\/dj-profile'/);
  assert.match(fn, /return false;/);
});

test('FORRÁS-LINT: a plugin verziója 2.7.0', () => {
  const main = pluginFile('huhs-mobile-api.php');
  assert.match(main, /\* Version: 2\.7\.0/);
  assert.match(main, /define\('HUHS_API_VERSION', '2\.7\.0'\)/);
});
