import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/models/release.dart';
import 'package:hungarian_hardstyle_app/providers/releases_provider.dart';
import 'package:hungarian_hardstyle_app/widgets/artist_releases_section.dart';
import 'package:hungarian_hardstyle_app/widgets/release_card.dart';

void main() {
  HuhsRelease release(
    int id, {
    List<int> artists = const [1],
    String title = 'Release',
    String date = '2026-01-01',
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

  Widget wrap(Future<List<HuhsRelease>> Function() load, {int artistId = 1}) {
    return ProviderScope(
      overrides: [releasesProvider.overrideWith((ref, query) => load())],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ArtistReleasesSection(
              artistId: artistId,
              artistName: 'Goze',
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('amíg tölt, semmit nem rajzol (nincs pörgő, nincs villogás)', (
    tester,
  ) async {
    final gate = Completer<List<HuhsRelease>>();
    await tester.pumpWidget(wrap(() => gate.future));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Megjelenései'), findsNothing);
    expect(find.byType(ReleaseCard), findsNothing);

    gate.complete([release(10, title: 'Goze – TikaTika')]);
    await tester.pump();
  });

  testWidgets('a saját kiadványok fejléccel és kártyákkal jelennek meg', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        () async => [
          release(10, title: 'Goze – TikaTika'),
          release(11, title: 'Goze x Denoiser', artists: const [1, 2]),
          release(12, title: 'Más DJ kiadványa', artists: const [2]),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Megjelenései'), findsOneWidget);
    expect(find.byType(ReleaseCard), findsNWidgets(2));
    expect(find.text('Goze – TikaTika'), findsOneWidget);
    expect(
      find.text('Más DJ kiadványa'),
      findsNothing,
      reason: 'más DJ kiadványa nem kerülhet a DJ-adatlapra',
    );
  });

  testWidgets('egy kiadványnál egyes szám a cím', (tester) async {
    await tester.pumpWidget(wrap(() async => [release(10)]));
    await tester.pumpAndSettle();

    expect(find.text('Megjelenése'), findsOneWidget);
    expect(find.text('Megjelenései'), findsNothing);
  });

  testWidgets('ha nincs kiadványa, a szakasz nem látszik', (tester) async {
    await tester.pumpWidget(
      wrap(() async => [release(10, artists: const [2])]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Megjelenései'), findsNothing);
    expect(find.byType(ReleaseCard), findsNothing);
  });

  testWidgets('hibánál nem tesz hibadobozt a DJ-adatlapra', (tester) async {
    await tester.pumpWidget(
      wrap(() => Future<List<HuhsRelease>>.error(Exception('nem elérhető'))),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ReleaseCard), findsNothing);
    expect(find.textContaining('nem elérhető'), findsNothing);
    expect(find.text('Megjelenései'), findsNothing);
  });

  testWidgets('négy kiadvány után „Összes megjelenése" gomb jön', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        () async => List.generate(
          6,
          (index) => release(
            index + 1,
            title: 'Goze #${index + 1}',
            date: '2026-01-0${index + 1}',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ReleaseCard), findsNWidgets(4));
    expect(find.text('Összes megjelenése (6)'), findsOneWidget);
    // A legfrissebb négy látszik: a két legrégebbi nem.
    expect(find.text('Goze #6'), findsOneWidget);
    expect(find.text('Goze #1'), findsNothing);
  });
}
