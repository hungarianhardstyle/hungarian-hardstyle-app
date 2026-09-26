import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../core/i18n/app_strings.dart';
import '../core/i18n/tr.dart';
import '../core/media/youtube_embed.dart';
import '../core/navigation/in_app_browser.dart';
import '../models/post.dart';
import 'app_text.dart';

class PostEmbedCard extends StatefulWidget {
  final PostEmbed embed;
  const PostEmbedCard({super.key, required this.embed});

  @override
  State<PostEmbedCard> createState() => _PostEmbedCardState();
}

class _PostEmbedCardState extends State<PostEmbedCard> {
  WebViewController? _controller;
  bool _loading = true;

  /// A YouTube-videó azonosítója — `null`, ha nem kinyerhető (akkor marad a
  /// régi, külső megnyitó kártya).
  String? get _videoId => widget.embed.type == 'youtube'
      ? youTubeVideoId(widget.embed.url)
      : null;

  @override
  void initState() {
    super.initState();
    if (widget.embed.type == 'youtube') {
      final videoId = _videoId;
      if (videoId == null) return;
      // A YouTube-lejátszót **saját HTML-be** ágyazzuk, és a `baseUrl` adja a
      // valódi origin-t. Enélkül a WebView-nak nincs hivatkozója, és a YouTube
      // „Video unavailable" hibát ad — ezért nyitotta eddig külső appot a
      // tulajdonos által jelzett kártya.
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        // A WebView saját user-agentje (`…; wv`) alapján a YouTube „nem
        // támogatott böngészőt" lát, ezért explicit Chrome-fejléc kell.
        ..setUserAgent(youTubeEmbedUserAgent)
        ..setBackgroundColor(const Color(0xFF000000))
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (_) {
              if (mounted) setState(() => _loading = false);
            },
            // A lejátszón BELÜLI navigációt engedjük (ez a videó kiválasztása),
            // de új lapot nem nyitunk: minden az appon belül marad.
            onNavigationRequest: (request) => NavigationDecision.navigate,
          ),
        )
        ..loadHtmlString(
          youTubeEmbedHtml(videoId),
          baseUrl: youTubeEmbedBaseUrl,
        );
      return;
    }

    final uri = _embedUri(widget.embed);
    if (uri != null) {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0xFF111111))
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (_) {
              if (mounted) setState(() => _loading = false);
            },
          ),
        )
        ..loadRequest(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embed.type == 'youtube' && _videoId == null) {
      return _YouTubeLinkCard(embed: widget.embed);
    }

    final controller = _controller;
    if (controller == null) return _ExternalLink(embed: widget.embed);

    final isYouTube = widget.embed.type == 'youtube';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          // A YouTube 16:9 — így nincs fekete csík a lejátszó körül.
          height: isYouTube ? null : _height(widget.embed.type),
          margin: EdgeInsets.fromLTRB(20, 0, 20, isYouTube ? 8 : 20),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: isYouTube ? const Color(0xFF000000) : const Color(0xFF111111),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: isYouTube
              ? AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: WebViewWidget(controller: controller),
                      ),
                      if (_loading) const _EmbedLoading(),
                    ],
                  ),
                )
              : Stack(
                  children: [
                    Positioned.fill(child: WebViewWidget(controller: controller)),
                    if (_loading) const _EmbedLoading(),
                  ],
                ),
        ),
        // TARTALÉK: ha a videó beágyazása tiltott, a felhasználó ne akadjon el.
        if (isYouTube)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _openExternal(widget.embed.url),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const AppText('Megnyitás a YouTube-on'),
              ),
            ),
          ),
      ],
    );
  }
}

class _EmbedLoading extends StatelessWidget {
  const _EmbedLoading();

  @override
  Widget build(BuildContext context) {
    return const Positioned.fill(
      child: ColoredBox(
        color: Color(0xFF111111),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _YouTubeLinkCard extends StatelessWidget {
  final PostEmbed embed;

  const _YouTubeLinkCard({required this.embed});

  @override
  Widget build(BuildContext context) {
    final source = Uri.tryParse(embed.url);
    final videoId = source == null
        ? null
        : source.host.contains('youtu.be')
        ? (source.pathSegments.isEmpty ? null : source.pathSegments.first)
        : source.queryParameters['v'] ??
              _after(source.pathSegments, 'shorts') ??
              _after(source.pathSegments, 'embed') ??
              _after(source.pathSegments, 'live');

    return InkWell(
      onTap: () => _openExternal(embed.url),
      child: Container(
        height: 210,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFF202020),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (videoId != null)
              CachedNetworkImage(
                imageUrl: 'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => const SizedBox.shrink(),
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                ),
              ),
            ),
            const Center(
              child: CircleAvatar(
                radius: 31,
                backgroundColor: Colors.red,
                child: Icon(Icons.play_arrow, color: Colors.white, size: 42),
              ),
            ),
            const Positioned(
              left: 16,
              right: 16,
              bottom: 12,
              child: AppText(
                'Videó megnyitása a YouTube-on',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExternalLink extends StatelessWidget {
  final PostEmbed embed;
  const _ExternalLink({required this.embed});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: ListTile(
        leading: const Icon(Icons.open_in_new, color: Colors.redAccent),
        title: Text(trArgs(context, '{label} megnyitása', {'label': _label(embed.type)})),
        onTap: () async {
          await _openExternal(embed.url);
        },
      ),
    );
  }
}

Future<void> _openExternal(String url) async {
  final uri = Uri.tryParse(_normalizeEmbedUrl(url));
  if (uri != null && isSafeInAppUri(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

Uri? _embedUri(PostEmbed embed) {
  final source = Uri.tryParse(_normalizeEmbedUrl(embed.url));
  if (source == null || !isSafeInAppUri(source)) return null;
  switch (embed.type) {
    case 'youtube':
      final id = source.host.contains('youtu.be')
          ? (source.pathSegments.isEmpty ? null : source.pathSegments.first)
          : source.queryParameters['v'] ??
                _after(source.pathSegments, 'shorts') ??
                _after(source.pathSegments, 'embed') ??
                _after(source.pathSegments, 'live');
      return id == null ? null : Uri.https('www.youtube.com', '/embed/$id');
    case 'spotify':
      return Uri.https(
        'open.spotify.com',
        '/embed/${source.pathSegments.where((part) => part.isNotEmpty).join('/')}',
      );
    case 'soundcloud':
      return Uri.https('w.soundcloud.com', '/player/', {
        'url': embed.url,
        'color': '#ff5500',
        'auto_play': 'false',
        'hide_related': 'true',
        'show_comments': 'false',
        'show_user': 'true',
        'show_reposts': 'false',
        'visual': 'false',
      });
    case 'instagram':
      final path = source.path.endsWith('/') ? source.path : '${source.path}/';
      return Uri.https('www.instagram.com', '${path}embed/captioned/');
    case 'tiktok':
      final id = _after(source.pathSegments, 'video');
      return id == null ? null : Uri.https('www.tiktok.com', '/player/v1/$id');
    default:
      return null;
  }
}

String _normalizeEmbedUrl(String raw) {
  final value = raw.trim();
  if (!value.startsWith('instagram://')) return value;
  final uri = Uri.tryParse(value);
  final shortcode = uri?.queryParameters['shortcode'];
  return shortcode == null || shortcode.isEmpty
      ? 'https://www.instagram.com/'
      : 'https://www.instagram.com/p/$shortcode/';
}

String? _after(List<String> parts, String marker) {
  final index = parts.indexOf(marker);
  return index >= 0 && index + 1 < parts.length ? parts[index + 1] : null;
}

double _height(String type) => switch (type) {
  'youtube' => 220,
  'spotify' => 176,
  'soundcloud' => 166,
  'instagram' => 600,
  'tiktok' => 640,
  _ => 90,
};

String _label(String type) => switch (type) {
  'youtube' => 'YouTube',
  'spotify' => AppStrings.tr('Spotify'),
  'soundcloud' => 'SoundCloud',
  'instagram' => AppStrings.tr('Instagram'),
  'tiktok' => 'TikTok',
  _ => AppStrings.tr('Beágyazott tartalom'),
};
