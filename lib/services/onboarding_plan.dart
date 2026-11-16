/// **Az 5 lépéses bemutató tiszta döntései** — hálózat, UI és tároló nélkül.
///
/// * a választható **műfajok** a valódi DJ-adatokból jönnek (nem beégetett
///   lista), gyakoriság szerint — így egy új műfaj magától megjelenik;
/// * a DJ-k a választott műfajokhoz **illeszkedés szerint** rendeződnek, de az
///   azonos súlyúak megtartják az eredeti sorrendet (stabil rendezés);
/// * a főoldal közelgő eseményei a stílusodhoz illőket **előnyben részesítik**,
///   de a kiválasztottak **időrendben** maradnak (nem borítjuk fel a dátumot).
library;

/// A műfaj összehasonlítható alakja (kis-nagybetű és szóköz független).
String normalizeGenre(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// A választható műfajok: a DJ-k műfajainak uniója, a leggyakoribb elöl
/// (egyenlőségnél ábécérendben), az első előfordulás írásmódjával.
List<String> availableGenres(Iterable<List<String>> genreLists) {
  final counts = <String, int>{};
  final labels = <String, String>{};
  for (final genres in genreLists) {
    final seen = <String>{};
    for (final raw in genres) {
      final key = normalizeGenre(raw);
      if (key.isEmpty || !seen.add(key)) continue;
      counts[key] = (counts[key] ?? 0) + 1;
      labels.putIfAbsent(key, () => raw.trim());
    }
  }
  final keys = counts.keys.toList()
    ..sort((a, b) {
      final byCount = counts[b]!.compareTo(counts[a]!);
      return byCount != 0 ? byCount : a.compareTo(b);
    });
  return [for (final key in keys) labels[key]!];
}

/// Hány választott műfaj illik az elemre.
int genreMatchCount(List<String> genres, Set<String> preferred) {
  if (preferred.isEmpty) return 0;
  final normalized = preferred.map(normalizeGenre).toSet();
  return genres.map(normalizeGenre).toSet().intersection(normalized).length;
}

/// Az elemek illeszkedés szerint (stabilan) rendezve.
List<T> rankByGenres<T>(
  List<T> items,
  List<String> Function(T item) genresOf,
  Set<String> preferred,
) {
  if (preferred.isEmpty) return List<T>.of(items);
  final indexed = [
    for (var i = 0; i < items.length; i++)
      (
        index: i,
        item: items[i],
        score: genreMatchCount(genresOf(items[i]), preferred),
      ),
  ];
  indexed.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    return byScore != 0 ? byScore : a.index.compareTo(b.index);
  });
  return [for (final entry in indexed) entry.item];
}

/// A főoldal közelgő eseményei: a következő [window] eseményből először a
/// stílusodhoz illőket választja, a maradékot a legközelebbiekkel tölti fel,
/// majd az eredményt **visszarendezi időrendbe** (a bemenet sorrendje az idő).
List<T> personalizedUpcoming<T>(
  List<T> items,
  List<String> Function(T item) genresOf,
  Set<String> preferred, {
  int limit = 5,
  int window = 10,
}) {
  if (preferred.isEmpty || limit <= 0) return items.take(limit).toList();
  final candidates = items.take(window < limit ? limit : window).toList();
  final chosen = <int>[];
  for (var i = 0; i < candidates.length && chosen.length < limit; i++) {
    if (genreMatchCount(genresOf(candidates[i]), preferred) > 0) chosen.add(i);
  }
  for (var i = 0; i < candidates.length && chosen.length < limit; i++) {
    if (!chosen.contains(i)) chosen.add(i);
  }
  chosen.sort();
  return [for (final i in chosen) candidates[i]];
}
