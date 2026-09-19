import 'dart:async';

/// A SAJÁT rang/jelvény változásának figyelése.
///
/// **MIÉRT:** a rang és a jelvény gyorsítótárból jön (memória + tartós tároló),
/// ezért a szintlépés egy ideig nem látszott — a felület csak a cache lejárta
/// után (30 s / 2 perc) vagy újranyitáskor frissült. A tulajdonos megfogalmazása:
/// *„úgy lenne jó, hogy cache-ben megvan, de ha szintet lép, indít egy
/// lekérést"*.
///
/// Ez az osztály a saját profil **nyilvános vetületére**
/// (`public_profiles/<uid>`, amit a szerver minden pontváltozásnál frissít)
/// figyel, és **csak akkor** indít lekérést, ha a **rang tényleg megváltozott**
/// — vagyis más a jelvény `slug`-ja, vagy új verziójú a jelvényképe. A
/// pontszám növekedése önmagában nem indít semmit: a jelvény ugyanaz marad.
///
/// **Két szándékos szabály:**
///  * az **első** képet nem tekintjük változásnak (induláskor nincs felesleges
///    szerverhívás — a cache épp ezért van);
///  * két frissítés között eltelik a `minimumInterval` (alapból 2 perc), így
///    egy gyors pontgyűjtés sem indít több hívást — a közben történt
///    változást a már kiürített cache miatt a következő olvasás úgyis látja.
class AchievementRankSync {
  AchievementRankSync({
    required this.uid,
    required this.projection,
    required this.onRankChanged,
    this.minimumInterval = const Duration(minutes: 2),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final String uid;
  final Stream<Map<String, dynamic>> projection;
  final Future<void> Function() onRankChanged;

  /// Két frissítés között ennyi időnek kell eltelnie.
  final Duration minimumInterval;

  final DateTime Function() _clock;

  StreamSubscription<Map<String, dynamic>>? _subscription;
  String? _lastBadgeKey;
  DateTime? _lastRefreshAt;
  bool _refreshing = false;

  /// Hányszor indítottunk tényleges frissítést (a tesztek és a napló miatt).
  int refreshCount = 0;

  /// A jelvény azonosítója + a kép verziója: ez dönti el, változott-e a rang.
  ///
  /// A kép URL-je a szerveren **verziózott** (`?huhs_badge_v=…`), ezért a
  /// kicserélt jelvénygrafika is új kulcsot ad — ilyenkor is frissíteni kell.
  static String badgeKeyOf(Map<String, dynamic> profile) {
    final badge = profile['achievementBadge'];
    if (badge is! Map) return '';
    final slug = '${badge['slug'] ?? ''}'.trim();
    final image = '${badge['imageUrl'] ?? badge['image_url'] ?? ''}'.trim();
    if (slug.isEmpty && image.isEmpty) return '';
    return '$slug|$image';
  }

  void start() {
    _subscription ??= projection.listen(_handle, onError: (_) {});
  }

  void _handle(Map<String, dynamic> profile) {
    final key = badgeKeyOf(profile);
    // Nincs értelmes jelvény-adat (pl. üres vetület): nem döntünk.
    if (key.isEmpty) return;
    final previous = _lastBadgeKey;
    _lastBadgeKey = key;
    // Az első kép nem változás, és ha a kulcs ugyanaz, nincs mit tenni.
    if (previous == null || previous == key) return;
    final lastRefresh = _lastRefreshAt;
    if (lastRefresh != null &&
        _clock().difference(lastRefresh) < minimumInterval) {
      return;
    }
    if (_refreshing) return;
    _refreshing = true;
    _lastRefreshAt = _clock();
    refreshCount += 1;
    unawaited(
      Future<void>.sync(onRankChanged)
          .catchError((Object _) {})
          .whenComplete(() => _refreshing = false),
    );
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
