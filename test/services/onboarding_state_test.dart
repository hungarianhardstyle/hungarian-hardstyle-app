import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/services/onboarding_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('friss telepítésen megjelenik, utána soha többet', () {
    expect(shouldShowOnboarding(completed: false), isTrue);
    expect(shouldShowOnboarding(completed: true), isFalse);
  });

  test('mélylinkről nyitva NEM jelenik meg (a tartalom az első)', () {
    expect(
      shouldShowOnboarding(completed: false, openedFromLink: true),
      isFalse,
    );
    expect(
      shouldShowOnboarding(completed: true, openedFromLink: true),
      isFalse,
    );
  });

  test('a jelölés hiánya „még nem futott le”, a mentés után igen', () async {
    final prefs = await SharedPreferences.getInstance();
    expect(onboardingCompletedFromPreferences(prefs), isFalse);
    await markOnboardingCompleted(prefs);
    expect(prefs.getBool(onboardingCompletedKey), isTrue);
    expect(onboardingCompletedFromPreferences(prefs), isTrue);
  });

  test('a lépések sorrendje kötött (5 lépés), és a végén nincs tovább', () {
    expect(onboardingStepCount, 5);
    expect(OnboardingStep.values.length, onboardingStepCount);
    expect(OnboardingStep.values, [
      OnboardingStep.welcome,
      OnboardingStep.genres,
      OnboardingStep.favoriteArtists,
      OnboardingStep.account,
      OnboardingStep.notifications,
    ]);
    var step = OnboardingStep.welcome;
    for (var i = 1; i < onboardingStepCount; i++) {
      step = nextOnboardingStep(step)!;
    }
    expect(step, OnboardingStep.notifications);
    expect(nextOnboardingStep(OnboardingStep.notifications), isNull);
  });

  test('a lépésszám 1-től indul (a pontozó sávhoz)', () {
    expect(onboardingStepNumber(OnboardingStep.welcome), 1);
    expect(onboardingStepNumber(OnboardingStep.genres), 2);
    expect(onboardingStepNumber(OnboardingStep.favoriteArtists), 3);
    expect(onboardingStepNumber(OnboardingStep.account), 4);
    expect(onboardingStepNumber(OnboardingStep.notifications), 5);
  });

  test('v2 kulcs: a régi (v1) jelölés NEM zárja ki az új bemutatót', () async {
    SharedPreferences.setMockInitialValues({'onboarding_completed_v1': true});
    final prefs = await SharedPreferences.getInstance();
    expect(onboardingCompletedKey, 'onboarding_completed_v2');
    expect(onboardingCompletedFromPreferences(prefs), isFalse);
  });

  test('a műfajok mentése és visszaolvasása, üres halmaz töröl', () async {
    final prefs = await SharedPreferences.getInstance();
    expect(preferredGenresFromPreferences(prefs), isEmpty);
    await savePreferredGenres(prefs, {'Rawstyle', ' Hardcore '});
    expect(preferredGenresFromPreferences(prefs), {'Rawstyle', 'Hardcore'});
    await savePreferredGenres(prefs, {});
    expect(prefs.containsKey(onboardingGenresKey), isFalse);
    expect(preferredGenresFromPreferences(null), isEmpty);
  });

  test('a vendég-követések mentése; hibás bejegyzést eldob', () async {
    final prefs = await SharedPreferences.getInstance();
    await savePendingArtistFollows(prefs, {12: 'Goze', 7: 'Denoiser'});
    expect(pendingArtistFollowsFromPreferences(prefs), {
      12: 'Goze',
      7: 'Denoiser',
    });
    await prefs.setString(
      onboardingPendingArtistsKey,
      '[{"id":3,"title":"A"},{"id":-1},{"title":"x"},"nem objektum"]',
    );
    expect(pendingArtistFollowsFromPreferences(prefs), {3: 'A'});
    await prefs.setString(onboardingPendingArtistsKey, 'nem json');
    expect(pendingArtistFollowsFromPreferences(prefs), isEmpty);
    await savePendingArtistFollows(prefs, {});
    expect(prefs.containsKey(onboardingPendingArtistsKey), isFalse);
  });

  test('forrás-lint: a belépés átveszi a vendég-követéseket', () {
    final favorites = File('lib/providers/favorites_provider.dart')
        .readAsStringSync();
    expect(favorites, contains('await applyPendingArtistFollows();'));
    expect(
      favorites,
      contains('savePendingArtistFollows(preferences, const {})'),
    );
    final home = File('lib/screens/home/home_screen.dart').readAsStringSync();
    expect(home, contains('personalizedUpcoming('));
  });

  test('tároló nélkül sem dob (null prefs)', () async {
    expect(onboardingCompletedFromPreferences(null), isFalse);
    await markOnboardingCompleted(null);
  });

  test('forrás-lint: az indulás EGYSZER és a tiszta döntéssel hív', () {
    final gate = File('lib/widgets/startup_gate.dart').readAsStringSync();
    // A döntés a modulból jön (nem a kapuban van a logika)…
    expect(gate, contains('shouldShowOnboardingNow()'));
    // …és csak egyszer fut le (nem minden újraépítésnél).
    expect(gate, contains('_onboardingChecked'));
    expect(gate, contains('const OnboardingScreen()'));
    final screen = File('lib/screens/onboarding/onboarding_screen.dart')
        .readAsStringSync();
    // A folyamat a jelöléssel zárul, és a lépéseket a modul adja.
    expect(screen, contains('markOnboardingCompleted'));
    expect(screen, contains('nextOnboardingStep'));
  });
}
