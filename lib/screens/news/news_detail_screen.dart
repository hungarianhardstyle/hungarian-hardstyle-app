import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:intl/intl.dart';

import '../../core/content/html_linkifier.dart';
import '../../core/navigation/in_app_browser.dart';
import '../../models/post.dart';
import '../../services/wordpress_service.dart';
import '../../widgets/post_embed_card.dart';
import '../../widgets/post_shortcode_card.dart';
import '../gallery/gallery_screen.dart';

class NewsDetailScreen extends StatelessWidget {
  final Post post;

  const NewsDetailScreen({super.key, required this.post});

  String _formatDate(String date) {
    try {
      final parsed = DateTime.parse(date);

      return DateFormat('yyyy. MMMM d.', 'hu_HU').format(parsed);
    } catch (_) {
      return date;
    }
  }

  Future<void> _openLink(
    BuildContext context,
    String? url,
    Map<String, String>? attributes,
  ) async {
    final isPostLink = attributes?['data-type'] == 'post' ||
        attributes?['type'] == 'post';
    final postId = int.tryParse(
      attributes?['data-id'] ?? attributes?['id'] ?? '',
    );

    if (isPostLink && postId != null && postId > 0) {
      try {
        final relatedPost = await WordpressService().getPost(postId);
        if (!context.mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => NewsDetailScreen(post: relatedPost),
          ),
        );
        return;
      } catch (_) {
        // Fall back to the in-app browser when the related post is unavailable.
      }
    }

    if (context.mounted) {
      await openInAppBrowser(context, url ?? '');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          post.title.trim().isEmpty ? 'Hír' : post.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewPaddingOf(context).bottom + 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (post.imageUrl.isNotEmpty)
              Hero(
                tag: "post_${post.id}",
                child: CachedNetworkImage(
                  imageUrl: post.imageUrl,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.title,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    _formatDate(post.date),
                    style: TextStyle(color: Colors.grey.shade400),
                  ),
                ],
              ),
            ),

            Html(
              data: linkifyPlainUrls(post.contentForDisplay),
              onLinkTap: (url, attributes, element) => _openLink(
                context,
                resolveHtmlLinkTarget(
                  callbackUrl: url,
                  attributes: attributes,
                  visibleText: element?.text,
                ),
                attributes,
              ),
              style: {
                "body": Style(
                  margin: Margins.zero,
                  padding: HtmlPaddings.all(20),
                  fontSize: FontSize(18),
                  lineHeight: const LineHeight(1.7),
                  color: Colors.white,
                ),
                "img": Style(margin: Margins.symmetric(vertical: 16)),
                "p": Style(margin: Margins.only(bottom: 18)),
                "h1": Style(
                  fontSize: FontSize(30),
                  fontWeight: FontWeight.bold,
                ),
                "h2": Style(
                  fontSize: FontSize(26),
                  fontWeight: FontWeight.bold,
                ),
                "h3": Style(
                  fontSize: FontSize(22),
                  fontWeight: FontWeight.bold,
                ),
                "a": Style(
                  color: Colors.redAccent,
                  textDecoration: TextDecoration.none,
                ),
              },
            ),

            if (post.embeds.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Text(
                  'Média',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
              ...post.embeds.map((embed) => PostEmbedCard(embed: embed)),
            ],

            if (post.shortcodes.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Text(
                  'Interaktív tartalom',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
              ...post.shortcodes.map(
                (shortcode) =>
                    PostShortcodeCard(
                      shortcode: shortcode,
                      postUrl: post.link,
                      relatedPosts: post.relatedPosts,
                    ),
              ),
            ],

            if (post.galleryImages.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 10, 20, 10),
                child: Text(
                  "Galéria",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),

              SizedBox(
                height: 130,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: post.galleryImages.length,
                  itemBuilder: (context, index) {
                    final image = post.galleryImages[index];

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => GalleryScreen(
                              images: post.galleryImages,
                              initialIndex: index,
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Hero(
                          tag: "gallery_${image.id}",
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(
                              imageUrl: image.url,
                              width: 180,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 30),
            ],
          ],
        ),
      ),
    );
  }
}
