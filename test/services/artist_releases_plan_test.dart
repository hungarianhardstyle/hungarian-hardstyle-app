import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/models/release.dart';
import 'package:hungarian_hardstyle_app/services/artist_releases_plan.dart';

void main() {
  HuhsRelease release(
    int id,
    String date, {
    List<int> artists = const [1],
    String title = 'Release',
  }) => HuhsRelease(
    id: id,
    title: title,
    coverUrl: '',
    genre: 'Hardstyle',
    artists: artists
        .map((artistId) => ReleaseArtist(id: artistId, name: 'DJ $artistId'))
        .toList(growable: false),
    tracks: const [],
    links: const {},
    products: const [],
    versions: const [],
    audioStatus: '',
    releaseDate: date,
    isFree: false,
    freeExternalLink: '',
  );

  group('artistReleasesFor — csak a saját kiadványok, a legfrissebbel az élen', () {
    test('kiszűri a más DJ kiadványait', () {
      final all = [
        release(1, '2026-01-01', artists: [1]),
        release(2, '2026-02-01', artists: [2]),
        release(3, '2026-03-01', artists: [1, 2]),
      ];

      final mine = artistReleasesFor(1, all);

      expect(mine.map((r) => r.id), [3, 1]);
    });

    test('a közös kiadvány mindkét DJ-nél megjelenik', () {
      final all = [release(7, '2026-05-05', artists: [1, 2])];

      expect(artistReleasesFor(1, all).map((r) => r.id), [7]);
      expect(artistReleasesFor(2, all).map((r) => r.id), [7]);
    });

    test('dátum szerint csökkenő a sorrend', () {
      final all = [
        release(1, '2026-01-01'),
        release(2, '2026-09-01'),
        release(3, '2026-05-01'),
      ];

      expect(artistReleasesFor(1, all).map((r) => r.id), [2, 3, 1]);
    });

    test('érvénytelen dátum a lista végére kerül, nem tűnik el', () {
      final all = [release(1, ''), release(2, '2026-03-03')];

      expect(artistReleasesFor(1, all).map((r) => r.id), [2, 1]);
    });

    test('üres előadó-listájú kiadvány nem kerülhet a lapra', () {
      final all = [release(1, '2026-01-01', artists: const [])];

      expect(artistReleasesFor(1, all), isEmpty);
    });

    test('hibás/ hiányzó DJ-azonosító nem hozza be a teljes katalógust', () {
      final all = [release(1, '2026-01-01'), release(2, '2026-02-01')];

      expect(artistReleasesFor(0, all), isEmpty);
      expect(artistReleasesFor(-5, all), isEmpty);
    });

    test('ha nincs egyetlen találat sem, üres lista jön (nincs kitalált adat)', () {
      final all = [release(1, '2026-01-01', artists: [2])];

      expect(artistReleasesFor(1, all), isEmpty);
    });
  });

  group('artistReleasesPreview — mennyi látszik az adatlapon', () {
    test('alapból négy kiadvány látszik', () {
      expect(artistReleasesPreviewCount, 4);
      final all = List.generate(7, (i) => release(i + 1, '2026-01-0${i + 1}'));

      expect(artistReleasesPreview(1, all).length, 4);
    });

    test('a négy a LEGFRISSEBB négyet jelenti', () {
      final all = [
        release(1, '2026-01-01'),
        release(2, '2026-02-01'),
        release(3, '2026-03-01'),
        release(4, '2026-04-01'),
        release(5, '2026-05-01'),
      ];

      expect(artistReleasesPreview(1, all).map((r) => r.id), [5, 4, 3, 2]);
    });

    test('négy alatt minden látszik', () {
      final all = [release(1, '2026-01-01'), release(2, '2026-02-01')];

      expect(artistReleasesPreview(1, all).length, 2);
    });

    test('limit <= 0 esetén nincs vágás', () {
      final all = List.generate(6, (i) => release(i + 1, '2026-01-0${i + 1}'));

      expect(artistReleasesPreview(1, all, limit: 0).length, 6);
    });
  });

  group('a „több" gomb és a cím', () {
    test('csak négy felett kell a több gomb', () {
      expect(hasMoreArtistReleases(4), isFalse);
      expect(hasMoreArtistReleases(5), isTrue);
    });

    test('limit <= 0 esetén nincs több gomb', () {
      expect(hasMoreArtistReleases(9, limit: 0), isFalse);
    });

    test('egy kiadványnál egyes szám a cím (nem magyartalan)', () {
      expect(artistReleasesLabel(1), 'Megjelenése');
      expect(artistReleasesLabel(2), 'Megjelenései');
      expect(artistReleasesLabel(0), 'Megjelenései');
    });
  });
}
