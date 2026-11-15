# eMudhra biztonsági frissítés — 404

Források:

- [Firebase javítási útmutató](https://firebase.google.com/support/guides/compromised-emudhra-intermediate-ca)
- [Dart/Flutter biztonsági közlemény](https://github.com/dart-lang/sdk/security/advisories/GHSA-frr6-h895-5pxp)
- [FlutterFire 6.10.2 visszaportolt javítás](https://pub.dev/packages/cloud_firestore/versions/6.10.2/changelog)

Az Android natív Firestore SDK nem érintett, de a Flutter `dart:io` hálózati
rétege igen. Apple-platformon a Firestore beépített tanúsítványtára külön érintett.
Az SDK-frissítés csak újonnan lefordított és telepített alkalmazással véd;
backenddeploy és az operációs rendszer frissítése önmagában nem elegendő.

## Verziók

| Összetevő | Korábbi | Javított |
|---|---|---|
| Flutter | 3.47.2 | 3.47.8 |
| Dart | 3.13.2 | 3.13.7 |
| firebase_core | 4.15.0 | 4.15.2 |
| cloud_firestore | 6.10.0 | 6.10.2 |
| Firebase Apple SDK | 12.19.0 | 12.19.3 |
| firebase_analytics | 12.6.0 | 12.6.1 |
| firebase_app_check | 0.4.8 | 0.4.9 |
| firebase_auth | 6.7.0 | 6.7.1 |
| firebase_messaging | 16.7.0 | 16.7.1 |
| cloud_functions | 6.5.0 | 6.5.1 |
| firebase_crashlytics | 5.4.0 | 5.4.1 |

Csak a Firebase-család nyolc javítókiadása változott a lockban; nincs főverzióváltás.
Az Auth-, SMTP-, App Check-enforcement- és WordPress-logika nem módosult.
A pubspec legalább Dart 3.13.7-et követel. Mindkét CI-konfiguráció Flutter 3.47.8-ra van rögzítve.

## Helyi SDK és ellenőrzések

2026-11-15 óta az alapértelmezett SDK (`C:/src/flutter`) 3.47.9 (stable,
2026-11-15: a `3.47.9` tagre rögzítve, a CI is 3.47.9); a korábbi külön `C:/src/flutter-3.47.8` könyvtár törölve.
PATH-módosítás nem kell:

```powershell
node tools/check-client-security.mjs --self-test
node tools/check-client-security.mjs
flutter analyze --no-pub lib test
flutter test --no-pub
```

- 1568/1568 Flutter-teszt sikeres az új SDK-val.
- Analyze: nincs probléma. Szigorú fordításellenőrzés: 100%.
- A biztonsági kapu a régi Flutter 3.47.2-t tényleges futtatáskor elutasította.
- A kapu önellenőrzése elutasítja a köztes, még sérülékeny főverziókat is
  (`cloud_firestore 7.0.0`, Firebase Apple SDK 13.1.0).
- Az első Android-fordítás App Check-osztály hiányával elbukott. Az elavult
  plugin-buildkimenet célzott tisztítása történt; a történeti AAB-ok megmaradtak.

## iOS-forrásazonosság

A helyi munkapéldány és index megőrzése mellett külön indexből készült CI-pillanatkép:
`codex/security-404`, commit `1c126bfaf008f64ed824940e4e17f1bf255d2e1a`.
Ez tartalmazza a 402/403 helyi kliensjavításait is. A főágra nem került merge.

[iOS CI-futás](https://github.com/hungarianhardstyle/hungarian-hardstyle-app/actions/runs/41847073722).
A CI a build után az Xcode által feloldott Firebase-verziót is ellenőrzi.

## Android-csomag bizonyítása

`build/HUHS-v1.0.0+404-release.aab`, 83 621 334 bájt.
SHA-256: `5C73EF5EB8C989EA25ECF9A4557C7EB14183C2A437E66D2D9A6884817CBB9545`.
A csomag saját protobuf-manifestje: `hu.hungarianhardstyle.app`, `1.0.0`, `404`.
Aláíró tanúsítvány SHA-256: `B4:FB:6D:AF:37:A7:0C:56:17:6F:8D:34:A5:BE:79:A1:7C:2E:5B:B5:59:1C:C4:F6:64:BF:29:47:F0:AB:0A:50`.

Mindhárom ABI-nál összehasonlítottuk az AAB-ból kivett `libflutter.so` hashét
a javított engine Maven-JAR-jából kivett, ugyanazzal az NDK 28.2 `llvm-strip
--strip-unneeded` parancsával megtisztított binárissal. Mindhárom bitazonos.
A javított engine: `cf636b1dfb818dd6a3ff16e390e93b1a036969c8`.
Ez a csomag tényleges motorját igazolja, nem csak a shell SDK-verzióját.
Részletek: `tmp/security-404-binary-proof.log`, `tmp/verify-aab-404.log`.

## iOS-csomag bizonyítása

A CI **success** állapotban zárult. A build utáni napló kétszer is megerősíti:
`Xcode resolved Firebase SDK: 12.19.3`. A macOS-os teljes tesztkör eredménye:
`1568 tests passed`. Mind a 18 CI-pillanatképfájl egyezik a helyi forrással.
Részletek: `tmp/security-404-ios-ci-detail.log`.

IPA: `build/ios-ipa-404/Runner-unsigned.ipa`, 23 225 514 bájt.
SHA-256: `AE5D9F182CA1113E554FC915D061C74FAB46DB22706D42EA96BA921917ADE156`.
Az Info.plist `CFBundleVersion = 404`, `CFBundleShortVersionString = 1.0.0`.
A csomagolt changelog és fordítás ellenőrizve; a Flutter frameworkben a Dart
3.13.7 verziójelölő is jelen van. Az IPA változatlanul a korábbi CI tesztprofilját
használja: aláírás nélküli és teszthirdetéses, közvetlenül App Store-ba nem tölthető.
Telepítéshez aláírás, éles kiadáshoz a külön Codemagic aláírt profil szükséges.

Éles terjesztés és valódi készülékes regressziós próba külön lépés.
