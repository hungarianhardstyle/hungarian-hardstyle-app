import 'package:flutter/material.dart';

import '../models/achievement.dart';
import 'resized_network_image.dart';

class AchievementBadgeCard extends StatelessWidget {
  final AchievementSummary achievement;

  const AchievementBadgeCard({super.key, required this.achievement});

  @override
  Widget build(BuildContext context) {
    final image = achievement.badgeImageUrl;
    final imageCacheWidth = (72 * MediaQuery.devicePixelRatioOf(context))
        .round()
        .clamp(144, 288);
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
                : ResizedNetworkImage(
                    // Ask for the badge at its painted size: the artwork stays
                    // crisp because the request always covers the physical
                    // pixels of this 72 px circle.
                    url: image,
                    physicalWidth: imageCacheWidth,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const ColoredBox(
                      color: Color(0xFFE53935),
                      child: Center(
                        child: SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) {
                      return const ColoredBox(
                        color: Color(0xFFE53935),
                        child: Icon(
                          Icons.workspace_premium_outlined,
                          color: Colors.white,
                        ),
                      );
                    },
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
