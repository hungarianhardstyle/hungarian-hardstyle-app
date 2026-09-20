const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const {
  chatReactionNotification,
  chatReplyNotification,
} = require('./chat-notification-plan');

/**
 * A tulajdonos kérése:
 *   *„chat like-ról legyen az adott usernek notify"*,
 *   *„Ha valaki válaszol neked a chaten legyen róla notify"*,
 *   *„Csak notify, push nem kell"*.
 *
 * Ez a teszt a DÖNTÉST méri (kit értesítünk, mikor NEM, mi a naplókulcs), és
 * forrás-linttel azt, hogy a két hívó **nem** küld push-t, valamint hogy a
 * kliens tényleg elküldi a válasz célpontját.
 *
 * Futtatás: node --test functions/chat-notification-plan.test.cjs
 */

const functionsSource = fs.readFileSync(path.join(__dirname, 'index.js'), 'utf8');
const serviceSource = fs.readFileSync(
  path.join(__dirname, '..', 'lib', 'services', 'community_service.dart'),
  'utf8',
);
const screenSource = fs.readFileSync(
  path.join(__dirname, '..', 'lib', 'screens', 'community', 'community_screen.dart'),
  'utf8',
);

function callableBody(name, nextName) {
  const start = functionsSource.indexOf(`exports.${name} = `);
  const end = functionsSource.indexOf(`exports.${nextName} = `, start);
  assert.ok(start > 0 && end > start, `${name} megtalálható`);
  return functionsSource.slice(start, end);
}

test('chat lájk: a SZERZŐ kap értesítést a lájkoló nevvel', () => {
  const plan = chatReactionNotification({
    authorId: 'author-1',
    reactorUid: 'liker-1',
    reactorName: 'Kiss Péter',
    postId: 'post-9',
    selected: '❤️',
  });

  assert.ok(plan, 'a lájk értesítést ad');
  assert.equal(plan.recipientUid, 'author-1');
  assert.equal(plan.type, 'chat_reaction');
  assert.equal(plan.title, 'Kedvelték a Chat-üzenetedet');
  assert.equal(plan.body, 'Kiss Péter kedvelte a Chat-üzenetedet.');
  assert.equal(plan.targetType, 'chat');
  assert.equal(plan.targetId, 'post-9');
  assert.equal(plan.senderId, 'liker-1');
  assert.equal(plan.dedupeKey, 'chat-reaction:post-9:liker-1');
});

test('chat lájk: a VISSZAVONÁS nem értesít', () => {
  assert.equal(
    chatReactionNotification({
      authorId: 'author-1',
      reactorUid: 'liker-1',
      postId: 'post-9',
      selected: '',
    }),
    null,
  );
});

test('chat lájk: a saját üzenet saját lájkja nem értesít', () => {
  assert.equal(
    chatReactionNotification({
      authorId: 'same',
      reactorUid: 'same',
      postId: 'post-9',
      selected: '🔥',
    }),
    null,
  );
});

test('chat lájk: hiányzó szerző vagy üzenet-azonosító esetén nincs találgatás', () => {
  assert.equal(
    chatReactionNotification({ reactorUid: 'liker-1', postId: 'post-9', selected: '❤️' }),
    null,
  );
  assert.equal(
    chatReactionNotification({ authorId: 'author-1', reactorUid: 'liker-1', selected: '❤️' }),
    null,
  );
  assert.equal(chatReactionNotification(), null);
});

test('chat lájk: ismeretlen nevű lájkoló sem hagy üres mondatot', () => {
  const plan = chatReactionNotification({
    authorId: 'author-1',
    reactorUid: 'liker-1',
    reactorName: '   ',
    postId: 'post-9',
    selected: '🙌',
  });
  assert.equal(plan.body, 'Egy HUHS tag kedvelte a Chat-üzenetedet.');
});

test('chat lájk: ugyanaz a lájkoló EGYSZER szól (a naplókulcs azonos)', () => {
  const first = chatReactionNotification({
    authorId: 'author-1',
    reactorUid: 'liker-1',
    postId: 'post-9',
    selected: '❤️',
  });
  const again = chatReactionNotification({
    authorId: 'author-1',
    reactorUid: 'liker-1',
    postId: 'post-9',
    selected: '🔥',
  });
  assert.equal(first.dedupeKey, again.dedupeKey, 'visszavonás + újralájk sem dupláz');
});

test('chat lájk: két KÜLÖN lájkoló két külön értesítés', () => {
  const a = chatReactionNotification({
    authorId: 'author-1',
    reactorUid: 'liker-1',
    postId: 'post-9',
    selected: '❤️',
  });
  const b = chatReactionNotification({
    authorId: 'author-1',
    reactorUid: 'liker-2',
    postId: 'post-9',
    selected: '❤️',
  });
  assert.notEqual(a.dedupeKey, b.dedupeKey);
});

test('chat válasz: a VÁLASZOLT kap értesítést a válaszoló nevével', () => {
  const plan = chatReplyNotification({
    recipientUid: 'author-1',
    senderUid: 'replier-1',
    senderName: 'Nagy Anna',
    replyToText: 'Szia!',
    messageId: 'message-7',
  });

  assert.ok(plan, 'a válasz értesítést ad');
  assert.equal(plan.recipientUid, 'author-1');
  assert.equal(plan.type, 'chat_reply');
  assert.equal(plan.title, 'Válaszoltak a Chat-üzenetedre');
  assert.equal(plan.body, 'Nagy Anna válaszolt a Chat-üzenetedre.');
  assert.equal(plan.targetType, 'chat');
  assert.equal(plan.targetId, 'message-7');
  assert.equal(plan.senderId, 'replier-1');
  assert.equal(plan.dedupeKey, 'chat-reply:message-7:author-1');
});

test('chat válasz: válasz-szöveg nélkül nincs értesítés', () => {
  assert.equal(
    chatReplyNotification({
      recipientUid: 'author-1',
      senderUid: 'replier-1',
      replyToText: '   ',
      messageId: 'message-7',
    }),
    null,
  );
});

test('chat válasz: magának válaszolva nincs értesítés', () => {
  assert.equal(
    chatReplyNotification({
      recipientUid: 'same',
      senderUid: 'same',
      replyToText: 'Szia!',
      messageId: 'message-7',
    }),
    null,
  );
});

test('chat válasz: régi kliens (nincs célpont) nem értesít senkit', () => {
  assert.equal(
    chatReplyNotification({
      senderUid: 'replier-1',
      replyToText: 'Szia!',
      messageId: 'message-7',
    }),
    null,
  );
});

test('chat válasz: ugyanaz a válasz egyszer szól (trigger-újrakézbesítés sem dupláz)', () => {
  const args = {
    recipientUid: 'author-1',
    senderUid: 'replier-1',
    replyToText: 'Szia!',
    messageId: 'message-7',
  };
  assert.equal(
    chatReplyNotification(args).dedupeKey,
    chatReplyNotification(args).dedupeKey,
  );
});

test('a két hívó a tiszta tervet használja', () => {
  const reaction = callableBody('toggleChatReaction', 'publishChatPost');
  const publish = callableBody('publishChatPost', 'manageConnection');
  assert.match(reaction, /chatReactionNotification\(/);
  assert.match(publish, /chatReplyNotification\(/);
});

test('a két hívó NEM küld push-t (a tulajdonos kérése: „csak notify")', () => {
  const reaction = callableBody('toggleChatReaction', 'publishChatPost');
  const publish = callableBody('publishChatPost', 'manageConnection');
  for (const [name, body] of [
    ['toggleChatReaction', reaction],
    ['publishChatPost', publish],
  ]) {
    assert.doesNotMatch(body, /sendMulticastToAllTokens/, `${name} nem küld push-t`);
    assert.doesNotMatch(body, /sendEachForMulticast/, `${name} nem hívja a Firebase API-t`);
    assert.doesNotMatch(body, /sendAchievementPushBestEffort/, `${name} nem küld pont-push-t`);
  }
});

test('a kliens ELKÜLDI a válasz célpontját (különben nincs értesítés)', () => {
  assert.match(
    serviceSource,
    /'replyToAuthorId': replyToAuthorId!/,
    'a szolgáltatás továbbadja a szerző UID-ját',
  );
  assert.match(screenSource, /_replyToAuthorId = post\.authorId\.trim\(\)/);
  assert.match(screenSource, /replyToAuthorId: _replyToAuthorId/);
});
