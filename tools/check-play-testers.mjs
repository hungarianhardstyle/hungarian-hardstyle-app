#!/usr/bin/env node
/**
 * ÉLES, CSAK OLVAS: kik és hányan vannak a **tesztelői listákon** sávonként?
 *
 * MIÉRT: a **személyes** fejlesztői fiókoknál a **nyilvános kiadás** (production
 * access) feltétele, hogy a zárt tesztben **legalább 12 tesztelő** legyen, és ők
 * **legalább 14 napja folyamatosan** jelentkezve legyenek. Ez a létszám a Play
 * Console-ban látszik, de a **lista tartalma** az API-ból is kiolvasható — így
 * pontosan tudjuk, hány ember van bent, és melyik sávon.
 *
 * ⚠️ A tesztelői lista **Google-csoportot** is tartalmazhat: ilyenkor a
 * Console csak a csoport címét mutatja, a **tagok számát nem** — a 12 fős
 * követelményhez ezért a csoport létszámát a Google Adminban kell megnézni.
 *
 * ⚠️ A `testers` végpont **edit-alapú**: az eszköz a saját ideiglenes
 * piszkozatát a végén törli. Alapból **nem ír** semmit.
 *
 * Futtatás: node tools/check-play-testers.mjs [csomagnév]
 */
import path from 'node:path';
import { createRequire } from 'node:module';
import { secretMultiline } from './lib/live-firebase.mjs';

const require = createRequire(path.join(process.cwd(), 'functions', 'index.js'));
const { google } = require('googleapis');

const packageName = process.argv[2] || 'hu.hungarianhardstyle.app';

/** Az e-mail cím maszkolása (a napló és a doksi ne tartalmazzon teljes címet). */
function mask(email) {
  const text = String(email || '').trim();
  const at = text.indexOf('@');
  if (at <= 0) return text;
  const name = text.slice(0, at);
  const domain = text.slice(at);
  const head = name.slice(0, 1);
  return `${head}${'*'.repeat(Math.max(1, Math.min(name.length - 1, 6)))}${domain}`;
}

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
  try {
    const tracks = await client.edits.tracks.list({ packageName, editId });
    const names = (tracks.data.tracks || []).map((track) => track.track).filter(Boolean);
    console.log(`sávok: ${names.join(', ') || '(nincs)'}`);
    console.log('');

    for (const track of names) {
      try {
        const response = await client.edits.testers.get({ packageName, editId, track });
        const groups = response.data?.googleGroups || [];
        const testers = response.data?.testers || [];
        console.log(`SÁV „${track}"`);
        console.log(`   egyéni tesztelő: ${testers.length} db`);
        for (const email of testers) console.log(`      - ${mask(email)}`);
        console.log(`   Google-csoport: ${groups.length} db`);
        for (const group of groups) {
          console.log(
            `      - ${group}  ⚠️ a tagok száma az API-ból NEM látszik (Google Admin kell hozzá)`,
          );
        }
        if (!testers.length && !groups.length) {
          // ⚠️ ÉLES TAPASZTALAT (2026-09-22): az API itt **0-t adott vissza**,
          // miközben a Play Console-ban **30+ tesztelő** volt beállítva. Ez a
          // végpont tehát **nem bizonyíték** a létszámra — a Console az irányadó.
          // E nélkül a figyelmeztetés nélkül ez a sor **hamis riasztást** adott
          // (azt sugallta, hogy nincs tesztelő, és a nyilvános kiadás feltétele
          // nem teljesül).
          console.log(
            '      ⚠️ az API itt 0-t ad — ez NEM jelenti azt, hogy nincs tesztelő! ' +
              '(ÉLESEN MÉRVE: a Console-ban 30+ tesztelő volt, miközben ez a végpont 0-t mutatott.)',
          );
        }
        console.log('');
      } catch (error) {
        const message = String(error?.message || error).replace(/\s+/g, ' ');
        console.log(`SÁV „${track}": a tesztelői lista nem kérdezhető le (${message.slice(0, 110)})`);
        console.log('');
      }
    }

    // A zárt teszt kezdete: mikor került ki az ELSŐ build az adott sávra?
    // (A 14 napos követelményhez a Console mutatja a pontos állapotot, de a
    // kiadások listája segít megérteni, mióta fut a teszt.)
    for (const track of names) {
      const info = (tracks.data.tracks || []).find((item) => item.track === track);
      const releases = Array.isArray(info?.releases) ? info.releases : [];
      if (!releases.length) continue;
      const builds = releases
        .map((release) => `${release.status || '?'}${release.userFraction ? ` (${release.userFraction})` : ''}`)
        .join(', ');
      console.log(`SÁV „${track}" kiadásai: ${releases.length} db — ${builds}`);
    }
  } finally {
    await client.edits.delete({ packageName, editId }).catch(() => {});
  }

  console.log('');
  console.log(
    'FIGYELEM  A 12 tesztelő / 14 folyamatos nap állapotát a Play Console mutatja ' +
      '(Test and release → Closed testing / Production access) — az API ezt nem adja ki.',
  );
  return 0;
}

const code = await main();
process.exit(code ?? 0);
