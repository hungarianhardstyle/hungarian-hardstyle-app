import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/core/i18n/app_language.dart';

void main() {
  group('appLanguageFromCode', () {
    test('a magyar az alapértelmezett', () {
      expect(appLanguageFromCode(null), AppLanguage.hu);
      expect(appLanguageFromCode(''), AppLanguage.hu);
      expect(appLanguageFromCode('hu'), AppLanguage.hu);
      expect(appLanguageFromCode('hu_HU'), AppLanguage.hu);
    });

    test('az angol felismerése minden alakból', () {
      expect(appLanguageFromCode('en'), AppLanguage.en);
      expect(appLanguageFromCode('EN'), AppLanguage.en);
      expect(appLanguageFromCode('en_US'), AppLanguage.en);
      expect(appLanguageFromCode('en-GB'), AppLanguage.en);
      expect(appLanguageFromCode(' en '), AppLanguage.en);
    });

    test('ismeretlen kód nem töri el a felületet (magyar marad)', () {
      expect(appLanguageFromCode('de'), AppLanguage.hu);
      expect(appLanguageFromCode('klingon'), AppLanguage.hu);
      expect(appLanguageFromCode('123'), AppLanguage.hu);
    });
  });

  test('a kapcsoló mindig a MÁSIK nyelv kódját írja', () {
    expect(appLanguageSwitchLabel(AppLanguage.hu), 'EN');
    expect(appLanguageSwitchLabel(AppLanguage.en), 'HU');
    expect(otherLanguage(AppLanguage.hu), AppLanguage.en);
    expect(otherLanguage(AppLanguage.en), AppLanguage.hu);
  });

  test('a nyelv kódja és locale-je', () {
    expect(appLanguageCode(AppLanguage.hu), 'hu');
    expect(appLanguageCode(AppLanguage.en), 'en');
    expect(appLanguageLocale(AppLanguage.hu), const Locale('hu', 'HU'));
    expect(appLanguageLocale(AppLanguage.en), const Locale('en', 'US'));
  });

  test('a nyelv a saját nevén szerepel', () {
    expect(appLanguageName(AppLanguage.hu), 'Magyar');
    expect(appLanguageName(AppLanguage.en), 'English');
  });

  test('a mentési kulcs stabil', () {
    expect(appLanguageStorageKey, 'app_language');
  });
}
