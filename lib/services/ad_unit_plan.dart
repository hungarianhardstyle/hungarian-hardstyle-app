/// **Melyik reklám-egységazonosítót kell használni?** — tiszta döntés.
///
/// MIÉRT KELL (a tulajdonos döntése, 2026-09-22): *„iOS-en is árulunk, oda is
/// kell reklámcsík és reklámért feloldható tartalom majd, de **ne ütközzön az
/// androiddal semmiképpen**"*.
///
/// A kiindulás az volt, hogy **egy** `productionBannerAdUnitId` /
/// `productionRewardedAdUnitId` konstans szolgálta ki mindkét platformot — és
/// ezek **Android** egységazonosítók. iOS-en ez két bajt okozott:
///
///  1. az iOS app a **másik platform** egységére kért reklámot (nincs kitöltés,
///     és a plist-ben lévő **teszt** App ID-hoz sem illik),
///  2. emiatt az iOS-en a reklám **némán nem működött**.
///
/// A szabály ezért platformonként él, de **aszimmetrikusan**:
///
///  * **Android:** pontosan a mai logika — `androidId` jön vissza, akkor is, ha
///    az üres. **Az Android viselkedése egyetlen esetben sem változhat.**
///  * **iOS:** ha nincs saját (`iosId`) azonosító, a **Google teszt** egységére
///    esik vissza — **soha nem az Androidéra**. Ez azért is helyes, mert az
///    `Info.plist`-ben jelenleg a Google **teszt** `GADApplicationIdentifier`
///    szerepel: a teszt egység + teszt App ID **összeillik**.
///
/// Amint a tulajdonos létrehozza az iOS AdMob alkalmazást és egységeit, csak a
/// `HUHS_ADMOB_*_IOS` dart-define-okat kell megadni — **kód nem változik**.
library;

import 'package:flutter/foundation.dart';

/// A Google **teszt** egységazonosítói — ezek minden AdMob-fiókban működnek.
const testBannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';
const testRewardedAdUnitId = 'ca-app-pub-3940256099942544/5224354917';

/// A tényleges egységazonosító a futó platformon.
///
/// ⚠️ A `platform != TargetPlatform.iOS` ág **szándékosan** az `androidId`-t adja
/// vissza feltétel nélkül: így az Android útja bitre ugyanaz, mint a bevezetés
/// előtt. Az iOS-ág a fenti aszimmetrikus szabályt követi.
String resolveAdUnitId({
  required TargetPlatform platform,
  required bool testAds,
  required String androidId,
  required String iosId,
  required String testId,
}) {
  if (testAds) return testId;
  if (platform != TargetPlatform.iOS) return androidId;
  return iosId.isEmpty ? testId : iosId;
}

/// A reklámcsík egységazonosítója a futó platformon.
String resolveBannerAdUnitId({
  required TargetPlatform platform,
  required bool testAds,
  required String androidId,
  required String iosId,
}) => resolveAdUnitId(
  platform: platform,
  testAds: testAds,
  androidId: androidId,
  iosId: iosId,
  testId: testBannerAdUnitId,
);

/// A jutalmazott (reklámért feloldható tartalom) egységazonosítója.
String resolveRewardedAdUnitId({
  required TargetPlatform platform,
  required bool testAds,
  required String androidId,
  required String iosId,
}) => resolveAdUnitId(
  platform: platform,
  testAds: testAds,
  androidId: androidId,
  iosId: iosId,
  testId: testRewardedAdUnitId,
);
