// MÉRŐ PRÓBA: mit tudunk MOST kiolvasni a használatról? (2026-09-29)
//
// KÉT ÚT van, és ezt mérni kell, nem feltételezni:
//   1. **GA4 Data API** — az analitika (app_open, news_open, …) ott van; a kérdés,
//      hogy a meglévő CLI-token jogosultsága elég-e hozzá.
//   2. **Firestore** — amit az app MAGA ír: profilok, kedvencek, jelenlét,
//      értesítések. Ez jogosultság nélkül is olvasható, és valódi használati jel.
import { accessToken, PROJECT, DATABASE } from '../tools/lib/live-firebase.mjs';

const token = await accessToken();

// 1) GA4: mely property-k érhetők el ezzel a tokennel?
try {
  const response = await fetch('https://analyticsadmin.googleapis.com/v1beta/accounts', {
    headers: { Authorization: `Bearer ${token}` },
  });
  const body = await response.json().catch(() => ({}));
  console.log(`GA4 Admin API: HTTP ${response.status}`);
  if (response.ok) {
    const accounts = body.accounts || [];
    console.log(`  fiókok: ${accounts.length}`);
    for (const account of accounts.slice(0, 3)) {
      console.log(`  - ${account.displayName} (${account.name})`);
    }
  } else {
    console.log(`  — ${body?.error?.message || 'ismeretlen hiba'}`);
  }
} catch (error) {
  console.log(`GA4 Admin API: hiba — ${error.message}`);
}

// 2) Firestore: a használati jelek (mind a MÁR meglevő adat).
const read = (fields) =>
  fields?.stringValue ?? fields?.integerValue ?? fields?.booleanValue ?? fields?.timestampValue ?? null;

async function countCollection(collection, { pageSize = 300 } = {}) {
  let total = 0;
  let pageToken = '';
  do {
    const url =
      `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/${DATABASE}/documents/${collection}` +
      `?pageSize=${pageSize}${pageToken ? `&pageToken=${encodeURIComponent(pageToken)}` : ''}`;
    const response = await fetch(url, { headers: { Authorization: `Bearer ${token}` } });
    const body = await response.json();
    if (!response.ok) throw new Error(`${response.status} — ${body?.error?.message || ''}`);
    total += (body.documents || []).length;
    pageToken = body.nextPageToken || '';
  } while (pageToken);
  return total;
}

console.log('\nFirestore-jelek (a MÁR meglevő adatból):');
const profiles = await countCollection('community_profiles');
console.log(`  community_profiles: ${profiles}`);

// Kedvencek: gyűjteménycsoport (a profilok alatt élnek).
let favorites = 0;
let pageToken = '';
do {
  const response = await fetch(
    `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/${DATABASE}/documents:runQuery`,
    {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        structuredQuery: {
          from: [{ collectionId: 'favorites', allDescendants: true }],
          limit: 1000,
          ...(pageToken ? {} : {}),
        },
      }),
    },
  );
  const rows = await response.json();
  const docs = Array.isArray(rows) ? rows.map((row) => row.document).filter(Boolean) : [];
  favorites += docs.length;
  pageToken = '';
  if (docs.length === 0) break;
} while (pageToken);
console.log(`  kedvencek (gyűjteménycsoport): ${favorites}`);

// Értesítések típus szerint (mennyi ért el ténylegesen embert).
const notices = await fetch(
  `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/${DATABASE}/documents:runQuery`,
  {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      structuredQuery: { from: [{ collectionId: 'notifications' }], limit: 1000 },
    }),
  },
);
const noticeRows = await notices.json();
const noticeDocs = Array.isArray(noticeRows) ? noticeRows.map((row) => row.document).filter(Boolean) : [];
const byType = new Map();
let unread = 0;
for (const doc of noticeDocs) {
  const type = String(read(doc.fields?.type) ?? '(nincs)');
  byType.set(type, (byType.get(type) ?? 0) + 1);
  if (!read(doc.fields?.readAt)) unread += 1;
}
console.log(`  értesítések: ${noticeDocs.length} (ebből olvasatlan: ${unread})`);
for (const [type, count] of [...byType].sort((a, b) => b[1] - a[1]).slice(0, 8)) {
  console.log(`    ${type}: ${count}`);
}
