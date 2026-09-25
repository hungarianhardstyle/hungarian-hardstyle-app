import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/core/i18n/app_language.dart';
import 'package:hungarian_hardstyle_app/core/i18n/app_strings.dart';
import 'package:hungarian_hardstyle_app/core/i18n/tr.dart';
import 'package:hungarian_hardstyle_app/providers/language_provider.dart';
import 'package:hungarian_hardstyle_app/widgets/language_switch_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A **valódi** szerkezet: a `home` egy `const` képernyő, ezért a szülő
/// (`MaterialApp`) újraépülése **nem** építi újra — pontosan úgy, ahogy az
/// appban a `const StartupGate()` él. Az egyetlen dolog, ami újrarajzolja, a
/// `Localizations`-függőség, amit a `tr(context, …)` regisztrál. (A teszt első
/// változata `Builder`-t használt, ezért **átengedte** azt a mutációt, amely a
/// feliratkozást kiveszi — a `flutter test` zölden hazudott volna.)
class _ProbeScreen extends StatelessWidget {
  const _ProbeScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Ez a lényeg: NEM figyeli a providert, csak a `tr`-t hívja.
          Text(tr(context, 'Közösség'), key: const Key('probe')),
          const LanguageSwitchButton(),
        ],
      ),
    );
  }
}

class _TestApp extends ConsumerWidget {
  const _TestApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(languageProvider);
    return MaterialApp(
      locale: appLanguageLocale(language),
      supportedLocales: const [Locale('hu', 'HU'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const _ProbeScreen(),
    );
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AppStrings.setLanguage(AppLanguage.hu);
    // A teszt a VALÓDI szótár egy darabját használja (a teljes asset a
    // i18n_wiring tesztben ellenőrzött).
    AppStrings.setEnglish({'Közösség': 'Community', 'Nyelv': 'Language'});
  });

  tearDown(() {
    AppStrings.setLanguage(AppLanguage.hu);
    AppStrings.setEnglish(null);
  });

  testWidgets('a kapcsoló a másik nyelv kódját írja', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: _TestApp()));
    expect(find.text('EN'), findsOneWidget);

    await tester.tap(find.byKey(const Key('language-switch-button')));
    await tester.pumpAndSettle();
    expect(find.text('HU'), findsOneWidget);

    await tester.tap(find.byKey(const Key('language-switch-button')));
    await tester.pumpAndSettle();
    expect(find.text('EN'), findsOneWidget);
  });

  testWidgets('nyelvváltáskor a MÁR FELÉPÜLT felirat is átrajzolódik', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: _TestApp()));
    expect(find.text('Közösség'), findsOneWidget);
    expect(find.text('Community'), findsNothing);

    await tester.tap(find.byKey(const Key('language-switch-button')));
    await tester.pumpAndSettle();

    // A `probe` szöveg widgetje nem figyeli a providert — mégis angol lett,
    // mert a `tr(context, …)` feliratkozik a `Localizations`-re.
    expect(find.text('Community'), findsOneWidget);
    expect(find.text('Közösség'), findsNothing);

    await tester.tap(find.byKey(const Key('language-switch-button')));
    await tester.pumpAndSettle();
    expect(find.text('Közösség'), findsOneWidget);
  });

  testWidgets('a nyelvválasztás mentődik', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: _TestApp()));
    await tester.tap(find.byKey(const Key('language-switch-button')));
    await tester.pumpAndSettle();

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString(appLanguageStorageKey), 'en');
  });
}
