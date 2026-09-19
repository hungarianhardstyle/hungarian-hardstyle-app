#!/usr/bin/env node
/**
 * A 15 percenkénti fiók-takarítás AZONNALI futtatása (operatív eszköz).
 *
 * MIÉRT: ha egy törlés félbemarad (pl. a Cloudinary átmenetileg hibázott), a
 * takarítás magától legfeljebb 15 percet vár — a fejlesztés/ellenőrzés közben
 * viszont hasznos azonnal lefuttatni. Ez ugyanazt a HTTP-hívást váltja ki, amit
 * az ütemező is megtesz, ezért **idempotens**: kétszer lefutva sem tesz mást,
 * mint amit amúgy is tenne (törli, aminek töröltnek kell lennie).
 *
 * BIZTONSÁG: `--confirm` nélkül **nem csinál semmit**, csak megmutatja, mi lenne.
 *
 * Futtatás:
 *   node tools/run-account-cleanup.mjs              # csak kiírja, mit tenne
 *   node tools/run-account-cleanup.mjs --confirm     # lefuttatja és megvárja
 */
import { accessToken, firestoreList, runScheduledJob } from './lib/live-firebase.mjs';

const JOB = 'firebase-schedule-cleanupIncompleteAccounts-europe-central2';

async function pendingCount(token) {
  const deletions = await firestoreList('account_deletions', { token, fields: ['status'] });
  return deletions.filter((entry) => String(entry.status) === 'pending').length;
}

(async () => {
  const token = await accessToken();
  const before = await pendingCount(token);
  console.log(`fuggoben levo torles a futtatas elott: ${before}`);

  if (!process.argv.includes('--confirm')) {
    console.log('');
    console.log('Ez egy előnézet — semmi nem történt.');
    console.log(`A tényleges futtatáshoz: node tools/run-account-cleanup.mjs --confirm`);
    return 0;
  }

  const result = await runScheduledJob(JOB, { token });
  console.log(`ütemező indítva: status=${result.status}`);
  if (result.status !== 200) {
    console.error('Az ütemező nem indult el; nézd meg a Cloud Scheduler állapotát.');
    return 1;
  }

  // A takarítás több szakaszból áll (Auth-átvizsgálás + függő rekordok), ezért
  // rövid ideig figyeljük, hogy csökken-e a függő rekordok száma.
  for (let round = 1; round <= 6; round += 1) {
    await new Promise((resolve) => setTimeout(resolve, 15_000));
    const current = await pendingCount(token);
    console.log(`  ${round * 15}s: fuggoben=${current}`);
    if (current === 0 || current < before) break;
  }
  const after = await pendingCount(token);
  console.log(`fuggoben levo torles a futtatas utan: ${after} (elotte: ${before})`);
  return after === 0 || after < before ? 0 : 1;
})()
  .then((code) => {
    process.exitCode = code;
  })
  .catch((error) => {
    console.error(`HIBA: ${error.message}`);
    process.exitCode = 2;
  });
