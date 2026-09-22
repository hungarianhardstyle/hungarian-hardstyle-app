import 'package:flutter/widgets.dart';

/// Görgethető oldalak ALJÁRA való üres hely — egy szabály, egy helyen.
///
/// MIÉRT KELL: a telefonokon a rendszer alsó sávja (gesztus-sáv vagy a rendszer
/// navigációja) **rá tud lógni** a tartalomra. A `MediaQuery.viewPaddingOf`
/// megmondja, mekkora ez a sáv; ha a lista alján nem hagyunk ekkora helyet, az
/// utolsó kártya **részben takarásban marad**, és úgy tűnik, mintha
/// „nem lehetne a végére görgetni".
///
/// EZ VOLT A TULAJDONOS JELZÉSE (2026-09-22): *„ha az achievement notifyra
/// nyomok, megnyílik a saját adatlap, viszont nem tudok legörgetni az aljára
/// rendesen"* — a saját profil a leghosszabb (átvett adatlapok, kedvenc DJ-k,
/// megjelölt események), ezért pont ott látszott.
///
/// A `extra` a **szándékos levegő** a rendszer sávja fölött (hogy az utolsó sor
/// ne tapadjon a szélére).
double scrollBottomInsetFor(double viewPaddingBottom, {double extra = 24}) {
  final safe = viewPaddingBottom.isFinite && viewPaddingBottom > 0
      ? viewPaddingBottom
      : 0.0;
  return safe + extra;
}

/// Ugyanaz `BuildContext`-ből — a képernyők ezt hívják.
double scrollBottomInset(BuildContext context, {double extra = 24}) =>
    scrollBottomInsetFor(MediaQuery.viewPaddingOf(context).bottom, extra: extra);

/// Kész „helykitöltő" a lista végére.
class ScrollBottomInset extends StatelessWidget {
  const ScrollBottomInset({super.key, this.extra = 24});

  final double extra;

  @override
  Widget build(BuildContext context) =>
      SizedBox(height: scrollBottomInset(context, extra: extra));
}
