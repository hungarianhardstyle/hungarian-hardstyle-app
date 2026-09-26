/**
 * Chat-@hivatkozás (mention) — a SZERVEROLDALI döntés mérése.
 *
 * **A tulajdonos kérése:** *„Kéne olyan, hogy egy @xy betűvel tudjak hivatkozni
 * a chaten cikkre, djre, szervezőre, eseményre, kiadványra vagy személyre/userre,
 * ha személyre hivatkozok kapjon róla notifyt"* — és a döntései:
 *
 *  1. **mind a hat típus** egyszerre;
 *  2. minden megemlített **személy** kap értesítést, de **legfeljebb 5/üzenet**;
 *  3. a nem admin/moderátor **tartalom-hivatkozásait a szerver kihagyja**
 *     (a szöveg marad), és visszaadja a **kihagyottak számát**;
 *  4. egyelőre **csak a Chat** (a cikk-kommentek nem).
 *
 * **Később (2026-09-25) ehhez jött az `@mindenki`** (a tulajdonos kérése:
 * *„kéne egy @mindenki tag is, amit ha beütök, kap mindenki notifyt és csak
 * moderátor/admin használhassa"*): a típus **csak privileged** küldőnek jár,
 * **egyszer** szerepelhet, az `id`/`label` pedig a **szerver** kanonikus értéke
 * (`everyone` / `mindenki`) — a kliens címkéjét nem hisszük el.
 *
 * Ez a teszt a döntést méri (`functions/chat-mention-plan.js`) — hálózat és
 * Firestore nélkül —, a végén pedig forrás-linttel azt, hogy a `publishChatPost`
 * a tiszta tervet használja **privileged** módban, az `@mindenki` fan-outot a
 * `community_profiles`-ból, kötegelt best-effort írással, és hogy a
 * Firestore-szabály ismeri a `mentions` mezőt (az `everyone` alakja beleillik,
 * ezért **nem** kellett bővíteni).
 *
 * Futtatás: node --test functions/chat-mention-plan.test.cjs
 */

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const {
  MENTION_TYPES,
  MAX_MENTIONS,
  MAX_USER_NOTIFICATIONS,
  MAX_EXCERPT_LENGTH,
  EVERYONE_TYPE,
  EVERYONE_ID,
  EVERYONE_LABEL,
  MAX_EVERYONE_RECIPIENTS,
  sanitizeMentions,
  chatMentionNotifications,
  chatEveryoneNotification,
  chatEveryoneNotifications,
  chatEveryonePushMessage,
  everyonePushTargets,
} = require('./chat-mention-plan');
const { notificationText } = require('./notification-texts');

const functionsSource = fs.readFileSync(path.join(__dirname, 'index.js'), 'utf8');
const rulesSource = fs.readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8');

/** A KIMENET-oldal mezői: a szerző neve körüli idézőjel a magyar helyesírás. */
const quoted = (excerpt) => `Nagy Anna megemlített a Chatben: „${excerpt}”`;

test('a hét típus (hat + everyone) és a korlátok exportálva vannak', () => {
  assert.deepEqual([...MENTION_TYPES], [
    'user',
    'article',
    'artist',
    'organizer',
    'event',
    'release',
    'everyone',
  ]);
  assert.equal(MAX_MENTIONS, 10);
  assert.equal(MAX_USER_NOTIFICATIONS, 5);
  // Az @mindenki kanonikus alakja és a fan-out plafonja (ma 41 profil van).
  assert.equal(EVERYONE_TYPE, 'everyone');
  assert.equal(EVERYONE_ID, 'everyone');
  assert.equal(EVERYONE_LABEL, 'mindenki');
  assert.equal(MAX_EVERYONE_RECIPIENTS, 500);
});

test('nem tömb bemenetre üres lista, és ilyenkor nincs mit kihagyni', () => {
  for (const raw of [undefined, null, 'user:uid-1', {}, 42, true]) {
    assert.deepEqual(sanitizeMentions(raw), { mentions: [], dropped: 0 });
  }
  // A régi kliens egyáltalán nem küldi a mezőt — az sem hiba.
  assert.deepEqual(sanitizeMentions(), { mentions: [], dropped: 0 });
});

test('SZEMÉLY-hivatkozás nem privileged módban is átmegy (mindenkinek jár)', () => {
  const { mentions, dropped } = sanitizeMentions([
    { type: 'user', id: 'uid-1', label: 'Kobakologia' },
  ]);
  assert.deepEqual(mentions, [{ type: 'user', id: 'uid-1', label: 'Kobakologia' }]);
  assert.equal(dropped, 0);
});

test('a nem admin/moderátor TARTALOM-hivatkozásait a szerver kihagyja (dropped++)', () => {
  const { mentions, dropped } = sanitizeMentions([
    { type: 'user', id: 'uid-1', label: 'Kobakologia' },
    { type: 'article', id: '991', label: 'Új cikk' },
    { type: 'artist', id: '12812', label: 'Goze' },
    { type: 'organizer', id: '77', label: 'Szervező' },
    { type: 'event', id: '12505', label: 'Hard Base Classic' },
    { type: 'release', id: '12699', label: 'Kiadvány' },
  ]);

  assert.deepEqual(mentions, [{ type: 'user', id: 'uid-1', label: 'Kobakologia' }]);
  assert.equal(dropped, 5, 'a kihagyottak száma megy vissza a kliensnek');
});

test('privileged módban mind az öt tartalom-típus átmegy', () => {
  const raw = [
    { type: 'user', id: 'uid-1', label: 'Kobakologia' },
    { type: 'article', id: '991', label: 'Új cikk' },
    { type: 'artist', id: '12812', label: 'Goze' },
    { type: 'organizer', id: '77', label: 'Szervező' },
    { type: 'event', id: '12505', label: 'Hard Base Classic' },
    { type: 'release', id: '12699', label: 'Kiadvány' },
  ];

  const { mentions, dropped } = sanitizeMentions(raw, { privileged: true });
  assert.deepEqual(
    mentions.map((mention) => mention.type),
    ['user', 'article', 'artist', 'organizer', 'event', 'release'],
  );
  assert.equal(dropped, 0);
});

test('ismeretlen típus és érvénytelen id/label kiesik (dropped++)', () => {
  const { mentions, dropped } = sanitizeMentions(
    [
      { type: 'post', id: '1', label: 'Ismeretlen típus' },
      { type: 'user', id: '', label: 'Üres azonosító' },
      { type: 'user', id: 'x'.repeat(65), label: 'Túl hosszú azonosító' },
      { type: 'user', id: 'uid-1', label: '' },
      { type: 'user', id: 'uid-1', label: 'y'.repeat(81) },
      { type: 'user', id: 12, label: 'Szám azonosító (nem string)' },
      { type: 'user', id: 'uid-2' },
      null,
      'user',
      42,
    ],
    { privileged: true },
  );

  assert.deepEqual(mentions, []);
  assert.equal(dropped, 10);
});

test('az id és a label trimelve kerül a listába, a hosszkorlát a tisztított értéken mér', () => {
  const { mentions, dropped } = sanitizeMentions([
    { type: 'user', id: '  uid-1  ', label: '  Kobakologia  ' },
    { type: 'user', id: ` ${'x'.repeat(64)} `, label: 'Pont 64 a tisztítás után' },
    { type: 'user', id: 'uid-3', label: ` ${'y'.repeat(80)} ` },
  ]);

  assert.deepEqual(mentions[0], { type: 'user', id: 'uid-1', label: 'Kobakologia' });
  assert.equal(mentions[1].id.length, 64);
  assert.equal(mentions[2].label.length, 80);
  assert.equal(dropped, 0);
});

test('ugyanaz a type:id EGY hivatkozás — a duplikátum nem számít kihagyottnak', () => {
  const { mentions, dropped } = sanitizeMentions(
    [
      { type: 'user', id: 'uid-1', label: 'Kobakologia' },
      { type: 'user', id: 'uid-1', label: 'Kobakologia (másodszor)' },
      { type: 'event', id: 'uid-1', label: 'Ugyanaz az id, más típus' },
    ],
    { privileged: true },
  );

  assert.deepEqual(mentions, [
    { type: 'user', id: 'uid-1', label: 'Kobakologia' },
    { type: 'event', id: 'uid-1', label: 'Ugyanaz az id, más típus' },
  ]);
  assert.equal(dropped, 0, 'a duplikátum nem büntetés');
});

test('a 10. utáni érvényes hivatkozás kiesik (dropped++)', () => {
  const raw = Array.from({ length: 12 }, (_, index) => ({
    type: 'user',
    id: `uid-${index}`,
    label: `Tag ${index}`,
  }));

  const { mentions, dropped } = sanitizeMentions(raw);
  assert.equal(mentions.length, MAX_MENTIONS);
  assert.equal(mentions[MAX_MENTIONS - 1].id, 'uid-9');
  assert.equal(dropped, 2);
});

test('a plafon fölötti DUPLIKÁTUM nem növeli a kihagyottak számát', () => {
  const raw = Array.from({ length: MAX_MENTIONS }, (_, index) => ({
    type: 'user',
    id: `uid-${index}`,
    label: `Tag ${index}`,
  }));
  raw.push({ type: 'user', id: 'uid-0', label: 'Tag 0 újra' });

  const { mentions, dropped } = sanitizeMentions(raw);
  assert.equal(mentions.length, MAX_MENTIONS);
  assert.equal(dropped, 0);
});

test('csak SZEMÉLY-hivatkozásból lesz értesítés, és a payload teljes', () => {
  const notifications = chatMentionNotifications({
    postId: 'post-9',
    authorId: 'author-1',
    authorName: 'Nagy Anna',
    mentions: [
      { type: 'event', id: '12505', label: 'Hard Base Classic' },
      { type: 'user', id: 'uid-1', label: 'Kobakologia' },
    ],
    text: 'Szia @Kobakologia!',
  });

  assert.equal(notifications.length, 1, 'a tartalom-hivatkozás nem szól senkinek');
  const notification = notifications[0];
  assert.equal(notification.recipientUid, 'uid-1');
  assert.equal(notification.type, 'chat_mention');
  // ⚠️ A szöveget a `notification-texts.js` oldja fel a címzett nyelvén — a
  // payload csak `kind`-ot és `params`-ot ad.
  assert.equal(notification.kind, 'chat_mention');
  assert.equal(notification.params.name, 'Nagy Anna');
  assert.equal(notification.params.snippet, 'Szia @Kobakologia!');
  assert.equal(
    notificationText(notification.kind, 'hu', notification.params).body,
    quoted('Szia @Kobakologia!'),
  );
  assert.equal(notification.targetType, 'chat');
  assert.equal(notification.targetId, 'post-9');
  assert.equal(notification.dedupeKey, 'chat-mention:post-9:uid-1');
  assert.equal(notification.senderId, 'author-1');
});

test('a szerző nem kap értesítést a saját üzenetéről', () => {
  const notifications = chatMentionNotifications({
    postId: 'post-9',
    authorId: 'uid-1',
    authorName: 'Nagy Anna',
    mentions: [
      { type: 'user', id: 'uid-1', label: 'Nagy Anna' },
      { type: 'user', id: 'uid-2', label: 'Kiss Péter' },
    ],
    text: '@Nagy Anna és @Kiss Péter',
  });

  assert.deepEqual(notifications.map((item) => item.recipientUid), ['uid-2']);
});

test('legfeljebb 5 értesítés, és ugyanaz a címzett csak egyszer szól', () => {
  const many = Array.from({ length: 8 }, (_, index) => ({
    type: 'user',
    id: `uid-${index}`,
    label: `Tag ${index}`,
  }));
  const capped = chatMentionNotifications({
    postId: 'post-9',
    authorId: 'author-1',
    authorName: 'Nagy Anna',
    mentions: many,
    text: 'sok @',
  });

  assert.equal(capped.length, MAX_USER_NOTIFICATIONS);
  assert.deepEqual(
    capped.map((item) => item.recipientUid),
    ['uid-0', 'uid-1', 'uid-2', 'uid-3', 'uid-4'],
  );

  const repeated = chatMentionNotifications({
    postId: 'post-9',
    authorId: 'author-1',
    authorName: 'Nagy Anna',
    mentions: [
      { type: 'user', id: 'uid-0', label: 'Tag 0' },
      { type: 'user', id: 'uid-0', label: 'Tag 0 újra' },
      { type: 'user', id: 'uid-1', label: 'Tag 1' },
    ],
    text: '@Tag 0 @Tag 0 @Tag 1',
  });

  assert.deepEqual(repeated.map((item) => item.recipientUid), ['uid-0', 'uid-1']);
  assert.equal(new Set(repeated.map((item) => item.dedupeKey)).size, 2);
});

test('a részlet whitespace-összevont, legfeljebb 80 karakter, hosszabban …-tal', () => {
  const mentions = [{ type: 'user', id: 'uid-1', label: 'Kobakologia' }];
  const build = (text) =>
    notificationText(
      'chat_mention',
      'hu',
      chatMentionNotifications({
        postId: 'post-9',
        authorId: 'author-1',
        authorName: 'Nagy Anna',
        mentions,
        text,
      })[0].params,
    ).body;

  // Whitespace (sortörés, dupla szóköz) összevonva, a szélek trimmelve.
  assert.equal(build('  Szia\n\n  @Kobakologia   ez   jó  '), quoted('Szia @Kobakologia ez jó'));

  // Pont 80 karakter: nincs levágás, nincs „…”.
  assert.equal(build('b'.repeat(MAX_EXCERPT_LENGTH)), quoted('b'.repeat(MAX_EXCERPT_LENGTH)));

  // 81 karakter: az első 80 jön, és a végén „…” jelzi a levágást.
  const long = build('a'.repeat(120)).split('„')[1].slice(0, -1);
  assert.equal(long, `${'a'.repeat(MAX_EXCERPT_LENGTH)}…`);
  assert.equal(long.length, MAX_EXCERPT_LENGTH + 1);
});

test('ismeretlen szerzőnél általános alak, hiányzó postId-nál nincs értesítés', () => {
  const mentions = [{ type: 'user', id: 'uid-1', label: 'Kobakologia' }];

  const unnamed = chatMentionNotifications({
    postId: 'post-9',
    authorId: 'author-1',
    authorName: '   ',
    mentions,
    text: 'Szia',
  });
  // A név-tartalék a katalógusban él, nyelvenként.
  assert.equal(
    notificationText('chat_mention', 'hu', unnamed[0].params).body,
    'Egy HUHS tag megemlített a Chatben: „Szia”',
  );
  assert.equal(
    notificationText('chat_mention', 'en', unnamed[0].params).body,
    'A HUHS member mentioned you in the Chat: “Szia”',
  );

  for (const postId of [undefined, null, '', '   ']) {
    assert.deepEqual(
      chatMentionNotifications({
        postId,
        authorId: 'author-1',
        authorName: 'Nagy Anna',
        mentions,
        text: 'Szia',
      }),
      [],
    );
  }
  assert.deepEqual(chatMentionNotifications(), []);
  assert.deepEqual(
    chatMentionNotifications({
      postId: 'post-9',
      authorId: 'author-1',
      authorName: 'Nagy Anna',
      mentions: [],
      text: 'Szia',
    }),
    [],
  );
});

// ---------------------------------------------------------------------------
// @MINDENKI („everyone") — a tulajdonos kérése (2026-09-25): *„kéne egy
// @mindenki tag is, amit ha beütök, kap mindenki notifyt és csak
// moderátor/admin használhassa"*.
// ---------------------------------------------------------------------------

test('nem privileged @mindenki kiesik (dropped++), és senkit nem értesít', () => {
  const { mentions, dropped } = sanitizeMentions([
    { type: 'everyone', id: 'everyone', label: 'mindenki' },
    { type: 'user', id: 'uid-1', label: 'Kobakologia' },
  ]);

  assert.deepEqual(mentions, [{ type: 'user', id: 'uid-1', label: 'Kobakologia' }]);
  assert.equal(dropped, 1, 'az @mindenki ugyanúgy kiesik, mint a tartalom-hivatkozás');

  // A megmaradt hivatkozásokból csak a SZEMÉLY kap értesítést — az `everyone`
  // soha nem kerül a `chatMentionNotifications` payload-jai közé.
  const notifications = chatMentionNotifications({
    postId: 'post-9',
    authorId: 'author-1',
    authorName: 'Nagy Anna',
    mentions,
    text: 'Szia @Kobakologia és @mindenki',
  });
  assert.deepEqual(notifications.map((item) => item.recipientUid), ['uid-1']);
});

test('privileged @mindenki átmegy, és az id/label a SZERVER kanonikus értéke', () => {
  const cases = [
    [{ type: 'everyone', id: 'HACK', label: 'Saját címke' }],
    [{ type: 'everyone' }],
    [{ type: 'everyone', id: 12, label: 42 }],
    [{ type: 'everyone', id: ` ${EVERYONE_ID} `, label: ` ${EVERYONE_LABEL} ` }],
  ];

  for (const raw of cases) {
    const { mentions, dropped } = sanitizeMentions(raw, { privileged: true });
    assert.deepEqual(
      mentions,
      [{ type: EVERYONE_TYPE, id: EVERYONE_ID, label: EVERYONE_LABEL }],
      `a kliens bemenete: ${JSON.stringify(raw)}`,
    );
    assert.equal(dropped, 0);
  }
});

test('két @mindenki: csak egy marad, a második kihagyottnak számít', () => {
  const { mentions, dropped } = sanitizeMentions(
    [
      { type: 'everyone', id: 'everyone', label: 'mindenki' },
      { type: 'user', id: 'uid-1', label: 'Kobakologia' },
      { type: 'everyone', id: 'everyone', label: 'mindenki újra' },
    ],
    { privileged: true },
  );

  assert.deepEqual(mentions, [
    { type: 'everyone', id: 'everyone', label: 'mindenki' },
    { type: 'user', id: 'uid-1', label: 'Kobakologia' },
  ]);
  assert.equal(dropped, 1);
});

test('a 10-es plafon @mindenkivel együtt is áll: 1 mindenki + 9 más fér el', () => {
  const users = Array.from({ length: 12 }, (_, index) => ({
    type: 'user',
    id: `uid-${index}`,
    label: `Tag ${index}`,
  }));

  const { mentions, dropped } = sanitizeMentions(
    [{ type: 'everyone', id: 'everyone', label: 'mindenki' }, ...users],
    { privileged: true },
  );
  assert.equal(mentions.length, MAX_MENTIONS);
  assert.equal(mentions[0].type, 'everyone');
  assert.deepEqual(
    mentions.slice(1).map((mention) => mention.id),
    ['uid-0', 'uid-1', 'uid-2', 'uid-3', 'uid-4', 'uid-5', 'uid-6', 'uid-7', 'uid-8'],
  );
  assert.equal(dropped, 3, 'uid-9, uid-10 és uid-11 esik ki');

  // Ha a plafon MÁR betelt, az @mindenki sem fér be — és kihagyottnak számít.
  const full = sanitizeMentions(
    [...users.slice(0, MAX_MENTIONS), { type: 'everyone', id: 'everyone', label: 'mindenki' }],
    { privileged: true },
  );
  assert.equal(full.mentions.length, MAX_MENTIONS);
  assert.equal(full.mentions.some((mention) => mention.type === 'everyone'), false);
  assert.equal(full.dropped, 1);
});

test('chatEveryoneNotification: a payload teljes, és a kulcs a címzettől is függ', () => {
  const base = {
    postId: 'post-9',
    authorId: 'author-1',
    authorName: 'Nagy Anna',
    excerpt: 'Szia   mindenki!',
  };

  const notification = chatEveryoneNotification({ ...base, recipientUid: 'uid-2' });
  assert.deepEqual(notification, {
    recipientUid: 'uid-2',
    type: 'chat_mention',
    kind: 'chat_everyone',
    params: { name: 'Nagy Anna', snippet: 'Szia mindenki!' },
    targetType: 'chat',
    targetId: 'post-9',
    dedupeKey: 'chat-everyone:post-9:uid-2',
    senderId: 'author-1',
  });
  assert.equal(
    notificationText('chat_everyone', 'hu', notification.params).body,
    'Nagy Anna mindenkit megemlített a Chatben: „Szia mindenki!”',
  );

  // UGYANAZ a post, MÁS címzett → MÁS dedupeKey: különben a `createNotification`
  // a kulcs hash-e miatt csak az ELSŐ címzettnek írna dokumentumot.
  const other = chatEveryoneNotification({ ...base, recipientUid: 'uid-3' });
  assert.notEqual(other.dedupeKey, notification.dedupeKey);
  assert.match(other.dedupeKey, /post-9/);
  assert.match(other.dedupeKey, /uid-3/);

  // A részlet itt is 80 karakterre vágva (a közös `mentionExcerpt`-tel).
  const long = chatEveryoneNotification({
    ...base,
    excerpt: 'a'.repeat(120),
    recipientUid: 'uid-2',
  });
  assert.equal(
    notificationText('chat_everyone', 'hu', long.params).body.split('„')[1].slice(0, -1),
    `${'a'.repeat(MAX_EXCERPT_LENGTH)}…`,
  );

  // Ismeretlen szerzőnél általános alak (mint a személy-értesítésnél).
  const unnamed = chatEveryoneNotification({ ...base, authorName: '   ', recipientUid: 'uid-2' });
  assert.equal(
    notificationText('chat_everyone', 'hu', unnamed.params).body,
    'Egy HUHS tag mindenkit megemlített a Chatben: „Szia mindenki!”',
  );
});

test('chatEveryoneNotification: null a szerzőnél és hiányzó kulcsoknál', () => {
  const base = {
    postId: 'post-9',
    authorId: 'author-1',
    authorName: 'Nagy Anna',
    excerpt: 'Szia',
    recipientUid: 'uid-2',
  };

  assert.equal(
    chatEveryoneNotification({ ...base, recipientUid: 'author-1' }),
    null,
    'a szerző nem kap értesítést a saját üzenetéről',
  );
  assert.equal(chatEveryoneNotification({ ...base, recipientUid: '  author-1  ' }), null);

  for (const postId of [undefined, null, '', '   ']) {
    assert.equal(chatEveryoneNotification({ ...base, postId }), null);
  }
  for (const authorId of [undefined, null, '', '   ']) {
    assert.equal(chatEveryoneNotification({ ...base, authorId }), null);
  }
  for (const recipientUid of [undefined, null, '', '   ']) {
    assert.equal(chatEveryoneNotification({ ...base, recipientUid }), null);
  }
  assert.equal(chatEveryoneNotification(), null);
});

test('a fan-out plafonja MAX_EVERYONE_RECIPIENTS, a szerző és a duplikátum kiesik', () => {
  const base = {
    postId: 'post-9',
    authorId: 'author-1',
    authorName: 'Nagy Anna',
    excerpt: 'Szia mindenki!',
  };

  const many = chatEveryoneNotifications({
    ...base,
    recipientUids: Array.from({ length: MAX_EVERYONE_RECIPIENTS + 20 }, (_, index) => `uid-${index}`),
  });
  assert.equal(many.length, MAX_EVERYONE_RECIPIENTS, 'a plafon a helperben is érvényes');
  assert.equal(many[0].recipientUid, 'uid-0');
  assert.equal(many[MAX_EVERYONE_RECIPIENTS - 1].recipientUid, `uid-${MAX_EVERYONE_RECIPIENTS - 1}`);

  const mixed = chatEveryoneNotifications({
    ...base,
    recipientUids: ['uid-1', '  uid-1  ', '', '   ', null, 'author-1', 'uid-2'],
  });
  assert.deepEqual(mixed.map((item) => item.recipientUid), ['uid-1', 'uid-2']);
  assert.equal(new Set(mixed.map((item) => item.dedupeKey)).size, 2);
  assert.equal(chatEveryoneNotifications().length, 0);
});

// A „@mindenki" PUSH-a (a tulajdonos jelzése, 2026-09-26: *„ja a @mindenki tag
// nem működik, nem küld notifyt"* — a mérés szerint a lista-bejegyzések
// létrejöttek, push viszont nem ment; a döntése: a @mindenki kapjon push-t, a
// személyes @említés maradjon csendes).
test('a @mindenki push-adata arra az üzenetre mutat, és a törzs 80 karakter', () => {
  const message = chatEveryonePushMessage({
    postId: 'post-9',
    authorId: 'uid-author',
    text: '  Ma   este @mindenki!  ',
  });
  assert.deepEqual(message.data, {
    type: 'chat_everyone',
    postId: 'post-9',
    targetType: 'chat',
    targetId: 'post-9',
    senderId: 'uid-author',
  });
  assert.equal(message.body, 'Ma este @mindenki!', 'a törzs a tömörített szöveg');

  // A vágás ugyanaz, mint a listabeli értesítésnél (közös `mentionExcerpt`).
  const long = chatEveryonePushMessage({ postId: 'p', authorId: 'a', text: 'x'.repeat(200) });
  assert.equal(long.body.length, MAX_EXCERPT_LENGTH + 1, '80 karakter + a levágás jele');
  assert.equal(long.body.endsWith('…'), true);

  // `postId` nélkül nincs értelmes célpont — nem találgatunk.
  assert.equal(chatEveryonePushMessage({ authorId: 'a', text: 'szia' }), null);
  assert.equal(chatEveryonePushMessage(), null);
});

test('push CSAK új értesítésnek, bekapcsolt értesítésnél és tokennel megy', () => {
  const targets = everyonePushTargets([
    // 1) rendben: új értesítés, nincs kikapcsolva, van token
    { uid: 'uid-1', created: true, tokens: ['t1', 't1', ' t2 '], preferences: {} },
    // 2) újrakézbesítés (created=false): nem küldünk második push-t
    { uid: 'uid-2', created: false, tokens: ['t3'], preferences: {} },
    // 3) kikapcsolt értesítés: a listába bekerül, push-t nem kap
    { uid: 'uid-3', created: true, tokens: ['t4'], preferences: { enabled: false } },
    // 4) nincs token
    { uid: 'uid-4', created: true, tokens: [], preferences: {} },
    // 5) üres/hibás sorok
    { uid: '   ', created: true, tokens: ['t5'] },
    null,
    'uid-6',
    [],
  ]);

  assert.deepEqual(targets, [{ uid: 'uid-1', tokens: ['t1', 't2'] }]);
  // Nem tömb bemenetre üres lista (nem dob).
  for (const raw of [undefined, null, 'uid-1', 42, {}]) {
    assert.deepEqual(everyonePushTargets(raw), []);
  }
  // A `preferences` hiánya/bármilyen alakja nem dönt véletlenül: csak a
  // kifejezett `false` tilt (a `null`/szöveg nem).
  assert.deepEqual(
    everyonePushTargets([
      { uid: 'a', created: true, tokens: ['t'], preferences: null },
      { uid: 'b', created: true, tokens: ['t'], preferences: { enabled: 'nem' } },
    ]).map((item) => item.uid),
    ['a', 'b'],
  );
});

test('a Firestore-szabályt NEM kellett bővíteni: az @mindenki kanonikus alakja beleillik', () => {
  const entry = { type: EVERYONE_TYPE, id: EVERYONE_ID, label: EVERYONE_LABEL };
  // A szabály ezt kéri: pont ez a három kulcs, string típus, id ≤ 64, label ≤ 80.
  assert.deepEqual(Object.keys(entry), ['type', 'id', 'label']);
  assert.equal(typeof entry.type, 'string');
  assert.equal(entry.id.length, 8, 'mérve: „everyone” = 8 karakter (≤ 64)');
  assert.equal(entry.label.length, 8, 'mérve: „mindenki” = 8 karakter (≤ 80)');
  // A szabály szövegében nincs típus-felsorolás (csak alak + darabszám), ezért
  // az új típus nem igényel szabálymódosítást.
  assert.equal(rulesSource.includes('everyone'), false);
});

test('forrás-lint: a publishChatPost @mindenki fan-outja kötegelt, best-effort és szerző-kihagyó', () => {
  const start = functionsSource.indexOf('exports.publishChatPost = ');
  const end = functionsSource.indexOf('exports.manageConnection = ', start);
  assert.ok(start > 0 && end > start, 'a publishChatPost megtalálható');
  const body = functionsSource.slice(start, end);

  // 1) Az import a tiszta modulból jön (helper + típus-konstans + plafon + push).
  assert.match(
    functionsSource,
    /chatEveryoneNotifications,\s*\n\s*chatEveryonePushMessage,\s*\n\s*everyonePushTargets,\s*\n\s*EVERYONE_TYPE,\s*\n\s*MAX_EVERYONE_RECIPIENTS,\s*\n\} = require\('\.\/chat-mention-plan'\)/,
  );

  // 2) A döntés a tiszta helperben van, és a típus-konstansot kéri.
  assert.match(body, /mentions\.some\(\(mention\) => mention\.type === EVERYONE_TYPE\)/);
  assert.match(body, /chatEveryoneNotifications\(\{/);

  // 3) A címzettek a community_profiles-ból, a DOKUMENTUM-AZONOSÍTÓVAL, plafonnal.
  assert.match(
    body,
    /\.collection\('community_profiles'\)\s*\.limit\(MAX_EVERYONE_RECIPIENTS\)\s*\.get\(\)/,
  );
  assert.match(body, /\.map\(\(document\) => document\.id\)/);

  // 4) A szerzőt kihagyjuk (a tiszta helper is kihagyja, de a hívó is).
  assert.match(body, /\.filter\(\(recipientUid\) => recipientUid && recipientUid !== uid\)/);

  // 5) Kötegelt (50) párhuzamos írás, best-effort íróval — pontosan egyszer.
  assert.match(body, /index \+= 50/);
  assert.match(body, /await Promise\.all\(/);
  assert.match(body, /createNotificationBestEffort\(notification\)/);
  assert.equal((body.match(/createNotificationBestEffort\(notification\)/g) || []).length, 1);

  // 6) A fan-out blokk try/catch-ben fut (a helper-hívás a try és a catch között).
  const everyoneIndex = body.indexOf('chatEveryoneNotifications({');
  const tryIndex = body.lastIndexOf('try {', everyoneIndex);
  const catchIndex = body.indexOf('} catch (error) {', everyoneIndex);
  assert.ok(
    tryIndex > 0 && tryIndex < everyoneIndex && catchIndex > everyoneIndex,
    'a fan-out try/catch-ben fut (egy olvasási/kapcsolati hiba nem viheti el a hívást)',
  );
  assert.match(body, /event: 'chat_everyone_notify_failed'/);

  // 7) A válasz visszaadja a számokat (a régi `droppedMentions` mellé).
  assert.match(body, /everyoneNotified = everyoneNotifications\.length;/);
  assert.match(body, /return \{ id: ref\.id, droppedMentions, everyoneNotified, everyonePushed \}/);

  // 8) A fan-out a SZEMÉLY-értesítések UTÁN fut (nem keveredik bele).
  const mentionIndex = body.indexOf('chatMentionNotifications({');
  assert.ok(mentionIndex > 0 && everyoneIndex > mentionIndex, 'a fan-out a személy-értesítések után van');

  // 9) PUSH: a döntés a tiszta helperben, a küldés kötegelt és best-effort.
  assert.match(body, /everyonePushTargets\(candidates\)/);
  assert.match(body, /chatEveryonePushMessage\(\{ postId: ref\.id, authorId: uid, text \}\)/);
  // Az „új volt-e" tény számít: a listabeli írások eredményét megtartjuk.
  assert.match(body, /created: results\[position\] === true/);
  assert.match(body, /notificationPreferences \|\| \{\}/);
  assert.match(body, /index \+= 10/, 'a push-küldés is kötegelt');
  assert.match(body, /sendMulticastToAllTokens\(/);
  // A cím a címzett nyelvén, ugyanabból a katalógusból (mint a lista szövege).
  assert.match(body, /notificationText\('chat_everyone', language, \{/);
  assert.match(body, /messaging\/registration-token-not-registered/);
  assert.match(body, /removePushTokens\(target\.uid, invalidTokens\)/);
  assert.match(body, /event: 'chat_everyone_push_failed'/);
  // A push-blokk a fan-out blokkon BELÜL, saját try/catch-ben fut: egy push-hiba
  // sem viheti el sem a listabeli értesítéseket, sem az üzenetet.
  const pushIndex = body.indexOf('everyonePushTargets(candidates)');
  const pushTry = body.lastIndexOf('try {', pushIndex);
  const pushCatch = body.indexOf('} catch (error) {', pushIndex);
  assert.ok(
    pushTry > everyoneIndex && pushCatch > pushIndex,
    'a push a fan-out blokkban, saját try/catch-ben fut',
  );
  // A PUSH a lista-írások UTÁN indul (különben nem tudná, mi az új).
  const writeIndex = body.indexOf('everyoneNotified = everyoneNotifications.length;');
  assert.ok(writeIndex > 0 && pushIndex > writeIndex, 'a push a lista-írások után indul');
});

test('a publishChatPost a tiszta tervet használja privileged módban, a szabály pedig ismeri a mentions mezőt', () => {
  const start = functionsSource.indexOf('exports.publishChatPost = ');
  const end = functionsSource.indexOf('exports.manageConnection = ', start);
  assert.ok(start > 0 && end > start, 'a publishChatPost megtalálható');
  const body = functionsSource.slice(start, end);

  // A jogosultság a MÁR kiszámolt `accessRole`-ból dől el (nincs újraolvasás).
  assert.match(body, /sanitizeMentions\(data\?\.mentions, \{/);
  assert.match(body, /privileged: accessRole === 'admin'/);
  assert.match(body, /accessRole === 'moderator'/);
  // A mező CSAK akkor kerül a dokumentumba, ha maradt érvényes hivatkozás.
  assert.match(body, /\.\.\.\(mentions\.length \? \{ mentions \} : \{\}\)/);
  // Az értesítések a válasz-blokk UTÁN, elemenként, best-effort módon mennek ki.
  assert.match(body, /chatMentionNotifications\(\{/);
  assert.match(body, /for \(const mentionNotification of mentionNotifications\)/);
  assert.match(body, /await createNotificationBestEffort\(mentionNotification\)/);
  const replyIndex = body.indexOf('createNotificationBestEffort(replyNotification)');
  const mentionIndex = body.indexOf('chatMentionNotifications({');
  assert.ok(replyIndex > 0 && mentionIndex > replyIndex, 'a mention-blokk a válasz-blokk után van');
  // Visszafelé kompatibilis válasz + a kihagyottak száma (és az @mindenki-számok).
  assert.match(body, /return \{ id: ref\.id, droppedMentions, everyoneNotified, everyonePushed \}/);

  // A Firestore-szabály: a whitelistben ott a mező, és a shape-korlát is.
  assert.match(rulesSource, /'reactions', 'reactionBy', 'pinned', 'createdAt', 'editedAt', 'mentions'/);
  assert.match(rulesSource, /request\.resource\.data\.mentions is list/);
  assert.match(rulesSource, /request\.resource\.data\.mentions\.size\(\) <= 10/);
  assert.match(rulesSource, /mentions\[0\]\.keys\(\)\.hasOnly\(\['type', 'id', 'label'\]\)/);
  assert.match(rulesSource, /mentions\[0\]\.id\.size\(\) <= 64/);
  assert.match(rulesSource, /mentions\[0\]\.label\.size\(\) <= 80/);
  // A korlát nem tűnhet el: a lista-végigiterálás hiánya le van írva a szabályban.
  assert.match(rulesSource, /NEM lehet listan vegigiteralni/);
  assert.match(rulesSource, /chat-mention-plan\.js/);
});
