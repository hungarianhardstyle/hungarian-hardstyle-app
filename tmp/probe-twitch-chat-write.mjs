// Miért nem megy a stream-chat üzenet? — ÉLES mérés a valódi profil-adatokkal.
//
// MIÉRT: a tulajdonos kérdése (2026-10-02): *„üzenet azért nem küldhető a twitch
// chates részre mert a stream nem live?”* — a stream állapota **nem** érinti a
// saját chatünket (az a saját Firestore-gyűjtemény), ezért a valódi okot mérjük:
// a stream-chat írása **kliensoldali** (a fő chat szerveroldali függvényen megy),
// és a szabály a **szerző képének URL-jét** is ellenőrzi.
//
// Ez a szkript anonim felhasználóval, a VALÓDI profil-képekkel próbál írni, és
// megmondja, melyik érték megy át — majd kitakarít maga után.
//
// Használat: node tmp/probe-twitch-chat-write.mjs
import fs from 'node:fs';
import { accessToken, firestoreList } from '../tools/lib/live-firebase.mjs';

const PROJECT = 'hungarian-hardstyle';
const DATABASE = 'hungarian-hardstyle';
const BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/${DATABASE}/documents`;
const DOCS = `projects/${PROJECT}/databases/${DATABASE}/documents`;

const googleServices = JSON.parse(fs.readFileSync('android/app/google-services.json', 'utf8'));
const apiKey = googleServices.client[0].api_key[0].current_key;

const signIn = async () => {
  const response = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${apiKey}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ returnSecureToken: true }),
    },
  );
  const json = await response.json();
  if (!json.idToken) throw new Error(`anonim bejelentkezés hiba: ${JSON.stringify(json).slice(0, 200)}`);
  return { idToken: json.idToken, uid: json.localId };
};

const write = async (token, uid, id, { authorName, authorImageUrl, text }, database = DATABASE) => {
  const base = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/${database}/documents`;
  const docs = `projects/${PROJECT}/databases/${database}/documents`;
  const response = await fetch(`${base}:commit`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
    body: JSON.stringify({
      writes: [
        {
          update: {
            name: `${docs}/twitch_chat/${id}`,
            fields: {
              authorId: { stringValue: uid },
              authorName: { stringValue: authorName },
              authorImageUrl: { stringValue: authorImageUrl },
              text: { stringValue: text },
            },
          },
          updateTransforms: [{ fieldPath: 'createdAt', setToServerValue: 'REQUEST_TIME' }],
          currentDocument: { exists: false },
        },
      ],
    }),
  });
  return response.status;
};

// A valódi profilok (a token admin-jogosultsággal olvas, ezért a szabály nem akadály).
const adminToken = await accessToken();
const profiles = await firestoreList('community_profiles', {
  fields: ['displayName', 'imageUrl'],
  token: adminToken,
  max: 200,
});
console.log(`profilok: ${profiles.length}`);

const shapes = new Map();
for (const profile of profiles) {
  const url = `${profile.imageUrl ?? ''}`.trim();
  const shape = url === ''
    ? '(üres)'
    : url.startsWith('https://res.cloudinary.com/fjxo93em/image/upload/')
      ? 'cloudinary (engedett)'
      : `MÁS: ${url.slice(0, 60)}`;
  shapes.set(shape, (shapes.get(shape) ?? 0) + 1);
}
console.log('a képek alakja a profilokban:');
for (const [shape, count] of [...shapes.entries()].sort((a, b) => b[1] - a[1])) {
  console.log(`  ${count.toString().padStart(4)}  ${shape}`);
}

const { idToken, uid } = await signIn();
console.log(`\nanonim felhasználó: ${uid}`);
const stamp = Date.now();
let failed = 0;

const cases = [
  ['üres kép + rövid név', { authorName: 'Teszt', authorImageUrl: '', text: 'proba' }],
  ['NÉV NÉLKÜL (Vendég)', { authorName: 'Vendég', authorImageUrl: '', text: 'proba' }],
  ['60 karakternél HOSSZABB név', { authorName: 'N'.repeat(61), authorImageUrl: '', text: 'proba' }],
];

// A valódi profilokból vett képekkel is próbálunk (ez a gyanú!).
const sampleUrls = [...new Set(profiles.map((p) => `${p.imageUrl ?? ''}`.trim()))].slice(0, 6);
for (const url of sampleUrls) {
  cases.push([
    url === '' ? 'profil: üres kép' : `profil-kép: ${url.slice(0, 55)}`,
    { authorName: 'Teszt', authorImageUrl: url, text: 'proba' },
  ]);
}

for (const [title, payload] of cases) {
  const id = `probe-${stamp}-${Math.random().toString(36).slice(2, 8)}`;
  const status = await write(idToken, uid, id, { ...payload, authorName: payload.authorName });
  const ok = status === 200;
  if (!ok) failed += 1;
  console.log(`${ok ? 'OK   ' : 'BUKIK'} ${status}  ${title}`);
  if (ok) {
    await fetch(`${BASE}/twitch_chat/${id}`, {
      method: 'DELETE',
      headers: { Authorization: `Bearer ${idToken}` },
    });
  }
}

console.log(`\n${cases.length - failed}/${cases.length} írás ment át a NÉVES adatbázisban`);

// ⚠️ A LÉNYEG: ugyanaz az írás a `(default)` adatbázisban — ez volt a hiba útja
// (a szolgáltatás a `FirebaseFirestore.instance`-t használta).
const defaultStatus = await write(
  idToken,
  uid,
  `probe-default-${stamp}`,
  { authorName: 'Teszt', authorImageUrl: '', text: 'proba' },
  '(default)',
);
console.log(`${defaultStatus === 200 ? 'OK   ' : 'BUKIK'} ${defaultStatus}  ugyanez a (default) adatbázisban`);
if (defaultStatus === 200) {
  await fetch(`${BASE.replace(DATABASE, '(default)')}/twitch_chat/probe-default-${stamp}`, {
    method: 'DELETE',
    headers: { Authorization: `Bearer ${idToken}` },
  });
}
console.log(
  defaultStatus === 200
    ? '\nFIGYELEM: a (default) adatbázis is beengedi az írást — a hiba nem ez volt.'
    : '\nMÉRVE: a (default) adatbázis ELUTASÍTJA az írást — pontosan ez volt a „nem küldhető” hiba.',
);
process.exitCode = failed === 0 ? 0 : 1;
