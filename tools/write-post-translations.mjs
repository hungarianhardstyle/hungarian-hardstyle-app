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
import { META_KEYS } from './lib/translation-meta.mjs';

const WP_BASE = 'https://hungarianhardstyle.hu/wp-json/wp/v2';
const EN_DIR = 'tmp/newsroom-en/en';
const HU_FILE = 'tmp/newsroom-en/hu-posts.json';

/** A három meta kulcs — közös modulból (a tartalom-író is ezt használja). */
export { META_KEYS };

/** A fordításból meta payload (tiszta függvény). */
export function metaPayload(translation) {
  return {
    [META_KEYS.title]: String(translation.title_en ?? ''),
    [META_KEYS.excerpt]: String(translation.excerpt_en ?? ''),
    [META_KEYS.content]: String(translation.content_en ?? ''),
  };
}

/**
 * Összehasonlítható alak a visszaolvasáshoz.
 *
 * ⚠️ MIÉRT KELL (mért, 2026-09-25): a WordPress a mentett HTML-t **normalizálja**
 * (pl. `<img ... />` → `<img ...  />`, illetve a tagek közötti whitespace-t
 * egységesíti), ezért a nyers string-összehasonlítás **minden** cikknél hamis
 * „eltér" jelzést adott — pedig a cím és a kivonat bájtpontosan egyezett, csak a
 * törzsben lett 3 karakter különbség. A normalizált alak a whitespace-t és a
 * tag-zárójelet egységesíti, de **a tageket nem dobja el**: ha a WP `wp_kses_post`
 * kidobna egy elemet, a normalizált alak továbbra is eltér (nem lesz hamis zöld).
 */
export function comparable(text) {
  return String(text ?? '')
    .replace(/\s+/g, ' ')
    .replace(/\s*\/>/g, '/>')
    .trim();
}

/** A visszaolvasás elfogadható-e? (normalizált egyezés; üres válasz sosem az) */
export function readBackMatches({ local, remote }) {
  const mine = comparable(local);
  const theirs = comparable(remote);
  return Boolean(theirs) && mine === theirs;
}

/**
 * Az angol fordítás ÁLLAPOTA a WP `meta` objektumából.
 *
 * ⚠️ MIÉRT CSAK A HÁROM KULCSOT NÉZZÜK (mért hiba, 2026-09-25): a `context=edit`
 * válasz `meta` objektuma **más pluginok kulcsait is** tartalmazza (Yoast, Rank
 * Math, saját beállítások), és azok gyakran ki vannak töltve. Az első változat
 * ezért **minden** meta-értéket vizsgált, és a már kitöltött cikkeket
 * „már van angol"-nak hitte → egyetlen fordítást sem írt volna be. Csak a saját
 * három kulcs számít, és csak a **string** típusú, nem üres érték.
 *
 * A `has_en` a pluginban **csak akkor** igaz, ha a cím ÉS a törzs is angol —
 * ezért a „kész" is ezt a kettőt kéri (a részleges állapotot be kell fejezni).
 */
export function translationState(existing) {
  const meta = existing ?? {};
  const filled = (key) => typeof meta[key] === 'string' && meta[key].trim().length > 0;
  const hasTitle = filled(META_KEYS.title);
  const hasContent = filled(META_KEYS.content);
  const hasExcerpt = filled(META_KEYS.excerpt);
  return {
    hasTitle,
    hasContent,
    hasExcerpt,
    complete: hasTitle && hasContent,
    partial: !(hasTitle && hasContent) && (hasTitle || hasContent || hasExcerpt),
  };
}

/** Kihagyjuk-e a cikket (már van teljes angol, és nem kértünk felülírást)? */
export function shouldSkip({ existing, force }) {
  if (force) return false;
  return translationState(existing).complete;
}

export function selfTest() {
  const checks = [];
  const check = (label, ok) => checks.push({ label, ok });
  const payload = metaPayload({ title_en: 'T', excerpt_en: 'E', content_en: 'C' });
  check('a payload a három kulcsot adja', Object.keys(payload).length === 3);
  check('a cím kulcsa jó', payload[META_KEYS.title] === 'T');
  check('a tartalom kulcsa jó', payload[META_KEYS.content] === 'C');
  check('hiányzó mezőt üresre állít', metaPayload({}).title_en === undefined);
  check('a teljes angolt kihagyja', shouldSkip({ existing: { [META_KEYS.title]: 'x', [META_KEYS.content]: 'y' } }) === true);
  check('üres meta nem kihagyás', shouldSkip({ existing: { [META_KEYS.title]: '  ', [META_KEYS.content]: '  ' } }) === false);
  check('felülíráskor nem kihagyás', shouldSkip({ existing: { [META_KEYS.title]: 'x', [META_KEYS.content]: 'y' }, force: true }) === false);
  // ⚠️ Ezek a mutáció-őrök: a régi, hibás „bármely érték" logika itt bukna el.
  check(
    'az IDEGEN meta nem számít angolnak',
    shouldSkip({ existing: { _yoast_wpseo_title: 'magyar cím', _thumbnail_id: '123' } }) === false,
  );
  check(
    'a `false`/`null` meta nem számít angolnak',
    shouldSkip({ existing: { [META_KEYS.title]: false, [META_KEYS.content]: null } }) === false,
  );
  check(
    'a részleges angol nem kész',
    translationState({ [META_KEYS.excerpt]: 'x' }).partial === true
      && shouldSkip({ existing: { [META_KEYS.excerpt]: 'x' } }) === false,
  );
  check('a cím+excerpt angol még nem kész', shouldSkip({ existing: { [META_KEYS.title]: 'x', [META_KEYS.excerpt]: 'y' } }) === false);
  // A visszaolvasás: a WP HTML-normalizálását el kell viselni, a valódi eltérést nem.
  check(
    'a WP normalizált HTML-je egyezik',
    readBackMatches({ local: '<img src="a.jpg"/>', remote: '<img src="a.jpg" />' }) === true,
  );
  check(
    'a whitespace-eltérés egyezik',
    readBackMatches({ local: 'a\n\nb', remote: 'a  b' }) === true,
  );
  check(
    'a valódi tartalom-eltérés NEM egyezik',
    readBackMatches({ local: '<p>a</p><p>b</p>', remote: '<p>a</p>' }) === false,
  );
  check(
    'a kidobott tag NEM egyezik',
    readBackMatches({ local: '<p><strong>a</strong></p>', remote: '<p>a</p>' }) === false,
  );
  check('az üres visszaolvasás NEM egyezik', readBackMatches({ local: 'a', remote: '' }) === false);
  return checks;
}


/** A WordPress Basic-hitelesítés — EGYSZER olvasva (a `secret()` minden hívása
 *  külön `firebase functions:secrets:access` folyamat; cikkenként kétszer hívva
 *  a 30 cikk 60 folyamatot indított, és az egyik elhasalt — mért hiba). */
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
      console.log(`  ${source.id}: már teljes az angol (kihagyva)`);
      skipped += 1;
      continue;
    }
    if (translationState(before.json?.meta).partial) {
      console.log(`  ${source.id}: részleges angol — kiegészítem`);
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
    // 2) visszaolvasás — a WP néha csendben eldobja a metát, és a HTML-t normalizálja
    const after = await wp(`/posts/${source.id}?context=edit`, { auth });
    const stored = after.json?.meta ?? {};
    const okContent = readBackMatches({
      local: payload[META_KEYS.content],
      remote: stored[META_KEYS.content],
    });
    const okTitle = readBackMatches({
      local: payload[META_KEYS.title],
      remote: stored[META_KEYS.title],
    });
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

// ⚠️ A `main()` CSAK közvetlen futtatáskor induljon: az első változat betöltéskor
// is lefutott, ezért a tartalom-író importja összekeverte a két eszközt.
if (process.argv[1] && process.argv[1].endsWith('write-post-translations.mjs')) {
  main()
    .then((code) => {
      process.exitCode = code;
    })
    .catch((error) => {
      console.error(`HIBA: ${error.message}`);
      process.exitCode = 2;
    });
}
