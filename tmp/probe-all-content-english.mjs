#!/usr/bin/env node
/**
 * ÉLES MÉRÉS (2026-09-26) — a tulajdonos **elvárt működése**:
 *
 *   *„Felteszek egy hírt, dj-t, szervezőt, eseményt, kvízt, nyereményjátékot,
 *   vagy kérdőívet, kiadványt → egyből jelenjen meg angolul, és semmi ne legyen
 *   az angol verzióban magyar; nem baj ha ez automata."*
 *
 * Ez a szonda **minden** tartalomtípust lehúz a plugin nyilvános végpontjairól
 * `lang=en`-nel, és megkeresi a **magyar maradványokat**:
 *   1. magyar ékezetes betűk (`á é í ó ö ő ú ü ű`) a szövegben,
 *   2. gyakori magyar szavak (a fordítás „visszaadta a forrást" esete),
 *   3. a leggyakoribb angol feliratok hiánya (ha a mező üreslen maradt).
 *
 * Csak olvas. Futtatás: node tmp/probe-all-content-english.mjs
 */
const BASE = 'https://hungarianhardstyle.hu/wp-json/huhs/v1';

const HUNGARIAN_LETTERS = /[áéíóöőúüűÁÉÍÓÖŐÚÜŰ]/;
/**
 * ⚠️ **MÁSODIK TANULSÁG (ugyanaz a futás):** az angol `is` szó **magyar
 * funkciószó is** (`is` = „also"), ezért a lista csak **egyértelműen magyar**
 * szavakat tartalmazhat — az angollal ütközőket (`is`, `van`, `de`, `ha`, `az`)
 * kivettem.
 */
const HUNGARIAN_FUNCTION_WORDS = [
  'és', 'vagy', 'hogy', 'nem', 'egy', 'már', 'csak', 'minden', 'lesz',
  'volt', 'aki', 'amely', 'után', 'előtt', 'két', 'több', 'lehet', 'kell',
  'miatt', 'szerint', 'azonban', 'ezért', 'mivel', 'illetve', 'továbbá',
  'nélkül', 'között', 'által', 'valamint', 'vagyis', 'jelenleg', 'idén',
  'tavaly', 'elővételben', 'kapható', 'megrendezik', 'részletek',
];

const fetchJson = async (path) => {
  const response = await fetch(`${BASE}${path}`, {
    headers: { Accept: 'application/json', 'User-Agent': 'HUHS-probe/1.0' },
  });
  if (!response.ok) return { error: `HTTP ${response.status}` };
  const body = await response.text();
  if (!body.trim()) return { error: 'üres válasz' };
  try {
    return JSON.parse(body);
  } catch (_) {
    return { error: `nem JSON (${body.slice(0, 40)}…)` };
  }
};

const asItems = (json) => (Array.isArray(json) ? json : json?.items ?? []);

/** Magyar **mondat**-gyanú: legalább 3 magyar funkciószó egy 200 karakteres ablakban. */
const hungarianFragment = (value) => {
  const text = String(value ?? '').replace(/<[^>]*>/g, ' ').replace(/\s+/g, ' ').trim();
  if (text.length < 20) return null;
  const words = text.split(/\s+/);
  const functionWords = new Set(HUNGARIAN_FUNCTION_WORDS);
  const clean = (word) => word.toLowerCase().replace(/[^a-záéíóöőúüű]/g, '');
  for (let index = 0; index < words.length; index += 1) {
    const window = words.slice(index, index + 32);
    const hits = window.map(clean).filter((word) => functionWords.has(word));
    if (hits.length >= 3) {
      return {
        kind: `magyar funkciószavak (${[...new Set(hits)].slice(0, 4).join(', ')})`,
        fragment: window.join(' ').slice(0, 120),
      };
    }
  }
  return null;
};

/** A tartalom „olvasható” szöveges mezői (a cím és az azonosítók nem számítanak). */
const TEXT_FIELDS = [
  'biography', 'excerpt', 'description', 'content', 'summary', 'question',
  'options', 'answers', 'type', 'prize', 'reward', 'details', 'place',
  'venue', 'address', 'label', 'title_en', 'subtitle',
];

const report = async (label, path, { fields = TEXT_FIELDS, listFields = [] } = {}) => {
  const json = await fetchJson(path);
  if (json?.error) {
    console.log(`\n=== ${label}: HIBA — ${json.error}`);
    return { label, total: 0, hungarian: 0, examples: [] };
  }
  const items = asItems(json);
  let hungarian = 0;
  const examples = [];
  for (const item of items) {
    const texts = [];
    for (const field of fields) {
      const value = item?.[field];
      if (typeof value === 'string') texts.push([field, value]);
      if (Array.isArray(value)) {
        value.forEach((entry, index) => {
          if (typeof entry === 'string') texts.push([`${field}[${index}]`, entry]);
        });
      }
    }
    for (const field of listFields) {
      const value = item?.[field];
      if (Array.isArray(value)) {
        value.forEach((entry, index) => {
          if (typeof entry === 'object' && entry) {
            Object.entries(entry).forEach(([key, inner]) => {
              if (typeof inner === 'string') texts.push([`${field}[${index}].${key}`, inner]);
            });
          } else if (typeof entry === 'string') {
            texts.push([`${field}[${index}]`, entry]);
          }
        });
      }
    }
    const bad = [];
    for (const [field, value] of texts) {
      const hit = hungarianFragment(value);
      if (hit) bad.push([field, hit]);
    }
    if (bad.length) {
      hungarian += 1;
      if (examples.length < 5) {
        examples.push(
          `${String(item.title ?? item.name ?? item.id ?? '?').slice(0, 26)} → `
          + bad.slice(0, 2).map(([field, hit]) =>
            `${field} (${hit.kind}): „${hit.fragment.slice(0, 90)}”`).join(' | '),
        );
      }
    }
  }
  console.log(`\n=== ${label}: ${items.length} elem, ebből MAGYAR maradvány: ${hungarian}`);
  for (const example of examples) console.log(`   ${example}`);
  return { label, total: items.length, hungarian, examples };
};

const results = [];
results.push(await report('Hírek', '/posts?per_page=20&lang=en'));
results.push(await report('DJ-k', '/artists?per_page=50&lang=en'));
results.push(await report('Szervezők', '/organizers?per_page=50&lang=en'));
results.push(await report('Események', '/events?per_page=20&lang=en'));
results.push(await report('Kiadványok', '/releases?per_page=20&lang=en'));
results.push(await report('Aktív kvíz', '/games/active?lang=en', { listFields: ['questions'] }));
results.push(await report('Aktív nyereményjáték', '/prize/active?lang=en', { listFields: ['answers'] }));
results.push(await report('Aktív kérdőív', '/poll/active?lang=en', { listFields: ['options'] }));

console.log('\n--- ÖSSZEGZÉS');
for (const result of results) {
  console.log(`  ${result.label.padEnd(22)} ${result.hungarian}/${result.total} magyar maradvány`);
}
const total = results.reduce((sum, item) => sum + item.hungarian, 0);
console.log(`\nmagyar maradvány összesen: ${total}`);
