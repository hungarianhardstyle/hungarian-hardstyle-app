'use strict';

/**
 * A Chat-értesítések DÖNTÉSE — tiszta logika, nulla függőség.
 *
 * A tulajdonos kérése: *„chat like-ról legyen az adott usernek notify"* és
 * *„Ha valaki válaszol neked a chaten legyen róla notify"* — **push nélkül**
 * (*„csak notify, push nem kell"*).
 *
 * Ez a modul **csak a bejegyzést** állítja elő, amit a hívó a
 * `createNotificationBestEffort`-tal ír ki az app értesítés-listájába. Push
 * küldése szándékosan **nincs** benne (és a hívókban sincs).
 *
 * MIÉRT külön modul: így a döntés (kit értesítünk, mikor NEM, mi a naplókulcs)
 * WordPress és Firestore nélkül is mérhető — a hívóban csak a kiírás marad.
 */

/**
 * Chat-üzenet LÁJKOLÁSA → értesítés a **szerzőnek**.
 *
 * @returns {object|null} értesítés-payload, vagy `null`, ha nincs értesítés.
 *
 * Négy szándékos szabály:
 *  1. **visszavonáskor nincs értesítés** (`selected` üres);
 *  2. **a saját üzenet saját lájkja** nem értesítés (senki nem szól magának);
 *  3. hiányzó szerző/üzenet-azonosító esetén nincs találgatás;
 *  4. a naplókulcs **üzenet + lájkoló**, ezért ugyanaz a felhasználó ugyanarra
 *     az üzenetre **egyszer** szól — visszavonás és újralájk után sem kétszer.
 */
function chatReactionNotification({
  authorId,
  reactorUid,
  reactorName,
  postId,
  selected,
} = {}) {
  const author = String(authorId || '').trim();
  const reactor = String(reactorUid || '').trim();
  const post = String(postId || '').trim();
  if (!String(selected || '').trim()) return null;
  if (!author || !reactor || author === reactor) return null;
  if (!post) return null;
  const name = String(reactorName || '').trim() || 'Egy HUHS tag';
  return {
    recipientUid: author,
    type: 'chat_reaction',
    title: 'Kedvelték a Chat-üzenetedet',
    body: `${name} kedvelte a Chat-üzenetedet.`,
    targetType: 'chat',
    targetId: post,
    dedupeKey: `chat-reaction:${post}:${reactor}`,
    senderId: reactor,
  };
}

/**
 * Chat-VÁLASZ → értesítés a **válaszolt** felhasználónak.
 *
 * @returns {object|null} értesítés-payload, vagy `null`, ha nincs értesítés.
 *
 * Négy szándékos szabály:
 *  1. **csak valódi válasz** esetén (`replyToText` nem üres) — a „nem válasz”
 *     üzenet nem szól senkinek;
 *  2. **magának válaszolva** nincs értesítés;
 *  3. címzett és üzenet-azonosító nélkül nincs találgatás;
 *  4. a naplókulcs a **válasz üzenetéhez** kötött, ezért egy konkrét válasz
 *     csak egyszer értesít (a trigger-újrakézbesítés sem duplázza).
 */
function chatReplyNotification({
  recipientUid,
  senderUid,
  senderName,
  replyToText,
  messageId,
} = {}) {
  const recipient = String(recipientUid || '').trim();
  const sender = String(senderUid || '').trim();
  const message = String(messageId || '').trim();
  if (!String(replyToText || '').trim()) return null;
  if (!recipient || !sender || recipient === sender) return null;
  if (!message) return null;
  const name = String(senderName || '').trim() || 'Egy HUHS tag';
  return {
    recipientUid: recipient,
    type: 'chat_reply',
    title: 'Válaszoltak a Chat-üzenetedre',
    body: `${name} válaszolt a Chat-üzenetedre.`,
    targetType: 'chat',
    targetId: message,
    dedupeKey: `chat-reply:${message}:${recipient}`,
    senderId: sender,
  };
}

module.exports = { chatReactionNotification, chatReplyNotification };
