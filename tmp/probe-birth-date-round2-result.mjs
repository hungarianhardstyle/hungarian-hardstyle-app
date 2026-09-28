// A 2. KÖR független mérése: tényleg létrejött-e 23 új értesítés és 22 e-mail-jelölés?
//
// ⚠️ Nem a függvény `lastRunSummary`-jét hisszük el, hanem a Firestore-t kérdezzük:
//   * az ÉRTESÍTÉSEK között a `birth_date_required` típusúakat, a 2. kör kulcsával
//     (`…:r2`) és a létrejöttük idejével;
//   * a PROFILOKON a `birthDateNoticeEmailRound` jelölést (2 = a 2. körben ment ki).
//
// ⚠️ MEZŐ-MASZK: minden mért mezőt fel kell sorolni — a kihagyott mező ugyanúgy
// néz ki, mint a hiányzó adat (ez a projekt visszatérő mérési hibája).
import { accessToken, PROJECT } from '../tools/lib/live-firebase.mjs';

const DATABASE = 'hungarian-hardstyle';
const token = await accessToken();

async function listCollection(collection) {
  const response = await fetch(
    `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/${DATABASE}/documents/${collection}?pageSize=300`,
    { headers: { Authorization: `Bearer ${token}` } },
  );
  const body = await response.json();
  if (!response.ok) throw new Error(`${response.status} — ${body?.error?.message || ''}`);
  return body.documents || [];
}

async function listSubcollection(uid, sub) {
  const response = await fetch(
    `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/${DATABASE}/documents/community_profiles/${uid}/${sub}?pageSize=300`,
    { headers: { Authorization: `Bearer ${token}` } },
  );
  const body = await response.json();
  if (!response.ok) throw new Error(`${response.status} — ${body?.error?.message || ''}`);
  return body.documents || [];
}

const field = (doc, name) => doc.fields?.[name]?.stringValue ?? doc.fields?.[name]?.integerValue ?? null;

// 1) Profilok: kinek van 2. körös e-mail-jelölése, és ki van még dátum nélkül?
const profiles = await listCollection('community_profiles');
let missingDate = 0;
let round2Marked = 0;
let round1Marked = 0;
for (const doc of profiles) {
  const uid = doc.name.split('/').pop();
  const hasDate = Boolean(field(doc, 'birthDate'));
  if (!hasDate) missingDate += 1;
  const emailRound = Number(field(doc, 'birthDateNoticeEmailRound') ?? 0);
  if (emailRound >= 2) round2Marked += 1;
  else if (field(doc, 'birthDateNoticeEmailSentAt')) round1Marked += 1;
  void uid;
}
console.log(`profilok: ${profiles.length}`);
console.log(`  születési dátum nélkül: ${missingDate}`);
console.log(`  e-mail-jelölés a 2. körből (birthDateNoticeEmailRound = 2): ${round2Marked}`);
console.log(`  e-mail-jelölés csak az 1. körből: ${round1Marked}`);

// 2) Értesítések: melyik körben hány jött létre?
// ⚠️ MÉRT HELY: az értesítések a **gyűjteménycsoport** `notifications` útvonalon
// érhetők el (`recipientUid` mezővel) — NEM a `community_profiles/{uid}/…` alatt.
// Az első próbám ezért adott 0 találatot (eszközhiba, nem hiányzó adat).
async function runQuery(collectionId, where, limit = 1000) {
  const response = await fetch(
    `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/${DATABASE}/documents:runQuery`,
    {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        structuredQuery: {
          from: [{ collectionId }],
          ...(where ? { where } : {}),
          limit,
        },
      }),
    },
  );
  const rows = await response.json();
  if (!Array.isArray(rows)) throw new Error(rows?.error?.message || 'ismeretlen válasz');
  return rows.map((row) => row.document).filter(Boolean);
}

// ⚠️ MÉRT TANULSÁG: a `dedupeKey` NINCS mezőként tárolva — a **dokumentum-azonosító**
// hordozza (azt a `create()` kapta). Ezért a kört az ID végződéséből olvassuk, és
// a szűrést a `type` mezőre tesszük (különben a 300-as lap plafonja miatt a
// legfrissebbek kimaradhatnak — az első mérésem pontosan ezt tette).
const birthNotices = await runQuery('notifications', {
  fieldFilter: {
    field: { fieldPath: 'type' },
    op: 'EQUAL',
    value: { stringValue: 'birth_date_required' },
  },
});
const idOf = (doc) => doc.name.split('/').pop();
const round2Notices = birthNotices.filter((doc) => idOf(doc).endsWith(':r2'));
const round1Notices = birthNotices.filter((doc) => !idOf(doc).endsWith(':r2'));
const created = round2Notices.map((doc) => String(field(doc, 'createdAt') ?? '')).sort();
const newest = created[created.length - 1];
console.log(`\nértesítések (birth_date_required, összesen ${birthNotices.length}):`);
console.log(`  1. kör (dokumentum-azonosító `+"`birth_date_required:{uid}`"+`): ${round1Notices.length}`);
console.log(`  2. kör (azonosító `+"`…:r2`"+`): ${round2Notices.length}`);
console.log(`  a 2. kör legfrissebbje: ${newest ?? '(nincs)'}`);
console.log(`  olvasatlan a 2. körből: ${round2Notices.filter((doc) => !field(doc, 'readAt')).length}`);
const recent = round2Notices.filter((doc) => String(field(doc, 'createdAt') ?? '') >= '2026-09-28T12:38');
console.log(`  a 12:38 utáni (mostani) körből: ${recent.length}`);
