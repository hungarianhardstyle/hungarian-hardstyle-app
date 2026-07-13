import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

Future<void> openInAppBrowser(
  BuildContext context,
  String url, {
  String? title,
}) async {
  final normalizedUrl = url
      .replaceAll('&amp;', '&')
      .replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '')
      .trim();
  final uri = Uri.tryParse(normalizedUrl);
  if (uri == null || uri.scheme.isEmpty) {
    _showOpenError(context);
    return;
  }

  if (uri.scheme != 'http' && uri.scheme != 'https') {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) _showOpenError(context);
    return;
  }

  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          InAppBrowserScreen(initialUri: uri, title: title ?? uri.host),
    ),
  );
}

/// Opens a social URL in its installed native app first, then falls back to
/// the shared in-app browser when no native handler is available.
Future<void> openSocialLink(
  BuildContext context,
  String url, {
  String? title,
}) async {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || uri.scheme.isEmpty) {
    _showOpenError(context);
    return;
  }

  try {
    if (await launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication)) {
      return;
    }
  } catch (_) {
    // Fall back to the in-app browser below.
  }

  if (context.mounted) {
    await openInAppBrowser(context, url, title: title);
  }
}

class InAppBrowserScreen extends StatefulWidget {
  final Uri initialUri;
  final String title;

  const InAppBrowserScreen({
    super.key,
    required this.initialUri,
    required this.title,
  });

  @override
  State<InAppBrowserScreen> createState() => _InAppBrowserScreenState();
}

class _InAppBrowserScreenState extends State<InAppBrowserScreen> {
  late final WebViewController _controller;
  var _progress = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (mounted) setState(() => _progress = progress);
          },
          onNavigationRequest: (request) async {
            final uri = Uri.tryParse(request.url);
            if (uri == null || uri.scheme == 'http' || uri.scheme == 'https') {
              return NavigationDecision.navigate;
            }

            await launchUrl(uri, mode: LaunchMode.externalApplication);
            return NavigationDecision.prevent;
          },
        ),
      )
      ..loadRequest(widget.initialUri);
  }

  Future<void> _handleSystemBack() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
    } else if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleSystemBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title, overflow: TextOverflow.ellipsis),
          actions: [
            IconButton(
              tooltip: 'Megnyitás külső böngészőben',
              onPressed: () async {
                final url = await _controller.currentUrl();
                final uri = Uri.tryParse(url ?? '');
                if (uri != null) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(Icons.open_in_browser),
            ),
          ],
          bottom: _progress < 100
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(3),
                  child: LinearProgressIndicator(value: _progress / 100),
                )
              : null,
        ),
        body: WebViewWidget(controller: _controller),
        bottomNavigationBar: SafeArea(
          top: false,
          child: SizedBox(
            height: 52,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  tooltip: 'Vissza',
                  onPressed: () async {
                    if (await _controller.canGoBack()) {
                      await _controller.goBack();
                    }
                  },
                  icon: const Icon(Icons.arrow_back),
                ),
                IconButton(
                  tooltip: 'Előre',
                  onPressed: () async {
                    if (await _controller.canGoForward()) {
                      await _controller.goForward();
                    }
                  },
                  icon: const Icon(Icons.arrow_forward),
                ),
                IconButton(
                  tooltip: 'Újratöltés',
                  onPressed: _controller.reload,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void _showOpenError(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Nem sikerült megnyitni a linket.')),
  );
}
