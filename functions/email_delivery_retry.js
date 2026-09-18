'use strict';

/**
 * Retrykesz tarolo a „tajekoztato" levelekhez.
 *
 * MIERT KELL: a `sendIdentityEmailOnce()` a duplikacio ellen ved, nem a kudarc
 * ellen. A munkarekordban a cimzett csak HASH-kent van (`recipientHash`), a
 * teljes cim nincs — ezert egy SMTP-hiba utan a rendszer nem tudja
 * megismetelni a kuldest, mert nem tudja, hova.
 *
 * Ket helyen ez vegleges elveszest jelent, mert nincs, aki ujrakerje:
 *   - e-mail-csere: a `syncEmailChange()` a `previousEmail` mezot a level
 *     ELOTT torli, tehat a regi cim a muvelettel eltunik;
 *   - admin fioktorles: az Auth-fiok mar torolve van, a cim csak a memoriaban
 *     elt, es a hivas egyszer fut.
 *
 * A felhasznalo altal KERT levelek (megerosites, jelszo-visszaallitas) ezt nem
 * igenylik: ott a felhasznalo latja a hibat es ujra tudja kerni.
 *
 * MIT TESZ: a cimzettet es a sablonnevet egy rovid eletu, szerveroldali
 * rekordban megorzi (a Firestore-szabalyzat kliens-számára olvashatatlanna
 * teszi), es egy utemezett fuggveny korlatozott alkalommal ujraprobalja.
 * A sikeres kuldes utan a rekord torlodik, tehat nem marad benne szemelyes adat.
 */

const MAX_ATTEMPTS = 3;

// A rovid TTL szandekos: ha a levelet nem sikerul kikuldeni, a cim ne maradjon
// meg napokig a szerveren. 24 ora boven eleg a ket ujraprobaláshoz.
const RETRY_TTL_MS = 24 * 60 * 60 * 1000;

// Idozitett lepesek: a masodik proba koran (a legtobb SMTP-hiba atmeneti),
// a harmadik mar tavolabb, hogy egy tartosabb kimaradas is atveszelheto legyen.
const RETRY_DELAYS_MS = [5 * 60 * 1000, 30 * 60 * 1000];

function nextRetryDelayMs(attempts) {
  const index = Math.max(0, Number(attempts) || 1) - 1;
  return RETRY_DELAYS_MS[Math.min(index, RETRY_DELAYS_MS.length - 1)];
}

function collectionName(uid) {
  return String(uid || '').trim();
}

/**
 * Elmenti a cimzettet egy ujraprobalhato rekordba.
 * Visszaadja a dokumentum-azonositot, vagy null-t, ha nincs mit menteni.
 */
async function queueIdentityNotificationRetry(db, { key, uid, to, template, reason }) {
  const recipient = String(to || '').trim();
  const dedupeKey = String(key || '').trim();
  const owner = collectionName(uid);
  if (!db || !recipient || !dedupeKey || !owner) return null;
  const crypto = require('crypto');
  const id = crypto.createHash('sha256').update(dedupeKey).digest('hex').slice(0, 40);
  await db
    .collection('email_delivery_pending')
    .doc(id)
    .set(
      {
        uid: owner,
        recipient,
        template: String(template || '').trim(),
        attempts: 0,
        lastFailure: String(reason || 'smtp_rejected').slice(0, 64),
        updatedAt: new Date(),
        expiresAt: new Date(Date.now() + RETRY_TTL_MS),
      },
      { merge: true },
    );
  return id;
}

async function clearIdentityNotificationRetry(db, id) {
  if (!db || !id) return;
  await db.collection('email_delivery_pending').doc(id).delete().catch(() => {});
}

async function bumpIdentityNotificationRetry(db, id, { attempts, reason }) {
  if (!db || !id) return;
  const nextAttempts = Math.max(1, Number(attempts) || 1);
  if (nextAttempts >= MAX_ATTEMPTS) {
    await clearIdentityNotificationRetry(db, id);
    return;
  }
  await db
    .collection('email_delivery_pending')
    .doc(id)
    .set(
      {
        attempts: nextAttempts,
        lastFailure: String(reason || 'smtp_rejected').slice(0, 64),
        nextAttemptAt: new Date(Date.now() + nextRetryDelayMs(nextAttempts)),
        updatedAt: new Date(),
        expiresAt: new Date(Date.now() + RETRY_TTL_MS),
      },
      { merge: true },
    );
}

/** A sablonnevet visszaoldja a kuldendo tartalomra. */
function resolveTemplate(templateName, templates) {
  switch (String(templateName || '').trim()) {
    case 'deletion':
      return templates.deletionEmailTemplate();
    case 'emailChange':
      return templates.emailChangeEmailTemplate();
    default:
      return null;
  }
}

module.exports = {
  MAX_ATTEMPTS,
  RETRY_TTL_MS,
  RETRY_DELAYS_MS,
  nextRetryDelayMs,
  queueIdentityNotificationRetry,
  clearIdentityNotificationRetry,
  bumpIdentityNotificationRetry,
  resolveTemplate,
};
