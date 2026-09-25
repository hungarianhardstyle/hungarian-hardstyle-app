'use strict';

/**
 * Az app-értesítések és a push üzenetek **nyelvi katalógusa**.
 *
 * MIÉRT KÜLÖN, TISZTA MODUL: a szövegek eddig a hívásokba égetve, **magyarul**
 * voltak (`functions/index.js`, `chat-notification-plan.js`,
 * `chat-mention-plan.js`), ezért az angol felületű felhasználó **magyar**
 * értesítést kapott. A döntés (tulajdonos, 2026-09-25): az értesítés a
 * **címzett** nyelvén menjen.
 *
 * A modul szándékosan **hálózat és Firestore nélkül** olvasható: a szöveg-
 * feloldás tiszta függvény, ezért mérhető. A címzett nyelvét a hívó adja
 * (`community_profiles/{uid}.language`), ismeretlen/hiányzó értékre **magyar**
 * (`DEFAULT_NOTIFICATION_LANGUAGE`) — így egy régi kliens vagy hiányzó mező nem
 * hagy üres értesítést.
 *
 * ⚠️ A `{név}` helyőrzők a `params` kulcsaival töltődnek; a hiányzó paraméter
 * **üres string** lesz (nem `undefined`), hogy a szöveg olvasható maradjon.
 */

const DEFAULT_NOTIFICATION_LANGUAGE = 'hu';
const NOTIFICATION_LANGUAGES = ['hu', 'en'];

/** A `language` mező normalizálása: minden ismeretlen és hiányzó érték magyar. */
function normalizeNotificationLanguage(value) {
  const code = String(value ?? '').trim().toLowerCase();
  if (code === 'en' || code.startsWith('en-') || code.startsWith('en_')) return 'en';
  return DEFAULT_NOTIFICATION_LANGUAGE;
}

/**
 * A pontforrás (`achievement_ledger.sourceKey`) → katalógus-kulcs.
 *
 * A mérés szerint **14 ág** van; a sorrend számít (a prefixek), ezért ez a
 * leképezés egy helyen él, és a `hu` szövegek **szó szerint** az eddigiek.
 */
function achievementReasonKey(sourceKey) {
  const key = String(sourceKey || '');
  if (key.startsWith('news-like:')) return 'achievement_reason_news_like';
  if (key.startsWith('article-comment:')) return 'achievement_reason_article_comment';
  if (key.startsWith('attendance:')) return 'achievement_reason_attendance';
  if (key.startsWith('meetup:')) return 'achievement_reason_meetup';
  if (key.startsWith('meetup-interest:')) return 'achievement_reason_meetup_interest';
  if (key.startsWith('event-rating:')) return 'achievement_reason_event_rating';
  if (key.startsWith('voting:')) return 'achievement_reason_voting';
  if (key.startsWith('game:')) return 'achievement_reason_game';
  if (key === 'profile-complete') return 'achievement_reason_profile_complete';
  if (key.startsWith('referral:')) return 'achievement_reason_referral';
  if (key.startsWith('news-like-restore:')) return 'achievement_reason_news_like_restore';
  if (key.startsWith('submission:')) return 'achievement_reason_submission';
  if (key.startsWith('release-purchase:')) return 'achievement_reason_release_purchase';
  if (key.startsWith('daily-activity:')) return 'achievement_reason_daily_activity';
  return 'achievement_reason_generic';
}

/** A katalógus: `kind` → `{ hu: {title, body}, en: {title, body} }`. */
const TEXTS = {
  article_comment: {
    hu: {
      title: 'Új hozzászólás érkezett',
      body: '{name} hozzászólt egy cikkhez: „{snippet}”',
    },
    en: {
      title: 'New comment posted',
      body: '{name} commented on an article: “{snippet}”',
    },
  },
  article_comment_reply: {
    hu: {
      title: 'Válaszoltak a hozzászólásodra',
      body: '{name} válaszolt a hozzászólásodra egy cikknél.',
    },
    en: {
      title: 'Someone replied to your comment',
      body: '{name} replied to your comment on an article.',
    },
  },
  chat_reaction: {
    hu: {
      title: 'Kedvelték a Chat-üzenetedet',
      body: '{name} kedvelte a Chat-üzenetedet.',
    },
    en: {
      title: 'Your Chat message was liked',
      body: '{name} liked your Chat message.',
    },
  },
  chat_reply: {
    hu: {
      title: 'Válaszoltak a Chat-üzenetedre',
      body: '{name} válaszolt a Chat-üzenetedre.',
    },
    en: {
      title: 'Someone replied to your Chat message',
      body: '{name} replied to your Chat message.',
    },
  },
  chat_mention: {
    hu: {
      title: 'Megemlítettek a Chatben',
      body: '{name} megemlített a Chatben: „{snippet}”',
    },
    en: {
      title: 'You were mentioned in the Chat',
      body: '{name} mentioned you in the Chat: “{snippet}”',
    },
  },
  chat_everyone: {
    hu: {
      title: 'Megemlítettek a Chatben',
      body: '{name} mindenkit megemlített a Chatben: „{snippet}”',
    },
    en: {
      title: 'You were mentioned in the Chat',
      body: '{name} mentioned everyone in the Chat: “{snippet}”',
    },
  },
  event_rating_request: {
    hu: {
      title: 'Értékeld az eseményt',
      body: '{event} véget ért. Értékeld az eseményt az appban.',
    },
    en: {
      title: 'Rate the event',
      body: '{event} has ended. Rate the event in the app.',
    },
  },
  new_news: {
    hu: { title: 'Új hír érkezett', body: '{name}' },
    en: { title: 'New article', body: '{name}' },
  },
  new_release: {
    hu: { title: 'Új release érkezett', body: '{name}' },
    en: { title: 'New release', body: '{name}' },
  },
  new_artist: {
    hu: { title: 'Új DJ került fel', body: '{name}' },
    en: { title: 'New DJ added', body: '{name}' },
  },
  new_organizer: {
    hu: { title: 'Új szervező került fel', body: '{name}' },
    en: { title: 'New organizer added', body: '{name}' },
  },
  new_event: {
    hu: { title: 'Új esemény érkezett', body: '{name}' },
    en: { title: 'New event', body: '{name}' },
  },
  prize_winner: {
    hu: { title: '🏆 Nyertél a nyereményjátékban!', body: 'Megnyerted a nyereményjátékot: {prize}' },
    en: { title: '🏆 You won the giveaway!', body: 'You won the giveaway: {prize}' },
  },
  prize_winner_no_prize: {
    hu: { title: '🏆 Nyertél a nyereményjátékban!', body: 'Megnyerted a nyereményjátékot!' },
    en: { title: '🏆 You won the giveaway!', body: 'You won the giveaway!' },
  },
  connection_request: {
    hu: { title: 'Új ismerősnek jelölés', body: '{name} ismerősnek jelölt.' },
    en: { title: 'New friend request', body: '{name} sent you a friend request.' },
  },
  meetup_interest: {
    hu: {
      title: 'Új Meetup érdeklődés',
      body: '{name} szívesen találkozna veled a(z) {event} eseményen.',
    },
    en: {
      title: 'New Meetup interest',
      body: '{name} would like to meet you at {event}.',
    },
  },
  chat_report: {
    hu: {
      title: 'Új chatjelentés',
      body: '{name} új chatjelentést küldött.',
    },
    en: {
      title: 'New chat report',
      body: '{name} submitted a new chat report.',
    },
  },
  chat_report_reason: {
    hu: { title: 'Új chatjelentés', body: '{name}: {reason}' },
    en: { title: 'New chat report', body: '{name}: {reason}' },
  },
  achievement_points: {
    hu: {
      title: '+{delta} achievement pont',
      body: '+{delta} pont {reason}. Új összösszpontszámod: {points}.',
    },
    en: {
      title: '+{delta} achievement points',
      body: '+{delta} points {reason}. Your new total is {points}.',
    },
  },
  achievement_points_level: {
    hu: {
      title: '+{delta} achievement pont',
      body: '+{delta} pont {reason}. Új összösszpontszámod: {points}. Új rangod: „{badge}”.',
    },
    en: {
      title: '+{delta} achievement points',
      body: '+{delta} points {reason}. Your new total is {points}. New rank: “{badge}”.',
    },
  },
  achievement_reason_news_like: {
    hu: { title: '', body: 'egy hír kedveléséért' },
    en: { title: '', body: 'for liking a news article' },
  },
  achievement_reason_article_comment: {
    hu: { title: '', body: 'egy cikkhez írt hozzászólásodért' },
    en: { title: '', body: 'for your comment on an article' },
  },
  achievement_reason_attendance: {
    hu: { title: '', body: 'egy eseményre való jelentkezésedért' },
    en: { title: '', body: 'for signing up for an event' },
  },
  achievement_reason_meetup: {
    hu: { title: '', body: 'egy meetupon való részvételedért' },
    en: { title: '', body: 'for taking part in a meetup' },
  },
  achievement_reason_meetup_interest: {
    hu: { title: '', body: 'egy meetup iránti érdeklődésedért' },
    en: { title: '', body: 'for your interest in a meetup' },
  },
  achievement_reason_event_rating: {
    hu: { title: '', body: 'egy esemény értékeléséért' },
    en: { title: '', body: 'for rating an event' },
  },
  achievement_reason_voting: {
    hu: { title: '', body: 'az éves szavazáson leadott szavazatodért' },
    en: { title: '', body: 'for your vote in the annual poll' },
  },
  achievement_reason_game: {
    hu: { title: '', body: 'egy játék teljesítéséért' },
    en: { title: '', body: 'for completing a game' },
  },
  achievement_reason_profile_complete: {
    hu: { title: '', body: 'a profilod kitöltéséért' },
    en: { title: '', body: 'for completing your profile' },
  },
  achievement_reason_referral: {
    hu: { title: '', body: 'egy meghívott barátod regisztrációjáért' },
    en: { title: '', body: 'for a friend you invited signing up' },
  },
  achievement_reason_news_like_restore: {
    hu: { title: '', body: 'egy korábban elveszett lájkpont visszaállításáért' },
    en: { title: '', body: 'for restoring a previously lost like point' },
  },
  achievement_reason_submission: {
    hu: { title: '', body: 'egy jóváhagyott beküldésedért' },
    en: { title: '', body: 'for an approved submission of yours' },
  },
  achievement_reason_release_purchase: {
    hu: { title: '', body: 'egy kiadvány megvásárlásáért' },
    en: { title: '', body: 'for purchasing a release' },
  },
  achievement_reason_daily_activity: {
    hu: { title: '', body: 'a tegnapi közösségi aktivitásodért (hozzászólás és chat)' },
    en: { title: '', body: 'for your community activity yesterday (comments and chat)' },
  },
  achievement_reason_generic: {
    hu: { title: '', body: 'egy jóváírt tevékenységért' },
    en: { title: '', body: 'for a credited activity' },
  },
};

/**
 * Nyelvfüggő **alapértékek** a helyőrzőkhöz.
 *
 * ⚠️ MIÉRT KELL: a neveknél eddig a hívóba égetett magyar tartalék volt
 * (`'Egy HUHS tag'`), ami angol értesítésben is magyarul jelent volna meg. A
 * tartalék ezért itt, nyelvenként él; a többi hiányzó helyőrző üres marad.
 */
const PLACEHOLDER_DEFAULTS = {
  name: { hu: 'Egy HUHS tag', en: 'A HUHS member' },
};

/** A `{helyőrző}` kitöltése; a hiányzó paraméter az alapérték vagy üres string. */
function fillTemplate(template, params, language) {
  return String(template ?? '').replace(/\{(\w+)\}/g, (_match, key) => {
    const value = params?.[key];
    if (value !== undefined && value !== null && String(value).trim() !== '') return String(value);
    const fallback = PLACEHOLDER_DEFAULTS[key];
    if (fallback) return fallback[language] ?? fallback[DEFAULT_NOTIFICATION_LANGUAGE];
    return '';
  });
}

/**
 * A szöveg feloldása.
 *
 * @returns {{title: string, body: string}|null} `null`, ha a `kind` ismeretlen
 *   (akkor a hívó a saját szövegére esik vissza — nem tippelünk).
 */
function notificationText(kind, language, params = {}) {
  const entry = TEXTS[String(kind || '').trim()];
  if (!entry) return null;
  const code = normalizeNotificationLanguage(language);
  const template = entry[code] || entry[DEFAULT_NOTIFICATION_LANGUAGE];
  // ⚠️ `reasonKey`: a `{reason}` helyőrző BEÁGYAZOTT katalógus-kulcsból is
  // jöhet (a pontforrás indoklása) — így a hívó nem kénytelen nyelvet választani.
  const resolved = { ...(params || {}) };
  if (resolved.reasonKey && !resolved.reason) {
    const reason = TEXTS[String(resolved.reasonKey).trim()];
    if (reason) {
      const reasonTemplate = reason[code] || reason[DEFAULT_NOTIFICATION_LANGUAGE];
      resolved.reason = reasonTemplate.body;
    }
  }
  return {
    title: fillTemplate(template.title, resolved, code),
    body: fillTemplate(template.body, resolved, code),
  };
}

/** A pontforrás indoklása a címzett nyelvén (a `reason` helyőrző tartalma). */
function achievementReasonText(sourceKey, language) {
  const text = notificationText(achievementReasonKey(sourceKey), language);
  return text ? text.body : '';
}

module.exports = {
  DEFAULT_NOTIFICATION_LANGUAGE,
  NOTIFICATION_LANGUAGES,
  PLACEHOLDER_DEFAULTS,
  TEXTS,
  achievementReasonKey,
  achievementReasonText,
  normalizeNotificationLanguage,
  notificationText,
};
