#!/usr/bin/env node
/**
 * **Mérés a születési dátum emlékeztetőhöz** (csak olvas, UID-et nem ír ki).
 *
 * A tulajdonos kérése (2026-09-27): *„menjen ki notifybe mér kötelező a
 * születési dátum, mehet nekik mail is"* — *„a meglévő tagoknak úgyértem"*.
 * Ez a szonda megmondja, **hány tagot érint** a kiküldés, és hogy közülük
 * mennyinek van e-mail-címe (a levél csak akkor megy ki, ha van).
 *
 * Használat: node tmp/probe-birth-date-notice-reach.mjs
 */
import { firestoreList, firestoreGet } from '../tools/lib/live-firebase.mjs';

const SETTINGS_DOC = 'app_settings/birth_date_notice';

const profiles = await firestoreList('community_profiles', {
  // ⚠️ A MEZŐ-MASZK MINDENT felsorol, amit mérünk — különben a Firestore REST
  // csak a kért mezőket adja vissza, és a hiányzó mező **hamis nullát** mutat
  // (ez a saját mérőeszközöm hibája volt: a kiküldés után „0" e-mail-jelölést
  // mértem, pedig a mező benne volt, csak nem kértem ki).
  fields: [
    'birthDate',
    'email',
    'language',
    'accessRole',
    'birthDateNoticeSentAt',
    'birthDateNoticeEmailSentAt',
  ],
});
const missing = profiles.filter(
  (profile) => String(profile.birthDate ?? '').trim().length === 0,
);
const withEmail = missing.filter((profile) => /^\S+@\S+\.\S+$/.test(String(profile.email ?? '').trim()));
const english = missing.filter((profile) =>
  String(profile.language ?? '').trim().toLowerCase().startsWith('en'),
);
const alreadyEmailed = missing.filter((profile) => profile.birthDateNoticeEmailSentAt);

let settings = null;
try {
  settings = await firestoreGet(SETTINGS_DOC);
} catch (error) {
  settings = { error: String(error?.message || error) };
}

console.log('Születési dátum emlékeztető — élő mérés');
console.log(`  profilok összesen:            ${profiles.length}`);
console.log(`  születési dátum NÉLKÜL:       ${missing.length}`);
console.log(`  ebből e-mail-címmel:          ${withEmail.length}`);
console.log(`  ebből angol nyelvű:           ${english.length}`);
console.log(`  már kapott emlékeztető e-mailt: ${alreadyEmailed.length}`);
console.log(`  kapcsoló (${SETTINGS_DOC}): ${settings ? JSON.stringify(settings) : 'nincs dokumentum → KIKAPCSOLVA'}`);
