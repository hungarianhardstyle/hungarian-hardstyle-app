import 'package:flutter/material.dart';

import '../core/content/date_formatters.dart';
import '../models/post.dart';
import '../screens/news/news_detail_screen.dart';
import '../services/wordpress_service.dart';
import 'detail_prefetch.dart';
import 'news_reaction_button.dart';
import 'resized_network_image.dart';

class NewsCard extends StatelessWidget {
  final Post post;
  final bool compact;

  const NewsCard({super.key, required this.post, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    // The card lives inside 18 px list padding, so the request has to cover the
    // card's own physical width instead of the whole screen.
    final imageCacheWidth = ((MediaQuery.sizeOf(context).width - 36) * dpr)
        .round()
        .clamp(360, 1600);
    return DetailPrefetch(
      onPrefetch: () => WordpressService().getPost(post.id),
      child: _buildCard(context, colors, imageCacheWidth),
    );
  }

  Widget _buildCard(
    BuildContext context,
    ColorScheme colors,
    int imageCacheWidth,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => NewsDetailScreen(post: post)),
          );
        },
        child: compact
            ? _CompactNewsCardContent(post: post)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Hero(
                    tag: "post_${post.id}",
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(8),
                      ),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: post.imageUrl.isNotEmpty
                            ? ResizedNetworkImage(
                                url: post.imageUrl,
                                physicalWidth: imageCacheWidth,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                color: Colors.grey.shade900,
                                child: const Icon(
                                  Icons.article,
                                  color: Colors.white54,
                                  size: 60,
                                ),
                              ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.onSurface,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            height: 1.25,
                          ),
                        ),
                        if (post.articleCategories.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            post.articleCategories.join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.primary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Text(
                          post.excerpt,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey.shade300,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 16,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              formatHungarianDate(post.date),
                              style: TextStyle(
                                color: colors.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            NewsReactionButton(postId: post.id),
                            const Spacer(),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: colors.primary,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _CompactNewsCardContent extends StatelessWidget {
  final Post post;

  const _CompactNewsCardContent({required this.post});

  @override
  Widget build(BuildContext context) {
    final imageCacheWidth = (240 * MediaQuery.devicePixelRatioOf(context))
        .round()
        .clamp(480, 1200);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 240,
          height: 135,
          child: ClipRRect(
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(12),
            ),
            child: post.imageUrl.isNotEmpty
                ? ResizedNetworkImage(
                    url: post.imageUrl,
                    physicalWidth: imageCacheWidth,
                    fit: BoxFit.cover,
                  )
                : Container(
                    color: Colors.grey.shade900,
                    child: const Icon(Icons.article, color: Colors.white54),
                  ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
                if (post.articleCategories.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    post.articleCategories.join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.redAccent, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  post.excerpt,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade300, height: 1.35),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        formatHungarianDate(post.date),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey.shade400),
                      ),
                    ),
                    NewsReactionButton(postId: post.id),
                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: Colors.redAccent,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A hírkártya **egységes elhelyezése** — ezt használja a „Friss hírek" lista
/// **és** a „Kiemelt hírek" sor is.
///
/// MIÉRT: fekvő (tablet) nézetben a teljes szélességű kártya 16:9-es képe
/// óriásira nő. A „Friss hírek" lista ezt már kezelte (legfeljebb 760 px széles,
/// **sávos** kártya), a „Kiemelt hírek" sor viszont **nem** — ezért nézett ki
/// másképp, és lett „nagyon nagy" (a tulajdonos jelzése: *„tableten a kiemelt
/// hírek a hírek tabon nagyon nagyok, olyannak kéne lennie mint a többi hír
/// kártyának"*). A szabály **egy helyen** van, ezért a kettő nem tud széthúzni.
class AdaptiveNewsCard extends StatelessWidget {
  const AdaptiveNewsCard({super.key, required this.post});

  final Post post;

  /// Fekvő nézetben ekkora a legnagyobb kártyaszélesség: ennél szélesebb
  /// tabletben a teljes szélességű kártya képe már túl nagy lenne.
  static const double maxLandscapeWidth = 760;

  @override
  Widget build(BuildContext context) {
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: landscape ? maxLandscapeWidth : double.infinity,
        ),
        child: NewsCard(post: post, compact: landscape),
      ),
    );
  }
}
