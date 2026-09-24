import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/widgets/prize_reward_details.dart';

/// A nyeremény részletei (típus + leírás) a **nyereményjáték képernyőn**.
///
/// **A tulajdonos jelzése:** *„a nyereményjátékba nem kerül bele a játék
/// leírása"*. A gyökér kettős volt: a WordPress a nyitott játéknál üresen
/// küldte a mezőket, és az app a **nyitott** nézetben egyáltalán nem rajzolta
/// ki őket. Ez a fájl a megjelenítést méri, és a forrás-lint azt őrzi, hogy a
/// **mindkét** nézet ugyanazt a widgetet használja.
void main() {
  Widget wrap(Widget child) => MaterialApp(
    home: Scaffold(body: Column(children: [child])),
  );

  group('PrizeRewardDetails', () {
    testWidgets('kiírja a nyeremény típusát és a leírását', (tester) async {
      await tester.pumpWidget(
        wrap(
          const PrizeRewardDetails(
            prizeType: 'Vinyl',
            prizeDescription: 'Aláírt 12" vinyl, a nyertesnek postázva.',
          ),
        ),
      );

      expect(find.text('Nyeremény: Vinyl'), findsOneWidget);
      expect(
        find.text('Aláírt 12" vinyl, a nyertesnek postázva.'),
        findsOneWidget,
      );
    });

    testWidgets('típus nélkül is megjelenik a leírás', (tester) async {
      await tester.pumpWidget(
        wrap(
          const PrizeRewardDetails(prizeType: '', prizeDescription: 'Póló M-es méretben.'),
        ),
      );

      expect(find.text('Póló M-es méretben.'), findsOneWidget);
      expect(find.textContaining('Nyeremény:'), findsNothing);
    });

    testWidgets('ha nincs kitöltve semmi, egyáltalán nem rajzol (nincs üres elválasztó)', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(const PrizeRewardDetails(prizeType: '', prizeDescription: '')),
      );

      expect(find.byType(Divider), findsNothing);
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('a whitespace-t nem tekinti tartalomnak', (tester) async {
      await tester.pumpWidget(
        wrap(const PrizeRewardDetails(prizeType: '   ', prizeDescription: '\n ')),
      );

      expect(find.byType(Divider), findsNothing);
    });
  });

  group('forrás-lint: a nyeremény leírása a játék ALATT is látszik', () {
    late String screen;

    setUpAll(() {
      screen = File('lib/screens/prize/prize_screen.dart')
          .readAsStringSync()
          .replaceAll('\r\n', '\n');
    });

    test('a nyitott nézet (NYEREMÉNYJÁTÉK) is kirajzolja a részleteket', () {
      final openStart = screen.indexOf("_buildHeader('NYEREMÉNYJÁTÉK'");
      final drawnStart = screen.indexOf("_buildHeader('NYERTES'");
      expect(openStart, greaterThan(0), reason: 'megvan a nyitott nézet');
      expect(drawnStart, greaterThan(openStart));

      final openSection = screen.substring(openStart, drawnStart);
      expect(
        openSection,
        contains('PrizeRewardDetails('),
        reason: 'a játék alatt is látszania kell a nyereménynek',
      );
      expect(
        openSection,
        contains('prize.prizeDescription'),
        reason: 'a leírás megy át a widgetnek',
      );
    });

    test('a nyertes-nézet UGYANAZT a widgetet használja (nem másolódik)', () {
      expect(screen, contains('PrizeRewardDetails('));
      expect(
        screen,
        isNot(contains("'Nyeremény: ")),
        reason: 'a szöveg egy helyen él, a widgetben',
      );
    });
  });
}
