class AchievementSummary {
  final int points;
  final String badgeName;
  final String badgeDescription;
  final String badgeImageUrl;
  final String badgeSlug;

  const AchievementSummary({
    required this.points,
    required this.badgeName,
    required this.badgeDescription,
    required this.badgeImageUrl,
    required this.badgeSlug,
  });

  static const empty = AchievementSummary(
    points: 0,
    badgeName: 'Kezdő ütem',
    badgeDescription: 'A HUHS közösség alapjelvénye.',
    badgeImageUrl: '',
    badgeSlug: 'starter',
  );

  factory AchievementSummary.fromProfile(Map<String, dynamic> data) {
    final raw = data['achievement'] is Map
        ? Map<String, dynamic>.from(data['achievement'] as Map)
        : data;
    final points = (raw['achievementPoints'] ?? raw['points']) is num
        ? ((raw['achievementPoints'] ?? raw['points']) as num)
              .clamp(0, 999999)
              .toInt()
        : 0;
    final badge = raw['achievementBadge'] is Map
        ? Map<String, dynamic>.from(raw['achievementBadge'] as Map)
        : const <String, dynamic>{};
    final image = _firstString([
      badge['imageUrl'],
      badge['image_url'],
      badge['image'],
      badge['badgeImageUrl'],
      badge['badge_image_url'],
      raw['achievementBadgeImageUrl'],
      raw['achievementBadgeImage'],
    ]);
    return AchievementSummary(
      points: points,
      badgeName: _string(badge['name']).isEmpty
          ? (points == 0 ? empty.badgeName : 'HUHS tag')
          : _string(badge['name']),
      badgeDescription: _string(badge['description']).isEmpty
          ? (points == 0
                ? empty.badgeDescription
                : 'Közösségi aktivitással megszerzett jelvény.')
          : _string(badge['description']),
      badgeImageUrl: image,
      badgeSlug: _string(badge['slug']).isEmpty
          ? (points == 0 ? empty.badgeSlug : 'achievement')
          : _string(badge['slug']),
    );
  }

  static String _string(Object? value) => value is String ? value.trim() : '';

  static String _firstString(Iterable<Object?> values) {
    for (final value in values) {
      final text = _string(value);
      if (text.isNotEmpty) return text;
    }
    return '';
  }
}
