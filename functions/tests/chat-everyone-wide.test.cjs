'use strict';
/**
 * A **@mindenki chat-push széles** útja (2.14.19) — tiszta mérés.
 *
 * A tulajdonos kérése (2026-10-04): *„hír push, esemény push, chaten @mindenki
 * push üzenetet megkaphatnák azok is, akik nem regisztráltak az appba”*.
 * MÉRVE: a hír- és esemény-push már eljut a vendégekhez (a plugin token-tára
 * 1070 eszköz, a regisztrált profilok száma 47), a `@mindenki` viszont eddig csak
 * a Firestore-profilokon ment — ezért a nem regisztráltak kimaradtak.
 *
 * Ez a kör a **kérés alakját** méri (a küldés a WordPress admin végpontjára
 * megy): nyelvenkénti szöveg, chat-típus, `postId` a koppintáshoz — és azt, hogy
 * a `publishChatPost` a széles utat **előbb** próbálja, a Firestore-kört pedig
 * csak tartalékként használja (különben a regisztráltak dupla push-t kapnának).
 */
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const { chatEveryonePushRequest } = require('../index.js').__pushNotifyForTests;

test('a széles chat-push kérés nyelvenkénti szöveget és chat-típust ad', () => {
  const request = chatEveryonePushRequest({
    name: 'Deeroy',
    snippet: 'Szia mindenki, ma este élő adás!',
    postId: 'abc123',
  });
  assert.ok(request, 'van kérés');
  const { payload, texts } = request;

  // A WordPress admin végpontjának a szerződése.
  assert.equal(payload.action, 'send_push');
  assert.equal(payload.type, 'chat_everyone', 'a chat-típus kell a széles pushhoz');
  assert.equal(payload.postId, 'abc123', 'a koppintás célpontja a chat üzenet');

  // Nyelvenkénti szöveg (hu + en) — a plugin a token nyelvén küldi.
  assert.ok(texts.hu, 'van magyar szöveg');
  assert.ok(texts.en, 'van angol szöveg');
  assert.ok(texts.hu.title.length > 0 && texts.hu.body.length > 0);
  assert.ok(texts.en.title.length > 0 && texts.en.body.length > 0);
  assert.notEqual(texts.hu.title, texts.en.title, 'a két nyelv nem ugyanaz a szöveg');
  assert.deepEqual(payload.texts, texts);

  // A tartalék cím/üzenet a magyarból jön (a plugin így is elfogadja).
  assert.equal(payload.title, texts.hu.title);
  assert.equal(payload.body, texts.hu.body);
});

test('a szöveg a beküldő nevét és az üzenet kivonatát tartalmazza', () => {
  const request = chatEveryonePushRequest({
    name: 'Deeroy',
    snippet: 'Szia mindenki!',
    postId: 'p1',
  });
  assert.match(request.texts.hu.body, /Deeroy/);
  assert.match(request.texts.en.body, /Deeroy/);
});

test('postId nélkül is biztonságos (üres célpont, nem dob)', () => {
  const request = chatEveryonePushRequest({ name: 'Deeroy', snippet: 'x' });
  assert.ok(request);
  assert.equal(request.payload.postId, '');
});

test('a publishChatPost a SZÉLES utat próbálja előbb, és csak hiba esetén megy a Firestore-kör', () => {
  const source = fs.readFileSync(path.join(__dirname, '..', 'index.js'), 'utf8');
  // 1) A széles push hívása megvan.
  assert.match(source, /const wide = await sendChatEveryonePush\(\{/);
  // 2) Siker esetén a Firestore-kör NEM fut (nincs dupla push).
  assert.match(source, /if \(!wide\.failed\) \{/);
  assert.match(source, /event: 'chat_everyone_push_wide'/);
  // 3) A tartalék ág a régi (regisztrált) kört használja, és jelzi, hogy a széles út bukott.
  assert.match(source, /event: 'chat_everyone_push_result'/);
  assert.match(source, /wideFailed: true/);
  // 4) A WordPress-secretek be vannak kötve a függvényhez (különben néma hiba).
  assert.match(
    source,
    /exports\.publishChatPost = functions\s*\n?\s*\.runWith\(\{ enforceAppCheck: false, secrets: \[WORDPRESS_USERNAME, WORDPRESS_APPLICATION_PASSWORD\] \}\)/,
  );
});
