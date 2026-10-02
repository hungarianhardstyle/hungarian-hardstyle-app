// A Twitch-kártya felülírásának előkészítése (a tulajdonos build nélkül cserélhesse).
//
// Létrehozza/merge-eli az `app_settings/twitch` dokumentumot:
//   { enabled: true, imageUrl: "", headerText: "" }
//
// ⚠️ Üres `imageUrl` esetén a kártya a Twitch MOZGÓ előnézetét használja —
// vagyis a dokumentum csak a felülírás helye, nem kötelező kitölteni.
import { accessToken, firestoreGet, firestoreSet } from '../tools/lib/live-firebase.mjs';

const token = await accessToken();
const path = 'app_settings/twitch';

const before = await firestoreGet(path, { token }).catch(() => null);
console.log('elotte:', JSON.stringify(before));

await firestoreSet(
  path,
  {
    enabled: true,
    imageUrl: '',
    headerText: '',
    // Súgó a tulajdonosnak (a konzolon is látszik):
    note:
      'A fooldali Twitch-kartya felulirasa. imageUrl: sajat kep URL-je (ures = a Twitch elo elonezete); ' +
      'headerText: a kartya felirata; enabled: false = a kartya teljesen elrejtve.',
  },
  { token },
);

const after = await firestoreGet(path, { token }).catch(() => null);
console.log('utana: ', JSON.stringify(after));
