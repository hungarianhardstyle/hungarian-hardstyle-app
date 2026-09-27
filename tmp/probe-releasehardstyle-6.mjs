#!/usr/bin/env node
/**
 * **releasehardstyle.nl — az adatlap tartalma** (van-e rajta előadó, cím,
 * dátum, borító és a hallgatási link).
 *
 * Használat: node tmp/probe-releasehardstyle-6.mjs [targetid]
 */

const UA = 'HUHS-app-probe/1.0 (+https://hungarianhardstyle.hu)';
const id = process.argv[2] || 'Y3ULWLmFX7ne';
const html = await fetch(`https://releasehardstyle.nl/release/${id}`, { headers: { 'User-Agent': UA } }).then((r) => r.text());

console.log(`/release/${id}: ${html.length} bájt`);
console.log(`  tartalmazza a címet (CREST / Monsters): ${/CREST/i.test(html)} / ${/Monsters/i.test(html)}`);

const titleIndex = html.search(/Monsters/i);
if (titleIndex > 0) {
  console.log('\n=== a cím környezete ===');
  console.log(html.slice(Math.max(0, titleIndex - 1400), titleIndex + 900).replace(/\s+/g, ' '));
}

const embeds = [...html.matchAll(/<iframe[^>]*embed\.spotify[^>]*>/gi)].map((match) => match[0]);
console.log(`\nSpotify-embedek: ${embeds.length}`);
for (const embed of embeds) console.log(`  ${embed.replace(/\s+/g, ' ').slice(0, 220)}`);

const links = [...new Set([...html.matchAll(/href="(https?:\/\/[^"]+)"/g)].map((match) => match[1]))]
  .filter((href) => /spotify|beatport|hardstyle\.com|apple|deezer|youtube|soundcloud|traxsource|junodownload/i.test(href));
console.log(`\nPlatform-linkek: ${links.length}`);
for (const href of links.slice(0, 12)) console.log(`  ${href}`);

const dataAttrs = [...new Set([...html.matchAll(/(data-[a-z-]+)="([^"]{0,80})"/g)].map((m) => `${m[1]}="${m[2]}"`))]
  .filter((attr) => /release|track|artist|spotify|date/i.test(attr));
console.log(`\nAdat-attribútumok: ${dataAttrs.length}`);
for (const attr of dataAttrs.slice(0, 12)) console.log(`  ${attr}`);
