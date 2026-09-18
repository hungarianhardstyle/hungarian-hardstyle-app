const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const functionsSource = fs.readFileSync(path.join(__dirname, 'index.js'), 'utf8');
const profileScreenSource = fs.readFileSync(
  path.join(__dirname, '..', 'lib', 'screens', 'more', 'community_users_screen.dart'),
  'utf8',
);

function block(startMarker, endMarker) {
  const start = functionsSource.indexOf(startMarker);
  assert.ok(start >= 0, `hiányzó kezdet: ${startMarker}`);
  const end = functionsSource.indexOf(endMarker, start);
  assert.ok(end > start, `hiányzó vég: ${endMarker}`);
  return functionsSource.slice(start, end);
}

test('a pontozás nem írja felül a jelvényt egy WordPress-kimaradás miatt', () => {
  const award = block('async function awardAchievementPoints', 'exports.reconcileAchievementPoints');
  assert.match(award, /persistedAchievementBadge\(badges, points, storedBadge\)/);
  // A tartalék katalógusból (kép nélküli „Kezdő ütem”) nem szabad rangot képezni.
  assert.doesNotMatch(award, /badges\.filter\(\(item\) => points >= item\.min_points\)/);
});

test('a jelvény-újraszámolás és az admin-egyeztetés is megőrzi a tárolt rangot', () => {
  const refresh = block('exports.refreshAchievementBadge', 'exports.getPublicAchievement');
  assert.match(refresh, /persistedAchievementBadge\(badges, points, profile\.achievementBadge\)/);
  const reconcile = block('exports.reconcileAchievementPoints', 'function normalizeReferralCode');
  assert.match(reconcile, /persistedAchievementBadge\(badges, points, profile\.achievementBadge\)/);
  assert.doesNotMatch(reconcile, /badges\.filter\(\(item\) => points >= item\.min_points\)/);
});

test('a tartalék katalógus csak megjelenítésre használható, mentésre nem', () => {
  const helper = block('function persistedAchievementBadge', 'function sameAchievementBadge');
  assert.match(helper, /if \(!achievementCatalogIsReliable\(\)\) \{/);
  const reliability = block('function achievementCatalogIsReliable', 'function normalizedStoredBadge');
  assert.match(reliability, /Array\.isArray\(achievementBadgesCache\) && achievementBadgesCache\.length > 0/);
});

test('a pontozás csak tényleges rangváltásnál bumpolja a jelvény verzióját', () => {
  const award = block('async function awardAchievementPoints', 'exports.reconcileAchievementPoints');
  assert.match(award, /const badgeChanged = !sameAchievementBadge\(storedBadge, badge\)/);
  assert.match(award, /\.\.\.\(badgeChanged[\s\S]{0,160}achievementUpdatedAt: FieldValue\.serverTimestamp\(\)/);
});

test('a napi vetületjavítás a WordPress-katalógusból számolja újra a jelvényt', () => {
  const repair = block('exports.repairCommunityProfileProjections', 'exports.getPublicProfiles');
  assert.match(repair, /const catalog = await getAchievementBadges\(\)/);
  assert.match(repair, /publicAchievementData\(profile, catalog\)/);
  assert.match(repair, /publicProfileData\(profile, document\.id, achievement\)/);
  // A katalógus nélküli futás nem írhat rossz rangot a profilba.
  assert.match(repair, /catalogReliable \? publicAchievementData\(profile, catalog\) : null/);
});

test('a nyilvános profil a meleg katalógust használja második kérés nélkül', () => {
  const callable = block('exports.getPublicProfile = functions', 'async function persistPublicProfileProjection');
  assert.match(callable, /achievementCatalogIsReliable\(\) \? achievementBadgesCache : null/);
  assert.match(callable, /publicProfileData\(profile, targetUid, achievement\)/);
});

test('a toplista kép nélküli sora a katalógusból pótolja a jelvényt', () => {
  const leaderboard = block('exports.getAchievementLeaderboard', 'function badgeForPoints');
  assert.match(leaderboard, /if \(!badgeImageUrl && catalog\) \{/);
  assert.match(leaderboard, /publicAchievementData\(profile, catalog\)\.achievementBadge/);
});

test('a nyilvános profiladatlap kiszámoltatja a hiányzó jelvényt', () => {
  assert.match(profileScreenSource, /final projected = AchievementSummary\.fromProfile\(profile\)/);
  assert.match(profileScreenSource, /if \(projected\.badgeImageUrl\.isNotEmpty\) return projected;/);
  assert.match(
    profileScreenSource,
    /return service\.getPublicAchievement\(widget\.userId\)\.then\(/,
  );
});
