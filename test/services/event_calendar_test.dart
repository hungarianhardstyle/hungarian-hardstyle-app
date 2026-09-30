import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:hungarian_hardstyle_app/models/event.dart';
import 'package:hungarian_hardstyle_app/services/event_calendar.dart';

/// **Naptár-export** — a `.ics` és a Google Naptár link bizonyítása.
///
/// MIÉRT EZEK A MÉRÉSEK (nem csak „van benne valami"):
///   * a `.ics` **szabvány-kötött**: CRLF, escape-elés, 75 oktettes sor-felbontás
///     — ha ezek sérülnek, a naptáralkalmazás **hibás vagy üres** bejegyzést
///     importál, és ezt a felhasználó nem tudja megjavítani;
///   * az **időpont nem csúszhat el**: a WordPress helyi faliórát tárol, a
///     szerver UTC-n fut — a bejegyzés ezért **lebegő helyi idő** (`20261017T230000`,
///     időzóna nélkül), és a teszt azt is méri, hogy a falióra **változatlan**;
///   * a **hibás adat** (nincs dátum, fordított sorrendű zárás) nem tippelhet:
///     ilyenkor nincs naptárbejegyzés, illetve a zárás a kezdéshez igazodik.
void main() {
  HuhsEvent eventFrom(Map<String, dynamic> json) => HuhsEvent.fromJson({
    'id': 12505,
    'title': 'Hard Base Classic',
    'description': 'Találkozzunk a kapuban!',
    'start_date': '2026-10-17',
    'start_time': '23:00',
    'end_date': '2026-10-18',
    'end_time': '05:00',
    'venue_name': 'Barba Negra',
    'venue_city': 'Budapest',
    'venue_zip': '1117',
    'venue_address': 'Prielle Kornélia u. 4.',
    ...json,
  });

  test('a bejegyzés a helyi faliórát viszi (nem számol időzónát)', () {
    final entry = eventCalendarEntry(eventFrom(const {}))!;
    expect(entry.start.hour, 23);
    expect(entry.start.minute, 0);
    expect(entry.start.day, 17);
    expect(entry.end.hour, 5);
    expect(entry.end.day, 18);
    expect(entry.allDay, isFalse);
    expect(entry.uid, 'huhs-event-12505@hungarianhardstyle.hu');
    expect(entry.fileName, 'huhs-event-12505.ics');
  });

  test('befejezés nélkül a zárás a kezdés + 4 óra (nem lesz hibás hossz)', () {
    final entry = eventCalendarEntry(
      eventFrom(const {'end_date': '', 'end_time': ''}),
    )!;
    expect(entry.end.difference(entry.start), eventCalendarFallbackDuration);
  });

  test('a kezdés ELŐTTI zárás nem kerülhet a naptárba (a kezdéshez igazodik)', () {
    final entry = eventCalendarEntry(
      eventFrom(const {'end_date': '2026-10-16', 'end_time': '22:00'}),
    )!;
    expect(entry.end.isAfter(entry.start), isTrue);
    expect(entry.end.difference(entry.start), eventCalendarFallbackDuration);
  });

  test('dátum nélküli eseményhez nincs naptárbejegyzés (nem tippelünk)', () {
    expect(
      eventCalendarEntry(eventFrom(const {'start_date': ''})),
      isNull,
    );
    expect(
      eventCalendarEntry(eventFrom(const {'start_date': 'nem-datum'})),
      isNull,
    );
  });

  test('időpont nélkül egész napos esemény, KIZÁRÓ végnappal', () {
    final entry = eventCalendarEntry(
      eventFrom(const {
        'start_time': '',
        'end_time': '',
        'end_date': '',
      }),
    )!;
    expect(entry.allDay, isTrue);
    expect(entry.start.day, 17);
    expect(entry.end.day, 18, reason: 'a DTEND egész napos eseménynél kizáró');
    expect(
      entry.end.difference(entry.start),
      const Duration(days: 1),
    );
  });

  test('a .ics szerkezete és a lebegő helyi idő', () {
    final entry = eventCalendarEntry(eventFrom(const {}))!;
    final ics = buildEventIcs(entry, stamp: DateTime.utc(2026, 9, 28, 12));
    final lines = ics.split('\r\n');

    expect(ics.contains('\n\n'), isFalse, reason: 'minden sor CRLF-fel zárul');
    expect(ics.endsWith('\r\n'), isTrue);
    expect(lines.first, 'BEGIN:VCALENDAR');
    expect(ics.contains('VERSION:2.0'), isTrue);
    expect(ics.contains('PRODID:$eventCalendarProdid'), isTrue);
    expect(ics.contains('UID:huhs-event-12505@hungarianhardstyle.hu'), isTrue);
    expect(ics.contains('DTSTAMP:20260928T120000Z'), isTrue);
    expect(
      ics.contains('DTSTART:20261017T230000'),
      isTrue,
      reason: 'lebegő helyi idő: semmi `Z`, semmi TZID',
    );
    expect(ics.contains('DTEND:20261018T050000'), isTrue);
    expect(ics.contains('TZID'), isFalse);
    expect(ics.contains('SUMMARY:Hard Base Classic'), isTrue);
    expect(
      ics.contains('LOCATION:Barba Negra\\, 1117\\, Budapest\\, Prielle'),
      isTrue,
      reason: 'a vessző escape-elve (RFC 5545)',
    );
    expect(ics.contains('URL:https://hungarianhardstyle.hu/?p=12505'), isTrue);
    expect(lines.contains('END:VCALENDAR'), isTrue);
  });

  test('a szöveg-mezők escape-elése (vessző, pontosvessző, backslash, sortörés)', () {
    final entry = eventCalendarEntry(
      eventFrom(const {
        'title': r'Buli; 23:00, avagy \ a jó buli',
        'description': 'Első sor\nMásodik sor',
      }),
    )!;
    final ics = buildEventIcs(entry);
    expect(
      ics.contains(r'SUMMARY:Buli\; 23:00\, avagy \\ a jó buli'),
      isTrue,
      reason: 'a `;` `,` és `\\` escape-elve',
    );
    final description = ics
        .split('\r\n')
        .firstWhere((line) => line.startsWith('DESCRIPTION:'))
        .replaceFirst(RegExp(r'^DESCRIPTION:'), '');
    // A törés után a folytató sor szóközzel kezdődik — ezt visszafűzve kapjuk a
    // szabvány szerinti értéket.
    final unfolded = description.replaceAll(RegExp(r'\r\n '), '');
    expect(unfolded.contains(r'\n'), isTrue, reason: 'a sortörés `\\n` alakban');
    expect(unfolded.contains('Első sor'), isTrue);
    expect(unfolded.contains('Második sor'), isTrue);
  });

  test('a 75 oktettnél hosszabb sor felbomlik, és visszafűzve AZONOS', () {
    final longTitle = 'Hard Base Classic — a hosszú cím ami biztosan nem fér ki egy sorba, '
        'mert a naptárak 75 oktettnél felbontják a sorokat';
    final entry = eventCalendarEntry(eventFrom({'title': longTitle}))!;
    final ics = buildEventIcs(entry);
    final rawLines = ics.split('\r\n');

    final summaryStart = rawLines.indexWhere(
      (line) => line.startsWith('SUMMARY:'),
    );
    expect(summaryStart >= 0, isTrue);
    final summaryLines = <String>[rawLines[summaryStart]];
    var index = summaryStart + 1;
    while (index < rawLines.length && rawLines[index].startsWith(' ')) {
      summaryLines.add(rawLines[index]);
      index += 1;
    }
    expect(
      summaryLines.length,
      greaterThan(1),
      reason: 'a hosszú cím több sorba törik',
    );
    for (final line in summaryLines) {
      expect(
        utf8.encode(line).length,
        lessThanOrEqualTo(75),
        reason: 'egy sor sem lehet 75 oktettnél hosszabb',
      );
    }
    for (final line in summaryLines.skip(1)) {
      expect(line.startsWith(' '), isTrue, reason: 'a folytatás szóközzel kezdődik');
    }
    final unfolded =
        summaryLines.first + summaryLines.skip(1).map((l) => l.substring(1)).join();
    // ⚠️ Az escape-elés a felbontás ELŐTT történik, ezért a visszafűzött érték a
    // szabvány szerinti (escape-elt) alak — a vessző `\,`.
    expect(unfolded, 'SUMMARY:${longTitle.replaceAll(',', r'\,')}');
  });

  test('a felbontás nem vág ketté többbájtos karaktert (UTF-8)', () {
    // Csupa kétbájtos karakter: 40 darab `ő` = 80 oktett.
    final title = 'ő' * 40;
    final folded = foldIcsLine('SUMMARY:$title');
    expect(folded.length, greaterThan(1));
    final unfolded = folded.first + folded.skip(1).map((l) => l.substring(1)).join();
    expect(unfolded, 'SUMMARY:$title');
    expect(unfolded.runes.length, 'SUMMARY:$title'.runes.length);
    for (final line in folded) {
      expect(utf8.encode(line).length, lessThanOrEqualTo(75));
      // A visszafejtés nem dob: nem keletkezett fél karakter.
      expect(() => utf8.decode(utf8.encode(line)), returnsNormally);
    }
  });

  test('egész napos eseménynél DATE alakok vannak (nincs óra)', () {
    final entry = eventCalendarEntry(
      eventFrom(const {'start_time': '', 'end_time': '', 'end_date': ''}),
    )!;
    final ics = buildEventIcs(entry);
    expect(ics.contains('DTSTART;VALUE=DATE:20261017'), isTrue);
    expect(ics.contains('DTEND;VALUE=DATE:20261018'), isTrue);
    expect(ics.contains('DTSTART:2026'), isFalse);
  });

  test('a Google Naptár link előtöltött, helyes zónával', () {
    final entry = eventCalendarEntry(eventFrom(const {}))!;
    final uri = googleCalendarUrl(entry);
    final query = uri.queryParameters;

    expect(uri.host, 'calendar.google.com');
    expect(uri.path, '/calendar/render');
    expect(query['action'], 'TEMPLATE');
    expect(query['text'], 'Hard Base Classic');
    expect(query['dates'], '20261017T230000/20261018T050000');
    expect(query['ctz'], eventCalendarTimeZone);
    expect(query['location'], contains('Barba Negra'));
    expect(query['location'], contains('Budapest'));
    expect(query['details'], contains('Találkozzunk a kapuban!'));
    expect(query['details'], contains('https://hungarianhardstyle.hu/?p=12505'));
  });

  test('egész napos eseménynél a Google link nap-dátumot és nincs `ctz`', () {
    final entry = eventCalendarEntry(
      eventFrom(const {'start_time': '', 'end_time': '', 'end_date': ''}),
    )!;
    final query = googleCalendarUrl(entry).queryParameters;
    expect(query['dates'], '20261017/20261018');
    expect(query.containsKey('ctz'), isFalse);
  });

  test('a HTML-leírás sima szövegként kerül a naptárba', () {
    final entry = eventCalendarEntry(
      eventFrom(const {
        'description': '<p>Első bekezdés &amp; encore</p><p>Második<br>sor</p>',
      }),
    )!;
    expect(entry.details.contains('<'), isFalse);
    expect(entry.details.contains('&amp;'), isFalse);
    expect(entry.details.contains('Első bekezdés & encore'), isTrue);
    expect(entry.details.contains('Második'), isTrue);
  });

  test('a felület bekötése: fejléc-gomb és az „Ott leszek" utáni akció', () {
    final screen = File(
      'lib/screens/events/event_detail_screen.dart',
    ).readAsStringSync();
    expect(
      screen.contains('EventCalendarButton(event: event)'),
      isTrue,
      reason: 'a fejlécben ott a naptár-gomb',
    );
    expect(
      screen.contains("if (mounted && state == 'attending')"),
      isTrue,
      reason: 'a felajánlás csak SIKERES „Ott leszek" után jelenik meg',
    );
    expect(
      screen.contains('openEventCalendarSheet(context, event)'),
      isTrue,
      reason: 'az akció ugyanazt a lapot nyitja, mint a fejléc gombja',
    );

    final widget = File(
      'lib/widgets/calendar_export_button.dart',
    ).readAsStringSync();
    expect(
      widget.contains('sharePositionOrigin: origin'),
      isTrue,
      reason: 'iPhone-on enélkül némán nem jelenik meg a megosztó lap',
    );

    final dictionary =
        jsonDecode(File('assets/i18n/en.json').readAsStringSync())
            as Map<String, dynamic>;
    for (final key in const [
      'Naptárba',
      'Esemény a naptárba',
      'Google Naptár',
      'Naptárfájl (.ics)',
      'Ehhez az eseményhez nincs érvényes dátum.',
      'A naptárfájl elkészítése nem sikerült.',
      'Ott leszek — tedd be a naptáradba is!',
    ]) {
      expect(dictionary.containsKey(key), isTrue, reason: 'hiányzó kulcs: $key');
    }
  });
}
