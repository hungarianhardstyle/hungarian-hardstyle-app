// MIÉRT látszik HIBÁnak egy KEZELT ág? (2026-09-28)
// A `console.warn` a Cloud Run/2nd gen alatt a **stderr**-re ír, ezért kérdés,
// hogy a Cloud Logging milyen súlyosságot rendel hozzá. Nem tippelünk: lekérdezzük
// ugyanazt az eseményt, és kiírjuk a tényleges `severity` mezőt.
import { accessToken, PROJECT } from '../tools/lib/live-firebase.mjs';

const hours = Number(process.argv[2] ?? 48) || 48;
const since = new Date(Date.now() - hours * 60 * 60 * 1000).toISOString();
const token = await accessToken();

const filter =
  `jsonPayload.event="achievement_catalog_fallback" AND timestamp>="${since}"`;
const response = await fetch('https://logging.googleapis.com/v2/entries:list', {
  method: 'POST',
  headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
  body: JSON.stringify({
    resourceNames: [`projects/${PROJECT}`],
    filter,
    orderBy: 'timestamp desc',
    pageSize: 50,
  }),
});
const body = await response.json();
if (!response.ok) throw new Error(`${response.status} — ${body?.error?.message || ''}`);
const entries = body.entries || [];
console.log(`${entries.length} bejegyzés az elmúlt ${hours} órában (event=achievement_catalog_fallback):\n`);
const bySeverity = new Map();
for (const entry of entries.slice(0, 12)) {
  bySeverity.set(entry.severity, (bySeverity.get(entry.severity) || 0) + 1);
  console.log(`  ${entry.timestamp}  severity=${entry.severity}  logName=${String(entry.logName).split('/').pop()}`);
  console.log(`      payload=${JSON.stringify(entry.jsonPayload ?? entry.textPayload ?? null).slice(0, 160)}`);
  const labels = entry.resource?.labels || {};
  console.log(`      forrás=${labels.service_name || labels.function_name || entry.resource?.type}`);
}
for (const entry of entries.slice(12)) {
  bySeverity.set(entry.severity, (bySeverity.get(entry.severity) || 0) + 1);
}
console.log('\nsúlyosság szerint:', [...bySeverity].map(([s, c]) => `${s}=${c}`).join(', '));
