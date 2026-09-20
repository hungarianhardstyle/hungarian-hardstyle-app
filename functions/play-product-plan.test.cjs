const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const { playProductMatches } = require('./play-product-plan');

/**
 * A „változatlan termék → nincs felesleges írás" döntés bizonyítása.
 *
 * ÉLES MÉRÉS (2026-09-20): a kiadvány-szinkron minden körben felküldte az összes
 * terméket a Play Console-ra (GET + PATCH termékenként), akkor is, ha semmi nem
 * változott — 5 percenként időtúllépéssel elhalt (~475 hibabejegyzés/24 óra).
 *
 * A javítás a BIZTONSÁGOS irány: a Play-válasz megmarad (a kézzel átírt terméket
 * továbbra is azonnal észrevesszük), csak a fölösleges PATCH marad el. Ennek a
 * döntésnek a helyességét méri ez a teszt: **csak akkor szabad kihagyni az
 * írást, ha a termék pontosan az, amit küldenénk**.
 *
 * Futtatás: node --test functions/play-product-plan.test.cjs
 */

const PACKAGE = 'hu.hungarianhardstyle.app';

/** Egy valósághű Play-válasz (a mezők a PATCH kérés törzsét tükrözik). */
function playProduct(overrides = {}) {
  const {
    title = 'Teszt kiadvány – Radio (WAV)',
    description = 'Hungarian Hardstyle Radio (WAV) letöltés: Teszt kiadvány',
    price = '700',
    availability = 'AVAILABLE',
    currency = 'HUF',
    nanos = 0,
    languages = ['hu-HU'],
    extraRegions = true,
    withBuyOption = true,
    withoutRegionCode = false,
  } = overrides;
  const configs = [
    {
      regionCode: withoutRegionCode ? '' : 'HU',
      availability,
      price: { currencyCode: currency, units: price, nanos },
    },
  ];
  if (extraRegions) configs.push({ regionCode: 'DE', availability: 'AVAILABLE', price: { currencyCode: 'EUR', units: '2', nanos: 0 } });
  return {
    packageName: PACKAGE,
    productId: 'huhs_release_12123_radio_wav',
    listings: languages.map((languageCode) => ({ languageCode, title, description })),
    purchaseOptions: [
      {
        purchaseOptionId: 'huhs-release-12123-radio-wav-option',
        ...(withBuyOption ? { buyOption: { legacyCompatible: true, multiQuantityEnabled: false } } : {}),
        regionalPricingAndAvailabilityConfigs: configs,
      },
    ],
  };
}

function desired(overrides = {}) {
  return {
    title: 'Teszt kiadvány – Radio (WAV)',
    description: 'Hungarian Hardstyle Radio (WAV) letöltés: Teszt kiadvány',
    price: 700,
    purchaseOptionId: 'huhs-release-12123-radio-wav-option',
    ...overrides,
  };
}

test('az azonos terméket felismeri (nincs szükség írásra)', () => {
  assert.equal(playProductMatches(playProduct(), desired()), true);
});

test('a megváltozott ÁR nem azonos (a PATCH nem maradhat el)', () => {
  assert.equal(playProductMatches(playProduct({ price: '550' }), desired({ price: 700 })), false);
  assert.equal(playProductMatches(playProduct({ price: '700' }), desired({ price: 550 })), false);
});

test('a fillérek (nanos) eltérése nem azonos', () => {
  assert.equal(playProductMatches(playProduct({ nanos: 500000000 }), desired()), false);
});

test('a megváltozott CÍM vagy LEÍRÁS nem azonos', () => {
  assert.equal(playProductMatches(playProduct(), desired({ title: 'Más cím' })), false);
  assert.equal(playProductMatches(playProduct(), desired({ description: 'Más leírás' })), false);
});

test('a nem elérhető (HU) régió nem azonos — azt javítani kell', () => {
  assert.equal(playProductMatches(playProduct({ availability: 'UNAVAILABLE' }), desired()), false);
});

test('a hiányzó HU régió nem azonos', () => {
  const product = playProduct();
  product.purchaseOptions[0].regionalPricingAndAvailabilityConfigs = [
    { regionCode: 'DE', availability: 'AVAILABLE', price: { currencyCode: 'EUR', units: '2', nanos: 0 } },
  ];
  assert.equal(playProductMatches(product, desired()), false);
});

test('a régió nélküli bejegyzés nem azonos (a PATCH eldobná)', () => {
  assert.equal(playProductMatches(playProduct({ withoutRegionCode: true }), desired()), false);
});

test('a hiányzó purchase option vagy buyOption nem azonos', () => {
  const noOption = playProduct();
  noOption.purchaseOptions = [];
  assert.equal(playProductMatches(noOption, desired()), false);
  assert.equal(playProductMatches(playProduct({ withBuyOption: false }), desired()), false);
});

test('a több nyelven kiírt termék nem azonos (a PATCH lecseréli a listát)', () => {
  assert.equal(playProductMatches(playProduct({ languages: ['hu-HU', 'en-US'] }), desired()), false);
  assert.equal(playProductMatches(playProduct({ languages: ['en-US'] }), desired()), false);
});

test('a hibás bemenet (ár, üres válasz) NEM azonos — nem hagyunk ki írást', () => {
  assert.equal(playProductMatches(null, desired()), false);
  assert.equal(playProductMatches(playProduct(), desired({ price: 0 })), false);
  assert.equal(playProductMatches(playProduct(), desired({ price: Number.NaN })), false);
  assert.equal(playProductMatches({}, desired()), false);
});

test('a szinkron valóban megkérdezi a döntést, mielőtt írna (bekötés)', () => {
  const source = fs.readFileSync(path.join(__dirname, 'index.js'), 'utf8');
  const start = source.indexOf('async function upsertPlayProduct(');
  const end = source.indexOf('async function updateWordPressReleaseProducts(', start);
  assert.ok(start > 0 && end > start, 'az upsertPlayProduct megtalálható');
  const body = source.slice(start, end);
  const check = body.indexOf('playProductMatches(');
  const patch = body.indexOf('.onetimeproducts.patch(');
  assert.ok(check > 0, 'a döntést meghívja');
  assert.ok(patch > 0, 'a PATCH megvan');
  assert.ok(check < patch, 'a döntés a PATCH ELŐTT van');
  assert.match(
    body.slice(check, patch),
    /return productId;/,
    'egyezésnél a PATCH előtt visszatér (nem küldi fel újra)',
  );
});

test('a döntés a valódi Play-választ kapja (nem a kérést használja alapnak)', () => {
  const source = fs.readFileSync(path.join(__dirname, 'index.js'), 'utf8');
  const call = source.slice(
    source.indexOf('if (playProductMatches('),
    source.indexOf('if (playProductMatches(') + 200,
  );
  assert.match(call, /playProductMatches\(current,/, 'az első argumentum a Play-válasz (current)');
});
