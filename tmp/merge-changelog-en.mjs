#!/usr/bin/env node
/**
 * A Névjegy-changelog angol fordítása a szótárba.
 *
 * MIÉRT: a tulajdonos jelzése — *„a changelog az appban nem angol"* (angol
 * felületen). A kiírás nyers volt (`Text(change)`), és a szövegek nem voltak a
 * szótárban. A javítás: a magyar sor a **kulcs**, az angol a szótár értéke, a
 * kiírás pedig a fordítón megy át (`tr(context, change)`).
 *
 * Ez az eszköz **ellenőriz és ír**: minden sornak lennie kell fordítása
 * (hiányos csomag esetén hibát ad), az angol érték nem lehet ékezetes, és nem
 * egyezhet a magyar kulccsal.
 */
import fs from 'node:fs';

const HU = 'tmp/changelog-hu.json';
const CHUNKS = [
  'tmp/changelog-en-1.mjs',
  'tmp/changelog-en-2.mjs',
  'tmp/changelog-en-3.mjs',
  'tmp/changelog-en-4.mjs',
];
const DICT = 'assets/i18n/en.json';

const hungarian = JSON.parse(fs.readFileSync(HU, 'utf8'));

// ⚠️ A **legfrissebb** kiadások sorai a lista ELEJÉN állnak (371: 2 sor, 370:
// 2 sor, 369: 3 sor, 368: 2 sor), ezért a fordítók is elöl mennek — így a
// chunkok sorrendje változatlan maradhatott.
const latest = await import('../tmp/changelog-en-5.mjs');

const english = [
  ...latest.release371,
  ...latest.release370,
  ...latest.release369,
  ...latest.release368,
];
for (const chunk of CHUNKS) {
  const module = await import(`../${chunk}`);
  const values = module.default;
  if (!Array.isArray(values)) throw new Error(`${chunk}: nem tömböt exportál`);
  console.log(`${chunk}: ${values.length} sor`);
  english.push(...values);
}
console.log(
  `tmp/changelog-en-5.mjs: ${latest.release371.length + latest.release370.length + latest.release369.length + latest.release368.length} sor (a legfrissebb kiadások)`,
);

/**
 * Horgonyok: a sorrend-egyezés ellenőrzése (a puszta hossz-egyezés nem elég —
 * egy elcsúszott lista ugyanolyan hosszú lehet).
 */
const anchors = [
  [0, 'ÚJ: a Chat @mindenki értesítéséhez mostantól push', 'NEW: an @everyone mention in the Chat now also sends a push'],
  [2, 'Javítva: az értesítésben a cikk (és a kiadás, esemény, DJ) címe', 'Fixed: the title of the article (and of the release, event or DJ)'],
  [4, 'Javítva: angol felületen az értesítések szövege', 'Fixed: on the English interface notification texts'],
  [5, 'Javítva: a privát üzenet értesítésének címe', 'Fixed: the title of a private message notification'],
  [7, 'Javítva: angol felületen a kiadási jegyzet', 'Fixed: on the English interface the release notes'],
  [9, 'Javítva: angol felületen a játék eredményei', 'Fixed: on the English interface the Game results'],
  [42, 'A kvíz azonnal mutatja', 'The quiz now shows immediately'],
  [76, 'Gyorsabb betöltés', 'Faster loading'],
  [107, 'A hír kedveléséért járó pontot', 'The points for liking a news item'],
  [140, 'A kérdőív szavazólapja saját képernyőn', 'The poll ballot opens on its own screen'],
];

const problems = [];
if (english.length !== hungarian.length) {
  problems.push(`sorszám-eltérés: magyar ${hungarian.length}, angol ${english.length}`);
}

for (const [index, huPrefix, enPrefix] of anchors) {
  const hu = `${hungarian[index] ?? ''}`;
  if (!hu.startsWith(huPrefix)) {
    problems.push(`[${index}] a magyar sor nem a várt: ${hu.slice(0, 60)}`);
  }
  if (enPrefix !== null) {
    const en = `${english[index] ?? ''}`;
    if (!en.startsWith(enPrefix)) {
      problems.push(`[${index}] AZ ELCSÚSZÁS GYANÚJA — angol: ${en.slice(0, 60)}`);
    }
  }
}

const pairs = [];
for (let index = 0; index < Math.min(hungarian.length, english.length); index += 1) {
  const hu = hungarian[index];
  const en = `${english[index] ?? ''}`.trim();
  if (en === '') problems.push(`[${index}] üres fordítás: ${hu.slice(0, 60)}`);
  if (en === hu) problems.push(`[${index}] a fordítás a magyar szöveg: ${hu.slice(0, 60)}`);
  if (/[áéíóöőúüűÁÉÍÓÖŐÚÜŰ]/.test(en)) {
    problems.push(`[${index}] ékezet az angol szövegben: ${en.slice(0, 60)}`);
  }
  pairs.push([hu, en]);
}

if (problems.length) {
  console.log('\nHIBA — a fordítás nem teljes:');
  for (const problem of problems) console.log(`  ${problem}`);
  process.exit(1);
}

const dictionary = JSON.parse(fs.readFileSync(DICT, 'utf8'));
let added = 0;
let overwritten = 0;
for (const [hu, en] of pairs) {
  if (dictionary[hu] === en) continue;
  if (Object.prototype.hasOwnProperty.call(dictionary, hu)) overwritten += 1;
  dictionary[hu] = en;
  added += 1;
}

// A Névjegy további kulcsai (sablonok), amiket ez a kör érint.
for (const [hu, en] of Object.entries(latest.extraKeys ?? {})) {
  if (dictionary[hu] === en) continue;
  if (Object.prototype.hasOwnProperty.call(dictionary, hu)) overwritten += 1;
  dictionary[hu] = en;
  added += 1;
}

const sorted = {};
for (const key of Object.keys(dictionary).sort((a, b) => a.localeCompare(b, 'hu'))) {
  sorted[key] = dictionary[key];
}
fs.writeFileSync(DICT, `${JSON.stringify(sorted, null, 2)}\n`, 'utf8');

console.log(`\nchangelog-sor: ${pairs.length} (mind lefordítva)`);
console.log(`hozzáadva/frissítve: ${added} (ebből felülírás: ${overwritten})`);
console.log(`összes kulcs: ${Object.keys(sorted).length}`);
