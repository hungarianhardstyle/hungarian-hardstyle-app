#!/usr/bin/env node
/**
 * ÉLES (csak olvas): a Chat-értesítésekben megjelölt üzenet **elérhető-e** az
 * odaugráshoz?
 *
 * MIÉRT: a tulajdonos jelzése (2026-09-25): *„egy régebbi chat like, update
 * előtti, rányomtam és nem dobott a chat üzire … régebbi chat üzivel nem megy,
 * újabba igen"*. Az odaugrás az élő ablakból (legfrissebb **60**) indul, és
 * legfeljebb **10 lapot** (10 × 30 = **300**) lapoz — ezért a kérdés az, hogy a
 * megjelölt üzenet **hányadik** a legfrissebbek sorában. Ez az eszköz ezt
 * számolja ki minden chat-értesítésre: rang = hány üzenet van nála frissebb.
 *
 * UID-et nem ír ki. Futtatás: node tools/check-chat-focus-reach.mjs
 */
import { accessToken, firestoreList } from './lib/live-firebase.mjs';

/** Az élő ablak mérete (a kliensben: `watchPosts().limit(60)`). */
export const liveWindow = 60;
/** A lapozás: ennyi lap, laponként ennyi üzenet (kliens: 10 × 30). */
export const focusMaxPages = 10;
export const focusPageSize = 30;
export const maxReach = focusMaxPages * focusPageSize;

const timeOf = (raw) => {
  if (!raw) return 0;
  if (typeof raw === 'string') return Date.parse(raw) || 0;
  if (typeof raw === 'object' && raw.seconds) return raw.seconds * 1000;
  return 0;
};

/** Rang (1 = a legfrissebb) minden üzenetre, a createdAt szerint csökkenőben. */
export function rankMap(posts) {
  const sorted = [...posts].sort((a, b) => timeOf(b.createdAt) - timeOf(a.createdAt));
  const map = new Map();
  sorted.forEach((post, index) => map.set(String(post.id), index + 1));
  return map;
}

/**
 * Egy értesítés elérhetősége.
 *  - `live`: az élő ablakban van (azonnal megtalálható)
 *  - `paged`: lapozással elérhető (a 10 lapos kereten belül)
 *  - `beyond`: a kereten kívül van (ennél többet nem lapozunk)
 *  - `missing`: a megjelölt üzenet már nincs az adatbázisban (törölték)
 */
export function reachability({ rank, live = liveWindow, reach = maxReach }) {
  if (!rank) return 'missing';
  if (rank <= live) return 'live';
  if (rank <= live + reach) return 'paged';
  return 'beyond';
}

export function summarize(notifications, posts) {
  const ranks = rankMap(posts);
  const rows = [];
  for (const notification of notifications) {
    const type = String(notification.type || '');
    if (type !== 'chat_reaction' && type !== 'chat_reply' && type !== 'chat_mention') continue;
    const targetId = String(notification.targetId || '').trim();
    const rank = ranks.get(targetId) || 0;
    rows.push({
      type,
      at: new Date(timeOf(notification.createdAt)).toISOString(),
      target: targetId ? `${targetId.slice(0, 8)}…` : '(nincs célpont)',
      rank,
      reach: reachability({ rank }),
    });
  }
  rows.sort((a, b) => a.rank - b.rank);
  return rows;
}

export function selfTest() {
  const checks = [];
  const check = (label, ok) => checks.push({ label, ok });
  const posts = [
    { id: 'd', createdAt: { seconds: 400 } },
    { id: 'a', createdAt: { seconds: 100 } },
    { id: 'c', createdAt: { seconds: 300 } },
    { id: 'b', createdAt: { seconds: 200 } },
  ];
  const ranks = rankMap(posts);
  check('a legfrissebb aze 1-es rang', ranks.get('d') === 1);
  check('a legrégebbi aze 4-es rang', ranks.get('a') === 4);
  check('az élő ablakon belül live', reachability({ rank: 10 }) === 'live');
  check('a keret végén még paged', reachability({ rank: 360 }) === 'paged');
  check('a kereten túl beyond', reachability({ rank: 361 }) === 'beyond');
  check('hiányzó üzenet missing', reachability({ rank: 0 }) === 'missing');
  const rows = summarize(
    [
      { type: 'chat_reaction', targetId: 'a', createdAt: { seconds: 1 } },
      { type: 'chat_reaction', targetId: 'zzz', createdAt: { seconds: 2 } },
      { type: 'new_news', targetId: 'd', createdAt: { seconds: 3 } },
    ],
    posts,
  );
  check('csak a chat-típusokat nézi', rows.length === 2);
  check('a törölt üzenetet missingnek jelöli', rows.some((row) => row.reach === 'missing'));
  check('a rang szerint rendez', rows[0].rank <= rows[rows.length - 1].rank);
  return checks;
}

async function main() {
  if (process.argv.includes('--self-test')) {
    const checks = selfTest();
    for (const check of checks) console.log(`${check.ok ? 'OK  ' : 'HIBA'} ${check.label}`);
    const failed = checks.filter((check) => !check.ok).length;
    console.log(`\n${checks.length - failed}/${checks.length} önteszt rendben`);
    return failed ? 1 : 0;
  }
  const token = await accessToken();
  const posts = await firestoreList('live_feed_posts', { token, max: 5000 });
  const notifications = await firestoreList('notifications', { token, max: 3000 });
  const rows = summarize(notifications, posts);
  console.log(`élő ablak: ${liveWindow}, lapozás: ${focusMaxPages} × ${focusPageSize} = ${maxReach}`);
  console.log(`chat-üzenetek: ${posts.length}, chat-értesítések: ${rows.length}\n`);
  const counts = { live: 0, paged: 0, beyond: 0, missing: 0 };
  for (const row of rows) {
    counts[row.reach] += 1;
    console.log(
      `  ${row.reach.padEnd(7)} rang=${String(row.rank).padStart(4)}  ${row.type}  ${row.at}  cél=${row.target}`,
    );
  }
  console.log(
    `\nösszegzés: élő ablakban ${counts.live}, lapozással elérhető ${counts.paged}, ` +
      `kereten túl ${counts.beyond}, hiányzik ${counts.missing}`,
  );
  return 0;
}

main()
  .then((code) => {
    process.exitCode = code;
  })
  .catch((error) => {
    console.error(`HIBA: ${error.message}`);
    process.exitCode = 2;
  });
