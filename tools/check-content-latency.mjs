#!/usr/bin/env node
'use strict';
/*
 * tools/check-content-latency.mjs — mennyi időbe telik az app adatbetöltése?
 *
 * A tulajdonos jelzése: *„sok adat lassan tölt be"* — ez az eszköz **méri**,
 * hol megy el az idő, mielőtt bármit átírnánk. Minden hívás **csak olvasás**
 * (GET), és a hívások száma kicsi.
 *
 * Amit mér:
 *   1. a WordPress nyilvános végpontok (a DJ-adatlap, a DJ-lista, a kiadványok,
 *      a hírek) — ezek mennek az app leggyakoribb képernyőin;
 *   2. ugyanaz **másodszor** — így látszik a WordPress-oldali gyorsítótár és a
 *      hálózat/megbízható késleltetés különbsége;
 *   3. a **privát** `claim-emails` végpont (ezt hívja a `getArtistClaimStatus`
 *      szerveroldala, amikor a claim-állapotot dönti el — vagyis ez a
 *      „ez az enyém?" gomb szerveroldali költsége);
 *   4. a `getArtistClaimStatus` callable **boot-ideje** (hitelesítés nélküli
 *      hívás: a függvénynek fel kell élednie, mielőtt elutasít — ez a cold start
 *      felső becslése; a válasz 400/401, adat nem keletkezik).
 *
 * Kimenet: minden végpontnál az egyes futások ms-ban + a legjobb (meleg) érték.
 *
 * Használat:
 *   node tools/check-content-latency.mjs               # 3 futás / végpont
 *   node tools/check-content-latency.mjs --runs 5
 *   node tools/check-content-latency.mjs --self-test   # csak a számítás öntesztje
 */

import { fileURLToPath } from 'node:url';
import { secretMultiline } from './lib/live-firebase.mjs';

const WORDPRESS_BASE_URL = 'https://hungarianhardstyle.hu/wp-json/huhs/v1';
const CALLABLE_CLAIM_STATUS =
  'https://us-central1-hungarian-hardstyle.cloudfunctions.net/getArtistClaimStatus';

const args = process.argv.slice(2);
const runsIndex = args.indexOf('--runs');
const runs = runsIndex >= 0 ? Math.max(1, Math.min(10, Number(args[runsIndex + 1]) || 3)) : 3;

/** A mért értékek összegzése (tiszta: önteszttel mérhető). */
export function summarise(samples) {
  const ok = samples.filter((value) => Number.isFinite(value) && value >= 0);
  if (!ok.length) return { count: 0, best: null, median: null, worst: null };
  const sorted = [...ok].sort((a, b) => a - b);
  const middle = Math.floor(sorted.length / 2);
  const median = sorted.length % 2 === 1
    ? sorted[middle]
    : Math.round((sorted[middle - 1] + sorted[middle]) / 2);
  return { count: sorted.length, best: sorted[0], median, worst: sorted[sorted.length - 1] };
}

async function timeRequest(label, url, { headers = {}, method = 'GET' } = {}) {
  const samples = [];
  const notes = [];
  for (let attempt = 1; attempt <= runs; attempt += 1) {
    const started = Date.now();
    let status = 0;
    let note = '';
    try {
      const response = await fetch(url, { method, headers });
      status = response.status;
      await response.arrayBuffer().catch(() => null);
      if (!response.ok) note = `HTTP ${status}`;
    } catch (error) {
      note = String(error?.message || error).slice(0, 60);
    }
    const elapsed = Date.now() - started;
    samples.push(elapsed);
    notes.push(note);
    process.stdout.write(`  ${label} #${attempt}: ${elapsed} ms${note ? ` (${note})` : ''}\n`);
  }
  const stats = summarise(samples);
  const failed = notes.filter(Boolean).length;
  return { label, stats, failed, notes };
}

function selfTest() {
  const cases = [
    ['egy érték', summarise([120]).median === 120],
    ['páratlan medián', summarise([100, 300, 200]).median === 200],
    ['páros medián', summarise([100, 200]).median === 150],
    ['legjobb a legkisebb', summarise([500, 90, 250]).best === 90],
    ['a hibás érték kimarad', summarise([100, Number.NaN, -5]).count === 1],
    ['üres bemenet nem hibázik', summarise([]).median === null],
  ];
  let failed = 0;
  for (const [name, ok] of cases) {
    console.log(`  ${ok ? 'OK  ' : 'HIBA'} ${name}`);
    if (!ok) failed += 1;
  }
  console.log(failed === 0 ? `ÖNTESZT: ${cases.length}/${cases.length} OK` : `ÖNTESZT: ${failed} bukott`);
  process.exit(failed === 0 ? 0 : 1);
}

if (args.includes('--self-test')) {
  selfTest();
}

async function main() {
  console.log(`Adatbetöltés mérése — ${runs} futás / végpont (csak olvasás)\n`);

  console.log('1) WordPress nyilvános végpontok (az app ezeket tölti):');
  const publicTargets = [
    ['DJ-adatlap /artists/12812', `${WORDPRESS_BASE_URL}/artists/12812`],
    ['DJ-lista /artists', `${WORDPRESS_BASE_URL}/artists`],
    ['Kiadványok /releases', `${WORDPRESS_BASE_URL}/releases`],
    ['Hírek /posts', `${WORDPRESS_BASE_URL}/posts`],
  ];
  for (const [label, url] of publicTargets) {
    await timeRequest(label, url);
  }

  console.log('\n2) A claim-ellenőrzés szerveroldali költsége (privát végpont):');
  let authorization = null;
  try {
    const user = secretMultiline('WORDPRESS_USERNAME');
    const password = secretMultiline('WORDPRESS_APPLICATION_PASSWORD');
    authorization = `Basic ${Buffer.from(`${user}:${password}`).toString('base64')}`;
  } catch (error) {
    console.log(`  (kihagyva: ${String(error?.message || error).slice(0, 80)})`);
  }
  if (authorization) {
    await timeRequest(
      'privát /artists/12812/claim-emails',
      `${WORDPRESS_BASE_URL}/artists/12812/claim-emails`,
      { headers: { Authorization: authorization } },
    );
  }

  console.log('\n3) A getArtistClaimStatus callable boot-ideje (hitelesítés nélkül, 400/401 a válasz):');
  await timeRequest('callable getArtistClaimStatus', CALLABLE_CLAIM_STATUS, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
  });

  console.log(
    '\n  Értelmezés: az 1) pont első futása a „hideg" eset (WP gyorsítótár nélkül),\n' +
      '  a legjobb érték a meleg. A 3) pont azért fontos, mert az app a claim-állapotot\n' +
      '  („ez az enyém?") MINDEN adatlap-megnyitásnál külön callable-lal kéri — a mentett\n' +
      '  válasz ezt a teljes kör-utat spórolja meg.',
  );
}

const isMain = process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1];
if (isMain) {
  await main();
}
