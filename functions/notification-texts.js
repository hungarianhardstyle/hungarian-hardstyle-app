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
  // Heti összefoglaló (2026-09-27): vasárnap esti, egyszeri emlékeztető azoknak,
  // akik nem nyitják naponta az appot. A `{summary}` helyőrzőt a szerver állítja
  // össze nyelvenként (`digestParamsByLanguage`), ezért itt csak a keret van.
  weekly_digest: {
    hu: { title: 'Heti összefoglaló', body: '{summary} — nézd meg az appban.' },
    en: { title: 'Weekly recap', body: '{summary} — open the app to catch up.' },
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
  // ⚠️ 2026-09-27: a **rendszer** által írt gyermekbiztonsági jelzés
  // (`chat_reports.systemFlag`). Ugyanaz a `chat_reports` út viszi ki, de NEM a
  // „felhasználó jelentett" szöveg, mert az félrevezetné az admint: itt a
  // súlyosság és a talált jelek a lényeg.
  //
  // ⚠️ MIÉRT SÚLYOSSÁGONKÉNT KÜLÖN TÍPUS: az értesítés a **címzett nyelvén**
  // születik, ezért a súlyosság szava nem lehet a dokumentumba égetve — így a
  // katalógus fordítja (`child-safety-plan.js` → `notificationKind`).
  // A `{reasons}` a jel-kódokból, a címzett nyelvén áll össze
  // (`reasonSummary`), a `{name}` a jelzett felhasználó.
  child_safety_flag: {
    hu: { title: 'Gyermekbiztonsági jelzés', body: '{name}: {reasons}' },
    en: { title: 'Child safety alert', body: '{name}: {reasons}' },
  },
  child_safety_flag_high: {
    hu: { title: 'Gyermekbiztonsági jelzés (magas)', body: '{name}: {reasons}' },
    en: { title: 'Child safety alert (high)', body: '{name}: {reasons}' },
  },
  child_safety_flag_medium: {
    hu: { title: 'Gyermekbiztonsági jelzés (közepes)', body: '{name}: {reasons}' },
    en: { title: 'Child safety alert (medium)', body: '{name}: {reasons}' },
  },
  child_safety_flag_low: {
    hu: { title: 'Gyermekbiztonsági jelzés (alacsony)', body: '{name}: {reasons}' },
    en: { title: 'Child safety alert (low)', body: '{name}: {reasons}' },
  },
  // ⚠️ 2026-09-27: a **meglévő tagok** emlékeztetője (a tulajdonos kérése:
  // *„menjen ki notifybe mér kötelező a születési dátum, mehet nekik mail is"* —
  // *„a meglévő tagoknak úgyértem"*). A szöveg megmondja a **pontos helyet** is,
  // mert a nem létező menüút volt a leggyakoribb félreértés a korábbi körökben.
  // A kiküldést a `app_settings/birth_date_notice` kapcsoló zárja (lásd
  // `tools/birth-date-notice-flag.mjs`): csak akkor megy ki, ha a dátumot
  // felvevő app-verzió már éles.
  birth_date_required: {
    hu: {
      title: 'Kérjük, add meg a születési dátumod',
      body: 'A közösségi szabályok miatt minden tagnál kötelező a születési dátum. Nyisd meg a profilod (Chat fül → profil ikon → Profil szerkesztése), és add meg a dátumot.',
    },
    en: {
      title: 'Please add your date of birth',
      body: 'A date of birth is now required for every member. Open your profile (Chat tab → profile icon → Edit profile) and add it.',
    },
  },
  // ⚠️ 2026-09-27: a **születésnapi köszöntés** (a tulajdonos kérése: *„akinek
  // születésnapja van, az adott napon kapjon egy Boldog szülinapos Notifyt,
  // szépen megfogalmazva"*). A küldő kör naponta fut
  // (`exports.sendBirthdayGreetings`), de a `dedupeKey` évet is tartalmaz, ezért
  // egy tag **évente egyszer** kap köszöntést.
  //
  // ⚠️ A `{greeting}` helyőrző a **megszólítás** („Kedves Anna! " / „Dear Anna! "),
  // és **üres** is lehet: aki nem adott meg megjelenített nevet, az is olvasható
  // köszöntést kap (a mondat ilyenkor a csapattal kezdődik). A megszólítást a
  // `functions/birthday-plan.js` állítja össze (`birthdayGreeting`), hogy a
  // szöveg nyelvtanilag mindkét nyelven helyes legyen.
  birthday: {
    hu: {
      title: 'Boldog születésnapot! 🎂',
      body: '{greeting}A Hungarian Hardstyle csapata boldog születésnapot kíván! Köszönjük, hogy velünk vagy.',
    },
    en: {
      title: 'Happy birthday! 🎂',
      body: '{greeting}The Hungarian Hardstyle team wishes you a very happy birthday! Thank you for being with us.',
    },
  },
  // ⚠️ 2026-09-26: a privát üzenet címe eddig **beégetve, magyarul** állt
  // (`functions/index.js`, a privát üzenet ágán), ezért az angol felületű
  // címzett magyar címet kapott — és a kliens ebből a címből fejtette vissza a
  // küldő nevét (`' üzenetet küldött'` utótag levágása), ami angolul nem működött.
  private_message: {
    hu: { title: '{name} üzenetet küldött', body: '{snippet}' },
    en: { title: '{name} sent you a message', body: '{snippet}' },
  },
  achievement_points: {
    hu: {
      title: '+{delta} achievement pont',
      // ⚠️ JAVÍTVA (a tulajdonos jelzése, 2026-09-26): „Új összösszpontszámod"
      // volt — a szó kétszer szerepelt benne.
      body: '+{delta} pont {reason}. Új összpontszámod: {points}.',
    },
    en: {
      title: '+{delta} achievement points',
      body: '+{delta} points {reason}. Your new total is {points}.',
    },
  },
  achievement_points_level: {
    hu: {
      title: '+{delta} achievement pont',
      // ⚠️ Ugyanaz a szóismétlés javítva, mint a `achievement_points`-nál.
      body: '+{delta} pont {reason}. Új összpontszámod: {points}. Új rangod: „{badge}”.',
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

/**
 * Egy helyőrző-érték feloldása a nyelvre.
 *
 * ⚠️ MIÉRT KELL (mért hiba, 2026-09-26): a tulajdonos jelezte, hogy **az
 * értesítésben a cikk címe nem angol** angol módban. A gyökér: a WordPress
 * listát a szerver **nyelv nélkül** kérte le, ezért a cím magyarul jött, és az
 * angol címzett is azt kapta. A megoldás: a hívó **nyelvenkénti térképet** adhat
 * (`{ hu: '…', en: '…' }`), és a szöveg a címzett nyelvén választja ki az értéket.
 *
 * A sima szöveg (nem térkép) változatlanul működik, a hiányzó nyelv pedig a
 * magyarra esik vissza — így egy régi hívó sem törik el.
 */
function resolveParamValue(value, language) {
  if (value === undefined || value === null) return value;
  if (typeof value !== 'object' || Array.isArray(value)) return value;
  const code = normalizeNotificationLanguage(language);
  const candidates = [value[code], value[DEFAULT_NOTIFICATION_LANGUAGE], value.en, value.hu];
  for (const candidate of candidates) {
    if (candidate !== undefined && candidate !== null && String(candidate).trim() !== '') {
      return candidate;
    }
  }
  return '';
}

/** A `{helyőrző}` kitöltése; a hiányzó paraméter az alapérték vagy üres string. */
function fillTemplate(template, params, language) {
  return String(template ?? '').replace(/\{(\w+)\}/g, (_match, key) => {
    const raw = resolveParamValue(params?.[key], language);
    if (raw !== undefined && raw !== null && String(raw).trim() !== '') return String(raw);
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
  resolveParamValue,
};
