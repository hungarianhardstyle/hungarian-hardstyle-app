// A Twitch-kártya felülírásának előkészítése (a tulajdonos build nélkül cserélhesse).
//
// Létrehozza/merge-eli az `app_settings/twitch` dokumentumot:
//   { enabled: true, imageUrl: "", headerText: "", showWhenOffline: false }
//
// ⚠️ Üres `imageUrl` esetén a kártya a Twitch MOZGÓ előnézetét használja —
// vagyis a dokumentum csak a felülírás helye, nem kötelező kitölteni.
//
// ⚠️ 2026-10-02: az `enabled: true` ÖNMAGÁBAN még nem elég élő adás nélkül —
// ehhez a `showWhenOffline: true` ÉS egy saját kép kell. Enélkül a kártya csak
// akkor látszik, ha tényleg megy a stream (ez a 386-ig így volt, és egy
// „beállítottam a képet, mégsem látszik" félreértést okozott).
//
// Használat:
//   node tmp/setup-twitch-card-settings.mjs                       # csak kiírja/megerősíti az alapot
//   node tmp/setup-twitch-card-settings.mjs --offline --image=https://…/plakat.jpg --header="Következő adás: péntek 20:00"
//   node tmp/setup-twitch-card-settings.mjs --hide                 # a kártya teljes elrejtése
//   node tmp/setup-twitch-card-settings.mjs --live-only            # vissza az alap viselkedésre
import { accessToken, firestoreGet, firestoreSet } from '../tools/lib/live-firebase.mjs';

const arg = (name, fallback = '') => {
  const found = process.argv.find((value) => value.startsWith(`--${name}=`));
  return found ? found.slice(name.length + 3) : fallback;
};
const has = (name) => process.argv.includes(`--${name}`);

const token = await accessToken();
const path = 'app_settings/twitch';

const before = await firestoreGet(path, { token }).catch(() => null);
console.log('elotte:', JSON.stringify(before));

const enabled = !has('hide');
const showWhenOffline = has('offline');
const imageUrl = arg('image', has('hide') || has('live-only') ? '' : (before?.imageUrl ?? ''));
const headerText = arg('header', has('hide') || has('live-only') ? '' : (before?.headerText ?? ''));

if (showWhenOffline && imageUrl.trim() === '') {
  // ⚠️ Ez NEM hiba, de a kártya így nem fog megjelenni — kimondjuk, hogy ne
  // tűnjön „elromlottnak".
  console.log('FIGYELEM: offline kártyához KÉP is kell (--image=…) — enélkül nem jelenik meg.');
}

await firestoreSet(
  path,
  {
    enabled,
    imageUrl,
    headerText,
    showWhenOffline,
    // Súgó a tulajdonosnak (a konzolon is látszik):
    note:
      'A fooldali Twitch-kartya felulirasa. imageUrl: sajat kep URL-je (ures = a Twitch elo elonezete); ' +
      'headerText: a kartya felirata; enabled: false = a kartya teljesen elrejtve; ' +
      'showWhenOffline: true = a kartya a sajat kepevel akkor is latszik, ha eppen nem megy adas ' +
      '(ehhez imageUrl is kell).',
  },
  { token },
);

const after = await firestoreGet(path, { token }).catch(() => null);
console.log('utana: ', JSON.stringify(after));
console.log(
  `\nallapot: enabled=${after?.enabled}, showWhenOffline=${after?.showWhenOffline}, ` +
    `kep=${(after?.imageUrl ?? '') === '' ? 'a Twitch elo elonezete' : after.imageUrl}`,
);
