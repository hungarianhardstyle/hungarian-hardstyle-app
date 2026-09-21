import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// A **nyilvános listáról eltűnt** kiadványok emlékezete.
///
/// MIÉRT KELL: a „Megvásárolt zenéim" lista a nyilvános katalógusból ismeri a
/// címeket, de egy kiadványt időközben **törölhetnek/elrejthetnek** — ilyenkor a
/// képernyő egyenként lekérdezi (`getRelease`), és a WordPress **0,4–2 másodperc**
/// alatt válaszol (mért érték). Enélkül a feloldott, de már nem létező kiadvány
/// (a tulajdonos esetében a `#12327`) **minden megnyitáskor** újra lefutna, és a
/// kártya addig „Kiadvány betöltése…" állapotban maradna.
///
/// HÁROM SZÁNDÉKOS SZABÁLY:
///  1. **Nem tippelünk örökre:** a jelölés **24 óra** után lejár, ezért ha a
///     kiadványt újra közzéteszik, legkésőbb egy nap múlva megint megjelenik
///     címmel (és ha közben mégis megvan, a sikeres lekérdezés azonnal törli).
///  2. **A hibás bejegyzést eldobjuk** (nem „nem elérhető" lesz belőle): egy
///     olvashatatlan tároló nem tehet tönkre egy kiadványt.
///  3. **Nem fiókhoz kötött**, mert a nyilvános katalógus mindenkinek ugyanaz —
///     viszont **nem tartalmaz semmit a felhasználóról**, csak kiadvány-azonosítót
///     és időpontot.
class LabelReleaseAvailability {
  LabelReleaseAvailability({Future<SharedPreferences> Function()? preferences})
    : _preferencesOverride = preferences;

  final Future<SharedPreferences> Function()? _preferencesOverride;

  static const _key = 'huhs.release.missing';

  /// Ennyi ideig nem kérdezzük újra azt, amiről kiderült, hogy nincs meg.
  static const ttl = Duration(hours: 24);

  Future<SharedPreferences> _preferences() {
    final override = _preferencesOverride;
    if (override != null) return override();
    return SharedPreferences.getInstance();
  }

  /// A **még érvényes** jelölések (a lejártakat közben ki is dobja).
  Future<Set<int>> loadMissing() async {
    final preferences = await _preferences();
    final payload = preferences.getString(_key);
    if (payload == null) return <int>{};
    List<dynamic> raw;
    try {
      final decoded = jsonDecode(payload);
      raw = decoded is List ? decoded : const [];
    } catch (_) {
      await preferences.remove(_key);
      return <int>{};
    }
    final active = activeMissingIds(
      raw,
      nowMs: DateTime.now().millisecondsSinceEpoch,
      ttlMs: ttl.inMilliseconds,
    );
    // Ha lejárt/eldobható bejegyzés volt, a tárolót is tisztára írjuk.
    if (active.length != raw.length) {
      await _write(preferences, active);
    }
    return active.toSet();
  }

  Future<void> markMissing(int releaseId) async {
    if (releaseId < 1) return;
    final preferences = await _preferences();
    final raw = _decodeRaw(preferences);
    final active = activeMissingIds(
      raw,
      nowMs: DateTime.now().millisecondsSinceEpoch,
      ttlMs: ttl.inMilliseconds,
    );
    if (active.contains(releaseId)) return;
    await _write(preferences, [...active, releaseId]);
  }

  Future<void> clear(int releaseId) async {
    final preferences = await _preferences();
    final raw = _decodeRaw(preferences);
    final active = activeMissingIds(
      raw,
      nowMs: DateTime.now().millisecondsSinceEpoch,
      ttlMs: ttl.inMilliseconds,
    );
    if (!active.contains(releaseId)) return;
    await _write(preferences, [
      for (final id in active)
        if (id != releaseId) id,
    ]);
  }

  List<dynamic> _decodeRaw(SharedPreferences preferences) {
    final payload = preferences.getString(_key);
    if (payload == null) return const [];
    try {
      final decoded = jsonDecode(payload);
      return decoded is List ? decoded : const [];
    } catch (_) {
      return const [];
    }
  }

  Future<void> _write(SharedPreferences preferences, List<int> ids) async {
    if (ids.isEmpty) {
      await preferences.remove(_key);
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    await preferences.setString(
      _key,
      jsonEncode([
        for (final id in ids) {'id': id, 'at': now},
      ]),
    );
  }
}

/// A **még érvényes** kiadvány-azonosítók a tárolt nyers listából.
///
/// Tiszta függvény, hogy a lejárat és a hibás bejegyzések kezelése mérhető
/// legyen: érvénytelen sor (`id` nem pozitív egész, hiányzó/olvashatatlan
/// időpont) **kimarad**, és a [ttlMs]-nél régebbi jelölés is.
List<int> activeMissingIds(
  List<dynamic> raw, {
  required int nowMs,
  required int ttlMs,
}) {
  final active = <int>[];
  for (final entry in raw) {
    if (entry is! Map) continue;
    final id = entry['id'];
    final at = entry['at'];
    if (id is! int || id < 1) continue;
    if (at is! int || at <= 0) continue;
    if (nowMs - at > ttlMs) continue;
    if (!active.contains(id)) active.add(id);
  }
  return active;
}
