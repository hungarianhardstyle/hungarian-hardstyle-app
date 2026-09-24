import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/prize.dart';

/// Helyi emlékezet: „erre a fiókra ebben a kérdőívben már szavaztunk", „ebben a
/// játékban már játszottunk", illetve „ebben a nyereményjátékban már játszottunk".
///
/// **A tulajdonos jelzése:** *„Kvíznél elsőre kicsit sokára tölti be, hogy már
/// játszottam"*, *„Kérdőívnél elsőre picit sokára tölti be, hogy már
/// kitöltöttem"*, illetve (2026-09-20) *„kviznél lassan frissül, hogy már
/// kitöltötte, pár másodpercig úgy jelzi mintha tudna még játszani"*.
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
/// **A kvíz sokáig kimaradt:** a kérdőív és a nyereményjáték megkapta ezt az
/// emlékezetet, a **kvíz viszont nem** — ezért ott továbbra is látszott a
/// „játszható" állapot néhány másodpercig (a `GameScreen` csak a szervert
/// kérdezte). Mostantól a kvíz is ugyanezt használja (`isGamePlayed`).
///
/// **A MÁSODIK KÖR — a másodpercek eltüntetése (2026-09-24, a tulajdonos
/// jelzése):** *„a kviz is írhatná, hogy már játszottál, a jelenlegi azt mutatja,
/// hogy tudnál játszani és kell pár másodperc mire beáll"*. A gyökér az volt,
/// hogy az emlékezet olvasása **aszinkron** (`SharedPreferences.getInstance()`)
/// és a `GameScreen` az **auth-állapot első jelzésére** is várt, mielőtt
/// bármit is kérdezett — a kvíz kártyája pedig **egyáltalán nem** kérdezte az
/// emlékezetet. Ezért mostantól:
/// 1. **memóriabeli tükör** van (`preload()` az app indításakor egyszer
///    beolvassa az összes kulcsot), így a `isGamePlayedSync` **szinkron**,
///    lemez- és hálózatmentes — a képernyő már az első képkockán a helyes
///    állapotot rajzolja;
/// 2. az írások **értesítést adnak** (`revision`), ezért a kvíz kártyája
///    („Már játszottál") beküldés után **magától** frissül;
/// 3. a szerver továbbra is **a hiteles forrás**: ha az emlékezet téved,
///    a jelzés törlődik.
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
  static const String _gamePrefix = 'huhs.played.game';

  /// A **memóriabeli tükör**: ebből olvas a szinkron (azonnali) út.
  static final Map<String, bool> _boolCache = <String, bool>{};
  static final Map<String, String> _stringCache = <String, String>{};
  static bool _loaded = false;

  /// Minden írás után nő — a felület ebből tudja, hogy az emlékezet változott.
  ///
  /// (A kvíz kártyája így **magától** vált „Már játszottál"-ra a beküldés után,
  /// anélkül hogy a szülő képernyőnek újra kellene épülnie.)
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  /// Igaz, ha a memóriabeli tükör már be van töltve (`preload()`).
  static bool get isLoaded => _loaded;

  /// Egyszeri betöltés az app indításakor.
  ///
  /// Utána a `isGamePlayedSync` / `isPollVotedSync` / `prizePlaySync`
  /// **lemezolvasás nélkül** válaszol, ezért a képernyő már az első képkockán
  /// a helyes állapotot mutatja. Hiba esetén csendben kimarad: az aszinkron
  /// utak ettől függetlenül működnek.
  static Future<void> preload() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in prefs.getKeys()) {
        if (_isRememberedBoolKey(key)) {
          if (prefs.getBool(key) == true) _boolCache[key] = true;
        } else if (key.startsWith(_prizePrefix)) {
          final raw = prefs.getString(key);
          if (raw != null && raw.isNotEmpty) _stringCache[key] = raw;
        }
      }
      _loaded = true;
    } catch (_) {
      // Best-effort: a lassabb (aszinkron) út ilyenkor is helyes marad.
    }
  }

  /// Teszt-segéd: a statikus tükör visszaállítása a következő esethez.
  @visibleForTesting
  static void resetForTests() {
    _boolCache.clear();
    _stringCache.clear();
    _loaded = false;
  }

  static bool _isRememberedBoolKey(String key) =>
      key.startsWith(_pollPrefix) || key.startsWith(_gamePrefix);

  static String _key(String prefix, String uid, int id) => '$prefix.$uid.$id';

  static String? _normalizedUid(String? uid) {
    final value = uid?.trim() ?? '';
    return value.isEmpty ? null : value;
  }

  /// Igaz, ha erre a fiókra ebben a kérdőívben már szavaztunk.
  ///
  /// A memóriabeli tükörből **azonnal** válaszol, ha tudja; egyébként a lemezről.
  static Future<bool> isPollVoted(String? uid, int pollId) async {
    final key = _uidKey(uid, pollId, _pollPrefix);
    if (key == null) return false;
    if (_boolCache[key] == true) return true;
    return _readRememberedBool(key);
  }

  /// A **szinkron** (azonnali) válasz: igaz, ha a memóriabeli tükör szerint már
  /// szavaztál. Ha még nem tudjuk (`preload()` előtt), `false` — a hívó ilyenkor
  /// várhat az aszinkron útra.
  static bool isPollVotedSync(String? uid, int pollId) {
    final key = _uidKey(uid, pollId, _pollPrefix);
    return key != null && _boolCache[key] == true;
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
    _rememberBool(key);
  }

  /// A jelzés törlése — akkor kell, ha a szerver azt mondja, mégsem szavaztál.
  ///
  /// ⚠️ **A memóriabeli tükör ELŐBB törlődik, mint a lemez**: ha fordítva lenne,
  /// egy mikrotasknyi ablakban még a régi (téves) „már szavaztál" látszana, és
  /// egy éppen induló újraszámolás azt olvasná ki.
  static Future<void> clearPollVoted(String? uid, int pollId) async {
    final key = _uidKey(uid, pollId, _pollPrefix);
    if (key == null) return;
    _forgetKey(key);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } catch (_) {}
  }

  /// Igaz, ha erre a fiókra ebben a **kvízben** már játszottunk.
  ///
  /// Ebből lesz azonnal „Már játszottál" a képernyőn, amíg a szerver
  /// (app → Cloud Function → WordPress) meg nem erősíti — enélkül néhány
  /// másodpercig úgy látszott, mintha újra lehetne játszani.
  static Future<bool> isGamePlayed(String? uid, int gameId) async {
    final key = _uidKey(uid, gameId, _gamePrefix);
    if (key == null) return false;
    if (_boolCache[key] == true) return true;
    return _readRememberedBool(key);
  }

  /// A **szinkron** (azonnali) válasz a kvíz kártyájához és a képernyő első
  /// képkockájához: igaz, ha a memóriabeli tükör szerint már játszottál.
  ///
  /// Csak `true`-t mond, ha **biztos** — bizonytalan esetben `false`, és ilyenkor
  /// a szerver (vagy az aszinkron út) dönt. Ez azért fontos, mert egy téves
  /// „már játszottál" elrejtené a kvízt egy olyan fióknál, aki még nem játszott.
  static bool isGamePlayedSync(String? uid, int gameId) {
    final key = _uidKey(uid, gameId, _gamePrefix);
    return key != null && _boolCache[key] == true;
  }

  /// A kvízjáték tényének megjegyzése (a szerver igazolása, vagy az épp most
  /// sikeresen beküldött válaszok után).
  static Future<void> markGamePlayed(String? uid, int gameId) async {
    final key = _uidKey(uid, gameId, _gamePrefix);
    if (key == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, true);
    } catch (_) {
      // A helyi emlékezet kiesése nem hiba: legfeljebb lassabb lesz a kijelzés.
    }
    _rememberBool(key);
  }

  /// A jelzés törlése — ha a szerver azt mondja, mégsem játszottál (pl. az
  /// admin újranyitotta a kvízt).
  ///
  /// A memóriabeli tükör **előbb** törlődik (lásd a `clearPollVoted` magyarázatát).
  static Future<void> clearGamePlayed(String? uid, int gameId) async {
    final key = _uidKey(uid, gameId, _gamePrefix);
    if (key == null) return;
    _forgetKey(key);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } catch (_) {}
  }

  /// A megjegyzett játékeredmény, vagy null, ha nincs.
  static Future<HuhsPrizePlay?> prizePlay(String? uid, int prizeId) async {
    final key = _uidKey(uid, prizeId, _prizePrefix);
    if (key == null) return null;
    final cached = _decodePrizePlay(key);
    if (cached != null) return cached;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return null;
      _stringCache[key] = raw;
      return _decodePrizePlay(key);
    } catch (_) {
      return null;
    }
  }

  /// A **szinkron** (azonnali) válasz a nyereményjáték kártyájához.
  static HuhsPrizePlay? prizePlaySync(String? uid, int prizeId) {
    final key = _uidKey(uid, prizeId, _prizePrefix);
    return key == null ? null : _decodePrizePlay(key);
  }

  /// A játék eredményének megjegyzése. **A `correct` és a választott index is
  /// tárolódik**, különben a visszatérő felhasználó egy pillanatra rossz
  /// ítéletet látna (a „helyes volt / nem talált" szöveg a saját eredménye).
  static Future<void> markPrizePlayed(String? uid, int prizeId, HuhsPrizePlay play) async {
    final key = _uidKey(uid, prizeId, _prizePrefix);
    if (key == null || !play.played) return;
    final encoded = jsonEncode(<String, dynamic>{
      'played': true,
      'correct': play.correct,
      'answerIndex': play.answerIndex,
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, encoded);
    } catch (_) {}
    _stringCache[key] = encoded;
    revision.value += 1;
  }

  static Future<void> clearPrizePlayed(String? uid, int prizeId) async {
    final key = _uidKey(uid, prizeId, _prizePrefix);
    if (key == null) return;
    _forgetKey(key);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } catch (_) {}
  }

  /// A memóriabeli tükör frissítése írás után (és értesítés a felületnek).
  static void _rememberBool(String key) {
    _boolCache[key] = true;
    revision.value += 1;
  }

  static void _forgetKey(String key) {
    final changed = _boolCache.remove(key) != null || _stringCache.remove(key) != null;
    if (changed) revision.value += 1;
  }

  static Future<bool> _readRememberedBool(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getBool(key) == true;
      if (value) _boolCache[key] = true;
      return value;
    } catch (_) {
      return false;
    }
  }

  static HuhsPrizePlay? _decodePrizePlay(String key) {
    final raw = _stringCache[key];
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return HuhsPrizePlay.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  static String? _uidKey(String? uid, int id, String prefix) {
    final normalized = _normalizedUid(uid);
    if (normalized == null || id < 1) return null;
    return _key(prefix, normalized, id);
  }
}
