// A 2. KÖR bizonyítéka — a dokumentum-azonosító a kulcs SHA-256-ja.
//
// ⚠️ KÉT MÉRÉSI HIBA JAVÍTVA EBBEN AZ ESZKÖZBEN (mindkettő az enyém volt):
//   1. az azonosító NEM a dedupe-kulcs szövege, hanem annak **sha256**-ja
//      (`createNotification`), ezért a `…:r2` végződésre épített mérés 0-t adott;
//   2. a létrejött idő `timestampValue` (nem `stringValue`) — a szűk mezőolvasóm
//      ezért látta üresnek. (Ugyanaz az osztály: a hiányzó mező úgy néz ki, mint a
//      hiányzó adat.)
import { createHash } from 'node:crypto';
import { accessToken, PROJECT } from '../tools/lib/live-firebase.mjs';

const DATABASE = 'hungarian-hardstyle';
const ROUND2_START = '2026-09-28T12:38'; // a 2. kör indítása (UTC)
const token = await accessToken();

async function runQuery(collectionId, where, limit = 1000) {
  const response = await fetch(
    `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/${DATABASE}/documents:runQuery`,
    {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ structuredQuery: { from: [{ collectionId }], ...(where ? { where } : {}), limit } }),
    },
  );
  const rows = await response.json();
  if (!Array.isArray(rows)) throw new Error(rows?.error?.message || 'ismeretlen válasz');
  return rows.map((row) => row.document).filter(Boolean);
}

const text = (doc, name) =>
  doc.fields?.[name]?.stringValue ??
  doc.fields?.[name]?.timestampValue ??
  doc.fields?.[name]?.integerValue ??
  null;
const bool = (doc, name) => doc.fields?.[name]?.booleanValue ?? null;

const profiles = await runQuery('community_profiles');
const missing = [];
for (const doc of profiles) {
  const uid = doc.name.split('/').pop();
  const hasDate = Boolean(text(doc, 'birthDate'));
  if (!hasDate) {
    missing.push({
      uid,
      email: text(doc, 'email') ?? '',
      emailRound: Number(text(doc, 'birthDateNoticeEmailRound') ?? 0),
      emailedAt: text(doc, 'birthDateNoticeEmailSentAt') ?? '',
      language: text(doc, 'language') ?? 'hu',
      hasPushToken: bool(doc, 'pushEnabled'),
    });
  }
}

const notices = await runQuery('notifications', {
  fieldFilter: { field: { fieldPath: 'type' }, op: 'EQUAL', value: { stringValue: 'birth_date_required' } },
});
const byId = new Map(notices.map((doc) => [doc.name.split('/').pop(), doc]));
const hash = (key) => createHash('sha256').update(key).digest('hex');

let round2Found = 0;
let round1Found = 0;
const createdTimes = [];
for (const person of missing) {
  const round1 = byId.get(hash(`birth_date_required:${person.uid}`));
  const round2 = byId.get(hash(`birth_date_required:${person.uid}:r2`));
  person.round1 = Boolean(round1);
  person.round2 = Boolean(round2);
  if (round1) round1Found += 1;
  if (round2) {
    round2Found += 1;
    const createdAt = String(text(round2, 'createdAt') ?? '');
    createdTimes.push(createdAt);
    person.round2CreatedAt = createdAt;
    person.round2Read = Boolean(text(round2, 'readAt'));
  }
}

console.log(`profilok: ${profiles.length}, születési dátum nélkül: ${missing.length}\n`);
console.log(`1. kör értesítés megvan:  ${round1Found}/${missing.length}`);
console.log(`2. kör értesítés megvan:  ${round2Found}/${missing.length}`);
console.log(`2. körben e-mail-jelölés: ${missing.filter((p) => p.emailRound >= 2).length}/${missing.length}`);
console.log(`2. körben van e-mail-cím: ${missing.filter((p) => p.email).length}/${missing.length}`);
if (createdTimes.length) {
  const sorted = [...createdTimes].sort();
  console.log(`\n2. kör létrejötte: ${sorted[0]} … ${sorted[sorted.length - 1]}`);
  console.log(`a mai (${ROUND2_START} utáni) körből: ${sorted.filter((t) => t >= ROUND2_START).length}`);
  console.log(`olvasatlan a 2. körből: ${missing.filter((p) => p.round2 && !p.round2Read).length}`);
}
const withoutRound2 = missing.filter((p) => !p.round2);
if (withoutRound2.length) {
  console.log(`\n⚠️ akinek NINCS 2. körös értesítése: ${withoutRound2.map((p) => p.uid.slice(0, 8)).join(', ')}`);
}
