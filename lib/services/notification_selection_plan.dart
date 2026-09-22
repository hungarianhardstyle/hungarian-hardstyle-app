import '../models/app_notification.dart';

/// Az értesítések **kijelöléssel történő törlésének** szabálya — tiszta logika.
///
/// MIÉRT: a tulajdonos kérése (2026-09-22): *„Notifyt esetleg lehessen kijelölni
/// is törléshez, hogy azt törölhessem amit akarok és még se egyszerre az egészet
/// vagy egyenként lenne úgy."* Eddig csak két véglet volt: egyenként a sorok
/// menüjéből, vagy az egész fül törlése.
///
/// A döntés itt él (nem a képernyőben), mert **biztonsági** kérdés is: a
/// törlésre csak a **saját** (`recipientUid == uid`) értesítések azonosítója
/// mehet ki. A Firestore-szabály ugyanezt kéri
/// (`allow delete: if isRegistered() && resource.data.recipientUid == request.auth.uid`),
/// ezért ez a réteg csak **megerősíti**: egy elrontott vagy idegen azonosító nem
/// is indul el, és nem bukik el félúton a köteg.

/// Egy sor kijelölésének megfordítása. Ismeretlen/üres azonosítót nem jelölünk.
Set<String> toggleNotificationSelection(
  Set<String> selected,
  String id, {
  required bool selectedNow,
}) {
  final clean = id.trim();
  final next = <String>{...selected};
  if (clean.isEmpty) return next;
  if (selectedNow) {
    next.add(clean);
  } else {
    next.remove(clean);
  }
  return next;
}

/// A **törölhető** azonosítók: a kijelöltek közül csak a saját soroké, a lista
/// sorrendjében, duplázódás nélkül.
List<String> deletableNotificationIds({
  required Iterable<AppNotification> items,
  required Set<String> selected,
  required String? uid,
}) {
  final owner = (uid ?? '').trim();
  if (owner.isEmpty) return const [];
  final out = <String>[];
  final seen = <String>{};
  for (final item in items) {
    final id = item.id.trim();
    if (id.isEmpty || !selected.contains(id) || !seen.add(id)) continue;
    // Ismeretlen jogosult (régi rekord `recipientUid` nélkül) nem törölhető
    // innen — a stream úgyis csak a sajátunkat adja, de nem tippelünk.
    if (item.recipientUid.trim() != owner) continue;
    out.add(id);
  }
  return out;
}

/// A kijelölés-gomb felirata.
String notificationSelectionLabel(int count) =>
    count <= 0 ? 'Jelölj ki értesítéseket' : 'Kijelölve: $count';

/// A törlés utáni visszajelzés (a tulajdonos magyar szövegei).
String notificationDeletedLabel(int count) => count == 1
    ? '1 értesítés törölve.'
    : '$count értesítés törölve.';

/// A kijelöltek közül eltűnt azonosítók eldobása (a lista élő streamből jön,
/// ezért egy törölt/archivált sor kikerülhet alólunk).
Set<String> pruneNotificationSelection(
  Set<String> selected,
  Iterable<AppNotification> items,
) {
  final live = items.map((item) => item.id.trim()).toSet();
  return selected.where(live.contains).toSet();
}
