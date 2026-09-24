import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/models/artist_claim_status.dart';
import 'package:hungarian_hardstyle_app/providers/cache_provider.dart';
import 'package:hungarian_hardstyle_app/providers/community_provider.dart';
import 'package:hungarian_hardstyle_app/services/async_cache_store.dart';
import 'package:hungarian_hardstyle_app/services/community_service.dart';
import 'package:hungarian_hardstyle_app/widgets/account_prefetch.dart';

/// Az **előtöltés** (a tulajdonos kérése: *„sok adat lassan tölt be"*).
///
/// A bejelentkezés után egyszer, a háttérben melegítjük a fiókhoz kötött
/// adatokat — így az első megnyitás is a **mentett** válaszból indul. A három
/// szabály, amit itt mérünk: csak olvas, egyszer fut fiókonként, és a hiba
/// nem jut el a felhasználóig.
void main() {
  setUp(() => TestWidgetsFlutterBinding.ensureInitialized());

  AsyncCacheStore memoryStore(Map<String, String> backing) => AsyncCacheStore(
    read: (key) async => backing[key],
    write: (key, value) async => backing[key] = value,
    remove: (key) async => backing.remove(key),
  );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
  }

  Widget app(_PrefetchService service, String? uid, Map<String, String> backing) {
    return ProviderScope(
      overrides: [
        communityServiceProvider.overrideWithValue(service),
        currentUidProvider.overrideWithValue(uid),
        asyncCacheStoreProvider.overrideWithValue(memoryStore(backing)),
      ],
      child: const MaterialApp(
        home: AccountPrefetch(child: Scaffold(body: Text('tartalom'))),
      ),
    );
  }

  testWidgets('a bejelentkezett fiók claim-adatait előtölti', (tester) async {
    final backing = <String, String>{};
    final service = _PrefetchService(claimed: const <int>[12812]);

    await tester.pumpWidget(app(service, 'uid-A', backing));
    await settle(tester);

    expect(service.claimedCalls, 1, reason: 'a saját lista egyszer lekérik');
    expect(
      service.claimStatusCalls,
      contains(12812),
      reason: 'a saját DJ-adatlapom claim-állapota is meleg lesz',
    );
    expect(
      backing.containsKey(artistClaimCacheKey('uid-A', 12812)),
      isTrue,
      reason: 'a mentés már megvan: a következő nyitás azonnali',
    );
    expect(
      service.profileCalls,
      1,
      reason: 'a saját profil is előmelegszik (a „Profil" képernyő azonnal rajzol)',
    );
    expect(find.text('tartalom'), findsOneWidget);
  });

  testWidgets('vendégként (UID nélkül) nem indít hívást', (tester) async {
    final service = _PrefetchService(claimed: const <int>[12812]);

    await tester.pumpWidget(app(service, null, <String, String>{}));
    await settle(tester);

    expect(service.claimedCalls, 0);
    expect(service.claimStatusCalls, isEmpty);
  });

  testWidgets('a hiba NEM jut el a felhasználóig (az előtöltés best-effort)', (
    tester,
  ) async {
    final service = _PrefetchService(claimed: const <int>[12812], failing: true);

    await tester.pumpWidget(app(service, 'uid-A', <String, String>{}));
    await settle(tester);

    expect(find.text('tartalom'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fiókonként EGYSZER fut (nem indul újra minden újrarajzolásnál)', (
    tester,
  ) async {
    final service = _PrefetchService(claimed: const <int>[12812]);

    await tester.pumpWidget(app(service, 'uid-A', <String, String>{}));
    await settle(tester);
    // Újrarajzolás ugyanazzal a fiókkal.
    await tester.pumpWidget(app(service, 'uid-A', <String, String>{}));
    await settle(tester);

    expect(service.claimedCalls, 1);
  });

  group('forrás-lint: az előtöltés be van kötve az app indulásába', () {
    test('a main.dart wrappeli a kezdőképernyőt', () {
      final main = File('lib/main.dart').readAsStringSync().replaceAll('\r\n', '\n');
      expect(main, contains('AccountPrefetch(child: const StartupGate())'));
    });

    test('az előtöltés csak olvas (nem hív író műveletet)', () {
      final source = File('lib/widgets/account_prefetch.dart')
          .readAsStringSync()
          .replaceAll('\r\n', '\n');
      expect(source, contains('claimedArtistsOfUserProvider(uid).future'));
      expect(source, contains('artistClaimStatusProvider(id).future'));
      expect(
        source,
        contains('getPublicProfile(uid)'),
        reason: 'a saját profil is előmelegszik (a képernyő azonnal rajzol)',
      );
      for (final forbidden in <String>[
        'claimArtist(',
        'releaseArtistClaim(',
        'markGamePlayed(',
        'verifyLabelPurchase',
        'firestore',
      ]) {
        expect(
          source,
          isNot(contains(forbidden)),
          reason: 'az előtöltés nem írhat és nem hozhat döntést ($forbidden)',
        );
      }
    });
  });
}

/// Csak a két érintett olvasó metódus helyettesítve.
class _PrefetchService extends CommunityService {
  _PrefetchService({required this.claimed, this.failing = false})
    : super(auth: _FakeAuth(), firestore: _FakeFirestore());

  final List<int> claimed;
  final bool failing;
  int claimedCalls = 0;
  int profileCalls = 0;
  final List<int> claimStatusCalls = <int>[];

  @override
  Future<List<int>> claimedArtistsOfUser(String userId) async {
    claimedCalls += 1;
    if (failing) throw StateError('nincs hálózat');
    return claimed;
  }

  @override
  Future<Map<String, dynamic>> getPublicProfile(
    String userId, {
    bool forceRefresh = false,
  }) async {
    profileCalls += 1;
    if (failing) throw StateError('nincs hálózat');
    return <String, dynamic>{'displayName': 'Teszt Elek'};
  }

  @override
  Future<ArtistClaimStatus> artistClaimStatus(int artistId) async {
    claimStatusCalls.add(artistId);
    if (failing) throw StateError('nincs hálózat');
    return ArtistClaimStatus.unknown;
  }
}

class _FakeAuth extends Fake implements FirebaseAuth {
  @override
  User? get currentUser => null;

  @override
  Stream<User?> userChanges() => Stream<User?>.value(null);
}

class _FakeFirestore extends Fake implements FirebaseFirestore {}
