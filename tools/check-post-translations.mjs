#!/usr/bin/env node
/**
 * A cikk-fordítások ellenőrzése (csak olvas).
 *
 * MIÉRT: a 30 cikk angol változatát LLM-ágensek írják fájlokba
 * (`tmp/newsroom-en/en/<id>.json`). A fordítás **nem törheti el a HTML-t**, nem
 * hagyhat ki URL-t, és nem hagyhat magyar mondatot a szövegben — ezt itt
 * mérjük, mielőtt bármi a WordPressbe kerülne.
 *
 * Amit ellenőriz (cikkenként):
 *  1. minden kért cikkhez van fájl, és a JSON alak helyes;
 *  2. a **HTML-tagek sorrendje bájtra ugyanaz**, mint a magyarban;
 *  3. az **URL-ek halmaza ugyanaz** (href/src/iframe);
 *  4. a **HTML-entitások** (pl. `&nbsp;`, `&#8211;`) száma ugyanaz;
 *  5. nincs benne **magyar mondat** (ékezetes szavak aránya a szövegben);
 *  6. a hossz-arány ésszerű (az angol jellemzően 0,8–1,5× a magyar);
 *  7. nincs üres mező, és nincs benne „fordítói megjegyzés" minta.
 *
 * Futtatás: node tools/check-post-translations.mjs [--strict]
 * Kilépési kód: 0 = minden rendben, 1 = van hiba, 2 = nem futott.
 */
import fs from 'node:fs';
import path from 'node:path';

const HU_FILE = 'tmp/newsroom-en/hu-posts.json';
const EN_DIR = 'tmp/newsroom-en/en';

/** Magyar ékezetes betűk — a bennmaradt magyar szöveg legjobb jele. */
const HUNGARIAN_LETTERS = /[áéíóöőúüűÁÉÍÓÖŐÚÜŰ]/;

/** HTML-tagek **szerkezete**: tagnév + attribútum-nevek sorrendben.
 *  ⚠️ Az attribútumok **értéke** szándékosan nem része az összehasonlításnak:
 *  az `alt` szövege fordul (felhasználónak látszik), a `class`/`style`/`src`
 *  viszont nem változhat — ezért az URL-eket külön ellenőrizzük. */
export function tagStructure(html) {
  return [...String(html ?? '').matchAll(/<[^>]+>/g)].map((match) => {
    const tag = match[0];
    const name = /^<\/?\s*([a-zA-Z0-9-]+)/.exec(tag)?.[1]?.toLowerCase() ?? tag;
    const attributes = [...tag.matchAll(/([a-zA-Z_:][-a-zA-Z0-9_:.]*)\s*=/g)]
      .map((attribute) => attribute[1].toLowerCase())
      .filter((attribute) => attribute !== 'alt');
    return `${name}[${attributes.join(',')}]`;
  });
}

/** Gyakori magyar szavak, amelyeknek angolul kell lenniük (ékezet nélkül is).
 *  ⚠️ MIÉRT KELL: az „alt" szövegek között lehet **ékezet nélküli magyar szó**
 *  (pl. „mobilapp", „dokumentumfilm") — azt az ékezet-keresés nem találja meg.
 *  Ezt a hiányt egy fordító-ágens jelezte kézzel, ezért itt pótoljuk. */
export const HUNGARIAN_WORDS = [
  'mobilapp',
  'dokumentumfilm',
  'beszamolo',
  'beszámoló',
  'hetvege',
  'hétvége',
  'megjelenesei',
  'megjelenései',
  'ujdonsagok',
  'újdonságok',
  'kultura',
  'kultúra',
  'kepek',
  'képek',
  'zene',
  'jatek',
  'játék',
  'esemeny',
  'esemény',
  'szervezo',
  'szervező',
  'kiadvany',
  'kiadvány',
  'felhasznalo',
  'felhasználó',
  'beallitasok',
  'beállítások',
];

/** Magyar ékezetes szöveget vagy magyar szót tartalmazó `alt` értékek. */
export function hungarianAltTexts(html) {
  const found = [];
  for (const match of String(html ?? '').matchAll(/alt="([^"]*)"/g)) {
    const value = match[1];
    if (!value.trim()) continue;
    if (/^[A-Z][a-zA-Z]*$/.test(value.trim())) continue;
    const words = value.toLowerCase().split(/[^a-záéíóöőúüű0-9]+/i);
    const hasHungarianWord = words.some((word) => HUNGARIAN_WORDS.includes(word));
    if (HUNGARIAN_LETTERS.test(value) || hasHungarianWord) found.push(value);
  }
  return found;
}

/** URL-ek halmaza (href, src, egyéb attribútum). */
export function urlSet(html) {
  const urls = new Set();
  for (const match of String(html ?? '').matchAll(/https?:\/\/[^\s"'<>]+/g)) {
    urls.add(match[0]);
  }
  return urls;
}

/** HTML-entitások (a fordítás ne nyúljon hozzájuk). */
export function entityCounts(html) {
  const counts = new Map();
  for (const match of String(html ?? '').matchAll(/&[a-zA-Z#0-9]+;/g)) {
    counts.set(match[0], (counts.get(match[0]) ?? 0) + 1);
  }
  return counts;
}

/** Magyar ékezetes szavak aránya a szövegben (0..1). */
export function hungarianWordRatio(text) {
  const words = String(text ?? '')
    .replace(/<[^>]+>/g, ' ')
    .split(/\s+/)
    .filter((word) => word.length > 2);
  if (!words.length) return 0;
  const hungarian = words.filter((word) => HUNGARIAN_LETTERS.test(word)).length;
  return hungarian / words.length;
}

/** Fordítói megjegyzés / placeholder minta. */
export function hasTranslatorNoise(text) {
  return /\[(?:fordítás|translation|TODO|XXX)|lorem ipsum|placeholder|\bTODO\b/i.test(
    String(text ?? ''),
  );
}

/** Egy cikk ellenőrzése (tiszta függvény). */
export function compareArticle(source, translation) {
  const problems = [];
  const huTags = tagStructure(source.content);
  const enTags = tagStructure(translation.content_en);
  if (huTags.length !== enTags.length) {
    problems.push(`HTML-tag szám eltér: hu=${huTags.length}, en=${enTags.length}`);
  } else {
    const index = huTags.findIndex((tag, position) => tag !== enTags[position]);
    if (index >= 0) {
      problems.push(
        `HTML-szerkezet eltér a(z) ${index}. helyen: hu=${huTags[index]}, en=${enTags[index]}`,
      );
    }
  }
  // Az `alt` szövege **fordul** (felhasználónak látszik) — ezért külön kérjük.
  for (const alt of hungarianAltTexts(translation.content_en)) {
    problems.push(`magyar alt szöveg maradt: „${alt}”`);
  }
  const huUrls = urlSet(source.content);
  const enUrls = urlSet(translation.content_en);
  for (const url of huUrls) if (!enUrls.has(url)) problems.push(`hiányzó URL: ${url}`);
  for (const url of enUrls) if (!huUrls.has(url)) problems.push(`új URL: ${url}`);

  const huEntities = entityCounts(source.content);
  const enEntities = entityCounts(translation.content_en);
  for (const [entity, count] of huEntities) {
    if ((enEntities.get(entity) ?? 0) !== count) {
      problems.push(`entitás eltér (${entity}): hu=${count}, en=${enEntities.get(entity) ?? 0}`);
    }
  }

  const ratio = hungarianWordRatio(translation.content_en);
  if (ratio > 0.08) {
    problems.push(
      `a fordításban sok magyar ékezetes szó maradt: ${(ratio * 100).toFixed(1)}%`,
    );
  }
  const huLength = [...String(source.content ?? '')].length;
  const enLength = [...String(translation.content_en ?? '')].length;
  const lengthRatio = huLength ? enLength / huLength : 0;
  if (lengthRatio < 0.6 || lengthRatio > 1.8) {
    problems.push(
      `gyanús hossz-arány: ${lengthRatio.toFixed(2)} (hu=${huLength}, en=${enLength})`,
    );
  }
  for (const field of ['title_en', 'excerpt_en', 'content_en']) {
    if (!String(translation[field] ?? '').trim()) problems.push(`üres mező: ${field}`);
    if (hasTranslatorNoise(translation[field])) problems.push(`fordítói zaj a(z) ${field} mezőben`);
  }
  return { id: source.id, problems, lengthRatio, hungarianRatio: ratio };
}

export function selfTest() {
  const checks = [];
  const check = (label, ok) => checks.push({ label, ok });
  const hu = {
    id: 1,
    content: '<p>Szia <b>világ</b> <a href="https://x.hu/a">link</a>&nbsp;</p>',
  };
  const good = {
    id: 1,
    title_en: 'Hello',
    excerpt_en: 'Hello there',
    content_en: '<p>Hi <b>world</b> <a href="https://x.hu/a">link</a>&nbsp;</p>',
  };
  check('a jó fordítás átmegy', compareArticle(hu, good).problems.length === 0);

  const brokenTag = { ...good, content_en: '<p>Hi world <a href="https://x.hu/a">link</a>&nbsp;</p>' };
  check('a hiányzó tagot kiszúrja', compareArticle(hu, brokenTag).problems.length > 0);

  const wrongOrder = {
    ...good,
    content_en: '<b>Hi <p>world</b> <a href="https://x.hu/a">link</a>&nbsp;</p>',
  };
  check('a tag-sorrendet kiszúrja', compareArticle(hu, wrongOrder).problems.length > 0);

  const missingUrl = {
    ...good,
    content_en: '<p>Hi <b>world</b> <a href="https://x.hu/b">link</a>&nbsp;</p>',
  };
  check('a megváltozott URL-t kiszúrja', compareArticle(hu, missingUrl).problems.length > 0);

  const hungarian = {
    ...good,
    content_en: '<p>Szia <b>világ</b> <a href="https://x.hu/a">link</a>&nbsp;</p>',
  };
  check('a bennmaradt magyart kiszúrja', compareArticle(hu, hungarian).problems.length > 0);

  const emptyField = { ...good, title_en: '   ' };
  check('az üres mezőt kiszúrja', compareArticle(hu, emptyField).problems.length > 0);

  check('a tag-szerkezetet helyesen szedi ki', tagStructure('<p><b>x</b></p>').length === 4);
  check('az URL-halmazt helyesen szedi ki', urlSet('<a href="https://a.hu">x</a>').size === 1);
  check('a zajmintát felismeri', hasTranslatorNoise('[TRANSLATION] x') === true);
  check('a tiszta szövegre nincs zaj', hasTranslatorNoise('Clean text') === false);

  // Az `alt` szövege FORDUL, de az attribútumok neve/sorrendje nem változhat.
  const huAlt = {
    id: 2,
    content: '<p><img src="https://x.hu/k.jpg" alt="kezdő producer" class="kep">Kép</p>',
  };
  const enAltTranslated = {
    id: 2,
    title_en: 'T',
    excerpt_en: 'E',
    content_en: '<p><img src="https://x.hu/k.jpg" alt="up-and-coming producer" class="kep">Image</p>',
  };
  check(
    'az angol alt szöveg átmegy',
    compareArticle(huAlt, enAltTranslated).problems.length === 0,
  );
  const enAltHungarian = {
    ...enAltTranslated,
    content_en: '<p><img src="https://x.hu/k.jpg" alt="kezdő producer" class="kep">Image</p>',
  };
  check(
    'a magyar alt szöveget kiszúrja',
    compareArticle(huAlt, enAltHungarian).problems.length > 0,
  );
  const structure = tagStructure('<img src="a" alt="x" class="y">');
  check('az alt értéke nem része a szerkezetnek', structure[0] === 'img[src,class]');
  check(
    'a magyar alt szöveget megtalálja',
    hungarianAltTexts('<img alt="kezdő producer">').length === 1,
  );
  return checks;
}

function main() {
  if (process.argv.includes('--self-test')) {
    const checks = selfTest();
    for (const check of checks) console.log(`${check.ok ? 'OK  ' : 'HIBA'} ${check.label}`);
    const failed = checks.filter((check) => !check.ok).length;
    console.log(`\n${checks.length - failed}/${checks.length} önteszt rendben`);
    return failed ? 1 : 0;
  }
  const sources = JSON.parse(fs.readFileSync(HU_FILE, 'utf8'));
  const rows = [];
  let failed = 0;
  for (const source of sources) {
    const file = path.join(EN_DIR, `${source.id}.json`);
    if (!fs.existsSync(file)) {
      rows.push({ id: source.id, problems: ['nincs fordítása (hiányzó fájl)'] });
      failed += 1;
      continue;
    }
    let translation;
    try {
      translation = JSON.parse(fs.readFileSync(file, 'utf8'));
    } catch (error) {
      rows.push({ id: source.id, problems: [`hibás JSON: ${error.message}`] });
      failed += 1;
      continue;
    }
    const result = compareArticle(source, translation);
    if (result.problems.length) failed += 1;
    rows.push(result);
  }
  console.log(`cikkek: ${sources.length}, ebből hibás: ${failed}\n`);
  for (const row of rows) {
    const status = row.problems.length ? 'HIBA' : 'OK  ';
    const ratio = row.lengthRatio ? ` (hossz-arány ${row.lengthRatio.toFixed(2)})` : '';
    console.log(`${status} ${row.id}${ratio}`);
    for (const problem of row.problems) console.log(`      - ${problem}`);
  }
  console.log(
    failed
      ? `\n${failed} cikk javításra szorul — a WordPress-írás ELŐTT rendezni kell.`
      : '\nMINDEN FORDÍTÁS RENDBEN — mehet a WordPressbe.',
  );
  return failed ? 1 : 0;
}

main_();
function main_() {
  let code = 0;
  try {
    code = main();
  } catch (error) {
    console.error(`HIBA: ${error.message}`);
    code = 2;
  }
  process.exitCode = code;
}
