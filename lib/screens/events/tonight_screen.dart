import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/tr.dart';
import '../../core/navigation/in_app_browser.dart';
import '../../models/event.dart';
import '../../providers/events_provider.dart';
import '../../services/tonight_plan.dart';
import '../../widgets/app_text.dart';
import '../../widgets/home_action_card.dart';
import 'event_detail_screen.dart';

/// „Hol van buli ma este?" — a mai bulik (bármely szervezőtől) egy listában,
/// soronként térkép-linkkel (Google Maps az app böngészőjében).
class TonightScreen extends ConsumerWidget {
  const TonightScreen({super.key, this.now});

  /// Csak a tesztnek: a „mostani" idő.
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(eventsProvider);
    return Scaffold(
      appBar: AppBar(title: const AppText('Hol van buli ma este?')),
      body: events.when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(tr(context, 'Az események most nem tölthetők be.')),
          ),
        ),
        data: (all) {
          final today = todaysEvents(all, now ?? DateTime.now());
          if (today.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(tr(context, 'Ma estére nincs bejegyzett buli.')),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: today.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _TonightRow(event: today[i]),
          );
        },
      ),
    );
  }
}

class _TonightRow extends StatelessWidget {
  const _TonightRow({required this.event});

  final HuhsEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => EventDetailScreen(event: event),
                ),
              ),
              child: Text(
                event.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              [
                if (event.startTime.isNotEmpty) event.startTime,
                if (event.venueLine.isNotEmpty) event.venueLine,
              ].join(' · '),
              style: theme.textTheme.bodySmall,
            ),
            if (event.hasGoogleMaps) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => openInAppBrowser(context, event.googleMapsUrl),
                  icon: const Icon(Icons.map_outlined),
                  label: const AppText('Térkép'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A Kezdőlapon: a „Hol van buli ma este?" sor — csak akkor látszik, ha ma van
/// legalább egy buli.
class TonightEntry extends ConsumerWidget {
  const TonightEntry({super.key, this.now});

  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(eventsProvider).valueOrNull;
    if (events == null) return const SizedBox.shrink();
    final count = todaysEvents(events, now ?? DateTime.now()).length;
    if (count == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: HomeActionCard(
        key: const Key('tonight-entry'),
        eyebrow: 'MA ESTE',
        label: trArgs(context, 'Hol van buli ma este? ({n})', {'n': '$count'}),
        icon: Icons.map_outlined,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => TonightScreen(now: now)),
        ),
      ),
    );
  }
}
