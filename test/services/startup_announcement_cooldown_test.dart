import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hungarian_hardstyle_app/services/startup_announcement_cooldown.dart';

void main() {
  const cooldown = StartupAnnouncementCooldown();
  final start = DateTime(2026, 9, 5, 12);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('ugyanazt az indítási képet két órán belül nem mutatja újra', () async {
    expect(
      await cooldown.canShow(
        identity: 'image-a',
        ownerId: 'user-1',
        now: start,
      ),
      isTrue,
    );
    await cooldown.markShown(
      identity: 'image-a',
      ownerId: 'user-1',
      now: start,
    );
    expect(
      await cooldown.canShow(
        identity: 'image-a',
        ownerId: 'user-1',
        now: start.add(const Duration(minutes: 119)),
      ),
      isFalse,
    );
    expect(
      await cooldown.canShow(
        identity: 'image-a',
        ownerId: 'user-1',
        now: start.add(const Duration(hours: 2)),
      ),
      isTrue,
    );
  });

  test('új kép vagy másik felhasználó azonnal megjelenhet', () async {
    await cooldown.markShown(
      identity: 'image-a',
      ownerId: 'user-1',
      now: start,
    );
    expect(
      await cooldown.canShow(
        identity: 'image-b',
        ownerId: 'user-1',
        now: start,
      ),
      isTrue,
    );
    expect(
      await cooldown.canShow(
        identity: 'image-a',
        ownerId: 'user-2',
        now: start,
      ),
      isTrue,
    );
  });
}
