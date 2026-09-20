'use strict';

/**
 * A „Saját zenéim" könyvtár összeállítása — tiszta logika, nulla függőség.
 *
 * MIÉRT: a felhasználó azt kérte, hogy *„egy user specifikus menüpontban"* lássa
 * a **megvett zenéit**, ott tudja **lejátszani** (a szám végén a következőre
 * lépve) és **újra letölteni**. A jogosultság eddig is megvolt a Firestore-ban
 * (`label_entitlements/<uid>_<productId>`), és a reklámmal feloldott változatok
 * is (`label_ad_unlocks/<uid>_<releaseId>`), de **egyik listát sem kérdezte le
 * soha senki** — a kliens egyetlen dokumentumot nézett meg név szerint, a
 * letöltés-végpont pedig csak egy fájlt ad.
 *
 * HÁROM SZÁNDÉKOS SZABÁLY:
 *  1. **Nincs találgatás:** a termék-azonosítóból dolgozunk, és ami nem illik a
 *     mintára (kézzel írt, hibás vagy idegen bejegyzés), azt **kihagyjuk** —
 *     nem tippelünk release-t vagy változatot.
 *  2. **Kiadványonként egy sor:** ugyanannak a kiadványnak több változata is
 *     lehet a birtokában (Radio + Extended, WAV + MP3), ezek **egy** elembe
 *     kerülnek, külön felsorolással — a felület így tudja „ez már megvan"
 *     jelöléssel kínálni a többit.
 *  3. **A reklám-feloldás NEM vásárlás:** külön mezőben adjuk vissza
 *     (`unlocked`), hogy a felület meg tudja jelölni („reklámmal feloldva"), és
 *     a felhasználó lássa, miért nem fizetett érte.
 */

/** A vásárolható változatok. A sorrend a felület megjelenítési sorrendje. */
const LABEL_VARIANTS = [
  'radio_wav',
  'radio_mp3_320',
  'extended_wav',
  'extended_mp3_320',
  'wav',
  'mp3_320',
  'mp3_128',
  'mp3_96',
  'free_wav',
];

const PRODUCT_PREFIX = 'huhs_release_';
const PRODUCT_PATTERN = new RegExp(
  `^${PRODUCT_PREFIX}([0-9]+)_(${LABEL_VARIANTS.join('|')})$`,
);

/**
 * `huhs_release_<releaseId>_<variant>` → `{ releaseId, variant }`, vagy `null`,
 * ha nem illik a mintára. Szándékosan **szigorú**: a release-azonosító pozitív
 * egész kell legyen.
 */
function parseLabelProductId(productId) {
  const match = PRODUCT_PATTERN.exec(String(productId || '').trim());
  if (!match) return null;
  const releaseId = Number(match[1]);
  if (!Number.isInteger(releaseId) || releaseId < 1) return null;
  return { releaseId, variant: match[2] };
}

/**
 * Egy reklám-feloldás dokumentumból kiolvassa, mely változatokat oldotta fel.
 *
 * A RÉGI dokumentumok (amelyek a változat előtti időből valók) **nem nevezik
 * meg** a változatot: azok az eredeti 128 kbps jutalmat jelentik — ugyanaz a
 * szabály, mint a letöltés-végpontnál (`activeAdUnlock`), hogy a könyvtár és a
 * letöltés **ne mondjon ellent** egymásnak.
 */
function adUnlockedVariants(unlock, releaseId) {
  const out = [];
  if (!unlock || Number(unlock.releaseId) !== Number(releaseId)) return out;
  if (!unlock.variants && !unlock.variant) return ['mp3_128'];
  if (LABEL_VARIANTS.includes(unlock.variant)) out.push(unlock.variant);
  const map = unlock.variants;
  if (map && typeof map === 'object') {
    for (const variant of LABEL_VARIANTS) {
      if (map[variant] === true && !out.includes(variant)) out.push(variant);
    }
  }
  return out;
}

/** A változatok rendezése a felületi sorrend szerint (nem ABC-sorrendben). */
function sortVariants(variants) {
  const unique = [...new Set(variants)].filter((v) => LABEL_VARIANTS.includes(v));
  return unique.sort(
    (a, b) => LABEL_VARIANTS.indexOf(a) - LABEL_VARIANTS.indexOf(b),
  );
}

/**
 * A könyvtár tartalma a nyers Firestore-dokumentumokból.
 *
 * Bemenet: a `label_entitlements` és a `label_ad_unlocks` rekordok (a hívó
 * szűri `uid`-re — itt csak az adat rendezése történik).
 * Kimenet: `{ items: [...], count }`, a **legfrissebb kiadvánnyal elöl**.
 */
function labelLibraryPayload(entitlements, unlocks) {
  const byRelease = new Map();

  const entryFor = (releaseId) => {
    if (!byRelease.has(releaseId)) {
      byRelease.set(releaseId, {
        releaseId,
        purchased: [],
        unlocked: [],
        lastVerifiedAt: null,
      });
    }
    return byRelease.get(releaseId);
  };

  for (const record of Array.isArray(entitlements) ? entitlements : []) {
    const parsed = parseLabelProductId(record?.productId);
    if (!parsed) continue;
    // A jogosultság a SAJÁT release-azonosítóját viszi; ha ez eltér a termék
    // azonosítójában lévőtől, a bejegyzés ellentmondásos, ezért kimarad.
    if (Number(record.releaseId) !== parsed.releaseId) continue;
    const entry = entryFor(parsed.releaseId);
    if (!entry.purchased.includes(parsed.variant)) {
      entry.purchased.push(parsed.variant);
    }
    const verified = record.verifiedAt;
    const millis = verified?.toMillis?.() ?? verified?._seconds * 1000;
    if (Number.isFinite(millis) && (!entry.lastVerifiedAt || millis > entry.lastVerifiedAt)) {
      entry.lastVerifiedAt = millis;
    }
  }

  for (const record of Array.isArray(unlocks) ? unlocks : []) {
    const releaseId = Number(record?.releaseId);
    if (!Number.isInteger(releaseId) || releaseId < 1) continue;
    const variants = adUnlockedVariants(record, releaseId);
    if (!variants.length) continue;
    const entry = entryFor(releaseId);
    for (const variant of variants) {
      if (!entry.unlocked.includes(variant)) entry.unlocked.push(variant);
    }
  }

  const items = [...byRelease.values()]
    .map((entry) => {
      const purchased = sortVariants(entry.purchased);
      // Amit megvett, az nem „reklámmal feloldott": a vásárlás az erősebb jog.
      const unlocked = sortVariants(entry.unlocked).filter(
        (variant) => !purchased.includes(variant),
      );
      return {
        releaseId: entry.releaseId,
        purchased,
        unlocked,
        variants: sortVariants([...purchased, ...unlocked]),
        lastVerifiedAt: entry.lastVerifiedAt,
      };
    })
    .filter((item) => item.variants.length > 0)
    .sort((a, b) => b.releaseId - a.releaseId);

  return { items, count: items.length };
}

module.exports = {
  LABEL_VARIANTS,
  parseLabelProductId,
  adUnlockedVariants,
  sortVariants,
  labelLibraryPayload,
};
