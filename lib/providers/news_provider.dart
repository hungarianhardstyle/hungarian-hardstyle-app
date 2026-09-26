import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/i18n/app_language.dart';
import '../core/i18n/app_strings.dart';
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
/// A hírlisták csendes újraegyeztetésének üteme.
///
/// ⚠️ **MÉRT OK (2026-09-26, éles szonda + a `tesztek`):** a szerver a
/// publikáláskor azonnal érvényteleníti a cache-ét, és a kondicionális HEAD-re
/// **304**-et ad (mért: 399 ms, 0 bájt) — a késés az app oldalán volt, mert a
/// nyitott főoldal/hírek fül **egyáltalán nem** kérdezte meg a szervert. Ez az
/// ütem egy kicsi ETag-egyeztetést indít, és nem ír a képernyőre (a friss test
/// megérkezésekor a jelzés frissíti a felületet), ezért a lapozás és a
/// kirajzolás közben nem történik semmi látható.
const Duration newsRevalidateInterval = Duration(seconds: 60);

/// A hírlista csendes egyeztetője.
///
/// Szándékosan **provider**: a viselkedés így hálózat nélkül, időzítő-vezérelten
/// mérhető (lásd `test/services/news_freshness_test.dart`).
final newsRevalidateProvider = Provider<Future<void> Function()>((ref) {
  final service = ref.watch(wordpressServiceProvider);
  return service.revalidateLatestPosts;
});

/// A főoldali hírlista betöltője.
///
/// Ugyanaz a mérési ok, mint a [newsRevalidateProvider]-nél: a szolgáltatás
/// egyke (`WordpressService()`), ezért a betöltést provideren át adjuk tovább —
/// így a frissességi viselkedés hálózat nélkül mérhető.
final latestPostsProvider = Provider<Future<List<Post>> Function()>((ref) {
  return ref.watch(wordpressServiceProvider).getLatestPosts;
});

/// Elindítja a csendes egyeztetést a felület élettartamára, és a provider
/// eldobásakor le is állítja (nem marad életben időzítő a lebontott képernyő
/// után).
Timer startNewsRevalidation(
  Ref ref,
  Future<void> Function() revalidate, {
  Duration interval = newsRevalidateInterval,
}) {
  final timer = Timer.periodic(interval, (_) => unawaited(revalidate()));
  ref.onDispose(timer.cancel);
  return timer;
}

final newsProvider = FutureProvider.autoDispose<List<Post>>((ref) async {
  ref.watch(publicContentRefreshProvider);
  startNewsRevalidation(ref, ref.watch(newsRevalidateProvider));
  return ref.watch(latestPostsProvider)();
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

/// A hírek fül csendes újraegyeztetése: a **jelenlegi** szűrőre kér egy
/// ETag-egyeztetést (nem ír a listára, csak jelzést ad, ha változott).
typedef NewsRevalidate =
    Future<void> Function({required String search, required int categoryId});

class PaginatedNewsNotifier extends StateNotifier<PaginatedNewsState> {
  PaginatedNewsNotifier({
    required this.loadPage,
    required this.loadCategories,
    this.revalidate,
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
    _revalidateTimer = Timer.periodic(
      newsRevalidateInterval,
      (_) => unawaited(_revalidateSilently()),
    );
  }

  static const int perPage = 10;

  final NewsPageLoader loadPage;
  final NewsCategoriesLoader loadCategories;

  /// A csendes (ETag/HEAD) egyeztetés útja. Ha nincs megadva, nem indul.
  final NewsRevalidate? revalidate;

  Timer? _revalidateTimer;

  /// A WordPress-gyorsítótár jelzése, amikor a **háttérben** beérkezett egy új
  /// test (ETag-változás). Ezen keresztül frissül a lista anélkül, hogy a
  /// képernyő megnyitása hálózati kérést indítana.
  final Listenable? _contentUpdates;
  int _requestId = 0;

  /// A **most látható lista nyelve** — ebből ismerjük fel a nyelvváltást.
  ///
  /// ⚠️ **MÉRT HIBA (a tulajdonos jelzése, 2026-09-26):** *„a legutolsó hír
  /// valamiért nincs fent angolul"* → *„újraindítás után jó"*. Két része volt:
  ///  1. a háttér-frissítés **azonosítók** alapján döntött („ugyanaz a lista"),
  ///     a nyelvváltás viszont **ugyanazokat** az azonosítókat adja **más
  ///     nyelvű** címekkel — így a régi nyelvű lista a helyén maradt;
  ///  2. a háttér-út **csak az első oldalon** futott (`state.page > 1` esetén
  ///     kilépett), ezért egy továbblapozott lista **újraindításig** a régi
  ///     nyelven maradt.
  ///
  /// Ezért a jelzésre előbb a nyelvet hasonlítjuk: ha megváltozott, a lista
  /// **minden betöltött oldalát eldobjuk** és az első oldalt töltjük újra.
  AppLanguage _loadedLanguage = AppStrings.language;

  @override
  void dispose() {
    _revalidateTimer?.cancel();
    _contentUpdates?.removeListener(_onContentUpdated);
    super.dispose();
  }

  /// Csendes egyeztetés a jelenlegi szűrőre (lásd [newsRevalidateInterval]).
  Future<void> _revalidateSilently() async {
    final revalidate = this.revalidate;
    if (revalidate == null) return;
    try {
      await revalidate(
        search: state.search,
        categoryId: state.selectedCategoryId,
      );
    } catch (_) {
      // A csendes egyeztetés hibája nem érintheti a képernyőn lévő listát.
    }
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
      _loadedLanguage = AppStrings.language;
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
    if (!mounted) return;
    // ⚠️ NYELVVÁLTÁS: a betöltött oldalakat is el kell dobni — a csendes
    // háttér-frissítés csak az első oldalt cserélné, a régi nyelvű címek
    // pedig a helyükön maradnának (mért hiba: „a legutolsó hír nem angol").
    if (_loadedLanguage != AppStrings.language) {
      unawaited(refresh());
      return;
    }
    if (state.isLoading || state.isLoadingMore) return;
    // Aki már továbblapozott, annak a listáját nem írjuk felül a háttérből:
    // ott a kifejezett frissítés a helyes út (a lista nem ugrál a keze alatt).
    if (state.page > 1) return;
    unawaited(_applyBackgroundUpdate());
  }

  Future<void> _applyBackgroundUpdate() async {
    try {
      // ⚠️ MÉRT OK (2026-09-26): a jelzés után a listát **kényszerített** úton
      // olvassuk vissza. A megjelenítési út ugyanis a mentett (régi) példányt
      // adná vissza, és a friss cikk csak egy MÁSODIK jelzésre jelent volna meg
      // — a felhasználó a lehúzásig a régi listát látta (ezt a
      // `test/services/news_freshness_test.dart` méri).
      final cached = await _getPostsPage(page: 1, forceRefresh: true);
      if (!mounted || cached.items.isEmpty) return;
      if (_samePosts(cached.items, state.posts)) return;
      state = state.copyWith(
        posts: cached.items,
        hasMore: cached.hasMore,
        page: cached.page,
        clearError: true,
      );
      _loadedLanguage = AppStrings.language;
    } catch (_) {
      // A háttérellenőrzés hibája nem törölheti a képernyőn lévő listát.
    }
  }

  /// Ugyanaz a lista? **Az azonosító MELLETT a cím is számít.**
  ///
  /// ⚠️ MÉRT OK: a csak azonosító-alapú összehasonlítás a **nyelvváltást** nem
  /// vette észre (ugyanazok a cikkek, más nyelvű címek), ezért a régi nyelvű
  /// lista a helyén maradt mindaddig, amíg a felhasználó újra nem indította az
  /// appot. A cím a legolcsóbb nyelvenként változó mező, ezért ezt hasonlítjuk.
  bool _samePosts(List<Post> left, List<Post> right) {
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      if (left[i].id != right[i].id) return false;
      if (left[i].title != right[i].title) return false;
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
        // A csendes egyeztetés ugyanazt a lekérdezést egyezteti, amit a fül
        // mutat (a keresés és a kategória a hívás pillanatában érvényes).
        revalidate:
            ({required String search, required int categoryId}) =>
                service.revalidatePosts(
                  search: search,
                  categoryId: categoryId,
                  sticky: false,
                ),
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
