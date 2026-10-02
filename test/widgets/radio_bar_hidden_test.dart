import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/services/radio_bar_visibility.dart';

/// **A rádiósáv elrejtése a Twitch-oldalon** — a tulajdonos jelzése (2026-10-02):
/// *„sztem a rádió lekerülhet a twitch chat részről”*.
///
/// MIÉRT kell külön mechanizmus: a Twitch-oldal **beágyazott** navigátoron nyílik
/// meg (`main_navigation.dart` tab-navigátorai), ezért az app keretének alsó sávja
/// (rádió + menü) **alatta marad** — a rádiósáv így helyet vesz el a chattól.
void main() {
  tearDown(() => radioBarVisibility.show());

  testWidgets('a rádiósáv eltűnik, amíg a Twitch-oldal kéri', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Text('tartalom'),
          bottomNavigationBar: HideRadioBar(child: Text('rádiósáv')),
        ),
      ),
    );
    expect(find.text('rádiósáv'), findsOneWidget);

    radioBarVisibility.hide();
    await tester.pumpAndSettle();
    expect(find.text('rádiósáv'), findsNothing,
        reason: 'a Twitch-oldalon nem látszódhat a rádiósáv');

    radioBarVisibility.show();
    await tester.pumpAndSettle();
    expect(find.text('rádiósáv'), findsOneWidget,
        reason: 'az oldal elhagyása után visszatér');
  });

  test('a szolgáltatás egyszerű és egyirányú (hide/show)', () {
    expect(radioBarVisibility.hidden.value, isFalse);
    radioBarVisibility.hide();
    expect(radioBarVisibility.hidden.value, isTrue);
    radioBarVisibility.show();
    expect(radioBarVisibility.hidden.value, isFalse);
  });

  test('FORRÁS-LINT: a Twitch-oldal megnyíláskor elrejti, bezáráskor visszaadja', () {
    final screen = File('lib/screens/twitch/twitch_screen.dart').readAsStringSync();
    final initBody = RegExp(r'void initState\(\) \{([\s\S]*?)\n  \}')
        .firstMatch(screen)
        ?.group(1);
    final disposeBody = RegExp(r'void dispose\(\) \{([\s\S]*?)\n  \}')
        .firstMatch(screen)
        ?.group(1);
    expect(initBody, isNotNull);
    expect(disposeBody, isNotNull);
    expect(initBody, contains('radioBarVisibility.hide()'),
        reason: 'az oldal nem rejti el a rádiósávot');
    expect(disposeBody, contains('radioBarVisibility.show()'),
        reason: 'az oldal nem adja vissza a rádiósávot kilépéskor');
  });

  test('FORRÁS-LINT: a keret a rádiósávot a burokban rejti el', () {
    final shell = File('lib/screens/main_navigation.dart').readAsStringSync();
    final wrapped = RegExp(r'HideRadioBar\(child: RadioPlayerBar\(\)\)')
        .allMatches(shell)
        .length;
    expect(wrapped, 2,
        reason: 'mindkét elrendezésben (álló és fekvő) el kell rejteni a rádiósávot');
  });
}
