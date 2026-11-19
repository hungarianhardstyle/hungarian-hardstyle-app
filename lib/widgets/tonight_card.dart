import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/i18n/tr.dart';
import '../core/navigation/in_app_browser.dart';
import '../models/event.dart';
import '../providers/community_provider.dart';
import '../providers/events_provider.dart';
import '../screens/events/checkin_scanner_screen.dart';
import '../screens/events/event_detail_screen.dart';
import '../services/tonight_plan.dart';
import 'app_text.dart';
import 'timetable_rows.dart';

/// A Kezdőlap tetején megjelenő **„Ma este"** kártya: a buli napján (és amíg a
/// buli tart) időbeosztás, térkép, jegy és a QR-becsekkolás. Egyébként **nem
/// foglal helyet**.
class TonightCard extends ConsumerWidget {
  const TonightCard({super.key, this.now});

  /// Csak a tesztnek: a „mostani" idő.
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(eventsProvider).valueOrNull;
    if (events == null) return const SizedBox.shrink();
    final clock = now ?? DateTime.now();
    final event = tonightEvent(events, clock);
    if (event == null) return const SizedBox.shrink();
    return _TonightBody(event: event, now: clock);
  }
}

class _TonightBody extends ConsumerWidget {
  const _TonightBody({required this.event, required this.now});

  final HuhsEvent event;
  final DateTime now;

  Future<void> _scan(BuildContext context, WidgetRef ref) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(context, 'A becsekkoláshoz be kell jelentkezned.'),
          ),
        ),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const CheckinScannerScreen()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final window = checkinWindowFor(event, now);
    final start = eventStartAt(event);
    final live = start != null && !now.isBefore(start);
    final timetable = event.timetable.take(8).toList();
    final primary = theme.colorScheme.primary;

    return Padding(
      key: const Key('tonight-card'),
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: primary, width: 4)),
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.nightlife, size: 18, color: primary),
                  const SizedBox(width: 8),
                  AppText(
                    live ? 'MOST ZAJLIK' : 'MA ESTE',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
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
              if (timetable.isNotEmpty) ...[
                const SizedBox(height: 10),
                TimetableRows(event: event, entries: timetable),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (event.hasGoogleMaps)
                    OutlinedButton.icon(
                      key: const Key('tonight-map'),
                      onPressed: () =>
                          openInAppBrowser(context, event.googleMapsUrl),
                      icon: const Icon(Icons.map_outlined),
                      label: const AppText('Térkép'),
                    ),
                  if (event.hasTicket)
                    OutlinedButton.icon(
                      key: const Key('tonight-ticket'),
                      onPressed: () =>
                          openInAppBrowser(context, event.ticketUrl),
                      icon: const Icon(Icons.confirmation_number_outlined),
                      label: const AppText('Jegy'),
                    ),
                  if (window == CheckinWindow.open)
                    FilledButton.icon(
                      key: const Key('tonight-checkin'),
                      onPressed: () => _scan(context, ref),
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const AppText('Becsekkolás'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
