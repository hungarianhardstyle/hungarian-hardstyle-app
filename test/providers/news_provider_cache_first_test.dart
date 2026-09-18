import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:hungarian_hardstyle_app/models/post.dart';
import 'package:hungarian_hardstyle_app/providers/news_provider.dart';
import 'package:hungarian_hardstyle_app/services/wordpress_service.dart';

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
  test('a mentett oldal azonnal látszik, a hálózat csak utána frissít', () async {
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

    // The cache read resolves before the forced network call finishes.
    await Future<void>.delayed(Duration.zero);
    expect(calls, [false, true]);
    expect(notifier.state.posts.map((post) => post.title), ['Mentett cikk']);
    expect(notifier.state.hasMore, isTrue);
    // The list stays visible while the forced refresh is still running.
    expect(notifier.state.isLoading, isTrue);

    fresh.complete(_page([_post(2, 'Friss cikk')]));
    await Future<void>.delayed(Duration.zero);
    expect(notifier.state.posts.map((post) => post.title), ['Friss cikk']);
    expect(notifier.state.isLoading, isFalse);
    expect(notifier.state.error, isNull);
  });

  test('üres cache-nél a töltő állapot marad, amíg nincs válasz', () async {
    final fresh = Completer<PostsPage>();

    final notifier = PaginatedNewsNotifier(
      loadCategories: () async => const <NewsCategory>[],
      loadPage:
          ({
            required int page,
            required String search,
            required int categoryId,
            required bool forceRefresh,
          }) => forceRefresh ? fresh.future : Future.value(_page(const [])),
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

  test('sikertelen háttérfrissítésnél a mentett lista a képernyőn marad', () async {
    final cached = _page([_post(1, 'Mentett cikk')]);

    final notifier = PaginatedNewsNotifier(
      loadCategories: () async => const <NewsCategory>[],
      loadPage:
          ({
            required int page,
            required String search,
            required int categoryId,
            required bool forceRefresh,
          }) => forceRefresh
          ? Future<PostsPage>.error(Exception('hálózati hiba'))
          : Future.value(cached),
    );
    addTearDown(notifier.dispose);

    await Future<void>.delayed(Duration.zero);
    expect(notifier.state.posts.map((post) => post.title), ['Mentett cikk']);
    expect(notifier.state.isLoading, isFalse);
    expect(notifier.state.error, isNotNull);
  });

  test('keresés és kategóriaváltás továbbra is azonnal frissít', () async {
    final queries = <String>[];
    final notifier = PaginatedNewsNotifier(
      loadCategories: () async => const <NewsCategory>[],
      loadPage:
          ({
            required int page,
            required String search,
            required int categoryId,
            required bool forceRefresh,
          }) {
            queries.add(search);
            return Future.value(_page([_post(1, search.isEmpty ? 'Lista' : search)]));
          },
    );
    addTearDown(notifier.dispose);

    await Future<void>.delayed(Duration.zero);
    await notifier.updateSearch('hardstyle');
    expect(queries.last, 'hardstyle');
    expect(notifier.state.posts.single.title, 'hardstyle');
    expect(notifier.state.search, 'hardstyle');
  });
}
