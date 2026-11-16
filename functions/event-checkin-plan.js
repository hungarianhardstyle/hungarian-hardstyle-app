'use strict';

/**
 * Bulis becsekkolás QR-kóddal (2.15.0 / build 410) — a tiszta döntések.
 *
 * Nulla függőség, hogy WordPress és Firestore nélkül mérhető legyen. A szerver
 * (`checkInEvent` callable) csak ezeket hívja; a valódi kapu (kód + időablak +
 * fiókonként egyszer) a WordPressben van, a jóváírás idempotenciáját a
 * `achievement_ledger` adja (`event-checkin:<eseményId>`).
 */

/** Ennyi pont jár egy igazolt (QR-rel becsekkolt) részvételért. */
const EVENT_CHECKIN_POINTS = 30;

/** Egyszeri jutalom a belépésért (a bemutató végén ajánljuk fel). */
const WELCOME_SIGN_IN_POINTS = 25;

const CHECKIN_HOSTS = new Set(['hungarianhardstyle.hu', 'www.hungarianhardstyle.hu']);

/**
 * A QR tartalmából (vagy a kliens által küldött mezőkből) az esemény és a kód.
 * Csak a saját domainünk `/checkin/<id>/<kód>` útvonalát fogadja el; minden más
 * `null` (nem tippelünk).
 */
function parseCheckinTarget(input) {
  if (input && typeof input === 'object') {
    const eventId = Number(input.eventId);
    const code = String(input.code || '').trim().toLowerCase();
    if (!Number.isInteger(eventId) || eventId < 1) return null;
    if (!/^[a-z0-9]{8,64}$/.test(code)) return null;
    return { eventId, code };
  }
  const raw = String(input || '').trim();
  if (!raw) return null;
  let url;
  try {
    url = new URL(raw);
  } catch (_) {
    return null;
  }
  if (url.protocol !== 'https:' || !CHECKIN_HOSTS.has(url.hostname.toLowerCase())) return null;
  const match = /^\/checkin\/(\d+)\/([A-Za-z0-9]+)\/?$/.exec(url.pathname);
  if (!match) return null;
  return parseCheckinTarget({ eventId: match[1], code: match[2] });
}

/** A felhasználó becsekkolás-rekordjának azonosítója (eseményenként egy). */
function checkinDocId(uid, eventId) {
  return `${String(uid)}_${Number(eventId)}`;
}

/** A becsekkolás pontforrás-kulcsa (a ledger miatt eseményenként egyszer fizet). */
function checkinSourceKey(eventId) {
  return `event-checkin:${Number(eventId)}`;
}

/** A jelvény adata a profilhoz: üres név/kép esetén az általános „Ott voltam”. */
function checkinBadge(payload) {
  const name = String(payload?.badgeName || '').trim();
  const url = String(payload?.badgeUrl || '').trim();
  const title = String(payload?.title || '').trim();
  return {
    badgeName: name || (title ? `${title} – ott voltam` : 'Ott voltam'),
    badgeUrl: /^https?:\/\//i.test(url) ? url : '',
    title,
  };
}

module.exports = {
  EVENT_CHECKIN_POINTS,
  WELCOME_SIGN_IN_POINTS,
  parseCheckinTarget,
  checkinDocId,
  checkinSourceKey,
  checkinBadge,
};
