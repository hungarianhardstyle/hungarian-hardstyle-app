#!/usr/bin/env node
/**
 * ÉLES mérés: maradt-e magyar szöveg az **angol** GYÍK-válaszokban, és mennyi a
 * formázás-szemét?
 *
 * ⚠️ MIÉRT: a 2.14.x gépi fordítása egyszer **visszaadta a magyar forrást** (a
 * tulajdonos észrevétele: *„ami iphoneon angol, az androidon magyar maradt"*),
 * ezért ez a szonda kérdésenként ellenőrzi az angol válaszokat. A „magyar"
 * eldöntése **két** jelből jön (ékezet VAGY magyar funkciószó), és a HTML-t
 * külön számolja (a régi válaszok `<p>…</p>` burkolással jöttek).
 *
 * Csak olvas. Használat: node tmp/check-faq-english.mjs [--verbose]
 */
const BASE = 'https://hungarianhardstyle.hu/wp-json/huhs/v1/faq?lang=en';
const verbose = process.argv.includes('--verbose');

const hungarianOnly = /[áéíóöőúüűÁÉÍÓÖŐÚÜŰ]/;
const hungarianWords =
  /\b(es|az|egy|nem|van|hogy|mert|vagy|minden|után|kell|bejelentkezés|hírek|események|kérdés|válasz|beállítás)\b/i;

const response = await fetch(`${BASE}&_p=${Date.now()}`);
const payload = await response.json();
const items = Array.isArray(payload) ? payload : (payload.items ?? []);

let hungarian = 0;
let tagged = 0;
for (const item of items) {
  const raw = String(item.answer ?? '');
  const plain = raw.replace(/<[^>]*>/g, ' ').replace(/\s+/g, ' ').trim();
  if (/<[a-z/][^>]*>/i.test(raw)) tagged += 1;
  const looksHungarian =
    hungarianOnly.test(plain.slice(0, 200)) ||
    hungarianWords.test(plain.slice(0, 200));
  if (looksHungarian) {
    hungarian += 1;
    console.log(
      `MAGYAR? id=${item.id}  kérdés=${JSON.stringify(String(item.question).slice(0, 55))}` +
        `  válasz=${JSON.stringify(plain.slice(0, 90))}`,
    );
  } else if (verbose) {
    console.log(`OK     id=${item.id}  ${JSON.stringify(plain.slice(0, 60))}`);
  }
}

console.log(
  `\n=== angol válaszok: ${items.length}, magyar maradvány: ${hungarian}, ` +
    `HTML-t tartalmaz: ${tagged}`,
);
process.exitCode = hungarian === 0 ? 0 : 1;
