import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// **iOS + CI konfiguráció — forrás-lint.**
///
/// Az iOS-út előkészítése (2026-09-22) olyan szabályokat vezetett be, amelyek
/// **több fájlban egyszerre** élnek, és pont ezért tudnak csendben széthúzni:
///
///  * a **bundle ID** három helyen van (Xcode-projekt, Android `applicationId`,
///    `codemagic.yaml`) — ha bármelyik eltér, az aláírás vagy a feltöltés hal el;
///  * a **deployment target** két helyen (Xcode-projekt, `Podfile`);
///  * a **Flutter-verzió** két helyen (Codemagic, GitHub Actions) — ha a kettő
///    eltér, a CI más engine-nel fordít, mint amivel a kód készült.
///
/// Ez a teszt ezeket **nem külön-külön** ellenőrzi, hanem **egymáshoz** méri:
/// így nem tud elavulni akkor sem, ha holnap verziót léptetsz.
///
/// A második csoport azt őrzi, amit az App Store **hard blokkol**:
/// az 1024-es ikon **nem tartalmazhat alfa-csatornát**.
void main() {
  group('az iOS-azonosítók egy helyen élnek (nem tudnak széthúzni)', () {
    late String pbxproj;
    late String gradle;

    setUpAll(() {
      pbxproj = _read('ios/Runner.xcodeproj/project.pbxproj');
      gradle = _read('android/app/build.gradle.kts');
    });

    test('a bundle ID ugyanaz az Xcode-projektben, az Androidban és a CI-ben', () {
      final xcodeIds = RegExp(r'PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);')
          .allMatches(pbxproj)
          .map((m) => m.group(1)!.trim())
          // A tesztek saját azonosítója a fő azonosító + ".RunnerTests".
          .map((id) => id.endsWith('.RunnerTests')
              ? id.substring(0, id.length - '.RunnerTests'.length)
              : id)
          .toSet();
      expect(
        xcodeIds,
        {'hu.hungarianhardstyle.app'},
        reason: 'a `com.example.*` bundle ID-val nem lehet App Store-ba feltölteni',
      );

      final androidId =
          RegExp(r'applicationId = "([^"]+)"').firstMatch(gradle)!.group(1);
      final ciId = RegExp(r'bundle_identifier: (\S+)')
          .firstMatch(_read('codemagic.yaml'))!
          .group(1);

      expect(androidId, xcodeIds.single,
          reason: 'egy termék, egy azonosító — az Android és az iOS nem térhet el');
      expect(ciId, xcodeIds.single,
          reason: 'a CI-nek pont azt a bundle ID-t kell aláírnia, ami a projektben van');
    });

    test('a deployment target egyezik a Xcode-projekt és a Podfile között', () {
      final xcodeTargets = RegExp(r'IPHONEOS_DEPLOYMENT_TARGET = ([\d.]+);')
          .allMatches(pbxproj)
          .map((m) => m.group(1)!)
          .toSet();
      expect(xcodeTargets, {'15.0'},
          reason: 'a Flutter 3.47 sablonja és migrációja is 15.0');

      final podTarget = RegExp(r"platform :ios, '([\d.]+)'")
          .firstMatch(_read('ios/Podfile'))!
          .group(1);
      expect(podTarget, xcodeTargets.single,
          reason: 'a `pod install` ne találgasson más platform-verziót');

      expect(
        _read('ios/Flutter/AppFrameworkInfo.plist'),
        isNot(contains('<key>MinimumOSVersion</key>')),
        reason: 'a Flutter migrációja eltávolítja — ne hozzuk vissza',
      );
    });

    test('a CI-k ugyanazt a Flutter-verziót használják, és az rögzített', () {
      final codemagic = _read('codemagic.yaml');
      final workflow = _read('.github/workflows/ios-unsigned-check.yml');

      final codemagicVersions = RegExp(r'^\s*flutter: (\S+)$', multiLine: true)
          .allMatches(codemagic)
          .map((m) => m.group(1)!)
          .toSet();
      expect(codemagicVersions, isNotEmpty,
          reason: 'a Codemagicban rögzíteni kell a Flutter-verziót');

      final workflowVersion =
          RegExp(r'flutter-version: (\S+)').firstMatch(workflow)!.group(1);

      expect(codemagicVersions.single, workflowVersion,
          reason: 'a két CI nem fordíthat más engine-nel');
      expect(
        workflowVersion,
        isNot(anyOf('stable', 'latest', 'master', 'beta')),
        reason: 'a mozgó verzió nem reprodukálható buildet ad',
      );
    });
  });

  group('amit az App Store megkövetel', () {
    test('az 1024-es ikon NEM tartalmaz alfa-csatornát', () {
      final bytes =
          File('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png')
              .readAsBytesSync();
      expect(bytes.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10],
          reason: 'ez nem PNG');

      int be32(int offset) =>
          (bytes[offset] << 24) |
          (bytes[offset + 1] << 16) |
          (bytes[offset + 2] << 8) |
          bytes[offset + 3];

      expect(be32(16), 1024);
      expect(be32(20), 1024);
      expect(bytes[24], 8, reason: 'bitmélység');
      expect(
        bytes[25],
        isNot(6),
        reason: 'az App Store elutasítja az átlátszó/alfa-csatornás 1024-es ikont '
            '(color type 6 = RGBA); a javítás feketére lapítja a sarkokat',
      );
    });

    test('a hatter-audio, az ATT es az export-compliance be van allitva', () {
      final plist = _read('ios/Runner/Info.plist');

      expect(plist, contains('<key>UIBackgroundModes</key>'),
          reason: 'enelkul a radio es a zene nem szol hatterben iOS-en');
      expect(plist, contains('<string>audio</string>'));
      expect(plist, contains('<key>NSUserTrackingUsageDescription</key>'),
          reason: 'iOS 14.5+ ota az AdMob csak ATT-engedellyel kérhet');
      expect(plist, contains('<key>ITSAppUsesNonExemptEncryption</key>'));
      expect(plist, contains('<key>GADApplicationIdentifier</key>'));
      expect(plist, contains('ca-app-pub-'),
          reason: 'AdMob app ID nelkul az SDK nem indul el');
    });

    test('a tamogatott eszkozok kore rogzitett (iPad-dontes)', () {
      // A tulajdonos dontese (2026-09-22): marad az iPhone + iPad.
      // ⚠️ Ez App Store-kovetkezmennyel jar: iPad-kepernyokepek is kellenek.
      expect(
        _read('ios/Runner.xcodeproj/project.pbxproj'),
        contains('TARGETED_DEVICE_FAMILY = "1,2";'),
        reason: 'a dontes iPhone + iPad (1,2). Ha ez valtozik (csak iPhone: 1), '
            'az App Store kepernyokep-kovetelmenye is valtozik — ezert nem '
            'valtozhat csendben',
      );
    });
  });

  group('a CI-pipeline lepesei', () {
    test('a Codemagic alairt ipat epit es TestFlightra tolt', () {
      final yaml = _read('codemagic.yaml');

      expect(yaml, contains('ios-unsigned-check'),
          reason: 'alairas nelkuli ellenorzes Apple-fiok nelkul is');
      expect(yaml, contains('ios-testflight'));
      expect(yaml, contains('flutter build ios --release --no-codesign'));
      expect(yaml, contains('xcode-project use-profiles'),
          reason: 'a provisioning profile-t ra kell tenni a projekt-re');
      expect(yaml, contains('flutter build ipa'));
      expect(yaml, contains('app_store_connect: HUHS_APPLE'),
          reason: 'a Developer Portal integracio neve pontosan ez');
      expect(yaml, contains('submit_to_testflight: true'));
      expect(yaml, contains('GOOGLE_SERVICE_INFO_PLIST_BASE64'),
          reason: 'a firebase_core iOS-en a bundle-bol olvassa a plistet');
    });

    test('a GitHub Actions az iOS-fordulast ellenorzi, nem tolt fel', () {
      final workflow = _read('.github/workflows/ios-unsigned-check.yml');

      expect(workflow, contains('runs-on: macos-'));
      expect(workflow, contains('flutter analyze'));
      expect(workflow, contains('flutter build ios --release --no-codesign'));
      expect(
        workflow,
        isNot(contains('app_store_connect')),
        reason: 'a feltoltes a Codemagic dolga: ott van a tanusítvány',
      );
      // A lepesek sorrendje szandekos: az iOS-forditas elobb, mint a tesztek,
      // hogy egy platformfuggo teszthiba ne rejtse el az iOS-eredmenyt.
      expect(
        workflow.indexOf('flutter build ios --release --no-codesign'),
        lessThan(workflow.indexOf('\n        run: flutter test')),
        reason: 'az iOS-forditas legyen a tesztkeszlet elott',
      );
    });
  });
}

String _read(String path) =>
    File(path).readAsStringSync().replaceAll('\r\n', '\n');
