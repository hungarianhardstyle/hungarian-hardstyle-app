const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

/**
 * A „tajekoztato" levelek ujraprobalasa (H2 az auditban).
 *
 * A `sendIdentityEmailOnce()` a DUPLIKACIO ellen ved, nem a kudarc ellen: a
 * munkarekordban a cimzett csak hash-kent van, tehat SMTP-hiba utan nincs
 * honnan ujrakuldeni. Ket helyen ez vegleges elveszest jelent, mert nincs, aki
 * ujrakerje:
 *
 *   - e-mail-csere: a `syncEmailChange()` a `previousEmail` mezot a level ELOTT
 *     torli, tehat a regi cim a muvelettel eltunik;
 *   - admin fioktorles: az Auth-fiok mar torolve van, a cim csak a memoriaban
 *     elt, es a hivas egyszer fut.
 *
 * A javitas: a cimzett rovid eletu, szerveroldali rekordba kerul, es egy
 * utemezett fuggveny korlatozott alkalommal ujraprobalja.
 *
 * Ez a teszt a `email_delivery_retry.js` tenyleges viselkedeset gyakorolja egy
 * minim, Firestore-szeru taroloval, es emellett ellenorzi a forras-invariansokat
 * (a ket hivo atadja a retry markert, a siker torli a rekordot).
 */

const retry = require('./email_delivery_retry.js');
const functionsSource = fs.readFileSync(path.join(__dirname, 'index.js'), 'utf8');

/** Minimal, Firestore-szeru tarolo a set/merge/delete muveletekhez. */
function createStore() {
  const documents = new Map();
  const collection = (name) => ({
    doc(id) {
      const key = `${name}/${id}`;
      return {
        id,
        async set(data, options = {}) {
          const previous = documents.get(key) || {};
          documents.set(key, options.merge ? { ...previous, ...data } : { ...data });
        },
        async delete() {
          documents.delete(key);
        },
        async get() {
          const value = documents.get(key);
          return { exists: value !== undefined, data: () => value };
        },
      };
    },
  });
  return { documents, collection };
}

test('a napi plafonok a híreknél és a kommenteknél is 3', () => {
  assert.equal(retry.MAX_ATTEMPTS, 3);
});

test('a kudarc utan a cimzett bekerul egy rovid eletu rekordba', async () => {
  const store = createStore();
  const id = await retry.queueIdentityNotificationRetry(store, {
    key: 'admin-deletion:abc',
    uid: 'abc',
    to: 'regi@cim.hu',
    template: 'deletion',
    reason: 'smtp-send-failed',
  });

  assert.ok(id, 'a rekord letrejon');
  const record = store.documents.get(`email_delivery_pending/${id}`);
  assert.equal(record.recipient, 'regi@cim.hu', 'a TELJES cim megmarad (nem hash)');
  assert.equal(record.template, 'deletion');
  assert.equal(record.attempts, 0);
  assert.ok(record.expiresAt instanceof Date, 'van lejarat');
  assert.ok(
    record.expiresAt.getTime() - Date.now() <= retry.RETRY_TTL_MS + 1000,
    'a lejarat a rovid TTL-en belul van',
  );
});

test('hianyzo cimzettel nem keletkezik rekord (nincs mit ujraprobalni)', async () => {
  const store = createStore();
  const id = await retry.queueIdentityNotificationRetry(store, {
    key: 'admin-deletion:abc',
    uid: 'abc',
    to: '   ',
    template: 'deletion',
  });
  assert.equal(id, null);
  assert.equal(store.documents.size, 0);
});

test('a sikeres kuldes utan a rekord (es vele a cim) torlodik', async () => {
  const store = createStore();
  const id = await retry.queueIdentityNotificationRetry(store, {
    key: 'k',
    uid: 'uid-1',
    to: 'a@b.hu',
    template: 'emailChange',
  });
  assert.equal(store.documents.size, 1);

  await retry.clearIdentityNotificationRetry(store, id);
  assert.equal(store.documents.size, 0, 'nem marad szemelyes adat a szerveren');
});

test('a kudarc noveli a kiserletek szamat es késlelteti a kovetkezot', async () => {
  const store = createStore();
  const id = await retry.queueIdentityNotificationRetry(store, {
    key: 'k',
    uid: 'uid-2',
    to: 'a@b.hu',
    template: 'deletion',
  });

  await retry.bumpIdentityNotificationRetry(store, id, { attempts: 1, reason: 'smtp' });
  const first = store.documents.get(`email_delivery_pending/${id}`);
  assert.equal(first.attempts, 1);
  assert.ok(first.nextAttemptAt instanceof Date, 'van kovetkezo idopont');

  // A masodik kudarc utan meg mindig ott a rekord (a plafon 3).
  await retry.bumpIdentityNotificationRetry(store, id, { attempts: 2, reason: 'smtp' });
  assert.equal(store.documents.get(`email_delivery_pending/${id}`).attempts, 2);
});

test('a harmadik kudarc utan feladja es torli a rekordot (nincs vegtelen proba)', async () => {
  const store = createStore();
  const id = await retry.queueIdentityNotificationRetry(store, {
    key: 'k',
    uid: 'uid-3',
    to: 'a@b.hu',
    template: 'deletion',
  });

  await retry.bumpIdentityNotificationRetry(store, id, {
    attempts: retry.MAX_ATTEMPTS,
    reason: 'smtp',
  });
  assert.equal(
    store.documents.size,
    0,
    'a plafon elerese utan a rekord torlodik, nem marad orokre',
  );
});

test('a késleltetés nonek (a masodik proba tavolabb, mint az elso)', () => {
  assert.ok(retry.nextRetryDelayMs(1) < retry.nextRetryDelayMs(2));
  assert.equal(retry.nextRetryDelayMs(3), retry.nextRetryDelayMs(2), 'a plafonon nem no tovabb');
});

test('a sablonnevek valodi levelet adnak, ismeretlen nev nem', () => {
  const templates = {
    deletionEmailTemplate: () => ({ subject: 'torles', text: 'x', html: 'x' }),
    emailChangeEmailTemplate: () => ({ subject: 'csere', text: 'y', html: 'y' }),
  };
  assert.equal(retry.resolveTemplate('deletion', templates).subject, 'torles');
  assert.equal(retry.resolveTemplate('emailChange', templates).subject, 'csere');
  assert.equal(retry.resolveTemplate('ismeretlen', templates), null);
  assert.equal(retry.resolveTemplate('', templates), null);
});

// --- Forras-invariansok ---------------------------------------------------

test('a ket ERINTETT hivo atadja a retry markert', () => {
  // Az admin torlesnek KET hivo helye van (a Cloudinary-takaritas elakadasakor
  // es a rendes uton) — mindkettonek jelolnie kell a retry-t, kulonben pont a
  // ritka agban veszne el a level.
  const occurrences = functionsSource.split('retry: { uid, template: \'deletion\' }').length - 1;
  assert.equal(occurrences, 2, 'az admin torles mindket hivo helyen jelol');

  const emailChangeStart = functionsSource.indexOf('key: `email-change:');
  assert.ok(emailChangeStart > 0);
  const emailChange = functionsSource.slice(emailChangeStart, emailChangeStart + 600);
  assert.match(emailChange, /to: profile\.previousEmail/, 'a REGI cimre megy');
  assert.match(emailChange, /retry: \{ uid, template: 'emailChange' \}/, 'van retry marker');
});

test('a felhasznalo altal KERT levelek nem kapnak retry markert (ott az ujrakeres a vedelem)', () => {
  // A `sendAuthEmail` (megerosites, jelszo-visszaallitas) szandekosan NEM ad
  // retry markert: a felhasznalo latja a hibat es ujra tudja kerni.
  const start = functionsSource.indexOf('exports.sendAuthEmail');
  const end = functionsSource.indexOf('// Article comments are accessed', start);
  const block = functionsSource.slice(start, end);
  assert.ok(!block.includes('retry:'), 'a sendAuthEmail nem jelol retry-t');
  assert.match(block, /throw new HttpsError\('unavailable'/, 'a hiba lathato a felhasznalonak');
});

test('az ujraprobalo utemezett fuggveny letezik es torli a lejart rekordokat', () => {
  assert.match(functionsSource, /exports\.retryPendingIdentityEmails = onSchedule\(/);
  assert.match(functionsSource, /schedule: 'every 10 minutes'/);
  assert.match(functionsSource, /identity_email_retry_delivered/);
  assert.match(functionsSource, /identity_email_retry_failed/);
  assert.match(functionsSource, /identity_email_retry_expired/);
});

test('a sikeres kuldes torli a retry rekordot', () => {
  assert.match(
    functionsSource,
    /await clearIdentityNotificationRetry\(db, retryPendingIdFor\(key\)\)/,
  );
});
