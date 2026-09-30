import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hungarian_hardstyle_app/providers/favorites_provider.dart';
import 'package:hungarian_hardstyle_app/widgets/followed_section.dart';

/// A főoldali **„Kedvenceid"** szekció kapuja.
///
/// **MIÉRT (mért ok):** a kedvencek eddig **csak** a „Több" → „Kedvencek"
/// képernyőn látszottak (89 kedvenc a Firestore-ban), a főoldalon semmi. A
/// szekció ezt hozza előre — a teszt azt méri, hogy (1) a követett DJ-k és
/// szervezők **kirajzolódnak** típus-címkével, (2) a koppintás a **helyes
/// bejegyzést** adja tovább, (3) **üresen semmi** nem jelenik meg (nem hagy
/// üres helyet a főoldalon), és (4) a valódi (provider-alapú) szekció a
/// **mentett kedvencekből** dolgozik, a megnyitást pedig a Kedvencek képernyő
/// **közös útvonalválasztója** végzi (egy helyen él a célképernyő-térkép).
void main() {
  Widget wrap(Widget child) => ProviderScope(
    child: MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );

  const artist = FavoriteEntry(
    kind: FavoriteKind.artist,
    id: 7,
    title: 'Nu-Clear',
  );
  const organizer = FavoriteEntry(
    kind: FavoriteKind.organizer,
    id: 12,
    title: 'Hard Base',
  );

  testWidgets('a követett DJ és szervező kirajzolódik, típus-címkével', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        FollowedSectionBody(
          entries: const [artist, organizer],
          onOpen: (_) {},
          onOpenAll: () {},
        ),
      ),
    );

    expect(find.byKey(const Key('followed-section')), findsOneWidget);
    expect(find.text('Kedvenceid'), findsOneWidget);
    expect(find.text('Nu-Clear'), findsOneWidget);
    expect(find.text('Hard Base'), findsOneWidget);
    // A típus-címke a szótárból fordítva (angol felületen DJ / Organizer).
    expect(find.text('DJ'), findsOneWidget);
    expect(find.text('SZERVEZŐ'), findsOneWidget);
    expect(find.text('Összes'), findsOneWidget);
  });

  testWidgets('a kártya a saját bejegyzését adja tovább (nem mást)', (
    tester,
  ) async {
    final opened = <FavoriteEntry>[];
    var openAll = 0;
    await tester.pumpWidget(
      wrap(
        FollowedSectionBody(
          entries: const [artist, organizer],
          onOpen: opened.add,
          onOpenAll: () => openAll += 1,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('followed-organizer-12')));
    await tester.pumpAndSettle();

    expect(opened, hasLength(1));
    expect(opened.single.kind, FavoriteKind.organizer);
    expect(opened.single.id, 12);
    expect(openAll, 0, reason: 'a kártya nem a „Összes" gombot nyitja meg');

    await tester.tap(find.text('Összes'));
    await tester.pumpAndSettle();
    expect(openAll, 1);
    expect(opened, hasLength(1), reason: 'az „Összes" nem nyit bejegyzést');
  });

  testWidgets('üres követésnél a szekció semmit nem rajzol', (tester) async {
    await tester.pumpWidget(
      wrap(
        FollowedSectionBody(
          entries: const [],
          onOpen: (_) {},
          onOpenAll: () {},
        ),
      ),
    );

    expect(find.byKey(const Key('followed-section')), findsNothing);
    expect(find.text('Kedvenceid'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a valódi szekció a mentett kedvencekből dolgozik', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'favorite_items': [
        jsonEncode({'kind': 'artist', 'id': 7, 'title': 'Nu-Clear'}),
        jsonEncode({'kind': 'organizer', 'id': 12, 'title': 'Hard Base'}),
        // A kedvelt **esemény** nem követés: a szekcióban nem szerepelhet.
        jsonEncode({'kind': 'event', 'id': 99, 'title': 'Valami buli'}),
      ],
    });

    await tester.pumpWidget(wrap(const FollowedSection()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('followed-section')), findsOneWidget);
    expect(find.text('Nu-Clear'), findsOneWidget);
    expect(find.text('Hard Base'), findsOneWidget);
    expect(
      find.text('Valami buli'),
      findsNothing,
      reason: 'a kedvelt esemény nem „követés" — az a Kedvencek képernyőn van',
    );
  });

  testWidgets('mentett kedvenc nélkül a valódi szekció eltűnik', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(wrap(const FollowedSection()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('followed-section')), findsNothing);
    expect(find.text('Kedvenceid'), findsNothing);
  });

  test('a főoldal beszúrja a szekciót, és a megnyitás a közös úton megy', () {
    final home = File(
      'lib/screens/home/home_screen.dart',
    ).readAsStringSync();
    expect(
      home.contains('const FollowedSection(),'),
      isTrue,
      reason: 'a főoldal ListView-jában ott kell lennie a szekciónak',
    );
    expect(
      home.contains("import '../../widgets/followed_section.dart';"),
      isTrue,
      reason: 'a szekció importja hiányzik a főoldalról',
    );

    final source = File(
      'lib/widgets/followed_section.dart',
    ).readAsStringSync();
    // A koppintás célja **egy** helyen dől el (a Kedvencek képernyő térképe),
    // ezért a két felület nem tud széttartani.
    expect(
      source.contains('FavoritesScreen.openEntry(context, ref, entry)'),
      isTrue,
      reason: 'a kártya megnyitása a Kedvencek képernyő közös útvonalát használja',
    );
    expect(
      source.contains('entry.kind == FavoriteKind.artist') &&
          source.contains('entry.kind == FavoriteKind.organizer'),
      isTrue,
      reason: 'a szekció csak a követés-jellegű kedvenceket mutatja',
    );
    // A szótár-kulcsok (a magyar a kulcs).
    final dictionary =
        jsonDecode(File('assets/i18n/en.json').readAsStringSync())
            as Map<String, dynamic>;
    expect(dictionary['Kedvenceid'], 'Your favorites');
    expect(dictionary['DJ'], 'DJ');
  });

  /// **A HELYE** — a tulajdonos jelzése (2026-09-30): *„a Hero FÖLÉ került, ami baj"*.
  ///
  /// A sorrendet a **forrás pozícióival** mérjük, mert pontosan ez volt a hiba:
  /// a szekció a logó-kártya ELÉ került. A mérés így nem attól függ, hogy egy
  /// `ListView` éppen mit rajzol ki a teszt-felületen.
  test('a szekció a Hero UTÁN, a hírek sora után és az események ELŐTT áll', () {
    final home = File('lib/screens/home/home_screen.dart').readAsStringSync();
    final section = home.indexOf('const FollowedSection(),');
    final hero = home.indexOf('HUNGARIAN HARDSTYLE');
    final moreNews = home.indexOf("key: const Key('more-news')");
    final events = home.indexOf("'Közelgő események'");

    expect(section, greaterThan(-1), reason: 'a szekció benne van a főoldalon');
    expect(
      hero,
      greaterThan(-1),
      reason: 'a Hero (logó) kártya megvan a forrásban',
    );
    expect(
      section,
      greaterThan(hero),
      reason: 'a szekció NEM kerülhet a Hero (logó) kártya fölé',
    );
    expect(
      section,
      greaterThan(moreNews),
      reason: 'a szekció a „További hírek" kártya UTÁN jön',
    );
    expect(
      section,
      lessThan(events),
      reason: 'a szekció a „Közelgő események" szakasz ELŐTT van',
    );
  });

  /// **MENNYIT MUTAT** — a tulajdonos kérése: *„max 3 legyen kiemelve, a többire
  /// ott az »összes«"*. Ezért öt kedvencből **három** kártya és az „Összes" gomb
  /// látszik.
  testWidgets('legfeljebb HÁROM kedvenc látszik, a többi az „Összes" mögött', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'favorite_items': [
        for (var id = 1; id <= 5; id += 1)
          jsonEncode({'kind': 'artist', 'id': id, 'title': 'DJ $id'}),
      ],
    });

    await tester.pumpWidget(wrap(const FollowedSection()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('followed-section')), findsOneWidget);
    expect(
      find.byKey(const Key('followed-artist-1')),
      findsOneWidget,
      reason: 'az első kedvenc látszik',
    );
    expect(find.byKey(const Key('followed-artist-3')), findsOneWidget);
    expect(
      find.byKey(const Key('followed-artist-4')),
      findsNothing,
      reason: 'a negyedik kedvenc már nem fér bele a három kiemelt helyre',
    );
    expect(find.byKey(const Key('followed-artist-5')), findsNothing);
    expect(
      find.text('Összes'),
      findsOneWidget,
      reason: 'a többi kedvenc az „Összes" gombbal érhető el',
    );
    expect(
      FollowedSection.maxItems,
      3,
      reason: 'a kiemelés felső határa a konstansban él (egy helyen)',
    );
  });
}
