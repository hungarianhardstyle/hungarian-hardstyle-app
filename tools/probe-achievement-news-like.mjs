/**
 * Csak olvaso proba: működik-e a hir-lajkolas napi achievement korlata?
 *
 * A tulajdonos jelzese: „hir lajkolassal ne lehessen achievement pontokat
 * farmolni, eddig volt benne valami tiltas, hogy max napi 3 hir lajkolasert
 * jar achi egy usernek, most mintha nem így működne".
 *
 * A szerveroldali korlat a `awardAchievementPoints()`-ban van:
 *   - `achievement_news_like_limits/<uid>_<YYYY-MM-DD>` szamlalo, 5/fo/nap;
 *   - a `achievement_ledger` sor a `<uid>:news-like:<postId>:grant` kulcsbol.
 *
 * Ez a szkript MEGMÉRI, nem feltetelez:
 *   1. keletkeztek-e egyaltalan `news-like:` ledger sorok (fut-e a trigger);
 *   2. leteznek-e napi limit dokumentumok, es mennyi a legnagyobb `count`;
 *   3. hany felhasznalo erte el a plafont (ez bizonyitja, hogy a korlat fog).
 *
 * Futtatas: node tools/probe-achievement-news-like.mjs
 * Csak OLVAS. Nem ir semmit.
 */

import { initializeApp, getApps } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

const app = getApps().length ? getApps()[0] : initializeApp();
const db = getFirestore(app, 'hungarian-hardstyle');

function newsLikeKeyOf(entry) {
  const key = String(entry?.sourceKey || '');
  return key.startsWith('news-like:') ? key : null;
}

async function main() {
  const [ledgerSnapshot, limitSnapshot] = await Promise.all([
    db.collection('achievement_ledger').get(),
    db.collection('achievement_news_like_limits').get(),
  ]);

  const newsLikeEntries = [];
  for (const document of ledgerSnapshot.docs) {
    const entry = document.data() || {};
    const key = newsLikeKeyOf(entry);
    if (!key) continue;
    newsLikeEntries.push({
      uid: String(entry.uid || ''),
      key,
      delta: Number(entry.delta || 0),
      postId: key.slice('news-like:'.length),
    });
  }

  const grants = newsLikeEntries.filter((entry) => entry.delta > 0);
  const revokes = newsLikeEntries.filter((entry) => entry.delta < 0);
  const distinctUsers = new Set(grants.map((entry) => entry.uid));

  console.log('--- news-like ledger sorok ---');
  console.log(`osszes ledger sor:      ${ledgerSnapshot.size}`);
  console.log(`news-like grant ( +2 ): ${grants.length}`);
  console.log(`news-like revoke ( -2 ): ${revokes.length}`);
  console.log(`erintett felhasznalo:   ${distinctUsers.size}`);

  const perUser = new Map();
  for (const grant of grants) {
    perUser.set(grant.uid, (perUser.get(grant.uid) || 0) + 1);
  }
  const busiest = [...perUser.entries()].sort((a, b) => b[1] - a[1]).slice(0, 8);
  console.log('\n--- legtobb news-like grant egy felhasznalonál (osszesen, nem naponta) ---');
  for (const [uid, count] of busiest) {
    console.log(`${uid.slice(0, 8)}…  ${count}`);
  }

  console.log('\n--- napi limit dokumentumok (achievement_news_like_limits) ---');
  console.log(`dokumentumok: ${limitSnapshot.size}`);
  const counters = [];
  for (const document of limitSnapshot.docs) {
    const data = document.data() || {};
    counters.push({
      id: document.id,
      uid: String(data.uid || document.id.split('_')[0] || ''),
      date: String(data.date || ''),
      count: Number(data.count || 0),
    });
  }
  counters.sort((a, b) => b.count - a.count);
  for (const counter of counters.slice(0, 12)) {
    console.log(`${counter.date}  ${counter.uid.slice(0, 8)}…  count=${counter.count}`);
  }

  const atCapOrAbove = counters.filter((counter) => counter.count >= 5);
  const atThree = counters.filter((counter) => counter.count >= 3);
  console.log('\n--- kovetkeztetes ---');
  console.log(`napok szama, amikor valaki elerte a 3-at: ${atThree.length}`);
  console.log(`napok szama, amikor valaki elerte az 5-ot: ${atCapOrAbove.length}`);
  if (!limitSnapshot.size) {
    console.log('FIGYELEM: egyetlen napi limit dokumentum sincs -> a korlat NEM irja a szamlalot.');
  } else if (!atThree.length) {
    console.log('A szamlalok leteznek, de senki nem erte el a 3-at -> a korlat meg nem bizonyított.');
  } else {
    console.log('A napi szamlalo mukodik, es legalabb egy felhasznalo elerte a plafont.');
  }
}

main().catch((error) => {
  console.error('probe failed:', error?.message || error);
  process.exitCode = 1;
});
