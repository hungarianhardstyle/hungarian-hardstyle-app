import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/post.dart';

class GalleryScreen extends StatefulWidget {
  final List<GalleryImage> images;
  final int initialIndex;

  const GalleryScreen({
    super.key,
    required this.images,
    this.initialIndex = 0,
  });

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

    _controller = PageController(
      initialPage: widget.initialIndex,
    );
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

        title: Text(
          "${_current + 1} / ${widget.images.length}",
        ),
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

          return Center(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 5,

              child: Hero(
                tag: "gallery_${image.id}",

                child: CachedNetworkImage(
                  imageUrl: image.url,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}