/// A Chat-`@`hivatkozás (mention) **tiszta** szabályai.
///
/// A tulajdonos kérése (2026-09-24): *„egy @xy betűvel tudjak hivatkozni a chaten
/// cikkre, djre, szervezőre, eseményre, kiadványra vagy személyre/userre"* —
/// *„elkezdem irni a betűket és dobja fel a lehetőségeket"*, *„a személyre/userre
/// hivatkozás legyen elérhető mindenkinek, többi csak admin/moderátornak"*,
/// *„mindegyik kattintható legyen és a megfelelő helyre vigyen"*.
///
/// Ez a modul **nem foglalkozik** sem hálózattal, sem felülettel: a javaslatok
/// szűrése, az éppen gépelt `@`-token felismerése, a beszúrás és a **tárolt**
/// hivatkozások szövegbeli megkeresése (a kattintható részekhez) itt dől el,
/// ezért mérhető.
library;

/// A hivatkozható típusok — a **személy** mindenkinek, a többi csak
/// adminnak/moderátornak jár.
const String mentionTypeUser = 'user';
const String mentionTypeArticle = 'article';
const String mentionTypeArtist = 'artist';
const String mentionTypeOrganizer = 'organizer';
const String mentionTypeEvent = 'event';
const String mentionTypeRelease = 'release';

/// A tartalom-típusok **sorrendje** a javaslatlistában (ez a felület sorrendje).
const List<String> mentionContentTypes = <String>[
  mentionTypeArticle,
  mentionTypeArtist,
  mentionTypeOrganizer,
  mentionTypeEvent,
  mentionTypeRelease,
];

/// A típus magyar címkéje a javaslatlista csoportfejlécéhez.
String mentionTypeLabel(String type) {
  switch (type) {
    case mentionTypeUser:
      return 'Személyek';
    case mentionTypeArticle:
      return 'Cikkek';
    case mentionTypeArtist:
      return 'DJ-k';
    case mentionTypeOrganizer:
      return 'Szervezők';
    case mentionTypeEvent:
      return 'Események';
    case mentionTypeRelease:
      return 'Kiadványok';
    default:
      return type;
  }
}

/// Ennyi hivatkozás kerülhet egy üzenetbe (a szerver is ezt kényszeríti).
const int mentionMaxCount = 10;

/// Ennyi **személy** kap értesítést egy üzenetből (a spam ellen).
const int mentionUserNotifyMax = 5;

/// Egy hivatkozható célpont: típus, azonosító és a **beíráskori** név.
class ChatMentionTarget {
  const ChatMentionTarget({
    required this.type,
    required this.id,
    required this.label,
  });

  final String type;
  final String id;
  final String label;

  bool get isUser => type == mentionTypeUser;

  /// A tárolt alak (a `mentions` tömb eleme a chates dokumentumban).
  Map<String, Object> toMap() => <String, Object>{
    'type': type,
    'id': id,
    'label': label,
  };

  /// A Firestore-ból jött elem feldolgozása — **hibás/üres elem kimarad**.
  static ChatMentionTarget? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final type = (raw['type'] ?? '').toString().trim();
    final id = (raw['id'] ?? '').toString().trim();
    final label = (raw['label'] ?? '').toString().trim();
    if (type.isEmpty || id.isEmpty || label.isEmpty) return null;
    final known = type == mentionTypeUser || mentionContentTypes.contains(type);
    if (!known) return null;
    return ChatMentionTarget(type: type, id: id, label: label);
  }

  /// A `mentions` tömb feldolgozása (legfeljebb [mentionMaxCount] elem).
  static List<ChatMentionTarget> listFrom(Object? raw) {
    if (raw is! List) return const <ChatMentionTarget>[];
    final result = <ChatMentionTarget>[];
    for (final item in raw) {
      final target = ChatMentionTarget.fromMap(item);
      if (target == null) continue;
      if (result.length >= mentionMaxCount) break;
      result.add(target);
    }
    return List<ChatMentionTarget>.unmodifiable(result);
  }

  @override
  bool operator ==(Object other) =>
      other is ChatMentionTarget &&
      other.type == type &&
      other.id == id &&
      other.label == label;

  @override
  int get hashCode => Object.hash(type, id, label);

  @override
  String toString() => 'ChatMentionTarget($type/$id/$label)';
}

/// Az éppen gépelt `@`-token a beviteli mezőben.
class MentionQuery {
  const MentionQuery({required this.start, required this.query});

  /// A `@` pozíciója a szövegben.
  final int start;

  /// A `@` utáni, még be nem fejezett szöveg (kis- és nagybetű számít).
  final String query;

  @override
  String toString() => 'MentionQuery(@$query a $start-tól)';
}

/// A `@` után ennyi karakterig keresünk (ennél hosszabb szöveg nem név).
const int mentionQueryMaxLength = 30;

/// Az **aktív** `@`-token megkeresése a kurzor előtt.
///
/// `null`, ha nincs `@`, ha a `@` és a kurzor között szóköz/soremelés van, vagy
/// ha a token hosszabb a [mentionQueryMaxLength]-nél (ilyenkor nem javasolunk).
MentionQuery? activeMentionQuery(String text, int caret) {
  if (text.isEmpty) return null;
  final end = caret.clamp(0, text.length);
  final start = text.lastIndexOf('@', end > 0 ? end - 1 : 0);
  if (start < 0) return null;
  // A `@` előtti karakter betű/szám: az e-mail-cím (`info@…`) nem hivatkozás.
  // Két egymás melletti `@` (`@@`) sem az: a második `@` „elnyelné" az elsőt.
  if (start > 0) {
    if (text[start - 1] == '@') return null;
    final before = text.codeUnitAt(start - 1);
    final isWordChar =
        (before >= 0x30 && before <= 0x39) ||
        (before >= 0x41 && before <= 0x5A) ||
        (before >= 0x61 && before <= 0x7A);
    if (isWordChar) return null;
  }
  final token = text.substring(start + 1, end);
  if (token.length > mentionQueryMaxLength) return null;
  if (token.contains(' ') || token.contains('\n') || token.contains('\t')) {
    return null;
  }
  if (token.contains('@')) return null;
  return MentionQuery(start: start, query: token);
}

/// A kiválasztott hivatkozás beszúrása a `@token` helyére.
///
/// Visszaadja a **teljes új szöveget** és az **új kurzorpozíciót** (a beszúrt
/// név után, egy szóközzel).
class MentionInsertion {
  const MentionInsertion({required this.text, required this.caret});

  final String text;
  final int caret;
}

MentionInsertion insertMention({
  required String text,
  required MentionQuery query,
  required int caret,
  required String label,
}) {
  final end = caret.clamp(0, text.length);
  final name = label.trim();
  final replacement = name.isEmpty ? '@' : '@$name ';
  final before = text.substring(0, query.start);
  final after = text.substring(end);
  final updated = '$before$replacement$after';
  return MentionInsertion(
    text: updated,
    caret: before.length + replacement.length,
  );
}

/// Egy javaslat a listában.
class MentionSuggestion {
  const MentionSuggestion({
    required this.type,
    required this.id,
    required this.label,
    this.subtitle = '',
  });

  final String type;
  final String id;
  final String label;

  /// Másodlagos sor (pl. a DJ városa, a cikk dátuma) — a felület használhatja.
  final String subtitle;

  ChatMentionTarget toTarget() =>
      ChatMentionTarget(type: type, id: id, label: label);

  @override
  String toString() => 'MentionSuggestion($type/$id/$label)';
}

/// A javaslatok összeállítása: **személyek elöl**, utána a tartalom-típusok a
/// [mentionContentTypes] sorrendjében — és a tartalom **csak** akkor, ha a
/// felhasználó admin/moderátor ([privileged]).
///
/// A szűrés: a lekérdezés a név **elején** áll (erősebb találat) vagy benne van.
/// Üres lekérdezésnél minden találat jó (a lista eleje látszik).
List<MentionSuggestion> mentionSuggestions({
  required String query,
  required List<MentionSuggestion> users,
  Map<String, List<MentionSuggestion>> content = const {},
  bool privileged = false,
  int limit = 8,
}) {
  final needle = query.trim().toLowerCase();
  final ordered = <MentionSuggestion>[
    ..._rank(users, needle),
  ];
  if (privileged) {
    for (final type in mentionContentTypes) {
      ordered.addAll(_rank(content[type] ?? const [], needle));
    }
  }
  if (ordered.length > limit) {
    return List<MentionSuggestion>.unmodifiable(ordered.sublist(0, limit));
  }
  return List<MentionSuggestion>.unmodifiable(ordered);
}

/// A találatok rendezése: elöl a név **elején** egyezők, utána a tartalmazók,
/// azonos esetben ABC-sorrend.
List<MentionSuggestion> _rank(List<MentionSuggestion> items, String needle) {
  final starts = <MentionSuggestion>[];
  final contains = <MentionSuggestion>[];
  for (final item in items) {
    final label = item.label.toLowerCase();
    if (needle.isEmpty) {
      starts.add(item);
    } else if (label.startsWith(needle)) {
      starts.add(item);
    } else if (label.contains(needle)) {
      contains.add(item);
    }
  }
  int byLabel(MentionSuggestion a, MentionSuggestion b) =>
      a.label.toLowerCase().compareTo(b.label.toLowerCase());
  starts.sort(byLabel);
  contains.sort(byLabel);
  return <MentionSuggestion>[...starts, ...contains];
}

/// A szövegben **ténylegesen megtalált** hivatkozás (a kattintható részhez).
class MentionSpan {
  const MentionSpan({
    required this.start,
    required this.end,
    required this.target,
  });

  final int start;
  final int end;
  final ChatMentionTarget target;
}

/// A tárolt hivatkozások megkeresése a szövegben.
///
/// ⚠️ A `mentions` a **beíráskori nevet** tartalmazza, ezért a `@Név` szöveg
/// alapján keressük — de csak a **még nem fedett** helyeken, és a hosszabb
/// neveket előbb, hogy a `@Kiss` ne nyelje le a `@Kiss Péter`-t.
List<MentionSpan> mentionSpans(
  String text,
  List<ChatMentionTarget> mentions,
) {
  if (text.isEmpty || mentions.isEmpty) return const <MentionSpan>[];
  final candidates = <({String needle, ChatMentionTarget target})>[];
  for (final target in mentions) {
    final label = target.label.trim();
    if (label.isEmpty) continue;
    candidates.add((needle: '@$label', target: target));
  }
  candidates.sort((a, b) => b.needle.length.compareTo(a.needle.length));
  final taken = <int>[];
  final spans = <MentionSpan>[];
  for (final candidate in candidates) {
    final index = text.indexOf(candidate.needle);
    if (index < 0) continue;
    final end = index + candidate.needle.length;
    final overlaps = taken.any((pos) => pos >= index && pos < end);
    if (overlaps) continue;
    for (var i = index; i < end; i++) {
      taken.add(i);
    }
    spans.add(
      MentionSpan(start: index, end: end, target: candidate.target),
    );
  }
  spans.sort((a, b) => a.start.compareTo(b.start));
  return List<MentionSpan>.unmodifiable(spans);
}
