#!/usr/bin/env node
/**
 * ÉLES IGAZOLÁS: a szinkron **helyreállítja-e** egy megjelent kiadvány termékét?
 *
 * MIÉRT: 2026-09-22-én kiderült, hogy a kiadvány-szinkron „változatlan termék →
 * nincs írás" gyors-útja **korán visszatért**, ezért a vásárlási opció
 * állapotának rendezése (activate/deactivate) **kihagyódott**. A javítás után a
 * gyors-út is lefuttatja — de ezt **mérni** kell, nem feltételezni.
 *
 * A mérés menete (szándékosan a valódi úton):
 *   1. egy MEGJELENT kiadvány egyik termékét **deaktiváljuk** (a Play nem adja el),
 *   2. várunk, amíg az **ütemezett szinkron** (5 percenként) lefut,
 *   3. megnézzük, hogy a termék **visszaállt-e ACTIVE**-ra,
 *   4. a végén **garantáltan** aktív állapotban hagyjuk (finally) — akkor is, ha
 *      a mérés elbukik vagy megszakad.
 *
 * ⚠️ Ez az eszköz **ÍR** a Play-hez (deactivate/activate). Csak akkor futtasd,
 * ha vállalod, hogy a vizsgált termék néhány percig nem vásárolható.
 *
 * Futtatás: node tools/verify-play-option-repair.mjs [--product <id>] [--minutes 8]
 */
import path from 'node:path';
import { createRequire } from 'node:module';
import { secretMultiline } from './lib/live-firebase.mjs';

const require = createRequire(path.join(process.cwd(), 'functions', 'index.js'));
const { google } = require('googleapis');

const packageName = 'hu.hungarianhardstyle.app';
/** Egy MEGJELENT kiadvány terméke (a 12123 régen kiment, van rajta eladás). */
const DEFAULT_PRODUCT = 'huhs_release_12123_extended_mp3_320';

function argValue(flag, fallback) {
  const index = process.argv.indexOf(flag);
  return index >= 0 && process.argv[index + 1] ? process.argv[index + 1] : fallback;
}

const productId = argValue('--product', DEFAULT_PRODUCT);
const maxMinutes = Number(argValue('--minutes', '8'));

async function optionState(client) {
  const product = (
    await client.monetization.onetimeproducts.get({ packageName, productId })
  ).data;
  const option = product?.purchaseOptions?.[0] || null;
  return { option, state: String(option?.state || '').toUpperCase() };
}

async function setState(client, activate) {
  const { option } = await optionState(client);
  const optionId = String(option?.purchaseOptionId || 'default');
  await client.monetization.onetimeproducts.purchaseOptions.batchUpdateStates({
    packageName,
    productId,
    requestBody: {
      requests: [
        activate
          ? { activatePurchaseOptionRequest: { packageName, productId, purchaseOptionId: optionId } }
          : { deactivatePurchaseOptionRequest: { packageName, productId, purchaseOptionId: optionId } },
      ],
    },
  });
}

async function main() {
  const serviceAccount = JSON.parse(secretMultiline('GOOGLE_PLAY_SERVICE_ACCOUNT_JSON'));
  const auth = new google.auth.GoogleAuth({
    credentials: serviceAccount,
    scopes: ['https://www.googleapis.com/auth/androidpublisher'],
  });
  const client = google.androidpublisher({ version: 'v3', auth });

  console.log(`Termék: ${productId}`);
  const before = await optionState(client);
  console.log(`Kezdeti állapot: ${before.state || '(nincs mező)'}`);
  if (before.state !== 'ACTIVE') {
    console.log('FIGYELEM  a termék nem ACTIVE — előbb aktívba tesszük, hogy tiszta legyen a mérés.');
    await setState(client, true);
  }

  let restored = false;
  try {
    console.log('');
    console.log('1) Szándékos DEAKTIVÁLÁS (a Play innentől nem adja el)…');
    await setState(client, false);
    const afterDeactivate = await optionState(client);
    console.log(`   állapot most: ${afterDeactivate.state || '(nincs mező)'}`);
    if (afterDeactivate.state === 'ACTIVE') {
      console.log('HIBA  a deaktiválás nem érvényesült — a mérés így nem értelmezhető.');
      return 1;
    }

    console.log('');
    console.log(`2) Várunk az ÜTEMEZETT szinkronra (legfeljebb ${maxMinutes} perc)…`);
    const deadline = Date.now() + maxMinutes * 60 * 1000;
    let last = afterDeactivate.state;
    while (Date.now() < deadline) {
      await new Promise((resolve) => setTimeout(resolve, 20_000));
      const current = await optionState(client);
      if (current.state !== last) {
        console.log(`   … ${current.state || '(nincs mező)'}`);
        last = current.state;
      }
      if (current.state === 'ACTIVE') {
        restored = true;
        break;
      }
    }

    console.log('');
    if (restored) {
      console.log('OK    az ütemezett szinkron VISSZAÁLLÍTOTTA a terméket ACTIVE-ra');
      console.log('      (ez bizonyítja, hogy az állapot-rendezés a gyors-úton is lefut)');
    } else {
      console.log(`HIBA  ${maxMinutes} perc alatt nem állt vissza (utolsó állapot: ${last || '(nincs mező)'})`);
      console.log('      — a szinkron naplóját kell megnézni: npx firebase functions:log --only syncWordPressLabelProducts');
    }
    return restored ? 0 : 1;
  } finally {
    // ⚠️ GARANCIA: soha nem hagyunk eladhatatlan terméket magunk után.
    const finalState = await optionState(client).catch(() => ({ state: '' }));
    if (finalState.state !== 'ACTIVE') {
      console.log('');
      console.log('HELYREÁLLÍTÁS: a terméket aktívba tesszük (nem maradhat eladhatatlanul).');
      await setState(client, true).catch((error) =>
        console.error(`HIBA  a helyreállítás nem sikerült: ${error?.message || error}`),
      );
      const check = await optionState(client).catch(() => ({ state: '' }));
      console.log(`   állapot a végén: ${check.state || '(nincs mező)'}`);
    }
  }
}

const code = await main();
process.exit(code ?? 0);
