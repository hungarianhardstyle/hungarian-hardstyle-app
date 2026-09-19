import '../core/firebase/firebase_callable.dart';

/// Egy szint (jelvény) a ranglétrán.
///
/// MIÉRT szerverről jön: a szinteket a WordPress adminban a tulajdonos
/// szerkeszti (`/achievements/badges`), ezért az appba beégetett lista
/// **némán elavul**, ha ott egy küszöb vagy név megváltozik. Az app a
/// `getAchievementBadgeCatalog` végpontról tölti, és csak akkor használja a
/// beépített tartalék listát, ha a hálózat nem elérhető.
class AchievementLevel {
  const AchievementLevel({
    required this.slug,
    required this.name,
    required this.minPoints,
    required this.description,
    this.imageUrl = '',
  });

  final String slug;
  final String name;
  final int minPoints;
  final String description;
  final String imageUrl;

  static AchievementLevel? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final minPoints = (raw['minPoints'] as num?)?.toInt();
    final name = '${raw['name'] ?? ''}'.trim();
    if (minPoints == null || name.isEmpty) return null;
    return AchievementLevel(
      slug: '${raw['slug'] ?? ''}'.trim(),
      name: name,
      minPoints: minPoints,
      description: '${raw['description'] ?? ''}'.trim(),
      imageUrl: '${raw['imageUrl'] ?? ''}'.trim(),
    );
  }
}

/// A katalógus-lekérdezés típusa. Azért paraméter, hogy a widget-teszt
/// **Firebase nélkül** mérhesse a viselkedést (a valódi hívás platformcsatornát
/// igényel, ami tesztben nem elérhető).
typedef AchievementCatalogCaller = Future<Map<String, dynamic>> Function();

Future<Map<String, dynamic>> _callCatalog() async {
  final response = await callFirebaseCallable<Map<String, dynamic>>(
    'getAchievementBadgeCatalog',
  );
  return response.data;
}

/// A szintek lekérdezése. Hálózati hiba esetén a **beépített** listát adja —
/// a Segítség/Achievementek képernyő soha nem lehet üres.
class AchievementService {
  AchievementService({AchievementCatalogCaller? catalogCaller})
    : _catalogCaller = catalogCaller ?? _callCatalog;

  final AchievementCatalogCaller _catalogCaller;
  /// Az utolsó ismert katalógus (2026-09-19, a WordPressből mérve).
  /// Ez csak tartalék: a hiteles forrás a szerver.
  static const fallbackLevels = <AchievementLevel>[
    AchievementLevel(
      slug: 'starter',
      name: 'Kezdő ütem',
      minPoints: 0,
      description: 'A HUHS közösség alapjelvénye.',
    ),
    AchievementLevel(
      slug: 'first-step',
      name: 'Első lépés',
      minPoints: 100,
      description: 'Az első közösségi mérföldkő.',
    ),
    AchievementLevel(
      slug: 'regular',
      name: 'Rendszeres látogató',
      minPoints: 300,
      description: 'Rendszeresen jelen van a közösségben.',
    ),
    AchievementLevel(
      slug: 'hardstyle-face',
      name: 'Hardstyle arc',
      minPoints: 700,
      description: 'Láthatóan aktív HUHS-közösségi tag.',
    ),
    AchievementLevel(
      slug: 'community',
      name: 'Közösségi ember',
      minPoints: 1500,
      description: 'Sokat tesz a közösségi jelenlétért.',
    ),
    AchievementLevel(
      slug: 'scene-veteran',
      name: 'Scene veteran',
      minPoints: 3000,
      description: 'Hosszú távon aktív színtértag.',
    ),
    AchievementLevel(
      slug: 'huhs-legend',
      name: 'HUHS legenda',
      minPoints: 6000,
      description: 'Kiemelkedő, tartós közösségi aktivitás.',
    ),
  ];

  Future<List<AchievementLevel>> fetchLevels() async {
    try {
      final data = await _catalogCaller();
      final raw = data['badges'];
      final levels = <AchievementLevel>[
        if (raw is List)
          for (final item in raw) ?AchievementLevel.fromJson(item),
      ];
      if (levels.isEmpty) return fallbackLevels;
      levels.sort((a, b) => a.minPoints.compareTo(b.minPoints));
      return levels;
    } catch (_) {
      // Hálózat nélkül is működnie kell a képernyőnek.
      return fallbackLevels;
    }
  }
}
