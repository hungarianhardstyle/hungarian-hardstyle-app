import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/services/achievement_rank_sync.dart';

/// A saját rang/jelvény figyelése — a tulajdonos kérése:
/// *„cache-ben megvan, de ha szintet lép, indít egy lekérést"*.
///
/// A teszt **injektált streammel** dolgozik, ezért Firebase és hálózat nélkül
/// méri a valódi viselkedést: mikor indul lekérés és mikor nem.
void main() {
  Map<String, dynamic> profile({String slug = 'starter', String image = 'a.png', int points = 0}) => {
    'achievementPoints': points,
    'achievementBadge': {'slug': slug, 'name': 'Név', 'imageUrl': image},
  };

  test('szintlépésnél (más jelvény) indít egy frissítést', () async {
    final controller = StreamController<Map<String, dynamic>>();
    var refreshes = 0;
    final sync = AchievementRankSync(
      uid: 'u1',
      projection: controller.stream,
      onRankChanged: () async => refreshes++,
    )..start();

    controller.add(profile(slug: 'starter'));
    await Future<void>.delayed(Duration.zero);
    expect(refreshes, 0, reason: 'az első kép nem változás — nincs felesleges lekérés');

    controller.add(profile(slug: 'regular', points: 300));
    await Future<void>.delayed(Duration.zero);
    expect(refreshes, 1, reason: 'a rang megváltozott, ezért frissítünk');

    sync.dispose();
    await controller.close();
  });

  test('pontnövekedés ugyanabban a rangban NEM indít lekérést', () async {
    final controller = StreamController<Map<String, dynamic>>();
    var refreshes = 0;
    final sync = AchievementRankSync(
      uid: 'u1',
      projection: controller.stream,
      onRankChanged: () async => refreshes++,
    )..start();

    controller.add(profile(slug: 'regular', points: 100));
    controller.add(profile(slug: 'regular', points: 250));
    await Future<void>.delayed(Duration.zero);
    expect(refreshes, 0, reason: 'a jelvény ugyanaz, a cache marad');

    sync.dispose();
    await controller.close();
  });

  test('a kicserélt jelvénygrafika (új kép-verzió) is frissítést indít', () async {
    final controller = StreamController<Map<String, dynamic>>();
    var refreshes = 0;
    final sync = AchievementRankSync(
      uid: 'u1',
      projection: controller.stream,
      onRankChanged: () async => refreshes++,
    )..start();

    controller.add(profile(slug: 'regular', image: 'badge.png?v=1'));
    controller.add(profile(slug: 'regular', image: 'badge.png?v=2'));
    await Future<void>.delayed(Duration.zero);
    expect(refreshes, 1, reason: 'a WordPress-katalógusban kicserélt grafika új verziót kap');

    sync.dispose();
    await controller.close();
  });

  test('a frissítések között eltelik a beállított idő', () async {
    final controller = StreamController<Map<String, dynamic>>();
    var refreshes = 0;
    var now = DateTime(2026, 9, 19, 12);
    final sync = AchievementRankSync(
      uid: 'u1',
      projection: controller.stream,
      onRankChanged: () async => refreshes++,
      minimumInterval: const Duration(minutes: 2),
      clock: () => now,
    )..start();

    controller.add(profile(slug: 'starter'));
    controller.add(profile(slug: 'regular'));
    await Future<void>.delayed(Duration.zero);
    expect(refreshes, 1);

    // 1 perccel később újabb rangváltás: még nem indul új lekérés.
    now = now.add(const Duration(minutes: 1));
    controller.add(profile(slug: 'community'));
    await Future<void>.delayed(Duration.zero);
    expect(refreshes, 1, reason: 'a 2 perces korlát védi a szervert');

    // 2 perccel az első után viszont már indul.
    now = now.add(const Duration(minutes: 1, seconds: 1));
    controller.add(profile(slug: 'hardstyle-face'));
    await Future<void>.delayed(Duration.zero);
    expect(refreshes, 2);

    sync.dispose();
    await controller.close();
  });

  test('hiányos vetület nem indít lekérést, és a hiba nem töri el a figyelést', () async {
    final controller = StreamController<Map<String, dynamic>>();
    var refreshes = 0;
    final sync = AchievementRankSync(
      uid: 'u1',
      projection: controller.stream,
      onRankChanged: () async => refreshes++,
    )..start();

    controller.add(<String, dynamic>{});
    controller.add({'achievementPoints': 100});
    controller.addError(StateError('hálózat'));
    controller.add(profile(slug: 'regular'));
    await Future<void>.delayed(Duration.zero);
    expect(refreshes, 0, reason: 'a hiányos/üres adat és a hiba nem döntés');

    sync.dispose();
    await controller.close();
  });

  test('a hibázó frissítés nem állítja meg a későbbi figyelést', () async {
    final controller = StreamController<Map<String, dynamic>>();
    var calls = 0;
    var now = DateTime(2026, 9, 19, 12);
    final sync = AchievementRankSync(
      uid: 'u1',
      projection: controller.stream,
      onRankChanged: () async {
        calls++;
        if (calls == 1) throw StateError('a szerver nem válaszol');
      },
      minimumInterval: Duration.zero,
      clock: () => now,
    )..start();

    controller.add(profile(slug: 'starter'));
    controller.add(profile(slug: 'regular'));
    await Future<void>.delayed(Duration.zero);
    now = now.add(const Duration(seconds: 1));
    controller.add(profile(slug: 'community'));
    await Future<void>.delayed(Duration.zero);
    expect(calls, 2, reason: 'egy hibás lekérés után is figyelünk tovább');

    sync.dispose();
    await controller.close();
  });

  test('a jelvény-kulcs a slugból és a kép verziójából áll', () {
    expect(
      AchievementRankSync.badgeKeyOf(profile(slug: 'regular', image: 'x.png?v=3')),
      'regular|x.png?v=3',
    );
    expect(AchievementRankSync.badgeKeyOf(const {}), '');
    expect(AchievementRankSync.badgeKeyOf({'achievementBadge': 'nem-map'}), '');
  });
}
