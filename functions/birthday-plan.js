'use strict';

/**
 * **Születésnapi köszöntés** — tiszta döntés, nulla függőség.
 *
 * A tulajdonos kérése (2026-09-27): *„akinek születésnapja van, az adott napon
 * kapjon egy Boldog szülinapos Notifyt, szépen megfogalmazva"*.
 *
 * Ez a modul **csak azt dönti el**, kit kell köszönteni (`birthdayTargets`) és
 * milyen kulccsal (`birthdayKey`) — az értesítés szövege a nyelvi katalógusból
 * jön (`functions/notification-texts.js` → `birthday`), a küldést pedig a
 * `functions/index.js` végzi.
 *
 * ⚠️ **IDEMPOTENCIA:** a kulcs évet is tartalmaz (`birthday:{uid}:{year}`), ezért
 * egy köszöntés **évente egyszer** megy ki akkor is, ha a kör naponta fut, vagy
 * ha a trigger/kör megismétlődik.
 *
 * ⚠️ **IDŐZÓNA:** a szerver UTC-ben fut, a felhasználók viszont magyar (illetve
 * közép-európai) idő szerint élnek. Ezért a „ma" napot **a megadott időzónában**
 * számoljuk (`Europe/Budapest`) — különben a hajnali órákban (00:00–02:00 között,
 * nyáron) **elcsúszna** a köszöntés napja.
 *
 * ⚠️ **FEBRUÁR 29.:** aki szökőnapon született, a **nem szökőévekben február
 * 28-án** kap köszöntést (különben 3 évente kimaradna) — ez szándékos döntés, és
 * a `birthdayMatches` dokumentálja.
 */

/** A köszöntés típusa (a nyelvi katalógus kulcsa is ez). */
const BIRTHDAY_TYPE = 'birthday';

/** Az alap időzóna (a felhasználók zöme magyar). */
const DEFAULT_TIME_ZONE = 'Europe/Budapest';

/** `'YYYY-MM-DD'` — a `community_profiles.birthDate` alakja. */
const BIRTH_DATE_PATTERN = /^(\d{4})-(\d{2})-(\d{2})$/;

/** A nap részei (`{year, month, day}`), vagy `null`, ha érvénytelen. */
function parseBirthDate(value) {
  const text = String(value ?? '').trim();
  const match = BIRTH_DATE_PATTERN.exec(text);
  if (!match) return null;
  const year = Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  const probe = new Date(Date.UTC(year, month - 1, day));
  if (
    probe.getUTCFullYear() !== year ||
    probe.getUTCMonth() + 1 !== month ||
    probe.getUTCDate() !== day
  ) {
    return null;
  }
  return { year, month, day };
}

/**
 * A **helyi** dátum a megadott időzónában (`{year, month, day}`).
 *
 * MIÉRT nem `new Date().getDate()`: a szerver UTC-ben jár, a felhasználó meg
 * helyi időben — nyáron 2 óra a különbség, ezért a hajnali kör a **másik**
 * napot köszöntené.
 */
function localDateIn(timeZone = DEFAULT_TIME_ZONE, now = new Date()) {
  const reference = now instanceof Date ? now : new Date(now);
  if (Number.isNaN(reference.getTime())) return null;
  try {
    const parts = new Intl.DateTimeFormat('en-CA', {
      timeZone,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    }).formatToParts(reference);
    const value = (type) => Number(parts.find((part) => part.type === type)?.value || 0);
    return { year: value('year'), month: value('month'), day: value('day') };
  } catch (_) {
    // Ismeretlen időzóna: essünk vissza UTC-re (nem tippelünk, csak működünk).
    return {
      year: reference.getUTCFullYear(),
      month: reference.getUTCMonth() + 1,
      day: reference.getUTCDate(),
    };
  }
}

/** Szökőév-e (a naptár szabálya szerint)? */
function isLeapYear(year) {
  return (year % 4 === 0 && year % 100 !== 0) || year % 400 === 0;
}

/**
 * A megadott napon van-e a születésnap?
 *
 * * a hónap és a nap egyezik → `true`;
 * * **február 29-i** születésnap nem szökőévben → **február 28-án** `true`
 *   (különben három évente kimaradna a köszöntés);
 * * minden más esetben `false`.
 */
function birthdayMatches(birthDate, today) {
  const parsed = parseBirthDate(birthDate);
  if (!parsed || !today) return false;
  if (parsed.month === today.month && parsed.day === today.day) return true;
  return parsed.month === 2 && parsed.day === 29 && today.month === 2 && today.day === 28 && !isLeapYear(today.year);
}

/** Az értesítés determinisztikus kulcsa — évente egyszer futhat le. */
function birthdayKey(uid, year) {
  const id = String(uid || '').trim();
  if (!id) return '';
  return `${BIRTHDAY_TYPE}:${id}:${Number(year) || 0}`;
}

/** Nyelv-normalizálás: minden ismeretlen érték magyar (mint a többi szerver-úton). */
function normalizeLanguage(value) {
  const code = String(value ?? '')
    .trim()
    .toLowerCase();
  if (code === 'en' || code.startsWith('en-') || code.startsWith('en_')) return 'en';
  return 'hu';
}

/** A megjelenített név: a profil `displayName` mezője, vagy üres. */
function displayNameOf(profile) {
  return String(profile?.displayName ?? '').trim();
}

/**
 * A **megszólítás** a köszöntéshez (nyelvhelyesen, mindkét nyelven).
 *
 * * névvel: `'Kedves Anna! '` / `'Dear Anna! '`
 * * név nélkül: **üres szöveg** — a köszöntés ilyenkor a csapattal kezdődik
 *   (*„A Hungarian Hardstyle csapata…"*), nem marad lógó megszólítás.
 *
 * A záró szóköz szándékos: a katalógus sablonja `'{greeting}A Hungarian…'`,
 * ezért a megszólítás és a mondat így nem tapad össze.
 */
function birthdayGreeting(name, language = 'hu') {
  const clean = String(name ?? '').trim();
  if (!clean) return '';
  return normalizeLanguage(language) === 'en' ? `Dear ${clean}! ` : `Kedves ${clean}! `;
}

/**
 * Kit köszöntsünk ma?
 *
 * @param {Array<{uid: string, profile: object}>} entries a `community_profiles` sorai
 * @param {{timeZone?: string, now?: Date}} [options]
 * @returns {{targets: Array<{uid: string, name: string, language: string}>, today: object|null, skipped: number}}
 */
function birthdayTargets(entries, { timeZone = DEFAULT_TIME_ZONE, now = new Date() } = {}) {
  const today = localDateIn(timeZone, now);
  const targets = [];
  let skipped = 0;
  for (const entry of Array.isArray(entries) ? entries : []) {
    const uid = String(entry?.uid || '').trim();
    const profile = entry?.profile || {};
    if (!uid || !birthdayMatches(profile.birthDate, today)) {
      skipped += 1;
      continue;
    }
    targets.push({
      uid,
      name: displayNameOf(profile),
      language: normalizeLanguage(profile.language),
    });
  }
  return { targets, today, skipped };
}

module.exports = {
  BIRTHDAY_TYPE,
  DEFAULT_TIME_ZONE,
  parseBirthDate,
  localDateIn,
  isLeapYear,
  birthdayMatches,
  birthdayKey,
  birthdayGreeting,
  displayNameOf,
  normalizeLanguage,
  birthdayTargets,
};
