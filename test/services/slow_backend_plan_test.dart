import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hungarian_hardstyle_app/models/label_library.dart';
import 'package:hungarian_hardstyle_app/providers/news_provider.dart';
import 'package:hungarian_hardstyle_app/services/label_library_service.dart';
import 'package:hungarian_hardstyle_app/services/wordpress_service.dart';
import 'package:hungarian_hardstyle_app/services/wordpress_tag_cache.dart';
import 'package:hungarian_hardstyle_app/widgets/home_row_state.dart';

/// A „lassú WordPress" kör bizonyítása.
///
/// **A tulajdonos panasza (szó szerint):** *„Wordpress api lekérős dolgok
/// nagyon lassan töltenek be, a tárhely változtatása nem opció, de pl ez az új
/// megvárásolt zenéim is lassan tölt be"*.
///
/// **A mért ok:** a WordPress REST **minden** kérése 0,4–2,0 s
/// időt-az-első-bájtig, a válasz méretétől függetlenül (egy 264 bájtos válasz is
/// 2,2 s volt). Ezért a javítás nem kisebb payload, hanem: (a) kevesebb kör,
/// (b) a mentett válasz azonnali kiszolgálása háttér-egyeztetéssel, (c) soha ne
/// maradjon láthatatlan a felület, amíg várunk.
///
/// Ez a fájl a **tiszta döntéseket** és a **forrás-lintet** méri; a viselkedést
/// a `test/providers/` és a `test/services/` megfelelő fájljai fedik.
void main() {
  group('címke-név gyorsítótár (kevesebb kör)', () {
    test('a kulcs a kért azonosítók rendezett halmaza (ugyanaz a halmaz = ugyanaz a kulcs)', () {
      expect(postTagCacheKey([3, 1, 2]), postTagCacheKey([1, 2, 3]));
      expect(postTagCacheKey([2, 2, 1, 3, 1]), postTagCacheKey([1, 2, 3]));
      expect(postTagCacheKey([1, 2, 3]), 'huhs.wp.tagnames.v1.1,2,3');
    });

    test('az érvénytelen azonosítók nem kerülnek a kulcsba', () {
      expect(sortedPostTagIds([0, -5, 7]), [7]);
      expect(postTagCacheKey([0, 7]), postTagCacheKey([7]));
    });

    test('a különböző halmazok külön kulcsot kapnak (nem keverednek)', () {
      expect(postTagCacheKey([1, 2]), isNot(postTagCacheKey([1, 2, 3])));
      expect(postTagCacheKey([1]), isNot(postTagCacheKey([2])));
    });

    test('a mentés és a visszaolvasás ugyanazt adja (JSON körút)', () {
      final byId = {
        42: ['Hardstyle', 'Új cikk'],
        7: ['Interjú'],
      };

      final decoded = decodePostTagNames(
        jsonDecode(jsonEncode(encodePostTagNames(byId))),
      );

      expect(decoded, byId);
      expect(decoded[42], ['Hardstyle', 'Új cikk']);
    });

    test('az olvashatatlan mentés nem tippel (üres térkép)', () {
      expect(decodePostTagNames(null), isEmpty);
      expect(decodePostTagNames('nem térkép'), isEmpty);
      expect(decodePostTagNames({'abc': ['x']}), isEmpty);
      expect(decodePostTagNames({'5': 'nem lista'}), isEmpty);
      expect(decodePostTagNames({'5': <String>[]}), isEmpty);
      // A nem-string és az üres neveket kiszűrjük.
      expect(decodePostTagNames({
        '5': ['  ', 7, 'Valódi'],
      }), {
        5: ['Valódi'],
      });
    });

    test('a nevek csak a megtalált bejegyzéseket írják át', () {
      final posts = <Map<String, dynamic>>[
        {'id': 1, 'title': 'Egy'},
        {'id': 2, 'title': 'Kettő'},
      ];

      final result = applyPostTagNames(posts, {
        2: ['Hardstyle'],
      });

      expect(result[0].containsKey('tag_names'), isFalse);
      expect(result[1]['tag_names'], ['Hardstyle']);
      // Amit nem érintünk, az UGYANAZ az objektum marad (nincs néma átalakítás).
      expect(identical(result[0], posts[0]), isTrue);
    });
  });

  group('„Megvásárolt zenéim" gyorsítótár (a tulajdonos példája)', () {
    LabelLibraryItem item(int releaseId, List<String> variants) =>
        LabelLibraryItem.fromJson({
          'releaseId': releaseId,
          'variants': variants,
        });

    test('a fiók kulcsa UID-hoz kötött (más fiók nem örököl)', () {
      expect(
        labelLibraryCacheKey('uid-1'),
        isNot(labelLibraryCacheKey('uid-2')),
      );
      expect(labelLibraryCacheKey('uid-1'), contains('uid-1'));
      // A kulcs nem tud kilépni a saját helyéről.
      expect(labelLibraryCacheKey('../../uid'), isNot(contains('/')));
    });

    test('a mentett lista JSON körútja megőrzi a változatokat', () {
      final items = [item(12405, ['radio_wav', 'mp3_128'])];

      final stored = jsonDecode(
        jsonEncode(encodeLabelLibraryCache(items, DateTime(2026, 9, 20, 10))),
      );
      final entry = decodeLabelLibraryCache(stored);

      expect(entry, isNotNull);
      expect(entry!.items, hasLength(1));
      expect(entry.items.first.releaseId, 12405);
      expect(entry.items.first.variants, ['radio_wav', 'mp3_128']);
      expect(entry.savedAt, DateTime(2026, 9, 20, 10));
    });

    test('az olvashatatlan mentésből nem lesz lista, és nem is dob', () {
      expect(decodeLabelLibraryCache(null), isNull);
      expect(decodeLabelLibraryCache('nem térkép'), isNull);
      expect(decodeLabelLibraryCache({'savedAt': 'tegnap'})?.savedAt, isNull);
      expect(decodeLabelLibraryCache({})?.items, isEmpty);
      expect(decodeLabelLibraryItems('nem lista'), isEmpty);
    });

    test('a mentett lista NYER a hibával szemben (nem lesz üres könyvtár)', () {
      final stored = [item(12405, ['wav'])];
      expect(labelLibraryFallbackOnError(stored), same(stored));
      expect(
        labelLibraryFallbackOnError(null),
        isNull,
        reason: 'mentés nélkül a hiba megy tovább a felületnek',
      );
    });

    test('a frissesség dönti el, kell-e háttér-egyeztetés', () {
      final now = DateTime(2026, 9, 20, 12);
      expect(labelLibraryNeedsRefresh(null, now: now), isTrue);
      expect(
        labelLibraryNeedsRefresh(
          now.subtract(const Duration(hours: 6)),
          now: now,
        ),
        isTrue,
      );
      expect(labelLibraryNeedsRefresh(now, now: now), isFalse);
      expect(
        labelLibraryNeedsRefresh(
          now.subtract(const Duration(seconds: 30)),
          now: now,
        ),
        isFalse,
      );
      expect(
        labelLibraryNeedsRefresh(
          now.subtract(const Duration(minutes: 4)),
          now: now,
        ),
        isTrue,
        reason: 'a vásárlás nem maradhat percekig láthatatlan',
      );
      // A határ pontosan a frissességi ablak.
      expect(
        labelLibraryNeedsRefresh(
          now.subtract(labelLibraryCacheTtl),
          now: now,
        ),
        isTrue,
      );
    });
  });

  group('főoldali sor: skeleton vagy üres hely', () {
    test('van tartalom → a valódi kártya', () {
      expect(
        homeRowView(hasValue: true, hasContent: true, isLoading: false),
        HomeRowView.content,
      );
    });

    test('megvan a válasz, de nincs mit mutatni → a sor eltűnik', () {
      expect(
        homeRowView(hasValue: true, hasContent: false, isLoading: false),
        HomeRowView.empty,
      );
      // Frissítés közben is (a válasz már megvan): nem villan fel skeleton.
      expect(
        homeRowView(hasValue: true, hasContent: false, isLoading: true),
        HomeRowView.empty,
      );
    });

    test('még nincs válasz → a sor HELYE megmarad (nem ugrik a főoldal)', () {
      expect(
        homeRowView(hasValue: false, hasContent: false, isLoading: true),
        HomeRowView.loading,
      );
    });

    test('hiba → nem tippelünk kártyával (nincs hamis „nyitott kérdoív")', () {
      expect(
        homeRowView(hasValue: false, hasContent: false, isLoading: false),
        HomeRowView.empty,
      );
    });
  });

  group('a megosztott frissítés-jelzés nem hal meg az első scope-pal', () {
    test('a scope eldobása után a globális jelző tovább használható', () {
      // A hiba, amit ez a teszt fog: a `ChangeNotifierProvider` a scope
      // lezárásakor `dispose()`-olja, amit kapott — ha a GLOBÁLIS notifiert
      // kapja, akkor a második scope már egy eldobott notifierhez iratkozik fel.
      final first = ProviderContainer();
      first.read(publicContentRefreshProvider);
      first.dispose();

      final second = ProviderContainer();
      addTearDown(second.dispose);
      late ValueNotifier<int> mirror;
      expect(() => mirror = second.read(publicContentRefreshProvider),
          returnsNormally);

      // A jelzés átmegy a tükrön (a valódi mechanizmus működik).
      final before = mirror.value;
      WordpressService.publicContentRefreshGeneration.value++;
      expect(mirror.value, greaterThan(before));
    });
  });

  group('forrás-lint: a lassú utak megszűntek', () {
    final wordpress = File(
      'lib/services/wordpress_service.dart',
    ).readAsStringSync();
    final newsProvider = File(
      'lib/providers/news_provider.dart',
    ).readAsStringSync();
    final newsScreen = File(
      'lib/screens/news/news_screen.dart',
    ).readAsStringSync();
    final pollProvider = File(
      'lib/providers/poll_provider.dart',
    ).readAsStringSync();
    final prizeProvider = File(
      'lib/providers/prize_provider.dart',
    ).readAsStringSync();
    final homeScreen = File(
      'lib/screens/home/home_screen.dart',
    ).readAsStringSync();
    final libraryProvider = File(
      'lib/providers/label_library_provider.dart',
    ).readAsStringSync();
    final libraryService = File(
      'lib/services/label_library_service.dart',
    ).readAsStringSync();

    test('a címke-nevek a gyorsítótárból jönnek, és a hálózat csak misskor fut', () {
      final body = _functionBody(wordpress, '_hydratePostTags');

      final cacheRead = body.indexOf('_readPersistentJson(cacheKey)');
      final networkCall = body.indexOf('await _fetchPostTagNames(ids)');
      expect(cacheRead, isNonNegative, reason: 'nincs cache-olvasás');
      expect(networkCall, isNonNegative, reason: 'nincs hálózati út');
      expect(
        cacheRead,
        lessThan(networkCall),
        reason: 'a gyorsítótár-ellenőrzésnek a hálózat ELŐTT kell futnia',
      );

      // A találat útja: azonnal visszaadja a mentett neveket (nincs benne
      // hálózati hívás), viszont a lejárt értékre háttér-egyeztetést indít.
      final hitBranch = body.substring(
        body.indexOf('if (stored.isNotEmpty)'),
        networkCall,
      );
      expect(hitBranch, contains('applyPostTagNames(posts, stored)'));
      expect(
        hitBranch,
        contains('_persistentValueNeedsRefresh(cacheKey)'),
        reason: 'a lejárt mentett címkenév is egyeztetésre kerül',
      );
      expect(
        hitBranch,
        contains('_schedulePersistentRefresh('),
        reason: 'az egyeztetés a HÁTTÉRBEN fut, a kirajzolás nem vár rá',
      );
      expect(
        hitBranch,
        isNot(contains('await _fetchPostTagNames')),
        reason: 'találatnál nem mehet ki azonnali hálózati kérés',
      );
    });

    test('a címke-hálózat egy helyen van (a két út nem tud eltérni)', () {
      final fetch = _functionBody(wordpress, '_fetchPostTagNames');
      expect(fetch, contains('_dio.get('));
      expect(fetch, contains('wp-json/wp/v2/posts'));
      // A "friss" (cache-miss) út a mentett értéket is felülírja.
      final hydrate = _functionBody(wordpress, '_hydratePostTags');
      expect(hydrate, contains('_writePersistentJson(cacheKey'));
      final refresh = _functionBody(wordpress, '_refreshPostTagNames');
      expect(refresh, contains('await _fetchPostTagNames(ids)'));
      expect(refresh, contains('_writePersistentJson(cacheKey'));
    });

    test('a hírlista megnyitása NEM kényszerít, a kifejezett frissítés igen', () {
      final open = _between(
        newsProvider,
        'Future<void> _loadFirstPage()',
        'Future<void> refresh(',
      );
      expect(open, contains('refresh()'));
      expect(
        open,
        isNot(contains('forceRefresh: true')),
        reason: 'a képernyő megnyitása nem fizethet HEAD + GET-et',
      );

      final refresh = _functionBody(newsProvider, 'refresh');
      expect(
        newsProvider,
        contains('Future<void> refresh({bool forceRefresh = false})'),
        reason: 'alapból a megjelenítési út fut',
      );
      expect(refresh, contains('forceRefresh: forceRefresh'));
      expect(
        refresh,
        isNot(contains('forceRefresh: true')),
        reason: 'nincs beégetett kényszerítés',
      );

      // A lehúzás és a frissítés ikon viszont kifejezetten frissít.
      final forced = _functionBody(newsScreen, '_refreshNews');
      expect(forced, contains('.refresh(forceRefresh: true)'));
    });

    test('a keresés és a kategóriaváltás a megjelenítési úton megy', () {
      for (final name in ['updateSearch', 'updateCategory']) {
        final body = _functionBody(newsProvider, name);
        expect(body, contains('await refresh();'));
        expect(body, isNot(contains('forceRefresh: true')));
      }
    });

    test('a kérdoív megjelenítési útja nem kerüli meg a cache-t', () {
      final display = _between(
        pollProvider,
        'final activePollProvider',
        'final activePollRefreshProvider',
      );
      expect(display, contains('activePoll()'));
      expect(
        display,
        isNot(contains('bypassCache: true')),
        reason: 'a megjelenítés a mentett válaszból rajzol azonnal',
      );
      expect(
        display,
        contains('publicContentRefreshProvider'),
        reason: 'a háttérben beérkező friss válasz megjelenjen a kártyán',
      );

      final forced = _between(
        pollProvider,
        'final activePollRefreshProvider',
        '\n}\n',
      );
      expect(
        forced,
        contains('bypassCache: true'),
        reason:
            'a kifejezett frissítésnél a mentett válasz NEM dönthet '
            '(nyitás/zárás időponthoz kötött)',
      );
      expect(forced, contains('ref.invalidate(activePollProvider)'));
    });

    test('a nyeremenyjatek megjelenítési útja nem kerüli meg a cache-t', () {
      final display = _between(
        prizeProvider,
        'final activePrizeProvider',
        'final activePrizeRefreshProvider',
      );
      expect(display, contains('activePrize()'));
      expect(display, isNot(contains('bypassCache: true')));
      expect(display, contains('publicContentRefreshProvider'));

      final forced = _between(
        prizeProvider,
        'final activePrizeRefreshProvider',
        '\n}\n',
      );
      expect(
        forced,
        contains('bypassCache: true'),
        reason: 'a sorsolás után kihirdetett nyertes nem várhat tíz percet',
      );
      expect(forced, contains('ref.invalidate(activePrizeProvider)'));
    });

    test('a főoldal frissítése a kifejezett (bypass) útra kérdez', () {
      final body = _functionBody(homeScreen, '_refreshHome');
      expect(body, contains('activePollRefreshProvider'));
      expect(body, contains('activePrizeRefreshProvider'));
    });

    test('a zenetár providera életben marad, és a mentett listát kéri', () {
      expect(
        libraryProvider,
        contains('ref.keepAlive()'),
        reason: 'enélkül minden képernyő-megnyitás újra a hálózatra vár',
      );
      expect(libraryProvider, contains('load(uid: uid)'));
      expect(libraryProvider, contains('pendingRefresh'));
      // Az életben tartott állapot nem öregedhet meg: időzítő kér
      // újraszámolást, hogy egy friss vásárlás megjelenjen.
      expect(libraryProvider, contains('Timer.periodic('));
      expect(libraryProvider, contains('ref.onDispose(refreshTimer.cancel)'));
    });

    test('a zenetár szolgáltatása ELŐBB a mentést olvassa, mint a hálózatot', () {
      final body = _functionBody(libraryService, 'load');

      expect(
        libraryService,
        contains('bool forceRefresh = false'),
        reason: 'a kifejezett frissítés külön kapcsoló (a régi hívók működnek)',
      );
      expect(libraryService, contains('String? uid'));
      final cacheRead = body.indexOf('_readStored(key)');
      final networkCall = body.indexOf('_fetchFromServer()');
      expect(cacheRead, isNonNegative);
      expect(networkCall, isNonNegative);
      expect(
        cacheRead,
        lessThan(networkCall),
        reason: 'a mentett lista azonnal kimegy, a hálózat csak utána',
      );

      // A mentett lista útja a hálózatot a HÁTTÉRBEN indítja.
      final hitBranch = body.substring(
        body.indexOf('if (!forceRefresh && stored != null'),
        networkCall,
      );
      expect(hitBranch, contains('_startBackgroundRefresh(key)'));
      expect(hitBranch, contains('return stored.items'));
      expect(
        hitBranch,
        isNot(contains('await _fetchFromServer')),
        reason: 'találatnál a kirajzolás nem vár hálózatra',
      );

      // A hiba nem lesz üres könyvtár.
      expect(body, contains('labelLibraryFallbackOnError(stored?.items)'));
      expect(body, contains('rethrow'));
    });

    test('a háttér-egyeztetés hibája nem törli a mentett listát', () {
      final body = _functionBody(libraryService, '_startBackgroundRefresh');
      expect(body, contains('_fetchFromServer()'));
      expect(
        body,
        contains('if (fetched != null) await _writeStored(key, fetched);'),
        reason: 'hibánál a mentett lista marad (nem lesz üres könyvtár)',
      );
      expect(body, contains('_refreshInFlight.remove(key)'));
    });

    test('a főoldali sorok skeletonnal töltik ki a helyet', () {
      final pollWidget = File(
        'lib/widgets/poll_entry_button.dart',
      ).readAsStringSync();
      final prizeWidget = File(
        'lib/widgets/prize_entry_card.dart',
      ).readAsStringSync();
      final card = File('lib/widgets/home_action_card.dart').readAsStringSync();

      for (final source in [pollWidget, prizeWidget]) {
        expect(source, contains('homeRowView('));
        expect(source, contains('HomeRowView.loading'));
        expect(source, contains('HomeActionCardPlaceholder('));
        expect(
          source,
          isNot(contains('orElse: () => const SizedBox.shrink()')),
          reason: 'a sor nem tűnhet el, amíg a válasz úton van',
        );
      }
      expect(card, contains('class HomeActionCardPlaceholder'));
      // A skeleton ugyanazokat a margókat használja, mint a valódi kártya.
      expect(card, contains('EdgeInsets.fromLTRB(12, 12, 10, 12)'));
    });
  });

  group('a zenetár szolgáltatás viselkedése (mentés, háttér, hiba)', () {
    Map<String, dynamic> payload(List<int> ids) => {
      'items': [
        for (final id in ids)
          {
            'releaseId': id,
            'variants': ['radio_wav'],
          },
      ],
    };

    test('az első betöltés a hálózatról jön, a második a mentésből', () async {
      final store = _MemoryStore();
      var calls = 0;
      final service = LabelLibraryService(
        caller: () async {
          calls++;
          return payload([12405]);
        },
        cacheRead: store.read,
        cacheWrite: store.write,
      );

      final first = await service.load(uid: 'uid-1');
      final second = await service.load(uid: 'uid-1');

      expect(first.single.releaseId, 12405);
      expect(second.single.releaseId, 12405);
      expect(
        calls,
        1,
        reason: 'a mentett lista kiszolgálása nem hálózati kör (0,4–2,0 s)',
      );
    });

    test('a lejárt mentés a HÁTTÉRBEN egyeztet, a kirajzolás nem vár rá', () async {
      final store = _MemoryStore();
      var calls = 0;
      var networkIds = [12405];
      final service = LabelLibraryService(
        caller: () async {
          calls++;
          return payload(networkIds);
        },
        cacheRead: store.read,
        cacheWrite: store.write,
      );

      // Lejárt (6 órás) mentés, mintha tegnap nyitották volna meg a képernyőt.
      store.values[labelLibraryCacheKey('uid-1')] = jsonEncode(
        encodeLabelLibraryCache(
          [
            LabelLibraryItem.fromJson({
              'releaseId': 11111,
              'variants': ['wav'],
            }),
          ],
          DateTime.now().subtract(const Duration(hours: 6)),
        ),
      );
      networkIds = [22222];

      final shown = await service.load(uid: 'uid-1');
      expect(
        shown.single.releaseId,
        11111,
        reason: 'a mentett lista azonnal kimegy',
      );

      // A háttér-egyeztetés befejeződik, és felülírja a mentést.
      await service.pendingRefresh('uid-1');
      final next = await service.load(uid: 'uid-1');
      expect(next.single.releaseId, 22222);
      expect(calls, 1, reason: 'a friss mentés után nincs újabb kör');
    });

    test('a friss mentés nem indít háttér-egyeztetést', () async {
      final store = _MemoryStore();
      var calls = 0;
      final service = LabelLibraryService(
        caller: () async {
          calls++;
          return payload([1]);
        },
        cacheRead: store.read,
        cacheWrite: store.write,
      );
      await service.load(uid: 'uid-1');

      await service.load(uid: 'uid-1');

      expect(calls, 1);
      expect(service.pendingRefresh('uid-1'), isNull);
    });

    test('mentett listánál a hálózati hiba nem lesz üres könyvtár', () async {
      final store = _MemoryStore();
      final service = LabelLibraryService(
        caller: () async => throw StateError('hálózat'),
        cacheRead: store.read,
        cacheWrite: store.write,
      );
      store.values[labelLibraryCacheKey('uid-1')] = jsonEncode(
        encodeLabelLibraryCache(
          [
            LabelLibraryItem.fromJson({
              'releaseId': 12405,
              'variants': ['wav'],
            }),
          ],
          DateTime.now(),
        ),
      );

      // Kifejezett frissítés: a hálózat hibázik, de a mentett lista marad.
      final items = await service.load(forceRefresh: true, uid: 'uid-1');

      expect(items.single.releaseId, 12405);
    });

    test('mentés nélkül a hiba továbbmegy a felületnek', () async {
      final store = _MemoryStore();
      final service = LabelLibraryService(
        caller: () async => throw StateError('hálózat'),
        cacheRead: store.read,
        cacheWrite: store.write,
      );

      await expectLater(
        service.load(uid: 'uid-1'),
        throwsA(isA<StateError>()),
      );
    });

    test('másik fiók nem örökli a mentett listát', () async {
      final store = _MemoryStore();
      final service = LabelLibraryService(
        caller: () async => throw StateError('hálózat'),
        cacheRead: store.read,
        cacheWrite: store.write,
      );
      store.values[labelLibraryCacheKey('uid-1')] = jsonEncode(
        encodeLabelLibraryCache(
          [
            LabelLibraryItem.fromJson({
              'releaseId': 12405,
              'variants': ['wav'],
            }),
          ],
          DateTime.now(),
        ),
      );

      expect(
        await service.load(uid: 'uid-1'),
        hasLength(1),
        reason: 'a saját fiók mentése használható',
      );
      await expectLater(
        service.load(uid: 'uid-2'),
        throwsA(isA<StateError>()),
        reason: 'más fiók nem kaphatja meg a másik zenéit',
      );
    });

    test('UID nélkül nincs gyorsítótár (a régi hívók így működnek)', () async {
      final store = _MemoryStore();
      var calls = 0;
      final service = LabelLibraryService(
        caller: () async {
          calls++;
          return payload([12405]);
        },
        cacheRead: store.read,
        cacheWrite: store.write,
      );

      await service.load();
      await service.load();

      expect(calls, 2);
      expect(store.values, isEmpty);
    });
  });
}

/// Egyszerű memóriabeli tároló: a gyorsítótár viselkedése plugin nélkül mérhető.
class _MemoryStore {
  final Map<String, String> values = {};

  Future<String?> read(String key) async => values[key];

  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

/// Kiveszi a `start` és az utána következő `end` marker közötti részt.
///
/// Provider-definícióknál ez a biztos út: a `_functionBody` a **metódusokra**
/// illeszkedik, a `final xProvider = ...` alak viszont nem metódus-definíció.
String _between(String source, String start, String end) {
  final from = source.indexOf(start);
  expect(from, isNonNegative, reason: 'nincs ilyen rész: $start');
  final to = source.indexOf(end, from + start.length);
  expect(to, greaterThan(from), reason: 'nincs ilyen lezáró rész: $end');
  return source.substring(from, to);
}

/// Kiveszi egy Dart-metódus törzsét a nyitó kapcsos zárójel bezárásáig.
///
/// A minta a **definícióra** illeszkedik (sortörés + visszatérési típus + név +
/// `(`), nem a puszta névre: a `_advance(` alak a **hívási helyet** is eltalálná
/// (`unawaited(_advance())`), és akkor rossz kapcsos zárójelet párosítana.
///
/// ⚠️ A **paraméterlistát át kell ugrani**: a névvel kezdődő NÉVES paraméter
/// (`{int? startAtMs}`) kapcsos zárójele különben a metódus törzse helyett
/// találódna meg — ez a hiba 2026-09-20-án több forrás-lintet is „elhasaltatott"
/// látszólag ok nélkül. (Ugyanaz a segéd, mint a
/// `test/services/label_library_plan_test.dart`-ban.)
String _functionBody(String source, String name) {
  final match = RegExp(
    '\\n\\s*[A-Za-z_][\\w<>, ?]*\\s${RegExp.escape(name)}\\(',
  ).firstMatch(source);
  expect(match, isNotNull, reason: 'nincs ilyen tag: $name');
  final openParen = source.indexOf('(', match!.start);
  expect(
    openParen,
    isNonNegative,
    reason: '$name paraméterlistája nem található',
  );
  var parens = 0;
  var afterParams = -1;
  for (var i = openParen; i < source.length; i++) {
    final char = source[i];
    if (char == '(') parens++;
    if (char == ')') {
      parens--;
      if (parens == 0) {
        afterParams = i;
        break;
      }
    }
  }
  expect(
    afterParams,
    isNonNegative,
    reason: '$name paraméterlistája nem záródik le',
  );
  final open = source.indexOf('{', afterParams);
  expect(open, isNonNegative, reason: '$name törzse nem található');
  var depth = 0;
  for (var i = open; i < source.length; i++) {
    final char = source[i];
    if (char == '{') depth++;
    if (char == '}') {
      depth--;
      if (depth == 0) return source.substring(open + 1, i);
    }
  }
  fail('$name törzse nem záródik le');
}
