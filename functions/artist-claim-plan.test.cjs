const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const {
  HOUSE_EMAIL,
  HOUSE_DOMAIN,
  isHouseEmail,
  claimEmailsFor,
  artistClaimState,
  claimErrorMessage,
  artistClaimRecord,
  claimedArtistIds,
} = require('./artist-claim-plan');

/**
 * A DJ-adatlap claim jogosultságának bizonyítása.
 *
 * A tulajdonos jelzése (2026-09-21): *„egy dj beküldött egy dj-t… valamiért
 * tudtam ÉN mint admin claimelni - ami hiba"*, majd *„most a Denoiser accomon a
 * Sunshite State dj van claimelve - ami hiba - lekéne szedni rólam"*, végül a
 * szabály: *„Claimelni csak az tudja a feltett dj adatlapot, akinek egyezik az
 * email címe amivel regelt a dj adatlapon szereplő email címmel"* és *„a claim
 * akkor jelenjen CSAK meg ha valamelyik email cím egyezik (booking vagy privát)"*.
 *
 * A legfontosabb teszt az **admin-kivétel hiánya**: élesben az `isAdminClaim`
 * miatt bármelyik adatlap claimelhető volt az admin címével.
 *
 * Futtatás: node --test functions/artist-claim-plan.test.cjs
 */

const ADMIN = 'info@hungarianhardstyle.hu';
const DJ = 'sunshite.state@gmail.com';

/** Egy valósághű adatlap (a WordPress `/artists/<id>` + a privát végpont mezői). */
function artist(overrides = {}) {
  return {
    id: 12345,
    title: 'Sunshite State',
    booking_email: 'booking@sunshite.hu',
    contact_email: DJ,
    ...overrides,
  };
}

test('egyező BOOKING e-mail → claimelhető', () => {
  const state = artistClaimState({
    email: 'booking@sunshite.hu',
    emailVerified: true,
    artist: artist(),
    claim: null,
    uid: 'uid-1',
  });
  assert.equal(state.canClaim, true);
  assert.equal(state.claimed, false);
  assert.equal(state.mine, false);
});

test('egyező PRIVÁT (contact) e-mail → claimelhető', () => {
  const state = artistClaimState({
    email: DJ,
    emailVerified: true,
    artist: artist(),
    claim: null,
    uid: 'uid-1',
  });
  assert.equal(state.canClaim, true);
});

test('az egyezés kis/nagybetűtől és a szóköztől független', () => {
  const state = artistClaimState({
    email: '  SunShite.State@Gmail.COM ',
    emailVerified: true,
    artist: artist(),
    claim: null,
    uid: 'uid-1',
  });
  assert.equal(state.canClaim, true);
});

test('⚠️ AZ ADMIN-KIVÉTEL NINCS: az admin címe nem claimelhet idegen adatlapot', () => {
  // ÉLES HIBA VOLT: `isAdminClaim = email === ADMIN_EMAIL` → az admin bármelyik
  // adatlapot claimelhette, és így került idegen DJ-adatlap a fiókjára.
  const state = artistClaimState({
    email: ADMIN,
    emailVerified: true,
    artist: artist(),
    claim: null,
    uid: 'uid-admin',
  });
  assert.equal(state.canClaim, false);
  assert.equal(state.reason, 'house-email');
});

test('egyező e-mail NÉLKÜL nem claimelhető (nincs találgatás)', () => {
  const state = artistClaimState({
    email: 'valaki.mas@gmail.com',
    emailVerified: true,
    artist: artist(),
    claim: null,
    uid: 'uid-1',
  });
  assert.equal(state.canClaim, false);
  assert.equal(state.reason, 'email-mismatch');
});

test('hitelesítetlen e-mail címmel nem claimelhető', () => {
  const state = artistClaimState({
    email: DJ,
    emailVerified: false,
    artist: artist(),
    claim: null,
    uid: 'uid-1',
  });
  assert.equal(state.canClaim, false);
  assert.equal(state.reason, 'unverified');
});

test('az adatlapon NINCS e-mail → nem claimelhető (nem tippelünk)', () => {
  const state = artistClaimState({
    email: DJ,
    emailVerified: true,
    artist: artist({ booking_email: '', contact_email: '' }),
    claim: null,
    uid: 'uid-1',
  });
  assert.equal(state.canClaim, false);
  assert.equal(state.reason, 'no-artist-email');
});

test('a ház saját címe (booking_via_huhs) nem számít egyezésnek', () => {
  const state = artistClaimState({
    email: 'egy.dj@gmail.com',
    emailVerified: true,
    artist: artist({ booking_email: HOUSE_EMAIL, contact_email: '' }),
    claim: null,
    uid: 'uid-1',
  });
  assert.equal(state.canClaim, false);
  assert.equal(
    claimEmailsFor(artist({ booking_email: HOUSE_EMAIL, contact_email: '' })).length,
    0,
  );
});

test('⚠️ a DJ privát címe lehet `info@` MÁS domainen (a tulajdonos észrevétele)', () => {
  // *„info@ mail lehet privát, ha nem hungarianhardstyle.hu a domain sztem"* —
  // ezért a szabály a **domainre** szűr, nem a pontos címre.
  const dj = artist({ booking_email: '', contact_email: 'info@sajatdomain.hu' });
  assert.deepEqual(claimEmailsFor(dj), ['info@sajatdomain.hu']);
  const state = artistClaimState({
    email: 'info@sajatdomain.hu',
    emailVerified: true,
    artist: dj,
    claim: null,
    uid: 'uid-1',
  });
  assert.equal(state.canClaim, true);
  assert.equal(state.reason, 'ok');
});

test('a ház DOMAINJÉRE eső bármely cím kimarad (nem csak az info@)', () => {
  // A korábbi pontos egyezés mellett a `booking@hungarianhardstyle.hu` átcsúszott
  // volna — a domain-szabály ezt is kizárja.
  const house = artist({
    booking_email: 'booking@hungarianhardstyle.hu',
    contact_email: 'sajat@hungarianhardstyle.hu',
  });
  assert.deepEqual(claimEmailsFor(house), []);
  assert.equal(isHouseEmail('booking@hungarianhardstyle.hu'), true);
  assert.equal(isHouseEmail('INFO@HungarianHardstyle.HU'), true);
  assert.equal(isHouseEmail('info@sajatdomain.hu'), false);
  assert.equal(isHouseEmail('nem-is-cim'), false);
  assert.equal(isHouseEmail(''), false);
  assert.equal(HOUSE_DOMAIN, 'hungarianhardstyle.hu');
});

test('a ház domainjével bejelentkező fiók sem claimelhet', () => {
  const state = artistClaimState({
    email: 'sajat@hungarianhardstyle.hu',
    emailVerified: true,
    artist: artist(),
    claim: null,
    uid: 'uid-1',
  });
  assert.equal(state.canClaim, false);
  assert.equal(state.reason, 'house-email');
});

test('már claimelt (másnál) → nem claimelhető, de látszik, hogy foglalt', () => {
  const state = artistClaimState({
    email: DJ,
    emailVerified: true,
    artist: artist(),
    claim: { uid: 'uid-mas', artistId: 12345 },
    uid: 'uid-1',
  });
  assert.equal(state.claimed, true);
  assert.equal(state.mine, false);
  assert.equal(state.canClaim, false);
  assert.equal(state.reason, 'taken');
});

test('a SAJÁT claimem → mine, és nincs második claim gomb', () => {
  const state = artistClaimState({
    email: DJ,
    emailVerified: true,
    artist: artist(),
    claim: { uid: 'uid-1', artistId: 12345 },
    uid: 'uid-1',
  });
  assert.equal(state.claimed, true);
  assert.equal(state.mine, true);
  assert.equal(state.canClaim, false);
  assert.equal(state.reason, 'mine');
});

test('a döntés NEM tartalmaz e-mail címet (nem szivárog ki)', () => {
  const state = artistClaimState({
    email: DJ,
    emailVerified: true,
    artist: artist(),
    claim: null,
    uid: 'uid-1',
  });
  assert.deepEqual(Object.keys(state).sort(), [
    'canClaim',
    'claimed',
    'mine',
    'reason',
  ]);
  assert.ok(!JSON.stringify(state).includes(DJ));
  assert.ok(!JSON.stringify(state).includes('booking@sunshite.hu'));
});

test('a hibaüzenetek magyarul vannak, és nem árulják el a címeket', () => {
  for (const reason of [
    'taken',
    'unverified',
    'missing-email',
    'house-email',
    'no-artist-email',
    'email-mismatch',
    'ismeretlen',
  ]) {
    const message = claimErrorMessage(reason);
    assert.ok(message.length > 10, reason);
    assert.ok(!message.includes('@'), reason);
  }
  assert.equal(
    claimErrorMessage('email-mismatch'),
    'A bejelentkezési e-mail nem egyezik az adatlapon szereplő e-mail címmel.',
  );
});

test('a claim-rekord egységes (kisbetűs cím, szám típusú azonosító)', () => {
  const record = artistClaimRecord({ artistId: '12345', uid: ' uid-1 ', email: ' DJ@Gmail.com ' });
  assert.equal(record.artistId, 12345);
  assert.equal(record.uid, 'uid-1');
  assert.equal(record.email, 'dj@gmail.com');
  assert.equal(record.status, 'claimed');
});

test('a profilkártyákhoz csak az ÉRVÉNYES azonosítók kerülnek be', () => {
  const ids = claimedArtistIds([
    { artistId: 12345 },
    { artistId: '6789' },
    { artistId: 0 },
    { artistId: null },
    { artistId: 12345 },
    {},
  ]);
  assert.deepEqual(ids, [12345, 6789]);
  assert.deepEqual(claimedArtistIds(null), []);
});

test('⚠️ a SZERVERBEN sincs admin-kivétel (ez volt az éles hiba)', () => {
  const source = fs.readFileSync(path.join(__dirname, 'index.js'), 'utf8');
  // ÉLES HIBA: `isAdminClaim = email === ADMIN_EMAIL` → az admin bármelyik
  // adatlapot claimelhette. Ez a sor többé nem térhet vissza.
  assert.doesNotMatch(source, /isAdminClaim/);
  assert.match(
    source,
    /exports\.claimArtistProfile[\s\S]*?artistClaimState\(/,
    'a claim a tiszta modul döntésén megy át',
  );
  assert.match(
    source,
    /claimErrorMessage\(state\.reason\)/,
    'a hibaüzenet a valódi okot mondja meg (magyarul)',
  );
  assert.match(
    source,
    /artists\/\$\{artistId\}\/claim-emails/,
    'a címeket a privát WordPress-végpont adja (nem a nyilvános adatlap)',
  );
  // A claim-állapot a felületnek **nem** ad e-mail címet.
  assert.match(
    source,
    /exports\.getArtistClaimStatus[\s\S]*?return artistClaimState\(\{/,
    'a státusz-válasz a tiszta döntés (claimed/mine/canClaim)',
  );
  assert.match(source, /exports\.releaseArtistClaim/);
  assert.match(source, /exports\.getClaimedArtistsForUser/);
});
