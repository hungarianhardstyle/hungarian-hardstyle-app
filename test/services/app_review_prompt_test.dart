import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hungarian_hardstyle_app/services/app_review_prompt.dart';

/// **A Play-értékelés kérése** — az „egyszer, telepítésenként" szabály mérése.
///
/// MIÉRT: a Google irányelve (és a Play felülvizsgálata) szerint a rétegzett
/// értékelés-kérés **nem ismételhető** korlátlanul. A jelölés ezért a
/// `SharedPreferences`-be kerül, és **a hívás előtt** íródik ki — így akkor is
/// garantált az egyszeri kérés, ha a Play-hívás közben megszakad a folyamat.
///
/// ⚠️ A kérés **soha** nem blokkolhat és **soha** nem dobhat: ezért a teszt
/// külön méri a hibaágakat (nem elérhető szolgáltatás, dobó hívás).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SharedPreferences> preferencesWith([
    Map<String, Object> values = const {},
  ]) async {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferences.getInstance();
  }

  group('a tiszta döntés', () {
    test('friss telepítésnél kérünk', () {
      expect(shouldRequestAppReview(alreadyRequested: false), isTrue);
    });

    test('a már megkérdezett telepítésnél nem kérünk', () {
      expect(shouldRequestAppReview(alreadyRequested: true), isFalse);
    });
  });

  group('a kérés lefutása', () {
    test('az első hívás elindítja a Play-értékelést, és megjelöli', () async {
      final preferences = await preferencesWith();
      var reviewCalls = 0;

      final started = await AppReviewPrompt.requestOnce(
        preferences: preferences,
        isAvailable: () async => true,
        requestReview: () async => reviewCalls += 1,
      );

      expect(started, isTrue);
      expect(reviewCalls, 1);
      expect(preferences.getBool(appReviewRequestedKey), isTrue);
    });

    test('a MÁSODIK hívás már nem indít semmit (at most once)', () async {
      final preferences = await preferencesWith();
      var reviewCalls = 0;

      await AppReviewPrompt.requestOnce(
        preferences: preferences,
        isAvailable: () async => true,
        requestReview: () async => reviewCalls += 1,
      );
      final second = await AppReviewPrompt.requestOnce(
        preferences: preferences,
        isAvailable: () async => true,
        requestReview: () async => reviewCalls += 1,
      );

      expect(second, isFalse);
      expect(reviewCalls, 1, reason: 'telepítésenként legfeljebb egyszer');
    });

    test('a korábbi (mentett) jelölés is blokkol', () async {
      final preferences = await preferencesWith({
        appReviewRequestedKey: true,
      });
      var reviewCalls = 0;

      final started = await AppReviewPrompt.requestOnce(
        preferences: preferences,
        isAvailable: () async => true,
        requestReview: () async => reviewCalls += 1,
      );

      expect(started, isFalse);
      expect(reviewCalls, 0);
    });

    test('ha a Play-értékelés nem elérhető, NEM hívunk (de megjelölünk)', () async {
      final preferences = await preferencesWith();
      var reviewCalls = 0;

      final started = await AppReviewPrompt.requestOnce(
        preferences: preferences,
        isAvailable: () async => false,
        requestReview: () async => reviewCalls += 1,
      );

      expect(started, isFalse);
      expect(reviewCalls, 0);
      // A jelölés akkor is kimegy: az „at most once" garancia az elsődleges.
      expect(preferences.getBool(appReviewRequestedKey), isTrue);
    });

    test('a Play-hívás hibája némán elnyelődik (nem dob tovább)', () async {
      final preferences = await preferencesWith();

      final started = await AppReviewPrompt.requestOnce(
        preferences: preferences,
        isAvailable: () async => true,
        requestReview: () async => throw StateError('nincs Play Áruház'),
      );

      expect(started, isFalse);
      expect(preferences.getBool(appReviewRequestedKey), isTrue);
    });

    test('az elérhetőség-ellenőrzés hibája sem dob tovább', () async {
      final preferences = await preferencesWith();

      final started = await AppReviewPrompt.requestOnce(
        preferences: preferences,
        isAvailable: () async => throw StateError('nincs platform'),
        requestReview: () async {},
      );

      expect(started, isFalse);
    });

    test('a „pozitív pillanat" indítása sem dob, ha minden hibázik', () async {
      // A hívó `unawaited`-tel indítja — a hibának itt kell eltűnnie.
      await AppReviewPrompt.requestAfterPositiveMoment(
        preferences: await preferencesWith(),
        isAvailable: () async => throw StateError('hiba'),
        requestReview: () async => throw StateError('hiba'),
      );
      // Ha idáig eljutottunk, a kérés nem dobott tovább.
      expect(true, isTrue);
    });
  });

  /// **Forrás-lint:** a hívás a kiválasztott pozitív pillanathoz van kötve.
  ///
  /// A döntés indoklása a szolgáltatás fejlécében él (a pont-események
  /// aszinkronok, az esemény-értékelés szinkron és egyértelműen sikeres).
  group('a hívás helye (forrás-lint)', () {
    test('a sikeres esemény-értékelés indítja (és csak az)', () {
      final source = File(
        'lib/screens/events/event_detail_screen.dart',
      ).readAsStringSync();
      expect(
        source.contains('AppReviewPrompt.requestAfterPositiveMoment'),
        isTrue,
        reason: 'a sikeres értékelés ágában kell indulnia',
      );
      expect(
        RegExp(
          r'AppReviewPrompt\.requestAfterPositiveMoment',
        ).allMatches(source).length,
        1,
        reason: 'egyetlen hívó hely — ne szaporodhasson el',
      );
    });

    test('a kérés a mentett jelölést használja', () {
      final source = File(
        'lib/services/app_review_prompt.dart',
      ).readAsStringSync();
      expect(source.contains(appReviewRequestedKey), isTrue);
      // A jelölés a hívás ELŐTT megy ki („at most once" versenyhelyzet ellen).
      expect(
        source.indexOf('setBool(appReviewRequestedKey') <
            source.indexOf('_isAvailable'),
        isTrue,
      );
    });
  });
}
