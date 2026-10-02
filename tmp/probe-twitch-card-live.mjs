#!/usr/bin/env node
/**
 * A Twitch-beharangozó **teljes láncának** mérése (csak olvas).
 *
 * A tulajdonos jelzése (2026-10-02): *„feldobtam egy képet a twitch
 * beharangozóhoz, de egyáltalán nem látom az iPhone appban”*. A lánc négy
 * szemből áll, és bármelyik elakadhat NÉMÁN:
 *   1. a **plugin** fent van-e (a beállítás a WordPress-adminban él);
 *   2. a **végpont** visszaadja-e a beállított képet;
 *   3. a **szinkron** beírta-e a Firestore-ba (a figyelő kör 5 percenként fut);
 *   4. az **app** mit olvas (a Firestore-dokumentum a kártya egyetlen forrása).
 *
 * Használat: node tmp/probe-twitch-card-live.mjs
 */
import { accessToken, firestoreGet } from '../tools/lib/live-firebase.mjs';

const WORDPRESS = 'https://hungarianhardstyle.hu';

console.log('=== 1) A plugin verziója (élő fejléc) ===');
const health = await readHealthHeader();
const api = /api=([0-9.]+)/.exec(health)?.[1] ?? '(nincs)';
console.log(`  api=${api}`);
console.log(`  ${api === '2.14.15' ? 'OK   a 2.14.15 (benne a Twitch beharangozó oldal)' : 'FIGYELEM: a 2.14.15-höz képest más verzió van fent — a beállító oldal csak abban létezik'}`);

console.log('\n=== 2) A végpont válasza (ezt olvassa a szinkron) ===');
let card = null;
try {
  const response = await fetch(`${WORDPRESS}/wp-json/huhs/v1/twitch-card`, {
    headers: { Accept: 'application/json' },
  });
  const text = await response.text();
  console.log(`  HTTP ${response.status}: ${text.slice(0, 300)}`);
  if (response.ok) {
    try {
      card = JSON.parse(text);
    } catch {
      card = null;
    }
  }
} catch (error) {
  console.log(`  HIBA: ${error.message}`);
}

console.log('\n=== 3) A Firestore-dokumentum (az app egyetlen forrása) ===');
const token = await accessToken();
const doc = await firestoreGet('app_settings/twitch', { token }).catch((error) => ({ error: error.message }));
console.log(`  ${JSON.stringify(doc)}`);

console.log('\n=== 4) Összevetés: miért nem látszik a kártya? ===');
const firestoreImage = String(doc?.imageUrl ?? '');
const offline = doc?.showWhenOffline === true;
const enabled = doc?.enabled !== false;
if (card) {
  console.log(`  plugin:  kép=${card.imageUrl ? 'van' : 'ÜRES'}  offline=${card.showWhenOffline === true}  engedve=${card.enabled !== false}`);
}
console.log(`  app:     kép=${firestoreImage ? 'van' : 'ÜRES'}  offline=${offline}  engedve=${enabled}`);
const ok = firestoreImage !== '' && offline && enabled;
if (ok) {
  console.log('  → a kártyának MEG KELL jelennie (élő adás nélkül is) — ha mégsem, az app-oldali olvasás a gyanús');
} else {
  const reasons = [];
  if (!firestoreImage) reasons.push('a Firestore-ban nincs kép (a szinkron még nem futott le, vagy a plugin végpont üres)');
  if (!offline) reasons.push('az „élő adás nélkül is” nincs bekapcsolva → a kártya csak ÉLŐ adásnál jelenik meg');
  if (!enabled) reasons.push('a kártya el van rejtve (enabled=false)');
  console.log(`  → ezért nem látszik: ${reasons.join('; ')}`);
}

async function readHealthHeader() {
  for (let attempt = 1; attempt <= 3; attempt += 1) {
    const response = await fetch(`${WORDPRESS}/wp-json/huhs/v1/posts?per_page=1&probe=card-${attempt}`, {
      headers: { Accept: 'application/json' },
    }).catch(() => null);
    const header = response?.headers?.get('x-huhs-health') ?? '';
    if (header) return header;
    await new Promise((resolve) => setTimeout(resolve, 1500));
  }
  return '';
}
