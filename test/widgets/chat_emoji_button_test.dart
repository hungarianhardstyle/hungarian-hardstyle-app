import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hungarian_hardstyle_app/widgets/chat_emoji_button.dart';

/// **A közösségi chat emoji-gombja — iOS-en.**
///
/// A tulajdonos jelzése (2026-09-22, iPhone): *„Androidon van emote a billen,
/// iPhone-on nincs, a chaten sztem kéne egy iPhone-specifikus emote a chatre, ami
/// csak iOS-en látszik."*
///
/// A gyökér **platform-különbség, nem hiba**: Androidon a rendszerbillentyűzeten
/// van emoji-kulcs, iOS-en az alfabetikus billentyűzeten nincs. Ezért a közösségi
/// chatben iOS-en adunk gombot, Androidon nem.
///
/// ⚠️ A tulajdonos kérése: a **privát chathez nem nyúlunk** — ezért ez a teszt
/// azt is őrzi, hogy ott nem jelent meg ez a widget (megvan a sajátja).
void main() {
  group('a lathatosag tiszta szabalya', () {
    test('iOS-en LATSZIK', () {
      expect(showsChatEmojiButton(TargetPlatform.iOS), isTrue);
    });

    test('Androidon NEM latszik (a rendszerbillentyuzeten van emoji-kulcs)', () {
      expect(showsChatEmojiButton(TargetPlatform.android), isFalse);
    });

    test('mas platformon sem latszik', () {
      for (final platform in const [
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux,
      ]) {
        expect(showsChatEmojiButton(platform), isFalse, reason: '$platform');
      }
    });
  });

  group('a beszuras a kurzor helyere tortenik', () {
    test('a kurzor helyere szur, es a kurzort moge teszi', () {
      final controller = TextEditingController(text: 'Szia vilag');
      controller.selection = const TextSelection.collapsed(offset: 4);
      insertChatEmoji(controller, '🔥');
      expect(controller.text, 'Szia🔥 vilag');
      expect(controller.selection.baseOffset, 'Szia🔥'.length);
    });

    test('a KIJELOLEST lecsereli (nem duplikal)', () {
      final controller = TextEditingController(text: 'Szia vilag');
      controller.selection = const TextSelection(baseOffset: 5, extentOffset: 10);
      insertChatEmoji(controller, '🙂');
      expect(controller.text, 'Szia 🙂');
    });

    test('ervenytelen kurzornal a vegere szur (nem dob)', () {
      // ⚠️ Új mezőnél a `selection` lehet -1/-1 — ilyenkor a végére kerül,
      // különben a beszúrás kivételt dobna.
      final controller = TextEditingController(text: 'Szia');
      controller.selection = const TextSelection.collapsed(offset: -1);
      insertChatEmoji(controller, '🎉');
      expect(controller.text, 'Szia🎉');
    });

    test('ures mezobe is be lehet szurni', () {
      final controller = TextEditingController();
      insertChatEmoji(controller, '😂');
      expect(controller.text, '😂');
    });
  });

  group('a widget valodi megjelenese (platformonkent)', () {
    Future<void> pumpButton(WidgetTester tester, TargetPlatform platform) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                // ⚠️ A platformot PARAMÉTERKÉNT adjuk át: a
                // `debugDefaultTargetPlatformOverride` a keretrendszer
                // debug-változója, és a teszt záró invariáns-ellenőrzése elhasal
                // tőle („The value of a foundation debug variable was changed").
                ChatEmojiButton(controller: controller, platform: platform),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('iOS-en megjelenik, es a valaszto kinyilik', (tester) async {
      await pumpButton(tester, TargetPlatform.iOS);
      expect(find.byIcon(Icons.emoji_emotions_outlined), findsOneWidget);

      // A választó tényleg kinyílik, és a koppintás be is szúrja az emojit.
      await tester.tap(find.byIcon(Icons.emoji_emotions_outlined));
      await tester.pumpAndSettle();
      expect(find.byType(GridView), findsOneWidget);
      final firstEmoji = find.text(chatEmojiChoices.first);
      expect(firstEmoji, findsOneWidget);
      await tester.tap(firstEmoji);
      await tester.pumpAndSettle();
      expect(find.byType(GridView), findsNothing,
          reason: 'a választó koppintásra bezárul');
    });

    testWidgets('Androidon SEMMIT nem rajzol (nincs foglalt hely)', (tester) async {
      await pumpButton(tester, TargetPlatform.android);
      expect(find.byIcon(Icons.emoji_emotions_outlined), findsNothing);
    });
  });

  group('forras-lint: a bekotes es a privat chat erintetlensege', () {
    test('a kozossegi chat beviteli savja hasznalja a gombot', () {
      final chat = _read('lib/screens/community/community_screen.dart');
      expect(chat, contains("import '../../widgets/chat_emoji_button.dart';"));
      expect(chat, contains('ChatEmojiButton(controller: controller, focusNode: focusNode)'),
          reason: 'a beviteli sávban, a Küldés mellett legyen');
    });

    test('a PRIVAT chat VALTOZATLAN (a tulajdonos keresere nem nyultunk hozza)', () {
      final priv = _read('lib/screens/community/private_messages_screen.dart');
      expect(priv.contains('ChatEmojiButton'), isFalse,
          reason: 'a privát chatnek saját választója van — ne keveredjen ide');
      expect(priv.contains('chat_emoji_button.dart'), isFalse);
      // ...és a sajátja megvan (nem tűnt el semmi).
      expect(priv, contains('_privateMessageEmojis'));
      expect(priv, contains('_showEmojiPicker'));
      expect(priv, contains('void _insertEmoji('));
    });
  });
}

String _read(String path) =>
    File(path).readAsStringSync().replaceAll('\r\n', '\n');
