import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/services/ad_unit_plan.dart';

/// **Reklám-egységazonosítók platformonként — az Android VÁLTOZATLANSÁGÁNAK
/// zárja.**
///
/// A tulajdonos döntése (2026-09-22): *„iOS-en is árulunk, oda is kell
/// reklámcsík és reklámért feloldható tartalom majd, de **ne ütközzön az
/// androiddal semmiképpen**"*.
///
/// A kiindulás: **egy** `productionBannerAdUnitId` / `productionRewardedAdUnitId`
/// konstans szolgálta ki mindkét platformot, és azok **Android** egységek —
/// ezért az iOS a másik platform egységére kért reklámot (nincs kitöltés).
///
/// A lényeg, amit ez a teszt **kikényszerít**, nem az, hogy „működik az iOS",
/// hanem hogy **az Android útja bitre ugyanaz marad**, és hogy az iOS **soha**
/// nem esik vissza az Android egységére.
void main() {
  group('az Android útja VÁLTOZATLAN (a legfontosabb szabály)', () {
    test('Androidon pontosan a kapott androidId jön vissza', () {
      expect(
        resolveBannerAdUnitId(
          platform: TargetPlatform.android,
          testAds: false,
          androidId: 'android-banner',
          iosId: 'ios-banner',
        ),
        'android-banner',
        reason: 'az iOS azonosító jelenléte nem érintheti az Androidot',
      );
      expect(
        resolveRewardedAdUnitId(
          platform: TargetPlatform.android,
          testAds: false,
          androidId: 'android-rewarded',
          iosId: 'ios-rewarded',
        ),
        'android-rewarded',
      );
    });

    test('az ÜRES androidId is üres marad (nem esik át a teszthez)', () {
      // ⚠️ Ez a visszafelé-kompatibilitás lényege: a régi kód az üres értéket
      // adta tovább (és a hívó kezelte). Ha itt a teszt-azonosító jönne vissza,
      // az MÁR megváltozott Android-viselkedés lenne.
      expect(
        resolveBannerAdUnitId(
          platform: TargetPlatform.android,
          testAds: false,
          androidId: '',
          iosId: 'ios-banner',
        ),
        '',
      );
    });

    test('a többi nem-iOS platform is a régi utat járja', () {
      for (final platform in [
        TargetPlatform.windows,
        TargetPlatform.linux,
        TargetPlatform.macOS,
        TargetPlatform.fuchsia,
      ]) {
        expect(
          resolveBannerAdUnitId(
            platform: platform,
            testAds: false,
            androidId: 'android-banner',
            iosId: 'ios-banner',
          ),
          'android-banner',
          reason: '$platform: a régi viselkedés az androidId volt',
        );
      }
    });

    test('teszt módban minden platform a Google teszt egységét kapja', () {
      for (final platform in TargetPlatform.values) {
        expect(
          resolveBannerAdUnitId(
            platform: platform,
            testAds: true,
            androidId: 'android-banner',
            iosId: 'ios-banner',
          ),
          testBannerAdUnitId,
        );
        expect(
          resolveRewardedAdUnitId(
            platform: platform,
            testAds: true,
            androidId: 'android-rewarded',
            iosId: 'ios-rewarded',
          ),
          testRewardedAdUnitId,
        );
      }
    });
  });

  group('az iOS ág (aszimmetrikus szabály)', () {
    test('ha van saját iOS egység, azt használja', () {
      expect(
        resolveBannerAdUnitId(
          platform: TargetPlatform.iOS,
          testAds: false,
          androidId: 'android-banner',
          iosId: 'ios-banner',
        ),
        'ios-banner',
      );
      expect(
        resolveRewardedAdUnitId(
          platform: TargetPlatform.iOS,
          testAds: false,
          androidId: 'android-rewarded',
          iosId: 'ios-rewarded',
        ),
        'ios-rewarded',
      );
    });

    test('⚠️ ha nincs iOS egység, a GOOGLE TESZT jön — nem az Androidé', () {
      final banner = resolveBannerAdUnitId(
        platform: TargetPlatform.iOS,
        testAds: false,
        androidId: 'android-banner',
        iosId: '',
      );
      expect(banner, testBannerAdUnitId);
      expect(
        banner,
        isNot('android-banner'),
        reason: 'az iOS SOHA nem kérhet a másik platform egységére',
      );

      expect(
        resolveRewardedAdUnitId(
          platform: TargetPlatform.iOS,
          testAds: false,
          androidId: 'android-rewarded',
          iosId: '',
        ),
        testRewardedAdUnitId,
      );
    });

    test('a jutalmazott reklám iOS-en sosem lehet üres (a hívó dobna)', () {
      // A `showRewardedAd` üres azonosítónál `StateError`-t dob, ezért az iOS
      // ágon üres érték nem maradhat.
      expect(
        resolveRewardedAdUnitId(
          platform: TargetPlatform.iOS,
          testAds: false,
          androidId: '',
          iosId: '',
        ),
        isNotEmpty,
      );
    });
  });

  group('a döntés EGY helyen él (nincs szétszórt azonosító)', () {
    String read(String path) =>
        File(path).readAsStringSync().replaceAll('\r\n', '\n');

    test('a hívási helyek a tiszta döntést használják', () {
      final banner = read('lib/widgets/mobile_ad_banner.dart');
      expect(banner, contains('resolveBannerAdUnitId('));
      expect(banner, contains('platform: defaultTargetPlatform'));

      final purchases = read('lib/services/label_purchase_service.dart');
      expect(purchases, contains('resolveRewardedAdUnitId('));
      expect(purchases, contains('platform: defaultTargetPlatform'));
    });

    test('a régi, beégetett teszt-egységek eltűntek a hívási helyekről', () {
      // Ha valaki visszateszi a `useTestAds ? 'ca-app-pub-3940…' : …` mintát,
      // az egy MÁSODIK döntési pont lenne — pont ez volt a hiba forrása.
      for (final path in [
        'lib/widgets/mobile_ad_banner.dart',
        'lib/services/label_purchase_service.dart',
      ]) {
        expect(
          read(path),
          isNot(contains("ca-app-pub-3940256099942544/")),
          reason: '$path: a teszt-egység csak az ad_unit_plan.dart-ban élhet',
        );
      }
    });

    test('a valódi Android egységek a provider-ben maradtak', () {
      final ads = read('lib/providers/ads_provider.dart');
      expect(ads, contains('ca-app-pub-7714662594685378~1123886696'));
      expect(ads, contains('ca-app-pub-7714662594685378/5219184964'));
      expect(ads, contains('ca-app-pub-7714662594685378/5286829694'));
      // Az iOS azonosítók dart-define-ból jönnek, és alapból ÜRESEK.
      expect(
        ads,
        contains("String.fromEnvironment('HUHS_ADMOB_BANNER_ID_IOS')"),
      );
      expect(
        ads,
        contains("String.fromEnvironment('HUHS_ADMOB_REWARDED_ID_IOS')"),
      );
    });
  });
}
