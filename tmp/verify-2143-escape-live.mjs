#!/usr/bin/env node
/**
 * ÉLES mérés: a 2.14.3 escape-javítása és az újragenerált fordítások.
 *
 * A hiba (mért): a WordPress `update_metadata()` unslash-e miatt a
 * `wp_json_encode()` escape-jeiből elveszett a backslash, ezért a nyeremény
 * leírásában `rn` jelent meg új sor helyett, az ékezetek pedig `u00e9` alakban
 * (`Béla` → `Bu00e9la`, `—` → `u2014`). A javítás: `wp_slash()` az íráskor +
 * séma-verzió (2), ezért a tárolt, hibás fordítások a pótló körben újra
 * elkészülnek.
 *
 * Ez a szonda a NYILVÁNOS végpontokat méri (az app ugyanezt látja):
 *   - nincs `rn`/`uXXXX` törmelék,
 *   - a magyar ág változatlanul valódi ékezeteket ad,
 *   - a fordítások megvannak.
 *
 * Csak olvas. Használat: node tmp/verify-2143-escape-live.mjs
 */
import process from 'node:process';

const BASE = 'https://hungarianhardstyle.hu/wp-json/huhs/v1';

let passed = 0;
let failed = 0;

function check(label, condition, detail = '') {
  if (condition) {
    passed += 1;
    console.log(`  OK   ${label}`);
  } else {
    failed += 1;
    console.log(`  HIBA ${label}${detail ? ` — ${detail}` : ''}`);
  }
}

async function get(path) {
  const response = await fetch(`${BASE}${path}`, {
    headers: { accept: 'application/json' },
  });
  const text = await response.text();
  let json = null;
  try {
    json = JSON.parse(text);
  } catch {
    json = null;
  }
  return { status: response.status, text, json };
}

/** Escape-törmelék keresése a NYERS válaszban (a JSON escape-elt formájában). */
function debris(text) {
  const hits = [];
  // ⚠️ MÉRT TANULSÁG (2026-09-26): a naiv `rn` keresés HAMIS POZITÍV, mert a
  // valódi angol szavakban is van `rn` (`retu`**`rn`**`, ea`**`rn`**`,
  // inte`**`rn`**`ational`). Csak a BIZONYÍTOTT törmelék számít: az `rn`
  // **önálló token** (előtte ÉS utána nem betű), vagy `rnrn`.
  const newlineNoise = text.match(/(?<![A-Za-z])rn(?![A-Za-z])|rnrn/g);
  if (newlineNoise) hits.push(`rn×${newlineNoise.length}`);
  // `\u00e9` helyett `u00e9` (a backslash elveszett) — ez egyértelmű.
  const unicodeNoise = text.match(/[^\\]u00[0-9a-f]{2}/gi);
  if (unicodeNoise) hits.push(`u00xx×${unicodeNoise.length}`);
  const dashNoise = text.match(/[^\\]u201[0-9a-f]/gi);
  if (dashNoise) hits.push(`u201x×${dashNoise.length}`);
  return hits;
}

function collectStrings(value, path = '', out = []) {
  if (typeof value === 'string') {
    out.push([path, value]);
  } else if (Array.isArray(value)) {
    value.forEach((item, index) => collectStrings(item, `${path}[${index}]`, out));
  } else if (value && typeof value === 'object') {
    for (const [key, item] of Object.entries(value)) {
      collectStrings(item, path ? `${path}.${key}` : key, out);
    }
  }
  return out;
}

console.log('=== a 2.14.3 escape-javítása ÉLESBEN (nyilvános végpontok)');
console.log(`idő: ${new Date().toISOString()}\n`);

// 1) A nyereményjáték: itt volt a leglátványosabb a hiba (`rnrn`, `u00e9`).
const prizeEn = await get('/prize/active?lang=en');
const prizeHu = await get('/prize/active?lang=hu');
console.log(`-- /prize/active (en: ${prizeEn.status}, hu: ${prizeHu.status})`);
if (prizeEn.status !== 200 || !prizeEn.json) {
  check('a nyitott nyeremény angol válasza elérhető', false, `státusz ${prizeEn.status}`);
} else {
  const payload = prizeEn.json.prize ?? prizeEn.json;
  const description = String(payload.prize_description ?? '');
  const question = String(payload.question ?? '');
  const answers = (payload.answers ?? []).map((item) => String(item.label ?? ''));

  check(
    'az angol leírásban nincs escape-törmelék (`rn`, `u00xx`, `u201x`)',
    debris(prizeEn.text).length === 0,
    debris(prizeEn.text).join(', '),
  );
  check(
    'az angol leírásban VALÓDI sortörés van (nem `rn`)',
    description.includes('\n') || !description.includes('rn'),
    JSON.stringify(description.slice(0, 120)),
  );
  check(
    'az angol leírás ékezete valódi karakter (nincs `u00e9`)',
    !/u00[0-9a-f]{2}/i.test(description),
    JSON.stringify(description.slice(0, 120)),
  );
  check(
    'a nyeremény szövegei megvannak angolul',
    question.trim().length > 0 && answers.length > 0 && description.trim().length > 0,
    `kérdés="${question}" válaszok=${answers.length}`,
  );
  console.log(`     leírás: ${JSON.stringify(description.slice(0, 140))}`);
  console.log(`     kérdés: ${JSON.stringify(question)}`);
  console.log(`     válaszok: ${JSON.stringify(answers)}`);

  if (prizeHu.json) {
    const huPayload = prizeHu.json.prize ?? prizeHu.json;
    const huDescription = String(huPayload.prize_description ?? '');
    check(
      'a magyar leírás változatlanul valódi ékezetes és sortöréses',
      !/u00[0-9a-f]{2}/i.test(huDescription) && !/rn/.test(huDescription),
      JSON.stringify(huDescription.slice(0, 120)),
    );
    check(
      'a magyar és az angol leírás tényleg különbözik',
      huDescription.trim() !== description.trim(),
    );
  }
}

// 2) A kérdőív: a válaszcímkék ékezetei.
const pollEn = await get('/poll/active?lang=en');
const pollHu = await get('/poll/active?lang=hu');
console.log(`\n-- /poll/active (en: ${pollEn.status}, hu: ${pollHu.status})`);
if (pollEn.status === 200 && pollEn.json) {
  const payload = pollEn.json.poll ?? pollEn.json;
  const options = (payload.options ?? []).map((item) => String(item.label ?? ''));
  check(
    'a kérdőív angol válaszaiban nincs escape-törmelék',
    debris(pollEn.text).length === 0,
    debris(pollEn.text).join(', '),
  );
  check(
    'a kérdőív kérdése és válaszai megvannak angolul',
    String(payload.question ?? '').trim().length > 0 && options.length > 0,
    JSON.stringify(options),
  );
  console.log(`     kérdés: ${JSON.stringify(payload.question ?? '')}`);
  console.log(`     válaszok: ${JSON.stringify(options)}`);
}

// 3) A kvíz: a 2.14.2-ben itt is roncsolódott a válasz (`Bu00e9la`).
const games = await get('/games?per_page=5');
const gameId = Array.isArray(games.json) && games.json.length > 0 ? games.json[0].id : null;
if (gameId) {
  const gameEn = await get(`/games/${gameId}?lang=en`);
  const gameHu = await get(`/games/${gameId}?lang=hu`);
  console.log(`\n-- /games/${gameId} (en: ${gameEn.status}, hu: ${gameHu.status})`);
  const questionsEn = gameEn.json?.questions ?? [];
  const prompts = questionsEn.map((item) => String(item.prompt ?? ''));
  const options = questionsEn.flatMap((item) =>
    (item.options ?? []).map((option) => String(option)),
  );
  check(
    'a kvíz angol kérdéseiben/válaszaiban nincs escape-törmelék',
    debris(gameEn.text).length === 0,
    debris(gameEn.text).join(', '),
  );
  check(
    'a kvíz angolul megy (kérdések + válaszok megvannak)',
    prompts.length > 0 && options.length > 0,
    `kérdések=${prompts.length}`,
  );
  check(
    'a helyes válasz nem szivárog a nyilvános payloadba',
    !gameEn.text.includes('"correct"'),
  );
  if (prompts.length > 0) {
    console.log(`     első kérdés: ${JSON.stringify(prompts[0])}`);
    console.log(`     első válaszok: ${JSON.stringify(options.slice(0, 4))}`);
  }
  if (gameHu.status === 200 && gameHu.json) {
    const huPrompts = (gameHu.json.questions ?? []).map((item) => String(item.prompt ?? ''));
    check(
      'a magyar kvíz változatlan (a magyar ág nem kapott angolt)',
      huPrompts.length > 0 && huPrompts.join('|') !== prompts.join('|'),
    );
    if (huPrompts.length > 0) {
      console.log(`     magyar első kérdés: ${JSON.stringify(huPrompts[0])}`);
    }
  }
} else {
  console.log('\n-- /games: nincs listázható játék, a kvíz-mérés kimarad');
}

// 4) A GYÍK: a 2.14.0-ban itt is keletkezhetett törmelék.
const faqEn = await get('/faq?lang=en');
console.log(`\n-- /faq (en: ${faqEn.status})`);
if (faqEn.status === 200) {
  check(
    'a GYÍK angol válaszában nincs escape-törmelék',
    debris(faqEn.text).length === 0,
    debris(faqEn.text).join(', '),
  );
  const items = Array.isArray(faqEn.json) ? faqEn.json : (faqEn.json?.items ?? []);
  const english = items.filter((item) =>
    /[A-Za-z]/.test(String(item.question ?? '')) &&
    !/[áéíóöőúüű]/i.test(String(item.question ?? '')),
  );
  check(
    'a GYÍK nagy része angolul van',
    items.length === 0 || english.length >= Math.ceil(items.length * 0.8),
    `${english.length}/${items.length}`,
  );
  if (items.length > 0) {
    console.log(`     első kérdés: ${JSON.stringify(items[0].question ?? '')}`);
  }
}

console.log(`\n=== ÖSSZESÍTÉS: ${passed} rendben, ${failed} hiba`);
process.exitCode = failed === 0 ? 0 : 1;
