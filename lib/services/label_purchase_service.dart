import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../providers/ads_provider.dart';

class LabelPurchaseService {
  LabelPurchaseService({InAppPurchase? store})
    : _store = store ?? InAppPurchase.instance;

  final InAppPurchase _store;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  final _updates = StreamController<PurchaseDetails>.broadcast();
  final Set<String> _completedPurchases = <String>{};
  RewardedAd? _preloadedRewarded;
  String? _preloadedRewardedUnitId;
  bool _preloadingRewarded = false;
  bool _rewardedInFlight = false;

  bool lastStoreAvailable = false;
  Set<String> lastNotFoundProductIds = const {};
  String? lastProductQueryError;

  Stream<PurchaseDetails> get purchaseUpdates => _updates.stream;

  Future<List<ProductDetails>> loadProducts(Iterable<String> productIds) async {
    final available = await _store.isAvailable();
    lastStoreAvailable = available;
    lastNotFoundProductIds = const {};
    lastProductQueryError = null;
    if (!available) return const [];
    final ids = productIds.toSet();
    ProductDetailsResponse? response;
    for (var attempt = 0; attempt < 3; attempt++) {
      response = await _store.queryProductDetails(ids);
      if (response.error == null && response.productDetails.isNotEmpty) break;
      if (attempt < 2) {
        await Future<void>.delayed(Duration(milliseconds: 400 * (attempt + 1)));
      }
    }
    if (response == null) return const [];
    if (response.error != null) {
      lastProductQueryError = response.error!.message;
      throw StateError(response.error!.message);
    }
    lastNotFoundProductIds = response.notFoundIDs.toSet();
    return response.productDetails;
  }

  void listen() {
    _subscription ??= _store.purchaseStream.listen((items) async {
      for (final purchase in items) {
        _updates.add(purchase);
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
    try {
      await _store.completePurchase(purchase);
      _completedPurchases.add(key);
      return true;
    } catch (error) {
      // Keep the transaction pending so Google Play can deliver it again.
      // This avoids falsely marking a purchase as finished when the
      // acknowledgement request actually failed.
      return false;
    }
  }

  String _purchaseKey(PurchaseDetails purchase) {
    final token = purchase.verificationData.serverVerificationData;
    return '${purchase.productID}:$token';
  }

  Future<bool> buy(ProductDetails product) => _store.buyNonConsumable(
    purchaseParam: PurchaseParam(productDetails: product),
  );

  String purchaseErrorMessage(PurchaseDetails purchase) {
    final error = purchase.error;
    if (error == null) return 'A Google Play-vásárlás nem sikerült.';
    return switch (error.code) {
      'item_already_owned' =>
        'Ezt a kiadást már megvásároltad. A letöltés hamarosan elérhető lesz.',
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

  Future<void> restore() => _store.restorePurchases();

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
    _preloadedRewarded?.dispose();
    _preloadedRewarded = null;
    await _subscription?.cancel();
    await _updates.close();
  }
}
