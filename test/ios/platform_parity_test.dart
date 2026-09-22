import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// **Platform-paritás: mi közös, és mi kér külön iOS-deklarációt.**
///
/// A `lib/` **egy és ugyanaz** Androidon és iOS-en, ezért minden Dart-funkció
/// automatikusan megjelenik iOS-en is. A kockázat NEM itt van, hanem a
/// **platform-kötött rétegben**: a natív kódban, az engedélyekben és a
/// mélylinkekben. Ezek iOS-en **futásidőben** buknak meg — a CI csak lefordítja
/// a buildet, ezért csendben el lehet felejteni őket.
///
/// Ezt a teszt kód-szinten zárja le:
///
///  1. az Android-specifikus natív fájlok halmaza **rögzített** — új Kotlin
///     szolgáltatás esetén a teszt elhasal, és dönteni kell az iOS-oldalról;
///  2. a **social linkek visszaesése** megmarad (iOS-en ugyanaz a hívás
///     `universalLinksOnly`-ként fut, ezért gyakran `false`-t ad);
///  3. minden **engedélykérő csomaghoz** megvan a hozzá tartozó `Info.plist`
///     kulcs;
///  4. az **ismert iOS-hiányok** a dokumentumban is szerepelnek, tehát nem
///     tudnak csendben elfelejtődni.
void main() {
  group('a platform-kötött natív kód nem nőhet csendben', () {
    test('az Android-specifikus natív fájlok halmaza rögzített', () {
      final directory = Directory('android/app/src/main/kotlin');
      expect(directory.existsSync(), isTrue,
          reason: 'az Android-natív forrásmappa eltűnt');

      final nativeFiles = directory
          .listSync(recursive: true)
          .whereType<File>()
          .map((file) => file.uri.pathSegments.last)
          .where((name) => name.endsWith('.kt') || name.endsWith('.java'))
          .toSet();

      expect(
        nativeFiles,
        {'MainActivity.kt', 'RadioPlaybackService.kt'},
        reason: 'Új Android-natív fájl = az iOS-nek nincs megfelelője. Ha ez '
            'szándékos, írd le a docs/IOS-CI-TESTFLIGHT.md-ben, mit tesz az '
            'iOS (pl. `audio_service` + AVAudioSession), és frissítsd ezt a listát.',
      );
    });

    test('a social linkeknél MINDIG van visszaesés a beépített böngészőre', () {
      // A `LaunchMode.externalNonBrowserApplication` iOS-en
      // `universalLinksOnly: true`-ként fut (url_launcher_ios), ezért ha az app
      // nem universal linkkel jelentkezik be, a hívás `false`-t ad. A
      // visszaesés ezért nem dísz, hanem a működés feltétele.
      final browser = _read('lib/core/navigation/in_app_browser.dart');
      expect(browser, contains('LaunchMode.externalNonBrowserApplication'));
      expect(
        browser,
        contains('openInAppBrowser(context, url, title: title)'),
        reason: 'az `openSocialLink` a natív próbálkozás után essen vissza',
      );

      final spotify = _read('lib/screens/more/spotify_playlists_screen.dart');
      expect(spotify, contains('LaunchMode.externalNonBrowserApplication'));
      expect(
        spotify,
        contains("openInAppBrowser(context, url, title: 'Spotify')"),
        reason: 'ha a natív megnyitás nem sikerül, a böngészőnek kell jönnie',
      );
    });
  });

  group('a platform-engedélyek deklarálva vannak (pubspec -> Info.plist)', () {
    /// Csomag -> a hozzá tartozó iOS-deklaráció.
    ///
    /// Csak azok a csomagok vannak itt, amelyek **valóban** külön `Info.plist`
    /// bejegyzést kérnek iOS-en. Ha egy csomag nincs a `pubspec.yaml`-ban, a
    /// teszt átugorja — ezért a végén ellenőrizzük, hogy nem csúszott ki minden.
    const requirements = <String, List<String>>{
      'local_auth': ['NSFaceIDUsageDescription'],
      'image_picker': [
        'NSCameraUsageDescription',
        'NSPhotoLibraryUsageDescription',
      ],
      'just_audio': ['UIBackgroundModes'],
      'audio_service': ['UIBackgroundModes'],
      'google_mobile_ads': [
        'GADApplicationIdentifier',
        'NSUserTrackingUsageDescription',
      ],
    };

    test('minden engedélykérő csomaghoz megvan a plist-kulcs', () {
      final pubspec = _read('pubspec.yaml');
      final plist = _read('ios/Runner/Info.plist');

      var verified = 0;
      for (final entry in requirements.entries) {
        final declared = pubspec.contains('${entry.key}:');
        if (!declared) continue;
        for (final key in entry.value) {
          expect(plist, contains('<key>$key</key>'),
              reason: '${entry.key} iOS-deklarációja hiányzik: $key');
          verified++;
        }
      }

      expect(
        verified,
        requirements.values.fold<int>(0, (sum, keys) => sum + keys.length),
        reason: 'ha bármelyik csomag kimarad, a teszt hamisan zöld lenne — '
            'ez a rész szándékosan mind a 7 kulcsot megköveteli',
      );
    });
  });

  group('a Firebase iOS-konfiguráció be van kötve', () {
    // ⚠️ Enélkül a `firebase_core` iOS-en **indulás közben elszáll**: a
    // `lib/core/firebase/firebase_callable.dart` sima `Firebase.initializeApp()`-ot
    // hív, ami a csomagba ágyazott plist-ből indul. A plist bundle ID-jának
    // egyeznie KELL a projektével — a rossz ID-jű plist csendben megölné a
    // Firebase-t (nem hibaüzenet, csak nem működő bejelentkezés).
    String? plistValue(String xml, String key) => RegExp(
          '<key>$key</key>\\s*<string>([^<]*)</string>',
        ).firstMatch(xml)?.group(1);

    test('a plist megvan, és a bundle ID egyezik a projekttel', () {
      final file = File('ios/Runner/GoogleService-Info.plist');
      expect(file.existsSync(), isTrue,
          reason: 'a Firebase iOS-konfiguráció hiányzik');

      final plistBundleId = plistValue(file.readAsStringSync(), 'BUNDLE_ID');
      final xcodeBundleId = RegExp(r'PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);')
          .allMatches(_read('ios/Runner.xcodeproj/project.pbxproj'))
          .map((match) => match.group(1)!.trim())
          .firstWhere((id) => !id.endsWith('.RunnerTests'));

      expect(plistBundleId, xcodeBundleId,
          reason: 'a plist bundle ID-ja nem egyezhet a projektével');
    });

    test('az .gitignore NEM rejti el a plistet (a CI-nak látnia kell)', () {
      expect(_read('ios/.gitignore'), isNot(contains('GoogleService-Info')),
          reason: 'a plist a repóban van (mint az Android google-services.json), '
              'különben a CI nem tudná beépíteni');
    });

    test('mind a négy helyen be van kötve az Xcode-projektbe', () {
      final pbxproj = _read('ios/Runner.xcodeproj/project.pbxproj');
      const name = 'GoogleService-Info.plist';
      for (final needle in [
        '/* $name in Resources */ = {isa = PBXBuildFile',
        '/* $name */ = {isa = PBXFileReference',
        '/* $name */,',
        '/* $name in Resources */,',
      ]) {
        expect(pbxproj, contains(needle),
            reason: 'hiányzó Xcode-bejegyzés: $needle');
      }
    });

    test('a Google Sign-In URL-sémája a plist REVERSED_CLIENT_ID-ja', () {
      final reversed =
          plistValue(_read('ios/Runner/GoogleService-Info.plist'), 'REVERSED_CLIENT_ID');
      expect(reversed, isNotNull, reason: 'a plistben nincs REVERSED_CLIENT_ID');

      final info = _read('ios/Runner/Info.plist');
      expect(info, contains('<key>CFBundleURLTypes</key>'));
      expect(info, contains('<string>$reversed</string>'),
          reason: 'enélkül a Google-bejelentkezés nem tér vissza a böngészőből '
              'az appba — a hiba csak futásidőben, a bejelentkezéskor látszana');
    });
  });

  group('az ismert iOS-hiányok dokumentáltak (nem felejtődnek el)', () {
    /// Ami iOS-en **még nincs meg**, és tudni kell róla. Ha bármelyik elkészül,
    /// ez a teszt elhasal → frissítsd a dokumentumot ÉS ezt a listát.
    const documentedGaps = <String, String>{
      'StoreKit': 'a zenevásárlás (az Apple IAP-szabálya miatt)',
      'aps-environment': 'a push értesítés (APNs entitlement)',
      'Associated Domains': 'a meghívó-link (app_links)',
    };

    test('a dokumentum megvan, és minden hiány szerepel benne', () {
      final path = 'docs/IOS-CI-TESTFLIGHT.md';
      expect(File(path).existsSync(), isTrue,
          reason: 'az iOS-út kézi lépéseinek dokumentuma eltűnt');

      final document = _read(path);
      for (final gap in documentedGaps.entries) {
        expect(document, contains(gap.key),
            reason: '${gap.value}: írd le a $path dokumentumban');
      }
    });
  });
}

String _read(String path) =>
    File(path).readAsStringSync().replaceAll('\r\n', '\n');
