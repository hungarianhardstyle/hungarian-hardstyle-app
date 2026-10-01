#!/usr/bin/env node
/**
 * HASZNÁLAT-MÉRŐ — mennyien használják ténylegesen az appot, és MIT használnak?
 * (2026-09-29, kibővítve 2026-10-01: funkció-szintű bontás)
 *
 * MIÉRT: a döntéseink eddig a **push-eszközök számából** indultak (1030), de az
 * nem használat. Ez az eszköz a **Firestore-ban MÁR meglevő jeleket** olvassa —
 * vagyis azt, amit az app maga ír: profilok, kedvelések, jelenlét, szavazat,
 * játék, reakció, üzenet, pont —, valamint a **WordPress-admin** oldali számokat
 * (szavazás, nyereményjáték, kvíz).
 *
 * ⚠️ MÉRT KORLÁT (nem tipp): a **GA4 (analitika) API** a meglévő CLI-tokennel
 * **HTTP 403 — insufficient authentication scopes**. Az analitika kiolvasásához
 * külön szolgáltatói fiók kell `analytics.readonly` joggal (a tulajdonos oldala).
 * Addig ez az eszköz a Firestore-jelekre támaszkodik — azok viszont valódi,
 * felhasználói cselekvésekből származnak.
 *
 * Futtatás:
 *   node tools/check-usage.mjs               # összegzés
 *   node tools/check-usage.mjs --self-test   # önteszt (hálózat nélkül)
 */
import { accessToken, DATABASE, PROJECT, secretAsync } from './lib/live-firebase.mjs';

const ARG = process.argv.slice(2);

/** A „hány százaléka ez a másiknak" — 0-val osztás nélkül. */
export function share(part, whole) {
  if (!Number.isFinite(part) || !Number.isFinite(whole) || whole <= 0) return 0;
  return Math.round((part / whole) * 1000) / 10;
}

/** A `runQuery` sorai → dokumentumok. */
export function documentsOf(rows) {
  if (!Array.isArray(rows)) return [];
  // ⚠️ A `runQuery` adhat `readTime`-os vagy üres sort is — a hiányzó dokumentum
  // nem hiba. (Ezt az önteszt fogta meg: a `null` sor elszállította a láncot.)
  return rows.map((row) => row?.document).filter(Boolean);
}

/** Érték kiolvasása egy Firestore-mezőből (mindegy, milyen típus). */
export function valueOf(field) {
  if (!field || typeof field !== 'object') return null;
  return (
    field.stringValue ??
    field.integerValue ??
    field.booleanValue ??
    field.timestampValue ??
    field.doubleValue ??
    null
  );
}

/**
 * Hány KÜLÖNBÖZŐ felhasználó van a dokumentumokban?
 *
 * ⚠️ Több mező-alakot ismer (mért séma): `uid`, `userId`, `authorId`, `from`,
 * `senderId`, `recipientUid`, `reporterId`. A **tömb-értéket** (`likedBy`,
 * `participantIds`) külön segéd számolja — az nem egy azonosító, hanem lista.
 */
export function distinctUsers(
  documents,
  keys = ['uid', 'userId', 'authorId', 'from', 'senderId', 'recipientUid', 'reporterId'],
) {
  const seen = new Set();
  for (const doc of documents) {
    for (const key of keys) {
      const value = valueOf(doc.fields?.[key]);
      if (typeof value === 'string' && value !== '') {
        seen.add(value);
        break;
      }
    }
  }
  return seen.size;
}

/**
 * Tömb-mezőben lévő azonosítók (pl. `likedBy`, `participantIds`) — különböző értékek.
 *
 * A Firestore REST a tömböt `arrayValue.values` alatt adja; string elemeket számolunk.
 */
export function distinctArrayMembers(documents, key) {
  const seen = new Set();
  for (const doc of documents) {
    const values = doc.fields?.[key]?.arrayValue?.values;
    for (const entry of Array.isArray(values) ? values : []) {
      const value = valueOf(entry);
      if (typeof value === 'string' && value !== '') seen.add(value);
    }
  }
  return seen.size;
}

/**
 * Egy alkollekció-csoport (pl. `users`) dokumentumai SZÜLŐ szerint csoportosítva.
 *
 * MIÉRT KELL: a jelenlét (`event_attendance/{esemény}/users/{uid}`) és az
 * értékelés (`event_ratings/{esemény}/users/{uid}`) is a `users` alkollekcióban
 * él, ezért egy kollekció-csoport lekérdezésből kell szétválogatni a dokumentum
 * **útvonala** alapján (a szülő-dokumentum maga nem is létezik — ezért mérte a
 * korábbi változat 0-nak a jelenlétet).
 */
export function groupByParent(documents) {
  const groups = new Map();
  for (const doc of documents) {
    const path = String(doc.name ?? '').split('/documents/')[1] ?? '';
    const segments = path.split('/');
    if (segments.length < 4) continue;
    const parent = `${segments[0]}/${segments[1]}`;
    const entry = groups.get(parent) ?? [];
    entry.push(doc);
    groups.set(parent, entry);
  }
  return groups;
}

/**
 * Egy **térkép**-mező kulcsai (pl. `likedBy`: `{uid: true, …}`) — különböző értékek.
 *
 * ⚠️ MÉRT ALAK: a lájk nem tömb, hanem **térkép** (`mapValue.fields`) — ezért a
 * tömb-segéd 0-t adott rá (a mérés pontossága itt is a tét).
 */
export function distinctMapKeys(documents, key) {
  const seen = new Set();
  for (const doc of documents) {
    const fields = doc.fields?.[key]?.mapValue?.fields;
    for (const name of Object.keys(fields ?? {})) {
      if (name !== '') seen.add(name);
    }
  }
  return seen.size;
}

/** A dokumentum-útvonal utolsó szakasza (többnyire a felhasználó azonosítója). */
export function lastSegment(doc) {
  const path = String(doc.name ?? '').split('/documents/')[1] ?? '';
  const segments = path.split('/');
  return segments[segments.length - 1] ?? '';
}

/** Napi aktivitás a `daily_activity` dokumentumaiból (dátum → hány felhasználó). */
export function dailyActive(documents) {
  const byDate = new Map();
  for (const doc of documents) {
    const date = String(valueOf(doc.fields?.date) ?? '');
    if (!/^\d{4}-\d{2}-\d{2}/.test(date)) continue;
    const day = date.slice(0, 10);
    byDate.set(day, (byDate.get(day) ?? 0) + 1);
  }
  return [...byDate].sort((a, b) => (a[0] < b[0] ? 1 : -1));
}

/** Összegzés szövege — a lényeg egy képernyőn. */
export function summaryLines({ devices, profiles, favorites, notices, unread }) {
  // ⚠️ Ha az eszközszám nem ismert, a százalék **kimarad** — nem írunk 0%-ot,
  // mert az félrevezetne (az önteszt méri mindkét ágat).
  const profilesLine =
    devices > 0
      ? `közösségi profil:          ${profiles}  (${share(profiles, devices)}% az eszközöknek)`
      : `közösségi profil:          ${profiles}`;
  return [
    `push-eszköz (plugin):      ${devices}`,
    profilesLine,
    `kedvelés (DJ/szervező):    ${favorites}`,
    `értesítés összesen:        ${notices}  (olvasatlan: ${unread})`,
  ];
}

/** A funkció-tábla sorai (mért számokból). */
export function featureLines(rows, limit = 1000) {
  const out = [];
  for (const row of rows) {
    if (row.count === 0 && row.users === 0) continue;
    // ⚠️ A lekérdezés limitje fölött a szám „legalább" — ezt ki is írjuk, mert
    // a csonkolt szám önmagában félrevezetne (a mérés pontossága a tét).
    const count = row.count >= limit ? `${row.count}+` : String(row.count);
    const users = row.users === null
      ? '—'
      : row.count >= limit
        ? `${row.users} (legalább)`
        : String(row.users);
    out.push(
      `  ${row.label.padEnd(30)} ${count.padStart(6)}` + `   különböző felhasználó: ${users}`,
    );
  }
  return out;
}

async function countPath(path, token) {
  let total = 0;
  let pageToken = '';
  do {
    const url =
      `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/${DATABASE}/documents/${path}` +
      `?pageSize=300${pageToken ? `&pageToken=${encodeURIComponent(pageToken)}` : ''}`;
    const response = await fetch(url, { headers: { Authorization: `Bearer ${token}` } });
    const body = await response.json();
    if (!response.ok) throw new Error(`${response.status} — ${body?.error?.message || ''}`);
    total += (body.documents || []).length;
    pageToken = body.nextPageToken || '';
  } while (pageToken);
  return total;
}

async function query(collectionId, allDescendants, token, limit = 1000) {
  const response = await fetch(
    `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/${DATABASE}/documents:runQuery`,
    {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        structuredQuery: {
          from: [{ collectionId, ...(allDescendants ? { allDescendants: true } : {}) }],
          limit,
        },
      }),
    },
  );
  const rows = await response.json();
  if (!Array.isArray(rows)) throw new Error(rows?.error?.message || 'ismeretlen válasz');
  return documentsOf(rows);
}

/**
 * A mért funkciók — [kollekció, alkollekció-e, magyar felirat, felhasználó-számítás].
 *
 * A felhasználó-számítás három módja (mind **mért** séma szerint):
 *   `{ keys: [...] }`  — azonosító mező(k), pl. az értesítés `recipientUid`;
 *   `{ array: 'x' }`   — tömb-mező, pl. a beszélgetés `participantIds`;
 *   `{ map: 'x' }`     — térkép-mező, pl. a lájk `likedBy` (`{uid: true}`);
 *   `null`             — nem értelmezhető (pl. a kedvelés a szülő-profilhoz tartozik)
 *                        → a tábla „—"-t ír, nem 0-t (a 0 félrevezetne).
 */
const DEFAULT_KEYS = { keys: ['uid', 'userId', 'authorId', 'from'] };
const FEATURES = [
  ['event_ratings', false, 'esemény-értékelés (szülő)', DEFAULT_KEYS],
  ['news_reactions', false, 'hír-reakció (lájk)', { map: 'likedBy' }],
  ['article_comments', false, 'cikk-hozzászólás', DEFAULT_KEYS],
  ['voting_votes', false, 'éves szavazat', { keys: ['userId'] }],
  ['game_attempts', false, 'kvíz/játék kitöltés', DEFAULT_KEYS],
  ['live_feed_posts', false, 'közösségi fal bejegyzés', { keys: ['authorId'] }],
  ['connection_requests', false, 'ismerőskérés', { keys: ['from'] }],
  ['connections', false, 'ismerős (elfogadva)', DEFAULT_KEYS],
  ['private_conversations', false, 'privát beszélgetés', { array: 'participantIds' }],
  ['messages', true, 'privát üzenet', { keys: ['senderId'] }],
  ['artist_claims', false, 'DJ-adatlap átvétel', DEFAULT_KEYS],
  ['label_purchase_claims', false, 'zene-vásárlás (claim)', DEFAULT_KEYS],
  ['label_entitlements', false, 'zene-jogosultság', DEFAULT_KEYS],
  ['admob_reward_transactions', false, 'reklám-feloldás', DEFAULT_KEYS],
  ['achievement_ledger', false, 'pont-esemény (achievement)', DEFAULT_KEYS],
  ['favorites', true, 'kedvelés (DJ/szervező/stb.)', null],
  ['notifications', false, 'értesítés (létrejött)', { keys: ['recipientUid'] }],
];

function selfTest() {
  const checks = [];
  const check = (label, ok) => checks.push({ label, ok: Boolean(ok) });
  check('a százalék kerekítve', share(46, 1022) === 4.5);
  check('nullával osztás nem dob', share(5, 0) === 0);
  check('a dokumentumok kiszűrése', documentsOf([{ document: { name: 'a' } }, {}, null]).length === 1);
  check('a mező-érték minden típust kezel', valueOf({ integerValue: '12' }) === '12' && valueOf({}) === null);
  const lines = summaryLines({ devices: 1022, profiles: 46, favorites: 89, notices: 1000, unread: 531 });
  check('az összegzés a lényeget mondja', lines.length === 4 && lines[1].includes('4.5%'));
  const noDevices = summaryLines({ devices: 0, profiles: 46, favorites: 89, notices: 10, unread: 3 });
  check('ismeretlen eszközszámnál nincs félrevezető százalék', !noDevices[1].includes('%'));
  // --- A funkció-mérés új segédei -----------------------------------------
  const docs = [
    { fields: { uid: { stringValue: 'a' } } },
    { fields: { uid: { stringValue: 'a' } } },
    { fields: { userId: { stringValue: 'b' } } },
    { fields: { from: { stringValue: 'c' } } },
    { fields: {} },
  ];
  check('a különböző felhasználók száma helyes (3)', distinctUsers(docs) === 3);
  check('ismeretlen séma esetén 0 (nem tippel)', distinctUsers([{ fields: { x: { stringValue: 'a' } } }]) === 0);
  const days = dailyActive([
    { fields: { date: { stringValue: '2026-09-30' } } },
    { fields: { date: { stringValue: '2026-09-30' } } },
    { fields: { date: { stringValue: '2026-10-01' } } },
    { fields: { date: { stringValue: 'nem-datum' } } },
  ]);
  check('a napi aktivitás dátum szerint csökkenő', days.length === 2 && days[0][0] === '2026-10-01' && days[0][1] === 1);
  const featureRows = featureLines([
    { label: 'x', count: 10, users: 4 },
    { label: 'ures', count: 0, users: 0 },
  ]);
  check('a funkció-tábla a nulla sorokat kihagyja', featureRows.length === 1 && featureRows[0].includes('10'));
  check(
    'a csonkolt (limiten ülő) számot „legalább"-ként írja',
    featureLines([{ label: 'y', count: 1000, users: 12 }], 1000)[0].includes('1000+'),
  );
  check('az ismeretlen felhasználó-mező „—", nem 0', featureLines([{ label: 'z', count: 5, users: null }])[0].includes('—'));
  const reaction = [{ fields: { likedBy: { arrayValue: { values: [{ stringValue: 'a' }, { stringValue: 'b' }, { stringValue: 'a' }] } } } }];
  check('a tömb-mezőből számolt felhasználók (2)', distinctArrayMembers(reaction, 'likedBy') === 2);
  const likeMap = [
    { fields: { likedBy: { mapValue: { fields: { uid1: { booleanValue: true }, uid2: { booleanValue: true } } } } } },
    { fields: { likedBy: { mapValue: { fields: { uid1: { booleanValue: true }, uid3: { booleanValue: true } } } } } },
  ];
  check('a térkép-mezőből számolt felhasználók (3)', distinctMapKeys(likeMap, 'likedBy') === 3);
  check('a tömb-segéd a térkép-alakot nem számolja (0)', distinctArrayMembers(likeMap, 'likedBy') === 0);
  const group = [
    { name: 'projects/p/databases/d/documents/event_attendance/11720/users/uid1', fields: {} },
    { name: 'projects/p/databases/d/documents/event_attendance/12081/users/uid1', fields: {} },
    { name: 'projects/p/databases/d/documents/event_ratings/11720/users/uid2', fields: {} },
  ];
  const groups = groupByParent(group);
  check('az alkollekció-csoport szülő szerint válogat', groups.get('event_attendance/11720').length === 1
    && groups.get('event_attendance/12081').length === 1
    && groups.get('event_ratings/11720').length === 1);
  check('az útvonal utolsó szakasza a felhasználó', lastSegment(group[0]) === 'uid1');
  for (const item of checks) console.log(`${item.ok ? 'OK  ' : 'HIBA'} ${item.label}`);
  const failed = checks.filter((item) => !item.ok).length;
  console.log(`\n${checks.length - failed}/${checks.length} önteszt rendben`);
  return failed ? 1 : 0;
}

if (ARG.includes('--self-test')) {
  process.exitCode = selfTest();
} else {
  const token = await accessToken();
  const profiles = await countPath('community_profiles', token);
  const favorites = (await query('favorites', true, token)).length;
  const notices = await query('notifications', false, token);
  const unread = notices.filter((doc) => !valueOf(doc.fields?.readAt)).length;

  // Az eszközszám a pluginból jön (ott él a token-tár) — a health fejlécből.
  // ⚠️ A fejléc néha nem jön le az első kérésre (mért viselkedés), ezért próbáljuk
  // többször; ha így sem, akkor **kimarad** a sor, nem írunk félrevezető 0%-ot.
  let devices = 0;
  let apiVersion = '';
  for (let attempt = 1; attempt <= 3 && devices === 0; attempt += 1) {
    try {
      const response = await fetch(
        `https://hungarianhardstyle.hu/wp-json/huhs/v1/posts?per_page=1&huhs_diag=huhs-boot-probe-2026&probe=usage-${attempt}`,
        { headers: { Accept: 'application/json', 'Cache-Control': 'no-cache' } },
      );
      const header = response.headers.get('x-huhs-health') || '';
      devices = Number(/push_tokens=(\d+)/.exec(header)?.[1] ?? 0);
      apiVersion = String(/api=(\S+)/.exec(header)?.[1] ?? '');
    } catch (_) {
      devices = 0;
    }
    if (devices === 0) await new Promise((resolve) => setTimeout(resolve, 1200));
  }

  console.log('HASZNÁLAT (Firestore-jelek, mért)\n');
  const lines = summaryLines({
    devices,
    profiles,
    favorites,
    notices: notices.length,
    unread,
  });
  console.log(devices > 0 ? lines.join('\n') : lines.slice(1).join('\n'));
  if (devices === 0) {
    console.log('  (a plugin health fejléc most nem jött le — az eszközszám kimarad)');
  }
  if (apiVersion) console.log(`élő plugin:               ${apiVersion}`);

  // --- Funkció-szintű bontás: mit használnak valójában? --------------------
  const rows = [];
  for (const [collection, allDescendants, label, users] of FEATURES) {
    try {
      const documents = await query(collection, allDescendants, token);
      const users_ = users === null
        ? null
        : users.map
          ? distinctMapKeys(documents, users.map)
          : users.array
            ? distinctArrayMembers(documents, users.array)
            : distinctUsers(documents, users.keys);
      rows.push({ label, count: documents.length, users: users_ });
    } catch (error) {
      rows.push({ label: `${label} (HIBA: ${String(error.message).slice(0, 40)})`, count: 0, users: 0 });
    }
  }

  // A jelenlét és az értékelés a `users` ALKOLLEKCIÓBAN él (a szülő-dokumentum
  // nem is létezik) — ezért kollekció-csoportból, útvonal szerint válogatva.
  try {
    const usersGroup = await query('users', true, token);
    const groups = groupByParent(usersGroup);
    for (const [name, label] of [
      ['event_attendance', 'jelenlét („Ott leszek")'],
      ['event_ratings', 'esemény-értékelés (szavazat)'],
    ]) {
      const documents = [...groups].filter(([parent]) => parent.startsWith(`${name}/`)).flatMap(([, docs]) => docs);
      if (!documents.length) continue;
      const who = new Set(documents.map((doc) => lastSegment(doc)).filter(Boolean));
      const events = new Set(documents.map((doc) => String(doc.name).split('/documents/')[1].split('/')[1]));
      rows.push({
        label: `${label} · ${events.size} esemény`,
        count: documents.length,
        users: who.size,
      });
    }
  } catch (error) {
    rows.push({ label: `jelenlét/értékelés (HIBA: ${String(error.message).slice(0, 40)})`, count: 0, users: 0 });
  }

  console.log('\nMELYIK FUNKCIÓT HASZNÁLJÁK (dokumentum = cselekvés):');
  for (const line of featureLines(rows)) console.log(line);
  console.log(
    '  ⚠️ A „különböző felhasználó" a Firebase-fiókot számolja, ami az **anonim**\n' +
      '     (vendég) felhasználókat is tartalmazza — a regisztrált tagok száma a\n' +
      '     „közösségi profil" sor (fent).',
  );

  // --- Értesítés-áramlás naponta (aktivitás-trend az utolsó napokra) -------
  const noticeDays = new Map();
  for (const doc of notices) {
    const created = String(valueOf(doc.fields?.createdAt) ?? '');
    if (!/^\d{4}-\d{2}-\d{2}/.test(created)) continue;
    const day = created.slice(0, 10);
    noticeDays.set(day, (noticeDays.get(day) ?? 0) + 1);
  }
  if (noticeDays.size) {
    console.log('\nÉRTESÍTÉS-ÁRAMLÁS NAPONTA (az utolsó napok aktivitása):');
    for (const [day, count2] of [...noticeDays].sort((a, b) => (a[0] < b[0] ? 1 : -1)).slice(0, 7)) {
      console.log(`  ${day}: ${count2}`);
    }
  }

  // --- Napi aktivitás ------------------------------------------------------
  try {
    const activity = await query('daily_activity', false, token);
    const days = dailyActive(activity);
    if (days.length) {
      console.log('\nNAPI AKTIVITÁS (daily_activity — hány felhasználónak volt jele aznap):');
      for (const [day, users] of days.slice(0, 7)) console.log(`  ${day}: ${users}`);
    } else {
      console.log('\n(napi aktivitás: nincs dátumozott jel)');
    }
  } catch (error) {
    console.log(`\n(napi aktivitás nem olvasható: ${String(error.message).slice(0, 60)})`);
  }

  // --- Értesítések: típus és olvasottság ----------------------------------
  const byType = new Map();
  for (const doc of notices) {
    const type = String(valueOf(doc.fields?.type) ?? '(nincs)');
    const entry = byType.get(type) ?? { total: 0, read: 0 };
    entry.total += 1;
    if (valueOf(doc.fields?.readAt)) entry.read += 1;
    byType.set(type, entry);
  }
  console.log('\nÉRTESÍTÉSEK TÍPUS SZERINT (olvasott / összes):');
  for (const [type, entry] of [...byType].sort((a, b) => b[1].total - a[1].total).slice(0, 12)) {
    console.log(`  ${type.padEnd(26)} ${entry.read} / ${entry.total}  (${share(entry.read, entry.total)}%)`);
  }

  // --- WordPress-oldali számok (admin API, mért) ---------------------------
  const wpToken = await accessToken().catch(() => '');
  const username = wpToken ? await secretAsync('WORDPRESS_USERNAME', { token: wpToken }).catch(() => '') : '';
  const password = wpToken
    ? await secretAsync('WORDPRESS_APPLICATION_PASSWORD', { token: wpToken }).catch(() => '')
    : '';
  if (username && password) {
    const credentials = Buffer.from(`${username}:${password}`).toString('base64');
    const admin = async (action) => {
      const response = await fetch(
        `https://hungarianhardstyle.hu/wp-json/huhs/v1/admin?action=${action}`,
        { headers: { Authorization: `Basic ${credentials}`, Accept: 'application/json' } },
      );
      return response.ok ? response.json().catch(() => null) : null;
    };
    const polls = await admin('polls');
    const prizes = await admin('prize_games');
    console.log('\nWORDPRESS-OLDALI HASZNÁLAT (admin API):');
    for (const poll of polls?.polls ?? []) {
      console.log(`  kérdőív #${poll.id} (${poll.state}): ${poll.votes} szavazat — ${String(poll.question).slice(0, 50)}`);
    }
    for (const prize of (prizes?.prizes ?? []).slice(0, 5)) {
      console.log(
        `  nyereményjáték #${prize.id} (${prize.state}): ${prize.players} játékos, ${prize.correct} jó válasz — ${String(prize.question).slice(0, 40)}`,
      );
    }
  } else {
    console.log('\n(a WordPress admin jelszó nem olvasható — a WP-oldali számok kimaradnak)');
  }

  console.log(
    '\n⚠️ Az analitika (GA4) kiolvasása külön jogosultságot kér (most 403) — addig ez a\n' +
      '   Firestore-alapú mérés a valódi használat képe: a jelenlét, a szavazat, a játék,\n' +
      '   a reakció és a pont mind a felhasználó cselekvése.',
  );
}
