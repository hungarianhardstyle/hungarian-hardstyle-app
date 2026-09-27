#!/usr/bin/env node
/**
 * **Kik kapnának ma születésnapi köszöntést?** (csak olvas, UID-et nem ír ki).
 *
 * A köszöntő kör (`exports.sendBirthdayGreetings`) naponta 09:00-kor fut; ez a
 * szonda ugyanazt a döntést futtatja le a valódi profilokon, hogy a kiküldés
 * előtt látható legyen a hatókör.
 *
 * Használat: node tmp/probe-birthday-today.mjs
 */
import { firestoreList } from '../tools/lib/live-firebase.mjs';
import { birthdayTargets, localDateIn, DEFAULT_TIME_ZONE } from '../functions/birthday-plan.js';

const profiles = await firestoreList('community_profiles', {
  fields: ['birthDate', 'displayName', 'language'],
});

const now = new Date();
const { targets, today } = birthdayTargets(
  profiles.map((profile) => ({ uid: profile.id, profile })),
  { now, timeZone: DEFAULT_TIME_ZONE },
);

const withDate = profiles.filter((profile) => String(profile.birthDate ?? '').trim().length > 0);
console.log('Születésnapi köszöntés — élő mérés');
console.log(`  időzóna:            ${DEFAULT_TIME_ZONE}`);
console.log(`  helyi dátum:        ${today.year}-${String(today.month).padStart(2, '0')}-${String(today.day).padStart(2, '0')}`);
console.log(`  profilok:           ${profiles.length}`);
console.log(`  dátummal:           ${withDate.length}`);
console.log(`  MA köszöntendő:     ${targets.length}`);
for (const target of targets) {
  console.log(`    - ${target.name || '(nincs megjelenített név)'} [${target.language}]`);
}
