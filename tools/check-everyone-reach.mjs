#!/usr/bin/env node
/**
 * ÉLES (csak olvas): hány címzettje lenne egy „@mindenki" értesítésnek?
 *
 * MIÉRT: a tulajdonos kérése (2026-09-25): *„kéne egy @mindenki tag is, amit ha
 * beütök, kap mindenki notifyt és csak moderátor/admin használhassa"*. A
 * szerveroldali fan-out méretét előre tudni kell (a `notifications` írások
 * száma), ezért ez az eszköz megszámolja a jelölteket.
 *
 * UID-et nem ír ki. Futtatás: node tools/check-everyone-reach.mjs
 */
import { accessToken, firestoreList } from './lib/live-firebase.mjs';

/** Ebből a gyűjteményből jönnek a címzettek (a szerver is innen dolgozik). */
export const sourceCollections = ['community_profiles', 'public_profiles'];

/** Egy profilból kiolvasott, értesíthető azonosító (tiszta függvény). */
export function recipientId(row) {
  const candidates = [row.uid, row.userId, row.id, row.authUid];
  for (const candidate of candidates) {
    const value = String(candidate ?? '').trim();
    if (value) return value;
  }
  return '';
}

/** A címzettek halmaza két gyűjteményből, duplikátum nélkül (tiszta függvény). */
export function recipients(profileRows) {
  const set = new Set();
  for (const row of profileRows) {
    const id = recipientId(row);
    if (id) set.add(id);
  }
  return set;
}

export function selfTest() {
  const checks = [];
  const check = (label, ok) => checks.push({ label, ok });
  check('uid az elsődleges', recipientId({ uid: 'a', id: 'b' }) === 'a');
  check('ha nincs uid, az id-t használja', recipientId({ id: 'b' }) === 'b');
  check('üres sorból nincs címzett', recipientId({}) === '');
  const set = recipients([{ uid: 'a' }, { uid: 'a' }, { id: 'b' }, { uid: '  ' }]);
  check('duplikátum nélkül számol', set.size === 2);
  check('üres bemenet üres halmaz', recipients([]).size === 0);
  return checks;
}

async function main() {
  if (process.argv.includes('--self-test')) {
    const checks = selfTest();
    for (const check of checks) console.log(`${check.ok ? 'OK  ' : 'HIBA'} ${check.label}`);
    const failed = checks.filter((check) => !check.ok).length;
    console.log(`\n${checks.length - failed}/${checks.length} önteszt rendben`);
    return failed ? 1 : 0;
  }
  const token = await accessToken();
  const all = [];
  for (const collection of sourceCollections) {
    const rows = await firestoreList(collection, { token, max: 5000 });
    const set = recipients(rows);
    console.log(`${collection}: ${rows.length} dokumentum, ebből azonosítható: ${set.size}`);
    all.push(...set);
  }
  const unique = new Set(all);
  console.log(`\nösszes címzett (duplikátum nélkül): ${unique.size}`);
  console.log(
    unique.size > 500
      ? '⚠️ 500 felett: a fan-out-hoz kötegelt írás és plafon kell.'
      : 'A fan-out kötegelve is elmegy (500 alatt).',
  );
  return 0;
}

main()
  .then((code) => {
    process.exitCode = code;
  })
  .catch((error) => {
    console.error(`HIBA: ${error.message}`);
    process.exitCode = 2;
  });
