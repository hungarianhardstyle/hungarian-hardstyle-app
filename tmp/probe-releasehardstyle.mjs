#!/usr/bin/env node
/**
 * **releasehardstyle.nl** mérés (a tulajdonos kérése: *„ezt nem lehet valahogy
 * beépíteni az appba natív? a prew linkekkel együtt"*).
 *
 * MIÉRT MÉRÉS ELŐBB: azt kell tudni, hogy a lista **géppel olvasható-e**
 * (JSON API / RSS), vagy csak HTML — mert ez dönti el, hogy natív beépítés,
 * szerveroldali közvetítés vagy egyáltalán nem javasolt.
 *
 * Csak olvas, és nem tárol tartalmat.
 *
 * Használat: node tmp/probe-releasehardstyle.mjs
 */

const BASE = 'https://releasehardstyle.nl';
const UA = 'HUHS-app-probe/1.0 (+https://hungarianhardstyle.hu)';

async function get(url) {
  const response = await fetch(url, { headers: { 'User-Agent': UA, Accept: '*/*' } });
  const text = await response.text();
  return { status: response.status, type: response.headers.get('content-type') || '', text };
}

/* --- 1. robots.txt és a géppel olvasható végpontok --------------------- */

const robots = await get(`${BASE}/robots.txt`);
console.log(`robots.txt: HTTP ${robots.status}`);
console.log(robots.text.split('\n').slice(0, 25).map((line) => `    ${line}`).join('\n'));

for (const path of ['/wp-json/', '/wp-json/wp/v2/posts', '/feed/', '/releases/feed/', '/?feed=rss2', '/api/releases', '/releases/?format=json']) {
  try {
    const result = await get(`${BASE}${path}`);
    const looksJson = result.text.trimStart().startsWith('{') || result.text.trimStart().startsWith('[');
    const looksXml = result.text.trimStart().startsWith('<?xml');
    console.log(
      `${path} → HTTP ${result.status} ${result.type} ${looksJson ? 'JSON' : looksXml ? 'XML' : 'HTML/egyéb'} (${result.text.length} bájt)`,
    );
  } catch (error) {
    console.log(`${path} → HIBA: ${error?.message || error}`);
  }
}

/* --- 2. A /releases/ oldal szerkezete --------------------------------- */

const page = await get(`${BASE}/releases/`);
console.log(`\n/releases/ → HTTP ${page.status}, ${page.text.length} bájt`);
console.log(`  WordPress: ${/wp-content|wp-json|generator" content="WordPress/i.test(page.text) ? 'igen' : 'nem'}`);
console.log(`  Elementor: ${/elementor/i.test(page.text) ? 'igen' : 'nem'}`);

const patterns = {
  spotify: /open\.spotify\.com|spotify\.com\/track|spotify\.com\/album/gi,
  beatport: /beatport\.com/gi,
  hardstylecom: /hardstyle\.com/gi,
  youtube: /youtube\.com|youtu\.be/gi,
  soundcloud: /soundcloud\.com/gi,
  appleMusic: /music\.apple\.com/gi,
  deezer: /deezer\.com/gi,
  bandcamp: /bandcamp\.com/gi,
};
console.log('\n  Előnép-linkek a HTML-ben:');
for (const [name, regex] of Object.entries(patterns)) {
  const hits = [...page.text.matchAll(regex)].length;
  if (hits) console.log(`    ${name}: ${hits} találat`);
}

/* --- 3. Egy kiadvány-kártya kiemelése --------------------------------- */

const article = /<article[\s\S]{0,2500}?<\/article>/i.exec(page.text);
if (article) {
  console.log('\n  Egy <article> blokk (1500 karakter):');
  console.log(article[0].replace(/\s+/g, ' ').slice(0, 1500));
} else {
  console.log('\n  Nincs <article> — a lista máshogy épül fel. Az oldal első 800 karaktere:');
  console.log(page.text.replace(/\s+/g, ' ').slice(0, 800));
}

/* --- 4. A linkek kigyűjtése (a „preview" linkek mintája) --------------- */

const links = [...page.text.matchAll(/href="([^"]+)"/g)].map((match) => match[1]);
const external = [...new Set(links.filter((href) => /^https?:\/\//.test(href) && !href.includes('releasehardstyle.nl')))];
console.log(`\n  Külső linkek (${external.length} db, az első 20):`);
for (const href of external.slice(0, 20)) console.log(`    ${href}`);
