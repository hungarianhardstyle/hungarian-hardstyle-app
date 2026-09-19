import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/prize.dart';

/// Helyi emlékezet: „erre a fiókra ebben a kérdőívben már szavaztunk", illetve
/// „ebben a játékban már játszottunk".
///
/// **A tulajdonos jelzése:** *„Kvíznél elsőre kicsit sokára tölti be, hogy már
/// játszottam"*, illetve *„Kérdőívnél elsőre picit sokára tölti be, hogy már
/// kitöltöttem"*.
///
/// **A gyökér:** ez az állapot csak egy három lépcsős út végén derül ki
/// (app → Cloud Function → WordPress), első hívásnál a függvény hidegen is indul.
/// A felület pedig — szándékosan — addig **nem** mutat válaszlehetőségeket, amíg
/// a szerver nem mondja ki, hogy nem szavaztál/játszottál. Ezért a várakozás
/// látszott.
///
/// **A megoldás:** a legutóbbi ismert állapotot a telefon megjegyzi, így az
/// **azonnal** megjelenik, a szerver válaszát pedig a háttérben ellenőrizzük
/// (lásd a providereket). Ha a szerver azt mondja, mégsem szavaztál, akkor a
/// jelzést töröljük és a felület visszavált.
///
/// **Két szándékos szabály:**
/// 1. **Csak `true`-t („már megtörtént") mentünk.** Hamis állapotot soha, mert
///    az a szavazólapot rejthetné el egy olyan fióknál, aki még nem szavazott.
/// 2. **A kulcs tartalmazza a UID-t**, ezért egy másik fiók bejelentkezése nem
///    örökli az előző emlékét. (UID nélkül — vendégként — nem is írunk.)
class VoteMemory {
  const VoteMemory._();

  static const String _pollPrefix = 'huhs.voted.poll';
  static const String _prizePrefix = 'huhs.played.prize';

  static String _key(String prefix, String uid, int id) => '$prefix.$uid.$id';

  static String? _normalizedUid(String? uid) {
    final value = uid?.trim() ?? '';
    return value.isEmpty ? null : value;
  }

  /// Igaz, ha erre a fiókra ebben a kérdőívben már szavaztunk.
  static Future<bool> isPollVoted(String? uid, int pollId) async {
    final key = _uidKey(uid, pollId, _pollPrefix);
    if (key == null) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(key) == true;
    } catch (_) {
      return false;
    }
  }

  /// A szavazat tényének megjegyzése (a szerver igazolása, vagy az épp most
  /// sikeresen leadott szavazat után).
  static Future<void> markPollVoted(String? uid, int pollId) async {
    final key = _uidKey(uid, pollId, _pollPrefix);
    if (key == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, true);
    } catch (_) {
      // A helyi emlékezet kiesése nem hiba: legfeljebb lassabb lesz a kijelzés.
    }
  }

  /// A jelzés törlése — akkor kell, ha a szerver azt mondja, mégsem szavaztál.
  static Future<void> clearPollVoted(String? uid, int pollId) async {
    final key = _uidKey(uid, pollId, _pollPrefix);
    if (key == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } catch (_) {}
  }

  /// A megjegyzett játékeredmény, vagy null, ha nincs.
  static Future<HuhsPrizePlay?> prizePlay(String? uid, int prizeId) async {
    final key = _uidKey(uid, prizeId, _prizePrefix);
    if (key == null) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return HuhsPrizePlay.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  /// A játék eredményének megjegyzése. **A `correct` és a választott index is
  /// tárolódik**, különben a visszatérő felhasználó egy pillanatra rossz
  /// ítéletet látna (a „helyes volt / nem talált" szöveg a saját eredménye).
  static Future<void> markPrizePlayed(String? uid, int prizeId, HuhsPrizePlay play) async {
    final key = _uidKey(uid, prizeId, _prizePrefix);
    if (key == null || !play.played) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        key,
        jsonEncode(<String, dynamic>{
          'played': true,
          'correct': play.correct,
          'answerIndex': play.answerIndex,
        }),
      );
    } catch (_) {}
  }

  static Future<void> clearPrizePlayed(String? uid, int prizeId) async {
    final key = _uidKey(uid, prizeId, _prizePrefix);
    if (key == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } catch (_) {}
  }

  static String? _uidKey(String? uid, int id, String prefix) {
    final normalized = _normalizedUid(uid);
    if (normalized == null || id < 1) return null;
    return _key(prefix, normalized, id);
  }
}
