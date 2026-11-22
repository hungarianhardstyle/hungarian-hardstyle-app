'use strict';

// „Ott voltam” jelvények: nyilvánosság és kiemelés — TISZTA logika (nincs Firestore),
// hogy külön tesztelhető legyen. A callable-ök az `index.js`-ben vannak.

/** Legfeljebb ennyi jelvény emelhető ki a főprofilon. */
const MAX_FEATURED = 3;

/**
 * A profil jelvény-beállításai a `community_profiles` dokumentumból.
 * `showAll`: az összes jelvény látható másoknak (alapból igen); `featured`: a
 * kiemelt események azonosítói (érvényes egészek, legfeljebb 3, ismétlés nélkül).
 */
function readBadgePrefs(profile) {
  const featured = [];
  const raw = Array.isArray(profile?.featuredCheckinEventIds) ? profile.featuredCheckinEventIds : [];
  for (const value of raw) {
    const id = Number(value);
    if (Number.isInteger(id) && id > 0 && !featured.includes(id)) featured.push(id);
    if (featured.length === MAX_FEATURED) break;
  }
  return { showAll: profile?.checkinBadgesPublic !== false, featured };
}

/**
 * A kért kiemelések ellenőrzése: egész azonosítók, ismétlés nélkül, legfeljebb 3,
 * és mind a felhasználó saját jelvényei közül valók. Hibára `null`.
 */
function normalizeFeatured(requested, ownedEventIds) {
  if (!Array.isArray(requested) || requested.length > MAX_FEATURED) return null;
  const owned = new Set(ownedEventIds);
  const result = [];
  for (const value of requested) {
    const id = Number(value);
    if (!Number.isInteger(id) || !owned.has(id) || result.includes(id)) return null;
    result.push(id);
  }
  return result;
}

/**
 * Mit lát a nézegető: a tulajdonos mindent; más csak akkor mindent, ha a tulajdonos
 * nyilvánossá tette, különben csak a kiemelteket. A jelvény a becsekkolás
 * helyéről is árulkodik, ezért a nyilvánosságot a tulajdonos szabályozza.
 */
function visibleBadges({ badges, prefs, own }) {
  if (own || prefs.showAll) return badges;
  return badges.filter((badge) => prefs.featured.includes(badge.eventId));
}

module.exports = { MAX_FEATURED, readBadgePrefs, normalizeFeatured, visibleBadges };
