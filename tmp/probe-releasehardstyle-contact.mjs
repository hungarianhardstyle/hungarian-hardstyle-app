#!/usr/bin/env node
/**
 * **releasehardstyle.nl — kapcsolat** (az engedélykéréshez kell a cím).
 *
 * A tulajdonos döntése: *„írjunk nekik és kérjünk engedélyt"* — ehhez tudni
 * kell, hova megy a levél (e-mail vagy űrlap), és ki a címzett.
 *
 * Használat: node tmp/probe-releasehardstyle-contact.mjs
 */

const BASE = 'https://releasehardstyle.nl';
const UA = 'HUHS-app-probe/1.0 (+https://hungarianhardstyle.hu)';
const get = async (url) => (await fetch(url, { headers: { 'User-Agent': UA } })).text();

for (const path of ['/contact/', '/contact', '/our-story/', '/about/']) {
  const html = await get(`${BASE}${path}`);
  const emails = [...new Set([...html.matchAll(/[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}/gi)].map((m) => m[0]))];
  const forms = [...html.matchAll(/<form[^>]*>/gi)].length;
  const socials = [...new Set([...html.matchAll(/href="(https?:\/\/(?:www\.)?(?:facebook|instagram|twitter|x|discord|mailto)[^"]*)"/gi)].map((m) => m[1]))];
  console.log(`\n${path} → ${html.length} bájt`);
  console.log(`  e-mail címek: ${emails.length ? emails.join(', ') : '(nincs)'}`);
  console.log(`  űrlapok: ${forms}`);
  console.log(`  közösségi linkek: ${socials.slice(0, 6).join(', ') || '(nincs)'}`);

  const contactIndex = html.search(/contact|get in touch|e-?mail/i);
  if (contactIndex > 0) {
    const text = html.slice(Math.max(0, contactIndex - 300), contactIndex + 900)
      .replace(/<script[\s\S]*?<\/script>/g, ' ')
      .replace(/<[^>]+>/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();
    console.log(`  szövegkörnyezet: ${text.slice(0, 400)}`);
  }
}
