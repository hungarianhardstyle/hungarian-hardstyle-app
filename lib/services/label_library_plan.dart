import '../models/label_library.dart';
import '../models/release.dart';

/// A „Megvásárolt zenéim" listában **megjelenő** kiadványok.
///
/// A tulajdonos kérése (2026-09-21): *„a megvásárolt zenék között ne látszódjon
/// a már eltávolított kiadvány, felesleges"* — vagyis ha egy kiadvány eltűnt a
/// nyilvános katalógusból (törölték vagy elrejtették), akkor **ne kapjon
/// kártyát** a listában. A feloldás/vásárlás ettől **megmarad** (a Firestore-ban
/// van, nem a listában), ezért ha a kiadvány visszakerül a katalógusba, a sor
/// automatikusan újra megjelenik.
///
/// A **lejátszási sorba** ilyen tétel nem is kerülhetett be: a `buildLabelQueue`
/// csak ismert kiadványból dolgozik (lásd ott a 3. szabályt).
List<LabelLibraryItem> visibleLibraryItems(
  List<LabelLibraryItem> items, {
  Set<int> unavailable = const {},
}) {
  if (unavailable.isEmpty) return List<LabelLibraryItem>.of(items);
  return [
    for (final item in items)
      if (!unavailable.contains(item.releaseId)) item,
  ];
}

/// A „Saját zenéim" lejátszási sor összeállítása — **tiszta logika**.
///
/// A tulajdonos kérése: *„le tudja játszani, ha vége a zenének, ugrik a
/// következőre"*, illetve a választott viselkedés: *„az egész könyvtárban
/// tovább (a kiadvány végén a következő kiadvány)"*.
///
/// MIÉRT TISZTA MODUL: a sorrend az egyetlen dolog, amit a felhasználó
/// **hall** — ha itt hiba van (kimarad egy tétel, rossz sorrend, kétszer
/// szerepel), azt nem lehet „szépnek" nevezni. Ezért a sor összeállítása
/// Firebase és lejátszó nélkül mérhető.
///
/// HÁROM SZÁNDÉKOS SZABÁLY:
///  1. **A sor a könyvtár sorrendjét követi** (a szerver a legfrissebb
///     kiadvánnyal kezd), és egy kiadványon belül a változatok a felületi
///     sorrendben mennek (Radio → Extended → WAV/MP3) — nem ABC-sorrendben.
///  2. **Csak az van a sorban, ami a felhasználóé** (`variants`), és minden
///     tétel **egyszer** szerepel — a duplikáció itt hallható hiba lenne.
///  3. **A hiányzó kiadvány-adat nem akadály**: ha egy kiadvány már nincs a
///     katalógusban (törölték/átnevezték), a tétel **akkor is** bekerül a
///     sorba, „Kiadvány #&lt;id&gt;" címmel — a zenéje attól még az övé.
List<LabelQueueEntry> buildLabelQueue({
  required List<LabelLibraryItem> items,
  required Map<int, HuhsRelease> catalog,
}) {
  final queue = <LabelQueueEntry>[];
  final seen = <String>{};
  for (final item in items) {
    final release = catalog[item.releaseId];
    final title = (release?.title ?? '').trim().isEmpty
        ? 'Kiadvány #${item.releaseId}'
        : release!.title.trim();
    final artist = release == null
        ? ''
        : release.artists.map((entry) => entry.name).join(' & ');
    for (final variant in item.variants) {
      final key = '${item.releaseId}:$variant';
      if (!seen.add(key)) continue;
      queue.add(
        LabelQueueEntry(
          releaseId: item.releaseId,
          variant: variant,
          title: title,
          artist: artist,
          coverUrl: release?.coverUrl ?? '',
        ),
      );
    }
  }
  return queue;
}

/// A következő lejátszandó tétel indexe, vagy `-1`, ha vége a sornak.
///
/// **Nem teker körbe** (a tulajdonos kérése: „a végén megáll"), és egyetlen
/// tételnél sem indítja újra önmagát.
int nextLabelQueueIndex(int current, int length) {
  if (length <= 0) return -1;
  final next = current + 1;
  return next >= length ? -1 : next;
}

/// Az előző tétel indexe, vagy `-1`, ha ez az első.
int previousLabelQueueIndex(int current, int length) {
  if (length <= 0) return -1;
  final previous = current - 1;
  return previous < 0 ? -1 : previous;
}

// --- CSAK A LETÖLTÖTT ZENÉK JÁTSZHATÓK ---------------------------------------
//
// A tulajdonos jelzése: *„ha lapozok a zenék között, le akarja tölteni ami nincs
// letöltve, és így akarja lejátszani, csak a letöltött zenéket játsza le"*.
//
// Ezért a lapozás (előre/hátra és a szám végi automatikus továbblépés) **átugorja**
// a nem letöltött tételeket, és nem indít letöltést. A letöltés kizárólag a
// „Letöltés" gombra történik — így nem lesz váratlan, nagy forgalmú letöltés,
// amikor csak tovább szeretnél lépni.

/// Az első **letöltött** tétel indexe, vagy `-1`, ha egy sincs letöltve.
int firstDownloadedIndex(List<LabelQueueEntry> queue, Set<String> downloaded) {
  for (var index = 0; index < queue.length; index++) {
    if (downloaded.contains(queue[index].key)) return index;
  }
  return -1;
}

/// A [current] utáni első **letöltött** tétel indexe, vagy `-1`, ha nincs több.
///
/// Ha [current] még nincs kiválasztva (`-1`), az első letöltött tétellel kezd.
int nextDownloadedIndex(
  List<LabelQueueEntry> queue,
  Set<String> downloaded,
  int current,
) {
  final start = current < 0 ? 0 : current + 1;
  for (var index = start; index < queue.length; index++) {
    if (downloaded.contains(queue[index].key)) return index;
  }
  return -1;
}

/// A [current] előtti első **letöltött** tétel indexe, vagy `-1`, ha nincs.
int previousDownloadedIndex(
  List<LabelQueueEntry> queue,
  Set<String> downloaded,
  int current,
) {
  final start = current < 0 ? queue.length - 1 : current - 1;
  for (var index = start; index >= 0; index--) {
    if (downloaded.contains(queue[index].key)) return index;
  }
  return -1;
}
