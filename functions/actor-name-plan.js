'use strict';

/**
 * Ki a **cselekvő** az értesítésben? — tiszta döntés, nulla függőség.
 *
 * A tulajdonos jelzése (2026-09-24): *„jön notify hogy kedvelték egy chat
 * üzenetem, meg arról is hogy valaki írt egy hírhez kommentet, de odaírhatná,
 * hogy KI likeolta"*.
 *
 * **A mért gyökér** (`node tools/check-notifications.mjs` + a `notifications`
 * gyűjtemény olvasása): a chat-lájk értesítésben a név **néha** kimaradt
 * („Egy HUHS tag kedvelte a Chat-üzenetedet."), miközben ugyanannál a
 * felhasználónál a profilban **van** `displayName`. A kód egyetlen forrásból
 * (`community_profiles/{uid}.displayName`) olvasott, és ha az abban a
 * pillanatban üres volt, a szöveg a semmit jelentő általános alakra esett.
 *
 * Ez a modul a **több forrásból** való választást teszi mérhetővé: a sorrend
 * szándékos — a közösségi profil a hiteles, utána a nyilvános profil, végül az
 * Auth-fiók megjelenítendő neve. Ha egyik sincs, **nem találgatunk**.
 */

/** A nevek felső hosszkorlátja (a régi kód 80 karaktert vágott). */
const MAX_NAME_LENGTH = 80;

/** Egy jelölt normalizálása: trim + hosszkorlát; üres, ha nem használható. */
function normalizeName(value) {
  return String(value ?? '')
    .trim()
    .slice(0, MAX_NAME_LENGTH);
}

/**
 * A cselekvő neve a rendelkezésre álló forrásokból.
 *
 * @param {object} sources
 * @param {string} [sources.communityName] a `community_profiles` neve (hiteles)
 * @param {string} [sources.publicName]    a `public_profiles` neve
 * @param {string} [sources.authName]      az Auth-fiók `displayName`-je
 * @returns {string} a név, vagy `''`, ha egyik forrás sem adott használhatót
 */
function pickActorName({ communityName, publicName, authName } = {}) {
  for (const candidate of [communityName, publicName, authName]) {
    const name = normalizeName(candidate);
    if (name) return name;
  }
  return '';
}

/**
 * Az értesítés szövegében használt név: ha nincs kit írni, **őszinte** általános
 * alak jön (nem tippelünk nevet).
 */
function actorNameOrGeneric(sources, fallback = 'Egy HUHS tag') {
  return pickActorName(sources) || fallback;
}

module.exports = { MAX_NAME_LENGTH, pickActorName, actorNameOrGeneric };
