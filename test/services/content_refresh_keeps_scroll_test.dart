import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/models/release.dart';
import 'package:hungarian_hardstyle_app/providers/news_provider.dart';
import 'package:hungarian_hardstyle_app/screens/releases/releases_screen.dart';
import 'package:hungarian_hardstyle_app/services/wordpress_service.dart';

/// **A háttér-frissítés nem ugrasztja a listát a tetejére.**
///
/// A TULAJDONOS JELZÉSE (2026-09-27): *„a label tab csinált olyat, hogy amíg
/// nem görgettük le az aljára teljesen, folyton visszaugrott a tetejére,
/// valszeg frissítgetett"* — és a kérése: *„nézd meg ez érint-e mást is"*.
///
/// **A MÉRT GYÖKÉR:** a tartalom-providel `ref.watch(publicContentRefreshProvider)`
/// miatt **újratöltődnek**, amikor a WordPress-jelzés megváltozik (a head-cache
/// figyelője ezt bármikor felhúzhatja), a felület pedig `AsyncValue.when(...)`-t
/// használt — ennek az alapértelmezése szerint **újratöltéskor a `loading` ágra
/// vált**, vagyis a lista helyére töltő ikon kerül, és ezzel a **görgetési
/// pozíció elveszik**. A javítás: `skipLoadingOnReload: true` (a meglévő
/// tartalom a helyén marad, amíg az új meg nem érkezik).
///
/// Ez a fájl **kettőt** mér:
///  1. **viselkedés** — a valódi `ReleasesScreen`-en: görgetés után frissítés
///     jelzése → a lista a helyén marad (és a régi kódon **elbukik**);
///  2. **forrás-lint** — minden tartalom-képernyő `.when(...)` hívása átadja a
///     `skipLoadingOnReload: true`-t, névre szóló kivétellistával (és indoklással).
void main() {
  group('a Label fül görgetése frissítéskor', () {
    testWidgets('a háttér-frissítés nem ugrasztja a listát a tetejére', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer(
        overrides: [
          wordpressServiceProvider.overrideWithValue(_FakeWordpressService()),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ReleasesScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Görgessünk le: a mérés a lista pozíciója.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
      await tester.pumpAndSettle();
      final scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      final before = scrollable.position.pixels;
      expect(before, greaterThan(100), reason: 'a görgetés tényleg megtörtént');

      // A WordPress-jelzés: ilyenkor a providerek újratöltődnek.
      container.read(publicContentRefreshProvider).value++;
      await tester.pump();

      // A döntő pillanat: a lista a helyén marad (nem töltő ikon).
      expect(
        find.byType(CustomScrollView),
        findsOneWidget,
        reason: 'a frissítés nem cserélheti töltő ikonra a listát',
      );
      await tester.pumpAndSettle();
      final after = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .pixels;
      expect(
        after,
        closeTo(before, 1),
        reason: 'a görgetési pozíció nem veszhet el a frissítéskor',
      );
    });
  });

  group('FORRÁS-LINT: minden tartalom-képernyő megtartja a tartalmat', () {
    /// Ezek a képernyők **tartalmat** mutatnak, ezért a frissítés nem
    /// cserélheti töltő ikonra a listát (különben a görgetés a tetejére ugrik).
    const contentScreens = <String>[
      'lib/screens/releases/releases_screen.dart',
      'lib/screens/releases/free_releases_screen.dart',
      'lib/screens/events/events_screen.dart',
      'lib/screens/more/faq_screen.dart',
      'lib/screens/more/my_music_screen.dart',
      'lib/screens/home/home_screen.dart',
      'lib/screens/community/community_screen.dart',
      'lib/screens/voting/voting_screen.dart',
      'lib/screens/artists/artists_screen.dart',
      'lib/screens/artists/artist_detail_screen.dart',
      'lib/screens/organizers/organizers_screen.dart',
      'lib/screens/organizers/organizer_detail_screen.dart',
    ];

    test('a tartalom-képernyők minden `.when(` hívása megkapja a jelzőt', () {
      final problems = <String>[];
      for (final path in contentScreens) {
        // ⚠️ A MEGJEGYZÉSEKET előbb kivesszük: a magyarázó sorok a `.when(` és a
        // jelző KÖZÖTT állnak, ezért egy szövegablakos minta hamis bukást adna
        // (ez a saját mérőeszközöm hibája volt — a minta a kódra szól).
        final source = File(
          path,
        ).readAsStringSync().replaceAll(RegExp(r'^\s*//.*$', multiLine: true), '');
        final calls = RegExp(r'\.when\(').allMatches(source).length;
        final guarded = RegExp(
          r'\.when\([\s\S]{0,120}?skipLoadingOnReload: true',
        ).allMatches(source).length;
        if (calls != guarded) {
          problems.add(
            '$path: $calls `.when(` hívás, ebből $guarded védett '
            '(skipLoadingOnReload: true)',
          );
        }
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
    });

    test('a kivételek névre szólók és indokoltak', () {
      // ⚠️ KÉT KIVÉTEL, indoklással: a szavazás-/játék-ÁLLAPOT kérése. Ott a
      // régi tartalom **megtartása hiba lenne**: amíg a szerver nem mondja meg,
      // hogy ez a fiók már szavazott/játszott, a válaszlehetőségek **nem**
      // jelenhetnek meg (különben egy már szavazott felhasználó újra látná őket).
      const exemptions = <String, String>{
        'lib/screens/poll/poll_screen.dart':
            'a „már szavaztál-e" állapot: a válaszlehetőségek nem villanhatnak fel',
        'lib/screens/prize/prize_screen.dart':
            'a „már játszottál-e" állapot: a válaszlehetőségek nem villanhatnak fel',
      };
      for (final entry in exemptions.entries) {
        final source = File(entry.key).readAsStringSync();
        expect(
          source.contains('skipLoadingOnReload: true'),
          isFalse,
          reason:
              '${entry.key}: a kivétel csak addig érvényes, amíg a tartalom '
              'szándékosan nem marad meg (${entry.value})',
        );
      }
    });
  });
}

/// A hálózat nélküli WordPress-szolgáltatás: a képernyő **valódi** kódja fut,
/// csak a lista jön a memóriából.
///
/// ⚠️ `implements` + `noSuchMethod`: a `WordpressService` konstruktora
/// **library-privát** (`_internal`), ezért nem lehet leszármaztatni — a
/// `noSuchMethod` viszont csak a ténylegesen hívott tagokat kéri (a képernyő
/// egyedül a `getReleases`-t hívja).
// ignore_for_file: avoid_implementing_value_types
class _FakeWordpressService implements WordpressService {
  @override
  Future<List<HuhsRelease>> getReleases({
    String search = '',
    int artistId = 0,
    bool forceRefresh = false,
  }) async {
    return List<HuhsRelease>.generate(
      24,
      (index) => HuhsRelease(
        id: 9000 + index,
        title: 'Teszt kiadvány $index',
        coverUrl: '',
        genre: 'Hardstyle',
        artists: const <ReleaseArtist>[],
        tracks: const <ReleaseTrack>[],
        links: const <String, String>{},
        products: const <ReleaseProduct>[],
        versions: const <ReleaseVersion>[],
        audioStatus: 'available',
        releaseDate: '2026-09-01',
        isFree: false,
        freeExternalLink: '',
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}
