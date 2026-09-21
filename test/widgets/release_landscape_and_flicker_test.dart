import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A 2026-09-21-i tulajdonosi hibajegy **négy** pontjának őre.
///
///  1. *„a jutalmazott külső linkes ingyenes kiadvány feloldása nem működik"* —
///     a gyökér a **szerveren** volt (`free_link` nincs a lejátszható
///     változatok listájában), ezért azt a `functions/label-library-plan.test.cjs`
///     méri; itt csak a szerződést rögzítjük (a kliens `free_link`-et kér).
///  2. *„tableten fekvő nézetben ha megnyitok egy kiadványt, rohadt nagy a cover
///     és frán nagy minden"* — fekvő nézet: a tartalom legfeljebb 1100 px, a
///     négyzetes borító legfeljebb 360 px.
///  3. *„djk, szervezők listája még mindig villog néha"* — a globális
///     frissítés-jelzőt **nem** `watch`-oljuk (az reload → spinner villan),
///     hanem `listen`-eljük + `invalidateSelf()`, és a listák
///     `skipLoadingOnReload: true`-t kapnak.
///  4. *„a megvásárolt zenék között ne látszódjon a már eltávolított kiadvány"* —
///     a lista a tiszta `visibleLibraryItems` szűrőn megy át.
void main() {
  String read(String path) =>
      File(path).readAsStringSync().replaceAll('\r\n', '\n');

  group('2 — a kiadvány-adatlap fekvő nézetben', () {
    late String screen;

    setUpAll(() {
      screen = read('lib/screens/releases/release_detail_screen.dart');
    });

    test('a tartalom legfeljebb 1100 px széles sávban jelenik meg', () {
      expect(screen, contains('Orientation.landscape'));
      expect(
        screen,
        contains('maxWidth: landscape ? 1100 : double.infinity'),
        reason: 'a többi adatlap (DJ, hír, esemény) ugyanezt használja',
      );
      expect(screen, contains('LayoutBuilder('));
      expect(screen, contains('alignment: Alignment.topCenter'));
    });

    test('a NÉGYZETES borító fekvő nézetben nem nő a képernyőnél nagyobbra', () {
      // Fekvő tabletben egy teljes szélességű négyzet 1100 px magas lenne —
      // magasabb, mint a képernyő. Ezért ott fix, kényelmes méret.
      expect(
        screen,
        contains('maxWidth: landscape ? 360 : double.infinity'),
        reason: 'a borító fekvő nézetben 360 px',
      );
      expect(screen, contains('aspectRatio: 1'));
      expect(screen, contains('alignment: Alignment.centerLeft'));
    });
  });

  group('3 — a DJ- és szervezőlista nem villog', () {
    test('a providerek nem `watch`-olják a globális frissítés-jelzőt', () {
      for (final path in [
        'lib/providers/artists_provider.dart',
        'lib/providers/organizers_provider.dart',
      ]) {
        final source = read(path);
        expect(
          source,
          contains('ref.listen(publicContentRefreshProvider'),
          reason: '$path: a listen + invalidateSelf frissítés (nem reload)',
        );
        expect(
          source,
          isNot(contains('ref.watch(publicContentRefreshProvider)')),
          reason:
              '$path: a watch reload-ot okoz, ilyenkor a `when()` loading ága '
              'fut le, és a kész lista helyett spinner villan',
        );
      }
    });

    test('a listák és adatlapok megtartják a korábbi tartalmat reloadkor', () {
      for (final path in [
        'lib/screens/artists/artists_screen.dart',
        'lib/screens/artists/artist_detail_screen.dart',
        'lib/screens/organizers/organizers_screen.dart',
        'lib/screens/organizers/organizer_detail_screen.dart',
      ]) {
        expect(
          read(path),
          contains('skipLoadingOnReload: true'),
          reason: '$path: háttér-frissítésnél nem ürülhet ki a lista',
        );
      }
    });
  });

  group('4 — a listából eltűnt kiadvány nem kap kártyát', () {
    late String music;

    setUpAll(() {
      music = read('lib/screens/more/my_music_screen.dart');
    });

    test('a lista a tiszta szűrőn megy át, és a régi kártya eltűnt', () {
      expect(music, contains('visibleLibraryItems('));
      expect(music, contains('unavailable: _unavailableReleases'));
      expect(music, contains('for (final item in visible) _buildReleaseCard'));
      expect(
        music,
        isNot(contains('_buildUnavailableCard')),
        reason: 'a hely kitöltése helyett a kiadvány ki sem kerül a listára',
      );
      expect(
        read('lib/services/label_library_plan.dart'),
        contains('List<LabelLibraryItem> visibleLibraryItems('),
      );
    });
  });

  group('1 — a külső linkes feloldás szerződése', () {
    test('a kliens `free_link` változattal kéri a feloldást', () {
      final screen = read('lib/screens/releases/release_detail_screen.dart');
      expect(screen, contains("_claimReward('free_link')"));
      expect(screen, contains("variant: 'free_link'"));
    });
  });
}
