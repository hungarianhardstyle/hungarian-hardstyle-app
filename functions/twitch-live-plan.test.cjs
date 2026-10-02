'use strict';

/**
 * A TWITCH-ÉLŐ FIGYELŐ tiszta döntésének mérése — hálózat és Firestore nélkül.
 *
 * ⚠️ A minták a 2026-10-01-i éles mérés alakját követik
 * (`node tmp/probe-twitch.mjs`): a nyilvános web-kliens GraphQL-válasza,
 * `HungarianHardstyle`, `id 87485328`.
 */

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const {
  TWITCH_CHANNEL,
  TWITCH_WEB_CLIENT_ID,
  twitchThumbnailUrl,
  twitchLiveQuery,
  parseTwitchLive,
  twitchLiveNoticePlan,
  twitchLiveNoticeParams,
} = require('./twitch-live-plan');

const LIVE_BODY = JSON.stringify({
  data: {
    user: {
      id: '87485328',
      displayName: 'HungarianHardstyle',
      stream: {
        id: '44123456789',
        title: 'HUHS Live #42 — hardstyle session',
        viewersCount: 128,
        createdAt: '2026-10-01T18:00:00Z',
        type: 'live',
        game: { name: 'Music' },
        previewImageURL: 'https://static-cdn.jtvnw.net/previews-ttv/live_user_hungarianhardstyle-640x360.jpg',
      },
    },
  },
});

test('a csatorna és a kliens-azonosító a mért érték', () => {
  assert.equal(TWITCH_CHANNEL, 'hungarianhardstyle');
  assert.equal(TWITCH_WEB_CLIENT_ID, 'kimne78kx3ncx6brgo4mv6wki5h1ko');
});

test('a lekérdezés a mért mezőket kéri', () => {
  const query = twitchLiveQuery();
  assert.match(query, /user\(login:"hungarianhardstyle"\)/);
  assert.match(query, /viewersCount/);
  assert.match(query, /previewImageURL/);
});

test('élő adás: a cím, a nézők és az adás azonosítója kiolvasható', () => {
  const live = parseTwitchLive(LIVE_BODY);
  assert.equal(live.isLive, true);
  assert.equal(live.streamId, '44123456789');
  assert.equal(live.title, 'HUHS Live #42 — hardstyle session');
  assert.equal(live.viewers, 128);
  assert.equal(live.game, 'Music');
  assert.match(live.thumbnailUrl, /previews-ttv/);
});

test('nem élő (stream = null): nem jelez élőt, de a borító URL megvan', () => {
  const live = parseTwitchLive('{"data":{"user":{"id":"87485328","stream":null}}}');
  assert.equal(live.isLive, false);
  assert.equal(live.thumbnailUrl, twitchThumbnailUrl());
});

test('hibás JSON és üres válasz: nem dob, nem jelez élőt', () => {
  for (const body of ['', 'nem json', '{}', '{"data":{}}', null, undefined]) {
    const live = parseTwitchLive(body);
    assert.equal(live.isLive, false, String(body));
  }
});

test('a borítókép sablon-URL-je a csatornára épül', () => {
  assert.equal(
    twitchThumbnailUrl('HungarianHardstyle'),
    'https://static-cdn.jtvnw.net/previews-ttv/live_user_hungarianhardstyle-640x360.jpg',
  );
});

test('ÚJ adás: értesítés indul, és a jelölés az adás azonosítója lesz', () => {
  const live = parseTwitchLive(LIVE_BODY);
  const plan = twitchLiveNoticePlan({ live, announcedStreamId: '' });
  assert.equal(plan.notify, true);
  assert.equal(plan.reason, 'new-stream');
  assert.equal(plan.streamId, '44123456789');
});

test('UGYANAZ az adás: nincs második értesítés (a cím módosítása sem számít)', () => {
  const live = parseTwitchLive(LIVE_BODY);
  const plan = twitchLiveNoticePlan({ live, announcedStreamId: '44123456789' });
  assert.equal(plan.notify, false);
  assert.equal(plan.reason, 'already-announced');
});

test('az adás VÉGE törli a jelölést, ezért a következő adás újra szól', () => {
  const ended = twitchLiveNoticePlan({
    live: { isLive: false, streamId: '', title: '' },
    announcedStreamId: '44123456789',
  });
  assert.equal(ended.notify, false);
  assert.equal(ended.reason, 'stream-ended');
  assert.equal(ended.reset, true, 'a jelölést törölni kell');

  const next = twitchLiveNoticePlan({
    live: { isLive: true, streamId: '44999999999', title: 'Új adás' },
    announcedStreamId: '',
  });
  assert.equal(next.notify, true);
  assert.equal(next.streamId, '44999999999');
});

test('kikapcsolt kapcsolóval nem indul értesítés', () => {
  const live = parseTwitchLive(LIVE_BODY);
  const plan = twitchLiveNoticePlan({ live, announcedStreamId: '', enabled: false });
  assert.equal(plan.notify, false);
  assert.equal(plan.reason, 'disabled');
});

test('adás azonosító nélkül nem küldünk (nem tippelünk)', () => {
  const plan = twitchLiveNoticePlan({
    live: { isLive: true, streamId: '', title: 'x' },
    announcedStreamId: '',
  });
  assert.equal(plan.notify, false);
  assert.equal(plan.reason, 'no-stream-id');
});

test('a szövegparaméter a stream címe (üresen a csatorna neve)', () => {
  assert.deepEqual(twitchLiveNoticeParams({ title: 'HUHS Live' }), { title: 'HUHS Live' });
  assert.deepEqual(twitchLiveNoticeParams({ title: '   ' }), { title: 'Hungarian Hardstyle' });
  assert.deepEqual(twitchLiveNoticeParams(null), { title: 'Hungarian Hardstyle' });
});

test('a katalógusban van twitch_live szöveg, MINDKÉT nyelven', () => {
  const catalogue = fs.readFileSync(path.join(__dirname, 'notification-texts.js'), 'utf8');
  assert.match(catalogue, /twitch_live:\s*\{/);
  const block = catalogue.slice(catalogue.indexOf('twitch_live:'));
  assert.match(block.slice(0, 400), /hu:\s*\{\s*title:/);
  assert.match(block.slice(0, 400), /en:\s*\{\s*title:/);
});

test('a figyelő be van kötve az indexbe (5 perces ütemezés, jelöléssel)', () => {
  const index = fs.readFileSync(path.join(__dirname, 'index.js'), 'utf8');
  assert.match(index, /exports\.sendTwitchLiveNotice\s*=\s*onSchedule\(/);
  assert.match(index, /twitch_live/);
  assert.match(index, /app_settings/);
  assert.match(index, /twitchLiveNoticePlan/);
});
