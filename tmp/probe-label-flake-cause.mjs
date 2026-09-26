#!/usr/bin/env node
/**
 * MÉRÉS (2026-09-26): a `label_release_availability` teszt „ismételt megjelölés"
 * ellenőrzése a **nyers** tárolóban számolja a `305` rész-szöveget:
 *
 *   expect('305'.allMatches(payload).length, 1);
 *
 * A tárolt JSON viszont az **időpontot is** tartalmazza (`at`), ezért ha a
 * timestamp számjegyei között ott a `305`, a találatok száma **2** lesz — vagyis
 * a teszt **hamisan bukik** (a CI-n pontosan ez történt: „Expected: <1>
 * Actual: <2>"). Ez a szonda megméri, milyen gyakori ez.
 */
const payloadFor = (at) => JSON.stringify([{ id: 305, at }]);

let hits = 0;
const samples = 200000;
// A mai idő körüli, valósághű ezredmásodperc-értékek (13 jegyű epoch ms).
const base = Date.now();
for (let index = 0; index < samples; index += 1) {
  const payload = payloadFor(base + index);
  if ('305'.allMatches ? false : payload.split('305').length - 1 !== 1) hits += 1;
}

console.log(`minta: ${samples} időpont (a mostani idő környékén)`);
console.log(`hamis bukás (a '305' kétszer szerepel a nyers JSON-ban): ${hits} (${((hits / samples) * 100).toFixed(3)}%)`);

// Példák a konkrét előfordulásra.
const examples = [];
for (let index = 0; index < 2000000 && examples.length < 5; index += 1) {
  const at = base + index;
  const payload = payloadFor(at);
  if (payload.split('305').length - 1 > 1) examples.push(payload);
}
console.log('\npéldák (a timestampben ott a 305):');
for (const example of examples) console.log(`  ${example}`);
