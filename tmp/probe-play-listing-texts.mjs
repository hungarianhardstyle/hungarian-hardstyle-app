// A Play-ÁRUHÁZLISTA szövegei (csak olvas): cím, rövid és hosszú leírás nyelvenként.
import path from 'node:path';
import { createRequire } from 'node:module';
import fs from 'node:fs';
import { secretMultiline } from '../tools/lib/live-firebase.mjs';

const require = createRequire(path.join(process.cwd(), 'functions', 'index.js'));
const { google } = require('googleapis');

const packageName = 'hu.hungarianhardstyle.app';
const serviceAccount = JSON.parse(secretMultiline('GOOGLE_PLAY_SERVICE_ACCOUNT_JSON'));
const auth = new google.auth.GoogleAuth({
  credentials: serviceAccount,
  scopes: ['https://www.googleapis.com/auth/androidpublisher'],
});
const client = google.androidpublisher({ version: 'v3', auth });

const edit = await client.edits.insert({ packageName });
const editId = edit.data.id;
const report = {};
try {
  const listings = await client.edits.listings.list({ packageName, editId });
  for (const item of listings.data.listings || []) {
    report[item.language] = {
      title: item.title || '',
      shortDescription: item.shortDescription || '',
      fullDescriptionLength: (item.fullDescription || '').length,
      fullDescription: item.fullDescription || '',
      video: item.video || '',
    };
    console.log(`=== ${item.language} ===`);
    console.log(`cím (${(item.title || '').length}/30): ${item.title}`);
    console.log(`rövid leírás (${(item.shortDescription || '').length}/80): ${item.shortDescription}`);
    console.log(`hosszú leírás: ${(item.fullDescription || '').length}/4000 karakter, videó: ${item.video || 'nincs'}`);
    console.log('--- hosszú leírás ---');
    console.log(item.fullDescription || '(üres)');
    console.log('');
  }

  // Képek: típusonként kell kérdezni (a Play API megköveteli az `imageType`-ot).
  const imageTypes = [
    'icon',
    'featureGraphic',
    'promoGraphic',
    'tvBanner',
    'phoneScreenshots',
    'sevenInchScreenshots',
    'tenInchScreenshots',
    'wearScreenshots',
    'tvScreenshots',
  ];
  console.log('=== KÉPEK (hu-HU) ===');
  const imageReport = {};
  for (const imageType of imageTypes) {
    try {
      const images = await client.edits.images.list({ packageName, editId, language: 'hu-HU', imageType });
      const urls = (images.data.images || []).map((image) => image.url || image.id || '?');
      imageReport[imageType] = urls;
      console.log(`  ${imageType}: ${urls.length} db`);
      for (const url of urls) console.log(`      ${url}`);
    } catch (error) {
      console.log(`  ${imageType}: (hiba: ${String(error.message).split('\n')[0].slice(0, 80)})`);
    }
  }
  report.images = imageReport;
} finally {
  await client.edits.delete({ packageName, editId }).catch(() => {});
}
fs.writeFileSync('tmp/play-listing-texts.json', JSON.stringify(report, null, 2), 'utf8');
