/// **Egyetlen Play-értékelés-kérés**, egy pozitív pillanatban.
///
/// MIÉRT EZ A PILLANAT (a döntés indoklása): a tulajdonos két helyet kínált — a
/// sikeres achipont-eseményt vagy a sikeres esemény-értékelést. Az
/// **esemény-értékelést** választottam, mert az a legbiztonságosabb és
/// leginkább „pozitív" horgony:
///   * **szinkron és egyértelmű siker**: a `rateEvent()` hívás visszatér, és a
///     felület már ma is egy „Köszönjük az értékelést!" üzenetet mutat — a
///     kérés pontosan ugyanabba a pillanatba kerül, nem kell stream-figyelés;
///   * **a pont-események aszinkronok** (szerveroldali jóváírás, több
///     értesítés-típus, hálózati újrapróbák), ezért ott a kérés vagy elmaradna,
///     vagy rossz pillanatban (pl. hibás körben) indulna el;
///   * **a felhasználó épp pozitívumot fejezett ki** (csillagokat adott), ez a
///     Google irányelvei szerinti „jó pillanat" a rétegzett kérésre.
///
/// ⚠️ A KÉRÉS **SOHA** NEM BLOKKOL ÉS **SOHA** NEM DOB: a hívó `unawaited`-tel
/// indítja, a hibát pedig a szolgáltatás némán elnyeli. Egy értékelés-kérés nem
/// viheti el a felhasználó műveletét.
///
/// ⚠️ **LEGFELJEBB EGYSZER** telepítésenként: a jelölés a `SharedPreferences`-be
/// kerül, és **a hívás ELŐTT** íródik ki — így két egymásba futó hívás sem
/// tud kétszer kérni.
library;

import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A `SharedPreferences` kulcsa: már megkérdeztük-e az értékelést.
///
/// Verziózott (`_v1`), hogy egy későbbi, más alkalomhoz kötött kérésnél ne
/// kelljen a régi döntést felülírni.
const String appReviewRequestedKey = 'app_review_requested_v1';

/// **A döntés** — tiszta függvény, ezért teszttel mérhető: telepítésenként
/// legfeljebb egyszer kérünk értékelést.
bool shouldRequestAppReview({required bool alreadyRequested}) =>
    !alreadyRequested;

/// Az értékelés-kérés egyszeri lefuttatása.
class AppReviewPrompt {
  AppReviewPrompt._();

  /// Az értékelés kérése, ha még nem kértük.
  ///
  /// @return `true`, ha ebben a hívásban **el is indult** a Play-értékelés.
  ///
  /// Minden külső hívás injektálható (`isAvailable`, `requestReview`,
  /// `preferences`), ezért a folyamat plugin és `Firebase` nélkül,
  /// egységteszttel végigjárható.
  static Future<bool> requestOnce({
    SharedPreferences? preferences,
    Future<bool> Function()? isAvailable,
    Future<void> Function()? requestReview,
  }) async {
    SharedPreferences? prefs = preferences;
    try {
      prefs ??= await SharedPreferences.getInstance();
    } catch (_) {
      // Tároló nélkül is működik: legfeljebb nem jegyezzük meg a jelölést.
    }

    final alreadyRequested =
        prefs?.getBool(appReviewRequestedKey) ?? false;
    if (!shouldRequestAppReview(alreadyRequested: alreadyRequested)) {
      return false;
    }

    // ⚠️ A jelölés **ELŐRE** megy ki: ez az „at most once" garanciája akkor is,
    // ha a Play-hívás közben megszakad (pl. a felhasználó kilép).
    try {
      await prefs?.setBool(appReviewRequestedKey, true);
    } catch (_) {
      // A jelölés hibája nem akadályozhatja a kérést.
    }

    try {
      final available = await (isAvailable ?? _isAvailable)();
      if (!available) return false;
      await (requestReview ?? _requestReview)();
      return true;
    } catch (error) {
      // ⚠️ Némán elnyeljük: az értékelés-kérés kényelmi funkció, a felületen
      // soha nem látszhat belőle hiba.
      if (kDebugMode) {
        debugPrint('HUHS értékelés-kérés kihagyva: ${error.runtimeType}');
      }
      return false;
    }
  }

  /// A **pozitív pillanat** utáni indítás — a hívó `unawaited`-tel használja.
  static Future<void> requestAfterPositiveMoment({
    SharedPreferences? preferences,
    Future<bool> Function()? isAvailable,
    Future<void> Function()? requestReview,
  }) async {
    try {
      await requestOnce(
        preferences: preferences,
        isAvailable: isAvailable,
        requestReview: requestReview,
      );
    } catch (_) {
      // Védelem a védelemben: a hívó művelete semmiképp ne sérüljön.
    }
  }

  static Future<bool> _isAvailable() => InAppReview.instance.isAvailable();

  static Future<void> _requestReview() => InAppReview.instance.requestReview();
}
