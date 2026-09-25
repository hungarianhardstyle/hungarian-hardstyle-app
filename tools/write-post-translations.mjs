#!/usr/bin/env node
/**
 * Az angol cikk-változatok beírása a WordPressbe (REJTETT post meta).
 *
 * MIÉRT meta és nem külön poszt: a tulajdonos döntése (2026-09-25) szerint az
 * angol **a weboldalon egyelőre nem jelenhet meg**, csak az app kapja meg. A
 * `_huhs_title_en` / `_huhs_excerpt_en` / `_huhs_content_en` meta mezőket a
 * téma nem olvassa, a HUHS plugin pedig `?lang=en` esetén adja ki.
 *
 * ⚠️ A WP REST csak **regisztrált** metát fogad el (plugin 2.11.0). Ha a plugin
 * még 2.10.0, a WP `rest_invalid_param`/`meta` hibát ad — ez nem hiba a
 * szkriptben, hanem a plugin hiánya.
 *
 * Használat:
 *   node tools/write-post-translations.mjs                 # száraz futás (alap)
 *   node tools/write-post-translations.mjs --confirm       # tényleges írás
 *   node tools/write-post-translations.mjs --confirm --limit=5
 *   node tools/write-post-translations.mjs --confirm --force   # felülírás is
 *
 * A jelszó a Secret Managerből jön (`WORDPRESS_USERNAME`,
 * `WORDPRESS_APPLICATION_PASSWORD`) — a repóban nincs és nem is lesz.
 */
import fs from 'node:fs';
import path from 'node:path';
import { secret } from './lib/live-firebase.mjs';

const WP_BASE = 'https://hungarianhardstyle.hu/wp-json/wp/v2';
const EN_DIR = 'tmp/newsroom-en/en';
const HU_FILE = 'tmp/newsroom-en/hu-posts.json';

/** A három meta kulcs — egy helyen, hogy a tesztek és a plugin ne széthúzzanak. */
export const META_KEYS = {
  title: '_huhs_title_en',
  excerpt: '_huhs_excerpt_en',
  content: '_huhs_content_en',
};

/** A fordításból meta payload (tiszta függvény). */
export function metaPayload(translation) {
  return {
    [META_KEYS.title]: String(translation.title_en ?? ''),
    [META_KEYS.excerpt]: String(translation.excerpt_en ?? ''),
    [META_KEYS.content]: String(translation.content_en ?? ''),
  };
}

/** Kihagyjuk-e a cikket (már van angol, és nem kértünk felülírást)? */
export function shouldSkip({ existing, force }) {
  if (force) return false;
  const hasEnglish = Object.values(existing ?? {}).some((value) => String(value ?? '').trim());
  return hasEnglish;
}

export function selfTest() {
  const checks = [];
  const check = (label, ok) => checks.push({ label, ok });
  const payload = metaPayload({ title_en: 'T', excerpt_en: 'E', content_en: 'C' });
  check('a payload a három kulcsot adja', Object.keys(payload).length === 3);
  check('a cím kulcsa jó', payload[META_KEYS.title] === 'T');
  check('a tartalom kulcsa jó', payload[META_KEYS.content] === 'C');
  check('hiányzó mezőt üresre állít', metaPayload({}).title_en === undefined);
  check('a meglévő angolt kihagyja', shouldSkip({ existing: { [META_KEYS.title]: 'x' } }) === true);
  check('üres meta nem kihagyás', shouldSkip({ existing: { [META_KEYS.title]: '  ' } }) === false);
  check('felülíráskor nem kihagyás', shouldSkip({ existing: { [META_KEYS.title]: 'x' }, force: true }) === false);
  return checks;
}

function authorization() {
  const user = secret('WORDPRESS_USERNAME');
  const password = secret('WORDPRESS_APPLICATION_PASSWORD');
  if (!user || !password) throw new Error('a WordPress hitelesítés nincs beállítva');
  return `Basic ${Buffer.from(`${user}:${password}`).toString('base64')}`;
}

async function wp(pathname, { method = 'GET', body, auth } = {}) {
  const response = await fetch(`${WP_BASE}${pathname}`, {
    method,
    headers: {
      accept: 'application/json',
      ...(body ? { 'content-type': 'application/json' } : {}),
      ...(auth ? { authorization: auth } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await response.text();
  let json = null;
  try {
    json = JSON.parse(text);
  } catch {
    json = null;
  }
  return { ok: response.ok, status: response.status, json, text };
}

async function main() {
  if (process.argv.includes('--self-test')) {
    const checks = selfTest();
    for (const check of checks) console.log(`${check.ok ? 'OK  ' : 'HIBA'} ${check.label}`);
    const failed = checks.filter((check) => !check.ok).length;
    console.log(`\n${checks.length - failed}/${checks.length} önteszt rendben`);
    return failed ? 1 : 0;
  }
  const confirm = process.argv.includes('--confirm');
  const force = process.argv.includes('--force');
  const limitArg = process.argv.find((arg) => arg.startsWith('--limit='));
  const limit = limitArg ? Number(limitArg.slice('--limit='.length)) : Infinity;

  const sources = JSON.parse(fs.readFileSync(HU_FILE, 'utf8'));
  let done = 0;
  let skipped = 0;
  let failed = 0;
  for (const source of sources) {
    if (done >= limit) break;
    const file = path.join(EN_DIR, `${source.id}.json`);
    if (!fs.existsSync(file)) {
      console.log(`  ${source.id}: nincs fordítása (kihagyva)`);
      continue;
    }
    const translation = JSON.parse(fs.readFileSync(file, 'utf8'));
    const payload = metaPayload(translation);
    if (!confirm) {
      console.log(
        `  [száraz] ${source.id}: ${[...payload[META_KEYS.title]].length} + ` +
          `${[...payload[META_KEYS.excerpt]].length} + ${[...payload[META_KEYS.content]].length} karakter`,
      );
      done += 1;
      continue;
    }
    const auth = authorization();
    // 1) van-e már angol? (a `context=edit` adja a védett metát)
    const before = await wp(`/posts/${source.id}?context=edit`, { auth });
    if (!before.ok) {
      console.log(`  ${source.id}: HIBA a kiolvasásnál (HTTP ${before.status})`);
      failed += 1;
      continue;
    }
    if (shouldSkip({ existing: before.json?.meta, force })) {
      console.log(`  ${source.id}: már van angol (kihagyva)`);
      skipped += 1;
      continue;
    }
    const write = await wp(`/posts/${source.id}`, {
      method: 'POST',
      auth,
      body: { meta: payload },
    });
    if (!write.ok) {
      console.log(`  ${source.id}: ÍRÁS HIBA (HTTP ${write.status}) ${write.text.slice(0, 200)}`);
      failed += 1;
      continue;
    }
    // 2) visszaolvasás — a WP néha csendben eldobja a metát
    const after = await wp(`/posts/${source.id}?context=edit`, { auth });
    const stored = after.json?.meta ?? {};
    const okContent = String(stored[META_KEYS.content] ?? '') === payload[META_KEYS.content];
    const okTitle = String(stored[META_KEYS.title] ?? '') === payload[META_KEYS.title];
    console.log(
      `  ${source.id}: ${okTitle && okContent ? 'beírva és visszaolvasva' : 'FIGYELEM: a visszaolvasás eltér'}`,
    );
    if (okTitle && okContent) done += 1;
    else failed += 1;
  }
  console.log(
    `\n${confirm ? 'Írás' : 'Száraz futás'}: ${done} cikk, kihagyva ${skipped}, hiba ${failed}`,
  );
  if (!confirm) console.log('A tényleges íráshoz add hozzá a --confirm kapcsolót.');
  return failed ? 1 : 0;
}

main()
  .then((code) => {
    process.exitCode = code;
  })
  .catch((error) => {
    console.error(`HIBA: ${error.message}`);
    process.exitCode = 2;
  });
