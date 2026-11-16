import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/models/artist.dart';
import 'package:hungarian_hardstyle_app/providers/artists_provider.dart';
import 'package:hungarian_hardstyle_app/providers/community_provider.dart';
import 'package:hungarian_hardstyle_app/screens/onboarding/onboarding_screen.dart';
import 'package:hungarian_hardstyle_app/services/onboarding_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

Artist _artist(int id, String title, List<String> genres) => Artist(
  id: id,
  title: title,
  slug: 'dj-$id',
  biography: '',
  excerpt: '',
  realName: '',
  country: '',
  city: '',
  genres: genres,
  categories: const [],
  logoUrl: '',
  profileImageUrl: '',
  featured: false,
  visible: true,
  webUrl: '',
  bookingEmail: '',
  bookingViaHuhs: false,
  socialLinks: const {},
  upcomingEvents: const [],
);

Widget _app() => ProviderScope(
  overrides: [
    currentUidProvider.overrideWithValue(null),
    artistsProvider.overrideWith(
      (ref, query) async => ArtistsPage(
        items: [
          _artist(1, 'Kemény Karcsi', const ['Hardcore']),
          _artist(2, 'Raw Rudi', const ['Rawstyle']),
        ],
        page: 1,
        perPage: 50,
        total: 2,
        totalPages: 1,
        hasMore: false,
      ),
    ),
  ],
  child: const MaterialApp(home: OnboardingScreen()),
);

Future<void> _next(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('onboarding-next')));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'vendégként: stílus → a stílushoz illő DJ elöl → követés helyben mentve',
    (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      // 1 → 2: stílusok a DJ-adatokból.
      await _next(tester);
      expect(find.widgetWithText(FilterChip, 'Rawstyle'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilterChip, 'Rawstyle'));
      await tester.pumpAndSettle();

      // 2 → 3: a választás mentődik, és a Rawstyle DJ kerül előre.
      await _next(tester);
      final prefs = await SharedPreferences.getInstance();
      expect(preferredGenresFromPreferences(prefs), {'Rawstyle'});
      final rudi = tester.getTopLeft(find.text('Raw Rudi')).dy;
      final karcsi = tester.getTopLeft(find.text('Kemény Karcsi')).dy;
      expect(rudi, lessThan(karcsi));

      await tester.tap(find.byKey(const Key('onboarding-artist-2')));
      await tester.pumpAndSettle();
      expect(pendingArtistFollowsFromPreferences(prefs), {2: 'Raw Rudi'});

      // 3 → 4: vendégnek a belépés ajánlata, a gomb „Később".
      await _next(tester);
      expect(find.byKey(const Key('onboarding-sign-in')), findsOneWidget);
      expect(find.text('Később'), findsOneWidget);

      // 4 → 5: az értesítés a követett DJ nevét mondja.
      await _next(tester);
      expect(find.textContaining('Raw Rudi'), findsOneWidget);
      expect(find.text('Kész'), findsOneWidget);
    },
  );

  testWidgets('a Kihagyás lezárja a bemutatót (v2 jelölés)', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kihagyás'));
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    expect(onboardingCompletedFromPreferences(prefs), isTrue);
  });
}
