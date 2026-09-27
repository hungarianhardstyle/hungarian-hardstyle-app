#!/usr/bin/env node
/**
 * **releasehardstyle.nl — a RELEASE INFO blokk teljes kiolvasása**, és a lista
 * mélysége (hány kiadvány, meddig visszamenőleg, van-e lapozás).
 *
 * Használat: node tmp/probe-releasehardstyle-7.mjs
 */

const UA = 'HUHS-app-probe/1.0 (+https://hungarianhardstyle.hu)';
const get = async (url) => (await fetch(url, { headers: { 'User-Agent': UA } })).text();

/* --- 1. Egy adatlap teljes info-blokkja ------------------------------- */

const detail = await get('https://releasehardstyle.nl/release/Y3ULWLmFX7ne');
const infoStart = detail.indexOf("releasetracker_details-info_container-inner");
const infoBlock = detail.slice(infoStart, infoStart + 2600);
const cleaned = infoBlock
  .replace(/<script[\s\S]*?<\/script>/g, ' ')
  .replace(/<[^>]+>/g, '|')
  .replace(/\|+/g, '|')
  .replace(/\s+/g, ' ')
  .trim();
console.log('=== RELEASE INFO blokk (tisztítva) ===');
console.log(cleaned.slice(0, 900));

const detailLinks = [...new Set([...infoBlock.matchAll(/href="([^"]+)"/g)].map((m) => m[1]))];
console.log('\nA blokk linkjei:');
for (const href of detailLinks.slice(0, 15)) console.log(`  ${href}`);

/* --- 2. A lista mélysége és lapozása ---------------------------------- */

const list = await get('https://releasehardstyle.nl/releases/');
const dates = [...list.matchAll(/releasetracker-list-entry-info-2'>\s*<div>\s*([0-9]{2} [A-Za-z]{3} [0-9]{4})/g)].map((m) => m[1]);
const parsed = dates.map((text) => Date.parse(text)).filter((value) => Number.isFinite(value));
console.log(`\n=== A LISTA ===`);
console.log(`  dátum-bejegyzések: ${dates.length}`);
if (parsed.length) {
  const newest = new Date(Math.max(...parsed)).toISOString().slice(0, 10);
  const oldest = new Date(Math.min(...parsed)).toISOString().slice(0, 10);
  console.log(`  legfrissebb: ${newest}`);
  console.log(`  legrégebbi:  ${oldest}`);
}
const uniqueDates = [...new Set(dates)];
console.log(`  egyedi dátumok: ${uniqueDates.length} (${uniqueDates.slice(0, 6).join(', ')} …)`);
console.log(`  „load more" / lapozás a HTML-ben: ${/load ?more|pagination|page\/2|next page/i.test(list)}`);
const containers = [...list.matchAll(/releasetracker-list-container/g)].length;
console.log(`  lista-konténerek: ${containers}`);

/* --- 3. Van-e szűrő (hónap/év, kereső)? ------------------------------- */

for (const pattern of [
  ['select', /<select[^>]*>/gi],
  ['input', /<input[^>]*>/gi],
  ['kereső placeholder', /placeholder="[^"]*"/gi],
  ['filter szó', /filter/gi],
]) {
  console.log(`  ${pattern[0]}: ${[...list.matchAll(pattern[1])].length}`);
}
