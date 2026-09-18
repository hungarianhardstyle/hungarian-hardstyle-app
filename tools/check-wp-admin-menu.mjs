#!/usr/bin/env node
/**
 * A WordPress admin „HUHS Mobile" almenujenek ellenorzese.
 *
 * A TULAJDONOS JELZESE: „meg apiban tedd rendbe a menüpontokat, elég
 * összevisszaság lett most, about legalul legyen a többi meg értelem szerűen
 * egymáshoz viszonyítva jó helyen".
 *
 * A hiba gyokere az volt, hogy a `admin.php` vegen levo rendezes listaja
 * elavult: a kesobb hozzaadott modulok (`huhs-poll-results`, `huhs-prize`,
 * `huhs-newsletter`) benne sem voltak, ezert a sajat bejegyzes-sorukkal egyutt a
 * lista VEGERE kerultek — a Lomtár es az About tarsasagaban.
 *
 * Ez a szkript ezt a hibaosztalyt fogja el: minden regisztralt almenut
 * osszegyujt a plugin forrasabol, es megkoveteli, hogy a rendezesi csoportokban
 * szerepeljen. Ha valaki uj modult tesz be es elfelejti a listaba felvenni, az
 * itt azonnal kiderul.
 *
 * Futtatas (a repository gyokerebol):
 *   node tools/check-wp-admin-menu.mjs [plugin-mappa]
 */

import fs from 'node:fs';
import path from 'node:path';

const pluginDir = process.argv[2] || '.tmp-api-24115/huhs-mobile-api';
const includesDir = path.join(pluginDir, 'includes');
const adminFile = path.join(includesDir, 'admin.php');

const results = [];
let checked = 0;
let failed = 0;

function check(label, ok, detail) {
  checked += 1;
  if (ok) results.push(`OK    ${label}`);
  else {
    failed += 1;
    results.push(`HIBA  ${label}${detail ? ` — ${detail}` : ''}`);
  }
}

if (!fs.existsSync(adminFile)) {
  console.error(`Nincs meg: ${adminFile}`);
  process.exit(2);
}

const files = fs
  .readdirSync(includesDir)
  .filter((name) => name.endsWith('.php'))
  .map((name) => path.join(includesDir, name));

/* --- 1. Minden regisztralt almenu slug -------------------------------- */

/**
 * A `add_submenu_page(...)` negyedik (slug) argumentuma.
 *
 * Sztring-szintu szkennelest hasznalunk, mert a slug allhat tobb sorba tordelt
 * konkatenaciobol is. A zarojel-parositas a HIVAS sajat nyito zarojelebol indul
 * (nem a `function ()` zarojelebol), kulonben a belso closure zarojelere
 * illeszkedne — ez volt az elso valtozat hibaja.
 */
function submenuSlugs(source) {
  const found = [];
  const marker = 'add_submenu_page(';
  let index = source.indexOf(marker);
  while (index >= 0) {
    const open = index + marker.length - 1;
    let depth = 0;
    let end = -1;
    let inString = null;
    for (let i = open; i < source.length; i += 1) {
      const char = source[i];
      if (inString) {
        if (char === '\\') i += 1;
        else if (char === inString) inString = null;
        continue;
      }
      if (char === "'" || char === '"') {
        inString = char;
        continue;
      }
      if (char === '(') depth += 1;
      else if (char === ')') {
        depth -= 1;
        if (depth === 0) {
          end = i;
          break;
        }
      }
    }
    if (end > open) {
      const args = source.slice(open + 1, end);
      // Vesszokre bontas CSAK a legkulso szinten, es a stringeket kihagyva.
      const parts = [];
      let current = '';
      let level = 0;
      let quote = null;
      for (const char of args) {
        if (quote) {
          current += char;
          if (char === quote) quote = null;
          continue;
        }
        if (char === "'" || char === '"') {
          quote = char;
          current += char;
          continue;
        }
        if (char === '(' || char === '[' || char === '{') level += 1;
        if (char === ')' || char === ']' || char === '}') level -= 1;
        if (char === ',' && level === 0) {
          parts.push(current.trim());
          current = '';
          continue;
        }
        current += char;
      }
      if (current.trim()) parts.push(current.trim());
      // Az `add_submenu_page()` parameterei:
      //   0: szulo slug, 1: oldal cim, 2: menu cim, 3: jogosultsag, 4: SAJAT slug
      // Ezert a SAJAT slug az otodik (index 4) — az elso a `'huhs-mobile'`.
      const slugArg = parts[4] || '';
      const literals = [...slugArg.matchAll(/'([^']*)'|"([^"]*)"/g)].map(
        (match) => match[1] ?? match[2] ?? '',
      );
      const slug = literals.join('');
      // A `manage_options`/`edit_posts` típusú jogosultsag-sztringek kizarasa.
      // Ezek soha nem tartalmaznak kotojelet vagy kerdojelet, viszont a
      // `huhs-mobile`/`huhs-about` tipusu valodi slugok sem — ezert a
      // jogosultsag-neveket NEV SZERINT soroljuk fel.
      const capabilities = new Set([
        'manage_options',
        'edit_posts',
        'edit_pages',
        'read',
        'publish_posts',
        'upload_files',
        'list_users',
        'manage_categories',
        'moderate_comments',
        'unfiltered_html',
        'edit_theme_options',
      ]);
      if (slug && !capabilities.has(slug)) found.push(slug);
    }
    index = source.indexOf(marker, index + marker.length);
  }
  return found;
}

const registered = new Set();
for (const file of files) {
  const source = fs.readFileSync(file, 'utf8');
  for (const slug of submenuSlugs(source)) registered.add(slug);
}
// A sajat bejegyzes-tipusok szerkeszto-sorat a `show_in_menu => 'huhs-mobile'`
// regisztracio hozza letre, `edit.php?post_type=<tipus>` sluggal.
//
// FONTOS: a `register_post_type(...)` hivasokat EGYENKENT kell nezni, mert egy
// fajlban tobb is lehet, es csak azt kell beszurni, amelyiknek a
// `show_in_menu` erteke `'huhs-mobile'` (a `huhs_vote_candidate` peldaul `false`).
for (const file of files) {
  const source = fs.readFileSync(file, 'utf8');
  const calls = [...source.matchAll(/register_post_type\(\s*'([a-z0-9_]+)'/g)];
  for (let index = 0; index < calls.length; index += 1) {
    const start = calls[index].index;
    const stop = index + 1 < calls.length ? calls[index + 1].index : source.length;
    const body = source.slice(start, stop);
    if (/show_in_menu'\s*=>\s*'huhs-mobile'/.test(body)) {
      registered.add(`edit.php?post_type=${calls[index][1]}`);
    }
  }
}

check(
  'talalhatok regisztralt almenu (a szkennelés nem üres)',
  registered.size > 5,
  `talalt: ${registered.size}`,
);

/* --- 2. A rendezesi csoportok ----------------------------------------- */

const adminSource = fs.readFileSync(adminFile, 'utf8');
const groupsStart = adminSource.indexOf('$groups = array(');
const groupsEnd = adminSource.indexOf('$items = $GLOBALS', groupsStart);
check('megvan a tematikus $groups lista', groupsStart > 0 && groupsEnd > groupsStart);

const groupsSource =
  groupsStart > 0 && groupsEnd > groupsStart
    ? adminSource.slice(groupsStart, groupsEnd)
    : '';
const ordered = [...groupsSource.matchAll(/'([a-z0-9_?=&.\-]+)'/g)].map((m) => m[1]);
const orderedSet = new Set(ordered);

/* --- 3. Minden regisztralt sor szerepel a listaban -------------------- */

const missing = [...registered].filter((slug) => !orderedSet.has(slug)).sort();
check(
  'minden regisztralt almenu szerepel a tematikus sorrendben',
  missing.length === 0,
  missing.length ? `hianyzik: ${missing.join(', ')}` : undefined,
);

/* --- 4. Az „About" az utolso tematikus csoport ------------------------ */

const aboutIndex = groupsSource.indexOf("'huhs-about'");
check('az About benne van a sorrendben', aboutIndex > 0);
check(
  'az About az UTOLSO tematikus csoportban van',
  // Az About utan csak a csoport lezaro sorai jonnek, ujabb slug nem.
  aboutIndex > 0 && !/'[a-z0-9_?=&.\-]+'/.test(groupsSource.slice(aboutIndex + "'huhs-about'".length)),
  'a tulajdonos keresere az About legalul van',
);

/* --- 5. A tematikus csoportok ertelmes sorrendje ---------------------- */

/**
 * A csoportok sorrendje a listaban valo elso elofordulasuk szerint.
 *
 * Ez rogziti, hogy a tematikus blokkok ne keveredjenek: a Dashboard elol, a
 * tartalom egymas mellett, az interakcio (kerdőív/nyeremenyjatek/szavazas)
 * egyutt, a kommunikacio (push/hirlevel) egymas utan, az About pedig legalul.
 */
const groupOrder = [];
{
  const blocks = groupsSource.split('array(').slice(1);
  for (const block of blocks) {
    const slugs = [...block.matchAll(/'([a-z0-9_?=&.\-]+)'/g)].map((m) => m[1]);
    if (slugs.length) groupOrder.push(slugs[0]);
  }
}
const expectedHead = [
  'huhs-mobile',
  'edit.php?post_type=huhs_artist',
  'edit.php?post_type=huhs_poll',
  'huhs-game-results',
  'huhs-push',
  'huhs-radio',
  'huhs-shortcodes',
  'huhs-about',
];
check(
  'a tematikus blokkok sorrendje a vart (Dashboard, Tartalom, Interakció, Közösség, Kommunikáció, Beállítások, Rendszer, About)',
  JSON.stringify(groupOrder) === JSON.stringify(expectedHead),
  `talalt: ${groupOrder.join(' | ')}`,
);

/* --- 6. Az idohoz kotott modulok nincsenek a vegén -------------------- */

const tailSlugs = ordered.slice(-6);
check(
  'a kerdőív/nyeremenyjatek/szavazas NEM a lista vegen van',
  !tailSlugs.some((slug) =>
    ['edit.php?post_type=huhs_poll', 'edit.php?post_type=huhs_prize', 'edit.php?post_type=huhs_vote_season'].includes(slug),
  ),
  `a lista vege: ${tailSlugs.join(', ')}`,
);

/* --- 7. Nincs elvalaszto-sor (kattintható lenne) ---------------------- */

check(
  'nincs „huhs-separator" sor (az kattintható, rossz oldalra vinne)',
  !adminSource.includes('huhs-separator'),
);

console.log(results.join('\n'));
console.log(`\n${checked - failed}/${checked} ellenorzes rendben`);
process.exit(failed === 0 ? 0 : 1);
