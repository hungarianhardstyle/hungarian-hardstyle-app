#!/usr/bin/env node
/**
 * A fióktörlési oldal **tartalmának** mérése a Play követelményeihez.
 *
 * A Play az „Adatbiztonsági űrlap" fióktörlési linkjénél nem csak azt nézi, hogy
 * a link él, hanem azt is, hogy az oldal **megadja a törlés módját** (appon belül
 * és/vagy weben), **megnevezi az appot**, **nem kér bejelentkezést**, és szól a
 * **megőrzött adatokról**. Ez a szonda ezt a négy dolgot keresi a szövegben.
 *
 * Használat: node tmp/probe-deletion-page-content.mjs
 */
const URL = 'https://hungarianhardstyle.hu/fiok-torles/';

const response = await fetch(URL, { headers: { 'user-agent': 'Mozilla/5.0 (compatible; HUHS-check)' } });
const html = await response.text();
const text = html
  .replace(/<script[\s\S]*?<\/script>/gi, ' ')
  .replace(/<style[\s\S]*?<\/style>/gi, ' ')
  .replace(/<[^>]+>/g, ' ')
  .replace(/&#8211;/g, '–')
  .replace(/&#8217;/g, '’')
  .replace(/&nbsp;/g, ' ')
  .replace(/\s+/g, ' ')
  .trim();

// A menü kiszűrése: a „Skip to content" utáni törzs a lényeg.
const body = text.replace(/^.*?Skip to content/i, '').trim();

console.log(`URL: ${URL}`);
console.log(`HTTP ${response.status}`);
console.log(`\n=== a lap SZÖVEGE (${body.length} karakter) ===\n`);
console.log(body);

const checks = [
  ['megnevezi az appot (Hungarian Hardstyle / alkalmazás)', /hungarian hardstyle|alkalmaz[aá]s/i],
  ['megadja az appon belüli törlést', /app(on)? bel[üu]l|be[aá]ll[ií]t[aá]sok|profil.*t[oö]rl/i],
  ['megadja a webes/email-es k[eé]r[eé]st', /e-?mail|@|k[eé]r[eé]s|urlap|űrlap/i],
  ['t[oö]rl[eé]si id[oő] / hat[aá]ridő', /nap|h[eé]t|azonnal|30|14|7/i],
  ['meg[oő]rz[oö]tt adatok eml[ií]t[eé]se', /meg[oő]rz|kiv[eé]tel|jogi|sz[aá]mvitel/i],
  ['kapcsolat / adatkezelő', /info@|kapcsolat|adatkezel/i],
];
console.log('\n=== a Play-követelményekhez mért tartalom ===');
for (const [label, pattern] of checks) {
  console.log(`  ${pattern.test(body) ? 'OK  ' : 'HIÁNYZIK'} ${label}`);
}
