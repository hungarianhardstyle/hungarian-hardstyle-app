import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/core/i18n/app_language.dart';
import 'package:hungarian_hardstyle_app/core/i18n/app_strings.dart';

/// A **hírek taxonómia-nevei** (kategóriák és címkék) — plugin 2.14.0 (app-oldal).
///
/// MIÉRT EZ A MEGOLDÁS: a kategória-/címke-nevek a **WordPress-ből jönnek** (adat),
/// nem a kód literáljai, ezért a fordításuk a **megjelenítésnél** történik a
/// szótárral (`tr(context, category.name)`, `'#${tr(context, tag)}'`). Így
///  * nincs szükség plugin-végpontra vagy új WordPress-mezőre,
///  * a kliens **egy** kategórialistát cache-el, és a felirat a nyelvváltáskor
///    azonnal vált (nem kell újratölteni),
///  * magyar módban a szótár **nem** szól bele (a `tr()` a magyart adja vissza).
///
/// ⚠️ A MÉRT KÉSZLET (2026-09-25, éles WordPress): **13 szerkesztői kategória** és
/// **600 címke**, amelyek közül csak a **magyar köznevek** kapnak fordítást — a
/// tulajdonos döntése szerint a nevek (`Adam Bass`, `adaro`, `#TBT`), a márkák és
/// az elírások (`festiva`, `akvérium`) **maradnak**. Ez a teszt azt is őrzi, hogy
/// egy névhez véletlenül se kerüljön fordítás.
void main() {
  final dictionary = jsonDecode(
    File('assets/i18n/en.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  const categoryNames = <String, String>{
    'Cikkek': 'Articles',
    'Hírek': 'News',
    'Érdekességek': 'Features',
    'Interjúk': 'Interviews',
    'Zene': 'Music',
    'Partyajánló': 'Party Guide',
    'Partyképek': 'Party Photos',
    'Teszt': 'Test',
    'Véleménycikk': 'Opinion',
  };

  const tagNames = <String, String>{
    'buli': 'party',
    'elektronikus zene': 'electronic music',
    'fesztivál': 'festival',
    'fesztiválszezon': 'festival season',
    'hirek': 'news',
    'Hollandia': 'Netherlands',
    'horvátország': 'Croatia',
    'interjú': 'interview',
    'Jövő': 'Future',
    'képek': 'photos',
    'magyar hardstyle': 'Hungarian hardstyle',
    'megjelenés': 'release',
    'partyképek': 'party photos',
    'zene': 'music',
  };

  setUp(() {
    AppStrings.setLanguage(AppLanguage.hu);
    AppStrings.setEnglish(null);
  });

  tearDown(() {
    AppStrings.setLanguage(AppLanguage.hu);
    AppStrings.setEnglish(null);
  });

  test('a mért kategória-nevek mind benne vannak a szótárban', () {
    final missing = categoryNames.keys
        .where((name) => !dictionary.containsKey(name))
        .toList();
    expect(missing, isEmpty, reason: 'hiányzó kategória-fordítás: $missing');
  });

  test('a mért magyar címkenevek mind benne vannak a szótárban', () {
    final missing = tagNames.keys
        .where((name) => !dictionary.containsKey(name))
        .toList();
    expect(missing, isEmpty, reason: 'hiányzó címke-fordítás: $missing');
  });

  test('a fordítások valódiak: nem üresek és nem azonosak a kulccsal', () {
    final bad = <String>[];
    for (final entry in {...categoryNames, ...tagNames}.entries) {
      final value = (dictionary[entry.key] as String?)?.trim() ?? '';
      if (value.isEmpty || value == entry.key) {
        bad.add('${entry.key} → "$value"');
      }
    }
    expect(bad, isEmpty, reason: 'gyanús fordítás: $bad');
  });

  test('angol módban a taxonómia-név fordítva jelenik meg', () {
    AppStrings.setEnglish(dictionary.map((key, value) => MapEntry(key, '$value')));
    AppStrings.setLanguage(AppLanguage.en);

    expect(AppStrings.tr('Partyajánló'), 'Party Guide');
    expect(AppStrings.tr('fesztivál'), 'festival');
    expect(AppStrings.tr('Hollandia'), 'Netherlands');
  });

  test('magyar módban a taxonómia-név VÁLTOZATLAN (nincs beszólás a magyar oldalba)', () {
    AppStrings.setEnglish(dictionary.map((key, value) => MapEntry(key, '$value')));
    AppStrings.setLanguage(AppLanguage.hu);

    for (final name in {...categoryNames.keys, ...tagNames.keys}) {
      expect(AppStrings.tr(name), name);
    }
  });

  test('a tulajdonnevekhez NINCS fordítás (a tulajdonos döntése)', () {
    final names = [
      'Adam Bass',
      'adaro',
      '#TBT',
      'akvárium klub',
      'siderunners',
      'defqon.1',
      'festiva', // elírás — szándékosan nem javítjuk/fordítjuk
    ];
    for (final name in names) {
      expect(
        dictionary.containsKey(name),
        isFalse,
        reason: '$name tulajdonnév/elírás, nem kaphat fordítást',
      );
    }
  });

  test('FORRÁS-LINT: a megjelenítési helyek tényleg fordítanak', () {
    final newsScreen = File('lib/screens/news/news_screen.dart').readAsStringSync();
    final detailScreen = File('lib/screens/news/news_detail_screen.dart').readAsStringSync();
    final taggedScreen = File('lib/screens/news/tagged_news_screen.dart').readAsStringSync();

    expect(
      newsScreen.contains('tr(context, category.name)'),
      isTrue,
      reason: 'a hírek szűrő-címkéje a szótárból fordul',
    );
    expect(
      detailScreen.contains(r"'#${tr(context, tag)}'"),
      isTrue,
      reason: 'a cikk címke-chipjei a szótárból fordulnak',
    );
    expect(
      taggedScreen.contains(r"'#${tr(context, widget.tag)}'"),
      isTrue,
      reason: 'a címke-oldal címe a szótárból fordul',
    );
  });
}
