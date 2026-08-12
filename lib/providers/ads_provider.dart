import 'package:flutter_riverpod/flutter_riverpod.dart';

const enableTestAds = bool.fromEnvironment(
  'HUHS_ENABLE_TEST_ADS',
  defaultValue: true,
);

final adsEnabledProvider = Provider<bool>((ref) => enableTestAds);

const productionAdMobAppId = String.fromEnvironment('HUHS_ADMOB_APP_ID');
const productionBannerAdUnitId = String.fromEnvironment('HUHS_ADMOB_BANNER_ID');
const productionRewardedAdUnitId = String.fromEnvironment(
  'HUHS_ADMOB_REWARDED_ID',
);
