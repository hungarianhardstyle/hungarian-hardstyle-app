import '../core/i18n/tr.dart';
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
/// máshova koppint.
///
/// A gomb **csak akkor látszik, amikor a billentyűzet nyitva van**.
///
/// ## ⚠️ KÉT CSAPDA, AMIT MÉRVE TALÁLTUNK (2026-09-22)
///
/// **1. A `MediaQuery` hazudik beágyazott Scaffoldban.** Az app képernyői
/// egymásba ágyazott Scaffoldokban élnek (`main_navigation.dart` külső Scaffold →
/// a Chat belső Scaffoldja). A külső Scaffold a saját `body`-jából **lenullázza**
/// a `viewInsets`-t (ez a `resizeToAvoidBottomInset` dokumentált viselkedése),
/// ezért a belső képernyőn a `MediaQuery.viewInsetsOf(context).bottom` **mindig 0**
/// — a gomb soha nem jelent meg, akármilyen helyesen volt bekötve. Ezért a
/// **nyers platform-értéket** olvassuk (`View.of(context).viewInsets`), amihez a
/// Scaffold nem nyúl. (Fizikai pixelben van, de csak a „> 0" kérdés számít.)
///
/// **2. A `View.of(context)` NEM értesít a változásról.** A Flutter saját
/// dokumentációja (`view.dart:150-151`) mondja ki: *„[MediaQuery.sizeOf], which
/// will ensure that the `context` is informed when the view properties change."*
/// Vagyis az első változat **egyszer** épült fel — zárt billentyűzettel —, és ott
/// is ragadt: a gomb akkor sem jelent meg, amikor a billentyűzet kinyílt
/// (a tulajdonos jelzése: *„most sem látszik"*). Ezért a metrika-változást külön
/// figyeljük (`WidgetsBindingObserver.didChangeMetrics`) — az a hívás **minden**
/// képernyő-metrika-változásnál megjön, így a billentyűzet nyitásakor/zárásakor
/// is.
class KeyboardDismissButton extends StatefulWidget {
  const KeyboardDismissButton({super.key, this.keyboardVisible});

  /// ⚠️ Csak **teszteléshez**: ha `null`, a nyers platform-érték dönt.
  final bool? keyboardVisible;

  @override
  State<KeyboardDismissButton> createState() => _KeyboardDismissButtonState();
}

class _KeyboardDismissButtonState extends State<KeyboardDismissButton>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    // ⚠️ EZ KELL AHHOZ, HOGY A GOMB MEGJELENJEN: a `View.of(context)` önmagában
    // nem hoz létre függőséget, ezért a billentyűzet kinyílása nem építené újra
    // a widgetet (lásd a fenti 2. pontot).
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    // Bármi változik a képernyő-metrikákban (billentyűzet, elforgatás), újraépítünk.
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final visible =
        widget.keyboardVisible ?? View.of(context).viewInsets.bottom > 0;
    if (!visible) return const SizedBox.shrink();

    return IconButton(
      tooltip: tr(context, 'Billentyűzet elrejtése'),
      icon: const Icon(Icons.keyboard_hide_rounded),
      onPressed: () => FocusManager.instance.primaryFocus?.unfocus(),
    );
  }
}
