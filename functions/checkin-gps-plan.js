'use strict';

// Helyalapú becsekkolás döntése — TISZTA logika (nincs hálózat/Firestore), hogy
// külön tesztelhető legyen. A telefon pozícióját NEM tároljuk: csak az eredmény
// számít. A GPS hamisítható, ezért a jutalom ugyanaz, mint a QR-nál, de az
// esemény szerkesztőjében külön kapcsolni kell (alapból ki).

/** A telefon pozíciójának legfeljebb ekkora hibahatára fogadható el (méter). */
const MAX_ACCURACY_METERS = 100;

const EARTH_RADIUS_METERS = 6_371_000;

/** Két földrajzi pont távolsága méterben (haversine). */
function distanceMeters(lat1, lng1, lat2, lng2) {
  const rad = (deg) => (deg * Math.PI) / 180;
  const dLat = rad(lat2 - lat1);
  const dLng = rad(lng2 - lng1);
  const a = Math.sin(dLat / 2) ** 2 + Math.cos(rad(lat1)) * Math.cos(rad(lat2)) * Math.sin(dLng / 2) ** 2;
  return 2 * EARTH_RADIUS_METERS * Math.asin(Math.min(1, Math.sqrt(a)));
}

/** A kliens által küldött pozíció érvényes-e (számok, tartományok). */
function parsePosition(data) {
  // `Number(null)` 0 lenne: csak szám vagy nem üres számszöveg fogadható el.
  const num = (value) =>
    typeof value === 'number' || (typeof value === 'string' && value.trim() !== '') ? Number(value) : NaN;
  const lat = num(data?.lat);
  const lng = num(data?.lng);
  const accuracy = num(data?.accuracy);
  if (!Number.isFinite(lat) || !Number.isFinite(lng) || !Number.isFinite(accuracy)) return null;
  if (Math.abs(lat) > 90 || Math.abs(lng) > 180 || accuracy < 0) return null;
  return { lat, lng, accuracy };
}

/**
 * Az eredmény: `{ ok: true, distance }` vagy `{ ok: false, code, distance? }`.
 * `config` a WordPress `checkin-gps` válasza: { enabled, lat, lng, radius, state }.
 * Kódok: `disabled` | `before` | `closed` | `unknown` | `inaccurate` | `too_far`.
 */
function gpsCheckinDecision(config, position) {
  if (!config || config.enabled !== true) return { ok: false, code: 'disabled' };
  if (config.state === 'before') return { ok: false, code: 'before' };
  if (config.state === 'closed') return { ok: false, code: 'closed' };
  if (config.state !== 'open') return { ok: false, code: 'unknown' };
  if (position.accuracy > MAX_ACCURACY_METERS) {
    return { ok: false, code: 'inaccurate', accuracy: Math.round(position.accuracy) };
  }
  const distance = distanceMeters(position.lat, position.lng, Number(config.lat), Number(config.lng));
  if (!(distance <= Number(config.radius))) {
    return { ok: false, code: 'too_far', distance: Math.round(distance) };
  }
  return { ok: true, distance: Math.round(distance) };
}

/** A döntés magyar üzenete a felhasználónak. */
function gpsDecisionMessage(decision) {
  switch (decision.code) {
    case 'disabled':
      return 'Ennél a bulinál nincs helyalapú becsekkolás, olvasd be a QR-kódot.';
    case 'before':
      return 'A becsekkolás a buli kezdetekor nyílik.';
    case 'closed':
      return 'Ennek a bulinak a becsekkolása már lezárult.';
    case 'inaccurate':
      return `A helymeghatározás most pontatlan (${decision.accuracy} m). Menj kijjebb, vagy olvasd be a QR-kódot.`;
    case 'too_far':
      return `Túl messze vagy a helyszíntől (${decision.distance} m). Olvasd be a QR-kódot, vagy gyere közelebb.`;
    default:
      return 'A helyalapú becsekkolás most nem érhető el.';
  }
}

module.exports = {
  MAX_ACCURACY_METERS,
  distanceMeters,
  parsePosition,
  gpsCheckinDecision,
  gpsDecisionMessage,
};
