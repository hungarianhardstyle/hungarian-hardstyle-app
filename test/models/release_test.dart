import 'package:flutter_test/flutter_test.dart';

import 'package:hungarian_hardstyle_app/models/release.dart';

void main() {
  test(
    'a kiadványokat megjelenési dátum szerint csökkenő sorrendbe rendezi',
    () {
      HuhsRelease release(String date, int id) => HuhsRelease.fromJson({
        'id': id,
        'title': 'Release $id',
        'release_date': date,
      });

      final sorted = sortReleasesByReleaseDate([
        release('2025-03-14', 1),
        release('2025-11-24', 2),
        release('', 3),
        release('2025-11-24', 4),
      ]);

      expect(sorted.map((item) => item.id), [2, 4, 1, 3]);
    },
  );

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
    expect(release.hasFreeWav, isFalse);
  });

  test(
    'külső linkes ingyenes kiadványnál WAV nélkül nincs WAV-jogosultság',
    () {
      final release = HuhsRelease.fromJson({
        'id': 12405,
        'title': 'External link only',
        'is_free': true,
        'free_external_link': 'https://example.com',
        'artists': <Map<String, dynamic>>[],
        'tracks': <Map<String, dynamic>>[],
        'products': <Map<String, dynamic>>[],
        'versions': <Map<String, dynamic>>[],
      });

      expect(release.freeExternalLink, isNotEmpty);
      expect(release.hasFreeWav, isFalse);
    },
  );

  test('ingyenes kiadványnál a jelentett radio verzió WAV-ot jelent', () {
    final release = HuhsRelease.fromJson({
      'id': 12242,
      'title': 'Free WAV',
      'is_free': true,
      'versions': [
        {'type': 'radio', 'available': true},
      ],
    });

    expect(release.hasFreeWav, isTrue);
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
