import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:async';

const enableTestAds = bool.fromEnvironment(
  'HUHS_ENABLE_TEST_ADS',
  defaultValue: false,
);

// A debug/emulátoros Android manifest teszt App ID-t használ. Production
// egységazonosítóval ugyanabban a folyamatban a banner/rewarded kérés
// formátum- vagy app-eltéréssel elbukhat, ezért debugban mindig teszt reklám
// menjen; a Play release továbbra is production azonosítókat használ.
const useTestAds = enableTestAds || kDebugMode;

// These are the verified production values configured in the Android release
// build. The dart-defines remain supported, but a missing define must not make
// a signed production build silently disable every ad request.
const _configuredProductionAppId = 'ca-app-pub-7714662594685378~1123886696';
const _configuredProductionBannerId = 'ca-app-pub-7714662594685378/5219184964';
const _configuredProductionRewardedId =
    'ca-app-pub-7714662594685378/5286829694';

const productionAdMobAppId = String.fromEnvironment(
  'HUHS_ADMOB_APP_ID',
  defaultValue: _configuredProductionAppId,
);
const productionBannerAdUnitId = String.fromEnvironment(
  'HUHS_ADMOB_BANNER_ID',
  defaultValue: _configuredProductionBannerId,
);
const productionRewardedAdUnitId = String.fromEnvironment(
  'HUHS_ADMOB_REWARDED_ID',
  defaultValue: _configuredProductionRewardedId,
);

final adsEnabledProvider = Provider<bool>((ref) {
  return useTestAds ||
      (productionAdMobAppId.isNotEmpty && productionBannerAdUnitId.isNotEmpty);
});

Future<void>? _consentPreparation;
Future<void>? _mobileAdsInitialization;
bool _consentResolved = false;

Future<void> prepareAdConsent() {
  if (useTestAds || _consentResolved) return Future<void>.value();
  final running = _consentPreparation;
  if (running != null) return running;
  final future = _prepareAdConsent().then((_) async {
    try {
      _consentResolved = await ConsentInformation.instance.canRequestAds();
    } catch (_) {
      _consentResolved = false;
    }
  });
  // Consent is process-wide. Coalesce only the active request; if consent is
  // still unavailable, a later banner retry must be able to ask again.
  _consentPreparation = future.whenComplete(() {
    _consentPreparation = null;
  });
  return _consentPreparation!;
}

Future<void> initializeMobileAds() {
  if (!useTestAds &&
      (productionAdMobAppId.isEmpty || productionBannerAdUnitId.isEmpty)) {
    return Future<void>.value();
  }
  final running = _mobileAdsInitialization;
  if (running != null) return running;
  _mobileAdsInitialization = _initializeMobileAdsOnce();
  return _mobileAdsInitialization!;
}

Future<void> _initializeMobileAdsOnce() async {
  try {
    await MobileAds.instance.initialize();
    debugPrint('AdMob SDK inicializálva.');
  } catch (error) {
    debugPrint('AdMob SDK inicializálási hiba: $error');
    _mobileAdsInitialization = null;
    rethrow;
  }
}

Future<void> _prepareAdConsent() async {
  final completed = Completer<void>();
  final consent = ConsentInformation.instance;
  consent.requestConsentInfoUpdate(
    ConsentRequestParameters(),
    () {
      ConsentForm.loadAndShowConsentFormIfRequired((formError) {
        if (formError != null) {
          debugPrint(
            'AdMob hozzájárulási űrlap hiba: '
            'code=${formError.errorCode}, message=${formError.message}',
          );
        } else {
          debugPrint('AdMob hozzájárulási folyamat befejeződött.');
        }
        if (!completed.isCompleted) completed.complete();
      });
    },
    (error) {
      debugPrint(
        'AdMob hozzájárulási információ nem frissíthető: '
        'code=${error.errorCode}, message=${error.message}',
      );
      if (!completed.isCompleted) completed.complete();
    },
  );
  await completed.future.timeout(const Duration(seconds: 10), onTimeout: () {});
}

Future<bool> canRequestAds() async {
  if (useTestAds) return true;
  if (_consentResolved) return true;
  try {
    final allowed = await ConsentInformation.instance.canRequestAds();
    debugPrint('AdMob canRequestAds=$allowed');
    return allowed;
  } catch (error) {
    debugPrint('AdMob canRequestAds ellenőrzési hiba: $error');
    return false;
  }
}
