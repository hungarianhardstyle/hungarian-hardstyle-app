#!/usr/bin/env node
/**
 * **releasehardstyle.nl — egy kiadvány ADATLAPJA** (`/release/{targetid}`).
 *
 * A lista koppintásra ide visz (`releasetrackerlist.js`), ezért itt vannak az
 * **előnép-/hallgatási linkek** (a tulajdonos kérése: *„a prew linkekkel
 * együtt"*). A mérés megmutatja, milyen mezők és milyen platform-linkek
 * vannak egy kiadványon.
 *
 * Használat: node tmp/probe-releasehardstyle-5.mjs [targetid]
 */

const BASE = 'https://releasehardstyle.nl';
const UA = 'HUHS-app-probe/1.0 (+https://hungarianhardstyle.hu)';
const targetId = process.argv[2] || 'Y3ULWLmFX7ne';

const response = await fetch(`${BASE}/release/${targetId}`, { headers: { 'User-Agent': UA } });
const html = await response.text();
console.log(`/release/${targetId} → HTTP ${response.status}, ${html.length} bájt`);

/* --- 1. Cím és a fő adatok ------------------------------------------- */

const title = /<title>([^<]*)<\/title>/.exec(html)?.[1] || '';
const ogTitle = /property="og:title" content="([^"]*)"/.exec(html)?.[1] || '';
const ogImage = /property="og:image" content="([^"]*)"/.exec(html)?.[1] || '';
const description = /name="description" content="([^"]*)"/.exec(html)?.[1] || '';
console.log(`  <title>: ${title}`);
console.log(`  og:title: ${ogTitle}`);
console.log(`  og:image: ${ogImage}`);
console.log(`  description: ${description.slice(0, 160)}`);

/* --- 2. Platform-linkek ---------------------------------------------- */

const links = [...new Set([...html.matchAll(/href="([^"]+)"/g)].map((m) => m[1]))]
  .filter((href) => /^https?:\/\//.test(href) && !href.includes('releasehardstyle.nl'));
const platforms = {
  spotify: /spotify\.com/,
  beatport: /beatport\.com/,
  hardstylecom: /hardstyle\.com/,
  appleMusic: /music\.apple\.com/,
  deezer: /deezer\.com/,
  youtube: /youtube\.com|youtu\.be/,
  soundcloud: /soundcloud\.com/,
  traxsource: /traxsource\.com/,
  bandcamp: /bandcamp\.com/,
  junodownload: /junodownload\.com/,
  amazon: /amazon\./,
};
console.log('\n  Platform-linkek:');
for (const [name, regex] of Object.entries(platforms)) {
  const hits = links.filter((href) => regex.test(href));
  if (hits.length) {
    console.log(`    ${name}: ${hits.length}`);
    for (const href of hits.slice(0, 3)) console.log(`      ${href}`);
  }
}

/* --- 3. Beágyazott lejátszók / preview --------------------------------- */

for (const pattern of [
  ['iframe', /<iframe[^>]+>/g],
  ['audio', /<audio[^>]*>/g],
  ['preview szó', /preview/gi],
  ['data-preview', /data-preview[^ >]*/gi],
  ['targetid', /targetid="[^"]+"/g],
]) {
  const hits = [...html.matchAll(pattern[1])];
  console.log(`\n  ${pattern[0]}: ${hits.length}`);
  for (const hit of hits.slice(0, 3)) console.log(`    ${hit[0].replace(/\s+/g, ' ').slice(0, 240)}`);
}

/* --- 4. A törzs szövege (a mezők kiolvasásához) ----------------------- */

const text = html
  .replace(/<script[\s\S]*?<\/script>/g, ' ')
  .replace(/<style[\s\S]*?<\/style>/g, ' ')
  .replace(/<[^>]+>/g, '\n')
  .split('\n')
  .map((line) => line.trim())
  .filter((line) => line.length > 1);
console.log('\n  Az oldal szöveges tartalma (első 40 sor):');
for (const line of text.slice(0, 40)) console.log(`    ${line.slice(0, 110)}`);
