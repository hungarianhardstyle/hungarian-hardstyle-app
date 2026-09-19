#!/usr/bin/env node
/**
 * ÉLES: mi van tényleg a Google Play-en? (csak olvas)
 *
 * MIÉRT: az „éles már?” kérdésre a kód nem válasz, a nyilvános Play-oldal pedig
 * zárt tesztnél 404-et ad. Ez az eszköz a Play Developer API-t kérdezi meg
 * **olvasásra**: milyen sávok (track) vannak, azokon melyik build
 * (`versionCode`) él, milyen állapotban, és milyen kiadási szöveggel.
 *
 * Titkot nem tartalmaz: a `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` a Secret
 * Managerből jön futásidőben. **Nem tölt fel semmit** — egy ideiglenes
 * „edit"-et nyit az olvasáshoz, majd törli (ez a Play API előírása az
 * olvasáshoz is).
 *
 * Futtatás: node tools/check-play-track.mjs [csomagnév]
 */
import path from 'node:path';
import { createRequire } from 'node:module';
import { PROJECT, secretMultiline } from './lib/live-firebase.mjs';

// A `googleapis` a functions függőségei között van, ezért onnan oldjuk fel —
// így nem kell a gyökérprojektbe új csomag.
const require = createRequire(path.join(process.cwd(), 'functions', 'index.js'));
const { google } = require('googleapis');

const packageName = process.argv[2] || 'hu.hungarianhardstyle.app';

async function main() {
  const serviceAccount = JSON.parse(secretMultiline('GOOGLE_PLAY_SERVICE_ACCOUNT_JSON'));
  const auth = new google.auth.GoogleAuth({
    credentials: serviceAccount,
    scopes: ['https://www.googleapis.com/auth/androidpublisher'],
  });
  const client = google.androidpublisher({ version: 'v3', auth });

  const edit = await client.edits.insert({ packageName });
  const editId = edit.data.id;
  console.log(`projekt=${PROJECT} csomag=${packageName} edit=${editId}\n`);
  try {
    const tracks = await client.edits.tracks.list({ packageName, editId });
    const list = tracks.data.tracks || [];
    if (!list.length) console.log('Nincs egyetlen sáv sem (track).');
    for (const track of list) {
      console.log(`SÁV: ${track.track}`);
      for (const release of track.releases || []) {
        console.log(
          `   állapot=${release.status} build=${(release.versionCodes || []).join(', ')} ` +
            `név=${release.name || '-'} feltöltve=${release.releaseNotes ? 'van kiadási szöveg' : 'nincs szöveg'}`,
        );
        for (const note of release.releaseNotes || []) {
          console.log(`      [${note.language}] ${String(note.text || '').replace(/\n/g, ' | ')}`);
        }
      }
    }
    const bundles = await client.edits.bundles.list({ packageName, editId });
    const codes = (bundles.data.bundles || []).map((bundle) => bundle.versionCode).sort((a, b) => a - b);
    console.log(`\nFELTÖLTÖTT AAB-ek (versionCode): ${codes.join(', ') || 'egy sincs'}`);
  } finally {
    // Az olvasáshoz is edit kell; a végén töröljük, hogy semmi ne maradjon.
    await client.edits.delete({ packageName, editId }).catch(() => {});
  }
}

main().catch((error) => {
  console.error(`HIBA: ${error?.errors?.[0]?.message || error.message}`);
  process.exitCode = 2;
});
