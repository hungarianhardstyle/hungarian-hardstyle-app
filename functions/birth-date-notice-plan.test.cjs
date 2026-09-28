/**
 * **Születési dátum emlékeztető a meglévő tagoknak** — a döntés és a kapu mérése.
 *
 * A tulajdonos kérése (2026-09-27): *„menjen ki notifybe mér kötelező a
 * születési dátum, mehet nekik mail is"* — *„a meglévő tagoknak úgyértem"* —, a
 * sorrend viszont kötött: *„természetesen majd akkor ha éles az új build"* és
 * *„majd szólok ha ez kiment élesbe"*.
 *
 * Ez a teszt hármat mér: (1) a tiszta döntést (`birth-date-notice-plan.js`),
 * (2) a levél szövegét (`email_service.js`), (3) forrás-linttel azt, hogy a
 * szerveroldali kiküldő **alvó állapotban** kerül élesre (a kapcsoló zárja), és
 * hogy a dupla kiküldés elleni védelem a helyén van.
 *
 * Futtatás: node --test functions/birth-date-notice-plan.test.cjs
 */

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const {
  NOTICE_TYPE,
  NOTICE_FIELD,
  EMAIL_FIELD,
  EMAIL_ROUND_FIELD,
  DEFAULT_EMAIL_LIMIT,
  MAX_EMAIL_LIMIT,
  normalizeLanguage,
  normalizeRound,
  hasBirthDate,
  needsBirthDateNotice,
  noticeDedupeKey,
  noticeRoundOf,
  noticePayload,
  isValidEmail,
  selectBirthDateNoticeTargets,
} = require('./birth-date-notice-plan');
const { TEXTS, notificationText } = require('./notification-texts');
const { birthDateRequiredEmailTemplate } = require('./email_service');

const source = fs.readFileSync(path.join(__dirname, 'index.js'), 'utf8');
const planSource = fs.readFileSync(path.join(__dirname, 'birth-date-notice-plan.js'), 'utf8');
const toolPath = path.join(__dirname, '..', 'tools', 'birth-date-notice-flag.mjs');
const toolSource = fs.readFileSync(toolPath, 'utf8');

test('a dátum megléte minden alakban felismerhető', () => {
  assert.equal(hasBirthDate({ birthDate: '2010-05-01' }), true);
  assert.equal(hasBirthDate({ birthDate: new Date(Date.UTC(2010, 4, 1)) }), true);
  assert.equal(hasBirthDate({ birthDate: '' }), false);
  assert.equal(hasBirthDate({ birthDate: '   ' }), false);
  assert.equal(hasBirthDate({ birthDate: null }), false);
  assert.equal(hasBirthDate({}), false);
  assert.equal(hasBirthDate(null), false);
  assert.equal(needsBirthDateNotice({}), true);
  assert.equal(needsBirthDateNotice({ birthDate: '2010-05-01' }), false);
});

test('az értesítés kulcsa determinisztikus, a cél a profil', () => {
  assert.equal(NOTICE_TYPE, 'birth_date_required');
  assert.equal(noticeDedupeKey('abc'), 'birth_date_required:abc');
  assert.equal(noticeDedupeKey('abc'), noticeDedupeKey('abc'), 'a kör ismételhető');
  const payload = noticePayload('abc');
  assert.equal(payload.type, 'birth_date_required');
  assert.equal(payload.kind, 'birth_date_required');
  assert.equal(payload.targetType, 'birth_date', 'a dátum beállításához visz, nem a nyilvános profilra');
  assert.equal(payload.targetId, 'abc');
  assert.equal(payload.dedupeKey, 'birth_date_required:abc');
});

test('a nyelv normalizálása: minden ismeretlen érték magyar', () => {
  assert.equal(normalizeLanguage('en'), 'en');
  assert.equal(normalizeLanguage('en-US'), 'en');
  assert.equal(normalizeLanguage('EN_us'), 'en');
  assert.equal(normalizeLanguage('hu'), 'hu');
  assert.equal(normalizeLanguage('de'), 'hu');
  assert.equal(normalizeLanguage(null), 'hu');
});

test('a cím-ellenőrzés ugyanaz, amit a küldő is kér', () => {
  assert.equal(isValidEmail('teszt@example.com'), true);
  assert.equal(isValidEmail('  teszt@example.com  '), true);
  assert.equal(isValidEmail('teszt'), false);
  assert.equal(isValidEmail('teszt@example'), false);
  assert.equal(isValidEmail(''), false);
});

test('a célpontok: dátum nélküliek, nyelvenként, e-mail kerettel', () => {
  const { targets, skipped, emailCount } = selectBirthDateNoticeTargets(
    [
      { uid: 'a', profile: { birthDate: '2010-05-01', email: 'a@example.com' } },
      { uid: 'b', profile: { language: 'en', email: 'b@example.com' } },
      { uid: 'c', profile: { language: 'de' } },
      { uid: 'd', profile: { email: 'd@example.com', [EMAIL_FIELD]: new Date() } },
      { uid: '', profile: {} },
    ],
    { emailLimit: 5 },
  );
  assert.deepEqual(
    targets.map((target) => target.uid),
    ['b', 'c', 'd'],
    'csak a dátum nélküliek',
  );
  assert.equal(skipped, 2, 'a dátummal rendelkező és az azonosító nélküli kimarad');
  assert.deepEqual(targets[0], { uid: 'b', email: 'b@example.com', language: 'en', sendEmail: true });
  assert.deepEqual(targets[1], { uid: 'c', email: '', language: 'hu', sendEmail: false }, 'cím nélkül nincs levél');
  assert.deepEqual(
    targets[2],
    { uid: 'd', email: 'd@example.com', language: 'hu', sendEmail: false },
    'akit már értesítettünk e-mailben, nem kap másodikat',
  );
  assert.equal(emailCount, 1);
});

test('az e-mail keret felső korlátja érvényes (SMTP-kímélés)', () => {
  const entries = Array.from({ length: 5 }, (_, index) => ({
    uid: `u${index}`,
    profile: { email: `u${index}@example.com` },
  }));
  const limited = selectBirthDateNoticeTargets(entries, { emailLimit: 2 });
  assert.equal(limited.emailCount, 2);
  assert.equal(limited.targets.length, 5, 'az értesítés mindenkinek megy');
  assert.equal(limited.targets.filter((target) => target.sendEmail).length, 2);
  const none = selectBirthDateNoticeTargets(entries, { emailLimit: 0 });
  assert.equal(none.emailCount, 0);
  const capped = selectBirthDateNoticeTargets(
    Array.from({ length: MAX_EMAIL_LIMIT + 50 }, (_, index) => ({
      uid: `x${index}`,
      profile: { email: `x${index}@example.com` },
    })),
    { emailLimit: 10_000 },
  );
  assert.equal(capped.emailCount, MAX_EMAIL_LIMIT, 'a plafon véd');
  assert.ok(DEFAULT_EMAIL_LIMIT > 0 && DEFAULT_EMAIL_LIMIT <= MAX_EMAIL_LIMIT);
  assert.deepEqual(selectBirthDateNoticeTargets(null).targets, [], 'hálózat nélkül üres');
});

test('a levél megmondja a PONTOS helyet, és nem kér jelszót', () => {
  const hu = birthDateRequiredEmailTemplate('hu');
  assert.match(hu.subject, /^Hungarian Hardstyle – /);
  assert.match(hu.text, /Profil szerkesztése/);
  assert.match(hu.text, /Chat fül/);
  assert.match(hu.text, /16 éves kortól/);
  assert.ok(!/jelsz/i.test(hu.text), 'a levél nem kér jelszót');
  assert.ok(!/jelsz/i.test(hu.html));
  const en = birthDateRequiredEmailTemplate('en');
  assert.match(en.subject, /^Hungarian Hardstyle – /);
  assert.match(en.text, /Edit profile/);
  assert.match(en.text, /age of 16/);
  assert.match(en.html, /Edit profile/);
  // Ismeretlen nyelvre magyar (mint a többi szerver-úton).
  assert.equal(birthDateRequiredEmailTemplate('de').subject, hu.subject);
  assert.equal(birthDateRequiredEmailTemplate(undefined).subject, hu.subject);
});

test('az értesítés-szöveg a katalógusból, két nyelven', () => {
  const kind = TEXTS.birth_date_required;
  assert.ok(kind, 'a katalógus ismeri a típust');
  for (const language of ['hu', 'en']) {
    assert.ok(kind[language].title.length > 0, `${language} cím`);
    assert.ok(kind[language].body.includes('Profil szerkesztése') || kind[language].body.includes('Edit profile'));
  }
  const hu = notificationText('birth_date_required', 'hu', {});
  const en = notificationText('birth_date_required', 'en', {});
  assert.notEqual(hu.title, en.title);
  assert.match(hu.body, /Profil szerkesztése/);
  assert.match(en.body, /Edit profile/);
});

test('a kiküldő ALVÓ állapotban kerül élesre: a kapcsoló zárja', () => {
  const trigger = source.indexOf('exports.sendBirthDateNotices = onSchedule(');
  assert.ok(trigger > 0, 'az ütemezett kiküldő létezik');
  const block = source.slice(trigger, source.indexOf('exports.__birthDateNoticeForTests', trigger));
  assert.match(block, /schedule: 'every day 18:00'/);
  assert.match(block, /secrets: SMTP_SECRETS/, 'a levélhez kell az SMTP-titok');
  assert.match(block, /settings\.enabled !== true/, 'a kapcsoló a küldés előtt');
  const gate = block.indexOf('settings.enabled !== true');
  const send = block.indexOf('await sendBirthDateNotices(');
  assert.ok(gate > 0 && send > gate, 'a kapu MEGELŐZI a küldést');
  assert.match(source, /app_settings\/birth_date_notice/, 'a kapcsoló dokumentuma');
});

test('a dupla kiküldés elleni védelem a helyén van', () => {
  const start = source.indexOf('async function sendBirthDateNotices(');
  assert.ok(start > 0, 'a mag létezik');
  const block = source.slice(start, source.indexOf('const BIRTH_DATE_NOTICE_SETTINGS_DOC', start));
  assert.match(block, /birthDateNoticePayload\(target\.uid, noticeRound\)/, 'determinisztikus értesítés-kulcs');
  assert.match(block, /const created = await createNotificationBestEffort\(/);
  // A push CSAK akkor megy, ha az értesítés most jött létre.
  const pushIndex = block.indexOf('await sendPush(');
  const createdGate = block.indexOf('if (created) {');
  assert.ok(createdGate > 0 && pushIndex > createdGate, 'a push a `created` kapu mögött van');
  // Az e-mail jelölése CSAK sikeres küldés után történik.
  const sendEmailIndex = block.indexOf('await sendEmail(');
  const markIndex = block.indexOf('[BIRTH_DATE_NOTICE_EMAIL_FIELD]');
  assert.ok(sendEmailIndex > 0 && markIndex > sendEmailIndex, 'a jelölés a sikeres küldés után');
  assert.match(block, /emailFailed \+= 1/, 'a hibás cím nem állítja meg a kört');
  assert.match(planSource, /EMAIL_FIELD = 'birthDateNoticeEmailSentAt'/);
  assert.match(planSource, /NOTICE_FIELD = 'birthDateNoticeSentAt'/);
  assert.equal(NOTICE_FIELD, 'birthDateNoticeSentAt');
  assert.equal(EMAIL_FIELD, 'birthDateNoticeEmailSentAt');
});

test('a kapcsolóhoz eszköz van, és írás csak --confirm-mal', () => {
  assert.match(toolSource, /--enable/);
  assert.match(toolSource, /--disable/);
  assert.match(toolSource, /--run-now/);
  assert.match(toolSource, /--confirm/);
  const writeIndex = toolSource.indexOf('await firestoreSet(SETTINGS_DOC');
  const confirmIndex = toolSource.indexOf('if (!confirmed && !dryRun)');
  assert.ok(confirmIndex > 0 && writeIndex > confirmIndex, 'a --confirm kapu megelőzi az írást');
  assert.match(toolSource, /firebase-schedule-sendBirthDateNotices-europe-central2/);
});

// --- ISMÉTELT KÖR (2. kör, 2026-09-28) -------------------------------------
//
// A tulajdonos kérése: *„menjen ki megint a születési dátum értesítés azoknak,
// akik még nem írták be"*. Az első kör szándékosan EGYSZER szól, ezért ismételt
// körben a kör-szám dönt: a kulcs `…:r2`, az e-mail kapuja pedig `emailRound`.

test('az ELSŐ kör kulcsa bájtazonos maradt (nincs dupla értesítés)', () => {
  assert.equal(noticeDedupeKey('abc123'), 'birth_date_required:abc123');
  assert.equal(noticeDedupeKey('abc123', 1), 'birth_date_required:abc123');
  assert.equal(noticeDedupeKey('abc123', 0), 'birth_date_required:abc123', 'a hibás kör = 1');
  assert.equal(noticeDedupeKey('abc123', 'x'), 'birth_date_required:abc123');
  assert.equal(noticePayload('abc123').dedupeKey, 'birth_date_required:abc123');
});

test('a MÁSODIK kör kulcsa külön dokumentum (ezért új értesítés és push)', () => {
  assert.equal(noticeDedupeKey('abc123', 2), 'birth_date_required:abc123:r2');
  assert.equal(noticeDedupeKey('abc123', 3), 'birth_date_required:abc123:r3');
  assert.notEqual(noticeDedupeKey('abc123', 2), noticeDedupeKey('abc123', 1));
  assert.equal(noticePayload('abc123', 2).dedupeKey, 'birth_date_required:abc123:r2');
  // A cél ugyanaz marad: a dátum beállítása (nem a nyilvános profil).
  assert.equal(noticePayload('abc123', 2).targetType, 'birth_date');
});

test('a kör-szám a profil jelöléséből olvasható (hiányzó mező = 1)', () => {
  assert.equal(noticeRoundOf({}), 0, 'aki sosem kapott e-mailt');
  assert.equal(noticeRoundOf({ [EMAIL_FIELD]: '2026-09-27' }), 1, 'a régi jelölés az 1. kör');
  assert.equal(noticeRoundOf({ [EMAIL_FIELD]: '2026-09-27', [EMAIL_ROUND_FIELD]: 2 }), 2);
  assert.equal(noticeRoundOf({ [EMAIL_FIELD]: '2026-09-27', [EMAIL_ROUND_FIELD]: '2' }), 2);
  assert.equal(noticeRoundOf({ [EMAIL_FIELD]: '2026-09-27', [EMAIL_ROUND_FIELD]: 0 }), 1, 'a 0 értelmetlen');
  assert.equal(normalizeRound(undefined), 1);
  assert.equal(normalizeRound('3'), 3);
  assert.equal(normalizeRound(-2), 1);
});

test('a 2. kör azokat szólítja meg, akik az 1.-ben kaptak, de még nincs dátumuk', () => {
  const entries = [
    // Az 1. körben kapott e-mailt, a dátumot azóta SEM adta meg -> ÚJRA szól.
    { uid: 'a', profile: { email: 'a@example.com', [EMAIL_FIELD]: '2026-09-27' } },
    // Az 1. körben kapott, és meg is adta a dátumot -> kimarad.
    { uid: 'b', profile: { email: 'b@example.com', birthDate: '2000-01-01', [EMAIL_FIELD]: '2026-09-27' } },
    // A 2. körben már kapott e-mailt -> nem kap harmadszor.
    { uid: 'c', profile: { email: 'c@example.com', [EMAIL_FIELD]: '2026-09-28', [EMAIL_ROUND_FIELD]: 2 } },
    // Sosem kapott -> most kap.
    { uid: 'd', profile: { email: 'd@example.com' } },
    // Nincs címe -> értesítést kap, e-mailt nem.
    { uid: 'e', profile: {} },
  ];
  const first = selectBirthDateNoticeTargets(entries, { round: 1, emailLimit: 10 });
  assert.deepEqual(
    first.targets.filter((target) => target.sendEmail).map((target) => target.uid),
    ['d'],
    'az 1. körben csak a d kap e-mailt (a és c már kapott, e-nek nincs címe)',
  );
  assert.equal(first.round, 1);

  const second = selectBirthDateNoticeTargets(entries, { round: 2, emailLimit: 10 });
  assert.deepEqual(second.targets.map((target) => target.uid), ['a', 'c', 'd', 'e'], 'mind a négy dátum nélküli célpont');
  assert.deepEqual(
    second.targets.filter((target) => target.sendEmail).map((target) => target.uid),
    ['a', 'd'],
    'a 2. körben az a is kap e-mailt (1. körből jelölt), a c nem (már a 2.-ban kapott)',
  );
  assert.equal(second.round, 2);
  assert.equal(second.skipped, 1, 'a b kimarad, mert már van dátuma');
});

test('a 2. kör e-mail kerete is érvényes (SMTP-kímélés)', () => {
  const entries = Array.from({ length: 6 }, (_, index) => ({
    uid: `u${index}`,
    profile: { email: `u${index}@example.com`, [EMAIL_FIELD]: '2026-09-27' },
  }));
  const limited = selectBirthDateNoticeTargets(entries, { round: 2, emailLimit: 2 });
  assert.equal(limited.emailCount, 2);
  assert.equal(limited.targets.length, 6, 'az értesítés mindenkinek megy, csak az e-mail korlátozott');
});

test('a kör a kapcsoló-dokumentumból jön, és a jelölés rögzíti', () => {
  assert.match(source, /round: normalizeBirthDateNoticeRound\(settings\.round\)/);
  assert.match(source, /\[BIRTH_DATE_NOTICE_EMAIL_ROUND_FIELD\]: noticeRound/);
  assert.match(planSource, /EMAIL_ROUND_FIELD = 'birthDateNoticeEmailRound'/);
  assert.equal(EMAIL_ROUND_FIELD, 'birthDateNoticeEmailRound');
  assert.match(toolSource, /--round=/, 'a kapcsoló-eszköz tudja állítani a kört');
});
