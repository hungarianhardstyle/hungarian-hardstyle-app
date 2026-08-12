import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:cloud_functions/cloud_functions.dart';

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

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _updates.close();
  }
}
