import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// **A billentyűzet bezárása a chatokban — iOS-en.**
///
/// A tulajdonos jelzése (2026-09-22, iPhone, a telepített iOS-buildben):
/// *„chatre kéne, mert nem zárja be a billt ha írok"*, majd *„privát chat dettó"*.
///
/// A gyökér **platform-különbség**, nem hiba a komponáló sávban: Androidon a
/// rendszer vissza-gombja bezárja a billentyűzetet, és a Chat ezt kifejezetten
/// kezeli is (`PopScope` + `canPop: !keyboardVisible`) — **iOS-en viszont nincs
/// ilyen gomb**, ezért ott a billentyűzet beragadt, és elfogta a felületet.
///
/// A megoldás **egy helyen** van (`KeyboardDismissButton`), és két rétegből áll:
/// a fejléc gombja (csak nyitott billentyűzetnél látszik) **és** a lista
/// húzásra (`keyboardDismissBehavior: onDrag`) — így nem csak egy úton lehet
/// megszabadulni tőle.
void main() {
  group('a billentyűzet-elrejtő gomb (keyboard_dismiss_button.dart)', () {
    late String widget;

    setUpAll(() {
      widget = _read('lib/widgets/keyboard_dismiss_button.dart');
    });

    test('van EGY közös widget, és a billentyűzet állapotára figyel', () {
      expect(widget, contains('class KeyboardDismissButton'));
      expect(
        widget,
        contains('MediaQuery.viewInsetsOf(context).bottom > 0'),
        reason: 'ettől a függőségtől épül újra, amikor a billentyűzet mozog',
      );
      expect(
        widget,
        contains('unfocus()'),
        reason: 'a gombnak el kell engednie a fókuszt',
      );
    });

    test('csak nyitott billentyűzetnél foglal helyet', () {
      expect(
        widget,
        contains('if (!keyboardVisible) return const SizedBox.shrink();'),
        reason: 'zárt billentyűzetnél nem lehet látható/kitöltő elem',
      );
    });
  });

  group('a chatok be van kötve (mindkét helyen)', () {
    test('a közösségi Chat fejlécében ott a gomb', () {
      final chat = _read('lib/screens/community/community_screen.dart');
      expect(chat, contains("import '../../widgets/keyboard_dismiss_button.dart';"));
      expect(chat, contains('const KeyboardDismissButton(),'));
    });

    test('a közösségi Chat listája húzásra is elrejti a billentyűzetet', () {
      final chat = _read('lib/screens/community/community_screen.dart');
      expect(
        chat,
        contains('keyboardDismissBehavior'),
        reason: 'iOS-en a húzás a megszokott gesztus',
      );
      expect(
        chat,
        contains('ScrollViewKeyboardDismissBehavior.onDrag'),
      );
    });

    test('a PRIVÁT chat (beszélgetés + új üzenet) is megkapta mindkettőt', () {
      final priv = _read('lib/screens/community/private_messages_screen.dart');
      expect(
        priv,
        contains("import '../../widgets/keyboard_dismiss_button.dart';"),
      );
      // Két fejléc: a beszélgetés és az „Új privát üzenet" képernyő.
      // ⚠️ Az import `keyboard_dismiss_button.dart` (snake_case), ezért az NEM
      // számolódik bele — pontosan 2 valódi felhasználás van.
      expect(
        'KeyboardDismissButton('.allMatches(priv).length,
        2,
        reason: 'a beszélgetés és az „Új privát üzenet" fejléce is kapja meg; '
            'ha ez 1, akkor valamelyik privát képernyő kimaradt',
      );
      expect(
        'ScrollViewKeyboardDismissBehavior.onDrag'.allMatches(priv).length,
        greaterThanOrEqualTo(2),
        reason: 'a beszélgetés- és a keresőlista is húzásra rejtsen',
      );
    });

    test('az Android-út (PopScope) érintetlen maradt', () {
      final chat = _read('lib/screens/community/community_screen.dart');
      expect(
        chat,
        contains('canPop: !keyboardVisible'),
        reason: 'Androidon a vissza-gomb továbbra is a billentyűzetet zárja be, '
            'és csak utána lép ki — ezt nem szabad elveszíteni',
      );
    });
  });
}

String _read(String path) =>
    File(path).readAsStringSync().replaceAll('\r\n', '\n');
