// A szóközzel körbevett szótár-kulcsok MÉRT használata a kódban.
//
// MIÉRT: a futásidejű szótár (`AppStrings.parseEnglishDictionary`) a kulcsokat
// `trim()`-eli, ezért egy „ szóközös " kulcsot a `tr(' szóközös ')` hívás
// **soha nem talál meg** → angol módban magyarul marad. Ez a hibaosztály
// ugyanaz, mint a nyers literáloké: a kulcs LÉTEZIK, csak elérhetetlen.
import { readFileSync, readdirSync, statSync } from 'node:fs';
import path from 'node:path';

const dict = JSON.parse(readFileSync('assets/i18n/en.json', 'utf8'));
const padded = Object.keys(dict).filter((key) => key !== key.trim());

// Ütközés: a trim-elt alak egy MÁSIK kulcsra is illeszkedik?
const byTrimmed = new Map();
for (const key of Object.keys(dict)) {
  const trimmed = key.trim();
  if (!byTrimmed.has(trimmed)) byTrimmed.set(trimmed, []);
  byTrimmed.get(trimmed).push(key);
}
const collisions = [...byTrimmed.entries()].filter(([, keys]) => keys.length > 1);

function walk(dir, out = []) {
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(full, out);
    else if (entry.isFile() && entry.name.endsWith('.dart')) out.push(full);
  }
  return out;
}

const files = walk('lib');
const sources = files.map((file) => ({ file, text: readFileSync(file, 'utf8') }));

console.log(`szóközzel körbevett kulcs: ${padded.length}`);
console.log(`ütközés (ugyanaz a trim-elt alak): ${collisions.length}`);
for (const [trimmed, keys] of collisions) {
  console.log(`  ÜTKÖZÉS ${JSON.stringify(trimmed)}: ${keys.map((k) => JSON.stringify(k)).join(', ')}`);
}

console.log('\n=== használat a kódban (csak a fordítás-hívásokban számít)');
let unused = 0;
let usedInCall = 0;
for (const key of padded) {
  // A Dart-forrásban a literál aposztróffal áll; escape-eljük az aposztrófot.
  const literal = `'${key.replace(/\\/g, '\\\\').replace(/'/g, "\\'")}'`;
  const hits = [];
  for (const { file, text } of sources) {
    let index = text.indexOf(literal);
    while (index !== -1) {
      const line = text.slice(0, index).split('\n').length;
      const before = text.slice(Math.max(0, index - 120), index);
      const inCall = /(tr|trArgs|AppText)\(\s*(context,\s*)?$/.test(before) || /(tr|trArgs|AppText)\($/.test(before.trimEnd());
      hits.push({ file, line, inCall, before: before.split('\n').pop() });
      index = text.indexOf(literal, index + 1);
    }
  }
  if (hits.length === 0) {
    unused += 1;
    console.log(`  NINCS a kódban  ${JSON.stringify(key)}`);
  } else {
    if (hits.some((hit) => hit.inCall)) usedInCall += 1;
    console.log(`  ${hits.some((hit) => hit.inCall) ? 'HÍVÁSBAN ' : 'máshol   '} ${JSON.stringify(key)}`);
    for (const hit of hits) {
      console.log(`      ${hit.file}:${hit.line}  ${hit.inCall ? '(fordítás-hívás)' : ''}`);
    }
  }
}
console.log(`\nösszegzés: ${usedInCall} kulcs áll fordítás-hívásban, ${unused} nincs a kódban`);
