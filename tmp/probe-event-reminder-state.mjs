// ÉLES mérés: (1) a WP push-lánc NYERS diagnosztikai fejléce, (2) a következő események
// és az emlékeztető-ablakok (1 hét / 1 nap / 6 óra) állapota.
import fs from 'node:fs';

const BASE = 'https://hungarianhardstyle.hu';
const MARKER = 'huhs-boot-probe-2026';
const TZ = 'Europe/Budapest';

async function rawHealth() {
  for (let attempt = 1; attempt <= 4; attempt += 1) {
    const url = `${BASE}/wp-json/huhs/v1/posts?per_page=1&huhs_diag=${MARKER}&probe=reminder-state-${attempt}`;
    const response = await fetch(url, { headers: { Accept: 'application/json' } });
    const health = response.headers.get('x-huhs-health');
    if (health) return { health, status: response.status, attempt };
    await new Promise((r) => setTimeout(r, 1500));
  }
  return { health: '', status: 0, attempt: 4 };
}

const zoneOffsetMinutes = (instantMs) => {
  const parts = new Intl.DateTimeFormat('en-US', { timeZone: TZ, timeZoneName: 'longOffset' }).formatToParts(new Date(instantMs));
  const name = parts.find((p) => p.type === 'timeZoneName')?.value || 'GMT+00:00';
  const m = /GMT([+-])(\d{2}):(\d{2})/.exec(name);
  if (!m) return 0;
  return (m[1] === '-' ? -1 : 1) * (Number(m[2]) * 60 + Number(m[3]));
};

function startMs(event) {
  const date = String(event?.start_date || '').trim();
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) return NaN;
  const time = String(event?.start_time || '').trim() || '12:00';
  const [hour, minute] = time.split(':').map((v) => Number(v));
  const wall = Date.UTC(Number(date.slice(0, 4)), Number(date.slice(5, 7)) - 1, Number(date.slice(8, 10)), hour || 0, minute || 0);
  const guess = wall - zoneOffsetMinutes(wall) * 60000;
  return wall - zoneOffsetMinutes(guess) * 60000;
}

const { health, status, attempt } = await rawHealth();
console.log(`diagnosztikai fejléc: ${health ? 'MEGVAN' : 'NINCS'} (HTTP ${status}, próba ${attempt})`);
if (health) {
  for (const part of health.split(/\s+/)) console.log('  ' + part);
}

const res = await fetch(`${BASE}/wp-json/huhs/v1/events?lang=hu`, { headers: { Accept: 'application/json' } });
const body = await res.json();
const events = (Array.isArray(body) ? body : body?.items || []).filter((e) => e && e.visible !== false);
const now = Date.now();
const rows = events
  .map((e) => ({ id: e.id, title: String(e?.title?.rendered || e?.title || '').trim(), at: startMs(e), venue: e.venue_name || '', city: e.venue_city || '' }))
  .filter((r) => Number.isFinite(r.at))
  .sort((a, b) => a.at - b.at);

console.log(`\nesemények (${rows.length}), a következő 4:`);
const windows = { week: 7 * 24 * 3600e3, day: 24 * 3600e3, hours: 6 * 3600e3 };
for (const row of rows.filter((r) => r.at > now).slice(0, 4)) {
  const hours = ((row.at - now) / 3600e3).toFixed(1);
  const due = Object.entries(windows)
    .filter(([, span]) => row.at - now <= span)
    .map(([kind]) => kind);
  const upcoming = Object.entries(windows)
    .filter(([, span]) => row.at - now > span)
    .map(([kind]) => kind);
  const when = new Date(row.at).toLocaleString('hu-HU', { timeZone: TZ });
  console.log(
    `  #${row.id} ${row.title.slice(0, 40)} — ${when} (${hours} óra múlva) ${row.venue}${row.city ? ', ' + row.city : ''}`,
  );
  console.log(`      ablakban már benne (elment/alvó): ${due.join(', ') || 'egy sem'} · még hátra: ${upcoming.join(', ') || 'egy sem'}`);
}
fs.writeFileSync('tmp/reminder-state.json', JSON.stringify({ health, rows: rows.slice(0, 10) }, null, 2), 'utf8');
