import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/services/chat_mention_plan.dart';
import 'package:hungarian_hardstyle_app/widgets/chat_message_text.dart';

/// A Chat-üzenet **kattintható** `@`hivatkozásai (widget-teszt).
///
/// A tulajdonos kérése: *„Természetesen mindegyik kattintható legyen és a
/// megfelelő helyre vigyen."* A szövegbeli megkeresés a tiszta
/// `mentionSpans`-ben van; ez a fájl azt méri, hogy a **koppintás tényleg a
/// helyes célpontot** adja át a hívónak — és hogy hivatkozás nélkül a szöveg
/// pontosan a korábbi, egyszerű megjelenítés marad.
void main() {
  Widget wrap(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );

  const kobakologia = ChatMentionTarget(
    type: mentionTypeUser,
    id: 'uid-1',
    label: 'Kobakologia',
  );
  const hardBase = ChatMentionTarget(
    type: mentionTypeEvent,
    id: '12505',
    label: 'Hard Base Classic',
  );

  group('ChatMessageText', () {
    testWidgets('hivatkozás nélkül bitre a régi, egyszerű szöveg', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const ChatMessageText(
            text: 'Szia, mizu?',
            mentions: <ChatMentionTarget>[],
            onTap: _ignore,
          ),
        ),
      );

      final widget = tester.widget<Text>(find.byType(Text));
      expect(widget.data, 'Szia, mizu?');
      expect(
        widget.textSpan,
        isNull,
        reason: 'nincs Text.rich, nincs felismerő — ugyanaz, mint eddig',
      );
    });

    testWidgets('a hivatkozás aláhúzott és felismerőt kap', (tester) async {
      await tester.pumpWidget(
        wrap(
          const ChatMessageText(
            text: 'Szia @Kobakologia, ez jó!',
            mentions: <ChatMentionTarget>[kobakologia],
            onTap: _ignore,
          ),
        ),
      );

      final span = tester.widget<Text>(find.byType(Text)).textSpan! as TextSpan;
      final link = span.children!
          .whereType<TextSpan>()
          .firstWhere((child) => child.text == '@Kobakologia');
      expect(link.style?.decoration, TextDecoration.underline);
      expect(
        link.recognizer,
        isA<TapGestureRecognizer>(),
        reason: 'ennek kell a koppintást elkapnia',
      );
    });

    testWidgets('a hivatkozásra koppintva a HELYES célpontot adja', (
      tester,
    ) async {
      final tapped = <ChatMentionTarget>[];
      await tester.pumpWidget(
        wrap(
          ChatMessageText(
            text: 'Szia @Kobakologia, ott leszel a @Hard Base Classic-on?',
            mentions: const <ChatMentionTarget>[kobakologia, hardBase],
            onTap: tapped.add,
          ),
        ),
      );

      await tester.tapOnText(
        find.textRange.ofSubstring('@Hard Base Classic'),
      );
      await tester.pump();

      expect(tapped.length, 1);
      expect(tapped.single.type, mentionTypeEvent);
      expect(tapped.single.id, '12505');
    });

    testWidgets('a hivatkozáson KÍVÜLI szöveg koppintása nem csinál semmit', (
      tester,
    ) async {
      final tapped = <ChatMentionTarget>[];
      await tester.pumpWidget(
        wrap(
          ChatMessageText(
            text: 'Szia @Kobakologia!',
            mentions: const <ChatMentionTarget>[kobakologia],
            onTap: tapped.add,
          ),
        ),
      );

      await tester.tapOnText(find.textRange.ofSubstring('Szia'));
      await tester.pump();

      expect(tapped, isEmpty);
    });

    testWidgets('a visszatörölt @név nem lesz kattintható (a szöveg az úr)', (
      tester,
    ) async {
      final tapped = <ChatMentionTarget>[];
      await tester.pumpWidget(
        wrap(
          ChatMessageText(
            // A célpont a listában van, de a szövegben MÁR nincs benne.
            text: 'Szia, mizu?',
            mentions: const <ChatMentionTarget>[kobakologia],
            onTap: tapped.add,
          ),
        ),
      );

      final widget = tester.widget<Text>(find.byType(Text));
      expect(
        widget.textSpan,
        isNull,
        reason: 'a mentionSpans nem talál semmit, ezért sima szöveg jön',
      );
      expect(tapped, isEmpty);
    });

    testWidgets('a widget eldobása nem dob (a felismerők bezáródnak)', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const ChatMessageText(
            text: 'Szia @Kobakologia!',
            mentions: <ChatMentionTarget>[kobakologia],
            onTap: _ignore,
          ),
        ),
      );
      await tester.pumpWidget(wrap(const SizedBox.shrink()));
      await tester.pumpAndSettle();

      expect(find.byType(ChatMessageText), findsNothing);
      expect(tester.takeException(), isNull);
    });

    // ⚠️ A tulajdonos kérése (2026-09-25): *„kéne egy @mindenki tag is … csak
    // moderátor/admin használhassa"*. A `@mindenki` **kiemelve látszik** (hogy
    // látszódjon: mindenkit megszólított), de **nem kattintható** — nincs mögötte
    // adatlap, ezért nem szabad „nem elérhető" hibát mutatnia.
    testWidgets('a @mindenki kiemelt, de NEM kattintható', (tester) async {
      final tapped = <ChatMentionTarget>[];
      await tester.pumpWidget(
        wrap(
          ChatMessageText(
            text: 'Figyelem @mindenki, ma este buli!',
            mentions: const <ChatMentionTarget>[
              ChatMentionTarget(
                type: mentionTypeEveryone,
                id: mentionEveryoneId,
                label: mentionEveryoneLabel,
              ),
            ],
            onTap: tapped.add,
          ),
        ),
      );

      final span = tester.widget<Text>(find.byType(Text)).textSpan! as TextSpan;
      final mention = span.children!
          .whereType<TextSpan>()
          .firstWhere((child) => child.text == '@mindenki');
      expect(mention.style?.decoration, TextDecoration.underline);
      expect(
        mention.recognizer,
        isNull,
        reason: 'a @mindenki nem visz sehova, ezért nincs felismerője',
      );

      await tester.tapOnText(find.textRange.ofSubstring('@mindenki'));
      await tester.pump();
      expect(tapped, isEmpty, reason: 'a koppintás nem ad célpontot a hívónak');
      expect(tester.takeException(), isNull);
    });

    testWidgets('a @mindenki mellett a személy továbbra is kattintható', (
      tester,
    ) async {
      final tapped = <ChatMentionTarget>[];
      await tester.pumpWidget(
        wrap(
          ChatMessageText(
            text: '@mindenki és @Kobakologia figyeljetek!',
            mentions: const <ChatMentionTarget>[
              ChatMentionTarget(
                type: mentionTypeEveryone,
                id: mentionEveryoneId,
                label: mentionEveryoneLabel,
              ),
              kobakologia,
            ],
            onTap: tapped.add,
          ),
        ),
      );

      await tester.tapOnText(find.textRange.ofSubstring('@Kobakologia'));
      await tester.pump();

      expect(tapped.single.type, mentionTypeUser);
      expect(tapped.single.id, 'uid-1');
    });
  });
}

void _ignore(ChatMentionTarget target) {}
