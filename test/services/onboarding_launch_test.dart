import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/services/referral_link_service.dart';

void main() {
  group('linkes indulás (409): a bemutató nem takarja el a tartalmat', () {
    test('a tartalom-linkek számítanak', () {
      for (final link in [
        'https://hungarianhardstyle.hu/events/hard-base-classic/',
        'https://hungarianhardstyle.hu/releases/goze-change-of-pace/',
        'https://hungarianhardstyle.hu/djs/goze/',
        'https://hungarianhardstyle.hu/2026/09/26/egy-hir/',
        'https://hungarianhardstyle.hu/?p=12505',
      ]) {
        expect(
          ReferralLinkService.isContentLaunchLink(Uri.parse(link)),
          isTrue,
          reason: link,
        );
      }
    });

    test('meghívó, idegen domain és link nélküli indulás NEM számít', () {
      expect(
        ReferralLinkService.isContentLaunchLink(
          Uri.parse('https://hungarianhardstyle.hu/invite/ABC123'),
        ),
        isFalse,
      );
      expect(
        ReferralLinkService.isContentLaunchLink(
          Uri.parse('https://example.com/events/x/'),
        ),
        isFalse,
      );
      expect(ReferralLinkService.isContentLaunchLink(null), isFalse);
    });

    test('forrás-lint: a kapu megvárja a link- és push-jelet', () {
      final gate = File('lib/widgets/startup_gate.dart').readAsStringSync();
      expect(gate, contains('ReferralLinkService.launchedFromContentLink()'));
      expect(
        gate,
        contains('PushNotificationService.launchedFromNotification()'),
      );
      expect(
        gate,
        contains('if (await _launchedFromExternalTarget()) return;'),
      );
      final push = File('lib/services/push_notification_service.dart')
          .readAsStringSync();
      // Az indító értesítést csak EGYSZER kérjük le (közös eredmény).
      expect(RegExp(r'getInitialMessage\(\)').allMatches(push).length, 1);
      expect(
        push,
        contains('final initialMessage = await _initialMessageOnce();'),
      );
    });
  });
}
