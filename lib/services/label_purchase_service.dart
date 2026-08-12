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

  Stream<PurchaseDetails> get purchaseUpdates => _updates.stream;

  Future<List<ProductDetails>> loadProducts(Iterable<String> productIds) async {
    final available = await _store.isAvailable();
    if (!available) return const [];
    final response = await _store.queryProductDetails(productIds.toSet());
    if (response.error != null) {
      throw StateError(response.error!.message);
    }
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

  Future<void> buy(ProductDetails product) => _store.buyNonConsumable(
    purchaseParam: PurchaseParam(productDetails: product),
  );

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

  Future<bool> showRewardedAd(int releaseId) async {
    final unitId = enableTestAds
        ? 'ca-app-pub-3940256099942544/5224354917'
        : productionRewardedAdUnitId;
    if (unitId.isEmpty) return false;
    final rewarded = await _loadRewarded(unitId);
    if (rewarded == null) return false;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return false;
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
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        if (!result.isCompleted) result.complete(false);
      },
    );
    rewarded.show(
      onUserEarnedReward: (_, _) {
        if (!result.isCompleted) result.complete(true);
      },
    );
    return result.future;
  }

  Future<RewardedAd?> _loadRewarded(String unitId) {
    final completer = Completer<RewardedAd?>();
    RewardedAd.load(
      adUnitId: unitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: completer.complete,
        onAdFailedToLoad: (_) => completer.complete(null),
      ),
    );
    return completer.future;
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _updates.close();
  }
}
