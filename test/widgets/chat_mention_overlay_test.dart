import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/services/chat_mention_plan.dart';
import 'package:hungarian_hardstyle_app/widgets/chat_mention_overlay.dart';

/// A `@`javaslatlista megjelenítése (widget-teszt).
///
/// A tulajdonos kérése: *„Elkezdem irni a betűket és dobja fel a
/// lehetőségeket."* A lista maga **buta**: nem kér le semmit, csak kirajzolja a
/// kapott találatokat — ezért itt mérhető, hogy mit mutat, és hogy **üresen
/// semmit** (nem hagy üres sávot a beviteli mező fölött).
void main() {
  Widget wrap(Widget child) => MaterialApp(
    home: Scaffold(body: Column(children: [child])),
  );

  /// Álló telefon (360×800 logikai pont): a valódi felhasználás képe, és itt a
  /// lista teljes magassága (224) érvényes — a fekvő keret külön tesztet kap.
  Future<void> pumpPortrait(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(wrap(child));
  }

  const user = MentionSuggestion(
    type: mentionTypeUser,
    id: 'uid-1',
    label: 'Kobakologia',
    subtitle: 'HUHS #1234',
  );
  const event = MentionSuggestion(
    type: mentionTypeEvent,
    id: '12505',
    label: 'Hard Base Classic',
    subtitle: '2026.10.17. · Budapest',
  );

  group('ChatMentionOverlay', () {
    testWidgets('üres listánál semmit nem rajzol', (tester) async {
      await pumpPortrait(
        tester,
        ChatMentionOverlay(
          suggestions: const <MentionSuggestion>[],
          onSelected: (_) {},
        ),
      );

      expect(find.byKey(const Key('chat-mention-overlay')), findsNothing);
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('a találatokat @-os címkével és csoportfejléccel rajzolja', (
      tester,
    ) async {
      await pumpPortrait(
        tester,
        ChatMentionOverlay(
          suggestions: const <MentionSuggestion>[user, event],
          onSelected: (_) {},
        ),
      );

      expect(find.byKey(const Key('chat-mention-overlay')), findsOneWidget);
      expect(find.text('Személyek'), findsOneWidget);
      expect(find.text('Események'), findsOneWidget);
      expect(find.text('@Kobakologia'), findsOneWidget);
      expect(find.text('HUHS #1234'), findsOneWidget);
      expect(find.text('@Hard Base Classic'), findsOneWidget);
      expect(find.text('2026.10.17. · Budapest'), findsOneWidget);
    });

    testWidgets('a személyek csoportja elöl van', (tester) async {
      await pumpPortrait(
        tester,
        ChatMentionOverlay(
          suggestions: const <MentionSuggestion>[event, user],
          onSelected: (_) {},
        ),
      );

      final userY = tester.getTopLeft(find.text('Személyek')).dy;
      final eventY = tester.getTopLeft(find.text('Események')).dy;
      expect(userY, lessThan(eventY));
    });

    testWidgets('koppintásra a HELYES célpontot adja vissza', (tester) async {
      final tapped = <MentionSuggestion>[];
      await pumpPortrait(
        tester,
        ChatMentionOverlay(
          suggestions: const <MentionSuggestion>[user, event],
          onSelected: tapped.add,
        ),
      );

      await tester.tap(find.text('@Hard Base Classic'));
      await tester.pump();

      expect(tapped.length, 1);
      expect(tapped.single.type, mentionTypeEvent);
      expect(tapped.single.id, '12505');
      expect(tapped.single.toTarget().id, '12505');
    });

    testWidgets('ismeretlen típus is megjelenik (nem vész el a találat)', (
      tester,
    ) async {
      await pumpPortrait(
        tester,
        ChatMentionOverlay(
          suggestions: const <MentionSuggestion>[
            MentionSuggestion(type: 'release', id: '9', label: 'Valami'),
            MentionSuggestion(type: 'mystery', id: '1', label: 'Rejtély'),
          ],
          onSelected: (_) {},
        ),
      );

      // Az ismert típus magyar fejlécet kap…
      expect(find.text('Kiadványok'), findsOneWidget);
      // …az ismeretlen pedig a nyers típusnevet (nem tűnik el a találat).
      expect(find.text('mystery'), findsOneWidget);
      expect(find.text('@Valami'), findsOneWidget);
      expect(find.text('@Rejtély'), findsOneWidget);
    });

    testWidgets('fekvő módban is megjelenik (kisebb kerettel, nem lóg ki)', (
      tester,
    ) async {
      // A fekvő keret (132) szándékosan kisebb, ezért itt egy találatot
      // mérünk: a lista a szűk helyen is látszik és koppintható marad.
      final tapped = <MentionSuggestion>[];
      await tester.pumpWidget(
        wrap(
          ChatMentionOverlay(
            suggestions: const <MentionSuggestion>[user],
            onSelected: tapped.add,
          ),
        ),
      );

      expect(find.byKey(const Key('chat-mention-overlay')), findsOneWidget);
      expect(find.text('Személyek'), findsOneWidget);
      await tester.tap(find.text('@Kobakologia'));
      await tester.pump();
      expect(tapped.single.id, 'uid-1');
    });
  });
}
