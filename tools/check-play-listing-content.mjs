#!/usr/bin/env node
/**
 * ÉLES, CSAK OLVAS: a **nyilvános bolt-lap tartalma** teljes-e?
 *
 * MIÉRT: a zárt tesztben a bolt-lap **nem látszik**, ezért a hiányai nem tűntek
 * fel. Amikor az app **nyilvánosra** megy, a leírás és a **képek** nélkül a bolt
 * lap üresen/hibásan jelenik meg — és a bírálat is elutasíthatja.
 *
 * Amit kiír nyelvenként és képtípusonként:
 *   - cím, rövid leírás, hosszú leírás (és a **hosszuk**, mert a Play limitál),
 *   - a **képek száma** (ikon, grafikus fejléc, telefonos képernyőképek, tablet),
 *   - és hogy megvan-e a **minimum** (ikon, grafikus fejléc, legalább 2 telefonos kép).
 *
 * ⚠️ A `listings`/`images` végpontok **edit-alapúak**: az eszköz a saját
 * ideiglenes piszkozatát a végén törli. Alapból **nem ír** semmit.
 *
 * Futtatás: node tools/check-play-listing-content.mjs [csomagnév]
 */
import path from 'node:path';
import { createRequire } from 'node:module';
import { secretMultiline } from './lib/live-firebase.mjs';

const require = createRequire(path.join(process.cwd(), 'functions', 'index.js'));
const { google } = require('googleapis');

const packageName = process.argv[2] || 'hu.hungarianhardstyle.app';

/** A Play limitjei (a hivatalos dokumentáció szerint). */
const LIMITS = {
  title: 30,
  shortDescription: 80,
  fullDescription: 4000,
};

/** A kötelező/minimális képtípusok. */
const REQUIRED_IMAGES = [
  ['icon', 'Alkalmazás ikon', 1],
  ['featureGraphic', 'Grafikus fejléc', 1],
  ['phoneScreenshots', 'Telefonos képernyőképek', 2],
];

async function main() {
  const serviceAccount = JSON.parse(secretMultiline('GOOGLE_PLAY_SERVICE_ACCOUNT_JSON'));
  const auth = new google.auth.GoogleAuth({
    credentials: serviceAccount,
    scopes: ['https://www.googleapis.com/auth/androidpublisher'],
  });
  const client = google.androidpublisher({ version: 'v3', auth });

  console.log(`csomagnév: ${packageName}`);
  const edit = await client.edits.insert({ packageName });
  const editId = edit.data.id;
  let problems = 0;
  try {
    const listings = await client.edits.listings.list({ packageName, editId });
    const items = listings.data?.listings || [];
    console.log(`nyelvi bejegyzés: ${items.length} db`);
    console.log('');

    if (!items.length) {
      console.log('HIBA  egyetlen nyelvi bejegyzés sincs — a nyilvános bolt-lap üres lenne!');
      problems += 1;
    }

    for (const item of items) {
      const language = item.language || '(ismeretlen)';
      console.log(`NYELV: ${language}`);
      for (const [key, label] of [
        ['title', 'cím'],
        ['shortDescription', 'rövid leírás'],
        ['fullDescription', 'hosszú leírás'],
      ]) {
        const value = String(item[key] || '');
        const limit = LIMITS[key];
        const ok = value.trim().length > 0 && value.length <= limit;
        if (!ok) problems += 1;
        console.log(
          `   ${ok ? 'OK   ' : 'HIBA '} ${label}: ${value.length}/${limit} karakter` +
            (value.trim().length ? '' : '  ← ÜRES!'),
        );
      }
      console.log('');
    }

    for (const language of items.map((item) => item.language).filter(Boolean)) {
      console.log(`KÉPEK (${language}):`);
      for (const [imageType, label, minimum] of REQUIRED_IMAGES) {
        try {
          const response = await client.edits.images.list({
            packageName,
            editId,
            language,
            imageType,
          });
          const count = (response.data?.images || []).length;
          const ok = count >= minimum;
          if (!ok) problems += 1;
          console.log(
            `   ${ok ? 'OK   ' : 'HIBA '} ${label}: ${count} db (minimum ${minimum})`,
          );
        } catch (error) {
          const message = String(error?.message || error).replace(/\s+/g, ' ');
          console.log(`   FIGYELEM  ${label}: nem kérdezhető le (${message.slice(0, 90)})`);
        }
      }
      // A tabletes képek nem kötelezők, de jó tudni róluk.
      for (const [imageType, label] of [
        ['sevenInchScreenshots', '7"-es tablet képek'],
        ['tenInchScreenshots', '10"-es tablet képek'],
      ]) {
        try {
          const response = await client.edits.images.list({
            packageName,
            editId,
            language,
            imageType,
          });
          const count = (response.data?.images || []).length;
          console.log(`   (nem kötelező) ${label}: ${count} db`);
        } catch (_) {
          /* nem kérdezhető le — nem hiba */
        }
      }
      console.log('');
    }
  } finally {
    await client.edits.delete({ packageName, editId }).catch(() => {});
  }

  console.log(
    problems === 0
      ? 'OK    a bolt-lap tartalma teljes (leírások + kötelező képek).'
      : `HIBA  ${problems} hiányosság van a bolt-lapon — ezek a nyilvános megjelenést rontják, és a bírálat is elutasíthatja.`,
  );
  return problems === 0 ? 0 : 1;
}

const code = await main();
process.exit(code ?? 0);
