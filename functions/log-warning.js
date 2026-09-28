/**
 * KEZELT (várt) hiba naplózása — WARNING szinten, NEM hibaként.
 *
 * MIÉRT KELL (mérve, 2026-09-28): a 2. generációs Cloud Function a `console.warn`
 * kimenetét a **stderr**-re írja (`run.googleapis.com/stderr`), amit a Cloud
 * Logging **ERROR** súlyossággal jelenít meg — így egy *kezelt* tartalék-ág
 * (a WordPress-jelvénykatalógus 2,5 mp-es időtúllépése) valódi hibaként jelent
 * meg a riasztásokban. A mérés: **48 óra alatt 47** `achievement_catalog_fallback`
 * bejegyzés, ugyanaz a szöveg KÉT naplófolyamban — a
 * `cloudfunctions.googleapis.com/cloud-functions`-ben súlyosság nélkül, a
 * `run.googleapis.com/stderr`-ben viszont **ERROR**-ként; a `severity>=ERROR`
 * kapu pedig pont ez utóbbit számolja.
 *
 * A strukturált napló `severity` mezőjét a Cloud Logging tiszteletben tartja,
 * ezért ez a segéd `console.log`-gal (stdout) és kifejezett `severity: 'WARNING'`
 * értékkel ír. A `console.error`/`console.warn` marad a VALÓDI hibákra.
 */
const WARNING_SEVERITY = 'WARNING';

/**
 * @param {string} event   gépi eseménynév (pl. `achievement_catalog_fallback`)
 * @param {string} message emberi szöveg (pl. a kivétel üzenete)
 * @param {object} [extra] további mezők (pl. `{ status: 503 }`)
 * @returns {object} a kiírt bejegyzés (a tesztek ezt mérik)
 */
function logWarning(event, message, extra = {}) {
  const entry = {
    severity: WARNING_SEVERITY,
    event: String(event ?? ''),
    message: String(message ?? ''),
  };
  for (const [key, value] of Object.entries(extra || {})) {
    // ⚠️ A súlyosságot és az eseménynevet a hívó NEM írhatja felül — különben egy
    // „figyelmeztetés" némán hibává (vagy annak ellenkezőjévé) válhatna.
    if (key === 'severity' || key === 'event' || key === 'message') continue;
    entry[key] = value;
  }
  console.log(JSON.stringify(entry));
  return entry;
}

module.exports = { logWarning, WARNING_SEVERITY };
