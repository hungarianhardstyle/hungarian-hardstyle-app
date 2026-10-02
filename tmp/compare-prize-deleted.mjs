// ÖSSZEVETÉS: kik vannak a nyereményjátékban úgy, hogy közben törölték a regisztrációjukat?
//
// A tulajdonos jelzése (2026-10-02): *„most is vannak olyanok a nyereményjátékban
// akik törölték a reget, vessd össze”*.
//
// MIÉRT lehet így mérni: a WordPress `/prize/participants` végpontja (amit a
// sorsoló függvény is használ) **application password-del** kiszolgálja a
// játékosokat a `uid`-dal együtt, a Firestore-ban pedig ott a
// `deleted_user_ids` gyűjtemény — a kettő metszete pontosan a kért lista.
//
// Csak olvasás. Használat: node tmp/compare-prize-deleted.mjs
import { accessToken, firestoreList, secretAsync } from '../tools/lib/live-firebase.mjs';

const WORDPRESS_BASE_URL = 'https://hungarianhardstyle.hu/wp-json/huhs/v1';

const token = await accessToken();
const username = await secretAsync('WORDPRESS_USERNAME', { token });
const password = await secretAsync('WORDPRESS_APPLICATION_PASSWORD', { token });
if (!username || !password) {
  console.log('HIBA  nincs WordPress hitelesítő adat a Secret Managerben');
  process.exit(2);
}
const authorization = `Basic ${Buffer.from(`${username}:${password}`).toString('base64')}`;

const getJson = async (path) => {
  const response = await fetch(`${WORDPRESS_BASE_URL}${path}`, {
    headers: { Authorization: authorization, Accept: 'application/json' },
  });
  const payload = await response.json().catch(() => ({}));
  return { status: response.status, payload };
};

// 1) A játékok: a most látszó (`/prize/active`) és a lezárt, de még nem sorsolt
//    játékok (`/prize/pending`) — a kettő együtt fedi, amiben bárki is lehet.
const active = await getJson('/prize/active');
const pending = await getJson('/prize/pending');
console.log(`aktív játék: HTTP ${active.status} — ${active.payload?.prize?.question ?? active.payload?.question ?? '(nincs)'}`);
console.log(`lezárt/sorsolásra váró: HTTP ${pending.status}`);

const prizes = [];
const pushPrize = (candidate) => {
  const id = Number(candidate?.id ?? candidate?.prizeId ?? 0);
  if (!Number.isInteger(id) || id < 1) return;
  if (prizes.some((entry) => entry.id === id)) return;
  prizes.push({ id, question: String(candidate?.question ?? candidate?.title ?? '') });
};
pushPrize(active.payload?.prize ?? active.payload);
for (const item of Array.isArray(pending.payload?.prizes) ? pending.payload.prizes : []) {
  pushPrize(item);
}
if (!prizes.length) {
  console.log('\nNem találtam játékot — a végpont válaszát érdemes megnézni:');
  console.log(JSON.stringify(active.payload).slice(0, 300));
  process.exit(2);
}

// 2) A törölt fiókok.
const deleted = await firestoreList('deleted_user_ids', { fields: ['deletedAt'], token, max: 5000 });
const deletedUids = new Set(deleted.map((doc) => doc.id));
console.log(`\ntörölt fiók a Firestore-ban: ${deletedUids.size}`);

// 3) A metszet játékonként.
let totalPlayers = 0;
let totalDeleted = 0;
const deletedInGame = [];
for (const prize of prizes) {
  const participants = await getJson(`/prize/participants?prizeId=${prize.id}`);
  const players = Array.isArray(participants.payload?.players) ? participants.payload.players : [];
  totalPlayers += players.length;
  const hits = players.filter((player) => deletedUids.has(String(player.uid || '').trim()));
  totalDeleted += hits.length;
  for (const hit of hits) {
    const uid = String(hit.uid || '').trim();
    if (uid && !deletedInGame.includes(uid)) deletedInGame.push(uid);
  }
  console.log(
    `\n#${prize.id} ${prize.question || '(cím nélkül)'}\n` +
      `  játékos: ${players.length}, ebből TÖRÖLT REGISZTRÁCIÓJÚ: ${hits.length}`,
  );
  for (const hit of hits) {
    console.log(`    - ${String(hit.name || '(név nélkül)')}  uid=${String(hit.uid).slice(0, 8)}…`);
  }
}

console.log(`\nÖSSZESEN: ${totalPlayers} játékos, ebből ${totalDeleted} törölt regisztrációjú.`);

// `--remove`: a találatok TÖRLÉSE a nyereményjátékból (a plugin 2.14.18
// `prize_forget` műveletével — a sózott hash miatt csak a WordPress tudja).
if (process.argv.includes('--remove') && totalDeleted > 0) {
  let forgotten = 0;
  let winners = 0;
  for (const uid of deletedInGame) {
    const response = await fetch(`${WORDPRESS_BASE_URL}/admin`, {
      method: 'POST',
      headers: {
        Authorization: authorization,
        'Content-Type': 'application/json',
        Accept: 'application/json',
      },
      body: JSON.stringify({ action: 'prize_forget', uid }),
    });
    const payload = await response.json().catch(() => ({}));
    if (response.ok) {
      forgotten += Number(payload?.forgotten) || 0;
      winners += Number(payload?.winnersCleared) || 0;
      console.log(`  törölve: ${String(uid).slice(0, 8)}… → forgotten=${payload?.forgotten} winners=${payload?.winnersCleared}`);
    } else {
      console.log(`  HIBA: ${String(uid).slice(0, 8)}… → HTTP ${response.status} ${payload?.message || ''}`);
    }
  }
  console.log(`\nnyereményjátékból törölve: ${forgotten} bejegyzés, ${winners} nyertes-jelölés`);
} else if (totalDeleted > 0) {
  console.log(
    'A kivételhez a plugin 2.14.18 kell (a `prize_forget` művelet), utána a fióktörlés\n' +
      'automatikusan kiveszi őket — és a sorsoló függvény már most kihagyja a törölteket.',
  );
}
process.exitCode = 0;
