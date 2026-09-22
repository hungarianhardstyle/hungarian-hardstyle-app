'use strict';

// Az AdMob jutalmazott **SSV-visszahívás** tiszta döntései.
//
// MIÉRT KÜLÖN MODUL (mérve, 2026-09-22): a kezelő a `missing reward data` ágat az
// **aláírás-ellenőrzés UTÁN** futtatta, és 400-at adott rá. Az AdMob konzol
// „URL ellenőrzése" gombja viszont **valódi aláírással, de `custom_data` nélkül**
// hív (a mező ott üres, mert a `custom_data`-t a KLIENS küldi
// `setServerSideOptions`-szal) — ezért a konzol **soha nem tudta érvényesíteni**
// az URL-t. A napló bizonyítéka: `{"reason":"missing reward data"}` háromszor,
// közvetlenül a validátor kattintásai után.
//
// ⚠️ A „nincs custom_data" eset **nem hiba**: az egy próba, amire 200-at kell
// adni, különben az AdMob hibát jelez a beállításnál. Jóváírást viszont NEM
// jelenthet, mert nem tudjuk, kinek szólna.

/** A reklámos feloldásnál használt változatok (a kliens ezt küldi). */
const AD_UNLOCK_VARIANTS = Object.freeze(['free_wav', 'free_link', 'mp3_96', 'mp3_128']);

/**
 * A **kliens-oldali** azonnali jóváírás keretei (tulajdonosi döntés, 2026-09-22).
 *
 * MIÉRT KELL: a Google SSV-dokumentációja szerint a jutalmat a **kliens
 * visszahívásából** kell azonnal megadni, az SSV pedig utólag ellenőriz. Emiatt a
 * kliens is kérhet jóváírást — ezt a két keret fogja vissza:
 *
 *  * `burst` — egy percen belül ennyi kérés mehet át (senki nem néz meg háromnál
 *    több jutalmazott reklámot egy perc alatt);
 *  * `daily` — a valódi megkötés: egy fiók ennyi reklámos feloldást kaphat egy
 *    nap. Ez teszi kockázatossá, hogy egy módosított kliens reklám nélkül
 *    próbálja kinyitni a teljes kínálatot.
 *
 * ⚠️ Amiről ez NEM véd: a fizetős tételek (`label_entitlements`) érintetlenek, a
 * reklámos feloldás csak az **ingyenes** sáv. A veszteség tehát elmaradt
 * reklámbevétel, nem eladott zenék ára — és az SSV-vel összevetve naplóból
 * látszik (`admob_ssv_granted` vs. `clientGrantedAt` nélküli rekordok).
 */
const CLIENT_UNLOCK_LIMITS = Object.freeze({
  burst: { key: 'ad_unlock_client', limit: 3, windowMs: 60_000 },
  daily: { key: 'ad_unlock_client_daily', limit: 20, windowMs: 24 * 60 * 60 * 1000 },
});

/**
 * A `custom_data` kibontása. A kliens base64url-kódolt JSON-t küld
 * (`{uid, releaseId, variant}`), de a hívás URL-kódolva is érkezhet.
 *
 * @returns {{uid: string, releaseId: number, variant: string}|null} null, ha a
 *   tartalom értelmezhetetlen vagy hiányos — ilyenkor NEM szabad jóváírni.
 */
function decodeSsvCustomData(raw) {
  const text = String(raw || '').trim();
  if (!text) return null;
  let decoded = null;
  try {
    decoded = JSON.parse(Buffer.from(text, 'base64url').toString('utf8'));
  } catch (_) {
    try {
      decoded = JSON.parse(
        Buffer.from(decodeURIComponent(text), 'base64url').toString('utf8'),
      );
    } catch (_) {
      return null;
    }
  }
  if (!decoded || typeof decoded !== 'object') return null;
  const uid = String(decoded.uid || '').trim();
  const releaseId = Number(decoded.releaseId || 0);
  const variant = String(decoded.variant || 'mp3_128').trim();
  if (!uid || !Number.isInteger(releaseId) || releaseId < 1) return null;
  if (!AD_UNLOCK_VARIANTS.includes(variant)) return null;
  return { uid, releaseId, variant };
}

/**
 * A **kliens** kérésének ellenőrzése (a callable bemenete).
 * Ugyanaz a szabály, mint az SSV-nél — egy helyen.
 *
 * @returns {{ok: true, releaseId: number, variant: string}|
 *   {ok: false, reason: string}}
 */
function normalizeAdUnlockRequest({ releaseId, variant } = {}) {
  const id = Number(releaseId || 0);
  if (!Number.isInteger(id) || id < 1) {
    return { ok: false, reason: 'Érvénytelen kiadvány-azonosító.' };
  }
  const name = String(variant || 'mp3_96').trim();
  if (!AD_UNLOCK_VARIANTS.includes(name)) {
    return { ok: false, reason: 'Érvénytelen reklámos feloldási változat.' };
  }
  return { ok: true, releaseId: id, variant: name };
}

/**
 * A meglévő `variants` térkép bővítése EGY változattal.
 * ⚠️ Szándékosan NEM írja felül a többit: egy kiadványon több változat is
 * feloldható (pl. `free_link` ÉS `mp3_96`), és a 349-es hiba pont egy ilyen
 * elveszett változat volt.
 */
function mergeUnlockVariants(existing, variant) {
  const base =
    existing && typeof existing === 'object' && !Array.isArray(existing) ? existing : {};
  return { ...base, [variant]: true };
}

/**
 * A visszahívás **végső** sorsa — az aláírás ellenőrzése UTÁN (addig minden
 * elutasítás a kezelőben marad, mert azok a kriptográfiai lépésekhez kötődnek).
 *
 * @param {{customData?: string, decoded?: object|null}} facts
 * @returns {{action: 'validate'}|{action: 'reject', reason: string}|
 *   {action: 'grant', uid: string, releaseId: number, variant: string}}
 */
function classifyVerifiedSsvCallback({ customData, decoded } = {}) {
  // ⚠️ Az AdMob konzol validátora: valódi aláírás, de ÜRES custom_data.
  // Ez próba, nem jutalom → 200, jóváírás nélkül.
  if (!String(customData || '').trim()) return { action: 'validate' };
  if (!decoded) return { action: 'reject', reason: 'invalid reward data' };
  return {
    action: 'grant',
    uid: decoded.uid,
    releaseId: decoded.releaseId,
    variant: decoded.variant,
  };
}

module.exports = {
  AD_UNLOCK_VARIANTS,
  // Visszamenőleges név (a meglévő hívók/testsztek miatt) — UGYANAZ a lista.
  SSV_VARIANTS: AD_UNLOCK_VARIANTS,
  CLIENT_UNLOCK_LIMITS,
  decodeSsvCustomData,
  normalizeAdUnlockRequest,
  mergeUnlockVariants,
  classifyVerifiedSsvCallback,
};
