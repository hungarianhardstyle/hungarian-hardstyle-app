#!/usr/bin/env node
/**
 * Az ELVESZETT achievement-pontok visszaállítása — ÉLES, karbantartó eszköz.
 *
 * MIÉRT: a 2026-09-19 előtti működés a hír-lájk visszavonásakor **levonta** a
 * pontot, a `grant`/`revoke` párosból álló ledger-kulcs miatt pedig az újralájk
 * már nem adott újat — a felhasználó így véglegesen mínuszba került ugyanazzal
 * a cikkel (élő mérés: 19 eset, 40 pont). A mechanizmus javítva van; a
 * tulajdonos döntése szerint a **már elveszett pontokat vissza kell állítani**,
 * de a szabályok (állapot-alapú ledger, farmolás-védelem, napi plafon)
 * **maradnak**. Ez az eszköz ezt hajtja végre, két lépcsőben:
 *
 *  1. **Előnézet** (alapértelmezés): csak olvas, és megmutatja, ki mennyit kap.
 *  2. **`--confirm`**: létrehoz egy `maintenance_jobs/<id>` „munkakérést”. A
 *     pontokat **nem ez az eszköz** írja be, hanem a Cloud Function
 *     (`runAchievementRestoreJob`), a **valódi `awardAchievementPoints`**
 *     tranzakcióval — így a jelvény, az értesítés és a ledger ugyanúgy
 *     viselkedik, mint a normál működésben. A függvény azután a munkakérés
 *     `result` mezőjébe írja, mit tett (UID nélkül, visszafejthetetlen
 *     rövidítéssel).
 *
 * BIZTONSÁGI KORLÁTOK (szándékosan):
 *  * a terv **pontosan annyit** állít vissza, amennyit a ledger szerint elvettek;
 *  * a korrekció (a saját hibám: dupla `profile-complete`) külön kapcsoló;
 *  * egy futás legfeljebb `MAX_POINTS` pontot és `MAX_USERS` felhasználót
 *    érinthet — egy elromlott ledger ne tudjon tömeges változást okozni;
 *  * a művelet **idempotens**: a visszaállítás forrása fix ledger-kulcs.
 *
 * Futtatás:
 *   node tools/restore-lost-achievement-points.mjs             (előnézet)
 *   node tools/restore-lost-achievement-points.mjs --confirm   (végrehajtás)
 *   node tools/restore-lost-achievement-points.mjs --self-test (detektorok)
 * Kilépési kód: 0 = rendben, 1 = hiba/eltérés, 2 = nem futtatható.
 */
import { createRequire } from 'node:module';
import { accessToken, firestoreGet, firestoreList, firestoreSet, shortHash } from './lib/live-firebase.mjs';

const require = createRequire(import.meta.url);
// UGYANAZ a tiszta logika, amit a Cloud Function használ — nem másolat.
const { buildAchievementRestorePlan } = require('../functions/achievement-restore-plan.js');

const JOB_ID = 'restore-lost-points';
const JOB_PATH = `maintenance_jobs/${JOB_ID}`;
const MAX_POINTS = 200;
const MAX_USERS = 25;
const POLL_INTERVAL_MS = 3000;
const POLL_TIMEOUT_MS = 8 * 60 * 1000;

/** A függvényekkel egyező, visszafejthetetlen UID-rövidítés (csak összekötésre). */
export function maintenanceUidHash(uid) {
  return shortHash(`huhs-maintenance:${uid}`);
}

/** A terv emberi összegzése (tiszta → önteszttel bizonyítható). */
export function summarizePlan(plan) {
  const users = new Map();
  let restorePoints = 0;
  let correctionPoints = 0;
  for (const award of plan.restores || []) {
    restorePoints += award.delta;
    const entry = users.get(award.uid) || { uid: award.uid, restored: 0, corrected: 0, sources: 0 };
    entry.restored += award.delta;
    entry.sources += 1;
    users.set(award.uid, entry);
  }
  for (const correction of plan.corrections || []) {
    correctionPoints += correction.delta;
    const entry = users.get(correction.uid) || { uid: correction.uid, restored: 0, corrected: 0, sources: 0 };
    entry.corrected += correction.delta;
    entry.sources += 1;
    users.set(correction.uid, entry);
  }
  return {
    restores: (plan.restores || []).length,
    corrections: (plan.corrections || []).length,
    restorePoints,
    correctionPoints,
    users: [...users.values()].sort((a, b) => b.restored - a.restored),
  };
}

/**
 * Biztonsági kapu: egy elromlott (vagy rosszul olvasott) ledger ne tudjon
 * tömeges változást okozni. A korlát NEM a valós adatra van szabva — a valós
 * terv nagyságrendekkel kisebb —, hanem a „valami nagyon félrement" esetre.
 */
export function exceedsSafetyLimit(summary, { maxPoints = MAX_POINTS, maxUsers = MAX_USERS } = {}) {
  const touched = Math.abs(summary.restorePoints) + Math.abs(summary.correctionPoints);
  if (touched > maxPoints) {
    return `a terv ${touched} pontot érintene (korlát: ${maxPoints})`;
  }
  if (summary.users.length > maxUsers) {
    return `a terv ${summary.users.length} felhasználót érintene (korlát: ${maxUsers})`;
  }
  return null;
}

async function loadPlan(token) {
  const [profiles, ledger] = await Promise.all([
    firestoreList('community_profiles', { token, fields: ['displayName', 'achievementPoints'] }),
    firestoreList('achievement_ledger', {
      token,
      fields: ['uid', 'sourceKey', 'delta', 'state', 'createdAt'],
      max: 8000,
    }),
  ]);
  const plan = buildAchievementRestorePlan(ledger);
  const names = new Map(profiles.map((profile) => [profile.id, String(profile.displayName || '')]));
  const points = new Map(profiles.map((profile) => [profile.id, Number(profile.achievementPoints || 0)]));
  return { plan, names, points, profiles, ledger };
}

function printPlan(summary, names, points) {
  for (const entry of summary.users) {
    const name = names.get(entry.uid) || '(ismeretlen profil)';
    console.log(
      `  ${name} — visszaállítás +${entry.restored} pont` +
        (entry.corrected ? `, korrekció ${entry.corrected} pont` : '') +
        ` (${entry.sources} forrás, jelenleg ${points.get(entry.uid) ?? '?'} pont)`,
    );
  }
  console.log(
    `\nÖsszesen: ${summary.restores} visszaállítás (+${summary.restorePoints} pont), ` +
      `${summary.corrections} korrekció (${summary.correctionPoints} pont), ` +
      `${summary.users.length} felhasználó.`,
  );
}

function selfTest() {
  const results = [];
  const check = (label, ok, detail) => {
    results.push({ label, ok, detail });
  };
  const plan = buildAchievementRestorePlan([
    { uid: 'u1', sourceKey: 'news-like:11', delta: 2 },
    { uid: 'u1', sourceKey: 'news-like:11', delta: -2 },
    { uid: 'u1', sourceKey: 'news-like:12', delta: -2 },
    { uid: 'u2', sourceKey: 'news-like:13', delta: 2 },
    { uid: 'u2', sourceKey: 'attendance:1', delta: 10 },
    { uid: 'u2', sourceKey: 'attendance:1', delta: -10 },
    { uid: 'u3', sourceKey: 'profile-complete', delta: 30 },
    { uid: 'u3', sourceKey: 'profile-complete', delta: 30, state: 'granted' },
  ]);
  const summary = summarizePlan(plan);

  check(
    'csak a hír-lájk visszavonásából állít vissza (az esemény-léptetés nem hiba)',
    plan.restores.length === 2 &&
      plan.restores.every((award) => award.sourceKey.startsWith('news-like-restore:')) &&
      !plan.restores.some((award) => award.uid === 'u2'),
  );
  check(
    'pontosan annyit ad vissza, amennyit elvettek (2 pont / forrás, sosem több)',
    plan.restores.every((award) => award.delta === 2),
  );
  check(
    'a dupla profile-complete-ot külön korrekcióval javítja',
    plan.corrections.length === 1 && plan.corrections[0].delta === -30,
  );
  check('az összegzés a valódi pontokat mutatja', summary.restorePoints === 4 && summary.correctionPoints === -30);
  check('a biztonsági kapu a kis terven nem szól', exceedsSafetyLimit(summary) === null);
  check(
    'a biztonsági kapu a nagy terven MEGÁLLÍT (nem enged tömeges írást)',
    exceedsSafetyLimit({ restorePoints: MAX_POINTS + 2, correctionPoints: 0, users: [] }) !== null &&
      exceedsSafetyLimit({ restorePoints: 0, correctionPoints: 0, users: new Array(MAX_USERS + 1).fill({}) }) !== null,
  );
  const applied = buildAchievementRestorePlan([
    { uid: 'u1', sourceKey: 'news-like:11', delta: 2 },
    { uid: 'u1', sourceKey: 'news-like:11', delta: -2 },
    { uid: 'u1', sourceKey: 'news-like-restore:11', delta: 2, state: 'granted' },
  ]);
  check(
    'a már visszaállított pontot nem ígéri újra (az előnézet igazat mond)',
    applied.restores.length === 0,
  );

  for (const result of results) console.log(`${result.ok ? 'OK   ' : 'HIBA '} ${result.label}`);
  const failed = results.filter((result) => !result.ok).length;
  console.log('');
  console.log(`${results.length - failed}/${results.length} ellenőrzés rendben${failed ? ` — ${failed} HIBA` : ''}`);
  console.log(failed === 0 ? 'Önteszt: a detektorok működnek.' : 'Önteszt: HIBA!');
  return failed ? 1 : 0;
}

async function waitForResult(token) {
  const deadline = Date.now() + POLL_TIMEOUT_MS;
  while (Date.now() < deadline) {
    const job = await firestoreGet(JOB_PATH, { token });
    const status = String(job?.status || '');
    if (status === 'completed') return job;
    if (status === 'failed') return job;
    await new Promise((resolve) => setTimeout(resolve, POLL_INTERVAL_MS));
  }
  return null;
}

async function main() {
  const confirm = process.argv.includes('--confirm');
  const token = await accessToken();
  const { plan, names, points } = await loadPlan(token);
  const summary = summarizePlan(plan);

  console.log('=== Elveszett achievement-pontok — terv ===');
  if (summary.users.length === 0) {
    console.log('Nincs visszaállítanivaló: a ledgerben nincs olyan visszavont hír-lájk pont.');
    return 0;
  }
  printPlan(summary, names, points);

  const limit = exceedsSafetyLimit(summary);
  if (limit) {
    console.error(`\nMEGÁLLÍTVA: ${limit}. Ez a szokásosnál sokkal nagyobb változás lenne — nem nyúlok hozzá.`);
    return 2;
  }

  if (!confirm) {
    console.log('\n(Ez előnézet: **semmi nem történt**. A végrehajtáshoz: --confirm)');
    return 0;
  }

  const job = {
    kind: 'restore-lost-points',
    status: 'approved',
    applyCorrections: true,
    requestedBy: 'tools/restore-lost-achievement-points.mjs',
    plannedRestores: summary.restores,
    plannedRestoredPoints: summary.restorePoints,
    plannedCorrections: summary.corrections,
    plannedCorrectedPoints: summary.correctionPoints,
    plannedUsers: summary.users.map((entry) => ({
      uidHash: maintenanceUidHash(entry.uid),
      restored: entry.restored,
      corrected: entry.corrected,
    })),
    requestedAt: new Date().toISOString(),
  };
  await firestoreSet(JOB_PATH, job, { merge: false });
  console.log(`\nMunkakérés kiírva (${JOB_PATH}, status=approved) — a függvény most dolgozik…`);

  const finished = await waitForResult(token);
  if (!finished) {
    console.error(
      `\nNEM fejeződött be ${POLL_TIMEOUT_MS / 1000} másodpercen belül. Ellenőrizd a függvény naplóját, ` +
        `majd futtasd újra: node tools/restore-lost-achievement-points.mjs (az előnézet megmutatja, mi maradt).`,
    );
    return 2;
  }
  const result = finished.result || {};
  const byHash = new Map(summary.users.map((entry) => [maintenanceUidHash(entry.uid), entry.uid]));
  console.log(
    `\n=== Kész (${String(finished.status)}) — tervezett=${result.planned ?? '?'} ` +
      `módosult=${result.changed ?? '?'} visszaállított pont=${result.restoredPoints ?? '?'} ` +
      `korrekció=${result.correctedPoints ?? '?'} hiba=${result.failureCount ?? '?'} ===`,
  );
  for (const entry of result.users || []) {
    const uid = byHash.get(entry.uidHash) || '';
    const name = names.get(uid) || '(ismeretlen profil)';
    console.log(
      `  ${name} — visszaállítva +${entry.restored} pont` +
        (entry.corrected ? `, korrekció ${entry.corrected} pont` : ''),
    );
  }
  for (const failure of result.failures || []) {
    console.error(`  HIBA ${failure.kind} ${failure.sourceKey}: ${failure.message}`);
  }
  console.log('\nEllenőrzés: node tools/verify-achievement-points.mjs');
  return result.failureCount ? 1 : 0;
}

if (process.argv.includes('--self-test')) {
  process.exitCode = selfTest();
} else {
  main()
    .then((code) => {
      process.exitCode = code;
    })
    .catch((error) => {
      console.error(`HIBA: ${error.message}`);
      process.exitCode = 2;
    });
}
