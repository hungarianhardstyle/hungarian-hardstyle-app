#!/usr/bin/env node
/**
 * Élő mérés: a Play **fióktörlési URL** és az adatvédelmi URL valódi állapota.
 *
 * MIÉRT: a Play Console 2026-09-27-én **elutasította** a frissítést azzal, hogy
 * „Érvénytelen adattörlési link az Adatbiztonsági űrlapon". Ez **nem** az app
 * hibája, hanem a Play-űrlapon megadott **URL** — ezért meg kell mérni, mit ad
 * a szerver: 404 / átirányítás / bejelentkezés / üres oldal.
 *
 * Használat: node tmp/probe-deletion-url.mjs
 */
const CANDIDATES = [
  'https://hungarianhardstyle.hu/fiok-torles/',
  'https://hungarianhardstyle.hu/fiok-torles',
  'https://hungarianhardstyle.hu/fioktorles/',
  'https://hungarianhardstyle.hu/account-deletion/',
  'https://hungarianhardstyle.hu/adatvedelmi-nyilatkozat/',
  'https://hungarianhardstyle.hu/adatvedelmi-nyilatkozat',
  'https://hungarianhardstyle.hu/',
];

const strip = (html) =>
  html
    .replace(/<script[\s\S]*?<\/script>/gi, ' ')
    .replace(/<style[\s\S]*?<\/style>/gi, ' ')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&nbsp;/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();

for (const url of CANDIDATES) {
  try {
    const response = await fetch(url, {
      redirect: 'follow',
      headers: { 'user-agent': 'Mozilla/5.0 (compatible; HUHS-check)' },
    });
    const body = await response.text();
    const text = strip(body);
    const title = /<title[^>]*>([\s\S]*?)<\/title>/i.exec(body)?.[1]?.trim() ?? '';
    const hasDeletion =
      /t[oö]rl[eé]s|delete|fi[oó]k/i.test(text.slice(0, 4000)) &&
      text.length > 200;
    console.log(`\n${url}`);
    console.log(`  HTTP ${response.status} ${response.statusText}`);
    console.log(`  végleges URL: ${response.url}${response.url !== url ? '  ⚠️ ÁTIRÁNYÍTVA' : ''}`);
    console.log(`  tartalom-típus: ${response.headers.get('content-type') ?? '-'}`);
    console.log(`  cím: ${JSON.stringify(title.slice(0, 90))}`);
    console.log(`  szöveghossz: ${text.length} karakter`);
    console.log(`  törlés-szöveg a lapon: ${hasDeletion ? 'igen' : 'NEM'}`);
    console.log(`  első 200 karakter: ${JSON.stringify(text.slice(0, 200))}`);
  } catch (error) {
    console.log(`\n${url}\n  HIBA: ${error.message}`);
  }
}
