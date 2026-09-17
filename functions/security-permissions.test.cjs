const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const functionsSource = fs.readFileSync(path.join(__dirname, 'index.js'), 'utf8');
const rulesSource = fs.readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8');
const clientSource = fs.readFileSync(
  path.join(__dirname, '..', 'lib', 'services', 'community_service.dart'),
  'utf8',
);
const communityScreenSource = fs.readFileSync(
  path.join(__dirname, '..', 'lib', 'screens', 'community', 'community_screen.dart'),
  'utf8',
);
const startupGateSource = fs.readFileSync(
  path.join(__dirname, '..', 'lib', 'widgets', 'startup_gate.dart'),
  'utf8',
);
const sessionWatcherSource = fs.readFileSync(
  path.join(__dirname, '..', 'lib', 'widgets', 'session_watcher.dart'),
  'utf8',
);
const eventSource = fs.readFileSync(
  path.join(__dirname, '..', 'lib', 'models', 'event.dart'),
  'utf8',
);
const wordpressSource = fs.readFileSync(
  path.join(__dirname, '..', 'lib', 'services', 'wordpress_service.dart'),
  'utf8',
);

test('minden callable enforcement nélkül marad, amíg a kliens kompatibilis nem lesz', () => {
  const blocks = [...functionsSource.matchAll(
    /^exports\.(?<name>[A-Za-z0-9_]+)\s*=\s*(?<body>.*?)(?=^exports\.|(?![\s\S]))/gms,
  )].filter(({ groups }) => /https\.onCall|wordPressCall\(/.test(groups.body));
  assert.ok(blocks.length >= 44);
  assert.ok(blocks.some(({ groups }) => groups.name === 'getGameResults'));
  for (const { groups } of blocks) {
    const { name, body } = groups;
    if (body.includes('wordPressCall(')) {
      assert.match(
        functionsSource.slice(0, functionsSource.indexOf('exports.' + name)),
        /wordPressCall = \(handler\) =>\s*functions[\s\S]*?enforceAppCheck:\s*false/,
        name,
      );
    } else {
      assert.match(body, /enforceAppCheck:\s*false/, name);
      assert.doesNotMatch(body, /enforceAppCheck:\s*true/, name);
    }
  }
  assert.doesNotMatch(functionsSource, /enforceAppCheck:\s*true/);
  assert.match(functionsSource, /function requireRegisteredViewer\(context\)/);
  assert.match(functionsSource, /function isAdmin\(context, profile\)/);
});

test('connections and chat reactions are server-managed', () => {
  assert.match(functionsSource, /exports\.manageConnection\s*=/);
  assert.match(functionsSource, /exports\.toggleChatReaction\s*=/);
  assert.match(functionsSource, /exports\.publishChatPost\s*=/);
  assert.match(clientSource, /callFirebaseCallable<[^>]+>\(\s*'manageConnection'/);
  assert.match(clientSource, /callFirebaseCallable<[^>]+>\(\s*'toggleChatReaction'/);
  assert.match(clientSource, /callFirebaseCallable<[^>]+>\(\s*'publishChatPost'/);
  assert.match(
    rulesSource,
    /match \/community_profiles\/\{userId\}\/connections\/\{otherUserId\}[\s\S]*?allow write: if false;/,
  );
  assert.match(
    rulesSource,
    /match \/connection_requests\/\{requestId\}[\s\S]*?allow write: if false;/,
  );
});

test('deleted UIDs cannot return while voluntary identity deletion remains reusable', () => {
  assert.match(rulesSource, /deleted_user_ids/);
  assert.match(rulesSource, /!exists\(\/databases\/\$\(database\)\/documents\/deleted_user_ids/);
  assert.match(functionsSource, /deleted_user_ids.*doc\(uid\).*set/s);
  assert.match(rulesSource, /deleted_identity_hashes/);
  const eligibilityStart = functionsSource.indexOf('exports.checkRegistrationEligibility');
  const eligibilityEnd = functionsSource.indexOf('exports.requestEmailChange', eligibilityStart);
  const eligibilitySource = functionsSource.slice(eligibilityStart, eligibilityEnd);
  assert.match(eligibilitySource, /enforceAppCheck:\s*false/);
  assert.match(eligibilitySource, /deleted_identity_hashes/);
  assert.match(eligibilitySource, /deletedIdentityKey\(email\)/);
  assert.match(eligibilitySource, /isExplicitIdentityBan\(deletedIdentityData\)/);
  assert.match(functionsSource, /const selfDelete = uid === context\.auth\.uid/);
  assert.match(functionsSource, /deletionType: 'account-deletion'/);
  assert.match(functionsSource, /source: 'deleteCommunityUser'/);
  assert.match(functionsSource, /exports\.banCommunityIdentity/);
  assert.match(functionsSource, /reason: 'incomplete-account-cleanup'/);
  assert.match(functionsSource, /account_deletions/);
  assert.match(functionsSource, /status: cleanup\.manualCleanupRequired \? 'manual_cleanup_required' : 'completed'/);
  assert.doesNotMatch(functionsSource, /requestedBy: context\.auth\.uid/);
  assert.doesNotMatch(functionsSource, /blockDeletedIdentityRegistration/);
});

test('only explicit moderation markers block identity re-registration', () => {
  const source = functionsSource.slice(
    functionsSource.indexOf('exports.checkRegistrationEligibility'),
    functionsSource.indexOf('exports.requestEmailChange'),
  );
  assert.match(source, /isExplicitIdentityBan\(deletedIdentityData\)/);
  assert.match(source, /administrator-ban/);
  assert.match(source, /abuse/);
  assert.match(source, /deletionType.*identity-ban/);
});

test('registration checks a display name before Auth while claim stays atomic', () => {
  assert.match(functionsSource, /exports\.checkDisplayNameAvailability/);
  assert.match(functionsSource, /return \{ available: !snapshot\.exists \}/);
  assert.match(functionsSource, /exports\.claimDisplayName[\s\S]*?validatedDisplayName\(data\?\.displayName\)/);
  const registerStart = clientSource.indexOf('Future<void> register');
  const registerEnd = clientSource.indexOf('Future<String> getMyReferralCode', registerStart);
  const registerSource = clientSource.slice(registerStart, registerEnd);
  assert.ok(
    registerSource.indexOf('checkDisplayNameAvailability(displayName)') <
      registerSource.indexOf('createUserWithEmailAndPassword'),
  );
  assert.ok(
    registerSource.indexOf("'sendAuthEmail'") <
      registerSource.indexOf('if (profileError != null)'),
  );
});

test('deletion keeps ownership checks and verifies required data is gone', () => {
  const start = functionsSource.indexOf('exports.deleteCommunityUser =');
  const end = functionsSource.indexOf('exports.cleanupIncompleteAccounts', start);
  const deletionSource = functionsSource.slice(start, end);
  assert.match(deletionSource, /uid !== context\.auth\.uid/);
  assert.match(deletionSource, /auth\.deleteUser\(uid\)/);
  assert.match(deletionSource, /deleteUserReferences\(uid, profileData\)/);
  assert.match(deletionSource, /authStillExists/);
  assert.match(deletionSource, /profileStillExists/);
  assert.match(deletionSource, /Auth is already gone/);
  assert.match(deletionSource, /cleanupStatus: 'cleanup_pending'/);
  assert.match(deletionSource, /status: 'pending'/);
  for (const collection of [
    'artist_claims',
    'label_entitlements',
    'label_purchase_claims',
    'label_ad_unlocks',
    'admob_reward_transactions',
    'community_profiles',
    'private_conversations',
    'game_attempts',
    'achievement_ledger',
    'voting_votes',
    'voting_device_claims',
  ]) {
    assert.match(functionsSource, new RegExp(`collection\\('${collection}'\\)`));
  }
});

test('a pending deletion is retried after Auth deletion even when the profile remains', () => {
  const start = functionsSource.indexOf('exports.cleanupIncompleteAccounts');
  const end = functionsSource.indexOf('exports.deletePrivateConversation', start);
  const source = functionsSource.slice(start, end);
  assert.match(source, /if \(authStillExists\) continue;/);
  assert.match(source, /const profileSnapshot = await db\.collection\('community_profiles'\)\.doc\(uid\)\.get\(\);/);
  assert.match(source, /deleteUserReferences\(uid, profileSnapshot\.data\(\) \|\| \{\}\)/);
  assert.doesNotMatch(source, /if \(authStillExists \|\| .*community_profiles.*exists\(\)\) continue/);
});

test('the repository has no Firebase Realtime Database or Storage user store', () => {
  assert.doesNotMatch(
    `${functionsSource}\n${require('fs').readFileSync('lib/services/community_service.dart', 'utf8')}`,
    /FirebaseDatabase|FirebaseStorage|firebase_database|firebase_storage/,
  );
});

test('username changes are server-limited and audit logs are anonymized', () => {
  assert.match(functionsSource, /usernameChangeCount/);
  assert.match(functionsSource, /évente egyszer lehet módosítani/);
  assert.match(functionsSource, /result: 'recorded'/);
  assert.match(functionsSource, /function securityLog\(event, context\)[\s\S]{0,400}uidHash/);
  assert.doesNotMatch(functionsSource, /console\.warn\(JSON\.stringify\(\{ event, uid:/);
});

test('leaderboard is cursor-paginated and deletion removes UID-owned game attempts', () => {
  assert.match(functionsSource, /orderBy\('achievementPoints', 'desc'\)/);
  assert.match(functionsSource, /startAfter\(cursorPoints, cursorUserId\)/);
  assert.match(functionsSource, /collection\('game_attempts'\)\.where\('uid', '==', uid\)/);
  assert.match(functionsSource, /game_stats.*FieldValue\.increment\(-1/s);
});

test('public profile fallback stays Firebase-only and private notifications carry the sender', () => {
  const start = functionsSource.indexOf('exports.getPublicProfile =');
  const end = functionsSource.indexOf('async function persistPublicProfileProjection', start);
  const getPublicProfileSource = functionsSource.slice(start, end);
  assert.doesNotMatch(getPublicProfileSource, /getAchievementBadges\(/);
  assert.match(getPublicProfileSource, /publicProfileData\(profile, targetUid\)/);
  assert.match(functionsSource, /targetType, targetId, dedupeKey, senderId/);
  assert.match(functionsSource, /senderId[\s\S]{0,400}dedupeKey: `private_message:/);
});

test('cleanup nem töröl teljes fiókot lejárt e-mail-csere miatt', () => {
  assert.doesNotMatch(
    functionsSource,
    /authUser\.emailVerified && !incompleteName && !pendingEmailExpired/,
  );
  assert.match(functionsSource, /pendingEmail: FieldValue\.delete\(\)/);
  assert.match(functionsSource, /hasGoogleProvider/);
  assert.match(functionsSource, /expiresAt: FieldValue\.delete\(\)/);
  assert.match(functionsSource, /completedAt: FieldValue\.serverTimestamp\(\)/);
});

test('SMTP munkarekord párhuzamos claimje lease-szel védett', () => {
  assert.match(functionsSource, /const leaseId = crypto\.randomUUID\(\)/);
  assert.match(functionsSource, /job\.status === 'sending' && job\.leaseUntil/);
  assert.match(functionsSource, /snapshot\.data\(\)\?\.leaseId !== leaseId/);
  assert.match(functionsSource, /status: 'failed'/);
  assert.match(functionsSource, /failureStage/);
  assert.match(functionsSource, /failureResponseCode/);
  assert.match(functionsSource, /operationId/);
  assert.match(functionsSource, /deliveryType/);
  assert.match(functionsSource, /smtp_rejected/);
  assert.match(functionsSource, /new Date\(Date\.now\(\) \+ 60 \* 60 \* 1000\)/);
  assert.match(functionsSource, /recentEmailDeliveryOutcome/);
  assert.match(functionsSource, /\['already_sent', 'in_flight'\]\.includes\(delivery\.outcome\)/);
  assert.match(functionsSource, /resendDeduplicationWindowMs = 60 \* 1000/);
  assert.match(functionsSource, /deliveryType === 'auth-verification'/);
  assert.match(functionsSource, /smtpResponseCode/);
  assert.match(functionsSource, /messageId/);
});

test('blokkolt privát üzenethez nem készül értesítés', () => {
  const start = functionsSource.indexOf('exports.notifyPrivateMessage');
  const end = functionsSource.indexOf('exports.notifyChatReport', start);
  const source = functionsSource.slice(start, end);
  assert.match(source, /blockedBySender/);
  assert.match(source, /blockedByRecipient/);
  assert.match(source, /if \(blockedBySender\.exists \|\| blockedByRecipient\.exists\) return null/);
});

test('e-mail-csere tiltott identity markerrel nem engedélyezett', () => {
  const start = functionsSource.indexOf('exports.requestEmailChange');
  const end = functionsSource.indexOf('exports.syncEmailChange', start);
  const source = functionsSource.slice(start, end);
  assert.match(source, /deleted_identity_hashes/);
  assert.match(source, /isExplicitIdentityBan/);
});

test('Google-belépés előtt a kliens törli a helyi Google-sessiont', () => {
  const start = clientSource.indexOf('Future<bool> signInWithGoogle');
  const end = clientSource.indexOf('bool _isAdmin', start);
  const source = clientSource.slice(start, end);
  assert.match(source, /googleSignIn\.signOut\(\)/);
  assert.match(source, /googleSignIn\.signIn\(\)/);
});

test('a Google-regisztráció a névfoglalás után kényszerített profilfrissítést végez', () => {
  const start = communityScreenSource.indexOf('Future<void> _google()');
  const end = communityScreenSource.indexOf('void _suggestPassword', start);
  const source = communityScreenSource.slice(start, end);
  assert.match(source, /await _loadProfile\(force: true\)/);
});

test('a névfoglalás után a kényszerített profilfrissítés nem használja az üres cache-t', () => {
  assert.match(clientSource, /if \(snapshot\.exists && !forceServer\)/);
  assert.match(communityScreenSource, /await _loadProfile\(force: true\)/);
});

test('a mai eseményhez a kliens a teljes időintervallumot és az include_past választ használja', () => {
  assert.match(eventSource, /bool get isPast => isPastAt\(DateTime\.now\(\)\)/);
  assert.match(eventSource, /bool isPastAt\(DateTime now\)/);
  assert.match(wordpressSource, /'include_past': true/);
  assert.match(wordpressSource, /event\.isPast/);
});

test('a távoli Auth-törlés csak Auth-hibánál jelentkeztet ki', () => {
  assert.match(sessionWatcherSource, /refresh/);
  assert.match(clientSource, /user-not-found/);
  assert.match(clientSource, /user-disabled/);
  assert.match(sessionWatcherSource, /transport failure is not proof/);
  assert.match(
    sessionWatcherSource,
    /Timer\.periodic\(\s*const Duration\(seconds: 60\)/,
  );
  assert.match(sessionWatcherSource, /_timer\?\.cancel\(\)/);
});

test('a normál e-mail-regisztráció és az e-mail-csere nem jelentkeztet ki megerősítéskor', () => {
  const registerStart = clientSource.indexOf('Future<void> register');
  const registerEnd = clientSource.indexOf('Future<String> getMyReferralCode', registerStart);
  const registerSource = clientSource.slice(registerStart, registerEnd);
  const changeStart = clientSource.indexOf('Future<void> syncEmailChange');
  const changeEnd = clientSource.indexOf('Future<void> resendEmailVerificationForCredentials', changeStart);
  const changeSource = clientSource.slice(changeStart, changeEnd);
  assert.doesNotMatch(registerSource, /(?:auth\.)?signOut\(/);
  assert.doesNotMatch(changeSource, /(?:auth\.)?signOut\(/);
});

test('a kijelentkezéses újraküldési ág elkülönül a normál megerősítéstől', () => {
  const start = clientSource.indexOf('Future<void> resendEmailVerificationForCredentials');
  const source = clientSource.slice(
    start,
    clientSource.indexOf('Future<void> sendPasswordReset', start),
  );
  assert.match(source, /sendAuthEmail/);
  assert.match(source, /finally\s*\{\s*await auth\.signOut\(\)/s);
});
