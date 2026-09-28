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
/**
 * Melyik **körben** ment ki az e-mail (2. kör, 2026-09-28).
 *
 * MIÉRT: a tulajdonos kérése *„menjen ki megint a születési dátum értesítés
 * azoknak, akik még nem írták be"* — az első kör viszont szándékosan **egyszer**
 * szól (determinisztikus kulcs + e-mail-jelölés), ezért ismételt körben **0**
 * embert érne el. A kör-szám ezért része a döntésnek: az értesítés kulcsa
 * körönként más (`…:r2`), az e-mail kapuja pedig `emailRound >= round`.
 * ⚠️ A **hiányzó** mező jelentése **1** (a régi jelölések az első körből valók),
 * így a régi viselkedés bájtra ugyanaz marad.
 */
const EMAIL_ROUND_FIELD = 'birthDateNoticeEmailRound';

/** Hányadik körben kapott már e-mailt ez a profil? (0 = soha) */
function noticeRoundOf(profile) {
  if (!profile?.[EMAIL_FIELD]) return 0;
  const value = Number(profile?.[EMAIL_ROUND_FIELD]);
  return Number.isFinite(value) && value >= 1 ? Math.floor(value) : 1;
}

/** A kör-szám normalizálása (hiányzó/hibás érték = 1). */
function normalizeRound(value) {
  const round = Number(value);
  return Number.isFinite(round) && round >= 1 ? Math.floor(round) : 1;
}

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

/**
 * Az értesítés determinisztikus kulcsa — ebből lesz a dokumentum-azonosító.
 *
 * ⚠️ Az **első kör** kulcsa VÁLTOZATLAN (`birth_date_required:{uid}`), különben
 * egy ismételt első kör **másodszor** szólna ugyanazoknak. A 2. körtől a kulcs
 * `…:r2`, ezért az új kör **új** értesítést hoz létre (és ezzel push-t is).
 */
function noticeDedupeKey(uid, round = 1) {
  const key = `${NOTICE_TYPE}:${String(uid || '').trim()}`;
  const normalized = normalizeRound(round);
  return normalized > 1 ? `${key}:r${normalized}` : key;
}

/**
 * Az értesítés mezői — **egy helyen**, hogy a hívó ne tudja elrontani.
 *
 * ⚠️ A `targetType` szándékosan `'birth_date'` (nem `'profile'`): a felület
 * `birth_date` ága (`lib/core/navigation/content_target.dart`) a **dátum
 * beállítására** visz, a `profile` viszont a nyilvános profilra — ott nincs
 * szerkesztés, ezért a koppintás zsákutca lenne.
 */
function noticePayload(uid, round = 1) {
  const target = String(uid || '').trim();
  return {
    type: NOTICE_TYPE,
    kind: NOTICE_TYPE,
    targetType: 'birth_date',
    targetId: target,
    dedupeKey: noticeDedupeKey(target, round),
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
 * @param {{emailLimit?: number, round?: number}} [options]
 *   `round` = hányadik kör (alap: 1). A 2. körben az kap e-mailt, aki az
 *   **elsőben** kapott (vagy sosem) — aki már a 2.-ban is, az nem.
 * @returns {{targets: Array<{uid: string, email: string, language: string, sendEmail: boolean}>, skipped: number, emailCount: number, round: number}}
 */
function selectBirthDateNoticeTargets(entries, { emailLimit = DEFAULT_EMAIL_LIMIT, round = 1 } = {}) {
  const limit = Math.max(
    0,
    Math.min(MAX_EMAIL_LIMIT, Number.isFinite(Number(emailLimit)) ? Number(emailLimit) : DEFAULT_EMAIL_LIMIT),
  );
  const noticeRound = normalizeRound(round);
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
    const alreadyEmailed = noticeRoundOf(profile) >= noticeRound;
    const sendEmail = isValidEmail(email) && !alreadyEmailed && emailBudget > 0;
    if (sendEmail) emailBudget -= 1;
    targets.push({ uid, email, language: normalizeLanguage(profile.language), sendEmail });
  }
  return {
    targets,
    skipped,
    emailCount: targets.filter((target) => target.sendEmail).length,
    round: noticeRound,
  };
}

module.exports = {
  NOTICE_TYPE,
  NOTICE_FIELD,
  EMAIL_FIELD,
  EMAIL_ROUND_FIELD,
  DEFAULT_EMAIL_LIMIT,
  MAX_EMAIL_LIMIT,
  normalizeLanguage,
  hasBirthDate,
  needsBirthDateNotice,
  noticeRoundOf,
  normalizeRound,
  noticeDedupeKey,
  noticePayload,
  isValidEmail,
  selectBirthDateNoticeTargets,
};
