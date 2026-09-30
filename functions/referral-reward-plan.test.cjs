'use strict';

/**
 * **Meghívó-jutalom mindkét félnek** — a döntés kapuja.
 *
 * MIT MÉR (nem forrás-lint, hanem a valódi döntés):
 *   1. a meghívó **50** pontot kap (a mai, éles viselkedés VÁLTOZATLAN);
 *   2. a meghívott **25** pontot kap (ÚJ) — ez a kör lényege;
 *   3. mindkettő **külön forráskulccsal** (a ledger ebből számol idempotenciát);
 *   4. az önmegírás (a `referredBy` a saját uid) **egyik** jutalmat sem adja;
 *   5. a már beváltott jelölés nem indít új kört, és a kész jelölő (`…Granted`)
 *      oldalanként **külön** zárja le a jóváírást (az egyik oldal hibája nem
 *      viszi el a másikét);
 *   6. a hívó (`index.js`) ezt a döntést használja, és a jelölőt a **siker után**
 *      írja — forrás-linttel mérve.
 */

const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const {
  INVITER_REWARD_POINTS,
  INVITEE_REWARD_POINTS,
  referralRewardPlan,
} = require('./referral-reward-plan');

const INDEX_SOURCE = fs.readFileSync(path.join(__dirname, 'index.js'), 'utf8');

test('a meghívó 50, a meghívott 25 pontot kap (kétoldali jutalom)', () => {
  const plan = referralRewardPlan({
    userId: 'invitee-1',
    before: {},
    after: { referredBy: 'inviter-1' },
  });
  assert.equal(plan.skipped, '');
  assert.deepEqual(plan.inviter, {
    userId: 'inviter-1',
    points: 50,
    reason: 'referral:invitee-1',
    flag: 'referralRewardGranted',
  });
  assert.deepEqual(plan.invitee, {
    userId: 'invitee-1',
    points: 25,
    reason: 'referral_welcome:invitee-1',
    flag: 'referralWelcomeGranted',
  });
  assert.equal(INVITER_REWARD_POINTS, 50, 'a meghívó jutalma változatlan');
  assert.equal(INVITEE_REWARD_POINTS, 25);
});

test('a két jóváírás KÜLÖN forráskulcsot és KÜLÖN címzettet kap', () => {
  const plan = referralRewardPlan({
    userId: 'b',
    before: {},
    after: { referredBy: 'a' },
  });
  assert.notEqual(plan.inviter.reason, plan.invitee.reason);
  assert.notEqual(plan.inviter.userId, plan.invitee.userId);
  // A forráskulcs a MEGHÍVOTTAT azonosítja mindkét oldalon (ezért számít
  // egyszer egy meghívott a meghívónak), a prefix viszont eltér.
  assert.ok(plan.inviter.reason.endsWith('b'));
  assert.ok(plan.invitee.reason.startsWith('referral_welcome:'));
  assert.ok(!plan.inviter.reason.startsWith('referral_welcome:'));
});

test('önmegírás: EGYIK jutalom sem jár (nincs pontfarmolás)', () => {
  const plan = referralRewardPlan({
    userId: 'same',
    before: {},
    after: { referredBy: 'same' },
  });
  assert.equal(plan.inviter, null);
  assert.equal(plan.invitee, null);
  assert.equal(plan.skipped, 'self-referral');
});

test('nincs meghívó / nincs felhasználó → nincs jutalom', () => {
  assert.equal(referralRewardPlan({ userId: 'x', after: {} }).skipped, 'no-referrer');
  assert.equal(referralRewardPlan({ userId: '', after: { referredBy: 'a' } }).skipped, 'no-user');
  assert.equal(referralRewardPlan({}).skipped, 'no-user');
});

test('a már meglévő meghívó-jelölés nem indít új kört, ha a jelölők készen vannak', () => {
  const plan = referralRewardPlan({
    userId: 'b',
    before: { referredBy: 'a' },
    after: { referredBy: 'a', referralRewardGranted: true, referralWelcomeGranted: true },
  });
  assert.equal(plan.skipped, 'already-granted');
  assert.equal(plan.inviter, null);
  assert.equal(plan.invitee, null);
});

test('ÖNGYÓGYÍTÓ: a hiányzó jutalom a KÖVETKEZŐ írásnál pótlódik (nem vész el)', () => {
  // ⚠️ MÉRT OK: élesben 1 olyan profil van, aki már 2026-09-27-én meghívóval
  // érkezett — a meghívói 50 pont megvan, a sajátja viszont nem. Az első
  // változat a `before.referredBy` átmenetre szűkített, ezért ő SOHA nem kapta
  // volna meg; most a jelölő hiánya pótolja.
  const laterWrite = referralRewardPlan({
    userId: 'b',
    before: { referredBy: 'a', referralRewardGranted: true },
    after: { referredBy: 'a', referralRewardGranted: true },
  });
  assert.equal(laterWrite.skipped, '');
  assert.equal(laterWrite.inviter, null, 'a meghívóé már megvan');
  assert.equal(laterWrite.invitee.points, 25, 'a meghívotté pótlódik');
  assert.equal(laterWrite.invitee.reason, 'referral_welcome:b');
  // A `before` állapot tehát NEM dönt: ugyanaz a döntés születik, ha a
  // meghívó-jelölés ebben az írásban keletkezett.
  const firstWrite = referralRewardPlan({
    userId: 'b',
    before: {},
    after: { referredBy: 'a', referralRewardGranted: true },
  });
  assert.deepEqual(firstWrite, laterWrite);
});

test('a kész jelölő oldalanként zárja le a jóváírást (a másik oldal még jár)', () => {
  const inviterDone = referralRewardPlan({
    userId: 'b',
    before: {},
    after: { referredBy: 'a', referralRewardGranted: true },
  });
  assert.equal(inviterDone.inviter, null, 'a meghívóé már megvan');
  assert.equal(inviterDone.invitee.points, 25, 'a meghívotté MÉG jár');

  const inviteeDone = referralRewardPlan({
    userId: 'b',
    before: {},
    after: { referredBy: 'a', referralWelcomeGranted: true },
  });
  assert.equal(inviteeDone.invitee, null);
  assert.equal(inviteeDone.inviter.points, 50, 'a meghívóé MÉG jár');

  const bothDone = referralRewardPlan({
    userId: 'b',
    before: {},
    after: { referredBy: 'a', referralRewardGranted: true, referralWelcomeGranted: true },
  });
  assert.equal(bothDone.skipped, 'already-granted');
});

test('a hívó a döntést használja, és a jelölőt a SIKER után írja', () => {
  // A régi, egyoldalú ág eltűnt: nincs többé „50 pont a meghívónak, a
  // meghívottnak semmi" logika a hívóban.
  assert.ok(
    INDEX_SOURCE.includes('const plan = referralRewardPlan({ userId, after });'),
    'a hívó a tiszta döntést hívja (a `before` állapot nem dönt)',
  );
  assert.ok(
    INDEX_SOURCE.includes("for (const side of ['inviter', 'invitee'])"),
    'mindkét oldal külön körben kap pontot',
  );
  assert.ok(
    INDEX_SOURCE.includes('[reward.flag]: true'),
    'a jelölő a jutalom oldalához tartozik',
  );
  assert.ok(
    INDEX_SOURCE.includes('const result = await awardAchievementPoints(reward.userId, reward.points, reward.reason);') &&
      INDEX_SOURCE.indexOf('[reward.flag]: true') > INDEX_SOURCE.indexOf('awardAchievementPoints(reward.userId'),
    'a jelölő írása a jóváírás UTÁN következik',
  );
  assert.ok(
    INDEX_SOURCE.includes('granted[side] = { userId: reward.userId, points: reward.points, error:'),
    'az egyik oldal hibája nem állítja meg a másikat (külön try)',
  );
  // A `claimReferralCode` (a meghívott jele) érintetlen: 24 órás ablak, saját
  // kód tiltása, egyszeri beállítás.
  assert.ok(INDEX_SOURCE.includes("referredBy: inviter.id,"));
  assert.ok(INDEX_SOURCE.includes("if (current.referredBy) return;"));
});
