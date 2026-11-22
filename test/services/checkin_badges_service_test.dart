import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/services/checkin_badges_service.dart';

CheckinBadgesResult build({required bool own, List<int> featured = const []}) {
  return CheckinBadgesResult.fromMap({
    'own': own,
    'showAll': true,
    'featured': featured,
    'badges': [
      for (final id in [1, 2, 3, 4])
        {
          'eventId': id,
          'title': 'Buli $id',
          'badgeName': 'Jelvény $id',
          'badgeUrl': '',
          'at': id * 1000,
        },
    ],
  });
}

void main() {
  test('a válasz feldolgozása: hibás elemek kimaradnak', () {
    final result = CheckinBadgesResult.fromMap({
      'own': true,
      'badges': [
        {'eventId': 1, 'title': 'A'},
        {'title': 'nincs azonosító'},
        'nem térkép',
      ],
    });
    expect(result.badges.length, 1);
    expect(result.badges.single.label, 'A');
    expect(result.showAll, isTrue);
  });

  test(
    'főprofil: a kiemeltek; saját profilon kiemelés nélkül a legutóbbi három',
    () {
      expect(build(own: true, featured: [3, 1]).shown.map((b) => b.eventId), [
        3,
        1,
      ]);
      expect(build(own: true).shown.length, 3);
      // Másnál kiemelés nélkül nincs mit mutatni.
      expect(build(own: false).shown, isEmpty);
    },
  );
}
