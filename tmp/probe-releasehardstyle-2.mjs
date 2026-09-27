#!/usr/bin/env node
/**
 * **releasehardstyle.nl — mélyebb mérés** (a natív beépítéshez).
 *
 * Kérdések, amikre választ kell kapni:
 *   1. van-e **külön „release" tartalomtípus** (CPT) a WordPressben;
 *   2. az **RSS** (a robots.txt által nem tiltott út) mit tartalmaz pontosan:
 *      címet, borítót, **Spotify-előnép linket**, előadót, kiadót;
 *   3. a REST API (a robots.txt **tiltja** a keresőknek) mit adna pluszban.
 *
 * Csak olvas, nem tárol tartalmat.
 *
 * Használat: node tmp/probe-releasehardstyle-2.mjs
 */

const BASE = 'https://releasehardstyle.nl';
const UA = 'HUHS-app-probe/1.0 (+https://hungarianhardstyle.hu)';

const get = async (url) => {
  const response = await fetch(url, { headers: { 'User-Agent': UA } });
  return { status: response.status, text: await response.text() };
};

/* --- 1. Tartalomtípusok (van-e „release" CPT?) ------------------------ */

const types = await get(`${BASE}/wp-json/wp/v2/types`);
try {
  const json = JSON.parse(types.text);
  console.log('Tartalomtípusok (REST):');
  for (const [slug, type] of Object.entries(json)) {
    console.log(`  ${slug}: ${type?.name || '?'} (rest_base=${type?.rest_base || '-'})`);
  }
} catch {
  console.log(`típusok: HTTP ${types.status}, nem JSON`);
}

/* --- 2. Az RSS feed --------------------------------------------------- */

const feed = await get(`${BASE}/feed/`);
const items = [...feed.text.matchAll(/<item>([\s\S]*?)<\/item>/g)].map((match) => match[1]);
console.log(`\nRSS (/feed/): HTTP ${feed.status}, ${items.length} item`);

const first = items[0] || '';
const field = (name) => {
  const match = new RegExp(`<${name}[^>]*>([\\s\\S]*?)</${name}>`).exec(first);
  return match ? match[1].replace(/<!\[CDATA\[|\]\]>/g, '').trim() : '';
};
console.log('  Az első item mezői:');
for (const name of ['title', 'link', 'pubDate', 'dc:creator', 'category']) {
  const value = field(name);
  if (value) console.log(`    ${name}: ${value.slice(0, 120)}`);
}
const content = field('content:encoded');
console.log(`    content:encoded: ${content.length} karakter`);
const links = [...new Set([...content.matchAll(/https?:\/\/[^\s"'<>]+/g)].map((match) => match[0]))];
const relevant = links.filter((href) => /spotify|beatport|hardstyle\.com|youtube|soundcloud|apple|deezer|bandcamp/i.test(href));
console.log(`    külső zene-linkek: ${relevant.length}`);
for (const href of relevant.slice(0, 8)) console.log(`      ${href}`);
const images = [...content.matchAll(/<img[^>]+src="([^"]+)"/g)].map((match) => match[1]);
console.log(`    képek: ${images.length}${images[0] ? ` (első: ${images[0].slice(0, 100)})` : ''}`);

/* --- 3. A REST API (csak összehasonlításhoz) -------------------------- */

const posts = await get(`${BASE}/wp-json/wp/v2/posts?per_page=2&_embed=1`);
try {
  const json = JSON.parse(posts.text);
  console.log(`\nREST /wp-json/wp/v2/posts: HTTP ${posts.status}, ${json.length} bejegyzés`);
  const post = json[0] || {};
  console.log(`  kulcsok: ${Object.keys(post).join(', ')}`);
  console.log(`  cím: ${post?.title?.rendered?.slice(0, 100)}`);
  console.log(`  kiemelt kép: ${post?._embedded?.['wp:featuredmedia']?.[0]?.source_url?.slice(0, 100) || '(nincs)'}`);
  console.log(`  taxonómiák: ${Object.keys(post?._embedded || {}).join(', ')}`);
  const contentLinks = [...new Set([...(post?.content?.rendered || '').matchAll(/https?:\/\/[^\s"'<>]+/g)].map((m) => m[0]))]
    .filter((href) => /spotify|beatport|hardstyle\.com|youtube|soundcloud/i.test(href));
  console.log(`  zene-linkek a tartalomban: ${contentLinks.length}`);
  for (const href of contentLinks.slice(0, 6)) console.log(`    ${href}`);
} catch {
  console.log(`\nREST: HTTP ${posts.status}, nem JSON (${posts.text.slice(0, 120)})`);
}

/* --- 4. A sitemap (van-e külön release-útvonal?) ---------------------- */

const sitemap = await get(`${BASE}/sitemap_index.xml`);
const maps = [...sitemap.text.matchAll(/<loc>([^<]+)<\/loc>/g)].map((match) => match[1]);
console.log(`\nSitemap: ${maps.length} al-sitemap`);
for (const url of maps.slice(0, 15)) console.log(`    ${url}`);
