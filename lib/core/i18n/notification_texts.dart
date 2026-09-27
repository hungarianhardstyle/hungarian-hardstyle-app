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

  /// ⚠️ **LEGACY sablonok** (2026-09-27, a tulajdonos jelzése: a pont-értesítés
  /// angol felületen is magyarul szólt).
  ///
  /// MIÉRT KELL: a tárolt értesítés szövege a **létrehozáskor érvényes** sablonból
  /// készült. A magyar pont-sablonban szóismétlés volt („Új össz**össz**pontszámod"),
  /// amit a 373-as kör javított — a **régi** sorok viszont a hibás szöveget
  /// tartalmazzák, és így **egyetlen mai sablonra sem illeszkednek**, ezért
  /// fordítás nélkül maradtak. Ezekkel az alias-sablonokkal a régi sorok is
  /// átfordulnak (a `kind` ugyanaz, csak a minta más).
  static const Map<String, Map<String, String>> _legacyTemplates = {
    'achievement_points': {
      'hu': '+{delta} pont {reason}. Új összösszpontszámod: {points}.',
    },
    'achievement_points_level': {
      'hu':
          '+{delta} pont {reason}. Új összösszpontszámod: {points}. Új rangod: „{badge}”.',
    },
  };

  /// A **rokon típusok**: ha a tárolt sor a másik típus sablonjával készült (mért
  /// eset: a `@mindenki` fan-out sorában `type = chat_mention`, de a szöveg a
  /// `chat_everyone` sablonból való), a fordítás csak akkor helyes, ha azt a
  /// sablont is megpróbáljuk.
  static const Map<String, List<String>> _relatedKinds = {
    'chat_mention': ['chat_everyone'],
    'chat_everyone': ['chat_mention'],
    'achievement_points': ['achievement_points_level'],
    'achievement_points_level': ['achievement_points'],
  };

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
  ///
  /// ⚠️ A `kind` az elsődleges (a szerver a `@mindenki` fan-outnál
  /// `type = chat_mention` + `kind = chat_everyone` párt ír), de ha nincs, a
  /// `type`-ból indulunk; a **rokon típusokat** is megpróbáljuk, és a **legjobban
  /// illeszkedő** sablont választjuk (amelyik a legkevesebbet hagyja a
  /// helyőrzőkben — így nem kerül a névbe a „mindenkit" szó).
  static NotificationText localize({
    required String type,
    String kind = '',
    required String title,
    required String body,
  }) {
    final language = AppStrings.language;
    final other = language == AppLanguage.en ? 'hu' : 'en';
    final kinds = _candidateKinds(kind, type);
    if (kinds.isEmpty) {
      return NotificationText(title: title, body: body);
    }
    return NotificationText(
      title: _localizeFieldAcrossKinds(kinds, 'title', title, language, other),
      body: _localizeFieldAcrossKinds(kinds, 'body', body, language, other),
    );
  }

  /// A típusok, amiket a fordításnál sorban megpróbálunk (az első a legfontosabb).
  static List<String> _candidateKinds(String kind, String type) {
    final result = <String>[];
    for (final candidate in [kind.trim(), type.trim()]) {
      if (candidate.isEmpty) continue;
      if (!result.contains(candidate)) result.add(candidate);
      for (final related in _relatedKinds[candidate] ?? const <String>[]) {
        if (!result.contains(related)) result.add(related);
      }
    }
    return result;
  }

  static Map<String, dynamic>? _kindEntry(String type) {
    final kinds = _catalog['kinds'];
    if (kinds is! Map) return null;
    final entry = kinds[type.trim()];
    return entry is Map<String, dynamic> ? entry : null;
  }

  /// A mező fordítása: végigmegy a jelölt típusokon, és a **legjobb illeszkedést**
  /// választja (a legkisebb helyőrző-lefedettséget), majd a mostani nyelvre írja.
  static String _localizeFieldAcrossKinds(
    List<String> kinds,
    String field,
    String stored,
    AppLanguage language,
    String other,
  ) {
    if (stored.trim().isEmpty) return stored;

    _BestMatch? best;
    for (final kind in kinds) {
      final entry = _kindEntry(kind);
      if (entry == null) continue;
      final current = _template(entry, appLanguageCode(language), field);
      final foreignTemplates = <String>[
        _template(entry, other, field),
        ...?_legacyTemplates[kind]?[other] != null
            ? [_legacyTemplates[kind]![other]!]
            : null,
      ];
      for (final foreign in foreignTemplates) {
        if (foreign.trim().isEmpty) continue;
        final params = _extract(foreign, stored);
        if (params == null) continue;
        final translated = _fill(current, params, language);
        if (translated.trim().isEmpty) continue;
        final score = _placeholderScore(params);
        if (best == null || score < best.score) {
          best = _BestMatch(score: score, text: translated);
        }
      }
      // A mostani nyelv sablonjára illeszkedés: ez a „már jó nyelvű" eset, ezt
      // csak akkor vesszük, ha nincs fordítás (kisebb prioritás).
      final own = _extract(current, stored);
      if (own != null) {
        final filled = _fill(current, own, language);
        if (filled.trim().isNotEmpty) {
          final score = _placeholderScore(own) + 1000;
          if (best == null || score < best.score) {
            best = _BestMatch(score: score, text: filled);
          }
        }
      }
    }
    // Ismeretlen/egyedi szöveg: marad, ahogy tárolva van.
    return best?.text ?? stored;
  }

  /// Minél több karakter kerül a helyőrzőkbe, annál **rosszabb** az illeszkedés
  /// (a `chat_mention` sablon a „mindenkit" szót is a névbe tenné).
  static int _placeholderScore(Map<String, String> params) =>
      params.values.fold(0, (sum, value) => sum + value.trim().length);

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

/// Egy kiválasztott illeszkedés (a legjobb megőrzéséhez).
class _BestMatch {
  const _BestMatch({required this.score, required this.text});

  final int score;
  final String text;
}
