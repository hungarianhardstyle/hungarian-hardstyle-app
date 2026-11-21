import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/i18n/tr.dart';
import '../../models/post.dart';
import '../../services/image_saver.dart';
import '../../widgets/app_text.dart';

class GalleryScreen extends StatefulWidget {
  final List<GalleryImage> images;
  final int initialIndex;

  const GalleryScreen({super.key, required this.images, this.initialIndex = 0});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  late final PageController _controller;

  late int _current;

  @override
  void initState() {
    super.initState();

    _current = widget.initialIndex;

    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          tooltip: tr(context, 'Bezárás'),
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).maybePop(),
        ),

        title: Text("${_current + 1} / ${widget.images.length}"),
        actions: [
          IconButton(
            tooltip: tr(context, 'Kép mentése'),
            icon: const Icon(Icons.download_outlined),
            onPressed: () async {
              try {
                await ImageSaver.saveFromUrl(
                  widget.images[_current].url,
                  name: 'huhs-gallery-${widget.images[_current].id}.jpg',
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: AppText('Kép mentve a galériába.')),
                );
              } catch (error) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: AppText(
                      'A kép mentése nem sikerült. Ellenőrizd a tárhelyengedélyt, majd próbáld újra.',
                    ),
                  ),
                );
              }
            },
          ),
        ],
      ),

      body: PageView.builder(
        controller: _controller,

        onPageChanged: (index) {
          setState(() {
            _current = index;
          });
        },

        itemCount: widget.images.length,

        itemBuilder: (context, index) {
          final image = widget.images[index];

          return _ZoomPage(
            image: image,
            onClose: () => Navigator.of(context).maybePop(),
          );
        },
      ),
    );
  }
}

/// Egy kép lightbox-szerűen: csippentés és dupla koppintás a nagyításhoz,
/// egy koppintás (nagyítatlan képre vagy a háttérre) bezárja a nézetet.
class _ZoomPage extends StatefulWidget {
  const _ZoomPage({required this.image, required this.onClose});

  final GalleryImage image;
  final VoidCallback onClose;

  @override
  State<_ZoomPage> createState() => _ZoomPageState();
}

class _ZoomPageState extends State<_ZoomPage> {
  final _transform = TransformationController();
  Offset _tap = Offset.zero;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  bool get _zoomed => _transform.value.getMaxScaleOnAxis() > 1.01;

  void _toggleZoom() {
    if (_zoomed) {
      _transform.value = Matrix4.identity();
      return;
    }
    // 2,5x nagyítás az ujj helyére.
    _transform.value = Matrix4.identity()
      ..translateByDouble(-_tap.dx * 1.5, -_tap.dy * 1.5, 0, 1)
      ..scaleByDouble(2.5, 2.5, 1, 1);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (!_zoomed) widget.onClose();
      },
      onDoubleTapDown: (details) => _tap = details.localPosition,
      onDoubleTap: _toggleZoom,
      child: Center(
        child: InteractiveViewer(
          transformationController: _transform,
          minScale: 1,
          maxScale: 5,
          child: Hero(
            tag: "gallery_${widget.image.id}",
            child: CachedNetworkImage(
              imageUrl: widget.image.url,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
