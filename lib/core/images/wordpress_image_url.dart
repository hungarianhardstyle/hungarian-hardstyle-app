/// Server-side image sizing for WordPress media through the site's Jetpack
/// Photon CDN.
///
/// Photon resizes the original file while keeping its format, so a PNG stays a
/// PNG (transparency included) and nothing is upscaled. Callers must pass the
/// **physical** pixel width of the box the image is painted into: as long as
/// the request is at least that wide, the painted result cannot look softer
/// than the file served today, while the download gets much smaller.
///
/// Measured on the live site for a 1024 px wide featured image:
/// the original file is 1.5 MB, Photon serves the same 1024 px as 0.37 MB and a
/// 200 px avatar as 0.02 MB.
class WordpressImageUrl {
  const WordpressImageUrl._();

  static const photonHost = 'i0.wp.com';
  static const _wordpressHostSuffix = 'hungarianhardstyle.hu';
  static const _uploadsSegment = '/wp-content/uploads/';
  static const _minWidth = 48;
  static const _maxWidth = 4096;
  static final _derivativePattern = RegExp(r'-(\d+)x(\d+)\.[A-Za-z0-9]+$');

  /// Width encoded in a WordPress derivative file name (`image-1024x683.png`).
  ///
  /// Returns 0 when the URL carries no size suffix, which means it points at the
  /// original upload and may legitimately be larger than any requested width.
  static int derivativeWidth(String url) {
    final path = Uri.tryParse(url.trim())?.path ?? '';
    final match = _derivativePattern.firstMatch(path);
    if (match == null) return 0;
    return int.tryParse(match.group(1) ?? '') ?? 0;
  }

  static bool isWordpressMedia(Uri uri) {
    final host = uri.host.toLowerCase();
    return (host == _wordpressHostSuffix ||
            host.endsWith('.$_wordpressHostSuffix')) &&
        uri.path.contains(_uploadsSegment);
  }

  /// [url] served at [physicalWidth] pixels wide, or unchanged when it is not a
  /// WordPress media URL (Cloudinary, embeds and other hosts are left alone).
  static String resized(String url, {required int physicalWidth}) {
    final value = url.trim();
    if (value.isEmpty) return value;
    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty) return value;

    final width = _targetWidth(physicalWidth, uri.path);
    if (uri.host.toLowerCase() == photonHost) {
      // Already optimized: only make sure the width is pinned.
      return _withWidth(uri, width);
    }
    if (!isWordpressMedia(uri)) return value;

    final photonUri = Uri(
      scheme: 'https',
      host: photonHost,
      path: '${uri.host}${uri.path}',
      queryParameters: uri.queryParameters.isEmpty ? null : uri.queryParameters,
    );
    return _withWidth(photonUri, width);
  }

  /// The width the CDN actually serves for [physicalWidth] on [url].
  ///
  /// Callers use this for the in-memory decode size as well, so the decoded
  /// bitmap matches the downloaded file instead of being scaled up.
  static int targetWidth(String url, {required int physicalWidth}) {
    final uri = Uri.tryParse(url.trim());
    return _targetWidth(physicalWidth, uri?.path ?? '');
  }

  /// The width Photon actually has to produce: the requested physical width,
  /// never above the width the referenced derivative already provides. Requesting
  /// more would only make Photon upscale (or serve a larger file for no gain).
  static int _targetWidth(int physicalWidth, String sourcePath) {
    final requested = physicalWidth.clamp(_minWidth, _maxWidth);
    final available = derivativeWidth(sourcePath);
    if (available <= 0) return requested;
    return requested < available ? requested : available;
  }

  static String _withWidth(Uri uri, int width) {
    final query = Map<String, String>.from(uri.queryParameters)
      ..['w'] = '$width';
    return uri.replace(queryParameters: query).toString();
  }
}
