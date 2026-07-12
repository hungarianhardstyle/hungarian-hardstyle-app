import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../models/post.dart';

class PostEmbedCard extends StatefulWidget {
  final PostEmbed embed;
  const PostEmbedCard({super.key, required this.embed});

  @override
  State<PostEmbedCard> createState() => _PostEmbedCardState();
}

class _PostEmbedCardState extends State<PostEmbedCard> {
  WebViewController? _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.embed.type == 'youtube') return;

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
    if (widget.embed.type == 'youtube') {
      return _YouTubeLinkCard(embed: widget.embed);
    }

    final controller = _controller;
    if (controller == null) return _ExternalLink(embed: widget.embed);

    return Container(
      height: _height(widget.embed.type),
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: WebViewWidget(controller: controller)),
          if (_loading)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0xFF111111),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
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
              _after(source.pathSegments, 'embed');

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
              child: Text(
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
        title: Text('${_label(embed.type)} megnyitása'),
        onTap: () async {
          await _openExternal(embed.url);
        },
      ),
    );
  }
}

Future<void> _openExternal(String url) async {
  final uri = Uri.tryParse(url);
  if (uri != null) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

Uri? _embedUri(PostEmbed embed) {
  final source = Uri.tryParse(embed.url);
  if (source == null || !source.isAbsolute) return null;
  switch (embed.type) {
    case 'youtube':
      final id = source.host.contains('youtu.be')
          ? (source.pathSegments.isEmpty ? null : source.pathSegments.first)
          : source.queryParameters['v'] ??
                _after(source.pathSegments, 'shorts') ??
                _after(source.pathSegments, 'embed');
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
  'spotify' => 'Spotify',
  'soundcloud' => 'SoundCloud',
  'instagram' => 'Instagram',
  'tiktok' => 'TikTok',
  _ => 'Beágyazott tartalom',
};
