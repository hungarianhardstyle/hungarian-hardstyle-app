#!/usr/bin/env node
/**
 * A tartalom-fordítások **kapuja**: lefedettség, üres érték, HTML-szerkezet,
 * magyarul maradt szöveg.
 *
 * MIÉRT: a fordítás chunkokban, ágensekkel készül, és a tartalom **HTML** — a
 * legkönnyebben ott csúszik el a dolog, hogy egy tag vagy attribútum eltűnik,
 * vagy a magyar szöveg benne marad. A `tagSequence()` a tagek **sorrendjét**
 * hasonlítja (a nyitó/záró jelekkel együtt), ezért a szerkezet-hibát megfogja.
 *
 * Használat:
 *   node tools/check-content-translations.mjs            # jelentés
 *   node tools/check-content-translations.mjs --strict    # hibakód, ha baj van
 *   node tools/check-content-translations.mjs --self-test
 */
import fs from 'node:fs';
import path from 'node:path';

export const SOURCE_PATH = 'tmp/content-en/source.json';
export const EN_DIR = 'tmp/content-en/en';

export const HUNGARIAN_ACCENTS = /[áéíóöőúüűÁÉÍÓÖŐÚÜŰ]/;

/**
 * Márkanevek és **tulajdonnevek**: ezekben legális a magyar ékezet az angol
 * szövegben. ⚠️ Ez a lista a **jelzést** szűri, nem bizonyíték: ha egy név
 * hiányzik innen, a kapu jelez — ilyenkor azt kell eldönteni, hogy valóban név-e
 * (akkor ide kerül), vagy fordítatlan magyar szöveg (akkor javítani kell).
 */
export const BRAND_ALLOWLIST = [
  // márkák, szervezők
  'Hungarian Hardstyle', 'HUHS', 'Pannon', 'Pannónia', 'Hardstyle',
  // helyszínek (a DJ-bemutatókban szerepelnek)
  'Akvárium', 'Arzenál', 'Víztorony', 'Nagyerdei', 'Hajó', 'Bálna', 'Dürer',
  'Balaton', 'Sziget', 'Budapest', 'SiMa', 'Café',
  // városok, személynevek
  'Siófok', 'Balázs', 'Dániel', 'Bence', 'Máté', 'Gábor', 'Zoltán', 'Attila',
];

/** A HTML-tagek sorrendje (a nyitó/záró jelekkel) — a szerkezet ujjlenyomata. */
export function tagSequence(html) {
  return String(html ?? '').match(/<\/?[a-zA-Z][^>]*>/g) ?? [];
}

export function withoutBrands(text) {
  let result = String(text ?? '');
  for (const brand of BRAND_ALLOWLIST) result = result.split(brand).join(' ');
  return result;
}

/** Magyarul maradt szöveg jele (ékezetes szó) a fordításban. */
export function hungarianSignals(value) {
  const text = withoutBrands(String(value ?? '').replace(/<[^>]*>/g, ' '));
  const words = [
    ...new Set(
      (text.match(/[A-Za-zÁÉÍÓÖŐÚÜŰáéíóöőúüű]{3,}/g) ?? []).filter((word) => HUNGARIAN_ACCENTS.test(word)),
    ),
  ];
  return words.length ? [`ékezetes szó: ${words.slice(0, 6).join(', ')}`] : [];
}

/** A fordítás-jegyzékek beolvasása (`"<típus>-<id>"` kulcsokkal). */
export function readTranslations(dir = EN_DIR) {
  if (!fs.existsSync(dir)) return {};
  const merged = {};
  for (const name of fs.readdirSync(dir).filter((file) => /^chunk-.*\.json$/.test(file)).sort()) {
    Object.assign(merged, JSON.parse(fs.readFileSync(path.join(dir, name), 'utf8')));
  }
  return merged;
}

/** A teljes ellenőrzés. */
export function checkTranslations({ source = [], translations = {} } = {}) {
  const problems = [];
  let covered = 0;
  for (const entry of source) {
    const key = `${entry.type}-${entry.id}`;
    const translation = translations[key];
    if (!translation) {
      problems.push({ type: 'hianyzo', key });
      continue;
    }
    covered += 1;
    const title = String(translation.title ?? '');
    const content = String(translation.content ?? '');
    if (!title.trim()) problems.push({ type: 'ures-cim', key });
    if (!content.trim()) problems.push({ type: 'ures-tartalom', key });
    const sourceTags = tagSequence(entry.content);
    const targetTags = tagSequence(content);
    if (sourceTags.join('|') !== targetTags.join('|')) {
      problems.push({
        type: 'szerkezet',
        key,
        detail: `forrás ${sourceTags.length} tag, fordítás ${targetTags.length} tag`,
      });
    }
    const signals = hungarianSignals(title) .concat(hungarianSignals(content));
    if (signals.length) {
      problems.push({ type: 'magyar', key, detail: `${title} (${[...new Set(signals)].join('; ')})` });
    }
  }
  const extra = Object.keys(translations).filter(
    (key) => !source.some((entry) => `${entry.type}-${entry.id}` === key),
  );
  return {
    problems,
    stats: {
      source: source.length,
      covered,
      missing: problems.filter((problem) => problem.type === 'hianyzo').length,
      empty: problems.filter((problem) => problem.type.startsWith('ures')).length,
      structure: problems.filter((problem) => problem.type === 'szerkezet').length,
      hungarian: problems.filter((problem) => problem.type === 'magyar').length,
      extra: extra.length,
      extraKeys: extra,
    },
  };
}

export function selfTest() {
  const checks = [];
  const check = (label, ok) => checks.push({ label, ok });

  check('a tag-szekvencia a nyitó/záró jelet is nézi', tagSequence('<p>a<br/></p>').join('') === '<p><br/></p>');
  check('a tag nélküli szöveg üres szekvencia', tagSequence('sima szöveg').length === 0);
  check('az attribútumot is látja', tagSequence('<img src="a.jpg" class="x">')[0] === '<img src="a.jpg" class="x">');
  check('az ékezetes szót jelzi', hungarianSignals('Közösség').some((s) => s.includes('Közösség')));
  check('a márkanevet nem jelzi', hungarianSignals('Pannónia').length === 0);
  check('a tulajdonnevet nem jelzi', hungarianSignals('Balázs Siófok').length === 0);
  check('a magyar szót a név mellett is jelzi', hungarianSignals('Balázs Közösség').some((s) => s.includes('Közösség')));
  check('a tiszta angolt nem jelzi', hungarianSignals('Save the changes').length === 0);

  const ok = checkTranslations({
    source: [{ type: 'event', id: 1, content: '<p>Szöveg</p>' }],
    translations: { 'event-1': { title: 'Hi', content: '<p>Text</p>' } },
  });
  check('a helyes fordítást átengedi', ok.problems.length === 0 && ok.stats.covered === 1);

  const missing = checkTranslations({ source: [{ type: 'event', id: 1, content: '<p>x</p>' }], translations: {} });
  check('a hiányzót jelzi', missing.problems[0].type === 'hianyzo');

  const broken = checkTranslations({
    source: [{ type: 'event', id: 1, content: '<p><strong>Szöveg</strong></p>' }],
    translations: { 'event-1': { title: 'Hi', content: '<p>Text</p>' } },
  });
  check('a szerkezet-hibát jelzi', broken.problems.some((problem) => problem.type === 'szerkezet'));

  const hungarian = checkTranslations({
    source: [{ type: 'event', id: 1, content: '<p>Szöveg</p>' }],
    translations: { 'event-1': { title: 'Cím', content: '<p>Text</p>' } },
  });
  check('a magyarul maradt szöveget jelzi', hungarian.problems.some((problem) => problem.type === 'magyar'));

  const empty = checkTranslations({
    source: [{ type: 'event', id: 1, content: '<p>Szöveg</p>' }],
    translations: { 'event-1': { title: '', content: '<p></p>' } },
  });
  check('az üres fordítást jelzi', empty.problems.some((problem) => problem.type === 'ures-cim'));
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

  const source = fs.existsSync(SOURCE_PATH) ? JSON.parse(fs.readFileSync(SOURCE_PATH, 'utf8')) : [];
  const translations = readTranslations();
  const { problems, stats } = checkTranslations({ source, translations });

  console.log(`forrás-elem: ${stats.source}`);
  console.log(`lefordítva: ${stats.covered}`);
  console.log(
    `hiányzó: ${stats.missing} | üres: ${stats.empty} | szerkezet-hiba: ${stats.structure} | `
    + `magyarul maradt: ${stats.hungarian} | ismeretlen kulcs: ${stats.extra}`,
  );
  for (const problem of problems.slice(0, 20)) {
    console.log(`  ${problem.type.toUpperCase()}  ${problem.key}${problem.detail ? ` — ${problem.detail}` : ''}`);
  }
  const failed = problems.length > 0;
  if (!failed) console.log('\nMINDEN ELLENŐRZÉS RENDBEN.');
  return process.argv.includes('--strict') && failed ? 1 : 0;
}

if (process.argv[1] && process.argv[1].endsWith('check-content-translations.mjs')) {
  process.exitCode = main();
}
