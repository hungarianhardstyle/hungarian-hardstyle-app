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
      // Három hely: a beszélgetés és az „Új privát üzenet" fejléce, VALAMINT a
      // beszélgetés beviteli sávja (a Küldés mellett).
      // ⚠️ Az import `keyboard_dismiss_button.dart` (snake_case), ezért az NEM
      // számolódik bele — pontosan 3 valódi felhasználás van.
      expect(
        'KeyboardDismissButton('.allMatches(priv).length,
        3,
        reason: 'a két fejléc ÉS a beviteli sáv is kapja meg; ha ez 1-2, akkor '
            'valamelyik hely kimaradt',
      );
      expect(
        'ScrollViewKeyboardDismissBehavior.onDrag'.allMatches(priv).length,
        greaterThanOrEqualTo(2),
        reason: 'a beszélgetés- és a keresőlista is húzásra rejtsen',
      );
    });

    test('a gomb a BEVITELI SÁVBAN is ott van, nem csak a fejlécben', () {
      // ⚠️ MÉRT TANULSÁG (2026-09-22): a gomb be volt kötve a fejlécbe, a
      // widget-teszt igazolta is, hogy megjelenik — a tulajdonos mégis azt
      // jelentette, hogy „nincs". Az ok **nem hiba, hanem hely**: írás közben a
      // beviteli sávra nézünk, nem a képernyő tetejére. Ezért ugyanaz a widget a
      // Küldés mellett is ott van (zárva magától eltűnik).
      final chat = _read('lib/screens/community/community_screen.dart');
      final priv = _read('lib/screens/community/private_messages_screen.dart');

      // A közösségi Chat beviteli sávja: `Spacer()` után, a sor jobb szélén.
      expect(chat, contains('const Spacer(),\n                const KeyboardDismissButton(),'),
          reason: 'a közösségi Chat beviteli sávjában is ott kell lennie');
      expect('KeyboardDismissButton('.allMatches(chat).length, 2,
          reason: 'fejléc + beviteli sáv');

      // A privát chat beviteli sávja: közvetlenül a Küldés előtt.
      final sendIndex = priv.indexOf('onPressed: _sending ? null : _send,');
      final keyboardIndex = priv.lastIndexOf('const KeyboardDismissButton(),');
      expect(keyboardIndex, greaterThan(0));
      expect(keyboardIndex, lessThan(sendIndex),
          reason: 'a gomb a Küldés mellett legyen, ne máshol a fájlban');
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
