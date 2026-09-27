'use strict';
/**
 * A **születési dátum** szerveroldali szabályai — tiszta, hálózat nélkül
 * tesztelhető függvények.
 *
 * MIÉRT KELL (a tulajdonos döntése, 2026-09-27):
 *   1. a `birthDate` csak akkor kerülhet a **nyilvános** `public_profiles`
 *      vetítésbe, ha a felhasználó bekapcsolta a megjelenítést
 *      (`birthDateVisible === true`) — a döntés a felhasználóé;
 *   2. a **kiskorú-védelemhez** (16–17 éves felhasználó nagykorú partnerrel)
 *      viszont kell egy kor-jelző akkor is, ha a **dátumot** nem tette
 *      nyilvánossá. Ezért a vetítés egyetlen logikai mezőt kap (`adult`), ami
 *      a **dátumot nem árulja el**, csak a kor-sávot — ez a legkisebb
 *      közzététel, ami a figyelmeztetéshez elég;
 *   3. a vetítés `merge: true`-val íródik, ezért a **visszavont** dátumot
 *      kifejezetten **törölni** kell, különben a korábban nyilvános dátum a
 *      dokumentumban maradna.
 */

/** `'YYYY-MM-DD'` — a tárolt alak. */
const BIRTH_DATE_PATTERN = /^\d{4}-\d{2}-\d{2}$/;

/** A regisztráció korhatára (a kliens ugyanezt kényszeríti ki). */
const MINIMUM_AGE = 16;

/** Ettől a kortól számít valaki nagykorúnak. */
const ADULT_AGE = 18;

/** A legkorábbi elfogadott év (elgépelés ellen). */
const FIRST_YEAR = 1900;

/** A vetítésből törlendő mezők, ha épp nem szerepelnek benne. */
const CACHEABLE_OPTIONAL_FIELDS = ['birthDate', 'adult'];

function todayUtc(now) {
  const value = now instanceof Date ? now : new Date();
  return Date.UTC(
    value.getUTCFullYear(),
    value.getUTCMonth(),
    value.getUTCDate(),
  );
}

/** A szöveg `Date`-té alakítva (UTC, csak valódi naptári nap), vagy `null`. */
function parseBirthDate(value) {
  const text = String(value == null ? '' : value).trim();
  if (!BIRTH_DATE_PATTERN.test(text)) return null;
  const year = Number(text.slice(0, 4));
  const month = Number(text.slice(5, 7));
  const day = Number(text.slice(8, 10));
  const date = new Date(Date.UTC(year, month - 1, day));
  if (
    date.getUTCFullYear() !== year ||
    date.getUTCMonth() !== month - 1 ||
    date.getUTCDate() !== day
  ) {
    return null;
  }
  return { year, month, day, millis: date.getTime() };
}

/** Érvényes (valódi, nem jövőbeli, elég régi) születési dátum-e. */
function isValidBirthDate(value, now) {
  const parsed = parseBirthDate(value);
  if (!parsed) return false;
  if (parsed.year < FIRST_YEAR) return false;
  return parsed.millis <= todayUtc(now);
}

/** Az életkor egész évben, vagy `null` (érvénytelen/hiányzó dátum). */
function ageInYears(value, now) {
  const parsed = parseBirthDate(value);
  if (!parsed || !isValidBirthDate(value, now)) return null;
  const reference = new Date(todayUtc(now));
  const year = reference.getUTCFullYear();
  const month = reference.getUTCMonth() + 1;
  const day = reference.getUTCDate();
  let age = year - parsed.year;
  const hadBirthday =
    month > parsed.month || (month === parsed.month && day >= parsed.day);
  if (!hadBirthday) age -= 1;
  return age < 0 ? 0 : age;
}

/** Betöltötte-e a megadott életkort. */
function isAtLeastAge(value, years, now) {
  const age = ageInYears(value, now);
  return age !== null && age >= years;
}

/** Nagykorú-e (18+). */
function isAdultBirthDate(value, now) {
  return isAtLeastAge(value, ADULT_AGE, now);
}

/**
 * A **nyilvános** vetítésbe kerülő dátum — csak akkor, ha a felhasználó
 * bekapcsolta a megjelenítést, és a dátum érvényes.
 */
function publicBirthDate(profile) {
  if (!profile || profile.birthDateVisible !== true) return {};
  const value = String(profile.birthDate == null ? '' : profile.birthDate).trim();
  return isValidBirthDate(value) ? { birthDate: value } : {};
}

/**
 * A **kor-sáv** a vetítésbe: `{ adult: true|false }`, a dátum nélkül.
 *
 * Ha nincs érvényes dátum, **nincs** mező — a kliens ilyenkor nem találgat
 * (nem jelenik meg a figyelmeztető sáv).
 */
function publicAgeBand(profile, now) {
  const value = String(
    profile && profile.birthDate != null ? profile.birthDate : '',
  ).trim();
  if (!isValidBirthDate(value, now)) return {};
  return { adult: isAdultBirthDate(value, now) };
}

/**
 * A `merge: true` írás nem töröl, ezért a vetítésből **kimaradó** opcionális
 * mezőket kifejezetten törölni kell (pl. a felhasználó visszavonta a dátum
 * nyilvánosságát).
 */
function projectionDeletions(projection) {
  const data = projection && typeof projection === 'object' ? projection : {};
  return CACHEABLE_OPTIONAL_FIELDS.filter(
    (field) => !Object.prototype.hasOwnProperty.call(data, field),
  );
}

module.exports = {
  ADULT_AGE,
  BIRTH_DATE_PATTERN,
  CACHEABLE_OPTIONAL_FIELDS,
  FIRST_YEAR,
  MINIMUM_AGE,
  ageInYears,
  isAdultBirthDate,
  isAtLeastAge,
  isValidBirthDate,
  parseBirthDate,
  projectionDeletions,
  publicAgeBand,
  publicBirthDate,
};
