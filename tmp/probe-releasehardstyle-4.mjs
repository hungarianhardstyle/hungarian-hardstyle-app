#!/usr/bin/env node
/**
 * **releasehardstyle.nl — a „preview" linkek nyoma** (a tulajdonos kérése:
 * *„a prew linkekkel együtt"*).
 *
 * Kérdés: a `releasetracker-list-entry targetid="…"` azonosítóból hogyan lesz
 * **előnép** (30 másodperces hang vagy beágyazott lejátszó)? Melyik végpontot
 * hívja a oldal JavaScriptje, és az ad-e géppel olvasható választ?
 *
 * Használat: node tmp/probe-releasehardstyle-4.mjs
 */

const BASE = 'https://releasehardstyle.nl';
const UA = 'HUHS-app-probe/1.0 (+https://hungarianhardstyle.hu)';
const get = async (url) => {
  const response = await fetch(url, { headers: { 'User-Agent': UA } });
  return { status: response.status, type: response.headers.get('content-type') || '', text: await response.text() };
};

const page = await get(`${BASE}/releases/`);
const html = page.text;

/* --- 1. A „preview" szó előfordulásai --------------------------------- */

const previewHits = [...html.matchAll(/preview[a-z_\-]*/gi)].map((m) => m[0].toLowerCase());
const previewCounts = new Map();
for (const hit of previewHits) previewCounts.set(hit, (previewCounts.get(hit) || 0) + 1);
console.log('„preview" előfordulások:', JSON.stringify([...previewCounts.entries()]));

const previewContext = html.search(/preview/i);
if (previewContext > 0) {
  console.log('\nEgy előfordulás környezete:');
  console.log(html.slice(Math.max(0, previewContext - 500), previewContext + 500).replace(/\s+/g, ' '));
}

/* --- 2. A releasetracker plugin scriptjei ----------------------------- */

const scripts = [...new Set([...html.matchAll(/<script[^>]+src="([^"]+)"/g)].map((m) => m[1]))];
const tracker = scripts.filter((src) => /releasetracker|release-tracker|tracker/i.test(src));
console.log(`\nScriptek összesen: ${scripts.length}; releasetracker: ${tracker.length}`);
for (const src of tracker) console.log(`  ${src}`);

/* --- 3. AJAX végpontok és akciók a HTML-ben --------------------------- */

for (const pattern of [
  ['ajaxurl', /ajaxurl\s*[:=]\s*["'][^"']+["']/gi],
  ['action:', /action["']?\s*[:=]\s*["'][a-z0-9_\-]+["']/gi],
  ['wp-json útvonal', /wp-json\/[a-z0-9_\-\/]+/gi],
  ['admin-ajax', /[^"']*admin-ajax\.php[^"']*/gi],
]) {
  const hits = [...new Set([...html.matchAll(pattern[1])].map((m) => m[0]))];
  console.log(`\n${pattern[0]}: ${hits.length}`);
  for (const hit of hits.slice(0, 8)) console.log(`  ${hit}`);
}

/* --- 4. A plugin fő scriptjének letöltése és átnézése ----------------- */

for (const src of tracker.slice(0, 3)) {
  const url = src.startsWith('http') ? src : `${BASE}${src}`;
  const script = await get(url);
  console.log(`\n--- ${url} → HTTP ${script.status}, ${script.text.length} bájt`);
  const endpoints = [...new Set([...script.text.matchAll(/(https?:\/\/[^"'\s)]+|\/[a-z0-9_\-\/.]*\.php[^"'\s)]*|wp-json\/[a-z0-9_\-\/]+)/gi)].map((m) => m[0]))];
  console.log(`  végpont-gyanús szövegek (${endpoints.length}):`);
  for (const hit of endpoints.slice(0, 20)) console.log(`    ${hit}`);
  const ajaxActions = [...new Set([...script.text.matchAll(/action:\s*["']([a-z0-9_\-]+)["']/gi)].map((m) => m[1]))];
  if (ajaxActions.length) console.log(`  AJAX action-ök: ${ajaxActions.join(', ')}`);
}

/* --- 5. Hány kiadvány van a listában --------------------------------- */

const entries = [...html.matchAll(/class="releasetracker-list-entry"/g)].length;
const targetIds = [...new Set([...html.matchAll(/targetid="([^"]+)"/g)].map((m) => m[1]))];
const spotifyLinks = [...new Set([...html.matchAll(/https:\/\/open\.spotify\.com\/track\/([A-Za-z0-9]+)/g)].map((m) => m[1]))];
console.log(`\nLista-elemek: ${entries}; egyedi targetid: ${targetIds.length}; egyedi Spotify track: ${spotifyLinks.length}`);
