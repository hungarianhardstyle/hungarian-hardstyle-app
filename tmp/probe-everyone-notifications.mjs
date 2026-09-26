#!/usr/bin/env node
/**
 * ÉLES MÉRÉS 2: a `@mindenki` üzenethez **keletkeztek-e** értesítések?
 *
 * Az első mérés (2026-09-26) szerint a `live_feed_posts` dokumentumban **ott van**
 * a `mentions: ["everyone:everyone"]` — vagyis a kliens elküldte, a szerver
 * elfogadta (a szerző `accessRole = admin`). Ezért a kérdés most az: a FAN-OUT
 * **írt-e** értesítéseket, és ha nem, mi hiúsult meg.
 *
 * Csak olvas; UID-et nem ír ki (csak darabszámot).
 *
 * Futtatás: node tmp/probe-everyone-notifications.mjs
 */
import { accessToken, firestoreList } from '../tools/lib/live-firebase.mjs';

const token = await accessToken();

const posts = await firestoreList('live_feed_posts', { token });
const post = posts.find((item) => String(item.text || '').toLowerCase().includes('@mindenki'));
if (!post) {
  console.log('nincs @mindenki üzenet');
  process.exit(1);
}
console.log(`a vizsgált üzenet: ${post.id} (${post.createdAt})`);
console.log(`mentions: ${JSON.stringify(post.mentions)}`);

const notifications = await firestoreList('notifications', { token });
console.log(`\nnotifications: ${notifications.length} dokumentum összesen`);

const forPost = notifications.filter((item) => String(item.targetId || '') === post.id);
console.log(`ehhez az üzenethez (targetId = a chat-üzenet): ${forPost.length}`);

const byType = {};
for (const item of forPost) {
  const key = String(item.type || '(nincs)');
  byType[key] = (byType[key] || 0) + 1;
}
console.log(`típus szerint: ${JSON.stringify(byType)}`);

const everyoneBodies = forPost.filter((item) =>
  String(item.body || '').includes('mindenkit megemlített'),
);
console.log(`„mindenkit megemlített" törzzsel: ${everyoneBodies.length}`);

if (everyoneBodies.length) {
  const sample = everyoneBodies[0];
  console.log(`\npélda: title=«${sample.title}» body=«${String(sample.body).slice(0, 90)}»`);
  console.log(`kind mező: ${sample.kind === undefined ? '(nincs)' : JSON.stringify(sample.kind)}`);
  console.log(`createdAt: ${sample.createdAt}`);
}

// A teljes kép: az utolsó 24 óra chat-értesítései (típus szerint).
const recent = notifications.filter((item) => {
  const created = Date.parse(String(item.createdAt || ''));
  return Number.isFinite(created) && Date.now() - created < 24 * 3600 * 1000;
});
const recentByType = {};
for (const item of recent) {
  const key = String(item.type || '(nincs)');
  recentByType[key] = (recentByType[key] || 0) + 1;
}
console.log(`\naz elmúlt 24 óra értesítései típus szerint: ${JSON.stringify(recentByType)}`);
console.log(`az elmúlt 24 óra összesen: ${recent.length}`);
