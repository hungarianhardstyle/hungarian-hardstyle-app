// A **stream-chat szabályának ÉLES ellenőrzése** (391) — valódi anonim
// felhasználóval, a Firestore REST API-n, a `hungarian-hardstyle` néves
// adatbázison.
//
// MIÉRT: a szabály helyessége a fájlból nem látszik — az számít, hogy az ÉLES
// adatbázis **beengeti-e** a stream-chat írását, és **elutasítja-e** a nem
// kívánt eseteket. Minden lépés mérve van, és a próba **törli maga után** a
// dokumentumot (a szerzői törlés jogát is ezzel méri).
//
// Használat: node tmp/verify-twitch-chat-rules.mjs
import fs from 'node:fs';

const PROJECT = 'hungarian-hardstyle';
const DATABASE = 'hungarian-hardstyle';
const BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/${DATABASE}/documents`;
const DOCS = `projects/${PROJECT}/databases/${DATABASE}/documents`;

// Az API-kulcs a mellékelt Android-konfigból jön (nem titok, a kliensben is ott van).
const googleServices = JSON.parse(
  fs.readFileSync('android/app/google-services.json', 'utf8'),
);
const apiKey = googleServices.client[0].api_key[0].current_key;

const results = [];
const check = (title, ok, detail) => {
  results.push({ title, ok, detail });
  console.log(`${ok ? 'OK    ' : 'HIBA  '}${title}${detail ? ` — ${detail}` : ''}`);
};

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
  if (!response.ok || !json.idToken) {
    throw new Error(`anonim bejelentkezés hiba: HTTP ${response.status} ${JSON.stringify(json).slice(0, 200)}`);
  }
  return { idToken: json.idToken, uid: json.localId };
};

const commit = async (token, documentId, fields, { extraField = null } = {}) => {
  const payload = {
    writes: [
      {
        update: {
          name: `${DOCS}/twitch_chat/${documentId}`,
          fields: {
            authorId: { stringValue: '{UID}' },
            authorName: { stringValue: 'Szabály-próba' },
            authorImageUrl: { stringValue: '' },
            text: { stringValue: 'szabaly-proba' },
            ...fields,
            ...(extraField ? { [extraField]: { booleanValue: true } } : {}),
          },
        },
        updateTransforms: [{ fieldPath: 'createdAt', setToServerValue: 'REQUEST_TIME' }],
        currentDocument: { exists: false },
      },
    ],
  };
  const response = await fetch(`${BASE}:commit`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: JSON.stringify(payload),
  });
  return { status: response.status, body: await response.text() };
};

const stamp = Date.now();
const { idToken, uid } = await signIn();
console.log(`anonim felhasználó: ${uid}\n`);

const withUid = (fields) =>
  Object.fromEntries(
    Object.entries(fields).map(([key, value]) => [
      key,
      value.stringValue === '{UID}' ? { stringValue: uid } : value,
    ]),
  );

// 1) A HELYES írás átmegy.
const ok = await commit(idToken, `probe-${stamp}`, withUid({
  authorId: { stringValue: '{UID}' },
}));
check('bejelentkezve a stream-chat írása ÁTMEGY', ok.status === 200, `HTTP ${ok.status}`);

// 2) Olvasás bejelentkezés NÉLKÜL is megy (a chat nyilvános, mint a fő chat).
const read = await fetch(`${BASE}/twitch_chat/probe-${stamp}`);
check('olvasás bejelentkezés nélkül is megy', read.status === 200, `HTTP ${read.status}`);

// 3) Bejelentkezés nélkül az írás TILOS.
const anonymous = await commit(null, `probe-anon-${stamp}`, withUid({
  authorId: { stringValue: '{UID}' },
}));
check('bejelentkezés nélkül az írás TILOS', anonymous.status === 403, `HTTP ${anonymous.status}`);

// 4) 500 KARAKTERNÉL hosszabb üzenet TILOS.
const tooLong = await commit(idToken, `probe-long-${stamp}`, withUid({
  authorId: { stringValue: '{UID}' },
  text: { stringValue: 'a'.repeat(501) },
}));
check('500 karakternél hosszabb üzenet TILOS', tooLong.status === 403, `HTTP ${tooLong.status}`);

// 4b) ⚠️ MÉRT RÉSZLET: az ékezetes szöveg NEM bájtban számít — a 300 ékezetes
// betű (UTF-8-ban 600 bájt, de csak 300 karakter) ÁTMEGY a szabályon. Ezért
// méri a kliens is karakterben a korlátot (mérés: 2026-10-02, a 391-es kör).
const accented = await commit(idToken, `probe-accent-${stamp}`, withUid({
  authorId: { stringValue: '{UID}' },
  text: { stringValue: 'á'.repeat(300) },
}));
check('a 300 ékezetes betű (600 bájt) ÁTMEGY — a korlát karakter', accented.status === 200, `HTTP ${accented.status}`);
if (accented.status === 200) {
  await fetch(`${BASE}/twitch_chat/probe-accent-${stamp}`, {
    method: 'DELETE',
    headers: { Authorization: `Bearer ${idToken}` },
  });
}

// 5) Idegen szerző nevű írás TILOS (authorId nem a bejelentkezett felhasználó).
const foreign = await commit(idToken, `probe-foreign-${stamp}`, {
  authorId: { stringValue: 'valaki-mas' },
});
check('más nevében írni TILOS', foreign.status === 403, `HTTP ${foreign.status}`);

// 6) Váratlan mező (pl. `pinned`) TILOS — a szabály pontosan a kulcshalmazt engedi.
const pinned = await commit(
  idToken,
  `probe-pinned-${stamp}`,
  withUid({ authorId: { stringValue: '{UID}' } }),
  { extraField: 'pinned' },
);
check('váratlan mezővel írni TILOS', pinned.status === 403, `HTTP ${pinned.status}`);

// 7) A szerző TÖRÖLHETI a saját üzenetét (a próba maga után takarít).
const cleanup = await fetch(`${BASE}/twitch_chat/probe-${stamp}`, {
  method: 'DELETE',
  headers: { Authorization: `Bearer ${idToken}` },
});
check('a szerző törölheti a saját üzenetét', cleanup.status === 200, `HTTP ${cleanup.status}`);

// 8) A törölt próba valóban eltűnt.
const gone = await fetch(`${BASE}/twitch_chat/probe-${stamp}`);
check('a próba-dokumentum eltűnt', gone.status === 404, `HTTP ${gone.status}`);

const failed = results.filter((entry) => !entry.ok);
console.log(`\n${results.length - failed.length}/${results.length} ellenőrzés rendben`);
process.exitCode = failed.length === 0 ? 0 : 1;
