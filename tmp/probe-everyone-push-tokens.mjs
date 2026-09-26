#!/usr/bin/env node
/**
 * ÉLES MÉRÉS 4: a `@mindenki` 44 címzettje közül **kinek van push-tokenje** — egy
 * esetleges push bevezetéséhez ez a döntő adat (különben a push elveszne).
 *
 * Azt is méri, hány címzettnél van **kikapcsolva** az értesítés
 * (`notificationPreferences.enabled === false`) — a push-nak ezt tisztelnie kell.
 *
 * Csak olvas; UID-et nem ír ki (csak darabszámot).
 *
 * Futtatás: node tmp/probe-everyone-push-tokens.mjs
 */
import { accessToken, firestoreList, firestoreGet } from '../tools/lib/live-firebase.mjs';

const token = await accessToken();
const postId = process.argv[2] ?? 'RQuJ4iV5YAMtXjkbgUKa';

const notifications = await firestoreList('notifications', { token, fields: ['targetId', 'recipientUid'] });
const recipients = [
  ...new Set(
    notifications
      .filter((item) => String(item.targetId || '') === postId)
      .map((item) => String(item.recipientUid || ''))
      .filter(Boolean),
  ),
];
console.log(`a(z) ${postId} üzenet címzettjei: ${recipients.length}`);

let withTokens = 0;
let withoutTokens = 0;
let disabled = 0;
let profilesWithLegacyToken = 0;

for (const uid of recipients) {
  const privateData = (await firestoreGet(`private_user_data/${uid}`, { token })) || {};
  const tokens = [privateData.fcmTokens, privateData.fcmToken]
    .flatMap((raw) =>
      Array.isArray(raw) ? raw : raw && typeof raw === 'object' ? Object.values(raw) : raw ? [raw] : [],
    )
    .filter((value) => typeof value === 'string' && value.trim());
  if (tokens.length) withTokens += 1;
  else withoutTokens += 1;

  const preferences = privateData.notificationPreferences || {};
  if (preferences.enabled === false) disabled += 1;
}

// A régi (profilban tárolt) token is számít, mert a `getPushTokens()` azt is olvassa.
const profiles = await firestoreList('community_profiles', { token, fields: ['fcmToken', 'fcmTokens'] });
const legacy = profiles.filter(
  (profile) => recipients.includes(profile.id)
    && (profile.fcmToken || (Array.isArray(profile.fcmTokens) && profile.fcmTokens.length)),
);
profilesWithLegacyToken = legacy.length;

console.log(`\npush-token a private_user_data-ban: ${withTokens} címzettnél VAN, ${withoutTokens}-nál nincs`);
console.log(`a profilban (régi hely) is van token: ${profilesWithLegacyToken} címzettnél`);
console.log(`kikapcsolt értesítés (notificationPreferences.enabled === false): ${disabled}`);
