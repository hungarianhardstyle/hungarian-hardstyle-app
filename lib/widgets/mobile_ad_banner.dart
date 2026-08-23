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
    with AutomaticKeepAliveClientMixin<MobileAdBanner>, WidgetsBindingObserver {
  BannerAd? _ad;
  bool _loaded = false;
  int? _requestedWidth;
  Timer? _retryTimer;
  Timer? _loadTimeout;
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
    if (_ad != null) return;
    _ad?.dispose();
    _ad = null;
    _loaded = false;
    _retryTimer?.cancel();
    _loadTimeout?.cancel();
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
      if (!mounted ||
          _requestedWidth != width ||
          _loadGeneration != generation) {
        return;
      }
      final size = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width);
      if (!mounted ||
          _requestedWidth != width ||
          _loadGeneration != generation) {
        return;
      }
      if (size == null) {
        debugPrint('AdMob banner méret nem kérhető: width=$width');
        _requestedWidth = null;
        _retryTimer?.cancel();
        _retryTimer = Timer(const Duration(seconds: 5), () {
          if (mounted) setState(() {});
        });
        return;
      }
      final ad = BannerAd(
        adUnitId: useTestAds
            ? 'ca-app-pub-3940256099942544/6300978111'
            : productionBannerAdUnitId,
        size: size,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            _loadTimeout?.cancel();
            debugPrint('AdMob banner betöltve.');
            if (!mounted || _loadGeneration != generation) {
              ad.dispose();
              return;
            }
            setState(() {
              _ad = ad as BannerAd;
              _loaded = true;
            });
          },
          onAdFailedToLoad: (ad, error) {
            _loadTimeout?.cancel();
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
      _loadTimeout = Timer(const Duration(seconds: 15), () {
        if (!mounted || _loadGeneration != generation || _loaded) return;
        _loadGeneration++;
        _requestedWidth = null;
        _loadTimeout = null;
        ad.dispose();
        _retryTimer?.cancel();
        _retryTimer = Timer(const Duration(seconds: 5), () {
          if (mounted) setState(() {});
        });
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _loadGeneration++;
    _retryTimer?.cancel();
    _loadTimeout?.cancel();
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final enabled = ref.watch(adsEnabledProvider);
    if (!enabled) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth.floor()
            : 0;
        if (width < 200) return const SizedBox(height: 50);
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

  @override
  bool get wantKeepAlive => true;
}
