import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/providers/twitch_live_provider.dart';
import 'package:hungarian_hardstyle_app/services/adaptive_card_layout.dart';
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

  testWidgets('élő adásnál a MOZGÓ streamkép megy a beharangozó kép HELYETT', (tester) async {
    // ⚠️ A tulajdonos kérése (2026-10-03): *„ha elindul egy twitch stream, akkor
    // a beharangozó kép helyett mehetne a stream mozgóképe a főoldalon.”* Ez
    // **szándékosan megváltoztatta** a korábbi viselkedést (a saját kép ment élő
    // adásnál is): a saját kép a **következő** adás beharangozója.
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

    expect(find.text('Élőben a stúdióból'), findsOneWidget,
        reason: 'a felirat a tulajdonosé marad');
    // A kép **gyorsítótárazva** töltődik (`CachedNetworkImage`), ezért nem
    // `Image.network`-öt keresünk.
    final image = tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));
    expect(image.imageUrl, contains('previews-ttv'),
        reason: 'élő adásnál a mozgó streamkép kell');
    expect(image.imageUrl, contains('tick='),
        reason: 'a mozgó előnézet frissítő paramétere nélkül befagyna a kép');
    expect(image.imageUrl.contains('sajat.jpg'), isFalse,
        reason: 'a beharangozó kép élő adásnál elrejtené a streamet');
    expect(image.memCacheWidth, 900, reason: 'a kép teljes méretben dekódolódna');
  });

  testWidgets('adás nélkül a tulajdonos beharangozó képe marad', (tester) async {
    await tester.pumpWidget(
      wrap(
        status: offlineStatus,
        override: const TwitchCardConfig(
          showWhenOffline: true,
          imageUrl: 'https://example.com/sajat.jpg',
          headerText: 'Élőben a stúdióból',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final image = tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));
    expect(image.imageUrl, contains('example.com/sajat.jpg'));
    expect(image.imageUrl.contains('tick='), isFalse,
        reason: 'a beharangozó kép egy pillanatkép, nem kell újratölteni');
  });

  testWidgets('széles (fekvő/tablet) nézetben a kártya legfeljebb 760 px széles', (tester) async {
    // ⚠️ A tulajdonos jelzése (2026-10-03): *„fekvő módban és tableten fekvő
    // módban a friss hírek kártya és a twitch beharangozó túl nagy.”* A 16:9-es
    // kép a teljes szélességhez igazodott. A korlát a **közös** szabályból jön
    // (`services/adaptive_card_layout.dart`), ugyanaz, mint a hírkártyáknál.
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(status: liveStatus));
    await tester.pumpAndSettle();

    final card = tester.getRect(find.byKey(const Key('twitch-live-card')));
    expect(card.width, lessThanOrEqualTo(wideCardMaxWidth + 0.01),
        reason: 'a kártya a fél tabletet elvinné');
    expect(card.width, greaterThan(wideCardMaxWidth - 40),
        reason: 'a korlát ne legyen indokolatlanul szűk');
    expect(card.center.dx, closeTo(1280 / 2, 1),
        reason: 'a kártya középre igazítva maradjon');
  });

  testWidgets('álló telefonon teljes szélességű marad (a tulajdonos szerint ez jó)', (tester) async {
    tester.view.physicalSize = const Size(412, 892);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(status: liveStatus));
    await tester.pumpAndSettle();

    final card = tester.getRect(find.byKey(const Key('twitch-live-card')));
    expect(card.width, greaterThan(370),
        reason: 'álló telefonon ne szűküljön be a kártya');
    expect(card.width, lessThanOrEqualTo(412));
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
