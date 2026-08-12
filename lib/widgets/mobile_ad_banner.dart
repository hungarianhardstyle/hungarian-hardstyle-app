import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/ads_provider.dart';

class MobileAdBanner extends ConsumerStatefulWidget {
  const MobileAdBanner({super.key});

  @override
  ConsumerState<MobileAdBanner> createState() => _MobileAdBannerState();
}

class _MobileAdBannerState extends ConsumerState<MobileAdBanner> {
  BannerAd? _ad;
  bool _loaded = false;
  int? _requestedWidth;

  @override
  void initState() {
    super.initState();
  }

  void _ensureAd(int width) {
    if (_requestedWidth == width ||
        _ad != null ||
        !ref.read(adsEnabledProvider)) {
      return;
    }
    _requestedWidth = width;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final size =
          await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);
      if (!mounted || size == null || _requestedWidth != width) return;
      final ad = BannerAd(
        adUnitId: enableTestAds
            ? 'ca-app-pub-3940256099942544/6300978111'
            : productionBannerAdUnitId,
        size: size,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            if (!mounted) {
              ad.dispose();
              return;
            }
            setState(() {
              _ad = ad as BannerAd;
              _loaded = true;
            });
          },
          onAdFailedToLoad: (ad, error) => ad.dispose(),
        ),
      );
      ad.load();
    });
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(adsEnabledProvider);
    if (!enabled) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth.floor().clamp(320, 640).toInt()
            : 320;
        _ensureAd(width);
        if (!_loaded || _ad == null) return const SizedBox(height: 50);
        return SizedBox(
          width: _ad!.size.width.toDouble(),
          height: _ad!.size.height.toDouble(),
          child: AdWidget(ad: _ad!),
        );
      },
    );
  }
}
