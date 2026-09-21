'use strict';

/**
 * A DJ-adatlap **claim** („ez az én adatlapom") tiszta döntései.
 *
 * MIÉRT KÜLÖN MODUL: a tulajdonos jelezte, hogy *„valamiért tudtam ÉN mint admin
 * claimelni - ami hiba"*, és hogy a claim *„csak az tudja… akinek egyezik az
 * email címe amivel regelt a dj adatlapon szereplő email címmel"*. Vagyis a
 * döntés **egy helyen** van, és WordPress + Firestore nélkül mérhető.
 *
 * NÉGY SZÁNDÉKOS SZABÁLY:
 *  1. **NINCS admin-kivétel.** Az admin ugyanúgy csak a saját e-mail címével
 *     claimelhet — élesben pont az admin-kivétel (`isAdminClaim`) miatt tudott a
 *     tulajdonos bármelyik adatlapot claimelni, és került a fiókjára egy
 *     idegen DJ adatlapja.
 *  2. **Booking VAGY privát (contact) e-mail** egyezése elég — a beküldött
 *     adatlapon a „Kapcsolattartó" a `contact_email`, a nyilvános a
 *     `booking_email`. Az egyezés kis/nagybetűtől és a cím körüli szóköztől
 *     független.
 *  3. **A ház domainje (`hungarianhardstyle.hu`) soha nem claimelhet** — azok a
 *     címek (`info@`, `booking@`, …) a szervezeté, nem egy DJ személyes címe.
 *     ⚠️ DE: egy **más** domainen lévő `info@` (pl. `info@sajatdomain.hu`) a DJ
 *     **privát címe lehet**, ezért azt **el kell fogadni** (a tulajdonos
 *     észrevétele: *„info@ mail lehet privát, ha nem hungarianhardstyle.hu a
 *     domain"*). Ezért a szabály a **domainre** szűr, nem a pontos címre.
 *  4. **A döntés nem szivárogtat e-mail címet.** A felület csak annyit kap, hogy
 *     `claimed` / `mine` / `canClaim` — a címek a szerveren maradnak.
 */

/** A ház elsődleges címe (a felületen ezt írjuk ki, és ez a `booking_via_huhs` értéke). */
const HOUSE_EMAIL = 'info@hungarianhardstyle.hu';

/**
 * A ház **domainje**: erre a domainre eső címek nem claimelhetők.
 *
 * ⚠️ MIÉRT DOMAIN ÉS NEM PONTOS CÍM (a tulajdonos észrevétele, 2026-09-21):
 * *„info@ mail lehet privát, ha nem hungarianhardstyle.hu a domain sztem"* — vagyis
 * egy DJ privát címe nyugodtan lehet `info@sajatdomain.hu`, azt **el kell fogadni**;
 * a ház címei (`info@`, `booking@`, … `@hungarianhardstyle.hu`) viszont nem
 * személyes címek, azokkal **senki** nem claimelhet. A korábbi pontos egyezés
 * (`info@hungarianhardstyle.hu`) mellett egy `booking@hungarianhardstyle.hu`
 * átcsúszott volna.
 */
const HOUSE_DOMAIN = 'hungarianhardstyle.hu';

/** A ház domainjére esik-e a cím (a `@` utáni rész pontosan a ház domainje)? */
function isHouseEmail(value) {
  const email = normalizeClaimEmail(value);
  if (!email) return false;
  const at = email.lastIndexOf('@');
  if (at <= 0) return false;
  return email.slice(at + 1) === HOUSE_DOMAIN;
}

/** Egységes cím-alak: körülötte lévő szóköz le, kisbetű. */
function normalizeClaimEmail(value) {
  return String(value ?? '').trim().toLowerCase();
}

/**
 * A claimhez elfogadható címek: **booking + privát (contact)**, duplikáció nélkül.
 *
 * A ház domainjére eső címeket kihagyjuk (nem személyes címek), az üreseket
 * szintén — így nem lehet „véletlenül" egyezni egy hiányzó mezőn.
 */
function claimEmailsFor(artist) {
  const emails = [];
  for (const value of [artist?.booking_email, artist?.contact_email]) {
    const email = normalizeClaimEmail(value);
    if (!email || isHouseEmail(email)) continue;
    if (!emails.includes(email)) emails.push(email);
  }
  return emails;
}

/**
 * Az adatlap claim-állapota a bejelentkezett felhasználónak.
 *
 * @param {object} input
 * @param {string} input.email        a bejelentkezett (hitelesített) e-mail
 * @param {boolean} input.emailVerified az Auth szerint hitelesített-e a cím
 * @param {object} input.artist       a WordPress-adatlap (`booking_email`, `contact_email`)
 * @param {object|null} input.claim   a meglévő `artist_claims` dokumentum (vagy `null`)
 * @param {string} input.uid          a hívó azonosítója
 * @returns {{claimed: boolean, mine: boolean, canClaim: boolean, reason: string}}
 */
function artistClaimState({ email, emailVerified, artist, claim, uid } = {}) {
  const normalized = normalizeClaimEmail(email);
  const claimUid = String(claim?.uid ?? '').trim();
  const claimed = Boolean(claim && claimUid);
  const mine = claimed && claimUid === String(uid ?? '').trim();

  let reason = 'ok';
  if (claimed && !mine) reason = 'taken';
  else if (claimed && mine) reason = 'mine';
  else if (!emailVerified) reason = 'unverified';
  else if (!normalized) reason = 'missing-email';
  else if (isHouseEmail(normalized)) reason = 'house-email';
  else {
    const emails = claimEmailsFor(artist);
    if (!emails.length) reason = 'no-artist-email';
    else if (!emails.includes(normalized)) reason = 'email-mismatch';
  }

  return {
    claimed,
    mine,
    // ⚠️ Admin-kivétel **nincs**: ugyanaz a szabály mindenkire.
    canClaim: reason === 'ok',
    reason,
  };
}

/** Magyar hibaüzenet a felületre (a technikai ok a naplóba megy). */
function claimErrorMessage(reason) {
  switch (reason) {
    case 'taken':
      return 'Ezt a DJ-adatlapot már claimelte egy másik fiók.';
    case 'unverified':
      return 'Hitelesített e-mailes fiók szükséges a claimeléshez.';
    case 'missing-email':
      return 'A bejelentkezési fiókodhoz nincs e-mail cím.';
    case 'house-email':
      return 'Ezzel a címmel nem claimelhető DJ-adatlap.';
    case 'no-artist-email':
      return 'Ehhez az adatlaphoz nincs bejelentkezési e-mail megadva — szólj a HUHS-nak.';
    case 'email-mismatch':
      return 'A bejelentkezési e-mail nem egyezik az adatlapon szereplő e-mail címmel.';
    default:
      return 'A DJ-adatlap claimelése nem sikerült.';
  }
}

/** A claim-rekord mezői (egy helyen, hogy a függvény és a teszt ne térjen el). */
function artistClaimRecord({ artistId, uid, email }) {
  return {
    artistId: Number(artistId),
    uid: String(uid ?? '').trim(),
    email: normalizeClaimEmail(email),
    status: 'claimed',
  };
}

/**
 * A felhasználóhoz tartozó **érvényes** DJ-adatlap azonosítók (a profilkártyákhoz).
 *
 * A hibás/üres bejegyzést eldobjuk: a profil nem mutathat „#0" adatlapot.
 */
function claimedArtistIds(rows) {
  const ids = [];
  for (const row of Array.isArray(rows) ? rows : []) {
    const id = Number(row?.artistId);
    if (!Number.isInteger(id) || id <= 0) continue;
    if (!ids.includes(id)) ids.push(id);
  }
  return ids;
}

module.exports = {
  HOUSE_EMAIL,
  HOUSE_DOMAIN,
  isHouseEmail,
  normalizeClaimEmail,
  claimEmailsFor,
  artistClaimState,
  claimErrorMessage,
  artistClaimRecord,
  claimedArtistIds,
};
