#!/usr/bin/env node
/**
 * A fordítandó cikkek letöltése (csak olvas) a HUHS plugin végpontjáról.
 *
 * MIÉRT a plugin végpontja és nem a WP core: az app **ezt** a szöveget mutatja
 * (`huhs_clean_content`), ezért azt kell lefordítani, amit a felhasználó lát.
 *
 * Kimenet: `tmp/newsroom-en/hu-posts.json` — a legfrissebb N cikk a következő
 * mezőkkel: id, title, excerpt, content, date, link + a mért karakterek.
 *
 * Futtatás: node tools/fetch-posts-for-translation.mjs [--limit=30] [--out=...]
 */
import fs from 'node:fs';
import path from 'node:path';

const BASE = 'https://hungarianhardstyle.hu/wp-json/huhs/v1';

/** Rövid védett-minta keresés: mit kell óvni a fordítás előtt. */
export function scanProtected(content) {
  const text = String(content ?? '');
  return {
    shortcodes: [...text.matchAll(/\[[^\]]+\]/g)].map((match) => match[0]),
    tags: [...text.matchAll(/<[^>]+>/g)].map((match) => match[0]),
    urls: [...text.matchAll(/https?:\/\/[^\s"'<>]+/g)].map((match) => match[0]),
  };
}

export function selfTest() {
  const checks = [];
  const check = (label, ok) => checks.push({ label, ok });
  const scan = scanProtected('<p>Szia <b>világ</b> [irp posts="1,2"] <a href="https://x.hu">link</a></p>');
  check('a shortcode-ot megtalálja', scan.shortcodes.length === 1 && scan.shortcodes[0].includes('irp'));
  check('a tageket megtalálja', scan.tags.length >= 4);
  check('az URL-t megtalálja', scan.urls.length === 1 && scan.urls[0] === 'https://x.hu');
  check('üres bemenet nem törik el', scanProtected('').tags.length === 0);
  return checks;
}

async function get(pathname) {
  const response = await fetch(`${BASE}${pathname}`, { headers: { accept: 'application/json' } });
  if (!response.ok) throw new Error(`${pathname}: HTTP ${response.status}`);
  return response.json();
}

async function main() {
  if (process.argv.includes('--self-test')) {
    const checks = selfTest();
    for (const check of checks) console.log(`${check.ok ? 'OK  ' : 'HIBA'} ${check.label}`);
    const failed = checks.filter((check) => !check.ok).length;
    console.log(`\n${checks.length - failed}/${checks.length} önteszt rendben`);
    return failed ? 1 : 0;
  }
  const limitArg = process.argv.find((arg) => arg.startsWith('--limit='));
  const limit = limitArg ? Number(limitArg.slice('--limit='.length)) : 30;
  const outArg = process.argv.find((arg) => arg.startsWith('--out='));
  const out = outArg ? outArg.slice('--out='.length) : 'tmp/newsroom-en/hu-posts.json';

  const list = await get(`/posts?per_page=${Math.min(50, limit)}&page=1&summary=false`);
  const items = (list.items ?? []).slice(0, limit);
  const rows = items.map((item) => {
    const scan = scanProtected(item.content);
    return {
      id: item.id,
      date: item.date,
      link: item.link,
      title: item.title,
      excerpt: item.excerpt,
      content: item.content,
      protectedCounts: {
        shortcodes: scan.shortcodes.length,
        tags: scan.tags.length,
        urls: scan.urls.length,
      },
    };
  });
  fs.mkdirSync(path.dirname(out), { recursive: true });
  fs.writeFileSync(out, JSON.stringify(rows, null, 2), 'utf8');

  const sum = (pick) => rows.reduce((total, row) => total + [...String(pick(row) ?? '')].length, 0);
  const shortcodes = rows.reduce((total, row) => total + row.protectedCounts.shortcodes, 0);
  const tags = rows.reduce((total, row) => total + row.protectedCounts.tags, 0);
  const urls = rows.reduce((total, row) => total + row.protectedCounts.urls, 0);
  console.log(`letöltve: ${rows.length} cikk (total a végponton: ${list.total ?? '?'})`);
  console.log(`  cím:      ${sum((row) => row.title)} karakter`);
  console.log(`  kivonat:  ${sum((row) => row.excerpt)} karakter`);
  console.log(`  tartalom: ${sum((row) => row.content)} karakter`);
  console.log(`  összesen: ${sum((row) => row.title) + sum((row) => row.excerpt) + sum((row) => row.content)} karakter`);
  console.log(`  védendő:  ${shortcodes} shortcode, ${tags} HTML-tag, ${urls} URL`);
  console.log(`\nmentve: ${out}`);
  console.log('legfrissebb:', rows[0]?.title?.slice(0, 70));
  return 0;
}

main()
  .then((code) => {
    process.exitCode = code;
  })
  .catch((error) => {
    console.error(`HIBA: ${error.message}`);
    process.exitCode = 2;
  });
