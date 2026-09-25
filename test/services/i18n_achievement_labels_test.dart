import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/core/i18n/app_language.dart';
import 'package:hungarian_hardstyle_app/core/i18n/app_strings.dart';
import 'package:hungarian_hardstyle_app/services/achievement_service.dart';

/// Az **Achievement-nevek és -leírások** angolul (2026-09-26).
///
/// MIÉRT: a tulajdonos jelezte, hogy angol módban a jelvények **neve** és
/// **leírása** magyarul maradt. A mérés szerint a névhez **egyetlen** fordítás sem
/// volt a szótárban (`Kezdő ütem`, `Első lépés`, …), a leírások közül pedig
/// **egy** hiányzott — a megjelenítés viszont már a szótárból fordít
/// (`AppText(level.name)`, `AchievementBadgeCard`). Ez a teszt a **szótárt** és a
/// **megjelenítési helyeket** is őrzi, mert pont ez a kettő csúszott szét.
///
/// ⚠️ A MÁSIK ŐRSZEM (a saját hibám nyoma): az adatlisták (`static final`)
/// korábban **betöltéskor** fordítottak (`AppStrings.tr(...)`), ezért a nyelvet
/// a betöltés pillanatában **rögzítették** — ha az app angolul indult, magyar
/// módban is angol szöveg maradt. A javítás: az adat magyar kulcs, a fordítás a
/// megjelenítés helyén. A teszt forrás-linttel zárja ki a visszacsúszást.
void main() {
  final dictionary = jsonDecode(File('assets/i18n/en.json').readAsStringSync()) as Map<String, dynamic>;
  final service = File('lib/services/achievement_service.dart').readAsStringSync();
  final guide = File('lib/screens/more/achievement_guide_screen.dart').readAsStringSync();
  final card = File('lib/widgets/achievement_badge_card.dart').readAsStringSync();

  setUp(() {
    AppStrings.setLanguage(AppLanguage.hu);
    AppStrings.setEnglish(null);
  });

  tearDown(() {
    AppStrings.setLanguage(AppLanguage.hu);
    AppStrings.setEnglish(null);
  });

  test('a tartalék jelvény-katalógus MINDEN neve és leírása a szótárban van', () {
    final missing = <String>[];
    for (final level in AchievementService.fallbackLevels) {
      if (!dictionary.containsKey(level.name)) missing.add(level.name);
      if (level.description.isNotEmpty && !dictionary.containsKey(level.description)) {
        missing.add(level.description);
      }
    }
    expect(missing, isEmpty, reason: 'nincs fordítás ezekre: $missing');
  });

  test('a fordítások valódiak (nem üresek, nem a kulccsal azonosak)', () {
    final bad = <String>[];
    for (final level in AchievementService.fallbackLevels) {
      for (final key in [level.name, level.description]) {
        if (key.isEmpty) continue;
        final value = (dictionary[key] as String?)?.trim() ?? '';
        if (value.isEmpty || value == key) bad.add('$key → "$value"');
      }
    }
    expect(bad, isEmpty, reason: 'gyanús fordítás: $bad');
  });

  test('angol módban a jelvények neve és leírása angolul jelenik meg', () {
    AppStrings.setEnglish(dictionary.map((key, value) => MapEntry(key, '$value')));
    AppStrings.setLanguage(AppLanguage.en);

    expect(AppStrings.tr('Kezdő ütem'), 'First Beat');
    expect(AppStrings.tr('Első lépés'), 'First Step');
    expect(AppStrings.tr('Közösségi ember'), 'Community Member');
    expect(AppStrings.tr('HUHS legenda'), 'HUHS Legend');
    expect(AppStrings.tr('A HUHS közösség alapjelvénye.'), isNot('A HUHS közösség alapjelvénye.'));
    expect(AppStrings.tr('Sokat tesz a közösségi jelenlétért.'), isNot('Sokat tesz a közösségi jelenlétért.'));
    expect(AppStrings.trArgs('{n} pont', {'n': '700'}), '700 points');
  });

  test('magyar módban VÁLTOZATLAN minden jelvénynév és leírás', () {
    AppStrings.setEnglish(dictionary.map((key, value) => MapEntry(key, '$value')));
    AppStrings.setLanguage(AppLanguage.hu);

    for (final level in AchievementService.fallbackLevels) {
      expect(AppStrings.tr(level.name), level.name);
      expect(AppStrings.tr(level.description), level.description);
    }
  });

  test('FORRÁS-LINT: az adatlista NEM fordít betöltéskor (nincs nyelv-rögzítés)', () {
    for (final (name, source) in [('achievement_service.dart', service), ('achievement_guide_screen.dart', guide)]) {
      expect(
        source.contains('AppStrings.tr('),
        isFalse,
        reason: '$name: az adatréteg ne fordítson (a megjelenítés fordít) — '
            'különben a betöltés pillanatában rögzül a nyelv',
      );
    }
  });

  test('FORRÁS-LINT: a jelvénykártya a szótárból fordítja a nevet és a leírást', () {
    expect(card.contains('AppText(achievement.badgeName)'), isTrue, reason: 'a név fordítva jelenik meg');
    expect(card.contains('tr(context, achievement.badgeDescription)'), isTrue, reason: 'a leírás fordítva jelenik meg');
    expect(card.contains("trArgs(context, '{n} pont'"), isTrue, reason: 'a pont-egység is fordítva (nem beégetett „pont")');
  });
}
