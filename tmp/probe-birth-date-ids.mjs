// Hogyan néz ki a 2. kör értesítése? (Az azonosító-végződésre épített mérésem
// 0-t adott, miközben a kör összegzése 23 létrejött értesítést mutat — tehát az
// ID névadása MÁS, mint amit feltételeztem. Nem tippelünk: megnézzük.)
import { accessToken, PROJECT } from '../tools/lib/live-firebase.mjs';

const DATABASE = 'hungarian-hardstyle';
const token = await accessToken();

const response = await fetch(
  `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/${DATABASE}/documents:runQuery`,
  {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      structuredQuery: {
        from: [{ collectionId: 'notifications' }],
        where: {
          fieldFilter: {
            field: { fieldPath: 'type' },
            op: 'EQUAL',
            value: { stringValue: 'birth_date_required' },
          },
        },
        limit: 1000,
      },
    }),
  },
);
const rows = await response.json();
const docs = rows.map((row) => row.document).filter(Boolean);
const field = (doc, name) => doc.fields?.[name]?.stringValue ?? doc.fields?.[name]?.integerValue ?? null;

const withCreated = docs.map((doc) => ({
  id: doc.name.split('/').pop(),
  path: doc.name.replace(`projects/${PROJECT}/databases/${DATABASE}/documents/`, ''),
  createdAt: String(field(doc, 'createdAt') ?? ''),
}));
withCreated.sort((a, b) => (a.createdAt < b.createdAt ? 1 : -1));
console.log(`összesen ${withCreated.length} birth_date_required értesítés\n`);
console.log('a 6 legfrissebb:');
for (const item of withCreated.slice(0, 6)) {
  console.log(`  ${item.createdAt}  id=${item.id}`);
  console.log(`      ${item.path}`);
}
const today = withCreated.filter((item) => item.createdAt >= '2026-09-28T12:38');
console.log(`\na mai (12:38 utáni) körből: ${today.length}`);
const byDay = new Map();
for (const item of withCreated) {
  const day = item.createdAt.slice(0, 10);
  byDay.set(day, (byDay.get(day) || 0) + 1);
}
console.log('naponként:', [...byDay].map(([day, count]) => `${day}=${count}`).join(', '));
