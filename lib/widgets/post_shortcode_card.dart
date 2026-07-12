import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../models/post.dart';

class PostShortcodeCard extends StatelessWidget {
  final PostShortcode shortcode;
  final String postUrl;

  const PostShortcodeCard({
    super.key,
    required this.shortcode,
    required this.postUrl,
  });

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(postUrl);
    if (uri == null || !uri.isAbsolute) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      color: const Color(0xFF181818),
      child: ListTile(
        leading: const Icon(Icons.widgets_outlined, color: Colors.redAccent),
        title: Text(shortcode.label),
        subtitle: const Text('Megnyitás az alkalmazásban'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                _ShortcodeWebViewScreen(title: shortcode.label, uri: uri),
          ),
        ),
      ),
    );
  }
}

class _ShortcodeWebViewScreen extends StatefulWidget {
  final String title;
  final Uri uri;

  const _ShortcodeWebViewScreen({required this.title, required this.uri});

  @override
  State<_ShortcodeWebViewScreen> createState() =>
      _ShortcodeWebViewScreenState();
}

class _ShortcodeWebViewScreenState extends State<_ShortcodeWebViewScreen> {
  late final WebViewController _controller;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
        ),
      )
      ..loadRequest(widget.uri);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Stack(
        children: [
          Positioned.fill(child: WebViewWidget(controller: _controller)),
          if (_loading)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0xFF080808),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}
