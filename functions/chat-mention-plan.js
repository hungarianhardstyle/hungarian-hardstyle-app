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
 * KÉSŐBB (2026-09-25) ehhez jött az **`@mindenki`** (a tulajdonos kérése:
 * *„kéne egy @mindenki tag is, amit ha beütök, kap mindenki notifyt és csak
 * moderátor/admin használhassa"*):
 *
 *  5. az `everyone` típus **csak privileged** küldőnek jár (mint a tartalom-
 *     hivatkozások), és **egyszer** szerepelhet — a második `dropped`;
 *  6. az `everyone` **alakját a szerver írja elő** (`id = 'everyone'`,
 *     `label = 'mindenki'`): a kliens címkéjét **soha nem hisszük el**;
 *  7. a fan-out **41 címzett ma** (mérve: `tools/check-everyone-reach.mjs`,
 *     41 dokumentum a `community_profiles`-ban), ezért felső plafonként
 *     `MAX_EVERYONE_RECIPIENTS = 500` van a biztonság kedvéért.
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

/** A hét támogatott hivatkozás-típus, ebben a (megjelenítési) sorrendben.
 *  Az `everyone` („@mindenki") a végén van: ez **csak privileged** küldőnek
 *  jár, és az alakját is a szerver írja elő (lásd `sanitizeMentions`). */
const MENTION_TYPES = Object.freeze([
  'user',
  'article',
  'artist',
  'organizer',
  'event',
  'release',
  'everyone',
]);

/** Az „@mindenki" típus, azonosító és címke — a szerver kanonikus alakja. */
const EVERYONE_TYPE = 'everyone';
const EVERYONE_ID = 'everyone';
const EVERYONE_LABEL = 'mindenki';

/** Egy „@mindenki" üzenet ennyi címzettet szólíthat meg (felső plafon: ma 41
 *  profil van összesen, mérve a `tools/check-everyone-reach.mjs`-szel). */
const MAX_EVERYONE_RECIPIENTS = 500;

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
 *        `accessRole`-ja `admin` vagy `moderator` (a tartalom-hivatkozásokhoz
 *        **és** az `everyone`-hoz)
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
 *     ahogy az érvénytelen vagy nem engedett elem is;
 *  6. az `everyone` („@mindenki") **csak `privileged`** módban megy át, és
 *     **egyszer** szerepelhet — a második előfordulás `dropped` (nem vonjuk
 *     össze csendben, mint a `type:id` duplikátumot, mert ez itt szándékos
 *     visszaélés-jelzés);
 *  7. az `everyone` **`id`/`label` mezőjét a szerver írja felül** a kanonikus
 *     értékre, ezért annak a kliens által küldött tartalma **soha** nem kerül a
 *     dokumentumba (és a hiányzó/érvénytelen `id`/`label` sem ok az elutasításra).
 */
function sanitizeMentions(raw, { privileged = false } = {}) {
  if (!Array.isArray(raw)) return { mentions: [], dropped: 0 };

  const mentions = [];
  const seen = new Set();
  let everyoneSeen = false;
  let dropped = 0;

  for (const item of raw) {
    const isObject = item !== null && typeof item === 'object' && !Array.isArray(item);
    const type = isObject ? mentionField(item.type) : '';
    const id = isObject ? mentionField(item.id) : '';
    const label = isObject ? mentionField(item.label) : '';

    if (!MENTION_TYPES.includes(type)) {
      dropped += 1;
      continue;
    }

    // @MINDENKI: ide a lenti id/label-érvényesség NEM vonatkozik — a kanonikus
    // alakot a szerver adja (a kliens címkéje nem hiteles), ezért a hiányzó vagy
    // hamis `id`/`label` nem elutasítási ok, hanem egyszerűen felülíródik.
    if (type === EVERYONE_TYPE) {
      // Jogosultság (mint a tartalom-hivatkozásoknál) + „egyszer" szabály.
      if (privileged !== true || everyoneSeen) {
        dropped += 1;
        continue;
      }
      if (mentions.length >= MAX_MENTIONS) {
        dropped += 1;
        continue;
      }
      everyoneSeen = true;
      mentions.push({ type: EVERYONE_TYPE, id: EVERYONE_ID, label: EVERYONE_LABEL });
      continue;
    }

    const valid = id.length > 0
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

/**
 * „@mindenki" értesítés **EGY** címzettnek.
 *
 * MIÉRT külön helper (és miért nem a `chatMentionNotifications`-ban): az
 * `everyone` nem egy konkrét `user`-hivatkozás, hanem **fan-out** — a címzettek
 * listáját a hívó tölti be (`community_profiles`), és **címzetenként** egy
 * payload kell. A `recipientUid` ezért **paraméter**, nem a `mentions` tömbből
 * jön; a payloadban viszont benne marad, mert a `createNotification` azt várja.
 *
 * @param {object} args
 * @param {string} args.postId       a Chat-üzenet azonosítója (a célpont)
 * @param {string} args.authorId     a szerző uid-ja (őt nem értesítjük)
 * @param {string} args.authorName   a szerző neve (a szövegben)
 * @param {string} args.excerpt      az üzenet szövege (a helper vágja 80-ra)
 * @param {string} args.recipientUid az ÉRTESÍTENDŐ címzett uid-ja
 * @returns {object|null} payload a `createNotificationBestEffort`-hoz, vagy
 *          `null`, ha nincs `postId`/`authorId`/`recipientUid`, illetve ha a
 *          címzett **maga a szerző** (önmagát nem értesítjük)
 *
 * A `dedupeKey` szándékosan **a címzettől is függ**
 * (`chat-everyone:{postId}:{recipientUid}`): különben a 41 címzett közül csak az
 * első kapna értesítést, mert a `createNotification` a kulcs SHA-256-ját teszi
 * a dokumentum azonosítójává.
 */
function chatEveryoneNotification({ postId, authorId, authorName, excerpt, recipientUid } = {}) {
  const post = cleanText(postId);
  const author = cleanText(authorId);
  const recipient = cleanText(recipientUid);
  if (!post || !author || !recipient) return null;
  if (recipient === author) return null;

  const name = cleanText(authorName) || GENERIC_AUTHOR_NAME;
  return {
    recipientUid: recipient,
    type: 'chat_mention',
    title: 'Megemlítettek a Chatben',
    body: `${name} mindenkit megemlített a Chatben: „${mentionExcerpt(excerpt)}”`,
    targetType: 'chat',
    targetId: post,
    dedupeKey: `chat-everyone:${post}:${recipient}`,
    senderId: author,
  };
}

/**
 * A teljes „@mindenki" fan-out: címzett-listából payload-lista.
 *
 * A plafon (`MAX_EVERYONE_RECIPIENTS = 500`) itt is érvényes, nem csak a
 * hívóban: így egy elszabadult lista **soha** nem tud 500 írásnál többet
 * indítani. Az ismétlődő és üres azonosítók kiesnek, a szerző pedig mindig
 * (még a lista első helyén is).
 *
 * @param {object} args
 * @param {string[]} args.recipientUids a címzettek (a hívó tölti be)
 * @returns {Array<object>} legfeljebb `MAX_EVERYONE_RECIPIENTS` payload
 */
function chatEveryoneNotifications({ postId, authorId, authorName, excerpt, recipientUids } = {}) {
  const notifications = [];
  const seen = new Set();

  for (const candidate of Array.isArray(recipientUids) ? recipientUids : []) {
    if (notifications.length >= MAX_EVERYONE_RECIPIENTS) break;
    const recipient = cleanText(candidate);
    if (!recipient || seen.has(recipient)) continue;

    const notification = chatEveryoneNotification({
      postId,
      authorId,
      authorName,
      excerpt,
      recipientUid: recipient,
    });
    if (!notification) continue;

    seen.add(recipient);
    notifications.push(notification);
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
  EVERYONE_TYPE,
  EVERYONE_ID,
  EVERYONE_LABEL,
  MAX_EVERYONE_RECIPIENTS,
  sanitizeMentions,
  mentionExcerpt,
  chatMentionNotifications,
  chatEveryoneNotification,
  chatEveryoneNotifications,
};
