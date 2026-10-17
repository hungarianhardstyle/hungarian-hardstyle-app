#!/usr/bin/env node
// A Chat legfrissebb üzenetei — a VALÓDI mezőnevekkel, hogy a @mindenki
// üzenetek közül a legutolsót tudjuk kiválasztani (időbélyeg szerint).
import { accessToken, firestoreList } from '../tools/lib/live-firebase.mjs';

const token = await accessToken();
const posts = await firestoreList('live_feed_posts', {
  fields: ['authorId', 'authorName', 'text', 'createdAt', 'createdAtMs', 'timestamp', 'mentions', 'deleted'],
  token,
  max: 200,
});

console.log(`összes betöltött üzenet: ${posts.length}`);
console.log('egy minta dokumentum kulcsai:', Object.keys(posts[0] || {}).join(', '));
console.log('');

/** Időbélyeg → ms (több lehetséges alak: szám, ISO szöveg, {seconds}/{_seconds}). */
function millis(value) {
  if (value == null) return 0;
  if (typeof value === 'number') return value > 1e12 ? value : value * 1000;
  if (typeof value === 'string') {
    const parsed = Date.parse(value);
    return Number.isNaN(parsed) ? 0 : parsed;
  }
  if (typeof value === 'object') {
    const seconds = value.seconds ?? value._seconds ?? value.secondsValue;
    if (typeof seconds === 'number') return seconds * 1000;
  }
  return 0;
}

const isEveryone = (entry) =>
  Array.isArray(entry.mentions) && entry.mentions.some((mention) => mention && mention.type === 'everyone');

const withTime = posts.map((entry) => ({
  id: entry.id,
  author: String(entry.authorName || entry.authorId || '?'),
  text: String(entry.text || '').replace(/\s+/g, ' ').slice(0, 70),
  ms: millis(entry.createdAt ?? entry.createdAtMs ?? entry.timestamp),
  everyone: isEveryone(entry),
}));
withTime.sort((a, b) => b.ms - a.ms);

console.log('A 12 LEGFRISSEBB üzenet (idő szerint csökkenő):');
for (const entry of withTime.slice(0, 12)) {
  const at = entry.ms ? new Date(entry.ms).toISOString() : '(nincs idő)';
  console.log(`  ${at}  ${entry.everyone ? '@MINDENKI' : '         '}  ${entry.author}: ${entry.text}`);
}
const everyone = withTime.filter((entry) => entry.everyone);
console.log(`\n@mindenki üzenetek: ${everyone.length}`);
if (everyone.length) {
  const newest = everyone[0];
  console.log(`LEGFRISSEBB @MINDENKI: id=${newest.id}  idő=${newest.ms ? new Date(newest.ms).toISOString() : '?'}`);
  console.log(`  ${newest.author}: ${newest.text}`);
}
