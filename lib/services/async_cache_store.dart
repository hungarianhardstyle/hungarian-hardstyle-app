import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import 'async_cache_plan.dart';

/// A **mentett értékek tárolója** (alapból `SharedPreferences`).
///
/// **Best-effort:** egy olvasási/írási hiba **soha** nem akadályozhatja a
/// betöltést — ilyenkor egyszerűen nincs mentés, és a hálózat dönt. Ez ugyanaz
/// a szerződés, mint a `LabelLibraryService` cache-énél.
///
/// A tároló a `read`/`write`/`remove` hívásokkal **tesztben felülírható**, ezért
/// a cache-viselkedés valódi értékekkel mérhető (nem kell SharedPreferences mock).
class AsyncCacheStore {
  AsyncCacheStore({
    Future<String?> Function(String key)? read,
    Future<void> Function(String key, String value)? write,
    Future<void> Function(String key)? remove,
  }) : _readOverride = read,
       _writeOverride = write,
       _removeOverride = remove;

  /// A közös, app-szintű tároló (a providerek ezt használják).
  static final AsyncCacheStore shared = AsyncCacheStore();

  final Future<String?> Function(String key)? _readOverride;
  final Future<void> Function(String key, String value)? _writeOverride;
  final Future<void> Function(String key)? _removeOverride;

  Future<SharedPreferences?> _preferences() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  /// A mentett boríték, vagy `null` (nincs mentés / olvashatatlan / régi verzió).
  Future<CacheEnvelope?> read(String key) async {
    final custom = _readOverride;
    try {
      final raw = custom != null
          ? await custom(key)
          : (await _preferences())?.getString(key);
      return decodeCacheEntry(raw);
    } catch (_) {
      return null;
    }
  }

  /// A tartalom mentése a mostani időbélyeggel.
  Future<void> write(String key, Object? payload) async {
    final encoded = encodeCacheEntry(payload, DateTime.now());
    final custom = _writeOverride;
    try {
      if (custom != null) {
        await custom(key, encoded);
        return;
      }
      await (await _preferences())?.setString(key, encoded);
    } catch (_) {
      // A mentés elmaradása nem hiba: legfeljebb lassabb lesz a következő nyitás.
    }
  }

  /// A mentés törlése (pl. kijelentkezéskor vagy ha a szerver mást mond).
  Future<void> remove(String key) async {
    final custom = _removeOverride;
    try {
      if (custom != null) {
        await custom(key);
        return;
      }
      await (await _preferences())?.remove(key);
    } catch (_) {}
  }
}

/// **Cache-first betöltés háttérfrissítéssel** — a `labelLibraryProvider` mintája,
/// de újrahasznosítható minden „menthető" adatra.
///
/// A működés:
/// 1. ha van mentés: **azonnal azt adja vissza** (nincs várakozás, nincs spinner),
///    és elindítja a háttérellenőrzést;
/// 2. ha nincs mentés: lekéri a hálózatról, és elmenti;
/// 3. a háttérellenőrzés **csak akkor** hívja a [refresh] callbacket, ha az adat
///    **tényleg változott** — így a felesleges újrarajzolás sem villogtat;
/// 4. ha a hálózat hibázik, a mentett érték **marad** (a [fetch] hibája a
///    háttérben elnyelődik; mentés nélkül viszont továbbra is dob).
///
/// A [isCancelled] azt jelzi, hogy a hívó (provider/képernyő) már nem él: ilyenkor
/// nem hívjuk a [refresh]-et, mert az egy megszűnt állapotot élesztene.
Future<T> readThroughCache<T>({
  required String cacheKey,
  required Future<T> Function() fetch,
  required Object? Function(T value) encode,
  required T Function(Object? payload) decode,
  required void Function() refresh,
  Duration ttl = const Duration(minutes: 10),
  AsyncCacheStore? store,
  bool Function()? isCancelled,
  DateTime Function()? now,
}) async {
  final cache = store ?? AsyncCacheStore.shared;
  final clock = now ?? DateTime.now;
  final envelope = await cache.read(cacheKey);
  if (envelope != null) {
    final stale = cacheIsStale(envelope.savedAt, clock(), ttl);
    unawaited(
      _revalidate<T>(
        cache: cache,
        cacheKey: cacheKey,
        fetch: fetch,
        encode: encode,
        refresh: refresh,
        ttl: ttl,
        previous: envelope,
        stale: stale,
        isCancelled: isCancelled,
        now: clock,
      ),
    );
    return decode(envelope.payload);
  }
  final fresh = await fetch();
  await cache.write(cacheKey, encode(fresh));
  return fresh;
}

Future<void> _revalidate<T>({
  required AsyncCacheStore cache,
  required String cacheKey,
  required Future<T> Function() fetch,
  required Object? Function(T value) encode,
  required void Function() refresh,
  required Duration ttl,
  required CacheEnvelope previous,
  required bool stale,
  bool Function()? isCancelled,
  required DateTime Function() now,
}) async {
  try {
    final fresh = await fetch();
    final payload = encode(fresh);
    final changed = cachePayloadChanged(previous.payload, payload);
    if (!changed && !stale) return;
    await cache.write(cacheKey, payload);
    if (changed && !(isCancelled?.call() ?? false)) refresh();
  } catch (_) {
    // A mentett érték marad; a következő megnyitás újrapróbálja.
  }
}
