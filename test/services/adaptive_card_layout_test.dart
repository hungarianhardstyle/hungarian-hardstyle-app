import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/models/post.dart';
import 'package:hungarian_hardstyle_app/services/adaptive_card_layout.dart';
import 'package:hungarian_hardstyle_app/services/twitch_live.dart';
import 'package:hungarian_hardstyle_app/widgets/news_card.dart';

/// **Széles nézet (fekvő telefon, tablet): a kártyák ne nőjenek óriásira.**
///
/// A tulajdonos jelzése (2026-10-03): *„Fekvő módban és tableten fekvő módban a
/// friss hírek kártya és a twitch beharangozó túl nagy. Álló módban jó!”*
///
/// A mért gyökér: a kártyák 16:9-es képe a **teljes szélességhez** igazodott, és a
/// régi szabály **csak a fekvő tájolást** nézte — a **tablet álló** nézete
/// kimaradt, ezért ott is óriási maradt. A döntés mostantól a **szélesség**, egy
/// helyen (`lib/services/adaptive_card_layout.dart`), és **mindkét** kártya azt
/// használja.
void main() {
  const phonePortrait = Size(412, 892);
  const phoneLandscape = Size(892, 412);
  const tabletPortrait = Size(800, 1280);
  const tabletLandscape = Size(1280, 800);

  group('tiszta döntés: széles-e az elrendezés', () {
    test('álló telefon: NEM széles (a kártya teljes szélességű marad)', () {
      expect(isWideCardLayout(phonePortrait), isFalse);
      expect(cardMaxWidthFor(phonePortrait), double.infinity);
    });

    test('fekvő telefon: széles, ezért a kártya legfeljebb 760 px', () {
      expect(isWideCardLayout(phoneLandscape), isTrue);
      expect(cardMaxWidthFor(phoneLandscape), wideCardMaxWidth);
      expect(wideCardMaxWidth, 760);
    });

    test('tablet ÁLLÓBAN is széles — ez maradt ki a régi szabályból', () {
      // A régi szabály `Orientation.landscape`-et nézett, ezért a 800 px széles
      // tablet álló nézetében a 16:9-es kép 450 px magas lett (az egész kártya).
      expect(isWideCardLayout(tabletPortrait), isTrue);
      expect(cardMaxWidthFor(tabletPortrait), wideCardMaxWidth);
      expect(isWideCardLayout(tabletLandscape), isTrue);
      expect(cardMaxWidthFor(tabletLandscape), wideCardMaxWidth);
    });

    test('a küszöb pontosan 700 px (alatta és felette mérve)', () {
      expect(isWideCardLayout(Size(wideLayoutMinWidth - 1, 2000)), isFalse);
      expect(isWideCardLayout(Size(wideLayoutMinWidth, 2000)), isTrue);
    });

    test('a MAGASSÁG-korlát a képernyő magasságából jön (állóban korlátlan)', () {
      // A tulajdonos jelzése: *„ájfónon a kiemelt hír és a twitch kártya a
      // főoldalon ugyanakkora mint eddig, fekvő nézetben”* — a **szélesség**
      // korlátja ezt nem fogja meg (667 < 760), ezért a magasságot is kötni kell.
      expect(wideCardMaxHeightFor(phoneLandscape), closeTo(412 * 0.55, 0.01));
      expect(wideCardMaxHeightFor(phonePortrait), double.infinity);
      expect(wideCardMaxHeightFor(tabletLandscape), closeTo(800 * 0.55, 0.01));
      // A tablet ÁLLÓ nézete is „széles” (a szélesség dönt), de ott a képernyő
      // magas, ezért a korlát nem szól bele a kártya méretébe.
      expect(wideCardMaxHeightFor(tabletPortrait), greaterThan(600));
    });
  });

  group('tiszta döntés: a főoldali KIEMELT HÍR mérete', () {
    test('fekvő iPhone (667×375): fele akkora, de nem apró', () {
      // Mért kiindulás (a javítás előtt): 354,9 px magas kártya egy 375 px magas
      // képernyőn — vagyis a teljes képernyő. Utána **mért** érték: 206,25.
      final card = heroCardSizeFor(
        viewport: const Size(667, 375),
        availableWidth: 631,
      );
      expect(card.height, closeTo(375 * 0.55, 0.01));
      expect(card.height, lessThan(375 * 0.60));
      expect(card.height, greaterThan(150), reason: 'ne legyen túl kicsi');
      expect(card.width, 631, reason: 'a szélességet ki kell használni');
    });

    test('fekvő telefon (892×412): a magasság-korlát dönt, nem a szélesség', () {
      final card = heroCardSizeFor(viewport: phoneLandscape, availableWidth: 856);
      expect(card.width, wideCardMaxWidth);
      expect(card.height, closeTo(412 * 0.55, 0.01));
      expect(card.height, lessThan(856 * 9 / 16),
          reason: 'a természetes 16:9 magasság elviszi a fél képernyőt');
    });

    test('álló iPhone: bitre a régi méret', () {
      final card = heroCardSizeFor(viewport: phonePortrait, availableWidth: 339);
      // A régi szabály: `width * 9 / 16` 250…460 között, 820-as szélesség-korláttal.
      expect(card.width, 339);
      expect(card.height, 250, reason: 'a közös legkisebb magasság (régi érték)');
      final old = (339 * 9 / 16).clamp(250.0, 460.0);
      expect(card.height, old);
    });

    test('tablet fekvő (1280×800): 760 széles, a természetes magasság a korlát alatt', () {
      final card = heroCardSizeFor(viewport: tabletLandscape, availableWidth: 1000);
      expect(card.width, wideCardMaxWidth);
      expect(card.height, closeTo(760 * 9 / 16, 0.01));
      expect(card.height, lessThan(800 * 0.55),
          reason: 'a 422 px-es korlát itt nem szól bele (a régi 460 helyett 427,5)');
    });

    test('tablet álló: a szélesség korlátozott, a magasság a természetes', () {
      final card = heroCardSizeFor(viewport: tabletPortrait, availableWidth: 764);
      expect(card.width, wideCardMaxWidth);
      expect(card.height, closeTo(760 * 9 / 16, 0.01));
    });
  });

  group('tiszta döntés: melyik kép megy a Twitch-kártyára', () {
    const preview =
        'https://static-cdn.jtvnw.net/previews-ttv/live_user_hungarianhardstyle-640x360.jpg';

    test('élő adásnál a MOZGÓ előnézet megy (a beharangozó kép helyett is)', () {
      // A tulajdonos kérése: *„ha elindul egy twitch stream, akkor a beharangozó
      // kép helyett mehetne a stream mozgóképe a főoldalon.”*
      final url = twitchCardImageUrl(
        isLive: true,
        liveThumbnailUrl: preview,
        overrideImageUrl: 'https://example.test/plakat.jpg',
        tick: 7,
      );
      expect(url, contains('previews-ttv'));
      expect(url, contains('tick=7'),
          reason: 'a frissítő paraméter nélkül befagyna a mozgó előnézet');
      expect(url.contains('plakat.jpg'), isFalse);
    });

    test('adás nélkül a beállított beharangozó kép marad (nem ürül ki)', () {
      final url = twitchCardImageUrl(
        isLive: false,
        liveThumbnailUrl: preview,
        overrideImageUrl: 'https://example.test/plakat.jpg',
        tick: 3,
      );
      expect(url, 'https://example.test/plakat.jpg');
    });

    test('ha nincs élő előnézet URL, a saját kép marad', () {
      final url = twitchCardImageUrl(
        isLive: true,
        liveThumbnailUrl: '   ',
        overrideImageUrl: 'https://example.test/plakat.jpg',
      );
      expect(url, 'https://example.test/plakat.jpg');
    });

    test('a meglévő query paraméterhez & kerül (nem ?)', () {
      final url = twitchCardImageUrl(
        isLive: true,
        liveThumbnailUrl: 'https://example.test/live.jpg?x=1',
        overrideImageUrl: '',
        tick: 2,
      );
      expect(url, 'https://example.test/live.jpg?x=1&tick=2');
    });

    test('kép nélkül üres marad (a kártya ilyenkor nem is látszik)', () {
      expect(
        twitchCardImageUrl(isLive: false, liveThumbnailUrl: '', overrideImageUrl: ''),
        isEmpty,
      );
    });
  });

  group('kirajzolva: a hírkártya szélessége széles nézetben', () {
    const post = Post(
      id: 4242,
      title: 'Fekvő nézet próba',
      excerpt: 'Rövid kivonat.',
      content: 'Tartalom.',
      imageUrl: '',
      date: '2026-10-03T10:00:00',
      link: 'https://hungarianhardstyle.hu/teszt',
      isSticky: false,
      categoryIds: <int>[],
      categories: <String>[],
      tags: <String>[],
      galleryId: 0,
      galleryImages: <GalleryImage>[],
      embeds: <PostEmbed>[],
      relatedPosts: <Post>[],
    );

    Future<Rect> render(WidgetTester tester, Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: SingleChildScrollView(child: AdaptiveNewsCard(post: post)),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      return tester.getRect(find.byType(NewsCard));
    }

    testWidgets('tablet állóban (800 px) legfeljebb 760 px széles', (tester) async {
      final card = await render(tester, tabletPortrait);
      expect(card.width, lessThanOrEqualTo(wideCardMaxWidth + 0.01),
          reason: 'a tablet álló nézete maradt ki a régi szabályból');
      expect(card.center.dx, closeTo(tabletPortrait.width / 2, 1),
          reason: 'a kártya középre igazítva maradjon');
      expect(find.byType(AspectRatio), findsNothing,
          reason: 'széles nézetben a sávos (kép balra, szöveg jobbra) kártya kell');
    });

    testWidgets('fekvő telefonon is korlátozott', (tester) async {
      final card = await render(tester, phoneLandscape);
      expect(card.width, lessThanOrEqualTo(wideCardMaxWidth + 0.01));
    });

    testWidgets('álló telefonon teljes szélességű marad (ez volt jó)', (tester) async {
      final card = await render(tester, phonePortrait);
      expect(card.width, greaterThan(phonePortrait.width - 40));
      expect(card.width, lessThanOrEqualTo(phonePortrait.width));
      // ⚠️ Nem elég a szélesség: a `ConstrainedBox` felső korlátja egy 412 px-es
      // telefonon akkor is „elfér”, ha a döntés tévesen szélesnek mondja a
      // nézetet — ilyenkor viszont a **sávos** (240 px-es képű) kártya jelenne
      // meg. Ezt méri a 16:9-es kép: az csak a nagy változatban van.
      expect(find.byType(AspectRatio), findsOneWidget,
          reason: 'álló telefonon a nagy (16:9) kártya kell, nem a sávos');
    });
  });

  group('FORRÁS-LINT: a kártyák ugyanazt a szabályt használják', () {
    late String news;
    late String twitch;

    setUpAll(() {
      // ⚠️ Sorvég-normalizálás: a fájlok egy része CRLF-fel van a lemezen.
      news = File('lib/widgets/news_card.dart').readAsStringSync().replaceAll('\r\n', '\n');
      twitch =
          File('lib/widgets/twitch_live_card.dart').readAsStringSync().replaceAll('\r\n', '\n');
    });

    test('a hírkártya a szélesség alapján dönt (nem a tájolás szerint)', () {
      expect(news, contains('cardMaxWidthFor(MediaQuery.sizeOf(context))'));
      expect(news, contains('maxWidth != double.infinity'),
          reason: 'széles nézetben a sávos (kép balra, szöveg jobbra) kártya kell');
      expect(news.contains('Orientation.landscape'), isFalse,
          reason: 'a tájolás-alapú döntés hagyta ki a tablet álló nézetét');
    });

    test('a Twitch-kártya is a közös szabályt és a tiszta képi döntést használja', () {
      expect(twitch, contains('final viewport = MediaQuery.sizeOf(context);'));
      expect(twitch, contains('cardMaxWidthFor(viewport)'));
      expect(twitch, contains('isWideCardLayout(viewport)'),
          reason: 'széles nézetben fekvő (kép balra) elrendezés kell');
      expect(twitch, contains('twitchCardImageUrl('),
          reason: 'a kép kiválasztása nem a tiszta döntésből jönne');
    });

    test('a főoldali kiemelt hír a közös méret-szabályból dolgozik', () {
      // ⚠️ Ez volt a mért hiba: a keringő a SAJÁT méretét adta (820 / 250…460),
      // ezért fekvő iPhone-on a kártya a teljes képernyőmagasságot elvitte.
      final home = File('lib/screens/home/home_screen.dart')
          .readAsStringSync()
          .replaceAll('\r\n', '\n');
      expect(home, contains('heroCardSizeFor('));
      expect(home, contains('viewport: viewport'),
          reason: 'a méret a képernyő méretéből döntsön');
      expect(home.contains('clamp(0.0, 820.0)'), isFalse,
          reason: 'a régi, saját szélesség-korlát visszahozná a hibát');
      expect(home.contains('clamp(250.0, 460.0)'), isFalse,
          reason: 'a régi, saját magasság-korlát visszahozná a hibát');
      // A széles (alacsony) nézetben kevesebb cím-sor kell, különben kifut.
      expect(home, contains('dense: wide'));
      final featured = File('lib/widgets/featured_news_card.dart')
          .readAsStringSync()
          .replaceAll('\r\n', '\n');
      expect(featured, contains('maxLines: dense ? 2 : 4'));
    });
  });
}
