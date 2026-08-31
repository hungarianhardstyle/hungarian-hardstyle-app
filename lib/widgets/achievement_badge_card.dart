import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/achievement.dart';

class AchievementBadgeCard extends StatelessWidget {
  final AchievementSummary achievement;

  const AchievementBadgeCard({super.key, required this.achievement});

  @override
  Widget build(BuildContext context) {
    final image = achievement.badgeImageUrl;
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: SizedBox.square(
          dimension: 72,
          child: ClipOval(
            child: image.isEmpty
                ? const ColoredBox(
                    color: Color(0xFFE53935),
                    child: Icon(
                      Icons.workspace_premium_outlined,
                      color: Colors.white,
                    ),
                  )
                : CachedNetworkImage(
                    imageUrl: image,
                    fit: BoxFit.cover,
                    memCacheWidth: 192,
                    maxWidthDiskCache: 192,
                    placeholder: (context, url) => const ColoredBox(
                      color: Color(0xFFE53935),
                      child: Center(
                        child: SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => const ColoredBox(
                      color: Color(0xFFE53935),
                      child: Icon(
                        Icons.workspace_premium_outlined,
                        color: Colors.white,
                      ),
                    ),
                  ),
          ),
        ),
        title: Text(achievement.badgeName),
        subtitle: Text(
          '${achievement.points} pont • ${achievement.badgeDescription}',
        ),
      ),
    );
  }
}
