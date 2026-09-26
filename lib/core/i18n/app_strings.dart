import 'dart:convert';

import 'app_language.dart';

/// A felület angol szótára — **a magyar szöveg a kulcs**, az angol az érték.
///
/// MIÉRT ÍGY (és nem ARB/`AppLocalizations`): a kód 180 fájlban ~1 800 magyar
/// literált használ, tiszta `const` widgetekben. Az ARB-refactor minden érintett
/// fájlt átírt volna (és a `const`-okat is), miközben a kívánt viselkedés ennél
/// egyszerűbb: **ha van angol, azt adja; ha nincs, marad a magyar**. A magyar
/// szöveg a kulcs, ezért egy hiányzó fordítás sosem ad üres feliratot.
///
/// A szótár (`assets/i18n/en.json`) fordítás közben bővül; a `tools/check-i18n.mjs`
/// méri a lefedettséget, a `test/services/i18n_wiring_test.dart` pedig őrzi, hogy
/// a fordítás ne csússzon a felhasználói tartalomra.
class AppStrings {
  AppStrings._();

  static const String dictionaryAsset = 'assets/i18n/en.json';

  static AppLanguage _language = AppLanguage.hu;
  static Map<String, String> _english = const <String, String>{};

  /// Az aktuális nyelv.
  static AppLanguage get language => _language;

  /// Igaz, ha éppen angolul rajzolunk.
  static bool get isEnglish => _language == AppLanguage.en;

  /// A betöltött szótár (csak olvasásra).
  static Map<String, String> get english => _english;

  /// Hány fordítás van betöltve (a lefedettség-méréshez és a tesztekhez).
  static int get dictionarySize => _english.length;

  static void setLanguage(AppLanguage language) {
    _language = language;
  }

  /// A szótár beállítása. Csak a **nem üres, string** értékek maradnak meg,
  /// ezért egy félkész fordítás nem tud üres feliratot okozni.
  static void setEnglish(Map<String, String>? dictionary) {
    _english = parseEnglishDictionary(dictionary);
  }

  /// A felirat: angol módban az angol szöveg, minden más esetben a magyar.
  ///
  /// ⚠️ **MÉRT HIBAOSZTÁLY (2026-09-26):** a `parseEnglishDictionary()` a
  /// szótár **kulcsait `trim()`-eli**, ezért egy „ szóközzel körbevett " kulcsot
  /// a `tr(' szóközzel körbevett ')` hívás **soha nem talált meg** — a fordítás
  /// létezett, de **elérhetetlen** volt, és angol módban magyarul maradt.
  /// Mérve: a szótár **15** ilyen kulcsa közül **mind a 15** fordítás-hívásban
  /// áll (pl. a chat/hozzászólás „… hozzászólására: " előtagja, az adatvédelmi
  /// képernyő mondatai, a „Unknown User "). Ezért a keresés **trim-elt
  /// tartalékkal** is megy: először a pontos kulcs, aztán a vágott alak (a
  /// szótárban nincs ütközés — mérve).
  static String tr(String hungarian) {
    if (_language != AppLanguage.en) return hungarian;
    // Először a pontos kulcs, aztán a vágott alak (a szótár kulcsai ugyanis
    // vágva vannak — lásd a fejlécet; mérve nincs ütközés).
    final translated = _english[hungarian] ?? _english[hungarian.trim()];
    if (translated == null) return hungarian;
    final trimmed = translated.trim();
    return trimmed.isEmpty ? hungarian : translated;
  }

  /// Fordítás **behelyettesítéssel**: `trArgs('{n} nap', {'n': '3'})`.
  ///
  /// A `tr()` csak statikus szövegekre való; a változót tartalmazó feliratoknál
  /// ez a helyes út, mert a szótárban a `{név}` helyőrző szerepel.
  static String trArgs(String hungarian, Map<String, String> values) {
    var result = tr(hungarian);
    values.forEach((key, value) {
      result = result.replaceAll('{$key}', value);
    });
    return result;
  }

  /// Nyers JSON szövegből szótár (hibás JSON esetén üres — sosem dob).
  static Map<String, String> decodeDictionary(String jsonText) {
    try {
      final decoded = jsonDecode(jsonText);
      if (decoded is! Map) return const <String, String>{};
      return parseEnglishDictionary(
        decoded.map((key, value) => MapEntry('$key', '$value')),
      );
    } catch (_) {
      return const <String, String>{};
    }
  }

  /// Szótár-tisztítás: csak a nem üres string értékek maradnak meg.
  static Map<String, String> parseEnglishDictionary(Map<String, String>? raw) {
    if (raw == null || raw.isEmpty) return const <String, String>{};
    final cleaned = <String, String>{};
    raw.forEach((key, value) {
      final k = key.trim();
      final v = value;
      if (k.isEmpty || v.trim().isEmpty) return;
      cleaned[k] = v;
    });
    return Map<String, String>.unmodifiable(cleaned);
  }
}
