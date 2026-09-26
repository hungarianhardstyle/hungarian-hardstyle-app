# Play Console — kiadási jegyzet (másolható)

> **Most a 369 megy fel** (versionCode **369**, `1.0.0`). **Mérve** (`node tools/check-play-track.mjs`,
> 2026-09-26): az **ÉLES (production) sávon a 360 fut** (`completed`, 100%), a **zárt teszten (alpha)
> a 365**, a `beta` sávon a 354. A 369 újdonsága (a tulajdonos jelzése: *„a notifyok még mindig
> magyarul vannak az angol felületen vagy lassan áll át"* → *„nagyon lassan"*): az **értesítések
> szövege angol felületen azonnal a választott nyelven** jelenik meg — a **régi** értesítések is
> átfordulnak, nem kell megvárni az újakat (eddig a szerver a **létrehozáskor** renderelte a szöveget,
> ezért a régi sorok a régi nyelven maradtak); a **privát üzenet** értesítésének címe is a választott
> nyelven szól; és az értesítések törlése ablak „archivált" címe is angolul jelenik meg. A 369 a **368
> minden** újdonságát is tartalmazza (a kiadási jegyzet angolul), az pedig a korábbiakét (játék-eredmény
> fejléc, válasz-előnézet, nyelvváltó, angol tartalom, GYÍK → FAQ, hírlista-frissesség, Chat-ugrás).
> A nyilvános kiadáshoz a **361–369 összesítő** (1b-2.), a bétához a **355–369 összesítő** (1b-3.) való.

Ez a fájl a **következő feltöltéshez** tartozó, **kész, másolható** changelog-szövegeket
tartalmazza. A szabály ugyanaz, mint a `docs/RELEASE_CHANGELOG_CHECKLIST.md`-ben:
ugyanaz a magyar changelog megy a Play Console-ra, az app Névjegyére
(`lib/data/app_changelog.dart`) és a plugin kiadásjegyzékére.

<!-- play-notes-meta
currentBuild: 369
currentVersion: 1.0.0
lastPublishedBuild: 360
aab: build/HUHS-v1.0.0+369-release.aab
sha256: D256A3D2CA405222D1394ACAA73FC96EE8D3427C15DEA542C7474F31722DF25F
-->

⚠️ A **369**-et a **368** után kellett építeni (a 368-at **nem** kell feltölteni, ha még nem tetted meg:
a 369 mindenben tartalmazza, és a Play a használt verziókódot amúgy is elutasítaná).
⚠️ **A WordPress-plugin ehhez a körhöz: 2.14.5** (`build/huhs-mobile-api-2.14.5.zip`, SHA-256
`68BE6407863D0905B3BB4A164654B354E412C731AA6323F86AF6F9FB6D90DF32`) — ebben vannak a **kézi angol
mezők** (kérdőív, nyereményjáték, játék-összefoglaló). Az apphoz **nem** kell külön telepítés, csak az
**AAB (369)** és a **plugin (2.14.5)** feltöltése.

## 0. ÉLŐ ÁLLAPOT a Play-en (mérve, `node tools/check-play-track.mjs`)

A Play Developer API-t **olvasásra** kérdezve (**2026-09-26**, a legfrissebb mérés):

| Sáv | Állapot | Build |
|---|---|---|
| **production (nyilvános — ÉLES)** | **completed** (100%-ban kigördült) | **360** — „360 (1.0.0)" |
| **alpha (zárt teszt)** | **completed** (100%-ban kigördült) | **365** — „365 (1.0.0)" |
| beta | completed (100%) | 354 |
| internal | completed (278) + egy **üres piszkozat** | 278 |
| **nyilvános bolt-lap** | **HTTP 200 — él** | — |

- **Az ÉLES sávon a 360 van** (`completed`, 100%, a 360-as szöveggel: `@mindenki` + a Chat-értesítés odaugrása) — **ez a mért állapot 2026-09-26-án**, és ez az, amit a nyilvános felhasználók használnak.
- **A zárt teszten MÁR A 365 FUT** (a tulajdonos feltöltötte, `completed` 100%), és a kiadási szövege **pontosan a 361–365 összesítő** (visszaolvasva a Playről: *„ÚJ: HU/EN nyelvváltó…"*, *„…a válasz idézetére koppintva az app az eredeti üzenetre ugrik"*, *„…a »Bulizó« szerepkör felirata »Partyface«"*).
- A feltöltött AAB-ek a Playen (a 2026-09-26-i mérés szerint): 1, 155, 159, 171, 175, 178, 181, 190, 204, 277, 278, 297, 319, 333, 352, 353, 354, 355, **357**, 358, 359, **360**, **365**.
- **A 365 a zárt teszt csúcsa**, ezért a következő lépés a **production sávra** való kirollázás (a 361–365 szöveggel), és **nem** kell új AAB-ot feltölteni: a **365-ös csomag már fent van** a Playen, csak át kell vinni a sávot.
- A `play-notes-meta` `lastPublishedBuild` értéke (**360**) a legutóbb **nyilvánosan** kigördült build — ezért a **következő nyilvános** kiadáshoz a **361–365 összesítő** való (az **1b-2. blokk**): ami a 360 óta történt, az a **nyelvváltó** + angol tartalom, az angol felület teljessé tétele, a **többnyelvű értesítések**, a **hírlista-frissesség**, a **Chat-idézet odaugrása** és a „Partyface" felirat.
- **⚠️ A Play-termékek ország-listája (2026-09-22, javítva):** a termékek **kilenc országban** érhetők el (HU, AT, HR, SI, SK, NL, CZ, RS, UA) — korábban **csak Magyarországon** voltak, miközben az app 8 országban elérhető volt. Ez **szerveroldali + Play-adat** javítás volt, ezért **nem** igényelt új AAB-ot. Ellenőrzés: `node tools/check-play-products.mjs`.

## 0b. Play-követelmény: alkalmazásregisztráció (határidő: **2026. szeptember 30.**)

A Play Console 2026-07-15-i értesítése szerint **2026. szeptember 30-tól** a **nem regisztrált**
Play-alkalmazásokat **globálisan letiltják** a Google Playről, és a **Playen kívül** terjesztett,
Android-aláírási kulcsot használó buildek **sem telepíthetők** a tanúsítvánnyal rendelkező
Android-eszközökre bizonyos országokban. Ezért **minden** csomagnévhez **minden** aláíró kulcsot
regisztrálni kell, amellyel terjesztesz.

**A MI ÁLLAPOTUNK (mérve, 2026-09-20):**

| Mit | Érték |
|---|---|
| Csomagnév | `hu.hungarianhardstyle.app` (ez az **egyetlen** alkalmazásunk; `applicationId` a `android/app/build.gradle.kts`-ből) |
| Regisztráció a Play Console-ban | **Regisztrált** (3 kulcs), utoljára frissítve 2026. aug. 12. |
| A helyi buildek aláíró tanúsítványa | SHA-256 `B4:FB:6D:AF:37:A7:0C:56:17:6F:8D:34:A5:BE:79:A1:7C:2E:5B:B5:59:1C:C4:F6:64:BF:29:47:F0:AB:0A:50` |
| Tanúsítvány tulajdonos | `CN=Hungarian Hardstyle, OU=Mobile, O=Hungarian Hardstyle, L=Budapest, C=HU` (érvényes 2053-12-23-ig) |
| Aláírási identitások száma | **1** — mind a **35 AAB** (301…335) és a 2 release APK ugyanezzel a kulccsal készült |
| Terjesztés a Playen kívül | **nincs**: sem a plugin, sem a weboldal nem kínál app-APK-t (csak zenét/kiadványt) |

**Ellenőrzés egy paranccsal:** `node tools/check-signing-identity.mjs` — kilistázza a kész buildek
aláírását, és megmondja, hány **különböző** identitás van (több = figyelmeztetés, mert a nem
regisztrált kulcsú build 2026-09-30 után nem telepíthető a tanúsított eszközökre).

**Amit tenni kell:** a Play Console „Aláírási kulcsok" nézetében **ellenőrizni**, hogy a fenti
lenyomat (a feltöltési kulcsunk) és a Google-féle **app signing key** is szerepel a regisztrált
kulcsok között. Új AAB vagy plugin feltöltés **nem** kell hozzá. Ha valaha APK-t adnál ki a Playen
kívül (másik áruház, weboldal), **azt a kulcsot is** regisztrálni kell — ezért érdemes továbbra is
**egy** kulccsal írni alá mindent.

## 0c. Play-javaslatok: a „teljes képernyős" kártyák — MÉRVE, egyik sem a mi kódunk (2026-09-25)

A Play Console a **358**-as kiadásnál is **két „teljes képernyős" kártyát** mutat (a tulajdonos
képernyőképe). Mindkettő **javaslat, nem blokkoló** — a 358 a zárt teszten **100%-ban kigördült**.
A gyökér **mérve** (a 360-as AAB `base/dex/classes*.dex`-e, `dexdump` + a híváshelyek keresése):

| Kártya | Mit keres a Play | Amit mértünk a csomagban | Kié a kód |
|---|---|---|---|
| „Előfordulhat, hogy a teljes képernyős mód nem jelenik meg minden felhasználónál" | **`enableEdgeToEdge()` / `EdgeToEdge.enable()` híváshelyet** a bytecode-ban | a `MainActivity.onCreate` **hívja** ugyan (356 óta), de az **R8 beinline-olja**, ezért a DEX-ben az `EdgeToEdge` **0 híváshely** — a `WindowCompat.setDecorFitsSystemWindows(...)` önmagában **nem** elég a szkennelésnek | **Flutter-motor** (`PlatformPlugin`) + a mi R8-optimalizálásunk |
| „Az alkalmazásod elavult API-kat vagy paramétereket használ a teljes képernyős megjelenítéshez" | a régi `setDecorFitsSystemWindows` / `layoutInDisplayCutoutMode` útvonalat | `setDecorFitsSystemWindows` **1 híváshely** (a motor `PlatformPlugin.enableEdgeToEdge()`-je; pontosan a `setSystemUiVisibility(0)` + `setDecorFitsSystemWindows(false)` pár), `layoutInDisplayCutoutMode` **4** hivatkozás (az `androidx.core` `WindowCompat`-ja, R8-összevonva) | **Flutter-motor + Google-könyvtár** (`androidx.core`) |

- **A `-neverinline` próbát is megmértük:** az `android/app/proguard-rules.pro`-ba tett
  `-neverinline class androidx.activity.EdgeToEdge { *; }` szabályra a build **elhasalt**:
  *„R8: Unknown option -neverinline"* — a projekt R8-verziója **nem támogatja**, és a `-keep`-nek
  önmagában nincs hatása a beágyazásra (a `-keep`-pel az `EdgeToEdge` osztály ugyan bennmarad, de
  **híváshely továbbra sincs**: `EdgeToEdge hivatkozás=24, HÍVÁS=0`). A `-dontoptimize` az egyetlen
  működő kapcsoló lenne, az viszont a **teljes** optimalizálást kikapcsolja (nagyobb, lassabb
  csomag) — egy kozmetikai kártyáért nem érdemes. **A proguard-fájl ezért bájtpontosan visszaállt**
  (SHA-256 `0AE47CC9…`), és a szállítandó csomag **változatlan** (`0C000AB2…`).
- **A hivatalos követés:** a jelenség nyitott Flutter-hiba:
  [flutter/flutter#192921](https://github.com/flutter/flutter/issues/192921) — a motor **soha** nem
  hívja az `EdgeToEdge.enable()`-t (csak a `WindowCompat`-ot), ezért a Play szkennere **minden**
  Flutter-appnál jelzi. App-oldali megoldás jelenleg **nincs** (a Dartból nem lehet híváshelyet
  varázsolni a bytecode-ba).
- **Amit ez jelent:** a **360 feltöltését nem érinti** (a kártyák a 358-nál is ott voltak, és a
  kiadás 100%-ban kigördült). A **bittérkép-kártya** (harmadik javaslat) ugyanígy **Google Mobile Ads
  SDK** — lásd a korábbi mérést. **Újramérés** egy paranccsal: `tmp\check-edge-to-edge-dex.ps1`,
  `tmp\probe-decor-fits.ps1` (a `dexdump`-hoz Android SDK build-tools kell).

## A feltöltendő AAB (mérve)

| | |
|---|---|
| Fájl | `build/HUHS-v1.0.0+364-release.aab` |
| Verzió | `1.0.0` (versionName) |
| Verziókód | **364** (a merge-elt release manifestből visszaolvasva: `android:versionCode="364"`, `versionName="1.0.0"`) |
| Méret | 81,67 MB (85 646 603 bájt) — a fájl nagy része a Play-oldali `proguard.map`, ami **nem** megy le a felhasználóhoz |
| SHA-256 | `C131504663942969F6D735247D3B217E469B3C014ADA3FD8F69E40859F3CD745` |

> **⚠️ A 364 a feltöltendő csomag** (versionCode **364**, `1.0.0`), és **2026-09-26-án újraépült**: benne van az **Achievement-nevek/-leírások** angol fordítása **a HUHS Legenda toplistában, a közösségi listában és az Achievement-súgóban is** (a leírás a `{d}` helyőrzőben is fordítva megy ki), a **„DJ-k" felirat** angolul (`DJs`), a **„Nyeremény"** és az **„Élő adás"** címkék fordítása, valamint a **chat-idézet koppintása** (megmutatja az eredeti üzenetet teljes egészében). A **„Közösség" gomb kiférésének** javítása szintén benne van. A **360 a zárt teszt csúcsa** (feltöltve, `completed`), ezért a 364-nél kisebb kódú csomagot a Play **nem** fogadná el; a 361/362/363 elkészült, de **egyik sem került fel**, a **364 mindegyiket tartalmazza**.
> ⚠️ **Az alábbi, 360-ról szóló bekezdések TÖRTÉNETIEK** (a 364 azokat is tartalmazza) — a 364 újdonságai a **„3. App (Több → Névjegy)"** szakaszban vannak.

**Miért a 360-at kell feltenni (és miért nem a 358-at):** a 360 **magában foglalja a 358-at, a 357-et, a 356-ot, a 355-öt és a 354-et is**, ezért egy csomagot kell feltenni:

- **ÚJ (a 360): `@mindenki` hivatkozás a Chatben.** A tulajdonos kérése: *„kéne egy @mindenki tag is,
  amit ha beütök, kap mindenki notifyt és csak moderátor/admin használhassa"*. Aki admin/moderátor, az
  a `@min…` beírásakor megkapja a **Mindenki** találatot (a lista **első** helyén), és az üzenet
  elküldésekor **minden regisztrált felhasználó értesítést kap** (mérve: **41** címzett). A
  jogosultságot a **szerver** kényszeríti (a nem admin küldést egyszerűen kihagyja), és a szövegben a
  `@mindenki` **ki van emelve, de nem kattintható** (nincs mögötte adatlap). Üres lekérdezésnél
  szándékosan **nem** ajánljuk fel, hogy egy véletlen koppintás ne küldjön értesítést mindenkinek.
- **Javítva (a 360): a Chat-értesítés a MÉLYEN lévő, régebbi üzenetnél is odaugrik.** A tulajdonos
  jelzése: *„egy régebbi chat like … rányomtam és nem dobott a chat üzire … régebbi chat üzivel nem
  megy, újabba igen"*. **A mért gyökér (kódból + widget-teszttel reprodukálva):** a lista **csak a
  látható** elemeket építi fel, ezért a mélyen lévő kártyához nem volt kontextus, és a kód ilyenkor a
  lista **végére** ugrott — az a **legrégebbi** üzeneteket mutatja, nem a megjelöltet. A legfrissebb
  üzenetnél ez azért működött, mert az már fel volt épülve. Mostantól a cél **indexéből becsült**
  pozícióra ugrunk, majd onnan pontosítunk.
- **A 359 (benne van):** a Chat-odaugrás javítása hideg indításra (a 10 lapos keret nem ég el a
  betöltés alatt), és minden, ami a 358-ban.
- **ÚJ (a 358): `@`-hivatkozás a Chatben.** A tulajdonos kérése: *„egy @xy betűvel tudjak hivatkozni a
  chaten cikkre, djre, szervezőre, eseményre, kiadványra vagy személyre/userre"*. Gépelés közben a
  javaslatlista **típus szerint csoportosítva** jelenik meg (Személyek / Cikkek / DJ-k / Szervezők /
  Események / Kiadványok), a **személy** mindenkinek elérhető, a **tartalom csak adminnak/moderátornak**
  — ezt a **szerver** is kényszeríti (a nem engedett hivatkozásokat kihagyja, a szöveg marad).
  Minden hivatkozás **kattintható**, és a megfelelő adatlapra visz (közös útvonal-feloldóval, ugyanazzal,
  amit az értesítés-központ is használ).
- **ÚJ (a 358): a megemlített személy értesítést kap** (üzenetenként legfeljebb **5 személy**), a
  szövegben a **hivatkozó nevével** — és a koppintás a **357 óta** arra az üzenetre visz, amelyről szól.
- **A 357 (benne van):** az értesítések megnevezik a cselekvőt (chat-lájk, cikk-komment), és a
  Chat-értesítés a megjelölt üzenetre ugrik.
- **A 356 újdonsága (benne van):** a hírlevélnél **nem megy ki újra** a megerősítő e-mail ugyanarra
  a címre (plugin **2.10.0** + app-oldali üzenet), és a `MainActivity` megkapta a Play által kért
  `enableEdgeToEdge()` hívást (**mérten nem változtat a felületen** — lásd a 356 bejegyzést).
- **Amit ez a kiadás is tartalmaz (a 355-ből és a 354-ből):** a nyeremény leírása a játék ALATT is
  látszik + a nyereményjáték azonnali nyitása; a DJ-adatlap „Megjelenései" szakasza.

**⚠️ A plugin ehhez 2.10.0** (`build/huhs-mobile-api-2.10.0.zip`) — **ez már fent van** (a tulajdonos
feltöltötte; benne van a 2.8.0 és a 2.9.0 javítása is: nyeremény-leírás, DJ privát e-mail). A
változások átnézhetők: `docs/plugin-2.8.0-prize-description.patch`,
`docs/plugin-2.9.0-private-email.patch`, `docs/plugin-2.10.0-newsletter-cooldown.patch`.

**A 358 a 357 (és így a 356, 355, 354, 353) minden javítását is tartalmazza** (a Firebase-család major emelése + a lassú betöltés
javítása: kvíz-állapot, claim-állapot, előtöltés), és a 352 vásárlási diagnosztikáját is. A 353
mérései változatlanul érvényesek a csomagra:

| Mérce | 352 | 353 |
|---|---|---|
| R8 optimalizálás (a riport szerint) | 54,33% | **92,09%** |
| R8 obfuszkiálás | 54,52% | **92,28%** |
| R8 csökkentés | 54,46% | **92,22%** |
| Visszatartott elemek | 92 912 | **15 756** |
| DEX a csomagban | 12,03 MB / **3 fájl** | **9,86 MB / 2 fájl** |
| Becsomagolt SafetyNet | 394 osztály | **0** (a manifestből és a mappingből is eltűnt) |

**Amit ez jelent:** kisebb a letöltött **kód** (a DEX 18%-kal kisebb, és eggyel kevesebb DEX-fájl — ez az
indításnál is számít), és **eltűnt** a becsomagolt, elavult **SafetyNet** könyvtár (ez volt a Play-panel
1. javaslata). **Látható újdonság nincs** — a bejelentkezés, az adatbázis, az értesítések és a vásárlás
működése változatlan; a csomag a Google legfrissebb javításait hozza.
**A 356 a 355 (és a 354) minden javítását is tartalmazza.** **Ugyanaz a verziókód nem
tölthető fel újra**, ezért minden javítás új verziókódot kap.

> **FONTOS:** a **korábbi AAB-eket ne töltsd fel** — a 356 mindegyiket tartalmazza, és kisebb
> verziókódú csomagot a Play amúgy sem fogadna el.

**A plugin ehhez 2.7.0** (`build/huhs-mobile-api-2.7.0.zip`) — **ez már fent van** (élőben
igazolva: `apiVersion = 2.7.0`, a privát végpontok védettek), ezért **nem kell újra feltölteni**.
A **szerveroldali függvények is telepítve vannak** (`firebase deploy --only functions`), benne a
**kilenc országra bővített termék-régiók** javításával (a 60 termék mind a 9 országban elérhető).

## 1. Play Console — RÖVID (ezt másold be)

A tulajdonos kérése: *„röviden kéne a Playbe"*. A Play a kiadási megjegyzést a frissítés
kártyáján **rövidítve** mutatja, ezért a **rövid** szöveg a jó. A részletes lista nem vész el —
az **az app Névjegyében** van (3. pont), és a felhasználó ott bármikor megnézheti.

A Play **nyelvenként 500 karaktert** enged ([súgó](https://support.google.com/googleplay/android-developer/answer/9859348?hl=en));
az alábbi blokk **mérve a limit töredéke** (a pontos számot a `tools/check-play-notes.mjs` írja ki).

```play-notes
- Javítva: angol felületen az értesítések szövege azonnal a választott nyelven jelenik meg — a régi értesítések is átfordulnak.
- Javítva: a privát üzenet értesítésének címe is a választott nyelven szól.
- Javítva: az értesítések törlése ablak „archivált" címe is angolul jelenik meg.
```

## 1b. Play Console — a 359–365 összesítő (TÖRTÉNETI — a 359/360 már élesben van)

⚠️ **2026-09-26-tól ezt NE használd a nyilvános kiadáshoz:** az ÉLES (production) sávon már a **360** van,
ezért a `@mindenki` és a Chat-odaugrás **már megvan** a felhasználóknak. A helyes blokk a **361–365**
összesítő (**1b-2.**). Ez a szöveg csak akkor való, ha valaki **358-ról** frissít (illetve történeti
dokumentációnak marad itt).

```play-notes
- ÚJ: a főoldal és a Hírek fül listája magától frissül — az új cikk egy percen belül megjelenik.
- ÚJ: a Chatben a válasz idézetére koppintva az app odaugrik az eredeti üzenetre.
- Angol felületnél a cikkek, a feliratok, a hírek kategória-/címke-nevei és az Achievement-nevek is angolul jelennek meg.
- Az értesítések is a választott nyelven jönnek (a push is); a nyelv a profilodban tárolódik.
- ÚJ a Chatben: @mindenki, és a Chat-értesítés a megjelölt üzenetre ugrik.
```

## 1b-2. Play Console — a **361–369** összesítő (a 360 után)

**Ezt használd, ha a felhasználó a 360-ról jön** (ez az ÉLES sáv jelenlegi buildje) — vagyis csak azok
az újdonságok szerepelnek benne, amelyek a **361–369** között készültek (a 359/360 `@mindenki`-je
**nincs** benne, mert azt a 360 már megkapta). A karakter-számot a `tools/check-play-notes.mjs` méri.

```play-notes
- ÚJ: HU/EN nyelvváltó — az app angolul is elérhető, a magyar marad az alap.
- Angolul a cikkek, a hírek címkéi, az Achievement-nevek és a GYÍK (FAQ) is.
- Az értesítések (lista és push) is a választott nyelven jönnek.
- ÚJ a Chatben: @mindenki, és a válasz idézetére koppintva az eredeti üzenetre ugrik.
- ÚJ: a főoldal és a Hírek fül magától frissül; a DJ-adatlapon a megjelenések.
- Javítva: angolul a játék-eredmény fejléc, a válasz-előnézet, a changelog és a feliratok.
```

## 1b-3. Play Console — a **BÉTA** sávhoz (**355–369** összesítő)

**Ezt használd, ha a 369-et a béta (nyílt teszt) sávra teszed fel:** a bétán mért állapot
(`node tools/check-play-track.mjs`, 2026-09-26) szerint ott a **354** fut, ezért a béta felhasználók a
**355 óta** történteket kapják — a nyelvváltó és az angol felület mellett a `@mindenki`, a Chat-értesítés
odaugrása, a DJ-adatlap megjelenései, a hírlista-frissesség és a mai felirat-javítások is.

```play-notes
- ÚJ: HU/EN nyelvváltó — az app angolul is elérhető, a magyar marad az alap.
- Angolul a cikkek, a hírek címkéi, az Achievement-nevek és a GYÍK (FAQ) is.
- Az értesítések (lista és push) is a választott nyelven jönnek.
- ÚJ a Chatben: @mindenki, és a válasz idézetére koppintva az eredeti üzenetre ugrik.
- ÚJ: a főoldal és a Hírek fül magától frissül; a DJ-adatlapon a megjelenések.
- Javítva: angolul a játék-eredmény fejléc, a válasz-előnézet és a changelog.
```

## 1c. Play Console — CSAK a 351-hez, bővebben (tartalék)

Ugyanaz a kiadás, részletesebben — akkor használd, ha a Play kártyáján több sort akarsz
megjeleníteni. **Ez a 351 javítását és a 350 újdonságait is leírja.**

```play-notes
- Javítva: az értesítéseknél mostantól több sor is kijelölhető egyszerre — eddig minden koppintás lecserélte az előzőt.
- ÚJ: az átvett DJ-adatlapodat te szerkesztheted az appban — név, valódi név, város, ország, bemutatkozás, közösségi linkek és a kép cseréje.
- A „Claim" helyett mindenhol magyar szó áll: „Adatlap átvétele", „Átvétel visszavonása".
- Javítva: az adatlapok (saját profil, hír, esemény, DJ, szervező) aljára rendesen le lehet görgetni.
```

## 2. Play Console — CSAK akkor, ha a 329 is kiment volna

**Most NE ezt használd!** Ez a blokk csak a **330** változásait sorolja fel, ezért akkor való, ha
a 329 **már kint van**, és csak a rákövetkező kiadás megy fel. Most az **1. pont** blokkját kell
bemásolni (mert a 329 nem ment ki).

```play-notes
- Adminoknak: a HUHS adminban új menüpontok — kvíz, kérdőív és nyereményjáték eredményei.
- A Vezérlőközpontban a Hírlevél, a Shortcode-ok és a Beállítások is megnyitható.
```

## 3. App (Több → Névjegy) — tételes, build szerint

Ez a lista **maga az app** (`lib/data/app_changelog.dart`), ezért külön feltölteni nem kell;
itt azért van, hogy egy helyen látsszon, mit kap a felhasználó. A sorok a legfrissebbel kezdődnek.

### 369 — az értesítések szövege is azonnal a választott nyelven
- **Javítva (a tulajdonos jelzése: *„a notifyok még mindig magyarul vannak az angol felületen vagy lassan áll át"* → *„ja lassan áll át"* → *„nagyon lassan"*):** a szerver az értesítés szövegét a **létrehozáskor** rendereli a címzett akkori nyelvén (`createNotification` → `recipientLanguage`), és a Firestore-ba **kész szöveget** ír (`title`/`body`) — ezért nyelvváltás után a **régi** értesítések a régi nyelven maradtak, és csak az **új** értesítések jöttek az új nyelven. Mostantól az app a **megjelenítés helyén** fordítja a tárolt szöveget: a szerveroldali katalógusból (`functions/notification-texts.js` → generált `assets/i18n/notification_texts.json`, **36 típus**) kiolvassa a helyőrzőket, és a mostani nyelven újra kitölti — így a váltás **azonnal** látszik, a **régi** értesítéseken is. Az **adat** (cikk címe, küldő neve, idézet) **nem** fordul le.
- **Javítva:** a **privát üzenet** értesítésének címe eddig **beégetve, magyarul** állt a szerveren (`{senderName} üzenetet küldött`), ezért angol felületen magyar cím jött — mostantól a katalógusból, a címzett nyelvén (a **push** címe is), és a kliens a küldő nevét **mindkét nyelvű** utótag levágásával fejti vissza.
- **Javítva:** az értesítések törlése ablak **„archivált" címe nyers ternary-ág** volt (a másik ág fordítva) — angol felületen magyarul jelent meg; a `Értesítés` tartalék felirat is a fordítón megy át.
- **Mérve:** `flutter analyze lib test` → **No issues found!**; `flutter test` → **1129/1129** (ebből új: `test/services/notification_language_test.dart` **12/12** — magyarul tárolt szöveg angolul, angolul tárolt magyarul, a helyőrzők (név, idézet, szám) változatlanok, a már jó nyelvű szöveg nem fordul duplán, az adat nem fordul, ismeretlen/egyedi szöveg változatlan, a privát üzenet címe is fordul, üres szöveg üres marad, forrás-lint); **mutációs bizonyíték 5/5** (`tmp/mutation-proof-notifications.mjs`, bájtazonos visszaállítással); a **katalógus-egyezés kapuja** `node tools/generate-notification-texts.mjs --check` → **RENDBEN** (a szerveroldali forrásból generálva); `node --test` tiszta függvénykör → **282/282**; `node tmp/verify-aab.mjs build/HUHS-v1.0.0+369-release.aab 369` → **versionCode 369**, **1126 kulcsú szótár**, **az értesítés-katalógus besomagolva (36 típus)**, mind a tizenegy changelog-sor mindhárom ABI-ban. A szerveroldali függvények **telepítve** (`firebase deploy --only functions` → *Deploy complete!*).
- **Amit ez a kiadás is tartalmaz:** a 368 (kiadási jegyzet angolul), a 367, a 366, a 365, a 364 és a 363–359 minden újdonsága.
- **⚠️ ŐSZINTE KORLÁT:** ha egy értesítés szövege **nem** a katalógusból készült (egyedi, dinamikus szöveg), vagy 500 karakterre **levágott**, akkor a fordítás nem illeszkedik, és a **tárolt szöveg marad** — ilyenkor nem tippelünk; a ChatGPT és a felhasználók saját szövegei továbbra sem fordulnak.

### 368 — a kiadási jegyzet (changelog) is angolul, a teljes előzmény
- **Javítva (a tulajdonos jelzése: *„a changelog az appban nem angol"*, majd *„az angol felületen"*):** a Névjegy → **Újdonságok** szakasz a kiadási jegyzet sorait **nyersen** írta ki (`Text(change)`), és a szövegek **nem voltak a szótárban** — ezért angol módban a magyar changelog ment ki. Mostantól a **magyar sor a szótári kulcs**, a kiírás a fordítón megy át, és **mind a 134 sor** (48 kiadás, a legkorábbiakig visszamenőleg) fordítása bekerült a szótárba. A „nincs ehhez a verzióhoz jegyzet" szöveg is **sablon** lett (`Ehhez a verzióhoz ({n}) …`), ezért az sem marad magyar.
- **Mérve:** `flutter analyze lib test` → **No issues found!**; `flutter test` → **1117/1117** (ebből új: `test/services/i18n_changelog_test.dart` **4/4** — minden sorhoz van fordítás, angol módban **egyetlen sor sem marad magyar**, magyar módban bájtazonos, és a forrás-lint a nyers kiírást tiltja); i18n-kapu → **1121 kulcs, 918/918 célzott (100%), 0 duplikált**; **mutációs bizonyíték 3/3** (`tmp/mutation-proof-changelog.mjs`: a nyers kiírás visszaállítása, egy sor fordításának elvétele a szótárból, a verzió-interpoláció nyersre cserélése — mind **elkapva**, bájtazonos visszaállítással); `node tmp/verify-aab.mjs build/HUHS-v1.0.0+368-release.aab 368` → **versionCode 368**, **1121 kulcsú szótár**, a két új changelog-sor mindhárom ABI-ban.
- **Amit ez a kiadás is tartalmaz:** a 367 (játék-eredmény fejléc, válasz-előnézet, „szóközös" szótár-kulcsok), a 366, a 365, a 364 és a 363–359 minden újdonsága.
- **⚠️ ŐSZINTE KORLÁT:** a **Chat** és a **felhasználók saját szövegei** továbbra sem fordulnak (ez szándékos), és a `setState`-tel tárolt átmeneti állapotüzenetek egy része még magyar (pl. „A jutalmazott reklám betöltése…") — külön kör.

### 367 — a játék-eredmény fejléc és a válasz-előnézet is angolul (+ a szótár „elveszett" kulcsai)
- **Javítva (a tulajdonos jelzése: *„a játék eredményei fejléc is magyar maradt, angolra kapcsolva"*):** a `GameScreen` fejléce **nyers literál** volt egy ternary ágában (`resultsOnly ? 'Játék eredményei' : game.title`) — ezért az i18n-extraktor **nem látta**, a szótárban **nem volt kulcs**, és angol módban magyarul maradt. Ugyanez a hibaosztály a főoldali **„JÁTÉK EREDMÉNYEI"** jelvényen, a **hero** tartalék szövegén (`Próbáld ki magad!`), a **betöltési hibaüzeneten** és a **zárás-dátum** zárójeles címkéjén (` (eddig: …)`) — mind a fordítón megy át, és mind a hat kulcs bekerült a szótárba.
- **Javítva (második, mért hibaosztály):** a futásidejű szótár a kulcsokat **`trim()`-eli**, ezért a szótár **15 „ szóközzel körbevett " kulcsát** a `tr()` **soha nem találta meg** — a fordítás létezett, de **elérhetetlen** volt. Mérve: mind a 15 kulcs **fordítás-hívásban** áll (a hozzászólás/chat **előtagja**: „… hozzászólására: ", az **adatvédelmi tájékoztató** és a **Saját zenék** súgóinak mondatai, az „Unknown User "), és ütközés nincs. A keresés mostantól a **vágott alakot** is megnézi.
- **Javítva:** a **válasz-előnézet** (a beviteli sávban: „Válasz <név> üzenetére / hozzászólására") **nyers, interpolált** szöveg volt a Chatben és a hozzászólásoknál — sablonkulcs (`Válasz {name} üzenetére: {text}`) + `trArgs` lett.
- **Mérve:** `flutter analyze lib test` → **No issues found!**; `flutter test` → **1113/1113** (ebből új: `test/services/i18n_game_labels_test.dart` **7/7**); `node tools/check-i18n.mjs --strict` → **986 kulcs, 917/917 célzott (100%), 0 duplikált**; **mutációs bizonyíték 6/6** (`tmp/mutation-proof-game-labels.mjs`, bájtazonos visszaállítással); `node tmp/verify-aab.mjs build/HUHS-v1.0.0+367-release.aab 367` → **versionCode 367**, **986 kulcsú szótár**, mind a kilenc changelog-sor mindhárom ABI-ban.
- **A WordPress-plugin ehhez 2.14.5:** **kézi angol mezők** a natív adminban (kérdőív kérdés + válaszok, nyereményjáték kérdés/válaszok/megnevezés/leírás, játék rövid leírás) — a sorrend: **kézi angol → gépi fordítás → magyar**, a lista **elemenként** dönt (a szavazat sorszám, ezért nem csúszhat el), a `has_en` jelző pedig a kézi szöveget is számolja. A kvíz kérdéseihez szándékosan **nincs** második `questions` mező (a natív szerkesztő egy listát tart, ezért felülírná a magyar kérdéseket).
- **Amit ez a kiadás is tartalmaz:** a 366, a 365, a 364 és a 363–359 minden újdonsága.
- **⚠️ ŐSZINTE KORLÁT:** az audit szerint **maradnak** `setState`-tel **tárolt** átmeneti állapotüzenetek, amelyek némelyike magyarul szól (pl. a jutalmazott reklám folyamatában: „A jutalmazott reklám betöltése…") — ezek átírása külön kör; a **kvíz kérdéseinek** angol változata továbbra is **gépi** fordítás (a kiolvasó a kézi `_huhs_game_questions_en` metát ismeri, ha valaki a WordPressben tölti ki).

### 366 — a kiadvány-dátum és a „Megjelenései" is angolul + azonnali nyelvváltás + a GYÍK/FAQ
- **Javítva (a tulajdonos jelzései: *„itt is maradt magyar"* — képernyőkép a Label fülről: `Megjelenés: 2026-09…` —, *„pl a djk-nél a Megjelenései"*, *„ami még gond, nyelvváltáskor lassan áll át az adott nyelvre"*, *„a help menüben bentmaradtak a formázások mint a /P stb angolul, meg az lehetne FAQ amúgy, magyarba meg GYÍK"*):**
  1. **A kiadvány-dátum** (`Megjelenés: {d}`) és a **„Hamarosan · Megjelenés: {d}"** változat eddig **interpolált, nyers** szöveg volt — ezért sem az i18n-extraktor nem látta, sem a fordító nem érintette; mostantól **sablonkulcs** (`Megjelenés: {d} → Release: {d}`) a kártyán és az adatlapon (2 helyen).
  2. **A DJ-adatlap „Megjelenései" rovata** a tiszta `artistReleasesLabel()` **magyar kulcsát** írta ki nyersen; a szótárban sem volt a `Megjelenése`/`Megjelenései` pár — mindkettő bekerült (`Appearance`/`Appearances`), a cím pedig a fordítón megy át.
  3. **Nyelvváltás:** a **jelzés** már megvolt (`contentLanguageSyncProvider`), a **feldolgozott** listák viszont nyelvfüggetlen kulccsal élnek (30 s / 45 s / 2–5 perc) — ezért a váltás csak a cache lejárta után látszott. Új `WordpressService.onContentLanguageChanged()` dobja el ezeket a jelzés **előtt** (egy váltás = egy jelzés, nem kettő).
  4. **GYÍK:** a magyar felirat **GYÍK** (a menüben és a képernyő címében), az angol fordítás **FAQ** (`GYÍK → FAQ` kulcs). A **válaszok** formázás-szemete (a mért **31/33** angol válasz `<p>…</p>` burkolással jött) a **parse-ban** tisztul (`faqPlainText()`): a `</p>` bekezdéshatár, a `<br>` sortörés lesz, az entitások feloldódnak — a magyar válaszok (0/33 HTML) bájtazonosak maradnak.
  5. **További nyers címkék egy menetben** (a `tmp/audit-raw-labels.mjs` listájából): DJ-adatlap fejléc, esemény-/híradatlap fejléc, „Felhasználó", „Kép kiválasztása", „Letöltés" (2 hely), „Betöltés…", „{n} lejárt esemény", „Nincs kiválasztva", profil-szerkesztő cím, „Nyeremény", játék-típus — és a **jelszó-mezők tooltipjei** (`Elrejtés`). A `Text('…')` gyanús lista **17 → 3** (a maradék 2 „HUHS user" szándékosan angol).
- **Mérve:** `flutter analyze lib test` → **No issues found!**; `flutter test` → **1106/1106**; `node tools/check-i18n.mjs --strict` → **977 kulcs, 909/909 célzott (100%), 0 duplikált**; a nyelvi kör **mutációs bizonyítéka 4/4** (`tmp/mutation-proof-language.mjs`: nyers dátum-címke, nyers „Megjelenései", a GYÍK-tisztítás elvétele, a lista-eldobás elvétele — mind **elkapva**, bájtazonos visszaállítással); `node tmp/verify-aab.mjs … 366` → **versionCode 366**, **977 kulcsú szótár**, mind a hat changelog-sor mindhárom ABI-ban.
- **Amit ez a kiadás is tartalmaz:** a 365 (hírlista-frissesség, Chat-idézet odaugrása, „Partyface"), a 364 (többnyelvű értesítések, teljes angol felület, angol Achievement-nevek, a „Közösség" gomb kifér, hírek kategória-/címke-nevei), a 363–359 minden újdonsága.
- **⚠️ ŐSZINTE KORLÁT:** az idézet odaugrása a **privát beszélgetésben** még nem működik (külön kör), és az audit szerint **maradnak** átmeneti állapotüzenetek, amelyek némelyike magyarul szól (pl. a jutalmazott reklám folyamatában: „A jutalmazott reklám betöltése…"), mert azok `setState`-tel **tárolt** szövegek — ezek átírása külön kör (a szótár-kulcs + a megjelenítés fordítása kell hozzá).

### 365 — a hírlista magától frissül + a „Partyface" felirat
- **ÚJ (a tulajdonos jelzése: *„ha felteszek egy hírt, nagyon lassan kerül ki a főoldalra, vagy a hírek tab alá"*):** a **főoldal** és a **Hírek fül** listája **percenként csendesen egyeztet** a szerverrel (ETag/HEAD, ami **304**-et ad — mért: 399 ms, 0 bájt), és **előtérbe kerüléskor** (pl. egy értesítésre megnyitva) **azonnal** ellenőriz. A mérés szerint a szerver **azonnal** a friss listát adná (a plugin a publikáláskor érvényteleníti a cache-ét), a késés az app oldalán volt: a nyitott képernyő **egyáltalán nem kérdezte meg** a szervert, ezért az új cikk csak lehúzásra vagy újraindításra jelent meg. A háttérben beérkező változás mostantól **egy körben** megjelenik (a mentett, feldolgozott lista is érvénytelenül, ezért nem a régi példány marad a képernyőn).
- **ÚJ (a tulajdonos kérése: *„ez a »partygoer« angolban legyen inkább »Partyface«"*):** angol felületen a **„Bulizó" szerepkör felirata „Partyface"** (a belső szerepkör-**érték** `partygoer` adat, az változatlan).
- **Mérve:** `flutter analyze lib test` → **No issues found!**; `flutter test` → **1083/1083** (ebből az új frissességi kör **10/10**: az ütem, a lebontás, az egykörös megjelenés és a bekötés forrás-lintje); a csomagban (`node tmp/verify-aab.mjs`) **versionCode 365**, **969 kulcsú szótár** (`Bulizó → Partyface`), termelési AdMob ID, aláírás, és az új changelog-sorok **mindhárom ABI**-ban megvannak.
- **Amit ez a kiadás is tartalmaz:** a 364 (többnyelvű értesítések, teljes angol felület, angol Achievement-nevek/-leírások, a „Közösség"/Community gomb kifér, hírek kategória-/címke-nevei angolul, „Nyeremény"/„Élő adás" címkék, a chat-idézet koppintásra megmutatja az eredeti üzenetet), a 363–359 minden újdonsága.
- **⚠️ ŐSZINTE KORLÁT:** az egyeztetés **percenként egy kicsi kérés** (a 304-es válasz miatt gyakran üres); ez **nem** azonnali push — egy új cikk **legfeljebb egy percen belül** tűnik fel magától, lehúzásra viszont azonnal. A **hírek tartalmának** angol fordítását a WordPress-plugin adja (2.14.x).

### 364 — az értesítések is a választott nyelven + az angol felület teljessé tétele
- **ÚJ (a tulajdonos kérése: *„maradék 132 szöveg + az értesítések is"*):** az **értesítések** (a bejövő lista **és** a push) a **címzett nyelvén** szólalnak meg. A szövegek eddig a szerverkódba voltak égetve **magyarul**, ezért az angol felületű felhasználó magyar értesítést kapott. Most egy **nyelvi katalógus** (`functions/notification-texts.js`) adja a szöveget a `kind` + a helyőrzők alapján, a címzett nyelvét pedig a `community_profiles/{uid}.language` mezőből olvassa (ezt az app a nyelvváltáskor **és** bejelentkezéskor írja; hiányzó értékre **magyar** — így egy régi kliens a megszokott szöveget kapja). Érintett: Chat-lájk, Chat-válasz, `@`-megemlítés, `@mindenki`, cikk-komment és válasz, esemény-értékelés kérés, új tartalom (hír/kiadvány/DJ/szervező/esemény), nyeremény-nyertes, ismerősnek jelölés, Meetup-érdeklődés, chatjelentés és a **pont-értesítés** (mind a 14 pontforrás-indoklással).
- **ÚJ: az angol felület MARADÉK nélkül.** A második kör után megmaradt **147 hely** (amit a `context`-függő bekötő szándékosan kihagyott) be van kötve: **101 hely** a `context` nélküli fordítóval (`AppStrings.tr`), **46 hely** pedig a **megjelenítés helyén** (`AppText`/`AppStrings.tr` a nézetben — mert `const` térképben/lista­ban nem lehet függvényt hívni). Emellett a **határvonal is pontosítva**: a kereső-/hibahívások (`contains`, `startsWith`, `StateError`) **nem** feliratok, ezért kikerültek a célok közül.
- **Javítva (mérési rés, nem csak szöveg):** a **többsoros, escape-elt bekezdések** (pl. az **adatkezelési tájékoztató** és a rádió jogi szövege) eddig **ki sem kerültek** a célok közül, ezért angol módban magyarul maradtak — a szótár kulcsa mostantól a **feloldott** (valódi) szöveg, és a **12 új kulcs** fordítása is bekerült. Emellett a szótárból **törölve** 10 szemét kulcs (a saját extraktorom korábbi hibájából: regex-minta és interpolációs töredék).
- **ÚJ: angol felületen a hírek kategória- és címke-nevei is angolul jelennek meg** (pl. `Hírek → News`, `Partyajánló → Party Guide`, `fesztivál → festival`). A fordítás a **megjelenítésnél** történik a beépített szótárból, ezért nincs új hálózat és nincs új WordPress-mező; a **tulajdonnevek** (`Adam Bass`, `adaro`, `#TBT`) és az elírások **szándékosan** változatlanok maradnak, és a **magyar** felület is bájtazonos.
- **Mérve:** a bekötött helyek **147 → 0** kimaradt (a `const`-helyek a nézetben fordulnak); a „se be nem kötött, se le nem fordított" szövegek **619 → …** (a `screens`/`widgets` rétegben **191 → 0 cél**, a maradék nem cél: technikai azonosító, changelog, `lib/core/**`). A szótár a címkékhez **+22**, az Achievementekhez **+8** kulccsal bővült (a `Sokat tesz a közösségi jelenlétért.` **duplikált kulcsa** a mérés szerint **törölve**), így a **szótár 964 kulcs**, a célzott szövegek **901/901 (100%)**, duplikált kulcs **0**.
- **ÚJ (a tulajdonos kérése: *„az Achievement nevek is lehetnének angolul az angol verzióban és a leírása is"*):** angol felületen a **7 Achievement-név és a hozzájuk tartozó leírások is angolul** jelennek meg (pl. `Kezdő ütem → First Beat`, `HUHS legenda → HUHS Legend`), és a pont-egység is fordítva (`{n} pont → {n} points`). A jelvény-katalógus **két** forrásból érkezik (a szerverről és az app tartalék listájából), ezért a fordítás az **app szótárából** történik a megjelenítés helyén — így nincs plusz hálózat, és nyelvváltáskor **azonnal** vált. **Közben egy valódi hiba is javítva:** a `static` adatlisták **betöltéskor** fordítottak, ezért **rögzítették a nyelvet** (angolul indított app magyar módban is angolul mutatta a jelvényeket) — mostantól az adat magyar kulcs, a fordítás a megjelenítésnél.
- **Javítva (a tulajdonos jelzése: *„Magyarul »Közösség«, Angolul »Community«, de férjen ki"*):** a fejléc küszöbe **fix 360 px** volt a magyar feliratra mérve, ezért angolul a hosszabb „Community" nem fért ki, és a tartalék `FittedBox` **lekicsinyítette az egész fejlécet**. Mostantól a döntés a **tényleges (lefordított) felirat szélességéből** jön: a gomb belső margója 12 → 10 px, a hézagok 8 → 6 px, és a felirat csak akkor jelenik meg, ha **valóban kifér** — így **semmi nem zsugorodik**. Teszt őrzi: mindkét nyelven, **7 képernyőszélességen** nincs túlcsordulás és **nincs zsugorodás**.
- **Mérve (ehhez a két újításhoz):** `flutter analyze lib test` → **No issues found!**; `flutter test` → **1070/1070**; a fejléc-teszt + az Achievement-teszt **35/35** (a toplista/közösségi lista fordítása is őrizve); a címke-fordítás mutációs bizonyítéka **3/3**; a csomagban (`node tmp/verify-aab-364.mjs`) **versionCode 364**, a **szótár 966 kulcsa** és az új changelog-sor **mindhárom ABI**-ban megvan.
- **Amit ez a kiadás is tartalmaz:** a 363 (a maradék feliratok köre), a 362 (angol cikktartalom + a többsoros szövegek javítása), a 361 (**HU/EN nyelvváltó**), a 360 (`@mindenki` + Chat-odaugrás), a 359 (hideg indításnál is odaugrik), a 358 (Chat `@`-hivatkozás), a 357 (az értesítés megnevezi a cselekvőt), a 356 (hírlevél-védelem + `enableEdgeToEdge`), a 355/354 (nyeremény-leírás, DJ „Megjelenései").
- **⚠️ ŐSZINTE KORLÁT:** az **értesítések** nyelve a **profilban tárolt** nyelvből dől el, ezért egy olyan felhasználó, aki **még nem nyitotta meg** a 364-es appot (nincs `language` mezője), **magyar** értesítést kap — az első indítás után ez magától helyreáll. A **chatjelentés** több adminnak megy, ezért a push **nyelvenként csoportosítva** megy (egy csoportos küldés csak egy nyelvet tudna mondani). A **jelvények** neve a **szótárból** fordul, ezért ha a WordPress-adminban **átírod** egy jelvény nevét/leírását, az új szöveg a következő app-verzióig magyarul látszik; a **fejléc** döntése a valós betűtípus szélességét méri. A **kiadvány/esemény/DJ/szervező** angol **tartalma** a plugin **2.14.0** feltöltésére vár (utána a GYÍK, a kérdőív és a nyereményjáték szövege is automatikusan angol lesz). A fordítás gépi — a **jogi szövegeket** érdemes a tulajdonosnak átnéznie.

### 363 — az angol felület teljessé tétele (a második kör bekötése)
- **ÚJ (a tulajdonos kérése: „fent a 2.11.0 és így mindent megkéne csinálni"):** angol felületen a **listák, kártyák, gombok és állapotüzenetek** további **több száz** felirata is angolul jelenik meg — ezek eddig azért maradtak magyarul, mert nem a szabályos alakban (`Text('…')`, `label:`) álltak, hanem **feltételes ágban** (`cond ? 'A' : 'B'`), **lista-/térkép-értékben** vagy **alapértékként** (`?? 'A'`). **Mérve:** **327 hely** **44 fájlban** bekötve, amivel a bekötött helyek száma **783 → 1110** körüli; a fordítás továbbra is **be van építve** (nincs hálózat, nincs várakozás).
- **A szótár és a mérés berekesztve:** a szótár **921 kulcs**, a **lefedettség 892/892 (100%)**; a mért „se be nem kötött, se le nem fordított" szövegek száma **983 → 618** (ebből a látható felület **538 → 192**).
- **⚠️ ŐSZINTE KORLÁT:** **132 egyedi szöveg (157 hely)** továbbra sem jelenik meg angolul, mert a bekötéshez `BuildContext` kellene, és az adott helyen (osztály-szintű adatlista, statikus tábla) nincs — ezek a **következő kör** (a fordításuk **kész**, csak a megjelenítésnél kell fordítani). Az **események, DJ-k, szervezők és kiadványok** szövege továbbra is magyar (a plugin **2.12.0** hozza az angol mezőket). Az **értesítések** szerveroldali szövegei szintén magyarul mennek (külön kör).
- **Amit ez a kiadás is tartalmaz:** a 362 (angol cikktartalom + a többsoros szövegek javítása), a 361 (**HU/EN nyelvváltó** és az angol felület), a 360 (`@mindenki` + Chat-odaugrás), a 359 (hideg indításnál is odaugrik), a 358 (Chat `@`-hivatkozás), a 357 (az értesítés megnevezi a cselekvőt), a 356 (hírlevél-védelem + `enableEdgeToEdge`), a 355/354 (nyeremény-leírás, DJ „Megjelenései").

### 362 — a cikkek angolul (a felület nyelve a tartalmat is átváltja)
- **ÚJ:** angol felületnél a **legutóbbi cikkek is angolul** jelennek meg. A fordítást a **szerver** adja: a WordPress a cikk **rejtett meta** mezőjében tárolja az angol címet, kivonatot és törzset (a weboldalon **nem** látszik), az app pedig a kérésben elküldött `lang` paraméterrel kéri. **Mérve élesben:** `?lang=en` → **30/30 cikk angolul** (`has_en: true`), `?lang=hu` → **30/30 magyarul, változatlanul** (a plugin **2.11.0** kell hozzá — fent van).
- **ÚJ: nyelvváltáskor a betöltött tartalom is frissül** — eddig csak a feliratok váltottak volna, a memóriában lévő lista a régi nyelven maradt volna. A mentett válasz (ETag-es cache) is **nyelvenként külön** tárolódik, ezért nem keveredhet a két nyelv. **Mérve:** a `lang` paramétert **mind a 13** tartalom-végpont elviseli (a státusz nyelvvel és nélküle ugyanaz), így semmi nem tud eltörni, és a plugin következő verziója (esemény/DJ/szervező/kiadvány) **app-frissítés nélkül** érvényesül.
- **Amit ez a kiadás is tartalmaz (a 361-ből):** a **HU/EN nyelvváltó** a főoldal jobb sarkában a teljes felület angol szótárával (**589 egyedi szöveg**, 783 helyen), és a magyar fallback (ha nincs fordítás, a felirat magyar marad).
- **Amit SZÁNDÉKOSAN nem fordítunk:** a **Chat üzenetei, a hozzászólások és a nevek** — a felhasználók saját szövege magyar marad.
- **⚠️ ŐSZINTE KORLÁT:** az **események, DJ-k, szervezők és kiadványok** szövege **egyelőre magyar** — ezek angol mezőit a plugin **2.12.0** hozza (utána a meglévő tartalom fordítása következik); a 361-es csomagot **nem kell feltölteni**, mert ugyanazt tudja, mint a 362, csak a tartalom-nyelv nélkül.
- **Javítva (mérve, a 362 újraépítésének oka):** a **többsoros, összefűzött** szövegek fordítása. A Dart a szomszédos literálokat összefűzi, ezért a **futásidejű** szöveg a fűzött változat — a szótár viszont **10 helyen** csak a **töredéket** ismerte, így a fordítás **csendben nem érvényesült** (angol módban is magyar maradt: a Több/Beállítások sorok, a „Keverés közben…" súgó, a privacy-szakaszok, a vásárlási diagnosztika). **+24 szótár-kulcs**, a megjelenítési helyek bekötve, és új teszt őrzi (a fűzött szöveg kulcsa legyen a szótárban — őrszemmel, mert a teszt első változata nulla helyet vizsgálva zölden hazudott).

### 361 — HU/EN nyelvváltó: az app felülete angolul is elérhető
- **ÚJ (a tulajdonos kérése: „valahogy megkéne oldani az angol nyelvet az appban"):** a **főoldal jobb sarkában** megjelent a **HU/EN kapcsoló** — a felirat mindig a **másik** nyelv kódja (magyar módban „EN"). A váltás **azonnal** átrajzolja a felületet (a már megnyitott képernyőket is), és a választás **megjegyződik**: a következő indításnál is azon a nyelven indul, és a szótár már a `runApp` előtt betölt, ezért nincs „bevillanó" magyar felirat. A magyar marad az **alapértelmezett**, és minden ismeretlen/hibás mentett érték is magyarrá esik vissza.
- **Amit lefordítottunk:** a **felület szövegei** — mérve **589 egyedi szöveg, 783 helyen** (menük, gombok, címkék, űrlap-feliratok, tippek, hiba- és állapotszövegek). A fordítás **be van építve** az appba (`assets/i18n/en.json`, **609 kulcs**), ezért angol módban **nincs hálózat és nincs várakozás**; ha valamire nincs fordítás, a felirat a **magyar** marad (soha nem üres).
- **Amit SZÁNDÉKOSAN nem fordítunk:** a **Chat üzenetei, a hozzászólások és a nevek** — a felhasználók saját szövege magyar marad. Ezt a kódban **forrás-lint** is őrzi (a chat-üzenet szövege nem mehet át a fordítón).
- **Hogyan épül be (a következő köröknek):** a `Text(...)` helyek `AppText(...)`-re cserélődtek (a szöveg a konstruktorban marad, ezért a `const` felület **nem tört el**), a címkék/tooltipek pedig `tr(context, '…')`-t kaptak; az **interpolált** feliratok `trArgs(...)`-tal mennek (`{n}` helyőrzőkkel). A szótár kulcsait **a kód adja** (`tools/extract-ui-strings.mjs`), a lefedettséget a `tools/check-i18n.mjs` méri (**100%**).
- **Amit ez a kiadás is tartalmaz (a 360-ból):** `@mindenki` a Chatben + a Chat-értesítés pontosan a megjelölt (akár mélyen lévő) üzenetre ugrik; **(a 359-ből):** az odaugrás hideg indításnál is; **(a 358-ból):** a Chat `@`-hivatkozás; **(a 357-ből):** az értesítések megnevezik a cselekvőt; **(a 356-ból):** a hírlevél-védelem és a `enableEdgeToEdge()`.
- **⚠️ ŐSZINTE KORLÁT:** a **tartalom** (cikkek, események, DJ-k, kiadványok) nyelve **egyelőre magyar** — az angol cikk-változatok a szerveren már élnek (a legutóbbi **30 cikk**, mérve `?lang=en` → 30/30), de az app a tartalmat még magyarul kéri; ez a **következő kör**. A csomagban mérve: a szótár **benne van** (609 kulcs), és **mindhárom ABI** `libapp.so`-jában megvan az `AppText`, `AppStrings`, `LanguageSwitchButton` és `languageProvider` szimbólum, valamint a 361 changelog-sora (UTF-16LE).

### 360 — `@mindenki` a Chatben + a mélyen lévő üzenethez is odaugrik a Chat-értesítés
- **ÚJ (a tulajdonos kérése: „kéne egy @mindenki tag is, amit ha beütök, kap mindenki notifyt és csak moderátor/admin használhassa"):** a `@min…` beírásakor az admin/moderátor a **Mindenki** találatot kapja a javaslatlista **első** helyén, és az üzenet elküldésekor **minden regisztrált felhasználó értesítést kap** (mérve: **41** címzett). A jogosultságot a **szerver** kényszeríti (`sanitizeMentions` csak privilegednek engedi; a nem admin küldést kihagyja), a szövegben a `@mindenki` **ki van emelve, de nem kattintható** (nincs mögötte adatlap), és **üres lekérdezésnél nem ajánljuk fel**, hogy egy véletlen koppintás ne küldjön értesítést mindenkinek. A fan-out **legfeljebb 500 címzett** (ma 41), a szerzőt kihagyja, és a hiba nem viheti el a már beírt üzenetet.
- **Javítva (a tulajdonos jelzése: „egy régebbi chat like … rányomtam és nem dobott a chat üzire … régebbi chat üzivel nem megy, újabba igen"):** a Chat-értesítés **a mélyen lévő, régebbi üzenetnél is** pontosan a megjelölt üzenetre ugrik. **A mért gyökér (kódból, widget-teszttel reprodukálva):** a lista csak a **látható** elemeket építi fel, ezért a mélyen lévő kártyához nem volt kontextus, és a kód ilyenkor a lista **végére** ugrott — az a **legrégebbi** üzeneteket mutatja, nem a megjelöltet; a legfrissebb üzenetnél azért működött, mert az már fel volt épülve. Mostantól a cél **indexéből becsült** pozícióra ugrunk, majd onnan pontosítunk (néhány körben, mert a lista hossza maga is becslés).
- **Amit ez a kiadás is tartalmaz:** a 359 (a hideg indításnál is működő odaugrás), a 358 (Chat `@`-hivatkozás + értesítés a megemlítettnek), a 357 (az értesítések megnevezik a cselekvőt), a 356 (hírlevél-védelem + `enableEdgeToEdge`), a 355/354 (nyeremény-leírás, DJ „Megjelenései").

### 359 — a Chat-értesítés MOSTANTÓL MINDIG a megjelölt üzenetre ugrik
- **Javítva (a tulajdonos jelzése: „chat üzenet like értesítés néha a megfelelő helyre dob, ha rányomok, néha nem"):** az odaugrás eddig **hideg indításnál elmaradhatott**. **A mért gyökér (kódból):** a Chat fül **lusta** módon épül fel (`MainNavigation._tabs[index] ??=`), ezért ha a Chatet még nem nyitottad meg abban a munkamenetben, a Chat **élő ablaka üresen indul** (a `communityPostsProvider` hideg). Az odaugrás viszont az üres ablakot is **lapozásnak számolta**, és mivel a betöltés alatt a képernyő **pörgőt** rajzol (folyamatos képkockák), a **10 lapos keret másodpercek alatt elfogyott**, mielőtt az adat megérkezett — ilyenkor a Chat a szokásos módon nyílt meg, odaugrás nélkül. Meleg indításnál (a Chat ebben a munkamenetben már nyitva volt) viszont működött: **ez adta a „néha igen, néha nem" jelenséget.** A javítás a tiszta tervben egy új állapot (`waiting`): amíg az élő ablak üres, az app **vár** (nem lapoz és nem fogyasztja a keretet), az adat megérkezésekor pedig magától megkeresi az üzenetet; emellett a lap-keret **csak valódi lapozás után** fogy, és a post-frame callback nem indít fölösleges lapozást, ha közben megjött az adat.
- **Amit ez a kiadás is tartalmaz (a 358-ból):** a Chat `@`-hivatkozás (személy, cikk, DJ, szervező, esemény, kiadvány) javaslatlistával, kattintható hivatkozásokkal és értesítéssel; **(a 357-ből):** az értesítések megnevezik a cselekvőt; **(a 356-ból):** a hírlevél-védelem (plugin **2.10.0**) és az `enableEdgeToEdge()`; **(a 355-ből és a 354-ből):** a nyeremény leírása a játék alatt + azonnali nyitás, valamint a DJ-adatlap „Megjelenései" szakasza.

### 358 — Chat `@`-hivatkozás (személy, cikk, DJ, szervező, esemény, kiadvány)
- **ÚJ (a tulajdonos kérése: „egy @xy betűvel tudjak hivatkozni a chaten cikkre, djre, szervezőre, eseményre, kiadványra vagy személyre/userre … elkezdem irni a betűket és dobja fel a lehetőségeket"):** a Chat beviteli mezőjében a `@` után **gépelés közben megjelenik a javaslatlista**, típus szerint csoportosítva (Személyek / Cikkek / DJ-k / Szervezők / Események / Kiadványok). A **személy** mindenkinek elérhető, a **tartalom csak adminnak/moderátornak** — ezt a **szerver is kényszeríti** (`publishChatPost`): a nem engedett hivatkozásokat egyszerűen **kihagyja** a mentett listából (a szöveg marad), és visszaadja a kihagyottak számát, amit az app jelez.
- **Javítva/ÚJ: minden hivatkozás kattintható** — a személynél a profilja, a cikknél a cikk, a DJ-nél az adatlapja, a szervezőnél, az eseménynél és a kiadványnál a saját oldala nyílik meg. Az útvonal-feloldó **közös** az értesítés-központtal (`content_target.dart`), ezért a kettő nem tud széthúzni.
- **ÚJ: a megemlített személy értesítést kap** — „{ki} megemlített a Chatben: „{részlet}”", üzenetenként legfeljebb **5 személy**, és a koppintás (a **357** óta) **arra az üzenetre visz**, amelyről szól; a szerző nevét a 357-ben bevezetett több-forrású feloldás adja.
- **Amit ez a kiadás is tartalmaz (a 357-ből):** az értesítések megnevezik a cselekvőt, és a Chat-értesítés a megjelölt üzenetre ugrik; **(a 356-ból):** a hírlevél-védelem (plugin **2.10.0**) és az `enableEdgeToEdge()`; **(a 355-ből és a 354-ből):** a nyeremény leírása a játék alatt + azonnali nyitás, valamint a DJ-adatlap „Megjelenései" szakasza.

### 357 — az értesítések megmondják, KI tette, és a Chat-értesítés a helyére ugrik
- **Javítva (a tulajdonos jelzése: „jön notify hogy kedvelték egy chat üzenetem, meg arról is hogy valaki írt egy hírhez kommentet, de odaírhatná, hogy KI likeolta"):** az értesítéseknél **látszik a cselekvő neve**. **A mért gyökér** (éles `notifications` gyűjtemény): az 5 chat-lájk értesítésből **2-ben nem volt név** („Egy HUHS tag kedvelte a Chat-üzenetedet."), pedig a küldő profiljában **mindkét esetben volt** `displayName` — a szerver **egyetlen** forrásból (`community_profiles`) olvasott. Mostantól a név **több forrásból** jön (közösségi profil → nyilvános profil → Auth-név), és a **cikk-komment** értesítés is megnevezi a hozzászólót egy rövid szövegrészlettel. **Ez szerveroldali javítás** (külön telepítés, `firebase deploy --only functions`), ezért az új értesítéseknél a 357 nélkül is jó.
- **Javítva (a tulajdonos kérése: „a chatnél meg odaugorhatna arra az üzenetre amit lájkoltak, ha a notifyre nyomok"):** a **Chat-értesítésre koppintva** az app a Chat képernyőn **arra az üzenetre görget** (és rövid ideig ki is emeli), amelyről az értesítés szól — eddig csak a legfrissebb üzenetekkel nyílt meg. A megkereséshez legfeljebb **10 lapot (300 üzenetet)** lapozunk, utána nem görgetünk találomra (`lib/services/chat_focus_plan.dart` + `LiveFeedScreen(focusPostId: …)`).
- **Amit ez a kiadás is tartalmaz (a 356-ból):** a hírlevélnél nem megy ki újra a megerősítő e-mail ugyanarra a címre (plugin **2.10.0**), és a Play „teljes képernyős mód" javaslatára az `enableEdgeToEdge()` hívás (**mérten nem változtat a felületen**); **(a 355-ből):** a nyeremény leírása a játék alatt + azonnali nyitás; **(a 354-ből):** a DJ-adatlap „Megjelenései" szakasza.

### 356 — a hírlevél nem küldi ki újra a megerősítő levelet + a Play „teljes képernyős mód" javaslata
- **Javítva (a tulajdonos jelzése: „hírlevél feliratkozásnál ugyanazt az email címet bármennyiszer be tudják küldeni és kimegy az ellenőrző mail is"):** a hírlevél-feliratkozásnál **ugyanarra a címre nem megy ki újra a megerősítő e-mail.** A gyökér a szerveren volt: ha a cím `pending` állapotban volt (kiment a levél, de nem kattintottak rá), **minden beküldés** új kérést indított a Mailchimpre, az pedig újra kiküldte a megerősítő levelet — a felületen korlátlanul. **Ehhez a plugin 2.10.0 kell** (`build/huhs-mobile-api-2.10.0.zip`): e-mailenkénti várakozás (alapból 15 perc), amelyen belül a Mailchimp-hívást meg sem indítjuk. Az app a háromféle **sikeres** választ megkülönbözteti (`newsletter_plan.dart`), és a hozzá tartozó szöveget mutatja: „elküldtük", „már fel van iratkozva", „már kiment, X perc múlva kérhetsz újat". A szavazásnál a hírlevél hibája **nem viheti el a szavazatot** (try/catch).
- **A 356 újdonsága a Play „teljes képernyős mód" javaslatára:** a `MainActivity` megkapta a `enableEdgeToEdge()` hívást. **Ez a felhasználónak nem látható:** Android 15/16-on a rendszer (targetSdk 36 mellett) **amúgy is kötelezően** teljes képernyős, a régebbi Androidokon pedig **mérten semmi nem mozdul el** — két csomagot összevetve (android-34 emulátor) a felület sorai bitre egyeznek, csak a statuszsáv sávja lesz ~11%-kal sötétebb.
- **Amit ez a kiadás is tartalmaz (a 355-ből):** a nyeremény leírása a játék alatt + a nyereményjáték azonnali nyitása; **(a 354-ből):** a DJ-adatlap „Megjelenései" szakasza; **(a 353-ból):** a Firebase-család frissítése és a lassú betöltés javítása; és a 352 vásárlási diagnosztikája.

### 355 — a nyeremény leírása a játék alatt + azonnali nyitás
- **Javítva (a tulajdonos jelzése: „a nyereményjátékba nem kerül bele a játék leírása"):** a **nyeremény leírása és típusa mostantól a játék ALATT is látszik** — eddig csak a sorsolás után, a nyertes mellett. A gyökér **kettős** volt: a WordPress a nyitott játéknál üresen küldte ezeket a mezőket (csak sorsolás után adta ki), és az app a nyitott nézetben nem is rajzolta ki őket. **Ehhez a plugin 2.8.0 kell** (`build/huhs-mobile-api-2.8.0.zip`).
- **Javítva (a tulajdonos jelzése: „100 év mire betölt"):** a **nyereményjáték azonnal megnyílik.** A „játszottál már?" állapot eddig minden megnyitásnál megvárta a teljes szerver-körutat (app → Cloud Function → WordPress), ami hidegen **több másodperc** volt. Mostantól a telefon a **legutóbbi ismert szerver-válaszból** rajzol azonnal — **akkor is, ha az „még nem játszottál"** —, a háttérben pedig ellenőriz; ha a válasz eltér, a jelzés frissül (a szerver az erősebb forrás).
- **Amit ez a kiadás is tartalmaz (a 354-ből):** a **DJ-adatlap „Megjelenései"** szakasza — a DJ azon kiadványai, amelyekben szerepel, a legfrissebbel az élen, „Összes megjelenése" gombbal.
- **A 355 a 353 minden javítását is tartalmazza** (Firebase-család major emelése + a lassú betöltés javítása) és a 352 vásárlási diagnosztikáját.

### 354 — a DJ megjelenései a DJ-adatlapon
- **ÚJ (a tulajdonos kérése):** a **DJ-adatlapon** megjelent a **„Megjelenései"** szakasz: azok a **kiadványok, amelyekben az adott DJ szerepel** — a **legfrissebbel az élen**. Négy kiadvány látszik rögtön, alatta az **„Összes megjelenése"** gomb nyitja a **teljes, DJ-re szűrt listát**.
- **A kártya ugyanaz, mint a kiadványok listájában:** borító, előadók, megjelenés dátuma, műfaj — koppintásra a **kiadvány adatlapja** nyílik meg (a részletes adat már a lista rajzolásakor elkezd töltődni, ezért a megnyitás azonnali).
- **Miért azonnali:** a szűrést a **szerver** végzi (`/releases?artist=<id>`), a választ pedig az app a **mentett** példányból rajzolja ki, és a háttérben egyeztet — ezért nincs villogás, és a szakasz **mentett adatból hálózat nélkül is** látszik. Ha a DJ-nek nincs megjelenése, a szakasz **nem hagy helyet** maga után.
- **Amit szándékosan NEM tettünk:** nem nyúltunk a **közelgő fellépések** szakaszhoz (az már mutatja a következő eseményeket), és nem változtattunk a kiadvány-adatlapon vagy a vásárlásban.
- **A 354 a 353 minden javítását is tartalmazza** (Firebase-család major emelése + a lassú betöltés javítása) és a 352 vásárlási diagnosztikáját.

### 353 — a Firebase-összetevők frissítése + a lassú betöltés javítása
- **Javítva (a tulajdonos jelzése: „sok adat lassan tölt be"):** a **kvíz** már az első képkockán mutatja, hogy **már játszottál** (a telefon megjegyzi, és a háttérben egyeztet a szerverrel) — eddig pár másodpercig úgy látszott, mintha újra lehetne játszani.
- **Javítva:** a **DJ-adatlap „ez az enyém / átvehető"** állapota (a `getArtistClaimStatus` döntése, szerveroldalon mérve ~1,4 s) és a **profil „DJ-adatlap" kártyái** mostantól a **mentett válaszból azonnal** megjelennek, a szerver pedig a háttérben frissít. Ha nincs hálózat, a **mentett** állapot marad (nincs hiba-képernyő).
- **ÚJ (háttérben):** bejelentkezés után az app **előtölti** a saját claim-adatait és a saját profilját, ezért az első megnyitás is azonnali.
- **Belső frissítés:** a Firebase-család (bejelentkezés, adatbázis, értesítések, App Check, Cloud Functions) **új verzióra** került, a Google legfrissebb javításaival.
- **Amit ez a háttérben jelent (mérve):** az R8-optimalizálás a riport szerint **54,33% → 92,09%** (obfuszkiálás 54,52% → **92,28%**, csökkentés 54,46% → **92,22%**), a becsomagolt **DEX 12,03 MB → 9,86 MB**, mégpedig **3 helyett 2 DEX-fájllal**, és **eltűnt a becsomagolt, elavult SafetyNet** könyvtár (**394 osztály → 0**). Utóbbi pontosan az volt, amit a Play kiadás-irányítópultja jelzett.
- **Miért lett ekkora a nyereség:** a blokkolt kód **39,78%-át egyetlen, a Google-től származó keep-szabály** adta (`-keep class com.google.android.gms.internal.** { *; }` a `firebase-auth` 23.2.1-ből) — ezt a **24.2.0-s** kiadás **már nem tartalmazza**. A mérés eszköze: `node tools/analyze-r8-config.mjs`.
- **A WordPress-plugin NEM változott** (2.7.0), és a **szerveroldali függvények sem** — **nincs API-oldali változás**, ezért a plugin kiadásjegyzékébe nem kerül bejegyzés.
- A **353 a 352 vásárlási diagnosztikáját is tartalmazza**.

### 352 — vásárlási diagnosztika (a vásárlási hiba kivizsgálásához)
- **ÚJ:** a **Több → Az appról** képernyőn megjelent a **Vásárlási diagnosztika** szakasz. Egy gomb megmutatja, amit eddig **nem láttunk**: hogy a Google Play vásárlási szolgáltatása elérhető-e az adott készüléken, **hány terméket** ad vissza a Play, milyen **áron és pénznemben**, mit **nem** adott vissza, és mi volt a **legutóbbi vásárlási hiba nyers kódja** (a Play saját üzenetével együtt). A jelentés egy mozdulattal a **vágólapra** tehető.
- **Miért kellett:** a tulajdonos a táblagépen ugyanazt a vásárlási hibát kapta („ez a tétel nem áll rendelkezésedre az országodban"), mint korábban a telefonon — **ugyanazzal a Google-fiókkal**, amellyel a telefonon már működik a vásárlás. A hibaüzenetet a **Play saját ablaka** írja ki, a kódunk pedig **nem látta** a hibakódot, ezért csak következtetni lehetett. Ez a kiadás azt a hiányzó **műszert** adja hozzá — vásárlást nem indít és nem ír semmit.
- A **352 a 351 minden javítását is tartalmazza** (értesítés-kijelölés, DJ-adatlap szerkesztése, magyar „Adatlap átvétele", görgetés).

### 351 — az értesítés-kijelölés javítása (több sor egyszerre)
- **Javítva:** az **értesítéseknél mostantól több sor is kijelölhető egyszerre**. Eddig minden koppintás **lecserélte** az előző kijelölést — ezért csak egyet lehetett kijelölni, vagy az „összes kijelölése" gombbal mindet. A gyökér a képernyő állapotkezelése volt (a `clear()` előbb futott, mint a váltás kiszámítása), nem a kijelölés szabálya; az állapot mostantól **tesztelt osztályban** él.
- A 351 a **350 minden újdonságát** is tartalmazza (lásd a következő bejegyzést).

### 350 — a DJ-adatlap szerkesztése, értesítés-kijelölés, magyar „Adatlap átvétele"
- **ÚJ:** az **átvett DJ-adatlapodat te szerkesztheted** az appban: név, valódi név, város, ország, bemutatkozás, közösségi linkek, valamint a **profil- és borítókép cseréje**. Amit **nem** tudsz átírni (szándékosan): a foglalási e-mail cím, a privát címed, a mûfajok és a ház döntései (láthatóság, kiemelés) — a képernyő ezt meg is mondja.
- **ÚJ:** az **értesítéseket ki lehet jelölni** törléshez: a fejlécben a pipa ikon indítja a kijelölést, ott van az „összes kijelölése" és a „kijelöltek törlése". Így **azt** törlöd, amit akarsz — nem az egész fület, és nem is egyenként.
- **Szöveg:** a „Claim" szó helyett mindenhol magyar megfelelő áll: **„Adatlap átvétele"**, „Átvétel visszavonása", „Átvett DJ-adatlap", „Ezt a DJ-adatlapot már átvette egy fiók."
- **Javítva:** az értesítésre megnyíló **saját adatlap aljára rendesen le lehet görgetni** — az utolsó kártya nem marad a rendszer alsó sávja alatt. Ugyanez a szabály **egy helyre** került, ezért a hír-, esemény-, DJ- és szervező-adatlapokon is ugyanaz érvényes.
- **Biztonság (szerveroldali, plugin 2.7.0):** a WordPress nyilvános válasz-gyorsítótárából **kivettük** a privát `claim-emails` végpontot, mert előtag-egyezés miatt a DJ privát e-mail címe 120 másodpercig a gyorsítótárból is kiszolgálható lett volna.

### 349 — jutalmazott ingyenes letöltés, tabletes kiadvány-adatlap, villogó listák
- **Javítva:** a **jutalmazott reklámmal feloldható ingyenes külső link** (`free_link`) mostantól **tényleg megnyílik**. A gyökér a szerveren volt: a „lejátszható változatok" listája nem tartalmazza a `free_link`-et (nem fájl, hanem külső link), ezért a kapu **soha** nem látta feloldottnak — hiába futott le a reklám, a felület 20 másodpercig várta a jóváírást, majd hibát írt. Éles adat: **1 ilyen feloldás** volt a rendszerben, és azt a régi kapu **elutasította**.
- **Javítva:** tableten **fekvő nézetben** a **kiadvány adatlapja** nem lesz óriási — a tartalom legfeljebb 1100 px széles sávban jelenik meg, a négyzetes **borító** pedig 360 px.
- **Javítva:** a **DJ-k és a szervezők listája nem villog** többé: a globális WordPress-frissítés-jelző eddig **reload**-ot okozott, ilyenkor a kész lista helyett **spinner** villant; mostantól a korábbi lista a helyén marad, amíg az új adat meg nem érkezik.
- **Javítva:** a **„Megvásárolt zenéim"** listában **nem látszik** az a kiadvány, amely **már nincs a nyilvános listában** (a feloldás persze megmarad, és ha visszakerül, újra megjelenik).

### 348 — a DJ-adatlap claim javítása + működő értesítés-koppintás
- **Javítva:** a **DJ-adatlapot csak az claimelheti** (jelölheti a magáénak), akinek a bejelentkezési e-mail címe egyezik az adatlapon szereplő **booking vagy privát** e-mail címmel. Az **admin-kivétel megszűnt** — élesben pont az tette lehetővé, hogy a tulajdonos fiókjára egy **idegen** DJ adatlapja kerüljön („Sunshite State"), amit most le is vettünk.
- **Javítva:** a „DJ-adatlap claimelése" gomb **csak akkor jelenik meg**, ha valóban claimelhető (a döntést a szerver hozza, e-mail cím nélkül) — eddig minden hitelesített fióknál látszott.
- **ÚJ:** a **saját claim visszavonható** a DJ-adatlapról („Claim visszavonása").
- **ÚJ:** a **nyilvános profilodon** megjelenik a claimelt DJ-adatlapod **kattintható kártyaként**.
- **Javítva:** az **„Új DJ került fel"** értesítésre koppintva megnyílik az adott DJ adatlapja — eddig **semmi** nem történt. Ugyanígy javult az **„Új szervező"** és a **chatjelentés** értesítés.

### 347 — a lejátszó a képernyő elhagyása után is vezérelhető + tabletes kártyák
- **Javítva:** a megvásárolt zene lejátszója a **képernyő elhagyása után is vezérelhető** — a zárképernyő **következő/előző** gombja mostantól működik, és a **dal végén magától jön a következő** tétel. Eddig ilyenkor a gomb ott maradt, de nem csinált semmit, a dal végén pedig **megállt a zene** (a döntés a képernyőhöz volt kötve).
- **Javítva:** a **kevert lejátszási sorrend stabil** — a „következő" tétel nem ugrál, amikor a lista frissül (új vásárlás, új letöltés, újbóli ellenőrzés).
- **Javítva:** tableten **fekvő nézetben** a **kiemelt hírkártyák** és a **játék (kvíz) kártya** akkora, mint a többi kártya — eddig a teljes szélességben óriásira nőttek. Álló nézetben szándékosan nem változott semmi.

### 346 — a lejátszó elindul (hibajavítás)
- **Javítva:** a „Megvásárolt zenéim" lejátszója **elindul** — a 345-ben a zene el sem indult, és egy **angol** hibaüzenet jelent meg a képernyőn.
- **Javítva:** minden hibaüzenet **magyar**; ha egy zene indítása nem sikerül, a **hang visszakerül a rádióhoz** (az app nem némul el), és a sor nem marad „ez szól" állapotban.
- **Javítva:** a lejátszási lista és a lapozás **mindig az összes letöltött zenét** mutatja (előfordult, hogy csak egy tételt látott: „1/1 · 15 letöltve").
- **Javítva:** a zárképernyőn a **tekerősáv hossza** és az **aktuális tétel jelölése** is helyes.
- **Javítva:** a lejátszás indítása nem indul el kétszer véletlenül, és a koppintás nem vész el.

### 345 — kikapcsolt képernyőn is szól a zene, és szerkeszthető a lejátszási lista
- A megvásárolt zene mostantól **kikapcsolt képernyőn is szól**, és a **zárképernyőn** (meg az értesítésből, illetve a fejhallgató gombjaival) vezérelhető: előző, szünet/lejátszás, következő, stop és tekerés.
- **Hangfókusz:** ha más app indít zenét, vagy hívást kapsz, a lejátszó szünetel; **hívás után magától folytatja** (más zene-apptól nem veszi vissza a hangot). A **fejhallgató kihúzásakor** is megáll.
- A lejátszó **nem áll meg**, ha elhagyod a képernyőt — visszatérve onnan folytatja a kijelzést, ahol a zene tart.
- A **rádió érintetlen** marad: külön szolgáltatás, a zene csak akkor veszi át a hangot, ha elindítod, és stopnál visszaadja.

### 344 — a frissen vásárolt zene azonnal megjelenik
- A frissen megvásárolt (vagy reklámmal feloldott) zene már **másodperceken belül** megjelenik a „Megvásárolt zenéim" listában. Eddig előfordulhatott, hogy a lista a munkamenet végéig a **mentett** állapotot mutatta (a megnyitás nem kérdezte le újra a szervert), ezért az új vásárlás csak az app újraindítása után látszott.

### 343 — gyorsabb betöltés, azonnali lájk/ismerős, tekerhető lejátszó
- **Gyorsabb betöltés:** a hírek, a kiadványok, a főoldali kérdőív/nyereményjáték sor és a saját zenéid listája a **készüléken tárolt példányból azonnal** megjelenik, a frissítés a háttérben fut. A lassulás oka a tárhely válaszideje (mérve 0,4–2,0 másodperc kéréseként, a válasz méretétől függetlenül), ezért a megoldás a helyi gyorsítótár és a háttérbeli egyeztetés — nem a tárhely cseréje.
- A hírek megnyitása, a keresés és a kategóriaváltás már **nem vár** a szerverre; a lehúzásos frissítés viszont továbbra is valódi, friss választ kér.
- A főoldali sorok betöltés közben **helykitöltő kártyát** mutatnak (eddig üresen maradtak, és a kártya másodpercekkel később „pattant be").
- **A lájk azonnal látszik:** a chat-üzenet reakciója a koppintás pillanatában megjelenik (a szám is azonnal mozdul), a szerverhívás a háttérben fut; ha nem sikerül, a jelzés **visszaáll** és üzenetet kapsz (eddig néma hiba volt).
- **Az ismerősnek jelölés is azonnal látszik**, és a bejövő felkérés elfogadása/elutasítása is — ez eddig hiba esetén **semmilyen** visszajelzést nem adott.
- **Tekerhető folyamatjelző** a „Megvásárolt zenéim" lejátszójában (`0:42 / 4:10`), húzás közben a sáv nem ugrik vissza.
- **Stop gomb:** megállítja a zenét és a szám elejére áll (a cím a sávban marad, egy koppintással újraindul).
- **Lejátszási lista** („Lista") a letöltött zenékből, a lejátszási sorrendben, az aktuális kiemelve.
- **Ismétlés** (nincs / mind / egy) és **keverés** — keverésnél az épp hallgatott zene marad az első.
- **Folytatás ott, ahol abbahagytad:** a lejátszó fiókonként megjegyzi a helyet, és felajánlja („Elölről" / „Folytatás").

### 342 — a könyvtár címei újra megjelennek
- **Javítás:** a 341-ben a „Megvásárolt zenéim" lista kártyái **végig „Adatok betöltése…"** állapotban maradtak (a képernyőfelvételen látszott), miközben a lejátszósáv már a valódi címet mutatta. Az ok: a kártya csak a lusta lekérdezés térképét nézte, a nyilvános **katalógust** nem.
- Most a kártya és a lejátszási sor **ugyanabból** a térképből dolgozik, és a regressziót **forrás-lint** őrzi (a hibát visszatelepítve a teszt elhasal).

### 341 — a lejátszó csak a letöltött zenéket játssza
- A „Saját zenéim" neve **„Megvásárolt zenéim"** lett, és a Több menüben a szakasz **nyitva indul**, mint a többi (eddig csukott kártyaként lógott ki).
- A lejátszó **csak a letöltött** zenéket játssza: az előre/hátra lapozás és a szám végi továbblépés **átugorja** a le nem töltött tételeket, és nem indít helyettük letöltést. Ha egy zenét le akarsz játszani, de nincs meg, a lejátszó **kiírja**, hogy előbb le kell tölteni.
- A nyilvános listáról időközben lekerült kiadvány (pl. régi reklámmal feloldott zene) mostantól **meg van nevezve** („Ez a kiadvány már nem elérhető"), nem pedig „Kiadvány #szám" — és nem kerül a lejátszási sorba.

### 340 — a kvíz azonnal jelzi, ha már kitöltötted
- A kvíz megnyitásakor eddig néhány másodpercig úgy látszott, mintha még játszhatnál; mostantól **azonnal** „már játszottál" látszik.
- A beküldés tényét a telefon jegyzi meg, a szerver válasza a háttérben érkezik — és **ő dönt**: ha az admin újranyitotta a kvízt, a jelzés törlődik és újra játszható.
- A kérdőívnél és a nyereményjátéknál ez már eddig is így működött; a kvíz maradt ki.

### 339 — „Saját zenéim": a megvásárolt zenék könyvtára
- ÚJ menüpont a Több menüben: a megvásárolt (és reklámmal feloldott) zenéid egy helyen, a fiókodhoz kötve.
- A zenék lejátszhatók az appban; a szám végén magától a következőre lép, és a sor a következő kiadvánnyal folytatódik.
- A fájlok letölthetők a készülékre, így offline is szólnak; bármikor törölhetők, és utána újra letölthetők — a vásárlás megmarad.
- A **régebbi** vásárlásaid és reklámmal feloldott zenéid is megjelennek (a szerver a meglévő jogosultságaidat listázza).
- Más fiókkal belépve sem a zeneid, sem a letöltött fájljaid nem látszanak és nem tölthetők le (a lista és a helyi tároló is fiókonként külön).

### 338 — chat-értesítések, ikonjelvény és a folyamatos rádió
- Értesítést kapsz, ha valaki kedveli a Chat-üzenetedet, vagy válaszol rá (push nélkül, csak az app értesítéslistájában).
- A cikkhez írt hozzászólásodra adott válaszról is szólunk (ez eddig is működött).
- Az app ikonja mutatja az olvasatlan értesítéseid számát.
- A rádió folyamatosan szól akkor is, ha a képernyő ki van kapcsolva — javítottuk a lejátszást, ami néhány perc után megállt.
- A rádió elhallgat, ha közben elindítasz egy másik zenét (Spotify, YouTube), és amint az befejeződik, magától folytatódik.

### 337 — a YouTube-videó az appban játszódik le
- A cikkekben lévő YouTube-videó mostantól az appban játszódik le: a videó a cikk „Média" szakaszában jelenik meg saját lejátszóval, nem nyitja meg a YouTube-alkalmazást. Ha egy videó beágyazása tiltott, marad egy „Megnyitás a YouTube-on" gomb.

### 336 — a saját reakciód jelzése a Chatben
- A Chat-üzeneteknél mostantól egyértelműen látszik, hogy **TE** már reagáltál: a reakciógomb bejelölve (pipa) és kiemelve jelenik meg. Nevek nem szerepelnek, csak a saját reakciód.

### 335 — beküldés szerepkör szerint
- Eseményt mostantól csak szervezői szerepkörrel lehet beküldeni (a DJ-t DJ-, a szervezőt szervezői szerepkörrel, ahogy eddig) — a beküldő gomb csak annak látszik, akinek szabad.
- Az Achievement-útmutató megmondja, ki mit küldhet be, és hogy a beküldésért járó pont a jóváhagyáskor jár a beküldőnek.

### 334 — pontos Achievement-útmutató, három új pontforrás, rang-frissítés
- Az Achievement-útmutató (Több → Achievementek) pontos leírásokat kapott: a napi keretek (lájk 3, komment 3, beküldés 3), a lájkpont véglegessége, és az is, hogy az esemény/meetup pont **eseményenként egyszer** jár, de lemondásnál elvész.
- A szintek és jelvények listája mostantól a szerverről jön, ezért azonnal követi, ha az adminban átírnak egy küszöböt vagy nevet.
- Kiadvány megvásárlásáért +20 pont jár minden megvásárolt változatért (a vásárlást a Google Play ellenőrzi).
- A jóváhagyott beküldésekért (esemény, DJ, szervező) +10 pont jár a beküldőnek, naponta legfeljebb 3 beküldésért.
- ÚJ napi aktivitási pont: a cikkhez írt hozzászólásaidért és a chat-üzeneteidért a következő napon 1–5 pontot kapsz, amennyit a szerver az aktivitásodból számol.
- A rang és a jelvény továbbra is gyorsítótárból jelenik meg azonnal, de szintlépésnél magától frissül.

### 333 — NEM ment ki (a tartalma a 334-ben van)
- A 333 elkészült, de **egyetlen Play-sávra sem került fel** (a mérés szerint az alpha és az internal sávon is csak egy üres piszkozat maradt). A tartalma **változatlanul a 334-ben** van, ezért a tesztelők onnan kapják meg.

### 332 — villogás javítása + lájkpont-jelzés
- A hírek, a DJ-k és az események listája görgetés közben már nem villog — a képek áttűnés nélkül, azonnal megjelennek.
- Ha a napi lájkpontod (3) elfogyott, az app mostantól szól, mielőtt lájkolnál — eddig csendben maradt, pedig ilyenkor nem járt pont.
- A hír kedveléséért járó pontot a lájk visszavonása már nem veszi el, és a régebben tévesen elvett lájkpontok visszaálltak.

### 331 — létrehozás a natív adminból (kérdőív, nyereményjáték, kvíz)
- A HUHS adminban (natív) mostantól új kérdőív, nyereményjáték és kvíz is létrehozható — nem kell hozzá a WordPress admin.
- A kvíz-szerkesztőben kérdéseket vehetsz fel 2–6 válasszal, és bepipálhatod a helyes választ; mentés előtt minden hibát megnevez a képernyő.
- A nyereményjátéknál a helyes válasz sorszámát adod meg, a látszási napokat pedig számban — a lista pedig azonnal frissül.

### 330 — natív admin menüpontok (kvíz, kérdőív, nyereményjáték)
- A HUHS Vezérlőközpontban (natív admin) új menüpontok: „Kvíz és játékok", „Kérdőív" és „Nyereményjáték" — a kérdőív eredményei és a nyereményjáték résztvevői mostantól innen is elérhetők.
- A Vezérlőközpontban elérhető lett a „Hírlevél", a „Shortcode-ok" és a „Beállítások" menüpont is (eddig a háttérben már működtek, de nem lehetett megnyitni őket).

### 329 — chat-lapozás, azonnali állapot, natív nyereményjáték-admin
- A Chatben lefelé görgetve betölti a régebbi üzeneteket — akár hetekkel ezelőttit is visszaolvashatsz, és egy gombbal visszaugorhatsz a legfrissebbhez.
- A nyereményjáték és a kérdőív „már játszottam / már szavaztam" állapota azonnal megjelenik nyitáskor, nem kell a betöltésre várni.
- Adminoknak: új „Résztvevők" nézet a nyereményjátékhoz az appban — ki játszott, mit válaszolt, helyes volt-e, és ki nyert.

### 328 — „További hírek" kártya + GYIK
- A főoldalon a „További hírek" sor ugyanolyan kártyaformát kapott, mint a kérdőív és a nyereményjáték — így egységes a megjelenés.
- A GYIK (Segítség) témakörökre bontva, érthetőbben — és a pontok, valamint a napi limitek a valós értékeket mutatják.

### 327 — kiadási jegyzet a Névjegy alatt
- ÚJ: a Névjegy alatt mostantól látszik a kiadási jegyzet (changelog) verziószámmal.
- Az aktuális verzió ki van emelve, alatta a korábbi kiadások újdonságai.

### 326 — chat és cikk-hozzászólás szerkesztése
- A Chatben a saját üzenetedet szerkesztheted, az admin bárkiét is — és az admin törölhet.
- Ugyanez a cikkek alatti hozzászólásoknál: a sajátodat szerkesztheted, az admin bárkiét.
- A szerkesztett üzenet és hozzászólás mellett „szerkesztve" jelzés látszik.

### 325 — értesítések: „összes törlése" fülre szűkítve
- Az értesítéseknél az „összes törlése" már csak a látható fület üríti: az Aktív fül az aktívakat, az Archivált fül az archiváltakat.
- A törlés megerősítő szövege megmondja, melyik fület érinti.

### 324 — nyertes és kérdőív azonnali frissülése
- A nyereményjáték nyertese már azonnal megjelenik a kártyán, nem késik perceket.
- A kérdőív nyitása és zárása is azonnal követi a szervert.

### 323 — kérdőív-eredmények javítása
- A kérdőív eredményeinél már a kérdőív saját válaszai látszanak az éves szavazás adatai helyett.
- A nyereményjátéknál eltűnt a felesleges kép mező.

## 4. HUHS Mobile API WordPress-plugin — kiadásjegyzék (2.12.0)

**📌 A TULAJDONOS LÉPÉSE:** a **`build/huhs-mobile-api-2.12.0.zip`** feltöltése a WordPressre
(a 2.11.0-t cseréli). **Ez teszi lehetővé, hogy az app az eseményeket, DJ-ket, szervezőket és
kiadványokat is angolul kapja** — a meglévő 2.11.0 csak a cikkeket tudja. A meglévő tartalom
fordítása utána következik (a plugin addig a **magyar** szöveget adja ezeknél, hiba nélkül).

A plugin csomag: `build/huhs-mobile-api-2.12.0.zip` (47 fájl, 160,3 KB,
SHA-256 `FABC459B3BA81F96D3421633AF102284704A06FA132C1F21C6D1EA82F31B768A`).
A változás verziókövetve: `docs/plugin-2.12.0-english-fields.patch` (7 fájl, +483/−51 sor,
SHA-256 `54D09AB3B76076B4274866BE0777E7CB359EE94C150A0FE298EBFDE3C88B16A7`).

**⚠️ 2026-09-25: a 2.12.0-t MÉG EGYSZER fel kell tölteni** — az első feltöltés után élesben
mértük, hogy a REST-en küldött angol meta **csendben elveszett** az esemény/DJ/szervező/kiadvány
típusnál (a `POST` 200-at adott, a visszaolvasás viszont üres lett, miközben a `post` típusnál
ugyanaz a hívás működött). **A gyökér:** a WordPress a `meta` mezőt csak akkor fogadja el REST-en, ha
a post-típus támogatja a **`custom-fields`**-et — ez a négy típusnál nem volt bekapcsolva. A javítás
(`add_post_type_support($post_type, 'custom-fields')` a késői `init`-en) már benne van a fenti
csomagban, és a szerveroldali utakra (WP-cron, végpontok) ez a hiba nem hatott.

**📌 ÁLLAPOTMÉRÉS EGY PARANCCSAL:** `node tools/check-content-english-live.mjs` — megmondja, hogy a
plugin támogatja-e már az esemény/DJ/szervező angol mezőt (azaz fent van-e a 2.12.0), hány cikk van
angolul a nyilvános végponton, és hogy az angol **nem** szivárgott-e ki a weboldalra. **Frissen mérve
(2026-09-25):** `post` **támogatott**, `huhs_event`/`huhs_artist`/`huhs_organizer` **nem** (0 `_huhs_*`
meta) → a 2.12.0 **még nincs fent**; a cikkek `?lang=en` válasza **30/50** angol (`?lang=hu`: 0), az
esemény/DJ/szervező 0; a weboldal HTML-jében az angol cím és kivonat **nincs benne**.

**✅ A CSOMAG PHP-JA FUTÁSSAL ELLENŐRIZVE (2026-09-25):** `node tools/run-php-plugin-tests.mjs` — a
Docker (`php:8.2-cli`) konténerben a **kibontott ZIP-en** fut: **46 PHP fájl `php -l`** szintaxisa +
**19 viselkedés-ellenőrzés kétszer** (kulcs nélkül/örökölt kulccsal, majd a `HUHS_OPENAI_API_KEY`
konstans ággal) WordPress-stubokkal. **Eredmény: `MINDEN ELLENŐRZÉS RENDBEN — lintelt fájl: 46,
viselkedés-körök: 19/19, 19/19`**, és a négy mutáció (fallback-kapu gyengítése, mindkét kulcs-kapu
kivétele, örökölt-kulcs felismerés elvétele, meta-írás elhagyása) **mind elkapva**, bájtpontos
visszaállítással. Docker nélkül az eszköz **KIHAGYVA** (indoklással) — a zöld így nem csúszik el.

### 2.12.0 — angol mezők az eseménynek, DJ-nek, szervezőnek és kiadványnak + automatikus fordítás (2026-09-25)

```text
- UGYANAZ a három rejtett meta mező (`_huhs_title_en`, `_huhs_excerpt_en`, `_huhs_content_en`)
  mostantól a huhs_event, huhs_artist, huhs_organizer és huhs_release típusra is regisztrálva van
  (egy helyen: huhs_translation_post_types()).
- A `lang=en` kérés ezeknél a végpontoknál is angolul válaszol — UGYANAZZAL a fallback-kapuval,
  mint a cikkeknél: angolra csak akkor váltunk, ha a CÍM ÉS a törzs is megvan, különben a magyar
  megy ki `has_en = false`-szal (a payload sosem kevert nyelvű).
- A mezőnevek VÁLTOZATLANOK (a cikknél title/excerpt/content, a DJ-nál title/biography/excerpt,
  a szervezőnél és eseménynél title/description), ezért az appnak nem kell új feldolgozó.
- ⚠️ A KIADVÁNY szándékosan kimarad a fordításból: az egyetlen szöveges mezője a CÍM, ami NÉV
  (kiadvány/szám címe) — mérve 21 kiadvány, 0 fordítható prózai szöveg. A meta regisztrálva van
  (egy jövőbeli leíráshoz), de a végpont nem hívja a fordítást.
- WP-cron: publikáláskor a fordítás automatikusan elindulhat (save_post → wp_schedule_single_event).
  ⚠️ API-KULCS NÉLKÜL SZÁNDÉKOSAN NEM CSINÁL SEMMIT: a kulcsot a `huhs_translation_api_key`
  opció (vagy szűrő) adja; ha üres, a folyamat el sem indul, külső hívást nem indít.
  A szolgáltató a `huhs_translation_provider` szűrővel váltható (alap: DeepSeek csevegő-végpont).
  ✅ **ÖRÖKÖLT KULCS (2026-09-25-e óta):** ha az elsődleges kulcs üres, de a **korábbi OpenAI-próba**
  kulcsa megvan (`huhs_openai_api_key` opció vagy `HUHS_OPENAI_API_KEY` konstans), akkor **azt**
  használja, és a szolgáltató automatikusan az **OpenAI** csevegő-végpontja lesz — így a feltöltés
  után **nem kell új kulcsot szerezni**, ha a régi még a beállításokban van. Ha mindkettő megvan, az
  elsődleges (`huhs_translation_api_key`) nyer.
- A webnyilvános oldal VÁLTOZATLAN: az angol továbbra is csak rejtett meta, a téma/shortcode
  nem olvassa (forrás-lint őrzi).
```

### 2.11.0 — angol cikk-mezők (rejtett meta) + `lang` paraméter (2026-09-25)

```text
- ÚJ: a cikkek angol változatának helye a WordPressben — három REJTETT post meta mező:
  _huhs_title_en, _huhs_excerpt_en, _huhs_content_en. A webfelület ezeket NEM olvassa,
  ezért az angol egyelőre kizárólag az appban jelenik meg (a cikkek magyar permalinkje
  változatlan, nincs külön angol bejegyzés).
- ÚJ: a /posts és a /posts/{id} végpont `lang` paramétert kapott (hu az alap, en az angol).
  Ha egy cikkhez nincs (vagy hiányos) az angol szöveg, a válasz a MAGYAR szöveget adja —
  üres mező soha nem kerül a felületre. A válasz `has_en` jelzőt is tartalmaz.
- A meta regisztrációja `show_in_rest`-tel történik (a fordító folyamat alkalmazás-jelszóval
  írja), és a tartalom szűrője HTML-t megtartó (wp_kses_post), különben a cikk tagek nélkül
  maradna.
- A régi appokra nincs hatás: `lang` nélkül (és `lang=hu`-nál) a válasz mezői változatlanok.
```

### 2.10.0 — a hírlevél nem küldi ki korlátlanul a megerősítő levelet (2026-09-24)

```text
- JAVÍTVA: a hírlevél-feliratkozásnál ugyanarra az e-mail-címre nem megy ki újra és újra a
  megerősítő levél. Eddig a cím state=pending állapotában MINDEN beküldés új kérést indított
  a Mailchimpre, az pedig újra kiküldte a megerősítő e-mailt — a felületen korlátlanul.
- Mostantól e-mailenkénti várakozás van (alapból 15 perc): a várakozáson belül a Mailchimp
  hívást meg sem indítjuk, a válasz pedig megmondja, mennyi van hátra.
- A már megerősített (subscribed) cím továbbra is azonnal jelzést kap, levél nélkül.
- Az app ezért (356) háromféle választ tud megkülönböztetni, és a hozzá tartozó szöveget
  mutatja; a szavazás pedig nem veszhet el a hírlevél hibáján.
- Az érintett fájlok: includes/newsletter.php (cím-várakozás), huhs-mobile-api.php (verzió).
```

### 2.9.0 — a DJ privát (kapcsolattartó) e-mail címe látható és javítható (2026-09-24)

```text
- JAVÍTVA: a DJ-adatlap PRIVÁT (kapcsolattartó) e-mail címe (contact_email meta) mostantól
  látszik ÉS javítható a natív HUHS vezérlőben (DJ-k → szerkesztés) és a WordPress admin
  DJ-adatlapján is. Eddig sehol nem lehetett látni és átírni — pedig ez a cím igazolja az
  adatlap átvételét, ezért egy elírt cím miatt a DJ nem tudta átvenni a saját adatlapját.
- A natív admin űrlapja szerver-vezérelt, ezért ehhez NEM kellett új app-verzió: a mező a
  következő megnyitáskor megjelenik.
- A cím továbbra sem publikus: a nyilvános adatlap válaszába nem kerül bele, csak a védett
  claim-emails végponton jön ki.
- Az érintett fájlok: includes/api-admin.php (natív admin mező), includes/artists.php
  (WP admin meta-box), includes/artist-save.php (mentés sanitize_email-lel),
  huhs-mobile-api.php (verzió).
```

### 2.8.0 — a nyeremény leírása a NYITOTT játékban is kimegy (2026-09-24)

```text
- JAVÍTVA: a /prize/active végpont a NYITOTT játéknál is kiküldi a prize_type és a
  prize_description mezőt (a _huhs_prize_type / _huhs_prize_description meta).
- ELŐTTE szándékosan üres volt, és csak a sorsolás után jelent meg — a tulajdonos viszont
  jelezte, hogy a kitöltött „Nyeremény leírása" nem kerül bele a játékba, a mező súgója
  pedig azt ígéri, hogy a játékosok látják. Ezért a nyitott ág is kiküldi.
- A HELYES válasz továbbra sem megy ki a nyilvános válaszban (sem a játékos-hash/uid).
  Ezt a functions/prize-active-payload.test.cjs (6/6) őrzi.
- Az érintett fájlok: includes/prize.php (a javítás), huhs-mobile-api.php (verzió).
```

### 2.6.0 — a privát claim-e-mail végpont és a cím-pótlás (2026-09-21)

A csomag: `build/huhs-mobile-api-2.6.0.zip` (45 fájl, 147,0 KB, SHA-256
`289E8CC099DD6B43D131A736E54740A8F8232769C9D7DDE633272AAC4901BCFE`), a változás:
`docs/plugin-2.6.0-dj-claim.patch`.

**Mit hoz a 2.6.0 (az előző, 2.5.9 óta):**
```text
- ÚJ (privát, csak a HUHS szerverének): GET /huhs/v1/artists/<id>/claim-emails — megadja a DJ-adatlap
  nyilvános booking és a beküldött PRIVÁT (kapcsolattartó) e-mail címét. Azért kell, mert a
  privát cím a nyilvános adatlapról szándékosan kimarad, a claim viszont ezzel is működik.
- JAVÍTVA: a beküldés jóváhagyásakor a privát e-mail eddig ELVESZETT (nem került át az adatlapra),
  ezért a beküldött DJ a saját címével nem tudta volna claimelni az adatlapját. Most átkerül.
- ÚJ (privát, idempotens): POST /huhs/v1/artists/claim-emails/backfill — a KORÁBBAN jóváhagyott
  adatlapokra pótolja a privát címet a beküldésből (csak ha még nincs ott; kézzel javított címet
  nem ír felül).
- Az érintett fájlok: includes/api-artists.php (két új végpont), includes/submissions.php
  (a cím átvitele), huhs-mobile-api.php (verzió).
```

### A 2.6.0 ÉLŐBEN igazolva (2026-09-21, a tulajdonos „2.6.0 feltöltve" jelzése után)

- **A privát végpont él:** `node tools/check-artist-claims.mjs --ping 12812` → válaszol, és megadja az
  adatlap címkéit (a kimenet **maszkolt**: `booking=(nincs) privát=j***@gmail.com`). A címek
  kisbetűsítve jönnek, és a végpont hitelesítés nélkül nem ad ki semmit.
- **A cím-pótlás lefutott:** `--backfill --confirm` → **1 adatlap pótolva**, 0 kihagyva. Ez a
  **12812 „Sunshine State"** adatlap: a beküldés privát címe eddig **elveszett** a jóváhagyásnál,
  mostantól ott van — vagyis **a beküldött DJ a saját e-mail címével claimelheti** az adatlapját.
  (⚠️ A WordPress object cache miatt az érték az első lekérdezésben még **elavultan üres** volt;
  közvetlenül a pótlás után érdemes néhány másodpercet várni.)
- **Teljes felmérés (élő, `--scan-emails`): 16 publikált DJ-adatlapból 11-en van claimhez használható
  cím, 5-en NINCS.** A cím nélküliek: **11678 „Denoiser"**, 11726 „Adam Bass", 11731 „Impulz",
  11734 „Noizemaker", 12373 „Goze" — ezeket **a DJ sem tudja claimelni**, amíg nincs rajtuk
  booking vagy privát e-mail (a WordPress adminban a „Nyilvános booking e-mail" mező kitöltése elég).

### A 2.5.9 — a nagy körüzenet dupla küldésének javítása

A plugin csomag: `build/huhs-mobile-api-2.5.9.zip` (45 fájl, 145,1 KB,
SHA-256 `61DCBD46FC114F2CDF8D83DC37CC2421833177620CEA1F33BFB20C71E3B01590`).

**Mit hoz a 2.5.9 (az előző, 2.5.8 óta):**
```text
- JAVÍTVA: a nagy körüzenet (hír, esemény, release, emlékeztető) egy része KÉTSZER ment ki.
- Az ok: a küldési láncot a cron ÉS a biztonsági háló is futtathatta; a háló a kör VÉGE előtt
  „elakadtnak" látta a még futó kört, és ugyanarról az offsetről indított egy második kört.
- Mostantól a kör a kezdetén szívverést ír, és egy atomikus foglalás védi: egyszerre egy kör dolgozhat.
- Az újrapróbálkozás sem indul el, ha a lánc viszi ki a küldést (nem küldi el kétszer ugyanazoknak).
```

### 2.7.0 — a DJ-adatlap szerkesztése + a nyilvános gyorsítótár javítása (2026-09-22)

**A csomag:** `build/huhs-mobile-api-2.7.0.zip` (45 fájl, 149,3 KB, SHA-256
`25900509936BBEF8AA8A8E8FC0730B662D2F41B3BF5838CAA575ED9B26B0047C`) — **ezt fel kell tölteni**,
mert a 350-es app egyik funkciója ezt használja.

```text
- ÚJ végpont: POST /huhs/v1/dj-profile/<id> — az ÁTVETT DJ-adatlap szerkesztése (a HUHS szervere hívja,
  admin-alkalmazásjelszóval; permission: manage_options).
- Amit ír: post_title (max 120), post_content (bemutatkozás, max 6000, wpautop(esc_html())),
  real_name / city / country / website / facebook / instagram / tiktok / spotify / soundcloud / youtube,
  valamint logo_url / hero_image_url (képcsere) — és a hozzá tartozó attachment-azonosítót nullázza,
  különben a nyilvános válasz a régi képet adná vissza.
- Amit SZÁNDÉKOSAN nem ír: booking_email (ez igazolja az átvételt), contact_email (privát cím),
  visible, featured, booking_via_huhs, genre, taxonómiák, slug.
- A kép csak https Cloudinary-link lehet (res.cloudinary.com) — a beküldés is oda tölt.
- A válasz ugyanaz a payload, mint a nyilvános /artists/<id> végponté, ezért az app egyből frissíthet.
- ⚠️ JAVÍTÁS a 2.6.0-hoz képest: a nyilvános válasz-gyorsítótár engedélylistája ELŐTAGRA illeszkedett,
  ezért a privát /artists/<id>/claim-emails (a DJ privát e-mail címével) is cache-elhető volt — a
  `rest_pre_dispatch` és a plugin-betöltéskori korai kiszolgálás pedig a hitelesítés ELŐTT fut, így egy
  korábbi hitelesített hívás válasza 120 másodpercig azonosítatlan kérésre is kijöhetett volna.
  Mostantól minden privát útvonal (claim-emails, dj-profile) ki van zárva a gyorsítótárból.
```

**Feltöltés után érdemes ellenőrizni:** `node tools/check-artist-claims.mjs --ping <djId>` (a privát
végpont továbbra is él), és egy átvett adatlap mentése az appból (a 350-es buildben).

### ✅ A 2.7.0 FELKERÜLT ÉS ÉLŐBEN IGAZOLVA (2026-09-22, a tulajdonos „2.7.0 fent" jelzése után)

- **A verzió élőben: `apiVersion = 2.7.0`** (`node tools/verify-submission-payout.mjs --live` → **4/4 OK**).
- **ÚJ eszköz-mód: `node tools/check-artist-claims.mjs --probe <djId>` → 5/5 OK** (adat írása nélkül):
  1. `claim-emails` **hitelesítés nélkül → 401** (a privát cím **nem** szolgálható ki — a gyorsítótár-javítás él),
  2. az új `dj-profile` **hitelesítés nélkül → 401** (nem 404: a végpont fent van és védett),
  3. `claim-emails` **hitelesítéssel → 200** (a végpont működik),
  4. `dj-profile` **üres kéréssel → 400** („Nem érkezett menthető mező" — üres kérés nem ír adatot),
  5. a **nyilvános** `/artists/<djId>` → 200, `X-HUHS-Cache=fresh` (a kizárás **nem** vitte el a nyilvános gyorsítótárat).
- `node tools/verify-wp-admin-endpoints.mjs` → **15/15 OK** (a frissítés semmi mást nem tört el).
- **⚠️ Közben a saját eszközünk egy hibáját is javítottuk:** a `verify-submission-payout.mjs` a verziót
  csak az **utolsó** száma alapján hasonlította (`2.7.0` → `0 >= 8` = hamis), ezért a 2.5.8 utáni
  **minden** kiadást hibásnak jelzett — a 2.7.0-nál élesben elő is jött. Mostantól valódi
  verzió-összehasonlítás van (`versionAtLeast`), 10 új önteszt-esettel (a kapu **15/15**).

### A 2.5.9 ÉLŐBEN igazolva (2026-09-20, a tulajdonos „2.5.9 fent van" jelzése után)

- **A plugin verziója élőben: `apiVersion = 2.5.9`.** `node tools/verify-submission-payout.mjs --live`
  → **4/4 OK** (a végpont válaszol, üres kérésre 400, ismeretlen azonosítóra üres lista, hitelesítés
  nélkül 401/403), `node tools/verify-wp-admin-endpoints.mjs` → **15/15 OK** (a frissítés nem tört el
  mást: nyereményjáték, kérdőív, szavazás továbbra is válaszol, UID/hash nem szivárog).
- **A push-lánc élő állapota** (`node tools/check-wp-push-state.mjs`): **807 regisztrált eszköz**,
  az utolsó kör egy **`news` körüzenet** volt — **130 eszköz, 0 hiba, 0 halott token**, és a lánc
  **lezárult** (`függő feladat: none`, `aktív: none`), tehát nem maradt elakadt küldés.
- **A szerveroldali (Firebase) dupla javítása mérve:** `node tools/check-push-duplicates.mjs --hours 8`
  → a naplóban a privát üzenetek **már viszik a `messageId`-t** (a javítás él), és **minden
  üzenethez pontosan EGY küldés** tartozik → **nincs dupla küldés**.
- **A plugin oldali védelem bizonyítéka:** `node tools/verify-push-dedupe.php` → **12/12**, és a régi
  viselkedést szimulálva a kapu **bizonyítottan elkapja** a duplát (ugyanaz az eszköz kétszer kapja a
  push-t). A WP-oldali javítás a **következő nagy körüzenetnél** lesz közvetlenül is megfigyelhető
  (a diagnosztika megmutatja a kör előrehaladását; a dupla a korábbi verzióban az azonos offset
  újrafuttatásából jött).


### 2.5.8 — a WordPress-adminban elfogadott beküldések pontja

**Mit hoz a 2.5.8 (az előző, 2.5.7 óta):**
```text
- ÚJ végpont: GET /huhs/v1/submission-statuses?ids=1,2,3 — megmondja, hogy egy beküldést elfogadtak-e (created_profile_id), típus szerint.
- Egyszerre legfeljebb 100 azonosítót fogad (batch), és hitelesített WordPress-felhasználót kér (nem nyilvános).
- Ezt használja az új ütemezett Cloud Function (reconcileSubmissionPoints): ha egy beküldést a WordPress adminban fogadtak el, a pont utólag is megérkezik a beküldőnek.
```

### A 2.5.8 ÉLŐBEN igazolva (2026-09-19, a tulajdonos „api feltöltve" jelzése után)

- `node tools/verify-submission-payout.mjs --live` → **4/4 OK**: `apiVersion = 2.5.8`, üres `ids`-re **400**, ismeretlen azonosítóra **üres lista**, hitelesítés nélkül **401/403**. Vagyis a végpont **fent van, védett, és a helyes hibákat adja**.
- `node tools/verify-wp-admin-endpoints.mjs` → **15/15 OK**: a meglévő admin-végpontok (nyereményjáték, kérdőív, szavazás) a pluginfrissítés után is válaszolnak, és továbbra sem adnak ki UID-t/hash-t.
- **Őszinte korlát:** a `submission_authors` megfeleltetés élőben még **üres** (**0 rekord** — a bevezetés óta nem érkezett beküldés), ezért a WordPress-adminban elfogadott beküldés **utólagos kifizetése** valódi beküldéssel **még nincs bizonyítva**; az emulátoros teszt (18/18) és a kapu (`10/10` + önteszt `5/5`) fedi. Az első beküldés után a 30 perces kör magától fizet.

### 2.5.7 — létrehozás a natív adminból

A plugin csomag: `build/huhs-mobile-api-2.5.7.zip` (45 fájl, 142,9 KB,
SHA-256 `352223459F8DC5318321303B8BF835623AE8856465F15412E03D5002F744F2E9`).

```text
- ÚJ: a natív adminból létrehozható új KÉRDŐÍV, NYEREMÉNYJÁTÉK és KVÍZ (admin-create.php).
- A mezők kulcsa a valódi meta-kulcs, ezért a mentés nem tud elcsúszni a WordPress-űrlaptól.
- Validáció a szerveren is: kérdőív 2–6 válasz, nyereményjáték 3–5 válasz + helyes válasz, kvíz 1+ kérdés 2–6 válasszal és megjelölt helyes válasszal.
- A `_huhs_prize_correct` 1-alapú (emberi) sorszámát a szerver fordítja 0-alapú indexre.
- A haladó beállítások (jutalomsávok, idővonal, hang-borítók, „találd ki a zenét” típusok) szándékosan a WordPress adminban maradnak.
- A nyilvános végpontok változatlanok; UID/hash továbbra sem megy ki a kliensnek.
```

## 5. Ellenőrzés feltöltés előtt

1. `node tools/check-play-notes.mjs` — a Play-blokkok hossza és a build-lefedettség.
2. `flutter test test/data/app_changelog_test.dart` — az app changelogja egyezik a `pubspec.yaml`-lel.
3. Az AAB verziókódja a merge-elt manifestből: **351** (versionName `1.0.0`, a production AdMob App ID bent, a teszt App ID nincs).
4. `node tools/verify-native-admin-menu.mjs` — a natív admin menüpontjai és a plugin végpontjai egyeznek.
5. `node tools/verify-achievement-points.mjs` — az achievement-pontok konzisztenciája (ÉLES, csak olvas).
6. `node tools/verify-achievement-guide.mjs` — az Achievement-útmutató szövege egyezik a kóddal (napi keretek, pontértékek, létező források).
7. `node tools/check-play-track.mjs` — mi van tényleg a Play sávjain.
8. `node tools/verify-submission-payout.mjs --live` — a feltöltött plugin végpontja él és védett (4/4).
9. `node tools/verify-wp-admin-endpoints.mjs` — a plugin admin-végpontjai a frissítés után is működnek (15/15).
