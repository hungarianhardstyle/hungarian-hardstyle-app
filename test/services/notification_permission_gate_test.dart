import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hungarian_hardstyle_app/services/notification_permission_gate.dart';

/// **Az értesítési engedély kérése** — a döntési logika mérése.
///
/// MIÉRT EZ A TESZT A LÉNYEG: a kérés **egyszer** történhet meg egy
/// telepítésen, és csak akkor, ha az engedély még nincs meg. Ha a döntés rossz,
/// kétféle hiba lehetséges, és mindkettő látható a felhasználónak:
///   * **túl sok kérés** (zaklatás — a régi, induláskori viselkedés volt ez),
///   * **elmaradt kérés** (a felhasználó soha nem kap értesítést).
///
/// ⚠️ Az engedély **már megléte** esetén a viselkedés nem változhat: ilyenkor
/// nem jelenik meg ismertető, viszont a **token-útvonal lefut** — ezt a
/// `onAlreadyGranted` hívással mérjük, hogy egy jövőbeli átírás ne veszítse el
/// csendben a tokent.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SharedPreferences> emptyPreferences([
    Map<String, Object> values = const {},
  ]) async {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferences.getInstance();
  }

  group('a tiszta döntés', () {
    test('az engedély már megvan → nincs ismertető, nincs kérés', () {
      expect(
        notificationPermissionAction(
          permissionGranted: true,
          memory: NotificationPermissionMemory.none,
        ),
        NotificationPermissionAction.alreadyGranted,
      );
    });

    test('az engedély megvan akkor is, ha korábban elutasítottuk', () {
      // A Beállításokban az OS-szintű engedélyt visszaadhatja a felhasználó —
      // ilyenkor a „Most nem" emléke **nem** tilthatja meg a token-útvonalat.
      expect(
        notificationPermissionAction(
          permissionGranted: true,
          memory: const NotificationPermissionMemory(
            explained: true,
            declined: true,
          ),
        ),
        NotificationPermissionAction.alreadyGranted,
      );
    });

    test('friss telepítés → ismertető, majd OS-ablak', () {
      expect(
        notificationPermissionAction(
          permissionGranted: false,
          memory: NotificationPermissionMemory.none,
        ),
        NotificationPermissionAction.showExplainer,
      );
    });

    test('a „Most nem" után SOHA nem kérdezünk újra', () {
      expect(
        notificationPermissionAction(
          permissionGranted: false,
          memory: const NotificationPermissionMemory(
            explained: true,
            declined: true,
          ),
        ),
        NotificationPermissionAction.staySilent,
      );
    });

    test('a „ne zavarj" jelölés önmagában is csendet jelent', () {
      expect(
        notificationPermissionAction(
          permissionGranted: false,
          memory: const NotificationPermissionMemory(doNotAsk: true),
        ),
        NotificationPermissionAction.staySilent,
      );
    });

    test('a már megmutatott ismertető után nem zaklatunk (egyszer kérdezünk)', () {
      expect(
        notificationPermissionAction(
          permissionGranted: false,
          memory: const NotificationPermissionMemory(explained: true),
        ),
        NotificationPermissionAction.staySilent,
      );
    });

    test('a Beállításokban kikapcsolt értesítésnél nem kérünk engedélyt', () {
      expect(
        notificationPermissionAction(
          permissionGranted: false,
          notificationsEnabledInSettings: false,
        ),
        NotificationPermissionAction.staySilent,
      );
    });
  });

  group('az OS-állapot megítélése', () {
    test('az authorized és a provisional engedély', () {
      expect(
        notificationPermissionIsGranted(AuthorizationStatus.authorized),
        isTrue,
      );
      expect(
        notificationPermissionIsGranted(AuthorizationStatus.provisional),
        isTrue,
      );
    });

    test('a notDetermined és a denied NEM engedély', () {
      expect(
        notificationPermissionIsGranted(AuthorizationStatus.notDetermined),
        isFalse,
      );
      expect(
        notificationPermissionIsGranted(AuthorizationStatus.denied),
        isFalse,
      );
    });
  });

  group('az emlékezet tárolása', () {
    test('a mentett döntés visszaolvasható', () async {
      final preferences = await emptyPreferences({
        notificationPermissionExplainedKey: true,
        notificationPermissionDeclinedKey: true,
        notificationPermissionDoNotAskKey: false,
      });
      final memory = NotificationPermissionMemory.fromPreferences(preferences);
      expect(memory.explained, isTrue);
      expect(memory.declined, isTrue);
      expect(memory.doNotAsk, isFalse);
    });

    test('üres tárolóból az alapállapot jön (nincs döntés)', () async {
      final preferences = await emptyPreferences();
      final memory = NotificationPermissionMemory.fromPreferences(preferences);
      expect(memory.explained, isFalse);
      expect(memory.declined, isFalse);
      expect(memory.doNotAsk, isFalse);
    });

    test('a mentés kiírja mindhárom jelzőt', () async {
      final preferences = await emptyPreferences();
      await const NotificationPermissionMemory(
        explained: true,
        declined: true,
      ).save(preferences);
      expect(preferences.getBool(notificationPermissionExplainedKey), isTrue);
      expect(preferences.getBool(notificationPermissionDeclinedKey), isTrue);
      expect(preferences.getBool(notificationPermissionDoNotAskKey), isFalse);
    });

    test('hiányzó tárolóval sem dob', () async {
      expect(
        NotificationPermissionMemory.fromPreferences(null).explained,
        isFalse,
      );
      await NotificationPermissionMemory.none.save(null);
    });
  });

  group('a kapu folyamata', () {
    test('friss telepítés: ismertető látszik, elfogadás után kérünk', () async {
      final preferences = await emptyPreferences();
      var explainerShown = 0;
      var requestCount = 0;

      final outcome = await NotificationPermissionGate.requestAfterAction(
        preferences: preferences,
        showExplainer: () async {
          explainerShown += 1;
          return true;
        },
        readPermissionGranted: () async => false,
        requestPermission: () async {
          requestCount += 1;
          return true;
        },
      );

      expect(outcome, NotificationPermissionOutcome.granted);
      expect(explainerShown, 1);
      expect(requestCount, 1);
      // A döntés megmarad: `explained` igen, `declined` nem.
      expect(preferences.getBool(notificationPermissionExplainedKey), isTrue);
      expect(preferences.getBool(notificationPermissionDeclinedKey), isFalse);
    });

    test('„Most nem" → nincs OS-kérés, és legközelebb sem kérdezünk', () async {
      final preferences = await emptyPreferences();
      var requestCount = 0;

      final first = await NotificationPermissionGate.requestAfterAction(
        preferences: preferences,
        showExplainer: () async => false,
        readPermissionGranted: () async => false,
        requestPermission: () async {
          requestCount += 1;
          return true;
        },
      );
      expect(first, NotificationPermissionOutcome.declined);
      expect(requestCount, 0);
      expect(preferences.getBool(notificationPermissionDeclinedKey), isTrue);

      // A **második** értelmes művelet már nem kérdez (nincs zaklatás).
      var secondExplainer = 0;
      final second = await NotificationPermissionGate.requestAfterAction(
        preferences: preferences,
        showExplainer: () async {
          secondExplainer += 1;
          return true;
        },
        readPermissionGranted: () async => false,
        requestPermission: () async {
          requestCount += 1;
          return true;
        },
      );
      expect(second, NotificationPermissionOutcome.skipped);
      expect(secondExplainer, 0);
      expect(requestCount, 0);
    });

    test('az OS elutasítása után sem kérdezünk újra', () async {
      final preferences = await emptyPreferences();
      var explainerShown = 0;

      final first = await NotificationPermissionGate.requestAfterAction(
        preferences: preferences,
        showExplainer: () async {
          explainerShown += 1;
          return true;
        },
        readPermissionGranted: () async => false,
        requestPermission: () async => false,
      );
      expect(first, NotificationPermissionOutcome.declined);
      expect(preferences.getBool(notificationPermissionDeclinedKey), isTrue);

      final second = await NotificationPermissionGate.requestAfterAction(
        preferences: preferences,
        showExplainer: () async {
          explainerShown += 1;
          return true;
        },
        readPermissionGranted: () async => false,
        requestPermission: () async => true,
      );
      expect(second, NotificationPermissionOutcome.skipped);
      expect(explainerShown, 1, reason: 'az ismertető csak egyszer jelenhet meg');
    });

    test(
      'az engedély már megvan → nincs ismertető, de a token-útvonal LEFUT',
      () async {
        final preferences = await emptyPreferences();
        var explainerShown = 0;
        var tokenPathRuns = 0;

        final outcome = await NotificationPermissionGate.requestAfterAction(
          preferences: preferences,
          showExplainer: () async {
            explainerShown += 1;
            return true;
          },
          readPermissionGranted: () async => true,
          requestPermission: () async => true,
          onAlreadyGranted: () async => tokenPathRuns += 1,
        );

        expect(outcome, NotificationPermissionOutcome.alreadyGranted);
        expect(explainerShown, 0, reason: 'engedéllyel nem jelenik meg semmi');
        expect(tokenPathRuns, 1, reason: 'a token-útvonal nem veszhet el');
      },
    );

    test('a Beállításokban kikapcsolt értesítésnél csendben maradunk', () async {
      final preferences = await emptyPreferences({
        notificationsEnabledStorageKey: false,
      });
      var explainerShown = 0;

      final outcome = await NotificationPermissionGate.requestAfterAction(
        preferences: preferences,
        showExplainer: () async {
          explainerShown += 1;
          return true;
        },
        readPermissionGranted: () async => false,
        requestPermission: () async => true,
      );

      expect(outcome, NotificationPermissionOutcome.skipped);
      expect(explainerShown, 0);
    });

    test('az állapot-olvasás hibájára nem kérdezünk (biztonságos irány)', () async {
      final preferences = await emptyPreferences();
      var explainerShown = 0;

      final outcome = await NotificationPermissionGate.requestAfterAction(
        preferences: preferences,
        showExplainer: () async {
          explainerShown += 1;
          return true;
        },
        readPermissionGranted: () async => throw StateError('nincs platform'),
      );

      expect(outcome, NotificationPermissionOutcome.skipped);
      expect(explainerShown, 0);
    });

    test('az ismertető hibája nem viszi el a hívó műveletét', () async {
      final preferences = await emptyPreferences();
      final outcome = await NotificationPermissionGate.requestAfterAction(
        preferences: preferences,
        showExplainer: () async => throw StateError('nincs navigátor'),
        readPermissionGranted: () async => false,
        requestPermission: () async => true,
      );
      expect(outcome, NotificationPermissionOutcome.declined);
    });

    test('a token-kezelés hibája nem dob tovább', () async {
      final preferences = await emptyPreferences();
      final outcome = await NotificationPermissionGate.requestAfterAction(
        preferences: preferences,
        showExplainer: () async => true,
        readPermissionGranted: () async => true,
        onAlreadyGranted: () async => throw StateError('token hiba'),
      );
      expect(outcome, NotificationPermissionOutcome.alreadyGranted);
    });
  });

  /// **Forrás-lint:** a hívó helyek kötése.
  ///
  /// MIÉRT: a döntés önmagában akkor sem ér semmit, ha a felület egyáltalán nem
  /// hívja. A tulajdonos kérése három **első értelmes műveletet** nevezett meg —
  /// ezeket kérjük számon (a fájlok és a hívások számával, nem csak a szöveg
  /// szereplésével).
  group('a hívó helyek kötése (forrás-lint)', () {
    test('az indulás NEM kér engedélyt (a régi út megszűnt)', () {
      final source = _read('lib/services/push_notification_service.dart');
      final initialize = _methodBody(
        source,
        'static Future<void> initialize()',
      );

      expect(
        initialize.contains('requestPermission'),
        isFalse,
        reason:
            'az OS-ablak nem jelenhet meg induláskor — a kérést a kapu végzi',
      );
      // Az állapot **lekérdezése** viszont igen (az nem vált ki ablakot).
      expect(initialize.contains('isPermissionGranted()'), isTrue);
      // Az OS-ablakot **egyetlen** hely mutathatja meg: `requestPermissionNow()`.
      final windows = RegExp(
        r'\.requestPermission\(',
      ).allMatches(source).length;
      expect(
        windows,
        1,
        reason: 'a kérést csak a `requestPermissionNow()` hívhatja',
      );
    });

    test('a három első művelet mind hívja a kaput', () {
      final callSites = <String, String>{
        'lib/widgets/favorite_button.dart': 'kedvenc mentése',
        'lib/screens/organizers/organizer_detail_screen.dart': 'kedvenc mentése',
        'lib/screens/events/event_detail_screen.dart': '„Ott leszek"',
        'lib/screens/community/community_screen.dart': 'sikeres regisztráció',
      };
      for (final entry in callSites.entries) {
        final source = _read(entry.key);
        expect(
          source.contains('NotificationPermissionPrompt.requestAfterAction'),
          isTrue,
          reason: '${entry.key}: hiányzik a hívás (${entry.value})',
        );
      }
    });

    test('a token-útvonal megmarad (a kérés sikere után is)', () {
      final source = _read('lib/services/push_notification_service.dart');
      expect(
        source.contains('static Future<bool> requestPermissionNow()'),
        isTrue,
      );
      expect(
        source.contains('static Future<void> ensureRegistered()'),
        isTrue,
      );
      // A token a nyelvvel együtt megy mindkét push-kérésben (1. változtatás).
      expect(source.contains("'/push/register'"), isTrue);
      expect(source.contains("'/push/preferences'"), isTrue);
      expect(
        RegExp(r'pushLanguageField:').allMatches(source).length,
        2,
        reason: 'a `language` mező MINDKÉT kérésben megy',
      );
    });
  });
}

String _read(String path) => File(path).readAsStringSync();

/// Egy `static` tag törzse a következő `static` tagig (forrás-linthez).
String _methodBody(String source, String signature) {
  final start = source.indexOf(signature);
  if (start < 0) return '';
  final end = source.indexOf('\n  static ', start + signature.length);
  return source.substring(start, end < 0 ? source.length : end);
}
