/// „Kit ismerhetek?" — akik ugyanazokra a közelgő bulikra mennek, mint te.
///
/// Tiszta rangsorolás: eseményenként a részt vevők azonosítói jönnek be, a
/// kimenet a közös bulik száma szerint csökkenő; döntetlennél azonosító szerint
/// (stabil sorrend).
List<({String uid, int shared})> rankSuggestions(
  Map<int, Iterable<String>> attendeesByEvent, {
  required String me,
  Set<String> exclude = const {},
  int limit = 20,
}) {
  final counts = <String, int>{};
  for (final attendees in attendeesByEvent.values) {
    for (final uid in attendees.toSet()) {
      if (uid.isEmpty || uid == me || exclude.contains(uid)) continue;
      counts[uid] = (counts[uid] ?? 0) + 1;
    }
  }
  final ranked = [
    for (final e in counts.entries) (uid: e.key, shared: e.value),
  ]..sort((a, b) {
      final byShared = b.shared.compareTo(a.shared);
      return byShared != 0 ? byShared : a.uid.compareTo(b.uid);
    });
  return ranked.take(limit).toList(growable: false);
}
