import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../core/i18n/tr.dart';
import '../core/navigation/in_app_browser.dart';
import '../models/event.dart';
import '../providers/community_provider.dart';
import '../providers/events_provider.dart';
import '../screens/events/checkin_scanner_screen.dart';
import '../screens/events/event_detail_screen.dart';
import '../services/event_checkin_service.dart';
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

String _hhmm(DateTime? time) => time == null
    ? ''
    : '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

class _TonightBody extends ConsumerWidget {
  const _TonightBody({required this.event, required this.now});

  final HuhsEvent event;
  final DateTime now;

  Future<void> _scan(BuildContext context, WidgetRef ref) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr(context, 'A becsekkoláshoz be kell jelentkezned.')),
        ),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const CheckinScannerScreen()),
    );
  }

  /// Helyalapú becsekkolás ("Itt vagyok a helyszínen"): egyszeri pozíció, amit a
  /// szerver csak ellenőriz (nem tárolja). A QR mellett, nem helyette.
  Future<void> _gpsCheckin(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context, rootNavigator: true);
    void say(String message) =>
        messenger.showSnackBar(SnackBar(content: Text(tr(context, message))));
    if (ref.read(currentUidProvider) == null) {
      say('A becsekkoláshoz be kell jelentkezned.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const AppText('Helyalapú becsekkolás'),
        content: const AppText(
          'A telefonod pozícióját egyszer lekérjük, és a szerver csak azt ellenőrzi, '
          'hogy a buli helyszínén vagy-e. A pozíciót nem tároljuk.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const AppText('Mégse'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const AppText('Folytatom'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      say(
        'A helyalapú becsekkoláshoz helyengedély kell. Olvasd be a QR-kódot, '
        'vagy engedélyezd a helyet a telefon beállításaiban.',
      );
      return;
    }
    if (!await Geolocator.isLocationServiceEnabled()) {
      say('Kapcsold be a helymeghatározást a telefonon.');
      return;
    }
    if (!context.mounted) return;

    // Várakozás-jelző a pozíció lekérése és a szerver ellenőrzése alatt.
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      ),
    );
    EventCheckinResult? result;
    String? error;
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      result = await EventCheckinService().checkInWithLocation(
        eventId: event.id,
        lat: position.latitude,
        lng: position.longitude,
        accuracy: position.accuracy,
      );
    } on EventCheckinException catch (e) {
      error = e.message;
    } on TimeoutException {
      error = 'Nem sikerült időben meghatározni a pozíciót. Menj kijjebb, vagy olvasd be a QR-kódot.';
    } catch (_) {
      error = 'A helyalapú becsekkolás most nem sikerült, próbáld újra.';
    }
    navigator.pop(); // a várakozás-jelző
    if (!context.mounted) return;
    if (result == null) {
      say(error ?? 'A becsekkolás most nem sikerült, próbáld újra.');
      return;
    }
    final done = result;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: AppText(
          done.alreadyCheckedIn
              ? 'Erre a bulira már becsekkoltál.'
              : 'Becsekkoltál!',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (done.badgeUrl.isNotEmpty)
              Image.network(
                done.badgeUrl,
                width: 120,
                height: 120,
                errorBuilder: (_, _, _) => const Icon(Icons.verified, size: 80),
              ),
            const SizedBox(height: 8),
            Text(done.badgeName, textAlign: TextAlign.center),
            if (done.points > 0)
              Text(
                trArgs(context, '+{n} pont jár a becsekkolásért.', {
                  'n': '${done.points}',
                }),
                textAlign: TextAlign.center,
              ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const AppText('Kész'),
          ),
        ],
      ),
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
              if (event.flyerUrl.isNotEmpty) ...[
                InkWell(
                  key: const Key('tonight-flyer'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => EventDetailScreen(event: event),
                    ),
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 260),
                    child: CachedNetworkImage(
                      imageUrl: event.flyerUrl,
                      width: double.infinity,
                      fit: BoxFit.contain,
                      errorWidget: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
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
                          openSocialLink(context, event.googleMapsUrl),
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
                  // Nyitás előtt is látszik (letiltva), hogy tudd, mikortól lehet becsekkolni.
                  if (window == CheckinWindow.notYet)
                    OutlinedButton.icon(
                      key: const Key('tonight-checkin-soon'),
                      onPressed: null,
                      icon: const Icon(Icons.qr_code_scanner),
                      label: Text(
                        trArgs(context, 'Becsekkolás {time}-tól', {
                          'time': _hhmm(checkinOpensAtFor(event)),
                        }),
                      ),
                    ),
                  if (window == CheckinWindow.open && event.checkinGps)
                    OutlinedButton.icon(
                      key: const Key('tonight-checkin-gps'),
                      onPressed: () => _gpsCheckin(context, ref),
                      icon: const Icon(Icons.my_location),
                      label: const AppText('Itt vagyok a helyszínen'),
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
