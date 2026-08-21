import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

import '../providers/ads_provider.dart';

class MobileAdBanner extends ConsumerStatefulWidget {
  const MobileAdBanner({super.key});

  @override
  ConsumerState<MobileAdBanner> createState() => _MobileAdBannerState();
}

class _MobileAdBannerState extends ConsumerState<MobileAdBanner>
    with WidgetsBindingObserver {
  BannerAd? _ad;
  bool _loaded = false;
  int? _requestedWidth;
  int? _adWidth;
  Timer? _retryTimer;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    if (_ad != null || _requestedWidth != null) return;
    _retryTimer?.cancel();
    setState(() {});
  }

  void _ensureAd(int width) {
    if (!ref.read(adsEnabledProvider)) {
      return;
    }
    if (_requestedWidth == width && _ad == null) return;
    if (_adWidth == width && _ad != null) return;
    _ad?.dispose();
    _ad = null;
    _loaded = false;
    _adWidth = null;
    _retryTimer?.cancel();
    _requestedWidth = width;
    final generation = ++_loadGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await prepareAdConsent();
      } catch (_) {
        // The retry path below still checks the current consent state.
      }
      try {
        await initializeMobileAds();
      } catch (_) {
        if (!mounted || _requestedWidth != width) return;
        _requestedWidth = null;
        _retryTimer = Timer(const Duration(seconds: 5), () {
          if (mounted) setState(() {});
        });
        return;
      }
      if (!await canRequestAds()) {
        if (!mounted ||
            _requestedWidth != width ||
            _loadGeneration != generation) {
          return;
        }
        _requestedWidth = null;
        _retryTimer?.cancel();
        _retryTimer = Timer(const Duration(seconds: 5), () {
          if (mounted) setState(() {});
        });
        return;
      }
      final size =
          await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width);
      if (!mounted ||
          _requestedWidth != width ||
          _loadGeneration != generation) {
        return;
      }
      if (size == null) {
        // A banner can be laid out once with no usable width while an
        // IndexedStack/landscape shell is settling. Do not permanently lock
        // that invalid request; allow the next real layout to retry.
        _requestedWidth = null;
        _retryTimer?.cancel();
        _retryTimer = Timer(const Duration(milliseconds: 300), () {
          if (mounted) setState(() {});
        });
        return;
      }
      final ad = BannerAd(
        adUnitId: enableTestAds
            ? 'ca-app-pub-3940256099942544/6300978111'
            : productionBannerAdUnitId,
        size: size,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            if (!mounted || _loadGeneration != generation) {
              ad.dispose();
              return;
            }
            setState(() {
              _ad = ad as BannerAd;
              _loaded = true;
              _adWidth = width;
            });
          },
          onAdFailedToLoad: (ad, error) {
            ad.dispose();
            debugPrint(
              'AdMob banner betöltési hiba: '
              'code=${error.code}, domain=${error.domain}, '
              'message=${error.message}',
            );
            if (!mounted) return;
            if (_loadGeneration != generation) return;
            _requestedWidth = null;
            _retryTimer?.cancel();
            _retryTimer = Timer(const Duration(seconds: 5), () {
              if (mounted) setState(() {});
            });
          },
        ),
      );
      ad.load();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _loadGeneration++;
    _retryTimer?.cancel();
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
            // Adaptive banner requests need a usable layout width. A
            // transient zero/very-small constraint must not become a 1 px
            // ad request; that made the production banner disappear after
            // the +160 release while rewarded ads still worked.
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
