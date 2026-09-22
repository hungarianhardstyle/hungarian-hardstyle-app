import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// **App Check platformonként — és az Android útjának zárja.**
///
/// A mért éles hiba (2026-09-22, a telefon naplójából):
///
///     AppCheck failed: '...The server responded with an error:
///      - URL: .../apps/1:1030187737487:ios:0ceb5a9685b34b5f78ebfa:exchangeDeviceCheckToken
///
/// Az ok **kétrétű**, és mindkettő mérve van:
///
///  1. az `activate()` iOS-en alapból `AppleProvider.deviceCheck`-et használ
///     (ez az enum alapértéke a `firebase_app_check` csomagban), és **ehhez az
///     apphoz nem volt regisztrálva szolgáltató** → a szerver elutasította;
///  2. a regisztrációhoz **Apple Developer fiók kell**: az App Check API szerint
///     a DeviceCheck konfighoz `keyId` **és** `privateKey` (`.p8`) kötelező.
///
/// Ezért a sideloadolt teszt-build a **`debug` szolgáltatót** használja — az az
/// egyetlen út, ami Apple-fiók nélkül is működik (Androidon debugban ugyanez
/// megy). Az éles iOS build (Codemagic → TestFlight) **nem** kapja meg a
/// zászlót: ott App Attest a helyes út, regisztrált szolgáltatóval.
void main() {
  String read(String path) =>
      File(path).readAsStringSync().replaceAll('\r\n', '\n');

  group('az Android App Check-útja VÁLTOZATLAN', () {
    test('az androidProvider kifejezése bitre a régi', () {
      final main = read('lib/main.dart');
      expect(
        main,
        contains(
          'androidProvider: kDebugMode\n'
          '          ? AndroidProvider.debug\n'
          '          : AndroidProvider.playIntegrity,',
        ),
        reason: 'az Android útja nem változhat: debug → debug, release → '
            'Play Integrity (ez regisztrálva van, és élesben működik)',
      );
    });

    test('az iOS-ág KÜLÖN paraméter, nem írja át az Androidét', () {
      final main = read('lib/main.dart');
      expect(main, contains('appleProvider: _appleAppCheckProvider'));
      expect(
        main,
        contains("'HUHS_APP_CHECK_DEBUG_IOS'"),
        reason: 'a zászló neve a CI-vel egyezzen',
      );
      expect(
        main,
        contains("defaultValue: false"),
        reason: 'alapból NEM debug — az éles build ne csússzon bele',
      );
    });

    test('az iOS-szolgáltató kiválasztása a két helyes értéket használja', () {
      final main = read('lib/main.dart');
      expect(main, contains('AppleProvider.debug'));
      expect(
        main,
        contains('AppleProvider.appAttestWithDeviceCheckFallback'),
        reason: 'élesben App Attest, DeviceCheck visszaeséssel',
      );
      // A tartósan beégetett deviceCheck NEM lehet a választás: pont az volt a hiba.
      expect(
        main,
        isNot(contains('AppleProvider.deviceCheck,')),
        reason: 'a csupasz DeviceCheck az alapérték volt — az nem elég',
      );
    });
  });

  group('a CI a TESZT-buildnek adja a zászlót', () {
    test('a sideload workflow átadja a dart-define-t', () {
      final workflow = read('.github/workflows/ios-unsigned-check.yml');
      expect(
        workflow,
        contains('--dart-define=HUHS_APP_CHECK_DEBUG_IOS=true'),
        reason: 'enélkül a sideloadolt build az éles (regisztrálatlan) utat '
            'járná, és az App Check-kel védett hívások elutasításra kerülnének',
      );
    });

    test('a TestFlight-build (Codemagic) NEM kapja meg a zászlót', () {
      final codemagic = read('codemagic.yaml');
      expect(
        codemagic,
        isNot(contains('HUHS_APP_CHECK_DEBUG_IOS')),
        reason: 'az éles iOS build ne használjon debug szolgáltatót',
      );
    });
  });
}
