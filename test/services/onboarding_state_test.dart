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

  test('a lépések sorrendje kötött, és a végén nincs tovább', () {
    expect(OnboardingStep.values.length, onboardingStepCount);
    expect(OnboardingStep.values.first, OnboardingStep.welcome);
    expect(OnboardingStep.values.last, OnboardingStep.notifications);
    expect(
      nextOnboardingStep(OnboardingStep.welcome),
      OnboardingStep.favoriteArtists,
    );
    expect(
      nextOnboardingStep(OnboardingStep.favoriteArtists),
      OnboardingStep.notifications,
    );
    expect(nextOnboardingStep(OnboardingStep.notifications), isNull);
  });

  test('a lépésszám 1-től indul (a pontozó sávhoz)', () {
    expect(onboardingStepNumber(OnboardingStep.welcome), 1);
    expect(onboardingStepNumber(OnboardingStep.favoriteArtists), 2);
    expect(onboardingStepNumber(OnboardingStep.notifications), 3);
  });

  test('tároló nélkül sem dob (null prefs)', () async {
    expect(onboardingCompletedFromPreferences(null), isFalse);
    await markOnboardingCompleted(null);
  });
}
