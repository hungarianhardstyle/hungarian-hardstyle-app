import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/community_provider.dart';
import '../screens/more/checkin_badges_screen.dart';
import '../services/checkin_badges_service.dart';
import 'app_text.dart';

/// A saját „Ott voltam” jelvények (a profilszerver adja; mindig friss).
final checkinBadgesProvider = FutureProvider.autoDispose<CheckinBadgesResult>((
  ref,
) async {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return CheckinBadgesResult.empty;
  return const CheckinBadgesService().fetch();
});

/// Az „Ott voltam” jelvények a **saját** profilon: a kiemelt (vagy a legutóbbi)
/// három, és az „Összes jelvény” oldal. Üresen nem foglal helyet.
class CheckinBadgesSection extends ConsumerWidget {
  const CheckinBadgesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result =
        ref.watch(checkinBadgesProvider).valueOrNull ??
        CheckinBadgesResult.empty;
    return CheckinBadgesStrip(
      result: result,
      onOpen: () async {
        await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (_) => const CheckinBadgesScreen()),
        );
        ref.invalidate(checkinBadgesProvider);
      },
    );
  }
}

/// Más felhasználó nyilvános profilján: a tulajdonos által kiemelt jelvények, és a
/// teljes lista (amit a tulajdonos megenged). Üresen nem foglal helyet.
class PublicCheckinBadges extends StatefulWidget {
  const PublicCheckinBadges({
    super.key,
    required this.userId,
    required this.userName,
  });

  final String userId;
  final String userName;

  @override
  State<PublicCheckinBadges> createState() => _PublicCheckinBadgesState();
}

class _PublicCheckinBadgesState extends State<PublicCheckinBadges> {
  late final Future<CheckinBadgesResult> _future = const CheckinBadgesService()
      .fetch(userId: widget.userId)
      .catchError((_) => CheckinBadgesResult.empty);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CheckinBadgesResult>(
      future: _future,
      builder: (context, snapshot) {
        final result = snapshot.data;
        if (result == null) return const SizedBox.shrink();
        return CheckinBadgesStrip(
          result: result,
          onOpen: () => Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => CheckinBadgesScreen(
                userId: widget.userId,
                userName: widget.userName,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A jelvény-sáv: legfeljebb három kiemelt jelvény és az „Összes jelvény” gomb.
class CheckinBadgesStrip extends StatelessWidget {
  const CheckinBadgesStrip({
    super.key,
    required this.result,
    required this.onOpen,
  });

  final CheckinBadgesResult result;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    if (result.badges.isEmpty) return const SizedBox.shrink();
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
        if (result.shown.isNotEmpty)
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final badge in result.shown)
                InkWell(
                  onTap: onOpen,
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 96,
                    child: Column(
                      children: [
                        if (badge.badgeUrl.isNotEmpty)
                          Image.network(
                            badge.badgeUrl,
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
                          badge.label,
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        TextButton.icon(
          onPressed: onOpen,
          icon: const Icon(Icons.workspace_premium_outlined),
          label: const AppText('Összes jelvény'),
        ),
      ],
    );
  }
}
