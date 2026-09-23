'use strict';

/**
 * A Play-termék „változatlan?" döntése — tiszta logika, nulla függőség.
 *
 * MIÉRT: a kiadvány-szinkron eddig **minden körben** felküldte az összes terméket
 * a Play Console-ra (egy GET + egy PATCH termékenként), akkor is, ha semmi nem
 * változott. Ez élesben 5 percenként időtúllépéshez vezetett (~475 hibabejegyzés
 * 24 órában), és feleslegesen fogyasztotta a Play API keretét.
 *
 * A javítás szándékosan a **biztonságos** irány: a Play-válasz **megmarad**
 * (tehát a kézzel, a Play Console-ban átírt terméket továbbra is azonnal
 * észrevesszük és javítjuk), csak a **felesleges ÍRÁST** hagyjuk ki. Nincs
 * gyorsítótár és nincs „utolsó szinkron" jelölő, ezért nem tud elavulni.
 *
 * A döntés pontosan azt hasonlítja, amit a PATCH küldene (a kérés törzse:
 * `listings` + `purchaseOptions`, `updateMask: 'listings,purchaseOptions'`):
 *   - a `listings` a PATCH-csel **lecserélődik**, ezért csak akkor egyező, ha a
 *     jelenlegi állapot pontosan az egyetlen `hu-HU` bejegyzés, ugyanazzal a
 *     címmel és leírással;
 *   - a `purchaseOptions`-nél a régiók a jelenlegiből **megmaradnak**, ezért
 *     **minden kívánt régiót** megkövetelünk, pontosan a kívánt árral és
 *     elérhetőséggel (ez a rész a 2026-09-22-i ország-hiba javítása: korábban
 *     csak a `HU` régiót nézte, ezért a HU-only termék örökre az maradt);
 *   - a `purchaseOptionId` és a `buyOption` megléte is kell (ezeket küldjük).
 *
 * AMIT SZÁNDÉKOSAN NEM HASONLÍT: a `state`. A `state` ugyanis **nem írható** a
 * PATCH-csel (a séma szerint „output only … use the dedicated endpoints
 * instead"), ezért az állapotot **külön** kell rendbe tenni
 * (`purchaseOptionStateAction` + a `purchaseOptions.batchUpdateStates` végpont).
 * Ha a döntés a `state`-et is figyelné, egy meg nem jelent kiadványnál minden
 * 5 perces körben felesleges PATCH indulna — pont az a hiba-osztály, amit ez a
 * modul megszüntetett.
 */
/**
 * AZOK AZ ORSZÁGOK, AHOL A TERMÉKEK MEGVÁSÁROLHATÓK.
 *
 * ⚠️ ÉLES HIBA, AMIT EZ JAVÍT (2026-09-22, mérve): a termékek **kizárólag
 * Magyarországra** voltak beállítva (`regionalPricingAndAvailabilityConfigs`
 * = `[HU]` mind a 60 terméknél), miközben az **alkalmazás 8 országban** érhető
 * el. Ezért aki nem magyar Play-fiókkal telepítette az appot, az **egyetlen
 * tételt sem tudott megvenni**: a Play minden kártyára ezt írta ki —
 * *„A tétel nem áll rendelkezésre az adott országban."* A tulajdonos jelezte,
 * hogy **más appban működik** a vásárlás (tehát a fiókja és a fizetési profilja
 * rendben van) — így a hiba egyértelműen a **termékek ország-listájában** volt.
 *
 * A szabály ezért: **ott legyen megvásárolható, ahol az app elérhető.**
 * A lista az app zárt teszt sávjának országai (mérve: AT, CZ, HR, HU, RS, SI,
 * SK, UA). Ha a Play Console-ban változik a sáv ország-listája, **ezt a listát
 * is** át kell írni — a `tools/check-play-products.mjs` kiírja mindkettőt,
 * ezért az eltérés nem maradhat észrevétlen.
 */
const LABEL_PRODUCT_REGIONS = [
  { regionCode: 'HU', currencyCode: 'HUF' },
  { regionCode: 'AT', currencyCode: 'EUR' },
  { regionCode: 'HR', currencyCode: 'EUR' },
  { regionCode: 'SI', currencyCode: 'EUR' },
  { regionCode: 'SK', currencyCode: 'EUR' },
  { regionCode: 'CZ', currencyCode: 'CZK' },
  { regionCode: 'RS', currencyCode: 'RSD' },
  { regionCode: 'UA', currencyCode: 'UAH' },
];

/**
 * Váltás a magyar alapárból: hány forint egy egység, és milyen „szép" árak
 * közül választunk. A Play-nek **régiós valutában** kell az árat megadni, ezért
 * a HUF árat át kell számolni — és a találatot a szokásos árpontokra kerekítjük
 * (a nyers átszámolt összeg, pl. 1,486 EUR, nem valódi árcédula).
 *
 * ⚠️ Ezek **üzleti** értékek, nem technikaiak: a tulajdonos hagyta jóvá őket
 * (2026-09-22) az 550 Ft-os alapárra — 1,49 EUR / 39 CZK / 169 RSD / 59 UAH.
 * Az árfolyam közelítő szándékkal szerepel itt, hogy a döntés **egy helyen** és
 * újraszámolhatóan éljen; a végső ár mindig a létráról kerül ki.
 */
const REGION_CURRENCY_RULES = {
  EUR: {
    hufPerUnit: 370,
    ladder: [
      0.99, 1.29, 1.49, 1.79, 1.99, 2.49, 2.99, 3.49, 3.99, 4.49, 4.99, 5.99,
      6.99, 7.99, 8.99, 9.99, 11.99, 12.99, 14.99, 16.99, 19.99, 24.99,
    ],
  },
  CZK: {
    hufPerUnit: 14.5,
    ladder: [19, 29, 39, 49, 59, 79, 99, 129, 149, 199, 249, 299, 399, 499, 599, 799, 999],
  },
  RSD: {
    hufPerUnit: 3.25,
    ladder: [99, 129, 149, 169, 199, 249, 299, 399, 499, 599, 799, 999, 1299],
  },
  UAH: {
    hufPerUnit: 9.3,
    ladder: [29, 39, 49, 59, 69, 79, 89, 99, 129, 149, 199, 249, 299, 399, 499, 599, 799, 999],
  },
};

/**
 * A legközelebbi „szép" ár — döntetlennél az **alsó** (kiszámítható, és a
 * vevőnek sem rosszabb).
 */
function nearestLadderPrice(value, ladder) {
  let best = ladder[0];
  let bestDistance = Math.abs(value - best);
  for (const candidate of ladder) {
    const distance = Math.abs(value - candidate);
    if (distance < bestDistance) {
      best = candidate;
      bestDistance = distance;
    }
  }
  return best;
}

/** Egy régió ára a magyar alapárból, a Play `Money` alakjában. */
function regionalPriceFor(baseHuf, currencyCode) {
  const huf = Number(baseHuf);
  if (!Number.isInteger(huf) || huf <= 0) {
    throw new Error(`Érvénytelen magyar alapár: ${String(baseHuf)}`);
  }
  if (currencyCode === 'HUF') {
    return { currencyCode: 'HUF', units: String(huf), nanos: 0 };
  }
  const rule = REGION_CURRENCY_RULES[currencyCode];
  if (!rule) throw new Error(`Nincs átszámítási szabály erre a valutára: ${currencyCode}`);
  const converted = huf / rule.hufPerUnit;
  // ⚠️ A **legközelebbi** ár a létráról — szándékosan nem „a nyers árnál nem
  // olcsóbb". Egy ilyen szűrő ugyanis a jóváhagyott értékeket vitte volna el:
  // 550 Ft-nál a 169 RSD (nyers 169,23) és az 59 UAH (nyers 59,14) kiesett
  // volna, és 199, illetve 69 lett volna belőle. A kerekítés iránya tehát a
  // szokásos árpont döntse el, ne egy mesterséges padló.
  const value = nearestLadderPrice(converted, rule.ladder);
  const units = Math.floor(value);
  const nanos = Math.round((value - units) * 1e9);
  return { currencyCode, units: String(units), nanos };
}

/**
 * A **teljes** kívánt régió-konfiguráció egy termékhez (minden ország
 * `AVAILABLE`, a magyar alapárból számolt helyi árakkal).
 */
function regionalPricingConfigs(baseHuf) {
  return LABEL_PRODUCT_REGIONS.map(({ regionCode, currencyCode }) => ({
    regionCode,
    availability: 'AVAILABLE',
    price: regionalPriceFor(baseHuf, currencyCode),
  }));
}

/**
 * A PATCH törzse: a **meglévő** régiókat megtartja (a Play Console-ban kézzel
 * beállított ország **nem veszik el** — a tulajdonos kérése: „semmit ne
 * kapcsolj ki"), a mieinket viszont a kívánt értékre írja.
 */
function mergeRegionalConfigs(currentConfigs, desiredConfigs) {
  const byRegion = new Map();
  for (const item of Array.isArray(currentConfigs) ? currentConfigs : []) {
    const code = String(item?.regionCode || '');
    if (code) byRegion.set(code, item);
  }
  for (const item of Array.isArray(desiredConfigs) ? desiredConfigs : []) {
    const code = String(item?.regionCode || '');
    if (code) byRegion.set(code, item);
  }
  return [...byRegion.values()];
}

function playProductMatches(current, desired) {
  const {
    title = '',
    description = '',
    price = 0,
    purchaseOptionId = 'default',
    regions = null,
  } = desired || {};
  if (!current || typeof current !== 'object') return false;
  // Ár nélkül nincs mit összehasonlítani (a hívó ilyenkor nem is hívja).
  if (!Number.isFinite(Number(price)) || Number(price) <= 0) return false;

  const listings = Array.isArray(current.listings) ? current.listings : [];
  if (listings.length !== 1) return false;
  const listing = listings[0] || {};
  if (String(listing.languageCode || '') !== 'hu-HU') return false;
  if (String(listing.title || '') !== String(title)) return false;
  if (String(listing.description || '') !== String(description)) return false;

  const options = Array.isArray(current.purchaseOptions) ? current.purchaseOptions : [];
  const option =
    options.find((item) => String(item?.purchaseOptionId || '') === String(purchaseOptionId)) ||
    (options.length === 1 ? options[0] : null);
  if (!option) return false;
  if (!option.buyOption) return false;

  const configs = Array.isArray(option.regionalPricingAndAvailabilityConfigs)
    ? option.regionalPricingAndAvailabilityConfigs
    : [];
  // A PATCH azokat a régiókat, amelyeknek nincs `regionCode`-juk, ELDOBNÁ —
  // ilyenkor tehát nem mondhatjuk, hogy semmi nem változna.
  if (configs.some((item) => !String(item?.regionCode || ''))) return false;

  // ⚠️ A KÍVÁNT RÉGIÓK LISTÁJA KÖTELEZŐ. Ha hiányozna, **nem** mondhatjuk, hogy
  // „minden rendben" (az csendesen kihagyná a javítást — pont az a hiba, amit ez
  // a modul megszüntetett), ezért ilyenkor „nem egyezik" a válasz: a hívó ír.
  // A bekötést a teszt forrás-lintje is megköveteli.
  if (!Array.isArray(regions) || regions.length === 0) return false;

  // ⚠️ MINDEN kívánt régiót megkövetelünk (nem csak a magyart): enélkül egy
  // HU-only termék **örökre** az maradt volna, mert a „változatlan ⇒ nincs írás"
  // gyors-út némán kihagyta volna a régiók pótlását (éles hiba, mérve 2026-09-22:
  // 60-ból 60 termék `[HU]` volt, miközben az app 8 országban elérhető).
  for (const wanted of regions) {
    const code = String(wanted?.regionCode || '');
    if (!code) return false;
    const found = configs.find((item) => String(item?.regionCode || '') === code);
    if (!found) return false;
    if (String(found.availability || '') !== String(wanted.availability || '')) return false;
    const wantedPrice = wanted.price || {};
    const foundPrice = found.price || {};
    if (String(foundPrice.currencyCode || '') !== String(wantedPrice.currencyCode || '')) return false;
    if (String(foundPrice.units ?? '') !== String(wantedPrice.units ?? '')) return false;
    if (Number(foundPrice.nanos || 0) !== Number(wantedPrice.nanos || 0)) return false;
  }

  return true;
}

/**
 * Mit kell tenni a **vásárlási opció állapotával**?
 *
 * Ez a döntés azért él külön, mert a `state`:
 *   - **nem** írható a termék PATCH-csel (csak a dedikált
 *     `purchaseOptions.batchUpdateStates` végponttal),
 *   - ezért a „változatlan termék = nincs írás" gyors-úton is **le kell futnia**.
 *
 * ⚠️ ÉLES HIBA, AMIT EZ A DÖNTÉS JAVÍT (2026-09-22, mérve): a gyors-út
 * (`playProductMatches` → `return productId`) **korán visszatért**, ezért a
 * megjelenés napján az aktiválás **soha nem futott volna le** — a kiadvány
 * terméke `DRAFT` állapotban ragadt volna, minden jelzés nélkül (a Play
 * egyszerűen nem adta volna el). A mérés ezt mutatta: a legfrissebb kiadvány
 * (12699) 4 terméke `DRAFT`, a többi 56 `ACTIVE`.
 *
 * Szabály: meg nem jelent kiadvány = **nem vásárolható** (deactivate), megjelent
 * kiadvány = **vásárolható** (activate). A `state` **hiánya** régi, aktív
 * terméket jelent, ezért azt nem bántjuk (különben minden körben írnánk).
 */
function purchaseOptionStateAction({ releaseIsUpcoming, currentState } = {}) {
  const state = String(currentState || '').toUpperCase();
  if (releaseIsUpcoming === true) {
    return state === 'ACTIVE' ? 'deactivate' : 'none';
  }
  if (!state) return 'none';
  return state === 'ACTIVE' ? 'none' : 'activate';
}

module.exports = {
  playProductMatches,
  purchaseOptionStateAction,
  LABEL_PRODUCT_REGIONS,
  regionalPricingConfigs,
  regionalPriceFor,
  mergeRegionalConfigs,
};
