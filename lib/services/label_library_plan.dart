import '../models/label_library.dart';
import '../models/release.dart';

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

/// Az **első** olyan tétel indexe, amit le kell tölteni a lejátszáshoz — a
/// sornak attól az indextől kell indulnia, hogy ne legyen csend.
///
/// [downloaded] a már meglevő tételek kulcsai (`releaseId:változat`).
int firstUndownloadedIndex(List<LabelQueueEntry> queue, Set<String> downloaded) {
  for (var index = 0; index < queue.length; index++) {
    if (!downloaded.contains(queue[index].key)) return index;
  }
  return -1;
}
