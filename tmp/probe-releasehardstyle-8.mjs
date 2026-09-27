#!/usr/bin/env node
/**
 * **releasehardstyle.nl — a PREVIEWS blokk** (a tulajdonos kérése: *„a prew
 * linkekkel együtt"*).
 *
 * A mérés: a `/release/{id}` adatlapokon van egy `PREVIEWS` szakasz; az egyik
 * kiadványon sem volt találat. Meg kell nézni **több** kiadványt, hogy lássuk,
 * milyen formában vannak a preview linkek (beágyazott lejátszó, mp3, platform),
 * és hogy a `/discography/` adja-e a teljes előzményt.
 *
 * Használat: node tmp/probe-releasehardstyle-8.mjs
 */

const UA = 'HUHS-app-probe/1.0 (+https://hungarianhardstyle.hu)';
const get = async (url) => (await fetch(url, { headers: { 'User-Agent': UA } })).text();

const list = await get('https://releasehardstyle.nl/releases/');
const ids = [...new Set([...list.matchAll(/targetid="([^"]+)"/g)].map((m) => m[1]))];
console.log(`a listán ${ids.length} kiadvány — az első 12 adatlapját nézzük meg`);

let withPreviews = 0;
for (const id of ids.slice(0, 12)) {
  const html = await get(`https://releasehardstyle.nl/release/${id}`);
  const start = html.indexOf('PREVIEWS');
  const block = start > 0 ? html.slice(start, start + 1600) : '';
  const found = /didn't find any previews/i.test(block);
  const title = /Title:\s*([^<|]{0,80})/.exec(html)?.[1]?.trim() || '(nincs cím)';
  if (found) {
    console.log(`  ${id}: nincs preview (${title})`);
    continue;
  }
  withPreviews += 1;
  console.log(`\n  ${id}: VAN PREVIEW (${title})`);
  console.log(`    ${block.replace(/<script[\s\S]*?<\/script>/g, ' ').replace(/\s+/g, ' ').slice(0, 700)}`);
  const media = [...new Set([...block.matchAll(/(?:src|href)="([^"]+)"/g)].map((m) => m[1]))];
  for (const href of media.slice(0, 8)) console.log(`      → ${href}`);
}

console.log(`\n${withPreviews}/12 kiadványon volt preview`);

/* --- A discography oldal (teljes előzmény?) --------------------------- */

const discography = await get('https://releasehardstyle.nl/discography/');
const discEntries = [...discography.matchAll(/class="[^"]*release[^"]*"/g)].length;
console.log(`\n/discography/: ${discography.length} bájt, „release" class: ${discEntries}`);
console.log(`  van-e benne lista-elem: ${/releasetracker-list-entry/.test(discography)}`);
console.log(`  van-e lapozás: ${/page\/2|load ?more|pagination/i.test(discography)}`);
const years = [...new Set([...discography.matchAll(/20[0-9]{2}/g)].map((m) => m[0]))].sort();
console.log(`  évszámok: ${years.slice(0, 12).join(', ')}${years.length > 12 ? ' …' : ''}`);
