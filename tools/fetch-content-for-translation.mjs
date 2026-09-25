#!/usr/bin/env node
/**
 * A fordításra váró WordPress-tartalom kigyűjtése (esemény, DJ, szervező, kiadvány).
 *
 * MIÉRT: a plugin 2.12.0 ugyanazt a három rejtett meta mezőt használja ezeknél a
 * típusoknál, mint a cikkeknél — a fordítás forrása viszont a jelenleg kiszolgált
 * **magyar** szöveg. Ez az eszköz begyűjti a listából + a részlet-végpontokból
 * (a bemutatók és leírások csak ott vannak), és **chunkokba** osztja, hogy a
 * fordítás párhuzamosítható legyen.
 *
 * Használat:
 *   node tools/fetch-content-for-translation.mjs            # összegzés
 *   node tools/fetch-content-for-translation.mjs --write     # tmp/content-en/*
 *   node tools/fetch-content-for-translation.mjs --self-test
 */
import fs from 'node:fs';
import path from 'node:path';

const BASE = 'https://hungarianhardstyle.hu/wp-json/huhs/v1';
export const OUT_DIR = 'tmp/content-en';
export const SOURCE_PATH = `${OUT_DIR}/source.json`;
export const CHUNK_DIR = `${OUT_DIR}/chunks`;
export const CHUNK_SIZE = 8;

/**
 * A típusok: végpont, a szöveg mezői és a részlet-végpont mintája.
 *
 * ⚠️ A **kiadvány szándékosan nincs a listában**: az egyetlen szöveges mezője a
 * **cím**, ami név (kiadvány/szám címe) — azt nem fordítjuk —, és a payloadban
 * nincs leírás sem. Mérve: 21 kiadvány, 0 fordítható prózai szöveg.
 */
export const CONTENT_TYPES = [
  { type: 'event', list: '/events', detail: (id) => `/events/${id}`, body: 'description' },
  { type: 'artist', list: '/artists?per_page=50', detail: (id) => `/artists/${id}`, body: 'biography' },
  { type: 'organizer', list: '/organizers?per_page=50', detail: (id) => `/organizers/${id}`, body: 'description' },
];

/** A HTML-tagek eltávolítása a **méréshez** (a fordító a nyers HTML-t kapja). */
export function plainText(html) {
  return String(html ?? '')
    .replace(/<[^>]*>/g, ' ')
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/\s+/g, ' ')
    .trim();
}

/** A begyűjtött elemek „üres-e" (nincs fordítható szövege). */
export function hasTranslatableText(entry) {
  return plainText(entry.title) !== '' && plainText(entry.content) !== '';
}

/** Chunkokba osztás (a típuson belül, hogy egy chunk egy típus szövegét vigye). */
export function chunkEntries(entries, size = CHUNK_SIZE) {
  const chunks = [];
  for (let index = 0; index < entries.length; index += size) {
    chunks.push(entries.slice(index, index + size));
  }
  return chunks;
}

export function selfTest() {
  const checks = [];
  const check = (label, ok) => checks.push({ label, ok });

  check('a HTML-taget kidobja', plainText('<p>Helló <strong>világ</strong></p>') === 'Helló világ');
  check('az entitást feloldja', plainText('a &amp; b') === 'a & b');
  check('a felesleges szóközt összevonja', plainText('a\n\n  b') === 'a b');
  check(
    'a cím ÉS a törzs kell a fordításhoz',
    hasTranslatableText({ title: 'Cím', content: 'Szöveg' })
      && !hasTranslatableText({ title: 'Cím', content: '   ' })
      && !hasTranslatableText({ title: '', content: 'Szöveg' }),
  );
  const chunks = chunkEntries([1, 2, 3, 4, 5], 2);
  check('a chunkolás helyes', chunks.length === 3 && chunks[2].length === 1);
  return checks;
}

async function fetchJson(url) {
  const response = await fetch(url);
  if (!response.ok) throw new Error(`${url}: HTTP ${response.status}`);
  return response.json();
}

function listItems(json) {
  if (Array.isArray(json)) return json;
  if (Array.isArray(json?.items)) return json.items;
  return [];
}

async function collect() {
  const all = [];
  for (const definition of CONTENT_TYPES) {
    const list = await fetchJson(`${BASE}${definition.list}${definition.list.includes('?') ? '&' : '?'}lang=hu`);
    const items = listItems(list);
    let skipped = 0;
    for (const item of items) {
      const id = Number(item?.id ?? 0);
      if (!id) continue;
      const detail = await fetchJson(`${BASE}${definition.detail(id)}?lang=hu`);
      const entry = {
        type: definition.type,
        id,
        title: String(item.title ?? detail.title ?? ''),
        content: String(detail[definition.body] ?? ''),
        excerpt: String(detail.excerpt ?? ''),
      };
      if (!hasTranslatableText(entry)) {
        skipped += 1;
        continue;
      }
      all.push(entry);
    }
    console.log(
      `${definition.type}: ${items.length} elem a listában, ${all.filter((e) => e.type === definition.type).length} fordítható`
      + (skipped ? `, ${skipped} kihagyva (nincs szövege)` : ''),
    );
  }
  return all;
}

async function main() {
  if (process.argv.includes('--self-test')) {
    const checks = selfTest();
    for (const check of checks) console.log(`${check.ok ? 'OK  ' : 'HIBA'} ${check.label}`);
    const failed = checks.filter((check) => !check.ok).length;
    console.log(`\n${checks.length - failed}/${checks.length} önteszt rendben`);
    return failed ? 1 : 0;
  }

  const entries = await collect();
  const characters = entries.reduce(
    (sum, entry) => sum + [...plainText(entry.title)].length + [...plainText(entry.content)].length,
    0,
  );
  console.log(`\nösszes fordítható elem: ${entries.length}`);
  console.log(`összes karakter (tagek nélkül): ${characters}`);

  if (!process.argv.includes('--write')) {
    console.log('\nAz íráshoz add hozzá a --write kapcsolót.');
    return 0;
  }

  fs.mkdirSync(CHUNK_DIR, { recursive: true });
  fs.writeFileSync(SOURCE_PATH, `${JSON.stringify(entries, null, 2)}\n`, 'utf8');
  fs.rmSync(CHUNK_DIR, { recursive: true, force: true });
  fs.mkdirSync(CHUNK_DIR, { recursive: true });

  let chunkIndex = 0;
  for (const definition of CONTENT_TYPES) {
    const typeEntries = entries.filter((entry) => entry.type === definition.type);
    for (const chunk of chunkEntries(typeEntries)) {
      chunkIndex += 1;
      const name = `chunk-${String(chunkIndex).padStart(2, '0')}-${definition.type}.json`;
      fs.writeFileSync(path.join(CHUNK_DIR, name), `${JSON.stringify(chunk, null, 2)}\n`, 'utf8');
    }
  }
  console.log(`\nforrás: ${SOURCE_PATH}`);
  console.log(`chunkok: ${chunkIndex} db → ${CHUNK_DIR}`);
  return 0;
}

if (process.argv[1] && process.argv[1].endsWith('fetch-content-for-translation.mjs')) {
  main().then((code) => {
    process.exitCode = code;
  }).catch((error) => {
    console.error(`HIBA: ${error.message}`);
    process.exitCode = 2;
  });
}
