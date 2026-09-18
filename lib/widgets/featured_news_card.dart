import 'package:flutter/material.dart';

import '../core/content/date_formatters.dart';
import '../models/post.dart';
import '../screens/news/news_detail_screen.dart';
import '../services/wordpress_service.dart';
import 'detail_prefetch.dart';
import 'news_reaction_button.dart';
import 'resized_network_image.dart';

class FeaturedNewsCard extends StatelessWidget {
  final Post post;

  const FeaturedNewsCard({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    return DetailPrefetch(
      onPrefetch: () => WordpressService().getPost(post.id),
      child: _buildCard(context),
    );
  }

  Widget _buildCard(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final imageCacheWidth =
        (MediaQuery.sizeOf(context).width *
                MediaQuery.devicePixelRatioOf(context) *
                0.42)
            .round()
            .clamp(360, 1600);

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => NewsDetailScreen(post: post)),
        );
      },
      child: Container(
        height: double.infinity,
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colors.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 5,
              child: Hero(
                tag: "post_${post.id}",
                child: post.imageUrl.isNotEmpty
                    ? ResizedNetworkImage(
                        url: post.imageUrl,
                        physicalWidth: imageCacheWidth,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        color: colors.surfaceContainerHighest,
                        child: const Icon(
                          Icons.article,
                          color: Colors.white54,
                          size: 60,
                        ),
                      ),
              ),
            ),
            Expanded(
              flex: 7,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 18, 14, 14),
                decoration: BoxDecoration(
                  color: colors.surfaceContainer,
                  border: Border(
                    left: BorderSide(color: colors.primary, width: 3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primaryContainer,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        post.isSticky ? 'KIEMELT HÍR' : 'FRISS HÍR',
                        style: TextStyle(
                          color: colors.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      post.title,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w800,
                        height: 1.05,
                        shadows: const [
                          Shadow(
                            color: Colors.black54,
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                    if (post.articleCategories.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        post.articleCategories.join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 11,
                          letterSpacing: .3,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            formatHungarianDate(post.date),
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        NewsReactionButton(postId: post.id),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: colors.primary,
                          size: 20,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
