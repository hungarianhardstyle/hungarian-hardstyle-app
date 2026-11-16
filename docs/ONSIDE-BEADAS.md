# Onside Store — az iOS app felvitele (tervezet + ellenőrző lista)

> **A tulajdonos kérése (2026-11-05):** *„van ez a oneside cucc iphone-ra, én ebbe a boltba akarom feltenni”*.
>
> Az **Onside** (onside.io) egy **alternatív iOS app-bolt** (EU, illetve Japán): a DSA
> szerint engedélyezett harmadik féltől származó piactér. A publikálás **nem** a saját
> panelen kezdődik, hanem az **App Store Connectben** — ez a lényeg, mert innen jön a
> build és az Apple jóváhagyása (notarizálás vagy teljes App Store review).
> Forrás: [Onside – How to Publish an App](https://docs.onside.io/console/publishing-your-app/how-to-publish-an-app).

---

## 1. A KEMÉNY előfeltételek (ezek nélkül nincs publikálás)

| Feltétel | Miért kell | Nálunk |
|---|---|---|
| **Fizetős Apple Developer Program** (99 USD/év) | a buildet App Store Connectbe kell feltölteni, és az Apple notarizálja/reviewolja | ❓ **ezt neked kell igazolnod** — TestFlight/Codemagic is ezt igényli |
| **App Store Connect → Users and Access → Alternative Distribution** → **Onside** piactér csatlakoztatása (marketplace token) | ez engedi, hogy az app alternatív piactéren megjelenjen | teendő (egyszeri) |
| Az app **kipipölése** az Alternative Distribution listában | ⚠️ **az új app NEM kerül be automatikusan** — minden új appot külön be kell jelölni | teendő minden új appnál |
| Apple **alternatív terjesztési feltételek** elfogadása | EU-s alternatív terjesztés; a **Core Technology Fee** csak az 1M első éves telepítés felett jár (kis appnál gyakorlatilag 0) | teendő |
| **Build feltöltése App Store Connectbe** | az Onside ezt szinkronizálja | a Codemagic workflow tudja (aláírt IPA + TestFlight), Apple API-kulcs kell hozzá |
| **Review Type = Notarization** (csak Onside) vagy **App Store** (mindkét bolt) | ezt az App Store Connectben kell átállítani az „App Review Information" alatt | teendő |
| **Adatvédelmi szabályzat URL** | kötelező | ✅ `https://hungarianhardstyle.hu/adatvedelmi-nyilatkozat/` |
| **ÁSZF URL** | a kereskedői/DSA adatokhoz | ✅ `https://hungarianhardstyle.hu/app-felhasznalasi-feltetelek/` |
| **Teszt-belépés az elbírálónak** (ha az app lényegéhez login kell) | notarizálásnál is kérik | ⚠️ az app vendégként is használható, de **adj meg egy teszt-fiókot** a review notes-ban |
| **EU-s felhasználó, iOS 17.4+** | az alternatív piactér csak EU-ban és új iOS-en működik | Magyarország ✅ |

---

## 2. A folyamat (a sorrend számít)

1. **Codemagic** (a `codemagic.yaml`-ban kész workflow): aláírt IPA + feltöltés **App Store Connectbe**.
   Ehhez a Codemagic környezetében az Apple API-kulcs / App Store Connect integráció kell.
2. **App Store Connect**: az app „App Review Information" → **Review Type = Notarization**
   (ha csak Onside-on akarod) vagy **App Store** (ha mindkettőn).
   → **Add for Review → Submit**.
3. **Onside Console** (console.onside.io): az app a jóváhagyás után megjelenik **„Missing Info"** állapotban.
4. Onside Console → az app → **Ár** és **Elérhető országok** beállítása → **Publish**.
5. **Onside moderáció** (legfeljebb 24 óra) → az app él a boltban.

**Ha a „Notarization" opció nem látszik:** App Store Connect → Users and Access →
Alternative Distribution → Onside sor → az app **kipipölése** → Save.

---

## 3. A kitöltendő szövegek (készen, másolhatóan)

Ezek ugyanazok, mint az App Store-beadásnál (`docs/APP-STORE-BEADAS.md`), hogy a két
boltban **ne mondjon ellent** egymásnak.

| Mező | Érték |
|---|---|
| Név (30) | `Hungarian Hardstyle` |
| Alcím (30) | `Hardstyle & Hardcore egy helyen` |
| Bundle ID | `hu.hungarianhardstyle.app` |
| SKU | `huhs-ios-001` |
| Elsődleges nyelv | magyar (`hu`) |
| Kategória | elsődleges: **Zene**; másodlagos: **Szórakozás** |
| Adatvédelmi URL | `https://hungarianhardstyle.hu/adatvedelmi-nyilatkozat/` |
| ÁSZF URL | `https://hungarianhardstyle.hu/app-felhasznalasi-feltetelek/` |
| Támogatási URL | `https://hungarianhardstyle.hu/impresszum/` |
| Marketing URL | `https://hungarianhardstyle.hu/` |
| Copyright | `Hungarian Hardstyle` |

**Kulcsszavak:** `hardstyle,hardcore,radio,magyar,dj,események,kiadványok,zene,community,chat`

**Leírás (magyar):**
```
A magyar hardstyle és hardcore színtér egy helyen: élő rádióadás, hírek,
események, kiadványok, DJ- és szervezőadatlapok, közösségi chat, kvízek és
szavazások. A rádió a háttérben is szól, az értesítésekből egy koppintással
nyílik a cikk vagy az esemény.

Az app ingyenesen használható; a regisztrációval a chatben és a játékokban
tudsz részt venni. iOS-en a zenevásárlás (Google Play Billing) nem érhető el —
ez Androidon működik.
```

**Leírás (angol):**
```
Hungarian hardstyle and hardcore in one place: live radio, news, events,
releases, artist and organiser profiles, community chat, quizzes and polls.
The radio keeps playing in the background, and a tap on a notification opens
the article or the event.

The app is free; registering lets you join the chat and the games. Music
purchases (Google Play Billing) are not available on iOS — they work on Android.
```

**Review notes (elbírálónak, magyar + rövid angol):**
```
A zenevásárlás (Google Play Billing) ebben az iOS-verzióban NEM érhető el: az app
iOS-en nem mutat vásárlási gombot, és nem irányít külső fizetésre. A „Megvásárolt
zenéim" az iOS-en a reklámmal feloldott ingyenes tartalmakat mutatja.

A rádió és a nyilvános tartalmak bejelentkezés nélkül is elérhetők. Teszt-fiók:
[a fiók e-mail-címe és jelszava — ezt a tulajdonos adja meg]
```

---

## 4. Amit ÉN tudok, és amit nem

| Teendő | Ki |
|---|---|
| A build (410) iOS-re fordul és az IPA elkészül (GitHub Actions, aláírás nélküli) | ✅ kész, artifact: `HUHS-ios-unsigned-ipa` |
| Aláírt build + App Store Connect feltöltés | Codemagic workflow kész — **az Apple-hitelesítés a tiéd** (Codemagic env) |
| App Store Connect: Alternative Distribution + Review Type + Submit | ❌ csak a te fiókod tudja |
| Onside Console: jelentkezés, ár, országok, Publish | ❌ csak a te fiókod tudja |
| A fenti szövegek (leírás, kulcsszavak, review notes) | ✅ kész ebben a fájlban |
| A trader/DSA adatok (kereskedői státusz) | a te nevedben, egyszer már kitöltöttük (Play) — az Apple-nél külön |

## 5. Őszinte korlátok

- **iOS-push az Onside-os buildben sem lesz jobb, mint a TestFlightban**: a push az app
  kódjától és az Apple engedélyektől függ, nem a bolttól. (A jelenlegi iOS build
  push-képes kódot tartalmaz, de a kézbesítés az APNs-en múlik.)
- Az **alternatív piactér csak EU-ban és iOS 17.4+** eszközön működik — a felhasználónak
  engedélyeznie kell a piactér telepítését a telefonján.
- A **notarizálás** az App Store review-nál enyhébb, de a **működést** ellenőrzi
  (pl. ha az app login mögött van, teszt-belépés kell).
- Az Onside a saját moderációját is lefuttatja (≤24 óra) a publikálás után.
