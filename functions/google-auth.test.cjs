const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

/**
 * A Play-termékszinkron némán elhalt egy `GoogleAuth` hibától.
 *
 * A tünet: a `syncWordPressLabelProducts` ütemezett függvény ötpercenként
 * lefutott, és minden futás egyetlen, olvashatatlan sorral bukott el:
 * „Class constructor GoogleAuth cannot be invoked without 'new'". Mivel a
 * scheduler a hibát egy generikus üzenetbe csomagolja, sem a release, sem a
 * termék, sem az ok nem látszott — így egy új kiadvány napokig nem került be a
 * Play Console-ba.
 *
 * Ez a teszt három dolgot rögzít:
 *   1. a helper valóban AuthPlus-példányt épít a `google.auth`-ból (nem
 *      függvényhívást), és a valódi `googleapis` csomaggal is lefut;
 *   2. a `new` nélküli hívás valóban dob (ezért a védelem indokolt);
 *   3. egyetlen `auth.GoogleAuth` hívás sincs a helperen kívül, tehát a
 *      hibaosztály nem tud visszakúszni a forrásba.
 */

const functionsSource = fs.readFileSync(path.join(__dirname, 'index.js'), 'utf8');
const createClient = require('./index.js').__createAndroidPublisherClientForTests;

const serviceAccount = {
  type: 'service_account',
  project_id: 'hungarian-hardstyle',
  client_email: 'play-sync@hungarian-hardstyle.iam.gserviceaccount.com',
  private_key: '-----BEGIN PRIVATE KEY-----\nnot-a-real-key\n-----END PRIVATE KEY-----\n',
};

test('a helper valodi AuthPlus-peldanybol epiti a GoogleAuth klienst', () => {
  const calls = [];
  const fakeGoogle = {
    auth: {
      GoogleAuth: function GoogleAuth(options) {
        calls.push(options);
        this.options = options;
      },
    },
    androidpublisher: (options) => ({ options, marker: 'publisher' }),
  };

  const client = createClient(serviceAccount, fakeGoogle);

  assert.equal(calls.length, 1, 'a GoogleAuth pontosan egyszer epitodik');
  assert.equal(calls[0].credentials, serviceAccount);
  assert.deepEqual(calls[0].scopes, [
    'https://www.googleapis.com/auth/androidpublisher',
  ]);
  assert.equal(client.marker, 'publisher');
  assert.equal(client.options.version, 'v3');
  assert.ok(
    client.options.auth instanceof fakeGoogle.auth.GoogleAuth,
    'a kliens a GoogleAuth PELDANYT kapja, nem a fuggvenyt',
  );
});

test('a `new` nelkuli hivas valoban dob — ez volt a néma hiba', () => {
  class GoogleAuth {
    constructor(options) {
      this.options = options;
    }
  }

  assert.throws(
    () => GoogleAuth({ credentials: serviceAccount }),
    /Class constructor GoogleAuth cannot be invoked without 'new'/,
  );
});

test('a valodi googleapis csomaggal is peldanyt ad (nem fuggvenyt)', () => {
  const client = createClient(serviceAccount);
  assert.ok(client, 'a kliens letrejon');
  assert.equal(typeof client.purchases?.products?.get, 'function');
  assert.equal(
    typeof client.monetization?.onetimeproducts?.patch,
    'function',
  );
});

test('nincs `new` nelkuli auth.GoogleAuth hivas a forrasban', () => {
  // A helper az EGYETLEN hely, ahol GoogleAuth epitodik.
  const occurrences = [...functionsSource.matchAll(/\.auth\s*\.\s*GoogleAuth/g)];
  assert.equal(occurrences.length, 1, 'pontosan egy GoogleAuth-epites van');

  // Es az is `new`-val, kozvetlenul a googleApis() hivas utan.
  assert.match(
    functionsSource,
    /const auth = new google\.auth\.GoogleAuth\(\{/,
  );
  assert.doesNotMatch(
    functionsSource,
    /(^|[^.\w])googleApis\(\)\.auth\.GoogleAuth\(/m,
    'a `new` nelkuli alak nem térhet vissza',
  );
});

test('a szinkron bukasa beszedes naplót hagy (nem néma)', () => {
  // A hibat körülvevő wrappernek rögzítenie kell a release-t, a terméket és az
  // okot, különben a következő hiba megint napokig láthatatlan marad.
  assert.match(functionsSource, /label_sync_summary/);
  assert.match(functionsSource, /label_sync_failed_items/);
  assert.match(functionsSource, /label_sync_failed/);
  assert.match(functionsSource, /label_product_sync_item_failed/);
  assert.match(functionsSource, /runWordPressLabelSync/);
});
