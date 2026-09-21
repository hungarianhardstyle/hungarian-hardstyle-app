import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// A „folytatás ott, ahol abbahagytad" emlékezete — **fiókonként**.
///
/// A tulajdonos kérése: *„folytatás ott, ahol abbahagytad"* — egy 50–100 MB-os
/// WAV-nál ez sokat számít, mert különben minden megnyitáskor az elejéről kell
/// keresni a helyet.
///
/// HÁROM SZÁNDÉKOS SZABÁLY:
///  1. **Az UID a kulcs része** (`huhs.music.last.<uid>`), ezért **másik fiók nem
///     örökli** a másik zenehallgatási helyét — ugyanaz a szabály, mint a
///     szavazat-emlékezetnél (`vote_memory.dart`). Ez adatvédelem: a
///     zenehallgatás is személyes adat.
///  2. **Vendégként (nincs bejelentkezés) nem írunk és nem olvasunk** — a
///     megvásárolt zene eleve bejelentkezéshez kötött.
///  3. **A hibát nem dobjuk tovább**: egy olvashatatlan/elavult bejegyzés nem
///     akadályozhatja a lejátszást, ezért ilyenkor `null` a válasz (és a hibás
///     bejegyzést töröljük).
class LabelPlaybackMemory {
  LabelPlaybackMemory({Future<SharedPreferences> Function()? preferences})
    : _preferencesOverride = preferences;

  /// Tesztben felülírható (ugyanaz a minta, mint a `VoteMemory`-nél).
  final Future<SharedPreferences> Function()? _preferencesOverride;

  static const _prefix = 'huhs.music.last';

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

  Future<LabelPlaybackPoint?> load(String uid) async {
    final key = keyFor(uid);
    if (key == null) return null;
    final preferences = await _preferences();
    final payload = preferences.getString(key);
    if (payload == null) return null;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) {
        await preferences.remove(key);
        return null;
      }
      final point = LabelPlaybackPoint.fromJson(
        decoded.map((key, value) => MapEntry('$key', value)),
      );
      if (point == null) {
        await preferences.remove(key);
        return null;
      }
      return point;
    } catch (_) {
      await preferences.remove(key);
      return null;
    }
  }

  Future<void> save(String uid, LabelPlaybackPoint point) async {
    final key = keyFor(uid);
    if (key == null) return;
    final preferences = await _preferences();
    await preferences.setString(key, jsonEncode(point.toJson()));
  }

  Future<void> clear(String uid) async {
    final key = keyFor(uid);
    if (key == null) return;
    final preferences = await _preferences();
    await preferences.remove(key);
  }
}

/// Egy elmentett lejátszási pont: melyik tétel és hol tartott.
class LabelPlaybackPoint {
  const LabelPlaybackPoint({
    required this.releaseId,
    required this.variant,
    required this.positionMs,
  });

  final int releaseId;
  final String variant;
  final int positionMs;

  /// A lejátszási sor azonosítója (`kiadvány:változat`) — ezzel találjuk meg a
  /// tételt a sorban. Ez ugyanaz a kulcs, amit a letöltés-kezelő használ.
  String get entryKey => '$releaseId:$variant';

  Map<String, Object?> toJson() => {
    'releaseId': releaseId,
    'variant': variant,
    'positionMs': positionMs,
  };

  /// Beolvasás; érvénytelen adatnál `null` (nem tippelünk).
  static LabelPlaybackPoint? fromJson(Map<String, dynamic> json) {
    final releaseId = json['releaseId'];
    final variant = json['variant'];
    final position = json['positionMs'];
    if (releaseId is! int || releaseId < 1) return null;
    if (variant is! String || variant.trim().isEmpty) return null;
    final positionMs = position is int
        ? position
        : position is num
        ? position.toInt()
        : 0;
    return LabelPlaybackPoint(
      releaseId: releaseId,
      variant: variant.trim(),
      positionMs: positionMs < 0 ? 0 : positionMs,
    );
  }
}
