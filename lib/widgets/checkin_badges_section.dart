import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/community_provider.dart';
import '../services/twitch_chat.dart' show huHsFirestore;
import 'app_text.dart';

/// Az „Ott voltam" jelvények a **saját** profilon: minden QR-rel becsekkolt
/// buliból egy. Üresen nem foglal helyet. A Firestore-szabály csak a saját
/// rekordokat engedi olvasni.
final checkinBadgesProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
      final uid = ref.watch(currentUidProvider);
      if (uid == null) return Stream.value(const []);
      return huHsFirestore()
          .collection('event_checkins')
          .where('uid', isEqualTo: uid)
          .snapshots()
          .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
    });

class CheckinBadgesSection extends ConsumerWidget {
  const CheckinBadgesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badges = ref.watch(checkinBadgesProvider).valueOrNull ?? const [];
    if (badges.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const AppText(
          'Ott voltam',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final badge in badges)
              SizedBox(
                width: 96,
                child: Column(
                  children: [
                    if ((badge['badgeUrl'] ?? '').toString().isNotEmpty)
                      Image.network(
                        badge['badgeUrl'].toString(),
                        width: 64,
                        height: 64,
                        errorBuilder: (_, _, _) => Icon(
                          Icons.verified,
                          size: 56,
                          color: theme.colorScheme.primary,
                        ),
                      )
                    else
                      Icon(
                        Icons.verified,
                        size: 56,
                        color: theme.colorScheme.primary,
                      ),
                    const SizedBox(height: 4),
                    Text(
                      (badge['badgeName'] ?? '').toString(),
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}
