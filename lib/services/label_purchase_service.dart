import 'dart:async';
import 'dart:convert';

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
    final response = await _store.queryProductDetails(productIds.toSet());
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
        if (purchase.pendingCompletePurchase) {
          await _store.completePurchase(purchase);
        }
      }
    });
  }

  Future<bool> buy(ProductDetails product) => _store.buyNonConsumable(
    purchaseParam: PurchaseParam(productDetails: product),
  );

  String purchaseErrorMessage(PurchaseDetails purchase) {
    final error = purchase.error;
    if (error == null) return 'A Google Play-vásárlás nem sikerült.';
    return switch (error.code) {
      'item_already_owned' => 'Ezt a kiadást már megvásároltad. A letöltés hamarosan elérhető lesz.',
      'user_canceled' => 'A vásárlást megszakítottad.',
      'billing_unavailable' => 'A Google Play vásárlási szolgáltatása most nem érhető el.',
      _ => 'A Google Play nem tudta elindítani a vásárlást. Próbáld újra később.',
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
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final callable = FirebaseFunctions.instance.httpsCallable(
      'getLabelAdUnlockStatus',
    );
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      try {
        final result = await callable.call({'releaseId': releaseId});
        final data = result.data;
        if (data is Map && data['unlocked'] == true) return true;
      } catch (_) {
        // The SSV callback is asynchronous; keep polling until the timeout.
      }
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    return false;
  }

  Future<bool> hasAdUnlock(int releaseId) async {
    final result = await FirebaseFunctions.instance
        .httpsCallable('getLabelAdUnlockStatus')
        .call({'releaseId': releaseId});
    return result.data is Map && result.data['unlocked'] == true;
  }

  Future<bool> showRewardedAd(int releaseId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      throw StateError('A reklámos feloldáshoz be kell jelentkezni.');
    }
    final unitId = enableTestAds
        ? 'ca-app-pub-3940256099942544/5224354917'
        : productionRewardedAdUnitId;
    if (unitId.isEmpty) {
      throw StateError('A jutalmazott reklám azonosítója nincs beállítva.');
    }
    final rewarded = await _loadRewarded(unitId).timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw TimeoutException(
        'A jutalmazott reklám betöltése túllépte a 15 másodpercet.',
      ),
    );
    final customData = base64UrlEncode(
      utf8.encode(jsonEncode({'uid': user.uid, 'releaseId': releaseId})),
    );
    await rewarded.setServerSideOptions(
      ServerSideVerificationOptions(customData: customData),
    );
    final result = Completer<bool>();
    rewarded.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (!result.isCompleted) result.complete(false);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        if (!result.isCompleted) {
          result.completeError(
            StateError(
              'AdMob megjelenítési hiba (${error.code}): ${error.message}',
            ),
          );
        }
      },
    );
    rewarded.show(
      onUserEarnedReward: (_, _) {
        if (!result.isCompleted) result.complete(true);
      },
    );
    return result.future;
  }

  Future<RewardedAd> _loadRewarded(String unitId) {
    final completer = Completer<RewardedAd>();
    RewardedAd.load(
      adUnitId: unitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: completer.complete,
        onAdFailedToLoad: (error) => completer.completeError(
          StateError(_admobLoadMessage(error)),
        ),
      ),
    );
    return completer.future;
  }

  static String _admobLoadMessage(LoadAdError error) {
    return switch (error.code) {
      0 => 'A reklám kérése érvénytelen. Ellenőrizd az alkalmazás beállításait.',
      1 => 'Nem sikerült betölteni a reklámot. Ellenőrizd az internetkapcsolatot.',
      2 => 'A reklámszolgáltatás jelenleg nem érhető el. Próbáld újra később.',
      3 => 'Most nincs elérhető reklám. Próbáld újra később.',
      _ => 'A reklámot most nem sikerült betölteni. Próbáld újra később.',
    };
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _updates.close();
  }
}
