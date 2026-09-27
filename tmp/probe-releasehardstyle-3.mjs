#!/usr/bin/env node
/**
 * **releasehardstyle.nl/releases/ — a lista szerkezete** (natív beépítéshez).
 *
 * A mérés célja: kiderül-e a HTML-ből, hogy egy kiadvány milyen mezőkből áll
 * (előadó, cím, kiadó, dátum, borító, előnép-link), és hogy a lista
 * **statikus HTML** vagy **JS/AJAX** tölti-e.
 *
 * Használat: node tmp/probe-releasehardstyle-3.mjs
 */

const BASE = 'https://releasehardstyle.nl';
const UA = 'HUHS-app-probe/1.0 (+https://hungarianhardstyle.hu)';

const response = await fetch(`${BASE}/releases/`, { headers: { 'User-Agent': UA } });
const html = await response.text();
console.log(`/releases/: HTTP ${response.status}, ${html.length} bájt`);

/* --- 1. Beágyazott JSON / AJAX végpontok ------------------------------ */

const jsonBlocks = [...html.matchAll(/<script[^>]*type="application\/json"[^>]*>([\s\S]*?)<\/script>/g)];
console.log(`\nBeágyazott JSON blokkok: ${jsonBlocks.length}`);
for (const block of jsonBlocks.slice(0, 3)) {
  const text = block[1].trim();
  console.log(`  ${text.length} bájt: ${text.slice(0, 160)}…`);
}

const ajax = [...new Set([...html.matchAll(/admin-ajax\.php[^"'<>\s]*/g)].map((m) => m[0]))];
console.log(`admin-ajax hivatkozások: ${ajax.length}`);
for (const hit of ajax.slice(0, 5)) console.log(`  ${hit}`);
const rest = [...new Set([...html.matchAll(/wp-json\/[a-z0-9_\-/]+/gi)].map((m) => m[0]))];
console.log(`wp-json hivatkozások: ${rest.length}`);
for (const hit of rest.slice(0, 8)) console.log(`  ${hit}`);

/* --- 2. A Spotify-linkek környezete (egy kiadvány felépítése) --------- */

const spotifyIndex = html.search(/open\.spotify\.com\/track/);
if (spotifyIndex < 0) {
  console.log('\nNincs Spotify track link a HTML-ben (JS tölti?).');
} else {
  const window = html.slice(Math.max(0, spotifyIndex - 1800), spotifyIndex + 400);
  console.log('\nEgy kiadvány környezete (a Spotify-link előtti 1800 karakter, tisztítva):');
  console.log(window.replace(/\s+/g, ' ').slice(0, 2200));
}

/* --- 3. Ismétlődő szerkezet keresése --------------------------------- */

for (const pattern of [
  ['class="release', /class="[^"]*release[^"]*"/gi],
  ['elementor-widget', /elementor-widget-[a-z0-9_-]+/gi],
  ['<table', /<table/gi],
  ['<tr', /<tr[\s>]/gi],
  ['spotify iframe', /<iframe[^>]*spotify[^>]*>/gi],
  ['data-attributes', /data-[a-z-]+="[^"]{0,60}"/gi],
]) {
  const hits = [...html.matchAll(pattern[1])].length;
  console.log(`${pattern[0]}: ${hits}`);
}

/* --- 4. A Spotify-embedek típusa ------------------------------------- */

const iframes = [...html.matchAll(/<iframe[^>]+>/g)].map((m) => m[0]);
console.log(`\n<iframe>-ek: ${iframes.length}`);
const spotifyIframes = iframes.filter((frame) => /spotify/i.test(frame));
console.log(`  ebből Spotify: ${spotifyIframes.length}`);
if (spotifyIframes[0]) console.log(`  első: ${spotifyIframes[0].slice(0, 300)}`);

/* --- 5. Szöveges minta: előadó – cím sorok --------------------------- */

const text = html
  .replace(/<script[\s\S]*?<\/script>/g, ' ')
  .replace(/<style[\s\S]*?<\/style>/g, ' ')
  .replace(/<[^>]+>/g, '\n')
  .split('\n')
  .map((line) => line.trim())
  .filter((line) => line.length > 2 && line.length < 80);
const counts = new Map();
for (const line of text) counts.set(line, (counts.get(line) || 0) + 1);
const repeated = [...counts.entries()].filter(([, count]) => count > 3).sort((a, b) => b[1] - a[1]);
console.log('\nGyakori sorok (a lista szerkezetének nyoma, top 15):');
for (const [line, count] of repeated.slice(0, 15)) console.log(`  ${count}×  ${line}`);
