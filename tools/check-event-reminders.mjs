#!/usr/bin/env node
/**
 * ÉLES (csak olvas): az **esemény-emlékeztető** lánc állapota.
 *
 * MIÉRT: a tulajdonos kérése (2026-09-27) — *„esemény-emlékeztetőt mindenki
 * kapjon, ne csak az aki ott leszeket nyomott"*. A mérés szerint ez **már így
 * van**: a WordPress-plugin (`huhs-mobile-api`) publikáláskor **három**
 * emlékeztetőt ütemez minden eseményhez (**1 hét / 1 nap / 6 óra** előtte), és
 * a küldés a **telepített eszközök mindegyikére** megy (`huhs_push_send`), a
 * `reminders` / `enabled` beállítás tiszteletben tartásával
 * (`huhs_push_recipients`). A Cloud Function-oldalon **nincs** emlékeztető —
 * ezért egy korábbi mérés félrevezető volt („nincs emlékeztető").
 *
 * Ez az eszköz **nem** küld semmit: megmutatja, hogy a lánc él-e (plugin
 * verzió, regisztrált eszközök, WP-Cron, utolsó push), és **mikor esedékes** a
 * következő emlékeztető az éppen nyilvántartott eseményekre. Így a kiküldés
 * akkor is ellenőrizhető, ha épp nincs ablakban lévő esemény.
 *
 * Futtatás:  node tools/check-event-reminders.mjs
 *            node tools/check-event-reminders.mjs --self-test
 */
const BASE = 'https://hungarianhardstyle.hu';
const MARKER = 'huhs-boot-probe-2026';
const TIME_ZONE = 'Europe/Budapest';

/** A plugin emlékeztető-ablakai (`huhs_push_schedule_event_reminders`). */
const REMINDER_WINDOWS = [
  { kind: 'week', label: '1 hét előtte', ms: 7 * 24 * 60 * 60 * 1000 },
  { kind: 'day_before', label: '1 nap előtte', ms: 24 * 60 * 60 * 1000 },
  { kind: 'hours_before', label: '6 óra előtte', ms: 6 * 60 * 60 * 1000 },
];

function parseHealthHeader(header) {
  const fields = {};
  for (const part of String(header || '').trim().split(/\s+/)) {
    const index = part.indexOf('=');
    if (index <= 0) continue;
    fields[part.slice(0, index)] = part.slice(index + 1);
  }
  return fields;
}

/** Az időzóna eltolása egy adott pillanatra (nyáron +2 óra, télen +1). */
function zoneOffsetMinutes(instantMs, timeZone = TIME_ZONE) {
  const parts = new Intl.DateTimeFormat('en-US', { timeZone, timeZoneName: 'longOffset' }).formatToParts(
    new Date(instantMs),
  );
  const name = parts.find((part) => part.type === 'timeZoneName')?.value || 'GMT+00:00';
  const match = /GMT([+-])(\d{2}):(\d{2})/.exec(name);
  if (!match) return 0;
  return (match[1] === '-' ? -1 : 1) * (Number(match[2]) * 60 + Number(match[3]));
}

/** `'YYYY-MM-DD'` + `'HH:MM'` (helyi falióra) → valódi pillanat. */
function eventStartMs(event, timeZone = TIME_ZONE) {
  const date = String(event?.start_date ?? '').trim();
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) return NaN;
  const time = String(event?.start_time ?? '').trim() || '12:00';
  const match = /^(\d{1,2}):(\d{2})/.exec(time);
  const hour = match ? Number(match[1]) : 12;
  const minute = match ? Number(match[2]) : 0;
  const wall = Date.UTC(
    Number(date.slice(0, 4)),
    Number(date.slice(5, 7)) - 1,
    Number(date.slice(8, 10)),
    hour,
    minute,
  );
  const guess = wall - zoneOffsetMinutes(wall, timeZone) * 60000;
  return wall - zoneOffsetMinutes(guess, timeZone) * 60000;
}

/** Melyik ablakok vannak még hátra, és mikor esedékesek? */
function reminderSchedule(startMs, nowMs, windows = REMINDER_WINDOWS) {
  return windows.map((window) => {
    const dueAt = startMs - window.ms;
    return { ...window, dueAt, pending: dueAt > nowMs };
  });
}

/** Helyi megjelenítés (`2026. 10. 17. 23:00`). */
function formatLocal(instantMs, timeZone = TIME_ZONE) {
  if (!Number.isFinite(instantMs)) return '?';
  return new Intl.DateTimeFormat('hu-HU', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  }).format(new Date(instantMs));
}

function selfTest() {
  const checks = [];
  const check = (label, ok) => checks.push({ label, ok: Boolean(ok) });

  const parsed = parseHealthHeader('api=2.14.5 push_tokens=1010 push_last=news/ok cron=75');
  check('a fejléc-kulcsokat kiolvassa', parsed.api === '2.14.5' && parsed.push_tokens === '1010');
  check('a perjelet tartalmazó értéket is', parsed.push_last === 'news/ok');
  check('a hiányzó kulcsot nem találja ki', parsed.nincs === undefined);

  // Nyári időszámítás: 2026-10-17 23:00 helyi idő = 21:00 UTC (CEST, +2).
  const summer = eventStartMs({ start_date: '2026-10-17', start_time: '23:00' });
  check(
    'nyári (CEST) falióra → helyes pillanat',
    new Date(summer).toISOString() === '2026-10-17T21:00:00.000Z',
  );
  // Téli időszámítás: 2026-12-05 23:00 helyi = 22:00 UTC (CET, +1).
  const winter = eventStartMs({ start_date: '2026-12-05', start_time: '23:00' });
  check(
    'téli (CET) falióra → helyes pillanat',
    new Date(winter).toISOString() === '2026-12-05T22:00:00.000Z',
  );
  check('hiányzó idő → 12:00', eventStartMs({ start_date: '2026-12-05' }) === winter - 11 * 3600e3);
  check('rossz dátum → NaN', Number.isNaN(eventStartMs({ start_date: '2026/12/05' })));

  const start = Date.UTC(2026, 9, 17, 21, 0, 0);
  const schedule = reminderSchedule(start, start - 10 * 24 * 3600e3);
  check('10 nappal előtte mindhárom ablak hátravan', schedule.every((item) => item.pending));
  const later = reminderSchedule(start, start - 3 * 24 * 3600e3);
  check('3 nappal előtte a heti ablak már lejárt', later[0].pending === false && later[1].pending === true);
  const near = reminderSchedule(start, start - 2 * 3600e3);
  check('2 órával előtte már minden ablak lejárt', near.every((item) => !item.pending));

  return checks;
}

async function fetchHealth() {
  for (let attempt = 1; attempt <= 4; attempt += 1) {
    const url = `${BASE}/wp-json/huhs/v1/posts?per_page=1&huhs_diag=${MARKER}&probe=event-reminders-${attempt}`;
    const response = await fetch(url, { headers: { Accept: 'application/json' } });
    const header = response.headers.get('x-huhs-health');
    if (header) return { header, status: response.status, attempt };
    await new Promise((resolve) => setTimeout(resolve, 1200));
  }
  return { header: '', status: 0, attempt: 4 };
}

async function main() {
  if (process.argv.includes('--self-test')) {
    const checks = selfTest();
    for (const check of checks) console.log(`${check.ok ? 'OK  ' : 'HIBA'} ${check.label}`);
    const failed = checks.filter((check) => !check.ok).length;
    console.log(`\n${checks.length - failed}/${checks.length} önteszt rendben`);
    return failed ? 1 : 0;
  }

  const { header, status, attempt } = await fetchHealth();
  if (!header) {
    console.log(`HIBA: nincs diagnosztikai fejléc (HTTP ${status}, ${attempt} próba).`);
    return 1;
  }
  const fields = parseHealthHeader(header);
  const version = fields.api || '?';
  const devices = Number(fields.push_tokens || 0);
  const cronDisabled = fields.cron_disabled === 'yes';
  const cronOverdue = Number(fields.cron_overdue || 0);

  console.log(`plugin=${version} · regisztrált eszközök=${devices}`);
  console.log(
    `utolsó push: ${fields.push_last || '?'} — címzettek=${fields.recipients || '?'} ` +
      `feldolgozva=${fields.processed || '?'} elküldve=${fields.sent || '?'} ` +
      `hiba=${fields.failed || '?'} halott=${fields.dead || '?'}`,
  );
  console.log(
    `WP-Cron: ${cronDisabled ? 'KI van kapcsolva (cron_disabled=yes)' : 'él'} · ` +
      `lejárt események=${cronOverdue}`,
  );

  const response = await fetch(`${BASE}/wp-json/huhs/v1/events?lang=hu`, {
    headers: { Accept: 'application/json' },
  });
  const body = await response.json();
  const items = Array.isArray(body) ? body : Array.isArray(body?.items) ? body.items : [];
  const now = Date.now();
  const events = items
    .map((item) => ({
      id: item?.id,
      title: String(item?.title?.rendered || item?.title || '').trim(),
      startMs: eventStartMs(item),
      venue: String(item?.venue_name || '').trim(),
      city: String(item?.venue_city || '').trim(),
    }))
    .filter((event) => Number.isFinite(event.startMs) && event.startMs > now)
    .sort((a, b) => a.startMs - b.startMs);

  console.log(`\nközelgő események: ${events.length}`);
  let next = null;
  for (const event of events.slice(0, 5)) {
    const hours = (event.startMs - now) / 3600e3;
    console.log(
      `  #${event.id} ${event.title.slice(0, 48)} — ${formatLocal(event.startMs)} ` +
        `(${hours.toFixed(1)} óra múlva)${event.venue ? ' · ' + event.venue : ''}${event.city ? ', ' + event.city : ''}`,
    );
    for (const window of reminderSchedule(event.startMs, now)) {
      if (!window.pending) continue;
      console.log(`      ${window.label}: esedékes ${formatLocal(window.dueAt)}`);
      if (!next || window.dueAt < next.dueAt) next = { ...window, event };
    }
  }

  const verdict = [];
  verdict.push(cronDisabled ? 'HIBA: a WP-Cron ki van kapcsolva — emlékeztető nem megy ki.' : 'OK: a WP-Cron él.');
  verdict.push(devices > 0 ? `OK: ${devices} eszköz kapja a push-t.` : 'HIBA: nincs regisztrált eszköz.');
  verdict.push(
    String(fields.push_last || '').startsWith('event/')
      ? `OK: az utolsó push ESEMÉNY-push volt (${fields.push_last}).`
      : `FIGYELEM: az utolsó push nem esemény-push (${fields.push_last || '?'}) — ez nem hiba, csak nem most ment emlékeztető.`,
  );
  verdict.push(
    next
      ? `A következő emlékeztető: ${next.label} a(z) #${next.event.id} eseményre — ${formatLocal(next.dueAt)}.`
      : 'A következő 8 napban nincs esedékes emlékeztető.',
  );
  console.log('\n' + verdict.join('\n'));
  console.log(
    '\n⚠️ Korlát: ez az eszköz a LÁNC állapotát méri (plugin, eszközök, cron, ablakok). Azt, hogy egy konkrét\n' +
      '   emlékeztető elment-e, a plugin `_huhs_push_reminder_sent_*` jelölője igazolná — az nem olvasható\n' +
      '   kívülről; a `push_last=event/ok` sor a küldés tényét mutatja.',
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
