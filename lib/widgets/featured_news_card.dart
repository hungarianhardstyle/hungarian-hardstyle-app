import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/content/date_formatters.dart';
import '../models/post.dart';
import '../providers/favorites_provider.dart';
import '../screens/news/news_detail_screen.dart';
import 'favorite_button.dart';

class FeaturedNewsCard extends StatelessWidget {
  final Post post;

  const FeaturedNewsCard({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => NewsDetailScreen(post: post)),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF171717),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .35),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Hero(
              tag: "post_${post.id}",
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: post.imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: post.imageUrl,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        color: Colors.grey.shade900,
                        child: const Icon(
                          Icons.article,
                          color: Colors.white54,
                          size: 70,
                        ),
                      ),
              ),
            ),

            // Gradient
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: .35),
                      Colors.black.withValues(alpha: .95),
                    ],
                  ),
                ),
              ),
            ),

            // Badge
            Positioned(
              left: 16,
              top: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.local_fire_department,
                      color: Colors.white,
                      size: 15,
                    ),
                    SizedBox(width: 5),
                    Text(
                      "KIEMELT HÍR",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        letterSpacing: .5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Positioned(
              left: 20,
              right: 20,
              bottom: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      height: 1.25,
                    ),
                  ),

                  const SizedBox(height: 14),

                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_rounded,
                        size: 15,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        formatHungarianDate(post.date),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      FavoriteButton(
                        kind: FavoriteKind.news,
                        id: post.id,
                        title: post.title,
                      ),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 22,
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
