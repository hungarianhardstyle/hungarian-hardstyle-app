import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:hungarian_hardstyle_app/models/event.dart';
import 'package:hungarian_hardstyle_app/models/post.dart';
import 'package:hungarian_hardstyle_app/services/public_content_warmer.dart';

void main() {
  test('induláskor a hírek és az események is előtöltődnek', () async {
    var news = 0;
    var events = 0;

    final pendingNews = Completer<List<Post>>();
    final future = PublicContentWarmer.warm(
      loadNews: () {
        news++;
        return pendingNews.future;
      },
      loadEvents: () async {
        events++;
        return const <HuhsEvent>[];
      },
    );

    // Mindkét kérés párhuzamosan elindul, nem egymás után.
    await Future<void>.delayed(Duration.zero);
    expect(news, 1);
    expect(events, 1);

    pendingNews.complete(const <Post>[]);
    await future;
  });

  test('egy hibázó előtöltés nem viszi el a másikat és nem dob', () async {
    var events = 0;

    await expectLater(
      PublicContentWarmer.warm(
        loadNews: () => Future<List<Post>>.error(Exception('nincs hálózat')),
        loadEvents: () async {
          events++;
          return const <HuhsEvent>[];
        },
      ),
      completes,
    );
    expect(events, 1);
  });

  test('az indulás akkor sem törik meg, ha mindkettő hibázik', () async {
    await expectLater(
      PublicContentWarmer.warm(
        loadNews: () => Future<List<Post>>.error(Exception('hiba')),
        loadEvents: () => Future<List<HuhsEvent>>.error(Exception('hiba')),
      ),
      completes,
    );
  });
}
