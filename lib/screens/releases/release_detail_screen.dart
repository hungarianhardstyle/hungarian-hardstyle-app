import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/release.dart';
import 'releases_screen.dart';
import '../../widgets/release_preview_player.dart';
import '../../core/navigation/in_app_browser.dart';
import '../../services/label_purchase_service.dart';
import '../../services/wordpress_service.dart';
import '../../core/errors/user_facing_error.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class ReleaseDetailScreen extends StatefulWidget {
  final HuhsRelease release;

  const ReleaseDetailScreen({super.key, required this.release});

  @override
  State<ReleaseDetailScreen> createState() => _ReleaseDetailScreenState();
}

class _ReleaseDetailScreenState extends State<ReleaseDetailScreen> {
  final _purchases = LabelPurchaseService.shared;
  late HuhsRelease _release;
  List<ProductDetails> _products = const [];
  StreamSubscription<PurchaseDetails>? _updates;
  StreamSubscription<User?>? _authUpdates;
  String? _message;
  bool _unlocking = false;
  bool _adUnlocked = false;
  bool _externalLinkUnlocked = false;
  bool _checkingAdUnlock = true;
  bool _loadingProducts = false;
  Timer? _productRetryTimer;
  int _productRetryAttempts = 0;
  final Set<String> _verifiedProducts = <String>{};
  final Set<String> _knownProductIds = <String>{};
  final Set<String> _handlingPurchaseKeys = <String>{};

  @override
  void initState() {
    super.initState();
    _release = widget.release;
    _knownProductIds.addAll(_release.products.map((product) => product.id));
    _purchases.listen();
    _updates = _purchases.purchaseUpdates.listen(_handlePurchase);
    _authUpdates = FirebaseAuth.instance.authStateChanges().listen(
      _handleAuthChange,
    );
    unawaited(_loadCachedEntitlements());
    _loadFullRelease();
    _loadAdUnlockStatus();
    _restorePurchases();
  }

  Future<void> _loadFullRelease() async {
    try {
      final fullRelease = await WordpressService().getRelease(_release.id);
      if (!mounted) return;
      setState(() {
        _release = fullRelease;
        _knownProductIds
          ..clear()
          ..addAll(fullRelease.products.map((product) => product.id));
      });
    } catch (_) {
      // Keep the summary visible; product retry can recover later.
    }
    if (mounted) await _loadProducts();
  }

  Future<void> _handleAuthChange(User? user) async {
    if (!mounted) return;
    setState(() {
      _adUnlocked = false;
      _externalLinkUnlocked = false;
      _checkingAdUnlock = user != null && !user.isAnonymous;
      _verifiedProducts.clear();
      _handlingPurchaseKeys.clear();
    });
    if (user == null || user.isAnonymous) return;
    unawaited(_loadCachedEntitlements(user.uid));
    await _loadAdUnlockStatus(user.uid);
    if (mounted) await _restorePurchases();
  }

  Future<void> _handlePurchase(PurchaseDetails purchase) async {
    if (!_knownProductIds.contains(purchase.productID)) {
      if (purchase.status == PurchaseStatus.error ||
          purchase.status == PurchaseStatus.canceled) {
        await _purchases.completePurchase(purchase);
      }
      return;
    }
    final key =
        '${purchase.productID}:${purchase.verificationData.serverVerificationData}';
    if (!_handlingPurchaseKeys.add(key)) return;

    // Google Play reports an already-owned non-consumable as an error and
    // does not include the entitlement token in that error event. Do not
    // leave the screen on the price button: ask Play for the owned purchase
    // again so the normal restored -> server verification -> download path
    // can populate _verifiedProducts.
    if (purchase.status == PurchaseStatus.error &&
        _purchases.isAlreadyOwned(purchase)) {
      _handlingPurchaseKeys.remove(key);
      if (mounted) {
        setState(
          () => _message =
              'A meglévő Google Play-vásárlás visszaállítása folyamatban van…',
        );
      }
      await _restorePurchases();
      return;
    }

    var verified = false;
    final needsVerification =
        purchase.status == PurchaseStatus.purchased ||
        purchase.status == PurchaseStatus.restored;
    if (needsVerification) {
      try {
        verified = await _purchases.verifyPurchase(
          purchase: purchase,
          releaseId: _release.id,
        );
      } catch (_) {
        verified = false;
      }
    }

    final canComplete = !needsVerification || verified;
    final completed = canComplete
        ? await _purchases.completePurchase(purchase)
        : false;
    // Server verification is the authorization boundary for downloads. A
    // delayed Play acknowledgement must not hide the download button for an
    // already-owned, otherwise valid purchase; completePurchase remains
    // retryable through the purchase stream.
    // A verified purchase whose acknowledgement failed must remain retryable;
    // otherwise the next purchase-stream event is discarded as a duplicate.
    if (!verified || !completed) {
      _handlingPurchaseKeys.remove(key);
    } else {
      _purchases.acknowledgePurchaseEvent(purchase);
    }
    if (!mounted) return;
    setState(() {
      if (verified) _verifiedProducts.add(purchase.productID);
      if (verified) unawaited(_cacheVerifiedProduct(purchase.productID));
      _message = verified
          ? completed
                ? 'A vásárlás ellenőrzése és véglegesítése sikeres.'
                : 'A vásárlás ellenőrzése sikeres, a Play-véglegesítés még folyamatban van.'
          : purchase.status == PurchaseStatus.purchased ||
                purchase.status == PurchaseStatus.restored
          ? completed
                ? 'A vásárlás ellenőrzése sikertelen.'
                : 'A vásárlás ellenőrzése vagy véglegesítése még nem sikerült.'
          : purchase.status == PurchaseStatus.error
          ? _purchases.purchaseErrorMessage(purchase)
          : null;
    });
  }

  Future<void> _restorePurchases() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      if (mounted) {
        setState(
          () => _message =
              'A meglévő vásárlás visszaállításához be kell jelentkezni.',
        );
      }
      return;
    }
    try {
      await _purchases.restore();
    } catch (_) {
      if (mounted) {
        setState(
          () => _message =
              'A korábbi Google Play-vásárlások visszaállítása nem sikerült.',
        );
      }
    }
  }

  Future<void> _loadAdUnlockStatus([String? expectedUid]) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      if (mounted) setState(() => _checkingAdUnlock = false);
      return;
    }
    final cached = await _readCachedAdUnlock(user.uid);
    if (cached &&
        mounted &&
        FirebaseAuth.instance.currentUser?.uid == (expectedUid ?? user.uid)) {
      setState(() {
        _adUnlocked = true;
        _checkingAdUnlock = false;
      });
    }
    try {
      final unlocked = await _purchases.hasAdUnlock(
        _release.id,
        variant: _rewardVariant,
      );
      final externalUnlocked =
          _release.isFree &&
          _release.freeExternalLink.isNotEmpty &&
          await _purchases.hasAdUnlock(_release.id, variant: 'free_link');
      if (mounted &&
          FirebaseAuth.instance.currentUser?.uid == (expectedUid ?? user.uid)) {
        setState(() {
          _adUnlocked = unlocked;
          _externalLinkUnlocked = externalUnlocked;
        });
        if (unlocked) unawaited(_cacheAdUnlock(user.uid));
      }
    } catch (_) {
      // A gomb előtt ismét ellenőrizzük; itt elég feloldani a betöltési állapotot.
    } finally {
      if (mounted) setState(() => _checkingAdUnlock = false);
    }
  }

  Future<void> _loadCachedEntitlements([String? expectedUid]) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return;
    final uid = expectedUid ?? user.uid;
    final preferences = await SharedPreferences.getInstance();
    final cached = <String>{};
    for (final product in _release.products) {
      if (preferences.getBool(_purchaseCacheKey(uid, product.id)) == true) {
        cached.add(product.id);
      }
    }
    if (!mounted || FirebaseAuth.instance.currentUser?.uid != uid) return;
    if (cached.isNotEmpty) {
      setState(() => _verifiedProducts.addAll(cached));
    }
  }

  Future<void> _cacheVerifiedProduct(String productId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_purchaseCacheKey(uid, productId), true);
  }

  Future<bool> _readCachedAdUnlock(String uid) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_adCacheKey(uid)) == true;
  }

  Future<void> _cacheAdUnlock(String uid) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_adCacheKey(uid), true);
  }

  String _purchaseCacheKey(String uid, String productId) =>
      'label_entitlement_${uid}_$productId';

  String _adCacheKey(String uid) =>
      'label_ad_unlock_${uid}_${_release.id}_$_rewardVariant';

  String get _rewardVariant => _release.isFree ? 'free_wav' : 'mp3_128';

  Future<void> _loadProducts() async {
    // Free releases intentionally have no Google Play product IDs. Do not
    // query Billing with an empty ID set or show a misleading product error.
    if (_release.isFree) {
      _productRetryTimer?.cancel();
      _productRetryTimer = null;
      _productRetryAttempts = 0;
      if (mounted && _message != null) {
        setState(() => _message = null);
      }
      return;
    }
    // The detail page may have been opened before the backend wrote the new
    // Play IDs back to WordPress. Refresh that release before querying Billing
    // so a retry can recover without forcing the user back to the list.
    if (_loadingProducts) return;
    if (mounted) {
      setState(() {
        _loadingProducts = true;
        _message = null;
      });
    }
    try {
      if (_productRetryAttempts > 0 || _release.products.isEmpty) {
        await _refreshReleaseFromWordPress();
      }
      if (_release.products.isEmpty) {
        if (mounted) {
          setState(
            () => _message =
                'A Play-termékazonosítók még nem érkeztek meg. Újrapróbálom automatikusan.',
          );
        }
        _scheduleProductRetry();
        return;
      }

      final products = await _purchases.loadProducts(
        _release.products.map((product) => product.id),
      );
      if (mounted) {
        setState(() {
          _products = products;
          final foundIds = products.map((product) => product.id).toSet();
          final allConfiguredProductsFound = _release.products.every(
            (configured) => foundIds.contains(configured.id),
          );
          if (allConfiguredProductsFound) {
            _productRetryAttempts = 0;
            _productRetryTimer?.cancel();
            _productRetryTimer = null;
          }
          if (products.isNotEmpty) _message = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _products = const [];
          _message =
              'A Google Play terméklista most nem tölthető be. Próbáld újra később.';
        });
      }
    } finally {
      if (mounted) setState(() => _loadingProducts = false);
    }
    if (!mounted) return;
    final allConfiguredProductsFound = _release.products.every(
      (configured) => _products.any((product) => product.id == configured.id),
    );
    if (allConfiguredProductsFound) return;
    if (_purchases.lastNotFoundProductIds.isNotEmpty) {
      setState(
        () => _message =
            'A Google Play Billing ezen az eszközön még nem adta vissza a kiadvány termékét. Újrapróbálom automatikusan.',
      );
      _scheduleProductRetry();
    } else if (!_purchases.lastStoreAvailable) {
      setState(
        () => _message =
            'A Google Play Billing szolgáltatás még nem áll készen. Újrapróbálom automatikusan.',
      );
      _scheduleProductRetry();
    } else {
      setState(
        () => _message =
            'A Google Play Billing lekérdezése nem adott vissza terméket. Újrapróbálom automatikusan.',
      );
      _scheduleProductRetry();
    }
  }

  void _scheduleProductRetry() {
    if (!mounted || _loadingProducts || _productRetryTimer != null) return;
    // Play may need time to propagate a newly-created catalog item to the
    // device Billing service. Keep polling until every configured product is
    // returned; back off so this does not hammer Billing while the app stays
    // open for a long time. _loadProducts stops the loop when all are found.
    const delays = <Duration>[
      Duration(seconds: 5),
      Duration(seconds: 15),
      Duration(seconds: 30),
      Duration(minutes: 1),
      Duration(minutes: 2),
      Duration(minutes: 5),
    ];
    final delay = delays[_productRetryAttempts.clamp(0, delays.length - 1)];
    _productRetryTimer = Timer(delay, () {
      _productRetryTimer = null;
      _productRetryAttempts++;
      if (mounted) unawaited(_loadProducts());
    });
  }

  Future<void> _retryProductsManually() async {
    _productRetryAttempts = 0;
    _productRetryTimer?.cancel();
    _productRetryTimer = null;
    await _refreshReleaseFromWordPress();
    await _loadProducts();
  }

  Future<void> _refreshReleaseFromWordPress() async {
    try {
      final next = await WordpressService().getRelease(_release.id);
      if (!mounted) return;
      final nextIds = next.products.map((product) => product.id).toSet();
      setState(() {
        _release = next;
        _knownProductIds
          ..clear()
          ..addAll(nextIds);
      });
    } catch (_) {
      // Billing retry remains available if WordPress is temporarily offline.
    }
  }

  @override
  void dispose() {
    _productRetryTimer?.cancel();
    _authUpdates?.cancel();
    _updates?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final release = _release;
    return Scaffold(
      appBar: AppBar(title: Text(release.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
        children: [
          if (release.coverUrl.isNotEmpty)
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                  imageUrl: release.coverUrl,
                  fit: BoxFit.contain,
                  memCacheWidth: 900,
                  maxWidthDiskCache: 1200,
                  color: const Color(0xFF171717),
                  colorBlendMode: BlendMode.dstOver,
                ),
              ),
            ),
          const SizedBox(height: 18),
          Text(
            release.title,
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
          ),
          if (release.genre.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                release.genre,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          if (release.releaseDate.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Megjelenés: ${release.releaseDate}',
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: release.artists
                .map(
                  (artist) => ActionChip(
                    label: Text(artist.name),
                    avatar: const Icon(Icons.person_outline, size: 18),
                    onPressed: artist.id == 0
                        ? null
                        : () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ReleasesScreen(
                                artistId: artist.id,
                                artistName: artist.name,
                              ),
                            ),
                          ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 20),
          ...release.tracks.asMap().entries.map(
            (entry) =>
                ReleasePreviewPlayer(track: entry.value, index: entry.key),
          ),
          if (release.audioStatus == 'queued')
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('A hanganyag feldolgozása folyamatban van.'),
            ),
          if (release.audioStatus == 'failed')
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('A hanganyag feldolgozása nem sikerült.'),
            ),
          if (!release.isFree && release.products.isNotEmpty) ...[
            const SizedBox(height: 20),
            ...release.products
                .where(
                  (configured) =>
                      _verifiedProducts.contains(configured.id) ||
                      _products.any((product) => product.id == configured.id),
                )
                .map(
                  (configured) =>
                      _productCard(configured, _findProduct(configured.id)),
                ),
            if (_message != null)
              Text(_message!, style: const TextStyle(color: Colors.white70)),
          ],
          if (!release.isFree &&
              release.audioStatus != 'queued' &&
              release.audioStatus != 'failed' &&
              _products.isEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _loadingProducts ? null : _retryProductsManually,
                icon: const Icon(Icons.refresh),
                label: Text(
                  _loadingProducts ? 'Termékek betöltése…' : 'Újrapróbálás',
                ),
              ),
            ),
          const SizedBox(height: 18),
          if (release.hasFreeWav)
            Card(
              child: ListTile(
                title: const Text('WAV feloldása reklámmal'),
                subtitle: const Text(
                  'A jutalmazott reklám megtekintése után a WAV letölthető.',
                ),
                trailing: FilledButton(
                  onPressed: _unlocking || _checkingAdUnlock
                      ? null
                      : _adUnlocked
                      ? () => _download('free_wav')
                      : _unlockRewarded,
                  child: Text(_adUnlocked ? 'Letöltés' : 'Feloldás'),
                ),
              ),
            )
          else if (!release.isFree)
            Card(
              child: ListTile(
                title: const Text('128 kbps MP3 feloldása reklámmal'),
                subtitle: const Text(
                  'A jutalmazott reklám megtekintése után a fájl letölthető.',
                ),
                trailing: FilledButton(
                  onPressed: _unlocking || _checkingAdUnlock
                      ? null
                      : _adUnlocked
                      ? () => _download('mp3_128')
                      : _unlockRewarded,
                  child: Text(_adUnlocked ? 'Letöltés' : 'Feloldás'),
                ),
              ),
            ),
          if (!release.isFree && release.products.isEmpty && _message != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _message!,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          if (release.isFree && release.freeExternalLink.isNotEmpty)
            Card(
              child: ListTile(
                title: const Text('Ingyenes külső link'),
                subtitle: const Text(
                  'A jutalmazott reklám megtekintése után megnyitható.',
                ),
                trailing: FilledButton(
                  onPressed: _unlocking || _checkingAdUnlock
                      ? null
                      : _externalLinkUnlocked
                      ? _openFreeExternalLink
                      : _unlockExternalLink,
                  child: Text(_externalLinkUnlocked ? 'Megnyitás' : 'Feloldás'),
                ),
              ),
            ),
          if (release.versions
              .where((version) => !(release.isFree && version.type == 'radio'))
              .isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Elérhető változatok',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: release.versions
                  .where(
                    (version) => !(release.isFree && version.type == 'radio'),
                  )
                  .map(
                    (version) => Chip(label: Text(_versionLabel(version.type))),
                  )
                  .toList(growable: false),
            ),
          ],
          if (release.links.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              'Hol érhető el?',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: release.links.entries
                  .map(
                    (entry) => OutlinedButton.icon(
                      onPressed: () => openInAppBrowser(context, entry.value),
                      icon: const Icon(Icons.open_in_new),
                      label: Text(_label(entry.key)),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  String _productLabel(String id) {
    final radio = id.contains('_radio_');
    final extended = id.contains('_extended_');
    final version = radio
        ? 'Radio'
        : extended
        ? 'Extended'
        : '';
    final format = id.endsWith('_wav')
        ? 'WAV / lossless'
        : id.endsWith('_mp3_320')
        ? 'MP3 320 kbps'
        : id;
    return version.isEmpty ? format : '$version – $format';
  }

  ProductDetails? _findProduct(String productId) {
    for (final product in _products) {
      if (product.id == productId) return product;
    }
    return null;
  }

  Widget _productCard(ReleaseProduct configured, ProductDetails? product) {
    final verified = _verifiedProducts.contains(configured.id);
    return Card(
      child: ListTile(
        title: Text(
          _productLabel(configured.id),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          product?.description.isNotEmpty == true
              ? product!.description
              : 'Megvásárolható a Google Playen • ${configured.price} Ft',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: verified
            ? IconButton(
                tooltip: 'Letöltés',
                icon: const Icon(Icons.download),
                onPressed: () => _download(_downloadVariant(configured.id)),
              )
            : FilledButton(
                onPressed: product == null ? null : () => _buy(product),
                /*
                    ? () => setState(
                        () => _message =
                            'A vásárlás a Google Playből telepített alkalmazásban érhető el.',
                      )
                    : () => _buy(product), */
                child: Text(product?.price ?? '${configured.price} Ft'),
              ),
      ),
    );
  }

  Future<void> _buy(ProductDetails product) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      if (mounted) {
        setState(() => _message = 'A vásárláshoz előbb be kell jelentkezni.');
      }
      return;
    }
    try {
      final started = await _purchases.buy(product);
      if (!started && mounted) {
        setState(
          () => _message =
              'A Google Play vásárlási ablakát nem sikerült megnyitni.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'A Google Play vásárlás nem indítható el.');
      }
    }
  }

  String _downloadVariant(String productId) {
    final match = RegExp(r'^huhs_release_[0-9]+_(.+)$').firstMatch(productId);
    return match?.group(1) ?? (productId.endsWith('_wav') ? 'wav' : 'mp3_320');
  }

  Future<bool> _claimReward(String variant) async {
    if (_unlocking) return false;
    setState(() {
      _unlocking = true;
      _message = 'A jutalmazott reklám betöltése…';
    });
    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      if (currentUid == null ||
          FirebaseAuth.instance.currentUser!.isAnonymous) {
        throw StateError('A reklámos feloldáshoz be kell jelentkezni.');
      }
      if (await _purchases.hasAdUnlock(_release.id, variant: variant)) {
        return true;
      }
      final earned = await _purchases.showRewardedAd(
        _release.id,
        variant: variant,
      );
      if (!earned) throw StateError('A reklám megtekintése nem fejeződött be.');
      if (mounted) {
        setState(() => _message = 'A reklám jóváírásának ellenőrzése…');
      }
      final unlocked = await _purchases.waitForAdUnlock(
        releaseId: _release.id,
        variant: variant,
      );
      if (!unlocked) {
        throw StateError(
          'A reklám lefutott, de a feloldás nem érkezett meg. Próbáld újra később.',
        );
      }
      if (mounted && FirebaseAuth.instance.currentUser?.uid == currentUid) {
        return true;
      }
      return false;
    } catch (error) {
      final message = error is StateError
          ? error.message.toString()
          : userFacingError(error);
      if (mounted) setState(() => _message = message);
      return false;
    } finally {
      if (mounted) setState(() => _unlocking = false);
    }
  }

  Future<void> _unlockRewarded() async {
    final unlocked = await _claimReward(_rewardVariant);
    if (!unlocked || !mounted) return;
    setState(() => _adUnlocked = true);
    final downloaded = await _download(_rewardVariant);
    if (mounted) {
      setState(
        () => _message = downloaded
            ? 'Feloldva, a letöltés elindult.'
            : 'Feloldva, de a letöltést nem sikerült elindítani.',
      );
    }
  }

  Future<void> _unlockExternalLink() async {
    final unlocked = await _claimReward('free_link');
    if (!unlocked || !mounted) return;
    setState(() => _externalLinkUnlocked = true);
    await _openFreeExternalLink();
  }

  Future<void> _openFreeExternalLink() async {
    final uri = Uri.tryParse(_release.freeExternalLink);
    if (uri == null || !{'http', 'https'}.contains(uri.scheme)) {
      setState(() => _message = 'Az ingyenes külső link érvénytelen.');
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      setState(() => _message = 'A linket nem sikerült megnyitni.');
    }
  }

  Future<bool> _download(String variant) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      if (mounted) {
        setState(() => _message = 'A letöltéshez be kell jelentkezni.');
      }
      return false;
    }
    try {
      final url = await _purchases.getDownloadUrl(
        releaseId: _release.id,
        variant: variant,
      );
      return launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (error) {
      if (mounted) setState(() => _message = userFacingError(error));
      return false;
    }
  }

  String _versionLabel(String type) => switch (type) {
    'radio' => 'Radio verzió',
    'extended' => 'Extended verzió',
    _ => type,
  };

  String _label(String key) => switch (key) {
    'spotify' => 'Spotify',
    'apple_music' => 'Apple Music',
    'beatport' => 'Beatport',
    'hardstyle_com' => 'Hardstyle.com',
    'youtube' => 'YouTube',
    _ => key,
  };
}
