import '../core/firebase/firebase_callable.dart';

/// Egy „Ott voltam” jelvény (egy becsekkolt buli).
class CheckinBadge {
  const CheckinBadge({
    required this.eventId,
    required this.title,
    required this.badgeName,
    required this.badgeUrl,
    required this.at,
  });

  final int eventId;
  final String title;
  final String badgeName;
  final String badgeUrl;

  /// A becsekkolás ideje (ezredmásodperc), vagy 0.
  final int at;

  /// A jelvény neve; ha nincs, a buli címe.
  String get label => badgeName.isNotEmpty ? badgeName : title;

  static CheckinBadge? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['eventId'];
    if (id is! num) return null;
    String text(String key) => raw[key] is String ? raw[key] as String : '';
    return CheckinBadge(
      eventId: id.toInt(),
      title: text('title'),
      badgeName: text('badgeName'),
      badgeUrl: text('badgeUrl'),
      at: raw['at'] is num ? (raw['at'] as num).toInt() : 0,
    );
  }
}

/// A `getCheckinBadges` válasza: a látható jelvények és a tulajdonos beállításai.
class CheckinBadgesResult {
  const CheckinBadgesResult({
    required this.own,
    required this.showAll,
    required this.featured,
    required this.badges,
  });

  /// A saját jelvényeidről van szó (ilyenkor szerkeszthető).
  final bool own;

  /// Az összes jelvény látható másoknak.
  final bool showAll;

  /// A kiemelt események azonosítói (legfeljebb 3).
  final List<int> featured;
  final List<CheckinBadge> badges;

  static const empty = CheckinBadgesResult(
    own: false,
    showAll: true,
    featured: [],
    badges: [],
  );

  factory CheckinBadgesResult.fromMap(Map<Object?, Object?> map) {
    final badges = <CheckinBadge>[
      for (final item
          in (map['badges'] is List ? map['badges'] as List : const []))
        ?CheckinBadge.tryParse(item),
    ];
    final featured = <int>[
      for (final id
          in (map['featured'] is List ? map['featured'] as List : const []))
        if (id is num) id.toInt(),
    ];
    return CheckinBadgesResult(
      own: map['own'] == true,
      showAll: map['showAll'] != false,
      featured: featured,
      badges: badges,
    );
  }

  /// A főprofilon mutatott jelvények: a kiemeltek; ha nincs kiemelés és a profil
  /// a tulajdonosé, a legutóbbi három. Másnak csak a kiemeltek (ha van).
  List<CheckinBadge> get shown {
    final chosen = [
      for (final id in featured)
        for (final badge in badges)
          if (badge.eventId == id) badge,
    ];
    if (chosen.isNotEmpty) return chosen;
    return own ? badges.take(3).toList() : const [];
  }
}

class CheckinBadgesService {
  const CheckinBadgesService();

  /// `userId` nélkül a saját jelvényeid; másnál a tulajdonos beállítása szerint.
  Future<CheckinBadgesResult> fetch({String? userId}) async {
    final result = await callFirebaseCallable<Map<Object?, Object?>>(
      'getCheckinBadges',
      parameters: {'userId': ?userId},
    );
    return CheckinBadgesResult.fromMap(result.data);
  }

  Future<void> saveFeatured({
    required List<int> eventIds,
    required bool showAll,
  }) async {
    await callFirebaseCallable<Object?>(
      'setFeaturedCheckinBadges',
      parameters: {'eventIds': eventIds, 'showAll': showAll},
    );
  }
}
