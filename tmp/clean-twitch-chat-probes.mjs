// A `twitch_chat` gyűjtemény TARTALMA — és a saját próba-üzeneteim takarítása.
//
// MIÉRT: a tulajdonos jelezte (2026-10-02): *„meg ezt a szabály próbált töröld már
// a chatről :D”* — vagyis a szabály-ellenőrző szkriptjeim próba-üzenetei
// **benne maradtak** az éles stream-chatben. Ez az én mérésem szemetje.
//
// Alapból csak **listáz** (`--clean` kapcsolóval töröl), és a törlést **ellenőrzi**.
//
// Használat:
//   node tmp/clean-twitch-chat-probes.mjs            (csak listáz)
//   node tmp/clean-twitch-chat-probes.mjs --clean    (törli a próbákat)
import { accessToken, firestoreList, firestoreDelete } from '../tools/lib/live-firebase.mjs';

const clean = process.argv.includes('--clean');

// A saját méréseim ujjlenyomatai (a szkriptek szövegei és a próba-szerzők).
const probeTexts = new Set(['szabaly-proba', 'szabály-próba', 'proba', 'rules probe']);
const probeAuthors = new Set(['Szabály-próba', 'Teszt', 'Rules probe']);

const token = await accessToken();
const messages = await firestoreList('twitch_chat', {
  fields: ['text', 'authorName', 'authorId', 'createdAt'],
  token,
  max: 500,
});

console.log(`üzenetek a twitch_chat gyűjteményben: ${messages.length}\n`);
const probes = [];
for (const message of messages) {
  const text = `${message.text ?? ''}`.trim();
  const author = `${message.authorName ?? ''}`.trim();
  const isProbe = probeTexts.has(text.toLowerCase()) || probeAuthors.has(author);
  const when = message.createdAt?.value ?? message.createdAt ?? '';
  console.log(
    `${isProbe ? 'PRÓBA' : 'valódi'}  ${JSON.stringify(text).slice(0, 40).padEnd(42)} ` +
      `${author.padEnd(16)} ${String(when).slice(0, 24)}`,
  );
  if (isProbe) probes.push(message.id);
}

console.log(`\npróba-üzenet: ${probes.length}, valódi: ${messages.length - probes.length}`);

if (!clean) {
  console.log('\n(csak listázás — a törléshez: --clean)');
  process.exitCode = probes.length === 0 ? 0 : 1;
} else {
  let deleted = 0;
  for (const id of probes) {
    await firestoreDelete(`twitch_chat/${id}`, { token });
    deleted += 1;
  }
  const after = await firestoreList('twitch_chat', { fields: ['text'], token, max: 500 });
  const remaining = after.filter((message) => {
    const text = `${message.text ?? ''}`.trim().toLowerCase();
    return probeTexts.has(text);
  });
  console.log(`\ntörölve: ${deleted}, a listában maradt próba-szöveg: ${remaining.length}`);
  console.log(remaining.length === 0 ? 'A stream-chat TISZTA.' : 'FIGYELEM: maradt próba-üzenet!');
  process.exitCode = remaining.length === 0 ? 0 : 1;
}
