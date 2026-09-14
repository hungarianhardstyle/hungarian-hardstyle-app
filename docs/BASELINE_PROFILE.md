# HuHS Baseline Profile

The Android app has a dedicated `:baselineprofile` generator module. The
generated profile is merged into the app's release variant through the
`baselineProfile(project(":baselineprofile"))` dependency in
`android/app/build.gradle.kts`.

## Generate a profile

Run the generator on a rooted emulator, a supported physical device, or an
Android 13+ device supported by the Macrobenchmark tooling:

```text
cd android
gradlew.bat :app:generateBaselineProfile
```

The generated profile must be reviewed and committed by the maintainer before
the next production AAB is built. Do not generate or upload an AAB as part of
this documentation step.

## Covered journey

The generator currently covers cold app startup and the first idle frame. When
the startup flow changes, extend the generator with the changed critical path.
Keep the existing Flutter, Billing, Firebase, WordPress, AdMob, download, and
navigation behavior unchanged; Baseline Profile changes must only describe
real user journeys and must not add application business logic.

## Release checklist

1. Generate the profile and inspect the generated `baseline-prof.txt`.
2. Run `flutter test --no-pub`, `flutter analyze --no-pub`, and `git diff --check`.
3. Build a release artifact and verify the profile is packaged in the AAB.
4. Smoke-test startup, navigation, Label/release loading, Billing, downloads,
   notifications, and the existing free-release path before Play upload.

The profile improves ART compilation of the recorded paths; it does not by
itself guarantee a change to the Play Console optimization score.
