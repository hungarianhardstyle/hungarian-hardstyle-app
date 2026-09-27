#!/usr/bin/env node
/**
 * Egy nyilvános oldal **elérhetőségének** mérése úgy, ahogy a Play-felülvizsgáló
 * és a Google robot látja (Googlebot / Play-Review / sima user-agent, robots.txt,
 * http/www változat).
 *
 * Használat: node tmp/probe-page-access.mjs <url> [<url2> …]
 */
const urls = process.argv.slice(2);
if (!urls.length) {
  console.error('Adj meg legalább egy URL-t.');
  process.exit(2);
}

const AGENTS = [
  ['Googlebot',
    'Mozilla/5.0 (Linux; Android 6.0.1; Nexus 5X Build/MMB29P) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/W.X.Y.Z Mobile Safari/537.36 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)'],
  ['Play-Review', 'Google-Play-Review/1.0 (+https://play.google.com)'],
  ['egyszerű', 'Mozilla/5.0 (compatible; HUHS-check)'],
];

for (const url of urls) {
  console.log(`\n=== ${url} ===`);
  for (const [label, ua] of AGENTS) {
    const started = Date.now();
    try {
      const response = await fetch(url, { redirect: 'follow', headers: { 'user-agent': ua } });
      const body = await response.text();
      const text = body
        .replace(/<script[\s\S]*?<\/script>/gi, ' ')
        .replace(/<style[\s\S]*?<\/style>/gi, ' ')
        .replace(/<[^>]+>/g, ' ')
        .replace(/\s+/g, ' ')
        .trim();
      console.log(
        `  ${response.status}  ${Date.now() - started} ms  [${label}]  `
        + `${(body.length / 1024).toFixed(1)} kB  szöveg: ${text.length} karakter`
        + (response.url !== url ? `  → ${response.url}` : ''),
      );
    } catch (error) {
      console.log(`  HIBA [${label}] ${error.message}`);
    }
  }
  const variants = [
    url.replace('https://', 'http://'),
    url.replace('https://', 'https://www.'),
  ];
  for (const variant of variants) {
    try {
      const response = await fetch(variant, {
        redirect: 'follow',
        headers: { 'user-agent': AGENTS[2][1] },
      });
      console.log(`  ${response.status}  [változat] ${variant}${response.url !== variant ? ` → ${response.url}` : ''}`);
    } catch (error) {
      console.log(`  HIBA [változat] ${variant}: ${error.message}`);
    }
  }
  try {
    const host = new URL(url).origin;
    const response = await fetch(`${host}/robots.txt`, { headers: { 'user-agent': AGENTS[2][1] } });
    const text = await response.text();
    const blocked = text
      .split(/\r?\n/)
      .filter((line) => /^disallow/i.test(line.trim()))
      .filter((line) => line.includes(new URL(url).pathname.replace(/\/$/, '')));
    console.log(`  robots.txt: HTTP ${response.status}, az oldalra vonatkozó tiltás: ${blocked.length ? blocked.join(' | ') : 'nincs'}`);
  } catch (error) {
    console.log(`  robots.txt HIBA: ${error.message}`);
  }
}
