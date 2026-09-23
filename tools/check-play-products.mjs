#!/usr/bin/env node
/**
 * ÉLES: a Google Play **alkalmazáson belüli termékei** — csak olvas.
 *
 * MIÉRT: a tulajdonos egy képernyőképet küldött a Play „Fizetési módok"
 * képernyőről, ahol **minden** kártyánál ez állt:
 * *„A tétel nem áll rendelkezésre az adott országban."*
 *
 * Ez a hiba **néma a kód felől**: az app elindul, a termék lekérdezhető, a
 * vásárlás gomb megjelenik — a Play viszont nem engedi megvenni. A gyanú a
 * termék **ország-elérhetősége** (a szinkron csak a `HU` régiót állítja
 * `AVAILABLE`-re), ezért ezt kell **mérni**, nem feltételezni.
 *
 * Amit kiír:
 *   1. hány termék van, és ezek **mely országokban** elérhetők (`AVAILABLE`),
 *   2. kiemelten a **HU** régió: van-e ára és elérhető-e,
 *   3. az **ORSZÁG-LEFEDETTSÉG**: minden termék elérhető-e mind a 8 országban,
 *      ahol az app (ez a 2026-09-22-i ország-hiba mérése; a várt lista a tiszta
 *      `functions/play-product-plan.js`-ből jön, ezért nem tud széthúzni),
 *   4. az **alkalmazás** ország-elérhetősége (`--tracks` esetén; ez az edit-API-t
 *      hívja, ezért alapból **nem** fut — a Play Console piszkozatait kíméljük),
 *   5. a termékek **állapota** (pl. `DRAFT`/`INACTIVE`), ha az API adja.
 *
 * Titkot nem tartalmaz: a `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` a Secret
 * Managerből jön. Alapértelmezésben **nem ír semmit**; a `--tracks` a végén a
 * saját ideiglenes edit-jét is törli.
 *
 * Futtatás: node tools/check-play-products.mjs [csomagnév] [--tracks] [--raw]
 */
import path from 'node:path';
import { createRequire } from 'node:module';
import { PROJECT, secretMultiline } from './lib/live-firebase.mjs';

const require = createRequire(path.join(process.cwd(), 'functions', 'index.js'));
const { google } = require('googleapis');
const { LABEL_PRODUCT_REGIONS } = require(
  path.join(process.cwd(), 'functions', 'play-product-plan.js'),
);

const positional = process.argv.slice(2).filter((arg) => !arg.startsWith('--'));
const packageName = positional[0] || 'hu.hungarianhardstyle.app';
const REGION = 'HU';
/** Azok az országok, ahol a termékeknek megvásárolhatónak kell lenniük. */
const EXPECTED_REGIONS = LABEL_PRODUCT_REGIONS.map((item) => item.regionCode);

/** Az egyetlen vásárlási lehetőség (nálunk mindig egy van: `default`). */
function firstPurchaseOption(product) {
  return product?.purchaseOptions?.[0] || null;
}

function availabilityOf(product, regionCode = REGION) {
  const option = firstPurchaseOption(product);
  const configs = option?.regionalPricingAndAvailabilityConfigs || [];
  const match = configs.find((item) => String(item?.regionCode) === regionCode) || null;
  if (!match) return { config: null, available: false, price: null };
  const price = match.price || null;
  const priceText =
    price && price.units ? `${price.units} ${price.currencyCode || ''}`.trim() : null;
  return {
    config: match,
    available: String(match.availability || '').toUpperCase() === 'AVAILABLE',
    price: priceText,
  };
}

/**
 * Az ország-lista elemei **objektumok** is lehetnek (nem sima kódok), ezért
 * normalizáljuk — enélkül a „benne van-e HU" ellenőrzés **hamis riasztást** ad.
 */
function regionCodes(list) {
  return (Array.isArray(list) ? list : [])
    .map((item) =>
      typeof item === 'string'
        ? item
        : String(item?.regionCode || item?.countryCode || item?.country || ''),
    )
    .filter((code) => code.length > 0);
}

async function main() {
  const serviceAccount = JSON.parse(secretMultiline('GOOGLE_PLAY_SERVICE_ACCOUNT_JSON'));
  const auth = new google.auth.GoogleAuth({
    credentials: serviceAccount,
    scopes: ['https://www.googleapis.com/auth/androidpublisher'],
  });
  const client = google.androidpublisher({ version: 'v3', auth });

  console.log(`projekt=${PROJECT} csomag=${packageName}`);
  console.log('');

  // 1) A termékek (a monetization API **nem** edit-alapú).
  let products = [];
  try {
    const response = await client.monetization.onetimeproducts.list({
      packageName,
      pageSize: 200,
    });
    products = response.data?.oneTimeProducts || [];
  } catch (error) {
    console.error(`HIBA  a terméklista nem kérdezhető le: ${error?.message || error}`);
    return 1;
  }

  console.log(`Alkalmazáson belüli termékek: ${products.length}`);
  console.log('');

  const huMissing = [];
  const huInactive = [];
  const regionCounts = new Map();
  const regionSetCounts = new Map();
  const regionGaps = [];

  for (const product of products) {
    const option = firstPurchaseOption(product);
    const configs = option?.regionalPricingAndAvailabilityConfigs || [];
    const available = configs.filter(
      (item) => String(item?.availability || '').toUpperCase() === 'AVAILABLE',
    );
    for (const item of available) {
      const code = String(item?.regionCode || '?');
      regionCounts.set(code, (regionCounts.get(code) || 0) + 1);
    }
    const codes = available.map((item) => String(item?.regionCode || '?')).sort();
    regionSetCounts.set(codes.join(','), (regionSetCounts.get(codes.join(',')) || 0) + 1);
    const missing = EXPECTED_REGIONS.filter((code) => !codes.includes(code));
    if (missing.length) regionGaps.push(`${product.productId} (hiányzik: ${missing.join(', ')})`);
    const hu = availabilityOf(product);
    if (!hu.available) huMissing.push(product.productId);
    const state = String(product.state || option?.state || '');
    if (state && state.toUpperCase() !== 'ACTIVE') {
      huInactive.push(`${product.productId} (state=${state})`);
    }
  }

  console.log(`Országok, ahol LEGALÁBB egy termék elérhető: ${regionCounts.size}`);
  const top = [...regionCounts.entries()].sort((a, b) => b[1] - a[1]).slice(0, 12);
  for (const [code, count] of top) console.log(`   ${code}: ${count} termék`);
  console.log('');

  const huAvailable = products.length - huMissing.length;
  console.log(
    huAvailable === products.length
      ? `OK    a ${REGION} régióban MINDEN termék elérhető (${huAvailable}/${products.length})`
      : `HIBA  a ${REGION} régióban NEM elérhető: ${huMissing.length}/${products.length} termék`,
  );
  for (const id of huMissing.slice(0, 12)) console.log(`      - ${id}`);
  if (huMissing.length > 12) console.log(`      … és további ${huMissing.length - 12}`);

  // ---------------------------------------------------------------------------
  // AZ ORSZÁG-LEFEDETTSÉG — éles hiba javítása (2026-09-22).
  //
  // A mérés: mind a 60 termék `regionalPricingAndAvailabilityConfigs` listája
  // **`[HU]`** volt, miközben az app 8 országban érhető el. Ezért egy nem magyar
  // Play-fiókkal minden tételre ez jött: *„A tétel nem áll rendelkezésre az
  // adott országban."* A javítás után **minden** terméknek mind a 8 országban
  // elérhetőnek kell lennie — ezt itt mérjük, nem feltételezzük.
  // ---------------------------------------------------------------------------
  console.log('');
  console.log('Elérhető országok halmaza → hány terméknél:');
  for (const [key, count] of [...regionSetCounts.entries()].sort((a, b) => b[1] - a[1])) {
    console.log(`   ${count} termék: [${key}]`);
  }
  console.log('');
  console.log(
    regionGaps.length === 0
      ? `OK    MINDEN termék elérhető mind a ${EXPECTED_REGIONS.length} országban, ahol az app (${EXPECTED_REGIONS.join(', ')})`
      : `HIBA  ${regionGaps.length}/${products.length} termék NEM érhető el minden országban — ` +
        'az érintett vevők ezt kapják: „A tétel nem áll rendelkezésre az adott országban."',
  );
  for (const row of regionGaps.slice(0, 12)) console.log(`      - ${row}`);
  if (regionGaps.length > 12) console.log(`      … és további ${regionGaps.length - 12}`);

  if (huInactive.length) {
    console.log('');
    console.log(`FIGYELEM  nem ACTIVE állapotú termék: ${huInactive.length}`);
    for (const row of huInactive.slice(0, 8)) console.log(`      - ${row}`);
  }

  // Kiadványonként: melyik termék-választási lehetőség milyen állapotban van?
  // (Egy DRAFT opciót a Play nem ad el, akkor sem, ha a termék elérhető.)
  const byRelease = new Map();
  for (const product of products) {
    const match = /^huhs_release_(\d+)_(.+)$/.exec(String(product.productId || ''));
    if (!match) continue;
    const releaseId = Number(match[1]);
    const option = firstPurchaseOption(product);
    if (!byRelease.has(releaseId)) byRelease.set(releaseId, new Map());
    const state = String(option?.state || 'ACTIVE').toUpperCase();
    byRelease.set(releaseId, byRelease.get(releaseId).set(state, (byRelease.get(releaseId).get(state) || 0) + 1));
  }
  const releases = [...byRelease.entries()].sort((a, b) => b[0] - a[0]);
  console.log('');
  console.log('Kiadványonként (a legfrissebbel kezdve) — vásárlási opció állapota:');
  for (const [releaseId, states] of releases.slice(0, 10)) {
    const text = [...states.entries()].map(([state, count]) => `${state}:${count}`).join(' ');
    const flag = states.has('DRAFT') ? '  ⚠️ VAN DRAFT — nem vásárolható' : '';
    console.log(`   ${releaseId}: ${text}${flag}`);
  }

  // 2) Két minta részletesen: pontosan mit lát a Play a HU régióra?
  const sample = products.slice(0, 2);
  for (const product of sample) {
    const hu = availabilityOf(product);
    console.log('');
    console.log(`Minta: ${product.productId}`);
    console.log(`   állapot: ${product.state || '(nincs mező)'}`);
    console.log(
      `   ${REGION}: elérhető=${hu.available}  ár=${hu.price || '(nincs ár)'}  ` +
        `nyers=${JSON.stringify(hu.config?.availability || null)}`,
    );
  }

  // 3) Az ALKALMAZÁS ország-elérhetősége — a másik lehetséges gyökér.
  //
  // ⚠️ SZÁNDÉKOSAN OPT-IN (`--tracks`): ez a rész a Play **edit**-API-ját
  // használja, és egy nyitott edit a Play Console-ban dolgozó piszkozatot
  // érvényteleníthet. Az alapértelmezett futás ezért **100%-ban olvas**.
  if (process.argv.includes('--tracks')) {
    const edit = await client.edits.insert({ packageName });
    const editId = edit.data.id;
    try {
      const tracks = await client.edits.tracks.list({ packageName, editId });
      const names = (tracks.data.tracks || []).map((track) => track.track).filter(Boolean);
      console.log('');
      if (!names.length) {
        console.log('(nincs egyetlen sáv sem — az app ország-elérhetősége nem kérdezhető le)');
      }
      for (const track of ['alpha', 'beta', 'production', ...names]) {
        try {
          const country = await client.edits.countryavailability.get({
            packageName,
            editId,
            track,
          });
          const list = regionCodes(country.data?.countries);
          const restOfWorld = country.data?.restOfWorld === true;
          const syncWithProduction = country.data?.syncWithProduction === true;
          console.log(
            `Sáv „${track}": ${list.length} ország` +
              (list.includes(REGION)
                ? `  (${REGION} benne van)`
                : `  ⚠️ ${REGION} NINCS benne`),
          );
          // ⚠️ EZ A KÉT MEZŐ DÖNTI EL, HOGY A LISTA VALÓBAN AZ-E, AMIT A VEVEK
          // LÁTNAK: ha a sáv a production listáját használja, a fenti országok
          // csak tájékoztatóak (a production lehet üres is!).
          console.log(
            `      restOfWorld=${restOfWorld}  syncWithProduction=${syncWithProduction}`,
          );
          if (syncWithProduction) {
            console.log(
              '      ⚠️ ez a sáv a PRODUCTION ország-listáját használja — a fenti lista önmagában félrevezető',
            );
          }
          if (list.length) {
            console.log(
              `      országok: ${list.slice(0, 24).join(', ')}${list.length > 24 ? ' …' : ''}`,
            );
            // Az ELVÁRT termék-régiók az app sávjából kell kijöjjenek — ha itt
            // eltérés van, a `LABEL_PRODUCT_REGIONS` listát kell igazítani.
            const expected = [...EXPECTED_REGIONS].sort().join(',');
            const actual = [...list].sort().join(',');
            if (syncWithProduction) {
              console.log('      (az elvárt lista egyeztetése kihagyva: a sáv production-nel szinkronizál)');
            } else {
              console.log(
                expected === actual
                  ? `      ✔ ez pontosan a termékek elvárt ország-listája (${EXPECTED_REGIONS.join(', ')})`
                  : `      ⚠️ ELTÉR a termékek elvárt listájától (${EXPECTED_REGIONS.join(', ')}) — ` +
                    'a LABEL_PRODUCT_REGIONS-t igazítani kell!',
              );
            }
          }
        } catch (error) {
          const message = String(error?.message || error).replace(/\s+/g, ' ');
          console.log(`Sáv „${track}": nem kérdezhető le (${message.slice(0, 90)})`);
        }
      }
    } catch (error) {
      console.log('');
      console.log(
        `(az app ország-elérhetősége nem kérdezhető le: ${error?.message || error})`,
      );
    } finally {
      await client.edits.delete({ packageName, editId }).catch(() => {});
    }
  } else {
    console.log('');
    console.log(
      '(a sávok ország-listája kihagyva — ehhez `--tracks`; az edit-API-t nem hívjuk)',
    );
  }

  // 4) Nyers JSON: pontosan mit lát a Play? (a legfrissebb és egy régebbi termék)
  if (process.argv.includes('--raw')) {
    const wanted = [
      products[0]?.productId,
      huInactive.length ? huInactive[0].split(' ')[0] : null,
    ].filter(Boolean);
    for (const productId of [...new Set(wanted)]) {
      try {
        const full = await client.monetization.onetimeproducts.get({
          packageName,
          productId,
        });
        console.log('');
        console.log(`NYERS ${productId}:`);
        console.log(JSON.stringify(full.data, null, 2));
      } catch (error) {
        console.log(`NYERS ${productId}: hiba (${error?.message || error})`);
      }
    }
  }

  console.log('');
  const problems = huMissing.length + regionGaps.length;
  console.log(
    problems === 0
      ? 'A termékek ország-elérhetősége rendben (minden országban, ahol az app elérhető).'
      : 'A fenti termékekre a Play „nem elérhető az adott országban" hibát ad.',
  );
  return problems === 0 ? 0 : 1;
}

const code = await main();
process.exit(code ?? 0);
