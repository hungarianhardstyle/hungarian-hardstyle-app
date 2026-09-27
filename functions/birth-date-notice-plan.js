'use strict';

/**
 * **Születési dátum emlékeztető a meglévő tagoknak** — tiszta döntés, nulla
 * függőség, Firestore és SMTP nélkül mérhető.
 *
 * A tulajdonos kérése (2026-09-27): *„menjen ki notifybe mér kötelező a
 * születési dátum, mehet nekik mail is"* — és pontosítás: *„a meglévő tagoknak
 * úgyértem"*. Vagyis a **már regisztrált**, de **születési dátum nélküli**
 * tagok kapjanak **értesítést** (és lehetőleg **e-mailt** is), hogy adják meg a
 * dátumot; ez a Play „gyermekbiztonsági normák" elvárásához és a 16+ korhatárhoz
 * kapcsolódik.
 *
 * MIÉRT külön modul: a „kit szólítunk meg, és ki kap e-mailt" döntés így
 * **hálózat nélkül** mérhető. A hívó (`functions/index.js`) csak a kiírást és a
 * küldést végzi.
 *
 * ⚠️ **IDEMPOTENCIA:** az értesítés `dedupeKey`-e (`birth_date_required:{uid}`)
 * determinisztikus, az e-mail tényét pedig a profilban jelöljük
 * (`birthDateNoticeEmailSentAt`) — így a napi kör **nem** spammel: egy tag
 * **egyszer** kap értesítést és **egyszer** e-mailt, akkor is, ha a dátumot
 * később sem adja meg.
 *
 * ⚠️ **ŐSZINTE KORLÁT:** az e-mail csak akkor megy ki, ha a profilban **van**
 * érvényes cím (a szociális belépésnél lehet, hogy nincs). A küldés
 * best-effort: egy hibás cím nem állítja meg a többit, és **nem** jelöljük
 * elküldöttnek — a következő kör újrapróbálja.
 */

/** Az értesítés típusa (a nyelvi katalógus kulcsa is ez). */
const NOTICE_TYPE = 'birth_date_required';

/** Az értesítés azonosítója a profilban (az e-mail ténye külön mező). */
const NOTICE_FIELD = 'birthDateNoticeSentAt';
const EMAIL_FIELD = 'birthDateNoticeEmailSentAt';

/** Egy körben ennyi e-mail megy ki (SMTP-kímélés; a kör naponta ismétlődik). */
const DEFAULT_EMAIL_LIMIT = 40;
const MAX_EMAIL_LIMIT = 200;

/** Nyelv-normalizálás: minden ismeretlen érték magyar (mint a többi szerver-úton). */
function normalizeLanguage(value) {
  const code = String(value ?? '')
    .trim()
    .toLowerCase();
  if (code === 'en' || code.startsWith('en-') || code.startsWith('en_')) return 'en';
  return 'hu';
}

/** Van-e már (bármilyen alakban) születési dátum a profilban? */
function hasBirthDate(profile) {
  const value = profile?.birthDate;
  if (value instanceof Date) return !Number.isNaN(value.getTime());
  return String(value ?? '').trim().length > 0;
}

/** Kaphat-e emlékeztetőt ez a profil? (dátum nélküli tagok) */
function needsBirthDateNotice(profile) {
  return !hasBirthDate(profile);
}

/** Az értesítés determinisztikus kulcsa — ebből lesz a dokumentum-azonosító. */
function noticeDedupeKey(uid) {
  return `${NOTICE_TYPE}:${String(uid || '').trim()}`;
}

/**
 * Az értesítés mezői — **egy helyen**, hogy a hívó ne tudja elrontani.
 *
 * ⚠️ A `targetType` szándékosan `'birth_date'` (nem `'profile'`): a felület
 * `birth_date` ága (`lib/core/navigation/content_target.dart`) a **dátum
 * beállítására** visz, a `profile` viszont a nyilvános profilra — ott nincs
 * szerkesztés, ezért a koppintás zsákutca lenne.
 */
function noticePayload(uid) {
  const target = String(uid || '').trim();
  return {
    type: NOTICE_TYPE,
    kind: NOTICE_TYPE,
    targetType: 'birth_date',
    targetId: target,
    dedupeKey: noticeDedupeKey(target),
  };
}

/** Érvényes-e a cím (a `sendMail` ugyanezt a mintát kéri). */
function isValidEmail(value) {
  return /^\S+@\S+\.\S+$/.test(String(value ?? '').trim());
}

/**
 * A kör célpontjai.
 *
 * @param {Array<{uid: string, profile: object}>} entries a `community_profiles` sorai
 * @param {{emailLimit?: number}} [options]
 * @returns {{targets: Array<{uid: string, email: string, language: string, sendEmail: boolean}>, skipped: number, emailCount: number}}
 */
function selectBirthDateNoticeTargets(entries, { emailLimit = DEFAULT_EMAIL_LIMIT } = {}) {
  const limit = Math.max(
    0,
    Math.min(MAX_EMAIL_LIMIT, Number.isFinite(Number(emailLimit)) ? Number(emailLimit) : DEFAULT_EMAIL_LIMIT),
  );
  const targets = [];
  let skipped = 0;
  let emailBudget = limit;
  for (const entry of Array.isArray(entries) ? entries : []) {
    const uid = String(entry?.uid || '').trim();
    const profile = entry?.profile || {};
    if (!uid || !needsBirthDateNotice(profile)) {
      skipped += 1;
      continue;
    }
    const email = String(profile.email || '').trim();
    const alreadyEmailed = Boolean(profile[EMAIL_FIELD]);
    const sendEmail = isValidEmail(email) && !alreadyEmailed && emailBudget > 0;
    if (sendEmail) emailBudget -= 1;
    targets.push({ uid, email, language: normalizeLanguage(profile.language), sendEmail });
  }
  return {
    targets,
    skipped,
    emailCount: targets.filter((target) => target.sendEmail).length,
  };
}

module.exports = {
  NOTICE_TYPE,
  NOTICE_FIELD,
  EMAIL_FIELD,
  DEFAULT_EMAIL_LIMIT,
  MAX_EMAIL_LIMIT,
  normalizeLanguage,
  hasBirthDate,
  needsBirthDateNotice,
  noticeDedupeKey,
  noticePayload,
  isValidEmail,
  selectBirthDateNoticeTargets,
};
