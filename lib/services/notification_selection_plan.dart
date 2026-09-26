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

/// A kijelölés-gomb felirata — **szótári kulcs**, nem kész szöveg.
///
/// ⚠️ **MÉRT HIBA (a tulajdonos jelzése, 2026-09-26):** *„Értesítéseknél: Jelölj
/// ki értesítéseket, Kijelölve: 50"* — ez a függvény **kész magyar szöveget**
/// adott vissza (nyers ternary + interpoláció), ezért angol módban is magyarul
/// jelent meg, és az i18n-extraktor **nem is látta** (nem UI-literál).
/// Mostantól a **kulcsot** adja (és a hívó fordítja `trArgs`-szal), így a szótár
/// kapuja is számon kéri.
String notificationSelectionKey(int count) =>
    count <= 0 ? 'Jelölj ki értesítéseket' : 'Kijelölve: {n}';

/// A törlés utáni visszajelzés **szótári kulcsa** (a hívó fordítja).
String notificationDeletedKey(int count) =>
    count == 1 ? '1 értesítés törölve.' : '{n} értesítés törölve.';

/// A kijelöltek közül eltűnt azonosítók eldobása (a lista élő streamből jön,
/// ezért egy törölt/archivált sor kikerülhet alólunk).
Set<String> pruneNotificationSelection(
  Set<String> selected,
  Iterable<AppNotification> items,
) {
  final live = items.map((item) => item.id.trim()).toSet();
  return selected.where(live.contains).toSet();
}

/// A kijelölés **állapota** — szándékosan külön osztály, hogy mérhető legyen.
///
/// ⚠️ MIÉRT KELL (éles hiba, 2026-09-22, a tulajdonos jelzése: *„a notify
/// kijelölésnél egyszerre csak egyet lehet kijelölni"*): a képernyő korábban
/// így írta magát:
///
/// ```dart
/// _selected..clear()..addAll(toggleNotificationSelection(_selected, id, …));
/// ```
///
/// A kaszkád (`..`) **előbb** futtatja a `clear()`-t, és csak utána értékeli ki a
/// `toggleNotificationSelection` argumentumait — a „most kijelölöm?" kérdés tehát
/// **már üres halmazon** dőlt el, mindig `true` lett, és az eredmény **pontosan
/// egy** azonosító volt. Ezért cserélte le minden koppintás az egész kijelölést.
///
/// A tiszta szabály (`toggleNotificationSelection`) végig helyes volt — a hiba a
/// **bekötésben** élt, amit a szabály tesztje nem lát. Ezért az állapot most itt
/// van, és a „több sor is kijelölhető" tulajdonság **közvetlenül mérhető**.
class NotificationSelection {
  final Set<String> _ids = <String>{};

  /// A kijelölt azonosítók (másolat — kívülről nem módosítható).
  Set<String> get ids => Set<String>.unmodifiable(_ids);

  int get count => _ids.length;

  bool get isEmpty => _ids.isEmpty;

  bool get isNotEmpty => _ids.isNotEmpty;

  bool contains(String id) => _ids.contains(id.trim());

  /// Egy sor kijelölése/leengedése. A **többit nem érinti** — ez a lényeg.
  void toggle(String id) {
    // ⚠️ A következő halmazt ELŐBB kell kiszámolni, és csak utána cserélni:
    // így a `selectedNow` a jelenlegi állapotból dől el.
    final next = toggleNotificationSelection(
      _ids,
      id,
      selectedNow: !contains(id),
    );
    _ids
      ..clear()
      ..addAll(next);
  }

  /// Az összes megadott azonosító kijelölése (a látható fül sorai).
  void selectAll(Iterable<String> ids) {
    _ids
      ..clear()
      ..addAll(ids.map((id) => id.trim()).where((id) => id.isNotEmpty));
  }

  void clear() => _ids.clear();

  /// A listából eltűnt sorok eldobása (a stream bármikor szűkíthet).
  void retainOnly(Iterable<AppNotification> items) {
    final live = items.map((item) => item.id.trim()).toSet();
    _ids.removeWhere((id) => !live.contains(id));
  }

  /// A megadott sorok közül hány van kijelölve (a fejléc számához).
  int countWithin(Iterable<AppNotification> items) =>
      items.where((item) => _ids.contains(item.id.trim())).length;
}
