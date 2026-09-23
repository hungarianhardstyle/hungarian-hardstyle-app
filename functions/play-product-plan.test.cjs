const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const {
  playProductMatches,
  purchaseOptionStateAction,
  regionalPricingConfigs,
  regionalPriceFor,
  mergeRegionalConfigs,
  LABEL_PRODUCT_REGIONS,
} = require('./play-product-plan');

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

/**
 * Egy valósághű Play-válasz (a mezők a PATCH kérés törzsét tükrözik).
 *
 * ⚠️ A régiók a **kívánt** listából épülnek (nem kézzel beírt `HU`-ból): a
 * „rendben lévő" termék a 2026-09-22-i javítás óta **minden** országot
 * tartalmaz, ahol az app elérhető. Az árak helyességét külön teszt rögzíti
 * konkrét értékekkel (lásd „a helyi árak…" tesztet), ezért itt nem önkényes a
 * kör: a **negatív** esetek (hiányzó régió, rossz ár) mérik a lényeget.
 */
function playProduct(overrides = {}) {
  const {
    title = 'Teszt kiadvány – Radio (WAV)',
    description = 'Hungarian Hardstyle Radio (WAV) letöltés: Teszt kiadvány',
    price = 700,
    languages = ['hu-HU'],
    extraRegions = true,
    withBuyOption = true,
    withoutRegionCode = false,
    mutateConfigs = null,
  } = overrides;
  let configs = regionalPricingConfigs(price);
  if (withoutRegionCode) {
    configs = [{ ...configs[0], regionCode: '' }, ...configs.slice(1)];
  }
  if (extraRegions) {
    // Kézzel (a Play Console-ban) beállított ország: a mi listánkban nincs benne,
    // ezért a PATCH-nek és a döntésnek is **meg kell tartania**.
    configs = [
      ...configs,
      { regionCode: 'DE', availability: 'AVAILABLE', price: { currencyCode: 'EUR', units: '2', nanos: 0 } },
    ];
  }
  if (mutateConfigs) configs = mutateConfigs(configs);
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
  const price = overrides.price === undefined ? 700 : overrides.price;
  const validPrice = Number.isInteger(price) && price > 0;
  return {
    title: 'Teszt kiadvány – Radio (WAV)',
    description: 'Hungarian Hardstyle Radio (WAV) letöltés: Teszt kiadvány',
    price,
    purchaseOptionId: 'huhs-release-12123-radio-wav-option',
    // Érvénytelen árnál nincs mit származtatni — ilyenkor a döntés az ár miatt
    // úgyis „nem egyezik" (és az üres lista is azt jelenti).
    regions: validPrice ? regionalPricingConfigs(price) : [],
    ...overrides,
  };
}

test('az azonos terméket felismeri (nincs szükség írásra)', () => {
  assert.equal(playProductMatches(playProduct(), desired()), true);
});

test('a megváltozott ÁR nem azonos (a PATCH nem maradhat el)', () => {
  assert.equal(playProductMatches(playProduct({ price: 550 }), desired({ price: 700 })), false);
  assert.equal(playProductMatches(playProduct({ price: 700 }), desired({ price: 550 })), false);
});

test('a fillérek (nanos) eltérése nem azonos', () => {
  const product = playProduct({
    mutateConfigs: (configs) =>
      configs.map((item) =>
        item.regionCode === 'HU'
          ? { ...item, price: { ...item.price, nanos: 500000000 } }
          : item,
      ),
  });
  assert.equal(playProductMatches(product, desired()), false);
});

test('a megváltozott CÍM vagy LEÍRÁS nem azonos', () => {
  assert.equal(playProductMatches(playProduct(), desired({ title: 'Más cím' })), false);
  assert.equal(playProductMatches(playProduct(), desired({ description: 'Más leírás' })), false);
});

test('a nem elérhető (HU) régió nem azonos — azt javítani kell', () => {
  const product = playProduct({
    mutateConfigs: (configs) =>
      configs.map((item) =>
        item.regionCode === 'HU' ? { ...item, availability: 'UNAVAILABLE' } : item,
      ),
  });
  assert.equal(playProductMatches(product, desired()), false);
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
  const start = source.indexOf('async function upsertPlayProduct(');
  const end = source.indexOf('async function updateWordPressReleaseProducts(', start);
  assert.ok(start > 0 && end > start, 'az upsertPlayProduct megtalálható');
  const body = source.slice(start, end);
  const call = body.slice(body.indexOf('playProductMatches('), body.indexOf('playProductMatches(') + 260);
  assert.match(call, /playProductMatches\(current,/, 'az első argumentum a Play-válasz (current)');
  // ⚠️ A kívánt régiókat is át kell adni: nélkülük a döntés nem tudná
  // megmondani, hogy a termék **minden** országban megvásárolható-e — vagyis
  // némán kihagyná a régiók pótlását (ez volt az éles hiba 2026-09-22-én).
  assert.match(call, /regions: desiredRegions,/, 'a kívánt régiókat átadja a döntésnek');
});

// ---------------------------------------------------------------------------
// AZ ORSZÁGOK — éles hiba javítása (2026-09-22, mérve)
//
// A tünet: a tulajdonos minden tételnél ezt kapta a Play-től —
// *„A tétel nem áll rendelkezésre az adott országban"* —, miközben **más
// appban** működött a vásárlás (tehát a fiókja rendben van).
//
// A mért gyökér (élő Play API, 60 termék): `regionalPricingAndAvailabilityConfigs`
// = **`[HU]` mind a 60 terméknél**, miközben az app 8 országban érhető el. Aki
// nem magyar Play-fiókkal telepítette az appot, az egyetlen tételt sem tudta
// megvenni.
// ---------------------------------------------------------------------------

test('a helyi árak a JÓVÁHAGYOTT értékek (550 Ft → 1,49 EUR / 39 CZK / 169 RSD / 59 UAH)', () => {
  assert.deepEqual(regionalPricingConfigs(550), [
    { regionCode: 'HU', availability: 'AVAILABLE', price: { currencyCode: 'HUF', units: '550', nanos: 0 } },
    { regionCode: 'AT', availability: 'AVAILABLE', price: { currencyCode: 'EUR', units: '1', nanos: 490000000 } },
    { regionCode: 'HR', availability: 'AVAILABLE', price: { currencyCode: 'EUR', units: '1', nanos: 490000000 } },
    { regionCode: 'SI', availability: 'AVAILABLE', price: { currencyCode: 'EUR', units: '1', nanos: 490000000 } },
    { regionCode: 'SK', availability: 'AVAILABLE', price: { currencyCode: 'EUR', units: '1', nanos: 490000000 } },
    { regionCode: 'NL', availability: 'AVAILABLE', price: { currencyCode: 'EUR', units: '1', nanos: 490000000 } },
    { regionCode: 'CZ', availability: 'AVAILABLE', price: { currencyCode: 'CZK', units: '39', nanos: 0 } },
    { regionCode: 'RS', availability: 'AVAILABLE', price: { currencyCode: 'RSD', units: '169', nanos: 0 } },
    { regionCode: 'UA', availability: 'AVAILABLE', price: { currencyCode: 'UAH', units: '59', nanos: 0 } },
  ]);
});

test('minden termék MINDEN országban elérhető, ahol az app (és a magyar ár a magyar ár)', () => {
  const configs = regionalPricingConfigs(700);
  assert.equal(configs.length, LABEL_PRODUCT_REGIONS.length, 'minden régió benne van');
  for (const config of configs) {
    assert.equal(config.availability, 'AVAILABLE', `${config.regionCode} elérhető`);
  }
  const hungary = configs.find((config) => config.regionCode === 'HU');
  assert.deepEqual(
    hungary.price,
    { currencyCode: 'HUF', units: '700', nanos: 0 },
    'a magyar ár a magyar ár (nincs átváltás)',
  );
  const others = configs.filter((config) => config.regionCode !== 'HU');
  assert.equal(others.length, LABEL_PRODUCT_REGIONS.length - 1, 'a külföldi országok is benne vannak');
});

test('a helyi ár nem csökken, ha a magyar ár nő (nincs fordított átváltás)', () => {
  const prices = [300, 500, 550, 700, 1100, 1900, 2900];
  const previous = new Map();
  for (const huf of prices) {
    for (const config of regionalPricingConfigs(huf)) {
      const value =
        Number(config.price.units) + Number(config.price.nanos || 0) / 1e9;
      const earlier = previous.get(config.regionCode);
      if (earlier !== undefined) {
        assert.ok(
          value >= earlier,
          `${config.regionCode}: ${huf} Ft-nál (${value}) nem lehet kevesebb, mint korábban (${earlier})`,
        );
      }
      previous.set(config.regionCode, value);
    }
  }
});

test('a helyi ár a nyers átszámolás KÖRÜL van (nem nagyságrenddel téveszt)', () => {
  // 550 Ft ≈ 1,49 EUR / 39 CZK / 169 RSD / 59 UAH — a létráról választott ár a
  // nyers érték ±25%-án belül kell legyen, különben elírt árfolyam.
  const expected = [
    ['EUR', 1.49],
    ['CZK', 39],
    ['RSD', 169],
    ['UAH', 59],
  ];
  for (const [currency, value] of expected) {
    const price = regionalPriceFor(550, currency);
    const actual = Number(price.units) + Number(price.nanos || 0) / 1e9;
    assert.ok(
      Math.abs(actual - value) / value < 0.25,
      `${currency}: ${actual} a várt ${value} körül van`,
    );
  }
});

test('az érvénytelen magyar ár HANGOS hiba (nem csendes rossz ár)', () => {
  for (const bad of [0, -1, 12.5, Number.NaN, '', null, undefined]) {
    assert.throws(() => regionalPricingConfigs(bad), /Érvénytelen magyar alapár/);
  }
  assert.throws(() => regionalPriceFor(550, 'XYZ'), /Nincs átszámítási szabály/);
});

test('a HU-only termék NEM egyezik — a régiókat pótolni kell (EZ VOLT AZ ÉLES HIBA)', () => {
  // Pontosan a mért éles állapot: egyetlen régió, `HU`.
  const live = playProduct();
  live.purchaseOptions[0].regionalPricingAndAvailabilityConfigs = [
    { regionCode: 'HU', availability: 'AVAILABLE', price: { currencyCode: 'HUF', units: '700', nanos: 0 } },
  ];
  assert.equal(
    playProductMatches(live, desired()),
    false,
    'a HU-only termék nem mondható „változatlannak" — különben örökre az marad',
  );
});

test('az egyetlen hiányzó ország is eltérés (nem elég a magyar régió)', () => {
  const missingUkraine = playProduct({
    mutateConfigs: (configs) => configs.filter((config) => config.regionCode !== 'UA'),
  });
  assert.equal(playProductMatches(missingUkraine, desired()), false);
});

test('az egyetlen rossz árú ország is eltérés', () => {
  const wrongPrice = playProduct({
    mutateConfigs: (configs) =>
      configs.map((config) =>
        config.regionCode === 'CZ'
          ? { ...config, price: { currencyCode: 'CZK', units: '999', nanos: 0 } }
          : config,
      ),
  });
  assert.equal(playProductMatches(wrongPrice, desired()), false);
});

test('az egyetlen nem elérhető ország is eltérés', () => {
  const unavailable = playProduct({
    mutateConfigs: (configs) =>
      configs.map((config) =>
        config.regionCode === 'SK' ? { ...config, availability: 'UNAVAILABLE' } : config,
      ),
  });
  assert.equal(playProductMatches(unavailable, desired()), false);
});

test('a KÉZZEL beállított plusz országot nem bántjuk (a döntés elviseli)', () => {
  assert.equal(
    playProductMatches(playProduct({ extraRegions: true }), desired()),
    true,
    'a Play Console-ban hozzáadott ország nem tesz kárt',
  );
});

test('a hiányzó régió-lista NEM egyezik (nem hagyhatja ki csendben a pótlást)', () => {
  assert.equal(
    playProductMatches(playProduct(), desired({ regions: [] })),
    false,
    'régió-lista nélkül nincs „minden rendben"',
  );
  assert.equal(playProductMatches(playProduct(), desired({ regions: null })), false);
});

test('a PATCH törzse megtartja a meglévő országokat és felülírja a mieinket', () => {
  const current = [
    { regionCode: 'HU', availability: 'AVAILABLE', price: { currencyCode: 'HUF', units: '500', nanos: 0 } },
    { regionCode: 'DE', availability: 'AVAILABLE', price: { currencyCode: 'EUR', units: '2', nanos: 0 } },
  ];
  const merged = mergeRegionalConfigs(current, regionalPricingConfigs(700));
  const codes = merged.map((item) => item.regionCode).sort();
  assert.deepEqual(
    codes,
    ['AT', 'CZ', 'DE', 'HR', 'HU', 'NL', 'RS', 'SI', 'SK', 'UA'],
    'a DE (kézi) megmarad, a többi régió bekerül',
  );
  const hungary = merged.find((item) => item.regionCode === 'HU');
  assert.equal(hungary.price.units, '700', 'a magyar árat a kívánt értékre írja');
  const germany = merged.find((item) => item.regionCode === 'DE');
  assert.equal(germany.price.units, '2', 'a kézzel beállított ország ára érintetlen');
});

test('a régió nélküli bejegyzést a PATCH eldobná — az egyesítés nem viszi tovább', () => {
  const merged = mergeRegionalConfigs(
    [{ availability: 'AVAILABLE' }, { regionCode: 'DE', availability: 'AVAILABLE' }],
    regionalPricingConfigs(550),
  );
  assert.equal(
    merged.some((item) => !item.regionCode),
    false,
    'nincs régió nélküli bejegyzés a kimenetben',
  );
});

test('FORRÁS-LINT: a szinkron a tiszta modulból veszi a régiókat és az árakat', () => {
  const source = fs.readFileSync(path.join(__dirname, 'index.js'), 'utf8');
  const start = source.indexOf('async function upsertPlayProduct(');
  const end = source.indexOf('async function updateWordPressReleaseProducts(', start);
  assert.ok(start > 0 && end > start, 'az upsertPlayProduct megtalálható');
  const body = source.slice(start, end);

  assert.match(body, /const desiredRegions = regionalPricingConfigs\(price\);/, 'a régiók a modulból jönnek');
  assert.match(body, /mergeRegionalConfigs\(/, 'a meglévő országokat megtartja');
  assert.match(body, /regions: desiredRegions,/, 'a döntés ugyanazt a listát kapja');
  // A régi, CSAK MAGYARORSZÁGRA beállító blokk nem térhet vissza.
  assert.doesNotMatch(
    body,
    /regionalPrices\.set\('HU'/,
    'a HU-only beállítás (ez volt az éles hiba) nem térhet vissza',
  );
  assert.doesNotMatch(
    body,
    /regionalPrices/,
    'a régió-térkép helyét a tiszta modul vette át',
  );

  // A régiók és az árfolyamok EGY helyen élnek: az index.js nem tartalmazhat
  // ország-besorolást vagy átszámítást.
  const indexSource = fs.readFileSync(path.join(__dirname, 'index.js'), 'utf8');
  const regionLiterals = [
    "regionCode: 'AT'",
    "regionCode: 'CZ'",
    "regionCode: 'NL'",
    "regionCode: 'RS'",
    "regionCode: 'UA'",
  ];
  for (const literal of regionLiterals) {
    assert.equal(
      indexSource.includes(literal),
      false,
      `a(z) ${literal} a tiszta modulban él, nem az index.js-ben`,
    );
  }
  const moduleSource = fs.readFileSync(path.join(__dirname, 'play-product-plan.js'), 'utf8');
  for (const literal of regionLiterals) {
    assert.ok(
      moduleSource.includes(literal),
      `a(z) ${literal} a tiszta modulban van`,
    );
  }
});

test('FORRÁS-LINT: a régió-lista az app országait fedi (a zárt teszt sávját + NL)', () => {
  assert.deepEqual(
    LABEL_PRODUCT_REGIONS.map((item) => item.regionCode),
    ['HU', 'AT', 'HR', 'SI', 'SK', 'NL', 'CZ', 'RS', 'UA'],
    'a termékek ott érhetők el, ahol az app (és a kérésre hozzáadott Hollandia)',
  );
});

// ---------------------------------------------------------------------------
// A VÁSÁRLÁSI OPCIÓ ÁLLAPOTA — éles hiba javítása (2026-09-22, mérve)
//
// A tünet: egy meg nem jelent kiadvány terméke `DRAFT` állapotban van (helyes,
// mert a Play nem adhatja el a megjelenés előtt) — DE a szinkron
// „változatlan termék → nincs írás" gyors-útja **korán visszatért**, ezért a
// megjelenés napján az aktiválás **soha nem futott volna le**: a kiadvány
// terméke örökre `DRAFT` maradt volna, minden jelzés nélkül.
//
// A mérés (élő Play API, 60 termék): a legfrissebb kiadvány (12699) 4 terméke
// `DRAFT`, a többi 56 `ACTIVE`.
// ---------------------------------------------------------------------------

test('a vásárlási opció állapota: megjelent kiadvány DRAFT termékét AKTIVÁLNI kell', () => {
  assert.equal(
    purchaseOptionStateAction({ releaseIsUpcoming: false, currentState: 'DRAFT' }),
    'activate',
  );
  assert.equal(
    purchaseOptionStateAction({ releaseIsUpcoming: false, currentState: 'INACTIVE' }),
    'activate',
  );
});

test('a vásárlási opció állapota: ami már jó, azt nem bántjuk (nincs felesleges írás)', () => {
  // Megjelent + ACTIVE → nincs teendő.
  assert.equal(
    purchaseOptionStateAction({ releaseIsUpcoming: false, currentState: 'ACTIVE' }),
    'none',
  );
  // A `state` HIÁNYA régi, aktív terméket jelent — nem írunk.
  assert.equal(
    purchaseOptionStateAction({ releaseIsUpcoming: false, currentState: '' }),
    'none',
  );
  assert.equal(purchaseOptionStateAction({ releaseIsUpcoming: false }), 'none');
});

test('a vásárlási opció állapota: meg nem jelent kiadvány NEM vásárolható', () => {
  // Ha valaki kézzel aktiválta a Play Console-ban, vissza kell venni.
  assert.equal(
    purchaseOptionStateAction({ releaseIsUpcoming: true, currentState: 'ACTIVE' }),
    'deactivate',
  );
  // A már inaktív (DRAFT) állapot rendben van — nem írunk minden körben.
  assert.equal(
    purchaseOptionStateAction({ releaseIsUpcoming: true, currentState: 'DRAFT' }),
    'none',
  );
  assert.equal(
    purchaseOptionStateAction({ releaseIsUpcoming: true, currentState: '' }),
    'none',
  );
});

test('a „változatlan termék" gyors-út NEM függhet a state-től (nincs írás-amplifikáció)', () => {
  // Ha a `playProductMatches` a DRAFT állapotot eltérésnek venné, egy meg nem
  // jelent kiadványnál MINDEN 5 perces körben PATCH indulna — pont az a hiba,
  // amit ez a modul megszüntetett. Ezért az állapotot külön kezeljük.
  const draft = playProduct({
    purchaseOptions: [
      {
        ...playProduct().purchaseOptions[0],
        state: 'DRAFT',
      },
    ],
  });
  assert.equal(
    playProductMatches(draft, desired()),
    true,
    'a DRAFT állapot nem a PATCH dolga — a döntés ne blokkolja a gyors-utat',
  );
});

test('FORRÁS-LINT: az aktiválás a gyors-úton IS lefut (ez volt az éles hiba)', () => {
  const source = fs.readFileSync(path.join(__dirname, 'index.js'), 'utf8');
  const start = source.indexOf('async function upsertPlayProduct(');
  const end = source.indexOf('async function updateWordPressReleaseProducts(', start);
  assert.ok(start > 0 && end > start, 'az upsertPlayProduct megtalálható');
  const body = source.slice(start, end);

  assert.match(body, /syncPlayPurchaseOptionState\(/, 'az állapot-rendezés bekötve');
  // 1. a gyors-út (egyezésnél) is rendbe teszi az állapotot
  //    (a keresés szándékosan a hívásra illeszkedik, nem egy `if (` alakzatra,
  //    hogy egy formázás ne tegye hamisan zölddé/sikertelenné a mérést)
  const early = body.indexOf('playProductMatches(');
  const earlyReturn = body.indexOf('return productId;', early);
  assert.ok(early > 0 && earlyReturn > early, 'a gyors-út megtalálható');
  const earlySlice = body.slice(early, earlyReturn);
  assert.match(
    earlySlice,
    /syncPlayPurchaseOptionState\(/,
    'a gyors-úton is le kell futnia az állapot-rendezésnek',
  );
  // 2. a PATCH utáni ágon is
  const patch = body.indexOf('.onetimeproducts.patch(');
  assert.ok(
    body.indexOf('syncPlayPurchaseOptionState(', patch) > patch,
    'a PATCH után is rendbe tesszük az állapotot',
  );
  // 3. a `state`-et NEM a PATCH-csel állítjuk (az nem is írható így)
  assert.doesNotMatch(
    body,
    /releaseIsUpcoming \? currentState/,
    'a régi, gyors-utat kihagyó inline blokk nem térhet vissza',
  );
  // 4. a döntés a tiszta modulban van (a közös állapot-rendezőben)
  const helperStart = source.indexOf('async function syncPlayPurchaseOptionState(');
  assert.ok(helperStart > 0, 'a syncPlayPurchaseOptionState megvan');
  assert.match(
    source.slice(helperStart, helperStart + 900),
    /purchaseOptionStateAction\(\{/,
    'a döntés a tiszta modulból jön',
  );
  // 5. a `releaseIsUpcoming` a verzió-ellenőrzés bemenete — a DEFINÍCIÓ is kell
  //    (ez a mező egyszer már kiesett egy refaktor alatt: futásidejű hiba lett
  //    volna, amit csak a kód kiíratása mutatott meg)
  assert.match(body, /const releaseIsUpcoming = release\?\.is_upcoming === true;/);
});
