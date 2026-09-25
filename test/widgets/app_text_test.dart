import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/core/i18n/app_language.dart';
import 'package:hungarian_hardstyle_app/core/i18n/app_strings.dart';
import 'package:hungarian_hardstyle_app/widgets/app_text.dart';

/// Az `AppText` a felület szövegeinek fordítója: a szöveg a **konstruktorban**
/// marad (ezért a `const` widget-fák épek), a fordítás a `build`-ben történik,
/// és a `Localizations`-függőség miatt nyelvváltáskor újrarajzolódik.
void main() {
  setUp(() {
    AppStrings.setLanguage(AppLanguage.hu);
    AppStrings.setEnglish({'Közösség': 'Community'});
  });

  tearDown(() {
    AppStrings.setLanguage(AppLanguage.hu);
    AppStrings.setEnglish(null);
  });

  testWidgets('magyar módban a magyar szöveget rajzolja', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AppText('Közösség')));
    expect(find.text('Közösség'), findsOneWidget);
  });

  testWidgets('angol módban a fordítást rajzolja', (tester) async {
    AppStrings.setLanguage(AppLanguage.en);
    await tester.pumpWidget(const MaterialApp(home: AppText('Közösség')));
    expect(find.text('Community'), findsOneWidget);
  });

  testWidgets('ismeretlen szövegnél a magyar marad (sosem üres)', (tester) async {
    AppStrings.setLanguage(AppLanguage.en);
    await tester.pumpWidget(const MaterialApp(home: AppText('Nincs ilyen kulcs')));
    expect(find.text('Nincs ilyen kulcs'), findsOneWidget);
  });

  testWidgets('a stílus és a paraméterek átkerülnek a belső Text-re', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AppText(
          'Közösség',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ),
    );
    final text = tester.widget<Text>(find.byType(Text));
    expect(text.data, 'Közösség');
    expect(text.style?.fontSize, 21);
    expect(text.style?.fontWeight, FontWeight.bold);
    expect(text.maxLines, 3);
    expect(text.overflow, TextOverflow.ellipsis);
    expect(text.textAlign, TextAlign.center);
  });

  testWidgets('const-ban is használható (ezért nem tört el a const fa)', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Column(
          children: [AppText('Közösség'), SizedBox(height: 4)],
        ),
      ),
    );
    expect(find.text('Közösség'), findsOneWidget);
  });

  testWidgets('nyelvváltáskor a MÁR FELÉPÜLT AppText is átrajzolódik', (tester) async {
    final notifier = ValueNotifier<AppLanguage>(AppLanguage.hu);
    addTearDown(notifier.dispose);
    await tester.pumpWidget(
      ValueListenableBuilder<AppLanguage>(
        valueListenable: notifier,
        builder: (context, language, _) => MaterialApp(
          locale: appLanguageLocale(language),
          supportedLocales: const [Locale('hu', 'HU'), Locale('en', 'US')],
          // A valódi appal egyező delegátusok (enélkül a `hu_HU` figyelmeztetés
          // hibaként jelenik meg a tesztben).
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const AppText('Közösség'),
        ),
      ),
    );
    expect(find.text('Közösség'), findsOneWidget);

    AppStrings.setLanguage(AppLanguage.en);
    notifier.value = AppLanguage.en;
    await tester.pumpAndSettle();
    expect(find.text('Community'), findsOneWidget);
    expect(find.text('Közösség'), findsNothing);
  });
}
