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
 *   3. az **alkalmazás** ország-elérhetősége (ez a másik lehetséges gyökér),
 *   4. a termékek **állapota** (pl. `DRAFT`/`INACTIVE`), ha az API adja.
 *
 * Titkot nem tartalmaz: a `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` a Secret
 * Managerből jön. **Nem ír semmit** (a végén a nyitott edit-et is törli).
 *
 * Futtatás: node tools/check-play-products.mjs [csomagnév]
 */
import path from 'node:path';
import { createRequire } from 'node:module';
import { PROJECT, secretMultiline } from './lib/live-firebase.mjs';

const require = createRequire(path.join(process.cwd(), 'functions', 'index.js'));
const { google } = require('googleapis');

const positional = process.argv.slice(2).filter((arg) => !arg.startsWith('--'));
const packageName = positional[0] || 'hu.hungarianhardstyle.app';
const REGION = 'HU';

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
        console.log(
          `Sáv „${track}": ${list.length} ország` +
            (list.includes(REGION)
              ? `  (${REGION} benne van)`
              : `  ⚠️ ${REGION} NINCS benne`),
        );
        if (list.length) {
          console.log(
            `      országok: ${list.slice(0, 24).join(', ')}${list.length > 24 ? ' …' : ''}`,
          );
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
  console.log(
    huMissing.length === 0
      ? 'A termékek ország-elérhetősége rendben.'
      : 'A fenti termékekre a Play „nem elérhető az adott országban" hibát ad.',
  );
  return huMissing.length === 0 ? 0 : 1;
}

const code = await main();
process.exit(code ?? 0);
