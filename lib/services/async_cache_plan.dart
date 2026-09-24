/// A **cache-first** működés tiszta szabályai (mentett érték borítéka, elavulás,
/// változás-összehasonlítás).
///
/// **MIÉRT VAN EZ A MODUL:** a tulajdonos kérése: *„nem lenne jobb minden ilyen
/// adatot cacheben tárolni és a hátérben frissíteni? villogás nélkül persze"*.
/// A mintát a WordPress-réteg (`WordpressHeadCache`) és a `labelLibraryProvider`
/// már használja; ez a modul azt teszi **újrahasznosíthatóvá** a callable-alapú
/// adatokhoz is (claim-állapot, claimelt DJ-adatlapok, profil).
///
/// **A három szabály, amit minden cache-elt adatra betartunk:**
/// 1. **A mentett érték azonnal kimegy**, a hálózat csak a háttérben egyeztet —
///    ezért nincs villogás és nincs spinner, ha van mit mutatni.
/// 2. **Hiba esetén a mentett érték MARAD** (a régi adat jobb, mint a hiba-képernyő).
/// 3. **Csak akkor rajzolunk újra, ha az adat tényleg változott** — különben a
///    felesleges újrarajzolás is villogást okozna.
///
/// Ez a fájl **nem** függ a Fluttertől és a hálózattól: tiszta függvények, ezért
/// a `test/services/async_cache_plan_test.dart` valódi értékekkel méri őket.
library;

import 'dart:convert';

/// A boríték verziója. Ha a formátum valaha változik, a régi mentés **nem**
/// értelmeződik félre: a verzióeltérés egyszerűen „nincs mentés".
const int asyncCacheVersion = 1;

/// Egy mentett érték: mikor mentettük, és mi volt a tartalom.
class CacheEnvelope {
  const CacheEnvelope({required this.savedAt, required this.payload});

  /// Mikor került a mentés (a háttérellenőrzés ebből számolja az elavulást).
  final DateTime savedAt;

  /// A mentett tartalom (JSON-kompatibilis: Map / List / String / num / bool).
  final Object? payload;
}

/// A mentett érték **borítékba** csomagolása (verzió + időbélyeg + tartalom).
///
/// Az időbélyeg azért kell, mert a megjelenítés **mindig** a mentett értéket
/// adja, viszont a **háttérellenőrzést** nem futtatjuk minden megnyitásnál:
/// csak ha a mentés elavult (lásd [cacheIsStale]).
String encodeCacheEntry(Object? payload, DateTime savedAt) {
  return jsonEncode(<String, Object?>{
    'v': asyncCacheVersion,
    'at': savedAt.toUtc().toIso8601String(),
    'payload': payload,
  });
}

/// A boríték visszafejtése.
///
/// `null`, ha nincs mentés, ha sérült (kézzel módosított/levágott JSON), vagy ha
/// **más verziójú** — ilyenkor a hívó egyszerűen a hálózatra megy. Ez szándékos:
/// egy olvashatatlan mentés sosem akadályozhatja a betöltést.
CacheEnvelope? decodeCacheEntry(String? raw) {
  final value = raw?.trim() ?? '';
  if (value.isEmpty) return null;
  try {
    final decoded = jsonDecode(value);
    if (decoded is! Map) return null;
    if (decoded['v'] != asyncCacheVersion) return null;
    final savedAt = DateTime.tryParse(decoded['at']?.toString() ?? '');
    if (savedAt == null) return null;
    return CacheEnvelope(savedAt: savedAt.toLocal(), payload: decoded['payload']);
  } catch (_) {
    return null;
  }
}

/// Elavult-e a mentés? (Ekkor kell a háttérben egyeztetni.)
///
/// ⚠️ Ez **nem** azt jelenti, hogy a mentett értéket ne mutatnánk: a megjelenítés
/// mindig a mentett értéket adja, akármilyen régi — csak az egyeztetést gátolja.
bool cacheIsStale(DateTime savedAt, DateTime now, Duration ttl) {
  final age = now.difference(savedAt);
  return age >= ttl;
}

/// Megváltozott-e a tartalom? (Ha nem, nem rajzolunk újra.)
///
/// A JSON-alakú összehasonlítás szándékos: a mentett tartalom is JSON, ezért a
/// sorrend és a számábrázolás ugyanúgy viselkedik, mint a mentésnél.
bool cachePayloadChanged(Object? previous, Object? next) {
  if (identical(previous, next)) return false;
  return jsonEncode(previous) != jsonEncode(next);
}
