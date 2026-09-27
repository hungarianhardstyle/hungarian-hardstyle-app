#!/usr/bin/env node
/**
 * A **születési dátum emlékeztető** kapcsolója (a tulajdonos döntése, 2026-09-27).
 *
 * MIÉRT KELL: a tulajdonos kérése — *„menjen ki notifybe mér kötelező a
 * születési dátum, mehet nekik mail is"*, *„a meglévő tagoknak úgyértem"* —, a
 * sorrend viszont kötött: *„természetesen majd akkor ha éles az új build"*,
 * illetve *„majd szólok ha ez kiment élesbe"*. Ezért a szerveroldali kiküldő
 * (`functions/index.js` → `exports.sendBirthDateNotices`) **élére kerül, de
 * alvó állapotban**: az `app_settings/birth_date_notice` dokumentum `enabled`
 * mezője zárja. Ez az eszköz kezeli azt a kapcsolót.
 *
 * Használat (írás csak `--confirm`-mal megy):
 *   node tools/birth-date-notice-flag.mjs --status
 *   node tools/birth-date-notice-flag.mjs --enable  --confirm
 *   node tools/birth-date-notice-flag.mjs --disable --confirm
 *   node tools/birth-date-notice-flag.mjs --run-now --confirm   # azonnali kör
 *
 * ⚠️ A `--run-now` a Cloud Scheduler `:run` hívásával indítja a telepített
 * ütemezett függvényt — ugyanazt a magot futtatja, amit a napi kör, tehát a
 * dupla kiküldés elleni védelem (determinisztikus értesítés-kulcs + a profilban
 * jelölt e-mail) itt is érvényes.
 */
import { createChecker, firestoreGet, firestoreSet, runScheduledJob } from './lib/live-firebase.mjs';

const SETTINGS_DOC = 'app_settings/birth_date_notice';
const DEFAULT_JOB = 'firebase-schedule-sendBirthDateNotices-europe-central2';

const args = process.argv.slice(2);
const has = (flag) => args.includes(flag);
const confirmed = has('--confirm');
const dryRun = has('--dry-run');
const jobName = (args.find((arg) => arg.startsWith('--job-name=')) || '').split('=')[1] || DEFAULT_JOB;

async function status() {
  const settings = await firestoreGet(SETTINGS_DOC);
  if (!settings) {
    console.log(`A kapcsoló-dokumentum még nincs meg (${SETTINGS_DOC}) — ez KIKAPCSOLT állapotot jelent.`);
    return null;
  }
  console.log(`Kapcsoló: ${SETTINGS_DOC}`);
  console.log(`  enabled: ${settings.enabled === true ? 'IGEN (kiküldés él)' : 'nem (alvó)'}`);
  console.log(`  emailLimit: ${settings.emailLimit ?? '(alapérték)'}`);
  console.log(`  lastRunAt: ${settings.lastRunAt ?? '(még nem futott)'}`);
  if (settings.lastRunSummary) {
    console.log(`  lastRunSummary: ${JSON.stringify(settings.lastRunSummary)}`);
  }
  return settings;
}

async function main() {
  const checker = createChecker();
  if (has('--status') || args.length === 0) {
    await status();
    return 0;
  }
  if (has('--enable') || has('--disable')) {
    const enabled = has('--enable');
    if (!confirmed && !dryRun) {
      console.log(`SZÁRAZ FUTÁS: a kapcsoló ${enabled ? 'BE' : 'KI'} állításához kell a --confirm.`);
      await status();
      return 0;
    }
    if (!dryRun) {
      const emailLimitArg = (args.find((arg) => arg.startsWith('--email-limit=')) || '').split('=')[1];
      const emailLimit = Number(emailLimitArg);
      const fields = { enabled, updatedAt: new Date() };
      if (Number.isFinite(emailLimit) && emailLimit > 0) fields.emailLimit = emailLimit;
      await firestoreSet(SETTINGS_DOC, fields);
    }
    checker.check(`a kapcsoló ${enabled ? 'BE' : 'KI'} állítva`, true, dryRun ? '(száraz futás)' : '');
    const settings = await status();
    checker.check(
      'a mért állapot a kértnek megfelelő',
      dryRun || (settings?.enabled === true) === enabled,
      `enabled=${settings?.enabled}`,
    );
    return checker.report();
  }
  if (has('--run-now')) {
    if (!confirmed) {
      console.log('SZÁRAZ FUTÁS: az azonnali körhöz kell a --confirm.');
      return 0;
    }
    const result = await runScheduledJob(jobName);
    checker.check(
      `a(z) ${jobName} kör elindult`,
      result.status === 200 || result.status === 204,
      `status=${result.status} ${result.body}`,
    );
    return checker.report();
  }
  console.log('Ismeretlen kapcsoló. Használat: --status | --enable | --disable | --run-now (--confirm).');
  return 1;
}

main()
  .then((code) => {
    process.exitCode = code ?? 0;
  })
  .catch((error) => {
    console.error(`HIBA: ${error?.message || error}`);
    process.exitCode = 1;
  });
