import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/screens/community/birth_date_setup_screen.dart';

/// **A születési dátum kérése — a koppintás útja és a beállító képernyő.**
///
/// A tulajdonos kérése (2026-09-27): *„menjen ki notifybe mér kötelező a
/// születési dátum, mehet nekik mail is"* — *„a meglévő tagoknak úgyértem"*.
/// A szerveroldali kiküldő (`functions/index.js` → `sendBirthDateNotices`) a
/// `birth_date` célpontot küldi, ezért ennek **mindhárom** úton működnie kell:
/// a listabeli értesítés koppintásánál, a push megnyitásánál, és a képernyőnek
/// a meglévő egy-mezős mentést kell hívnia.
void main() {
  group('a koppintás célpontja', () {
    test('FORRÁS-LINT: a birth_date ág a beállító képernyőre visz', () {
      final target = File(
        'lib/core/navigation/content_target.dart',
      ).readAsStringSync();
      expect(target.contains("case 'birth_date':"), isTrue);
      expect(target.contains('BirthDateSetupScreen()'), isTrue);
      expect(
        target.contains("import '../../screens/community/birth_date_setup_screen.dart';"),
        isTrue,
      );
      // A `profile` ág érintetlen (az a nyilvános profilra visz).
      expect(target.contains("case 'profile':"), isTrue);
    });

    test('FORRÁS-LINT: az értesítés-központ és a push is ismeri', () {
      final center = File(
        'lib/screens/notifications/notification_center_screen.dart',
      ).readAsStringSync();
      expect(center.contains("'birth_date',"), isTrue);

      final push = File(
        'lib/services/push_notification_service.dart',
      ).readAsStringSync();
      expect(push.contains("type == 'birth_date'"), isTrue);
      expect(
        push.contains('openContentTarget('),
        isTrue,
        reason: 'a push ugyanazt a célpont-feloldást hívja, mint a központ',
      );
      expect(
        push.contains("targetType: 'birth_date'"),
        isTrue,
        reason: 'a push-adat típusa is birth_date',
      );
    });

    test('FORRÁS-LINT: a szerver is a birth_date célpontot küldi', () {
      final plan = File('functions/birth-date-notice-plan.js').readAsStringSync();
      expect(plan.contains("targetType: 'birth_date'"), isTrue);
      expect(plan.contains('targetId: target'), isTrue);
    });
  });

  group('a beállító képernyő', () {
    testWidgets('dátum nélkül a Mentés inaktív', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: BirthDateSetupScreen()));
      final button = tester.widget<FilledButton>(
        find.byKey(const ValueKey('birth-date-setup-save')),
      );
      expect(button.onPressed, isNull);
      expect(find.text('Nincs megadva'), findsOneWidget);
    });

    testWidgets('meglévő dátummal a Mentés aktív, és látszik a dátum', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: BirthDateSetupScreen(initialValue: '1990-05-01'),
        ),
      );
      final button = tester.widget<FilledButton>(
        find.byKey(const ValueKey('birth-date-setup-save')),
      );
      expect(button.onPressed, isNotNull);
      expect(find.text('Nincs megadva'), findsNothing);
      // A választó gomb mindig ott van.
      expect(
        find.byKey(const ValueKey('birth-date-setup-pick')),
        findsOneWidget,
      );
    });

    test('FORRÁS-LINT: a mentés a meglévő egy-mezős utat hívja', () {
      final screen = File(
        'lib/screens/community/birth_date_setup_screen.dart',
      ).readAsStringSync();
      expect(screen.contains('CommunityService().saveBirthDate('), isTrue);
      expect(
        screen.contains('pickBirthDate('),
        isTrue,
        reason: 'ugyanaz a dátumválasztó, mint a regisztrációnál',
      );
      // A hibaüzenet a közös fordítón megy át (nem nyers szöveg).
      expect(screen.contains('userFacingError(error)'), isTrue);
      // Nincs nyers, fordítatlan felirat: minden szöveg `AppText`/`tr`.
      // ⚠️ A minta szándékosan zárja ki az `AppText(`-et (a „Text(" rész-szöveg
      // különben hamis találatot ad — ez a saját mérőeszközöm hibája volt).
      expect(RegExp(r"(?<![A-Za-z])Text\(\s*'").hasMatch(screen), isFalse);
    });
  });
}
