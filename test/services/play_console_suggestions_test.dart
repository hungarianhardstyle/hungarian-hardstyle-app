import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// **A Play Console két „javasolt" jelzése** (2026-09-27, képernyőkép).
///
/// A tulajdonos jelezte: *„3 művelet javasolt … Előfordulhat, hogy a teljes
/// képernyős mód nem jelenik meg minden felhasználónál … Az alkalmazásod elavult
/// API-kat vagy paramétereket használ a teljes képernyős megjelenítéshez"*.
///
/// **A MÉRÉS** (`tmp/probe-play-suggestions.mjs`, a 376-os AAB DEX-ében):
/// * `enableEdgeToEdge: 0`, `EdgeToEdge: 0` — a hívás **benne van** a kódban
///   (`MainActivity.onCreate`), de az R8 a `-repackageclasses ''` +
///   `-allowaccessmodification` mellett **beinlajnolta/átnevezte**, ezért a Play
///   statikus szkennere **nem látja**;
/// * az „elavult API-k" (`setStatusBarColor`, `setNavigationBarColor`,
///   `setSystemUiVisibility`, `setDecorFitsSystemWindows`) a csomagolt
///   **könyvtárakból** jönnek (mért tulajdonos:
///   `com.google.android.play.core.common.PlayCoreDialogWrapperActivity` és
///   újracsomagolt androidx-osztályok) — a saját kódunk nem hívja őket.
///
/// A javítás: a `proguard-rules.pro` **megtartja** az `androidx.activity.EdgeToEdge`
/// definíciót, így a hívás neve a csomagban marad, és a szkenner látja.
void main() {
  final proguard = File('android/app/proguard-rules.pro').readAsStringSync();
  final activity = File(
    'android/app/src/main/kotlin/hu/hungarianhardstyle/app/MainActivity.kt',
  ).readAsStringSync();
  final manifest = File(
    'android/app/src/main/AndroidManifest.xml',
  ).readAsStringSync();

  test('az app kéri a teljes képernyős módot (enableEdgeToEdge)', () {
    expect(
      activity.contains('enableEdgeToEdge()'),
      isTrue,
      reason: 'a MainActivity.onCreate hívja az AndroidX szabványos hívását',
    );
    expect(
      activity.contains('import androidx.activity.enableEdgeToEdge'),
      isTrue,
      reason: 'a hívás az AndroidX-ből jön, nem saját ablak-manipuláció',
    );
  });

  test('a ProGuard megtartja az EdgeToEdge definíciót (a szkenner lássa)', () {
    expect(
      proguard.contains('-keep class androidx.activity.EdgeToEdge'),
      isTrue,
      reason:
          'R8 nélküle beinlajnolja/átnevezi, és a Play nem látja a hívást '
          '(mért: 0 találat a 376-os DEX-ben)',
    );
    // A mért JVM-név (`enable`/`enable$default`) is megmaradjon — így a hívás
    // tényleg felismerhető a DEX-ből.
    expect(
      proguard.contains('public static void enable('),
      isTrue,
      reason: 'a metódusnév is megmaradjon (mért név: enable)',
    );
  });

  test('nem kapcsoljuk ki a teljes képernyős módot', () {
    // A kikapcsoló zászló (Android 15 átmeneti mentőöv) szándékosan NINCS bent:
    // a cél-SDK 36-on az Android amúgy is kikényszeríti.
    expect(
      manifest.contains('windowOptOutEdgeToEdgeEnforcement'),
      isFalse,
      reason: 'a kikapcsolás pont azt jelentené, hogy „nem jelenik meg mindenkinél"',
    );
  });

  test('a saját kódunk nem használ elavult ablak-API-t', () {
    for (final path in [
      'android/app/src/main/kotlin/hu/hungarianhardstyle/app/MainActivity.kt',
      'android/app/src/main/kotlin/hu/hungarianhardstyle/app/RadioPlaybackService.kt',
    ]) {
      final source = File(path).readAsStringSync();
      for (final deprecated in [
        'setStatusBarColor',
        'setNavigationBarColor',
        'setSystemUiVisibility',
        'setDecorFitsSystemWindows',
      ]) {
        expect(
          source.contains(deprecated),
          isFalse,
          reason: '$path: $deprecated (elavult ablak-API)',
        );
      }
    }
  });
}
