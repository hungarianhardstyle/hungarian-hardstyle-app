const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const {
  LABEL_VARIANTS,
  parseLabelProductId,
  adUnlockedVariants,
  adUnlockGrantsVariant,
  labelLibraryPayload,
} = require('./label-library-plan');

/**
 * A „Saját zenéim" könyvtár összeállításának bizonyítása.
 *
 * A tulajdonos kérése: *„kéne egy user specifikus menüpont a megvett zenékre,
 * ahol le tudja játszani… le is tudja tölteni újra, úgymond megmarad ott a
 * megvásárolt zenéje"*.
 *
 * A jogosultság ÉVEK ÓTA megvan a Firestore-ban (`label_entitlements`), a
 * reklámmal feloldottak is (`label_ad_unlocks`), de **egyik listát sem kérdezte
 * le soha senki**. Ez a modul az egyetlen hely, ahol eldől, mi kerül a
 * könyvtárba — ezért itt mérjük, és nem a felületen.
 *
 * Futtatás: node --test functions/label-library-plan.test.cjs
 */

/** Egy valósághű jogosultság-rekord (a `verifyLabelPurchase` írja így). */
function entitlement(releaseId, variant, overrides = {}) {
  return {
    uid: 'uid-1',
    releaseId,
    productId: `huhs_release_${releaseId}_${variant}`,
    purchaseTokenHash: `hash-${releaseId}-${variant}`,
    orderId: `GPA.${releaseId}.${variant}`,
    verifiedAt: { _seconds: 1_700_000_000, toMillis: () => 1_700_000_000_000 },
    ...overrides,
  };
}

test('a termék-azonosító minden vásárolható változatot felismer', () => {
  for (const variant of LABEL_VARIANTS) {
    assert.deepEqual(parseLabelProductId(`huhs_release_12699_${variant}`), {
      releaseId: 12699,
      variant,
    });
  }
});

test('a hibás termék-azonosító nem tippel (kimarad a könyvtárból)', () => {
  const bad = [
    '',
    null,
    undefined,
    'huhs_release_',
    'huhs_release_abc_wav',
    'huhs_release_0_wav',
    'huhs_release_-3_wav',
    'huhs_release_12699',
    'huhs_release_12699_flac',
    'huhs_release_12699_wav_extra',
    'huhs_release_12699_ WAV',
    'valami_mas_12699_wav',
  ];
  for (const productId of bad) {
    assert.equal(parseLabelProductId(productId), null, String(productId));
  }
});

test('egy kiadvány több változata EGY sorba kerül, rendezett sorrendben', () => {
  const payload = labelLibraryPayload(
    [
      entitlement(100, 'extended_mp3_320'),
      entitlement(100, 'radio_wav'),
      entitlement(100, 'radio_wav'), // ugyanaz kétszer (újra-ellenőrzés)
    ],
    [],
  );
  assert.equal(payload.count, 1);
  assert.deepEqual(payload.items[0].purchased, ['radio_wav', 'extended_mp3_320']);
  assert.deepEqual(payload.items[0].variants, ['radio_wav', 'extended_mp3_320']);
  assert.deepEqual(payload.items[0].unlocked, []);
});

test('a legfrissebb kiadvány van elöl', () => {
  const payload = labelLibraryPayload(
    [entitlement(100, 'wav'), entitlement(305, 'wav'), entitlement(200, 'wav')],
    [],
  );
  assert.deepEqual(
    payload.items.map((item) => item.releaseId),
    [305, 200, 100],
  );
});

test('a reklámmal feloldott változat külön jelölést kap (nem vásárlás)', () => {
  const payload = labelLibraryPayload(
    [entitlement(100, 'radio_wav')],
    [{ uid: 'uid-1', releaseId: 100, variant: 'mp3_128' }],
  );
  assert.deepEqual(payload.items[0].purchased, ['radio_wav']);
  assert.deepEqual(payload.items[0].unlocked, ['mp3_128']);
  assert.deepEqual(payload.items[0].variants, ['radio_wav', 'mp3_128']);
});

test('a régi (változat nélküli) reklám-feloldás az eredeti 128 kbps jutalmat adja', () => {
  // Ugyanaz a szabály, mint a letöltés-végpontnál — a könyvtár nem mondhat
  // mást, mint amit a letöltés engedélyez.
  assert.deepEqual(adUnlockedVariants({ releaseId: 100 }, 100), ['mp3_128']);
  assert.deepEqual(
    adUnlockedVariants({ releaseId: 100, variants: { mp3_96: true } }, 100),
    ['mp3_96'],
  );
  assert.deepEqual(adUnlockedVariants({ releaseId: 999 }, 100), [], 'más kiadvány');
  assert.deepEqual(adUnlockedVariants(null, 100), []);
});

test('⚠️ a `free_link` (külső linkes ingyenes kiadvány) feloldása MŰKÖDIK', () => {
  // ÉLES HIBA VOLT (a tulajdonos jelzése): *„a jutalmazott külső linkes ingyenes
  // kiadvány feloldása nem működik"*. Az ok: a `free_link` **nincs** a
  // `LABEL_VARIANTS`-ban (nem fájl, hanem külső link), ezért az
  // `adUnlockedVariants(...)` **soha** nem adta vissza, a kapu pedig
  // (`adUnlockedVariants(...).includes('free_link')`) **mindig** elutasított —
  // a felület hiába várta a jóváírást.
  const unlock = { uid: 'uid-1', releaseId: 100, variants: { free_link: true } };
  assert.equal(adUnlockGrantsVariant(unlock, 100, 'free_link'), true);
  assert.equal(adUnlockGrantsVariant(unlock, 100, 'mp3_96'), false);
  assert.equal(adUnlockGrantsVariant(unlock, 100, 'free_wav'), false);
  assert.equal(adUnlockGrantsVariant(unlock, 999, 'free_link'), false, 'más kiadvány');
  assert.equal(adUnlockGrantsVariant(null, 100, 'free_link'), false);
  assert.deepEqual(
    adUnlockedVariants(unlock, 100),
    [],
    'a könyvtárba továbbra sem kerül be a free_link (nem lejátszható fájl)',
  );
  // A `free_link` a régi `variant` mezőben is működik.
  assert.equal(
    adUnlockGrantsVariant({ releaseId: 100, variant: 'free_link' }, 100, 'free_link'),
    true,
  );
});

test('a pontos változat-szabály a fájl-változatoknál ugyanazt adja, mint eddig', () => {
  const unlock = { releaseId: 100, variants: { mp3_96: true, mp3_128: true } };
  for (const variant of ['mp3_96', 'mp3_128']) {
    assert.equal(adUnlockGrantsVariant(unlock, 100, variant), true, variant);
  }
  for (const variant of ['free_wav', 'wav', 'mp3_320', 'radio_wav']) {
    assert.equal(adUnlockGrantsVariant(unlock, 100, variant), false, variant);
  }
  // Régi, változat nélküli dokumentum: az eredeti 128 kbps jutalom.
  assert.equal(adUnlockGrantsVariant({ releaseId: 100 }, 100, 'mp3_128'), true);
  assert.equal(adUnlockGrantsVariant({ releaseId: 100 }, 100, 'mp3_96'), false);
  assert.equal(adUnlockGrantsVariant({ releaseId: 100 }, 100, 'free_link'), false);
  assert.equal(adUnlockGrantsVariant({ releaseId: 100 }, 100, ''), false);
});

test('amit megvett, az nem szerepel „reklámmal feloldva" is', () => {
  const payload = labelLibraryPayload(
    [entitlement(100, 'mp3_128')],
    [{ uid: 'uid-1', releaseId: 100, variants: { mp3_128: true, mp3_96: true } }],
  );
  assert.deepEqual(payload.items[0].purchased, ['mp3_128']);
  assert.deepEqual(payload.items[0].unlocked, ['mp3_96']);
});

test('az ellentmondásos jogosultság kimarad (nem tippelünk)', () => {
  // A dokumentum releaseId-ja nem egyezik a termék-azonosítóban lévővel: ez
  // adathiba, nem szabad belőle könyvtárat építeni.
  const payload = labelLibraryPayload(
    [entitlement(100, 'wav', { releaseId: 200 })],
    [],
  );
  assert.equal(payload.count, 0);
});

test('FORRÁS-LINT: a könyvtár-végpont a SAJÁT uid-re szűr, és a közös szabályt használja', () => {
  const source = fs.readFileSync(path.join(__dirname, 'index.js'), 'utf8');
  const start = source.indexOf('exports.getMyLabelLibrary');
  assert.ok(start > 0, 'nincs getMyLabelLibrary végpont');
  const body = source.slice(start, start + 2200);

  // 1. Bejelentkezés kell (vendég nem kaphat könyvtárat).
  assert.match(body, /sign_in_provider === 'anonymous'/);
  // 2. A szűrés a HITELESÍTETT uid-del történik, nem a kliens által küldöttel.
  assert.match(body, /const uid = context\.auth\.uid/);
  assert.match(body, /\.where\('uid', '==', uid\)/);
  assert.ok(
    !/data\?\.uid/.test(body),
    'a kliens nem kérhet le más felhasználót',
  );
  // 3. A döntés a közös, tesztelt modulban van.
  assert.match(body, /labelLibraryPayload\(/);
  // 4. A letöltés-kapu UGYANAZT a szabályt használja (nem csúszhat el) — és
  //    **pontos változatra** kérdez, mert a `free_link` nincs a fájl-listában.
  assert.match(source, /return adUnlockGrantsVariant\(data, releaseId, variant\);/);
  assert.ok(
    !/activeAdUnlock[\s\S]{0,200}adUnlockedVariants\(data, releaseId\)\.includes\(variant\)/.test(
      source,
    ),
    'a free_link-et elnyelő régi szabály nem térhet vissza',
  );
});
