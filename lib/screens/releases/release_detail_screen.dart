import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/release.dart';
import 'releases_screen.dart';
import '../../widgets/release_preview_player.dart';
import '../../core/navigation/in_app_browser.dart';
import '../../services/label_purchase_service.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

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
          if (_products.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              'Megvásárolható kiadások',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ..._products.map(
              (product) => Card(
                child: ListTile(
                  title: Text(_productLabel(product.id)),
                  subtitle: Text(product.description),
                  trailing: FilledButton(
                    onPressed: () => _purchases.buy(product),
                    child: Text(product.price),
                  ),
                ),
              ),
            ),
            if (_message != null)
              Text(_message!, style: const TextStyle(color: Colors.white70)),
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

  String _productLabel(String id) => id.endsWith('_wav')
      ? 'WAV / lossless'
      : id.endsWith('_mp3_320')
      ? 'MP3 320 kbps'
      : id;

  String _label(String key) => switch (key) {
    'spotify' => 'Spotify',
    'apple_music' => 'Apple Music',
    'beatport' => 'Beatport',
    'hardstyle_com' => 'Hardstyle.com',
    'youtube' => 'YouTube',
    _ => key,
  };
}
