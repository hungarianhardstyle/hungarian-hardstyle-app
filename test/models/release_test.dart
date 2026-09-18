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

  test('a megjelenés előtti kiadvány a szerver jelzését használja', () {
    // The server decides `is_upcoming`, because the release date is a site-local
    // calendar date while the download gate lives on the server. The app must
    // not re-derive it in the device timezone.
    final upcoming = HuhsRelease.fromJson({
      'id': 1,
      'title': 'Coming soon',
      'release_date': '2099-01-01',
      'is_upcoming': true,
      'presave_url': 'https://example.com/presave',
    });
    expect(upcoming.isUpcoming, isTrue);
    expect(upcoming.presaveUrl, 'https://example.com/presave');

    // After the release date the API stops sending the presave link and clears
    // the flag, so the button disappears without any client-side date logic.
    final live = HuhsRelease.fromJson({
      'id': 1,
      'title': 'Out now',
      'release_date': '2020-01-01',
      'is_upcoming': false,
      'presave_url': '',
    });
    expect(live.isUpcoming, isFalse);
    expect(live.presaveUrl, isEmpty);
  });

  test('hiányzó is_upcoming mezőnél a kiadvány a régi módon viselkedik', () {
    // An older plugin version does not send the flag. The release must then stay
    // buyable in the UI exactly as before; the server-side gate still protects
    // the files, so nothing is exposed by defaulting to false here.
    final release = HuhsRelease.fromJson({
      'id': 5,
      'title': 'Legacy payload',
      'release_date': '2099-01-01',
    });
    expect(release.isUpcoming, isFalse);
    expect(release.presaveUrl, isEmpty);
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
