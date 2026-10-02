import 'package:flutter/material.dart';

/// **A rádiósáv elrejtése** — a Twitch-oldal kéri, amíg nyitva van.
///
/// MIÉRT (a tulajdonos jelzése, 2026-10-02): *„sztem a rádió lekerülhet a twitch
/// chat részről”*. A rádiósáv az **app keretében** él (`main_navigation.dart`
/// alsó sávja), a Twitch-oldal pedig egy **beágyazott** navigátoron nyílik meg,
/// ezért a keret sávja **alatta marad** — a chat így kevesebb helyet kap, és a
/// „Leállítás/play” gomb elvonja a figyelmet a streamről.
///
/// A megoldás szándékosan **egyszerű és egyirányú**: a Twitch-oldal megnyíláskor
/// [hide]-ot, bezáráskor [show]-t hív, a keret pedig figyeli.
class RadioBarVisibility {
  RadioBarVisibility();

  final ValueNotifier<bool> hidden = ValueNotifier<bool>(false);

  /// A Twitch-oldal megnyílt — a rádiósáv ne látszódjon.
  void hide() => hidden.value = true;

  /// A Twitch-oldal bezárt — a rádiósáv visszatér.
  void show() => hidden.value = false;
}

final RadioBarVisibility radioBarVisibility = RadioBarVisibility();

/// Elrejti a gyerekét, ha a rádiósávot el kell rejteni (Twitch-oldal vagy PiP).
class HideRadioBar extends StatelessWidget {
  const HideRadioBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: radioBarVisibility.hidden,
      builder: (context, hidden, _) => hidden ? const SizedBox.shrink() : child,
    );
  }
}
