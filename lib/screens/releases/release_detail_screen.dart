import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/release.dart';
import 'releases_screen.dart';
import '../../widgets/release_preview_player.dart';
import '../../core/navigation/in_app_browser.dart';
import '../../services/label_purchase_service.dart';
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
  String? _message;
  bool _unlocking = false;
  final Set<String> _verifiedProducts = <String>{};

  @override
  void initState() {
    super.initState();
    _purchases.listen();
    _updates = _purchases.purchaseUpdates.listen((purchase) async {
      if (!mounted) return;
      var verified = false;
      if (purchase.status == PurchaseStatus.purchased) {
        try {
          verified = await _purchases.verifyPurchase(
            purchase: purchase,
            releaseId: widget.release.id,
          );
        } catch (_) {}
      }
      setState(() {
        if (verified) _verifiedProducts.add(purchase.productID);
        _message = verified
            ? 'A vásárlás ellenőrzése sikeres.'
            : purchase.status == PurchaseStatus.purchased
            ? 'A vásárlás ellenőrzése sikertelen.'
            : purchase.status == PurchaseStatus.error
            ? 'A vásárlás sikertelen.'
            : null;
      });
    });
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final products = await _purchases.loadProducts(
        widget.release.products.map((product) => product.id),
      );
      if (mounted) setState(() => _products = products);
    } catch (_) {
      if (mounted) setState(() => _products = const []);
    }
  }

  @override
  void dispose() {
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
          ],
          const SizedBox(height: 18),
          Card(
            child: ListTile(
              title: const Text('128 kbps MP3 feloldása reklámmal'),
              subtitle: const Text(
                'A jutalmazott reklám megtekintése után a fájl letölthető.',
              ),
              trailing: FilledButton(
                onPressed: _unlocking ? null : _unlock128,
                child: const Text('Feloldás'),
              ),
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
                onPressed: product == null
                    ? () => setState(
                        () => _message =
                            'A vásárlás a Google Playből telepített alkalmazásban érhető el.',
                      )
                    : () => _buy(product),
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

  Future<void> _unlock128() async {
    if (_unlocking) return;
    setState(() {
      _unlocking = true;
      _message = 'A jutalmazott reklám betöltése…';
    });
    try {
      final earned = await _purchases.showRewardedAd(widget.release.id);
      if (!earned) throw StateError('A reklám megtekintése nem fejeződött be.');
      var downloaded = false;
      for (var attempt = 0; attempt < 6 && !downloaded; attempt++) {
        await Future<void>.delayed(const Duration(seconds: 2));
        downloaded = await _download('mp3_128');
      }
      if (!downloaded) {
        throw StateError(
          'A reklámos feloldás még nem érkezett meg, próbáld újra később.',
        );
      }
    } catch (error) {
      if (mounted) setState(() => _message = '$error');
    } finally {
      if (mounted) setState(() => _unlocking = false);
    }
  }

  Future<bool> _download(String variant) async {
    try {
      final url = await _purchases.getDownloadUrl(
        releaseId: widget.release.id,
        variant: variant,
      );
      return launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (error) {
      if (mounted) setState(() => _message = '$error');
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
