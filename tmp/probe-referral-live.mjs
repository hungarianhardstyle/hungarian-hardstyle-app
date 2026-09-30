// ÉLES, SZÁRAZ MÉRÉS: hol tart a meghívó-jutalom, és mit jelent a kétoldali jutalom?
//
// A kérdés nem elméleti: a meghívó oldala **már élt** (50 pont, egyszer), a
// meghívott viszont **semmit** nem kapott. Ez a szonda a Firestore-ból méri:
//   * hány profil jelölte meg, ki hívta meg (`referredBy`);
//   * ezek közül hánynál van már meg a meghívói jóváírás jelölője;
//   * hány olyan profil van, aki **régen** jelezte a meghívót (az új jutalom
//     rájuk NEM vonatkozik visszamenőleg — ezt tudni kell a jelentéshez).
//
// Csak olvas: egyetlen írás sincs.
import { firestoreList, accessToken } from '../tools/lib/live-firebase.mjs';

const token = await accessToken();
const profiles = await firestoreList('community_profiles', {
  token,
  fields: [
    'displayName',
    'referredBy',
    'referralClaimedAt',
    'referralRewardGranted',
    'referralRewardGrantedAt',
    'referralWelcomeGranted',
    'achievementPoints',
    'createdAt',
  ],
});

const referred = profiles.filter((profile) => String(profile.referredBy || '').trim() !== '');
const selfReferred = referred.filter((profile) => profile.referredBy === profile.id);
const inviterGranted = referred.filter((profile) => profile.referralRewardGranted === true);
const inviterPending = referred.filter((profile) => profile.referralRewardGranted !== true);
const welcomeGranted = referred.filter((profile) => profile.referralWelcomeGranted === true);

/** Hány különböző meghívó van (a valódi hatás: ennyi ember kap pontot). */
const inviters = new Set(referred.map((profile) => profile.referredBy));

console.log(`összes profil: ${profiles.length}`);
console.log(`meghívóval érkezett profil (referredBy): ${referred.length}`);
console.log(`  ebből önmagára hivatkozó (hiba lenne): ${selfReferred.length}`);
console.log(`  különböző meghívó: ${inviters.size}`);
console.log(`  meghívói jóváírás MEGVAN: ${inviterGranted.length}`);
console.log(`  meghívói jóváírás HÁTRAVAN (a következő írásnál megy ki): ${inviterPending.length}`);
console.log(`  meghívotti (üdvözlő) jóváírás megvan: ${welcomeGranted.length}`);

const claimDates = referred
  .map((profile) => String(profile.referralClaimedAt || ''))
  .filter((value) => value !== '')
  .sort();
if (claimDates.length) {
  console.log(`  legkorábbi meghívás: ${claimDates[0]}`);
  console.log(`  legutóbbi meghívás: ${claimDates[claimDates.length - 1]}`);
}

// A pont-jutalom hatása: mennyi pontot osztott ki eddig a meghívó-oldal, és
// mennyit osztana ki a MÁSODIK oldal, ha a jövőben minden meghívott megkapná.
const pointsOf = (profile) => Number(profile.achievementPoints || 0);
const totalPoints = profiles.reduce((sum, profile) => sum + pointsOf(profile), 0);
console.log(`\na profilok összpontja: ${totalPoints}`);
console.log(`a meghívói jutalom eddig kiosztva (becslés): ${inviterGranted.length * 50} pont`);
console.log(`a meghívotti jutalom a JÖVŐBELI meghívásokra: ${25} pont / fő`);
console.log(
  `\nA ${referred.length} meghívott közül ${welcomeGranted.length}-nak van üdvözlő jelölője, ` +
    `ezért ${referred.length - welcomeGranted.length} fő jutalma **pótlódik** a következő profil-írásnál ` +
    '(a döntés öngyógyító: a jelölő hiánya pótolja a jutalmat, kétszer viszont nem adható).',
);
