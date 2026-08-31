import 'dart:async';
import 'dart:convert';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

import '../providers/ads_provider.dart';

class LabelPurchaseService with WidgetsBindingObserver {
  static final LabelPurchaseService shared = LabelPurchaseService();
  static final Map<String, ProductDetails> _catalogCache = {};

  LabelPurchaseService({InAppPurchase? store})
    : _store = store ?? InAppPurchase.instance {
    WidgetsBinding.instance.addObserver(this);
  }

  final InAppPurchase _store;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  final _updates = StreamController<PurchaseDetails>.broadcast();
  final Map<String, PurchaseDetails> _pendingUpdates =
      <String, PurchaseDetails>{};
  final Map<String, Future<bool>> _completionAttempts =
      <String, Future<bool>>{};
  final Map<String, Timer> _completionRetryTimers = <String, Timer>{};
  final Set<String> _completedPurchases = <String>{};
  RewardedAd? _preloadedRewarded;
  String? _preloadedRewardedUnitId;
  bool _preloadingRewarded = false;
  bool _rewardedInFlight = false;

  bool lastStoreAvailable = false;
  Set<String> lastNotFoundProductIds = const {};
  String? lastProductQueryError;
  Set<String> lastProductQueryIds = const {};
  final Set<String> _backgroundProductIds = <String>{};
  Timer? _backgroundRetryTimer;
  bool _backgroundSyncRunning = false;
  int _backgroundRetryAttempts = 0;
  Future<void>? _restoreInFlight;

  Stream<PurchaseDetails> get purchaseUpdates async* {
    for (final purchase in _pendingUpdates.values.toList(growable: false)) {
      yield purchase;
    }
    yield* _updates.stream;
  }

  /// Warms the Play catalog independently from any release detail screen.
  /// Newly-created products can take time to propagate; keeping their IDs
  /// here means navigating away does not stop the retry loop.
  void registerProductIds(Iterable<String> productIds) {
    final ids = productIds.map((id) => id.trim()).where((id) => id.isNotEmpty);
    final before = _backgroundProductIds.length;
    _backgroundProductIds.addAll(ids);
    if (_backgroundProductIds.length == before &&
        (_backgroundRetryTimer != null || _backgroundSyncRunning)) {
      return;
    }
    _backgroundRetryAttempts = 0;
    _backgroundRetryTimer?.cancel();
    _backgroundRetryTimer = Timer(Duration.zero, () {
      _backgroundRetryTimer = null;
      unawaited(_syncBackgroundProducts());
    });
  }

  Future<void> _syncBackgroundProducts() async {
    if (_backgroundSyncRunning || _backgroundProductIds.isEmpty) return;
    _backgroundSyncRunning = true;
    try {
      final ids = Set<String>.from(_backgroundProductIds);
      final products = await loadProducts(ids);
      _backgroundProductIds.removeAll(products.map((product) => product.id));
      if (_backgroundProductIds.isNotEmpty) _scheduleBackgroundRetry();
    } catch (_) {
      _scheduleBackgroundRetry();
    } finally {
      _backgroundSyncRunning = false;
    }
  }

  void _scheduleBackgroundRetry() {
    if (_backgroundRetryTimer != null || _backgroundProductIds.isEmpty) return;
    const delays = [
      Duration(seconds: 5),
      Duration(seconds: 15),
      Duration(seconds: 30),
      Duration(minutes: 1),
      Duration(minutes: 2),
      Duration(minutes: 5),
    ];
    final delay = delays[_backgroundRetryAttempts.clamp(0, delays.length - 1)];
    _backgroundRetryAttempts++;
    _backgroundRetryTimer = Timer(delay, () {
      _backgroundRetryTimer = null;
      unawaited(_syncBackgroundProducts());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed ||
        _backgroundProductIds.isEmpty ||
        _backgroundSyncRunning) {
      return;
    }
    _backgroundRetryTimer?.cancel();
    _backgroundRetryTimer = Timer(Duration.zero, () {
      _backgroundRetryTimer = null;
      unawaited(_syncBackgroundProducts());
    });
  }

  Future<List<ProductDetails>> loadProducts(Iterable<String> productIds) async {
    final available = await _store.isAvailable();
    lastStoreAvailable = available;
    lastNotFoundProductIds = const {};
    lastProductQueryError = null;
    lastProductQueryIds = productIds.toSet();
    if (!available) return const [];
    final ids = lastProductQueryIds;
    if (ids.isEmpty) return const [];

    final found = <String, ProductDetails>{
      for (final id in ids)
        if (_catalogCache.containsKey(id)) id: _catalogCache[id]!,
    };
    String? lastError;

    // Play can briefly return an incomplete catalog while a newly-created
    // one-time product is propagating. Keep the bounded fast retries here so
    // the screen does not need to wait for its long background retry schedule.
    for (var attempt = 0; attempt < 3 && found.length < ids.length; attempt++) {
      try {
        final batch = await _store.queryProductDetails(ids);
        if (batch.error != null) {
          lastError = batch.error!.message;
        } else {
          for (final product in batch.productDetails) {
            found[product.id] = product;
            _catalogCache[product.id] = product;
          }

          // The Android Billing bridge can report a sibling as unfetched in a
          // batch even though the same product is immediately available when
          // queried alone. Recover those IDs without discarding the products
          // already returned by the successful batch.
          final missing = ids.difference(found.keys.toSet());
          for (final productId in missing) {
            try {
              final single = await _store.queryProductDetails({productId});
              if (single.error != null) {
                lastError = single.error!.message;
                continue;
              }
              for (final product in single.productDetails) {
                found[product.id] = product;
                _catalogCache[product.id] = product;
              }
            } catch (error) {
              lastError = error.toString();
            }
          }
        }
      } catch (error) {
        lastError = error.toString();
      }

      if (found.length < ids.length && attempt < 2) {
        await Future<void>.delayed(Duration(milliseconds: 400 * (attempt + 1)));
      }
    }

    lastNotFoundProductIds = ids.difference(found.keys.toSet());
    if (found.isEmpty && lastError != null) {
      lastProductQueryError = lastError;
      throw StateError(lastError);
    }
    debugPrint(
      'Google Play terméklekérdezés: '
      'found=${found.keys.toList()} notFound=$lastNotFoundProductIds',
    );
    return found.values.toList(growable: false);
  }

  void listen() {
    _subscription ??= _store.purchaseStream.listen((items) async {
      for (final purchase in items) {
        final key = _purchaseKey(purchase);
        // Retain every event until the release screen confirms both server
        // verification and Play completion. This also covers a screen that
        // is opened after the purchase was delivered.
        _pendingUpdates[key] = purchase;
        if (_updates.hasListener) {
          _updates.add(purchase);
        }
        if ((purchase.status == PurchaseStatus.error ||
                purchase.status == PurchaseStatus.canceled) &&
            purchase.pendingCompletePurchase) {
          await completePurchase(purchase);
        }
      }
    });
  }

  Future<bool> completePurchase(PurchaseDetails purchase) async {
    if (!purchase.pendingCompletePurchase) return true;
    final key = _purchaseKey(purchase);
    if (_completedPurchases.contains(key)) return true;
    return _completionAttempts[key] ??= _completeWithRetry(purchase, key);
  }

  Future<bool> _completeWithRetry(PurchaseDetails purchase, String key) async {
    try {
      for (var attempt = 0; attempt < 3; attempt++) {
        try {
          await _store.completePurchase(purchase);
          _completedPurchases.add(key);
          return true;
        } catch (_) {
          if (attempt < 2) {
            await Future<void>.delayed(
              Duration(milliseconds: 500 * (attempt + 1)),
            );
          }
        }
      }
      _scheduleCompletionRetry(purchase, key);
      return false;
    } finally {
      _completionAttempts.remove(key);
    }
  }

  void acknowledgePurchaseEvent(PurchaseDetails purchase) {
    final key = _purchaseKey(purchase);
    _pendingUpdates.remove(key);
    _completionRetryTimers.remove(key)?.cancel();
  }

  void _scheduleCompletionRetry(PurchaseDetails purchase, String key) {
    if (_completionRetryTimers.containsKey(key)) return;
    _completionRetryTimers[key] = Timer(const Duration(seconds: 30), () {
      _completionRetryTimers.remove(key);
      unawaited(completePurchase(purchase));
    });
  }

  String _purchaseKey(PurchaseDetails purchase) {
    final token = purchase.verificationData.serverVerificationData;
    return '${purchase.productID}:$token';
  }

  Future<bool> buy(ProductDetails product) => _store.buyNonConsumable(
    purchaseParam: PurchaseParam(productDetails: product),
  );

  bool isAlreadyOwned(PurchaseDetails purchase) {
    final error = purchase.error;
    final values = <String>[
      error?.code ?? '',
      error?.message ?? '',
      error?.details?.toString() ?? '',
    ].map((value) => value.toLowerCase().replaceAll('_', '')).toList();
    return values.any((value) => value.contains('itemalreadyowned'));
  }

  String purchaseErrorMessage(PurchaseDetails purchase) {
    final error = purchase.error;
    if (error == null) return 'A Google Play-vásárlás nem sikerült.';
    if (isAlreadyOwned(purchase)) {
      return 'Ezt a kiadást már megvásároltad. A letöltés hamarosan elérhető lesz.';
    }
    return switch (error.code) {
      'user_canceled' => 'A vásárlást megszakítottad.',
      'billing_unavailable' =>
        'A Google Play vásárlási szolgáltatása most nem érhető el.',
      _ =>
        'A Google Play nem tudta elindítani a vásárlást. Próbáld újra később.',
    };
  }

  Future<bool> verifyPurchase({
    required PurchaseDetails purchase,
    required int releaseId,
  }) async {
    final token = purchase.verificationData.serverVerificationData;
    if (token.isEmpty) return false;
    final result = await FirebaseFunctions.instance
        .httpsCallable('verifyLabelPurchase')
        .call({
          'releaseId': releaseId,
          'productId': purchase.productID,
          'purchaseToken': token,
        });
    return result.data is Map && result.data['verified'] == true;
  }

  Future<void> restore() {
    return _restoreInFlight ??= _store.restorePurchases().whenComplete(() {
      _restoreInFlight = null;
    });
  }

  Future<String> getDownloadUrl({
    required int releaseId,
    required String variant,
  }) async {
    final result = await FirebaseFunctions.instance
        .httpsCallable('getLabelDownloadUrl')
        .call({'releaseId': releaseId, 'variant': variant});
    final data = result.data;
    if (data is! Map || data['downloadUrl'] is! String) {
      throw StateError('A letöltési hivatkozás nem érhető el.');
    }
    return data['downloadUrl'] as String;
  }

  Future<bool> waitForAdUnlock({
    required int releaseId,
    String variant = 'mp3_128',
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final callable = FirebaseFunctions.instance.httpsCallable(
      'getLabelAdUnlockStatus',
    );
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      try {
        final result = await callable.call({
          'releaseId': releaseId,
          'variant': variant,
        });
        final data = result.data;
        if (data is Map && data['unlocked'] == true) return true;
      } catch (_) {
        // The SSV callback is asynchronous; keep polling until the timeout.
      }
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    return false;
  }

  Future<bool> hasAdUnlock(int releaseId, {String variant = 'mp3_128'}) async {
    final result = await FirebaseFunctions.instance
        .httpsCallable('getLabelAdUnlockStatus')
        .call({'releaseId': releaseId, 'variant': variant});
    return result.data is Map && result.data['unlocked'] == true;
  }

  Future<bool> showRewardedAd(
    int releaseId, {
    String variant = 'mp3_128',
  }) async {
    if (_rewardedInFlight) {
      throw StateError('A jutalmazott reklám már folyamatban van.');
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      throw StateError('A reklámos feloldáshoz be kell jelentkezni.');
    }
    final unitId = useTestAds
        ? 'ca-app-pub-3940256099942544/5224354917'
        : productionRewardedAdUnitId;
    if (unitId.isEmpty) {
      throw StateError('A jutalmazott reklám azonosítója nincs beállítva.');
    }
    _rewardedInFlight = true;
    try {
      await prepareAdConsent();
      await initializeMobileAds();
      if (!await canRequestAds()) {
        throw StateError(
          'A reklámokhoz szükséges hozzájárulás még nem áll rendelkezésre.',
        );
      }
      final rewarded = await _takeOrLoadRewarded(unitId);
      return await _showRewarded(
        rewarded,
        releaseId: releaseId,
        variant: variant,
        unitId: unitId,
        uid: user.uid,
      );
    } finally {
      _rewardedInFlight = false;
    }
  }

  Future<bool> _showRewarded(
    RewardedAd rewarded, {
    required int releaseId,
    required String variant,
    required String unitId,
    required String uid,
  }) async {
    // The reward is granted only from onUserEarnedReward below. Loading or
    // dismissing the ad alone never unlocks a file.
    debugPrint('AdMob rewarded betöltve: variant=$variant');
    final customData = base64UrlEncode(
      utf8.encode(
        jsonEncode({'uid': uid, 'releaseId': releaseId, 'variant': variant}),
      ),
    );
    await rewarded.setServerSideOptions(
      ServerSideVerificationOptions(customData: customData),
    );
    final result = Completer<bool>();
    rewarded.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) =>
          debugPrint('AdMob rewarded megjelenítve.'),
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('AdMob rewarded bezárva reward nélkül.');
        ad.dispose();
        unawaited(_preloadRewarded(unitId));
        if (!result.isCompleted) result.complete(false);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint(
          'AdMob rewarded megjelenítési hiba: '
          'code=${error.code}, domain=${error.domain}, message=${error.message}',
        );
        ad.dispose();
        unawaited(_preloadRewarded(unitId));
        if (!result.isCompleted) {
          result.completeError(
            StateError(
              'A jutalmazott reklámot nem sikerült megjeleníteni. Próbáld újra később.',
            ),
          );
        }
      },
    );
    rewarded.show(
      onUserEarnedReward: (_, _) {
        debugPrint('AdMob reward megszerezve: variant=$variant');
        if (!result.isCompleted) result.complete(true);
      },
    );
    return result.future;
  }

  Future<RewardedAd> _takeOrLoadRewarded(String unitId) async {
    final cached = _preloadedRewarded;
    if (cached != null && _preloadedRewardedUnitId == unitId) {
      _preloadedRewarded = null;
      _preloadedRewardedUnitId = null;
      return cached;
    }
    return _loadRewarded(unitId).timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw TimeoutException(
        'A jutalmazott reklám betöltése túllépte a 15 másodpercet.',
      ),
    );
  }

  Future<void> _preloadRewarded(String unitId) async {
    if (_preloadingRewarded || _preloadedRewarded != null) return;
    _preloadingRewarded = true;
    try {
      if (!await canRequestAds()) return;
      final ad = await _loadRewarded(
        unitId,
      ).timeout(const Duration(seconds: 15));
      _preloadedRewarded?.dispose();
      _preloadedRewarded = ad;
      _preloadedRewardedUnitId = unitId;
      debugPrint('AdMob következő rewarded reklám előtöltve.');
    } catch (error) {
      debugPrint('AdMob rewarded előtöltési hiba: $error');
    } finally {
      _preloadingRewarded = false;
    }
  }

  Future<RewardedAd> _loadRewarded(String unitId) {
    final completer = Completer<RewardedAd>();
    RewardedAd.load(
      adUnitId: unitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('AdMob rewarded load sikeres.');
          completer.complete(ad);
        },
        onAdFailedToLoad: (error) {
          debugPrint(
            'AdMob rewarded betöltési hiba: '
            'code=${error.code}, domain=${error.domain}, message=${error.message}',
          );
          completer.completeError(StateError(_admobLoadMessage(error)));
        },
      ),
    );
    return completer.future;
  }

  static String _admobLoadMessage(LoadAdError error) {
    return switch (error.code) {
      0 =>
        'A reklám kérése érvénytelen. Ellenőrizd az alkalmazás beállításait.',
      1 =>
        'Nem sikerült betölteni a reklámot. Ellenőrizd az internetkapcsolatot.',
      2 => 'A reklámszolgáltatás jelenleg nem érhető el. Próbáld újra később.',
      3 => 'Most nincs elérhető reklám. Próbáld újra később.',
      _ => 'A reklámot most nem sikerült betölteni. Próbáld újra később.',
    };
  }

  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    _backgroundRetryTimer?.cancel();
    _backgroundRetryTimer = null;
    for (final timer in _completionRetryTimers.values) {
      timer.cancel();
    }
    _completionRetryTimers.clear();
    _preloadedRewarded?.dispose();
    _preloadedRewarded = null;
    await _subscription?.cancel();
    await _updates.close();
  }
}
