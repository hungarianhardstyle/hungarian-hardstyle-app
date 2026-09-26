#!/usr/bin/env node
/**
 * ÉLES MÉRÉS (2026-09-26): a tulajdonos jelzése — *„a híreknél a kategóriák is
 * magyar"* (angol felületen).
 *
 * A hírek fül a kategória-neveket a WordPress **core** végpontjáról kapja
 * (`/wp-json/wp/v2/categories`), és a megjelenítésnél fordítja
 * (`tr(context, category.name)`) — vagyis **csak akkor lesz angol**, ha a név
 * pontosan szerepel a szótárban. Ez a szonda megméri, melyik élő kategórianév
 * hiányzik a szótárból.
 *
 * Csak olvas.
 *
 * Futtatás: node tmp/probe-news-categories.mjs
 */
import fs from 'node:fs';

const URL_CATEGORIES =
  'https://hungarianhardstyle.hu/wp-json/wp/v2/categories?per_page=100&hide_empty=true&_fields=id,name,slug,count';

const response = await fetch(URL_CATEGORIES);
if (!response.ok) throw new Error(`HTTP ${response.status}`);
const categories = await response.json();

const dictionary = JSON.parse(fs.readFileSync('assets/i18n/en.json', 'utf8'));
const keys = new Set(Object.keys(dictionary));

console.log(`élő kategóriák: ${categories.length}\n`);
let missing = 0;
for (const category of categories) {
  const name = String(category.name ?? '');
  const translated = dictionary[name];
  const hasKey = keys.has(name);
  if (!hasKey) missing += 1;
  console.log(
    `${hasKey ? 'OK   ' : 'HIÁNYZIK'}  #${category.id}  ${JSON.stringify(name)}`
    + `  (${category.count} cikk)`
    + (hasKey ? `  → ${JSON.stringify(translated)}` : ''),
  );
}
console.log(`\nszótárból hiányzó kategórianév: ${missing}/${categories.length}`);

// A „rejtett szóköz" típusú hiba kizárása: a kulcs vágott alakja létezik-e?
const trimmedHits = categories.filter(
  (category) => !keys.has(String(category.name ?? ''))
    && keys.has(String(category.name ?? '').trim()),
);
console.log(`csak vágott alakban létező kulcs: ${trimmedHits.length}`);
