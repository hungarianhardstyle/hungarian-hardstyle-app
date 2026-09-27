#!/usr/bin/env node
/**
 * **ÉLES ellenőrzés telepítés után** (csak olvas):
 *   1. a kiadott Firestore-szabály tartalmazza-e a `moderation_flags` blokkot;
 *   2. a két új függvény létezik-e (a Cloud Functions listából).
 *
 * Használat: node tmp/verify-deployed-376.mjs
 */
import { accessToken, PROJECT, firestoreGet } from '../tools/lib/live-firebase.mjs';

const token = await accessToken();
let failures = 0;
const check = (label, ok, detail = '') => {
  if (!ok) failures += 1;
  console.log(`  ${ok ? 'OK  ' : 'HIBA'} ${label}${detail ? ` — ${detail}` : ''}`);
};

/* --- 1. A kiadott szabályok ------------------------------------------- */

const releases = await fetch(
  `https://firebaserules.googleapis.com/v1/projects/${PROJECT}/releases`,
  { headers: { Authorization: `Bearer ${token}` } },
).then((response) => response.json());
const firestoreRelease = (releases.releases || [])
  .filter((entry) => String(entry.name || '').includes('cloud.firestore'))
  // ⚠️ KÉT kiadás van: a `cloud.firestore` (a régi, alapértelmezett adatbázisé)
  // és a `cloud.firestore/hungarian-hardstyle` (a VALÓDI, nevesített adatbázisé).
  // A legfrissebb a mérvadó — különben egy 2026-07-i szabályt mérnénk.
  .sort((a, b) => String(b.updateTime || '').localeCompare(String(a.updateTime || '')))[0];
if (!firestoreRelease) {
  check('van kiadott Firestore-szabály', false, JSON.stringify(releases).slice(0, 200));
} else {
  const content = await fetch(`https://firebaserules.googleapis.com/v1/${firestoreRelease.rulesetName}`, {
    headers: { Authorization: `Bearer ${token}` },
  }).then((response) => response.json());
  const files = (content.source?.files || []).map((file) => file.content || '').join('\n');
  check(
    'a kiadott szabály tartalmazza a moderation_flags blokkot',
    files.includes('match /moderation_flags/{flagId}'),
    `${firestoreRelease.rulesetName} (${firestoreRelease.updateTime})`,
  );
  check('a moderation_flags olvasása moderátorra szűkített', files.includes('allow read: if isModerator()'));
  check('a moderation_flags írása tiltott', /match \/moderation_flags[\s\S]{0,200}allow write: if false/.test(files));
  check(
    'a birthDate/birthDateVisible a profil-szabályban van',
    files.includes('birthDate') && files.includes('birthDateVisible'),
  );
}

/* --- 2. Az új függvények ---------------------------------------------- */

const services = await fetch(
  `https://run.googleapis.com/v2/projects/${PROJECT}/locations/europe-central2/services?pageSize=200`,
  { headers: { Authorization: `Bearer ${token}` } },
).then((response) => response.json());
const names = (services.services || []).map((service) => service.name.split('/').pop());
check('a moderatePrivateMessage telepítve van', names.includes('moderateprivatemessage'), names.length ? `${names.length} szolgáltatás` : 'nincs válasz');
check('a sendBirthDateNotices telepítve van', names.includes('sendbirthdatenotices'));

/* --- 3. A kapcsoló állapota (alvó kell legyen) ------------------------ */

const settings = await firestoreGet('app_settings/birth_date_notice');
if (!settings) {
  console.log('  info a kapcsoló-dokumentum még nincs meg → a kiküldés ALVÓ');
} else {
  check('a kiküldés ALVÓ állapotban van (enabled !== true)', settings.enabled !== true, JSON.stringify(settings));
}

console.log('');
console.log(failures === 0 ? 'MINDEN ELLENŐRZÉS RENDBEN' : `${failures} HIBA`);
process.exitCode = failures === 0 ? 0 : 1;
