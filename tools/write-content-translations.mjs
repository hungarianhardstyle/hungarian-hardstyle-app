#!/usr/bin/env node
/**
 * Az angol **tartalom-fordítások** beírása a WordPressbe (esemény, DJ, szervező).
 *
 * UGYANAZ a három rejtett meta, mint a cikkeknél (`_huhs_title_en`,
 * `_huhs_excerpt_en`, `_huhs_content_en`), ezért a beírás is ugyanaz: a WP REST
 * `context=edit` végpontjára POST-olunk `meta` payloaddal, egy szerkesztői
 * alkalmazás-jelszóval (a Secret Managerből).
 *
 * ⚠️ EZ A PLUGIN **2.12.0**-T IGÉNYLI: a meta csak akkor regisztrált ezeknél a
 * típusoknál (és így REST-en írható), ha a 2.12.0 fent van. Amíg nincs, a WP
 * `rest_invalid_param`-ot ad — ez nem hiba a szkriptben, hanem a plugin hiánya.
 *
 * Bemenet: `tmp/content-en/en/chunk-*.json` (a fordítók kimenete, `"<típus>-<id>"`
 * kulcsokkal). A kiadvány szándékosan nincs köztük: a címe név, nem fordítjuk.
 *
 * Használat:
 *   node tools/write-content-translations.mjs              # száraz futás
 *   node tools/write-content-translations.mjs --confirm     # tényleges írás
 *   node tools/write-content-translations.mjs --self-test
 */
import fs from 'node:fs';
import path from 'node:path';

import { secret } from './lib/live-firebase.mjs';
import { META_KEYS } from './lib/translation-meta.mjs';

export const EN_DIR = 'tmp/content-en/en';
export const SOURCE_PATH = 'tmp/content-en/source.json';

/** A REST-végpont a post típusonként (a meta ugyanaz). */
export const REST_BASE_BY_TYPE = {
  event: 'events',
  artist: 'artists',
  organizer: 'organizers',
};

/** A `"<típus>-<id>"` kulcs felbontása. */
export function parseKey(key) {
  const match = /^([a-z]+)-(\d+)$/.exec(String(key ?? ''));
  if (!match) return null;
  return { type: match[1], id: Number(match[2]) };
}

/** A fordításból meta payload (ugyanaz a három kulcs, mint a cikkeknél). */
export function metaPayload(entry) {
  return {
    [META_KEYS.title]: String(entry?.title ?? ''),
    [META_KEYS.excerpt]: String(entry?.excerpt ?? ''),
    [META_KEYS.content]: String(entry?.content ?? ''),
  };
}

/** A fordítás-jegyzék összegyűjtése a chunkokból (típus szerint). */
export function collectTranslations(dir = EN_DIR) {
  if (!fs.existsSync(dir)) return [];
  const entries = [];
  for (const name of fs.readdirSync(dir).filter((file) => /^chunk-.*\.json$/.test(file)).sort()) {
    const data = JSON.parse(fs.readFileSync(path.join(dir, name), 'utf8'));
    for (const [key, value] of Object.entries(data ?? {})) {
      const parsed = parseKey(key);
      if (!parsed || !REST_BASE_BY_TYPE[parsed.type]) continue;
      entries.push({ ...parsed, key, ...metaPayload(value) });
    }
  }
  return entries;
}

/**
 * Kihagyjuk? — csak akkor, ha a **cím ÉS a törzs** angolja is megvan (ugyanaz a
 * kapu, mint a pluginban), és nem kértünk felülírást. Az idegen meta-kulcsok
 * (Yoast, Rank Math, egyéb beállítások) **nem** számítanak angolnak — ez a
 * cikkeknél mért hiba volt, ezért itt is csak a saját három kulcsot nézzük.
 */
export function shouldSkip({ existing, force }) {
  if (force) return false;
  const current = existing ?? {};
  const filled = (key) => typeof current[key] === 'string' && current[key].trim() !== '';
  return filled(META_KEYS.title) && filled(META_KEYS.content);
}

export function selfTest() {
  const checks = [];
  const check = (label, ok) => checks.push({ label, ok });

  check('a kulcs felbontása jó', parseKey('artist-1234')?.type === 'artist' && parseKey('artist-1234')?.id === 1234);
  check('a hibás kulcs null', parseKey('artist') === null && parseKey('artist-x') === null);
  check(
    'az ismeretlen típus kimarad a gyűjtésből',
    REST_BASE_BY_TYPE['release'] === undefined && REST_BASE_BY_TYPE['x'] === undefined,
  );
  check('a payload a három kulcsot adja', Object.keys(metaPayload({})).length === 3);
  check(
    'az IDEGEN meta nem számít angolnak',
    shouldSkip({ existing: { _yoast_wpseo_title: 'x' }, payload: {} }) === false,
  );
  check(
    'a teljes angolt kihagyja',
    shouldSkip({ existing: { [META_KEYS.title]: 'a', [META_KEYS.content]: 'b' }, payload: {} }) === true,
  );
  check(
    'a részleges angolt NEM hagyja ki',
    shouldSkip({ existing: { [META_KEYS.title]: 'a' }, payload: {} }) === false,
  );
  check('a felülírás kikapcsolja a kihagyást', shouldSkip({ existing: { [META_KEYS.title]: 'a', [META_KEYS.content]: 'b' }, payload: {}, force: true }) === false);
  check('a típus-térkép a hármat ismeri', Object.keys(REST_BASE_BY_TYPE).join(',') === 'event,artist,organizer');
  return checks;
}

let cachedAuthorization = null;

function authorization() {
  if (cachedAuthorization) return cachedAuthorization;
  const user = secret('WORDPRESS_USERNAME');
  const password = secret('WORDPRESS_APPLICATION_PASSWORD');
  if (!user || !password) throw new Error('a WordPress hitelesítés nincs beállítva');
  cachedAuthorization = `Basic ${Buffer.from(`${user}:${password}`).toString('base64')}`;
  return cachedAuthorization;
}

async function wp(pathname, { method = 'GET', body, auth } = {}) {
  const response = await fetch(`https://hungarianhardstyle.hu/wp-json/wp/v2${pathname}`, {
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

  const translations = collectTranslations();
  if (!translations.length) {
    console.log(`Nincs fordítás a ${EN_DIR} könyvtárban.`);
    return 1;
  }
  const confirm = process.argv.includes('--confirm');
  const force = process.argv.includes('--force');
  console.log(`fordítás: ${translations.length} elem (${[...new Set(translations.map((t) => t.type))].join(', ')})`);

  if (!confirm) {
    for (const entry of translations.slice(0, 10)) {
      console.log(`  [száraz] ${entry.key}: ${[...entry[META_KEYS.title]].length} + ${[...entry[META_KEYS.content]].length} karakter`);
    }
    console.log('\nA tényleges íráshoz add hozzá a --confirm kapcsolót.');
    return 0;
  }

  let done = 0;
  let skipped = 0;
  let failed = 0;
  for (const entry of translations) {
    const auth = authorization();
    const base = REST_BASE_BY_TYPE[entry.type];
    const before = await wp(`/${base}/${entry.id}?context=edit`, { auth });
    if (!before.ok) {
      console.log(`  ${entry.key}: HIBA a kiolvasásnál (HTTP ${before.status}) ${before.text.slice(0, 120)}`);
      failed += 1;
      continue;
    }
    if (shouldSkip({ existing: before.json?.meta, force, payload: entry })) {
      console.log(`  ${entry.key}: már teljes az angol (kihagyva)`);
      skipped += 1;
      continue;
    }
    const write = await wp(`/${base}/${entry.id}`, {
      method: 'POST',
      auth,
      body: { meta: { [META_KEYS.title]: entry[META_KEYS.title], [META_KEYS.excerpt]: entry[META_KEYS.excerpt], [META_KEYS.content]: entry[META_KEYS.content] } },
    });
    if (!write.ok) {
      console.log(`  ${entry.key}: ÍRÁS HIBA (HTTP ${write.status}) ${write.text.slice(0, 160)}`);
      failed += 1;
      continue;
    }
    const after = await wp(`/${base}/${entry.id}?context=edit`, { auth });
    const stored = after.json?.meta ?? {};
    const okTitle = String(stored[META_KEYS.title] ?? '').trim() !== '';
    const okContent = String(stored[META_KEYS.content] ?? '').trim() !== '';
    console.log(`  ${entry.key}: ${okTitle && okContent ? 'beírva és visszaolvasva' : 'FIGYELEM: a visszaolvasás üres'}`);
    if (okTitle && okContent) done += 1;
    else failed += 1;
  }
  console.log(`\nÍrás: ${done} elem, kihagyva ${skipped}, hiba ${failed}`);
  return failed ? 1 : 0;
}

if (process.argv[1] && process.argv[1].endsWith('write-content-translations.mjs')) {
  main().then((code) => {
    process.exitCode = code;
  }).catch((error) => {
    console.error(`HIBA: ${error.message}`);
    process.exitCode = 2;
  });
}
