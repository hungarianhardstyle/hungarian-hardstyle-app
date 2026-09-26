#!/usr/bin/env node
/**
 * ÉLES MÉRÉS (2026-09-26): a tulajdonos jelzése — *„Goze leírásában: Hardstyle
 * producer &amp; … itt csak a kódolási hiba van"* (Goze, DJ, Nu-Clear).
 *
 * A kérdés: a **forrás** tartalmazza a `&amp;` entitást (amit az app még egyszer
 * escape-el, ezért látszik `&amp;`), vagy a szerver ad sima `&`-t?
 *
 * Csak olvas, a nyilvános végpontot kéri (ugyanazt, amit az app).
 *
 * Futtatás: node tmp/probe-amp-entities.mjs
 */
const BASE = 'https://hungarianhardstyle.hu/wp-json/huhs/v1';

const fetchJson = async (path) => {
  const response = await fetch(`${BASE}${path}`, {
    headers: { 'Accept': 'application/json', 'User-Agent': 'HUHS-probe/1.0' },
  });
  if (!response.ok) throw new Error(`${path}: HTTP ${response.status}`);
  return response.json();
};

const decode = (value) => String(value ?? '').replace(/<[^>]*>/g, ' ');

const report = (label, items) => {
  console.log(`\n=== ${label}: ${items.length} elem`);
  let withEntity = 0;
  for (const item of items) {
    const raw = String(item.biography ?? '');
    const occurrences = (raw.match(/&amp;/g) || []).length;
    if (!occurrences) continue;
    withEntity += 1;
    const example = decode(raw)
      .replace(/\s+/g, ' ')
      .match(/.{0,45}&amp;.{0,25}/);
    console.log(
      `  ${String(item.title ?? item.name ?? '?').slice(0, 24)}: ${occurrences}× &amp;`
      + (example ? `  …${example[0]}…` : ''),
    );
  }
  console.log(`  ebből entitást tartalmazó életrajz: ${withEntity}/${items.length}`);
};

const hu = (await fetchJson('/artists?per_page=50')).items ?? [];
report('DJ-k (hu)', hu);
const en = (await fetchJson('/artists?per_page=50&lang=en')).items ?? [];
report('DJ-k (en)', en);

// Keressük a konkrét neveket is (a tulajdonos jelzése szerint).
for (const item of [...hu, ...en]) {
  const name = String(item.title ?? item.name ?? '');
  if (!/goze|nu-?clear|^dj$/i.test(name)) continue;
  const raw = String(item.biography ?? '');
  console.log(`\n--- ${name} (${raw.length} karakter) ---`);
  console.log(raw.replace(/\s+/g, ' ').slice(0, 220));
}
