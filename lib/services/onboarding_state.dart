/// **Onboarding (3 lépés) — a döntés**, tiszta kóddal, hálózat és UI nélkül.
///
/// MIÉRT (a cél 2. pontja): a mért szakadék a **regisztrált profilok (45)** és a
/// **push-ra regisztrált eszközök (~1010)** között van — vagyis a legtöbb ember
/// használja az appot, de nem lép be a közösségi rétegbe, és nem követi a kedvenc
/// DJ-it. A 3 lépéses onboarding ezt a két dolgot teszi meg **egy folyamban**:
/// (1) rövid bemutatás, (2) kedvenc DJ(k) kiválasztása, (3) értesítési engedély.
///
/// ⚠️ **EGYSZER fut**, és **átugorható**: a döntést a `SharedPreferences` jelöli
/// (`onboarding_completed_v1`), ezért egy friss telepítésen egyszer jelenik meg,
/// utána soha. A verziózott kulcs miatt egy későbbi, más tartalmú folyamat
/// **újrakezdhető** anélkül, hogy a régi döntést felül kellene írni.
///
/// ⚠️ **Ami NEM történik:** az onboarding nem írja felül a felhasználó meglévő
/// döntéseit (ha már be van kapcsolva az értesítés, a 3. lépés nem kérdez újra —
/// ezt a `notificationPermissionGate` dönti el), és nem kényszerít regisztrációt:
/// a kedvencelés a profilhoz kötött, ezért a 2. lépés a bejelentkezett állapotot
/// kéri, de **kihagyható**.
library;

import 'package:shared_preferences/shared_preferences.dart';

/// A `SharedPreferences` kulcsa: végigment-e a felhasználó az onboardingon.
const String onboardingCompletedKey = 'onboarding_completed_v1';

/// A lépések száma (a felület ehhez igazítja a pontozó sávot).
const int onboardingStepCount = 3;

/// A lépések — a felület ezekből épül (a sorrend kötött).
enum OnboardingStep {
  /// 1. Rövid bemutatás: mi van az appban.
  welcome,

  /// 2. Kedvenc DJ(k) kiválasztása (ez indítja a személyes értesítéseket).
  favoriteArtists,

  /// 3. Értesítési engedély a **jó pillanatban** (a meglévő kapun át).
  notifications,
}

/// Megmutassuk-e az onboardingot?
///
/// * **friss telepítés** (nincs jelölés) → igen;
/// * **már végigment** → nem (soha többet);
/// * ha a felület épp egy **mélylinkről** nyílt meg (`openedFromLink`), akkor sem:
///   ilyenkor a felhasználó **konkrét tartalmat** akar látni, nem egy bemutatót.
bool shouldShowOnboarding({
  required bool completed,
  bool openedFromLink = false,
}) =>
    !completed && !openedFromLink;

/// A jelölés beolvasása (hiányzó kulcs = még nem futott le; sosem dob).
bool onboardingCompletedFromPreferences(SharedPreferences? preferences) {
  if (preferences == null) return false;
  try {
    return preferences.getBool(onboardingCompletedKey) ?? false;
  } catch (_) {
    return false;
  }
}

/// A jelölés mentése — a hiba nem akadályozhatja a folyamatot.
Future<void> markOnboardingCompleted(SharedPreferences? preferences) async {
  if (preferences == null) return;
  try {
    await preferences.setBool(onboardingCompletedKey, true);
  } catch (_) {
    // A folyamat ebben a munkamenetben így is lezárult.
  }
}

/// Megmutassuk-e MOST? (a tárolót maga nyitja meg; hiba esetén **nem** mutatja,
/// mert egy induláskori hiba nem nyithat folyamatot a felhasználó elé)
Future<bool> shouldShowOnboardingNow({bool openedFromLink = false}) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return shouldShowOnboarding(
      completed: onboardingCompletedFromPreferences(prefs),
      openedFromLink: openedFromLink,
    );
  } catch (_) {
    return false;
  }
}

/// A következő lépés (a „Tovább" gombhoz); az utolsónál `null`.
OnboardingStep? nextOnboardingStep(OnboardingStep current) {
  final index = OnboardingStep.values.indexOf(current);
  if (index < 0 || index + 1 >= OnboardingStep.values.length) return null;
  return OnboardingStep.values[index + 1];
}

/// Hányadik lépésnél tartunk (1-től számolva, a pontozó sávhoz).
int onboardingStepNumber(OnboardingStep step) =>
    OnboardingStep.values.indexOf(step) + 1;
