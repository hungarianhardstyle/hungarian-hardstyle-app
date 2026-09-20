#!/usr/bin/env node
/**
 * ÉLES (csak olvas): a WordPress push-küldési lánc állapota.
 *
 * MIÉRT: a dupla push vizsgálatához kellett — a plugin a titkos diagnosztikai
 * fejlécben (`X-HUHS-Health`) kiírja a regisztrált eszközök számát, az utolsó kör
 * eredményét és a függőben lévő küldési feladatot. Ebből derül ki, hogy egy kör
 * belefér-e az időkeretbe (a 807 eszköz / 125 eszköz-kör arány mutatta meg, hogy
 * egy kör hosszabb a 10 s-os „elakadt" küszöbnél — ez volt a dupla push egyik
 * feltétele).
 *
 * Titkot nem tartalmaz és nem ír: a diagnosztikai markert a plugin forrása
 * tartalmazza, a végpont pedig csak olvasás.
 *
 * Futtatás:  node tools/check-wp-push-state.mjs
 *            node tools/check-wp-push-state.mjs --self-test
 * Kilépési kód: 0 = sikerült kiolvasni, 1 = nem (vagy önteszt-hiba).
 */

const MARKER = 'huhs-boot-probe-2026';
const BASE = 'https://hungarianhardstyle.hu';

/** A diagnosztikai fejléc feldolgozása (tiszta függvény, ezért tesztelhető). */
export function parseHealthHeader(value) {
  const parts = String(value || '')
    .trim()
    .split(/\s+/)
    .filter(Boolean);
  const fields = {};
  for (const part of parts) {
    const index = part.indexOf('=');
    if (index <= 0) continue;
    fields[part.slice(0, index)] = part.slice(index + 1);
  }
  return fields;
}

export function selfTest() {
  const checks = [];
  const check = (label, ok) => checks.push({ label, ok });

  const fields = parseHealthHeader('api=2.5.9 push_tokens=807 push_last=custom/ok push_job=none');
  check('a kulcsokat kiolvassa', fields.api === '2.5.9' && fields.push_tokens === '807');
  check('a perjelet tartalmazó értéket is', fields.push_last === 'custom/ok');
  check('a hiányzó értéket nem találja ki', parseHealthHeader('api=2.5.9').push_tokens === undefined);
  check('az üres fejléc üres térkép', Object.keys(parseHealthHeader('')).length === 0);
  check('a szemét nem töri el', parseHealthHeader('api=2.5.9 ??? =x push_job=none').api === '2.5.9');

  return checks;
}

async function main() {
  if (process.argv.includes('--self-test')) {
    const checks = selfTest();
    for (const check of checks) console.log(`${check.ok ? 'OK  ' : 'HIBA'} ${check.label}`);
    const failed = checks.filter((check) => !check.ok).length;
    console.log(`\n${checks.length - failed}/${checks.length} önteszt rendben`);
    return failed ? 1 : 0;
  }

  const url = `${BASE}/wp-json/huhs/v1/posts?per_page=1&huhs_diag=${MARKER}&probe=push-state`;
  const response = await fetch(url, { headers: { Accept: 'application/json' } });
  const health = response.headers.get('x-huhs-health');
  if (!health) {
    console.log(`HIBA: nincs diagnosztikai fejléc (HTTP ${response.status}).`);
    return 1;
  }
  const fields = parseHealthHeader(health);
  const tokens = Number(fields.push_tokens || 0);
  console.log(`plugin=${fields.api || '?'} eszközök=${tokens}`);
  console.log(
    `utolsó kör: ${fields.push_last || '?'} — feldolgozva=${fields.processed || '?'} ` +
      `elküldve=${fields.sent || '?'} hiba=${fields.failed || '?'} halott=${fields.dead || '?'}`,
  );
  console.log(`függő feladat: ${fields.push_job || '?'} · aktív: ${fields.push_active || '?'}`);
  console.log(
    '\nÉrtelmezés: ha a „feldolgozva" jóval kevesebb, mint az eszközök száma, akkor egy kör ' +
      'több szeletből áll (nagy küldés) — ilyenkor a lánc-verseny védelme (2.5.9) számít.',
  );
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
