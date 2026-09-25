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
