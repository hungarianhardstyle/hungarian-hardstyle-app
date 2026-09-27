/**
 * **Gyermekbiztonsági jelzőrendszer (1. fázis)** — a döntés mérése.
 *
 * A tulajdonos döntése (2026-09-27): *„indulhat az első fázis + olyan is kéne ha
 * egy gyerekre írnak rá alapból figyelmeztesse a rendszer, hogy akivel beszél
 * öregebb + terjesszük ki angolra is és legyen 16+ a regelés korhatár"*.
 *
 * Ez a teszt a tiszta döntést méri (`functions/child-safety-plan.js`) — Firestore
 * és hálózat nélkül —, a végén pedig forrás-linttel azt, hogy a szerver
 * (`functions/index.js`) a tervet használja: a privát üzenet útvonalán fut, a
 * jelzést **két** helyre írja (`moderation_flags` + a meglévő admin-lista
 * `chat_reports` sora), **nem** tilt és **nem** töröl automatikusan, az
 * értesítés pedig a **rendszer** jelzésére saját szöveget használ.
 *
 * Futtatás: node --test functions/child-safety-plan.test.cjs
 */

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const {
  MINOR_AGE,
  MINIMUM_SCORE,
  MINIMUM_REGISTRATION_AGE,
  AGE_GAP_THRESHOLD,
  FLAG_COLLECTION,
  MAX_EXCERPT_LENGTH,
  HIGH_RISK_CODES,
  SIGNAL_CODES,
  SIGNAL_LABELS,
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
  notificationKind,
  planChildSafetyFlag,
} = require('./child-safety-plan');
const { TEXTS, notificationText } = require('./notification-texts');

const source = fs.readFileSync(path.join(__dirname, 'index.js'), 'utf8');
const rulesSource = fs.readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8');

/** A modul forrása (a „nem tilt / nem töröl" linthez). */
const planSource = fs.readFileSync(path.join(__dirname, 'child-safety-plan.js'), 'utf8');

const NOW = new Date(Date.UTC(2026, 8, 27)); // 2026-09-27

test('a korhatárok rögzítve vannak (16+ regisztráció, 18 alatt kiskorú)', () => {
  assert.equal(MINIMUM_REGISTRATION_AGE, 16);
  assert.equal(MINOR_AGE, 18);
  assert.equal(AGE_GAP_THRESHOLD, 5);
  assert.equal(FLAG_COLLECTION, 'moderation_flags');
});

test('a két életkor-számítás UGYANAZT adja (nincs széttartó szabály)', () => {
  // ⚠️ Két modulban él életkor-számítás: a jelzőben (`child-safety-plan.js`) és a
  // nyilvános vetítésben (`birth-date-plan.js`). Ha a kettő széttartana, a
  // jelzés és a figyelmeztető sáv MÁS korhoz szólna — ezért itt
  // **összemérjük** őket a határeseteken (születésnap előtt/után, szökőév,
  // jövőbeli és hibás dátum).
  const reference = require('./birth-date-plan');
  const cases = [
    '1985-01-01',
    '2010-09-27',
    '2010-09-28',
    '2012-02-29',
    '2011-02-29',
    '1900-01-01',
    '1899-12-31',
    '0202-01-01',
    '2030-01-01',
    '2010-13-01',
    '',
  ];
  for (const value of cases) {
    const mine = ageInYears(value, NOW);
    const theirs = reference.ageInYears(value, NOW);
    // A két modul szándékosan ugyanazt a szabályt használja (1900 utáni,
    // nem jövőbeli dátum; a kor nem negatív).
    assert.equal(mine, theirs, `életkor: ${value}`);
    assert.equal(
      reference.isValidBirthDate(value, NOW),
      mine !== null,
      `érvényesség: ${value}`,
    );
  }
  assert.equal(reference.MINIMUM_AGE, MINIMUM_REGISTRATION_AGE);
  assert.equal(reference.ADULT_AGE, MINOR_AGE);
});

test('a születési dátum beolvasása valós dátumot kér', () => {
  assert.deepEqual(parseBirthDate('2010-05-01'), { year: 2010, month: 5, day: 1 });
  assert.deepEqual(parseBirthDate(new Date(Date.UTC(2010, 4, 1))), { year: 2010, month: 5, day: 1 });
  assert.equal(parseBirthDate('2010-02-30'), null, 'nincs február 30.');
  assert.equal(parseBirthDate('2011-02-29'), null, '2011 nem szökőév');
  assert.equal(parseBirthDate('2012-02-29')?.day, 29, '2012 szökőév');
  assert.equal(parseBirthDate('2010-13-01'), null);
  assert.equal(parseBirthDate('2010-1-1'), null, 'a forma ÉÉÉÉ-HH-NN');
  assert.equal(parseBirthDate(''), null);
  assert.equal(parseBirthDate(null), null);
  assert.equal(parseBirthDate(new Date('invalid')), null);
});

test('az életkor a születésnap előtt/után pontosan számol', () => {
  assert.equal(ageInYears('2010-09-28', NOW), 15, 'a születésnap előtti nap még 15');
  assert.equal(ageInYears('2010-09-27', NOW), 16, 'a születésnap napján már 16');
  assert.equal(ageInYears('1985-01-01', NOW), 41);
  assert.equal(ageInYears('', NOW), null);
  assert.equal(ageInYears('2010-05-01', new Date('invalid')), null);
});

test('a korkülönbség súlya csak kiskorú ↔ nagykorú között számít', () => {
  assert.equal(ageGapWeight(25, true, false), 5);
  assert.equal(ageGapWeight(12, true, false), 4);
  assert.equal(ageGapWeight(6, true, false), 2);
  assert.equal(ageGapWeight(2, true, false), 0, 'kis különbség nem jel');
  assert.equal(ageGapWeight(20, true, true), 0, 'két kiskorú nem kap súlyt');
  assert.equal(ageGapWeight(20, false, false), 0, 'két felnőtt nem kap súlyt');
  assert.equal(ageGapWeight(null, true, false), 0);
});

test('a jelek magyarul ÉS angolul is találnak (ékezet nélkül is)', () => {
  assert.deepEqual(detectSignals('Hány éves vagy?'), ['age_probe']);
  assert.deepEqual(detectSignals('hany eves vagy'), ['age_probe'], 'ékezet nélkül is');
  assert.deepEqual(detectSignals('How old are you?'), ['age_probe']);
  assert.deepEqual(detectSignals('Ezt senkinek ne mondd el!'), ['secrecy_request']);
  assert.deepEqual(detectSignals("Don't tell anyone, this is our secret"), ['secrecy_request']);
  assert.deepEqual(detectSignals('Találkozzunk holnap!'), ['meeting_request']);
  assert.deepEqual(detectSignals('come alone to my place'), ['meeting_request']);
  assert.deepEqual(detectSignals('Küldj képet magadról!'), ['image_request']);
  assert.deepEqual(detectSignals('send nudes'), ['image_request']);
  assert.deepEqual(detectSignals('Hol laksz?'), ['address_probe']);
  assert.deepEqual(detectSignals('are you home alone?'), ['address_probe']);
  assert.deepEqual(detectSignals('Írj privátban!'), ['off_platform_contact']);
  assert.deepEqual(detectSignals('add me on snapchat'), ['off_platform_contact']);
  assert.deepEqual(detectSignals('Küldök neked pénzt.'), ['gift_or_money']);
  assert.deepEqual(detectSignals('A számom: +36 30 123 4567'), ['contact_share']);
  assert.deepEqual(detectSignals('Írj ide: teszt@example.com'), ['contact_share']);
  assert.deepEqual(detectSignals('az instám: @hardstyle_king'), ['off_platform_contact', 'contact_share']);
  assert.deepEqual(detectSignals('Szia, milyen volt a buli?'), [], 'ártalmatlan üzenet nem jel');
  assert.deepEqual(detectSignals(''), []);
});

test('minden egyes HU/EN minta ÖNMAGÁBAN is talál (nincs „másik minta fedi el")', () => {
  // ⚠️ MIÉRT KÜLÖN: az összetett mondatokban több minta is illeszkedhet, ezért
  // egy minta eltávolítása **észrevétlen** maradhat (a mutációs bizonyíték
  // pontosan ezt fogta meg: a `dont tell anyone` törlése nem bukott meg).
  // Itt minden minta **magában** szerepel, így a hiánya azonnal kiderül.
  const cases = [
    ['age_probe', 'hany eves vagy'],
    ['age_probe', 'How old are you?'],
    ['age_probe', 'when were you born'],
    ['age_probe', 'which grade are you in'],
    ['secrecy_request', 'dont tell anyone'],
    ['secrecy_request', 'Dont tell your parents about this'],
    ['secrecy_request', 'keep it between us'],
    ['secrecy_request', 'ne mondd el a szuleidnek'],
    ['secrecy_request', 'titok marad'],
    ['meeting_request', 'meet me'],
    ['meeting_request', 'come alone'],
    ['meeting_request', 'talalkozzunk'],
    ['image_request', 'send nudes'],
    ['image_request', 'kuldj kepet'],
    ['image_request', 'meztelen kep'],
    ['address_probe', 'where do you live'],
    ['address_probe', 'hol laksz'],
    ['address_probe', 'are you home alone'],
    ['off_platform_contact', 'add me on'],
    ['off_platform_contact', 'irj privatban'],
    ['off_platform_contact', 'telegram'],
    ['gift_or_money', 'send you money'],
    ['gift_or_money', 'kuldok neked penzt'],
    ['contact_share', 'a szamom: +36 30 123 4567'],
    ['contact_share', 'teszt@example.com'],
    ['contact_share', 'az instam @hardstyle_king'],
  ];
  for (const [code, text] of cases) {
    assert.ok(detectSignals(text).includes(code), `${code} — ${text}`);
  }
});

test('a jelek súlya és a magas kockázatúak listája rögzített', () => {
  assert.equal(signalWeight('secrecy_request'), 4);
  assert.equal(signalWeight('meeting_request'), 4);
  assert.equal(signalWeight('image_request'), 4);
  assert.equal(signalWeight('address_probe'), 3);
  assert.equal(signalWeight('age_probe'), 2);
  assert.equal(signalWeight('ismeretlen'), 0, 'ismeretlen kódra nem tippelünk');
  assert.deepEqual([...HIGH_RISK_CODES].sort(), [
    'address_probe',
    'image_request',
    'meeting_request',
    'secrecy_request',
  ]);
  for (const code of SIGNAL_CODES) {
    assert.ok(SIGNAL_LABELS[code]?.hu && SIGNAL_LABELS[code]?.en, `${code} kétnyelvű címkéje megvan`);
  }
});

test('a súlyosság a pontszámból, a minimum alatt nincs jelzés', () => {
  assert.equal(severityFor(0), null);
  assert.equal(severityFor(MINIMUM_SCORE - 1), null);
  assert.equal(severityFor(MINIMUM_SCORE), 'low');
  assert.equal(severityFor(5), 'medium');
  assert.equal(severityFor(8), 'high');
  assert.equal(severityFor(99), 'high');
});

test('ártalmatlan üzenet felnőttek között: nincs jelzés', () => {
  const plan = planChildSafetyFlag({
    message: { text: 'Szia, találkozunk a buliban!' },
    senderProfile: { birthDate: '1995-01-01' },
    recipientProfile: { birthDate: '1993-01-01' },
    now: NOW,
  });
  assert.equal(plan.shouldFlag, false);
  assert.equal(plan.severity, null);
  assert.equal(plan.score, 0);
});

test('két kiskorú között az életkor önmagában nem jel', () => {
  const plan = planChildSafetyFlag({
    message: { text: 'Szia!' },
    senderProfile: { birthDate: '2010-01-01' },
    recipientProfile: { birthDate: '2009-01-01' },
    now: NOW,
  });
  assert.equal(plan.senderIsMinor, true);
  assert.equal(plan.recipientIsMinor, true);
  assert.equal(plan.shouldFlag, false);
});

test('nagy korkülönbség kiskorúval: önmagában is jelez (közepes)', () => {
  const plan = planChildSafetyFlag({
    message: { text: 'Szia!' },
    senderProfile: { birthDate: '1985-01-01' },
    recipientProfile: { birthDate: '2010-05-01' },
    now: NOW,
  });
  assert.equal(plan.senderAge, 41);
  assert.equal(plan.recipientAge, 16);
  assert.equal(plan.ageGap, 25);
  assert.equal(plan.minorInvolved, true);
  assert.equal(plan.adultWritesToMinor, true);
  assert.equal(plan.severity, 'medium');
  assert.deepEqual(plan.reasonCodes, ['age_gap']);
});

test('egy gyenge jel önmagában nem elég (kevesebb a minimum pontnál)', () => {
  const plan = planChildSafetyFlag({
    message: { text: 'How old are you?' },
    senderProfile: {},
    recipientProfile: {},
    now: NOW,
  });
  assert.equal(plan.score, 2);
  assert.equal(plan.shouldFlag, false, 'az életkorra kérdezés magában nem jelzés');
  assert.deepEqual(plan.reasonCodes, ['age_probe']);
});

test('lakóhelyre kérdezés magában is jelez (alacsony)', () => {
  const plan = planChildSafetyFlag({
    message: { text: 'Hol laksz?' },
    senderProfile: {},
    recipientProfile: {},
    now: NOW,
  });
  assert.equal(plan.severity, 'low');
  assert.deepEqual(plan.reasonCodes, ['address_probe']);
});

test('magas kockázatú jel kiskorúnál: LEGALÁBB magas súlyosság', () => {
  const plan = planChildSafetyFlag({
    message: { text: 'Küldj képet!' },
    senderProfile: { birthDate: '2006-01-01' }, // 20 éves
    recipientProfile: { birthDate: '2010-01-01' }, // 16 éves
    now: NOW,
  });
  assert.equal(plan.score, 4, 'a korkülönbség itt 4 év, súly nélkül');
  assert.equal(plan.severity, 'high', 'kiskorú + magas kockázatú jel = magas');
  assert.equal(plan.minorInvolved, true);
});

test('titoktartás + nagy korkülönbség: magas súlyosság', () => {
  const plan = planChildSafetyFlag({
    message: { text: 'Ezt senkinek ne mondd el!' },
    senderProfile: { birthDate: '1980-01-01' },
    recipientProfile: { birthDate: '2010-01-01' },
    now: NOW,
  });
  assert.ok(plan.score >= 8, `pontszám: ${plan.score}`);
  assert.equal(plan.severity, 'high');
  assert.deepEqual(plan.reasonCodes, ['age_gap', 'secrecy_request']);
});

test('a részlet egysoros és legfeljebb 200 karakter', () => {
  const long = `${'a'.repeat(300)}\n\n  több   szóköz`;
  const plan = planChildSafetyFlag({
    message: { text: long },
    senderProfile: {},
    recipientProfile: {},
    now: NOW,
  });
  assert.equal(plan.excerpt.length, MAX_EXCERPT_LENGTH);
  assert.ok(plan.excerpt.endsWith('…'));
  assert.equal(excerptOf('  a\n b  '), 'a b');
  assert.equal(excerptOf(''), '');
});

test('a jelzés azonosítója determinisztikus (a trigger ismételhet)', () => {
  assert.equal(flagDocumentId('uid1_uid2', 'msg1'), 'uid1_uid2__msg1');
  assert.equal(flagDocumentId('uid1_uid2', 'msg1'), flagDocumentId('uid1_uid2', 'msg1'));
  assert.equal(flagDocumentId('', 'msg1'), '');
});

test('az értesítés típusa a súlyosságból, a jelek felsorolása kétnyelvű', () => {
  assert.equal(notificationKind('high'), 'child_safety_flag_high');
  assert.equal(notificationKind('medium'), 'child_safety_flag_medium');
  assert.equal(notificationKind('low'), 'child_safety_flag_low');
  assert.equal(notificationKind(''), 'child_safety_flag');
  assert.equal(notificationKind('ismeretlen'), 'child_safety_flag');
  assert.equal(reasonSummary(['age_gap', 'secrecy_request'], 'hu'), 'nagy korkülönbség, titoktartást kér');
  assert.equal(reasonSummary(['age_gap', 'secrecy_request'], 'en'), 'large age gap, asks for secrecy');
  assert.equal(reasonSummary(['age_gap'], 'EN'), 'large age gap', 'a nyelv kis/nagybetű nem számít');
  assert.equal(reasonSummary([], 'hu'), '');
  assert.equal(severityLabel('high', 'hu'), 'magas');
  assert.equal(severityLabel('high', 'en'), 'high');
  assert.equal(severityLabel('', 'hu'), '');
});

test('a katalógus mind a négy gyermekbiztonsági típust ismeri, két nyelven', () => {
  for (const kind of [
    'child_safety_flag',
    'child_safety_flag_high',
    'child_safety_flag_medium',
    'child_safety_flag_low',
  ]) {
    const entry = TEXTS[kind];
    assert.ok(entry, `${kind} a katalógusban`);
    for (const language of ['hu', 'en']) {
      assert.ok(entry[language].title.length > 0, `${kind} ${language} cím`);
      assert.ok(entry[language].body.includes('{reasons}'), `${kind} ${language} a jeleket is mutatja`);
    }
  }
  const text = notificationText('child_safety_flag_high', 'en', {
    name: 'Denoiser',
    reasons: 'large age gap, asks for secrecy',
  });
  assert.equal(text.title, 'Child safety alert (high)');
  assert.equal(text.body, 'Denoiser: large age gap, asks for secrecy');
});

test('a szerver a privát üzenet útvonalán futtatja a jelzőt', () => {
  assert.match(
    source,
    /require\('\.\/child-safety-plan'\)/,
    'a tiszta terv be van kötve',
  );
  const trigger = source.indexOf('exports.moderatePrivateMessage = onDocumentCreated(');
  assert.ok(trigger > 0, 'a trigger létezik');
  const block = source.slice(trigger, trigger + 400);
  assert.match(block, /document: 'private_conversations\/\{conversationId\}\/messages\/\{messageId\}'/);
  assert.match(block, /handlePrivateMessageModeration\(event\)/);
});

test('a jelzés KÉT helyre íródik, és egyik sem tilt/töröl', () => {
  const start = source.indexOf('async function writeChildSafetyFlag(');
  assert.ok(start > 0, 'a jelzés-író megvan');
  const block = source.slice(start, source.indexOf('exports.moderatePrivateMessage', start));
  assert.match(block, /\.collection\(CHILD_SAFETY_FLAG_COLLECTION\)/, 'strukturált rekord');
  assert.match(block, /\.collection\('chat_reports'\)/, 'a meglévő admin-lista sora');
  assert.equal(block.split('.create(').length - 1, 2, 'mindkettő create() — az ismétlés nem duplikál');
  assert.doesNotMatch(block, /community_bans/, 'a jelzés NEM tilt');
  assert.doesNotMatch(block, /\.delete\(/, 'a jelzés NEM töröl');
  assert.match(block, /systemFlag: true/, 'a sor rendszer-jelzésként megy ki');
  assert.match(block, /reasonCodes: flag\.reasonCodes \|\| \[\]/, 'a jelek kódként, nem kész mondatként');
  // A döntés maga sem tartalmaz tiltó/törlő utat.
  assert.doesNotMatch(planSource, /community_bans|deleteProfile|\.delete\(/);
});

test('a jelző is védett a dupla kiküldés ellen (a trigger ismételhet)', () => {
  const start = source.indexOf('async function handlePrivateMessageModeration(');
  assert.ok(start > 0, 'a jelző-ág megvan');
  const block = source.slice(start, source.indexOf('async function writeChildSafetyFlag(', start));
  // A `writeFlag` `false`-t ad, ha a jelzés MÁR megvan (újrakézbesítés) — ilyenkor
  // nem szabad sem naplózni, sem értesíteni.
  const createdGate = block.indexOf('if (!created) return null;');
  const log = block.indexOf("event: 'child_safety_flag'");
  assert.ok(createdGate > 0 && log > createdGate, 'a kapu megelőzi a naplózást');
  assert.match(
    block,
    /[Ff]lagDocumentId\(conversationId, messageId\)/,
    'a jelzés azonosítója a beszélgetésből és az üzenetből készül',
  );
});

test('a rendszer jelzése saját értesítés-szöveget kap, nyelvenként', () => {
  const start = source.indexOf('async function handleChatReportNotification(');
  const block = source.slice(start, source.indexOf('exports.notifyChatReport', start));
  assert.match(block, /const systemFlag = report\.systemFlag === true;/);
  assert.match(block, /childSafetyNotificationKind\(report\.severity\)/);
  assert.match(block, /childSafetyReasonSummary\(report\.reasonCodes, language\)/);
  assert.match(block, /systemFlag \? paramsByLanguage\.get\(language\) \|\| reportParams : reportParams/);
});

test('a moderation_flags gyűjteményt csak moderátor olvashatja, írni senki', () => {
  const start = rulesSource.indexOf('match /moderation_flags/{flagId}');
  assert.ok(start > 0, 'a szabály megvan');
  const block = rulesSource.slice(start, start + 400);
  assert.match(block, /allow read: if isModerator\(\)/);
  assert.match(block, /allow write: if false/);
});
