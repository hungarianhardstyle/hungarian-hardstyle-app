import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:hungarian_hardstyle_app/services/app_analytics.dart';

/// **A mérés zárt, adatvédelem-barát eseményhalmaza.**
///
/// MIÉRT EZ A TESZT A LÉNYEG: a mérés a legkönnyebben „kiszivárgó" rész — egy
/// későbbi kérésre bárki beírhat egy `logEvent('user_$uid')` sort, és az
/// észrevétlen marad. Ezért itt **forrásban** kérjük számon:
///   * az eseménynevek **zárt listából** jönnek (nincs szabad szöveg),
///   * a naplózó függvény **nem fogad paramétert** (ami nincs, nem szivároghat),
///   * a hívó helyek a fenti öt eseményt kötik be,
///   * a gyűjtés **debugban kikapcsol**, a Crashlytics pedig **csak kiadásban** él.
void main() {
  group('a zárt eseményhalmaz', () {
    test('pontosan az öt kért esemény van benne', () {
      expect(AppAnalyticsEvent.all, const <String>[
        'app_open',
        'news_open',
        'event_open',
        'attendance_set',
        'register_done',
      ]);
    });

    test('az ismert neveket elfogadja', () {
      for (final name in AppAnalyticsEvent.all) {
        expect(isKnownAnalyticsEvent(name), isTrue, reason: name);
      }
    });

    test('az ismeretlen nevet elveti (nincs csendes új esemény)', () {
      for (final name in const <String>[
        '',
        'news_opne',
        'app_open ',
        'APP_OPEN',
        'user_12345',
        'email_sent',
        'chat_message',
      ]) {
        expect(isKnownAnalyticsEvent(name), isFalse, reason: '"$name"');
      }
    });

    test('az eseménynevek nem tartalmazhatnak felhasználói adatot', () {
      final suspicious = RegExp(
        r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+|\d{5,}|\{|\}|\$',
      );
      for (final name in AppAnalyticsEvent.all) {
        expect(
          suspicious.hasMatch(name),
          isFalse,
          reason: 'gyanús eseménynév: $name',
        );
      }
    });
  });

  group('az inicializálás védettsége', () {
    test('Firebase nélkül sem dob, és nem lesz „ready"', () async {
      // A tesztkörnyezetben nincs `Firebase.initializeApp()`, ezért az
      // inicializálásnak **csendben** vissza kell térnie.
      await AppAnalytics.initialize();
      expect(AppAnalytics.isReady, isFalse);
    });

    test('a naplózás inicializálás nélkül sem dob', () async {
      await AppAnalytics.logEvent(AppAnalyticsEvent.appOpen);
      await AppAnalytics.logNewsOpen();
      await AppAnalytics.logEventOpen();
      await AppAnalytics.logAttendanceSet();
      await AppAnalytics.logRegisterDone();
      // Ismeretlen esemény: csendben elvetve.
      await AppAnalytics.logEvent('user_42_opened_chat');
      expect(true, isTrue);
    });
  });

  /// **Forrás-lint** — a burkoló és a hívó helyek szerződése.
  group('az adatvédelmi szerződés (forrás-lint)', () {
    late String analytics;

    setUpAll(() {
      analytics = File(
        'lib/services/app_analytics.dart',
      ).readAsStringSync();
    });

    test('a naplózó függvény NEM fogad paramétert', () {
      expect(
        analytics.contains('static Future<void> logEvent(String name) async'),
        isTrue,
        reason: 'egy `Map` paraméter már szabad szöveg behordója lehet',
      );
      expect(
        analytics.contains('logEvent(String name, {'),
        isFalse,
        reason: 'nincs második (paraméter-) argumentum',
      );
    });

    test('a burkoló nem hivatkozik személyes adatra', () {
      final forbidden = <String>[
        'uid',
        'userId',
        'email',
        'displayName',
        'userName',
        'token',
        'message',
        'postId',
        'eventId',
        'setUserId',
        'setUserProperty',
      ];
      for (final needle in forbidden) {
        expect(
          analytics.contains(needle),
          isFalse,
          reason: 'a mérésbe nem kerülhet ilyen adat: $needle',
        );
      }
    });

    test('a gyűjtés debugban kikapcsol, a Crashlytics csak kiadásban él', () {
      expect(
        analytics.contains('setAnalyticsCollectionEnabled(!kDebugMode)'),
        isTrue,
      );
      expect(
        analytics.contains('setCrashlyticsCollectionEnabled(\n        kReleaseMode,\n      )') ||
            analytics.contains('setCrashlyticsCollectionEnabled(kReleaseMode)'),
        isTrue,
      );
      // A hibaág is csak kiadásban kötődik be, és az előző ágat meghívja.
      expect(analytics.contains('if (!kReleaseMode) return;'), isTrue);
      expect(analytics.contains('previous?.call(details)'), isTrue);
      expect(analytics.contains('PlatformDispatcher.instance.onError'), isTrue);
    });

    test('a `main()` a Firebase inicializálás UTÁN indítja', () {
      final main = File('lib/main.dart').readAsStringSync();
      final firebaseIndex = main.indexOf('await initializeFirebaseRuntime()');
      final analyticsIndex = main.indexOf('await AppAnalytics.initialize()');
      expect(firebaseIndex, greaterThan(-1));
      expect(analyticsIndex, greaterThan(firebaseIndex));
      expect(
        main.contains('AppAnalytics.logAppOpen()'),
        isTrue,
        reason: 'az `app_open` az indulásnál megy ki',
      );
    });

    test('a négy további esemény a megfelelő helyen van bekötve', () {
      final callSites = <String, String>{
        'lib/screens/news/news_detail_screen.dart': 'AppAnalytics.logNewsOpen()',
        'lib/screens/events/event_detail_screen.dart':
            'AppAnalytics.logEventOpen()',
        'lib/screens/community/community_screen.dart':
            'AppAnalytics.logRegisterDone()',
      };
      for (final entry in callSites.entries) {
        expect(
          File(entry.key).readAsStringSync().contains(entry.value),
          isTrue,
          reason: '${entry.key}: hiányzik a(z) ${entry.value} hívás',
        );
      }
      final events = File(
        'lib/screens/events/event_detail_screen.dart',
      ).readAsStringSync();
      expect(events.contains('AppAnalytics.logAttendanceSet()'), isTrue);
      expect(
        RegExp(
          r'AppAnalytics\.log(NewsOpen|EventOpen|AttendanceSet|RegisterDone)\(',
        ).allMatches(events).length,
        2,
        reason: 'az esemény-képernyő a saját kettőjét naplózza',
      );
    });
  });
}
