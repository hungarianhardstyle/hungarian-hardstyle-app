'use strict';

/**
 * A **claimelt (átvett) DJ-adatlap szerkesztésének** szabálya — tiszta logika.
 *
 * A TULAJDONOS KÉRÉSE (2026-09-22): *„Aki claimelte a dj adatlapját, tudja
 * szerkeszteni is."* A kérdező ablakban ezt választotta: **szöveges adatok +
 * közösségi linkek + képcsere**.
 *
 * HOL A DÖNTÉS: a bemenet normalizálása és a hibaokok **itt** vannak (mérhető,
 * hálózat nélkül), a WordPress-írás pedig a plugin új végpontján megy
 * (`POST /huhs/v1/dj-profile/<id>`). A kimenet kulcsai **pontosan a WordPress
 * mezőnevei**, ezért a hívó csak továbbadja — nem kell két helyen egyeztetni.
 *
 * ⚠️ AMI SZÁNDÉKOSAN NEM SZERKESZTHETŐ:
 *  - **`booking_email`** — pont ez igazolja az átvételt; ha a DJ átírhatná, egy
 *    másik fiók is átvehetné az adatlapot,
 *  - **`contact_email`** (privát cím) — a szerveroldali claim-döntés alapja,
 *  - `visible`, `featured`, `booking_via_huhs` — a ház döntései,
 *  - `genre`, taxonómiák, slug, állapot.
 */

const ARTIST_PROFILE_LIMITS = Object.freeze({
  title: 120,
  realName: 120,
  city: 80,
  country: 80,
  biography: 6000,
  url: 300,
  imageUrl: 500,
});

/** A közösségi linkek kulcsai — ugyanazok, mint a nyilvános válaszban. */
const ARTIST_SOCIAL_KEYS = Object.freeze([
  'website',
  'facebook',
  'instagram',
  'tiktok',
  'spotify',
  'soundcloud',
  'youtube',
]);

const CLOUDINARY_HOST = 'res.cloudinary.com';

/** Vezérlőkarakterek, amik nem lehetnek szöveges mezőben (a sortörés kivétel). */
// eslint-disable-next-line no-control-regex
const CONTROL_CHARS = /[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/;

function artistProfileErrorMessage(reason) {
  switch (reason) {
    case 'empty':
      return 'Nem érkezett menthető adat.';
    case 'title-too-long':
      return `A név legfeljebb ${ARTIST_PROFILE_LIMITS.title} karakter lehet.`;
    case 'real-name-too-long':
      return `A valódi név legfeljebb ${ARTIST_PROFILE_LIMITS.realName} karakter lehet.`;
    case 'city-too-long':
      return `A város legfeljebb ${ARTIST_PROFILE_LIMITS.city} karakter lehet.`;
    case 'country-too-long':
      return `Az ország legfeljebb ${ARTIST_PROFILE_LIMITS.country} karakter lehet.`;
    case 'biography-too-long':
      return `A bemutatkozás legfeljebb ${ARTIST_PROFILE_LIMITS.biography} karakter lehet.`;
    case 'link-invalid':
      return 'A közösségi link csak teljes, http vagy https kezdetű cím lehet.';
    case 'image-not-cloudinary':
      return 'A kép csak az appból feltöltött (Cloudinary) kép lehet.';
    case 'invalid-type':
      return 'Érvénytelen adat érkezett.';
    case 'control-chars':
      return 'A szöveg nem tartalmazhat vezérlőkaraktereket.';
    default:
      return 'Az adatlap mentése nem sikerült.';
  }
}

/** Szöveges mező: string, vezérlőkarakter nélkül, hossz-korláttal. */
function normalizeText(value, { maxLength, reason }) {
  if (value === undefined || value === null) return { value: '' };
  if (typeof value !== 'string') return { error: 'invalid-type' };
  const trimmed = value.trim();
  if (CONTROL_CHARS.test(trimmed)) return { error: 'control-chars' };
  if (trimmed.length > maxLength) return { error: reason };
  return { value: trimmed };
}

/**
 * Link: üres érték = **törlés** (a mező kiürül), egyébként teljes http(s) cím.
 * Szándékosan szigorú: nem tippelünk sémát, és a `javascript:`/`data:` nem megy át.
 */
function normalizeLink(value) {
  if (value === undefined || value === null) return { value: '' };
  if (typeof value !== 'string') return { error: 'invalid-type' };
  const trimmed = value.trim();
  if (trimmed === '') return { value: '' };
  if (CONTROL_CHARS.test(trimmed) || trimmed.length > ARTIST_PROFILE_LIMITS.url) {
    return { error: 'link-invalid' };
  }
  let parsed;
  try {
    parsed = new URL(trimmed);
  } catch (_) {
    return { error: 'link-invalid' };
  }
  if (parsed.protocol !== 'http:' && parsed.protocol !== 'https:') {
    return { error: 'link-invalid' };
  }
  if (!parsed.hostname.includes('.')) return { error: 'link-invalid' };
  return { value: parsed.toString() };
}

/** Kép: csak a saját Cloudinary-fiókunkról, **https**-sel (a beküldés is oda tölt). */
function normalizeImageUrl(value) {
  const link = normalizeLink(value);
  if (link.error) return { error: 'image-not-cloudinary' };
  if (!link.value) return { error: 'image-not-cloudinary' };
  if (link.value.length > ARTIST_PROFILE_LIMITS.imageUrl) {
    return { error: 'image-not-cloudinary' };
  }
  // ⚠️ Csak https: az Android a sima http képet nem is töltené be, ezért egy
  // ilyen cím „elmentve, de láthatatlan" állapotot okozna — inkább elutasítjuk.
  if (!link.value.startsWith('https://')) {
    return { error: 'image-not-cloudinary' };
  }
  let host = '';
  try {
    host = new URL(link.value).hostname.toLowerCase();
  } catch (_) {
    return { error: 'image-not-cloudinary' };
  }
  if (host !== CLOUDINARY_HOST) return { error: 'image-not-cloudinary' };
  return { value: link.value };
}

/**
 * A bemenet → a WordPress mezőnevei.
 *
 * Kimenet: `{ ok: true, fields }` vagy `{ ok: false, error, message }`.
 * Ismeretlen kulcsot **eldobunk** (nem hiba), de ha semmi érvényes nem marad,
 * az `empty` — így egy elrontott kliens nem indít fölösleges írást.
 */
function normalizeArtistProfileUpdate(input) {
  const source = input && typeof input === 'object' ? input : {};
  const fields = {};

  const textFields = [
    ['title', 'title', ARTIST_PROFILE_LIMITS.title, 'title-too-long'],
    ['realName', 'real_name', ARTIST_PROFILE_LIMITS.realName, 'real-name-too-long'],
    ['city', 'city', ARTIST_PROFILE_LIMITS.city, 'city-too-long'],
    ['country', 'country', ARTIST_PROFILE_LIMITS.country, 'country-too-long'],
    ['biography', 'biography', ARTIST_PROFILE_LIMITS.biography, 'biography-too-long'],
  ];
  for (const [inputKey, wireKey, maxLength, reason] of textFields) {
    if (!(inputKey in source)) continue;
    const result = normalizeText(source[inputKey], { maxLength, reason });
    if (result.error) {
      return { ok: false, error: result.error, message: artistProfileErrorMessage(result.error) };
    }
    // Üres nevet nem küldünk: a `post_title` nem lehet üres.
    if (inputKey === 'title' && result.value === '') continue;
    fields[wireKey] = result.value;
  }

  const socials = source.socialLinks;
  if (socials !== undefined && socials !== null) {
    if (typeof socials !== 'object' || Array.isArray(socials)) {
      return {
        ok: false,
        error: 'invalid-type',
        message: artistProfileErrorMessage('invalid-type'),
      };
    }
    for (const key of ARTIST_SOCIAL_KEYS) {
      if (!(key in socials)) continue;
      const result = normalizeLink(socials[key]);
      if (result.error) {
        return { ok: false, error: result.error, message: artistProfileErrorMessage(result.error) };
      }
      fields[key] = result.value;
    }
  }

  const images = [
    ['profileImageUrl', 'logo_url'],
    ['coverImageUrl', 'hero_image_url'],
  ];
  for (const [inputKey, wireKey] of images) {
    if (!(inputKey in source)) continue;
    const result = normalizeImageUrl(source[inputKey]);
    if (result.error) {
      return { ok: false, error: result.error, message: artistProfileErrorMessage(result.error) };
    }
    fields[wireKey] = result.value;
  }

  if (Object.keys(fields).length === 0) {
    return { ok: false, error: 'empty', message: artistProfileErrorMessage('empty') };
  }
  return { ok: true, fields };
}

/**
 * Szerkesztheti-e a hívó ezt az adatlapot? (A döntés a `artist_claims`
 * dokumentumból jön, de a szabály itt, tisztán mérhető.)
 */
function artistEditAllowed({ claimUid, callerUid } = {}) {
  const owner = String(claimUid || '').trim();
  const caller = String(callerUid || '').trim();
  if (!owner) return { allowed: false, reason: 'not-claimed' };
  if (!caller || caller !== owner) return { allowed: false, reason: 'not-owner' };
  return { allowed: true, reason: '' };
}

function artistEditErrorMessage(reason) {
  switch (reason) {
    case 'not-claimed':
      return 'Ez a DJ-adatlap még nincs átvéve. Előbb vedd át az adatlapot.';
    case 'not-owner':
      return 'Ez a DJ-adatlap egy másik fiókhoz tartozik.';
    default:
      return 'Az adatlap szerkesztése nem engedélyezett.';
  }
}

module.exports = {
  ARTIST_PROFILE_LIMITS,
  ARTIST_SOCIAL_KEYS,
  CLOUDINARY_HOST,
  normalizeArtistProfileUpdate,
  artistEditAllowed,
  artistEditErrorMessage,
  artistProfileErrorMessage,
};
