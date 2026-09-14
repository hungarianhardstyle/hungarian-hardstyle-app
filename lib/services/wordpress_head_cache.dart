import 'dart:async';
import 'dart:convert';

typedef WordpressCacheRead = Future<String?> Function(String key);
typedef WordpressCacheWrite = Future<void> Function(String key, String value);
typedef WordpressCacheRemove = Future<void> Function(String key);
typedef WordpressCacheRequest = Future<WordpressCacheResponse> Function(
  String method,
  Uri uri,
);

class WordpressCacheResponse {
  const WordpressCacheResponse({
    required this.statusCode,
    this.etag,
    this.data,
  });

  final int statusCode;
  final String? etag;
  final Object? data;
}

class WordpressHeadCache {
  WordpressHeadCache({
    required this.read,
    required this.write,
    required this.remove,
    required this.request,
    this.onUpdated,
    this.validationWindow = const Duration(seconds: 30),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final WordpressCacheRead read;
  final WordpressCacheWrite write;
  final WordpressCacheRemove remove;
  final WordpressCacheRequest request;
  final void Function()? onUpdated;
  final DateTime Function() _now;
  final Duration validationWindow;
  final Map<String, _CacheRecord> _memory = {};
  final Map<String, Future<Object?>> _inFlight = {};
  final Map<String, Future<void>> _refreshInFlight = {};
  int _generation = 0;

  Future<Object?> get(
    Uri uri, {
    String cacheContext = '',
    bool forceRefresh = false,
  }) {
    final key = _key(uri, cacheContext);
    final existing = _inFlight[key];
    if (existing != null) return existing;
    late final Future<Object?> request;
    request = _get(key, uri, forceRefresh: forceRefresh).whenComplete(() {
      if (identical(_inFlight[key], request)) _inFlight.remove(key);
    });
    _inFlight[key] = request;
    return request;
  }

  Future<Object?> _get(
    String key,
    Uri uri, {
    required bool forceRefresh,
  }) async {
    final generation = _generation;
    final cached = await _load(key);
    final now = _now();
    if (!forceRefresh &&
        cached != null &&
        now.difference(cached.checkedAt) < validationWindow) {
      return cached.data;
    }

    if (!forceRefresh && cached != null) {
      _refreshInBackground(key, uri, cached);
      return cached.data;
    }

    if (cached != null) {
      try {
        final head = await request('HEAD', _bypass(uri, now));
        final headEtag = head.etag;
        if (_unchanged(head.statusCode, headEtag, cached.etag)) {
          final refreshed = cached.copyWith(checkedAt: now);
          if (generation == _generation) await _save(key, refreshed);
          return cached.data;
        }
      } catch (_) {
        return cached.data;
      }
    }

    late final WordpressCacheResponse response;
    try {
      response = await request('GET', cached == null ? uri : _bypass(uri, now));
    } catch (_) {
      if (cached != null) return cached.data;
      rethrow;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (cached != null) return cached.data;
      throw StateError('WordPress GET failed: ${response.statusCode}');
    }
    final etag = response.etag;
    if (etag != null && etag.trim().isNotEmpty) {
      if (generation == _generation) {
        await _save(
          key,
          _CacheRecord(data: response.data, etag: etag, checkedAt: now),
        );
        if (cached == null || !_sameEtag(etag, cached.etag)) onUpdated?.call();
      }
    }
    return response.data;
  }

  void _refreshInBackground(String key, Uri uri, _CacheRecord cached) {
    if (_refreshInFlight.containsKey(key)) return;
    late final Future<void> refresh;
    refresh = _refresh(key, uri, cached, _generation).whenComplete(() {
      if (identical(_refreshInFlight[key], refresh)) {
        _refreshInFlight.remove(key);
      }
    });
    _refreshInFlight[key] = refresh;
    unawaited(refresh);
  }

  Future<void> _refresh(
    String key,
    Uri uri,
    _CacheRecord cached,
    int generation,
  ) async {
    final now = _now();
    try {
      final head = await request('HEAD', _bypass(uri, now));
      if (_unchanged(head.statusCode, head.etag, cached.etag)) {
        if (generation == _generation) {
          await _save(key, cached.copyWith(checkedAt: now));
        }
        return;
      }
      final response = await request('GET', _bypass(uri, now));
      final etag = response.etag;
      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          etag != null &&
          etag.trim().isNotEmpty) {
        if (generation == _generation) {
          await _save(
            key,
            _CacheRecord(data: response.data, etag: etag, checkedAt: now),
          );
          if (!_sameEtag(etag, cached.etag)) onUpdated?.call();
        }
      }
    } catch (_) {
      // A usable stale body survives transient validation failures.
    }
  }

  Future<void> clear() async {
    _generation++;
    final keys = _memory.keys.toList(growable: false);
    _memory.clear();
    _refreshInFlight.clear();
    await Future.wait(keys.map(remove));
  }

  Future<_CacheRecord?> _load(String key) async {
    final memory = _memory[key];
    if (memory != null) return memory;
    final encoded = await read(key);
    if (encoded == null) return null;
    try {
      final record = _CacheRecord.fromJson(
        jsonDecode(encoded) as Map<String, dynamic>,
      );
      _memory[key] = record;
      return record;
    } catch (_) {
      await remove(key);
      return null;
    }
  }

  Future<void> _save(String key, _CacheRecord record) async {
    final encoded = jsonEncode(record.toJson());
    await write(key, encoded);
    _memory[key] = record;
  }

  static String _key(Uri uri, String cacheContext) {
    final entries = uri.queryParametersAll.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final query = <String, List<String>>{
      for (final entry in entries) entry.key: [...entry.value]..sort(),
    };
    return 'huhs.wp.head.v1.$cacheContext.${uri.replace(queryParameters: query)}';
  }

  static Uri _bypass(Uri uri, DateTime now) {
    final query = Map<String, dynamic>.from(uri.queryParametersAll);
    query['_huhs_revalidate'] = now.microsecondsSinceEpoch.toString();
    return uri.replace(queryParameters: query);
  }

  static bool _sameEtag(String left, String right) =>
      _normalizeEtag(left) == _normalizeEtag(right);

  static bool _unchanged(int statusCode, String? etag, String cachedEtag) =>
      statusCode == 304 ||
      (statusCode >= 200 &&
          statusCode < 300 &&
          etag != null &&
          _sameEtag(etag, cachedEtag));

  static String _normalizeEtag(String value) =>
      value.trim().replaceFirst(RegExp(r'^W/', caseSensitive: false), '');
}

class _CacheRecord {
  const _CacheRecord({
    required this.data,
    required this.etag,
    required this.checkedAt,
  });

  factory _CacheRecord.fromJson(Map<String, dynamic> json) {
    final etag = json['etag'];
    final checkedAt = json['checkedAt'];
    if (etag is! String || checkedAt is! int || !json.containsKey('data')) {
      throw const FormatException('Invalid WordPress cache record.');
    }
    return _CacheRecord(
      data: json['data'],
      etag: etag,
      checkedAt: DateTime.fromMillisecondsSinceEpoch(checkedAt),
    );
  }

  final Object? data;
  final String etag;
  final DateTime checkedAt;

  _CacheRecord copyWith({DateTime? checkedAt}) => _CacheRecord(
    data: data,
    etag: etag,
    checkedAt: checkedAt ?? this.checkedAt,
  );

  Map<String, Object?> toJson() => {
    'data': data,
    'etag': etag,
    'checkedAt': checkedAt.millisecondsSinceEpoch,
  };
}
