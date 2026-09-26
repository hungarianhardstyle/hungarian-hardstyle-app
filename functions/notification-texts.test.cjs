'use strict';

/**
 * A `notification-texts.js` (nyelvi katalógus) tesztjei — **hálózat és Firestore
 * nélkül**, mert a modul szándékosan tiszta.
 *
 * A lényeg, amit mérünk:
 *  1. minden `kind`-nak van **mindkét** nyelvű szövege, és a magyar szövegek
 *     **szó szerint** az eddigiek (nem csúszhat el a HU élmény),
 *  2. a helyőrzők **mindkét** nyelvben ugyanazok (különben a név kimaradna),
 *  3. ismeretlen nyelv/hiányzó mező → **magyar** (fallback),
 *  4. ismeretlen `kind` → `null` (a hívó a saját szövegére esik vissza),
 *  5. a pontforrás-leképezés mind a 14 ágat lefedi.
 */
const test = require('node:test');
const assert = require('node:assert/strict');

const {
  DEFAULT_NOTIFICATION_LANGUAGE,
  NOTIFICATION_LANGUAGES,
  TEXTS,
  achievementReasonKey,
  achievementReasonText,
  normalizeNotificationLanguage,
  notificationText,
} = require('./notification-texts.js');

const placeholders = (value) => [...String(value ?? '').matchAll(/\{(\w+)\}/g)].map((m) => m[1]).sort();

test('minden kind mindkét nyelven teljes', () => {
  const kinds = Object.keys(TEXTS);
  assert.ok(kinds.length >= 25, `várt legalább 25 kind, mért: ${kinds.length}`);
  for (const kind of kinds) {
    const entry = TEXTS[kind];
    for (const language of NOTIFICATION_LANGUAGES) {
      const text = entry[language];
      assert.ok(text, `${kind}: hiányzik a(z) ${language} szöveg`);
      assert.equal(typeof text.title, 'string', `${kind}.${language}.title`);
      assert.equal(typeof text.body, 'string', `${kind}.${language}.body`);
      // A cím lehet üres (a pontforrás-indoklásnál szándékosan az), a törzs nem.
      if (!kind.startsWith('achievement_reason_')) {
        assert.ok(text.title.trim(), `${kind}.${language}.title nem lehet üres`);
      }
      assert.ok(text.body.trim(), `${kind}.${language}.body nem lehet üres`);
    }
    // A helyőrzők mindkét nyelven ugyanazok — különben a név/részlet kimaradna.
    assert.deepEqual(
      placeholders(entry.hu.title),
      placeholders(entry.en.title),
      `${kind}: a cím helyőrzői eltérnek`,
    );
    assert.deepEqual(
      placeholders(entry.hu.body),
      placeholders(entry.en.body),
      `${kind}: a törzs helyőrzői eltérnek`,
    );
  }
});

test('a magyar szövegek szó szerint az eddigiek (nem csúszott el a HU élmény)', () => {
  const expected = {
    chat_reaction: ['Kedvelték a Chat-üzenetedet', '{name} kedvelte a Chat-üzenetedet.'],
    chat_reply: ['Válaszoltak a Chat-üzenetedre', '{name} válaszolt a Chat-üzenetedre.'],
    chat_mention: ['Megemlítettek a Chatben', '{name} megemlített a Chatben: „{snippet}”'],
    chat_everyone: ['Megemlítettek a Chatben', '{name} mindenkit megemlített a Chatben: „{snippet}”'],
    article_comment: ['Új hozzászólás érkezett', '{name} hozzászólt egy cikkhez: „{snippet}”'],
    article_comment_reply: [
      'Válaszoltak a hozzászólásodra',
      '{name} válaszolt a hozzászólásodra egy cikknél.',
    ],
    event_rating_request: ['Értékeld az eseményt', '{event} véget ért. Értékeld az eseményt az appban.'],
    new_news: ['Új hír érkezett', '{name}'],
    new_release: ['Új release érkezett', '{name}'],
    new_artist: ['Új DJ került fel', '{name}'],
    new_organizer: ['Új szervező került fel', '{name}'],
    new_event: ['Új esemény érkezett', '{name}'],
    prize_winner: ['🏆 Nyertél a nyereményjátékban!', 'Megnyerted a nyereményjátékot: {prize}'],
    prize_winner_no_prize: ['🏆 Nyertél a nyereményjátékban!', 'Megnyerted a nyereményjátékot!'],
    connection_request: ['Új ismerősnek jelölés', '{name} ismerősnek jelölt.'],
    meetup_interest: [
      'Új Meetup érdeklődés',
      '{name} szívesen találkozna veled a(z) {event} eseményen.',
    ],
    chat_report: ['Új chatjelentés', '{name} új chatjelentést küldött.'],
    chat_report_reason: ['Új chatjelentés', '{name}: {reason}'],
  };
  for (const [kind, [title, body]] of Object.entries(expected)) {
    assert.equal(TEXTS[kind].hu.title, title, `${kind} hu cím`);
    assert.equal(TEXTS[kind].hu.body, body, `${kind} hu törzs`);
  }
  assert.equal(
    TEXTS.achievement_reason_news_like.hu.body,
    'egy hír kedveléséért',
    'a pontforrás-indoklás magyar szövege',
  );
  assert.equal(
    TEXTS.achievement_reason_daily_activity.hu.body,
    'a tegnapi közösségi aktivitásodért (hozzászólás és chat)',
    'a napi aktivitás indoklása',
  );
});

test('a szöveg a kért nyelven jön, a helyőrzők kitöltve', () => {
  const hu = notificationText('chat_reaction', 'hu', { name: 'Anna' });
  assert.deepEqual(hu, {
    title: 'Kedvelték a Chat-üzenetedet',
    body: 'Anna kedvelte a Chat-üzenetedet.',
  });
  const en = notificationText('chat_reaction', 'en', { name: 'Anna' });
  assert.deepEqual(en, {
    title: 'Your Chat message was liked',
    body: 'Anna liked your Chat message.',
  });
});

test('a magyar és az angol szöveg KÜLÖNBÖZIK (nem maradt magyarul)', () => {
  for (const kind of Object.keys(TEXTS)) {
    if (kind.startsWith('achievement_reason_')) continue;
    const hu = notificationText(kind, 'hu', { name: 'X', event: 'Y', prize: 'Z', snippet: 'S' });
    const en = notificationText(kind, 'en', { name: 'X', event: 'Y', prize: 'Z', snippet: 'S' });
    assert.notDeepEqual(en, hu, `${kind}: az angol szöveg megegyezik a magyarral`);
    // Az angol szövegben nem lehet magyar ékezetes szó (a márkanevek kivételével).
    assert.ok(
      !/[áéíóöőúüű]/i.test(en.body.replace(/Hungarian Hardstyle/g, '')),
      `${kind}: magyar ékezet maradt az angol törzsben: ${en.body}`,
    );
  }
});

test('ismeretlen vagy hiányzó nyelv → magyar (fallback)', () => {
  for (const value of [undefined, null, '', 'de', 'xx-YY', 'magyar']) {
    assert.equal(normalizeNotificationLanguage(value), DEFAULT_NOTIFICATION_LANGUAGE);
    const text = notificationText('chat_reaction', value, { name: 'Anna' });
    assert.equal(text.title, TEXTS.chat_reaction.hu.title);
  }
  // Az angol változatok felismerése (nyelv-kód változatokkal).
  for (const value of ['en', 'EN', 'en-US', 'en_US']) {
    assert.equal(normalizeNotificationLanguage(value), 'en');
  }
});

test('ismeretlen kind → null (nem tippelünk szöveget)', () => {
  assert.equal(notificationText('nincs_ilyen', 'hu', {}), null);
  assert.equal(notificationText('', 'hu', {}), null);
  assert.equal(notificationText(undefined, 'en', {}), null);
});

test('a pontforrás mind a 14 ágat lefedi', () => {
  const cases = {
    'news-like:abc': 'achievement_reason_news_like',
    'article-comment:abc': 'achievement_reason_article_comment',
    'attendance:abc': 'achievement_reason_attendance',
    'meetup:abc': 'achievement_reason_meetup',
    'meetup-interest:abc': 'achievement_reason_meetup_interest',
    'event-rating:abc': 'achievement_reason_event_rating',
    'voting:abc': 'achievement_reason_voting',
    'game:abc': 'achievement_reason_game',
    'profile-complete': 'achievement_reason_profile_complete',
    'referral:abc': 'achievement_reason_referral',
    'news-like-restore:abc': 'achievement_reason_news_like_restore',
    'submission:abc': 'achievement_reason_submission',
    'release-purchase:abc': 'achievement_reason_release_purchase',
    'daily-activity:abc': 'achievement_reason_daily_activity',
  };
  assert.equal(Object.keys(cases).length, 14, 'a mért 14 ág');
  for (const [sourceKey, kind] of Object.entries(cases)) {
    assert.equal(achievementReasonKey(sourceKey), kind, sourceKey);
    assert.ok(TEXTS[kind], `${kind} hiányzik a katalógusból`);
    assert.ok(achievementReasonText(sourceKey, 'hu').length > 0, sourceKey);
  }
  assert.equal(achievementReasonKey('ismeretlen:abc'), 'achievement_reason_generic');
  assert.equal(achievementReasonKey(undefined), 'achievement_reason_generic');
});

test('a pont-értesítés a címzett nyelvén épül fel (rangváltással is)', () => {
  const en = notificationText('achievement_points_level', 'en', {
    delta: 5,
    reasonKey: 'achievement_reason_news_like',
    points: 120,
    badge: 'Legend',
  });
  assert.equal(en.title, '+5 achievement points');
  assert.equal(en.body, '+5 points for liking a news article. Your new total is 120. New rank: “Legend”.');
  const hu = notificationText('achievement_points', 'hu', {
    delta: 5,
    reasonKey: 'achievement_reason_news_like',
    points: 120,
  });
  // ⚠️ 2026-09-26: a magyar sablonból javítottuk a szóismétlést
  // („Új összösszpontszámod" → „Új összpontszámod") — a tulajdonos jelzése:
  // *„ez a magyarnál javítandó"*.
  assert.equal(hu.body, '+5 pont egy hír kedveléséért. Új összpontszámod: 120.');
  // A kész `reason` elsőbbséget élvez a `reasonKey`-jel szemben.
  const explicit = notificationText('achievement_points', 'en', { delta: 1, reason: 'for testing', points: 2 });
  assert.equal(explicit.body, '+1 points for testing. Your new total is 2.');
});

test('a hiányzó név a NYELVNEK megfelelő tartalékot kapja', () => {
  const hu = notificationText('chat_reaction', 'hu', {});
  assert.equal(hu.body, 'Egy HUHS tag kedvelte a Chat-üzenetedet.');
  const en = notificationText('chat_reaction', 'en', {});
  assert.equal(en.body, 'A HUHS member liked your Chat message.');
  // A többi hiányzó helyőrző üres marad (nem `undefined`).
  const noPrize = notificationText('prize_winner', 'en', {});
  assert.equal(noPrize.body, 'You won the giveaway: ');
  assert.ok(!noPrize.body.includes('undefined'));
  // Az üres string is tartalékra esik (a régi hívók üres nevet adhatnak).
  assert.equal(
    notificationText('chat_reply', 'en', { name: '   ' }).body,
    'A HUHS member replied to your Chat message.',
  );
});
