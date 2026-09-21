import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// A **lejátszási listáról kivett** tételek emlékezete — **fiókonként**.
///
/// A tulajdonos kérése: *„zenét hogy tud a playlistre rakni/levenni"* — vagyis
/// egy letöltött tétel **kivehető** legyen a lejátszási listából anélkül, hogy a
/// fájl törlődne (és bármikor **vissza** is tehető legyen).
///
/// MIÉRT a **kivett** tételeket tároljuk, és nem a benne lévőket: így az
/// alapállapot változatlan (minden letöltött tétel a listán van), és egy későbbi
/// vásárlás/letöltés **automatikusan** bekerül — nem kell „felvenni".
///
/// HÁROM SZÁNDÉKOS SZABÁLY:
///  1. **Az UID a kulcs része** (`huhs.music.excluded.<uid>`), ezért **másik fiók
///     nem örökli** a másik listáját (ugyanaz az adatvédelmi szabály, mint a
///     folytatási pontnál és a szavazat-emlékezetnél).
///  2. **Vendégként nem írunk és nem olvasunk.**
///  3. **A hibás bejegyzés nem tesz tönkre semmit**: olvashatatlan tárolónál üres
///     halmaz (minden a listán marad), és a hibás kulcsot töröljük.
class LabelPlaylistMembership {
  LabelPlaylistMembership({Future<SharedPreferences> Function()? preferences})
    : _preferencesOverride = preferences;

  final Future<SharedPreferences> Function()? _preferencesOverride;

  static const _prefix = 'huhs.music.excluded';
  static const _orderPrefix = 'huhs.music.order';

  Future<SharedPreferences> _preferences() {
    final override = _preferencesOverride;
    if (override != null) return override();
    return SharedPreferences.getInstance();
  }

  /// A kulcs a **fiókhoz** kötött; üres UID-nál `null` (vendég).
  String? keyFor(String uid) {
    final trimmed = uid.trim();
    if (trimmed.isEmpty) return null;
    return '$_prefix.$trimmed';
  }

  /// A **sorrend** kulcsa — szándékosan külön a kivétel kulcsától.
  ///
  /// ⚠️ NEM a [keyFor] eredményéből épül (az már tartalmazza a `excluded`
  /// előtagot, így dupla prefix lett volna belőle — ezt a teszt fogta meg).
  String? orderKeyFor(String uid) {
    final trimmed = uid.trim();
    if (trimmed.isEmpty) return null;
    return '$_orderPrefix.$trimmed';
  }

  /// A listáról **kivett** tételek (`kiadvány:változat`).
  Future<Set<String>> load(String uid) async {
    final key = keyFor(uid);
    if (key == null) return <String>{};
    final preferences = await _preferences();
    final payload = preferences.getString(key);
    if (payload == null) return <String>{};
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! List) {
        await preferences.remove(key);
        return <String>{};
      }
      return sanitizeExcludedKeys(decoded);
    } catch (_) {
      await preferences.remove(key);
      return <String>{};
    }
  }

  Future<void> save(String uid, Set<String> keys) async {
    final key = keyFor(uid);
    if (key == null) return;
    final preferences = await _preferences();
    final clean = sanitizeExcludedKeys(keys.toList());
    if (clean.isEmpty) {
      await preferences.remove(key);
      return;
    }
    await preferences.setString(key, jsonEncode(clean.toList()..sort()));
  }

  /// A lista **kézi sorrendje** (`kiadvány:változat` kulcsok sorrendben).
  ///
  /// A tulajdonos kérése: *„lehet szerkeszteni a playlistet?"* — a fel/le
  /// mozgatás eredménye itt marad meg, fiókonként.
  Future<List<String>> loadOrder(String uid) async {
    final key = orderKeyFor(uid);
    if (key == null) return const [];
    final preferences = await _preferences();
    final payload = preferences.getString(key);
    if (payload == null) return const [];
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! List) {
        await preferences.remove(key);
        return const [];
      }
      return sanitizeOrderKeys(decoded);
    } catch (_) {
      await preferences.remove(key);
      return const [];
    }
  }

  Future<void> saveOrder(String uid, List<String> order) async {
    final key = orderKeyFor(uid);
    if (key == null) return;
    final preferences = await _preferences();
    final clean = sanitizeOrderKeys(order);
    if (clean.isEmpty) {
      await preferences.remove(key);
      return;
    }
    await preferences.setString(key, jsonEncode(clean));
  }
}

/// A mentett **sorrend** tisztítása: csak az értelmes `kiadvány:változat` kulcsok
/// maradnak, **sorrendben**, duplikáció nélkül (az első előfordulás számít).
///
/// Tiszta függvény, hogy a szűrés önmagában mérhető legyen.
List<String> sanitizeOrderKeys(Iterable<dynamic> raw) {
  final order = <String>[];
  final seen = <String>{};
  for (final value in sanitizeExcludedKeys(raw)) {
    if (seen.add(value)) order.add(value);
  }
  return order;
}

/// A tárolt/bemenő értékek tisztítása: csak a **`kiadvány:változat`** alakú,
/// értelmes kulcsok maradnak (a szemét nem kerülhet a listába).
///
/// Tiszta függvény, hogy a szűrés önmagában mérhető legyen.
Set<String> sanitizeExcludedKeys(Iterable<dynamic> raw) {
  final clean = <String>{};
  for (final value in raw) {
    if (value is! String) continue;
    final trimmed = value.trim();
    final parts = trimmed.split(':');
    if (parts.length != 2) continue;
    final releaseId = int.tryParse(parts[0]);
    if (releaseId == null || releaseId < 1) continue;
    if (parts[1].isEmpty) continue;
    clean.add('$releaseId:${parts[1]}');
  }
  return clean;
}
