import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/core/i18n/app_language.dart';
import 'package:hungarian_hardstyle_app/core/i18n/app_strings.dart';

void main() {
  setUp(() {
    AppStrings.setLanguage(AppLanguage.hu);
    AppStrings.setEnglish(null);
  });

  tearDown(() {
    AppStrings.setLanguage(AppLanguage.hu);
    AppStrings.setEnglish(null);
  });

  group('tr', () {
    test('magyar módban a magyar szöveg jön (akkor is, ha van fordítás)', () {
      AppStrings.setEnglish({'Közösség': 'Community'});
      expect(AppStrings.tr('Közösség'), 'Közösség');
    });

    test('angol módban a fordítás jön', () {
      AppStrings.setEnglish({'Közösség': 'Community'});
      AppStrings.setLanguage(AppLanguage.en);
      expect(AppStrings.tr('Közösség'), 'Community');
    });

    test('hiányzó kulcsnál MAGYAR marad (sosem üres)', () {
      AppStrings.setEnglish({'Közösség': 'Community'});
      AppStrings.setLanguage(AppLanguage.en);
      expect(AppStrings.tr('Nincs ilyen kulcs'), 'Nincs ilyen kulcs');
    });

    test('üres fordítás nem ad üres feliratot', () {
      AppStrings.setEnglish({'Közösség': 'Community'});
      // Az üres érték a betöltésnél kiesik, ezért itt sem lehet üres a felirat.
      expect(AppStrings.english.containsKey('Közösség'), true);
      expect(AppStrings.tr('Közösség'), 'Közösség');
    });
  });

  group('parseEnglishDictionary', () {
    test('az üres és hiányzó értékek kiesnek', () {
      final dictionary = AppStrings.parseEnglishDictionary({
        'A': 'a',
        'B': '   ',
        'C': '',
        '  ': 'd',
      });
      expect(dictionary.keys.toList(), ['A']);
      expect(dictionary['A'], 'a');
    });

    test('null és üres bemenet üres szótárat ad', () {
      expect(AppStrings.parseEnglishDictionary(null), isEmpty);
      expect(AppStrings.parseEnglishDictionary({}), isEmpty);
    });

    test('a szótár nem módosítható (véletlen írás nem szivárog)', () {
      final dictionary = AppStrings.parseEnglishDictionary({'A': 'a'});
      expect(() => dictionary['B'] = 'b', throwsUnsupportedError);
    });
  });

  group('decodeDictionary', () {
    test('érvényes JSON-t szótárrá alakít', () {
      final dictionary = AppStrings.decodeDictionary('{"Hírek":"News"}');
      expect(dictionary['Hírek'], 'News');
    });

    test('hibás JSON nem dob, üres szótár lesz', () {
      expect(AppStrings.decodeDictionary('{ez nem json'), isEmpty);
      expect(AppStrings.decodeDictionary(''), isEmpty);
    });

    test('a nem objektum gyökér üres szótár', () {
      expect(AppStrings.decodeDictionary('[1,2,3]'), isEmpty);
      expect(AppStrings.decodeDictionary('"szöveg"'), isEmpty);
    });

    test('a valós asset-szótár feldolgozható alakú', () {
      // Ugyanaz a tisztítás fut, mint a betöltésnél: nem lehet üres felirat.
      final raw = jsonDecode(const JsonEncoder().convert({'Hírek': 'News'})) as Map;
      final dictionary = AppStrings.parseEnglishDictionary(
        raw.map((key, value) => MapEntry('$key', '$value')),
      );
      expect(dictionary.values.where((value) => value.trim().isEmpty), isEmpty);
    });
  });

  group('trArgs', () {
    test('a helyőrzőt behelyettesíti a fordításban', () {
      AppStrings.setEnglish({'{n} nap': '{n} days'});
      AppStrings.setLanguage(AppLanguage.en);
      expect(AppStrings.trArgs('{n} nap', {'n': '3'}), '3 days');
    });

    test('magyar módban a magyar sablont tölti ki', () {
      AppStrings.setLanguage(AppLanguage.hu);
      expect(AppStrings.trArgs('{n} nap', {'n': '3'}), '3 nap');
    });

    test('hiányzó kulcsnál a magyar sablon marad, kitöltve', () {
      AppStrings.setLanguage(AppLanguage.en);
      expect(AppStrings.trArgs('{n} jegy', {'n': '2'}), '2 jegy');
    });
  });
}
