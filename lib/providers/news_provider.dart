import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/post.dart';
import '../services/wordpress_service.dart';

final wordpressServiceProvider = Provider<WordpressService>((ref) {
  return WordpressService();
});

final publicContentRefreshProvider = ChangeNotifierProvider<ValueNotifier<int>>(
  (ref) {
    return WordpressService.publicContentRefreshGeneration;
  },
);

// Home news must be recreated after leaving the screen so a withdrawn/draft
// post cannot remain in the long-lived provider state.
final newsProvider = FutureProvider.autoDispose<List<Post>>((ref) async {
  ref.watch(publicContentRefreshProvider);
  final service = ref.watch(wordpressServiceProvider);
  return service.getLatestPosts();
});

final stickyNewsProvider = FutureProvider.autoDispose<List<Post>>((ref) async {
  ref.watch(publicContentRefreshProvider);
  final service = ref.watch(wordpressServiceProvider);
  // Pagination state changes for every loaded page. Only the filters affect
  // the sticky query; watching the whole state caused needless refetches.
  final (search, categoryId) = ref.watch(
    paginatedNewsProvider.select(
      (state) => (state.search, state.selectedCategoryId),
    ),
  );
  return service.getStickyPosts(search: search, categoryId: categoryId);
});

class PaginatedNewsState {
  final List<Post> posts;
  final List<NewsCategory> categories;
  final String search;
  final int selectedCategoryId;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final int page;
  final Object? error;

  const PaginatedNewsState({
    this.posts = const [],
    this.categories = const [],
    this.search = '',
    this.selectedCategoryId = 0,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.page = 0,
    this.error,
  });

  List<Post> get visiblePosts => posts;

  PaginatedNewsState copyWith({
    List<Post>? posts,
    List<NewsCategory>? categories,
    String? search,
    int? selectedCategoryId,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    int? page,
    Object? error,
    bool clearError = false,
  }) {
    return PaginatedNewsState(
      posts: posts ?? this.posts,
      categories: categories ?? this.categories,
      search: search ?? this.search,
      selectedCategoryId: selectedCategoryId ?? this.selectedCategoryId,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      page: page ?? this.page,
      error: clearError ? null : error ?? this.error,
    );
  }
}

/// One page of WordPress news, loaded either from the layered cache or from the
/// network. Injectable so the cache-first first paint can be tested without a
/// live WordPress instance.
typedef NewsPageLoader =
    Future<PostsPage> Function({
      required int page,
      required String search,
      required int categoryId,
      required bool forceRefresh,
    });

typedef NewsCategoriesLoader = Future<List<NewsCategory>> Function();

class PaginatedNewsNotifier extends StateNotifier<PaginatedNewsState> {
  PaginatedNewsNotifier({
    required this.loadPage,
    required this.loadCategories,
  }) : super(const PaginatedNewsState()) {
    _loadCategories();
    _loadFirstPage();
  }

  static const int perPage = 10;

  final NewsPageLoader loadPage;
  final NewsCategoriesLoader loadCategories;
  int _requestId = 0;

  Future<void> _loadCategories() async {
    final categories = await loadCategories();

    state = state.copyWith(categories: categories);
  }

  /// Cache-first first paint.
  ///
  /// The layered WordPress cache answers this call from memory or from disk and
  /// only revalidates in the background, so the last known page can be painted
  /// without waiting for the network. The forced [refresh] right after it
  /// replaces the page with the current server state. On a cold cache there is
  /// nothing to show, so the loading state stays until the first response.
  Future<void> _loadFirstPage() async {
    try {
      final cached = await _getPostsPage(page: 1);
      if (!mounted) return;
      if (cached.items.isNotEmpty && state.posts.isEmpty) {
        state = state.copyWith(
          posts: cached.items,
          isLoading: false,
          hasMore: cached.hasMore,
          page: cached.page,
          clearError: true,
        );
      }
    } catch (_) {
      // The forced refresh below surfaces the error state; a usable cache entry
      // keeps the list on screen instead of an empty error page.
    }
    if (!mounted) return;
    await refresh();
  }

  Future<void> refresh() async {
    final requestId = ++_requestId;

    state = state.copyWith(
      isLoading: true,
      isLoadingMore: false,
      hasMore: true,
      page: 0,
      clearError: true,
    );

    try {
      final response = await _getPostsPage(page: 1, forceRefresh: true);

      if (_isStale(requestId)) {
        return;
      }

      state = state.copyWith(
        posts: response.items,
        isLoading: false,
        hasMore: response.hasMore,
        page: response.page,
        clearError: true,
      );
    } catch (error) {
      if (_isStale(requestId)) {
        return;
      }

      state = state.copyWith(isLoading: false, hasMore: false, error: error);
    }
  }

  Future<void> loadNextPage() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) {
      return;
    }

    final requestId = _requestId;

    state = state.copyWith(isLoadingMore: true, clearError: true);

    try {
      final nextPage = state.page + 1;
      final response = await _getPostsPage(page: nextPage);

      if (requestId != _requestId) {
        return;
      }

      final knownIds = state.posts.map((post) => post.id).toSet();
      final newItems = response.items
          .where((post) => knownIds.add(post.id))
          .toList(growable: false);
      state = state.copyWith(
        posts: [...state.posts, ...newItems],
        isLoadingMore: false,
        hasMore: response.hasMore,
        page: response.page,
        clearError: true,
      );
    } catch (error) {
      if (requestId != _requestId) {
        return;
      }

      state = state.copyWith(isLoadingMore: false, error: error);
    }
  }

  Future<PostsPage> _getPostsPage({
    required int page,
    bool forceRefresh = false,
  }) {
    return loadPage(
      page: page,
      search: state.search,
      categoryId: state.selectedCategoryId,
      forceRefresh: forceRefresh,
    );
  }

  bool _isStale(int requestId) => requestId != _requestId;

  Future<void> updateSearch(String value) async {
    state = state.copyWith(
      search: value,
      selectedCategoryId: value.trim().isNotEmpty
          ? 0
          : state.selectedCategoryId,
    );
    await refresh();
  }

  Future<void> updateCategory(int value) async {
    if (state.selectedCategoryId == value) {
      return;
    }

    state = state.copyWith(
      selectedCategoryId: value,
      search: value > 0 ? '' : state.search,
    );

    await refresh();
  }
}

final paginatedNewsProvider =
    StateNotifierProvider.autoDispose<
      PaginatedNewsNotifier,
      PaginatedNewsState
    >((ref) {
      final service = ref.watch(wordpressServiceProvider);
      return PaginatedNewsNotifier(
        loadCategories: service.getCategories,
        loadPage:
            ({
              required int page,
              required String search,
              required int categoryId,
              required bool forceRefresh,
            }) => service.getPosts(
              search: search,
              categoryId: categoryId,
              sticky: false,
              page: page,
              perPage: PaginatedNewsNotifier.perPage,
              forceRefresh: forceRefresh,
            ),
      );
    });
