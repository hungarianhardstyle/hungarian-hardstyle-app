import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Forrás-lint: a DJ-adatlap „Megjelenései" szakasza.
///
/// A tiszta szabály tesztje (`artist_releases_plan_test.dart`) és a widget-teszt
/// (`artist_releases_section_test.dart`) a **logikát** fedi; ez a fájl azt
/// őrzi, hogy a **bekötés** ne csússzon el — ez a 351-es tanulság: a szabály
/// lehet helyes, a bekötés hibás.
void main() {
  String readFile(String path) =>
      File(path).readAsStringSync().replaceAll('\r\n', '\n');

  group('forrás-lint: a DJ-adatlap „Megjelenései" szakasza', () {
    late String detail;
    late String section;

    setUpAll(() {
      detail = readFile('lib/screens/artists/artist_detail_screen.dart');
      section = readFile('lib/widgets/artist_releases_section.dart');
    });

    test('a szakasz a DJ-adatlapra be van kötve, a DJ azonosítójával', () {
      expect(detail, contains('ArtistReleasesSection('));
      expect(
        detail,
        contains('artistId: artist.id'),
        reason: 'a szűrés a DJ azonosítójával történik',
      );
      expect(detail, contains('artistName: artist.title'));
    });

    test('a szakasz külön, tesztelhető widget — nem a képernyőn belül él', () {
      expect(detail, isNot(contains('class _ArtistReleasesSection')));
      expect(section, contains('class ArtistReleasesSection extends ConsumerWidget'));
    });

    test('a szerver szűr a DJ-re (nem a teljes katalógust töltjük le)', () {
      expect(
        section,
        contains("releasesProvider((search: '', artistId: artistId))"),
      );
      expect(
        readFile('lib/services/wordpress_service.dart'),
        contains("'artist': artistId"),
        reason: 'a WordPress végpont `artist` paramétere szűri a listát',
      );
    });

    test('nincs villogás: amíg nincs érték, nem rajzol semmit', () {
      expect(section, contains('valueOrNull'));
      expect(
        section,
        isNot(contains('CircularProgressIndicator')),
        reason: 'a szakasz nem pörgővel jelzi a töltést, hanem kimarad',
      );
      expect(
        section,
        isNot(contains('.when(')),
        reason: 'a `.when` loading-ág pörgőt/hibát rajzolna a DJ-adatlapra',
      );
      expect(section, contains('SizedBox.shrink()'));
    });

    test('a kiadvány-kártya KÖZÖS a kiadvány-listával (nem másolódik)', () {
      expect(section, contains('ReleaseCard(release: release)'));
      expect(readFile('lib/widgets/release_card.dart'), contains('class ReleaseCard'));
      final list = readFile('lib/screens/releases/releases_screen.dart');
      expect(list, contains('ReleaseCard(release: items[index])'));
      expect(
        list,
        isNot(contains('class _ReleaseCard')),
        reason: 'a lista ne tartson külön, saját kártya-másolatot',
      );
    });

    test('a „több" gomb a szűrt kiadvány-listára visz', () {
      expect(section, contains('Összes megjelenése ('));
      expect(
        section,
        contains('ReleasesScreen('),
        reason: 'a gomb az artistId-vel szűrt kiadvány-listát nyitja',
      );
    });
  });
}
