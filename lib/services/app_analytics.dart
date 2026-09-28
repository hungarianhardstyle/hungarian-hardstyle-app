/// **Mérés és összeomlás-jelentés** — egy vékony, ellenőrizhető burkoló.
///
/// MIÉRT BURKOLÓ (és nem közvetlen `FirebaseAnalytics` hívások a képernyőkön):
/// így a naplózott események **zárt halmaza** egy helyen, forrásban olvasható,
/// és a kapu (`test/services/app_analytics_test.dart`) számon kérheti, hogy
/// **nem** kerül bele személyes adat. A hívó helyek csak a szándékot mondják meg
/// (`newsOpen()`), a megvalósítás pedig itt dől el.
///
/// ADATVÉDELEM (a tulajdonos kérése): a naplózott események **paraméter
/// nélküliek** — nincs bennük felhasználó-azonosító, e-mail-cím, név, cset- vagy
/// kommentszöveg, és semmilyen szabad szöveg. Ezért a [AppAnalytics.logEvent]
/// **nem is fogad paramétert**: ami nincs, az nem is szivároghat ki.
///
/// ⚠️ DEBUG: a mérés **ki** van kapcsolva (`kDebugMode`), hogy a fejlesztés ne
/// szennyezze a statisztikát; a Crashlytics gyűjtése pedig **csak kiadásban**
/// él. Egyik hívás sem dob és nem blokkol — a hibák némán elnyelődnek, mert a
/// mérés soha nem viheti el az app indulását vagy egy felhasználói műveletet.
library;

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// A naplózott események **zárt halmaza**.
///
/// Azért `abstract final class` konstansokkal, hogy egy elgépelés
/// (`'news_opne'`) ne hozhasson létre csendben egy új, senki által nem látott
/// eseményt, és hogy a teszt a **teljes** listát mérhesse.
abstract final class AppAnalyticsEvent {
  /// App-indítás.
  static const String appOpen = 'app_open';

  /// Hírek részletek megnyitása.
  static const String newsOpen = 'news_open';

  /// Esemény adatlapjának megnyitása.
  static const String eventOpen = 'event_open';

  /// Részvétel-jelölés mentése („Ott leszek" / mégsem).
  static const String attendanceSet = 'attendance_set';

  /// Sikeres regisztráció.
  static const String registerDone = 'register_done';

  /// Az összes ismert esemény (a naplózás ezt a listát kéri számon).
  static const List<String> all = <String>[
    appOpen,
    newsOpen,
    eventOpen,
    attendanceSet,
    registerDone,
  ];
}

/// Ismert (naplózható) eseménynév-e? — tiszta, tesztelhető döntés.
bool isKnownAnalyticsEvent(String name) => AppAnalyticsEvent.all.contains(name);

/// A mérés és a Crashlytics belépési pontja.
class AppAnalytics {
  AppAnalytics._();

  static bool _ready = false;
  static FirebaseAnalytics? _analytics;

  /// Igaz, ha a mérés be van kötve (a tesztek és a hívó helyek ezt láthatják).
  static bool get isReady => _ready;

  /// Inicializálás **a `Firebase.initializeApp()` UTÁN** (lásd `main.dart`).
  ///
  /// ⚠️ **SOHA nem dob**: ha a Firebase nem indult el, vagy a mérés nem
  /// elérhető, a függvény csendben visszatér, és az app ugyanúgy működik.
  static Future<void> initialize() async {
    if (_ready) return;
    try {
      if (Firebase.apps.isEmpty) return;
      final analytics = FirebaseAnalytics.instance;
      // A fejlesztői kör ne szennyezze a statisztikát: debugban kikapcsolva.
      await analytics.setAnalyticsCollectionEnabled(!kDebugMode);
      // Crashlytics-gyűjtés **csak kiadásban** (debug/profil: nincs jelentés).
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
        kReleaseMode,
      );
      _analytics = analytics;
      _ready = true;
      _installErrorHooks();
    } catch (error) {
      if (kDebugMode) {
        debugPrint('HUHS mérés-inicializálás kihagyva: ${error.runtimeType}');
      }
    }
  }

  /// A Flutter-hiba horog bekötése — **kizárólag kiadásban**, védetten.
  ///
  /// MIÉRT CSAK KIADÁSBAN: debugban a Flutter saját, olvasható hibaútja maradjon
  /// (a `presentError` piros képernyője) — a Crashlytics ott csak zaj.
  ///
  /// MIÉRT VÉDETTEN: a korábbi hibaágat **meghívjuk** (`previous?.call`), és
  /// minden külső hívás `try`-ban áll, ezért a jelentés hibája sem akaszthatja
  /// meg az appot (a horog a `runApp` után, a háttérben áll be).
  static void _installErrorHooks() {
    if (!kReleaseMode) return;
    try {
      final previous = FlutterError.onError;
      FlutterError.onError = (details) {
        try {
          previous?.call(details);
        } catch (_) {
          // A korábbi ág hibája nem nyelheti el a jelentést.
        }
        try {
          FirebaseCrashlytics.instance.recordFlutterFatalError(details);
        } catch (_) {
          // A jelentés hibája nem törheti meg a hibakezelést.
        }
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        try {
          FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        } catch (_) {}
        // Igaz: a hibát kezeltük (nem omlik össze tőle az app).
        return true;
      };
    } catch (_) {
      // Ha a horog nem köthető be, az app indulása akkor is rendben van.
    }
  }

  /// Egy esemény naplózása — **paraméter nélkül** (lásd a fájl fejlécét).
  ///
  /// Az ismeretlen nevet **csendben elveti**, így a zárt halmaz garantált.
  static Future<void> logEvent(String name) async {
    if (!isKnownAnalyticsEvent(name)) return;
    final analytics = _analytics;
    if (analytics == null) return;
    try {
      await analytics.logEvent(name: name);
    } catch (_) {
      // A mérés kiesése nem érintheti a felhasználói műveletet.
    }
  }

  /// App megnyitása (a `main()` hívja, a sikeres indulás után).
  static Future<void> logAppOpen() => logEvent(AppAnalyticsEvent.appOpen);

  /// Hírek részletek megnyitása (a `NewsDetailScreen` indulásakor).
  static Future<void> logNewsOpen() => logEvent(AppAnalyticsEvent.newsOpen);

  /// Esemény adatlapjának megnyitása (az `EventDetailScreen` indulásakor).
  static Future<void> logEventOpen() => logEvent(AppAnalyticsEvent.eventOpen);

  /// Részvétel-jelölés **sikeres** mentése.
  static Future<void> logAttendanceSet() =>
      logEvent(AppAnalyticsEvent.attendanceSet);

  /// **Sikeres** regisztráció.
  static Future<void> logRegisterDone() =>
      logEvent(AppAnalyticsEvent.registerDone);
}
