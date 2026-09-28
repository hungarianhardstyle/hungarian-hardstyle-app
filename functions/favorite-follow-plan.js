'use strict';

/**
 * **Követés a kedvencek alapján** — tiszta döntés, nulla függőség.
 *
 * A tulajdonos választotta a használat-növelő csomagból a *„követés (DJ/szervező)"*
 * pontot. A mérés szerint a **követés jele már létezik**: a DJ-k és a szervezők
 * kedvencelhetők (`FavoriteKind.artist|organizer`), és a kedvencek a Firestore-ba
 * is szinkronizálódnak (`community_profiles/{uid}/favorites/{kind}_{id}`). Ezért
 * nem kell új gomb és új build ahhoz, hogy a kedvelés **értesítést is jelentsen**:
 *
 *   * **új kiadvány** → azok kapnak bejegyzést, akik a kiadvány **DJ-it** kedvelik;
 *   * **új esemény** → azok, akik a **szervezőt** vagy az esemény **DJ-it** kedvelik.
 *
 * Ez a modul **csak a döntést** adja: melyik kedvenc-kapcsolat számít, mi a
 * determinisztikus kulcs, és melyik katalógus-szöveg tartozik hozzá. Az
 * adatolvasást és az írást a `functions/index.js` végzi.
 *
 * ⚠️ **PUSH NINCS EBBEN AZ ÚTBAN:** a bejövő értesítés készül el (a meglévő
 * fan-out mintájára) — az új tartalom push-ját a WordPress-plugin küldi
 * **mindenkinek**, ezért itt egy második push csak duplázna.
 */

/** A kedvencek alkollekciója a profil alatt (a kliens is ide ír). */
const FAVORITES_COLLECTION = 'favorites';

/** A kedvenc-típusok (`FavoriteKind` a kliensben). */
const ARTIST_FAVORITE_KIND = 'artist';
const ORGANIZER_FAVORITE_KIND = 'organizer';

/** A katalógus-kulcsok (a `notification-texts.js`-ben élnek, magyar + angol). */
const FAVORITE_RELEASE_TYPE = 'favorite_release';
const FAVORITE_EVENT_TYPE = 'favorite_event';

/** A végpont kulcsa → katalógus-típus (a `pollWordPressContentNotifications` kulcsai). */
function followCatalogKindFor(endpointKey) {
  if (endpointKey === 'release') return FAVORITE_RELEASE_TYPE;
  if (endpointKey === 'event') return FAVORITE_EVENT_TYPE;
  return '';
}

/** Az azonosítók kiolvasása egy `{id, name}` listából vagy egyetlen objektumból. */
function relationIds(value) {
  const list = Array.isArray(value) ? value : value ? [value] : [];
  return [
    ...new Set(
      list
        .map((entry) => String(entry?.id ?? entry ?? '').trim())
        .filter((id) => /^\d+$/.test(id)),
    ),
  ];
}

/**
 * Mely **kedvenc-kapcsolatok** számítanak egy új tartalomnál?
 *
 * @param {string} endpointKey `'release'` vagy `'event'` (a poll végpont-kulcsa)
 * @param {object} item a WordPress-elem (mért alak: `artists: [{id,name}]`,
 *   `organizer: {id,name}`)
 * @returns {Array<{kind: string, id: string}>} a (típus, azonosító) párok
 */
function followTargetsFor(endpointKey, item) {
  const targets = [];
  if (endpointKey === 'release') {
    for (const id of relationIds(item?.artists)) {
      targets.push({ kind: ARTIST_FAVORITE_KIND, id });
    }
    return targets;
  }
  if (endpointKey === 'event') {
    // A szervező ÉS a fellépő DJ-k is „követhetők" a kedvenceken keresztül.
    for (const id of relationIds(item?.organizer)) {
      targets.push({ kind: ORGANIZER_FAVORITE_KIND, id });
    }
    for (const id of relationIds(item?.artists)) {
      targets.push({ kind: ARTIST_FAVORITE_KIND, id });
    }
  }
  return targets;
}

/**
 * A bejövő értesítés determinisztikus kulcsa.
 *
 * ⚠️ Tartalmonként **egyszer** megy ki akkor is, ha a felhasználó több kapcsolatot
 * is kedvel (pl. a szervezőt ÉS egy fellépő DJ-t): a kulcs nem tartalmazza a
 * kedvenc-típust, ezért a `create()` a második írást elutasítja — nem duplázunk.
 */
function favoriteFollowKey(endpointKey, contentId, uid) {
  const id = String(contentId || '').trim();
  const user = String(uid || '').trim();
  const type = String(endpointKey || '').trim();
  if (!id || !user || !type) return '';
  return `favorite-follow:${type}:${id}:${user}`;
}

module.exports = {
  FAVORITES_COLLECTION,
  ARTIST_FAVORITE_KIND,
  ORGANIZER_FAVORITE_KIND,
  FAVORITE_RELEASE_TYPE,
  FAVORITE_EVENT_TYPE,
  followCatalogKindFor,
  followTargetsFor,
  favoriteFollowKey,
  relationIds,
};
