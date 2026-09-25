#!/usr/bin/env node
/**
 * Az **angol tartalom** ÉLES állapotának mérése — egy paranccsal.
 *
 * MIÉRT KELL: a WordPress-tartalom angol változata három külön dologtól függ, és
 * ezeket eddig külön-külön mértük (kézzel, ideiglenes szkriptekkel):
 *  1. **plugin-támogatás** — az esemény/DJ/szervező angol meta csak akkor
 *     regisztrált (és így REST-en írható), ha a **2.12.0** fent van;
 *  2. **nyilvános végpontok** — a `huhs/v1` listák `?lang=en` válasza adja-e az
 *     angol szöveget (`has_en: true`), és a `?lang=hu` maradt-e magyar;
 *  3. **a weboldal** — az angol változat **nem** szivároghat ki a nyilvános
 *     oldalakra (a tulajdonos kérése: *„a weboldalon az angol ne jelenjen meg"*).
 *
 * Ez az eszköz **csak olvas** (a WordPress-jelszót a Secret Managerből kéri, és
 * `GET`-et hív), ezért bármikor futtatható. A beírás külön eszköz
 * (`tools/write-content-translations.mjs --confirm`), és csak akkor van értelme,
 * ha ez a mérés azt mondja: a plugin támogatja.
 *
 * Használat:
 *   node tools/check-content-english-live.mjs
 *   node tools/check-content-english-live.mjs --self-test
 */
import { secret } from './lib/live-firebase.mjs';
import { META_KEYS } from './lib/translation-meta.mjs';

export const PUBLIC_API = 'https://hungarianhardstyle.hu/wp-json/huhs/v1';
export const WP_API = 'https://hungarianhardstyle.hu/wp-json/wp/v2';

/** A nyilvános végpontok típusonként (a `huhs/v1` útvonalak). */
export const PUBLIC_ROUTES = {
  article: 'posts',
  event: 'events',
  artist: 'artists',
  organizer: 'organizers',
};

/** A WordPress post-típusok, amiknek angol mezőt kell tudniuk. */
export const POST_TYPES = ['post', 'huhs_event', 'huhs_artist', 'huhs_organizer'];

/** Hány elem ad angol szöveget a válaszban. */
export function countHasEn(items) {
  const list = Array.isArray(items) ? items : [];
  return {
    total: list.length,
    withEn: list.filter((item) => item?.has_en === true).length,
  };
}

/** Normalizálás a HTML-kereséshez: whitespace, nem törhető szóköz, HTML-entitások. */
export function normalizeForSearch(text) {
  return String(text ?? '')
    .replace(/&#8211;|&ndash;/g, '–')
    .replace(/&#8217;|&rsquo;/g, '’')
    .replace(/&quot;/g, '"')
    .replace(/&amp;/g, '&')
    .replace(/&nbsp;/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

/**
 * Kiszivárgott-e az angol szöveg a nyilvános HTML-be?
 *
 * ⚠️ Rövid szövegre a keresés **hamis pozitív** lehet (pl. egy angol cím egyben
 * márkanév is), ezért csak akkor jelez, ha a minta elég hosszú (≥ 12 karakter) —
 * a rövidebbeket a hívó szándékosan kihagyja.
 */
export function englishLeak(html, englishText) {
  const needle = normalizeForSearch(englishText);
  if (needle.length < 12) return false;
  return normalizeForSearch(html).includes(needle);
}

/** A plugin-támogatás összegzése a `context=edit` próbákból. */
export function pluginSupport(probes) {
  const supported = {};
  for (const [type, meta] of Object.entries(probes ?? {})) {
    const keys = Object.keys(meta ?? {});
    supported[type] = keys.includes(META_KEYS.title) && keys.includes(META_KEYS.content);
  }
  return supported;
}

export function selfTest() {
  const checks = [];
  const check = (label, ok) => checks.push({ label, ok });

  check(
    'a has_en számlálás jó',
    JSON.stringify(countHasEn([{ has_en: true }, { has_en: false }, {}])) === '{"total":3,"withEn":1}',
  );
  check('a has_en hiánya nem számol', countHasEn([{}, {}]).withEn === 0);
  check('a nem lista üres', countHasEn(null).total === 0);
  check(
    'a normalizálás összevonja a whitespace-t és az entitásokat',
    normalizeForSearch('Kick\n  &#8211;  Culture') === 'Kick – Culture',
  );
  check(
    'a hosszú angol szöveg kiszivárgását jelzi',
    englishLeak('<p>Hello world, this is English text</p>', 'Hello world, this is English text'),
  );
  check(
    'a rövid mintát szándékosan nem jelzi (hamis pozitív elleni védelem)',
    englishLeak('<p>Hardstyle</p>', 'Hardstyle') === false,
  );
  check('a hiányzó angol szöveget nem jelzi', englishLeak('<p>magyar</p>', 'English content here') === false);
  check(
    'a plugin-támogatás csak a MINDKÉT meta-kulccsal igaz',
    JSON.stringify(
      pluginSupport({
        post: { [META_KEYS.title]: '', [META_KEYS.content]: '' },
        huhs_event: { [META_KEYS.title]: '' },
        huhs_artist: {},
      }),
    ) === '{"post":true,"huhs_event":false,"huhs_artist":false}',
  );
  return checks;
}

async function getJson(url, headers = {}) {
  const response = await fetch(url, { headers: { accept: 'application/json', ...headers } });
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

  let authorization = '';
  try {
    const user = secret('WORDPRESS_USERNAME');
    const password = secret('WORDPRESS_APPLICATION_PASSWORD');
    authorization = `Basic ${Buffer.from(`${user}:${password}`).toString('base64')}`;
  } catch (error) {
    console.log(`⚠️ WordPress hitelesítés nélkül futok (${error.message}) — a plugin-próba kimarad.`);
  }

  // 1) Plugin-támogatás: a `context=edit` válasz `meta` kulcsai.
  const probes = {};
  if (authorization) {
    const types = await getJson(`${WP_API}/types?context=edit`, { authorization });
    const restBase = {};
    if (types.ok && types.json) {
      for (const [name, definition] of Object.entries(types.json)) {
        restBase[name] = definition?.rest_base || name;
      }
    }
    for (const type of POST_TYPES) {
      const base = restBase[type];
      if (!base) continue;
      const list = await getJson(`${WP_API}/${base}?per_page=1&context=edit`, { authorization });
      if (!list.ok || !Array.isArray(list.json) || !list.json.length) continue;
      probes[type] = list.json[0].meta || {};
    }
  }
  const support = pluginSupport(probes);
  console.log('=== 1) Plugin-támogatás (a 2.12.0 angol meta mezői)');
  for (const type of POST_TYPES) {
    const keys = Object.keys(probes[type] ?? {});
    console.log(
      `  ${type.padEnd(15)} ${support[type] ? 'TÁMOGATOTT' : 'nem támogatott'} `
      + `(${keys.length} meta-kulcs, _huhs_*: ${keys.filter((k) => k.startsWith('_huhs_')).length})`,
    );
  }

  // 2) Nyilvános végpontok: `?lang=hu` és `?lang=en`.
  console.log('\n=== 2) Nyilvános végpontok (huhs/v1)');
  const endpoints = {};
  for (const [type, route] of Object.entries(PUBLIC_ROUTES)) {
    const hu = await getJson(`${PUBLIC_API}/${route}?per_page=50&lang=hu`);
    const en = await getJson(`${PUBLIC_API}/${route}?per_page=50&lang=en`);
    const huList = Array.isArray(hu.json) ? hu.json : (hu.json?.items || []);
    const enList = Array.isArray(en.json) ? en.json : (en.json?.items || []);
    endpoints[type] = { hu: countHasEn(huList), en: countHasEn(enList), enItems: enList, huStatus: hu.status, enStatus: en.status };
    console.log(
      `  ${type.padEnd(10)} ?lang=hu: ${endpoints[type].hu.withEn}/${endpoints[type].hu.total} angol | `
      + `?lang=en: ${endpoints[type].en.withEn}/${endpoints[type].en.total} angol`,
    );
  }

  // 3) A weboldal: az angol változat NE szivárogjon ki.
  console.log('\n=== 3) A weboldal (az angol nem jelenhet meg)');
  const article = endpoints.article?.enItems?.find((item) => item?.link && item?.has_en === true);
  if (!article) {
    console.log('  ⚠️ Nincs mérhető angol cikk (a mérés kimarad).');
  } else {
    const page = await fetch(article.link, { headers: { accept: 'text/html' } });
    const html = await page.text();
    const enTitle = article.title?.rendered || article.title || '';
    const leak = englishLeak(html, enTitle.replace(/<[^>]*>/g, ''));
    const marker = String(article.excerpt?.rendered || '').replace(/<[^>]*>/g, '').slice(0, 120);
    const leakExcerpt = marker.length >= 12 && englishLeak(html, marker);
    console.log(`  cikk: ${article.link}`);
    console.log(`  angol cím a nyilvános HTML-ben: ${leak ? 'KISZIVÁRGOTT' : 'nincs'}`);
    console.log(`  angol kivonat a nyilvános HTML-ben: ${leakExcerpt ? 'KISZIVÁRGOTT' : 'nincs'}`);
  }

  const pluginReady = POST_TYPES.filter((type) => type !== 'post').every((type) => support[type] === true);
  console.log('\n=== ÖSSZEGZÉS');
  console.log(`  a plugin (2.12.0) támogatja az esemény/DJ/szervező angol mezőt: ${pluginReady}`);
  console.log(`  a cikkek angolul: ${endpoints.article?.en.withEn ?? 0}/${endpoints.article?.en.total ?? 0}`);
  console.log(
    `  esemény: ${endpoints.event?.en.withEn ?? 0}, DJ: ${endpoints.artist?.en.withEn ?? 0}, `
    + `szervező: ${endpoints.organizer?.en.withEn ?? 0}`,
  );
  if (!pluginReady) {
    console.log('  → a tartalom-fordítás beírása a plugin 2.12.0 feltöltésére vár '
      + '(build/huhs-mobile-api-2.12.0.zip)');
  }
  return 0;
}

if (process.argv[1] && process.argv[1].endsWith('check-content-english-live.mjs')) {
  process.exitCode = await main();
}
