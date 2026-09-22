import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// **iOS + CI konfiguráció — forrás-lint.**
///
/// Az iOS-út előkészítése (2026-09-22) olyan szabályokat vezetett be, amelyek
/// **több fájlban egyszerre** élnek, és pont ezért tudnak csendben széthúzni:
///
///  * a **bundle ID** három helyen van (Xcode-projekt, Android `applicationId`,
///    `codemagic.yaml`) — ha bármelyik eltér, az aláírás vagy a feltöltés hal el;
///  * a **deployment target** egy helyen él (Xcode-projekt) — a projekt
///    **Swift Package Manager**-t használ, ezért **Podfile nem lehet** benne;
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

    test('a deployment target a Xcode-projektben él (SPM, nem CocoaPods)', () {
      final xcodeTargets = RegExp(r'IPHONEOS_DEPLOYMENT_TARGET = ([\d.]+);')
          .allMatches(pbxproj)
          .map((m) => m.group(1)!)
          .toSet();
      expect(xcodeTargets, {'15.0'},
          reason: 'a Flutter 3.47 sablonja és migrációja is 15.0');

      // ⚠️ MÉRT ÉLES HIBA (GitHub Actions run #1, 2026-09-22): amikor egy
      // Podfile került a repóba, a Flutter ráfogta a CocoaPods utat egy
      // SPM-alapú projektre, és a build elhasalt:
      //   "All plugins found for ios are Swift Packages, but your project still
      //    has CocoaPods integration. Your project uses a non-standard Podfile"
      //   "Error (Xcode): The sandbox is not in sync with the Podfile.lock."
      // Ezért a Podfile HIÁNYA itt nem hiányosság, hanem a működés feltétele:
      // az összes iOS-plugin Swift Package-ként jön.
      expect(File('ios/Podfile').existsSync(), isFalse,
          reason: 'a projekt Swift Package Manager-t használ — egy Podfile '
              'CocoaPods integrációt kényszerít rá, és elhasal tőle a build');

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

    test('az iOS reklam-egysegazonositok GitHub-valtozokbol jonnek', () {
      final workflow = _read('.github/workflows/ios-unsigned-check.yml');
      final ads = _read('lib/providers/ads_provider.dart');

      // ⚠️ MIÉRT `vars.*`: így a valódi iOS egység-azonosítók bevezetése
      // **nem kér kódmódosítást**, és beállítatlanul **üres string** marad —
      // azaz pontosan a mai, biztonságos viselkedés él tovább (a Google
      // hivatalos teszt-egységei). Ha valaki beégetné az éles azonosítót,
      // ez a teszt elhasal.
      for (final name in const [
        'HUHS_ADMOB_BANNER_ID_IOS',
        'HUHS_ADMOB_REWARDED_ID_IOS',
      ]) {
        expect(
          workflow,
          contains('--dart-define=$name=\${{ vars.$name }}'),
          reason: 'a(z) $name a CI-ből, GitHub-változóból jöjjön (nem beégetve)',
        );
        expect(
          ads,
          contains("String.fromEnvironment('$name')"),
          reason: 'a(z) $name nevet a kliens is pontosan így olvassa',
        );
      }

      // ⚠️ A debug App Check-szolgáltató KIZÁRÓLAG a sideloadolt teszt-buildbe
      // való: a produkciós (TestFlight) build App Attest-tel megy, különben egy
      // éles appban a debug szolgáltató ütné ki az attestation-t.
      expect(workflow, contains('HUHS_APP_CHECK_DEBUG_IOS=true'),
          reason: 'a sideloadolt teszt-build igenis kapja meg');
      expect(
        _read('codemagic.yaml'),
        isNot(contains('HUHS_APP_CHECK_DEBUG_IOS')),
        reason: 'a TestFlight-build NEM kaphat debug App Check-szolgáltatót',
      );

      // ⚠️ Ugyanez a minta a reklámoknál: a sideloadolt TESZT-buildnek
      // garantáltan töltő reklám kell (különben a jutalmazott feloldás nem is
      // próbálható), a produkciós build viszont a VALÓDI egységekkel megy.
      expect(workflow, contains('HUHS_ENABLE_TEST_ADS=true'),
          reason: 'a sideloadolt build teszt-reklámot használjon: a valódi iOS '
              'egységek az AdMob-jóváhagyásig nem töltenek, és ilyenkor a '
              'jutalmazott feloldás el sem indul');
      expect(
        _read('codemagic.yaml'),
        isNot(contains('HUHS_ENABLE_TEST_ADS')),
        reason: 'a kiadott app nem használhat teszt-reklámot',
      );
    });

    test('az iOS reklam-identitas valodi (a Google TESZT app ID nem mehet ki)', () {
      // A tulajdonos AdMob konzoljából (2026-09-22). Ezek **nyilvános**
      // azonosítók (a kész binárisban úgyis benne vannak), nem titkok — de
      // attól még pontosan egy helyen kell élniük, és a teszt app ID nem
      // szivároghat ki a kiadott csomagba.
      const appId = 'ca-app-pub-7714662594685378~6550697484';
      const bannerId = 'ca-app-pub-7714662594685378/5511193968';
      const rewardedId = 'ca-app-pub-7714662594685378/7238016636';
      const googleTestAppId = 'ca-app-pub-3940256099942544~1458002511';

      // ⚠️ Az ÉRTÉKET mérjük, nem a fájl szövegét: a teszt app ID-t a
      // figyelmeztető komment szándékosan megemlíti, az nem hiba.
      final gad = RegExp(r'<key>GADApplicationIdentifier</key>\s*<string>([^<]+)</string>')
          .firstMatch(_read('ios/Runner/Info.plist'))
          ?.group(1);
      expect(gad, appId,
          reason: 'az iOS AdMob app ID az Info.plist-ben él — és ez a VALÓDI');
      expect(gad, isNot(googleTestAppId),
          reason: 'a Google teszt app ID-ja nem kerülhet kiadott buildbe');

      final appIds = RegExp(r'ca-app-pub-\d+~\d+').allMatches(appId).length;
      expect(appIds, 1, reason: 'az app ID alakja `…~…`, az egységé `…/…`');

      final codemagic = _read('codemagic.yaml');
      for (final id in [bannerId, rewardedId]) {
        expect(codemagic, contains(id),
            reason: 'a TestFlight-build is a VALÓDI iOS egységekkel induljon '
                '(különben a kiadott app a teszt-egységeket használná)');
      }

      // ⚠️ A sideloadolt (teszt-reklámos) csomag ellenőrzése `--test-ads`-szal
      // fut, a produkciós pedig a VALÓDI értékekkel — a kettő nem csúszhat el.
      final workflow = _read('.github/workflows/ios-unsigned-check.yml');
      expect(workflow, contains('--test-ads'),
          reason: 'a sideloadolt build a teszt-egységeket méri');
      expect(codemagic, contains('verify-ios-ipa.mjs'),
          reason: 'a TestFlight-csomag is legyen lemérve, ne csak a sideloadolt');

      // A verifier aláértéke egyezzen a codemagic.yaml beépített értékeivel,
      // különben a produkciós ellenőrzés mást mérne, mint amit valójában építünk.
      final verifier = _read('tools/verify-ios-ipa.mjs');
      for (final name in ['BANNER', 'REWARDED']) {
        final fromYaml = RegExp('HUHS_ADMOB_${name}_ID_IOS:-([^}]+)\\}')
            .firstMatch(codemagic)!
            .group(1)!
            .trim();
        final fromTool =
            RegExp("DEFAULT_$name = '([^']+)'").firstMatch(verifier)!.group(1)!;
        expect(fromTool, fromYaml,
            reason: 'a verifier a $name értékét ugyanúgy várja, mint a CI építi');
      }
    });
  });
}

String _read(String path) =>
    File(path).readAsStringSync().replaceAll('\r\n', '\n');
