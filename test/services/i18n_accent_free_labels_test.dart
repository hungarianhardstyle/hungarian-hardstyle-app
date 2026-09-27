import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/core/errors/user_facing_error.dart';
import 'package:hungarian_hardstyle_app/core/i18n/app_language.dart';
import 'package:hungarian_hardstyle_app/core/i18n/app_strings.dart';
import 'package:hungarian_hardstyle_app/models/label_library.dart';
import 'package:hungarian_hardstyle_app/services/newsletter_plan.dart';

/// **Az „ékezet nélkül is magyar" feliratok** és a **kivétel-üzenetek** nyelve.
///
/// A tulajdonos jelzése (2026-09-27): *„mintha itt még lenne magyar szöveg"* a
/// „Saját zenéim" listában — a szöveg **`WAV (ingyenes)`** volt. Ez azért maradt
/// bent a 374-es kör zöld kapui mellett, mert **nincs ékezet**, és mert a
/// **modellben** (`lib/models/label_library.dart`) él, amit a szonda akkor még
/// nem vizsgált.
///
/// Ugyanebben a körben derült ki, hogy a **kivétel-üzenetek** (`StateError`,
/// `ArgumentError`) és a `userFacingError()` általános szövegei is **magyarul**
/// mentek ki angol felületen: ezeket egyetlen korábbi kapu sem látta, mert nem
/// feliratok, hanem **üzenetek**.
void main() {
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

  void enableEnglish() {
    AppStrings.setEnglish(
      dictionary.map((key, value) => MapEntry(key, '$value')),
    );
    AppStrings.setLanguage(AppLanguage.en);
  }

  group('a változat-nevek („WAV (ingyenes)") fordulnak', () {
    test('a magyar címke a szótár kulcsa, és angolul szól', () {
      expect(labelVariantLabel('free_wav'), 'WAV (ingyenes)');
      expect(dictionary['WAV (ingyenes)'], 'WAV (free)');
    });

    test('a többi változatnév nyelvfüggetlen (nem kell fordítás)', () {
      for (final variant in [
        'radio_wav',
        'radio_mp3_320',
        'extended_wav',
        'extended_mp3_320',
        'wav',
        'mp3_320',
        'mp3_128',
        'mp3_96',
      ]) {
        final label = labelVariantLabel(variant);
        expect(
          label,
          isNot(contains('ingyenes')),
          reason: '$variant: ne legyen benne magyar szó',
        );
      }
    });

    test('angol módban a lejátszó felirata is angol', () {
      const entry = LabelQueueEntry(
        releaseId: 1,
        title: 'Goze — TikaTika',
        artist: 'Goze',
        coverUrl: '',
        variant: 'free_wav',
      );
      AppStrings.setLanguage(AppLanguage.hu);
      expect(entry.nowPlayingLabel, 'Goze — TikaTika — WAV (ingyenes)');

      enableEnglish();
      expect(entry.nowPlayingLabel, 'Goze — TikaTika — WAV (free)');
    });
  });

  group('a kivétel-üzenetek a választott nyelven szólnak', () {
    test('StateError üzenete fordul (a `userFacingError` a kapu)', () {
      AppStrings.setLanguage(AppLanguage.hu);
      expect(
        userFacingError(StateError('A beszélgetés törléséhez bejelentkezés szükséges.')),
        'A beszélgetés törléséhez bejelentkezés szükséges.',
      );

      enableEnglish();
      expect(
        userFacingError(StateError('A beszélgetés törléséhez bejelentkezés szükséges.')),
        'You need to sign in to delete the conversation.',
      );
    });

    test('az általános (kód-alapú) üzenetek is fordulnak', () {
      enableEnglish();
      expect(
        userFacingError(Exception('network-request-failed')),
        'Could not connect. Check your internet connection.',
      );
      expect(
        userFacingError(Exception('permission-denied')),
        'You do not have permission for this action.',
      );
    });

    test('a hírlevél-visszajelzés (sablonnal) is angol', () {
      enableEnglish();
      expect(
        newsletterMessage(
          const NewsletterResult(outcome: NewsletterOutcome.confirmationSent),
        ),
        startsWith('We have sent the confirmation e-mail'),
      );
      expect(
        newsletterMessage(
          const NewsletterResult(
            outcome: NewsletterOutcome.confirmationPending,
            retryAfterSeconds: 900,
          ),
        ),
        allOf(
          contains('Check your inbox'),
          contains('try again in about 15 minutes.'),
        ),
      );
    });
  });

  group('FORRÁS-LINT: a felületi üzenetek forrása', () {
    test('a `userFacingError` egy helyen fordít (nincs nyers kiút)', () {
      final source = File(
        'lib/core/errors/user_facing_error.dart',
      ).readAsStringSync();
      expect(source, contains('String userFacingError(Object? error) =>'));
      expect(source, contains('AppStrings.tr(_hungarianUserFacingError(error))'));
      expect(source, contains('String _hungarianUserFacingError(Object? error) {'));
    });

    test('a lejátszó metaadata és a lista is fordítja a változatnevet', () {
      final screen = File(
        'lib/screens/more/my_music_screen.dart',
      ).readAsStringSync();
      expect(screen, contains('album: AppStrings.tr(entry.variantLabel)'));
      expect(screen, contains('tr(context, item.entry.variantLabel)'));
      expect(screen, contains('tr(context, entry.variantLabel)'));
    });
  });

  group('LEfedettség: a modell- és szolgáltatás-szintű üzenetek kulcsai', () {
    test('minden ékezet NÉLKÜLI magyar címke a szótárban van', () {
      // A `WAV (ingyenes)` tanulsága: az ékezet-alapú szabály önmagában kevés.
      const accentFreeLabels = ['WAV (ingyenes)'];
      final missing = accentFreeLabels
          .where((key) => !dictionary.containsKey(key))
          .toList();
      expect(missing, isEmpty, reason: 'hiányzó kulcs(ok): $missing');
    });

    test('a gyakori hibaüzenetek mind fordíthatók', () {
      const frequentMessages = [
        'A beszélgetés törléséhez bejelentkezés szükséges.',
        'Az üzenet 1–2000 karakter lehet.',
        'A felhasználó nem található.',
        'Érvénytelen címzett.',
        'A kép feltöltése sikertelen.',
        'Csak admin törölhet Chat-üzenetet.',
        'Nincs törölhető profil.',
        'A zenék letöltéséhez be kell jelentkezni.',
      ];
      final missing = frequentMessages
          .where((key) => !dictionary.containsKey(key))
          .toList();
      expect(missing, isEmpty, reason: 'hiányzó kulcs(ok): $missing');
    });
  });
}
