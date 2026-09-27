/**
 * **Születésnapi köszöntés** — a döntés mérése.
 *
 * A tulajdonos kérése (2026-09-27): *„akinek születésnapja van, az adott napon
 * kapjon egy Boldog szülinapos Notifyt, szépen megfogalmazva"*.
 *
 * Ez a teszt a tiszta döntést méri (`functions/birthday-plan.js`) — hálózat és
 * Firestore nélkül —, a végén forrás-linttel azt, hogy a szerver a tervet
 * használja: naponta **egyszer** futó kör, **évente egyszer** köszönt (a kulcs
 * évet is tartalmaz), és a szöveg a nyelvi katalógusból jön.
 *
 * Futtatás: node --test functions/birthday-plan.test.cjs
 */

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const {
  BIRTHDAY_TYPE,
  DEFAULT_TIME_ZONE,
  parseBirthDate,
  localDateIn,
  isLeapYear,
  birthdayMatches,
  birthdayKey,
  birthdayGreeting,
  normalizeLanguage,
  birthdayTargets,
} = require('./birthday-plan');
const { TEXTS, notificationText } = require('./notification-texts');

const source = fs.readFileSync(path.join(__dirname, 'index.js'), 'utf8');

/** Egy időpont a budapesti időzónában (nyár: UTC+2, tél: UTC+1). */
const at = (iso) => new Date(iso);

test('a típus és az időzóna rögzített', () => {
  assert.equal(BIRTHDAY_TYPE, 'birthday');
  assert.equal(DEFAULT_TIME_ZONE, 'Europe/Budapest');
});

test('a születési dátum beolvasása valós dátumot kér', () => {
  assert.deepEqual(parseBirthDate('1990-05-01'), { year: 1990, month: 5, day: 1 });
  assert.equal(parseBirthDate('1990-02-30'), null);
  assert.equal(parseBirthDate('1991-02-29'), null, '1991 nem szökőév');
  assert.equal(parseBirthDate('1992-02-29')?.day, 29);
  assert.equal(parseBirthDate('1990-13-01'), null);
  assert.equal(parseBirthDate(''), null);
  assert.equal(parseBirthDate(null), null);
});

test('a „ma" nap az IDŐZÓNÁBAN számolódik (nem UTC-ben)', () => {
  // Nyáron Budapest = UTC+2: 22:30 UTC-kor már MÁSNAP van Budapesten.
  assert.deepEqual(localDateIn('Europe/Budapest', at('2026-07-14T22:30:00Z')), {
    year: 2026,
    month: 7,
    day: 15,
  });
  // Télen Budapest = UTC+1.
  assert.deepEqual(localDateIn('Europe/Budapest', at('2026-01-14T23:30:00Z')), {
    year: 2026,
    month: 1,
    day: 15,
  });
  // UTC-ben ugyanez még a 14-e — ezért nem szabad UTC-t használni.
  assert.deepEqual(localDateIn('UTC', at('2026-07-14T22:30:00Z')), {
    year: 2026,
    month: 7,
    day: 14,
  });
});

test('a születésnap egyezése (hónap + nap)', () => {
  const today = { year: 2026, month: 9, day: 27 };
  assert.equal(birthdayMatches('1990-09-27', today), true);
  assert.equal(birthdayMatches('1990-09-26', today), false);
  assert.equal(birthdayMatches('1990-10-27', today), false);
  assert.equal(birthdayMatches('', today), false);
  assert.equal(birthdayMatches('1990-09-27', null), false);
});

test('a szökőnapi születésnap nem szökőévben február 28-án köszönt', () => {
  assert.equal(isLeapYear(2024), true);
  assert.equal(isLeapYear(2026), false);
  assert.equal(isLeapYear(2000), true, '400-zal osztható');
  assert.equal(isLeapYear(1900), false, '100-zal osztható, de 400-zal nem');
  // Szökőévben a valódi napon:
  assert.equal(birthdayMatches('1992-02-29', { year: 2028, month: 2, day: 29 }), true);
  // Nem szökőévben február 28-án:
  assert.equal(birthdayMatches('1992-02-29', { year: 2026, month: 2, day: 28 }), true);
  assert.equal(birthdayMatches('1992-02-29', { year: 2026, month: 3, day: 1 }), false);
  // Mást nem érint:
  assert.equal(birthdayMatches('1992-02-28', { year: 2026, month: 2, day: 28 }), true);
});

test('a köszöntés kulcsa évet is tartalmaz (évente egyszer futhat)', () => {
  assert.equal(birthdayKey('abc', 2026), 'birthday:abc:2026');
  assert.equal(birthdayKey('abc', 2026), birthdayKey('abc', 2026));
  assert.notEqual(birthdayKey('abc', 2026), birthdayKey('abc', 2027), 'jövőre újra köszönt');
  assert.equal(birthdayKey('', 2026), '');
});

test('a megszólítás nyelvenként helyes, név nélkül üres', () => {
  assert.equal(birthdayGreeting('Anna', 'hu'), 'Kedves Anna! ');
  assert.equal(birthdayGreeting('Anna', 'en'), 'Dear Anna! ');
  assert.equal(birthdayGreeting('Anna', 'de'), 'Kedves Anna! ', 'ismeretlen nyelv = magyar');
  assert.equal(birthdayGreeting('', 'hu'), '', 'név nélkül nincs lógó megszólítás');
  assert.equal(birthdayGreeting('   ', 'en'), '');
  assert.equal(normalizeLanguage('en-US'), 'en');
  assert.equal(normalizeLanguage(null), 'hu');
});

test('a célpontok: csak a mai születésnaposok, nyelvenként', () => {
  const { targets, today } = birthdayTargets(
    [
      { uid: 'a', profile: { birthDate: '1990-09-27', displayName: 'Anna', language: 'hu' } },
      { uid: 'b', profile: { birthDate: '1985-09-27', displayName: 'Bob', language: 'en' } },
      { uid: 'c', profile: { birthDate: '1990-09-26', displayName: 'Cili' } },
      { uid: 'd', profile: { displayName: 'Dénes' } },
      { uid: '', profile: { birthDate: '1990-09-27' } },
    ],
    { now: at('2026-09-27T09:00:00Z') },
  );
  assert.deepEqual(today, { year: 2026, month: 9, day: 27 });
  assert.deepEqual(
    targets.map((target) => target.uid),
    ['a', 'b'],
  );
  assert.deepEqual(targets[0], { uid: 'a', name: 'Anna', language: 'hu' });
  assert.deepEqual(targets[1], { uid: 'b', name: 'Bob', language: 'en' });
});

test('a magyar időzóna dönt a napról (a szerver UTC-ben fut)', () => {
  // 2026-09-27 22:30 UTC = 2026-09-28 00:30 Budapest → a 28-ai születésnapos kap.
  const { targets, today } = birthdayTargets(
    [
      { uid: 'a', profile: { birthDate: '1990-09-27' } },
      { uid: 'b', profile: { birthDate: '1990-09-28' } },
    ],
    { now: at('2026-09-27T22:30:00Z') },
  );
  assert.deepEqual(today, { year: 2026, month: 9, day: 28 });
  assert.deepEqual(targets.map((target) => target.uid), ['b']);
});

test('a katalógus ismeri a köszöntést, két nyelven', () => {
  const entry = TEXTS.birthday;
  assert.ok(entry, 'a `birthday` típus a katalógusban');
  for (const language of ['hu', 'en']) {
    assert.ok(entry[language].title.length > 0, `${language} cím`);
    assert.ok(entry[language].body.includes('{greeting}'), `${language} a megszólítást is viszi`);
  }
  const hu = notificationText('birthday', 'hu', { greeting: 'Kedves Anna! ' });
  assert.equal(hu.title, 'Boldog születésnapot! 🎂');
  assert.match(hu.body, /^Kedves Anna! A Hungarian Hardstyle csapata/);
  const en = notificationText('birthday', 'en', { greeting: 'Dear Anna! ' });
  assert.equal(en.title, 'Happy birthday! 🎂');
  assert.match(en.body, /^Dear Anna! The Hungarian Hardstyle team/);
  // Név nélkül is olvasható (nincs lógó megszólítás):
  const anonymous = notificationText('birthday', 'hu', { greeting: '' });
  assert.match(anonymous.body, /^A Hungarian Hardstyle csapata/);
});

test('a szerver naponta futtatja a kört, és a tervet használja', () => {
  const trigger = source.indexOf('exports.sendBirthdayGreetings = onSchedule(');
  assert.ok(trigger > 0, 'az ütemezett kör létezik');
  const block = source.slice(trigger, source.indexOf('exports.__birthdayForTests', trigger));
  assert.match(block, /schedule: 'every day 09:00'/);
  assert.match(block, /timeZone: BIRTHDAY_TIME_ZONE/);
  assert.match(source, /require\('\.\/birthday-plan'\)/);
});

test('a köszöntés évente EGYSZER megy ki (a kulcs a napot is tartalmazza)', () => {
  const start = source.indexOf('async function sendBirthdayGreetings(');
  assert.ok(start > 0, 'a küldő mag létezik');
  const block = source.slice(start, source.indexOf('exports.sendBirthdayGreetings = onSchedule(', start));
  assert.match(block, /birthdayKey\(target\.uid, today\?\.year\)/, 'a kulcs évet tartalmaz');
  assert.match(block, /const created = await createNotificationBestEffort\(/);
  assert.match(block, /if \(!created\) continue;/, 'ismételt kör nem küld újra');
  // A push a `created` kapu mögött van:
  const gate = block.indexOf('if (!created) continue;');
  const push = block.indexOf('await sendPush(');
  assert.ok(gate > 0 && push > gate, 'a push csak új köszöntésnél megy ki');
  // Életkor NEM kerül a szövegbe (adatvédelem): a köszöntés csak a
  // megszólítást viszi, és a kör nem is számol életkort.
  assert.match(block, /params: \{ greeting: birthdayGreeting\(target\.name, target\.language\) \}/);
  assert.doesNotMatch(block, /ageInYears|isAdult|isMinor|éves/);
});
