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

### Ingyenes út a telefonra — ✅ **VÉGIG MŰKÖDÖTT, mérve (2026-09-22)**

A CI aláírás nélküli `.ipa`-t ad (`HUHS-ios-unsigned-ipa` artefakt), a
**Sideloadly** pedig a **saját ingyenes Apple ID-dal aláírja és USB-n felrakja**.
Ez a [Habr-cikk](https://habr.com/en/articles/1058788/) lánca — és **élesben
lefutott** egy iPhone SE (2. gen), **iOS 26.7** készüléken. A Sideloadly saját
adatbázisa igazolja, hiba nélkül:

```
name             = Hungarian Hardstyle          last_error   = (üres)
final_bundle_id  = hu.hungarianhardstyle.app.JQPJ793V65       failures     = 0
version          = 1.0.0                        known_ttl    = 7 nap
telepítve        = 2026-09-22 14:55:15          auto-refresh = 96 óra múlva
```

#### ⚠️ A KÉT DOLOG, AMI TÉNYLEG KELL (ezek nélkül fél nap elmegy vele)

1. **iTunes (web) ÉS iCloud (web) telepítve legyen** — a Sideloadly ezt
   kifejezetten megköveteli ([sideloadly.io](https://sideloadly.io/), „Before you
   install"). **Az illesztőprogram önmagában NEM elég:** az `Apple Mobile Device
   Support`-tal a Sideloadly ugyan **látja** a készüléket a listában, de a
   számláló **0** marad, a **`Start` letiltva**, és a hitelesítés (anisette) el
   sem indul — mert ahhoz az iCloud kell.
   ```
   winget install --id Apple.iTunes -e      # iTunes (web) 12.13.11.1
   winget install --id Apple.iCloud -e      # „iCloud (Legacy)" 7.21
   ```
   **Utána indítsd újra a Sideloadly-t** — a függőség-ellenőrzés indításkor fut.
2. **A profil megbízása a telefonon** — enélkül az app nem indul el:
   *Beállítások → Általános → **VPN és eszközkezelés*** → a **„Fejlesztői app"**
   szakaszban az Apple ID sorára koppintva → **megbízása** → megerősítés.
   A sor a megbízás ELŐTT **„Nem megbízható"**, utána **„Megbízható"**.

#### A fejlesztői mód (iOS 16+ óta kötelező) — GUI nélkül, parancssorból

A kapcsoló csak azután jelenik meg, hogy egy fejlesztői aláírással készült app már
felkerült a készülékre (tyúk-tojás). **Nem kell hozzá iCareFone/3uTools** — a
`pymobiledevice3` elvégzi (a telefon legyen **feloldva** és a gép **megbízva**):

```
pymobiledevice3 amfi reveal-developer-mode    # megjeleníti a kapcsolót
pymobiledevice3 amfi developer-mode-status    # false -> true
```
Utána a telefonon: *Beállítások → Adatvédelem és biztonság → Fejlesztői mód* →
be → kód → újraindítás → megerősítés. (A `reveal` **megjeleníti**, a `true`-ra
állítás a **tulajdonos koppintása** — az Apple így kéri a beleegyezést.)

#### A négy lépés, ami végül lefutott

1. **Illesztőprogram:** `winget install --id Apple.AppleMobileDeviceSupport -e`
2. **Fejlesztői mód** a fenti CLI-vel, majd bekapcsolás a telefonon
3. **IPA letöltése:** GitHub → **Actions** → a legutóbbi **zöld** futás →
   **Artifacts → `HUHS-ios-unsigned-ipa`** (14 napig marad meg), **vagy** a gépen:
   `gh run download <run-id> --name HUHS-ios-unsigned-ipa --dir build/ios-ipa`
4. **Sideloadly:** telefon USB-n + feloldva → az `.ipa` behúzása → az Apple ID
   beírása → **Start** → majd a **profil megbízása** a telefonon (fent)

**⚠️ Az ingyenes Apple ID korlátai — ezek tények, nem hibák:**

| Korlát | Mit jelent a gyakorlatban |
|---|---|
| Az aláírás **7 napig** érvényes | utána újra át kell húzni a Sideloadly-val |
| Egyszerre **max. 3 app** | a Sideloadly az ingyenes fióknál **utótagot** tesz a bundle ID-ra (`hu.hungarianhardstyle.app.JQPJ793V65`). Az utótag viszont **állandó** (az Apple ID-hoz kötött), ezért a frissítés **valódi frissítés** — mérve: ugyanaz a `final_bundle_id`, **1 telepítés**, `last_error` üres, és az **app-adatok megmaradnak** (a debug token is) |
| Egyes **entitlementek** nem elérhetők | a **push értesítés** (`aps-environment`) biztosan nem megy így — nekünk amúgy sincs még |
| **App Check** | ✅ **MEGOLDVA, mérve** — a build a **debug szolgáltatót** használja, a token a Firebase Console-ban regisztrálva van; az éles App Attest/DeviceCheck **nem kell** hozzá. Részletek lentebb |
| **Helyi fájlok** | a „Megvásárolt zenéim" letöltései az újratelepítésnél elvesznek (új bundle ID) |

#### App Check a sideloadolt builden — ✅ **MEGOLDVA, mérve (2026-09-22)**

A gond az volt, hogy a `firebase_app_check` iOS-en alapból **App Attest / DeviceCheck**
alapú, és mindkettő **fizetős** Apple-fiókot kér (DeviceCheck: `keyId` + `.p8` kulcs;
App Attest: `teamId` + entitlement). Ingyenes fiókkal egyik sem elérhető — vagyis az
App Check-kel védett callable-ok (`enforceAppCheck: true`) elutasították volna a kérést.

**A megoldás a beépített debug szolgáltató**, ami ingyenes:

1. a build `--dart-define=HUHS_APP_CHECK_DEBUG_IOS=true`-vel készül (a CI is így építi),
   a `lib/main.dart` pedig ilyenkor `AppleAppCheckProvider.debug()`-ot ad meg az
   `appAttestWithDeviceCheckFallback` helyett — az **Android ága változatlan**;
2. az app **első indításakor maga generál** egy debug tokent; ugyanez a token a
   készüléken a `Library/Preferences/<bundle>.plist` `GACAppCheckDebugToken` kulcsában
   is ott van — **innen olvastuk ki** (`pymobiledevice3` + AFC, mert a napló
   `<private>`-ként maszkolja);
3. a tokent a Firebase Console-ban regisztráltuk:
   **App Check → Apps → az iOS sor `⋮` → Manage debug tokens → Add debug token.**

**A mért bizonyíték (nem feltételezés):**

| Mit mértem | Hogyan | Eredmény |
|---|---|---|
| a debug provider **aktív** a telepített buildben | `pymobiledevice3 syslog live -pn Runner` indítás közben | `Firebase App Check Debug Token: <private>` |
| a token a **mi app ID-nkhoz** tartozik | ugyanaz a napló | `GACAppCheckDebugToken…projects_hungarian-hardstyle_apps_1:1030187737487:ios:0ceb5a9685b34b5f78ebfa` |
| a csere **élesben működik** | `POST …/apps/<app-id>:exchangeDebugToken?key=<API_KEY>`, az `API_KEY` a `GoogleService-Info.plist`-ből | **HTTP 200**, valódi App Check token, `ttl 3600s` |
| a **régi hiba eltűnt** | ugyanaz a napló | nincs többé `AppCheck failed … exchangeDeviceCheckToken` |

**EZ VOLT A VALÓDI OKA A „NEM TÖLTENEK A PROFILOK / ÜRES A RANGLISTA" JELZÉSNEK
(mérve).** A `community_service.dart` a profilokat, az átvett DJ-adatlapokat és a
ranglistát **App Check-kel védett** callable-okból kéri (`getPublicProfile`,
`getPublicProfiles`, `getClaimedArtistsForUser`, `getAchievementLeaderboard`,
`getPublicAchievement` — mind `enforceAppCheck: true`). Amíg az App Check elbukott,
ezek **HTTP 401**-gyel tértek vissza, ezért a képernyők üresek maradtak. Kétoldalú
éles mérés a regisztrált debug tokennel:

| hívás | App Check token nélkül | tokennel |
|---|---|---|
| `getAchievementLeaderboard` | **401** | **200** + valódi ranglista (`Benyo1982`, 768 pont) |
| `getPublicProfile` | **401** | **404** — a kapun **átjutott**, már csak a nem létező uid-ot jelzi |

A hiba tehát **nem a kliensben és nem a szerverben** volt, hanem az **attestation
hiányában** — és pont ezért nem lehetett Androidon reprodukálni (ott a Play Integrity
már regisztrálva van).

**⚠️ A „Not registered" állapot NEM blokkol.** Az App Check → Apps listában az iOS sor
`Attestation providers` oszlopa **`–`**, a státusz **„Not registered"** — ez az **éles**
attestation-re vonatkozik, a debug tokenes útra **nem**. Ezért a sideloadolt
teszteléshez **nem kell** sem fizetős fiók, sem DeviceCheck-kulcs. Az éles App Attest
majd a TestFlight-körben kerül be (a tulajdonos `teamId`-jével + entitlementtel).

**⚠️ EZ A TESTFLIGHT-KÖR ELŐTT KÖTELEZŐ LÉPÉS (különben megismétlődik a hiba).**
A produkciós build — helyesen — **nem** kapja meg a debug zászlót, ezért App
Attest-tel/DeviceCheck-kel próbál attestálni, az iOS apphoz viszont **nincs
regisztrálva szolgáltató** a Firebase Console-ban (a sor `Attestation providers`
oszlopa `–`). Ha így menne fel a TestFlightra, az `enforceAppCheck: true`
callable-ok (**közösségi profilok, ranglista, átvett DJ-adatlapok**) **HTTP 401**-et
adnának — pontosan az a hiba, amit itt feltártunk. A szolgáltatót tehát az
Apple-tagság megszerzése **után azonnal** regisztrálni kell (DeviceCheck:
`keyId` + `.p8` kulcs, vagy App Attest: `teamId` + entitlement).

**⚠️ A debug token a telepítéshez kötődik.** Ha a container **törlődik** (eltávolítás +
újratelepítés, nem frissítés), az app **új** tokent generál — azt újra regisztrálni kell.
Frissítésnél (mint nálunk is) az app-adatok és így a token **megmaradnak**.

**Ez tehát tesztelésre való, nem terjesztésre.** A végleges út a **TestFlight**
(fizetős tagsággal): nincs 7 napos lejárat, nincs kábel, a tesztelőket meghívóval
lehet hozzáadni, és az App Attest is működik.

> ⚠️ **A Sideloadly-úthoz NEM kell (és nem is szabad) `pod install`:** ez a projekt
> Swift Package Manager-t használ — egy Podfile elhasalását már megmértük.

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
2. **Reklám az iOS-en — és a mért AdMob-korlát (2026-09-22).** Az `Info.plist`-ben a
   **Google teszt** App ID van (`ca-app-pub-3940256099942544~1458002511`), és az
   `ad_unit_plan.dart` iOS-en üres azonosító esetén a **Google hivatalos
   teszt-egységeire** esik vissza — ezért **a reklám megjelenik** (teszt-reklámként)
   AdMob-regisztráció nélkül is. Az **AdMob konzol Kezdőlapja** (mérve) viszont
   megmondja a valódi korlátot: *„**Az alkalmazásboltra mutató link** — A hirdetések
   megjelenítése előtt az alkalmazásokat **jóvá kell hagyni**. Kapcsolja össze egy
   alkalmazásbolttal, hogy felülvizsgálatot kérjen."* A fiók-ellenőrző lista **3/4**-en
   áll (Fizetések ✅, Hirdetési egységek ✅; az alkalmazás–applikáció-áruház kapcsolat
   hiányzik). Vagyis az iOS **valódi** reklámbevétele **kettős kapu** mögött van:
   (1) az app legyen fent az App Store-ban (→ $99 tagság), (2) az AdMob hagyja jóvá a
   store-linket. **Ezért most a teszt-egységek a helyesek:** a valódi iOS egységek
   bevezetése csak az App Store-os megjelenés után van értelme — addig a valódi
   egységek **egyáltalán nem** szolgálnának ki hirdetést, ami **rosszabb** a
   teszt-reklámnál.
   **✅ ÁLLAPOT (2026-09-22):** az iOS app és a két egység **létrejött** az AdMobban,
   az azonosítók be vannak kötve (lásd lentebb). **Ha a banner vagy a jutalmazott
   mégsem jelenik meg**, az nem kódhiba, hanem ez a **jóváhagyási kapu** — ilyenkor
   a `gh variable delete HUHS_ADMOB_BANNER_ID_IOS` (és `…_REWARDED_ID_IOS`)
   visszaállítja a teszt-egységeket, amíg az AdMob jóvá nem hagyja az appot.
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

### A valódi iOS reklám-azonosítók — ✅ **BEÁLLÍTVA (2026-09-22)**

| Érték | Mi az | Hol él |
|---|---|---|
| `ca-app-pub-7714662594685378~6550697484` | AdMob **iOS app ID** | `ios/Runner/Info.plist` → `GADApplicationIdentifier` |
| `ca-app-pub-7714662594685378/5511193968` | **Banner** („HUHS banner") | GitHub-változó `HUHS_ADMOB_BANNER_ID_IOS` **és** `codemagic.yaml` |
| `ca-app-pub-7714662594685378/7238016636` | **Jutalmazott** („HUHS jutalmazott") | GitHub-változó `HUHS_ADMOB_REWARDED_ID_IOS` **és** `codemagic.yaml` |

A két **egység**-azonosító szándékosan **nem** a Dart-kódban él: a GitHub Actions
GitHub-változóból (`vars.*`), a Codemagic a `codemagic.yaml`-ból adja át
`--dart-define`-nal. Így a sideloadolt teszt-build és a TestFlight-build külön
állítható, és a `test/ios/ios_ci_config_test.dart` **őrzi**, hogy a **valódi** app ID
bekerüljön, a Google teszt app ID viszont **ki ne** szivárogjon. Az **Android**
app ID (`…~1123886696`) és az Android egységek **változatlanok** — egy kiadó
(`pub-7714662594685378`), két külön app.

A `.github/workflows/ios-unsigned-check.yml` mindkettőt átadja `--dart-define`-nal, a
`test/ios/ios_ci_config_test.dart` pedig **őrzi**, hogy ne lehessen beégetni őket, és
hogy a debug App Check-szolgáltató **csak** a sideloadolt buildbe kerüljön.
Beállítatlanul **üres string** → a Google teszt-egységei (ez a mai viselkedés).

**⚠️ A sorrend nem mindegy.** A konzol szerint *„a hirdetések megjelenítése előtt az
alkalmazásokat jóvá kell hagyni"*, és a fiók-ellenőrző lista a **store-link** hiánya
miatt **3/4**-en áll. Ezért a **valódi egységek bekapcsolása csak az App Store-os
megjelenés + AdMob-jóváhagyás után** van értelme: addig a teszt-egységek mutatnak
hirdetést, a valódiak **semmit**. Visszaváltás egy paranccsal:
`gh variable delete <név>`.

**⚠️ Ezért a sideloadolt build `HUHS_ENABLE_TEST_ADS=true`-vel épül** (a GitHub
Actions adja át). Az AdMob-jóváhagyásig a valódi iOS egységek **nem töltenek**, és
ilyenkor nemcsak a banner marad üres, hanem a **jutalmazott feloldás el sem indul**
(a `RewardedAd.load` hibára fut, és a felület *„Most nincs elérhető reklám"* /
*„Nem sikerült betölteni a reklámot"* üzenetet adja). A teszt-zászló a Google
**teszt**-egységeit használja (azok mindig töltenek), **és** átengedi a
hozzájárulás-kaput is (`prepareAdConsent`/`canRequestAds` kimarad) — iOS-en ez friss
telepítésnél számít, mert az UMP/ATT űrlap állapota blokkolhatja a kérést.
A **TestFlight**-build ezt a zászlót szándékosan **nem** kapja meg. Ez **nem** a
sideload hibája: ugyanez történne egy aláírt buildben is, amíg az AdMob nem hagyja
jóvá az appot.

#### ⚠️ ÚJ JUTALMAZOTT EGYSÉG = AZ SSV-VISSZAHÍVÁSI URL KÖTELEZŐ (mérve, 2026-09-22)

**A tünet:** a jutalmazott teszt-reklám **lefutott**, de a termék **nem nyílt meg**.

**A mért gyökér — nem a kliens és nem a reklám:** a feloldás kizárólag a
**szerveroldali visszaigazoláson** múlik. A kliens `waitForAdUnlock`-kal várja, hogy
a `label_ad_unlocks` rekord aktív legyen, azt viszont **csak az AdMob aláírt
SSV-visszahívása** hozza létre (`functions/index.js` → `admobRewardedSsv` → aláírás
ellenőrzése a `gstatic.com/admob/reward/verifier-keys.json` kulcsaival). A kliens
`onUserEarnedReward` visszahívása **csak egy flaget állít** — a szervert nem
értesíti.

**A bizonyíték (`npx firebase functions:log --only admobRewardedSsv`):** a végpontot
**összesen négyszer** hívták valaha, utoljára **2026-09-21 22:46**-kor — a 2026-09-22-i
iOS-teszt idején **egyetlen hívás sem érkezett**. A végpont maga él és helyes
(közvetlen próba: `HTTP 200 "validated"` a validátori ágon, `HTTP 400` aláírás nélküli
tranzakcióra).

**A gyökér oka:** az SSV-visszahívási URL az AdMobban **hirdetési egységenként**
állítandó be. Az új iOS „HUHS jutalmazott" egységen ez **nincs beállítva** (a régi
hívások a korábban beállított egységhez tartoznak). Ezért az AdMob sosem hívja a
szervert, a rekord nem jön létre, és a felület *„A reklám lefutott, de a feloldás nem
érkezett meg."* üzenetet adja.

**A beállítandó URL (egyszer, minden jutalmazott egységen):**

```
https://us-central1-hungarian-hardstyle.cloudfunctions.net/admobRewardedSsv
```

AdMob → **Hirdetési egységek** → a jutalmazott egység szerkesztése →
**Szerveroldali ellenőrzés (SSV)** → a fenti URL. Az **„Egyéni adatok" mező
maradjon ÜRES** — a `custom_data`-t a kliens küldi `setServerSideOptions`-szal,
a konzolba írt érték csak elrontaná a próbát.

**⚠️ KÖZBEN A SAJÁT KEZELŐNK HIBÁJA IS ELŐKERÜLT — javítva (2026-09-22).**
Az AdMob konzol *„URL ellenőrzése"* gombja **400-at** kapott
(*„A szerver a következő HTTP-válaszkódot küldte: 400"*). A napló megmondta,
miért: `{"reason":"missing reward data"}` — a kezelő ezt az ágat az
**aláírás-ellenőrzés UTÁN** futtatta, a validátor viszont **valódi aláírással, de
`custom_data` nélkül** hív. Ezért a `!customData` ág 400-at adott, és **a konzol
soha nem tudta volna érvényesíteni az URL-t** — a beállítás így bizonytalan.

A javítás: a „nincs `custom_data`" eset mostantól **próba** (`200 "validated"`),
**jóváírás nélkül** — az aláírást továbbra sem lehet megkerülni, mert a döntés az
aláírás-ellenőrzés **után** születik. A döntés a tiszta
`functions/admob-ssv-plan.js`-be került (`classifyVerifiedSsvCallback`,
`decodeSsvCustomData`), a `functions/admob-ssv-plan.test.cjs` **8/8** teszteli —
benne forrás-lint, ami **tiltja** a `missing reward data` 400-as ág visszatérését,
és kimondja, hogy jóváírni csak ellenőrzött aláírással szabad. A függvény
telepítve (`Deploy complete!`), a végpont mérve: aláírás nélkül
`200 "validated"`, `transaction_id`-vel aláírás nélkül `400`.

**✅ A NYITOTT KÉRDÉS ELDŐLT (mérve, 2026-09-22): a TESZT-reklám NEM küld SSV-t.**
Az URL beállítása **és** a konzol sikeres érvényesítése után a jutalmazott teszt
lefutott, a szerver viszont **egyetlen visszahívást sem kapott**:

```
node tools/check-ssv-state.mjs --hours 6
  admob_reward_transactions: 29 összesen, ebből a szűrésre 0
  label_ad_unlocks:          22 összesen, ebből a szűrésre 0
  => NINCS visszahívás a szűrt időszakban: az AdMob nem hívta a végpontot.
```

A legfrissebb tranzakció **2026-09-21 22:46** — a mai iOS-tesztekből **egyetlen
rekord sem** keletkezett. Vagyis a jutalmazott feloldás **teszt-reklámmal nem
próbálható**: csak éles reklámmal, azaz az AdMob-jóváhagyás után. Ez **nem
kódhiba** — a Google teszt-kreatívjai egyszerűen nem gyakorolják az SSV-utat.

**Az eszköz erre: `node tools/check-ssv-state.mjs`** (`--hours N`, `--release ID`,
`--require`, `--self-test` 4/4). Egy paranccsal megmondja, melyik eset áll fenn:
(a) meg sem érkezett a visszahívás → AdMob-beállítás a hibás, (b) megérkezett, de
**későn** — a kliens ugyanis csak **20 másodpercig** vár (`waitForAdUnlock`), ezért
egy lassú SSV mellett a felhasználó hiába nézte meg a reklámot, vagy
(c) megérkezett és jóváírt → a hiba a kliens oldalán van.

**⚠️ ÉS A MÉLYEBB TANULSÁG (a Google saját ajánlása):** az
[iOS SSV-dokumentáció](https://developers.google.com/admob/ios/ssv) szerint
*„For a good user experience, it is recommended to **reward the user immediately
using the client-side callback** while performing validation on all rewards upon
receiving server-side callbacks."* A mostani felépítés ennek az **ellenkezője**: a
jóváírás **kizárólag** a szerverre vár, ezért ha az SSV késik, elmarad vagy nincs
beállítva, a felhasználó **megnézte a reklámot és mégsem kap semmit**. Ez éles
felhasználóknál is előfordulhat (hálózat, AdMob-kimaradás). A javítás iránya
**tulajdonosi döntés**, mert a szigorú kapu egyben visszaélést is fog: ha a kliens
azonnal jóváírhat, egy módosított kliens reklám nélkül is feloldhat.

**⚠️ Ismert korlát (mérve, 2026-09-22):** az AdMob konzol **Alkalmazások**
mikro-frontendje a CDP-vezérelt Chrome-profilban **nem indul el** (a Kezdőlap
renderel, az Alkalmazások útvonal nem; nincs JS-hiba és nincs bukott kérés) — ezért
az app + egységek létrehozása **kézi lépés** a tulajdonos böngészőjében.

#### A kész csomag ellenőrzése — `tools/verify-ios-ipa.mjs` (mérve, 2026-09-22)

A rossz reklám-azonosító **némán** jelentkezik: az app elindul, minden képernyő
betölt, csak épp nem szolgál ki hirdetést. Ezt egy sikeres build és egy tiszta
`flutter analyze` **sem** jelzi. Ezért van egy eszköz, ami a **kész csomag byte-jait**
méri — Xcode nélkül, Windows-on is:

```
Copy-Item build/ios-ipa/Runner-unsigned.ipa build/ipa.zip
Expand-Archive build/ipa.zip -DestinationPath build/ipa -Force
node tools/verify-ios-ipa.mjs build/ipa/Payload/Runner.app
```

**A mért eredmény a valódi csomagon (GitHub Actions run `35744632628`):**

```
OK    AdMob app ID        ca-app-pub-7714662594685378~6550697484  <- Info.plist
OK    banner egyseg       ca-app-pub-7714662594685378/5511193968  <- Frameworks\App.framework\App
OK    jutalmazott egyseg  ca-app-pub-7714662594685378/7238016636  <- Frameworks\App.framework\App
OK    Google TESZT app ID  (nincs benne)
```

Vagyis a `--dart-define` **tényleg átért** a befordított Dart-kódba, az app ID pedig
az `Info.plist`-be került. **A viszonyítási alap** ugyanez az eszköz a javítás
**előtti** csomagon: mind a négy ellenőrzés elhasalt, és a Google teszt app ID-t az
`Info.plist`-ben találta meg — vagyis az eszköz nem „mindig zöld". Az `--self-test`
**5/5 OK**.

**Két mód (2026-09-22 óta):**

- **`--test-ads`** — a **sideloadolt** csomag ellenőrzése: a Google **teszt**-egységeit
  várja (ezt a build szándékosan használja, lásd `HUHS_ENABLE_TEST_ADS`), és azt,
  hogy a tiltott teszt **app** ID ne kerüljön a csomagba. A GitHub Actions ezt futtatja.
- **kapcsoló nélkül** — a **produkciós** csomag ellenőrzése: a **valódi** iOS
  egységeket várja. A Codemagic TestFlight-lépése ezt futtatja a kész `.ipa`-n.

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
| `[FirebaseCore][I-COR000008] The project's Bundle ID is inconsistent` | a Sideloadly ingyenes fióknál **utótagot** tesz a bundle ID-ra (`hu.hungarianhardstyle.app.JQPJ793V65`), a plist viszont `hu.hungarianhardstyle.app`-t ír. **Ártalmatlan**: a Firebase az app **ID-t** a plistből veszi (ezért megy az App Check is), és a naplóban mért módon minden szolgáltatás elindul. TestFlightnél (azonos bundle ID) meg sem jelenik |
| `AppCheck failed … exchangeDeviceCheckToken` | a build **éles** attestationt próbál a debug helyett → hiányzik a `--dart-define=HUHS_APP_CHECK_DEBUG_IOS=true` (a CI-ben benne van), vagy a debug token nincs regisztrálva a Console-ban |
| a Google-bejelentkezés elhasal iOS-en | elég a becsatolt `GoogleService-Info.plist` (`CLIENT_ID`) **és** a `REVERSED_CLIENT_ID` URL-séma: a `google_sign_in_ios` 5.9.0 a **plistből** olvassa a kliens-azonosítót, ezért külön `GIDClientID` **nem kell**. Ellenőrzés: `node tools/attach-ios-firebase.mjs --check` |
| az AdMob konzol **Alkalmazások / Hirdetési egységek** oldala üresen renderel | a héj (Angular) **és a Kezdőlap** renderel, az `Alkalmazások` útvonal viszont nem — mérve: **nincs JS-hiba, nincs bukott kérés, nincs szolgáltató-munkás, nincs cache**. Az oldalsáv `Alkalmazások` pontja ráadásul **almennüt nyit** (`>` chevron), nem navigál. Az egység-azonosítókat ezért a **tulajdonos böngészőjében** kell lekérni (ott rendben megjelenik) |

---

## 7. ŐSZINTE KORLÁTOK

- **A TELEPÍTETT BUILD MŰKÖDIK A KÉSZÜLÉKEN (2026-09-22, mérve):** a legfrissebb
  CI-artefakt (`772ae708` futása) **frissítésként** felment egy iPhone SE (2. gen),
  iOS 26.7 készülékre, és a `pymobiledevice3 developer dvt launch` + `screenshot`
  szerint az app elindul és **tartalmat tölt**: főoldal, „Legfrissebb hírek" kártya,
  profilkép, a rádiósáv (`REAL HARDSTYLE FM / Élő adás`) és az alsó öt lap. A Firebase
  inicializálódik (FCM 11.15.0), és **App Check hiba nincs**. Ez az első **mért**
  bizonyíték arra, hogy az iOS-build a készüléken nem csak lefordul, hanem
  **használható**. (Amit ez nem bizonyít: a képernyőnkénti viselkedést — lásd a
  korlátokat.)
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
- **AMI A KÉSZÜLÉKEN MÉG NINCS MEGMÉRVE (őszintén):** a képernyőnkénti viselkedés —
  a **billentyűzet-elrejtő gomb** a chatokban, a privát üzenetek, a **DJ-adatlap
  átvétele/szerkesztése**, a **közösségi profilok** és a **ranglista** betöltése —,
  továbbá a **háttér-hanglejátszás zárképernyőn** (az `audio_service` iOS-en az
  `AVAudioSession`-t használja, ami más, mint az Android zenei fókusz-kezelése), a
  **Face ID**, a **Google-bejelentkezés** és a **reklámok** (iOS-en egyelőre a Google
  **teszt** egységei mennek, mert az AdMob iOS app még nincs regisztrálva). Ezek
  **koppintást** igényelnek a készüléken — a `pymobiledevice3` indítani, naplózni és
  képernyőképet készíteni tud, **koppintani nem**.
