#!/usr/bin/env node
/**
 * A **nyilvános Play-adatlap** ellenőrzése: megjelenik-e az adattörlés
 * (a fióktörlési link elfogadása után ez a látható visszaigazolás).
 *
 * Csak olvas (nyilvános oldal), és kiírja, mit talált — a Play a tartalmat
 * részben JS-sel tölti, ezért a hiány **nem** bizonyíték, csak a meglét.
 *
 * Használat: node tmp/probe-play-listing.mjs [--lang hu|en]
 */
const lang = process.argv.includes('--lang')
  ? process.argv[process.argv.indexOf('--lang') + 1]
  : 'hu';

const url =
  `https://play.google.com/store/apps/details?id=hu.hungarianhardstyle.app&hl=${lang}&gl=HU`;

const response = await fetch(url, {
  headers: {
    'user-agent':
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120 Safari/537.36',
    'accept-language': lang === 'hu' ? 'hu-HU,hu;q=0.9' : 'en-US,en;q=0.9',
  },
});

console.log(`URL: ${url}`);
console.log(`HTTP ${response.status}`);
const html = await response.text();
console.log(`HTML: ${(html.length / 1024).toFixed(0)} kB`);

const text = html
  .replace(/<script[\s\S]*?<\/script>/gi, ' ')
  .replace(/<style[\s\S]*?<\/style>/gi, ' ')
  .replace(/<[^>]+>/g, ' ')
  .replace(/&amp;/g, '&')
  .replace(/&#39;/g, "'")
  .replace(/\s+/g, ' ')
  .trim();

const probes = [
  ['adatbiztonság szakasz', /adatbiztons|data safety/i],
  ['adattörlés említése', /adatt[oö]rl|data deletion/i],
  ['fióktörlés említése', /fi[oó]k ?t[oö]rl|account deletion|delete your account/i],
  ['a törlési oldal URL-je a HTML-ben', /fiok-torles/],
  ['a frissítés dátuma (2026)', /2026\. (szept|okt)|Sep \d+, 2026|Oct \d+, 2026/i],
];

console.log('\n=== mit tartalmaz a nyilvános adatlap ===');
for (const [label, pattern] of probes) {
  const hit = pattern.test(text) || pattern.test(html);
  console.log(`  ${hit ? 'MEGVAN ' : 'nincs  '} ${label}`);
}

const index = text.search(/adatbiztons|data safety/i);
if (index >= 0) {
  console.log('\n=== az Adatbiztonság szakasz szövege ===');
  console.log(text.slice(index, index + 700));
}
