import 'package:flutter/material.dart';

import '../core/navigation/in_app_browser.dart';
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
        onTap: () =>
            openInAppBrowser(context, uri.toString(), title: shortcode.label),
      ),
    );
  }
}
