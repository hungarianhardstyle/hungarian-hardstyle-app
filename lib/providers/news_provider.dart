import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/post.dart';
import '../services/wordpress_service.dart';

final wordpressServiceProvider = Provider<WordpressService>((ref) {
  return WordpressService();
});

final newsProvider = FutureProvider<List<Post>>((ref) async {
  final service = ref.watch(wordpressServiceProvider);
  return service.getLatestPosts();
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

class PaginatedNewsNotifier extends StateNotifier<PaginatedNewsState> {
  PaginatedNewsNotifier(this._service) : super(const PaginatedNewsState()) {
    _loadCategories();
    refresh();
  }

  static const int _perPage = 10;

  final WordpressService _service;
  int _requestId = 0;

  Future<void> _loadCategories() async {
    final categories = await _service.getCategories();

    state = state.copyWith(categories: categories);
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
      final response = await _getPostsPage(page: 1);

      if (requestId != _requestId) {
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
      if (requestId != _requestId) {
        return;
      }

      state = state.copyWith(
        isLoading: false,
        hasMore: false,
        error: error,
      );
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

      state = state.copyWith(
        posts: [...state.posts, ...response.items],
        isLoadingMore: false,
        hasMore: response.hasMore,
        page: response.page,
        clearError: true,
      );
    } catch (error) {
      if (requestId != _requestId) {
        return;
      }

      state = state.copyWith(
        isLoadingMore: false,
        error: error,
      );
    }
  }

  Future<PostsPage> _getPostsPage({required int page}) {
    if (state.selectedCategoryId > 0 || state.search.trim().isNotEmpty) {
      return _service.getStandardPosts(
        categoryId: state.selectedCategoryId,
        search: state.search,
        page: page,
        perPage: _perPage,
      );
    }

    return _service.getPosts(
      page: page,
      perPage: _perPage,
    );
  }

  Future<void> updateSearch(String value) async {
    state = state.copyWith(
      search: value,
      selectedCategoryId: value.trim().isNotEmpty ? 0 : state.selectedCategoryId,
    );
    await refresh();
  }

  Future<void> updateCategory(int value) async {
    if (state.selectedCategoryId == value) {
      return;
    }

    state = state.copyWith(selectedCategoryId: value);

    await refresh();
  }
}

final paginatedNewsProvider =
    StateNotifierProvider<PaginatedNewsNotifier, PaginatedNewsState>((ref) {
  final service = ref.watch(wordpressServiceProvider);
  return PaginatedNewsNotifier(service);
});
