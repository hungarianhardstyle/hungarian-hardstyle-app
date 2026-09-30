'use strict';

/**
 * **Meghívó-jutalom MINDKÉT félnek** — tiszta döntés, nulla függőség.
 *
 * A tulajdonos választotta a hat irány közül a *„meghívó-jutalom mindkét félnek"*
 * pontot. A **mért kiindulás** (2026-09-28): a meghívó oldala **már élt**
 * (`awardAchievementFromReferral` → 50 pont a meghívónak, egyszer), a
 * **meghívott viszont semmit nem kapott** — vagyis a jutalom egyoldalú volt,
 * pedig a meghívott az, aki a legtöbbet kockáztatja (regisztrál, profilt tölt ki).
 *
 * Ez a modul **csak a döntést** adja: egy profil-írásból (`community_profiles/{uid}`)
 * megmondja, **ki kap pontot, mennyit és milyen forráskulccsal**, valamint hogy
 * melyik jelölőt kell a siker után beírni. Az olvasást és az írást a
 * `functions/index.js` végzi.
 *
 * ⚠️ **MIÉRT KÜLÖN FORRÁSKULCS:** a pont-jóváírás egy ledger-sorral
 * idempotens (`huhs` ledger: `${uid}:${sourceKey}`), ezért a két oldal **külön
 * kulcsot** kap:
 *   * meghívó: `referral:{meghívott-uid}` → minden meghívott **egyszer** számít;
 *   * meghívott: `referral_welcome:{meghívott-uid}` → neki is **egyszer** jár.
 * Így a két jóváírás nem tudja kioltani vagy blokkolni egymást, és egyik oldal
 * hibája sem viszi el a másikét (külön `try`-ban futnak a hívóban).
 *
 * ⚠️ **AZ ÖNMEGHÍVÁS TILTOTT:** ha a `referredBy` a saját uid, **egyik** jutalom
 * sem jár (a `claimReferralCode` ezt kizárja, de a döntés itt is véd — egy kézi
 * adatmódosítás ne tudjon pontot farmolni).
 *
 * ⚠️ **ÖNGYÓGYÍTÓ (mért ok, 2026-09-28):** a döntés **nem** a `before` állapotra
 * épül, hanem a profilban tárolt **jelölőkre**. Az első változat a „éppen most
 * jelent meg a `referredBy`" átmenetre szűkített, és az éles mérés megmutatta a
 * hátulütőjét: **1 olyan profil van, aki már 2026-09-27-én meghívóval érkezett**
 * (a meghívói 50 pont jóváírása megvan) — ő a szűkítés miatt **soha** nem kapta
 * volna meg a saját jutalmát, és egy átmeneti hiba is **véglegesen**
 * elveszíthette volna a pontot. Mostantól minden profil-írásnál újraellenőrizzük
 * a jelölőket: a jutalom **pótlódik**, ha korábban nem sikerült, viszont a jelölő
 * (és a ledger) miatt **kétszer nem** adható.
 */

/** A meghívó jutalma (a mai, éles viselkedés — változatlan). */
const INVITER_REWARD_POINTS = 50;

/** A meghívott jutalma (ÚJ: a regisztrációért és a profil kitöltéséért). */
const INVITEE_REWARD_POINTS = 25;

/** A meghívó forráskulcs-előtagja. */
const INVITER_REASON_PREFIX = 'referral:';

/** A meghívott forráskulcs-előtagja. */
const INVITEE_REASON_PREFIX = 'referral_welcome:';

/** A meghívó jelölője a profilban (a jóváírás után íródik). */
const INVITER_FLAG = 'referralRewardGranted';

/** A meghívott jelölője a profilban (a jóváírás után íródik). */
const INVITEE_FLAG = 'referralWelcomeGranted';

function cleanId(value) {
  return String(value || '').trim();
}

/**
 * A kétoldali jutalom döntése egy profil-írásból.
 *
 * @param {{userId: string, after?: object}} input
 * @returns {{
 *   inviter: {userId: string, points: number, reason: string, flag: string} | null,
 *   invitee: {userId: string, points: number, reason: string, flag: string} | null,
 *   skipped: string,
 * }}
 */
function referralRewardPlan({ userId, after } = {}) {
  const inviteeId = cleanId(userId);
  const current = after || {};
  const inviterId = cleanId(current.referredBy);
  const empty = { inviter: null, invitee: null };

  if (!inviteeId) return { ...empty, skipped: 'no-user' };
  if (!inviterId) return { ...empty, skipped: 'no-referrer' };
  if (inviterId === inviteeId) return { ...empty, skipped: 'self-referral' };
  // ⚠️ SZÁNDÉKOSAN NINCS `before`-kapu: a döntés a profilban tárolt
  // **jelölőkből** jön, ezért egy korábban elveszett jutalom **pótlódik** a
  // következő írásnál, kétszer viszont nem adható (jelölő + ledger).

  const inviter =
    current[INVITER_FLAG] === true
      ? null
      : {
          userId: inviterId,
          points: INVITER_REWARD_POINTS,
          reason: `${INVITER_REASON_PREFIX}${inviteeId}`,
          flag: INVITER_FLAG,
        };
  const invitee =
    current[INVITEE_FLAG] === true
      ? null
      : {
          userId: inviteeId,
          points: INVITEE_REWARD_POINTS,
          reason: `${INVITEE_REASON_PREFIX}${inviteeId}`,
          flag: INVITEE_FLAG,
        };

  if (!inviter && !invitee) return { ...empty, skipped: 'already-granted' };
  return { inviter, invitee, skipped: '' };
}

module.exports = {
  INVITER_REWARD_POINTS,
  INVITEE_REWARD_POINTS,
  INVITER_REASON_PREFIX,
  INVITEE_REASON_PREFIX,
  INVITER_FLAG,
  INVITEE_FLAG,
  referralRewardPlan,
};
