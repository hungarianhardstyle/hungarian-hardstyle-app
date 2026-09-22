# iOS build + TestFlight — előkészítés és kézi lépések

Ez a dokumentum **egyetlen helyen** tartalmazza, mi készült el az iOS-úthoz, mi az,
amihez neked kell hozzányúlnod (Apple, Firebase, Codemagic), és mi az, ami még
hiányzik az App Store-hoz.

**Alapszabály, ami az egész tervet vezérli:** a **Mac csak az UTOLSÓ lépés**. A
Dart-kód, a `flutter analyze` és a teljes tesztkészlet Windows-on fut — macOS-en
csak a `pod install`, az aláírás és az `.ipa` archívum kell. Ezért nem kell Macet
venni ahhoz, hogy **TestFlight-buildet** kapj: a CI végzi el, és a kész buildet a
**saját iPhone-odra** telepíted a TestFlight appból.

---

## 1. Mi készült el ebben a körben (kódszinten, verziózva)

| Fájl | Mi változott | Miért |
|---|---|---|
| `ios/Runner.xcodeproj/project.pbxproj` | bundle ID: `com.example.hungarianHardstyleApp` → **`hu.hungarianhardstyle.app`** (3+3 hely) | `com.example.*`-tal nem lehet App Store-ba feltölteni; ez az Android `applicationId`-jával **egyezik** |
| ugyanaz | `IPHONEOS_DEPLOYMENT_TARGET` 13.0 → **15.0** (3 hely) | a Flutter 3.47 sablonja és a saját migrációja is 15.0; 13.0-nál a build figyelmeztet/elhasal |
| ~~`ios/Podfile`~~ | **NEM kell** — egy ideig bent volt, és **elhasalt tőle a build** | a projekt **Swift Package Manager**-t használ (minden iOS-plugin Swift Package). A Podfile CocoaPods integrációt kényszerít rá → `The sandbox is not in sync with the Podfile.lock` |
| `ios/Runner/Info.plist` | **`UIBackgroundModes` = `audio`** | enélkül a rádió és a megvásárolt zene **nem szól** háttérben/zárképernyőn iOS-en |
| ugyanaz | **`NSUserTrackingUsageDescription`** | iOS 14.5+ óta a reklámcélú követéshez ATT-engedély kell, különben az AdMob nem kérheti |
| ugyanaz | **`ITSAppUsesNonExemptEncryption` = false** | csak HTTPS-t használunk → nem kell minden feltöltésnél az export-compliance kérdőív |
| `ios/.../Icon-App-1024x1024@1x.png` | **alfa-csatorna eltávolítva** (RGBA → RGB) | ⚠️ **ez hard blokk volt:** az App Store elutasítja az átlátszó/alfa-csatornás 1024-es ikont |
| `codemagic.yaml` | **ÚJ** — 2 workflow: aláírás nélküli ellenőrzés + aláírt TestFlight | ez viszi a valódi buildet |
| `.github/workflows/ios-unsigned-check.yml` | **ÚJ** — ingyenes, Apple-fiók nélküli ellenőrzés | analyze + iOS-fordítás + teszt |
| `test/ios/ios_ci_config_test.dart` | **ÚJ** forrás-lint | a fenti szabályok nem tudnak csendben széthúzni |

### Az ikon-javítás bizonyítéka (mérve, nem feltételezve)

A 1024-es ikon **RGBA** volt (PNG IHDR color type `6`). Mérés a javítás előtt:

```
Összes pixel:      1 048 576  (1024×1024)
Teljesen átlátszó:         0
Részlegesen átlátszó:  4 090  → mind a külső 8 pixelben (lekerekített sarkok),
                                egyik sem α<128, átlagos RGB = (3, 1, 0) = fekete
```

Ezért a javítás **feketére lapítás** volt (a sarok a tervezés szerint is fekete),
nem találomra választott háttér. Utána: color type `2` (RGB), 1144 KB, a kép
szemrevételezve **változatlan**.

> A **kisebb** iOS ikonok szándékosan RGBA-k maradtak: az Apple csak a **1024-es**
> marketing-ikonnál tiltja az alfa-csatornát, a többit az iOS úgyis maszkolja.

---

## 1b. Mi közös a két platformban — és mi nem

**A válasz a „minden új funkciót átvesz?" kérdésre: IGEN, de csak a Dart-kódra.**
Ez egy Flutter-projekt: a `lib/` **egy és ugyanaz** Androidon és iOS-en. Egy új
funkció (hír, esemény, kvíz, chat, szavazás, kiadvány, értesítés, pontrendszer)
**egyszer** íródik meg, és automatikusan megjelenik iOS-en is — nincs külön iOS-
implementáció, nincs dupla karbantartás. Az iOS-út **nem elágazás**, hanem egy
második célplatform ugyanarra a kódra.

Ami **nem** közös, az a platform-kötött réteg. Ez a mérés a kódból:

| Terület | Android | iOS | Állapot |
|---|---|---|---|
| Minden `lib/`-funkció | ugyanaz a Dart-kód | ugyanaz a Dart-kód | ✅ automatikus |
| Rádió háttérben | saját Kotlin `RadioPlaybackService.kt` | `audio_service` + `AVAudioSession` + `UIBackgroundModes: audio` | ⚠️ plist kész, **eszközön még nem mért** |
| Megvásárolt zene, zárképernyő | `audio_service` | ugyanaz | ✅ közös |
| App-frissítés jelzés | Play In-App Updates (`in_app_update`) | **nincs ilyen API** — az App Store frissít | ℹ️ iOS-en néma, de **szándékosan**: a hívás kivételbe fut, és el van kapva |
| Biometrikus belépés | BiometricPrompt | Face ID / Touch ID (`local_auth`) | ✅ javítva: `NSFaceIDUsageDescription` |
| Google Sign-In | `google-services.json` | `GoogleService-Info.plist` + a benne lévő `REVERSED_CLIENT_ID` **URL-séma** az Info.plistben | ✅ kész (E lépés) |
| Reklám | Android AdMob egységek | külön iOS AdMob app + egységek, ATT | ⚠️ ATT kész, az egységek nem |
| Push (FCM) | FCM | APNs + `aps-environment` entitlement | ❌ nincs |
| Zenevásárlás | Google Play Billing | StoreKit | ❌ üzleti döntés |
| Meghívó-link (`app_links`) | install-referrer + https link | **Associated Domains** entitlement + `apple-app-site-association` | ❌ iOS-en nem fog megnyílni |
| Social / Spotify megnyitás | natív app (`externalNonBrowserApplication`) | ugyanez a hívás **`universalLinksOnly`**-ként fut, ezért gyakran `false` | ✅ **van visszaesés** a beépített böngészőre |

### ⚠️ A gyakorlati következmény, amit érdemes megjegyezni

A CI **lefordítja** az iOS-buildet, de a hiányzó `Info.plist`-kulcsok és
entitlementek **futásidőben** buknak meg — vagy még úgy sem, csak némán máshogy
viselkednek. Ezért minden olyan új funkciónál, ami **új natív képességet** kér
(kamera, hely, háttér, értesítés, biometria, mélylink, fizetés), az iOS-oldali
deklarációt **külön meg kell nézni**. Ez a szabály kód-szinten is le van zárva:
`test/ios/platform_parity_test.dart`.



### A) Apple Developer Program tagság — $99/év

- Jelentkezés: <https://developer.apple.com/programs/enroll/>
- **Enélkül nincs TestFlight és nincs App Store.** Fejlesztéshez (saját gépre
  telepítés) nem kell, de a terjesztéshez igen.
- Egyéni vagy céges regisztráció; cégnél adószám/közösségi adószám és D-U-N-S
  szám kell, ez napokat vehet igénybe.

### B) Bundle ID regisztrálása

- <https://developer.apple.com/account/resources/identifiers/add/bundleId>
- Típus: **App IDs → App**
- Bundle ID (explicit): **`hu.hungarianhardstyle.app`**
  ⚠️ Pontosan ez, mert a `codemagic.yaml`, az Xcode-projekt és az Android
  `applicationId` is ezt használja — a forrás-lint teszt ezt őrzi.

### C) App rekord az App Store Connectben

- <https://appstoreconnect.apple.com> → **My Apps → + → New App**
- Platform: iOS; név: `Hungarian Hardstyle`; nyelv: magyar (elsődleges);
  bundle ID: a fenti; SKU: pl. `huhs-ios-001`
- **App rekord nélkül a CI nem tud feltölteni** (ezt a Codemagic is kiírja).

### D) App Store Connect API-kulcs (a CI-nek)

- <https://appstoreconnect.apple.com/access/integrations/api> → **+**
- Név: `HUHS Codemagic`; jogosultság: **App Manager**
- **Issuer ID** (a táblázat felett) és **Key ID** — jegyezd fel
- **Download API Key** (`.p8`) — ⚠️ **csak egyszer tölthető le**

### E) Firebase: iOS app + `GoogleService-Info.plist` — ✅ **KÉSZ (2026-09-22)**

Az iOS app létrejött a `hungarian-hardstyle` projektben:

- **App ID:** `1:1030187737487:ios:0ceb5a9685b34b5f78ebfa`
- **Bundle ID:** `hu.hungarianhardstyle.app` (egyezik az Android `applicationId`-jával)
- **A plist** a repóban van: `ios/Runner/GoogleService-Info.plist` — ugyanúgy
  verziózva, mint az Android `google-services.json`.

A plist **mind a négy helyen be van kötve** az Xcode-projektbe (PBXBuildFile,
PBXFileReference, Runner csoport, Copy Bundle Resources), és a Google Sign-In
`REVERSED_CLIENT_ID` URL-sémája bent van az `Info.plist`-ben. Ezt a
**`tools/attach-ios-firebase.mjs`** végzi, amely:

- a szerkesztés **előtt** ellenőrzi, hogy a plist bundle ID-ja egyezik-e a
  projektével (a rossz ID-jű plist **csendben** megölné a Firebase-t),
- **idempotens** — kétszer futtatva semmit nem dupláz,
- `--check` módban nem ír semmit, `--self-test`-tel önmagát méri (19 ellenőrzés).

Ha a plistet valaha újra le kell tölteni: `node tools/attach-ios-firebase.mjs`.

> **Miért volt ez kritikus:** a `firebase_core` iOS-en a csomagba ágyazott
> plistből indul (`lib/core/firebase/firebase_callable.dart` sima
> `Firebase.initializeApp()`-ot hív) — enélkül az app **indulás közben elszáll**.

### F) Codemagic

1. <https://codemagic.io> → jelentkezés GitHubbal → **Add application** →
   `hungarianhardstyle/hungarian-hardstyle-app`
2. **Team settings → Integrations → Developer Portal** → API-kulcs hozzáadása.
   A név **pontosan** ez legyen: **`HUHS_APPLE`** (a `codemagic.yaml` erre hivatkozik).
3. **codemagic.yaml settings → Code signing identities** → a disztribúciós
   tanúsítvány + App Store profil (a "Fetch from Developer Portal" gombbal
   letölthetők az imént feltöltött kulccsal).
4. **Environment variables** — két csoport:
   - `ios_firebase` → `GOOGLE_SERVICE_INFO_PLIST_BASE64` — **nem kell**, mert a
     plist a repóban van (`ios/Runner/GoogleService-Info.plist`). Csak akkor,
     ha kiveszed a repóból.
   - `appstore_credentials` → `APP_STORE_CONNECT_PRIVATE_KEY` (a `.p8` tartalma),
     `APP_STORE_CONNECT_KEY_IDENTIFIER`, `APP_STORE_CONNECT_ISSUER_ID` (**Secret**)
5. Indítás: **Start new build → ios-testflight**

### G) GitHub Actions

Nincs teendő: a workflow a repóban van, és **magától elindul**, ha az `ios/**`, a
`pubspec.yaml`/`pubspec.lock` vagy maga a workflow fájl változik a `codex/v1.0`
ágon. Kézzel is indítható: **Actions → „iOS fordítás-ellenőrzés" → Run workflow**.

⚠️ **A kézi gomb csapdája (mérve):** a `workflow_dispatch` gombot a GitHub csak
akkor mutatja, ha a workflow az **alapértelmezett** branch-en is ott van — ez
ebben a repóban a **`master`**, nem a `codex/v1.0`. Ezért van mellette `push`
trigger is: enélkül **semmi** nem indítaná el a workflow-t.

💰 **Ez ingyenes.** A repó **publikus**, és a standard GitHub-hosted runnerek
publikus repóban **nem fogyasztanak keretet** (a macOS 10× szorzó csak fizetős
csomagnál számítana). Ha a repó valaha privát lesz, a `push:` triggert vedd ki —
privátban a macOS-perc tízszeres szorzóval fogy.

---

## 3. Hogyan kell futtatni

```bash
# 1) Ma is működik, Apple-fiók nélkül — csak azt mondja meg, lefordul-e:
#    GitHub Actions → "iOS fordítás-ellenőrzés" → Run workflow
#    (helyben, Windows-on ez NEM futtatható: nincs Xcode)

# 2) A valódi, aláírt build + TestFlight (Apple-fiók után):
#    Codemagic → ios-testflight → Start new build
```

A TestFlight-build a feltöltés után **10-60 perc** alatt jelenik meg az App Store
Connectben (Apple feldolgozás), onnan a telefonon a **TestFlight appból**
telepíthető. A verziószám a `pubspec.yaml`-ból jön (`1.0.0+N` → CFBundleVersion
`N`), és **minden feltöltésnél nőnie kell** — ugyanaz a build-szám egyszer
mehet fel, pontosan mint a Play versionCode-nál.

### Milyen iPhone kell a teszthez — és miért nem segít a kábel

**A gépre kötött iPhone nem teszi lehetővé az iOS-fordítást.** Az iPhone a
**cél**, nem a fordító: iOS-t futtat (zárt rendszer), nem macOS-t, és nem tud
Xcode-ot futtatni. Az iOS-buildet **kizárólag az Xcode** készíti, az pedig csak
macOS-en létezik — Windows-on akkor sem indul el, ha ott van melletted a telefon.
Ugyanezért a **kábeles telepítés** (fejlesztői build) útja is zárva van: ahhoz is
Xcode kell.

Ami viszont **működik, és pont ez a terv**: a build a **CI macOS gépén** készül,
és a telefon a **TestFlightból** kapja meg — kábel, Mac és iTunes nélkül.

| Kérdés | Válasz |
|---|---|
| Milyen iOS kell a telefonon? | **iOS 15 vagy újabb** — a projekt deployment targetje 15.0 (a Flutter 3.47 sablonja és migrációja is ezt állítja be) |
| Melyik iPhone jó? | **iPhone 6s / SE (1. generáció) és újabb.** Az iPhone 6 és régebbi **nem tudja telepíteni** (iOS 12-nél megállnak) |
| Kell UDID-regisztráció? | **Nem.** A TestFlight nem kéri az eszköz regisztrálását (ellentétben az ad-hoc/fejlesztői buildekkel) — elég a TestFlight app és a meghívó |
| Kell hozzá fizetős tagság? | **Igen** ($99/év), mert TestFlight csak azzal van |
| Mit ad a régi iPhone? | **Valódi eszközön mért visszajelzést** — a rádió/zene háttér-viselkedését, a plist-kulcsokat, a Face ID-t. Pont azt, amit a CI **nem** tud megmondani |

A telefon iOS-verziója: **Beállítások → Általános → Névjegy → Szoftververzió**.
Ha az **15.0 alatti**, akkor az app ezen a készüléken nem telepíthető — és mivel a
Flutter 3.47 minimuma is iOS 15, **lejjebb vinni nem lehet**, vagyis ilyenkor
másik (iOS 15+) tesztkészülék kell.

---

## 4. Költség (őszintén)

| | Ingyenes keret | Utána |
|---|---|---|
| **GitHub Actions** (publikus repó) | macOS perc ingyenes | — |
| **GitHub Actions** (privát repó) | 2000 perc/hó, de a macOS **10×** szorzóval fogy → **~200 macOS-perc/hó** | fizetős csomag |
| **Codemagic** (magánszemély) | **500 perc/hó macOS M2** (havonta nullázódik) | $0,095/perc |
| **Apple Developer Program** | — | **$99/év** (kötelező) |
| **Használt Mac mini M1/M2** (opcionális) | — | ~150–250 e Ft |

Egy iOS-fordítás jellemzően **15–25 perc**, a teljes aláírt TestFlight-kör
**25–40 perc**. Vagyis a Codemagic ingyenes kerete **havi ~12-20 kiadásra** elég.

---

## 5. Ami MÉG hiányzik az App Store-hoz (nehogy meglepetés legyen)

Ezek **nem** a TestFlightot blokkolják (egy belső tesztre így is felmehet), hanem
a **nyilvános** megjelenést:

1. **StoreKit / In-App Purchase — a legnagyobb tétel, és üzleti döntés.**
   Az Apple a **digitális tartalom** (a megvásárolható zene) értékesítésére a
   **saját** fizetési rendszerét írja elő. Ma a vásárlás `in_app_purchase` +
   Google Play Billing. iOS-en külön App Store termékek kellenek. 2025 óta
   vannak kivételek (US: Epic-ítélet; EU: DMA külső vásárlásra mutatás), de ezt
   **jogilag tisztázni kell, mielőtt bármit építünk**.
2. **Reklám az iOS-en:** az `Info.plist`-ben a **Google teszt** App ID van
   (`ca-app-pub-3940256099942544~1458002511`), a Dart-konstansok pedig az
   **Android** AdMob egységek (`ca-app-pub-7714662594685378/...`). iOS-re külön
   AdMob app + egységek kellenek, különben nincs reklámbevétel.
3. **Push (FCM):** APNs kulcs a Firebase-ben + `aps-environment` entitlement.
   Az entitlement csak akkor kerülhet a projektbe, ha az App ID-nál a Push
   capability **be van kapcsolva** — különben az aláírás elhasal.
4. **App Store metaadatok:** privacy policy URL, App Privacy kérdőív (Firebase +
   AdMob miatt adatgyűjtést kell bejelenteni), korhatár, kategória, leírás.
5. **Képernyőképek:** a projekt **iPhone + iPad** (a `TARGETED_DEVICE_FAMILY`
   `1,2`), ezért iPad-képernyőképek is kellenek. **A tulajdonos döntése
   (2026-09-22): marad az iPhone + iPad** — vagyis ez a követelmény él. A
   döntést a `test/ios/ios_ci_config_test.dart` is rögzíti, hogy ne változhasson
   csendben (csak iPhone-ra állítva `1` lenne, és ezzel az iPad-képernyőképek
   követelménye megszűnne — de az külön döntés).
6. **A zárképernyős lejátszás viselkedése iOS-en** futásidőben még nem lett
   mérve — az `audio_service` iOS-en az `AVAudioSession`-t használja, ami más,
   mint az Android zenei fókusz-kezelése.

---

## 6. Hibakeresés

| Tünet | Ok / teendő |
|---|---|
| `Invalid App Store Icon ... alpha channel` | valamelyik ikon RGBA — a nagyot már javítottuk; ellenőrizd: PNG IHDR 25. bájt ≠ 6 |
| `No profiles for 'hu.hungarianhardstyle.app' were found` | hiányzik a Code signing identity a Codemagicben, vagy nem egyezik a bundle ID |
| `The app record ... was not found` | nincs App rekord az App Store Connectben (C lépés) |
| az app elindul és **azonnal bezárul** | hiányzik a `GoogleService-Info.plist` a bundle-ből (E lépés) |
| `group ... not found` | hiányzik a `ios_firebase` / `appstore_credentials` env-csoport |
| `Could not find a version of Xcode` | a `codemagic.yaml`-ban állítsd `xcode: latest`-re (vagy érvényes verzióra) |
| a zene nem szól háttérben | `UIBackgroundModes: audio` az Info.plist-ben (kész) **és** helyes `AVAudioSession` kategória |

---

## 7. ŐSZINTE KORLÁTOK

- **A CI MÁR FUTOTT, ÉS ZÖLD (2026-09-22, mérve):** a GitHub Actions **2. futása**
  (`af47542a`) **12m4s alatt sikeres** lett — `flutter analyze`, az
  **iOS-fordítás** és a teljes tesztkészlet is:
  `✓ Built build/ios/iphoneos/Runner.app (60.0MB)` (release, eszközre, aláírás
  nélkül). **Ez az első valaha mért bizonyíték arra, hogy a projekt lefordul
  iOS-re.** Az **1. futás még elhasalt** — az `ios/Podfile` miatt (lásd a fenti
  táblázatot). Vagyis a pipeline pontosan azt tette, amiért épült: az első
  futásából derült ki egy valódi, addig láthatatlan hiba.
- **A `codemagic.yaml` viszont MÉG NEM futott élesben:** az aláírt
  TestFlight-feltöltéshez Apple Developer Program tagság kell ($99/év), az pedig
  még nincs meg. A Codemagic workflow-je a hivatalos sémákból készült, de élesben
  igazolatlan.
- A **Codemagic Xcode-verzió** szándékosan `latest` — kiadás előtt érdemes
  konkrét verzióra szorítani, hogy a build reprodukálható legyen.
- Az **ikon-javítás** méréssel és szemrevételezéssel igazolt (alfa nincs, a kép
  változatlan), de **Apple-oldali validáción** még nem esett át.
- **A függőségek útja MÉRVE eldőlt (a CI első futása, 2026-09-22):** a projekt
  **Swift Package Manager**-t használ — a napló szerint *„All plugins found for
  ios are Swift Packages"*, és húsznál több csomag jön SPM-mel (Firebase,
  GoogleSignIn, GoogleMobileAds, gRPC, abseil…). A Podfile-t ezért **távolítsd
  el** (megtörtént): CocoaPods integrációt kényszerített rá, és a build elhasalt
  (`The sandbox is not in sync with the Podfile.lock`). **Ez a hiba nem
  feltételezésből, hanem az első CI-futás naplójából derült ki** — pontosan ezért
  épült a pipeline.
