import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/services/wordpress_head_cache.dart';

void main() {
  final uri = Uri.parse('https://example.test/wp-json/huhs/v1/posts?page=1');

  test('first request performs GET and saves body with ETag', () async {
    final harness = _Harness();

    expect(await harness.cache.get(uri), {'items': <Object>[]});
    expect(harness.methods, ['GET']);
    expect(harness.storage, isNotEmpty);
  });

  test('matching weak ETag uses cached body without GET', () async {
    final harness = _Harness();
    await harness.cache.get(uri);
    harness.advance();
    harness.etag = 'W/"v1"';

    expect(await harness.cache.get(uri), {'items': <Object>[]});
    expect(harness.methods, ['GET', 'HEAD']);
  });

  test('304 validation keeps the cached body', () async {
    final harness = _Harness();
    await harness.cache.get(uri);
    harness.advance();
    harness.headStatus = 304;

    expect(await harness.cache.get(uri, forceRefresh: true), {
      'items': <Object>[],
    });
    expect(harness.methods, ['GET', 'HEAD']);
  });

  test('clearing cache invalidates an in-flight background refresh', () async {
    final harness = _Harness();
    await harness.cache.get(uri);
    harness.advance();
    harness.etag = '"v2"';
    final gate = Completer<void>();
    harness.beforeResponse = () => gate.future;

    expect(await harness.cache.get(uri), {'items': <Object>[]});
    await harness.cache.clear();
    gate.complete();
    await _flushBackgroundWork();

    expect(harness.storage, isEmpty);
  });

  test('stale body returns immediately then refreshes in background', () async {
    final harness = _Harness();
    await harness.cache.get(uri);
    harness.advance();
    harness.etag = '"v2"';
    harness.data = {
      'items': [2],
    };

    expect(await harness.cache.get(uri), {'items': <Object>[]});
    await _flushBackgroundWork();
    expect(harness.methods, ['GET', 'HEAD', 'GET']);
    expect(await harness.cache.get(uri), {
      'items': [2],
    });
    expect(harness.updates, 2);
  });

  test('HEAD failure keeps an existing usable cache', () async {
    final harness = _Harness();
    await harness.cache.get(uri);
    harness.advance();
    harness.failHead = true;

    expect(await harness.cache.get(uri), {'items': <Object>[]});
    expect(harness.methods, ['GET', 'HEAD']);
  });

  test('failed refresh GET keeps the previous cache', () async {
    final harness = _Harness();
    await harness.cache.get(uri);
    harness.advance();
    harness.etag = '"v2"';
    harness.failGet = true;

    expect(await harness.cache.get(uri), {'items': <Object>[]});
    await _flushBackgroundWork();
    expect(harness.methods, ['GET', 'HEAD', 'GET']);
  });

  test('network failure without cache is surfaced', () async {
    final harness = _Harness()..failGet = true;

    await expectLater(harness.cache.get(uri), throwsStateError);
  });

  test('corrupt persistent cache is removed and replaced by GET', () async {
    final harness = _Harness();
    harness.storage['huhs.wp.head.v1..$uri'] = '{broken';

    expect(await harness.cache.get(uri), {'items': <Object>[]});
    expect(harness.methods, ['GET']);
    expect(harness.storage.values.single, isNot('{broken'));
  });

  test('parallel identical requests share one network request', () async {
    final harness = _Harness();
    final gate = Completer<void>();
    harness.beforeResponse = () => gate.future;

    final first = harness.cache.get(uri);
    final second = harness.cache.get(uri);
    gate.complete();

    expect(await Future.wait([first, second]), hasLength(2));
    expect(harness.methods, ['GET']);
  });

  test('different query parameters use different cache keys', () async {
    final harness = _Harness();
    await harness.cache.get(uri);
    await harness.cache.get(uri.replace(queryParameters: {'page': '2'}));

    expect(harness.methods, ['GET', 'GET']);
    expect(harness.storage, hasLength(2));
  });

  test('different language contexts use different cache keys', () async {
    final harness = _Harness();
    await harness.cache.get(uri, cacheContext: 'hu-HU');
    await harness.cache.get(uri, cacheContext: 'en-US');

    expect(harness.methods, ['GET', 'GET']);
    expect(harness.storage, hasLength(2));
  });

  test('manual refresh bypasses window but still starts with HEAD', () async {
    final harness = _Harness();
    await harness.cache.get(uri);

    expect(await harness.cache.get(uri, forceRefresh: true), {
      'items': <Object>[],
    });
    expect(harness.methods, ['GET', 'HEAD']);
  });
}

Future<void> _flushBackgroundWork() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

class _Harness {
  _Harness() {
    cache = WordpressHeadCache(
      read: (key) async => storage[key],
      write: (key, value) async => storage[key] = value,
      remove: (key) async => storage.remove(key),
      onUpdated: () => updates++,
      request: (method, uri) async {
        methods.add(method);
        await beforeResponse?.call();
        if (method == 'HEAD' && failHead) {
          throw StateError('HEAD failed');
        }
        if (method == 'GET' && failGet) {
          throw StateError('GET failed');
        }
        return WordpressCacheResponse(
          statusCode: method == 'HEAD' ? headStatus : 200,
          etag: etag,
          data: method == 'GET' ? data : null,
        );
      },
      now: () => now,
    );
  }

  late final WordpressHeadCache cache;
  final Map<String, String> storage = {};
  final List<String> methods = [];
  DateTime now = DateTime(2026, 9, 9, 12);
  String etag = '"v1"';
  Object data = {'items': <Object>[]};
  bool failHead = false;
  bool failGet = false;
  int headStatus = 200;
  int updates = 0;
  Future<void> Function()? beforeResponse;

  void advance() => now = now.add(const Duration(minutes: 1));
}
