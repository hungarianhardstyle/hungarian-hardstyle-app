/// Az **értesítési engedély kérése** — tiszta döntési logika + egy vékony,
/// injektálható kapu.
///
/// MIÉRT KELL (mért probléma, 2026-09-28): eddig az OS engedélykérő ablaka
/// **induláskor** jelent meg (`PushNotificationService.initialize()` hívta a
/// `requestPermission()`-t), még mielőtt a felhasználó bármit is csinált volna.
/// A Play és a felhasználók is ezt nehezményezik: egy „hideg" kérésnél sokkal
/// nagyobb az elutasítás esélye, és utána az app már **nem is kérhet** (Android
/// 13+ egyszer kérdez).
///
/// A SZABÁLY (a tulajdonos kérése): az OS-ablak **csak az első értelmes
/// felhasználói művelet után** jelenhet meg — kedvenc mentése, „Ott leszek" egy
/// eseményen, vagy sikeres regisztráció —, és előtte egy rövid magyar ismertető
/// látszik. Ez a fájl a **döntést** tartalmazza (hálózat és `BuildContext`
/// nélkül, ezért teszttel mérhető), a felugró lapot a
/// `lib/widgets/notification_permission_prompt.dart` adja.
///
/// ⚠️ AMI **NEM** VÁLTOZIK: ha az engedély már megvan, nem történik semmi
/// (nincs ismertető, nincs OS-ablak), és a token-útvonal pontosan úgy fut, mint
/// eddig — a meglévő felhasználók értesítései nem sérülhetnek.
library;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'push_notification_service.dart';

/// A `SharedPreferences` kulcsa: **megmutattuk-e már** az ismertetőt.
///
/// Verziózott (`_v1`), hogy egy későbbi, más szövegű ismertetőhöz újrakezdhető
/// legyen a folyamat anélkül, hogy a régi döntést felül kellene írni.
const String notificationPermissionExplainedKey =
    'notification_permission_explained_v1';

/// A `SharedPreferences` kulcsa: a felhasználó a **„Most nem"**-et választotta
/// (vagy az OS utasította el) — ilyenkor **soha többet nem kérdezünk**.
const String notificationPermissionDeclinedKey =
    'notification_permission_declined_v1';

/// A `SharedPreferences` kulcsa: **„Ne zavarj"** — hívás **nélkül** is figyeli
/// ezt a kapu (a régi, tartós elutasítás jele).
const String notificationPermissionDoNotAskKey =
    'notification_permission_do_not_ask_v1';

/// A Beállítások képernyő **fő** értesítés-kapcsolója (`settings_screen.dart`).
///
/// MIÉRT ITT (és nem a Beállításokban): ha a felhasználó a felületen kikapcsolta
/// az értesítéseket, akkor **nem illik** OS-engedélyt kérni — az csak zavarná.
const String notificationsEnabledStorageKey = 'notifications_enabled';

/// Mit tegyünk az első értelmes művelet után?
enum NotificationPermissionAction {
  /// Az OS-engedély **már megvan** → nincs ismertető, nincs kérés; a
  /// token-útvonal viszont lefut (a meglévő működés változatlan).
  alreadyGranted,

  /// Mutassuk meg az ismertetőt, és utána kérje az OS az engedélyt.
  showExplainer,

  /// Ne zavarjuk a felhasználót (már kérdeztük, vagy „Most nem", vagy a
  /// Beállításokban kikapcsolta).
  staySilent,
}

/// A megjegyzett döntés a `SharedPreferences`-ből.
class NotificationPermissionMemory {
  const NotificationPermissionMemory({
    this.explained = false,
    this.declined = false,
    this.doNotAsk = false,
  });

  /// Már megmutattuk az ismertetőt.
  final bool explained;

  /// A felhasználó a „Most nem"-et választotta, vagy az OS elutasította.
  final bool declined;

  /// Tartós „ne kérdezz" jelölés (kézzel vagy korábbi verziótól).
  final bool doNotAsk;

  /// Semmi nem történt még — ez az alapállapot egy friss telepítésnél.
  static const NotificationPermissionMemory none =
      NotificationPermissionMemory();

  /// Beolvasás a tárolóból (hiányzó kulcs = `false`, sosem dob).
  static NotificationPermissionMemory fromPreferences(
    SharedPreferences? preferences,
  ) {
    if (preferences == null) return none;
    try {
      return NotificationPermissionMemory(
        explained: preferences.getBool(notificationPermissionExplainedKey) ??
            false,
        declined:
            preferences.getBool(notificationPermissionDeclinedKey) ?? false,
        doNotAsk:
            preferences.getBool(notificationPermissionDoNotAskKey) ?? false,
      );
    } catch (_) {
      return none;
    }
  }

  /// Mentés a tárolóba — a **hiba nem akadályozhatja** a műveletet.
  Future<void> save(SharedPreferences? preferences) async {
    if (preferences == null) return;
    try {
      await preferences.setBool(notificationPermissionExplainedKey, explained);
      await preferences.setBool(notificationPermissionDeclinedKey, declined);
      await preferences.setBool(notificationPermissionDoNotAskKey, doNotAsk);
    } catch (_) {
      // A döntés ebben a munkamenetben így is érvényes.
    }
  }

  NotificationPermissionMemory copyWith({
    bool? explained,
    bool? declined,
    bool? doNotAsk,
  }) => NotificationPermissionMemory(
    explained: explained ?? this.explained,
    declined: declined ?? this.declined,
    doNotAsk: doNotAsk ?? this.doNotAsk,
  );
}

/// **A döntés** — tiszta függvény, ezért teszttel mérhető.
///
/// Sorrend (és miért ez a sorrend):
///   1. **már megvan** az engedély → nincs teendő (`alreadyGranted`),
///   2. **„ne kérdezz"** (kimondott „Most nem", vagy a Beállításokban
///      kikapcsolt értesítés) → csendben maradunk,
///   3. **már megmutattuk** az ismertetőt → nem zaklatunk újra (egy telepítésen
///      egyszer kérdezünk),
///   4. egyébként → ismertető, majd OS-ablak.
NotificationPermissionAction notificationPermissionAction({
  required bool permissionGranted,
  NotificationPermissionMemory memory = NotificationPermissionMemory.none,
  bool notificationsEnabledInSettings = true,
}) {
  if (permissionGranted) return NotificationPermissionAction.alreadyGranted;
  if (memory.doNotAsk || memory.declined) {
    return NotificationPermissionAction.staySilent;
  }
  if (memory.explained) return NotificationPermissionAction.staySilent;
  if (!notificationsEnabledInSettings) {
    return NotificationPermissionAction.staySilent;
  }
  return NotificationPermissionAction.showExplainer;
}

/// Mi lett a kérés eredménye (a hívó naplózáshoz/döntéshez használhatja).
enum NotificationPermissionOutcome {
  /// Az engedély már megvolt — nem kértünk semmit.
  alreadyGranted,

  /// Az OS-ablak megjelent, és a felhasználó **engedélyezte**.
  granted,

  /// A felhasználó (vagy az OS) **elutasította** — többet nem kérdezünk.
  declined,

  /// Esély sem volt rá (már kérdeztük / kikapcsolta) — nem történt semmi.
  skipped,
}

/// A kapu: az OS-állapot ellenőrzése **kérés nélkül**, majd a döntés szerinti
/// végrehajtás.
///
/// Minden külső hívás (állapot, kérés, ismertető, tároló) **injektálható**,
/// ezért a folyamat `Firebase` és `BuildContext` nélkül, egységteszttel
/// végigjárható.
class NotificationPermissionGate {
  NotificationPermissionGate._();

  /// Az első értelmes felhasználói művelet utáni kérés.
  ///
  /// ⚠️ **SOHA nem dob**: az engedélykérés egy kényelmi funkció, nem akadályozhat
  /// meg egy mentést, egy részvétel-jelölést vagy egy regisztrációt.
  static Future<NotificationPermissionOutcome> requestAfterAction({
    required Future<bool> Function() showExplainer,
    SharedPreferences? preferences,
    Future<bool> Function()? readPermissionGranted,
    Future<bool> Function()? requestPermission,
    Future<void> Function()? onAlreadyGranted,
  }) async {
    final readGranted = readPermissionGranted ?? _readPermissionGranted;
    final request = requestPermission ?? PushNotificationService.requestPermissionNow;
    final handleGranted = onAlreadyGranted ?? PushNotificationService.ensureRegistered;

    SharedPreferences? prefs = preferences;
    try {
      prefs ??= await SharedPreferences.getInstance();
    } catch (_) {
      // Tároló nélkül is működik: legfeljebb nem jegyezzük meg a döntést.
    }

    bool granted = false;
    try {
      granted = await readGranted();
    } catch (_) {
      // Ismeretlen állapotra nem kérdezünk — a biztonságos irány a csend.
      return NotificationPermissionOutcome.skipped;
    }

    final memory = NotificationPermissionMemory.fromPreferences(prefs);
    final action = notificationPermissionAction(
      permissionGranted: granted,
      memory: memory,
      notificationsEnabledInSettings:
          prefs?.getBool(notificationsEnabledStorageKey) ?? true,
    );

    switch (action) {
      case NotificationPermissionAction.alreadyGranted:
        // ⚠️ (a) ÉS (d): az engedéllyel rendelkező felhasználónál **nincs**
        // ismertető, viszont a token-útvonal lefut — ne vesszen el a token.
        try {
          await handleGranted();
        } catch (_) {
          // A token-kezelés hibája nem viheti el a hívó műveletét.
        }
        return NotificationPermissionOutcome.alreadyGranted;

      case NotificationPermissionAction.staySilent:
        return NotificationPermissionOutcome.skipped;

      case NotificationPermissionAction.showExplainer:
        bool accepted = false;
        try {
          accepted = await showExplainer();
        } catch (_) {
          accepted = false;
        }
        if (!accepted) {
          await memory
              .copyWith(explained: true, declined: true)
              .save(prefs);
          return NotificationPermissionOutcome.declined;
        }
        bool requestGranted = false;
        try {
          requestGranted = await request();
        } catch (_) {
          requestGranted = false;
        }
        // Az ismertetőt **megmutattuk** (ezt jegyezzük), és ha az OS elutasította,
        // azt is — így a következő műveletnél már nem kérdezünk újra.
        await memory
            .copyWith(explained: true, declined: !requestGranted)
            .save(prefs);
        return requestGranted
            ? NotificationPermissionOutcome.granted
            : NotificationPermissionOutcome.declined;
    }
  }

  /// Az OS-engedély állapota **kérés nélkül** (`getNotificationSettings`).
  static Future<bool> _readPermissionGranted() =>
      PushNotificationService.isPermissionGranted();
}

/// Az engedély megvan-e az adott állapotban?
///
/// Az `authorized` mellett a `provisional` is elfogadott (iOS „csendes"
/// értesítés): ilyenkor az értesítések **működnek**, ezért nem kérdezünk rá
/// újra. A `notDetermined` és a `denied` viszont **nem** engedély.
bool notificationPermissionIsGranted(AuthorizationStatus status) =>
    status == AuthorizationStatus.authorized ||
    status == AuthorizationStatus.provisional;
