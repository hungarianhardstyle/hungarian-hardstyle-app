/// **Naptár-export** egy eseményhez — tiszta, hálózat és Flutter nélkül tesztelhető
/// kód (a `.ics` szöveg és a Google Naptár link összeállítása).
///
/// MIÉRT (a tulajdonos választotta a hat irány közül a *„naptár-export az
/// eseményekhez"* pontot): aki „Ott leszek"-et nyom, az **elköteleződik** — de a
/// buli estéjére semmi nem emlékezteti, ha nem kerül be a naptárába. A naptárba
/// tett esemény viszont **visszahozza**: a naptár emlékeztet, és a bejegyzésben
/// ott a link is.
///
/// KÉT ÚT (mindkettő ugyanabból az adatból):
///   * **Google Naptár** — egy előtöltött `calendar.google.com/calendar/render`
///     link, ami azonnal a „mentés" lapot nyitja;
///   * **`.ics` fájl** — bármelyik naptáralkalmazásba importálható (iOS
///     Naptár, Outlook, Thunderbird, Google Naptár import).
///
/// ⚠️ **IDŐZÓNA-DÖNTÉS (mért buktató elkerülése):** a WordPress **helyi
/// faliórát** tárol (`2026-10-17` + `23:00`), a szerver viszont UTC-n fut. A
/// `.ics`-be ezért **lebegő (floating) helyi idő** kerül — `DTSTART:20261017T230000`
/// időzóna nélkül. Ez az RFC 5545 szerint a **néző helyi ideje**, ami a magyar
/// közönségnél pontosan a buli kezdete; így nem kell nyári/téli óraátállítást
/// számolni (és nem is tudunk elszámolni egy órát). A Google-linkhez hasonlóan
/// `ctz=Europe/Budapest`-et adunk, hogy a naptár a helyes zónában értelmezze.
///
/// ⚠️ **A .ics SZABÁLYAI, amiket itt be kell tartani** (mérve a szabványból):
///   * a sorok **CRLF**-fel zárulnak;
///   * a `\` `;` `,` és a sortörés **escape-elendő** (`\\`, `\;`, `\,`, `\n`);
///   * a 75 oktettnél hosszabb sorokat **fel kell törni**, és a folytatás egy
///     szóközzel kezdődik (a szóköz beleszámít a 75-be);
///   * egész napos eseménynél `DTSTART;VALUE=DATE`, és a `DTEND` **kizáró**
///     (a következő nap).
library;

import 'dart:convert';

import '../models/event.dart';
import 'share_links.dart';

/// Az alapértelmezett hossz, ha az eseménynek nincs befejezése.
///
/// Miért 4 óra: a mért magyar események jellemzően 22:00/23:00-kor kezdődnek és
/// hajnali 3-5 körül végződnek — a 4 óra a „nem sikerül rosszul" választás, és a
/// naptárban a felhasználó bármikor átírja.
const Duration eventCalendarFallbackDuration = Duration(hours: 4);

/// A naptárbejegyzés időzónája (a szcéna eseményei Budapesten vannak).
const String eventCalendarTimeZone = 'Europe/Budapest';

/// A `PRODID` — a naptáralkalmazások ebből tudják, melyik program írta a fájlt.
const String eventCalendarProdid = '-//Hungarian Hardstyle//HUHS App//HU';

/// Egy esemény naptárbejegyzése (minden mező készen a kiíráshoz).
class EventCalendarEntry {
  const EventCalendarEntry({
    required this.uid,
    required this.title,
    required this.start,
    required this.end,
    required this.allDay,
    this.location = '',
    this.details = '',
    this.url = '',
  });

  /// Az egyedi azonosító — a naptár ebből ismeri fel az **ugyanazt** az eseményt.
  final String uid;

  final String title;

  /// Kezdés (**helyi** falióra, időzóna nélkül értelmezve).
  final DateTime start;

  /// Befejezés (kizáró, mint az RFC 5545-ben).
  final DateTime end;

  /// Igaz, ha az eseménynek nincs kezdési időpontja (egész napos).
  final bool allDay;

  final String location;
  final String details;
  final String url;

  /// A javasolt fájlnév (a naptáralkalmazások ezt ajánlják fel).
  String get fileName => '${uid.split('@').first}.ics';
}

/// Esemény → naptárbejegyzés. `null`, ha az eseménynek nincs értelmezhető dátuma
/// (ilyenkor nincs mit a naptárba tenni — nem tippelünk dátumot).
EventCalendarEntry? eventCalendarEntry(HuhsEvent event) {
  final startDay = _parseDay(event.startDate);
  if (startDay == null) return null;

  final startClock = _parseClock(event.startTime);
  final endDay = _parseDay(event.endDate);
  final endClock = _parseClock(event.endTime);
  final allDay = startClock == null;

  late DateTime start;
  late DateTime end;
  if (allDay) {
    start = startDay;
    // Egész napos eseménynél a DTEND **kizáró**: a záró nap utáni nap.
    end = (endDay ?? startDay).add(const Duration(days: 1));
  } else {
    start = DateTime(
      startDay.year,
      startDay.month,
      startDay.day,
      startClock.$1,
      startClock.$2,
    );
    final endDate = endDay ?? startDay;
    final clock = endClock ?? startClock;
    end = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
      clock.$1,
      clock.$2,
    );
    // A hibás (a kezdés előtti vagy azzal azonos) befejezést nem vesszük át:
    // a naptárban a negatív hosszú esemény hibát okoz.
    if (!end.isAfter(start)) end = start.add(eventCalendarFallbackDuration);
  }

  final location = event.venueLine.trim();
  final details = _plainText(event.description);
  final url = contentShareUrl(id: event.id);

  return EventCalendarEntry(
    uid: 'huhs-event-${event.id}@hungarianhardstyle.hu',
    title: event.title.trim(),
    start: start,
    end: end,
    allDay: allDay,
    location: location,
    details: details,
    url: url,
  );
}

/// A `.ics` fájl **teljes** tartalma (CRLF, felbontott sorokkal).
String buildEventIcs(EventCalendarEntry entry, {DateTime? stamp}) {
  final lines = <String>[
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:$eventCalendarProdid',
    'CALSCALE:GREGORIAN',
    'METHOD:PUBLISH',
    'BEGIN:VEVENT',
    'UID:${_icsText(entry.uid)}',
    'DTSTAMP:${_icsStamp(stamp ?? DateTime.now().toUtc())}',
    if (entry.allDay) ...[
      'DTSTART;VALUE=DATE:${_icsDay(entry.start)}',
      'DTEND;VALUE=DATE:${_icsDay(entry.end)}',
    ] else ...[
      'DTSTART:${_icsLocal(entry.start)}',
      'DTEND:${_icsLocal(entry.end)}',
    ],
    'SUMMARY:${_icsText(entry.title)}',
    if (entry.location.isNotEmpty) 'LOCATION:${_icsText(entry.location)}',
    if (entry.details.isNotEmpty) 'DESCRIPTION:${_icsText(entry.details)}',
    if (entry.url.isNotEmpty) 'URL:${_icsText(entry.url)}',
    'END:VEVENT',
    'END:VCALENDAR',
  ];
  final out = StringBuffer();
  for (final line in lines) {
    for (final folded in foldIcsLine(line)) {
      out.write(folded);
      out.write('\r\n');
    }
  }
  return out.toString();
}

/// **Google Naptár** előtöltött link — azonnal a mentés lapot nyitja.
///
/// A `dates` helyi időt kap (a `ctz` mondja meg, melyik zónában), egész napos
/// eseménynél `YYYYMMDD/YYYYMMDD` alakot (a záró nap **kizáró**).
Uri googleCalendarUrl(EventCalendarEntry entry) {
  final dates = entry.allDay
      ? '${_icsDay(entry.start)}/${_icsDay(entry.end)}'
      : '${_icsLocal(entry.start)}/${_icsLocal(entry.end)}';
  final details = [
    if (entry.details.isNotEmpty) entry.details,
    if (entry.url.isNotEmpty) entry.url,
  ].join('\n\n');

  return Uri.https('calendar.google.com', '/calendar/render', {
    'action': 'TEMPLATE',
    'text': entry.title,
    'dates': dates,
    if (!entry.allDay) 'ctz': eventCalendarTimeZone,
    if (entry.location.isNotEmpty) 'location': entry.location,
    if (details.isNotEmpty) 'details': details,
  });
}

/// **RFC 5545 szerinti sor-felbontás**: 75 oktett után `CRLF` + szóköz.
///
/// ⚠️ A hosszt **oktettben** kell mérni (UTF-8), és a felbontás nem eshet
/// ketté egy többbájtos karakteren — különben a fájl importáláskor hibás lesz.
List<String> foldIcsLine(String line, {int limit = 75}) {
  final out = <String>[];
  var current = <int>[];
  var first = true;
  for (final rune in line.runes) {
    final char = String.fromCharCode(rune);
    final charBytes = utf8.encode(char);
    // A folytató sor egy szóközzel kezdődik, és az beleszámít a keretbe.
    final allowed = first ? limit : limit - 1;
    if (current.isNotEmpty && current.length + charBytes.length > allowed) {
      out.add((first ? '' : ' ') + utf8.decode(current));
      first = false;
      current = <int>[];
    }
    current.addAll(charBytes);
  }
  out.add((first ? '' : ' ') + utf8.decode(current));
  return out;
}

/// A szöveg-mezők escape-elése (RFC 5545: `\` `;` `,` és a sortörés).
String _icsText(String value) {
  return value
      .replaceAll('\\', r'\\')
      .replaceAll(';', r'\;')
      .replaceAll(',', r'\,')
      .replaceAll('\r\n', r'\n')
      .replaceAll('\n', r'\n')
      .replaceAll('\r', r'\n');
}

String _two(int value) => value.toString().padLeft(2, '0');

/// Helyi falióra `.ics` alakban (`20261017T230000`) — időzóna nélkül.
String _icsLocal(DateTime value) =>
    '${value.year}${_two(value.month)}${_two(value.day)}'
    'T${_two(value.hour)}${_two(value.minute)}${_two(value.second)}';

/// Naptári nap `.ics` alakban (`20261017`) — egész napos eseményhez.
String _icsDay(DateTime value) =>
    '${value.year}${_two(value.month)}${_two(value.day)}';

/// UTC időbélyeg (`20260928T120000Z`) — a `DTSTAMP` mindig UTC.
String _icsStamp(DateTime utc) {
  final value = utc.toUtc();
  return '${_icsDay(value)}T${_two(value.hour)}${_two(value.minute)}'
      '${_two(value.second)}Z';
}

/// `YYYY-MM-DD` nap (a WordPress ezt adja); bármi más `null`.
DateTime? _parseDay(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return null;
  final day = DateTime.tryParse(value);
  if (day == null) return null;
  return DateTime(day.year, day.month, day.day);
}

/// `HH:mm` (vagy `HH:mm:ss`) óra; üresen/hibásan `null` → egész napos esemény.
(int, int)? _parseClock(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return null;
  final parts = value.split(':');
  final hour = int.tryParse(parts.first.trim());
  final minute = parts.length > 1 ? int.tryParse(parts[1].trim()) : 0;
  if (hour == null || minute == null) return null;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  return (hour, minute);
}

/// A leírás **sima szövegként** (a naptár nem tud HTML-t, és a nyers tagek
/// csúnyán lógnának a bejegyzésben).
String _plainText(String raw) {
  var value = raw.trim();
  if (value.isEmpty) return '';
  if (RegExp(r'</?[a-z][\s\S]*>', caseSensitive: false).hasMatch(value)) {
    value = value
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'<[^>]*>'), ' ');
  }
  value = value
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#039;', "'")
      .replaceAll('&apos;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll(RegExp(r'[ \t]+'), ' ')
      .replaceAll(RegExp(r'[ \t]*\n[ \t]*'), '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return value.trim();
}
