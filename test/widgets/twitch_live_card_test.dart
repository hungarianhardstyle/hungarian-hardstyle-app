import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
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
    TwitchCardConfig? override,
  }) => ProviderScope(
    overrides: [
      twitchLiveProvider.overrideWith((ref) async => status),
      twitchCardOverrideProvider.overrideWith(
        (ref) async => override ?? const TwitchCardConfig(),
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
        override: const TwitchCardConfig(
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
        override: const TwitchCardConfig(showWhenOffline: true, headerText: 'Következő adás'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('twitch-live-card')), findsNothing);
  });

  testWidgets('a kikapcsolt kapcsoló élő adásnál is elrejti a kártyát', (tester) async {
    await tester.pumpWidget(
      wrap(status: liveStatus, override: const TwitchCardConfig(enabled: false)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('twitch-live-card')), findsNothing);
  });

  testWidgets('élő adásnál a saját kép és felirat kerül a kártyára', (tester) async {
    await tester.pumpWidget(
      wrap(
        status: liveStatus,
        override: const TwitchCardConfig(
          imageUrl: 'https://example.com/sajat.jpg',
          headerText: 'Élőben a stúdióból',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Élőben a stúdióból'), findsOneWidget);
    // A saját kép URL-je kerül a kép-widgetbe (a kártya nem a Twitch előnézetét
    // tölti) — 2026-10-02 óta **gyorsítótárazva** (`CachedNetworkImage`), ezért
    // nem `Image.network`-öt keresünk.
    final image = tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));
    expect(image.imageUrl, contains('example.com/sajat.jpg'));
    expect(image.memCacheWidth, 900, reason: 'a kép teljes méretben dekódolódna');
  });

  testWidgets('élő adásnál kép nélkül a Twitch mozgó előnézete megy (frissítő paraméterrel)', (tester) async {
    await tester.pumpWidget(wrap(status: liveStatus));
    await tester.pumpAndSettle();

    final image = tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));
    expect(image.imageUrl, contains('previews-ttv'));
    // A 30 másodperces kör a gyorsítótár-kerülő paramétert írja a linkre.
    expect(image.imageUrl, contains('tick='));
  });

  testWidgets('a behirdetett kártya AZONNAL megjelenik (a Twitch-állapot nem kell hozzá)', (tester) async {
    // ⚠️ A tulajdonos jelzése: *„meg ez a twitch kártya a főoldalon 100 év mire
    // betölt”*. A mért gyökér: a kártya a Twitch-állapotra várt. Ez a teszt a
    // provider **soha be nem fejeződő** jövőjével méri, hogy a kártya így is ott
    // van-e (az „ÉLŐ" jelvény nélkül).
    final pending = Completer<TwitchLiveStatus>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          twitchLiveProvider.overrideWith((ref) => pending.future),
          twitchCardOverrideProvider.overrideWith(
            (ref) async => const TwitchCardConfig(
              imageUrl: 'https://example.com/plakat.jpg',
              showWhenOffline: true,
              headerText: 'Következő adás: péntek 20:00',
            ),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(body: SingleChildScrollView(child: TwitchLiveCard())),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('twitch-live-card')), findsOneWidget,
        reason: 'a behirdetett kártya a Twitch-állapot nélkül is látszik');
    expect(find.text('Következő adás: péntek 20:00'), findsOneWidget);
    expect(find.text('ÉLŐ'), findsNothing, reason: 'nem hazudunk élő adást');
    expect(find.text('Twitch-csatorna'), findsOneWidget);
    pending.complete(offlineStatus);
  });
}
