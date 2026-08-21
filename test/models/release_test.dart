import 'package:flutter_test/flutter_test.dart';

import 'package:hungarian_hardstyle_app/models/release.dart';

void main() {
  test('beolvassa az ingyenes kiadvány jelölését', () {
    final release = HuhsRelease.fromJson({
      'id': 123,
      'title': 'Free release',
      'is_free': true,
      'artists': <Map<String, dynamic>>[],
      'tracks': <Map<String, dynamic>>[],
      'products': <Map<String, dynamic>>[],
      'versions': <Map<String, dynamic>>[],
    });

    expect(release.isFree, isTrue);
  });

  test('a hiányzó ingyenes jelölés nem teszi ingyenessé a kiadványt', () {
    final release = HuhsRelease.fromJson({
      'id': 123,
      'title': 'Paid release',
      'artists': <Map<String, dynamic>>[],
      'tracks': <Map<String, dynamic>>[],
      'products': <Map<String, dynamic>>[],
      'versions': <Map<String, dynamic>>[],
    });

    expect(release.isFree, isFalse);
  });
}
