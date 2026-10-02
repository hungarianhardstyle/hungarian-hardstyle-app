import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/screens/twitch/twitch_layout.dart';
import 'package:hungarian_hardstyle_app/services/twitch_layout.dart';

/// A Twitch-oldal **elrendezésének mérése** — a tulajdonos három jelzésére
/// (2026-10-02, videóval az Android-telefonról):
///
/// *„gond van androidon is, az a chat rész elég pici”*,
/// *„+ hiba, fekvő módban nincs chat”*,
/// *„+ figyelj a tabletre is”*.
///
/// ⚠️ MIÉRT geometria és nem forrás-lint: a hiba **nem** az volt, hogy valami
/// hiányzik a kódból — a függőleges elrendezés **lenullázta** a chat magasságát.
/// Ezt csak **kirajzolva** lehet mérni, ezért a teszt a vázat valódi
/// méretekben rajzolja ki, és a widgetek **tényleges helyét** kéri le
/// (`tester.getRect`).
void main() {
  // A telefonok/tabletek logikai méretei (a mért esetek: a tulajdonos telefonja
  // álló és fekvő módban, illetve egy tablet).
  const phonePortrait = Size(412, 892);
  const phoneLandscape = Size(892, 412);
  const tabletPortrait = Size(800, 1280);
  const tabletLandscape = Size(1280, 800);
  const smallLandscape = Size(640, 360);

  Widget frame(Size size) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: size),
          child: Scaffold(
            body: SizedBox(
              width: size.width,
              height: size.height,
              child: const TwitchLayoutFrame(
                video: ColoredBox(color: Colors.black, child: SizedBox.expand(key: Key('teszt-video'))),
                info: SizedBox(key: Key('teszt-info'), height: 80),
                chat: SizedBox(key: Key('teszt-chat')),
              ),
            ),
          ),
        ),
      );

  group('tiszta döntés: melyik elrendezés való', () {
    test('álló telefon → egymás alatt', () {
      expect(twitchLayoutModeFor(phonePortrait), TwitchLayoutMode.stacked);
    });

    test('fekvő telefon → egymás mellett (ez volt a „nincs chat” hiba)', () {
      expect(twitchLayoutModeFor(phoneLandscape), TwitchLayoutMode.sideBySide);
      expect(twitchLayoutModeFor(smallLandscape), TwitchLayoutMode.sideBySide,
          reason: 'a kicsi fekvő képernyőn is látszania kell a chatnek');
    });

    test('tablet (álló és fekvő) → egymás mellett', () {
      expect(twitchLayoutModeFor(tabletPortrait), TwitchLayoutMode.sideBySide);
      expect(twitchLayoutModeFor(tabletLandscape), TwitchLayoutMode.sideBySide);
    });

    test('a videó a stacked módban legfeljebb a magasság harmada', () {
      final height = twitchStackedVideoHeight(phonePortrait);
      expect(height, lessThanOrEqualTo(phonePortrait.height * twitchVideoHeightFraction + 0.01));
      expect(height, greaterThan(100), reason: 'a videó azért látszódjon');
    });

    test('a chat oszlop szélessége a korlátok között marad', () {
      for (final size in [phoneLandscape, tabletPortrait, tabletLandscape, smallLandscape]) {
        final width = twitchSideChatWidth(size);
        expect(width, greaterThanOrEqualTo(twitchSideChatMinWidth - 0.01));
        expect(width, lessThanOrEqualTo(twitchSideChatMaxWidth + 0.01));
      }
    });
  });

  group('kirajzolva: a chat MINDIG látszik és elég nagy', () {
    testWidgets('gépelés közben (billentyűzet) a videó eltűnik — a chat a teljes helyet kapja', (tester) async {
      // A tulajdonos jelzése (2026-10-02): *„az a chat rész NAGYON kicsi, az
      // olvasható rész”* — gépelés közben a videó és az adatsáv összehúzódik.
      const size = phonePortrait;
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      Widget frameWithKeyboard(bool keyboard) => MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(size: size),
              child: Scaffold(
                body: SizedBox(
                  width: size.width,
                  height: size.height,
                  child: TwitchLayoutFrame(
                    keyboardVisible: keyboard,
                    video: const ColoredBox(color: Colors.black, child: SizedBox.expand()),
                    info: const SizedBox(key: Key('teszt-info'), height: 80),
                    chat: const SizedBox(key: Key('teszt-chat')),
                  ),
                ),
              ),
            ),
          );

      await tester.pumpWidget(frameWithKeyboard(false));
      await tester.pumpAndSettle();
      final withoutKeyboard = tester.getRect(find.byKey(const Key('twitch-stacked-chat')));

      await tester.pumpWidget(frameWithKeyboard(true));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('twitch-video-area')), findsNothing,
          reason: 'gépelés közben a videó nem viheti el a helyet');
      expect(find.byKey(const Key('teszt-info')), findsNothing,
          reason: 'gépelés közben az adatsáv is eltűnik');
      final withKeyboard = tester.getRect(find.byKey(const Key('twitch-stacked-chat')));

      expect(withKeyboard.height, greaterThan(withoutKeyboard.height),
          reason: 'gépelés közben a chat nagyobb, mint a videóval');
      expect(withKeyboard.top, lessThan(withoutKeyboard.top));
    });

    testWidgets('álló telefonon a chat a videó ALATT van, és nagy a helye', (tester) async {
      const size = phonePortrait;
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(frame(size));
      await tester.pumpAndSettle();

      final video = tester.getRect(find.byKey(const Key('twitch-video-area')));
      final chat = tester.getRect(find.byKey(const Key('twitch-stacked-chat')));

      expect(video.height, lessThanOrEqualTo(size.height * twitchVideoHeightFraction + 0.01),
          reason: 'a videó nem viheti el a hely nagy részét');
      expect(chat.top, greaterThanOrEqualTo(video.bottom - 0.01),
          reason: 'a chat a videó alatt van');
      expect(chat.height, greaterThan(size.height * 0.4),
          reason: 'a chat kapja a képernyő érdemi részét („elég pici” volt)');
    });

    testWidgets('fekvő telefonon a chat a videó MELLETT van, teljes magasságban', (tester) async {
      const size = phoneLandscape;
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(frame(size));
      await tester.pumpAndSettle();

      final video = tester.getRect(find.byKey(const Key('twitch-video-area')));
      final chat = tester.getRect(find.byKey(const Key('twitch-side-chat-column')));

      expect(find.byKey(const Key('twitch-stacked-chat')), findsNothing,
          reason: 'fekvő módban nem a függőleges elrendezés való');
      expect(chat.left, greaterThanOrEqualTo(video.right - 0.01),
          reason: 'a chat a videótól jobbra van');
      expect(chat.height, greaterThan(size.height * 0.9),
          reason: 'a chat a teljes magasságot kapja');
      expect(chat.width, greaterThanOrEqualTo(twitchSideChatMinWidth - 0.01));
    });

    testWidgets('tableten is egymás mellett van a chat (a tulajdonos kérése)', (tester) async {
      for (final size in [tabletPortrait, tabletLandscape]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(frame(size));
        await tester.pumpAndSettle();

        final video = tester.getRect(find.byKey(const Key('twitch-video-area')));
        final chat = tester.getRect(find.byKey(const Key('twitch-side-chat-column')));
        expect(chat.left, greaterThanOrEqualTo(video.right - 0.01),
            reason: '$size: a chat nem került a videó mellé');
        expect(chat.height, greaterThan(size.height * 0.9), reason: '$size: kicsi a chat');
        expect(chat.width, greaterThanOrEqualTo(twitchSideChatMinWidth - 0.01));
      }
    });

    testWidgets('nyitott képarányú (kis tablet / összecsukható) képernyőn is a chat kapja a helyet', (tester) async {
      // ⚠️ EZ az az eset, ahol a videó magasság-korlátja **tényleg dolgozik**: a
      // 16:9-es videó a szélességből számolva magasabb lenne, mint a képernyő
      // harmada. A mutációs bizonyíték ezen a ponton mérte, hogy a korlát
      // elvétele **nem** bukott meg a magas telefonos eseten (ott a 16:9 eleve
      // kisebb a korlátnál) — ezért ez a méret is bekerült a körbe.
      const size = Size(600, 800);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      expect(twitchLayoutModeFor(size), TwitchLayoutMode.stacked);
      await tester.pumpWidget(frame(size));
      await tester.pumpAndSettle();

      final video = tester.getRect(find.byKey(const Key('twitch-video-area')));
      final chat = tester.getRect(find.byKey(const Key('twitch-stacked-chat')));

      expect(video.height, lessThanOrEqualTo(size.height * twitchVideoHeightFraction + 0.01),
          reason: 'a magasság-korlát nélkül a videó elvinné a helyet');
      expect(chat.height, greaterThan(size.height * 0.4));
    });

    testWidgets('az adatsáv (támogatás gomb) a chat FÖLÖTT marad minden módban', (tester) async {
      for (final size in [phonePortrait, phoneLandscape, tabletPortrait]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(frame(size));
        await tester.pumpAndSettle();

        final info = tester.getRect(find.byKey(const Key('teszt-info')));
        final video = tester.getRect(find.byKey(const Key('twitch-video-area')));
        expect(info.top, greaterThanOrEqualTo(video.bottom - 0.01),
            reason: '$size: az adatsáv a videó alatt van');
        // A chat vagy alatta (stacked), vagy mellette (sideBySide) — de soha nem
        // fedésben az adatsávval.
        final chatFinder = find.byKey(const Key('twitch-stacked-chat'));
        if (chatFinder.evaluate().isNotEmpty) {
          expect(tester.getRect(chatFinder).top, greaterThanOrEqualTo(info.bottom - 0.01),
              reason: '$size: a chat az adatsáv alatt van');
        }
      }
    });
  });

  group('FORRÁS-LINT: a képernyő a vázat használja', () {
    test('a Twitch-oldal nem épít saját függőleges elrendezést', () {
      final screen = File('lib/screens/twitch/twitch_screen.dart').readAsStringSync();
      expect(screen.contains('TwitchLayoutFrame('), isTrue);
      expect(screen.contains('video:'), isTrue);
      expect(screen.contains('info: _infoColumn(context, status)'), isTrue);
      expect(screen.contains('chat: const TwitchStreamChat()'), isTrue);
      // A régi hiba: a videó `AspectRatio`-ja a `Column`-ban, cap nélkül. Az
      // egyetlen megengedett 16:9 a **PiP-ágban** van (ott nincs váza, a kis
      // ablakban a videó tölti ki a helyet) — a normál nézetet a váza méretezi.
      final aspectCount = 'aspectRatio: 16 / 9'.allMatches(screen).length;
      expect(aspectCount, 1,
          reason: 'a 16:9 csak a PiP-ágban lehet, a normál nézetet a váza adja');
      final pipBranch = RegExp(r'if \(inPictureInPicture\) \{([\s\S]*?)\n        \}')
          .firstMatch(screen)
          ?.group(1);
      expect(pipBranch, isNotNull);
      expect(pipBranch!.contains('aspectRatio: 16 / 9'), isTrue,
          reason: 'a PiP-ágban a videó 16:9-ben legyen');
    });

    test('a váza a tiszta döntést használja (nem saját küszöböt)', () {
      final frame = File('lib/screens/twitch/twitch_layout.dart').readAsStringSync();
      expect(frame.contains('twitchLayoutModeFor(size)'), isTrue);
      expect(frame.contains('twitchStackedVideoHeight(size)'), isTrue);
      expect(frame.contains('twitchSideChatWidth(size)'), isTrue);
      expect(frame.contains('TwitchLayoutMode.sideBySide'), isTrue);
    });
  });
}
