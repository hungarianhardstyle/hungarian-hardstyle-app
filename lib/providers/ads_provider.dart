import 'package:flutter_riverpod/flutter_riverpod.dart';

const enableTestAds = bool.fromEnvironment(
  'HUHS_ENABLE_TEST_ADS',
  defaultValue: true,
);

final adsEnabledProvider = Provider<bool>((ref) => enableTestAds);
