# Időzített Google Play-értékeléskérés

Androidon a Kezdőlapon jelenhet meg, legalább 7 nap és 5 alkalmazásindítás után.
A számlálás a funkciót tartalmazó verzió első használatakor indul; a korábbi
telepítés dátumát nem találgatjuk. Egy folyamatban egy indítást számolunk,
fiókváltás és háttérből visszatérés nem növeli a számlálót.

- **Értékelem:** külső alkalmazásban megnyitja a meglévő `playStoreUrl` adatlapot,
  és sikeres megnyitás után nem kérdez újra. Az értékelés elküldése nem ellenőrizhető.
- **Később**, vissza gomb vagy ablakon kívüli koppintás: 30 nap szünet.
- **Ne kérdezd többet:** helyi, tartós letiltás.
- Sikertelen Play-megnyitás: érthető üzenet; nem állítjuk be a tartós letiltást.

A kérés nem jelenik meg másik fülön, nyitott aloldalon/párbeszédablakban,
látható billentyűzet, háttérállapot vagy PiP mellett. A frissítési ablak elsőbbséget
kap. Nincs periodikus lekérdezés: az indulás/frissítésellenőrzés, előtérbe
visszatérés és Kezdőlapra fülváltás a biztonságos megjelenítési alkalom.

Az eseményértékelés utáni régi natív kérés Androidon megszűnt, iOS-en megmaradt.
A régi kérés jelölőjével érkező Android-telepítés 30 nap türelmi időt kap.
Alkalmazásadatok törlése a helyi választásokat és számlálókat is törli.

Ellenőrzések:

```powershell
flutter test --no-pub test/services/app_review_prompt_test.dart test/widgets/app_review_navigation_test.dart
flutter analyze --no-pub lib test
```

A navigációs teszt a tényleges `HungarianHardstyleApp` és `MainNavigation`
képernyőket használja, és a billentyűzet/aloldal melletti halasztást, majd a
Kezdőlapon megjelenő tényleges párbeszédablakot ellenőrzi. A Play indítása a
tesztben helyettesített platformhívás; valódi készüléken még ellenőrizendő.

A korábban elkészült 402-es AAB nem tartalmazza ezt az utólagos funkciót.
A külön kért végleges csomag: `build/HUHS-v1.0.0+403-release.aab` (`1.0.0+403`).
SHA-256: `7EAE776E0105C1A89649A6DB9D5260E7E393DF5AC887C43CB094F0D2EC6D400D`.
Backenddeploy és Play-feltöltés nem történt.
