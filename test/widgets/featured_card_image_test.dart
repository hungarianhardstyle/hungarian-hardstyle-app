import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/services/adaptive_card_layout.dart';
import 'package:hungarian_hardstyle_app/widgets/featured_news_card.dart';

/// **A főoldali kiemelt hír képe** — a tulajdonos jelzése (2026-11-05):
/// *„mondjuk az app főoldalon is fura”*.
///
/// A mért gyökér: a kártya álló telefonon **358×250 px**, a képsáv ebből
/// `flex: 5/12` = **149×250 px** — vagyis ÁLLÓ. Egy 1200×630-as (1,90)
/// borítóképből `BoxFit.cover`-rel csak **31%** látszott: az arcok óriásira
/// nagyítva, a fejek levágva.
///
/// Ez a mérés két dolgot bizonyít:
///  1. a **geometriát** (tiszta függvény: 31% → 100%);
///  2. a **szerkezetet** (a sávban elmosott háttér fölött a kép TELJES
///     egészében, `contain`-nal látszik) — vagyis a javítás tényleg benne van a
///     felépítésben, nem csak a dokumentációban.
void main() {
  group('a borítókép látható hányada (cover)', () {
    const imageAspect = 1200 / 630; // a legutóbbi cikk borítóképe: 1,90

    test('a RÉGI sáv (149×250) csak ~31%-ot mutatott', () {
      final fraction = coverVisibleFraction(
        boxWidth: 149,
        boxHeight: 250,
        imageAspectRatio: imageAspect,
      );
      expect(fraction, closeTo(0.313, 0.01));
    });

    test('16:9-es sávban ugyanez ~93% lenne (a contain ehhez képest is jobb)',
        () {
      final fraction = coverVisibleFraction(
        boxWidth: 149,
        boxHeight: 149 * 9 / 16,
        imageAspectRatio: imageAspect,
      );
      expect(fraction, closeTo(0.933, 0.01));
    });

    test('ha a doboz szélesebb a képnél, nincs vízszintes vágás', () {
      expect(
        coverVisibleFraction(
          boxWidth: 400,
          boxHeight: 100,
          imageAspectRatio: imageAspect,
        ),
        1,
      );
    });

    test('hibás bemenetre nulla (nem tippel)', () {
      expect(
        coverVisibleFraction(
          boxWidth: 0,
          boxHeight: 250,
          imageAspectRatio: imageAspect,
        ),
        0,
      );
    });
  });

  group('a képsáv felépítése', () {
    testWidgets('elmosott háttér fölött a kép TELJES egészében (contain)', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(
            width: 149,
            height: 250,
            child: FeaturedNewsImageBand(
              url: 'https://hungarianhardstyle.hu/wp-content/uploads/a.jpg',
              physicalWidth: 500,
            ),
          ),
        ),
      );
      await tester.pump();

      // 1) van elmosott háttér (a `ImageFiltered` hozza a blur-t)
      expect(find.byType(ImageFiltered), findsOneWidget);
      expect(
        tester.widget<ImageFiltered>(find.byType(ImageFiltered)).imageFilter,
        isA<ui.ImageFilter>(),
      );

      // 2) KÉT kép van: elmosott háttér (cover) + éles kép (contain)
      final images = tester
          .widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage))
          .toList();
      expect(images.length, 2);
      expect(images.first.fit, BoxFit.cover); // háttér
      expect(images.last.fit, BoxFit.contain); // éles kép — nincs vágás
      expect(images.last.alignment, Alignment.topCenter);

      // 3) az éles kép a háttér FÖLÖTT van (a Stack utolsó gyereke)
      final stack = tester.widget<Stack>(find.byType(Stack).first);
      expect(stack.children.length, 3);
      expect(stack.children.last, isA<Align>());

      // 4) a sötétítő réteg is ott van (a kép nem „villog")
      expect(stack.children[1], isA<ColoredBox>());
    });
  });
}
