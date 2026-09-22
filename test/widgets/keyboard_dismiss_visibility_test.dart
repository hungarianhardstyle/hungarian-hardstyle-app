import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hungarian_hardstyle_app/widgets/keyboard_dismiss_button.dart';

/// **A billentyűzet-elrejtő gomb LÁTHATÓSÁGA — valódi widget-teszt.**
///
/// A tulajdonos két jelzése (2026-09-22, iPhone):
///  * *„billentyűzet-elrejtő gomb a chatben és a privát üzeneteknél — **nincs**"*;
///  * *„most sem látszik, de ha elkezdem görgetni a chatet eltűnik"*.
///
/// ## ⚠️ KÉT HAMIS POZITÍV TANULSÁGA EBBEN A FÁJLBAN
///
/// **1.** Az első változat **egyetlen** Scaffolddal mért, ezért **zöld** volt —
/// miközben az éles appban a gomb soha nem jelent meg. Az app képernyői ugyanis
/// **egymásba ágyazott** Scaffoldokban élnek, és a külső Scaffold a `body`-jából
/// lenullázza a `MediaQuery.viewInsets`-t. Ezért itt **beágyazott** Scaffolddal
/// mérünk.
///
/// **2.** A második változat a `View.of(context)`-et olvasta, de **csak az első
/// felépítéskor** mérte (a billentyűzetet a `pumpWidget` ELŐTT állítottuk be) —
/// így megint zöld lett, pedig a `View.of` **nem értesíti** a contextet, ezért a
/// gomb a **bezrt állapotban ragadt**. Ezért van itt **dinamikus** eset is: a
/// billentyűzetet a widget felépítése **UTÁN** nyitjuk ki.
void main() {
  const keyboardHeight = 320.0;

  /// ⚠️ A valódi platform-inset állítása (nem `MediaQuery` injektálás): pontosan
  /// ezt olvassa a widget is.
  void initKeyboard(WidgetTester tester, double bottomInset) {
    tester.view.viewInsets = FakeViewPadding(bottom: bottomInset);
    addTearDown(tester.view.reset);
  }

  void openKeyboard(WidgetTester tester) {
    tester.view.viewInsets = const FakeViewPadding(bottom: keyboardHeight);
  }

  void closeKeyboard(WidgetTester tester) {
    tester.view.viewInsets = FakeViewPadding.zero;
  }

  Widget host({required bool nestedScaffold}) {
    final inner = Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
        actions: const [KeyboardDismissButton()],
      ),
      body: const SizedBox.expand(),
    );
    return MaterialApp(
      home: nestedScaffold
          // ⚠️ PONTOSAN az éles szerkezet: külső Scaffold (MainNavigation) a
          // benne lévő képernyővel.
          ? Scaffold(
              bottomNavigationBar: const SizedBox(height: 60),
              body: inner,
            )
          : inner,
    );
  }

  testWidgets('zárt billentyűzetnél NEM foglal helyet', (tester) async {
    initKeyboard(tester, 0);
    await tester.pumpWidget(host(nestedScaffold: true));
    expect(find.byIcon(Icons.keyboard_hide_rounded), findsNothing);
  });

  testWidgets('nyitott billentyűzetnél látszik (egyszerű Scaffold)', (tester) async {
    initKeyboard(tester, keyboardHeight);
    await tester.pumpWidget(host(nestedScaffold: false));
    expect(find.byIcon(Icons.keyboard_hide_rounded), findsOneWidget);
  });

  testWidgets('BEÁGYAZOTT Scaffold mellett is látszik — az 1. hiba őre',
      (tester) async {
    initKeyboard(tester, keyboardHeight);
    await tester.pumpWidget(host(nestedScaffold: true));
    expect(
      find.byIcon(Icons.keyboard_hide_rounded),
      findsOneWidget,
      reason: 'a külső Scaffold lenullázza a belső MediaQuery viewInsets-ét, '
          'ezért a NYERS platform-értéket kell olvasni',
    );
  });

  testWidgets('a billentyűzet KINYÍLÁSAKOR jelenik meg — a 2. hiba őre',
      (tester) async {
    // Így indul: nincs billentyűzet.
    initKeyboard(tester, 0);
    await tester.pumpWidget(host(nestedScaffold: true));
    expect(find.byIcon(Icons.keyboard_hide_rounded), findsNothing);

    // A felhasználó a szövegmezőbe koppint: a billentyűzet kinyílik.
    openKeyboard(tester);
    await tester.pump();

    expect(
      find.byIcon(Icons.keyboard_hide_rounded),
      findsOneWidget,
      reason: 'a View.of(context) NEM értesíti a widgetet a változásról — ezért '
          'kell a metrika-figyelő, különben a gomb a zárt állapotban ragad',
    );
  });

  testWidgets('a billentyűzet BEZÁRÁSAKOR eltűnik', (tester) async {
    initKeyboard(tester, keyboardHeight);
    await tester.pumpWidget(host(nestedScaffold: true));
    expect(find.byIcon(Icons.keyboard_hide_rounded), findsOneWidget);

    closeKeyboard(tester);
    await tester.pump();
    expect(find.byIcon(Icons.keyboard_hide_rounded), findsNothing);
  });

  testWidgets('a gomb elengedi a fókuszt (ez zárja be a billentyűzetet)',
      (tester) async {
    initKeyboard(tester, keyboardHeight);
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(actions: const [KeyboardDismissButton()]),
          body: TextField(focusNode: focusNode),
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

  testWidgets('teszt-paraméterrel is működik (nem kell valódi inset)',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Row(children: [KeyboardDismissButton(keyboardVisible: true)]),
        ),
      ),
    );
    expect(find.byIcon(Icons.keyboard_hide_rounded), findsOneWidget);
  });
}
