# App Store-beadás — az iOS megjelenés csomagja (mérve, 2026-09-22)

> **MIÉRT EZ A FÁJL:** az iOS-szál **funkcionálisan kész** — a sideloadolt build
> egy iPhone SE (2. gen) készüléken mérve működik (rádió, zene zárképernyőn,
> közösségi profilok, ranglista, DJ-adatlap, Touch ID, Google-bejelentkezés,
> jutalmazott feloldás, billentyűzet-gomb). Ami **hátra van**, az **nem kód**,
> hanem **Apple-jóváhagyás és űrlapok** — ez a fájl ezeket szedi össze egy helyre,
> hogy a `$99`-os tagság megérkezésekor semmi ne maradjon ki.
>
> A technikai úthoz (CI, aláírás, Sideloadly, TestFlight) lásd:
> `docs/IOS-CI-TESTFLIGHT.md`. **Ez** a fájl a **beadási anyag**.

---

## 0. Ami a mérés szerint MÁR kész (nem kell vele foglalkozni)

| Mit | Állapot | Bizonyíték |
|---|---|---|
| Bundle ID | `hu.hungarianhardstyle.app` (egyezik az Android `applicationId`-jával) | `test/ios/ios_ci_config_test.dart` |
| Firebase iOS app + plist | kész, az Xcode-projektbe kötve | `node tools/attach-ios-firebase.mjs --check` |
| App Check (sideload) | debug token regisztrálva, a callable-ok 200-at adnak | `IOS-CI-TESTFLIGHT.md` 1. szakasz |
| 1024-es ikon | alfa-csatorna nélkül (az App Store elutasítaná) | ugyanott, méréssel |
| Háttér-hang | `UIBackgroundModes: audio` | Info.plist |
| ATT + Face ID szövegek | `NSUserTrackingUsageDescription`, `NSFaceIDUsageDescription` | Info.plist |
| Fordulás | a GitHub Actions zöld (`✓ Built … Runner.app`) | CI-napló |
| Adatvédelmi nyilatkozat **URL** | **`https://hungarianhardstyle.hu/adatvedelmi-nyilatkozat/`** (3025. oldal, élőben ellenőrizve) | WP REST `pages` |
| ÁSZF URL | `https://hungarianhardstyle.hu/altalanos-szerzodesi-feltetelek-aszf/` | ugyanott |
| Kapcsolat e-mail | `info@hungarianhardstyle.hu` | a ház címe |

---

## 1. App Store Connect — az app rekord mezői

| Mező | Érték |
|---|---|
| Név (30 karakter) | `Hungarian Hardstyle` |
| Alcím (30) | `Hardstyle & Hardcore egy helyen` |
| Bundle ID | `hu.hungarianhardstyle.app` |
| SKU | `huhs-ios-001` |
| Elsődleges nyelv | magyar (`hu`) |
| Kategória | elsődleges: **Zene**; másodlagos: **Szórakozás** |
| Korhatár | lásd a 3. pontot (a kérdőív dönti el) |
| Adatvédelmi szabályzat URL | `https://hungarianhardstyle.hu/adatvedelmi-nyilatkozat/` |
| Támogatási URL | `https://hungarianhardstyle.hu/impresszum/` (vagy a főoldal) |
| Marketing URL (opcionális) | `https://hungarianhardstyle.hu/` |
| Copyright | `Hungarian Hardstyle` |

**Kulcsszavak (100 karakter, vesszővel):**
`hardstyle,hardcore,radio,magyar,dj,események,kiadványok,zene,community,chat`

**Leírás (vázlat, magyar):** a rádió (élő adás), a magyar hardstyle/hardcore
kiadványok, DJ-adatlapok, események, közösségi chat, kvízek és szavazások egy
appban. A zene-vásárlás **Androidon** elérhető (Google Play), iOS-en ez még nem —
ezt a **4. pont** szerint kell megfogalmazni az elbírálóknak.

---

## 2. App Privacy (adatvédelmi kérdőív) — a tényleges SDK-kból

A válaszok alapja a `pubspec.yaml` **mért** függőséglistája, nem feltételezés:

| SDK | Mit gyűjt | Apple-kategória | Összekapcsolható a felhasználóval? | Cél |
|---|---|---|---|---|
| `firebase_auth` | e-mail cím, felhasználói azonosító | Contact Info (Email), Identifiers (User ID) | **Igen** | App Functionality |
| `firebase_auth` (Google Sign-In) | név, e-mail | Contact Info (Name, Email) | **Igen** | App Functionality |
| Firestore (profil, chat, DJ-adatlap) | név, profilkép, bemutatkozás, **felhasználói tartalom** (chat, hozzászólás) | User Content, Contact Info | **Igen** | App Functionality |
| `firebase_messaging` | eszköz-token | Identifiers (Device ID) | **Igen** | App Functionality |
| `google_mobile_ads` | hirdetési azonosító, hirdetési adatok | Identifiers (Device ID), Usage Data (Advertising Data) | **Nem** (harmadik fél hirdetés) | Third-Party Advertising |
| `image_picker` + Cloudinary | a feltöltött képek | User Content (Photos) | **Igen** | App Functionality |
| `local_auth` | biometrikus adat **nem hagyja el az eszközt** | — (nem gyűjt) | — | — |
| `shared_preferences` | helyi beállítások | — (nem gyűjt) | — | — |

**Amit NEM használunk (ezért NEM kell bejelenteni):** analitika (nincs
`firebase_analytics`), összeomlás-jelentés (nincs `firebase_crashlytics`),
helyadat (nincs geolocation), névjegyzék, egészségadatok, böngészési előzmény.

**Tracking (ATT):** az AdMob miatt az app **kérheti** a követés engedélyét
(`NSUserTrackingUsageDescription` bent van) — ezért a kérdőívben a
**„Used to Track You"** bejelölendő a hirdetési azonosítónál. Ha a tulajdonos
inkább nem kérné az engedélyt (kevesebb bevétel, egyszerűbb kérdőív), az egy
**külön döntés** — a kód ehhez nem változik, csak az AdMob-konfiguráció.

---

## 3. Korhatár-kérdőív (a tartalom dönti el)

A mérés szerint az app **felhasználói tartalmat** tartalmaz (chat, hozzászólás,
profil), és **nyílt webes tartalmat** nyit meg (hírek, YouTube, Spotify):

| Kérdés | Válasz |
|---|---|
| Cartoon/Fantasy/Realistic Violence | Nincs |
| Profanity or Crude Humor | **Előfordulhat** (felhasználói tartalom) |
| Horror/Fear Themes | Nincs |
| Medical/Treatment Information | Nincs |
| Alcohol, Tobacco, or Drug Use | **Előfordulhat** (események, szövegek) |
| Mature/Suggestive Themes | Nincs |
| Simulated Gambling | Nincs |
| Unrestricted Web Access | **Igen** (beépített böngésző + külső linkek) |
| User-Generated Content | **Igen** |

**A várható eredmény: 16+** (a felhasználói tartalom és a nyílt web miatt).
⚠️ Ez **nem** választható szabadon: a kérdőív eredménye kötelező.

---

## 4. Amit az ELBÍRÁLÓNAK meg kell írni (review notes)

Ez azért fontos, mert az app **tartalmaz zene-vásárlást — de csak Androidon**:

```text
A zenevásárlás (Google Play Billing) ebben az iOS-verzióban NEM érhető el, ezért
az app iOS-en nem is mutat vásárlási gombot és nem irányít külső fizetésre:
a „Megvásárolt zenéim" az iOS-en a reklámmal feloldott ingyenes tartalmakat
mutatja. Az iOS vásárlás (StoreKit) külön fejlesztés, ezért ebben a verzióban
szándékosan nincs.

Teszteléshez: a regisztráció e-mail címmel történik (bármely cím megadható),
a rádió és a nyilvános tartalmak bejelentkezés nélkül is elérhetők.
```

**Ez a kódban mérve is igaz:** a kiadvány-adatlap a **csak a store-ból
megtalált** termékeket rajzolja (`_products.any(...)` szűrő), iOS-en viszont
nincs StoreKit-termék, ezért **nincs vásárlási kártya** — vagyis nem sérül az
App Store 3.1.1 szabálya (digitális tartalom csak Apple-fizetéssel), és nincs
„halott gomb" sem. Ha valaha bekerül a StoreKit, ezt a bekezdést **át kell írni**.

---

## 5. Képernyőképek (kötelező méretek)

A projekt **iPhone + iPad** (`TARGETED_DEVICE_FAMILY = 1,2`), ezért **mindkettő**
kell:

| Eszköz | Felbontás | Honnan |
|---|---|---|
| iPhone 6.7" | 1290×2796 vagy 1320×2868 | a tulajdonos készülékéről nem ez a méret jön — **szimulátor vagy méretezés** kell |
| iPad 13" | 2064×2752 | ugyanaz |

**Amit érdemes megörökíteni (5-6 kép):** főoldal (kiemelt hírek), rádió sáv,
„Megvásárolt zenéim" lejátszó, DJ-adatlap (átvétel gombbal), chat, kvíz/szavazás.
⚠️ A képernyőképen **ne** látszódjon teszt-reklám (az elbíráló furcsállhatja) —
érdemes a `HUHS_ENABLE_TEST_ADS=false` builddel fotózni.

---

## 6. A TestFlight ELŐTT kötelező lépés (ez egyszer már megbukott)

Az éles build **nem** kapja meg a `HUHS_APP_CHECK_DEBUG_IOS` zászlót, ezért
App Attest-tel/DeviceCheck-kel próbál attestálni — az iOS apphoz viszont nincs
regisztrálva szolgáltató a Firebase Console-ban. Enélkül az
`enforceAppCheck: true` callable-ok (**közösségi profilok, ranglista, átvett
DJ-adatlapok**) **HTTP 401**-et adnak — pontosan az a hiba, amit a sideloadolt
körben feltártunk.

**A tagság megérkezése után azonnal:**

1. Firebase Console → App Check → Apps → az iOS sor `⋮` → **Attestation providers**;
2. válaszd a **DeviceCheck**-et (egyszerűbb): Apple Developer → Keys → új kulcs
   (DeviceCheck) → `keyId` + `.p8` + `teamId`;
3. vagy **App Attest** + `aps-environment`-hez hasonló entitlement;
4. utána ellenőrzés: `node tools/check-app-check.mjs` (ha van) vagy egy
   `getAchievementLeaderboard` hívás a TestFlight-buildből — **200** kell, nem 401.

---

## 7. Ami pénz vagy üzleti döntés (nem kód)

| # | Tétel | Mi kell hozzá |
|---|---|---|
| 1 | **Apple Developer Program** | **$99/év** — enélkül nincs TestFlight és nincs App Store |
| 2 | **StoreKit-vásárlás** | döntés + fejlesztés (a Google-termékek nem vihetők át; külön App Store-termékek kellenek) |
| 3 | **iOS reklámbevétel** | AdMob: az app–store kapcsolat jóváhagyása, ami az App Store-os megjelenést feltételezi |
| 4 | **Push (FCM/APNs)** | APNs-kulcs a Firebase-ben + `aps-environment` entitlement (csak fizetős fiókkal) |
| 5 | **Zárképernyős lejátszás mérése iOS-en** | a tulajdonos készüléke (a `pymobiledevice3` indítani/naplózni tud, koppintani nem) |

---

## 8. ŐSZINTE KORLÁTOK

- **A `codemagic.yaml` élesben még nem futott** (nincs $99 tagság) — a TestFlight
  út **nem** igazolt, csak a sideloadolt (aláírás nélküli + Sideloadly) út.
- Az **Adatvédelmi nyilatkozat** oldal a WordPressben él (3025. oldal); a benne
  szereplő adatkezelési leírás és a fenti App Privacy válaszok **egyezését** a
  beadás előtt érdemes átnézni (ha az oldal nem említi az AdMob-azonosítót, azt
  pótolni kell).
- A képernyőképek **mérete** nem hozható ki a tulajdonos telefonjáról (6.7" és
  iPad 13" kell) — szimulátor vagy méretezés szükséges.
- Az iOS **teszt-reklám** és a valódi egységek helyzete az AdMob-jóváhagyáshoz
  kötött (`IOS-CI-TESTFLIGHT.md`, 5.2 pont).
