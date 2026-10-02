import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/providers/twitch_live_provider.dart';
import 'package:hungarian_hardstyle_app/services/twitch_live.dart';
import 'package:hungarian_hardstyle_app/widgets/twitch_live_card.dart';

/// A főoldali **Twitch-kártya** VISELKEDÉSE — valódi kirajzolással, nem
/// forrás-linttel.
///
/// MIÉRT (mért hiány, 2026-10-02): a láthatóság döntése ugyan tiszta
/// függvényben él (`twitchCardVisible`, mérve a `twitch_live_test.dart`-ban), de
/// az önmagában **nem** bizonyítja, hogy a **widget** is így viselkedik: a kártya
/// a döntést használja-e, a felirat/gomb/jelvény a valódi állapotot tükrözi-e.
/// Ez a kör ezért override-olt providerekkel **tényleg kirajzolja** a kártyát
/// minden ágban.
void main() {
  const liveStatus = TwitchLiveStatus(
    isLive: true,
    title: 'HUHS Live #42 — hardstyle session',
    viewers: 128,
    thumbnailUrl: 'https://static-cdn.jtvnw.net/previews-ttv/live_user_hungarianhardstyle-640x360.jpg',
  );
  const offlineStatus = TwitchLiveStatus(
    thumbnailUrl: 'https://static-cdn.jtvnw.net/previews-ttv/live_user_hungarianhardstyle-640x360.jpg',
  );

  Widget wrap({
    required TwitchLiveStatus status,
    TwitchCardOverride? override,
  }) => ProviderScope(
    overrides: [
      twitchLiveProvider.overrideWith((ref) async => status),
      twitchCardOverrideProvider.overrideWith(
        (ref) async => override ?? const TwitchCardOverride(),
      ),
    ],
    child: MaterialApp(
      theme: ThemeData.dark(),
      home: const Scaffold(body: SingleChildScrollView(child: TwitchLiveCard())),
    ),
  );

  testWidgets('élő adásnál kirajzolódik, ÉLŐ jelvénnyel és nézőszámmal', (tester) async {
    await tester.pumpWidget(wrap(status: liveStatus));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('twitch-live-card')), findsOneWidget);
    expect(find.text('ÉLŐ'), findsOneWidget);
    expect(find.text('128 néző'), findsOneWidget);
    expect(find.text('HUHS Live #42 — hardstyle session'), findsOneWidget);
    expect(find.text('Élőben a Twitch-csatornán'), findsOneWidget);
    expect(find.text('Nézd élőben'), findsOneWidget);
  });

  testWidgets('élő adás nélkül alapból SEMMI nem jelenik meg (nem hagy üres helyet)', (tester) async {
    await tester.pumpWidget(wrap(status: offlineStatus));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('twitch-live-card')), findsNothing);
    expect(find.text('ÉLŐ'), findsNothing);
  });

  testWidgets('offline behirdetés: a tulajdonos képével és feliratával megjelenik', (tester) async {
    await tester.pumpWidget(
      wrap(
        status: offlineStatus,
        override: const TwitchCardOverride(
          showWhenOffline: true,
          imageUrl: 'https://example.com/plakat.jpg',
          headerText: 'Következő adás: péntek 20:00',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('twitch-live-card')), findsOneWidget);
    expect(find.text('Következő adás: péntek 20:00'), findsOneWidget);
    // ⚠️ NEM hazudik élő adást: nincs jelvény, és a gomb a csatornára visz.
    expect(find.text('ÉLŐ'), findsNothing);
    expect(find.text('Nézd élőben'), findsNothing);
    expect(find.text('Twitch-csatorna'), findsOneWidget);
  });

  testWidgets('offline behirdetés kép NÉLKÜL nem jelenik meg (nincs mit mutatni)', (tester) async {
    await tester.pumpWidget(
      wrap(
        status: offlineStatus,
        override: const TwitchCardOverride(showWhenOffline: true, headerText: 'Következő adás'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('twitch-live-card')), findsNothing);
  });

  testWidgets('a kikapcsolt kapcsoló élő adásnál is elrejti a kártyát', (tester) async {
    await tester.pumpWidget(
      wrap(status: liveStatus, override: const TwitchCardOverride(enabled: false)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('twitch-live-card')), findsNothing);
  });

  testWidgets('élő adásnál a saját kép és felirat kerül a kártyára', (tester) async {
    await tester.pumpWidget(
      wrap(
        status: liveStatus,
        override: const TwitchCardOverride(
          imageUrl: 'https://example.com/sajat.jpg',
          headerText: 'Élőben a stúdióból',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Élőben a stúdióból'), findsOneWidget);
    // A saját kép URL-je kerül a kép-widgetbe (a kártya nem a Twitch előnézetét tölti).
    final images = tester.widgetList<Image>(find.byType(Image)).toList();
    expect(images, isNotEmpty);
    expect(images.first.image.toString(), contains('example.com/sajat.jpg'));
  });

  testWidgets('élő adásnál kép nélkül a Twitch mozgó előnézete megy (frissítő paraméterrel)', (tester) async {
    await tester.pumpWidget(wrap(status: liveStatus));
    await tester.pumpAndSettle();

    final images = tester.widgetList<Image>(find.byType(Image)).toList();
    expect(images, isNotEmpty);
    expect(images.first.image.toString(), contains('previews-ttv'));
    // A 30 másodperces kör a gyorsítótár-kerülő paramétert írja a linkre.
    expect(images.first.image.toString(), contains('tick='));
  });
}
