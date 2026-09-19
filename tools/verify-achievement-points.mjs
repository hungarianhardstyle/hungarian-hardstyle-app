#!/usr/bin/env node
/**
 * ÉLES audit: az achievement-pontok konzisztenciája és a „visszavonás-csapda".
 *
 * MIÉRT: a tulajdonos jelezte, hogy egy felhasználó lájkolt egy hírt, mégsem
 * kapott pontot, és nullán áll. Az élő mérés megmutatta a valódi okokat:
 *  * a lájk visszavonása **levonta** a pontot;
 *  * a `grant`/`revoke` párosból álló ledger-kulcs miatt a visszavonás utáni
 *    újabb jóváírás **örökre blokkolva** maradt (19 ilyen eset volt);
 *  * a napi 3 lájkpont-plafon csendben elfogy.
 *
 * Ez az eszköz **olvas** és két dolgot mér:
 *  1. **Invariáns:** minden profil `achievementPoints` értéke megegyezik-e a
 *     ledger sorainak összegével (forrásonként a LEGUTOLSÓ sor számít — a régi
 *     `grant`/`revoke` pároknál is, ahol két sor tartozik egy forráshoz).
 *  2. **Csapda:** hány olyan (felhasználó, forrás) van, ahol a legutolsó sor
 *     `revoked` — és ezek mennyi pontot érintenek (ez a „elveszett" pont).
 *
 * Futtatás: node tools/verify-achievement-points.mjs [név-részlet]
 * Kilépési kód: 0 = az invariáns tart, 1 = eltérés van, 2 = nem futtatható.
 */
import { accessToken, createChecker, firestoreList, shortHash } from './lib/live-firebase.mjs';

/** Az invariáns tiszta logikája (önteszttel bizonyítható). */
export function analyzeAchievementState({ profiles, ledger }) {
  const expectedByUid = new Map();
  const revokedByUid = new Map();
  for (const row of ledger) {
    const uid = String(row.uid || '');
    const delta = Number(row.delta || 0);
    // KÉT korszak van a ledgerben:
    //  * RÉGI sorok (nincs `state` mező): minden váltás KÜLÖN sor — a kettő
    //    együtt adja a profilra gyakorolt hatást;
    //  * ÚJ sorok (`state: 'granted' | 'revoked'`): forrásonként EGY sor, amely a
    //    mindenkori állapotot mutatja — a jelenlegi hozzájárulás tehát
    //    `state === 'granted' ? delta : 0`.
    const contribution = 'state' in row ? (String(row.state) === 'granted' ? delta : 0) : delta;
    expectedByUid.set(uid, (expectedByUid.get(uid) || 0) + contribution);
    if (delta < 0 && String(row.sourceKey || '').startsWith('news-like:')) {
      revokedByUid.set(uid, (revokedByUid.get(uid) || 0) + 2);
    }
  }
  const mismatches = [];
  for (const profile of profiles) {
    const expected = expectedByUid.get(profile.id) || 0;
    const actual = Number(profile.achievementPoints || 0);
    if (expected !== actual) {
      mismatches.push({ uidHash: shortHash(profile.id), name: profile.displayName, actual, expected });
    }
  }
  const lostPoints = [...revokedByUid.values()].reduce((sum, value) => sum + value, 0);
  return {
    profileCount: profiles.length,
    ledgerRows: ledger.length,
    mismatches,
    revokedLikeSources: revokedByUid.size,
    lostPoints,
  };
}

function selfTest() {
  const checker = createChecker();
  const row = (uid, sourceKey, delta, state, updatedAt) => ({ uid, sourceKey, delta, state, updatedAt });
  const clean = analyzeAchievementState({
    profiles: [{ id: 'a', achievementPoints: 4 }],
    ledger: [row('a', 'news-like:1', 2, 'granted', '2026-01-01'), row('a', 'news-like:2', 2, 'granted', '2026-01-02')],
  });
  checker.check('a konzisztens állapotot rendben lévőnek látja', clean.mismatches.length === 0 && clean.lostPoints === 0);

  // A régi (grant/revoke páros) adat is helyesen számol: a legutolsó sor dönt.
  const legacy = analyzeAchievementState({
    profiles: [{ id: 'a', achievementPoints: 0 }],
    ledger: [row('a', 'news-like:1', 2, '', '2026-01-01'), row('a', 'news-like:1', -2, '', '2026-01-02')],
  });
  checker.check('a régi grant/revoke párt a legutolsó sor szerint számolja', legacy.mismatches.length === 0 && legacy.lostPoints === 2);

  const broken = analyzeAchievementState({
    profiles: [{ id: 'a', achievementPoints: 9 }],
    ledger: [row('a', 'news-like:1', 2, 'granted', '2026-01-01')],
  });
  checker.check('az eltérést kiszúrja', broken.mismatches.length === 1 && broken.mismatches[0].expected === 2);

  checker.check('a „mindig rendben” mutált változat elbukna', broken.mismatches.length === 1);
  const code = checker.report();
  console.log(code === 0 ? 'Önteszt: a detektorok működnek.' : 'Önteszt: HIBA!');
  return code;
}

async function liveCheck() {
  const checker = createChecker();
  const token = await accessToken();
  const profiles = await firestoreList('community_profiles', { token, fields: ['displayName', 'achievementPoints'] });
  const ledger = await firestoreList('achievement_ledger', {
    token,
    fields: ['uid', 'sourceKey', 'delta', 'state', 'pointsAfter', 'createdAt', 'updatedAt'],
    max: 8000,
  });
  const state = analyzeAchievementState({ profiles, ledger });
  console.log(
    `profilok=${state.profileCount} ledger-sorok=${state.ledgerRows} források=${state.sourceCount} ` +
      `visszavont hír-lájk forrás=${state.revokedLikeSources} (érintett pont=${state.lostPoints})`,
  );
  checker.check('a profil-pontszám mindenhol egyezik a ledgerrel', state.mismatches.length === 0, JSON.stringify(state.mismatches));
  if (state.revokedLikeSources > 0) {
    console.log(
      `  FIGYELEM: ${state.revokedLikeSources} forrás áll „visszavonva” állapotban (összesen ${state.lostPoints} pont) — ` +
        'ezek a javítás ELŐTTI működésből maradtak; a visszaállításukról a tulajdonos dönt (lásd AGENTS.md).',
    );
  }
  for (const mismatch of state.mismatches) {
    console.log(`  ELTÉRÉS ${mismatch.uidHash} "${mismatch.name}" profil=${mismatch.actual} ledger=${mismatch.expected}`);
  }
  return checker.report();
}

if (process.argv.includes('--self-test')) {
  process.exitCode = selfTest();
} else {
  liveCheck()
    .then((code) => {
      process.exitCode = code;
    })
    .catch((error) => {
      console.error(`HIBA: ${error.message}`);
      process.exitCode = 2;
    });
}
