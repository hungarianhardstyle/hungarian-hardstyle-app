import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/models/artist_claim_status.dart';
import 'package:hungarian_hardstyle_app/providers/cache_provider.dart';
import 'package:hungarian_hardstyle_app/providers/community_provider.dart';
import 'package:hungarian_hardstyle_app/services/async_cache_plan.dart';
import 'package:hungarian_hardstyle_app/services/async_cache_store.dart';
import 'package:hungarian_hardstyle_app/services/community_service.dart';

/// A DJ-adatlap **claim-állapotának** („ez az enyém / átvehető") azonnali
/// megjelenítése — a tulajdonos jelzése: *„sok adat lassan tölt be, pl az hogy a
/// dj adatlap az »enyém«"*.
///
/// A mért gyökér: a döntés **minden** adatlap-megnyitásnál egy callable körút
/// volt (boot + a szerveroldali privát e-mail-ellenőrzés, mérve ~1,4 s), és a sor
/// addig nem látszott. A javítás: a **mentett válasz azonnal kimegy**, a szerver
/// a háttérben egyeztet — és csak akkor rajzolunk újra, ha a döntés változott.
void main() {
  late Map<String, String> backing;

  AsyncCacheStore memoryStore() {
    return AsyncCacheStore(
      read: (key) async => backing[key],
      write: (key, value) async => backing[key] = value,
      remove: (key) async => backing.remove(key),
    );
  }

  setUp(() {
    backing = <String, String>{};
  });

  Future<void> settle() async {
    for (var i = 0; i < 6; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  ProviderContainer containerWith(
    _FakeClaimService service, {
    String? uid = 'uid-A',
  }) {
    final container = ProviderContainer(
      overrides: [
        communityServiceProvider.overrideWithValue(service),
        currentUidProvider.overrideWithValue(uid),
        asyncCacheStoreProvider.overrideWithValue(memoryStore()),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('a claim-állapot cache-first', () {
    test('mentett állapotnál AZONNAL jön a válasz (nem vár a callable-ra)', () async {
      backing[artistClaimCacheKey('uid-A', 5)] = encodeCacheEntry(
        const ArtistClaimStatus(claimed: true, mine: true, canClaim: false).toJson(),
        DateTime.now(),
      );
      final service = _FakeClaimService(
        const ArtistClaimStatus(claimed: true, mine: true, canClaim: false),
        gate: Completer<void>(),
      );
      final container = containerWith(service);

      final value = await container.read(artistClaimStatusProvider(5).future);

      expect(value.mine, isTrue);
      expect(
        service.claimStatusFinished,
        isFalse,
        reason: 'a mentett válaszból dolgozunk: a hálózat még fut',
      );
      service.gate!.complete();
      await settle();
      expect(
        service.claimStatusCalls,
        1,
        reason: 'a háttérellenőrzés viszont lefut',
      );
    });

    test('mentés nélkül a szerver dönt, és mentés készül', () async {
      final service = _FakeClaimService(
        const ArtistClaimStatus(claimed: false, mine: false, canClaim: true),
      );
      final container = containerWith(service);

      final value = await container.read(artistClaimStatusProvider(5).future);

      expect(value.canClaim, isTrue);
      expect(service.claimStatusCalls, 1);
      final stored = decodeCacheEntry(backing[artistClaimCacheKey('uid-A', 5)]);
      expect(stored, isNotNull, reason: 'a következő nyitás innen lesz azonnali');
      expect(stored!.payload, containsPair('canClaim', true));
    });

    test('ha a szerver MÁST mond, a háttérben javítjuk (és újrarajzolunk)', () async {
      backing[artistClaimCacheKey('uid-A', 5)] = encodeCacheEntry(
        const ArtistClaimStatus(claimed: false, mine: false, canClaim: true).toJson(),
        DateTime.now(),
      );
      final service = _FakeClaimService(
        const ArtistClaimStatus(claimed: true, mine: true, canClaim: false),
      );
      final container = containerWith(service);

      final first = await container.read(artistClaimStatusProvider(5).future);
      expect(first.canClaim, isTrue, reason: 'először a mentett (még régi)');

      await settle();
      final second = await container.read(artistClaimStatusProvider(5).future);
      expect(second.mine, isTrue, reason: 'a szerver döntése az erősebb');
      expect(
        decodeCacheEntry(backing[artistClaimCacheKey('uid-A', 5)])!.payload,
        containsPair('mine', true),
      );
    });

    test('a mentés a FIÓKHOZ kötött: másik fiók nem örökli', () async {
      backing[artistClaimCacheKey('uid-A', 5)] = encodeCacheEntry(
        const ArtistClaimStatus(claimed: true, mine: true, canClaim: false).toJson(),
        DateTime.now(),
      );
      final service = _FakeClaimService(
        const ArtistClaimStatus(claimed: false, mine: false, canClaim: false),
      );
      final container = containerWith(service, uid: 'uid-B');

      final value = await container.read(artistClaimStatusProvider(5).future);

      expect(value.mine, isFalse);
      expect(
        service.claimStatusCalls,
        1,
        reason: 'másik fiók: nincs mentés, a szervert kérdezzük',
      );
    });

    test('hálózati hiba esetén a MENTETT állapot marad (nincs hiba-képernyő)', () async {
      backing[artistClaimCacheKey('uid-A', 5)] = encodeCacheEntry(
        const ArtistClaimStatus(claimed: true, mine: true, canClaim: false).toJson(),
        DateTime.now(),
      );
      final service = _FakeClaimService(null); // minden hívás hibázik
      final container = containerWith(service);

      final value = await container.read(artistClaimStatusProvider(5).future);
      await settle();

      expect(value.mine, isTrue);
      expect(
        decodeCacheEntry(backing[artistClaimCacheKey('uid-A', 5)])!.payload,
        containsPair('mine', true),
        reason: 'a mentést hibánál sem töröljük',
      );
    });
  });

  group('átvétel / visszavonás után azonnal a helyes állapot', () {
    test('a tudott új állapot bekerül a mentésbe (nincs régi állapot villanás)', () async {
      await rememberArtistClaimStatus(
        uid: 'uid-A',
        artistId: 5,
        status: const ArtistClaimStatus(claimed: true, mine: true, canClaim: false),
        store: memoryStore(),
      );

      final stored = decodeCacheEntry(backing[artistClaimCacheKey('uid-A', 5)]);
      expect(stored!.payload, containsPair('mine', true));
    });

    test('az átvétel a „claimelt DJ-adatlapjaim" mentését is eldobja', () async {
      backing[claimedArtistsCacheKey('uid-A')] = encodeCacheEntry(
        <int>[1, 2],
        DateTime.now(),
      );

      await rememberArtistClaimStatus(
        uid: 'uid-A',
        artistId: 5,
        status: const ArtistClaimStatus(claimed: true, mine: true, canClaim: false),
        store: memoryStore(),
      );

      expect(
        backing.containsKey(claimedArtistsCacheKey('uid-A')),
        isFalse,
        reason: 'a lista megváltozott: a következő nyitás a szerverről kérdezze',
      );
    });
  });

  group('a profil „DJ-adatlap" szekciója is cache-first', () {
    test('mentett listánál azonnal jönnek a kártyák azonosítói', () async {
      backing[claimedArtistsCacheKey('uid-B')] = encodeCacheEntry(
        <int>[12812],
        DateTime.now(),
      );
      final service = _FakeClaimService(
        ArtistClaimStatus.unknown,
        claimedArtists: const <int>[12812, 11678],
        gate: Completer<void>(),
      );
      final container = containerWith(service);

      final value = await container.read(
        claimedArtistsOfUserProvider('uid-B').future,
      );

      expect(value, <int>[12812]);
      expect(
        service.claimedArtistsFinished,
        isFalse,
        reason: 'a mentett listából dolgozunk: a hálózat még fut',
      );

      service.gate!.complete();
      await settle();
      expect(service.claimedArtistsCalls, 1);
      expect(
        await container.read(claimedArtistsOfUserProvider('uid-B').future),
        <int>[12812, 11678],
        reason: 'a szerver friss listája átveszi a mentettet',
      );
    });
  });
}

/// A `CommunityService` **csak a két érintett metódusban** helyettesítve.
///
/// Ha a [status] `null`, minden hívás hibázik (a „nincs hálózat" eset).
/// A Firebase-függőségeket üres hamis objektumok adják (a projekt bevált mintája),
/// ezért a teszt nem igényel valódi Firebase-t.
class _FakeClaimService extends CommunityService {
  _FakeClaimService(
    this.status, {
    this.claimedArtists = const <int>[],
    this.gate,
  }) : super(auth: _FakeAuth(), firestore: _FakeFirestore());

  final ArtistClaimStatus? status;
  final List<int> claimedArtists;

  /// Ha meg van adva, a hívás addig „fut", amíg a teszt ki nem engedi — így
  /// mérhető, hogy a válasz **nem** várja meg a hálózatot.
  final Completer<void>? gate;

  int claimStatusCalls = 0;
  int claimedArtistsCalls = 0;
  bool claimStatusFinished = false;
  bool claimedArtistsFinished = false;

  @override
  Future<ArtistClaimStatus> artistClaimStatus(int artistId) async {
    claimStatusCalls += 1;
    if (gate != null) await gate!.future;
    final value = status;
    if (value == null) throw StateError('nincs hálózat');
    claimStatusFinished = true;
    return value;
  }

  @override
  Future<List<int>> claimedArtistsOfUser(String userId) async {
    claimedArtistsCalls += 1;
    if (gate != null) await gate!.future;
    claimedArtistsFinished = true;
    return claimedArtists;
  }
}

class _FakeAuth extends Fake implements FirebaseAuth {
  @override
  User? get currentUser => null;

  @override
  Stream<User?> userChanges() => Stream<User?>.value(null);
}

class _FakeFirestore extends Fake implements FirebaseFirestore {}
