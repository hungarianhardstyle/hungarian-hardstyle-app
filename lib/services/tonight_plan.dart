import '../models/event.dart';

/// A **„Ma este"** kártya döntései — tiszta függvények, hálózat nélkül mérhetők.
///
/// Szabály: egy buli „ma este" akkor, ha **ma van**, vagy **épp tart** (az
/// éjfél utáni órákban is, amíg be nem fejeződik). Több ilyen közül a
/// legkorábban kezdődőt (vagy az épp tartót) mutatjuk.

/// Hány órával a kezdés előtt jelenik meg a kártya (a nap folyamán).
const Duration tonightLeadTime = Duration(hours: 12);

/// Záró idő nélkül ennyi ideig tart egy buli (ugyanaz, mint a szerveren).
const Duration tonightDefaultLength = Duration(hours: 10);

/// A becsekkolás a kezdés előtt ennyivel nyílik (ugyanaz, mint a szerveren).
const Duration checkinLeadTime = Duration(hours: 1);

DateTime? eventStartAt(HuhsEvent event) =>
    _combine(event.startDate, event.startTime, '20:00');

/// A buli vége: záró dátum/idő; ha az nincs vagy a kezdés előtt van (22:00 → 05:00),
/// akkor az éjfél utáni nap; ha egyik sincs, a kezdéstől 10 óra.
DateTime? eventEndAt(HuhsEvent event) {
  final start = eventStartAt(event);
  if (start == null) return null;
  final hasEnd =
      event.endDate.trim().isNotEmpty || event.endTime.trim().isNotEmpty;
  if (!hasEnd) return start.add(tonightDefaultLength);
  var end = _combine(
    event.endDate.trim().isNotEmpty ? event.endDate : event.startDate,
    event.endTime,
    '23:59',
  );
  if (end == null) return start.add(tonightDefaultLength);
  if (!end.isAfter(start)) end = end.add(const Duration(days: 1));
  return end;
}

/// A kártyán megjelenítendő buli, vagy `null`.
HuhsEvent? tonightEvent(Iterable<HuhsEvent> events, DateTime now) {
  HuhsEvent? best;
  DateTime? bestStart;
  for (final event in events) {
    final start = eventStartAt(event);
    final end = eventEndAt(event);
    if (start == null || end == null) continue;
    // A buli napján reggel 6-tól (korai kezdésnél a kezdés előtt 12 órával).
    final morning = DateTime(start.year, start.month, start.day, 6);
    final lead = start.subtract(tonightLeadTime);
    final visibleFrom = lead.isBefore(morning) ? lead : morning;
    if (now.isBefore(visibleFrom) || now.isAfter(end)) continue;
    if (bestStart == null || start.isBefore(bestStart)) {
      best = event;
      bestStart = start;
    }
  }
  return best;
}

enum CheckinWindow { none, notYet, open, closed }

/// A becsekkolás állapota. A szerver által küldött ablakot használja; ha az
/// hiányzik, a saját számítást (a szerver úgyis ellenőriz).
CheckinWindow checkinWindowFor(HuhsEvent event, DateTime now) {
  if (!event.checkinEnabled) return CheckinWindow.none;
  final opens =
      event.checkinOpensAt ??
      eventStartAt(event)?.subtract(checkinLeadTime);
  final closes = event.checkinClosesAt ?? eventEndAt(event);
  if (opens == null || closes == null) return CheckinWindow.none;
  if (now.isBefore(opens)) return CheckinWindow.notYet;
  if (now.isAfter(closes)) return CheckinWindow.closed;
  return CheckinWindow.open;
}

DateTime? _combine(String date, String time, String fallbackTime) {
  final day = DateTime.tryParse(date.trim());
  if (day == null) return null;
  final parts = (time.trim().isEmpty ? fallbackTime : time.trim()).split(':');
  final hour = int.tryParse(parts.first) ?? 0;
  final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  return DateTime(day.year, day.month, day.day, hour, minute);
}
