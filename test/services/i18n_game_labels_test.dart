import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/core/i18n/app_language.dart';
import 'package:hungarian_hardstyle_app/core/i18n/app_strings.dart';

/// A **játék-eredmény** képernyő címkéi — a tulajdonos jelzése (2026-09-26):
/// *„a játék eredményei fejléc is magyar maradt, angolra kapcsolva"*.
///
/// **A MÉRT GYÖKÉR:** a címke a kódban **nyers** literál volt egy ternary ágában
/// (`widget.resultsOnly ? 'Játék eredményei' : game.title`), ezért
///  1. az i18n-extraktor **nem látta** (nem lett célzott szöveg),
///  2. a szótárban **nem volt** kulcs (a fordító így nem is érinthette),
///  3. angol módban a nyers magyar szöveg ment ki a képernyőre.
///
/// Ugyanez a hibaosztály volt a `home_screen.dart` kártya-jelvényénél
/// (`resultsOnly ? 'JÁTÉK EREDMÉNYEI' : tr(context, 'JÁTÉK')`) és a képernyő
/// további nyers szövegeinél (`Próbáld ki magad!`, a betöltési hibaüzenet, a
/// zárás-dátum zárójeles címkéje) — ez a teszt mindet őrzi.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final dictionary = jsonDecode(
    File('assets/i18n/en.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  setUp(() {
    AppStrings.setLanguage(AppLanguage.hu);
    AppStrings.setEnglish(null);
  });

  tearDown(() {
    AppStrings.setLanguage(AppLanguage.hu);
    AppStrings.setEnglish(null);
  });

  group('a játék-eredmény címkéi angolul is megjelennek', () {
    const keys = <String, String>{
      'Játék eredményei': 'Game results',
      'JÁTÉK EREDMÉNYEI': 'GAME RESULTS',
      'Próbáld ki magad!': 'Try it yourself!',
      'Az eredménylista most nem tölthető be.':
          "The results list can't be loaded right now.",
      'Az eredményeket a játék lezárása után láthatod{d}.':
          'You can see the results after the game closes{d}.',
      ' (eddig: {d})': ' (until {d})',
    };

    test('a szótárban valódi fordítás van (nem üres, nem a kulcs)', () {
      for (final entry in keys.entries) {
        final value = dictionary[entry.key];
        expect(
          value,
          isA<String>(),
          reason: 'hiányzik a(z) „${entry.key}" kulcs',
        );
        expect(
          (value as String).trim(),
          isNotEmpty,
          reason: 'a(z) „${entry.key}" fordítása üres',
        );
        expect(
          value,
          isNot(entry.key),
          reason: 'a(z) „${entry.key}" nincs lefordítva',
        );
      }
    });

    test('angol módban angolul, magyar módban változatlanul szól', () {
      final english = dictionary.map((key, value) => MapEntry(key, '$value'));
      AppStrings.setEnglish(english);

      AppStrings.setLanguage(AppLanguage.en);
      expect(AppStrings.tr('Játék eredményei'), 'Game results');
      expect(AppStrings.tr('JÁTÉK EREDMÉNYEI'), 'GAME RESULTS');
      expect(AppStrings.tr('Próbáld ki magad!'), 'Try it yourself!');
      expect(
        AppStrings.tr('Az eredménylista most nem tölthető be.'),
        "The results list can't be loaded right now.",
      );
      expect(
        AppStrings.trArgs(' (eddig: {d})', {'d': '2026. 09. 30. 23:59'}),
        ' (until 2026. 09. 30. 23:59)',
      );
      expect(
        AppStrings.trArgs('Az eredményeket a játék lezárása után láthatod{d}.', {
          'd': ' (until 2026. 09. 30. 23:59)',
        }),
        'You can see the results after the game closes (until 2026. 09. 30. 23:59).',
      );

      // ⚠️ Magyar módban a szótár NEM szól bele — a magyar szöveg bájtazonos.
      AppStrings.setLanguage(AppLanguage.hu);
      expect(AppStrings.tr('Játék eredményei'), 'Játék eredményei');
      expect(AppStrings.tr('Próbáld ki magad!'), 'Próbáld ki magad!');
      expect(
        AppStrings.trArgs(' (eddig: {d})', {'d': '2026. 09. 30. 23:59'}),
        ' (eddig: 2026. 09. 30. 23:59)',
      );
    });

    test('FORRÁS-LINT: a játék-képernyő egyetlen címkéje sem nyers', () {
      final game = File('lib/screens/games/game_screen.dart').readAsStringSync();

      // A fejléc (a tulajdonos jelzése) — a ternary ágában is fordítva.
      expect(
        game.contains("Text(widget.resultsOnly ? 'Játék eredményei'"),
        isFalse,
        reason: 'a fejléc nyers literál volt — pont ez maradt magyarul',
      );
      expect(game.contains("tr(context, 'Játék eredményei')"), isTrue);

      // A tárolt hibaüzenet a **szótári kulcsot** hordozza, a kiírás fordít.
      expect(
        game.contains("_resultsError = 'Az eredménylista most nem tölthető be.'"),
        isTrue,
        reason: 'a tárolt érték a szótári kulcs (különben beleragad a nyelv)',
      );
      expect(game.contains('Text(_resultsError!'), isFalse);
      expect(game.contains('Text(tr(context, _resultsError!)'), isTrue);

      // A zárás-dátum címkéje: nincs nyers interpolált szöveg, van sablon.
      expect(
        game.contains(
          r"'Az eredményeket a játék lezárása után láthatod${_resultsUntilLabel()}'",
        ),
        isFalse,
      );
      expect(
        game.contains("'Az eredményeket a játék lezárása után láthatod{d}.'"),
        isTrue,
      );
      expect(game.contains("trArgs(context, ' (eddig: {d})'"), isTrue);

      // A hero tartalék szövege is a fordítón megy át.
      expect(game.contains("Text(game.summary.isEmpty ? 'Próbáld ki magad!'"), isFalse);
      expect(game.contains("tr(context, 'Próbáld ki magad!')"), isTrue);
    });

    test('FORRÁS-LINT: a főoldali kártya „JÁTÉK EREDMÉNYEI" jelvénye is fordítva', () {
      final home = File('lib/screens/home/home_screen.dart').readAsStringSync();

      expect(
        home.contains("resultsOnly ? 'JÁTÉK EREDMÉNYEI'"),
        isFalse,
        reason: 'a jelvény nyers ternary-ága angol módban magyarul maradt',
      );
      expect(home.contains("tr(context, 'JÁTÉK EREDMÉNYEI')"), isTrue);
    });
  });

  /// **MÁSODIK MÉRT HIBAOSZTÁLY ebben a körben:** a futásidejű szótár
  /// (`AppStrings.parseEnglishDictionary`) a kulcsokat **`trim()`-eli**, ezért a
  /// „ szóközzel körbevett " kulcsokat a `tr(' szóközzel körbevett ')` hívás
  /// **soha nem találta meg** — a fordítás létezett, csak **elérhetetlen** volt.
  ///
  /// Mérve (`tmp/check-padded-keys-usage.mjs`): a szótárnak **15** ilyen kulcsa
  /// van, és **mind a 15** fordítás-hívásban áll (chat/hozzászólás előtag,
  /// adatvédelmi mondatok, „Unknown User ", a játék zárás-dátuma). Ütközés nincs
  /// (ugyanaz a vágott alak egyetlen másik kulcsra sem illeszkedik).
  group('a szótár minden kulcsa elérhető (a szóközzel körbevett kulcsok is)', () {
    test('MINDEN szótár-kulcs kiszolgálható angol módban', () {
      AppStrings.setEnglish(dictionary.map((key, value) => MapEntry(key, '$value')));
      AppStrings.setLanguage(AppLanguage.en);

      final unresolvable = <String>[
        for (final entry in dictionary.entries)
          if (AppStrings.tr(entry.key) != entry.value) entry.key,
      ];

      expect(
        unresolvable,
        isEmpty,
        reason:
            'ezek a kulcsok léteznek a szótárban, de a `tr()` nem találja meg '
            'őket (a kulcs és a vágott alak eltér): $unresolvable',
      );
    });

    test('a válasz-előnézet előtagjai (szóközzel) is angolul szólnak', () {
      AppStrings.setEnglish(dictionary.map((key, value) => MapEntry(key, '$value')));
      AppStrings.setLanguage(AppLanguage.en);

      expect(AppStrings.tr(' hozzászólására: '), "'s comment: ");
      expect(AppStrings.tr(' üzenetére: '), "'s message: ");
      expect(AppStrings.tr('Válasz: '), 'Reply: ');
      expect(AppStrings.tr('Unknown User '), 'Unknown User ');
    });

    test('a beviteli sáv válasz-előnézete sablonból fordul (nem nyers)', () {
      AppStrings.setEnglish(dictionary.map((key, value) => MapEntry(key, '$value')));
      AppStrings.setLanguage(AppLanguage.en);

      expect(
        AppStrings.trArgs('Válasz {name} hozzászólására: {text}', {
          'name': 'Teszt',
          'text': 'Szia!',
        }),
        "Reply to Teszt's comment: Szia!",
      );
      expect(
        AppStrings.trArgs('Válasz {name} üzenetére: {text}', {
          'name': 'Teszt',
          'text': 'Szia!',
        }),
        "Reply to Teszt's message: Szia!",
      );
      expect(
        AppStrings.trArgs('Válasz erre: {text}', {'text': 'Szia!'}),
        'Reply to this: Szia!',
      );

      final comments = File(
        'lib/widgets/article_comments.dart',
      ).readAsStringSync();
      final community = File(
        'lib/screens/community/community_screen.dart',
      ).readAsStringSync();

      expect(
        comments.contains(r"'Válasz $_replyToName hozzászólására: $_replyToText'"),
        isFalse,
        reason: 'a hozzászólás-válasz előnézete nyers volt',
      );
      expect(comments.contains(r"'Válasz {name} hozzászólására: {text}'"), isTrue);
      expect(comments.contains(r"'Válasz erre: {text}'"), isTrue);

      expect(
        community.contains(r"'Válasz $replyToName üzenetére: $replyToText'"),
        isFalse,
        reason: 'a chat-válasz előnézete nyers volt',
      );
      expect(community.contains(r"'Válasz {name} üzenetére: {text}'"), isTrue);
    });
  });
}
