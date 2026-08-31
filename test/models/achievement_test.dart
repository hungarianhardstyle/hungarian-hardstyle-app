import 'package:flutter_test/flutter_test.dart';

import 'package:hungarian_hardstyle_app/models/achievement.dart';

void main() {
  test('hiányzó achievement-adatnál a nulla pontos alapjelvényt adja', () {
    final summary = AchievementSummary.fromProfile({});

    expect(summary.points, 0);
    expect(summary.badgeSlug, 'starter');
    expect(summary.badgeName, 'Kezdő ütem');
  });

  test('beolvassa a szerver által küldött pontot és jelvényképet', () {
    final summary = AchievementSummary.fromProfile({
      'achievementPoints': 315,
      'achievementBadge': {
        'slug': 'crowd-starter',
        'name': 'Tömegmozgató',
        'description': 'Aktív közösségi jelenlét.',
        'imageUrl': 'https://example.com/badge.png',
      },
    });

    expect(summary.points, 315);
    expect(summary.badgeSlug, 'crowd-starter');
    expect(summary.badgeName, 'Tömegmozgató');
    expect(summary.badgeImageUrl, 'https://example.com/badge.png');
  });

  test('a beágyazott achievement-formátumot is támogatja', () {
    final summary = AchievementSummary.fromProfile({
      'achievement': {
        'points': 100,
        'badge': {'name': 'Első lépés'},
      },
    });

    expect(summary.points, 100);
    expect(summary.badgeName, 'HUHS tag');
  });

  test('a WordPress/Firebase snake_case képmezőjét is beolvassa', () {
    final summary = AchievementSummary.fromProfile({
      'achievementPoints': 0,
      'achievementBadge': {
        'slug': 'starter',
        'name': 'Kezdő ütem',
        'image_url': 'https://example.com/starter.png',
      },
    });

    expect(summary.badgeImageUrl, 'https://example.com/starter.png');
  });
}
