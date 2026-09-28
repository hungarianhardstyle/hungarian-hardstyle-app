import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hungarian_hardstyle_app/core/i18n/app_language.dart';
import 'package:hungarian_hardstyle_app/services/push_language.dart';

/// **A push-kérés nyelvi mezője** (plugin 2.14.6).
///
/// MIÉRT KELL A TESZT: a nyelv a token-rekordba kerül, és **az** dönti el, hogy
/// az esemény-emlékeztető magyarul vagy angolul megy ki. Egy hibás/üres érték
/// csendben mindenkit magyarra váltana — vagyis pont az a felhasználói élmény
/// veszne el, amiért a mező egyáltalán létezik. A szerver fallbackje a magyar,
/// ezért a kliens **soha** nem küldhet üres vagy ismeretlen kódot.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('a küldhető nyelvkód', () {
    test('a magyar és az angol a saját kódját adja', () {
      expect(pushLanguageCode('hu'), 'hu');
      expect(pushLanguageCode('en'), 'en');
    });

    test('a nagybetű és a területi változat is elfogadott', () {
      expect(pushLanguageCode('EN'), 'en');
      expect(pushLanguageCode(' en '), 'en');
      expect(pushLanguageCode('en_US'), 'en');
      expect(pushLanguageCode('en-GB'), 'en');
      expect(pushLanguageCode('HU'), 'hu');
    });

    test('a hiányzó érték magyar (a szerver fallbackjével egyezően)', () {
      expect(pushLanguageCode(null), 'hu');
      expect(pushLanguageCode(''), 'hu');
      expect(pushLanguageCode('   '), 'hu');
    });

    test('az ismeretlen érték is magyar — nem küldhető szemét', () {
      expect(pushLanguageCode('de'), 'hu');
      expect(pushLanguageCode('fr_FR'), 'hu');
      expect(pushLanguageCode('magyar'), 'hu');
      expect(pushLanguageCode('42'), 'hu');
    });

    test('a kimenet MINDIG a két ismert kód egyike', () {
      const inputs = <String?>[
        null,
        '',
        ' ',
        'hu',
        'en',
        'EN',
        'en_US',
        'de',
        'xx',
        'undefined',
        'null',
        '0',
      ];
      for (final input in inputs) {
        expect(
          const <String>['hu', 'en'],
          contains(pushLanguageCode(input)),
          reason: 'bemenet: ${input ?? 'null'}',
        );
      }
    });

    test('a mező neve a plugin szerződése szerint „language"', () {
      expect(pushLanguageField, 'language');
    });
  });

  group('az aktuális felületi nyelv feloldása', () {
    test('a mentett választás az elsődleges', () async {
      SharedPreferences.setMockInitialValues({appLanguageStorageKey: 'en'});
      final preferences = await SharedPreferences.getInstance();
      expect(await resolvePushLanguage(preferences: preferences), 'en');
    });

    test('mentés nélkül magyar az alapértelmezés', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      expect(await resolvePushLanguage(preferences: preferences), 'hu');
    });

    test('a hibás mentett érték sem hoz hibát', () async {
      SharedPreferences.setMockInitialValues({appLanguageStorageKey: 'klingon'});
      final preferences = await SharedPreferences.getInstance();
      expect(await resolvePushLanguage(preferences: preferences), 'hu');
    });

    test('tároló nélkül sem dob (a memóriabeli nyelvre esik vissza)', () async {
      // A `SharedPreferences` ilyenkor a platform-csatornát hívná, ami tesztben
      // nem elérhető — a hívás mégis **hibamentesen** visszatér.
      final code = await resolvePushLanguage();
      expect(const <String>['hu', 'en'], contains(code));
    });
  });
}
