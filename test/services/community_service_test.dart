import 'package:flutter_test/flutter_test.dart';

import 'package:hungarian_hardstyle_app/services/community_service.dart';

void main() {
  test('a privát üzenetek szűrője a káromkodást maszkolja', () {
    expect(
      CommunityService.maskProfanity('Ez kurva szar, baszás, fuck és SH1T!'),
        'Ez ***** ****, ******, **** és ****!',
    );
  });

  test('a gyakori magyar és angol változatokat is maszkolja', () {
    final masked = CommunityService.maskProfanity(
      'basz buzi faszfej szarházi bitch asshole',
    );
    expect(masked, '**** **** ******* ******** ***** *******');
  });

  test('a normál szöveget változatlanul hagyja', () {
    const text = 'Ez egy normális privát üzenet.';
    expect(CommunityService.maskProfanity(text), text);
  });
}
