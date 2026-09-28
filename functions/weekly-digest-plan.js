'use strict';

/**
 * **Heti összefoglaló** (weekly digest) — tiszta döntés, nulla függőség.
 *
 * A tulajdonos választotta a használat-növelő csomagból (2026-09-27): azok a
 * tagok, akik nem nyitják meg naponta az appot, **egy** rövid összefoglalót
 * kapjanak vasárnap — „mi történt a héten" —, hogy legyen ok visszatérni.
 *
 * Ez a modul **csak azt dönti el**:
 *   * kik kaphatják (`digestAllowed` — az értesítés-kapcsolók tiszteletben
 *     tartása: `enabled`, és a saját `digest` kapcsoló, ha a kliens küldi),
 *   * mit tartalmaz (`digestPlan` — a legfrissebb hírek és a következő hét
 *     eseményei, nyelvi térképpel),
 *   * milyen kulccsal megy ki (`digestDedupeKey` — **hetente egyszer**).
 *
 * A szöveg a nyelvi katalógusból jön (`functions/notification-texts.js` →
 * `weekly_digest`), a küldést a `functions/index.js` végzi.
 *
 * ⚠️ **IDŐZÓNA:** a szerver UTC-ben fut, a felhasználók magyar idő szerint
 * élnek — a hét kulcsa ezért a **megadott időzónában** számolódik, különben a
 * vasárnap esti kör és a hét sorszáma elcsúszna.
 *
 * ⚠️ **ÜRES ÖSSZEFOGLALÓ NINCS:** ha a héten nem volt hír és nincs közelgő
 * esemény, a kör **nem küld semmit** — nem zavarunk üres értesítéssel.
 */

/** Az értesítés típusa (a nyelvi katalógus kulcsa is ez). */
const DIGEST_KIND = 'weekly_digest';

/** Az alap időzóna (a felhasználók zöme magyar). */
const DEFAULT_TIME_ZONE = 'Europe/Budapest';

/** Mennyi hír és esemény kerüljön az összefoglalóba. */
const MAX_DIGEST_NEWS = 3;
const MAX_DIGEST_EVENTS = 3;

/** Az események ennyi napon belül számítanak „közelgőnek". */
const DIGEST_EVENT_HORIZON_MS = 7 * 24 * 60 * 60 * 1000;

/** Nyelv-normalizálás: minden ismeretlen érték magyar (mint a többi szerver-úton). */
function normalizeLanguage(value) {
  const code = String(value ?? '')
    .trim()
    .toLowerCase();
  if (code === 'en' || code.startsWith('en-') || code.startsWith('en_')) return 'en';
  return 'hu';
}

/** Az időzóna eltolása egy adott pillanatra (nyáron +2 óra, télen +1). */
function zoneOffsetMinutes(instantMs, timeZone = DEFAULT_TIME_ZONE) {
  const parts = new Intl.DateTimeFormat('en-US', { timeZone, timeZoneName: 'longOffset' }).formatToParts(
    new Date(instantMs),
  );
  const name = parts.find((part) => part.type === 'timeZoneName')?.value || 'GMT+00:00';
  const match = /GMT([+-])(\d{2}):(\d{2})/.exec(name);
  if (!match) return 0;
  return (match[1] === '-' ? -1 : 1) * (Number(match[2]) * 60 + Number(match[3]));
}

/**
 * Helyi falióra (`'2026-10-17'` + `'23:00'`, illetve WordPress ISO-dátum) →
 * **valódi** pillanat. A `strtotime`/`Date.parse` a szerver UTC-jét venné
 * alapul, ezért nyáron 2 órával elcsúszna.
 */
function instantFromLocalParts(year, month, day, hour = 0, minute = 0, timeZone = DEFAULT_TIME_ZONE) {
  const wall = Date.UTC(year, month - 1, day, hour, minute, 0, 0);
  const guess = wall - zoneOffsetMinutes(wall, timeZone) * 60000;
  return wall - zoneOffsetMinutes(guess, timeZone) * 60000;
}

/** `'2026-10-17 23:00'` / `'2026-10-17T23:00:00'` → pillanat (vagy `NaN`). */
function parseLocalDateTime(value, timeZone = DEFAULT_TIME_ZONE) {
  const match = /^(\d{4})-(\d{2})-(\d{2})(?:[T ](\d{2}):(\d{2}))?/.exec(String(value ?? '').trim());
  if (!match) return NaN;
  return instantFromLocalParts(
    Number(match[1]),
    Number(match[2]),
    Number(match[3]),
    Number(match[4] ?? 0),
    Number(match[5] ?? 0),
    timeZone,
  );
}

/** A helyi dátum (`{year, month, day}`) a megadott időzónában. */
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
    return {
      year: reference.getUTCFullYear(),
      month: reference.getUTCMonth() + 1,
      day: reference.getUTCDate(),
    };
  }
}

/**
 * A hét kulcsa (`'2026-W41'`) — **hetente egyszer** megy ki az összefoglaló.
 *
 * Szabványos ISO-hét: a hét **hétfőn** kezdődik, és a hét az év azon napjához
 * tartozik, amelyik a csütörtököt tartalmazza. Így a vasárnap esti kör mindig
 * ugyanahhoz a kulcshoz tartozik, és egy ismételt futás (vagy egy elszállt kör
 * utáni újrapróbálkozás) **nem** küldi ki kétszer.
 */
function isoWeekKey(timeZone = DEFAULT_TIME_ZONE, now = new Date()) {
  const local = localDateIn(timeZone, now);
  if (!local) return '';
  const date = new Date(Date.UTC(local.year, local.month - 1, local.day));
  const dayNumber = (date.getUTCDay() + 6) % 7; // hétfő = 0
  date.setUTCDate(date.getUTCDate() - dayNumber + 3); // a hét csütörtökje
  const isoYear = date.getUTCFullYear();
  const firstThursday = new Date(Date.UTC(isoYear, 0, 4));
  const firstDayNumber = (firstThursday.getUTCDay() + 6) % 7;
  firstThursday.setUTCDate(firstThursday.getUTCDate() - firstDayNumber + 3);
  const week = 1 + Math.round((date.getTime() - firstThursday.getTime()) / (7 * 24 * 60 * 60 * 1000));
  return `${isoYear}-W${String(week).padStart(2, '0')}`;
}

/** Kaphat-e az adott tag összefoglalót? (A kapcsolók tiszteletben tartása.) */
function digestAllowed(preferences) {
  const prefs = preferences || {};
  if (prefs.enabled === false) return false;
  if (prefs.digest === false) return false;
  return true;
}

/** Az értesítés determinisztikus kulcsa — hetente egyszer futhat le. */
function digestDedupeKey(weekKey, uid) {
  const id = String(uid || '').trim();
  const week = String(weekKey || '').trim();
  if (!id || !week) return '';
  return `${DIGEST_KIND}:${week}:${id}`;
}

/** A hír címe (WordPress alak) vagy üres. */
function itemTitle(item) {
  return String(item?.title?.rendered || item?.title || item?.name || '').trim();
}

/**
 * Mit tartalmazzon az összefoglaló?
 *
 * * **hírek:** a legfrissebb `MAX_DIGEST_NEWS` darab (dátum szerint csökkenő),
 * * **események:** a következő `DIGEST_EVENT_HORIZON_MS`-en belül kezdődők,
 *   kezdés szerint növekvő, legfeljebb `MAX_DIGEST_EVENTS`.
 *
 * A címek **nyelvi térképként** mennek ki (`{hu, en}`), hogy a szöveg a címzett
 * nyelvén épüljön fel — a magyar és az angol lista azonosító szerint párosul.
 */
function digestPlan({ news = [], newsEn = [], events = [], eventsEn = [] } = {}, nowMs = Date.now(), timeZone = DEFAULT_TIME_ZONE) {
  const englishTitles = new Map(
    (Array.isArray(newsEn) ? newsEn : [])
      .map((item) => [String(item?.id ?? '').trim(), itemTitle(item)])
      .filter(([id, title]) => id && title),
  );
  const englishEventTitles = new Map(
    (Array.isArray(eventsEn) ? eventsEn : [])
      .map((item) => [String(item?.id ?? '').trim(), itemTitle(item)])
      .filter(([id, title]) => id && title),
  );

  const localized = (title, englishTitle) =>
    englishTitle && englishTitle !== title ? { hu: title, en: englishTitle } : title;

  const stories = (Array.isArray(news) ? news : [])
    .map((item) => ({
      id: String(item?.id ?? '').trim(),
      title: itemTitle(item),
      at: parseLocalDateTime(item?.date || item?.date_gmt || item?.modified, timeZone),
    }))
    .filter((entry) => entry.id && entry.title && Number.isFinite(entry.at))
    .sort((first, second) => second.at - first.at)
    .slice(0, MAX_DIGEST_NEWS)
    .map((entry) => ({
      id: entry.id,
      title: localized(entry.title, englishTitles.get(entry.id)),
    }));

  const upcoming = (Array.isArray(events) ? events : [])
    .map((item) => {
      const date = String(item?.start_date ?? '').trim();
      const time = String(item?.start_time ?? '').trim() || '12:00';
      return {
        id: String(item?.id ?? '').trim(),
        title: itemTitle(item),
        at: parseLocalDateTime(`${date}T${time}`, timeZone),
        venue: String(item?.venue_name ?? '').trim(),
        city: String(item?.venue_city ?? '').trim(),
      };
    })
    .filter((entry) => entry.id && entry.title && Number.isFinite(entry.at))
    .filter((entry) => entry.at > nowMs && entry.at - nowMs <= DIGEST_EVENT_HORIZON_MS)
    .sort((first, second) => first.at - second.at)
    .slice(0, MAX_DIGEST_EVENTS)
    .map((entry) => ({
      id: entry.id,
      title: localized(entry.title, englishEventTitles.get(entry.id)),
      when: entry.at,
      where: [entry.venue, entry.city].filter((part) => part !== '').join(', '),
    }));

  return { news: stories, events: upcoming };
}

/**
 * A szöveg helyőrzői: `{summary}` (nyelvi térkép) + a darabszámok.
 *
 * A magyar és az angol összegzés **nyelvtanilag helyes** minden kombinációra
 * (csak hír, csak esemény, mindkettő), ezért a darabokat itt fűzzük össze — a
 * katalógus sablonja már csak beilleszti.
 */
function digestParams(plan, language = 'hu') {
  const code = normalizeLanguage(language);
  const newsCount = plan?.news?.length || 0;
  const eventCount = plan?.events?.length || 0;
  const parts = [];
  if (newsCount > 0) parts.push(code === 'en' ? `${newsCount} new ${newsCount === 1 ? 'story' : 'stories'}` : `${newsCount} új hír`);
  if (eventCount > 0) {
    parts.push(code === 'en' ? `${eventCount} upcoming ${eventCount === 1 ? 'event' : 'events'}` : `${eventCount} közelgő esemény`);
  }
  const headlines = (plan?.news || []).map((entry) => entry.title);
  return {
    summary: parts.join(' · '),
    news: newsCount,
    events: eventCount,
    headlines,
  };
}

/** A két nyelvhez tartozó helyőrzők (a `params` nyelvi térképekkel). */
function digestParamsByLanguage(plan) {
  return {
    summary: { hu: digestParams(plan, 'hu').summary, en: digestParams(plan, 'en').summary },
    news: (plan?.news || []).length,
    events: (plan?.events || []).length,
  };
}

module.exports = {
  DIGEST_KIND,
  DEFAULT_TIME_ZONE,
  MAX_DIGEST_NEWS,
  MAX_DIGEST_EVENTS,
  DIGEST_EVENT_HORIZON_MS,
  normalizeLanguage,
  zoneOffsetMinutes,
  instantFromLocalParts,
  parseLocalDateTime,
  localDateIn,
  isoWeekKey,
  digestAllowed,
  digestDedupeKey,
  digestPlan,
  digestParams,
  digestParamsByLanguage,
};
