import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/post.dart';
import '../services/wordpress_service.dart';

final wordpressServiceProvider = Provider<WordpressService>((ref) {
  return WordpressService();
});

/// A WordPress-tartalom frissítésének jelzése a felület felé.
///
/// **MÉRT OK, MIÉRT NEM A GLOBÁLIS NOTIFIER KÖZVETLENÜL:** a
/// `ChangeNotifierProvider` a scope lezárásakor `dispose()`-olja, amit kapott —
/// a szolgáltatás jelzője (`WordpressService.publicContentRefreshGeneration`)
/// viszont **globális**. Ha azt adjuk oda, akkor az első `ProviderScope`
/// megszűnése **eldobja a globális jelzőt**, és minden további olvasó egy
/// eldobott notifierhez iratkozna fel (`A ValueNotifier&lt;int&gt; was used after
/// being disposed`), vagyis a képernyő meg sem épül. Ez a hiba eddig is megvolt
/// (a tartalmat figyelő providereknél), és tesztben sorban meg is buktatta a
/// képernyőket.
///
/// Ezért minden scope a **saját tükrét** kapja: a tükör továbbadja a jelzést, a
/// scope-pal együtt szűnik meg, a szolgáltatás jelzője viszont érintetlen marad.
final publicContentRefreshProvider = ChangeNotifierProvider<ValueNotifier<int>>(
  (ref) => PublicContentRefreshMirror(
    WordpressService.publicContentRefreshGeneration,
  ),
);

/// A megosztott WordPress-frissítés-jelzés **scope-hoz kötött tükre**.
///
/// A scope-pal együtt dobjuk el, és ilyenkor leiratkozunk a forrásról — így a
/// forrás élettartama nem függ egyetlen képernyőtől (vagy teszt-scope-tól) sem.
class PublicContentRefreshMirror extends ValueNotifier<int> {
  PublicContentRefreshMirror(this._source) : super(_source.value) {
    _source.addListener(_sync);
  }

  final ValueNotifier<int> _source;
  bool _stopped = false;

  void _sync() {
    if (_stopped) return;
    value = _source.value;
  }

  /// Leiratkozás a forrásról (ismételve nem csinál semmit).
  void stop() {
    if (_stopped) return;
    _stopped = true;
    _source.removeListener(_sync);
  }

  @override
  void removeListener(VoidCallback listener) {
    // A scope lezárásakor a tükör már eldobott állapotban lehet, amikor a
    // leszármazott providerek leiratkoznak — ez nem hiba, csak sorrend.
    if (_stopped) return;
    super.removeListener(listener);
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

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
    Listenable? contentUpdates,
  }) : // A privát mezőhöz nem lehet `this._x` nevű NÉVES paramétert adni, ezért
       // szándékos a kézi hozzárendelés (ugyanaz a minta, mint a
       // `LabelLibraryService`-nél).
       // ignore: prefer_initializing_formals
       _contentUpdates = contentUpdates,
       super(const PaginatedNewsState()) {
    _contentUpdates?.addListener(_onContentUpdated);
    _loadCategories();
    _loadFirstPage();
  }

  static const int perPage = 10;

  final NewsPageLoader loadPage;
  final NewsCategoriesLoader loadCategories;

  /// A WordPress-gyorsítótár jelzése, amikor a **háttérben** beérkezett egy új
  /// test (ETag-változás). Ezen keresztül frissül a lista anélkül, hogy a
  /// képernyő megnyitása hálózati kérést indítana.
  final Listenable? _contentUpdates;
  int _requestId = 0;

  @override
  void dispose() {
    _contentUpdates?.removeListener(_onContentUpdated);
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final categories = await loadCategories();

    state = state.copyWith(categories: categories);
  }

  /// Az első oldal betöltése a képernyő megnyitásakor.
  ///
  /// Ez a **megjelenítési út**: a mentett oldal azonnal kirajzolódik, a
  /// WordPress-egyeztetés pedig a háttérben fut (lásd `WordpressHeadCache`),
  /// ezért a képernyő megnyitása **nem** fizet egy 0,4–2,0 s-os körrel.
  /// A kifejezett frissítés ([refresh] `forceRefresh: true`-val) továbbra is a
  /// hálózatra vár.
  Future<void> _loadFirstPage() => refresh();

  /// Az első oldal (újra)betöltése.
  ///
  /// [forceRefresh] a **kifejezett felhasználói frissítés** (lehúzás, frissítés
  /// ikon): ilyenkor a válaszra várunk. Alapból viszont a megjelenítési út fut,
  /// amely a mentett oldalt azonnal kirajzolja és csak a háttérben egyeztet —
  /// ezen az úton megy a képernyő megnyitása, a keresés és a kategóriaváltás
  /// is, mert egy koppintás után a felhasználó nem várhat másodperceket.
  Future<void> refresh({bool forceRefresh = false}) async {
    final requestId = ++_requestId;

    state = state.copyWith(
      isLoading: true,
      isLoadingMore: false,
      hasMore: true,
      page: 0,
      clearError: true,
    );

    try {
      final response = await _getPostsPage(
        page: 1,
        forceRefresh: forceRefresh,
      );

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

  /// A háttérben lezajló WordPress-egyeztetés jelzése.
  ///
  /// A megjelenítési út nem vár a hálózatra: a mentett oldalt rajzolja ki, a
  /// frissítést pedig a `WordpressHeadCache` végzi a háttérben. Amikor az új
  /// test megérkezett, a mentett oldal **hálózat nélkül** újraolvasható — így a
  /// lista magától frissül, a felhasználónak nem kell lehúznia.
  void _onContentUpdated() {
    if (!mounted || state.isLoading || state.isLoadingMore) return;
    // Aki már továbblapozott, annak a listáját nem írjuk felül a háttérből:
    // ott a kifejezett frissítés a helyes út (a lista nem ugrál a keze alatt).
    if (state.page > 1) return;
    unawaited(_applyBackgroundUpdate());
  }

  Future<void> _applyBackgroundUpdate() async {
    try {
      final cached = await _getPostsPage(page: 1);
      if (!mounted || cached.items.isEmpty) return;
      if (_sameIds(cached.items, state.posts)) return;
      state = state.copyWith(
        posts: cached.items,
        hasMore: cached.hasMore,
        page: cached.page,
        clearError: true,
      );
    } catch (_) {
      // A háttérellenőrzés hibája nem törölheti a képernyőn lévő listát.
    }
  }

  bool _sameIds(List<Post> left, List<Post> right) {
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      if (left[i].id != right[i].id) return false;
    }
    return true;
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
        // A háttérben beérkező friss test jelzése: e nélkül a lista csak a
        // következő megnyitáskor (vagy lehúzásra) frissülne. Szándékosan
        // `read` (nem `watch`): a jelzés nem építheti újra a notifiert, mert az
        // a továbblapozott listát dobná el.
        contentUpdates: ref.read(publicContentRefreshProvider),
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
