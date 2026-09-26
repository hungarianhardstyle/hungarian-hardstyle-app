import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/models/post.dart';
import 'package:hungarian_hardstyle_app/providers/news_provider.dart';
import 'package:hungarian_hardstyle_app/services/wordpress_service.dart';

/// A HÍR-FRISSESSÉG MÉRÉSE (2026-09-26).
///
/// **A mért hiba:** a főoldal és a hírek fül listája **nem kérdezte meg** a
/// szervert, amíg az app nyitva volt. A WP-plugin a publikáláskor azonnal
/// érvényteleníti a saját cache-ét (mért éles szonda: `X-HUHS-Cache`, stabil
/// ETag, 304 a kondicionális HEAD-re — `tmp/probe-news-freshness.mjs`), a
/// szerver tehát **azonnal** a friss listát adná — az app viszont csak lehúzásra
/// (vagy újraindításra) kérdezte meg. Ez a fájl az app-oldali utat méri:
///  1. a főoldali provider **percenként** csendesen egyeztet (ETag/HEAD),
///  2. a hírek fül notifiere **percenként** csendesen egyeztet,
///  3. a háttérben kiderült változás **megjelenik** a listán (egy körben),
///  4. a lebontott képernyő nem indít több kérést.
void main() {
  Post post(int id, String title) => Post(
    id: id,
    title: title,
    content: '',
    excerpt: '',
    date: '',
    link: '',
    imageUrl: '',
    isSticky: false,
    categoryIds: const [],
    categories: const [],
    tags: const [],
    galleryId: 0,
    galleryImages: const [],
    embeds: const [],
    relatedPosts: const [],
  );

  PostsPage pageWith(List<Post> items) => PostsPage(
    items: items,
    page: 1,
    perPage: 10,
    total: items.length,
    totalPages: 1,
    hasMore: false,
  );

  group('a főoldali hírlista percenként csendesen egyeztet', () {
    /// A főoldali provider a valódi úton fut, csak a hálózat van kicserélve.
    Future<void> pumpHome(WidgetTester tester, ProviderContainer container) {
      return tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                ref.watch(newsProvider);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
    }

    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pump();
    }
    testWidgets('az ütem leteltével egyeztet, azon kívül nem', (tester) async {
      var revalidations = 0;
      final container = ProviderContainer(
        overrides: [
          latestPostsProvider.overrideWithValue(() async => [post(1, 'Cikk')]),
          newsRevalidateProvider.overrideWithValue(() async {
            revalidations++;
          }),
        ],
      );
      addTearDown(container.dispose);

      await pumpHome(tester, container);
      await tester.pump();

      expect(
        revalidations,
        0,
        reason: 'az első kirajzolás nem fizet külön egyeztetést',
      );

      await tester.pump(newsRevalidateInterval - const Duration(seconds: 1));
      expect(
        revalidations,
        0,
        reason: 'az ütem előtt nem szabad kérést indítani',
      );

      await tester.pump(const Duration(seconds: 1));
      expect(
        revalidations,
        1,
        reason: 'az ütem leteltével csendesen egyeztetni kell (ETag/HEAD)',
      );

      await tester.pump(newsRevalidateInterval);
      expect(
        revalidations,
        2,
        reason: 'az egyeztetés ismétlődik, amíg a főoldal él',
      );

      await unmount(tester);
      container.dispose();
      await tester.pump();
    });

    testWidgets('a háttérben kiderült változás megjelenik a főoldalon', (
      tester,
    ) async {
      var serverHasNewPost = false;
      final container = ProviderContainer(
        overrides: [
          latestPostsProvider.overrideWithValue(
            () async => [
              serverHasNewPost ? post(2, 'Új cikk') : post(1, 'Régi cikk'),
            ],
          ),
          newsRevalidateProvider.overrideWithValue(() async {
            // A valódi út: az ETag-egyeztetés megállapítja a változást, elmenti
            // az új testet, és jelzi a felületnek.
            serverHasNewPost = true;
            WordpressService.publicContentRefreshGeneration.value++;
          }),
        ],
      );
      addTearDown(container.dispose);

      late List<Post> shown;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                shown = ref.watch(newsProvider).valueOrNull ?? const [];
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      await tester.pump();
      expect(shown.single.id, 1);

      // A csendes egyeztetés az ütem leteltével fut le.
      await tester.pump(newsRevalidateInterval);
      await tester.pump();

      expect(
        shown.single.id,
        2,
        reason:
            'a jelzés után a főoldalnak az új cikket kell mutatnia, '
            'nem a mentett példányt',
      );

      await unmount(tester);
      container.dispose();
      await tester.pump();
    });

    test('az időzítő a provider eldobásakor megszűnik', () async {
      var ticks = 0;
      final container = ProviderContainer();
      final probe = Provider<void>((ref) {
        startNewsRevalidation(
          ref,
          () async {
            ticks++;
          },
          interval: const Duration(milliseconds: 10),
        );
      });
      container.read(probe);

      await Future<void>.delayed(const Duration(milliseconds: 35));
      expect(ticks, greaterThan(0), reason: 'az ütem ismétlődik');

      // A felület/provider lebontása: nem maradhat életben időzítő.
      container.dispose();
      final stopped = ticks;
      await Future<void>.delayed(const Duration(milliseconds: 35));
      expect(ticks, stopped, reason: 'lebontás után nem indul több kérés');
    });
  });

  group('a hírek fül notifiere percenként csendesen egyeztet', () {
    testWidgets('az ütem leteltével a jelenlegi szűrőre egyeztet', (
      tester,
    ) async {
      final revalidated = <String>[];
      final notifier = PaginatedNewsNotifier(
        loadPage:
            ({
              required int page,
              required String search,
              required int categoryId,
              required bool forceRefresh,
            }) async => pageWith(const []),
        loadCategories: () async => const [],
        revalidate: ({required String search, required int categoryId}) async {
          revalidated.add('$search|$categoryId');
        },
      );

      await tester.pump();
      expect(revalidated, isEmpty, reason: 'nyitáskor nem egyeztetünk');

      await tester.pump(newsRevalidateInterval);
      expect(
        revalidated,
        ['|0'],
        reason: 'az ütem leteltével a jelenlegi szűrőre egyeztet',
      );

      notifier.dispose();
      await tester.pump(newsRevalidateInterval * 3);
      expect(revalidated.length, 1, reason: 'lebontás után nem indul kérés');
    });

    testWidgets('a háttérben kiderült változás EGY körben megjelenik', (
      tester,
    ) async {
      // A valódi szolgáltatás szerződése: a megjelenítési út a mentett (régi)
      // listát adja, a kényszerített (`forceRefresh: true`) út viszont a
      // szerver AKTUÁLIS állapotát — pontosan ezt méri a hamis betöltő.
      var serverHasNewPost = false;
      final updates = ValueNotifier<int>(0);
      final notifier = PaginatedNewsNotifier(
        loadPage:
            ({
              required int page,
              required String search,
              required int categoryId,
              required bool forceRefresh,
            }) async => pageWith([
              if (serverHasNewPost && forceRefresh)
                post(2, 'Új cikk')
              else
                post(1, 'Régi cikk'),
            ]),
        loadCategories: () async => const [],
        contentUpdates: updates,
        revalidate: ({required String search, required int categoryId}) async {},
      );

      await tester.pump();
      expect(notifier.state.posts.single.id, 1);

      // A háttérben kiderül, hogy a szerveren már ott az új cikk.
      serverHasNewPost = true;
      updates.value++;
      await tester.pump();
      await tester.pump();

      expect(
        notifier.state.posts.single.id,
        2,
        reason:
            'a jelzés után a listának a friss tartalmat kell mutatnia '
            '(nem a mentett példányt)',
      );

      notifier.dispose();
      updates.dispose();
      await tester.pump();
    });
  });

  group('forrás-lint: a csendes egyeztetés be van kötve', () {
    final providerSource = File(
      'lib/providers/news_provider.dart',
    ).readAsStringSync();
    final serviceSource = File(
      'lib/services/wordpress_service.dart',
    ).readAsStringSync();

    test('a főoldali provider indítja az ütemezett egyeztetést', () {
      final provider = providerSource.substring(
        providerSource.indexOf('final newsProvider = FutureProvider.autoDispose'),
      );
      expect(
        provider,
        contains(
          'startNewsRevalidation(ref, ref.watch(newsRevalidateProvider))',
        ),
        reason: 'a főoldalnak indítania kell a csendes egyeztetést',
      );
      expect(
        provider,
        contains('ref.watch(latestPostsProvider)()'),
        reason: 'a betöltés a valódi (provideren át adott) úton megy',
      );
    });

    test('a hírek fül notifiere a szolgáltatás egyeztetőjét kapja', () {
      final wiring = providerSource.substring(
        providerSource.indexOf('final paginatedNewsProvider'),
      );
      expect(
        wiring,
        contains('service.revalidatePosts('),
        reason: 'a fül egyeztetése a szolgáltatás valódi útján menjen',
      );
      expect(
        wiring,
        contains('sticky: false'),
        reason: 'a fül a saját (nem kiemelt) lekérdezését egyezteti',
      );
    });

    test('a szolgáltatás a kényszerített (ETag) úton egyeztet', () {
      final body = _functionBody(serviceSource, 'revalidatePosts');
      expect(
        body,
        contains('_getHeadCached('),
        reason: 'az egyeztetés a rétegzett cache útján megy',
      );
      expect(
        body,
        contains('forceRefresh: true'),
        reason: 'csak a kényszerített út adja a szerver aktuális állapotát',
      );
      expect(
        body,
        isNot(contains('_postsCache')),
        reason: 'a csendes egyeztetés nem a feldolgozott listát olvassa',
      );
    });

    test('a háttérben beérkező változás eldobja a feldolgozott listákat', () {
      final onUpdated = serviceSource.substring(
        serviceSource.indexOf('onUpdated:'),
        serviceSource.indexOf(
          'static final ValueNotifier<int> publicContentRefreshGeneration',
        ),
      );
      expect(
        onUpdated,
        contains('_onHeadContentUpdated'),
        reason: 'a head-cache jelzését a szolgáltatásnak kell kezelnie',
      );
      final handler = _functionBody(serviceSource, '_onHeadContentUpdated');
      expect(
        handler,
        contains('_postsCache.clear()'),
        reason:
            'a mentett feldolgozott lista különben a RÉGI tartalmat adná '
            'vissza a jelzés utáni újraolvasáskor (mért kétkörös késés)',
      );
      expect(
        handler,
        contains('publicContentRefreshGeneration.value++'),
        reason: 'a felületet is értesíteni kell',
      );
    });

    test('előtérbe kerüléskor azonnal egyeztetünk', () {
      final navigation = File(
        'lib/screens/main_navigation.dart',
      ).readAsStringSync();
      final resume = navigation.substring(
        navigation.indexOf('void didChangeAppLifecycleState'),
        navigation.indexOf('Future<void> _checkForUpdate'),
      );
      expect(
        resume,
        contains('newsRevalidateProvider'),
        reason:
            'az app előtérbe kerülésekor azonnal meg kell kérdezni a '
            'szervert (a push-ra nyitott app ne várjon egy percet)',
      );
    });
  });
}

/// Egy Dart-függvény törzsének kivágása (a név utáni első `{`-től a záró
/// `}`-ig). A paraméterlistát **zárójel-számlálással** átugorja, és csak azt a
/// találatot fogadja el, amelynél a paraméterlista után **tényleges törzs**
/// következik — különben egy hívás (`revalidatePosts()`) félrevisz.
String _functionBody(String source, String name) {
  final pattern = RegExp('[A-Za-z0-9_<>,\\s]*\\b$name\\s*\\(');
  for (final declaration in pattern.allMatches(source)) {
    var index = source.indexOf('(', declaration.start);
    var depth = 0;
    while (index < source.length) {
      final char = source[index];
      if (char == '(') {
        depth++;
      } else if (char == ')') {
        depth--;
        if (depth == 0) break;
      } else if (char == "'" || char == '"') {
        index = _skipString(source, index) + 1;
        continue;
      }
      index++;
    }
    var after = index + 1;
    while (after < source.length && source[after].trim().isEmpty) {
      after++;
    }
    if (after < source.length && source.startsWith('async', after)) {
      after += 'async'.length;
      while (after < source.length && source[after].trim().isEmpty) {
        after++;
      }
    }
    if (after >= source.length || source[after] != '{') continue;
    return _bracedBlock(source, after);
  }
  throw StateError('Nincs ilyen függvénytörzs: $name');
}

String _bracedBlock(String source, int open) {
  var depth = 0;
  var cursor = open;
  var inString = false;
  var quote = '';
  while (cursor < source.length) {
    final char = source[cursor];
    if (inString) {
      if (char == r'\') {
        cursor += 2;
        continue;
      }
      if (char == quote) inString = false;
    } else if (char == "'" || char == '"') {
      inString = true;
      quote = char;
    } else if (char == '{') {
      depth++;
    } else if (char == '}') {
      depth--;
      if (depth == 0) return source.substring(open, cursor + 1);
    }
    cursor++;
  }
  throw StateError('Befejezetlen blokk');
}

int _skipString(String source, int start) {
  final quote = source[start];
  var index = start + 1;
  while (index < source.length) {
    final char = source[index];
    if (char == r'\') {
      index += 2;
      continue;
    }
    if (char == quote) return index;
    index++;
  }
  return source.length - 1;
}
