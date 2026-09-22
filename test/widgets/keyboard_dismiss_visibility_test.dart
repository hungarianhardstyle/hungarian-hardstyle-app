import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hungarian_hardstyle_app/widgets/keyboard_dismiss_button.dart';

/// **A billentyűzet-elrejtő gomb LÁTHATÓSÁGA — valódi widget-teszt.**
///
/// MIÉRT KELL (a tulajdonos jelzése, 2026-09-22, iPhone): *„billentyűzet-elrejtő
/// gomb a chatben és a privát üzeneteknél — **nincs**"*, majd a második körben:
/// *„billentyűzet-elrejtő, na az nincs most se, nyitva, nézd meg"*.
///
/// ⚠️ **A LEGFONTOSABB TANULSÁG EBBEN A FÁJLBAN:** az első változat **egyetlen**
/// Scaffolddal mérte a láthatóságot, ezért **zöld** volt — miközben az éles appban
/// a gomb **soha** nem jelent meg. Az app képernyői ugyanis **egymásba ágyazott**
/// Scaffoldokban élnek (`main_navigation.dart` külső Scaffold → a Chat belső
/// Scaffoldja), és a külső Scaffold a saját `body`-jából **lenullázza** a
/// `MediaQuery.viewInsets`-t (`resizeToAvoidBottomInset` viselkedése). A belső
/// képernyőn ezért a `MediaQuery.viewInsetsOf(context).bottom` **mindig 0**.
///
/// Ezért ez a teszt **beágyazott** Scaffolddal méri azt az esetet, ami élesben
/// elhasalt — és a nyers `tester.view.viewInsets`-szel állítja be a billentyűzetet
/// (a `View.of(context)` ugyanazt olvassa, amit a platform ad).
void main() {
  const keyboardHeight = 320.0;

  /// ⚠️ A valódi platform-inset állítása (nem `MediaQuery` injektálás): pontosan
  /// ezt olvassa a widget is.
  void setKeyboard(WidgetTester tester, double bottomInset) {
    tester.view.viewInsets = FakeViewPadding(bottom: bottomInset);
    addTearDown(tester.view.reset);
  }

  Widget host({
    required Widget child,
    required bool nestedScaffold,
  }) {
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
    setKeyboard(tester, 0);
    await tester.pumpWidget(host(nestedScaffold: true, child: const SizedBox()));
    expect(find.byIcon(Icons.keyboard_hide_rounded), findsNothing);
  });

  testWidgets('nyitott billentyűzetnél látszik (egyszerű Scaffold)', (tester) async {
    setKeyboard(tester, keyboardHeight);
    await tester.pumpWidget(host(nestedScaffold: false, child: const SizedBox()));
    expect(find.byIcon(Icons.keyboard_hide_rounded), findsOneWidget);
  });

  testWidgets('BEÁGYAZOTT Scaffold mellett is látszik — ez volt az éles hiba',
      (tester) async {
    setKeyboard(tester, keyboardHeight);
    await tester.pumpWidget(host(nestedScaffold: true, child: const SizedBox()));
    expect(
      find.byIcon(Icons.keyboard_hide_rounded),
      findsOneWidget,
      reason: 'a külső Scaffold lenullázza a belső MediaQuery viewInsets-ét, '
          'ezért a NYERS platform-értéket kell olvasni — enélkül a gomb soha '
          'nem jelenik meg az éles appban',
    );
  });

  testWidgets('a gomb elengedi a fókuszt (ez zárja be a billentyűzetet)',
      (tester) async {
    setKeyboard(tester, keyboardHeight);
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
          appBar: null,
          body: Row(children: [KeyboardDismissButton(keyboardVisible: true)]),
        ),
      ),
    );
    expect(find.byIcon(Icons.keyboard_hide_rounded), findsOneWidget);
  });
}
