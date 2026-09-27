/**
 * A születési dátum nyilvános vetítése és a kor-sáv — `birth-date-plan.js`.
 *
 * **A tulajdonos döntése (2026-09-27):** *„legyen 16+ a regelés korhatár"* és
 * *„ha egy gyerekre írnak rá, alapból figyelmeztesse a rendszer, hogy akivel
 * beszél, öregebb"*, valamint a dátum csak **engedélyezve** jelenjen meg a
 * nyilvános profilon.
 *
 * MIÉRT EZ A TESZT: a nyilvános profil a `public_profiles` dokumentumba kerül,
 * amit **bárki olvashat**. Egy véletlenül bekerülő `birthDate` adatszivárgás
 * lenne, a hiányzó `adult` jelző viszont a kiskorú-védelmet kapcsolná ki — a
 * kettő együtt mérhető itt, hálózat nélkül.
 *
 * ⚠️ A vetítés `merge: true`-val íródik, ezért a **visszavont** dátumot
 * törölni kell: ezt a `projectionDeletions()` méri.
 */

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const {
  CACHEABLE_OPTIONAL_FIELDS,
  MINIMUM_AGE,
  ADULT_AGE,
  ageInYears,
  isAtLeastAge,
  isValidBirthDate,
  projectionDeletions,
  publicAgeBand,
  publicBirthDate,
} = require('./birth-date-plan.js');

// Fix „most” a tesztekhez: 2026-09-27 (a kör dátuma).
const NOW = new Date(Date.UTC(2026, 8, 27, 12, 0, 0));

test('a korhatár a tulajdonos döntése szerint 16 év', () => {
  assert.equal(MINIMUM_AGE, 16);
  assert.equal(ADULT_AGE, 18);
});

test('az érvényes dátum ismert, a hibás alak és a jövőbeli dátum nem', () => {
  assert.equal(isValidBirthDate('1990-01-31', NOW), true);
  assert.equal(isValidBirthDate('2026-09-27', NOW), true, 'a mai nap még érvényes');
  assert.equal(isValidBirthDate('2026-09-28', NOW), false, 'a jövőbeli dátum nem');
  assert.equal(isValidBirthDate('1990-1-1', NOW), false, 'a rövid alak nem');
  assert.equal(isValidBirthDate('1990-02-31', NOW), false, 'nincs ilyen naptári nap');
  assert.equal(isValidBirthDate('1899-12-31', NOW), false, 'túl korai év');
  assert.equal(isValidBirthDate('', NOW), false);
  assert.equal(isValidBirthDate(null, NOW), false);
});

test('az életkor betöltött években számol (születésnap előtt/után)', () => {
  assert.equal(ageInYears('2010-09-27', NOW), 16, 'pont a 16. születésnap');
  assert.equal(ageInYears('2010-09-28', NOW), 15, 'holnap lenne 16');
  assert.equal(ageInYears('2008-09-28', NOW), 17);
  assert.equal(ageInYears('2008-09-27', NOW), 18);
  assert.equal(ageInYears('1990-01-01', NOW), 36);
  assert.equal(ageInYears('', NOW), null);
  assert.equal(ageInYears('2100-01-01', NOW), null, 'jövőbeli dátum: nincs életkor');
});

test('a 16. életév a határ: előtte nem, a napján már igen', () => {
  assert.equal(isAtLeastAge('2010-09-28', MINIMUM_AGE, NOW), false);
  assert.equal(isAtLeastAge('2010-09-27', MINIMUM_AGE, NOW), true);
  assert.equal(isAtLeastAge('', MINIMUM_AGE, NOW), false, 'hiányzó dátum: nem találgatunk');
});

test('a dátum CSAK engedélyezve kerül a nyilvános vetítésbe', () => {
  assert.deepEqual(
    publicBirthDate({ birthDate: '1990-01-31', birthDateVisible: true }),
    { birthDate: '1990-01-31' },
  );
  assert.deepEqual(
    publicBirthDate({ birthDate: '1990-01-31', birthDateVisible: false }),
    {},
    'alapból rejtve',
  );
  assert.deepEqual(publicBirthDate({ birthDate: '1990-01-31' }), {}, 'hiányzó jelző = rejtve');
  assert.deepEqual(
    publicBirthDate({ birthDate: '1990-1-1', birthDateVisible: true }),
    {},
    'hibás dátumot nem vetítünk ki',
  );
  assert.deepEqual(publicBirthDate(null), {});
});

test('a kor-sáv a dátum NÉLKÜL is megvan (a kiskorú-védelemhez)', () => {
  // A felhasználó a dátumát nem tette nyilvánossá — a kor-sáv akkor is kell,
  // különben a figyelmeztetés pont a rejtett dátumú partnernél maradna el.
  assert.deepEqual(
    publicAgeBand({ birthDate: '1990-01-31', birthDateVisible: false }, NOW),
    { adult: true },
  );
  assert.deepEqual(
    publicAgeBand({ birthDate: '2010-09-27', birthDateVisible: false }, NOW),
    { adult: false },
  );
  // A kor-sáv nem tartalmazhat dátumot (nincs adatszivárgás).
  const band = publicAgeBand({ birthDate: '1990-01-31' }, NOW);
  assert.deepEqual(Object.keys(band), ['adult']);
  assert.deepEqual(publicAgeBand({}, NOW), {}, 'hiányzó dátum: nincs sáv');
});

test('a visszavont dátumot és a kor-sávot törölni kell a vetítésből', () => {
  assert.deepEqual(projectionDeletions({}), ['birthDate', 'adult']);
  assert.deepEqual(projectionDeletions({ birthDate: '1990-01-31', adult: true }), []);
  assert.deepEqual(projectionDeletions({ birthDate: '1990-01-31' }), ['adult']);
  assert.deepEqual(projectionDeletions(null), [...CACHEABLE_OPTIONAL_FIELDS]);
});

test('a szerver index.js tényleg ezt a modult használja (forrás-lint)', () => {
  // ⚠️ A tiszta modul önmagában nem elég: ha a `publicProfileData` nem hívja,
  // a dátum soha nem kerül a vetítésbe (vagy épp tiltás nélkül bekerül).
  const source = fs.readFileSync(path.join(__dirname, 'index.js'), 'utf8');
  assert.match(
    source,
    /require\('\.\/birth-date-plan'\)/,
    'az index.js-nek be kell töltenie a modult',
  );
  assert.match(
    source,
    /return \{[\s\S]{0,4000}?\.\.\.publicBirthDate\(profile\)[\s\S]{0,400}?\.\.\.publicAgeBand\(profile\)/,
    'a nyilvános vetítés a dátumot és a kor-sávot is a modulból kapja',
  );
  assert.match(
    source,
    /async function persistPublicProfileProjection\(userId, data\) \{[\s\S]{0,600}?birthDateProjectionDeletions\(data\)/,
    'a vetítés írásakor a kimaradó mezőket törölni kell (a merge nem töröl)',
  );
});
