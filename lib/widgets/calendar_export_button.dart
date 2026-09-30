import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/i18n/tr.dart';
import '../models/event.dart';
import '../services/event_calendar.dart';
import '../services/share_links.dart';
import 'app_text.dart';

/// **„Naptárba"** — az esemény beírása a felhasználó naptárába.
///
/// MIÉRT (a tulajdonos választotta a hat irány közül a *„naptár-export"* pontot):
/// aki „Ott leszek"-et nyom, elköteleződik — de a buli estéjére semmi nem
/// emlékezteti. A naptárbejegyzés **visszahozza**: emlékeztet, és a leírásban ott
/// a link is (ezért nem csak a jelenlét jelölése számít, hanem a naptár is).
///
/// KÉT ÚT, egy lapon: **Google Naptár** (azonnal a mentés lap) vagy
/// **`.ics` fájl** (bármelyik naptáralkalmazásba importálható). A döntés a
/// tiszta `event_calendar.dart`-ban van, ez a fájl csak a felület és a
/// rendszerhívások (link megnyitása, megosztás).
class EventCalendarButton extends StatelessWidget {
  const EventCalendarButton({super.key, required this.event});

  final HuhsEvent event;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tr(context, 'Naptárba'),
      icon: const Icon(Icons.calendar_month_outlined),
      onPressed: () => openEventCalendarSheet(context, event),
    );
  }
}

/// A naptárlap megnyitása (a fejléc gombja **és** az „Ott leszek" utáni
/// felugró üzenet akciója is ezt hívja — egy helyen él a viselkedés).
Future<void> openEventCalendarSheet(
  BuildContext context,
  HuhsEvent event,
) async {
  final entry = eventCalendarEntry(event);
  if (entry == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: AppText('Ehhez az eseményhez nincs érvényes dátum.'),
      ),
    );
    return;
  }

  final choice = await showModalBottomSheet<String>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
            child: Text(
              tr(sheetContext, 'Esemény a naptárba'),
              style: Theme.of(
                sheetContext,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: AppText(
              'Válaszd ki, hova kerüljön a bejegyzés — a naptár emlékeztetni fog a bulira.',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.event_available_outlined),
            title: const AppText('Google Naptár'),
            subtitle: const AppText('Azonnal megnyílik a mentés lap'),
            onTap: () => Navigator.pop(sheetContext, 'google'),
          ),
          ListTile(
            leading: const Icon(Icons.file_download_outlined),
            title: const AppText('Naptárfájl (.ics)'),
            subtitle: const AppText('Bármelyik naptáralkalmazásba importálható'),
            onTap: () => Navigator.pop(sheetContext, 'ics'),
          ),
          const SizedBox(height: 10),
        ],
      ),
    ),
  );

  if (!context.mounted) return;
  if (choice == 'google') {
    final opened = await _launchExternal(googleCalendarUrl(entry));
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AppText('Nem sikerult megnyitni a linket.')),
      );
    }
    return;
  }
  if (choice == 'ics') {
    await shareEventIcs(context, entry);
  }
}

/// A `.ics` fájl elkészítése és megosztása (a rendszer megosztó lapjával).
///
/// ⚠️ Az `sharePositionOrigin` **kötelező** az iPhone/iPad megosztó laphoz: enélkül
/// a lap némán nem jelenik meg (ezt a 382-es kör mérte meg a megosztás gombnál).
Future<void> shareEventIcs(
  BuildContext context,
  EventCalendarEntry entry,
) async {
  final messenger = ScaffoldMessenger.of(context);
  // ⚠️ A megosztás kiindulópontját MÉG az aszinkron hívások ELŐTT olvassuk ki: az
  // iPhone/iPad megosztó lapja ezt kéri, egy `await` után viszont a `context`
  // már nem biztos, hogy a fában van (ezt az analyzer is jelzi).
  final box = context.findRenderObject() as RenderBox?;
  final origin = box == null || !box.hasSize
      ? null
      : box.localToGlobal(Offset.zero) & box.size;
  try {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/${entry.fileName}');
    await file.writeAsString(buildEventIcs(entry), flush: true);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/calendar', name: entry.fileName)],
      subject: shareSubject(entry.title),
      sharePositionOrigin: origin,
    );
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(
        content: AppText('A naptárfájl elkészítése nem sikerült.'),
      ),
    );
  }
}

/// Külső megnyitás (a Google Naptár a böngészőben/natív appban nyíljon).
Future<bool> _launchExternal(Uri uri) async {
  try {
    if (await launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication)) {
      return true;
    }
  } catch (_) {
    // A nem támogatott mód kivételt ad — ezért jön a második próba.
  }
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}
