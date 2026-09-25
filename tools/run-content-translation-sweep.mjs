#!/usr/bin/env node
/**
 * A hiányzó angol fordítások **pótlása** a plugin saját végpontján keresztül.
 *
 * MIÉRT ESZKÖZ: a 2.13.0 óránként magától pótol (3 elem/típus), de az első körben
 * ~90 elem vár — ez az eszköz a plugin `POST /huhs/v1/translations/sweep`
 * végpontját hívja nagyobb adagokban, amíg a várólista ki nem ürül.
 *
 * ⚠️ A fordítás a **szerveren** történik, a tulajdonos saját kulcsával: ez az
 * eszköz nem fordít és nem ír metát, csak a pótlást indítja és **méri** az
 * eredményt (`GET /translations/status`).
 *
 * ⚠️ A költségvetés (`budget`) azért van, mert a WP-cron/végpont egy PHP-kérésben
 * fut: rövidebb kérés → kisebb esély a futásidő-korlátra. A már kész fordítások
 * minden elem után mentődnek, ezért egy megszakadt kör sem veszik el.
 *
 * Használat:
 *   node tools/run-content-translation-sweep.mjs --status
 *   node tools/run-content-translation-sweep.mjs --limit=20 --budget=20 --rounds=25
 *   node tools/run-content-translation-sweep.mjs --self-test
 */
import { secret } from './lib/live-firebase.mjs';

export const WP_BASE = 'https://hungarianhardstyle.hu/wp-json';
export const STATUS_ROUTE = '/huhs/v1/translations/status';
export const SWEEP_ROUTE = '/huhs/v1/translations/sweep';

/** A várólista összege (`pending` minden típusra). */
export function pendingTotal(status) {
  const pending = status?.pending ?? {};
  return Object.values(pending).reduce((sum, value) => sum + (Number(value) || 0), 0);
}

/**
 * Az alapértelmezett paraméterek kiolvasása (`--kulcs=érték`).
 * Az ismeretlen kulcsokat figyelmen kívül hagyja, a számokat korlátozza.
 *
 * ⚠️ A `--type=` azért kell, mert a pótló kör a **típusok sorrendjében** halad, és
 * egy nagy cikk-hátralék (mért: 200+) felemészti a költségvetést — a kisebb
 * típusok (pl. a 6 régi esemény) így **kiéheznének**. A `--type=huhs_event`
 * ilyenkor célzottan azt a típust pótolja.
 */
export function parseArgs(argv, defaults = { limit: 20, budget: 20, rounds: 25 }) {
  const out = { ...defaults, status: false, type: '' };
  for (const arg of argv) {
    if (arg === '--status') out.status = true;
    else if (arg === '--self-test') out.selfTest = true;
    else {
      const numeric = /^--(limit|budget|rounds)=(\d+)$/.exec(arg);
      if (numeric) out[numeric[1]] = Number(numeric[2]);
      else {
        const type = /^--type=([a-z_]+)$/.exec(arg);
        if (type) out.type = type[1];
      }
    }
  }
  out.limit = Math.max(1, Math.min(20, out.limit));
  out.budget = Math.max(0, Math.min(55, out.budget));
  out.rounds = Math.max(1, Math.min(60, out.rounds));
  return out;
}

/** Egy sweep-válasz összegzése a naplóhoz (tesztelhető, hálózat nélkül). */
export function roundSummary(payload) {
  const byType = payload?.by_type ?? {};
  const parts = Object.entries(byType)
    .filter(([, stats]) => (stats?.checked ?? 0) > 0)
    .map(([type, stats]) => `${type}: ${stats.translated}/${stats.checked}`);
  return {
    translated: Number(payload?.translated ?? 0),
    failed: Number(payload?.failed ?? 0),
    skipped: Number(payload?.skipped ?? 0),
    pending: pendingTotal(payload),
    detail: parts.join(', '),
  };
}

export function selfTest() {
  const checks = [];
  const check = (label, ok) => checks.push({ label, ok });

  check(
    'a `--status` és a szám-paraméterek beolvasása jó',
    (() => {
      const parsed = parseArgs(['--status', '--limit=20', '--budget=7', '--rounds=3', '--egyeb']);
      return parsed.status === true && parsed.limit === 20 && parsed.budget === 7 && parsed.rounds === 3;
    })(),
  );
  check(
    'a `--type=` célzott típust ad (és csak érvényes nevet fogad el)',
    (() => {
      const parsed = parseArgs(['--type=huhs_event']);
      const invalid = parseArgs(['--type=NemIlyen']);
      return parsed.type === 'huhs_event' && invalid.type === '';
    })(),
  );
  check(
    'a paraméterek felső korlátja érvényesül (limit ≤ 20, budget ≤ 55)',
    (() => {
      const parsed = parseArgs(['--limit=999', '--budget=999']);
      return parsed.limit === 20 && parsed.budget === 55;
    })(),
  );
  check(
    'a várólista összege minden típust számol',
    pendingTotal({ pending: { post: 70, huhs_event: 6, huhs_artist: 0, huhs_organizer: 0, huhs_release: 0 } }) === 76,
  );
  check('a hiányzó pending nulla', pendingTotal({}) === 0 && pendingTotal(null) === 0);
  check(
    'a kör-összegzés csak a dolgozó típusokat sorolja fel',
    (() => {
      const summary = roundSummary({
        translated: 3,
        failed: 1,
        skipped: 0,
        pending: { post: 5, huhs_event: 0 },
        by_type: {
          post: { checked: 4, translated: 3, failed: 1, skipped: 0 },
          huhs_event: { checked: 0, translated: 0, failed: 0, skipped: 0 },
        },
      });
      return summary.detail === 'post: 3/4' && summary.pending === 5 && summary.translated === 3 && summary.failed === 1;
    })(),
  );
  return checks;
}

async function request(route, { authorization, method = 'GET', body } = {}) {
  const response = await fetch(`${WP_BASE}${route}`, {
    method,
    headers: {
      accept: 'application/json',
      ...(authorization ? { authorization } : {}),
      ...(body ? { 'content-type': 'application/json' } : {}),
    },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });
  const text = await response.text();
  let json = null;
  try {
    json = JSON.parse(text);
  } catch {
    json = null;
  }
  return { ok: response.ok, status: response.status, json, text };
}

async function main() {
  const args = parseArgs(process.argv.slice(2));

  if (args.selfTest) {
    const checks = selfTest();
    for (const check of checks) console.log(`${check.ok ? 'OK  ' : 'HIBA'} ${check.label}`);
    const failed = checks.filter((check) => !check.ok).length;
    console.log(`\n${checks.length - failed}/${checks.length} önteszt rendben`);
    return failed ? 1 : 0;
  }

  let authorization = '';
  try {
    const user = secret('WORDPRESS_USERNAME');
    const password = secret('WORDPRESS_APPLICATION_PASSWORD');
    authorization = `Basic ${Buffer.from(`${user}:${password}`).toString('base64')}`;
  } catch (error) {
    console.log(`HIBA  a WordPress-jelszó nem érhető el (${error.message}) — a végpont admin-jogot kér.`);
    return 1;
  }

  const status = await request(STATUS_ROUTE, { authorization });
  if (!status.ok || !status.json) {
    console.log(
      `HIBA  a ${STATUS_ROUTE} nem válaszol (HTTP ${status.status}) — a 2.13.0 nincs fent? `
      + `${String(status.text).slice(0, 120)}`,
    );
    return 1;
  }

  const info = status.json;
  console.log(`=== állapot`);
  console.log(`  fordítás bekapcsolva: ${info.enabled === true}`);
  console.log(`  szolgáltató: ${info.provider?.url ?? '?'} (${info.provider?.model ?? '?'})`);
  console.log(`  várólista: ${pendingTotal(info)} elem — ${JSON.stringify(info.pending ?? {})}`);

  if (!info.enabled) {
    console.log('  → API-kulcs nélkül a pótlás nem indul (ez szándékos).');
    return 0;
  }
  if (args.status) return 0;

  let lastPending = pendingTotal(info);
  for (let round = 1; round <= args.rounds; round += 1) {
    const started = Date.now();
    const result = await request(SWEEP_ROUTE, {
      authorization,
      method: 'POST',
      body: { limit: args.limit, budget: args.budget, ...(args.type ? { type: args.type } : {}) },
    });
    const seconds = ((Date.now() - started) / 1000).toFixed(1);

    if (!result.ok || !result.json) {
      console.log(`  ${round}. kör: HIBA HTTP ${result.status} (${seconds} s) — ${String(result.text).slice(0, 120)}`);
      // Egy futásidő-korlát nem hiba: a kész fordítások mentve vannak, a következő kör folytatja.
      continue;
    }

    const summary = roundSummary(result.json);
    console.log(
      `  ${round}. kör (${seconds} s): fordítva ${summary.translated}, hiba ${summary.failed}, `
      + `kihagyva ${summary.skipped}${summary.detail ? ` [${summary.detail}]` : ''} → hátralévő ${summary.pending}`,
    );

    if (summary.pending === 0) {
      console.log('\nMINDEN HIÁNYZÓ ANGOL PÓTOLVA.');
      return 0;
    }
    // Nincs előrelépés (pl. minden elem hibázik): felesleges pörgetni.
    if (summary.translated === 0 && summary.pending >= lastPending) {
      console.log('\nMEGÁLLVA — ebben a körben nem sikerült fordítás (a hibajelző 6 óráig késleltet).');
      return 2;
    }
    lastPending = summary.pending;
  }

  console.log(`\nMEGÁLLVA a körlimittnél (${args.rounds}) — hátralévő: ${lastPending}. Futtasd újra.`);
  return 0;
}

if (process.argv[1] && process.argv[1].endsWith('run-content-translation-sweep.mjs')) {
  process.exitCode = await main();
}
