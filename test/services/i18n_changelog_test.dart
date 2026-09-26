import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/core/i18n/app_language.dart';
import 'package:hungarian_hardstyle_app/core/i18n/app_strings.dart';
import 'package:hungarian_hardstyle_app/data/app_changelog.dart';

/// A **kiadási jegyzet** (Névjegy → Újdonságok) angolul — a tulajdonos jelzése:
/// *„a changelog az appban nem angol"* (angol felületen).
///
/// **A MÉRT GYÖKÉR:** a sorok kiírása **nyers** volt (`Text(change)`), és a
/// szövegek nem voltak a szótárban — ezért angol módban a magyar changelog ment
/// ki. A javítás: a magyar sor a **szótári kulcs**, a kiírás a fordítón megy át.
///
/// ⚠️ Ez a teszt **teljességet** kér számon: MINDEN kiadás MINDEN sorához kell
/// angol fordítás a szótárban — új bejegyzés felvételekor tehát a fordítást is
/// meg kell adni, különben a kör elbukik (ez a szándék).
void main() {
  final dictionary = jsonDecode(
    File('assets/i18n/en.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  final lines = <String>[
    for (final note in appChangelog) ...note.changes,
  ];

  setUp(() {
    AppStrings.setLanguage(AppLanguage.hu);
    AppStrings.setEnglish(null);
  });

  tearDown(() {
    AppStrings.setLanguage(AppLanguage.hu);
    AppStrings.setEnglish(null);
  });

  test('minden changelog-sorhoz van angol fordítás a szótárban', () {
    final missing = <String>[
      for (final line in lines)
        if (!dictionary.containsKey(line)) line,
    ];

    expect(
      lines.length,
      greaterThan(100),
      reason: 'a changelog mérése: ennyi sort kell lefedni',
    );
    expect(
      missing,
      isEmpty,
      reason:
          'ezekhez a changelog-sorokhoz nincs angol fordítás (a Névjegy angol '
          'felületen magyarul mutatná): ${missing.map((line) => line.length > 60 ? '${line.substring(0, 60)}…' : line).join(' | ')}',
    );
  });

  test('angol módban MINDEN sor angolul szól, magyar módban változatlan', () {
    final english = dictionary.map((key, value) => MapEntry(key, '$value'));
    AppStrings.setEnglish(english);

    AppStrings.setLanguage(AppLanguage.en);
    final stillHungarian = <String>[];
    for (final line in lines) {
      final translated = AppStrings.tr(line);
      if (translated == line || translated.trim().isEmpty) {
        stillHungarian.add(line);
      }
    }
    expect(
      stillHungarian,
      isEmpty,
      reason: 'ezek a sorok angol módban is magyarul szóltak: ${stillHungarian.length}',
    );

    // ⚠️ Magyar módban a szótár NEM szól bele: a szöveg bájtazonos.
    AppStrings.setLanguage(AppLanguage.hu);
    final changed = <String>[
      for (final line in lines)
        if (AppStrings.tr(line) != line) line,
    ];
    expect(changed, isEmpty, reason: 'a magyar ág nem változhat');
  });

  test('az angol changelog a legfrissebb kiadást is lefedi', () {
    final newest = sortedChangelog(appChangelog).first;
    final english = dictionary.map((key, value) => MapEntry(key, '$value'));
    AppStrings.setEnglish(english);
    AppStrings.setLanguage(AppLanguage.en);

    for (final line in newest.changes) {
      expect(
        AppStrings.tr(line),
        isNot(line),
        reason: 'a legfrissebb kiadás (${newest.build}) sora magyar maradt',
      );
    }
  });

  test('FORRÁS-LINT: a Névjegy a fordítón át írja ki a sorokat', () {
    final about = File('lib/screens/more/about_screen.dart').readAsStringSync();

    expect(
      about.contains('Expanded(child: Text(change))'),
      isFalse,
      reason: 'a changelog sora nyersen ment ki — pont ez maradt magyarul',
    );
    expect(about.contains('Text(tr(context, change))'), isTrue);
    expect(
      about.contains(r"'Ehhez a verzióhoz ($currentBuild) még nincs kiadási jegyzet.'"),
      isFalse,
      reason: 'a verzió-interpoláció is sablonkulccsal fordul',
    );
    expect(
      about.contains("'Ehhez a verzióhoz ({n}) még nincs kiadási jegyzet.'"),
      isTrue,
    );
    expect(
      dictionary.containsKey('Ehhez a verzióhoz ({n}) még nincs kiadási jegyzet.'),
      isTrue,
    );
  });
}
