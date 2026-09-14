import 'dart:typed_data';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:hungarian_hardstyle_app/services/community_service.dart';
import 'package:hungarian_hardstyle_app/core/errors/user_facing_error.dart';

void main() {
  test('a privát üzenetek szűrője a káromkodást maszkolja', () {
    expect(
      CommunityService.maskProfanity('Ez kurva szar, baszás, fuck és SH1T!'),
      'Ez ***** ****, ******, **** és ****!',
    );
  });

  test('a gyakori magyar és angol változatokat is maszkolja', () {
    final masked = CommunityService.maskProfanity(
      'basz buzi faszfej szarházi bitch asshole',
    );
    expect(masked, '**** **** ******* ******** ***** *******');
  });

  test('a szóközzel írt bazd meget alakot is maszkolja', () {
    expect(CommunityService.maskProfanity('bazd meget'), '**** *****');
  });

  test('a normál szöveget változatlanul hagyja', () {
    const text = 'Ez egy normális privát üzenet.';
    expect(CommunityService.maskProfanity(text), text);
  });

  test('csak Cloudinary-képnél ad thumbnail transzformációt', () {
    const cloudinary =
        'https://res.cloudinary.com/fjxo93em/image/upload/v1/avatar.jpg';
    expect(
      CommunityService.optimizedImageUrl(cloudinary, width: 96),
      contains('/image/upload/f_auto,q_auto,w_96,c_limit/v1/avatar.jpg'),
    );
    const external = 'https://example.com/avatar.jpg';
    expect(CommunityService.optimizedImageUrl(external, width: 96), external);
  });

  test('csak támogatott képfejlécet fogad el feltöltéshez', () {
    expect(
      CommunityService.isSupportedImageBytes(
        Uint8List.fromList([0xFF, 0xD8, 0xFF, 0x00]),
      ),
      isTrue,
    );
    expect(
      CommunityService.isSupportedImageBytes(
        Uint8List.fromList([0x3C, 0x73, 0x63, 0x72, 0x69, 0x70, 0x74]),
      ),
      isFalse,
    );
  });

  test('csak a saját Cloudinary képtár URL-je jelenhet meg üzenetben', () {
    expect(
      CommunityService.isSafeCloudinaryImageUrl(
        'https://res.cloudinary.com/fjxo93em/image/upload/v1/chat.jpg',
      ),
      isTrue,
    );
    expect(
      CommunityService.isSafeCloudinaryImageUrl('https://example.com/chat.jpg'),
      isFalse,
    );
  });

  test('a UID-cache invalidálása új generációt indít', () {
    const uid = 'achievement-cache-test-user';
    final before = CommunityService.publicCacheEpochForTesting(uid);
    var notifications = 0;
    void listener() => notifications++;
    CommunityService.publicProfileRefreshGeneration.addListener(listener);
    try {
      CommunityService.clearPublicProfileCache(uid);
      expect(
        CommunityService.publicCacheEpochForTesting(uid),
        greaterThan(before),
      );
      expect(notifications, 1);
    } finally {
      CommunityService.publicProfileRefreshGeneration.removeListener(listener);
    }
  });

  test('a lokalizált Auth StateError nem alakul generikus üzenetté', () {
    expect(
      userFacingError(StateError('Ez az e-mail-cím már használatban van.')),
      'Ez az e-mail-cím már használatban van.',
    );
  });

  test('ismeretlen Auth hiba nem szivárogtat belső részletet', () {
    expect(
      userFacingError(Exception('internal credential payload')),
      'Belső szolgáltatási hiba történt. Próbáld újra később.',
    );
  });

  test('az e-mail-regisztráció közvetlen Auth-művelettel indul', () {
    final source = File('lib/services/community_service.dart')
        .readAsStringSync();
    final start = source.indexOf('Future<void> register(');
    final end = source.indexOf('Future<String> getMyReferralCode()', start);
    expect(start, greaterThanOrEqualTo(0));
    final registerSource = source.substring(start, end);
    expect(registerSource, contains('createUserWithEmailAndPassword'));
    expect(registerSource, contains('checkRegistrationEligibility'));
  });

  test('SMTP-hiba előtt az e-mail-regisztráció menti a nevet és szerepkört', () {
    final source = File('lib/services/community_service.dart').readAsStringSync();
    final start = source.indexOf('Future<void> register(');
    final end = source.indexOf('Future<String> getMyReferralCode()', start);
    final registerSource = source.substring(start, end);
    expect(registerSource.indexOf("'role': accountRole"), greaterThanOrEqualTo(0));
    expect(registerSource.indexOf("'role': accountRole"),
        lessThan(registerSource.indexOf("'sendAuthEmail'")));
  });

  test('a Google-belépés a hiányos profilt a profilbefejezésre hagyja', () {
    final source = File('lib/services/community_service.dart')
        .readAsStringSync();
    expect(source, contains('if (!profileComplete)'));
    expect(source, contains('clearProfileCache(user.uid);'));
    expect(source, contains('return true;'));
    expect(source, isNot(contains('requestDisplayName')));
  });

  test('a névfoglalás után a kliens nem írja újra a védett nevet', () {
    final source = File('lib/services/community_service.dart')
        .readAsStringSync();
    final start = source.indexOf('Future<void> register(');
    final end = source.indexOf('Future<String> getMyReferralCode()', start);
    final registerSource = source.substring(start, end);
    final profileWrite = registerSource.substring(
      registerSource.indexOf('await profileRef.set({'),
      registerSource.indexOf(
        '}, SetOptions(merge: true));',
        registerSource.indexOf('await profileRef.set({'),
      ),
    );
    expect(profileWrite, isNot(contains("'displayName'")));
  });

  test('az olvasó profilfejléc a szerveresen visszaigazolt nevet mutatja', () {
    final source = File('lib/screens/community/community_screen.dart')
        .readAsStringSync();
    final start = source.indexOf('List<Widget> _readOnlyProfileWidgets');
    final headerStart = source.indexOf('Center(\n        child: Text(', start);
    final headerEnd = source.indexOf(
      'const SizedBox(height: 20)',
      headerStart,
    );
    final header = source.substring(headerStart, headerEnd);
    expect(header, contains('_savedProfileName.isEmpty'));
    expect(header, isNot(contains('_name.text.trim().isEmpty')));
  });

  test(
    'a Google-profilbefejezés nem Auth-regisztrációs hibaként tér vissza',
    () {
      final source = File('lib/services/community_service.dart')
          .readAsStringSync();
      final start = source.indexOf('final profile = firestore.collection');
      final end = source.indexOf('await _ensureAdminProfile(user);', start);
      final profileFlow = source.substring(start, end);
      expect(profileFlow, contains('if (!profileComplete)'));
      expect(profileFlow, contains('return true;'));
    },
  );

  test('Google-profilnév nem készül e-mail-címből', () {
    final source = File('lib/services/community_service.dart')
        .readAsStringSync();
    expect(source, isNot(contains('emailDisplayName')));
    expect(source, contains('account.displayName'));
    expect(source, contains('savedNameIsValid'));
  });

  test(
    'új Google-fióknál a valid displayName a névfoglalási úton mentődik',
    () {
      final source = File('lib/services/community_service.dart')
          .readAsStringSync();
      final start = source.indexOf('Future<bool> signInWithGoogle(');
      final end = source.indexOf(
        '\n    } on FirebaseAuthException catch',
        start,
      );
      final flow = source.substring(start, end);
      expect(flow, isNot(contains('isNewAuthAccount && !profileComplete')));
      expect(flow, contains('bootstrapGoogleProfile('));
      expect(flow, contains('account.displayName'));
      expect(flow, contains('claimDisplayName: claimDisplayName'));
      expect(flow, contains('final requiredRole = accountRole(role)'));
    },
  );

  test('Google Auth metaadat nem írhatja felül a közösségi profilt', () {
    final source = File('lib/screens/community/community_screen.dart')
        .readAsStringSync();
    expect(source, contains('uploadedImage?.url ??'));
    expect(source, contains('_service.resolveProfileImage(data);'));
    expect(source, isNot(contains('resolveProfileImage(data, user.photoURL')));
    expect(source, isNot(contains("user.displayName ?? 'HUHS user'")));
  });

  test('Google-profil az account válaszának e-mailjét menti, nem Firebase UID-t', () {
    final source = File('lib/services/community_service.dart')
        .readAsStringSync();
    final start = source.indexOf('Future<bool> signInWithGoogle(');
    final end = source.indexOf('Future<void> signOut()', start);
    final googleFlow = source.substring(start, end);
    expect(googleFlow, contains('final googleEmail = account.email'));
    expect(googleFlow, contains("'email': googleEmail"));
  });

  test('adminlista nem ír ki Firebase UID-t e-mail helyett', () {
    final source = File('lib/screens/community/community_screen.dart')
        .readAsStringSync();
    final start = source.indexOf("final email = (data['email'] as String? ?? '').trim();");
    final emailTextStart = source.indexOf('Text(\n                                email.isEmpty', start);
    final end = source.indexOf('),\n                              TextButton(', emailTextStart);
    final adminEmailRow = source.substring(emailTextStart, end);
    expect(adminEmailRow, contains("'E-mail-cím nem érhető el'"));
    expect(adminEmailRow, isNot(contains('?? doc.id')));
  });

  test('névfoglalás után a profil- és nyilvános cache érvénytelenedik', () {
    final source = File('lib/services/community_service.dart')
        .readAsStringSync();
    final start = source.indexOf('Future<void> claimDisplayName');
    final end = source.indexOf('Future<void> signIn(', start);
    final claimSource = source.substring(start, end);
    expect(claimSource, contains('clearProfileCache(uid)'));
    expect(claimSource, contains('clearPublicProfileCache(uid)'));
  });

  test('hiányos profil nem kap profilbefejezési jutalmat', () {
    final source = File('lib/services/community_service.dart')
        .readAsStringSync();
    final start = source.indexOf('void _cacheProfileRoleFromSnapshot(');
    final end = source.indexOf('static void _storeProfileCache(', start);
    final cacheSource = source.substring(start, end);
    expect(cacheSource, contains('if (!profileIsComplete) return;'));
    expect(
      cacheSource,
      contains('unawaited(_claimProfileCompletionAchievement())'),
    );
  });

  test('profilbefejezés előtt a név validálva van', () {
    final source = File('lib/services/community_service.dart')
        .readAsStringSync();
    expect(source, contains('AUTH/claimDisplayName-invalid-argument'));
    expect(source, contains("parameters: {'displayName': value}"));
  });

  test('kijelentkezés lezárja a Firebase és Google sessiont', () {
    final source = File('lib/services/community_service.dart')
        .readAsStringSync();
    final start = source.indexOf('Future<void> signOut()');
    final end = source.indexOf('Future<void> _cacheProfileRole()', start);
    final signOutSource = source.substring(start, end);
    expect(signOutSource, contains('GoogleSignIn().signOut()'));
    expect(signOutSource, contains('await auth.signOut()'));
  });

  test('az Auth-diagnosztikai azonosító látható marad a felületi hibában', () {
    expect(
      userFacingError(StateError('AUTH/network-request-failed: hiba')),
      'AUTH/network-request-failed: hiba',
    );
  });
}
