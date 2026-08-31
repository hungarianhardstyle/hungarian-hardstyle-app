import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/artist.dart';
import '../models/event.dart';
import '../models/event_submission.dart';
import '../models/faq.dart';
import '../models/organizer.dart';
import '../models/post.dart';
import '../models/profile_submission.dart';
import '../models/release.dart';
import '../models/submission_image.dart';
import '../models/voting.dart';

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

  final Dio _dio =
      Dio(
          BaseOptions(
            baseUrl: 'https://hungarianhardstyle.hu/wp-json/huhs/v1',
            connectTimeout: const Duration(seconds: 20),
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
            onError: (error, handler) {
              _logApiTiming(
                error.requestOptions,
                error.response?.statusCode,
                error.response?.data,
              );
              handler.next(error);
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

  static const _listCacheDuration = Duration(seconds: 30);
  final Map<String, _PostsCacheEntry> _postsCache = {};
  final Map<String, Future<PostsPage>> _postsInFlight = {};
  final Map<String, _ReleasesCacheEntry> _releasesCache = {};
  final Map<String, Future<List<HuhsRelease>>> _releasesInFlight = {};
  final Map<String, _TimedCacheEntry<List<HuhsEvent>>> _eventsCache = {};
  final Map<String, Future<List<HuhsEvent>>> _eventsInFlight = {};
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

  static const _persistentCacheTtl = Duration(minutes: 5);
  Future<SharedPreferences>? _preferencesFuture;
  final Map<String, _TimedCacheEntry<Object?>> _persistentJsonCache = {};

  Future<SharedPreferences> _preferences() {
    return _preferencesFuture ??= SharedPreferences.getInstance();
  }

  Future<Object?> _readPersistentJson(String key) async {
    final now = DateTime.now();
    final memory = _persistentJsonCache[key];
    if (memory != null && memory.expiresAt.isAfter(now)) return memory.value;

    final preferences = await _preferences();
    final savedAt = preferences.getInt('$key.savedAt');
    final payload = preferences.getString(key);
    if (savedAt == null || payload == null) return null;
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(
      savedAt,
    ).add(_persistentCacheTtl);
    if (!expiresAt.isAfter(now)) {
      _persistentJsonCache.remove(key);
      return null;
    }
    try {
      final value = jsonDecode(payload);
      _persistentJsonCache[key] = _TimedCacheEntry(value, expiresAt);
      return value;
    } catch (_) {
      return null;
    }
  }

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

  /// Clears only public WordPress API caches; user purchases and preferences
  /// stay untouched.
  Future<void> clearPublicCache() async {
    _postsCache.clear();
    _releasesCache.clear();
    _eventsCache.clear();
    _faqCache.clear();
    _artistsCache.clear();
    _artistCache.clear();
    _organizersCache.clear();
    _organizerCache.clear();
    _releaseDetailCache.clear();
    _releaseDetailInFlight.clear();
    _persistentJsonCache.clear();

    final preferences = await _preferences();
    final keys = preferences
        .getKeys()
        .where((key) => key.startsWith('huhs.wp.'))
        .toList(growable: false);
    for (final key in keys) {
      await preferences.remove(key);
    }
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
    bool forceRefresh = false,
  }) async {
    final key = '$page|$perPage|${search.trim()}|$categoryId';
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
    bool allowPersistentCache = true,
  }) async {
    try {
      final persistentKey =
          'huhs.wp.posts.$page.$perPage.${search.trim()}.$categoryId';
      Object? data = allowPersistentCache
          ? await _readPersistentJson(persistentKey)
          : null;
      if (data == null) {
        final response = await _dio.get(
          '/posts',
          queryParameters: {
            'page': page,
            'per_page': perPage,
            'summary': true,
            if (search.trim().isNotEmpty) 'search': search.trim(),
            if (categoryId > 0) 'category': categoryId,
          },
        );
        data = response.data;
        unawaited(_writePersistentJson(persistentKey, data!));
      }

      if (data is List<dynamic>) {
        final rawPosts = data.whereType<Map<String, dynamic>>().toList();
        final allPosts = (await _hydratePostTags(
          rawPosts,
        )).map(Post.fromJson).toList();
        final query = search.trim().toLowerCase();
        final posts = query.isEmpty
            ? allPosts
            : allPosts
                  .where(
                    (post) =>
                        post.title.toLowerCase().contains(query) ||
                        post.excerpt.toLowerCase().contains(query) ||
                        post.content.toLowerCase().contains(query),
                  )
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
      final currentPage = _readInt(json['page'], fallback: page);
      final totalPages = _readInt(json['total_pages'], fallback: 1);
      final hasMore = _readBool(json['has_more']) || currentPage < totalPages;

      return PostsPage(
        items: hydratedItems.map(Post.fromJson).toList(),
        page: currentPage,
        perPage: _readInt(json['per_page'], fallback: perPage),
        total: _readInt(json['total']),
        totalPages: totalPages,
        hasMore: hasMore,
      );
    } on DioException catch (e) {
      throw Exception(_readApiError(e, 'Nem sikerült betölteni a híreket.'));
    } catch (_) {
      throw Exception('Nem sikerült betölteni a híreket.');
    }
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
    final page = await getPosts();
    return page.items;
  }

  Future<List<FaqItem>> getFaq() async {
    return _cached<List<FaqItem>>(
      key: 'faq',
      ttl: const Duration(minutes: 10),
      cache: _faqCache,
      inFlight: _faqInFlight,
      loader: _fetchFaq,
    );
  }

  Future<List<FaqItem>> _fetchFaq() async {
    try {
      final persistent = await _readPersistentJson('huhs.wp.faq');
      if (persistent is List) {
        return persistent
            .whereType<Map<String, dynamic>>()
            .map(FaqItem.fromJson)
            .where((item) => item.question.trim().isNotEmpty)
            .toList(growable: false);
      }
      final response = await _dio.get('/faq');
      final data = response.data;
      final raw = data is List<dynamic>
          ? data
          : (data is Map<String, dynamic> ? data['items'] : null);
      if (raw is! List<dynamic>) return const [];
      final result = raw
          .whereType<Map<String, dynamic>>()
          .map(FaqItem.fromJson)
          .where((item) => item.question.trim().isNotEmpty)
          .toList(growable: false);
      unawaited(_writePersistentJson('huhs.wp.faq', raw));
      return result;
    } on DioException catch (e) {
      throw Exception(_readApiError(e, 'Nem sikerült betölteni a GYIK-et.'));
    }
  }

  Future<Post> getPost(int postId) async {
    final key = 'huhs.wp.post.$postId';
    final cached = await _readPersistentJson(key);
    final data = cached ?? (await _dio.get('/posts/$postId')).data;
    if (cached == null) unawaited(_writePersistentJson(key, data));
    if (data is Map<String, dynamic>) {
      final hydrated = await _hydratePostTags([data]);
      return Post.fromJson(hydrated.first);
    }
    throw const FormatException('Hibás hír válasz.');
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
      return posts
          .map((post) {
            final names = byId[_readInt(post['id'])];
            return names == null ? post : {...post, 'tag_names': names};
          })
          .toList(growable: false);
    } catch (_) {
      // The custom endpoint remains usable if the optional core REST lookup
      // is blocked or unavailable.
      return posts;
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

  Future<List<HuhsEvent>> getEvents({bool includePast = false}) async {
    final key = includePast ? 'past' : 'upcoming';
    return _cached<List<HuhsEvent>>(
      key: key,
      ttl: const Duration(seconds: 45),
      cache: _eventsCache,
      inFlight: _eventsInFlight,
      loader: () => _fetchEvents(includePast: includePast),
    );
  }

  Future<List<HuhsEvent>> _fetchEvents({required bool includePast}) async {
    try {
      final persistentKey = includePast
          ? 'huhs.wp.events.past'
          : 'huhs.wp.events.upcoming';
      final persistent = await _readPersistentJson(persistentKey);
      if (persistent is List) {
        final events = persistent
            .whereType<Map<String, dynamic>>()
            .map(HuhsEvent.fromJson)
            .toList(growable: false);
        return includePast
            ? events
            : events.where((event) => !event.isPast).toList(growable: false);
      }
      final response = await _dio.get<String>(
        '/events',
        queryParameters: {
          if (includePast) 'include_past': true,
          'summary': true,
        },
        options: Options(responseType: ResponseType.plain),
      );
      final data = _decodePossiblyPrefixedJson(response.data ?? '');

      if (data is List<dynamic>) {
        final events = data
            .map((json) => HuhsEvent.fromJson(json as Map<String, dynamic>))
            .toList();
        unawaited(_writePersistentJson(persistentKey, data));
        return includePast
            ? events
            : events.where((event) => !event.isPast).toList();
      }

      if (data is Map<String, dynamic>) {
        final items = data['items'] as List<dynamic>? ?? [];

        final events = items
            .map((json) => HuhsEvent.fromJson(json as Map<String, dynamic>))
            .toList();
        unawaited(_writePersistentJson(persistentKey, items));
        return includePast
            ? events
            : events.where((event) => !event.isPast).toList();
      }

      return const [];
    } on DioException catch (e) {
      throw Exception(
        _readApiError(e, 'Nem sikerült betölteni az eseményeket.'),
      );
    } catch (_) {
      throw Exception('Nem sikerült betölteni az eseményeket.');
    }
  }

  Future<HuhsEvent> getEvent(int eventId) async {
    final response = await _dio.get('/events/$eventId');
    final data = response.data;
    if (data is Map<String, dynamic>) return HuhsEvent.fromJson(data);
    throw const FormatException('Hibás esemény-adatlap válasz.');
  }

  Future<ArtistsPage> getArtists({
    String search = '',
    String category = '',
    int page = 1,
    int perPage = 50,
  }) async {
    final key =
        '$page|$perPage|${search.trim().toLowerCase()}|${category.trim().toLowerCase()}';
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
      ),
    );
  }

  Future<ArtistsPage> _fetchArtists({
    String search = '',
    String category = '',
    int page = 1,
    int perPage = 50,
  }) async {
    try {
      final canUsePersistentCache =
          page == 1 && perPage == 50 && search == '' && category == '';
      if (canUsePersistentCache) {
        final persistent = await _readPersistentJson('huhs.wp.artists');
        if (persistent is Map<String, dynamic>) {
          return ArtistsPage.fromJson(persistent);
        }
      }
      final response = await _dio.get(
        '/artists',
        queryParameters: {
          'page': page,
          'per_page': perPage,
          'summary': true,
          if (search.trim().isNotEmpty) 'search': search.trim(),
          if (category.trim().isNotEmpty) 'category': category.trim(),
        },
      );
      final data = response.data;

      if (data is Map<String, dynamic>) {
        if (canUsePersistentCache) {
          unawaited(_writePersistentJson('huhs.wp.artists', data));
        }
        return ArtistsPage.fromJson(data);
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

  Future<Artist> getArtist(int artistId) async {
    return _cachedById<Artist>(
      key: artistId,
      ttl: const Duration(minutes: 10),
      cache: _artistCache,
      inFlight: _artistInFlight,
      loader: () => _fetchArtist(artistId),
    );
  }

  Future<Artist> _fetchArtist(int artistId) async {
    try {
      final key = 'huhs.wp.artist.$artistId';
      final cached = await _readPersistentJson(key);
      final data = cached ?? (await _dio.get('/artists/$artistId')).data;

      if (data is Map<String, dynamic>) {
        if (cached == null) unawaited(_writePersistentJson(key, data));
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
  }) async {
    final key = '$page|$perPage|${search.trim().toLowerCase()}';
    return _cached<OrganizersPage>(
      key: key,
      ttl: const Duration(minutes: 10),
      cache: _organizersCache,
      inFlight: _organizersInFlight,
      loader: () =>
          _fetchOrganizers(search: search, page: page, perPage: perPage),
    );
  }

  Future<OrganizersPage> _fetchOrganizers({
    String search = '',
    int page = 1,
    int perPage = 50,
  }) async {
    try {
      final canUsePersistentCache = page == 1 && perPage == 50 && search == '';
      if (canUsePersistentCache) {
        final persistent = await _readPersistentJson('huhs.wp.organizers');
        if (persistent is Map<String, dynamic>) {
          return OrganizersPage.fromJson(persistent);
        }
      }
      final response = await _dio.get(
        '/organizers',
        queryParameters: {
          'page': page,
          'per_page': perPage,
          'summary': true,
          if (search.trim().isNotEmpty) 'search': search.trim(),
        },
      );
      final data = response.data;

      if (data is Map<String, dynamic>) {
        if (canUsePersistentCache) {
          unawaited(_writePersistentJson('huhs.wp.organizers', data));
        }
        return OrganizersPage.fromJson(data);
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

  Future<OrganizerProfile> getOrganizer(int organizerId) async {
    return _cachedById<OrganizerProfile>(
      key: organizerId,
      ttl: const Duration(minutes: 10),
      cache: _organizerCache,
      inFlight: _organizerInFlight,
      loader: () => _fetchOrganizer(organizerId),
    );
  }

  Future<OrganizerProfile> _fetchOrganizer(int organizerId) async {
    try {
      final key = 'huhs.wp.organizer.$organizerId';
      final cached = await _readPersistentJson(key);
      final data = cached ?? (await _dio.get('/organizers/$organizerId')).data;

      if (data is Map<String, dynamic>) {
        if (cached == null) unawaited(_writePersistentJson(key, data));
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
        // The live HUHS API exposes the complete release records through the
        // collection endpoint. There is no reliable /releases/{id} route;
        // calling it makes the detail screen fall back to the summary item,
        // which intentionally has no versions or free download metadata.
        final response = await _dio.get('/releases');
        final data = response.data;
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
      final persistentKey = 'huhs.wp.releases.${search.trim()}.$artistId';
      if (allowPersistentCache) {
        final cached = await _readPersistentJson(persistentKey);
        if (cached is List) {
          return cached
              .whereType<Map<String, dynamic>>()
              .map(HuhsRelease.fromJson)
              .toList(growable: false);
        }
      }
      final response = await _dio.get(
        '/releases',
        queryParameters: {
          'summary': true,
          if (search.trim().isNotEmpty) 'search': search.trim(),
          if (artistId > 0) 'artist': artistId,
        },
      );
      final data = response.data;
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
      unawaited(_writePersistentJson(persistentKey, values));
      return releases;
    } on DioException catch (e) {
      throw Exception(
        _readApiError(e, 'Nem sikerült betölteni a release-eket.'),
      );
    }
  }

  Future<VotingSeason> getActiveVoting() async {
    try {
      final response = await _dio.get(
        '/voting/active',
        options: Options(
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      if (response.data is Map<String, dynamic>) {
        return VotingSeason.fromJson(response.data as Map<String, dynamic>);
      }
      return const VotingSeason.inactive();
    } on DioException {
      // The Home button is optional; a temporarily unavailable voting endpoint
      // must not block the rest of the Home screen.
      return const VotingSeason.inactive();
    }
  }

  Future<ProfileSubmissionOptions> getProfileSubmissionOptions() async {
    try {
      final response = await _dio.get('/profile-submission-options');
      final data = response.data;

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
      final responseData =
          (await FirebaseFunctions.instance
                  .httpsCallable('submitWordPressContent')
                  .call<Map<String, dynamic>>({'kind': kind, 'payload': data}))
              .data;
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
      final response = await _dio.get('/event-submission-options');
      final data = response.data as Map<String, dynamic>;
      final genres = data['genres'] as List<dynamic>? ?? const [];

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
      final responseData =
          (await FirebaseFunctions.instance
                  .httpsCallable('submitWordPressContent')
                  .call<Map<String, dynamic>>({
                    'kind': 'event',
                    'payload': payload,
                  }))
              .data;
      final message = _readResponseMessage(responseData);
      if (message != null) return message;

      return 'Köszönjük, az eseményt elküldtük ellenőrzésre.';
    } on DioException catch (e) {
      throw Exception(_readApiError(e, 'Az eseményt nem sikerült elküldeni.'));
    } catch (_) {
      throw Exception('Az eseményt nem sikerült elküldeni.');
    }
  }

  Future<String> _uploadCloudinaryImage(SubmissionImage image) async {
    try {
      final extension = image.name.split('.').last.toLowerCase();
      if (image.bytes.isEmpty ||
          image.bytes.length > _maxUploadBytes ||
          !_allowedImageExtensions.contains(extension)) {
        throw const FormatException(
          'JPG, PNG vagy WebP kép szükséges, legfeljebb 5 MB méretben.',
        );
      }
      final upload = Dio();
      final response = await upload.post(
        'https://api.cloudinary.com/v1_1/$_cloudinaryCloudName/image/upload',
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

  Future<List<NewsCategory>> getCategories() async {
    try {
      const key = 'huhs.wp.categories';
      final cached = await _readPersistentJson(key);
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
