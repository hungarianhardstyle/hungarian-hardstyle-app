#!/usr/bin/env node
/**
 * Mikor készült a fióktörlési oldal? (WordPress REST API, csak olvasás.)
 *
 * Ez dönti el, hogy a Play-elutasítás oka lehet-e az, hogy a link **akkor még
 * nem élt** (az oldal a felülvizsgálat UTÁN készült el), vagy pedig a link
 * egyszerűen **más** (elgépelt).
 *
 * Használat: node tmp/probe-deletion-page-dates.mjs
 */
const endpoints = [
  'https://hungarianhardstyle.hu/wp-json/wp/v2/pages?slug=fiok-torles&_fields=id,slug,link,date,modified,status,title',
  'https://hungarianhardstyle.hu/wp-json/wp/v2/pages?search=fi%C3%B3k%20t%C3%B6rl%C3%A9se&_fields=id,slug,link,date,modified,status,title',
  'https://hungarianhardstyle.hu/wp-json/wp/v2/pages?slug=adatvedelmi-nyilatkozat&_fields=id,slug,link,date,modified,status,title',
];

for (const url of endpoints) {
  console.log(`\n${url}`);
  try {
    const response = await fetch(url, { headers: { 'user-agent': 'Mozilla/5.0 (compatible; HUHS-check)' } });
    console.log(`  HTTP ${response.status}`);
    const json = await response.json();
    if (!Array.isArray(json) || json.length === 0) {
      console.log('  (nincs találat)');
      continue;
    }
    for (const page of json) {
      console.log(`  #${page.id}  ${page.slug}`);
      console.log(`      cím: ${page.title?.rendered ?? '-'}`);
      console.log(`      link: ${page.link}`);
      console.log(`      létrehozva: ${page.date ?? '-'}   módosítva: ${page.modified ?? '-'}   állapot: ${page.status ?? '-'}`);
    }
  } catch (error) {
    console.log(`  HIBA: ${error.message}`);
  }
}
