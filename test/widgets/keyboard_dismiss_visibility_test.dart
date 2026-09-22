import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hungarian_hardstyle_app/widgets/keyboard_dismiss_button.dart';

/// **A billentyűzet-elrejtő gomb LÁTHATÓSÁGA — valódi widget-teszt.**
///
/// MIÉRT KELL (a tulajdonos jelzése, 2026-09-22, iPhone): *„billentyűzet-elrejtő
/// gomb a chatben és a privát üzeneteknél — **nincs**"*. A gomb viszont be volt
/// kötve (`community_screen.dart`, `private_messages_screen.dart`), és a
/// forrás-lint is zöld volt — vagyis a hiba a **megjelenítésben** él, amit
/// forrás-lint **nem tud** megfogni.
///
/// Ez a teszt a kérdést a **keretrendszer valódi viselkedésével** méri: a
/// `Scaffold` a `MediaQuery`-t módosítva adja tovább a gyerekeinek, ezért
/// elképzelhető, hogy a fejléc (`AppBar`) **nem látja** a billentyűzet magasságát
/// — ilyenkor a gomb örökre `SizedBox.shrink()` marad, pontosan úgy, ahogy a
/// tulajdonos látta.
///
/// ⚠️ A `Scaffold`-ot szándékosan **valódi** `AppBar`-ral építjük, mert a
/// kérdés épp az, hogy a fejléc megkapja-e a `viewInsets`-et.
void main() {
  const keyboardHeight = 320.0;

  Widget host({required double bottomInset}) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          viewInsets: EdgeInsets.only(bottom: bottomInset),
        ),
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Chat'),
            actions: const [KeyboardDismissButton()],
          ),
          body: const SizedBox.expand(),
        ),
      ),
    );
  }

  testWidgets('zárt billentyűzetnél NEM foglal helyet', (tester) async {
    await tester.pumpWidget(host(bottomInset: 0));
    expect(find.byIcon(Icons.keyboard_hide_rounded), findsNothing);
  });

  testWidgets('NYITOTT billentyűzetnél látszik a fejlécben', (tester) async {
    await tester.pumpWidget(host(bottomInset: keyboardHeight));
    expect(
      find.byIcon(Icons.keyboard_hide_rounded),
      findsOneWidget,
      reason: 'a gombnak a fejlécben kell megjelennie, amikor a billentyűzet '
          'nyitva van — különben iOS-en nem lehet bezárni',
    );
  });

  testWidgets('a gomb elengedi a fókuszt (ez zárja be a billentyűzetet)',
      (tester) async {
    await tester.pumpWidget(host(bottomInset: keyboardHeight));

    // Valódi szövegmező, hogy legyen fókusz, amit el lehet engedni.
    final focusNode = FocusNode();
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            viewInsets: EdgeInsets.only(bottom: keyboardHeight),
          ),
          child: Scaffold(
            appBar: AppBar(
              actions: const [KeyboardDismissButton()],
            ),
            body: TextField(focusNode: focusNode),
          ),
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);

    await tester.tap(find.byIcon(Icons.keyboard_hide_rounded));
    await tester.pumpAndSettle();
    expect(focusNode.hasFocus, isFalse,
        reason: 'a gomb a fókusz elengedésével zárja be a billentyűzetet');
  });
}
