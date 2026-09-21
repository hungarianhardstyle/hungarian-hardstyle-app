import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/firebase/firebase_callable.dart';
import '../models/label_library.dart';
import 'label_purchase_service.dart';

/// A szerveroldali könyvtár-lekérdezés típusa (a teszt így tud Firebase nélkül
/// mérni — ugyanaz a minta, mint az `AchievementService.catalogCaller`-nél).
typedef LabelLibraryCaller = Future<Map<String, dynamic>> Function();

/// A letöltési hivatkozás kérése (a valódi útvonal a `LabelPurchaseService`,
/// amely a **jogosultságot a szerveren** ellenőrzi — a kliens nem dönthet róla).
typedef LabelDownloadUrlCaller =
    Future<String> Function(int releaseId, String variant);

/// A gyorsítótár-tároló olvasása/írása.
///
/// Az éles tároló a SharedPreferences, a teszt viszont memóriabeli tárolót ad —
/// így a gyorsítótár viselkedése plugin és Firebase nélkül mérhető.
typedef LabelLibraryCacheRead = Future<String?> Function(String key);
typedef LabelLibraryCacheWrite = Future<void> Function(String key, String value);

/// A mentett könyvtár frissességi ablaka.
///
/// Ez **nem** az adat élettartama: a mentett lista bármilyen korú, mindig
/// azonnal kimegy, csak azt dönti el, hogy kell-e a háttérben egyeztetni. Ez a
/// különbség a lényeg: a lista megjelenítése soha nem vár a hálózatra.
///
/// **Miért rövidebb, mint a WordPress-gyorsítótár 5 perce:** ez a lista a
/// **vásárlásról** szól, és a tulajdonos panasza pont ez volt (*„ez az új
/// megvásárolt zenéim is lassan tölt be"*). Ha itt öt percig „frissnek"
/// számítana a mentés, akkor egy frissen megvett kiadvány akár öt percig nem
/// látszana. A végpont ráadásul egy **hitelesített callable** (nem a lassú
/// WordPress REST), és az egyeztetés a **háttérben** fut, ezért a rövidebb
/// ablak olcsó: a képernyő így is mindig a mentett listát rajzolja azonnal.
const labelLibraryCacheTtl = Duration(seconds: 60);

/// A fiókhoz tartozó gyorsítótár-kulcs.
///
/// A UID **benne van a kulcsban**, mert a lista fiókhoz kötött: egy fiók zenéje
/// nem kerülhet a másik alá (ugyanaz a szabály, mint a helyi fájlok mappájánál).
/// Az elválasztókat kiszűrjük, hogy a kulcs ne tudjon kilépni a saját helyéről.
String labelLibraryCacheKey(String uid) =>
    'huhs.label.library.v1.${uid.trim().replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_')}';

/// A mentett könyvtár alakja: `{'savedAt': <ezredmásodperc>, 'items': [...]}`.
Map<String, Object?> encodeLabelLibraryCache(
  List<LabelLibraryItem> items,
  DateTime savedAt,
) => {
  'savedAt': savedAt.millisecondsSinceEpoch,
  'items': encodeLabelLibraryItems(items),
};

/// A mentett könyvtár visszaolvasása. Olvashatatlan bejegyzés → `null`, mert
/// abból nem lehet listát rajzolni (a hívó ilyenkor a hálózatot kérdezi).
LabelLibraryCacheEntry? decodeLabelLibraryCache(Object? stored) {
  if (stored is! Map) return null;
  final savedAt = stored['savedAt'];
  return LabelLibraryCacheEntry(
    items: decodeLabelLibraryItems(stored['items']),
    savedAt: savedAt is int
        ? DateTime.fromMillisecondsSinceEpoch(savedAt)
        : null,
  );
}

/// A mentés alakja (a [decodeLabelLibraryItems] párja).
List<Map<String, dynamic>> encodeLabelLibraryItems(
  List<LabelLibraryItem> items,
) => items.map((item) => item.toJson()).toList(growable: false);

/// A mentett JSON visszaolvasása.
///
/// Ugyanaz a szabály, mint a szerverválasznál: az értelmezhetetlen sort
/// **kihagyjuk**, nem tippelünk. Ha a mentés sérült, üres lista jön — a hívó
/// pedig a hálózathoz fordul.
List<LabelLibraryItem> decodeLabelLibraryItems(Object? stored) {
  if (stored is! List) return const [];
  final items = <LabelLibraryItem>[];
  for (final raw in stored) {
    if (raw is! Map) continue;
    final item = LabelLibraryItem.fromJson(
      raw.map((key, value) => MapEntry('$key', value)),
    );
    if (item.releaseId < 1) continue;
    if (item.variants.isEmpty) continue;
    items.add(item);
  }
  return items;
}

/// A nyers szerverválasz feldolgozása.
///
/// A `load()` és a háttérfrissítés is **ezt** használja, ezért a két út nem
/// tud eltérni egymástól (a régi hiba épp a két külön szabályból született).
List<LabelLibraryItem> labelLibraryItemsFromPayload(Object? data) {
  if (data is! Map) return const [];
  final rawItems = data['items'];
  if (rawItems is! List) return const [];
  return decodeLabelLibraryItems(rawItems);
}

/// A hálózati hiba utáni döntés: **a mentett lista nyer**, ha van.
///
/// Ez kötelező szabály (lásd az osztály dokumentációját): a felhasználó nem
/// hiheti, hogy elvesztek a vásárlásai. Mentés nélkül viszont `null` jön, és a
/// hiba **továbbmegy** — a felületnek meg kell tudnia különböztetni a „nincs
/// zenéd" és a „most nem érhető el" állapotot.
List<LabelLibraryItem>? labelLibraryFallbackOnError(
  List<LabelLibraryItem>? stored,
) => stored;

/// Kell-e háttérfrissítés a mentés korából kiindulva.
///
/// Mentés nélkül (`savedAt == null`) mindig kell; egyébként a
/// [labelLibraryCacheTtl] letelte után. Tiszta függvény, ezért az idő is
/// beadható — a teszt nem függ az óra járásától.
bool labelLibraryNeedsRefresh(
  DateTime? savedAt, {
  DateTime? now,
  Duration ttl = labelLibraryCacheTtl,
}) {
  if (savedAt == null) return true;
  return !savedAt.add(ttl).isAfter(now ?? DateTime.now());
}

/// A gyorsítótárban lévő könyvtár: a lista és a mentés időpontja.
class LabelLibraryCacheEntry {
  const LabelLibraryCacheEntry({required this.items, required this.savedAt});

  final List<LabelLibraryItem> items;
  final DateTime? savedAt;

  bool get needsRefresh => labelLibraryNeedsRefresh(savedAt);
}

/// A „Saját zenéim" könyvtár betöltése.
///
/// A szerver (`getMyLabelLibrary`) a **saját** vásárlásokat és reklám-feloldásokat
/// adja vissza; itt csak beolvassuk és megtisztítjuk. Négy szándékos szabály:
///
///  1. **Firebase nélkül nem dob**, hanem üres listát ad — a widget-tesztek
///     (és egy Firebase nélkül induló build) ne omoljanak el ezen.
///  2. **A hibás elemeket kihagyjuk**, nem tippelünk: ha egy sorban nincs
///     értelmezhető kiadvány-azonosító, az nem kerül a könyvtárba.
///  3. **A hiba nem lesz üres könyvtár**: ha a hálózat/szerver hibázik, a hiba
///     **továbbmegy** a felületnek, hogy meg tudja különböztetni a „nincs
///     zenéd" és a „most nem érhető el" állapotot. Ez fontos: a felhasználó
///     különben azt hinné, elvesztek a vásárlásai. Ha viszont **van mentett
///     lista**, az marad a képernyőn.
///  4. **A megjelenítés nem vár a hálózatra**: a mentett lista azonnal kimegy,
///     és csak a háttérben egyeztetünk. A tulajdonos panasza szó szerint ez
///     volt: *„ez az új megvárásolt zenéim is lassan tölt be"* — a WordPress
///     válaszideje mérve 0,4–2,0 s, és eddig **minden** képernyő-megnyitás
///     végigvárta.
class LabelLibraryService {
  LabelLibraryService({
    LabelLibraryCaller? caller,
    LabelDownloadUrlCaller? downloadUrlCaller,
    LabelLibraryCacheRead? cacheRead,
    LabelLibraryCacheWrite? cacheWrite,
  }) : // A privát mezőhöz nem lehet `this._x` nevű NÉVES paramétert adni, ezért
       // szándékos a kézi hozzárendelés (ugyanaz a minta, mint a letöltés-kezelőnél).
       // ignore: prefer_initializing_formals
       _caller = caller,
       // ignore: prefer_initializing_formals
       _downloadUrlCaller = downloadUrlCaller,
       // ignore: prefer_initializing_formals
       _cacheRead = cacheRead,
       // ignore: prefer_initializing_formals
       _cacheWrite = cacheWrite;

  final LabelLibraryCaller? _caller;
  final LabelDownloadUrlCaller? _downloadUrlCaller;
  final LabelLibraryCacheRead? _cacheRead;
  final LabelLibraryCacheWrite? _cacheWrite;

  /// A futó háttérfrissítések (fiókonként egy), hogy egy megnyitás se
  /// indíthasson másodikat ugyanarra a fiókra.
  final Map<String, Future<void>> _refreshInFlight = {};

  /// Aláírt letöltési hivatkozás egy **birtokolt** változathoz.
  ///
  /// A jogosultságot a szerver ellenőrzi (`getLabelDownloadUrl`), ezért ez a
  /// hívás más fiók zenéjéhez **nem** ad linket — a „ne tudja letölteni" rész
  /// itt is szerveroldalon dől el, nem a felületen.
  Future<String> downloadUrl({
    required int releaseId,
    required String variant,
  }) {
    final custom = _downloadUrlCaller;
    if (custom != null) return custom(releaseId, variant);
    return LabelPurchaseService.shared.getDownloadUrl(
      releaseId: releaseId,
      variant: variant,
    );
  }

  /// A fiók könyvtára.
  ///
  /// [uid] nélkül **nincs gyorsítótár** (sem olvasás, sem írás): a lista
  /// fiókhoz kötött, ezért UID nélkül nem tudjuk, kié — ilyenkor minden hívás a
  /// szerverre megy, ami a régi viselkedés (a meglévő hívók így működnek).
  ///
  /// [forceRefresh] a **kifejezett** frissítés: ilyenkor a mentett lista nem
  /// dönthet, a válaszra várunk. Alapból a mentett lista megy ki **azonnal**, és
  /// a hálózat csak a háttérben egyeztet (a friss eredményt a
  /// [pendingRefresh] jelzi a hívónak).
  Future<List<LabelLibraryItem>> load({
    bool forceRefresh = false,
    String? uid,
  }) async {
    final key = _cacheKeyFor(uid);
    final stored = key == null ? null : await _readStored(key);
    if (!forceRefresh && stored != null && key != null) {
      // A mentett lista már a hívónál van; a hálózat a háttérben dolgozik.
      if (stored.needsRefresh) _startBackgroundRefresh(key);
      return stored.items;
    }

    try {
      final fetched = await _fetchFromServer();
      if (fetched == null) {
        // Nincs mit kérdezni (Firebase nélküli build/teszt): nem írunk
        // mentést, és nem is hazudunk üres könyvtárat, ha van mentett lista.
        return labelLibraryFallbackOnError(stored?.items) ?? const [];
      }
      if (key != null) await _writeStored(key, fetched);
      return fetched;
    } catch (_) {
      // A hiba NEM lesz üres könyvtár (lásd a 3. szabályt).
      final fallback = labelLibraryFallbackOnError(stored?.items);
      if (fallback != null) return fallback;
      rethrow;
    }
  }

  /// A fiók futó háttérfrissítése, ha van ilyen.
  ///
  /// A megjelenítő ezt megvárhatja, és utána újraolvashatja a (már friss)
  /// mentett listát — így a friss eredmény **magától** megjelenik, hálózati
  /// várakozás nélkül.
  Future<void>? pendingRefresh(String? uid) {
    final key = _cacheKeyFor(uid);
    return key == null ? null : _refreshInFlight[key];
  }

  String? _cacheKeyFor(String? uid) {
    final trimmed = uid?.trim() ?? '';
    return trimmed.isEmpty ? null : labelLibraryCacheKey(trimmed);
  }

  /// A szerver válasza, vagy `null`, ha nincs mit kérdezni (Firebase nélkül).
  Future<List<LabelLibraryItem>?> _fetchFromServer() async {
    if (_caller == null && Firebase.apps.isEmpty) return null;
    final caller =
        _caller ??
        () => callFirebaseCallable<Map<String, dynamic>>('getMyLabelLibrary')
            .then((result) => result.data);
    return labelLibraryItemsFromPayload(await caller());
  }

  Future<LabelLibraryCacheEntry?> _readStored(String key) async {
    final payload = await _readCacheValue(key);
    if (payload == null) return null;
    try {
      return decodeLabelLibraryCache(jsonDecode(payload));
    } catch (_) {
      // Olvashatatlan mentés: nem blokkolunk, a hálózat dönt (és felülírja).
      return null;
    }
  }

  Future<void> _writeStored(String key, List<LabelLibraryItem> items) async {
    await _writeCacheValue(
      key,
      jsonEncode(encodeLabelLibraryCache(items, DateTime.now())),
    );
  }

  /// A háttérben lezajló egyeztetés.
  ///
  /// Hiba esetén **nem töröljük a mentést**: a régi lista jobb, mint a
  /// „nem érhető el" képernyő, és a következő megnyitás újrapróbálja.
  void _startBackgroundRefresh(String key) {
    if (_refreshInFlight.containsKey(key)) return;
    late final Future<void> refresh;
    refresh = Future<void>.delayed(Duration.zero, () async {
      try {
        final fetched = await _fetchFromServer();
        if (fetched != null) await _writeStored(key, fetched);
      } catch (_) {
        // A mentett lista marad (lásd a 3. szabályt).
      } finally {
        _refreshInFlight.remove(key);
      }
    });
    _refreshInFlight[key] = refresh;
  }

  Future<String?> _readCacheValue(String key) async {
    final custom = _cacheRead;
    if (custom != null) return custom(key);
    try {
      return (await SharedPreferences.getInstance()).getString(key);
    } catch (_) {
      // Best-effort: ha a tároló nem érhető el (pl. teszt-környezet), akkor
      // nincs mentés, és a betöltés a hálózati úton megy tovább.
      return null;
    }
  }

  Future<void> _writeCacheValue(String key, String value) async {
    final custom = _cacheWrite;
    if (custom != null) return custom(key, value);
    try {
      await (await SharedPreferences.getInstance()).setString(key, value);
    } catch (_) {
      // Best-effort írás: a mentés elmaradása nem akadályozhatja a betöltést.
    }
  }
}
