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
const SSV_VARIANTS = Object.freeze(['free_wav', 'free_link', 'mp3_96', 'mp3_128']);

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
  if (!SSV_VARIANTS.includes(variant)) return null;
  return { uid, releaseId, variant };
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
  SSV_VARIANTS,
  decodeSsvCustomData,
  classifyVerifiedSsvCallback,
};
