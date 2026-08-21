import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/release.dart';
import 'releases_screen.dart';
import '../../widgets/release_preview_player.dart';
import '../../core/navigation/in_app_browser.dart';
import '../../services/label_purchase_service.dart';
import '../../core/errors/user_facing_error.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:url_launcher/url_launcher.dart';

class ReleaseDetailScreen extends StatefulWidget {
  final HuhsRelease release;

  const ReleaseDetailScreen({super.key, required this.release});

  @override
  State<ReleaseDetailScreen> createState() => _ReleaseDetailScreenState();
}

class _ReleaseDetailScreenState extends State<ReleaseDetailScreen> {
  final _purchases = LabelPurchaseService();
  List<ProductDetails> _products = const [];
  StreamSubscription<PurchaseDetails>? _updates;
  StreamSubscription<User?>? _authUpdates;
  String? _message;
  bool _unlocking = false;
  bool _adUnlocked = false;
  bool _checkingAdUnlock = true;
  bool _loadingProducts = false;
  final Set<String> _verifiedProducts = <String>{};
  final Set<String> _knownProductIds = <String>{};
  final Set<String> _handlingPurchaseKeys = <String>{};

  @override
  void initState() {
    super.initState();
    _knownProductIds.addAll(
      widget.release.products.map((product) => product.id),
    );
    _purchases.listen();
    _updates = _purchases.purchaseUpdates.listen(_handlePurchase);
    _authUpdates = FirebaseAuth.instance.authStateChanges().listen(
      _handleAuthChange,
    );
    _loadProducts();
    _loadAdUnlockStatus();
    _restorePurchases();
  }

  Future<void> _handleAuthChange(User? user) async {
    if (!mounted) return;
    setState(() {
      _adUnlocked = false;
      _checkingAdUnlock = user != null && !user.isAnonymous;
      _verifiedProducts.clear();
      _handlingPurchaseKeys.clear();
    });
    if (user == null || user.isAnonymous) return;
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

    var verified = false;
    final needsVerification =
        purchase.status == PurchaseStatus.purchased ||
        purchase.status == PurchaseStatus.restored;
    if (needsVerification) {
      try {
        verified = await _purchases.verifyPurchase(
          purchase: purchase,
          releaseId: widget.release.id,
        );
      } catch (_) {
        verified = false;
      }
    }

    final canComplete = !needsVerification || verified;
    final completed = canComplete
        ? await _purchases.completePurchase(purchase)
        : false;
    if (!completed || !verified) _handlingPurchaseKeys.remove(key);
    if (!mounted) return;
    setState(() {
      if (verified && completed) _verifiedProducts.add(purchase.productID);
      _message = verified && completed
          ? 'A vásárlás ellenőrzése és véglegesítése sikeres.'
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
    try {
      final unlocked = await _purchases.hasAdUnlock(
        widget.release.id,
        variant: _rewardVariant,
      );
      if (mounted &&
          FirebaseAuth.instance.currentUser?.uid == (expectedUid ?? user.uid)) {
        setState(() => _adUnlocked = unlocked);
      }
    } catch (_) {
      // A gomb előtt ismét ellenőrizzük; itt elég feloldani a betöltési állapotot.
    } finally {
      if (mounted) setState(() => _checkingAdUnlock = false);
    }
  }

  String get _rewardVariant => widget.release.isFree ? 'free_wav' : 'mp3_128';

  Future<void> _loadProducts() async {
    // Free releases intentionally have no Google Play product IDs. Do not
    // query Billing with an empty ID set or show a misleading product error.
    if (widget.release.products.isEmpty) return;
    if (_loadingProducts) return;
    if (mounted) setState(() => _loadingProducts = true);
    try {
      final products = await _purchases.loadProducts(
        widget.release.products.map((product) => product.id),
      );
      if (mounted) setState(() => _products = products);
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
    if (!mounted || _products.isNotEmpty) return;
    if (_purchases.lastNotFoundProductIds.isNotEmpty) {
      setState(
        () => _message =
            'Ehhez a kiadáshoz a Google Play-termék még nem érhető el vásárlásra.',
      );
    } else if (!_purchases.lastStoreAvailable) {
      setState(
        () => _message =
            'A vásárlás csak a Google Play Áruházból telepített alkalmazásban érhető el.',
      );
    }
  }

  @override
  void dispose() {
    _authUpdates?.cancel();
    _updates?.cancel();
    _purchases.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final release = widget.release;
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
          if (release.products.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              'Megvásárolható kiadások',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ...release.products.map((configured) {
              ProductDetails? product;
              for (final candidate in _products) {
                if (candidate.id == configured.id) product = candidate;
              }
              return _productCard(configured, product);
            }),
            if (_message != null)
              Text(_message!, style: const TextStyle(color: Colors.white70)),
            if (_products.isEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _loadingProducts ? null : _loadProducts,
                  icon: const Icon(Icons.refresh),
                  label: Text(
                    _loadingProducts ? 'Termékek betöltése…' : 'Újrapróbálás',
                  ),
                ),
              ),
          ],
          const SizedBox(height: 18),
          if (release.isFree)
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
          else
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
          if (release.products.isEmpty && _message != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _message!,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          if (release.versions.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Elérhető változatok',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: release.versions
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

  Widget _productCard(ReleaseProduct configured, ProductDetails? product) {
    final verified = _verifiedProducts.contains(configured.id);
    return Card(
      child: ListTile(
        title: Text(_productLabel(configured.id)),
        subtitle: Text(
          product?.description.isNotEmpty == true
              ? product!.description
              : 'Megvásárolható a Google Playen • ${configured.price} Ft',
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

  Future<void> _unlockRewarded() async {
    if (_unlocking) return;
    setState(() {
      _unlocking = true;
      _message = 'A jutalmazott reklám betöltése…';
    });
    try {
      final variant = _rewardVariant;
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      if (currentUid == null ||
          FirebaseAuth.instance.currentUser!.isAnonymous) {
        throw StateError('A reklámos feloldáshoz be kell jelentkezni.');
      }
      if (await _purchases.hasAdUnlock(widget.release.id, variant: variant)) {
        if (mounted) {
          setState(() {
            _adUnlocked = true;
            _message = 'Ez a release már fel van oldva.';
          });
        }
        return;
      }
      final earned = await _purchases.showRewardedAd(
        widget.release.id,
        variant: variant,
      );
      if (!earned) throw StateError('A reklám megtekintése nem fejeződött be.');
      if (mounted) {
        setState(() => _message = 'A reklám jóváírásának ellenőrzése…');
      }
      final unlocked = await _purchases.waitForAdUnlock(
        releaseId: widget.release.id,
        variant: variant,
      );
      if (!unlocked) {
        throw StateError(
          'A reklám lefutott, de a feloldás nem érkezett meg. Próbáld újra később.',
        );
      }
      if (mounted && FirebaseAuth.instance.currentUser?.uid == currentUid) {
        setState(() => _adUnlocked = true);
      }
      final downloaded = await _download(variant);
      if (mounted) {
        setState(
          () => _message = downloaded
              ? 'Feloldva, a letöltés elindult.'
              : 'Feloldva, de a letöltést nem sikerült elindítani.',
        );
      }
    } catch (error) {
      final message = error is StateError
          ? error.message.toString()
          : userFacingError(error);
      if (mounted) setState(() => _message = message);
    } finally {
      if (mounted) setState(() => _unlocking = false);
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
        releaseId: widget.release.id,
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
