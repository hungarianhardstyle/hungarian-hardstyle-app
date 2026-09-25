import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/core/i18n/app_language.dart';
import 'package:hungarian_hardstyle_app/core/i18n/app_strings.dart';
import 'package:hungarian_hardstyle_app/providers/language_provider.dart';

/// Forrás-lint az angol nyelvhez: a **bekötést** őrzi, nem a logikát.
///
/// A logika (`app_language_test.dart`, `app_strings_test.dart`) és a widget
/// viselkedés (`language_switch_test.dart`) külön fut; itt az van, ami egy
/// refactornál csendben elromolhat: az asset regisztrációja, a `MaterialApp`
/// locale-ja, a fejlécbeli kapcsoló, és a **tilalom**, hogy a felhasználói
/// tartalom (chat) fordításra kerüljön.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String readFile(String path) =>
      File(path).readAsStringSync().replaceAll('\r\n', '\n');

  group('forrás-lint: a szótár asset a helyén van', () {
    test('a pubspec regisztrálja az assets/i18n könyvtárat', () {
      final pubspec = readFile('pubspec.yaml');
      expect(pubspec, contains('- assets/i18n/'));
    });

    test('a szótárfájl valós, minden érték nem üres', () {
      final file = File('assets/i18n/en.json');
      expect(file.existsSync(), isTrue);
      final decoded = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      expect(decoded, isNotEmpty);
      for (final entry in decoded.entries) {
        // ⚠️ A kulcs szélén LEHET szóköz: a kódban vannak összefűzött
        // szövegrészek (pl. `'… a letöltés '`), és a kulcsnak pontosan kell
        // egyeznie a forrásszöveggel. Csak a csupa-szóköz kulcs tilos.
        expect(entry.key.trim(), isNotEmpty, reason: 'üres kulcs a szótárban');
        expect(
          (entry.value as String).trim(),
          isNotEmpty,
          reason: 'üres fordítás: ${entry.key}',
        );
      }
    });

    test('a szótár a VALÓDI bundle-ből betöltődik (pubspec-regisztráció él)', () async {
      AppStrings.setEnglish(null);
      await preloadEnglishDictionary();
      expect(
        AppStrings.dictionarySize,
        greaterThan(0),
        reason: 'ha az asset nincs a pubspecban, a szótár üresen tölt be',
      );
      // ⚠️ A puszta „> 0" egy **csonka** szótárat is átengedne (a mérés szerint
      // 921 kulcs van) — ezért a küszöb a mért érték alatt, de érdemben.
      expect(
        AppStrings.dictionarySize,
        greaterThan(800),
        reason: 'a szótár nem csorbulhat (mért: 921 kulcs)',
      );
      AppStrings.setLanguage(AppLanguage.en);
      expect(AppStrings.tr('Közösség'), 'Community');
      AppStrings.setLanguage(AppLanguage.hu);
    });
  });

  group('forrás-lint: a nyelv be van kötve az appba', () {
    late String main;
    late String home;

    setUpAll(() {
      main = readFile('lib/main.dart');
      home = readFile('lib/screens/home/home_screen.dart');
    });

    test('a mentett nyelv és a szótár a runApp ELŐTT betöltődik', () {
      expect(main, contains('await preloadAppLanguage();'));
      // A sorrend is számít: a preload a `runApp` előtt legyen.
      expect(
        main.indexOf('await preloadAppLanguage();'),
        lessThan(main.indexOf('runApp(')),
      );
    });

    test('az angol dátum-nevek is inicializálódnak (nyelvváltás azonnal hasson)', () {
      expect(main, contains("initializeDateFormatting('en_US')"));
      expect(main, contains("initializeDateFormatting('hu_HU')"));
    });

    test('a MaterialApp a figyelt nyelvet használja, mindkét locale-lel', () {
      expect(main, contains('ref.watch(languageProvider)'));
      expect(main, contains('locale: appLanguageLocale(language)'));
      expect(main, contains("Locale('hu', 'HU')"));
      expect(main, contains("Locale('en', 'US')"));
      // A régi, rögzített magyar locale nem maradhat bent.
      expect(main, isNot(contains("locale: const Locale('hu', 'HU')")));
      expect(main, isNot(contains('supportedLocales: const [Locale(\'hu\', \'HU\')]')));
    });

    test('a főoldal fejlécében ott a HU/EN kapcsoló', () {
      expect(home, contains("import '../../widgets/language_switch_button.dart';"));
      // A fejlécben ikon nélkül (mérve ~25 px-cel keskenyebb), és a kapcsoló
      // a jobb oldali csoport végén van.
      expect(home, contains('LanguageSwitchButton(showIcon: false)'));
    });

    test('a felület szövegei be vannak kötve a fordítóba (nem esett vissza)', () {
      final files = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .toList();
      var appText = 0;
      var tr = 0;
      for (final file in files) {
        final source = file.readAsStringSync();
        appText += RegExp(r'AppText\(').allMatches(source).length;
        tr += RegExp(r'\btr(?:Args)?\(context,').allMatches(source).length;
      }
      // A mért érték 2026-09-25-én: 581 AppText + 202 tr = 783 bekötött szöveg.
      // A küszöbök szándékosan a mért érték alatt vannak (kisebb változás nem
      // buktat), de egy visszaesést (a körbefordítás visszavonását) igen.
      expect(appText, greaterThan(450), reason: 'az AppText-bekötés megvan');
      expect(tr, greaterThan(150), reason: 'a tr(...)-bekötés megvan');
    });

    test('a MÁSODIK kör is be van kötve (context nélküli helyek is)', () {
      // A második kör (2026-09-25) a szabályalapú célokon TÚLI UI-szövegeket
      // kötötte be: ternary-ág, `map`-érték, `??` alapérték, service-üzenet.
      // Ahol nincs `BuildContext` a hatókörben, ott a `context` nélküli fordító
      // (`AppStrings.tr`) a helyes alak — ezt a `flutter analyze` jelzi, és a
      // `tools/fix-context-fallout.mjs` írja át.
      //
      // ⚠️ Az `AppStrings.tr(` ág **mérési** szempontból is kényes: amíg az
      // extraktor nem ismerte fel ezt az alakot, addig az így bekötött helyek
      // **kiestek a célok közül**, és a lefedettség hamisan 100% lett. Ezért ez a
      // lint a bekötés mértékét is őrzi (nem csak azt, hogy „van valahol”).
      final files = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .toList();
      var appStringsTr = 0;
      var appStringsTrArgs = 0;
      var filesWithAppStrings = 0;
      for (final file in files) {
        final source = file.readAsStringSync();
        final plain = RegExp(r'AppStrings\.tr\(').allMatches(source).length;
        final withArgs = RegExp(r'AppStrings\.trArgs\(').allMatches(source).length;
        appStringsTr += plain;
        appStringsTrArgs += withArgs;
        if (plain + withArgs > 0) filesWithAppStrings += 1;
      }
      // Mért érték: 59 `AppStrings.tr(` + 1 `AppStrings.trArgs(`, 11 fájlban.
      expect(appStringsTr, greaterThan(40), reason: 'a context nélküli bekötés megvan');
      expect(appStringsTrArgs, greaterThanOrEqualTo(1), reason: 'a trArgs-ág is be van kötve');
      expect(filesWithAppStrings, greaterThan(5), reason: 'több fájlban, nem egy helyen');
    });
  });

  group('forrás-lint: a TARTALOM nyelve követi a választott nyelvet', () {
    late String service;
    late String mainFile;

    setUpAll(() {
      service = readFile('lib/services/wordpress_service.dart');
      mainFile = readFile('lib/main.dart');
    });

    test('a kérés a nyelvi tervből kapja a lang paramétert', () {
      expect(service, contains('wordpressContentQuery('));
      expect(service, contains('wordpressCacheContext(language)'));
      expect(service, contains("import 'wordpress_language_plan.dart';"));
      expect(service, contains("import '../core/i18n/app_strings.dart';"));
    });

    test('a cache kulcsa NEM a platform locale-tól függ (az nem a mi nyelvünk)', () {
      expect(
        service,
        isNot(contains('PlatformDispatcher.instance.locale.toLanguageTag()')),
        reason: 'a mentett válasz nyelve a felületen választott nyelv kell legyen',
      );
    });

    test('a gyökér életben tartja a nyelv–tartalom szinkront', () {
      expect(mainFile, contains('ref.watch(contentLanguageSyncProvider)'));
      expect(mainFile, contains("import 'providers/content_language_provider.dart';"));
    });
  });

  group('forrás-lint: a felhasználói tartalom NEM fordul', () {
    test('a chat üzenet szövege nem megy át fordítón', () {
      final chatText = readFile('lib/widgets/chat_message_text.dart');
      expect(
        chatText,
        isNot(contains('app_strings.dart')),
        reason: 'a chat üzenet a felhasználó szövege — soha nem fordítjuk',
      );
      expect(chatText, isNot(contains('tr(')));
    });

    test('a szótár ÚTJÁT csak az i18n mag ismeri', () {
      final files = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .toList();
      final readers = files
          .where((file) => file.readAsStringSync().contains('en.json'))
          .map((file) => file.path.replaceAll('\\', '/'))
          .toList();
      expect(
        readers..sort(),
        ['lib/core/i18n/app_strings.dart'],
        reason: 'az asset útja egy helyen él (AppStrings.dictionaryAsset)',
      );
    });
  });
}
