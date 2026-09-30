import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'package:hungarian_hardstyle_app/models/event.dart';
import 'package:hungarian_hardstyle_app/widgets/calendar_export_button.dart';

/// A külső megnyitás **meghatározott** helyettesítője: a teszt így pontosan azt
/// méri, amit állít (a valódi plugin a teszt-környezetben nem hívható, és a
/// válasza platformonként más lenne — az „esetleg" nem bizonyíték).
class _FakeLauncher extends UrlLauncherPlatform {
  _FakeLauncher({required this.succeeds});

  final bool succeeds;
  int calls = 0;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launch(
    String url, {
    bool? useSafariVC,
    bool? useWebView,
    bool? enableJavaScript,
    bool? enableDomStorage,
    bool? universalLinksOnly,
    Map<String, String>? headers,
    String? webOnlyWindowName,
  }) async {
    calls += 1;
    return succeeds;
  }

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    calls += 1;
    return succeeds;
  }

  @override
  Future<bool> supportsCloseForMode(PreferredLaunchMode mode) async => true;

  @override
  Future<bool> supportsMode(PreferredLaunchMode mode) async => true;

  /// A platform-interfész egyetlen kötelező tagja, amit nem használunk: a
  /// `Link`-kezelő (ez a webes `linkDelegate`). A teszt nem hívja.
  @override
  LinkDelegate? get linkDelegate => null;
}

/// A **„Naptárba"** gomb és lap viselkedése.
///
/// MIÉRT: a tiszta `.ics`/link-építést a `test/services/event_calendar_test.dart`
/// méri; itt az a kérdés, hogy a felhasználó **eljut-e** oda, és hogy egy
/// hibás/elérhetetlen rendszerhívás **nem töri-e el** a képernyőt (a 382-es kör
/// tanulsága: az iPhone megosztó lap némán elmaradhat, illetve a hívás dobhat).
void main() {
  HuhsEvent event() => HuhsEvent.fromJson(const {
    'id': 12505,
    'title': 'Hard Base Classic',
    'start_date': '2026-10-17',
    'start_time': '23:00',
    'end_date': '2026-10-18',
    'end_time': '05:00',
    'venue_name': 'Barba Negra',
    'venue_city': 'Budapest',
  });

  Widget wrap(Widget child) => MaterialApp(
    theme: ThemeData.dark(),
    home: Scaffold(appBar: AppBar(actions: [child]), body: const SizedBox()),
  );

  testWidgets('a gomb koppintásra megnyitja a naptárlapot MINDKÉT úttal', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(EventCalendarButton(event: event())));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.calendar_month_outlined), findsOneWidget);
    await tester.tap(find.byIcon(Icons.calendar_month_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Esemény a naptárba'), findsOneWidget);
    expect(find.text('Google Naptár'), findsOneWidget);
    expect(find.text('Naptárfájl (.ics)'), findsOneWidget);
    // A magyarázat is ott van (a felhasználó tudja, melyik mit csinál).
    expect(find.text('Azonnal megnyílik a mentés lap'), findsOneWidget);
  });

  testWidgets('dátum nélküli eseménynél nincs lap, hanem érthető üzenet', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        EventCalendarButton(
          event: HuhsEvent.fromJson(const {'id': 7, 'title': 'Dátum nélkül'}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.calendar_month_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Ehhez az eseményhez nincs érvényes dátum.'), findsOneWidget);
    expect(find.text('Google Naptár'), findsNothing);
  });

  testWidgets('ha a naptár nem nyitható meg, NÉMA hibaüzenet jön (nem omlik össze)', (
    tester,
  ) async {
    final launcher = _FakeLauncher(succeeds: false);
    UrlLauncherPlatform.instance = launcher;
    addTearDown(() => UrlLauncherPlatform.instance = _FakeLauncher(succeeds: true));

    await tester.pumpWidget(wrap(EventCalendarButton(event: event())));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.calendar_month_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Google Naptár'));
    await tester.pumpAndSettle();

    expect(launcher.calls, greaterThan(0), reason: 'megpróbálta megnyitni');
    expect(tester.takeException(), isNull);
    expect(find.text('Nem sikerult megnyitni a linket.'), findsOneWidget);
  });

  testWidgets('sikeres megnyitásnál nincs hibaüzenet, és a lap bezárul', (
    tester,
  ) async {
    final launcher = _FakeLauncher(succeeds: true);
    UrlLauncherPlatform.instance = launcher;

    await tester.pumpWidget(wrap(EventCalendarButton(event: event())));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.calendar_month_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Google Naptár'));
    await tester.pumpAndSettle();

    expect(launcher.calls, greaterThan(0));
    expect(find.text('Nem sikerult megnyitni a linket.'), findsNothing);
    expect(find.text('Google Naptár'), findsNothing, reason: 'a lap bezárult');
    expect(tester.takeException(), isNull);
  });
}
