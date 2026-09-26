import 'dart:convert';

import 'app_language.dart';
import 'app_strings.dart';

/// Egy értesítés megjelenítendő szövege.
class NotificationText {
  const NotificationText({required this.title, required this.body});

  final String title;
  final String body;
}

/// Az **értesítés-szövegek nyelvi katalógusa** + a megjelenítéskori fordítás.
///
/// **MIÉRT KELL (a tulajdonos jelzése, 2026-09-26):** *„a notifyok még mindig
/// magyarul vannak az angol felületen vagy lassan áll át"* → *„nagyon lassan"*.
///
/// **A MÉRT GYÖKÉR:** a szerver az értesítés szövegét a **létrehozáskor**
/// rendereli a címzett akkori nyelvén (`functions/index.js` →
/// `createNotification` → `recipientLanguage`), és a Firestore-ba **kész
/// szöveget** ír (`title`/`body`). Ezért nyelvváltás után a **régi** sorok a régi
/// nyelven maradnak, és csak az **új** értesítések jönnek az új nyelven — ez a
/// „nagyon lassú átállás". Az app a tárolt szöveget **nyersen** írta ki
/// (`Text(item.body)`).
///
/// **A MEGOLDÁS:** a megjelenítés helyén fordítunk. A tárolt szöveg ugyanis a
/// katalógus **egyik nyelvű sablonjából** készült — ha a másik nyelv sablonjára
/// illeszkedik, abból kinyerjük a helyőrzőket, és a **mostani** nyelven újra
/// kitöltjük. Így a váltás **azonnal** látszik, és a **régi** értesítésekre is
/// működik (nincs szükség szerveroldali változásra vagy adat-átíráshoz).
///
/// A katalógus **egy forrásból** származik: a szerveroldali
/// `functions/notification-texts.js`-ből generálja a
/// `tools/generate-notification-texts.mjs` (a `--check` kapu az elcsúszást
/// jelzi).
class NotificationTexts {
  /// Az app-oldali katalógus (a szerveroldaliból generálva).
  static const String asset = 'assets/i18n/notification_texts.json';

  static Map<String, dynamic> _catalog = const <String, dynamic>{};

  /// Be van-e töltve a katalógus? (Ha nem, minden szöveg változatlanul megy ki.)
  static bool get isLoaded => _catalog.isNotEmpty;

  /// A katalógus beállítása nyers JSON-ból (hibás JSON esetén üres — sosem dob).
  static void setCatalogFromJson(String jsonText) {
    try {
      final decoded = jsonDecode(jsonText);
      setCatalog(decoded is Map<String, dynamic> ? decoded : null);
    } catch (_) {
      setCatalog(null);
    }
  }

  static void setCatalog(Map<String, dynamic>? catalog) {
    _catalog = catalog ?? const <String, dynamic>{};
    _embeddedIndex = _buildEmbeddedIndex(_catalog);
  }

  /// A **beágyazott** indoklás-szövegek indexe (pl. „egy hír kedveléséért").
  ///
  /// ⚠️ MIÉRT KELL: az achievement-értesítés törzse `+{delta} pont {reason}. …`
  /// alakú, ahol a `{reason}` **maga is egy katalógus-szöveg** (a szerver a
  /// `reasonKey`-ből oldja fel). A tárolt sorban viszont csak a kész indoklás
  /// van — ezért a helyőrző értékét **visszafejtjük** a katalógusból, és a
  /// mostani nyelven írjuk vissza.
  static Map<String, String> _buildEmbeddedIndex(Map<String, dynamic> catalog) {
    final kinds = catalog['kinds'];
    if (kinds is! Map) return const <String, String>{};
    final index = <String, String>{};
    for (final entry in kinds.entries) {
      final value = entry.value;
      if (value is! Map) continue;
      for (final language in const ['hu', 'en']) {
        final byLanguage = value[language];
        if (byLanguage is! Map) continue;
        final body = '${byLanguage['body'] ?? ''}'.trim();
        // Csak a SABLON NÉLKÜLI, rövid indoklások jönnek szóba.
        if (body.isEmpty || body.contains('{')) continue;
        index.putIfAbsent(body, () => '${entry.key}');
      }
    }
    return index;
  }

  static Map<String, String> _embeddedIndex = const <String, String>{};

  /// A tárolt (létrehozáskor renderelt) szöveg átfordítása a **mostani** nyelvre.
  ///
  /// Ha a típus ismeretlen, vagy a szöveg egyik sablonra sem illeszkedik (például
  /// egyedi, dinamikus szöveg, vagy 500 karakterre vágott sor), akkor a **tárolt
  /// szöveg változatlanul** megy ki — sosem tippelünk és sosem hagyunk üresen.
  static NotificationText localize({
    required String type,
    required String title,
    required String body,
  }) {
    final entry = _kindEntry(type);
    if (entry == null) {
      return NotificationText(title: title, body: body);
    }

    final language = AppStrings.language;
    final other = language == AppLanguage.en ? 'hu' : 'en';
    return NotificationText(
      title: _localizeField(entry, 'title', title, language, other),
      body: _localizeField(entry, 'body', body, language, other),
    );
  }

  static Map<String, dynamic>? _kindEntry(String type) {
    final kinds = _catalog['kinds'];
    if (kinds is! Map) return null;
    final entry = kinds[type.trim()];
    return entry is Map<String, dynamic> ? entry : null;
  }

  static String _localizeField(
    Map<String, dynamic> entry,
    String field,
    String stored,
    AppLanguage language,
    String other,
  ) {
    if (stored.trim().isEmpty) return stored;
    final current = _template(entry, appLanguageCode(language), field);
    final foreign = _template(entry, other, field);

    // 1) A MÁSIK nyelv sablonjára illeszkedik? → helyőrzők kinyerése.
    final params = _extract(foreign, stored);
    if (params != null) {
      final translated = _fill(current, params, language);
      if (translated.trim().isNotEmpty) return translated;
    }

    // 2) A mostani nyelv sablonjára illeszkedik? → már jó (helyőrzőkkel együtt).
    final own = _extract(current, stored);
    if (own != null) {
      final filled = _fill(current, own, language);
      if (filled.trim().isNotEmpty) return filled;
    }

    // 3) Ismeretlen/egyedi szöveg: marad, ahogy tárolva van.
    return stored;
  }

  static String _template(Map<String, dynamic> entry, String languageCode, String field) {
    final byLanguage = entry[languageCode];
    if (byLanguage is! Map) return '';
    return '${byLanguage[field] ?? ''}';
  }

  /// A sablon illesztése a tárolt szövegre, a helyőrzők értékeivel.
  ///
  /// `null`, ha nem illeszkedik (akkor nem fordítunk).
  static Map<String, String>? _extract(String template, String text) {
    if (template.trim().isEmpty) return null;

    final pattern = StringBuffer('^');
    final names = <String>[];
    var index = 0;
    for (final match in RegExp(r'\{(\w+)\}').allMatches(template)) {
      pattern.write(RegExp.escape(template.substring(index, match.start)));
      pattern.write('([\\s\\S]*?)');
      names.add(match.group(1)!);
      index = match.end;
    }
    pattern.write(RegExp.escape(template.substring(index)));
    pattern.write(r'$');

    final regex = RegExp(pattern.toString());
    final matched = regex.firstMatch(text);
    if (matched == null) return null;

    final params = <String, String>{};
    for (var group = 0; group < names.length; group += 1) {
      final name = names[group];
      // Ismétlődő helyőrzőnél az ELSŐ érték marad (a szerver is így tölti ki).
      params.putIfAbsent(name, () => matched.group(group + 1) ?? '');
    }
    return params;
  }

  /// A sablon kitöltése — a hiányzó helyőrző a katalógus alapértékét kapja
  /// (pl. `name` → „A HUHS member"), ismeretlen kulcs pedig üres lesz.
  static String _fill(String template, Map<String, String> params, AppLanguage language) {
    return template.replaceAllMapped(RegExp(r'\{(\w+)\}'), (match) {
      final key = match.group(1)!;
      final value = params[key];
      if (value != null && value.trim().isNotEmpty) {
        return _translateEmbedded(value, language);
      }
      return _defaultValue(key, language);
    });
  }

  /// Ha a helyőrző értéke **maga is katalógus-szöveg** (beágyazott indoklás),
  /// akkor a mostani nyelvre fordítjuk; egyébként változatlanul megy vissza.
  static String _translateEmbedded(String value, AppLanguage language) {
    if (_embeddedIndex.isEmpty) return value;
    final kind = _embeddedIndex[value.trim()];
    if (kind == null) return value;
    final entry = _kindEntry(kind);
    if (entry == null) return value;
    final translated = _template(entry, appLanguageCode(language), 'body');
    return translated.trim().isEmpty ? value : translated;
  }

  static String _defaultValue(String key, AppLanguage language) {
    final defaults = _catalog['defaults'];
    if (defaults is! Map) return '';
    final entry = defaults[key];
    if (entry is! Map) return '';
    return '${entry[appLanguageCode(language)] ?? entry['hu'] ?? ''}';
  }
}
