import 'package:flutter/material.dart';

/// **Billentyűzet-elrejtő gomb a fejlécben és a beviteli sávban.**
///
/// MIÉRT KELL (a tulajdonos jelzése, 2026-09-22, iPhone):
/// *„chatre kéne, mert nem zárja be a billt ha írok"*, majd *„privát chat dettó"*.
///
/// A gyökér **platform-különbség**: Androidon a rendszer vissza-gombja bezárja a
/// billentyűzetet — a Chat ezt kifejezetten kezeli is (`PopScope` +
/// `canPop: !keyboardVisible` a `community_screen.dart`-ban) —, **iOS-en viszont
/// nincs ilyen gomb**, ott a billentyűzet csak akkor tűnik el, ha a felhasználó
/// máshova koppint. Így iPhone-on a komponáló sáv alatt **beragadt** a billentyűzet.
///
/// A gomb **csak akkor látszik, amikor a billentyűzet nyitva van** — így nem
/// foglal helyet feleslegesen, és pontosan akkor van ott, amikor kell.
///
/// ⚠️ **A nyers platform-értéket olvassuk, NEM a `MediaQuery`-t.**
///
/// MÉRT GYÖKÉR (2026-09-22, a tulajdonos jelzése: *„billentyűzet-elrejtő, na az
/// nincs most se, nyitva, nézd meg"* — és igaza volt): az app képernyői
/// **egymásba ágyazott Scaffoldokban** élnek (`main_navigation.dart` külső
/// Scaffold → a Chat belső Scaffoldja). A külső Scaffold a saját `body`-jából
/// **lenullázza** a `viewInsets`-t (ez a `resizeToAvoidBottomInset` dokumentált
/// viselkedése), ezért a belső képernyőn a `MediaQuery.viewInsetsOf(context).bottom`
/// **mindig 0** volt — a gomb **soha** nem jelent meg, akármilyen helyesen is volt
/// bekötve.
///
/// A `View.of(context).viewInsets` a **platformtól** jön, és a Scaffold nem nyúl
/// hozzá — így a beágyazás nem tudja elrontani. (Fizikai pixelben van, de nekünk
/// csak a „> 0" kérdés számít.)
///
/// ⚠️ **A tanulság a tesztelésről:** az első widget-tesztem **egyetlen**
/// Scaffolddal mérte a láthatóságot, ezért **zöld** volt, miközben az éles appban
/// a gomb nem jelent meg. A `keyboard_dismiss_visibility_test.dart` ezért
/// **beágyazott** Scaffolddal méri — pontosan azt az esetet, ami elhasalt.
class KeyboardDismissButton extends StatelessWidget {
  const KeyboardDismissButton({super.key, this.keyboardVisible});

  /// ⚠️ Csak **teszteléshez**: ha `null`, a nyers platform-érték dönt.
  final bool? keyboardVisible;

  @override
  Widget build(BuildContext context) {
    final visible = keyboardVisible ?? View.of(context).viewInsets.bottom > 0;
    if (!visible) return const SizedBox.shrink();

    return IconButton(
      tooltip: 'Billentyűzet elrejtése',
      icon: const Icon(Icons.keyboard_hide_rounded),
      onPressed: () => FocusManager.instance.primaryFocus?.unfocus(),
    );
  }
}
