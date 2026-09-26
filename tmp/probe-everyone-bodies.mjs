#!/usr/bin/env node
/**
 * ÉLES MÉRÉS 3: a `@mindenki` üzenet 44 értesítésének a TÖRZSE — mi a 43 egyforma
 * mellett az 1 eltérő, és mindegyik ugyanarra az üzenetre mutat-e?
 *
 * Csak olvas; UID-et nem ír ki (a recipientUid-ból csak rövid, visszafejthetetlen
 * ujjlenyomatot, ahogy a függvények is teszik).
 *
 * Futtatás: node tmp/probe-everyone-bodies.mjs
 */
import { accessToken, firestoreList, shortHash } from '../tools/lib/live-firebase.mjs';

const token = await accessToken();
const notifications = await firestoreList('notifications', { token });
const postId = process.argv[2] ?? 'RQuJ4iV5YAMtXjkbgUKa';

const forPost = notifications.filter((item) => String(item.targetId || '') === postId);
const groups = new Map();
for (const item of forPost) {
  const key = `${String(item.title || '')} || ${String(item.body || '')}`;
  groups.set(key, (groups.get(key) || 0) + 1);
}

console.log(`a(z) ${postId} üzenethez tartozó értesítések: ${forPost.length}`);
for (const [key, count] of [...groups.entries()].sort((a, b) => b[1] - a[1])) {
  console.log(`\n  ${count} db\n    ${key}`);
}

const recipients = new Set(forPost.map((item) => String(item.recipientUid || '')));
console.log(`\nkülönböző címzett: ${recipients.size}`);
console.log(`címzett-ujjlenyomatok: ${[...recipients].map((uid) => shortHash(uid)).join(', ')}`);

// Kik NEM kaptak? (a profilok és a címzettek összevetése — csak darabszám)
const profiles = await firestoreList('community_profiles', { token, fields: ['displayName'] });
const missing = profiles.filter((profile) => !recipients.has(profile.id));
console.log(`\nprofilok: ${profiles.length}; ebből NEM kapott értesítést: ${missing.length}`);
console.log(
  `a kimaradók neve: ${missing.map((profile) => String(profile.displayName || '(névtelen)')).join(', ')}`,
);
