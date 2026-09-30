// ÉLES, SZÁRAZ MÉRÉS: mit tenne a 2.14.11 felhordása után a szavazás/játék push?
//
// A kérdés nem elméleti: a frissességi kapu (6 óra) azért van, hogy a feltöltés
// pillanatában a RÉGI, régen megnyílt tartalom NE hirdetődjön meg. Ez a szonda
// a nyilvános végpontokról megmutatja, JELENLEG mi nyitott, és mikor nyílt meg —
// abból pedig kiszámolható, hogy a feltöltés után kimenne-e értesítés, vagy sem.
//
// Csak olvas: GET kérések a nyilvános API-ra, semmit nem ír és nem küld.
import { setTimeout as delay } from 'node:timers/promises';

const BASE = 'https://hungarianhardstyle.hu/wp-json/huhs/v1';
const HOUR = 3600 * 1000;

async function get(path) {
  const response = await fetch(`${BASE}${path}`, {
    headers: { accept: 'application/json' },
  });
  const text = await response.text();
  let json = null;
  try {
    json = JSON.parse(text);
  } catch {
    json = null;
  }
  return { status: response.status, json, text: text.slice(0, 160) };
}

/** A szerver `Y-m-d\TH:i` helyi falióráját értelmezzük (nyár +2 / tél +1 óra). */
function localClockToEpoch(raw) {
  const match = /^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2})/.exec(String(raw ?? '').trim());
  if (!match) return 0;
  const [, y, mo, d, h, mi] = match;
  const asUtc = Date.UTC(Number(y), Number(mo) - 1, Number(d), Number(h), Number(mi));
  // Két jelölt (CET/CEST), és amelyik visszaadja ugyanazt a faliórát, az a helyes.
  for (const offsetHours of [2, 1]) {
    const candidate = asUtc - offsetHours * HOUR;
    const back = new Date(candidate + offsetHours * HOUR);
    if (back.getUTCHours() === Number(h) && back.getUTCMinutes() === Number(mi)) {
      // A nyári időszámítás azt jelenti, hogy az adott pillanatban tényleg +2 óra van.
      const inSummer = isSummerTime(candidate);
      if (inSummer === (offsetHours === 2)) return candidate;
    }
  }
  return asUtc - 2 * HOUR;
}

function isSummerTime(epochMs) {
  const year = new Date(epochMs).getUTCFullYear();
  const lastSundayMarch = lastSundayUtc(year, 2); // március (0-alapú: 2)
  const lastSundayOctober = lastSundayUtc(year, 9); // október
  const start = Date.UTC(lastSundayMarch.getUTCFullYear(), 2, lastSundayMarch.getUTCDate(), 1, 0);
  const end = Date.UTC(lastSundayOctober.getUTCFullYear(), 9, lastSundayOctober.getUTCDate(), 1, 0);
  return epochMs >= start && epochMs < end;
}

function lastSundayUtc(year, monthIndex) {
  const date = new Date(Date.UTC(year, monthIndex + 1, 0));
  date.setUTCDate(date.getUTCDate() - date.getUTCDay());
  return date;
}

function describe(label, rawStart, rawEnd, extra = {}) {
  const start = localClockToEpoch(rawStart);
  const end = localClockToEpoch(rawEnd);
  const now = Date.now();
  const open = (!start || start <= now) && (!end || end >= now);
  const ageHours = start ? (now - start) / HOUR : null;
  const wouldPush = open && (ageHours === null || ageHours <= 6) && extra.enabled !== false;
  console.log(`\n${label}`);
  console.log(`  kezdés: ${rawStart || '(nincs)'}  zárás: ${rawEnd || '(nincs)'}`);
  console.log(`  állapot: ${open ? 'NYITOTT' : 'nem nyitott'}${extra.enabled === false ? ' (kikapcsolva)' : ''}`);
  if (ageHours !== null) {
    console.log(`  megnyílt: ${ageHours >= 0 ? `${ageHours.toFixed(1)} órával ezelőtt` : `${(-ageHours).toFixed(1)} óra múlva`}`);
  }
  console.log(`  feltöltés utáni push: ${wouldPush ? 'KIMENNE (friss)' : 'NEM menne ki'}`);
  return { open, wouldPush };
}

const results = {};

const poll = await get('/poll/active');
results.poll = poll.status === 200 && poll.json && poll.json.id
  ? describe(`KÉRDŐÍV (#${poll.json.id})`, poll.json.start, poll.json.end)
  : (console.log(`\nKÉRDŐÍV: nincs nyitott (HTTP ${poll.status})`), { open: false, wouldPush: false });

await delay(300);
const prize = await get('/prize/active');
results.prize = prize.status === 200 && prize.json && prize.json.id
  ? describe(`NYEREMÉNYJÁTÉK (#${prize.json.id})`, prize.json.start, prize.json.end)
  : (console.log(`\nNYEREMÉNYJÁTÉK: nincs nyitott (HTTP ${prize.status})`), { open: false, wouldPush: false });

await delay(300);
const vote = await get('/voting/active');
if (vote.status === 200 && vote.json) {
  const payload = vote.json;
  results.vote = describe(
    `ÉVES SZAVAZÁS (${payload.year ?? '?'}, #${payload.seasonId ?? '?'})`,
    payload.start,
    payload.end,
    { enabled: payload.active !== false },
  );
} else {
  console.log(`\nÉVES SZAVAZÁS: nincs aktív szezon (HTTP ${vote.status})`);
  results.vote = { open: false, wouldPush: false };
}

await delay(300);
const game = await get('/games/active');
if (game.status === 200 && game.json && (game.json.id || game.json.gameId)) {
  const payload = game.json;
  results.game = describe(
    `GYÍK-JÁTÉK (#${payload.id ?? payload.gameId})`,
    payload.start,
    payload.end,
  );
} else {
  console.log(`\nGYÍK-JÁTÉK: nincs aktív játék (HTTP ${game.status})`);
  results.game = { open: false, wouldPush: false };
}

const wouldPush = Object.values(results).filter((entry) => entry.wouldPush).length;
console.log(`\nÖSSZEGEZVE: ${wouldPush} értesítés menne ki azonnal a 2.14.11 feltöltésekor.`);
console.log(wouldPush === 0
  ? 'Ez a helyes eredmény: a feltöltés önmagában SENKIT nem értesít (nincs frissen nyitott tartalom).'
  : 'FIGYELEM: a feltöltés után azonnal menne ki értesítés — ez csak akkor helyes, ha a tartalom tényleg most nyílt meg.');
