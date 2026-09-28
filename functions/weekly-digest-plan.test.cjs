'use strict';

/**
 * A **heti összefoglaló** tiszta logikájának tesztje (`functions/weekly-digest-plan.js`).
 *
 * Mérések (nem vélemények):
 *   * az ISO-hét kulcsa **hétfőn** kezdődik, és a vasárnap esti kör ugyanahhoz a
 *     kulcshoz tartozik (különben a hét határán kétszer menne ki);
 *   * a nyári/téli időszámítás szerint a falióra **valódi** pillanatra vált;
 *   * az üres összefoglaló **nem** megy ki;
 *   * a `digest === false` és az `enabled === false` beállítás **kizár**;
 *   * a címek nyelvenként párosulnak (magyar/angol lista azonosító szerint).
 */
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const plan = require('./weekly-digest-plan.js');

test('az ISO-hét kulcsa a hét minden napján ugyanaz, és hétfőn vált', () => {
  const timeZone = 'Europe/Budapest';
  const sunday = new Date('2026-10-11T16:00:00Z'); // vasárnap 18:00 helyi
  const monday = new Date('2026-10-12T05:00:00Z'); // hétfő 07:00 helyi
  assert.equal(plan.isoWeekKey(timeZone, sunday), '2026-W41');
  assert.equal(plan.isoWeekKey(timeZone, new Date('2026-10-05T09:00:00Z')), '2026-W41');
  assert.equal(plan.isoWeekKey(timeZone, monday), '2026-W42');
  assert.notEqual(plan.isoWeekKey(timeZone, sunday), plan.isoWeekKey(timeZone, monday));
});

test('az év végi határ is helyes (a hét a csütörtök évéhez tartozik)', () => {
  const timeZone = 'Europe/Budapest';
  // 2026-12-31 csütörtök → az 2026-W53; 2027-01-01 péntek → még mindig 2026-W53.
  assert.equal(plan.isoWeekKey(timeZone, new Date('2026-12-31T10:00:00Z')), '2026-W53');
  assert.equal(plan.isoWeekKey(timeZone, new Date('2027-01-01T10:00:00Z')), '2026-W53');
  assert.equal(plan.isoWeekKey(timeZone, new Date('2027-01-04T10:00:00Z')), '2027-W01');
});

test('a falióra valódi pillanatra vált (nyár: +2, tél: +1 óra)', () => {
  assert.equal(
    new Date(plan.parseLocalDateTime('2026-10-17T23:00')).toISOString(),
    '2026-10-17T21:00:00.000Z',
  );
  assert.equal(
    new Date(plan.parseLocalDateTime('2026-12-05T23:00')).toISOString(),
    '2026-12-05T22:00:00.000Z',
  );
  assert.ok(Number.isNaN(plan.parseLocalDateTime('nem-dátum')));
});

test('a hírek a legfrissebbel kezdődnek, legfeljebb három darab', () => {
  const news = [1, 2, 3, 4, 5].map((index) => ({
    id: String(index),
    title: { rendered: `Hír ${index}` },
    date: `2026-10-0${index}T10:00:00`,
  }));
  const result = plan.digestPlan({ news }, Date.parse('2026-10-05T10:00:00Z'));
  assert.equal(result.news.length, plan.MAX_DIGEST_NEWS);
  assert.deepEqual(
    result.news.map((entry) => entry.id),
    ['5', '4', '3'],
  );
});

test('csak a következő hét eseményei kerülnek bele, kezdés szerint', () => {
  const now = Date.parse('2026-10-05T10:00:00Z');
  const events = [
    { id: '1', title: { rendered: 'Ma este' }, start_date: '2026-10-05', start_time: '22:00' },
    { id: '2', title: { rendered: 'Jövő héten' }, start_date: '2026-10-11', start_time: '23:00' },
    { id: '3', title: { rendered: 'Két hét múlva' }, start_date: '2026-10-20', start_time: '23:00' },
    { id: '4', title: { rendered: 'Tegnap volt' }, start_date: '2026-10-04', start_time: '23:00' },
  ];
  const result = plan.digestPlan({ events }, now);
  assert.deepEqual(
    result.events.map((entry) => entry.id),
    ['1', '2'],
  );
  assert.equal(result.events[0].where, '');
});

test('a helyszín és a város együtt jelenik meg', () => {
  const result = plan.digestPlan(
    {
      events: [
        {
          id: '7',
          title: { rendered: 'Buli' },
          start_date: '2026-10-06',
          start_time: '23:00',
          venue_name: 'Stenk',
          venue_city: 'Budapest',
        },
      ],
    },
    Date.parse('2026-10-05T10:00:00Z'),
  );
  assert.equal(result.events[0].where, 'Stenk, Budapest');
});

test('a címek nyelvenként párosulnak, és a magyar marad az alap', () => {
  const result = plan.digestPlan(
    {
      news: [{ id: '9', title: { rendered: 'Magyar cím' }, date: '2026-10-05T10:00:00' }],
      newsEn: [{ id: '9', title: { rendered: 'English title' } }],
      events: [{ id: '8', title: { rendered: 'Magyar esemény' }, start_date: '2026-10-06', start_time: '22:00' }],
      eventsEn: [],
    },
    Date.parse('2026-10-05T10:00:00Z'),
  );
  assert.deepEqual(result.news[0].title, { hu: 'Magyar cím', en: 'English title' });
  assert.equal(result.events[0].title, 'Magyar esemény');
});

test('üres hét: nincs sem hír, sem esemény', () => {
  const result = plan.digestPlan({}, Date.parse('2026-10-05T10:00:00Z'));
  assert.equal(result.news.length, 0);
  assert.equal(result.events.length, 0);
  assert.equal(plan.digestParamsByLanguage(result).summary.hu, '');
  assert.equal(plan.digestParamsByLanguage(result).summary.en, '');
});

test('az összegzés nyelvtanilag helyes minden kombinációra', () => {
  const onlyNews = { news: [{ id: '1' }], events: [] };
  const onlyEvents = { news: [], events: [{ id: '1' }] };
  const both = { news: [{ id: '1' }, { id: '2' }], events: [{ id: '1' }] };
  assert.equal(plan.digestParams(onlyNews, 'hu').summary, '1 új hír');
  assert.equal(plan.digestParams(onlyNews, 'en').summary, '1 new story');
  assert.equal(plan.digestParams(onlyEvents, 'hu').summary, '1 közelgő esemény');
  assert.equal(plan.digestParams(onlyEvents, 'en').summary, '1 upcoming event');
  assert.equal(plan.digestParams(both, 'hu').summary, '2 új hír · 1 közelgő esemény');
  assert.equal(plan.digestParams(both, 'en').summary, '2 new stories · 1 upcoming event');
});

test('a beállítás-kapuk zárnak (enabled és digest)', () => {
  assert.equal(plan.digestAllowed({}), true);
  assert.equal(plan.digestAllowed({ digest: true, enabled: true }), true);
  assert.equal(plan.digestAllowed({ enabled: false }), false);
  assert.equal(plan.digestAllowed({ digest: false }), false);
  assert.equal(plan.digestAllowed(null), true);
});

test('a heti kulcs determinisztikus és hetente más', () => {
  const first = plan.digestDedupeKey('2026-W41', 'uid-1');
  const second = plan.digestDedupeKey('2026-W41', 'uid-1');
  const nextWeek = plan.digestDedupeKey('2026-W42', 'uid-1');
  assert.equal(first, second);
  assert.notEqual(first, nextWeek);
  assert.match(first, /^weekly_digest:2026-W41:/);
  assert.equal(plan.digestDedupeKey('', 'uid-1'), '');
  assert.equal(plan.digestDedupeKey('2026-W41', ''), '');
});

test('a katalógusban van heti összefoglaló szöveg, magyarul és angolul', () => {
  const catalog = require('./notification-texts.js');
  const hu = catalog.notificationText('weekly_digest', 'hu', { summary: '3 új hír' });
  const en = catalog.notificationText('weekly_digest', 'en', { summary: '3 new stories' });
  assert.ok(hu && hu.title && hu.body.includes('3 új hír'), JSON.stringify(hu));
  assert.ok(en && en.title && en.body.includes('3 new stories'), JSON.stringify(en));
  assert.notEqual(hu.title, en.title);
});

test('forrás-lint: az ütemezett kör létezik és a tiszta döntést használja', () => {
  const source = fs.readFileSync(path.join(__dirname, 'index.js'), 'utf8');
  assert.match(source, /exports\.sendWeeklyDigest\s*=\s*onSchedule\(/);
  assert.match(source, /schedule:\s*'every sunday 18:00'/);
  assert.match(source, /require\('\.\/weekly-digest-plan(\.js)?'\)/);
  // A küldés előtt **kapuk** vannak: a beállítás és a „már kiment" védelem.
  // (A `index.js` a könnyebb olvashatóság kedvéért `weeklyDigest…` néven importál.)
  assert.match(source, /weeklyDigestAllowed\(/);
  assert.match(source, /weeklyDigestDedupeKey\(/);
  // Az üres összefoglaló nem megy ki.
  assert.match(source, /weeklyDigestPlan\(/);
  assert.match(source, /skipped: 'empty'/);
  // Push csak akkor, ha az értesítés TÉNYLEG létrejött (nincs dupla küldés).
  assert.match(source, /if \(!notificationCreated\) continue;/);
  // A katalógus-típus és a hangnem a szerveroldali katalógusból jön.
  assert.match(source, /notificationTextFor\(uid, WEEKLY_DIGEST_KIND, params\)/);
});
