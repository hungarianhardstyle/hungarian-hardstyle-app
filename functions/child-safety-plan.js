'use strict';

/**
 * Gyermekbiztonsági jelzőrendszer — az **1. fázis** döntése: tiszta logika,
 * nulla függőség, hálózat és Firestore nélkül mérhető.
 *
 * A tulajdonos döntése (2026-09-27, a `docs/GYERMEKBIZTONSAG-MODERACIO-JAVASLAT.md`
 * 1. fázisa): *„indulhat az első fázis + olyan is kéne ha egy gyerekre írnak rá
 * alapból figyelmeztesse a rendszer, hogy akivel beszél öregebb + terjesszük ki
 * angolra is és legyen 16+ a regelés korhatár"*.
 *
 * Ez a modul a **privát chat** üzeneteit méri (a Chat fan-out és a cikk-kommentek
 * nincsenek benne), és **négyféle jelet** ismer:
 *
 *  1. **korkülönbség** — a két fél `community_profiles/{uid}.birthDate` mezőjéből
 *     számolt életkor; ha az egyik fél **kiskorú** (18 év alatt), a másik pedig
 *     **nagykorú**, a különbség súlyt kap (minél nagyobb, annál nagyobbat);
 *  2. **életkorra kérdezés** („hány éves vagy", „how old are you");
 *  3. **titoktartás / találkozó / kép kérése / lakóhely** — a szakirodalomban
 *     (és a Play „gyermekbiztonsági normák" elvárásában) **magas kockázatú**
 *     jelnek számító kérések;
 *  4. **más platformra terelés és elérhetőség-csere** (Snapchat/Insta/WhatsApp/
 *     Telegram/…, telefonszám, e-mail, `@`-handle) — a grooming tipikus
 *     első lépése, mert onnantól a moderáció **nem lát rá** a beszélgetésre;
 *  5. **ajándék/pénz felajánlása** — a bizalom megvásárlásának jele.
 *
 * ⚠️ **ANGOLUL IS MŰKÖDIK** (tulajdonosi döntés): a minták **ékezet nélkül,
 * kisbetűvel** illeszkednek a normált szövegre (`normalizeForMatch`), ezért a
 * magyar ékezet hiánya/eltérése és az angol írásmód is talál.
 *
 * ⚠️ **ŐSZINTE KORLÁT:** ez **nem** automatikus gyermekbántalmazás-detektálás.
 * A jelzés **valószínűséget** fejez ki, ezért minden jelzés **emberi
 * felülvizsgálatra** megy (admin-értesítés + `moderation_flags` dokumentum), és
 * **nem** jár automatikus tiltással, üzenettörléssel vagy felhasználói
 * figyelmeztetéssel. A hamis pozitívok csökkentése érdekében egyetlen gyenge
 * jel önmagában **nem** elég (`MINIMUM_SCORE`).
 *
 * ⚠️ **ADATVÉDELEM:** a jelzés rögzíti a beszélgetés/üzenet azonosítóját és egy
 * **legfeljebb 200 karakteres** részletet — ugyanazt, amit a `chat_reports` út is
 * tárol. A részlet a felülvizsgálathoz kell; a jelzés **nem** kerül a
 * felhasználók elé, és a `moderation_flags` gyűjteményt a szabály csak
 * admin/moderátor számára engedi olvasni.
 */

/** A kiskorúság határa (az app 16+ korhatárral regisztrál, de a jelzés 18 alatt szól). */
const MINOR_AGE = 18;

/** A regisztrációs korhatár (a tulajdonos döntése: 16+). */
const MINIMUM_REGISTRATION_AGE = 16;

/** A legkorábbi elfogadott év (elgépelés ellen; ugyanaz, mint a vetítésben). */
const FIRST_YEAR = 1900;

/** Ettől a korkülönbségtől számít a pár „nem kortárs"-nak (kiskorú ↔ nagykorú). */
const AGE_GAP_THRESHOLD = 5;

/** A jelzés-dokumentum gyűjteménye. */
const FLAG_COLLECTION = 'moderation_flags';

/** A detektor verziója — a jelzés dokumentumba kerül, hogy a későbbi változás látszódjon. */
const DETECTOR_VERSION = 'child-safety-plan/1';

/** A jelzésben tárolt részlet felső hossza (ugyanaz az elv, mint a chatjelentésnél). */
const MAX_EXCERPT_LENGTH = 200;

/** Az admin-értesítésben idézett indoklás felső hossza. */
const MAX_REASON_LENGTH = 200;

/**
 * A jelek pontszáma. A `highRisk` jelek **magas kockázatúak**: ha kiskorú is
 * érintett, a jelzés súlyossága **legalább `high`** (nem várunk további jelekre).
 */
const SIGNAL_DEFINITIONS = Object.freeze([
  {
    code: 'age_probe',
    weight: 2,
    highRisk: false,
    // Életkorra kérdezés — önmagában ártalmatlan, ezért a legalacsonyabb súly.
    phrases: [
      'hany eves vagy',
      'hany evesek vagytok',
      'mennyi idos vagy',
      'mikor szulettel',
      'melyik osztalyba jarsz',
      'hanyadik osztalyba jarsz',
      'how old are you',
      'how old r u',
      'whats your age',
      'what is your age',
      'when were you born',
      'which grade are you in',
      'what grade are you in',
      'are you still in school',
    ],
  },
  {
    code: 'secrecy_request',
    weight: 4,
    highRisk: true,
    phrases: [
      'senkinek ne mondd',
      'senkinek sem mondd',
      'ne mondd el senkinek',
      'ne mondd el a szuleidnek',
      'ne szolj a szuleidnek',
      'titok marad',
      'titokban tartsd',
      'ez a mi titkunk',
      'torold ki ezt',
      'torold az uzeneteket',
      'ne mondd el a barataidnak',
      'dont tell anyone',
      'do not tell anyone',
      'dont tell your parents',
      'do not tell your parents',
      'keep it a secret',
      'keep this between us',
      'keep it between us',
      'our secret',
      'delete these messages',
      'delete this message',
      'dont show anyone',
    ],
  },
  {
    code: 'meeting_request',
    weight: 4,
    highRisk: true,
    phrases: [
      'talalkozzunk',
      'talalkozz velem',
      'talalkozni akarok veled',
      'gyere el hozzam',
      'gyere at hozzam',
      'gyere egyedul',
      'varok a parkban',
      'meet me',
      'meet up with me',
      'lets meet',
      'let us meet',
      'can we meet',
      'come alone',
      'come over to my place',
      'come to my place',
      'i will pick you up',
      'ill pick you up',
    ],
  },
  {
    code: 'image_request',
    weight: 4,
    highRisk: true,
    phrases: [
      'kuldj kepet',
      'kuldj fotot',
      'kuldj egy kepet',
      'kuldj magadrol kepet',
      'kuldj magadrol fotot',
      'meztelen kep',
      'pucer kep',
      'mutasd magad',
      'send a pic',
      'send me a pic',
      'send pics',
      'send me pics',
      'send nudes',
      'send me a photo of you',
      'send me a picture of you',
      'nude pic',
      'picture of you',
      'show me your body',
    ],
  },
  {
    code: 'address_probe',
    weight: 3,
    highRisk: true,
    phrases: [
      'hol laksz',
      'mi a cimed',
      'mi az email cimed',
      'hol van a hazad',
      'egyedul vagy otthon',
      'otthon vagy egyedul',
      'a szuleid otthon vannak',
      'where do you live',
      'whats your address',
      'what is your address',
      'are you home alone',
      'are your parents home',
      'are your parents at home',
      'is anyone home',
    ],
  },
  {
    code: 'off_platform_contact',
    weight: 2,
    highRisk: false,
    phrases: [
      'snapchat',
      'snap chat',
      'insta',
      'instagram',
      'whatsapp',
      'whats app',
      'viber',
      'telegram',
      'discord',
      'messenger',
      'tiktok',
      'add me on',
      'dm me',
      'irj privatban',
      'privatban folytassuk',
      'beszeljunk privatban',
      'a sajat szamom',
    ],
  },
  {
    code: 'contact_share',
    weight: 2,
    highRisk: false,
    // Külön kezelés: telefonszám és e-mail MINTÁVAL (lásd `detectSignals`).
    detectors: ['phone', 'email', 'handle'],
  },
  {
    code: 'gift_or_money',
    weight: 3,
    highRisk: false,
    phrases: [
      'kuldok neked penzt',
      'adok neked penzt',
      'fizetek neked',
      'veszek neked ajandekot',
      'ajandekot veszek neked',
      'kuldok neked valamit',
      'send you money',
      'give you money',
      'buy you a gift',
      'i will buy you',
      'ill buy you',
      'ill pay you',
      'i can pay you',
      'send you a gift',
    ],
  },
]);

/** A jelek sorrendje (a jelzés-dokumentumban is így szerepelnek). */
const SIGNAL_CODES = Object.freeze(SIGNAL_DEFINITIONS.map((signal) => signal.code));

/** A magas kockázatú jelek halmaza. */
const HIGH_RISK_CODES = Object.freeze(
  SIGNAL_DEFINITIONS.filter((signal) => signal.highRisk).map((signal) => signal.code),
);

/** A jelek **kétnyelvű** címkéje (az admin-értesítés a címzett nyelvén szól). */
const SIGNAL_LABELS = Object.freeze({
  age_gap: { hu: 'nagy korkülönbség', en: 'large age gap' },
  age_probe: { hu: 'életkorra kérdez rá', en: 'asks about age' },
  secrecy_request: { hu: 'titoktartást kér', en: 'asks for secrecy' },
  meeting_request: { hu: 'találkozót kér', en: 'asks to meet' },
  image_request: { hu: 'képet kér', en: 'asks for photos' },
  address_probe: { hu: 'lakóhelyre kérdez rá', en: 'asks about the home address' },
  off_platform_contact: { hu: 'másik platformra terelné', en: 'moves to another platform' },
  contact_share: { hu: 'elérhetőséget oszt meg', en: 'shares contact details' },
  gift_or_money: { hu: 'ajándékot vagy pénzt ajánl', en: 'offers gifts or money' },
});

/** A súlyosság kétnyelvű címkéje. */
const SEVERITY_LABELS = Object.freeze({
  high: { hu: 'magas', en: 'high' },
  medium: { hu: 'közepes', en: 'medium' },
  low: { hu: 'alacsony', en: 'low' },
});

/** Nyelv-normalizálás: minden ismeretlen érték magyar (mint a többi szerver-úton). */
function normalizeLanguage(value) {
  const code = String(value ?? '')
    .trim()
    .toLowerCase();
  if (code === 'en' || code.startsWith('en-') || code.startsWith('en_')) return 'en';
  return 'hu';
}

/**
 * A szöveg illesztés előtti normalizálása: kisbetű + **ékezetek eltávolítása**.
 *
 * MIÉRT: így egy minta (`'hany eves vagy'`) talál a `„Hány éves vagy?"` és a
 * `„hany eves vagy"` írásmódra is, és az **angol** minták ugyanígy illeszkednek.
 */
function normalizeForMatch(value) {
  return String(value ?? '')
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[’‘`´]/g, "'")
    .replace(/\s+/g, ' ')
    .trim();
}

/** Telefonszám-e a szöveg? Legalább 9 számjegy egybefüggő számsorozatban. */
function hasPhoneNumber(normalized) {
  const candidates = normalized.match(/\+?\d[\d\s\-().]{7,}\d/g) || [];
  return candidates.some((candidate) => candidate.replace(/\D/g, '').length >= 9);
}

/** E-mail cím a szövegben? */
function hasEmail(normalized) {
  return /[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}/.test(normalized);
}

/** `@`-handle (pl. `@nev123`) a szövegben? */
function hasSocialHandle(normalized) {
  return /(^|[\s(])@[a-z0-9._]{3,}/.test(normalized);
}

const PATTERN_DETECTORS = Object.freeze({
  phone: hasPhoneNumber,
  email: hasEmail,
  handle: hasSocialHandle,
});

/**
 * A szöveg jelei — **kanonikus sorrendben**, ismétlődés nélkül.
 *
 * @param {string} text az üzenet szövege (kép esetén üres)
 * @returns {string[]} a talált jel-kódok
 */
function detectSignals(text) {
  const normalized = normalizeForMatch(text);
  if (!normalized) return [];
  const found = [];
  for (const definition of SIGNAL_DEFINITIONS) {
    const byPhrase = (definition.phrases || []).some((phrase) => normalized.includes(phrase));
    const byDetector = (definition.detectors || []).some((name) =>
      PATTERN_DETECTORS[name](normalized),
    );
    if (byPhrase || byDetector) found.push(definition.code);
  }
  return found;
}

/** Egy jel súlya (ismeretlen kódra 0 — nem tippelünk). */
function signalWeight(code) {
  const definition = SIGNAL_DEFINITIONS.find((signal) => signal.code === code);
  return definition ? definition.weight : 0;
}

/**
 * A születési dátum beolvasása `'YYYY-MM-DD'` alakból (a `community_profiles`
 * mezője), **valós dátum**-ellenőrzéssel. Elfogad `Date`-et is (Firestore).
 *
 * @returns {{year: number, month: number, day: number}|null}
 */
function parseBirthDate(value) {
  if (value instanceof Date && !Number.isNaN(value.getTime())) {
    return {
      year: value.getUTCFullYear(),
      month: value.getUTCMonth() + 1,
      day: value.getUTCDate(),
    };
  }
  const text = String(value ?? '').trim();
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(text);
  if (!match) return null;
  const year = Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  // Valós dátum: a hónap napjai (szökőévvel) — a `Date` normalizálna, ezért
  // visszamérjük, hogy a megadott nap megmaradt-e.
  const probe = new Date(Date.UTC(year, month - 1, day));
  if (
    probe.getUTCFullYear() !== year ||
    probe.getUTCMonth() + 1 !== month ||
    probe.getUTCDate() !== day
  ) {
    return null;
  }
  return { year, month, day };
}

/**
 * Az életkor **betöltött** években a megadott időpontban.
 *
 * ⚠️ A `functions/birth-date-plan.js` (`ageInYears`) **ugyanezt** a szabályt
 * használja, hogy a jelzés és a nyilvános kor-sáv ne mondhasson mást; a
 * széttartást a `child-safety-plan.test.cjs` **össze is méri**.
 *
 * @returns {number|null} `null`, ha nincs/hibás/valószerűtlen a születési dátum
 */
function ageInYears(birthDate, now = new Date()) {
  const parsed = parseBirthDate(birthDate);
  if (!parsed || parsed.year < FIRST_YEAR) return null;
  const reference = now instanceof Date ? now : new Date(now);
  if (Number.isNaN(reference.getTime())) return null;
  let age = reference.getUTCFullYear() - parsed.year;
  const monthDiff = reference.getUTCMonth() + 1 - parsed.month;
  if (monthDiff < 0 || (monthDiff === 0 && reference.getUTCDate() < parsed.day)) age -= 1;
  if (age < 0) return null;
  return age;
}

/**
 * A korkülönbség súlya — **csak akkor**, ha az egyik fél kiskorú, a másik
 * nagykorú (`AGE_GAP_THRESHOLD` alatt 0). A kortárs kapcsolat (mindkettő felnőtt
 * vagy mindkettő kiskorú) szándékosan **nem** kap súlyt.
 */
function ageGapWeight(ageGap, senderIsMinor, recipientIsMinor) {
  if (ageGap === null || senderIsMinor === recipientIsMinor) return 0;
  if (ageGap >= 15) return 5;
  if (ageGap >= 10) return 4;
  if (ageGap >= AGE_GAP_THRESHOLD) return 2;
  return 0;
}

/** A jelzés-dokumentum azonosítója — determinisztikus (a trigger ismételhet). */
function flagDocumentId(conversationId, messageId) {
  const conversation = String(conversationId || '').trim();
  const message = String(messageId || '').trim();
  if (!conversation || !message) return '';
  return `${conversation}__${message}`;
}

/** A beszélgetés-részlet: egysoros, legfeljebb `MAX_EXCERPT_LENGTH` karakter. */
function excerptOf(text) {
  const collapsed = String(text ?? '')
    .replace(/\s+/g, ' ')
    .trim();
  if (!collapsed) return '';
  if (collapsed.length <= MAX_EXCERPT_LENGTH) return collapsed;
  return `${collapsed.slice(0, MAX_EXCERPT_LENGTH - 1)}…`;
}

/** A jelmagyarázat a megadott nyelven (az admin-értesítéshez). */
function reasonSummary(reasonCodes, language = 'hu') {
  const lang = normalizeLanguage(language);
  const labels = (Array.isArray(reasonCodes) ? reasonCodes : [])
    .map((code) => (SIGNAL_LABELS[code] ? SIGNAL_LABELS[code][lang] : ''))
    .filter(Boolean);
  const text = labels.join(', ');
  if (text.length <= MAX_REASON_LENGTH) return text;
  return `${text.slice(0, MAX_REASON_LENGTH - 1)}…`;
}

/** A súlyosság címkéje a megadott nyelven. */
function severityLabel(severity, language = 'hu') {
  const lang = normalizeLanguage(language);
  const entry = SEVERITY_LABELS[String(severity || '').trim()];
  return entry ? entry[lang] : '';
}

/**
 * A jelzés **értesítés-típusa** a súlyosságból.
 *
 * MIÉRT külön típus súlyosságonként: az értesítés szövege a **címzett nyelvén**
 * születik (`functions/notification-texts.js`), ezért a súlyosság szavát nem
 * lehet a dokumentumba égetve tárolni — így viszont a katalógus fordítja.
 * Ismeretlen/hiányzó súlyosságra a semleges típus marad.
 */
const NOTIFICATION_KINDS = Object.freeze({
  high: 'child_safety_flag_high',
  medium: 'child_safety_flag_medium',
  low: 'child_safety_flag_low',
});

function notificationKind(severity) {
  return NOTIFICATION_KINDS[String(severity || '').trim()] || 'child_safety_flag';
}

/** A súlyosság a pontszámból — a `MINIMUM_SCORE` alatt nincs jelzés. */
const MINIMUM_SCORE = 3;

function severityFor(score) {
  if (score >= 8) return 'high';
  if (score >= 5) return 'medium';
  if (score >= MINIMUM_SCORE) return 'low';
  return null;
}

/**
 * A **döntés**: kell-e jelzés erről az üzenetről, és ha igen, milyen súlyosan.
 *
 * @param {object} input
 * @param {object} input.message a `private_conversations/{id}/messages/{id}` adatai
 * @param {object} input.senderProfile a küldő `community_profiles` adatai
 * @param {object} input.recipientProfile a címzett `community_profiles` adatai
 * @param {Date}   [input.now] a számolás időpontja (teszthez)
 */
function planChildSafetyFlag({
  message = {},
  senderProfile = {},
  recipientProfile = {},
  now = new Date(),
} = {}) {
  const text = String(message.text || '');
  const imageUrl = String(message.imageUrl || '').trim();
  const senderAge = ageInYears(senderProfile.birthDate, now);
  const recipientAge = ageInYears(recipientProfile.birthDate, now);
  const senderAgeKnown = senderAge !== null;
  const recipientAgeKnown = recipientAge !== null;
  const senderIsMinor = senderAgeKnown && senderAge < MINOR_AGE;
  const recipientIsMinor = recipientAgeKnown && recipientAge < MINOR_AGE;
  const minorInvolved = senderIsMinor || recipientIsMinor;
  const adultWritesToMinor = recipientIsMinor && senderAgeKnown && !senderIsMinor;
  const agesKnown = senderAgeKnown && recipientAgeKnown;
  const ageGap = agesKnown ? Math.abs(senderAge - recipientAge) : null;

  const textSignals = detectSignals(text);
  const gapWeight = agesKnown ? ageGapWeight(ageGap, senderIsMinor, recipientIsMinor) : 0;
  const textScore = textSignals.reduce((total, code) => total + signalWeight(code), 0);
  const score = textScore + gapWeight;

  let severity = severityFor(score);
  // Magas kockázatú jel + kiskorú érintett = **legalább magas** súlyosság.
  if (
    severity &&
    minorInvolved &&
    textSignals.some((code) => HIGH_RISK_CODES.includes(code))
  ) {
    severity = 'high';
  }

  const reasonCodes = gapWeight > 0 ? ['age_gap', ...textSignals] : [...textSignals];

  return {
    shouldFlag: severity !== null,
    severity,
    score,
    reasonCodes,
    signalCount: textSignals.length,
    senderAge,
    recipientAge,
    ageGap,
    minorInvolved,
    senderIsMinor,
    recipientIsMinor,
    adultWritesToMinor,
    hasImage: Boolean(imageUrl),
    excerpt: excerptOf(text),
    detector: DETECTOR_VERSION,
  };
}

module.exports = {
  MINOR_AGE,
  MINIMUM_REGISTRATION_AGE,
  MINIMUM_SCORE,
  FIRST_YEAR,
  AGE_GAP_THRESHOLD,
  FLAG_COLLECTION,
  DETECTOR_VERSION,
  MAX_EXCERPT_LENGTH,
  SIGNAL_CODES,
  HIGH_RISK_CODES,
  SIGNAL_LABELS,
  SEVERITY_LABELS,
  NOTIFICATION_KINDS,
  notificationKind,
  normalizeForMatch,
  hasPhoneNumber,
  hasEmail,
  hasSocialHandle,
  detectSignals,
  signalWeight,
  parseBirthDate,
  ageInYears,
  ageGapWeight,
  flagDocumentId,
  excerptOf,
  severityFor,
  reasonSummary,
  severityLabel,
  planChildSafetyFlag,
};
