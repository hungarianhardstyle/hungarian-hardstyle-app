import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/providers/achievement_provider.dart';
import 'package:hungarian_hardstyle_app/screens/more/achievement_guide_screen.dart';
import 'package:hungarian_hardstyle_app/services/achievement_service.dart';

/// `Több → Achievementek`.
///
/// MIÉRT kell ez a teszt: a képernyő szövegei **elavultak és pontatlanok**
/// voltak (a lájk visszavonásáról, a napi 5 kommentről, és két olyan sorról,
/// ami mögött nem volt szabály), és **semmi nem őrizte** őket — ezért csendben
/// elavultak. A teszt a szöveget és a szerverről töltött szinteket is méri.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpGuide(WidgetTester tester, {List<AchievementLevel>? levels}) {
    // Magas nézet: a képernyő `ListView`-ja lustán épít, ezért a lista alján
    // lévő sorok (pl. a legmagasabb szint) csak így jönnek létre.
    tester.view.physicalSize = const Size(1200, 4200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          achievementLevelsProvider.overrideWith(
            (ref) async => levels ?? AchievementService.fallbackLevels,
          ),
        ],
        child: const MaterialApp(home: AchievementGuideScreen()),
      ),
    );
  }

  test('a pontforrások a valós szabályokat írják le', () {
    final byTitle = {
      for (final activity in AchievementGuideScreen.activities)
        activity.title: activity,
    };

    // A komment napi kerete 3 (korábban tévesen 5 volt).
    expect(byTitle['Cikk kommentelése']!.detail, contains('legfeljebb 3'));
    expect(byTitle['Cikk kommentelése']!.detail, isNot(contains('legfeljebb 5')));

    // A lájkpont VÉGLEGES: a visszavonás nem veszi el (2026-09-19-i javítás).
    final like = byTitle['Hír kedvelése']!;
    expect(like.detail, contains('legfeljebb 3 hír'));
    expect(like.detail, contains('végleges'));
    expect(like.detail, isNot(contains('visszavonódik')));

    // A lemondásnál elvesző pontok kimondva (esemény, meetup, kapcsolat), és
    // az is, hogy ez ESEMÉNYENKÉNT egyszer jár (nem egyszer az életben).
    expect(byTitle['Eseményen ott leszek']!.detail, contains('Eseményenként'));
    expect(byTitle['Eseményen ott leszek']!.detail, contains('elvész'));
    expect(byTitle['Meetup jelzés']!.detail, contains('Meetuponként'));
    expect(byTitle['Meetup jelzés']!.detail, contains('elvész'));
    expect(
      byTitle['Kölcsönös kapcsolat meetupolóval']!.detail,
      contains('kapcsolatonként'),
    );
    expect(
      byTitle['Kölcsönös kapcsolat meetupolóval']!.detail,
      contains('megszűnik'),
    );
    expect(byTitle['Esemény utáni értékelés']!.detail, contains('Eseményenként'));

    // A két korábban „üres" sor mostantól valódi szabályt ír le.
    expect(byTitle['Kiadvány megvásárlása']!.points, '+20 pont');
    expect(byTitle['Kiadvány megvásárlása']!.detail, contains('Google Play'));
    expect(byTitle['Jóváhagyott beküldés']!.points, '+10 pont');
    expect(byTitle['Jóváhagyott beküldés']!.detail, contains('jóváhagyáskor'));
    expect(byTitle['Jóváhagyott beküldés']!.detail, contains('legfeljebb 3'));

    // A napi aktivitási pont (a tulajdonos kérése): 1–5, a szerver számolja.
    expect(byTitle['Napi aktivitási pont']!.points, '+1–5 pont');
    expect(byTitle['Napi aktivitási pont']!.detail, contains('1–5'));
    expect(byTitle['Napi aktivitási pont']!.detail, contains('chat'));

    // A játék-jutalom pontos (nem „pont járhat érte").
    expect(byTitle['HUHS játékok']!.detail, contains('sávokban'));

    // Nincs benne technikai zsargon, és a napi keretek is kimondva.
    final rules = AchievementGuideScreen.rules.join(' ');
    expect(rules, contains('naponta legfeljebb 3-3'));
    expect(rules, contains('napi aktivitási pont'));
    expect(rules, contains('végleges'));
    expect(rules, isNot(contains('idempotens')));
    expect(rules, isNot(contains('Firebase')));
    expect(rules, isNot(contains('szerveroldalon könyveli')));
  });

  testWidgets('a szintek a SZERVERRŐL jönnek (nem beégetve)', (tester) async {
    await pumpGuide(
      tester,
      levels: const [
        AchievementLevel(
          slug: 'uj-szint',
          name: 'Frissen szerkesztett szint',
          minPoints: 42,
          description: 'A WordPressben átírt leírás.',
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('Frissen szerkesztett szint'), findsOneWidget);
    expect(find.textContaining('42 pont'), findsOneWidget);
    expect(find.textContaining('A WordPressben átírt leírás.'), findsOneWidget);
    // A beégetett lista elemei ilyenkor NEM látszanak.
    expect(find.text('HUHS legenda'), findsNothing);
  });

  testWidgets('hálózat nélkül a tartalék szintek jelennek meg', (tester) async {
    await pumpGuide(tester);
    await tester.pumpAndSettle();

    expect(find.text('Kezdő ütem'), findsOneWidget);
    expect(find.text('HUHS legenda'), findsOneWidget);
    // A pontforrások és a szabályok hálózat nélkül is látszanak.
    expect(find.text('Hír kedvelése'), findsOneWidget);
    expect(find.text('Fontos szabályok'), findsOneWidget);
  });

  testWidgets('hálózat nélkül a beépített tartalék lista jön', (tester) async {
    // A valódi hívás platformcsatornát igényel, ezért a szolgáltatás
    // bemenetén keresztül mérjük a hibaágat: ilyenkor a tartalék lista kell.
    final failing = AchievementService(
      catalogCaller: () async => throw StateError('nincs hálózat'),
    );
    final levels = await failing.fetchLevels();
    expect(levels, isNotEmpty);
    expect(
      levels.map((level) => level.name).toList(),
      AchievementService.fallbackLevels.map((level) => level.name).toList(),
    );

    // Üres katalógus sem hagyhatja üresen a képernyőt.
    final empty = AchievementService(catalogCaller: () async => {'badges': []});
    expect(await empty.fetchLevels(), AchievementService.fallbackLevels);

    // A szerverről jött lista viszont a szerver sorrendjét adja (pontszám
    // szerint), és a hibás elemeket kihagyja.
    final fromServer = AchievementService(
      catalogCaller: () async => {
        'badges': [
          {'slug': 'b', 'name': 'Nagyobb', 'minPoints': 500, 'description': 'x'},
          {'slug': 'hibas', 'minPoints': 10},
          {'slug': 'a', 'name': 'Kisebb', 'minPoints': 100, 'description': 'y'},
        ],
      },
    );
    final parsed = await fromServer.fetchLevels();
    expect(parsed.map((level) => level.name).toList(), ['Kisebb', 'Nagyobb']);
  });
}
