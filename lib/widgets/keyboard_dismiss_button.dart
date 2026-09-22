import 'package:flutter/material.dart';

/// **Billentyűzet-elrejtő gomb a fejlécben.**
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
/// ⚠️ A `MediaQuery.viewInsetsOf(context)` szándékos: ettől a widget **függ** a
/// billentyűzet magasságától, ezért újraépül, amikor az kinyílik vagy bezárul.
/// Ha ezt `MediaQuery.of(context).viewInsets`-re írnánk át, ugyanígy működne —
/// de a `sizeOf`/`paddingOf` mintára itt is a szűkebb olvasás a helyes.
class KeyboardDismissButton extends StatelessWidget {
  const KeyboardDismissButton({super.key});

  @override
  Widget build(BuildContext context) {
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    if (!keyboardVisible) return const SizedBox.shrink();

    return IconButton(
      tooltip: 'Billentyűzet elrejtése',
      icon: const Icon(Icons.keyboard_hide_rounded),
      onPressed: () => FocusManager.instance.primaryFocus?.unfocus(),
    );
  }
}
