/// A DJ-adatlap „Megjelenései" szakaszának **tiszta** szabályai.
///
/// Miért külön modul: a szakasz a szerverről kapott kiadvány-listából dolgozik,
/// és két dolgot **soha** nem szabad elrontania —
///  1. **más DJ kiadványa nem kerülhet a lapra** (a lista cache-ből is jöhet,
///     ezért itt is szűrünk, nem bízunk vakon a kérés paraméterében),
///  2. **a sorrend a megjelenés dátuma szerint csökkenő** (a legfrissebb elöl).
/// A döntés ezért nem a képernyőn él, hanem itt, ahol mérhető.
library;

import '../models/release.dart';

/// Ennyi kiadvány látszik közvetlenül a DJ-adatlapon; a többi a
/// „Összes megjelenése" gomb mögött van.
const int artistReleasesPreviewCount = 4;

/// A DJ **saját** kiadványai, a legfrissebbel az élen.
///
/// [artistId] <= 0 esetén üres lista: így egy hibás/hiányzó azonosító sem
/// hozhatja be a teljes katalógust a DJ-adatlapra.
List<HuhsRelease> artistReleasesFor(
  int artistId,
  Iterable<HuhsRelease> releases,
) {
  if (artistId <= 0) return const [];
  final mine = releases
      .where(
        (release) => release.artists.any((artist) => artist.id == artistId),
      )
      .toList(growable: false);
  return sortReleasesByReleaseDate(mine);
}

/// Az adatlapon **azonnal** látszó rész (legfeljebb [limit] darab).
List<HuhsRelease> artistReleasesPreview(
  int artistId,
  Iterable<HuhsRelease> releases, {
  int limit = artistReleasesPreviewCount,
}) {
  final all = artistReleasesFor(artistId, releases);
  if (limit <= 0 || all.length <= limit) return all;
  return all.take(limit).toList(growable: false);
}

/// Van-e a láthatónál több kiadvány (ekkor kell a „több" gomb).
bool hasMoreArtistReleases(
  int total, {
  int limit = artistReleasesPreviewCount,
}) {
  if (limit <= 0) return false;
  return total > limit;
}

/// A szakasz címe — egy kiadványnál egyes szám, hogy ne legyen magyartalan.
String artistReleasesLabel(int count) =>
    count == 1 ? 'Megjelenése' : 'Megjelenései';
