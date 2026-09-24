import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/services/async_cache_plan.dart';
import 'package:hungarian_hardstyle_app/services/async_cache_store.dart';

/// A **cache-first + háttérfrissítés** réteg mérése.
///
/// A tulajdonos kérése: *„nem lenne jobb minden ilyen adatot cacheben tárolni és
/// a hátérben frissíteni? villogás nélkül persze"*. A réteg ezt a három
/// tulajdonságot ígéri, és ezeket itt **valódi értékekkel** mérjük:
/// 1. a mentett adat **azonnal** kimegy (nem várunk a hálózatra);
/// 2. **csak változáskor** rajzolunk újra (különben villogna);
/// 3. **hiba esetén a mentett adat marad**.
void main() {
  /// Memóriabeli tároló (a `SharedPreferences` helyett).
  AsyncCacheStore memoryStore(Map<String, String> backing) {
    return AsyncCacheStore(
      read: (key) async => backing[key],
      write: (key, value) async => backing[key] = value,
      remove: (key) async => backing.remove(key),
    );
  }

  /// A háttérben futó munka „kiengedése" (a `readThroughCache` nem vár rá).
  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  group('a boríték (tiszta szabályok)', () {
    test('kódolás és dekódolás körbe megy (Map, List, null)', () {
      final at = DateTime(2026, 9, 24, 12, 30);
      final map = decodeCacheEntry(
        encodeCacheEntry(<String, Object?>{'mine': true}, at),
      );
      expect(map, isNotNull);
      expect(map!.savedAt, at);
      expect(map.payload, <String, Object?>{'mine': true});

      final list = decodeCacheEntry(encodeCacheEntry(<int>[1, 2, 3], at));
      expect(list!.payload, <int>[1, 2, 3]);

      final empty = decodeCacheEntry(encodeCacheEntry(null, at));
      expect(empty!.payload, isNull);
    });

    test('olvashatatlan vagy más verziójú mentés egyszerűen „nincs mentés"', () {
      expect(decodeCacheEntry(null), isNull);
      expect(decodeCacheEntry(''), isNull);
      expect(decodeCacheEntry('   '), isNull);
      expect(decodeCacheEntry('nem json'), isNull);
      expect(decodeCacheEntry('[1,2,3]'), isNull, reason: 'nem boríték');
      expect(
        decodeCacheEntry('{"v":99,"at":"2026-09-24T10:00:00Z","payload":1}'),
        isNull,
        reason: 'verzióeltérésnél nem találgatunk',
      );
      expect(
        decodeCacheEntry('{"v":1,"payload":1}'),
        isNull,
        reason: 'időbélyeg nélkül nincs értelme',
      );
    });

    test('az elavulás a TTL határán dől el', () {
      final saved = DateTime(2026, 9, 24, 12, 0);
      const ttl = Duration(minutes: 10);
      expect(cacheIsStale(saved, saved, ttl), isFalse);
      expect(
        cacheIsStale(saved, saved.add(const Duration(minutes: 9, seconds: 59)), ttl),
        isFalse,
      );
      expect(
        cacheIsStale(saved, saved.add(const Duration(minutes: 10)), ttl),
        isTrue,
      );
      expect(
        cacheIsStale(saved, saved.add(const Duration(hours: 5)), ttl),
        isTrue,
      );
    });

    test('a változás-összehasonlítás a tartalmat nézi, nem az azonosságot', () {
      expect(cachePayloadChanged(<String, Object?>{'a': 1}, <String, Object?>{'a': 1}), isFalse);
      expect(cachePayloadChanged(<String, Object?>{'a': 1}, <String, Object?>{'a': 2}), isTrue);
      expect(cachePayloadChanged(<int>[1, 2], <int>[1, 2]), isFalse);
      expect(cachePayloadChanged(<int>[1, 2], <int>[2, 1]), isTrue);
      expect(cachePayloadChanged(null, null), isFalse);
      expect(cachePayloadChanged(null, <String, Object?>{'a': 1}), isTrue);
    });
  });

  group('readThroughCache — a villogás nélküli betöltés', () {
    test('mentés nélkül a hálózat dönt, és mentés készül', () async {
      final backing = <String, String>{};
      var fetches = 0;
      var refreshes = 0;

      final value = await readThroughCache<String>(
        cacheKey: 'k',
        store: memoryStore(backing),
        fetch: () async {
          fetches += 1;
          return 'szerver';
        },
        encode: (value) => value,
        decode: (payload) => payload.toString(),
        refresh: () => refreshes += 1,
      );

      expect(value, 'szerver');
      expect(fetches, 1);
      expect(refreshes, 0, reason: 'az első betöltés még nem „változás"');
      expect(backing, contains('k'));
    });

    test('mentett adatnál AZONNAL a mentett érték jön (a hálózatra nem várunk)', () async {
      final backing = <String, String>{'k': encodeCacheEntry('mentett', DateTime.now())};
      var fetches = 0;
      var refreshes = 0;
      var fetchFinished = false;

      final value = await readThroughCache<String>(
        cacheKey: 'k',
        store: memoryStore(backing),
        fetch: () async {
          fetches += 1;
          await Future<void>.delayed(const Duration(milliseconds: 50));
          fetchFinished = true;
          return 'mentett';
        },
        encode: (value) => value,
        decode: (payload) => payload.toString(),
        refresh: () => refreshes += 1,
      );

      expect(value, 'mentett');
      expect(
        fetchFinished,
        isFalse,
        reason: 'a mentett értéket a hálózat befejezése ELŐTT megkaptuk',
      );
      await settle();
      expect(fetches, 1, reason: 'a háttérellenőrzés azért lefut');
      expect(refreshes, 0, reason: 'ugyanaz az adat: nem rajzolunk újra');
    });

    test('változott adatnál EGYSZER szólunk, hogy újra kell rajzolni', () async {
      final backing = <String, String>{
        'k': encodeCacheEntry(<String, Object?>{'mine': false}, DateTime.now()),
      };
      var fetches = 0;
      final refreshes = <String>[];

      final value = await readThroughCache<Map<String, Object?>>(
        cacheKey: 'k',
        store: memoryStore(backing),
        fetch: () async {
          fetches += 1;
          return <String, Object?>{'mine': true};
        },
        encode: (value) => value,
        decode: (payload) => Map<String, Object?>.from(payload as Map),
        refresh: () => refreshes.add('friss'),
      );

      expect(value, <String, Object?>{'mine': false}, reason: 'először a mentett');
      await settle();
      expect(fetches, 1);
      expect(refreshes, ['friss']);
      // A mentés már az új adatot tartalmazza.
      final stored = decodeCacheEntry(backing['k']);
      expect(stored!.payload, <String, Object?>{'mine': true});
    });

    test('a friss adat a MÁSODIK olvasásnál már azonnal jön', () async {
      final backing = <String, String>{
        'k': encodeCacheEntry(<int>[1], DateTime.now()),
      };
      final store = memoryStore(backing);

      await readThroughCache<List<int>>(
        cacheKey: 'k',
        store: store,
        fetch: () async => <int>[1, 2],
        encode: (value) => value,
        decode: (payload) => (payload as List).cast<int>(),
        refresh: () {},
      );
      await settle();
      expect(decodeCacheEntry(backing['k'])!.payload, <int>[1, 2]);

      // A második nyitás: a háttérellenőrzés ELINDUL, de a válasz nem vár rá.
      final gate = Completer<List<int>>();
      var fetchStarted = false;
      final value = await readThroughCache<List<int>>(
        cacheKey: 'k',
        store: store,
        fetch: () {
          fetchStarted = true;
          return gate.future;
        },
        encode: (value) => value,
        decode: (payload) => (payload as List).cast<int>(),
        refresh: () {},
      );

      expect(value, <int>[1, 2], reason: 'a háttérben frissült mentés');
      expect(fetchStarted, isTrue, reason: 'az egyeztetés elindult');
      gate.complete(<int>[1, 2]);
      await settle();
    });

    test('hálózati hiba esetén a MENTETT adat marad', () async {
      final saved = <String, Object?>{'mine': true};
      final backing = <String, String>{'k': encodeCacheEntry(saved, DateTime.now())};
      var refreshes = 0;

      final value = await readThroughCache<Map<String, Object?>>(
        cacheKey: 'k',
        store: memoryStore(backing),
        fetch: () async => throw StateError('nincs hálózat'),
        encode: (value) => value,
        decode: (payload) => Map<String, Object?>.from(payload as Map),
        refresh: () => refreshes += 1,
      );

      expect(value, saved);
      await settle();
      expect(refreshes, 0, reason: 'hibánál nem rajzolunk újra');
      expect(
        decodeCacheEntry(backing['k'])!.payload,
        saved,
        reason: 'a mentést sem töröljük',
      );
    });

    test('mentés NÉLKÜL viszont a hiba nem nyelődik el', () async {
      expect(
        () => readThroughCache<String>(
          cacheKey: 'k',
          store: memoryStore(<String, String>{}),
          fetch: () async => throw StateError('nincs hálózat'),
          encode: (value) => value,
          decode: (payload) => payload.toString(),
          refresh: () {},
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('elavult mentésnél a háttérellenőrzés frissíti az időbélyeget', () async {
      final old = DateTime.now().subtract(const Duration(hours: 2));
      final backing = <String, String>{'k': encodeCacheEntry('ugyanaz', old)};
      var refreshes = 0;
      var fetches = 0;

      await readThroughCache<String>(
        cacheKey: 'k',
        store: memoryStore(backing),
        ttl: const Duration(minutes: 10),
        fetch: () async {
          fetches += 1;
          return 'ugyanaz';
        },
        encode: (value) => value,
        decode: (payload) => payload.toString(),
        refresh: () => refreshes += 1,
      );
      await settle();

      expect(fetches, 1, reason: 'elavult mentés: egyeztetünk');
      expect(refreshes, 0, reason: 'de az adat ugyanaz: nincs újrarajzolás');
      expect(
        decodeCacheEntry(backing['k'])!.savedAt.isAfter(old),
        isTrue,
        reason: 'az időbélyeg frissült, ezért nem egyeztetünk minden nyitásnál',
      );
    });

    test('ha a hívó már nem él, nem szólunk vissza (nincs újrarajzolás)', () async {
      final backing = <String, String>{'k': encodeCacheEntry('régi', DateTime.now())};
      var refreshes = 0;

      await readThroughCache<String>(
        cacheKey: 'k',
        store: memoryStore(backing),
        fetch: () async => 'új',
        encode: (value) => value,
        decode: (payload) => payload.toString(),
        refresh: () => refreshes += 1,
        isCancelled: () => true,
      );
      await settle();

      expect(refreshes, 0);
      expect(
        decodeCacheEntry(backing['k'])!.payload,
        'új',
        reason: 'a mentést viszont frissítjük: a következő nyitás már az újat kapja',
      );
    });
  });
}
