#!/usr/bin/env node
/**
 * ÉLES: kiment-e UGYANAZ a push kétszer?
 *
 * MIÉRT: a Cloud Function-ök push-küldésüket naplózzák (pl.
 * `private_message_push_result`). Ha egy eseményre **kétszer** fut le a küldő
 * út, az a naplóban is kétszer jelenik meg ugyanazzal az azonosítóval — ez a
 * trigger-újrakézbesítés (at-least-once) bizonyítéka. Ahol lehet, a naplót a
 * VALÓS adathoz hasonlítjuk (hány üzenet van a beszélgetésben).
 *
 * Titkot nem használ: a Firebase CLI bejelentkezését használja, és **csak olvas**.
 *
 * Futtatás:
 *   node tools/check-push-duplicates.mjs                (elmúlt 7 nap)
 *   node tools/check-push-duplicates.mjs --hours 720    (elmúlt 30 nap)
 *   node tools/check-push-duplicates.mjs --self-test    (a detektor öntesztje)
 * Kilépési kód: 0 = nincs dupla küldés, 1 = van (vagy nem futtatható).
 */
import { accessToken, firestoreList, PROJECT } from './lib/live-firebase.mjs';

function argValue(name, fallback) {
  const index = process.argv.indexOf(name);
  if (index < 0) return fallback;
  const value = process.argv[index + 1];
  return value && !value.startsWith('--') ? value : fallback;
}

const hours = Number(argValue('--hours', '168')) || 168;
const since = new Date(Date.now() - hours * 60 * 60 * 1000).toISOString();

/** Az egy küldéshez tartozó napló-események és az azonosítójuk mezője. */
export const PUSH_EVENTS = {
  connection_request_push_result: 'requestId',
  chat_report_push_result: 'reportId',
  private_message_push_result: 'conversationId',
};

/**
 * Összeszámolja, melyik azonosítóhoz hányszor futott le küldés.
 * Tiszta függvény, hogy öntesztelhető legyen.
 *
 * Ha a napló tartalmaz `messageId`-t (a küldő út 2026-09-20 óta írja), akkor az
 * a pontos kulcs: ugyanaz az üzenet kétszer = dupla push.
 */
export function countPushRuns(entries) {
  const counts = new Map();
  for (const entry of entries) {
    const json = entry.jsonPayload || entry;
    const event = String(json.event || '');
    const field = PUSH_EVENTS[event];
    if (!field) continue;
    let id = String(json[field] || '').trim();
    if (!id) continue;
    const messageId = String(json.messageId || '').trim();
    if (event === 'private_message_push_result' && messageId) id = `${id}:${messageId}`;
    const key = `${event}:${id}`;
    const record =
      counts.get(key) || { event, id, messageId: messageId || '', count: 0, timestamps: [] };
    record.count += 1;
    if (entry.timestamp) record.timestamps.push(entry.timestamp);
    counts.set(key, record);
  }
  return [...counts.values()];
}

/**
 * Eldönti, melyik sor számít dupla küldésnek.
 *
 * MIÉRT IDŐABLAK: ugyanarra a beszélgetésre/kérésre **tervszerűen** is mehet
 * több értesítés (új üzenet, újra megjelölt ismerős) — az nem hiba. A dupla
 * küldés ismertetője az, hogy ugyanaz a kör **másodperceken belül** fut le
 * kétszer (trigger-újrakézbesítés vagy versenyhelyzet).
 *
 * Ha van `messageId` (a napló 2026-09-20 után), akkor az időablak nem kell:
 * ugyanaz az üzenet egynél többször = dupla, időtől függetlenül.
 */
export function findDuplicates(records, { windowSeconds = 120 } = {}) {
  const duplicates = [];
  for (const record of records) {
    if (record.count < 2) continue;
    if (record.messageId) {
      duplicates.push({ ...record, expected: 1, reason: 'ugyanaz az üzenet többször' });
      continue;
    }
    const times = record.timestamps
      .map((value) => Date.parse(value))
      .filter((value) => Number.isFinite(value))
      .sort((a, b) => a - b);
    for (let index = 1; index < times.length; index += 1) {
      const gap = (times[index] - times[index - 1]) / 1000;
      if (gap <= windowSeconds) {
        duplicates.push({
          ...record,
          expected: 1,
          gapSeconds: Math.round(gap * 10) / 10,
          reason: `${gap.toFixed(1)} másodpercen belül kétszer`,
        });
        break;
      }
    }
  }
  return duplicates;
}

export function selfTest() {
  const checks = [];
  const check = (label, ok) => checks.push({ label, ok });
  const at = (seconds) => new Date(1700000000000 + seconds * 1000).toISOString();

  const single = countPushRuns([
    { jsonPayload: { event: 'connection_request_push_result', requestId: 'a' }, timestamp: at(0) },
  ]);
  check('egy küldés = egy sor', single.length === 1 && single[0].count === 1);
  check('az egy küldés nem dupla', findDuplicates(single).length === 0);

  const mixed = countPushRuns([
    { jsonPayload: { event: 'push_multicast_all_failed', tokens: 5 }, timestamp: at(0) },
    { jsonPayload: { event: 'private_message_push_result', conversationId: '' }, timestamp: at(0) },
  ]);
  check('az idegen/azonosító nélküli esemény nem dupla', findDuplicates(mixed).length === 0);

  // Tervszerű ismétlés (napokkal később) NEM dupla.
  const spread = countPushRuns([
    { jsonPayload: { event: 'connection_request_push_result', requestId: 'a' }, timestamp: at(0) },
    { jsonPayload: { event: 'connection_request_push_result', requestId: 'a' }, timestamp: at(4 * 86400) },
  ]);
  check('napokkal későbbi ismétlés nem dupla', findDuplicates(spread).length === 0);

  // Trigger-újrakézbesítés: másodperceken belül kétszer.
  const tight = countPushRuns([
    { jsonPayload: { event: 'connection_request_push_result', requestId: 'a' }, timestamp: at(0) },
    { jsonPayload: { event: 'connection_request_push_result', requestId: 'a' }, timestamp: at(3) },
  ]);
  check('másodperceken belüli ismétlés = dupla', findDuplicates(tight).length === 1);
  check('a dupla megmondja az időközt', findDuplicates(tight)[0].gapSeconds === 3);

  // Ha van messageId, az a döntő — időablak nélkül is.
  const withMessageId = countPushRuns([
    {
      jsonPayload: { event: 'private_message_push_result', conversationId: 'c1', messageId: 'm1' },
      timestamp: at(0),
    },
    {
      jsonPayload: { event: 'private_message_push_result', conversationId: 'c1', messageId: 'm1' },
      timestamp: at(600),
    },
  ]);
  check('ugyanaz az üzenet kétszer = dupla', findDuplicates(withMessageId).length === 1);
  check(
    'a messageId pontos kulcsot ad',
    withMessageId[0].id === 'c1:m1' || withMessageId[0].messageId === 'm1',
  );

  const twoMessages = countPushRuns([
    {
      jsonPayload: { event: 'private_message_push_result', conversationId: 'c1', messageId: 'm1' },
      timestamp: at(0),
    },
    {
      jsonPayload: { event: 'private_message_push_result', conversationId: 'c1', messageId: 'm2' },
      timestamp: at(0.5),
    },
  ]);
  check('két külön üzenet fél másodpercen belül nem dupla', findDuplicates(twoMessages).length === 0);

  return checks;
}

async function fetchEntries(token) {
  const events = Object.keys(PUSH_EVENTS);
  // FONTOS, mérve: a 2. generációs függvények (`onDocumentCreated`, `onSchedule`)
  // naplója `cloud_run_revision` alatt jelenik meg, NEM `cloud_function` alatt.
  // Az első változat emiatt NULLA találatot adott, miközben a bejegyzések
  // léteznek — a szűrőt tehát mindkét típusra kiterjesztjük.
  const filter =
    `resource.type=("cloud_function" OR "cloud_run_revision") AND timestamp>="${since}" AND (` +
    events.map((event) => `jsonPayload.event="${event}"`).join(' OR ') +
    ')';
  const entries = [];
  let pageToken = '';
  for (let page = 0; page < 10; page += 1) {
    const response = await fetch('https://logging.googleapis.com/v2/entries:list', {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        resourceNames: [`projects/${PROJECT}`],
        filter,
        orderBy: 'timestamp desc',
        pageSize: 1000,
        ...(pageToken ? { pageToken } : {}),
      }),
    });
    const body = await response.json().catch(() => ({}));
    if (!response.ok) {
      throw new Error(`${response.status} — ${body?.error?.message || 'ismeretlen hiba'}`);
    }
    entries.push(...(body.entries || []));
    pageToken = body.nextPageToken || '';
    if (!pageToken) break;
  }
  return entries;
}

async function messageCountsFor() {
  // A beszélgetés-szintű üzenetszám NEM használható mércének: az üzenetek
  // törölhetők, ezért a napló több küldést mutathat, mint ahány üzenet ma megvan
  // (mért eset: 7 küldés, 0 megmaradt üzenet). A dupla küldést ezért az
  // időablak (és a naplózott `messageId`) bizonyítja, nem a darabszám.
  return new Map();
}

async function main() {
  if (process.argv.includes('--self-test')) {
    const checks = selfTest();
    for (const check of checks) console.log(`${check.ok ? 'OK  ' : 'HIBA'} ${check.label}`);
    const failed = checks.filter((check) => !check.ok).length;
    console.log(`\n${checks.length - failed}/${checks.length} önteszt rendben`);
    return failed ? 1 : 0;
  }

  const token = await accessToken();
  const entries = await fetchEntries(token);
  const records = countPushRuns(entries);
  const windowSeconds = Number(argValue('--window', '120')) || 120;
  console.log(
    `${entries.length} push-naplóbejegyzés az elmúlt ${hours} órában, ` +
      `${records.length} különálló esemény (időablak: ${windowSeconds} s).`,
  );

  const duplicates = findDuplicates(records, { windowSeconds });
  const withMessageId = records.filter((record) => record.messageId).length;
  console.log(
    withMessageId
      ? `  üzenet-azonosítós sorok: ${withMessageId} (ezeknél a dupla bizonyított)`
      : '  üzenet-azonosító még nincs a naplóban (a javítás után lesz) — az időablak dönt',
  );
  for (const record of records.sort((a, b) => b.count - a.count).slice(0, 10)) {
    console.log(`  ${record.event} ${record.id}: ${record.count} küldés`);
  }
  if (!duplicates.length) {
    console.log('\nNincs dupla küldés a naplókban. Ez a várt eredmény.');
    return 0;
  }
  console.log(`\n${duplicates.length} dupla küldés:`);
  for (const record of duplicates) {
    console.log(
      `  HIBA ${record.event} ${record.id}: ${record.count} küldés — ${record.reason}`,
    );
    for (const timestamp of record.timestamps.slice(0, 6)) console.log(`       ${timestamp}`);
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
