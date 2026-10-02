'use strict';

/**
 * TWITCH-ÉLŐ FIGYELŐ — a **tiszta döntés** (hálózat és Firestore nélkül mérhető).
 *
 * MIÉRT (a tulajdonos kérése, 2026-10-01): *„érzekelje ha indul a twitch stream”*
 * és *„szóljon push mindenkinek, amikor elindítod a Twitch-streamet”*.
 *
 * A mérés szerint az élő állapot **kulcs nélkül** kiolvasható a Twitch nyilvános
 * web-kliensével:
 *
 * ```
 * POST https://gql.twitch.tv/gql    (Client-ID: kimne78kx3ncx6brgo4mv6wki5h1ko)
 *   → user(login:"hungarianhardstyle") { stream { id title viewersCount previewImageURL } }
 * ```
 * A mért válasz: `HungarianHardstyle`, `id 87485328`; élő adásnál a `stream`
 * kitöltve, egyébként `null`. A hivatalos Helix API **OAuth tokent** kér (401),
 * ezért nem használjuk.
 *
 * ⚠️ A DÖNTÉS LÉNYEGE: **egy adásról egyszer** szólunk. A jelölés az adás
 * azonosítója (`streamId`), amit a hívó tárol (`app_settings/twitch_live`).
 * Amikor az adás véget ér, a jelölés **törlődik**, ezért a KÖVETKEZŐ adás újra
 * szól — a stream címének módosítása viszont nem ad új értesítést.
 */

const TWITCH_CHANNEL = 'hungarianhardstyle';

/** A nyilvános Twitch web-kliens azonosítója (ugyanaz, amit a twitch.tv oldal használ). */
const TWITCH_WEB_CLIENT_ID = 'kimne78kx3ncx6brgo4mv6wki5h1ko';

/** A borítókép sablonja — élő adásnál ez a **mozgó** kép. */
function twitchThumbnailUrl(channel = TWITCH_CHANNEL, width = 640, height = 360) {
  return `https://static-cdn.jtvnw.net/previews-ttv/live_user_${String(channel).toLowerCase()}-${width}x${height}.jpg`;
}

/** A GraphQL-lekérdezés (tiszta szöveg, ezért forrás-linttel mérhető). */
function twitchLiveQuery(channel = TWITCH_CHANNEL) {
  return (
    `query{user(login:"${channel}"){id displayName stream{id title viewersCount createdAt type ` +
    'game{name} previewImageURL(width:640,height:360)}}}'
  );
}

/**
 * A nyilvános válasz értelmezése.
 *
 * Toleráns: hiányzó mezőkre és hibás JSON-ra **nem-élő** állapotot ad (nem tippel).
 */
function parseTwitchLive(body, channel = TWITCH_CHANNEL) {
  const empty = {
    isLive: false,
    streamId: '',
    title: '',
    viewers: 0,
    game: '',
    thumbnailUrl: twitchThumbnailUrl(channel),
  };
  let decoded;
  try {
    decoded = JSON.parse(String(body ?? ''));
  } catch {
    return empty;
  }
  const stream = decoded?.data?.user?.stream;
  if (!stream || typeof stream !== 'object') return empty;
  const thumbnail = String(stream.previewImageURL ?? '').trim();
  return {
    isLive: true,
    streamId: String(stream.id ?? '').trim(),
    title: String(stream.title ?? '').trim(),
    viewers: Number(stream.viewersCount) || 0,
    game: String(stream.game?.name ?? '').trim(),
    thumbnailUrl: thumbnail || twitchThumbnailUrl(channel),
  };
}

/**
 * A döntés: kell-e most értesítést küldeni?
 *
 * @param {object} input
 * @param {{isLive: boolean, streamId: string, title: string}} input.live a mért állapot
 * @param {string} input.announcedStreamId a legutóbb bejelentett adás azonosítója
 * @param {boolean} [input.enabled] a tulajdonosi kapcsoló (alapból BE)
 * @returns {{notify: boolean, reason: string, streamId: string, reset: boolean}}
 */
function twitchLiveNoticePlan({ live, announcedStreamId = '', enabled = true } = {}) {
  const state = live && typeof live === 'object' ? live : {};
  const streamId = String(state.streamId ?? '').trim();
  const announced = String(announcedStreamId ?? '').trim();

  if (state.isLive !== true) {
    // Az adás véget ért: a jelölést töröljük, hogy a KÖVETKEZŐ adás szóljon.
    return { notify: false, reason: announced ? 'stream-ended' : 'offline', streamId: '', reset: Boolean(announced) };
  }
  if (!enabled) return { notify: false, reason: 'disabled', streamId, reset: false };
  if (!streamId) return { notify: false, reason: 'no-stream-id', streamId: '', reset: false };
  if (streamId === announced) return { notify: false, reason: 'already-announced', streamId, reset: false };
  return { notify: true, reason: 'new-stream', streamId, reset: false };
}

/** A push és az appon belüli értesítés szövegparaméterei (nyelvenként a katalógus fordítja). */
function twitchLiveNoticeParams(live) {
  const title = String(live?.title ?? '').trim();
  return { title: title || 'Hungarian Hardstyle' };
}

module.exports = {
  TWITCH_CHANNEL,
  TWITCH_WEB_CLIENT_ID,
  twitchThumbnailUrl,
  twitchLiveQuery,
  parseTwitchLive,
  twitchLiveNoticePlan,
  twitchLiveNoticeParams,
};
