#!/usr/bin/env node
/**
 * Mennyi a WordPress-tartalom? (csak olvas)
 *
 * Az angol nyelv kérdésének MÁSIK fele: a hírek, események, DJ-bemutatkozók és
 * kiadványleírások a WordPress-ből jönnek, és **magyarul** vannak. Ez a
 * mennyiség folyamatosan nő (minden új cikk), ezért a döntéshez ezt is mérni
 * kell — a felület szövegei egyszeri költséggel fordíthatók, a tartalom nem.
 *
 * Futtatás: node tools/check-content-volume.mjs
 */
const BASE = 'https://hungarianhardstyle.hu/wp-json/huhs/v1';

const FIELDS = {
  posts: ['title', 'excerpt', 'content'],
  events: ['title', 'description', 'venue', 'city'],
  artists: ['title', 'bio', 'description'],
  releases: ['title', 'description'],
  organizers: ['title', 'bio', 'description'],
};

/** Egy rekord szövegmezőinek összegyűjtése (tiszta függvény). */
export function recordTexts(record, fields) {
  const out = [];
  for (const field of fields) {
    const value = record?.[field];
    if (typeof value === 'string' && value.trim()) out.push(value.trim());
  }
  return out;
}

/** Egy lista összegzése: hány rekord, hány szöveg, hány karakter. */
export function summarizeList(records, fields) {
  let chars = 0;
  let texts = 0;
  for (const record of records) {
    for (const text of recordTexts(record, fields)) {
      texts += 1;
      chars += [...text].length;
    }
  }
  return { records: records.length, texts, chars };
}

export function selfTest() {
  const checks = [];
  const check = (label, ok) => checks.push({ label, ok });
  const rows = [
    { title: 'Egy cikk', excerpt: 'Rövid', content: '<p>Hosszabb szöveg</p>' },
    { title: 'Kettő', content: '' },
  ];
  const summary = summarizeList(rows, ['title', 'excerpt', 'content']);
  check('a rekordokat számolja', summary.records === 2);
  check('az üres mezőt kihagyja', summary.texts === 4);
  check('a karaktereket számolja', summary.chars > 20);
  check('az ismeretlen mezőt kihagyja', recordTexts({ title: 'X' }, ['nincs']).length === 0);
  return checks;
}

async function get(path) {
  const response = await fetch(`${BASE}${path}`, {
    headers: { accept: 'application/json' },
  });
  if (!response.ok) throw new Error(`${path}: HTTP ${response.status}`);
  const json = await response.json();
  if (Array.isArray(json)) return json;
  for (const key of ['items', 'data', 'results', 'posts', 'events', 'artists', 'releases']) {
    if (Array.isArray(json?.[key])) return json[key];
  }
  return [];
}

async function main() {
  if (process.argv.includes('--self-test')) {
    const checks = selfTest();
    for (const check of checks) console.log(`${check.ok ? 'OK  ' : 'HIBA'} ${check.label}`);
    const failed = checks.filter((check) => !check.ok).length;
    console.log(`\n${checks.length - failed}/${checks.length} önteszt rendben`);
    return failed ? 1 : 0;
  }
  let total = 0;
  console.log('WordPress-tartalom (magyar szöveg, amit angolul is meg kellene jeleníteni)\n');
  for (const [endpoint, fields] of Object.entries(FIELDS)) {
    try {
      const rows = await get(`/${endpoint}`);
      const summary = summarizeList(rows, fields);
      total += summary.chars;
      console.log(
        `  /${endpoint.padEnd(11)} ${String(summary.records).padStart(4)} rekord  ` +
          `${String(summary.texts).padStart(5)} szövegmező  ${String(summary.chars).padStart(8)} karakter`,
      );
    } catch (error) {
      console.log(`  /${endpoint.padEnd(11)} HIBA: ${error.message}`);
    }
  }
  console.log(`\nösszesen: ${total.toLocaleString('hu-HU')} karakter`);
  console.log(
    `egy teljes fordítás a Google Cloud Translation névleges díjával (20 USD / 1M karakter): ` +
      `${((total / 1_000_000) * 20).toFixed(2)} USD`,
  );
  console.log('\n⚠️ Ez csak a MOSTANI tartalom: minden új cikk/esemény növeli.');
  return 0;
}

main()
  .then((code) => {
    process.exitCode = code;
  })
  .catch((error) => {
    console.error(`HIBA: ${error.message}`);
    process.exitCode = 2;
  });
