import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/content/date_formatters.dart';
import '../models/post.dart';
import '../screens/news/news_detail_screen.dart';
import 'news_reaction_button.dart';

class NewsCard extends StatelessWidget {
  final Post post;
  final bool compact;

  const NewsCard({super.key, required this.post, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: const Color(0xFF171717),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF5A2424)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF03A37).withValues(alpha: .12),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
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
                        top: Radius.circular(12),
                      ),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: post.imageUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: post.imageUrl,
                                fit: BoxFit.cover,
                                memCacheWidth: 800,
                                maxWidthDiskCache: 800,
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
                          style: const TextStyle(
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
                            style: const TextStyle(
                              color: Colors.redAccent,
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
                            const Icon(
                              Icons.calendar_today,
                              size: 16,
                              color: Colors.redAccent,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              formatHungarianDate(post.date),
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            NewsReactionButton(postId: post.id),
                            const Spacer(),
                            const Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: Colors.redAccent,
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
                ? CachedNetworkImage(
                    imageUrl: post.imageUrl,
                    fit: BoxFit.cover,
                    memCacheWidth: 480,
                    maxWidthDiskCache: 480,
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
                  style: const TextStyle(
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
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 12,
                    ),
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
