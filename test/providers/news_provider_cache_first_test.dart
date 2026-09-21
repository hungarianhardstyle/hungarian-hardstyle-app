import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hungarian_hardstyle_app/models/post.dart';
import 'package:hungarian_hardstyle_app/providers/news_provider.dart';
import 'package:hungarian_hardstyle_app/services/wordpress_service.dart';

/// A hírek **megjelenítési útja** és a **kifejezett frissítés** két külön út.
///
/// MÉRT OK: a WordPress REST válaszideje 0,4–2,0 s (a válasz méretétől
/// függetlenül), ezért a képernyő megnyitása, a keresés és a kategóriaváltás
/// **nem** indíthat blokkoló kört: a mentett oldal azonnal kimegy, és csak a
/// háttérben egyeztetünk. A lehúzás / frissítés ikon viszont kifejezett
/// frissítés, ott a válaszra várunk.
Post _post(int id, String title) => Post.fromJson({
  'id': id,
  'title': title,
  'excerpt': '',
  'content': '',
  'link': 'https://hungarianhardstyle.hu/?p=$id',
  'date': '2026-09-18T10:00:00',
});

PostsPage _page(List<Post> posts, {bool hasMore = false, int page = 1}) =>
    PostsPage(
      items: posts,
      page: page,
      perPage: PaginatedNewsNotifier.perPage,
      total: posts.length,
      totalPages: hasMore ? page + 1 : page,
      hasMore: hasMore,
    );

void main() {
  test('nyitáskor EGY kérés megy ki, és az sem kényszerített', () async {
    final cached = _page([_post(1, 'Mentett cikk')], hasMore: true);
    final fresh = Completer<PostsPage>();
    final calls = <bool>[];

    final notifier = PaginatedNewsNotifier(
      loadCategories: () async => const <NewsCategory>[],
      loadPage:
          ({
            required int page,
            required String search,
            required int categoryId,
            required bool forceRefresh,
          }) {
            calls.add(forceRefresh);
            if (forceRefresh) return fresh.future;
            return Future.value(cached);
          },
    );
    addTearDown(notifier.dispose);

    await Future<void>.delayed(Duration.zero);
    // ⚠️ Ez a lényeg: a megnyitás nem fizet HEAD + GET-et (két blokkoló kört),
    // csak a megjelenítési utat hívja, ami a mentett oldalt azonnal adja.
    expect(calls, [false]);
    expect(notifier.state.posts.map((post) => post.title), ['Mentett cikk']);
    expect(notifier.state.hasMore, isTrue);
    expect(notifier.state.isLoading, isFalse);
  });

  test('hideg cache-nél a töltő állapot marad, amíg nincs válasz', () async {
    final fresh = Completer<PostsPage>();

    final notifier = PaginatedNewsNotifier(
      loadCategories: () async => const <NewsCategory>[],
      loadPage:
          ({
            required int page,
            required String search,
            required int categoryId,
            required bool forceRefresh,
          }) => fresh.future,
    );
    addTearDown(notifier.dispose);

    await Future<void>.delayed(Duration.zero);
    expect(notifier.state.posts, isEmpty);
    expect(notifier.state.isLoading, isTrue);

    fresh.complete(_page([_post(3, 'Első cikk')]));
    await Future<void>.delayed(Duration.zero);
    expect(notifier.state.posts.map((post) => post.title), ['Első cikk']);
    expect(notifier.state.isLoading, isFalse);
  });

  test('a kifejezett frissítés KÉNYSZERÍT (lehúzás, frissítés ikon)', () async {
    final cached = _page([_post(1, 'Mentett cikk')]);
    final calls = <bool>[];

    final notifier = PaginatedNewsNotifier(
      loadCategories: () async => const <NewsCategory>[],
      loadPage:
          ({
            required int page,
            required String search,
            required int categoryId,
            required bool forceRefresh,
          }) {
            calls.add(forceRefresh);
            return Future.value(
              forceRefresh ? _page([_post(2, 'Friss cikk')]) : cached,
            );
          },
    );
    addTearDown(notifier.dispose);
    await Future<void>.delayed(Duration.zero);

    await notifier.refresh(forceRefresh: true);

    expect(calls, [false, true]);
    expect(notifier.state.posts.map((post) => post.title), ['Friss cikk']);
    expect(notifier.state.isLoading, isFalse);
  });

  test('keresés és kategóriaváltás NEM kényszerít hálózati kört', () async {
    final calls = <bool>[];
    final notifier = PaginatedNewsNotifier(
      loadCategories: () async => const <NewsCategory>[],
      loadPage:
          ({
            required int page,
            required String search,
            required int categoryId,
            required bool forceRefresh,
          }) {
            calls.add(forceRefresh);
            return Future.value(
              _page([_post(1, search.isEmpty ? 'Lista' : search)]),
            );
          },
    );
    addTearDown(notifier.dispose);
    await Future<void>.delayed(Duration.zero);
    calls.clear();

    await notifier.updateSearch('hardstyle');
    await notifier.updateCategory(4);

    expect(calls, [false, false], reason: 'egyik koppintás sem vár a hálózatra');
    expect(notifier.state.search, '');
    expect(notifier.state.selectedCategoryId, 4);
  });

  test('a háttérben beérkező friss oldal magától megjelenik', () async {
    // A megjelenítési út a mentett oldalt rajzolja, a WordPress-egyeztetést a
    // gyorsítótár végzi a háttérben. Amikor az új test megérkezett, a jelzésre
    // a lista **hálózat nélkül** újraolvasható.
    final updates = ValueNotifier<int>(0);
    addTearDown(updates.dispose);
    var freshItems = [_post(1, 'Mentett cikk')];

    final notifier = PaginatedNewsNotifier(
      contentUpdates: updates,
      loadCategories: () async => const <NewsCategory>[],
      loadPage:
          ({
            required int page,
            required String search,
            required int categoryId,
            required bool forceRefresh,
          }) => Future.value(_page(freshItems)),
    );
    addTearDown(notifier.dispose);
    await Future<void>.delayed(Duration.zero);
    expect(notifier.state.posts.single.title, 'Mentett cikk');

    // A háttérben lezajlott az egyeztetés: a mentett oldal már az új cikket adja.
    freshItems = [_post(2, 'Friss cikk')];
    updates.value++;
    await Future<void>.delayed(Duration.zero);

    expect(notifier.state.posts.single.title, 'Friss cikk');
  });

  test('a továbblapozott listát a háttérfrissítés nem írja felül', () async {
    final updates = ValueNotifier<int>(0);
    addTearDown(updates.dispose);
    var freshItems = [_post(1, 'Mentett cikk')];

    final notifier = PaginatedNewsNotifier(
      contentUpdates: updates,
      loadCategories: () async => const <NewsCategory>[],
      loadPage:
          ({
            required int page,
            required String search,
            required int categoryId,
            required bool forceRefresh,
          }) => Future.value(
            page == 1
                ? _page(freshItems, hasMore: true)
                : _page([_post(9, 'Második oldal')], page: 2),
          ),
    );
    addTearDown(notifier.dispose);
    await Future<void>.delayed(Duration.zero);
    await notifier.loadNextPage();
    expect(notifier.state.posts, hasLength(2));

    freshItems = [_post(2, 'Friss cikk')];
    updates.value++;
    await Future<void>.delayed(Duration.zero);

    expect(
      notifier.state.posts.map((post) => post.id),
      [1, 9],
      reason: 'a felhasználó listája nem ugrál a keze alatt',
    );
  });

  test('sikertelen háttérellenőrzésnél a mentett lista a képernyőn marad', () async {
    final updates = ValueNotifier<int>(0);
    addTearDown(updates.dispose);
    var fail = false;

    final notifier = PaginatedNewsNotifier(
      contentUpdates: updates,
      loadCategories: () async => const <NewsCategory>[],
      loadPage:
          ({
            required int page,
            required String search,
            required int categoryId,
            required bool forceRefresh,
          }) => fail
          ? Future<PostsPage>.error(Exception('hálózati hiba'))
          : Future.value(_page([_post(1, 'Mentett cikk')])),
    );
    addTearDown(notifier.dispose);
    await Future<void>.delayed(Duration.zero);
    fail = true;

    updates.value++;
    await Future<void>.delayed(Duration.zero);

    expect(notifier.state.posts.map((post) => post.title), ['Mentett cikk']);
    expect(notifier.state.error, isNull);
  });

  test('a jelzésre leiratkozunk a notifier eldobásakor', () async {
    final updates = ValueNotifier<int>(0);
    addTearDown(updates.dispose);
    final notifier = PaginatedNewsNotifier(
      contentUpdates: updates,
      loadCategories: () async => const <NewsCategory>[],
      loadPage:
          ({
            required int page,
            required String search,
            required int categoryId,
            required bool forceRefresh,
          }) => Future.value(_page(const [])),
    );
    await Future<void>.delayed(Duration.zero);

    notifier.dispose();
    // Eldobás után a jelzés nem hívhatja meg a notifiert (nem dob).
    updates.value++;
    await Future<void>.delayed(Duration.zero);
  });
}
