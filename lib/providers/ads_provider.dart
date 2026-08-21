import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:async';

const enableTestAds = bool.fromEnvironment(
  'HUHS_ENABLE_TEST_ADS',
  defaultValue: false,
);

const productionAdMobAppId = String.fromEnvironment('HUHS_ADMOB_APP_ID');
const productionBannerAdUnitId = String.fromEnvironment('HUHS_ADMOB_BANNER_ID');
const productionRewardedAdUnitId = String.fromEnvironment(
  'HUHS_ADMOB_REWARDED_ID',
);

final adsEnabledProvider = Provider<bool>((ref) {
  return enableTestAds ||
      (productionAdMobAppId.isNotEmpty && productionBannerAdUnitId.isNotEmpty);
});

Future<void>? _consentPreparation;
Future<void>? _mobileAdsInitialization;
bool _consentResolved = false;

Future<void> prepareAdConsent() {
  if (enableTestAds || _consentResolved) return Future<void>.value();
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
  if (!enableTestAds &&
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
  } catch (_) {
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
      ConsentForm.loadAndShowConsentFormIfRequired((_) {
        if (!completed.isCompleted) completed.complete();
      });
    },
    (_) {
      if (!completed.isCompleted) completed.complete();
    },
  );
  await completed.future.timeout(const Duration(seconds: 10), onTimeout: () {});
}

Future<bool> canRequestAds() async {
  if (enableTestAds) return true;
  try {
    return await ConsentInformation.instance.canRequestAds();
  } catch (_) {
    return false;
  }
}
