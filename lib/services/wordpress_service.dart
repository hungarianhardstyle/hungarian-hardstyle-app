import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/artist.dart';
import '../models/event.dart';
import '../models/event_submission.dart';
import '../models/faq.dart';
import '../models/game.dart';
import '../models/organizer.dart';
import '../models/post.dart';
import '../models/profile_submission.dart';
import '../models/release.dart';
import '../models/submission_image.dart';
import '../core/firebase/firebase_callable.dart';
import '../models/voting.dart';
import 'wordpress_head_cache.dart';
import 'wordpress_tag_cache.dart';

int _readInt(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

String? _readResponseMessage(Object? responseData) {
  if (responseData is! Map<String, dynamic>) return null;
  final message = responseData['message'];
  return message is String && message.trim().isNotEmpty ? message.trim() : null;
}

bool _isSupportedImageBytes(Uint8List bytes) {
  final jpeg =
      bytes.length >= 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF;
  final png =
      bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0D &&
      bytes[5] == 0x0A &&
      bytes[6] == 0x1A &&
      bytes[7] == 0x0A;
  final webp =
      bytes.length >= 12 &&
      String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
      String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP';
  return jpeg || png || webp;
}

class NewsCategory {
  final int id;
  final String name;
  final String slug;
  final int count;

  const NewsCategory({
    required this.id,
    required this.name,
    required this.slug,
    required this.count,
  });

  factory NewsCategory.fromJson(Map<String, dynamic> json) {
    return NewsCategory(
      id: _readInt(json['id']),
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      count: _readInt(json['count']),
    );
  }
}

class PostsPage {
  final List<Post> items;
  final int page;
  final int perPage;
  final int total;
  final int totalPages;
  final bool hasMore;

  const PostsPage({
    required this.items,
    required this.page,
    required this.perPage,
    required this.total,
    required this.totalPages,
    required this.hasMore,
  });
}

class EventsPage {
  final List<HuhsEvent> items;
  final int page;
  final int perPage;
  final int total;
  final bool hasMore;

  const EventsPage({
    required this.items,
    required this.page,
    required this.perPage,
    required this.total,
    required this.hasMore,
  });
}

class _PostsCacheEntry {
  const _PostsCacheEntry(this.value, this.expiresAt);

  final PostsPage value;
  final DateTime expiresAt;
}

class _ReleasesCacheEntry {
  const _ReleasesCacheEntry(this.value, this.expiresAt);

  final List<HuhsRelease> value;
  final DateTime expiresAt;
}

class _TimedCacheEntry<T> {
  const _TimedCacheEntry(this.value, this.expiresAt);

  final T value;
  final DateTime expiresAt;
}

class WordpressService {
  static final WordpressService instance = WordpressService._internal();

  factory WordpressService() => instance;

  WordpressService._internal();

  static const _cloudinaryCloudName = 'fjxo93em';
  static const _cloudinaryUploadPreset = 'Hun_hs_Mobile';
  static const _maxUploadBytes = 5 * 1024 * 1024;
  static const _allowedImageExtensions = {'jpg', 'jpeg', 'png', 'webp'};

  late final Dio _dio =
      Dio(
          BaseOptions(
            baseUrl: 'https://hungarianhardstyle.hu/wp-json/huhs/v1',
            connectTimeout: const Duration(seconds: 20),
            sendTimeout: const Duration(seconds: 20),
            receiveTimeout: const Duration(seconds: 20),
            responseType: ResponseType.json,
          ),
        )
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              if (kDebugMode) {
                options.extra['_huhsStartedAt'] = Stopwatch()..start();
              }
              handler.next(options);
            },
            onResponse: (response, handler) {
              _logApiTiming(
                response.requestOptions,
                response.statusCode,
                response.data,
              );
              handler.next(response);
            },
            onError: (error, handler) async {
              var currentError = error;
              final request = currentError.requestOptions;
              final retryCount = request.extra['_huhsRetryCount'] as int? ?? 0;
              if (_isRetryableGet(currentError) && retryCount < 2) {
                request.extra['_huhsRetryCount'] = retryCount + 1;
                await Future<void>.delayed(
                  Duration(milliseconds: retryCount == 0 ? 250 : 750),
                );
                try {
                  handler.resolve(await _dio.fetch<dynamic>(request));
                  return;
                } on DioException catch (retryError) {
                  currentError = retryError;
                }
              }
              _logApiTiming(
                currentError.requestOptions,
                currentError.response?.statusCode,
                currentError.response?.data,
              );
              handler.next(currentError);
            },
          ),
        );

  static void _logApiTiming(
    RequestOptions options,
    int? statusCode,
    Object? data,
  ) {
    if (!kDebugMode) return;
    final stopwatch = options.extra['_huhsStartedAt'];
    if (stopwatch is Stopwatch) stopwatch.stop();
    final elapsedMs = stopwatch is Stopwatch
        ? stopwatch.elapsedMilliseconds
        : -1;
    var bytes = 0;
    if (data != null) {
      try {
        bytes = utf8.encode(jsonEncode(data)).length;
      } catch (_) {
        bytes = -1;
      }
    }
    debugPrint(
      '[HUHS API] ${options.method} ${options.path} '
      '${statusCode ?? 'error'} ${elapsedMs}ms ${bytes}B',
    );
  }

  /// Freshness window of the parsed in-memory list caches.
  ///
  /// This is not a lifetime: once it passes, the call falls through to the
  /// layered disk cache ([WordpressHeadCache]), which still answers instantly
  /// and only revalidates in the background. Display never blocks on it.
  static const _listCacheDuration = Duration(seconds: 30);
  final Map<String, _PostsCacheEntry> _postsCache = {};
  final Map<String, Future<PostsPage>> _postsInFlight = {};
  final Map<String, _ReleasesCacheEntry> _releasesCache = {};
  final Map<String, Future<List<HuhsRelease>>> _releasesInFlight = {};
  final Map<String, _TimedCacheEntry<EventsPage>> _eventsCache = {};
  final Map<String, Future<EventsPage>> _eventsInFlight = {};
  final Map<int, _TimedCacheEntry<HuhsEvent>> _eventDetailCache = {};
  final Map<int, Future<HuhsEvent>> _eventDetailInFlight = {};
  final Map<int, _TimedCacheEntry<Post>> _postDetailCache = {};
  final Map<int, Future<Post>> _postDetailInFlight = {};
  final Map<String, _TimedCacheEntry<List<FaqItem>>> _faqCache = {};
  final Map<String, Future<List<FaqItem>>> _faqInFlight = {};
  final Map<String, _TimedCacheEntry<ArtistsPage>> _artistsCache = {};
  final Map<String, Future<ArtistsPage>> _artistsInFlight = {};
  final Map<int, _TimedCacheEntry<Artist>> _artistCache = {};
  final Map<int, Future<Artist>> _artistInFlight = {};
  final Map<String, _TimedCacheEntry<OrganizersPage>> _organizersCache = {};
  final Map<String, Future<OrganizersPage>> _organizersInFlight = {};
  final Map<int, _TimedCacheEntry<OrganizerProfile>> _organizerCache = {};
  final Map<int, Future<OrganizerProfile>> _organizerInFlight = {};
  final Map<int, _TimedCacheEntry<HuhsRelease>> _releaseDetailCache = {};
  final Map<int, Future<HuhsRelease>> _releaseDetailInFlight = {};
  final Map<String, _TimedCacheEntry<HuhsGame?>> _activeGameCache = {};
  final Map<String, Future<HuhsGame?>> _activeGameInFlight = {};
  final Map<String, _TimedCacheEntry<HuhsGame?>> _latestGameResultsCache = {};
  final Map<String, Future<HuhsGame?>> _latestGameResultsInFlight = {};
  final Map<int, _TimedCacheEntry<List<HuhsGameResult>>> _gameResultsCache = {};
  final Map<int, Future<List<HuhsGameResult>>> _gameResultsInFlight = {};

  /// Freshness window of the persisted JSON entries.
  ///
  /// It marks when a stored value should be revalidated, not how long it may be
  /// used: the display path always serves whatever is on disk, however old it
  /// is, and only the background refresh is gated by this window. This keeps a
  /// second app session from waiting for WordPress just because the previous
  /// visit was more than a few minutes ago.
  static const _persistentCacheTtl = Duration(minutes: 5);
  Future<SharedPreferences>? _preferencesFuture;
  final Map<String, _TimedCacheEntry<Object?>> _persistentJsonCache = {};
  final Set<String> _persistentRefreshInFlight = {};

  late final WordpressHeadCache _headCache = WordpressHeadCache(
    read: (key) async => (await _preferences()).getString(key),
    write: (key, value) async {
      await (await _preferences()).setString(key, value);
    },
    remove: (key) async {
      await (await _preferences()).remove(key);
    },
    request: (method, uri) async {
      final response = await _dio.requestUri<String>(
        uri,
        options: Options(method: method, responseType: ResponseType.plain),
      );
      return WordpressCacheResponse(
        statusCode: response.statusCode ?? 0,
        etag: response.headers.value('etag'),
        data: method == 'HEAD'
            ? null
            : _decodePossiblyPrefixedJson(response.data ?? ''),
      );
    },
    onUpdated: () => publicContentRefreshGeneration.value++,
  );

  static final ValueNotifier<int> publicContentRefreshGeneration =
      ValueNotifier<int>(0);

  Future<Object?> _getHeadCached(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool forceRefresh = false,
    bool bypassCache = false,
  }) {
    final query = queryParameters?.map(
      (key, value) => MapEntry(key, value.toString()),
    );
    final uri = Uri.parse('${_dio.options.baseUrl}$path')
        .replace(queryParameters: query);
    return _headCache.get(
      uri,
      cacheContext: PlatformDispatcher.instance.locale.toLanguageTag(),
      forceRefresh: forceRefresh,
      bypassCache: bypassCache,
    );
  }

  static bool _isRetryableGet(DioException error) {
    if (error.requestOptions.method.toUpperCase() != 'GET') return false;
    if (error.type == DioExceptionType.cancel ||
        error.type == DioExceptionType.badCertificate) {
      return false;
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError) {
      return true;
    }
    final status = error.response?.statusCode;
    return status == 408 ||
        status == 429 ||
        status == 500 ||
        status == 502 ||
        status == 503 ||
        status == 504;
  }

  Future<SharedPreferences> _preferences() {
    return _preferencesFuture ??= SharedPreferences.getInstance();
  }

  /// Reads a persisted JSON value for the display path.
  ///
  /// An expired entry is still returned: the age only decides whether the
  /// caller schedules a background refresh (see [_persistentValueNeedsRefresh]).
  /// Only unreadable payloads are dropped, because those cannot be rendered.
  Future<Object?> _readPersistentJson(String key) async {
    final now = DateTime.now();
    final memory = _persistentJsonCache[key];
    if (memory != null) return memory.value;

    final preferences = await _preferences();
    final payload = preferences.getString(key);
    if (payload == null) return null;
    try {
      final value = jsonDecode(payload);
      final savedAt = preferences.getInt('$key.savedAt');
      final expiresAt = savedAt == null
          ? now.add(_persistentCacheTtl)
          : DateTime.fromMillisecondsSinceEpoch(savedAt).add(_persistentCacheTtl);
      _persistentJsonCache[key] = _TimedCacheEntry(value, expiresAt);
      return value;
    } catch (_) {
      await _removePersistentJson(key);
      return null;
    }
  }

  /// Whether the stored value passed its freshness window and should be
  /// revalidated in the background. Display never waits for that refresh.
  Future<bool> _persistentValueNeedsRefresh(String key) async {
    final entry = _persistentJsonCache[key];
    if (entry != null) return !entry.expiresAt.isAfter(DateTime.now());
    final preferences = await _preferences();
    final savedAt = preferences.getInt('$key.savedAt');
    if (savedAt == null) return true;
    return !DateTime.fromMillisecondsSinceEpoch(
      savedAt,
    ).add(_persistentCacheTtl).isAfter(DateTime.now());
  }

  /// Test hook for the persisted display policy: an expired entry must still be
  /// returned, because only the background refresh is gated by the freshness
  /// window.
  @visibleForTesting
  Future<Object?> readPersistentJsonForTesting(String key) =>
      _readPersistentJson(key);

  @visibleForTesting
  Future<bool> persistentJsonNeedsRefreshForTesting(String key) =>
      _persistentValueNeedsRefresh(key);

  Future<void> _writePersistentJson(String key, Object value) async {
    final now = DateTime.now();
    _persistentJsonCache[key] = _TimedCacheEntry(
      value,
      now.add(_persistentCacheTtl),
    );
    final preferences = await _preferences();
    await preferences.setString(key, jsonEncode(value));
    await preferences.setInt('$key.savedAt', now.millisecondsSinceEpoch);
  }

  Future<void> _removePersistentJson(String key) async {
    _persistentJsonCache.remove(key);
    final preferences = await _preferences();
    await preferences.remove(key);
    await preferences.remove('$key.savedAt');
  }

  void _schedulePersistentRefresh(String key, Future<void> Function() refresh) {
    if (!_persistentRefreshInFlight.add(key)) return;
    // Show the persisted value first, then refresh once the current request
    // has released its in-flight entry.
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 1), () async {
        try {
          await refresh();
        } finally {
          _persistentRefreshInFlight.remove(key);
        }
      }),
    );
  }

  /// Clears only public WordPress API caches; user purchases and preferences
  /// stay untouched.
  Future<void> clearPublicCache() async {
    _postsCache.clear();
    _releasesCache.clear();
    _eventsCache.clear();
    _eventDetailCache.clear();
    _eventDetailInFlight.clear();
    _postDetailCache.clear();
    _postDetailInFlight.clear();
    _faqCache.clear();
    _artistsCache.clear();
    _artistCache.clear();
    _organizersCache.clear();
    _organizerCache.clear();
    _releaseDetailCache.clear();
    _releaseDetailInFlight.clear();
    _activeGameCache.clear();
    _activeGameInFlight.clear();
    _latestGameResultsCache.clear();
    _latestGameResultsInFlight.clear();
    _gameResultsCache.clear();
    _gameResultsInFlight.clear();
    _persistentJsonCache.clear();
    await _headCache.clear();
    _persistentRefreshInFlight.clear();

    final preferences = await _preferences();
    final keys = preferences
        .getKeys()
        .where((key) => key.startsWith('huhs.wp.'))
        .toList(growable: false);
    for (final key in keys) {
      await preferences.remove(key);
    }
  }

  Future<HuhsGame?> getActiveGame({bool forceRefresh = false}) async {
    if (forceRefresh) _activeGameCache.remove('active');
    return _cached<HuhsGame?>(
      key: 'active',
      ttl: const Duration(minutes: 1),
      cache: _activeGameCache,
      inFlight: _activeGameInFlight,
      loader: () async {
        final data = await _getHeadCached('/games/active');
        if (data == null || data is! Map) return null;
        return HuhsGame.fromJson(Map<String, dynamic>.from(data));
      },
    );
  }

  Future<HuhsGame?> getLatestGameResults({bool forceRefresh = false}) async {
    if (forceRefresh) _latestGameResultsCache.remove('latest');
    return _cached<HuhsGame?>(
      key: 'latest',
      ttl: const Duration(minutes: 1),
      cache: _latestGameResultsCache,
      inFlight: _latestGameResultsInFlight,
      loader: () async {
        final data = await _getHeadCached('/games/results/latest');
        if (data == null || data is! Map) return null;
        return HuhsGame.fromJson(Map<String, dynamic>.from(data));
      },
    );
  }

  Future<String> getGameAudioClipUrl(int gameId) async {
    final result = await callFirebaseCallable<Map<String, dynamic>>(
      'getGameAudioClip',
      parameters: {'gameId': gameId},
    );
    final data = result.data;
    if (data['url'] is! String || (data['url'] as String).isEmpty) {
      throw StateError('A játék hangrészlete nem érhető el.');
    }
    return data['url'] as String;
  }

  Future<Map<String, dynamic>> submitGameAttempt({
    required int gameId,
    List<int>? answers,
    List<String>? orderedIds,
  }) async {
    final result = await callFirebaseCallable<Map<String, dynamic>>(
      'submitGameAttempt',
      parameters: {
        'gameId': gameId,
        ...?(answers == null ? null : <String, dynamic>{'answers': answers}),
        ...?(orderedIds == null
            ? null
            : <String, dynamic>{'orderedIds': orderedIds}),
      },
    );
    final data = result.data;
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> getGameAttemptStatus(int gameId) async {
    final result = await callFirebaseCallable<Map<String, dynamic>>(
      'getGameAttemptStatus',
      parameters: {'gameId': gameId},
    );
    final data = result.data;
    return Map<String, dynamic>.from(data);
  }

  Future<List<HuhsGameResult>> getGameResults(int gameId) async {
    return _cachedById<List<HuhsGameResult>>(
      key: gameId,
      // A lezárt játék végeredménye nem változik; egy nap után a meglévő
      // lejárati útvonal újra lekérheti, illetve a nyilvános cache ürítésekor
      // azonnal eldobható.
      ttl: const Duration(days: 1),
      cache: _gameResultsCache,
      inFlight: _gameResultsInFlight,
      loader: () async {
        final result = await callFirebaseCallable<Map<String, dynamic>>(
          'getGameResults',
          parameters: {'gameId': gameId},
        );
        final items = result.data['items'];
        return items is List
            ? items
                  .whereType<Map>()
                  .map(
                    (item) => HuhsGameResult.fromJson(
                      Map<String, dynamic>.from(item),
                    ),
                  )
                  .toList(growable: false)
            : const [];
      },
    );
  }

  Future<T> _cached<T>({
    required String key,
    required Duration ttl,
    required Map<String, _TimedCacheEntry<T>> cache,
    required Map<String, Future<T>> inFlight,
    required Future<T> Function() loader,
  }) async {
    final now = DateTime.now();
    final existingValue = cache[key];
    if (existingValue != null && existingValue.expiresAt.isAfter(now)) {
      return existingValue.value;
    }
    final existingRequest = inFlight[key];
    if (existingRequest != null) return existingRequest;

    final request = loader();
    inFlight[key] = request;
    try {
      final value = await request;
      cache[key] = _TimedCacheEntry(value, DateTime.now().add(ttl));
      return value;
    } finally {
      if (identical(inFlight[key], request)) inFlight.remove(key);
    }
  }

  Future<T> _cachedById<T>({
    required int key,
    required Duration ttl,
    required Map<int, _TimedCacheEntry<T>> cache,
    required Map<int, Future<T>> inFlight,
    required Future<T> Function() loader,
  }) async {
    final now = DateTime.now();
    final existingValue = cache[key];
    if (existingValue != null && existingValue.expiresAt.isAfter(now)) {
      return existingValue.value;
    }
    final existingRequest = inFlight[key];
    if (existingRequest != null) return existingRequest;

    final request = loader();
    inFlight[key] = request;
    try {
      final value = await request;
      cache[key] = _TimedCacheEntry(value, DateTime.now().add(ttl));
      return value;
    } finally {
      if (identical(inFlight[key], request)) inFlight.remove(key);
    }
  }

  void clearReleasesCache({String search = '', int artistId = 0}) {
    final cacheKey = '${search.trim()}|$artistId';
    _releasesCache.remove(cacheKey);
    unawaited(_removePersistentJson('huhs.wp.releases.$cacheKey'));
  }

  Future<PostsPage> getPosts({
    int page = 1,
    int perPage = 10,
    String search = '',
    int categoryId = 0,
    bool? sticky,
    bool forceRefresh = false,
  }) async {
    final key = '$page|$perPage|${search.trim()}|$categoryId|$sticky';
    final now = DateTime.now();
    final cached = _postsCache[key];
    if (!forceRefresh && cached != null && cached.expiresAt.isAfter(now)) {
      return cached.value;
    }
    final existing = _postsInFlight[key];
    if (existing != null) return existing;

    final request = _fetchPosts(
      page: page,
      perPage: perPage,
      search: search,
      categoryId: categoryId,
      sticky: sticky,
      allowPersistentCache: !forceRefresh,
    );
    _postsInFlight[key] = request;
    try {
      final value = await request;
      _postsCache[key] = _PostsCacheEntry(
        value,
        DateTime.now().add(_listCacheDuration),
      );
      return value;
    } finally {
      if (identical(_postsInFlight[key], request)) {
        _postsInFlight.remove(key);
      }
    }
  }

  Future<PostsPage> _fetchPosts({
    int page = 1,
    int perPage = 10,
    String search = '',
    int categoryId = 0,
    bool? sticky,
    bool allowPersistentCache = true,
  }) async {
    try {
      final normalizedSearch = search.trim();
      final hasSearch = normalizedSearch.isNotEmpty;
      final data = await _getHeadCached(
        '/posts',
        queryParameters: {
          'page': page,
          // Search needs the full article body. The summary response has an
          // empty `content` field and cannot be filtered safely on-device.
          'per_page': hasSearch ? 100 : perPage,
          'summary': !hasSearch,
          if (hasSearch) 'search': normalizedSearch,
          if (categoryId > 0) 'category': categoryId,
          if (sticky != null) 'sticky': sticky ? 1 : 0,
        },
        forceRefresh: !allowPersistentCache,
      );

      if (data is List<dynamic>) {
        final rawPosts = data.whereType<Map<String, dynamic>>().toList();
        final allPosts = (await _hydratePostTags(rawPosts))
            .map(Post.fromJson)
            .toList();
        final posts = normalizedSearch.isEmpty
            ? allPosts
            : allPosts
                  .where((post) => _matchesNewsSearch(post, normalizedSearch))
                  .toList();

        return PostsPage(
          items: posts,
          page: page,
          perPage: perPage,
          total: posts.length,
          totalPages: 1,
          hasMore: false,
        );
      }

      final json = data as Map<String, dynamic>;
      final items = (json['items'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();
      final hydratedItems = await _hydratePostTags(items);
      final parsedItems = hydratedItems.map(Post.fromJson).toList();
      final visibleItems = normalizedSearch.isEmpty
          ? parsedItems
          : parsedItems
                .where((post) => _matchesNewsSearch(post, normalizedSearch))
                .toList(growable: false);
      final currentPage = _readInt(json['page'], fallback: page);
      final totalPages = _readInt(json['total_pages'], fallback: 1);
      final hasMore = _readBool(json['has_more']) || currentPage < totalPages;

      return PostsPage(
        items: visibleItems,
        page: currentPage,
        perPage: _readInt(json['per_page'], fallback: perPage),
        total: normalizedSearch.isEmpty
            ? _readInt(json['total'])
            : visibleItems.length,
        totalPages: totalPages,
        hasMore: hasMore,
      );
    } on DioException catch (e) {
      throw Exception(_readApiError(e, 'Nem sikerült betölteni a híreket.'));
    } catch (_) {
      throw Exception('Nem sikerült betölteni a híreket.');
    }
  }

  bool _matchesNewsSearch(Post post, String search) {
    final query = search.toLowerCase();
    final plainContent = post.content.replaceAll(RegExp(r'<[^>]*>'), ' ');
    return post.title.toLowerCase().contains(query) ||
        plainContent.toLowerCase().contains(query);
  }

  Future<Set<int>> getAllPostIds() async {
    final ids = <int>{};
    var page = 1;
    while (true) {
      final result = await getPosts(page: page, perPage: 100);
      ids.addAll(result.items.map((post) => post.id));
      if (!result.hasMore || result.items.isEmpty) break;
      page++;
    }
    return ids;
  }

  Future<List<Post>> getLatestPosts() async {
    // Use the short-lived memory/persistent cache for a fast first render.
    // The News screen still has explicit refresh and forceRefresh paths, so
    // new or withdrawn articles are not hidden indefinitely.
    final page = await getPosts();
    return page.items;
  }

  /// Sticky posts for the "Kiemelt" row of the news screen.
  ///
  /// The display path reads the layered cache like every other list: the stored
  /// row is painted immediately and the ETag revalidation replaces it in the
  /// background, then bumps [publicContentRefreshGeneration] so the row updates
  /// without a gesture. Pass [forceRefresh] only on an explicit user refresh.
  Future<List<Post>> getStickyPosts({
    String search = '',
    int categoryId = 0,
    bool forceRefresh = false,
  }) async {
    final page = await getPosts(
      page: 1,
      perPage: 50,
      search: search,
      categoryId: categoryId,
      sticky: true,
      forceRefresh: forceRefresh,
    );
    return page.items;
  }

  Future<List<FaqItem>> getFaq({bool forceRefresh = false}) async {
    if (forceRefresh) _faqCache.remove('faq');
    return _cached<List<FaqItem>>(
      key: 'faq',
      ttl: const Duration(minutes: 10),
      cache: _faqCache,
      inFlight: _faqInFlight,
      loader: () => _fetchFaq(allowPersistentCache: !forceRefresh),
    );
  }

  Future<List<FaqItem>> _fetchFaq({bool allowPersistentCache = true}) async {
    try {
      final data = await _getHeadCached(
        '/faq',
        forceRefresh: !allowPersistentCache,
      );
      final raw = data is List<dynamic>
          ? data
          : (data is Map<String, dynamic> ? data['items'] : null);
      if (raw is! List<dynamic>) return const [];
      final result = raw
          .whereType<Map<String, dynamic>>()
          .map(FaqItem.fromJson)
          .where((item) => item.question.trim().isNotEmpty)
          .toList(growable: false);
      return result;
    } on DioException catch (e) {
      throw Exception(_readApiError(e, 'Nem sikerült betölteni a GYIK-et.'));
    }
  }

  Future<Post> getPost(int postId, {bool forceRefresh = false}) async {
    if (forceRefresh) _postDetailCache.remove(postId);
    return _cachedById<Post>(
      key: postId,
      ttl: const Duration(minutes: 5),
      cache: _postDetailCache,
      inFlight: _postDetailInFlight,
      loader: () async {
        final data = await _getHeadCached(
          '/posts/$postId',
          forceRefresh: forceRefresh,
        );
        if (data is Map<String, dynamic>) {
          final hydrated = await _hydratePostTags([data]);
          return Post.fromJson(hydrated.first);
        }
        throw const FormatException('Hibás hír válasz.');
      },
    );
  }

  /// Registers a native-app article open in the WordPress view counter.
  ///
  /// This is deliberately best-effort: a missing/temporarily unavailable
  /// counter must never prevent the article from being displayed.
  Future<bool> recordPostView(int postId) async {
    if (postId <= 0) return false;

    try {
      final response = await _dio.post('/posts/$postId/view');
      return response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300;
    } on DioException {
      return false;
    }
  }

  /// A címke-nevek pótlása a hír-végpont azonosítóihoz.
  ///
  /// **ELŐBB a gyorsítótár, és csak utána a hálózat.** A címkenév ritkán változó
  /// adat, ezért egy találatnál a kirajzolás **nem** vár hálózatra — ez a
  /// lényeg: egy kör a WordPressnél mérve 0,4–2,0 s, és ez a függvény eddig
  /// MINDEN hírlista-, keresés- és cikk-lekérdezéshez hozzátett egy másodikat.
  ///
  /// A találat útja viszont nem „örök": a mentett érték a
  /// [_persistentCacheTtl] letelte után **a háttérben** egyeztet (átnevezett
  /// címke, átszámozott cikk), ugyanúgy, ahogy a kategóriáknál — a friss válasz
  /// felülírja a mentettet, a kirajzolás pedig addig a mentett neveket használja.
  ///
  /// A kulcs a kért azonosítók **sorba rendezett** halmaza (lásd
  /// [postTagCacheKey]), a mentés pedig a meglévő állandó gyorsítótáron megy
  /// (`_readPersistentJson` / `_writePersistentJson`), ezért memóriából és
  /// lemezről is azonnal válaszol.
  ///
  /// Hiba esetén a viselkedés változatlan: a bemeneti lista megy vissza, csak a
  /// címkenevek nélkül.
  Future<List<Map<String, dynamic>>> _hydratePostTags(
    List<Map<String, dynamic>> posts,
  ) async {
    final ids = posts
        .map((post) => _readInt(post['id']))
        .where((id) => id > 0)
        .toList();
    if (ids.isEmpty || posts.every((post) => _hasNamedTags(post))) {
      return posts;
    }

    final cacheKey = postTagCacheKey(ids);
    final stored = decodePostTagNames(await _readPersistentJson(cacheKey));
    if (stored.isNotEmpty) {
      if (await _persistentValueNeedsRefresh(cacheKey)) {
        _schedulePersistentRefresh(
          cacheKey,
          () => _refreshPostTagNames(cacheKey, ids),
        );
      }
      return applyPostTagNames(posts, stored);
    }

    final byId = await _fetchPostTagNames(ids);
    if (byId.isNotEmpty) {
      // A mentés a háttérben történik: a kirajzolás nem várhat a lemezre.
      unawaited(_writePersistentJson(cacheKey, encodePostTagNames(byId)));
    }
    return applyPostTagNames(posts, byId);
  }

  /// A háttér-egyeztetés: a lejárt mentett címkenevek frissítése.
  Future<void> _refreshPostTagNames(String cacheKey, List<int> ids) async {
    final byId = await _fetchPostTagNames(ids);
    if (byId.isEmpty) return;
    await _writePersistentJson(cacheKey, encodePostTagNames(byId));
  }

  /// A címkenevek lekérdezése a WordPress alapszolgáltatásából.
  ///
  /// A `_hydratePostTags` és a háttér-egyeztetés is **ezt** használja, ezért a
  /// két út nem tud eltérni egymástól. Hiba esetén üres térkép jön (nem dob): a
  /// szerver válaszától függetlenül a hívó a bemeneti listát adja vissza.
  Future<Map<int, List<String>>> _fetchPostTagNames(List<int> ids) async {
    try {
      final response = await _dio.get(
        'https://hungarianhardstyle.hu/wp-json/wp/v2/posts',
        options: Options(
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
        queryParameters: {
          'include': ids.join(','),
          'per_page': ids.length,
          '_embed': true,
          '_fields': 'id,tags,_embedded',
        },
      );
      final byId = <int, List<String>>{};
      for (final item in (response.data as List<dynamic>? ?? const [])) {
        if (item is! Map<String, dynamic>) continue;
        final id = _readInt(item['id']);
        final names = Post.fromWordpressJson(item).tags;
        if (id > 0 && names.isNotEmpty) byId[id] = names;
      }
      return byId;
    } catch (_) {
      // The custom endpoint remains usable if the optional core REST lookup
      // is blocked or unavailable.
      return const {};
    }
  }

  bool _hasNamedTags(Map<String, dynamic> post) {
    final value = post['tag_names'] ?? post['tag'] ?? post['tags'];
    if (value is String) return value.trim().isNotEmpty;
    if (value is List) {
      return value.any((item) => item is String || item is Map);
    }
    return false;
  }

  Future<void> subscribeNewsletter({
    required String email,
    required bool consent,
  }) async {
    try {
      await _dio.post(
        '/newsletter/subscribe',
        data: {'email': email.trim(), 'consent': consent},
      );
    } on DioException catch (e) {
      throw Exception(
        _readApiError(e, 'A hírlevél-feliratkozás nem sikerült.'),
      );
    }
  }

  Future<List<HuhsEvent>> getEvents({
    bool includePast = false,
    int page = 1,
    int perPage = 12,
    bool forceRefresh = false,
  }) async {
    final result = await getEventsPage(
      includePast: includePast,
      page: page,
      perPage: perPage,
      forceRefresh: forceRefresh,
    );
    return result.items;
  }

  Future<EventsPage> getEventsPage({
    bool includePast = false,
    int page = 1,
    int perPage = 12,
    bool forceRefresh = false,
  }) async {
    final safePage = page < 1 ? 1 : page;
    final safePerPage = perPage.clamp(1, 25);
    final key = '${includePast ? 'past' : 'upcoming'}|$safePage|$safePerPage';
    if (forceRefresh) _eventsCache.remove(key);
    return _cached<EventsPage>(
      key: key,
      ttl: const Duration(seconds: 45),
      cache: _eventsCache,
      inFlight: _eventsInFlight,
      loader: () => _fetchEventsPage(
        includePast: includePast,
        page: safePage,
        perPage: safePerPage,
        forceRefresh: forceRefresh,
      ),
    );
  }

  Future<EventsPage> _fetchEventsPage({
    required bool includePast,
    required int page,
    required int perPage,
    bool forceRefresh = false,
  }) async {
    try {
      // Events are editable in WordPress, so persistent caching can keep an
      // old title or venue visible for minutes after an admin update. The
      // in-memory cache above is enough and is cleared by pull-to-refresh.
      final data = await _getHeadCached(
        '/events',
        queryParameters: {
          'summary': true,
          'page': page,
          'per_page': perPage,
          // The API's default upcoming filter incorrectly drops events whose
          // start date is today, even when their end time is still future.
          // Fetch the same paged data without that server-side cutoff and
          // apply the authoritative local start/end-time filter below.
          'include_past': true,
        },
        forceRefresh: forceRefresh,
      );

      if (data is List<dynamic>) {
        final events = data
            .map((json) => HuhsEvent.fromJson(json as Map<String, dynamic>))
            .toList();
        final filtered = includePast
            ? events
            : events.where((event) => !event.isPast).toList();
        return EventsPage(
          items: filtered,
          page: page,
          perPage: perPage,
          total: filtered.length,
          hasMore: false,
        );
      }

      if (data is Map<String, dynamic>) {
        final items = data['items'] as List<dynamic>? ?? [];

        final events = items
            .map((json) => HuhsEvent.fromJson(json as Map<String, dynamic>))
            .toList();
        final filtered = includePast
            ? events
            : events.where((event) => !event.isPast).toList();
        final currentPage = _readInt(data['page'], fallback: page);
        final currentPerPage = _readInt(data['per_page'], fallback: perPage);
        final total = _readInt(data['total'], fallback: filtered.length);
        final hasMore = data.containsKey('has_more')
            ? _readBool(data['has_more'])
            : filtered.length >= currentPerPage;
        return EventsPage(
          items: filtered,
          page: currentPage,
          perPage: currentPerPage,
          total: total,
          hasMore: hasMore,
        );
      }

      return EventsPage(
        items: const [],
        page: page,
        perPage: perPage,
        total: 0,
        hasMore: false,
      );
    } on DioException catch (e) {
      throw Exception(
        _readApiError(e, 'Nem sikerült betölteni az eseményeket.'),
      );
    } catch (_) {
      throw Exception('Nem sikerült betölteni az eseményeket.');
    }
  }

  Future<HuhsEvent> getEvent(int eventId) async {
    return _cachedById<HuhsEvent>(
      key: eventId,
      ttl: const Duration(minutes: 2),
      cache: _eventDetailCache,
      inFlight: _eventDetailInFlight,
      loader: () async {
        Object? data;
        try {
          data = await _getHeadCached('/events/$eventId');
          if (data is Map<String, dynamic>) return HuhsEvent.fromJson(data);
        } catch (_) {
          // Compatibility with HUHS Mobile API versions before 2.4.102.
        }
        data = await _getHeadCached(
          '/events',
          queryParameters: {'include_past': true},
        );
        final values = data is List
            ? data
            : data is Map<String, dynamic>
            ? data['items']
            : null;
        if (values is List) {
          for (final value in values) {
            if (value is Map<String, dynamic> &&
                _readInt(value['id']) == eventId) {
              return HuhsEvent.fromJson(value);
            }
          }
        }
        throw const FormatException('Hibás esemény-adatlap válasz.');
      },
    );
  }

  Future<ArtistsPage> getArtists({
    String search = '',
    String category = '',
    int page = 1,
    int perPage = 50,
    bool forceRefresh = false,
  }) async {
    final key =
        '$page|$perPage|${search.trim().toLowerCase()}|${category.trim().toLowerCase()}';
    if (forceRefresh) _artistsCache.remove(key);
    return _cached<ArtistsPage>(
      key: key,
      ttl: const Duration(minutes: 10),
      cache: _artistsCache,
      inFlight: _artistsInFlight,
      loader: () => _fetchArtists(
        search: search,
        category: category,
        page: page,
        perPage: perPage,
        allowPersistentCache: !forceRefresh,
      ),
    );
  }

  Future<ArtistsPage> _fetchArtists({
    String search = '',
    String category = '',
    int page = 1,
    int perPage = 50,
    bool allowPersistentCache = true,
  }) async {
    try {
      final data = await _getHeadCached(
        '/artists',
        queryParameters: {
          'page': page,
          'per_page': perPage,
          'summary': true,
          if (search.trim().isNotEmpty) 'search': search.trim(),
          if (category.trim().isNotEmpty) 'category': category.trim(),
        },
        forceRefresh: !allowPersistentCache,
      );

      if (data is Map<String, dynamic>) {
        final pageResult = ArtistsPage.fromJson(data);
        final query = search.trim().toLowerCase();
        if (query.isEmpty) return pageResult;
        final items = pageResult.items
            .where(
              (artist) =>
                  '${artist.title} ${artist.slug} ${artist.realName} '
                          '${artist.city} ${artist.country}'
                      .toLowerCase()
                      .contains(query),
            )
            .toList(growable: false);
        return ArtistsPage(
          items: items,
          page: pageResult.page,
          perPage: pageResult.perPage,
          total: items.length,
          totalPages: pageResult.totalPages,
          hasMore: pageResult.hasMore,
        );
      }

      throw const FormatException('Hibás DJ-lista válasz.');
    } on DioException catch (e) {
      throw Exception(_readApiError(e, 'Nem sikerült betölteni a DJ-ket.'));
    } catch (_) {
      throw Exception('Nem sikerült betölteni a DJ-ket.');
    }
  }

  Future<Set<int>> getAllArtistIds() async {
    final ids = <int>{};
    var page = 1;
    while (true) {
      final result = await getArtists(page: page, perPage: 100);
      ids.addAll(result.items.map((artist) => artist.id));
      if (!result.hasMore || result.items.isEmpty) break;
      page++;
    }
    return ids;
  }

  Future<Artist> getArtist(int artistId, {bool forceRefresh = false}) async {
    if (forceRefresh) _artistCache.remove(artistId);
    return _cachedById<Artist>(
      key: artistId,
      ttl: const Duration(minutes: 10),
      cache: _artistCache,
      inFlight: _artistInFlight,
      loader: () => _fetchArtist(artistId, allowPersistentCache: !forceRefresh),
    );
  }

  Future<Artist> _fetchArtist(
    int artistId, {
    bool allowPersistentCache = true,
  }) async {
    try {
      final data = await _getHeadCached(
        '/artists/$artistId',
        forceRefresh: !allowPersistentCache,
      );

      if (data is Map<String, dynamic>) {
        return Artist.fromJson(data);
      }

      throw const FormatException('Hibás DJ-adatlap válasz.');
    } on DioException catch (e) {
      throw Exception(
        _readApiError(e, 'Nem sikerült betölteni a DJ-adatlapot.'),
      );
    } catch (_) {
      throw Exception('Nem sikerült betölteni a DJ-adatlapot.');
    }
  }

  Future<OrganizersPage> getOrganizers({
    String search = '',
    int page = 1,
    int perPage = 50,
    bool forceRefresh = false,
  }) async {
    final key = '$page|$perPage|${search.trim().toLowerCase()}';
    if (forceRefresh) _organizersCache.remove(key);
    return _cached<OrganizersPage>(
      key: key,
      ttl: const Duration(minutes: 10),
      cache: _organizersCache,
      inFlight: _organizersInFlight,
      loader: () => _fetchOrganizers(
        search: search,
        page: page,
        perPage: perPage,
        allowPersistentCache: !forceRefresh,
      ),
    );
  }

  Future<OrganizersPage> _fetchOrganizers({
    String search = '',
    int page = 1,
    int perPage = 50,
    bool allowPersistentCache = true,
  }) async {
    try {
      final data = await _getHeadCached(
        '/organizers',
        queryParameters: {
          'page': page,
          'per_page': perPage,
          'summary': true,
          if (search.trim().isNotEmpty) 'search': search.trim(),
        },
        forceRefresh: !allowPersistentCache,
      );

      if (data is Map<String, dynamic>) {
        final pageResult = OrganizersPage.fromJson(data);
        final query = search.trim().toLowerCase();
        if (query.isEmpty) return pageResult;
        final items = pageResult.items
            .where(
              (organizer) =>
                  '${organizer.title} ${organizer.slug} ${organizer.city} '
                          '${organizer.country}'
                      .toLowerCase()
                      .contains(query),
            )
            .toList(growable: false);
        return OrganizersPage(
          items: items,
          page: pageResult.page,
          perPage: pageResult.perPage,
          total: items.length,
          totalPages: pageResult.totalPages,
          hasMore: pageResult.hasMore,
        );
      }

      throw const FormatException('Hibás szervezőlista-válasz.');
    } on DioException catch (e) {
      throw Exception(
        _readApiError(e, 'Nem sikerült betölteni a szervezőket.'),
      );
    } catch (_) {
      throw Exception('Nem sikerült betölteni a szervezőket.');
    }
  }

  Future<Set<int>> getAllOrganizerIds() async {
    final ids = <int>{};
    var page = 1;
    while (true) {
      final result = await getOrganizers(page: page, perPage: 100);
      ids.addAll(result.items.map((organizer) => organizer.id));
      if (!result.hasMore || result.items.isEmpty) break;
      page++;
    }
    return ids;
  }

  Future<OrganizerProfile> getOrganizer(
    int organizerId, {
    bool forceRefresh = false,
  }) async {
    if (forceRefresh) _organizerCache.remove(organizerId);
    return _cachedById<OrganizerProfile>(
      key: organizerId,
      ttl: const Duration(minutes: 10),
      cache: _organizerCache,
      inFlight: _organizerInFlight,
      loader: () =>
          _fetchOrganizer(organizerId, allowPersistentCache: !forceRefresh),
    );
  }

  Future<OrganizerProfile> _fetchOrganizer(
    int organizerId, {
    bool allowPersistentCache = true,
  }) async {
    try {
      final data = await _getHeadCached(
        '/organizers/$organizerId',
        forceRefresh: !allowPersistentCache,
      );

      if (data is Map<String, dynamic>) {
        return OrganizerProfile.fromJson(data);
      }

      throw const FormatException('Hibás szervezői adatlap válasz.');
    } on DioException catch (e) {
      throw Exception(
        _readApiError(e, 'Nem sikerült betölteni a szervezői adatlapot.'),
      );
    } catch (_) {
      throw Exception('Nem sikerült betölteni a szervezői adatlapot.');
    }
  }

  Future<List<HuhsRelease>> getReleases({
    String search = '',
    int artistId = 0,
    bool forceRefresh = false,
  }) async {
    final key = '${search.trim()}|$artistId';
    final now = DateTime.now();
    final cached = _releasesCache[key];
    if (!forceRefresh && cached != null && cached.expiresAt.isAfter(now)) {
      return cached.value;
    }
    final existing = _releasesInFlight[key];
    if (existing != null) return existing;

    final request = _fetchReleases(
      search: search,
      artistId: artistId,
      allowPersistentCache: !forceRefresh,
    );
    _releasesInFlight[key] = request;
    try {
      final value = await request;
      _releasesCache[key] = _ReleasesCacheEntry(
        value,
        DateTime.now().add(_listCacheDuration),
      );
      return value;
    } finally {
      if (identical(_releasesInFlight[key], request)) {
        _releasesInFlight.remove(key);
      }
    }
  }

  Future<HuhsRelease> getRelease(int releaseId) async {
    return _cachedById<HuhsRelease>(
      key: releaseId,
      ttl: const Duration(minutes: 5),
      cache: _releaseDetailCache,
      inFlight: _releaseDetailInFlight,
      loader: () async {
        // A dedicated detail route exists and returns the complete record
        // (tracks with `preview_url`, `product_prices`, `versions`,
        // `audio_status`). Read that first: it is one small request instead of
        // downloading the whole release catalogue for a single record.
        try {
          final detail = await _getHeadCached('/releases/$releaseId');
          final record = detail is Map<String, dynamic>
              ? detail
              : detail is Map
              ? Map<String, dynamic>.from(detail)
              : null;
          if (record != null && _readInt(record['id']) == releaseId) {
            return HuhsRelease.fromJson(record);
          }
        } catch (_) {
          // Fall through to the collection payload below.
        }
        // Fallback: the collection endpoint always carries the full records
        // (only `summary=true` strips the tracks), so the detail screen can
        // still be completed if the detail route is unavailable or cached
        // under an older shape.
        final data = await _getHeadCached('/releases');
        final values = data is List
            ? data
            : data is Map<String, dynamic>
            ? data['items']
            : null;
        if (values is List) {
          for (final value in values) {
            if (value is Map<String, dynamic> &&
                _readInt(value['id']) == releaseId) {
              return HuhsRelease.fromJson(value);
            }
          }
        }
        throw const FormatException('Hibás release-adatlap válasz.');
      },
    );
  }

  Future<List<HuhsRelease>> _fetchReleases({
    String search = '',
    int artistId = 0,
    bool allowPersistentCache = false,
  }) async {
    try {
      final data = await _getHeadCached(
        '/releases',
        queryParameters: {
          'summary': true,
          if (search.trim().isNotEmpty) 'search': search.trim(),
          if (artistId > 0) 'artist': artistId,
        },
        forceRefresh: !allowPersistentCache,
      );
      final values = data is List
          ? data
          : data is Map<String, dynamic>
          ? data['items']
          : null;
      if (values is! List) return const [];
      final releases = values
          .whereType<Map<String, dynamic>>()
          .map(HuhsRelease.fromJson)
          .toList(growable: false);
      return releases;
    } on DioException catch (e) {
      throw Exception(
        _readApiError(e, 'Nem sikerült betölteni a release-eket.'),
      );
    }
  }

  Future<VotingSeason> getActiveVoting() async {
    try {
      final data = await _getHeadCached('/voting/active');
      if (data is Map) {
        return VotingSeason.fromJson(Map<String, dynamic>.from(data));
      }
      return const VotingSeason.inactive();
    } on DioException {
      // The Home button is optional; a temporarily unavailable voting endpoint
      // must not block the rest of the Home screen.
      return const VotingSeason.inactive();
    }
  }

  /// A jelenleg nyitott kerdőív, vagy null, ha épp nincs ilyen.
  ///
  /// Az app szandekosan nem szamolja ki az időablakot: a WordPress donti el a
  /// webhely időzonajaban, es csak nyitott kerdőívet ad vissza, így egy elállított
  /// keszülék-ido nem tudja kitolni az ablakot.
  ///
  /// `bypassCache: true` eseten a mentett valasz **egyaltalan nem** donthet.
  /// A kerdőív nyitasa es zarasa időponthoz kotott, es a `forceRefresh` erre nem
  /// volt eleg: az HEAD + ETag egyeztetessel dolgozik, a WordPress cache-elt
  /// valasza pedig ugyanazt az ETag-ot adja vissza, ezert a kliens a REGI testet
  /// szolgalta ki. A `forceRefresh` marad a „felhasznalo frissitett" jelentesre.
  Future<Map<String, dynamic>?> getActivePoll({
    bool forceRefresh = false,
    bool bypassCache = false,
  }) async {
    try {
      final data = await _getHeadCached(
        '/poll/active',
        forceRefresh: forceRefresh,
        bypassCache: bypassCache,
      );
      if (data is Map) {
        final poll = data['poll'];
        if (poll is Map) return Map<String, dynamic>.from(poll);
      }
      return null;
    } on DioException {
      // A kerdőív opcionalis; egy atmenetileg elerhetetlen vegpont nem
      // akadalyozhatja a főoldal többi reszet.
      return null;
    }
  }

  /// A jelenleg latszo nyeremenyjatek, vagy null, ha épp nincs ilyen.
  ///
  /// Ket allapot letezik: nyitott jatek (akkor a kerdes es a valaszlehetosegek
  /// jonnek le), illetve kihirdetett nyertes (akkor a kerdes NEM, csak a nyertes
  /// es a nyeremeny leirasa). A helyes valaszt a szerver soha nem kuldi el a
  /// sorsolas elott.
  ///
  /// Az időablakot mint a kerdőívnél: a WordPress donti el a webhely
  /// időzonajaban, ezert `bypassCache: true` eseten a mentett valasz **nem**
  /// dönthet — a sorsolas utan kihirdetett nyertesnek azonnal meg kell jelennie.
  Future<Map<String, dynamic>?> getActivePrize({
    bool forceRefresh = false,
    bool bypassCache = false,
  }) async {
    try {
      final data = await _getHeadCached(
        '/prize/active',
        forceRefresh: forceRefresh,
        bypassCache: bypassCache,
      );
      if (data is Map) {
        final prize = data['prize'];
        if (prize is Map) return Map<String, dynamic>.from(prize);
      }
      return null;
    } on DioException {
      // A nyeremenyjatek opcionalis; egy atmenetileg elerhetetlen vegpont nem
      // akadalyozhatja a főoldal többi reszet.
      return null;
    }
  }

  Future<ProfileSubmissionOptions> getProfileSubmissionOptions() async {
    try {
      final data = await _getHeadCached('/profile-submission-options');

      if (data is Map<String, dynamic>) {
        return ProfileSubmissionOptions.fromJson(data);
      }

      throw const FormatException('Hibás beküldési beállítások.');
    } on DioException catch (e) {
      throw Exception(
        _readApiError(e, 'Nem sikerült betölteni a beküldési adatokat.'),
      );
    } catch (_) {
      throw Exception('Nem sikerült betölteni a beküldési adatokat.');
    }
  }

  Future<String> submitArtist(
    ArtistSubmission submission, {
    SubmissionImage? image,
    SubmissionImage? logo,
  }) async {
    final payload = submission.toJson();
    if (image != null) {
      payload['profile_image_url'] = await _uploadCloudinaryImage(image);
    }
    if (logo != null) {
      payload['logo_url'] = await _uploadCloudinaryImage(logo);
    }
    return _submitProfile('artist', payload);
  }

  Future<String> submitOrganizer(
    OrganizerSubmission submission, {
    SubmissionImage? image,
  }) async {
    final payload = submission.toJson();
    if (image != null) {
      payload['logo_url'] = await _uploadCloudinaryImage(image);
    }
    return _submitProfile('organizer', payload);
  }

  Future<String> _submitProfile(String kind, Map<String, dynamic> data) async {
    try {
      final responseData = (await callFirebaseCallable<Map<String, dynamic>>(
        'submitWordPressContent',
        parameters: {'kind': kind, 'payload': data},
      )).data;
      final message = _readResponseMessage(responseData);
      if (message != null) return message;

      return 'Köszönjük, a beküldést elküldtük ellenőrzésre.';
    } on DioException catch (e) {
      throw Exception(_readApiError(e, 'A beküldés nem sikerült.'));
    } catch (_) {
      throw Exception('A beküldés nem sikerült.');
    }
  }

  Future<List<String>> getEventSubmissionGenres() async {
    try {
      final data = await _getHeadCached('/event-submission-options');
      if (data is! Map) throw const FormatException('Hibás műfajlista.');
      final values = Map<String, dynamic>.from(data);
      final genres = values['genres'] as List<dynamic>? ?? const [];

      return genres
          .whereType<String>()
          .map((genre) => genre.trim())
          .where((genre) => genre.isNotEmpty)
          .toList(growable: false);
    } on DioException catch (e) {
      throw Exception(_readApiError(e, 'Nem sikerült betölteni a műfajokat.'));
    } catch (_) {
      throw Exception('Nem sikerült betölteni a műfajokat.');
    }
  }

  Future<String> submitEvent(
    EventSubmission submission, {
    SubmissionImage? image,
  }) async {
    try {
      final payload = submission.toJson();
      if (image != null) {
        payload['flyer_url'] = await _uploadCloudinaryImage(image);
      }
      final responseData = (await callFirebaseCallable<Map<String, dynamic>>(
        'submitWordPressContent',
        parameters: {'kind': 'event', 'payload': payload},
      )).data;
      final message = _readResponseMessage(responseData);
      if (message != null) return message;

      return 'Köszönjük, az eseményt elküldtük ellenőrzésre.';
    } on DioException catch (e) {
      throw Exception(_readApiError(e, 'Az eseményt nem sikerült elküldeni.'));
    } catch (_) {
      throw Exception('Az eseményt nem sikerült elküldeni.');
    }
  }

  /// Kép feltöltése a Cloudinary-ra — **ugyanaz az ellenőrzött út**, mint a
  /// beküldésnél (JPG/PNG/WebP, legfeljebb 5 MB, valódi kép-bájtok).
  ///
  /// MIÉRT publikus: a DJ a saját (átvett) adatlapján cserélhet képet, és ott
  /// ugyanazt a szabályt kell használni — nem egy második feltöltő utat.
  Future<String> uploadProfileImage(SubmissionImage image) =>
      _uploadCloudinaryImage(image);

  Future<String> _uploadCloudinaryImage(SubmissionImage image) async {
    try {
      final extension = image.name.split('.').last.toLowerCase();
      if (image.bytes.isEmpty ||
          image.bytes.length > _maxUploadBytes ||
          !_allowedImageExtensions.contains(extension) ||
          !_isSupportedImageBytes(image.bytes)) {
        throw const FormatException(
          'JPG, PNG vagy WebP kép szükséges, legfeljebb 5 MB méretben.',
        );
      }
      final response = await _dio.postUri(
        Uri.parse(
          'https://api.cloudinary.com/v1_1/$_cloudinaryCloudName/image/upload',
        ),
        data: FormData.fromMap({
          'file': MultipartFile.fromBytes(image.bytes, filename: image.name),
          'upload_preset': _cloudinaryUploadPreset,
        }),
        options: Options(receiveTimeout: const Duration(seconds: 30)),
      );
      final url = response.data is Map ? response.data['secure_url'] : null;
      if (url is String && url.trim().isNotEmpty) return url.trim();
      throw const FormatException('A kép URL-je nem érkezett meg.');
    } on DioException catch (e) {
      throw Exception(_readApiError(e, 'A képet nem sikerült feltölteni.'));
    }
  }

  String _readApiError(DioException exception, String fallback) {
    final data = exception.response?.data;

    if (data is Map<String, dynamic>) {
      final message = data['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
    }

    if (data is String && data.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map<String, dynamic>) {
          final message = decoded['message'];
          if (message is String && message.trim().isNotEmpty) {
            return message.trim();
          }
        }
      } catch (_) {
        // Keep the localized fallback for non-JSON server responses.
      }
    }

    return fallback;
  }

  Object? _decodePossiblyPrefixedJson(String value) {
    final arrayStart = value.indexOf('[');
    final objectStart = value.indexOf('{');
    final starts = [arrayStart, objectStart].where((index) => index >= 0);

    if (starts.isEmpty) return null;

    return jsonDecode(value.substring(starts.reduce((a, b) => a < b ? a : b)));
  }

  Future<List<NewsCategory>> getCategories({bool forceRefresh = false}) async {
    try {
      const key = 'huhs.wp.categories';
      final cached = forceRefresh ? null : await _readPersistentJson(key);
      // The stored category list is served whatever its age, so the news filter
      // chips never wait for WordPress. Only the revalidation is delayed until
      // the freshness window passed; a forced refresh writes the new list.
      if (cached is List && await _persistentValueNeedsRefresh(key)) {
        _schedulePersistentRefresh(key, () async {
          await getCategories(forceRefresh: true);
        });
      }
      final data = cached is List
          ? cached
          : (await _dio.get(
                  'https://hungarianhardstyle.hu/wp-json/wp/v2/categories',
                  queryParameters: {
                    'per_page': 100,
                    'hide_empty': true,
                    '_fields': 'id,name,slug,count',
                  },
                )).data
                as List<dynamic>;
      if (cached == null) unawaited(_writePersistentJson(key, data));

      return data
          .map((json) => NewsCategory.fromJson(json as Map<String, dynamic>))
          .where((category) => category.id > 0 && category.name.isNotEmpty)
          .toList();
    } on DioException catch (_) {
      return const [];
    } catch (_) {
      return const [];
    }
  }

  Future<Set<int>> getPostIdsForCategory(int categoryId) async {
    if (categoryId <= 0) {
      return const {};
    }

    final postIds = <int>{};
    var page = 1;
    var totalPages = 1;

    try {
      do {
        final response = await _dio.get(
          'https://hungarianhardstyle.hu/wp-json/wp/v2/posts',
          queryParameters: {
            'categories': categoryId,
            'per_page': 100,
            'page': page,
            '_fields': 'id',
          },
        );

        final data = response.data as List<dynamic>;

        for (final item in data) {
          if (item is Map<String, dynamic>) {
            final id = _readInt(item['id']);

            if (id > 0) {
              postIds.add(id);
            }
          }
        }

        totalPages = _readInt(
          response.headers.value('x-wp-totalpages'),
          fallback: totalPages,
        );
        page += 1;
      } while (page <= totalPages);
    } catch (_) {
      return postIds;
    }

    return postIds;
  }

  Future<PostsPage> getStandardPosts({
    int categoryId = 0,
    String search = '',
    int page = 1,
    int perPage = 10,
  }) async {
    try {
      final response = await _dio.get(
        'https://hungarianhardstyle.hu/wp-json/wp/v2/posts',
        queryParameters: {
          if (categoryId > 0) 'categories': categoryId,
          if (search.trim().isNotEmpty) 'search': search.trim(),
          'page': page,
          'per_page': perPage,
          '_embed': true,
        },
      );

      final data = response.data as List<dynamic>;
      final total = _readInt(response.headers.value('x-wp-total'));
      final totalPages = _readInt(
        response.headers.value('x-wp-totalpages'),
        fallback: 1,
      );

      return PostsPage(
        items: data
            .map((json) => Post.fromWordpressJson(json as Map<String, dynamic>))
            .toList(),
        page: page,
        perPage: perPage,
        total: total,
        totalPages: totalPages,
        hasMore: page < totalPages,
      );
    } on DioException catch (e) {
      throw Exception(_readApiError(e, 'Nem sikerült betölteni a híreket.'));
    } catch (_) {
      throw Exception('Nem sikerült betölteni a híreket.');
    }
  }

  bool _readBool(Object? value) {
    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    if (value is String) {
      final normalized = value.toLowerCase();
      return normalized == 'true' || normalized == '1';
    }

    return false;
  }
}
