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
          final uri = Uri.tryParse(embed.url);
          if (uri != null) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
      ),
    );
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
  'instagram' => 600,
  'tiktok' => 640,
  _ => 90,
};

String _label(String type) => switch (type) {
  'youtube' => 'YouTube',
  'spotify' => 'Spotify',
  'instagram' => 'Instagram',
  'tiktok' => 'TikTok',
  _ => 'Beágyazott tartalom',
};
