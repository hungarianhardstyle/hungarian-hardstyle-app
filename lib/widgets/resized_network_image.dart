import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/images/wordpress_image_url.dart';

/// Remote image that asks the CDN for the display-sized file.
///
/// [physicalWidth] is the pixel width the image is painted into
/// (`logical width * devicePixelRatio`), so the requested file is never smaller
/// than what the screen shows and never larger than the source. If the optimizer
/// cannot serve the image, the widget retries the original WordPress URL once so
/// an image can never disappear because of the CDN.
class ResizedNetworkImage extends StatelessWidget {
  const ResizedNetworkImage({
    super.key,
    required this.url,
    required this.physicalWidth,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.width,
    this.height,
    this.color,
    this.colorBlendMode,
    this.placeholder,
    this.errorWidget,
  });

  final String url;
  final int physicalWidth;
  final BoxFit fit;
  final Alignment alignment;
  final double? width;
  final double? height;
  final Color? color;
  final BlendMode? colorBlendMode;
  final Widget Function(BuildContext, String)? placeholder;
  final Widget Function(BuildContext, String, Object)? errorWidget;

  @override
  Widget build(BuildContext context) {
    final optimized = WordpressImageUrl.resized(
      url,
      physicalWidth: physicalWidth,
    );
    // Decode at the size that is actually served, so the bitmap is never scaled
    // up in memory while the widget shows it at its own size.
    final decodeWidth = WordpressImageUrl.targetWidth(
      url,
      physicalWidth: physicalWidth,
    );
    return _image(
      optimized,
      decodeWidth: decodeWidth,
      fallbackUrl: optimized == url ? null : url,
    );
  }

  Widget _image(
    String imageUrl, {
    required int decodeWidth,
    String? fallbackUrl,
  }) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit,
      alignment: alignment,
      width: width,
      height: height,
      color: color,
      colorBlendMode: colorBlendMode,
      memCacheWidth: decodeWidth,
      maxWidthDiskCache: decodeWidth,
      // NINCS áttűnés: a `CachedNetworkImage` alapértéke 500 ms be- és 1000 ms
      // kiúsztatás, ami **minden újraépítésnél lefut**. Görgetés közben a lista
      // elemei újraépülnek, ezért a (gyorsítótárból azonnal megjövő) kép
      // újra „beúszott" — a felhasználó ezt **villogásként** látta (a DJ-knél,
      // híreknél, eseményeknél ugyanígy). A gyorsítótárból érkező képnél nincs
      // mit áttűnni, ezért a nulla a helyes érték.
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholder: placeholder,
      errorWidget: (context, failedUrl, error) {
        if (fallbackUrl != null) {
          return _image(fallbackUrl, decodeWidth: decodeWidth);
        }
        return errorWidget?.call(context, failedUrl, error) ??
            const SizedBox.shrink();
      },
    );
  }
}
