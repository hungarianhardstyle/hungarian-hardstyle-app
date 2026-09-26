#!/usr/bin/env node
/**
 * ÉLES MÉRÉS: mi történik a `@mindenki` hivatkozással a Chatben?
 *
 * A tulajdonos jelzése (2026-09-26): *„ja a @mindenki tag nem működik, nem küld
 * notifyt"*. Két lehetséges ok, és NEM tippelünk — a valódi adatból mérjük:
 *   A) a kliens **nem küldte el** a `mentions` mezőt (mert a felhasználó beírta a
 *      `@mindenki` szöveget, de nem a javaslatból választotta) → a szerver nem is
 *      tud róla, senkit nem értesít;
 *   B) a szerver **kihagyta** (a küldő `accessRole`-ja nem admin/moderátor).
 *
 * Ez a szonda csak olvas (`live_feed_posts`, `community_profiles`) — UID-et nem ír ki.
 *
 * Futtatás: node tmp/probe-everyone-mention.mjs
 */
import { accessToken, firestoreList } from '../tools/lib/live-firebase.mjs';

const token = await accessToken();

const posts = await firestoreList('live_feed_posts', { token });
const withTag = posts.filter((post) =>
  String(post.text || '').toLowerCase().includes('@mindenki'),
);

console.log(`live_feed_posts: ${posts.length} dokumentum, ebből @mindenki a szövegben: ${withTag.length}`);

const sorted = withTag
  .map((post) => ({
    id: post.id,
    authorName: String(post.authorName || ''),
    authorAccessRole: String(post.authorAccessRole || '(nincs mező)'),
    createdAt: String(post.createdAt || ''),
    text: String(post.text || '').replace(/\s+/g, ' ').slice(0, 80),
    mentions: Array.isArray(post.mentions) ? post.mentions.map((m) => `${m?.type}:${m?.id}`) : null,
  }))
  .sort((a, b) => String(a.createdAt).localeCompare(String(b.createdAt)));

for (const post of sorted.slice(-8)) {
  console.log(
    `\n  ${post.createdAt}\n    szerző: ${post.authorName} (accessRole: ${post.authorAccessRole})`
    + `\n    szöveg: ${post.text}`
    + `\n    mentions: ${post.mentions === null ? 'NINCS mező' : JSON.stringify(post.mentions)}`,
  );
}

const withEveryone = sorted.filter((post) => (post.mentions || []).some((m) => m.startsWith('everyone')));
console.log(
  `\nÖSSZEGZÉS: @mindenki a szövegben ${sorted.length} üzenetben;`
  + ` ebből a mentions mezőben is ott van: ${withEveryone.length}`,
);

// A szerepkör-eloszlás (a 2. ok méréséhez) — UID nélkül.
const profiles = await firestoreList('community_profiles', { token, fields: ['accessRole', 'role', 'displayName'] });
const byAccessRole = {};
for (const profile of profiles) {
  const key = String(profile.accessRole || '(nincs)');
  byAccessRole[key] = (byAccessRole[key] || 0) + 1;
}
console.log(`\ncommunity_profiles: ${profiles.length} profil`);
console.log(`accessRole szerint: ${JSON.stringify(byAccessRole)}`);
