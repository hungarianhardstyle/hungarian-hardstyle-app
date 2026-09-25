#!/usr/bin/env node
/**
 * Az angol szótár **kapuja**: lefedettség, üres érték, helyőrzők, magyarul
 * maradt szövegek, ismeretlen kulcsok.
 *
 * MIÉRT KELL: a fordítás chunkokban, több ágenssel készül — a szótár attól még
 * lehet hiányos vagy félig magyar. Ez az eszköz ezt méri, és a `--strict`
 * kapcsolóval hibává is teszi (a CI/ellenőrző kör ezt használja).
 *
 * Használat:
 *   node tools/check-i18n.mjs            # jelentés
 *   node tools/check-i18n.mjs --strict   # hibakód, ha bármi kifogás van
 *   node tools/check-i18n.mjs --self-test
 */
import fs from 'node:fs';

export const KEYS_PATH = 'tmp/i18n/keys.json';
export const DICTIONARY_PATH = 'assets/i18n/en.json';

/**
 * A célzott szövegek **alsó** küszöbe — a „hamis 100% lefedettség" ellen.
 *
 * MIÉRT KELL (mért hibaosztály, 2026-09-25): a lefedettség nevezője a kódból
 * kinyert célok száma. Ha az extraktor egy **bekötött alakot** nem ismer fel
 * (`tr(context, …)` helyett pl. `AppStrings.tr(…)`), akkor azok a szövegek
 * kiesnek a célok közül — a hiányzó fordítás **nem** hiányzóként jelenik meg,
 * hanem a nevező csökken, és a kapu zölden **hazudik** („100%”). Ezért a
 * célszámnak érdemi padlója van: a mért érték 892 (2026-09-25), a padló 880.
 */
export const MIN_TARGETS = 880;

/** Magyar ékezet — a fordításban gyanús. */
export const HUNGARIAN_ACCENTS = /[áéíóöőúüűÁÉÍÓÖŐÚÜŰ]/;

/** Magyar szavak (ékezet nélkül is), amik angol szövegben nem fordulhatnak elő. */
export const HUNGARIAN_STOPWORDS = [
  'vagy', 'hogy', 'mert', 'csak', 'kell', 'tobb', 'osszes', 'vissza', 'hiba',
  'uzenet', 'mentes', 'torles', 'ujra', 'kilepes', 'belepes', 'fiok', 'jelszo',
  'beallitas', 'kereses', 'talalat', 'felhasznalo', 'esemeny', 'szervezo',
  'kiadvany', 'szavazas', 'jatek', 'kep', 'cim', 'nev', 'zene', 'hirek',
  'hozzaszolas', 'ertesites', 'feliratkozas', 'bejelentkezes', 'kijelentkezes',
  'regisztracio', 'hangulat', 'szoveg', 'sorozat', 'eloado', 'nyeremeny',
  'jatekos', 'eredmeny', 'kerdes', 'valasz', 'szavazat', 'jeloles',
];

/** Márkanevek: ezekben legális a magyar ékezet az angol szövegben. */
export const BRAND_ALLOWLIST = [
  'Hungarian Hardstyle',
  'HUHS',
  'Pannónia',
  'Balaton',
  'Sziget',
];

/** A minta-ellenőrzéshez: ezek a szótárakban elfogadott „nem változott" értékek. */
export const ALREADY_ENGLISH = [
  'Chat', 'DJ', 'DJs', 'Live', 'Link', 'Promo', 'Records', 'Spotify', 'Facebook',
  'Cloudinary', 'Android', 'Google', 'Google Play', 'Instagram', 'YouTube',
  'Real Hardstyle FM', 'REAL HARDSTYLE FM', 'HUHS', 'HUHS Radio', 'WAV', 'GDPR',
  'HUNGARIAN HARDSTYLE', 'Achievement', 'Team', 'Set', 'Mixtape', 'Remix',
];

/** `{név}` helyőrzők a szövegben. */
export function placeholderTokens(text) {
  return [...String(text ?? '').matchAll(/\{([a-zA-Z0-9_]+)\}/g)]
    .map((match) => match[1])
    .sort();
}

/** A szótár szövegéből objektum (hibás JSON esetén dob). */
export function decodeDictionary(rawText) {
  const decoded = JSON.parse(rawText);
  if (decoded === null || typeof decoded !== 'object' || Array.isArray(decoded)) {
    throw new Error('a szótár gyökere objektum kell legyen');
  }
  return decoded;
}

/** Duplikált kulcsok a nyers szövegben (a JSON.parse csendben összevonná). */
export function duplicateKeys(rawText) {
  const seen = new Map();
  for (const match of String(rawText ?? '').matchAll(/^\s*"((?:[^"\\]|\\.)*)"\s*:/gm)) {
    const key = match[1];
    seen.set(key, (seen.get(key) ?? 0) + 1);
  }
  return [...seen.entries()].filter(([, count]) => count > 1).map(([key]) => key);
}

/** Márkanevek kivétele, hogy az ékezet-ellenőrzés ne jelezzen rájuk. */
export function withoutBrands(text) {
  let result = String(text ?? '');
  for (const brand of BRAND_ALLOWLIST) {
    result = result.split(brand).join(' ');
  }
  return result;
}

/** Magyarul maradt szöveg jelei egy angol értékben. */
export function hungarianSignals(value) {
  const text = withoutBrands(value);
  const signals = [];
  if (HUNGARIAN_ACCENTS.test(text)) signals.push('ékezet');
  const words = text.toLowerCase().split(/[^a-z0-9áéíóöőúüű]+/);
  const hits = [...new Set(words.filter((word) => HUNGARIAN_STOPWORDS.includes(word)))];
  if (hits.length) signals.push(`magyar szó: ${hits.join(', ')}`);
  return signals;
}

/** Minden `lib/**\/*.dart` fájl legfrissebb módosítási ideje (a kulcslista frissességéhez). */
export function newestDartMtime(root = 'lib') {
  let newest = 0;
  const stack = [root];
  while (stack.length) {
    const dir = stack.pop();
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      const full = `${dir}/${entry.name}`;
      if (entry.isDirectory()) stack.push(full);
      else if (entry.name.endsWith('.dart')) {
        const mtime = fs.statSync(full).mtimeMs;
        if (mtime > newest) newest = mtime;
      }
    }
  }
  return newest;
}

/**
 * Elavult-e a kulcslista?
 *
 * ⚠️ MIÉRT KELL (mérve, 2026-09-25): a kapu a `tmp/i18n/keys.json`-t olvassa, nem
 * futtatja újra az extraktort. A mutációs bizonyíték közben pont ez buktatta meg a
 * mérést: a szabály mutálása **nem** látszott, mert a kulcslista a régi volt. Egy
 * elavult kulcslistán a lefedettség zölden hazudhat, ezért ezt jelezzük (és
 * `--strict`-ben hibává tesszük).
 */
export function staleKeys(keysPath = KEYS_PATH, root = 'lib') {
  if (!fs.existsSync(keysPath)) return { missing: true, stale: true, keysMtime: 0, newest: 0 };
  const keysMtime = fs.statSync(keysPath).mtimeMs;
  const newest = newestDartMtime(root);
  return { missing: false, stale: newest > keysMtime, keysMtime, newest };
}

/**
 * A szótár ellenőrzése.
 * @returns {{problems: Array, stats: object}}
 */
export function checkDictionary({ keys = [], dictionary = {} } = {}) {
  const problems = [];
  const targetKeys = keys.map((entry) => entry.value ?? entry);
  const targetSet = new Set(targetKeys);
  let unchanged = 0;

  for (const key of targetKeys) {
    const value = dictionary[key];
    if (value === undefined) {
      problems.push({ type: 'hianyzo', key });
      continue;
    }
    if (typeof value !== 'string' || !value.trim()) {
      problems.push({ type: 'ures', key });
      continue;
    }
    const missing = placeholderTokens(key).filter((token) => !placeholderTokens(value).includes(token));
    if (missing.length) {
      problems.push({ type: 'helyorzо', key, detail: missing.join(', ') });
    }
    const signals = hungarianSignals(value);
    if (signals.length) {
      problems.push({ type: 'magyar', key, detail: `${value} (${signals.join('; ')})` });
    }
    if (value === key && !ALREADY_ENGLISH.includes(key)) unchanged += 1;
  }

  const extra = Object.keys(dictionary).filter((key) => !targetSet.has(key));
  return {
    problems,
    stats: {
      targets: targetKeys.length,
      dictionary: Object.keys(dictionary).length,
      translated: targetKeys.filter((key) => dictionary[key] !== undefined).length,
      missing: problems.filter((problem) => problem.type === 'hianyzo').length,
      empty: problems.filter((problem) => problem.type === 'ures').length,
      hungarian: problems.filter((problem) => problem.type === 'magyar').length,
      placeholders: problems.filter((problem) => problem.type === 'helyorzо').length,
      unchanged,
      extra: extra.length,
      extraKeys: extra,
    },
  };
}

export function selfTest() {
  const checks = [];
  const check = (label, ok) => checks.push({ label, ok });

  check('a helyőrzőt megtalálja', placeholderTokens('{n} nap').join('') === 'n');
  check('a helyőrző nélküli szöveg üres', placeholderTokens('nap').length === 0);
  check(
    'a hiányzó helyőrzőt jelzi',
    checkDictionary({ keys: [{ value: '{n} nap' }], dictionary: { '{n} nap': 'days' } })
      .problems.some((problem) => problem.type === 'helyorzо'),
  );
  check(
    'a helyes helyőrzőt nem jelzi',
    checkDictionary({ keys: [{ value: '{n} nap' }], dictionary: { '{n} nap': '{n} days' } })
      .problems.length === 0,
  );
  check(
    'a hiányzó fordítást jelzi',
    checkDictionary({ keys: [{ value: 'Hiba' }], dictionary: {} })
      .problems.some((problem) => problem.type === 'hianyzo'),
  );
  check(
    'az üres fordítást jelzi',
    checkDictionary({ keys: [{ value: 'Hiba' }], dictionary: { Hiba: '   ' } })
      .problems.some((problem) => problem.type === 'ures'),
  );
  check('az ékezetes angol értéket jelzi', hungarianSignals('Közösség').includes('ékezet'));
  check(
    'a magyar szót ékezet nélkül is jelzi',
    hungarianSignals('Back to the previous screen').length === 0
      && hungarianSignals('Vissza a beallitas').some((signal) => signal.includes('magyar szó')),
  );
  check('a márkanevet nem jelzi', hungarianSignals('Pannónia Festival').length === 0);
  check('a tiszta angolt nem jelzi', hungarianSignals('Save changes').length === 0);
  check(
    'a duplikált kulcsot megtalálja',
    duplicateKeys('{\n "A": "x",\n "A": "y"\n}').join('') === 'A',
  );
  check('a hibás gyökeret elutasítja', (() => {
    try {
      decodeDictionary('[1,2]');
      return false;
    } catch (_) {
      return true;
    }
  })());
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

  const keys = fs.existsSync(KEYS_PATH) ? JSON.parse(fs.readFileSync(KEYS_PATH, 'utf8')) : [];
  const rawText = fs.readFileSync(DICTIONARY_PATH, 'utf8');
  const dictionary = decodeDictionary(rawText);
  const duplicates = duplicateKeys(rawText);
  const { problems, stats } = checkDictionary({ keys, dictionary });

  console.log(`célzott szöveg: ${stats.targets}`);
  console.log(`szótár: ${stats.dictionary} kulcs, ebből lefordítva: ${stats.translated}`);
  console.log(`lefedettség: ${stats.targets ? Math.round((stats.translated / stats.targets) * 100) : 100}%`);
  console.log(
    `hiányzó: ${stats.missing} | üres: ${stats.empty} | magyarul maradt: ${stats.hungarian} | `
    + `helyőrző-hiba: ${stats.placeholders} | változatlan: ${stats.unchanged} | szótáron kívüli kulcs: ${stats.extra}`,
  );
  if (duplicates.length) console.log(`duplikált kulcs a fájlban: ${duplicates.length}`);
  // ⚠️ A VAKSÁG-KAPU: kevesebb cél, mint a padló → az extraktor valószínűleg nem
  // ismer fel egy bekötött alakot, ezért a „100%" nem bizonyíték.
  const blind = stats.targets < MIN_TARGETS;
  if (blind) {
    console.log(
      `⚠️ GYANÚS: célzott szöveg ${stats.targets} < ${MIN_TARGETS} — az extraktor `
      + 'valószínűleg nem ismer fel egy bekötött alakot (hamis 100% lefedettség).',
    );
  }
  const staleness = staleKeys();
  if (staleness.stale) {
    console.log(
      '⚠️ ELAVULT KULCSLISTA: a kód újabb, mint a '
      + `${KEYS_PATH} — futtasd: node tools/extract-ui-strings.mjs --write`,
    );
  }

  const byType = (type) => problems.filter((problem) => problem.type === type);
  for (const problem of byType('magyar').slice(0, 15)) {
    console.log(`  MAGYAR  ${JSON.stringify(problem.key)} → ${problem.detail}`);
  }
  for (const problem of byType('helyorzо').slice(0, 10)) {
    console.log(`  HELYŐRZŐ ${JSON.stringify(problem.key)} (hiányzik: ${problem.detail})`);
  }
  for (const problem of byType('hianyzo').slice(0, 20)) {
    console.log(`  HIÁNYZÓ ${JSON.stringify(problem.key)}`);
  }
  for (const key of stats.extraKeys.slice(0, 10)) {
    console.log(`  EXTRA   ${JSON.stringify(key)}`);
  }

  const failed = problems.length > 0 || duplicates.length > 0 || blind || staleness.stale;
  if (!failed) console.log('\nMINDEN ELLENŐRZÉS RENDBEN.');
  return process.argv.includes('--strict') && failed ? 1 : 0;
}

if (process.argv[1] && process.argv[1].endsWith('check-i18n.mjs')) {
  process.exitCode = main();
}
