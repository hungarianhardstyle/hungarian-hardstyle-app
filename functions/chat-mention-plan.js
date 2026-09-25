'use strict';

/**
 * Chat-@hivatkozás (mention) — a SZERVEROLDALI döntés: tiszta logika, nulla
 * függőség.
 *
 * A tulajdonos kérése: *„Kéne olyan, hogy egy @xy betűvel tudjak hivatkozni a
 * chaten cikkre, djre, szervezőre, eseményre, kiadványra vagy személyre/userre,
 * ha személyre hivatkozok kapjon róla notifyt"* — és a döntései:
 *
 *  1. **mind a hat típus** egyszerre (`user`, `article`, `artist`, `organizer`,
 *     `event`, `release`);
 *  2. a megemlített **személyek mind kapnak** értesítést, de **legfeljebb 5
 *     személy/üzenet** (spam-korlát);
 *  3. a nem admin/moderátor **tartalom-hivatkozásait a szerver kihagyja** (a
 *     szöveg marad), és **visszaadja a kihagyottak számát**;
 *  4. egyelőre **csak a Chat** (a cikk-kommentek nem).
 *
 * MIÉRT külön modul (a `chat-notification-plan.js` és az `actor-name-plan.js`
 * mintájára): így a döntés — mi számít érvényes hivatkozásnak, mi esik ki, kit
 * értesítünk és mit írunk a szövegbe — **Firestore és WordPress nélkül
 * mérhető**. A hívóban (`publishChatPost`) csak a kiírás marad.
 *
 * ⚠️ A `sanitizeMentions` a **hiteles** szűrő: a kliens-oldali lista csak UX.
 * A Firestore-szabály ezzel szemben **nem tud listán végigiterálni** (lásd
 * `firestore.rules`), ezért az ottani ellenőrzés csak az első elem alakjára és
 * a darabszámra terjed ki — a többi elem a callable-en megy át, ami az app
 * egyetlen írási útja.
 */

/** A hat támogatott hivatkozás-típus, ebben a (megjelenítési) sorrendben. */
const MENTION_TYPES = Object.freeze([
  'user',
  'article',
  'artist',
  'organizer',
  'event',
  'release',
]);

/** Egy üzenetben összesen ennyi hivatkozás fér el (tulajdonosi döntés). */
const MAX_MENTIONS = 10;

/** Egy üzenetből ennyi SZEMÉLY kaphat értesítést (tulajdonosi döntés). */
const MAX_USER_NOTIFICATIONS = 5;

/** A célpont-azonosító felső hossza (Firestore uid vagy WordPress-azonosító). */
const MAX_ID_LENGTH = 64;

/** A megjelenített név felső hossza (ugyanaz, mint az `actor-name-plan.js`-ben). */
const MAX_LABEL_LENGTH = 80;

/** Az értesítésben idézett részlet hossza. */
const MAX_EXCERPT_LENGTH = 80;

/** Ha a szerző neve nem ismert, **nem találgatunk** (a 357-es kör mintája). */
const GENERIC_AUTHOR_NAME = 'Egy HUHS tag';

/** BEMENET-ellenőrzés: **csak string** fogadható el, trimelve (a hosszkorlát a
 *  tisztított értéken mér, és a tisztított érték kerül a dokumentumba). */
function mentionField(value) {
  return typeof value === 'string' ? value.trim() : '';
}

/** KIMENET-építés: itt már nem validálunk, csak normalizálunk (a
 *  `chat-notification-plan.js` mintája: `String(value || '').trim()`). */
function cleanText(value) {
  return String(value ?? '').trim();
}

/**
 * A hivatkozások megtisztítása: mi kerülhet a `live_feed_posts.mentions` mezőbe,
 * és mi esik ki.
 *
 * @param {*} raw a kliens `mentions` mezője (szándékosan bármi lehet)
 * @param {{privileged?: boolean}} [options] `privileged === true`, ha a szerző
 *        `accessRole`-ja `admin` vagy `moderator` (a tartalom-hivatkozásokhoz)
 * @returns {{mentions: Array<{type: string, id: string, label: string}>, dropped: number}}
 *          a megtartott hivatkozások és a **kihagyottak száma**
 *
 * A szabályok szándékosak:
 *  1. **csak tömböt** fogadunk el — minden más bemenet üres lista, és ekkor
 *     `dropped` is 0 (nem hiba, csak nincs mit szűrni; a régi kliensek nem
 *     küldenek `mentions` mezőt);
 *  2. érvényes elem: ismert `type`, nem üres `id` ≤ 64 és nem üres `label` ≤ 80
 *     — **csak valódi string** fogadható el (szám nem), **a tisztított (trimelt)
 *     értéken** mérve, és a tisztított érték kerül a dokumentumba;
 *  3. a `user` típus **mindenkinek** engedett, a másik öt TARTALOM-típus
 *     **csak** `privileged` módban (a tulajdonos kérése: *„A személyre/userre
 *     hivatkozás legyen elérhető mindenkinek, többi csak admin/moderátornak"*);
 *  4. az azonos `type:id` párok **összevonódnak** — a duplikátum **nem**
 *     számít kihagyottnak (nem büntetjük azt, aki ugyanazt kétszer küldi);
 *  5. a **10. utáni** érvényes hivatkozás kiesik, és `dropped`-nek számít,
 *     ahogy az érvénytelen vagy nem engedett elem is.
 */
function sanitizeMentions(raw, { privileged = false } = {}) {
  if (!Array.isArray(raw)) return { mentions: [], dropped: 0 };

  const mentions = [];
  const seen = new Set();
  let dropped = 0;

  for (const item of raw) {
    const isObject = item !== null && typeof item === 'object' && !Array.isArray(item);
    const type = isObject ? mentionField(item.type) : '';
    const id = isObject ? mentionField(item.id) : '';
    const label = isObject ? mentionField(item.label) : '';

    const valid = MENTION_TYPES.includes(type)
      && id.length > 0
      && id.length <= MAX_ID_LENGTH
      && label.length > 0
      && label.length <= MAX_LABEL_LENGTH;
    if (!valid) {
      dropped += 1;
      continue;
    }

    // A jogosultság a SZERVEREN dől el: a nem admin/moderátor tartalom-
    // hivatkozása kiesik, a szöveg viszont marad.
    if (type !== 'user' && privileged !== true) {
      dropped += 1;
      continue;
    }

    const key = `${type}:${id}`;
    // Duplikátum: összevonva, NEM számít kihagyottnak (4. szabály). Az első
    // előfordulás nyer, ezért a tárolt `label` determinisztikus.
    if (seen.has(key)) continue;

    if (mentions.length >= MAX_MENTIONS) {
      dropped += 1;
      continue;
    }

    seen.add(key);
    mentions.push({ type, id, label });
  }

  return { mentions, dropped };
}

/**
 * Az értesítésben idézett RÉSZLET: whitespace-összevont szöveg első 80
 * karaktere, hosszabban `…`-tal a végén.
 */
function mentionExcerpt(text) {
  const collapsed = String(text ?? '').replace(/\s+/g, ' ').trim();
  if (collapsed.length <= MAX_EXCERPT_LENGTH) return collapsed;
  return `${collapsed.slice(0, MAX_EXCERPT_LENGTH)}…`;
}

/**
 * Kik kapnak értesítést a megemlítésről?
 *
 * @param {object} args
 * @param {string} args.postId     a Chat-üzenet azonosítója (a célpont)
 * @param {string} args.authorId   a szerző uid-ja (őt nem értesítjük)
 * @param {string} args.authorName a szerző neve (a szövegben)
 * @param {Array}  args.mentions   a **már megtisztított** hivatkozások
 * @param {string} args.text       az üzenet szövege (a részlethez)
 * @returns {Array<object>} értesítés-payloadok (a `createNotificationBestEffort`-hoz)
 *
 * Öt szándékos szabály:
 *  1. **csak `user`** hivatkozásból lesz értesítés — a tartalom-hivatkozás
 *     kattintható, de nem szól senkinek;
 *  2. a **szerzőt kihagyjuk** (mint a saját lájknál): önmagát megemlíteni szabad,
 *     de nem kap róla értesítést;
 *  3. **legfeljebb 5** értesítés/üzenet (tulajdonosi döntés), a hivatkozások
 *     sorrendjében;
 *  4. ugyanaz a címzett **egyszer** szól (`dedupeKey` a postId-hoz és a
 *     címzetthez kötött, ezért egy újrakézbesítés sem dupláz);
 *  5. **hiányzó `postId`** esetén üres tömb — nem találgatunk (a `targetId` és a
 *     `dedupeKey` nélkül az értesítés értelmezhetetlen lenne).
 */
function chatMentionNotifications({ postId, authorId, authorName, mentions, text } = {}) {
  const post = cleanText(postId);
  if (!post) return [];

  const author = cleanText(authorId);
  const name = cleanText(authorName) || GENERIC_AUTHOR_NAME;
  const excerpt = mentionExcerpt(text);
  const notifications = [];
  const notified = new Set();

  for (const mention of Array.isArray(mentions) ? mentions : []) {
    if (mention === null || typeof mention !== 'object' || Array.isArray(mention)) continue;
    if (cleanText(mention.type) !== 'user') continue;

    const recipientUid = cleanText(mention.id);
    if (!recipientUid) continue;
    if (author && recipientUid === author) continue;
    if (notified.has(recipientUid)) continue;
    if (notifications.length >= MAX_USER_NOTIFICATIONS) break;

    notified.add(recipientUid);
    notifications.push({
      recipientUid,
      type: 'chat_mention',
      title: 'Megemlítettek a Chatben',
      body: `${name} megemlített a Chatben: „${excerpt}”`,
      targetType: 'chat',
      targetId: post,
      dedupeKey: `chat-mention:${post}:${recipientUid}`,
      senderId: author,
    });
  }

  return notifications;
}

module.exports = {
  MENTION_TYPES,
  MAX_MENTIONS,
  MAX_USER_NOTIFICATIONS,
  MAX_ID_LENGTH,
  MAX_LABEL_LENGTH,
  MAX_EXCERPT_LENGTH,
  sanitizeMentions,
  mentionExcerpt,
  chatMentionNotifications,
};
