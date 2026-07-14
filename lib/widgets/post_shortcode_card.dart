import 'package:flutter/material.dart';

import '../core/navigation/in_app_browser.dart';
import '../models/post.dart';
import '../screens/news/news_detail_screen.dart';

class PostShortcodeCard extends StatelessWidget {
  final PostShortcode shortcode;
  final String postUrl;
  final List<Post> relatedPosts;

  const PostShortcodeCard({
    super.key,
    required this.shortcode,
    required this.postUrl,
    this.relatedPosts = const [],
  });

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(postUrl);
    if (uri == null || !uri.isAbsolute) return const SizedBox.shrink();

    final related = shortcode.name.toLowerCase() == 'irp'
        ? relatedPosts
        : const <Post>[];

    return Card(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      color: const Color(0xFF181818),
      child: ListTile(
        leading: const Icon(Icons.widgets_outlined, color: Colors.redAccent),
        title: Text(shortcode.label),
        subtitle: Text(
          related.isEmpty
              ? 'Megnyitás az alkalmazásban'
              : '${related.length} kapcsolódó cikk',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
            if (related.isNotEmpty) {
            if (related.length == 1) {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => NewsDetailScreen(post: related.first),
                ),
              );
            } else {
              await showModalBottomSheet<void>(
                context: context,
                builder: (sheetContext) => SafeArea(
                  child: ListView(
                    shrinkWrap: true,
                    children: related
                        .map(
                          (post) => ListTile(
                            leading: const Icon(Icons.article_outlined),
                            title: Text(post.title),
                            onTap: () {
                              Navigator.pop(sheetContext);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => NewsDetailScreen(post: post),
                                ),
                              );
                            },
                          ),
                        )
                        .toList(),
                  ),
                ),
              );
            }
            return;
          }
          await openInAppBrowser(context, uri.toString(), title: shortcode.label);
        },
      ),
    );
  }
}
