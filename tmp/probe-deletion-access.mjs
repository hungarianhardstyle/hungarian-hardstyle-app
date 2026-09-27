#!/usr/bin/env node
/**
 * Miért mondhatja a Play, hogy „érvénytelen" a fióktörlési link?
 *
 * Ez a szonda a **hozzáférhetőséget** méri több szempontból:
 *   1. Googlebot-User-Agent (a felülvizsgáló robot így kér),
 *   2. `robots.txt` — tiltja-e az oldalt,
 *   3. `http://` és `www.` változat (átirányítás? elérhető?),
 *   4. válaszidő és a HTML mérete.
 *
 * Használat: node tmp/probe-deletion-access.mjs
 */
const UA_GOOGLEBOT =
  'Mozilla/5.0 (Linux; Android 6.0.1; Nexus 5X Build/MMB29P) AppleWebKit/537.36 (KHTML, like Gecko) '
  + 'Chrome/W.X.Y.Z Mobile Safari/537.36 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)';
const UA_PLAY = 'Google-Play-Review/1.0 (+https://play.google.com)';
const UA_PLAIN = 'Mozilla/5.0 (compatible; HUHS-check)';

const targets = [
  ['https://hungarianhardstyle.hu/fiok-torles/', UA_GOOGLEBOT],
  ['https://hungarianhardstyle.hu/fiok-torles/', UA_PLAY],
  ['https://hungarianhardstyle.hu/fiok-torles/', UA_PLAIN],
  ['http://hungarianhardstyle.hu/fiok-torles/', UA_PLAIN],
  ['https://www.hungarianhardstyle.hu/fiok-torles/', UA_PLAIN],
];

for (const [url, ua] of targets) {
  const started = Date.now();
  try {
    const response = await fetch(url, { redirect: 'follow', headers: { 'user-agent': ua } });
    const body = await response.text();
    const ms = Date.now() - started;
    const label = ua.includes('Googlebot')
      ? 'Googlebot'
      : ua.includes('Play-Review')
        ? 'Play-Review'
        : 'egyszerű';
    console.log(
      `${response.status}  ${ms} ms  ${(body.length / 1024).toFixed(1)} kB  [${label}]  ${url}`
      + (response.url !== url ? `  → ${response.url}` : ''),
    );
  } catch (error) {
    console.log(`HIBA [${url}] ${error.message}`);
  }
}

console.log('\n=== robots.txt ===');
try {
  const response = await fetch('https://hungarianhardstyle.hu/robots.txt', {
    headers: { 'user-agent': UA_PLAIN },
  });
  const text = await response.text();
  console.log(`HTTP ${response.status}`);
  console.log(text.split(/\r?\n/).filter((line) => /fiok|disallow|sitemap/i.test(line)).slice(0, 20).join('\n'));
} catch (error) {
  console.log(`HIBA: ${error.message}`);
}

console.log('\n=== az adatvédelmi nyilatkozat hivatkozik-e a törlési oldalra? ===');
try {
  const response = await fetch('https://hungarianhardstyle.hu/adatvedelmi-nyilatkozat/', {
    headers: { 'user-agent': UA_PLAIN },
  });
  const html = await response.text();
  const links = [...html.matchAll(/href="([^"]+)"/g)].map((m) => m[1]);
  const deletion = links.filter((href) => /fiok|t[oö]rl|deletion/i.test(href));
  console.log(`talált törlés-hivatkozás: ${deletion.length ? deletion.join(', ') : 'NINCS'}`);
  console.log(`a lap szövegében szerepel az e-mail: ${/info@hungarianhardstyle\.hu/.test(html) ? 'igen' : 'nem'}`);
} catch (error) {
  console.log(`HIBA: ${error.message}`);
}
