#!/usr/bin/env node
/**
 * ÉLES: volt-e HIBA a Cloud Function-ökben az elmúlt időszakban?
 *
 * MIÉRT: kiadás előtt ez a legjobb „van-e más probléma?" mérés — a Cloud
 * Logging-ból kérdezi le a `severity >= ERROR` (vagy WARNING) bejegyzéseket,
 * és függvényenként összegzi. Titkot nem használ: a Firebase CLI saját
 * bejelentkezését (memóriában) használja, és **csak olvas**.
 *
 * Futtatás:
 *   node tools/check-function-errors.mjs               (elmúlt 24 óra, ERROR+)
 *   node tools/check-function-errors.mjs --hours 72    (elmúlt 3 nap)
 *   node tools/check-function-errors.mjs --warnings    (WARNING is)
 * Kilépési kód: 0 = nincs hiba, 1 = van hiba (vagy nem futtatható).
 */
import { accessToken, PROJECT } from './lib/live-firebase.mjs';

function argValue(name, fallback) {
  const index = process.argv.indexOf(name);
  if (index < 0) return fallback;
  const value = process.argv[index + 1];
  return value && !value.startsWith('--') ? value : fallback;
}

const hours = Number(argValue('--hours', '24')) || 24;
const withWarnings = process.argv.includes('--warnings');
const severity = withWarnings ? 'WARNING' : 'ERROR';
const since = new Date(Date.now() - hours * 60 * 60 * 1000).toISOString();
const limit = Number(argValue('--limit', '100')) || 100;

/**
 * A bejegyzés forrásának neve.
 *
 * 1. generációs függvény: `resource.labels.function_name`.
 * 2. generációs függvény: `resource.labels.service_name` (Cloud Run), mert a
 * napló `cloud_run_revision` alatt jelenik meg.
 * Ütemező: `resource.labels.job_id`.
 */
function functionNameOf(entry) {
  const labels = entry.resource?.labels || {};
  return (
    labels.function_name ||
    labels.service_name ||
    labels.job_id ||
    entry.resource?.type ||
    '(ismeretlen forrás)'
  );
}

function payloadText(entry) {
  if (entry.textPayload) return entry.textPayload;
  const json = entry.jsonPayload || {};
  // A saját naplóink `event` + `message` mezőt használnak.
  const parts = [json.event, json.message, json.error, json.result].filter(Boolean);
  if (parts.length) return parts.join(' — ');
  return JSON.stringify(json).slice(0, 200);
}

async function main() {
  const token = await accessToken();
  // FONTOS, mérve (2026-09-20): a 2. generációs függvények (`onDocumentCreated`,
  // `onSchedule`, `onDocumentWritten`) naplója `cloud_run_revision` alatt
  // jelenik meg, NEM `cloud_function` alatt. Az eredeti szűrő ezért a
  // legfontosabb függvényeink hibáit **egyáltalán nem látta** — pont azokat,
  // amelyek a push-t és az ütemezett feladatokat futtatják.
  const filter =
    `severity>=${severity} AND resource.type=("cloud_function" OR "cloud_run_revision" OR "cloud_scheduler_job") ` +
    `AND timestamp>="${since}"`;
  const response = await fetch('https://logging.googleapis.com/v2/entries:list', {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      resourceNames: [`projects/${PROJECT}`],
      filter,
      orderBy: 'timestamp desc',
      pageSize: Math.min(1000, limit),
    }),
  });
  const body = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(`${response.status} — ${body?.error?.message || 'ismeretlen hiba'}`);
  }
  const entries = body.entries || [];
  if (!entries.length) {
    console.log(
      `Nincs ${severity}+ bejegyzés az elmúlt ${hours} órában (${PROJECT}). Ez a várt eredmény.`,
    );
    return 0;
  }
  const byFunction = new Map();
  console.log(`${entries.length} ${severity}+ bejegyzés az elmúlt ${hours} órában:\n`);
  for (const entry of entries.slice(0, 40)) {
    const name = functionNameOf(entry);
    byFunction.set(name, (byFunction.get(name) || 0) + 1);
    console.log(
      `${entry.timestamp} ${String(entry.severity).padEnd(8)} ${name}\n    ${String(payloadText(entry)).slice(0, 300)}`,
    );
  }
  if (entries.length > 40) console.log(`… és további ${entries.length - 40} bejegyzés.`);
  // A maradékot is beszámoljuk az összegzésbe (a lista csak az első 40-et írja ki).
  for (const entry of entries.slice(40)) {
    const name = functionNameOf(entry);
    byFunction.set(name, (byFunction.get(name) || 0) + 1);
  }
  console.log('\nÖsszegzés forrásonként:');
  for (const [name, count] of [...byFunction].sort((a, b) => b[1] - a[1])) {
    console.log(`  ${name}: ${count}`);
  }
  return 1;
}

main()
  .then((code) => {
    process.exitCode = code;
  })
  .catch((error) => {
    console.error(`HIBA: ${error.message}`);
    process.exitCode = 2;
  });
