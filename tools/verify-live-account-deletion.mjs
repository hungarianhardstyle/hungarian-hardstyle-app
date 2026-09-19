#!/usr/bin/env node
/**
 * ÉLES ellenőrzés: nincs-e elakadt felhasználó-törlés, és nincs-e „szellem-profil”?
 *
 * MIÉRT: a 2026-09-19-i hiba pontosan ez volt — a `deleteCommunityUser` HTTP 200-at
 * adott, az Auth-fiók eltűnt, de a `community_profiles/<uid>` **a helyén maradt**,
 * ezért a törölt felhasználó továbbra is látszott az admin listában. A napló ezt
 * nem mutatta meg; csak az adatbázis.
 *
 * KÉT INVARIÁNS, amit mér:
 *   1. ha egy `account_deletions` rekord `pending`, akkor a profilja **nem** lehet
 *      meg (különben a takarítás félbemaradt);
 *   2. a `deleted_user_ids` és a `community_profiles` halmaza **nem fedheti
 *      egymást** (törölt felhasználónak nem lehet profilja).
 *
 * Futtatás (a repository gyökeréből):
 *   node tools/verify-live-account-deletion.mjs            # éles mérés
 *   node tools/verify-live-account-deletion.mjs --self-test # a detektor öntesztje
 *
 * Kilépési kód: 0 = minden rendben, 1 = talált elakadást/szellem-profilt.
 */
import {
  accessToken,
  createChecker,
  firestoreList,
  shortHash,
} from './lib/live-firebase.mjs';

/** A két invariáns tiszta logikája — így önteszttel is bizonyítható. */
export function analyzeDeletionState({ profiles, deletions, deletedIds }) {
  const profileIds = new Set(profiles.map((profile) => profile.id));
  const deletedIdsSet = new Set(deletedIds.map((entry) => entry.id));
  const pendingWithProfile = deletions
    .filter((entry) => String(entry.status) === 'pending' && profileIds.has(entry.id))
    .map((entry) => shortHash(entry.id));
  const ghostProfiles = profiles
    .filter((profile) => deletedIdsSet.has(profile.id))
    .map((profile) => shortHash(profile.id));
  const pending = deletions.filter((entry) => String(entry.status) === 'pending');
  return {
    profileCount: profiles.length,
    deletionCount: deletions.length,
    deletedIdCount: deletedIds.length,
    pendingCount: pending.length,
    completedCount: deletions.filter((entry) => String(entry.status) === 'completed').length,
    pendingWithProfile,
    ghostProfiles,
    clean: pendingWithProfile.length === 0 && ghostProfiles.length === 0,
  };
}

function selfTest() {
  const checker = createChecker();
  const clean = analyzeDeletionState({
    profiles: [{ id: 'uid-a' }, { id: 'uid-b' }],
    deletions: [
      { id: 'uid-c', status: 'completed' },
      { id: 'uid-d', status: 'pending' },
    ],
    deletedIds: [{ id: 'uid-c' }, { id: 'uid-d' }],
  });
  checker.check('a tiszta állapotot rendben lévőnek látja', clean.clean === true, JSON.stringify(clean));

  const stuck = analyzeDeletionState({
    profiles: [{ id: 'uid-a' }],
    deletions: [{ id: 'uid-a', status: 'pending' }],
    deletedIds: [{ id: 'uid-a' }],
  });
  checker.check('az elakadt (pending + létező profil) esetet kiszúrja', stuck.clean === false && stuck.pendingWithProfile.length === 1);

  const ghost = analyzeDeletionState({
    profiles: [{ id: 'uid-x' }],
    deletions: [{ id: 'uid-x', status: 'completed' }],
    deletedIds: [{ id: 'uid-x' }],
  });
  checker.check('a „szellem-profilt” (törölt jelző + létező profil) kiszúrja', ghost.clean === false && ghost.ghostProfiles.length === 1);

  // A mutációs bizonyíték: ha a detektor feltételeit kiiktatjuk, a fenti esetek
  // „rendben”-t adnának — vagyis a kapu valóban a lényeget méri.
  const brokenAnalyze = ({ profiles, deletions }) => ({
    clean: true,
    pendingWithProfile: [],
    ghostProfiles: [],
    profileCount: profiles.length,
    deletionCount: deletions.length,
  });
  const mutated = brokenAnalyze({ profiles: [{ id: 'uid-a' }], deletions: [{ id: 'uid-a', status: 'pending' }] });
  checker.check('a „mindig rendben” mutált változat elbukna a valódi állapoton', mutated.clean === true && stuck.clean === false);

  const code = checker.report();
  console.log(code === 0 ? 'Önteszt: a detektor mindkét hibát elkapja.' : 'Önteszt: HIBA!');
  return code;
}

async function liveCheck() {
  const checker = createChecker();
  const token = await accessToken();
  const profiles = await firestoreList('community_profiles', { token, fields: ['displayName'] });
  const deletions = await firestoreList('account_deletions', {
    token,
    fields: ['status', 'lastError', 'pendingCloudinaryAssets', 'cloudinaryRetryAfter', 'updatedAt'],
  });
  const deletedIds = await firestoreList('deleted_user_ids', { token, fields: ['deletedAt'] });

  const state = analyzeDeletionState({ profiles, deletions, deletedIds });
  console.log(
    `profiles=${state.profileCount} deletions=${state.deletionCount} (completed=${state.completedCount}, pending=${state.pendingCount}) ` +
      `deletedUserIds=${state.deletedIdCount}`,
  );
  checker.check('nincs elakadt törlés (pending rekord létező profillal)', state.pendingWithProfile.length === 0, state.pendingWithProfile.join(', '));
  checker.check('nincs szellem-profil (törölt jelző + létező profil)', state.ghostProfiles.length === 0, state.ghostProfiles.join(', '));
  for (const deletion of deletions.filter((entry) => String(entry.status) === 'pending')) {
    console.log(`  pending: ${shortHash(deletion.id)} lastError=${deletion.lastError || '-'} updatedAt=${deletion.updatedAt || '-'}`);
  }
  return checker.report();
}

// FIGYELEM: szándékosan `process.exitCode`, nem `process.exit()` — a hálózati
// kapcsolatok lezárása közben a Windows-os Node elhasal (libuv assertion).
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
