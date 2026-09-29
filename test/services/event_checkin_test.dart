import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/services/event_checkin.dart';

void main() {
  final start = DateTime(2026, 10, 17, 23);

  test('az ablakban (4 órával előtte … 12 órával utána) rögzíthető', () {
    expect(
      checkInStatus(eventStart: start, now: start, alreadyCheckedIn: false),
      CheckInStatus.ok,
    );
    expect(
      checkInStatus(
        eventStart: start,
        now: start.subtract(const Duration(hours: 3)),
        alreadyCheckedIn: false,
      ),
      CheckInStatus.ok,
    );
    expect(
      checkInStatus(
        eventStart: start,
        now: start.add(const Duration(hours: 11)),
        alreadyCheckedIn: false,
      ),
      CheckInStatus.ok,
    );
  });

  test('túl korai: a kód nem használható hetekkel előre', () {
    expect(
      checkInStatus(
        eventStart: start,
        now: start.subtract(const Duration(days: 7)),
        alreadyCheckedIn: false,
      ),
      CheckInStatus.tooEarly,
    );
    expect(
      checkInStatus(
        eventStart: start,
        now: start.subtract(const Duration(hours: 5)),
        alreadyCheckedIn: false,
      ),
      CheckInStatus.tooEarly,
    );
  });

  test('túl késői: a lefotózott kód sem működik másnap', () {
    expect(
      checkInStatus(
        eventStart: start,
        now: start.add(const Duration(days: 2)),
        alreadyCheckedIn: false,
      ),
      CheckInStatus.tooLate,
    );
    expect(
      checkInStatus(
        eventStart: start,
        now: start.add(const Duration(hours: 13)),
        alreadyCheckedIn: false,
      ),
      CheckInStatus.tooLate,
    );
  });

  test('tagonként egyszer: aki már jelezte, nem halmozhat pontot', () {
    expect(
      checkInStatus(eventStart: start, now: start, alreadyCheckedIn: true),
      CheckInStatus.alreadyCheckedIn,
    );
    // Az „már megvan" akkor is elsőbbséget élvez, ha amúgy lejárt az ablak.
    expect(
      checkInStatus(
        eventStart: start,
        now: start.add(const Duration(days: 3)),
        alreadyCheckedIn: true,
      ),
      CheckInStatus.alreadyCheckedIn,
    );
  });

  test('az ablak lekérdezhető a felületnek (gomb megjelenítése)', () {
    expect(
      checkInWindowOpen(eventStart: start, now: start),
      isTrue,
    );
    expect(
      checkInWindowOpen(
        eventStart: start,
        now: start.subtract(const Duration(days: 1)),
      ),
      isFalse,
    );
  });

  test('az ablak hossza állítható (a szabály egy helyen él)', () {
    expect(
      checkInStatus(
        eventStart: start,
        now: start.add(const Duration(hours: 2)),
        alreadyCheckedIn: false,
        openAfter: const Duration(hours: 1),
      ),
      CheckInStatus.tooLate,
    );
  });

  test('minden döntéshez van magyar üzenet (a szótár kulcsa)', () {
    for (final status in CheckInStatus.values) {
      expect(checkInMessageKey(status).trim(), isNotEmpty);
    }
  });
}
