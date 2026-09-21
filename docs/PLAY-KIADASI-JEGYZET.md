# Play Console — kiadási jegyzet (másolható)

Ez a fájl a **következő feltöltéshez** tartozó, **kész, másolható** changelog-szövegeket
tartalmazza. A szabály ugyanaz, mint a `docs/RELEASE_CHANGELOG_CHECKLIST.md`-ben:
ugyanaz a magyar changelog megy a Play Console-ra, az app Névjegyére
(`lib/data/app_changelog.dart`) és a plugin kiadásjegyzékére.

<!-- play-notes-meta
currentBuild: 346
currentVersion: 1.0.0
lastPublishedBuild: 345
aab: build/HUHS-v1.0.0+346-release.aab
sha256: 662CAB098AA88923180304F52064DCB3ED102E1547165C4C3F25782FA762B859
-->

## 0. ÉLŐ ÁLLAPOT a Play-en (mérve, `node tools/check-play-track.mjs`)

A Play Developer API-t **olvasásra** kérdezve (2026-09-20, a legfrissebb mérés):

| Sáv | Állapot | Build |
|---|---|---|
| **alpha (zárt teszt)** | **completed** (100%-ban kigördült) | **345** — „345 (1.0.0)", kiadási szöveggel (a tulajdonos 2026-09-21-én jelezte) |
| beta | üres | — |
| production | üres | — |
| internal | completed + egy **üres piszkozat** | 278 |

- **A 337 a zárt teszt sávján MÁR FENT VAN** (completed), a **bővebb (1c.) kiadási szöveggel** ment ki.
- **A production sáv viszont üres:** a termékkör megnyitása a Play zárt teszt követelményéhez kötött (személyes fejlesztői fióknál legalább **12 tesztelő / 14 nap** folyamatos zárt teszt), ezért az „élesítés" **nem** egy újabb AAB feltöltése, hanem a production access megnyitása + kiadás a meglévő bundle-ből.
- **A zárt teszt sávján egyszerre egy kiadás él**, ezért a 338 automatikusan felváltja a 337-et; az **internal sávon maradt üres piszkozatot** a Play Console-ban **el kell dobni** (Discard), különben ott marad.
- A feltöltött AAB-ek a Playen (a legfrissebb mérés szerint): 1, 155, 159, 171, 175, 178, 181, 190, 204, 277, 278, 297, 319, 332, 333, 334, 335, 336, **337**.
- A `play-notes-meta` `lastPublishedBuild` értéke (**337**) azt jelöli, hogy a **zárt teszt sávjára legutóbb kikerült** build a 337 volt — ezért az **1. pont** blokkja már csak a **338** újdonságát írja le. A **production** kiadáshoz a **hosszabb, 329–338 összesítő** blokk való (1b. pont), mert a nyilvános felhasználók legutóbb a **328**-at kapták.

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

## A feltöltendő AAB (mérve)

| | |
|---|---|
| Fájl | `build/HUHS-v1.0.0+346-release.aab` |
| Verzió | `1.0.0` (versionName) |
| Verziókód | **346** (a merge-elt release manifestből visszaolvasva) |
| Méret | 80.43 MB |
| SHA-256 | 662CAB098AA88923180304F52064DCB3ED102E1547165C4C3F25782FA762B859 |

**Miért a 346-ot kell feltenni:** a **345 már fel van töltve** a zárt teszt sávjára (a tulajdonos
jelezte), abban viszont a **lejátszó néma maradt**, és angol hibaüzenetet írt ki — ezt a
hibát a **346 javítja** (a `.pipe`/`addStream` csapda + 8 további hiba, lásd a 3. pontot).
**Ugyanaz a verziókód nem tölthető fel újra**, ezért a javítás új verziókódot kapott.
A 346-ban **minden** eddigi funkció is benne van: gyorsabb WordPress-betöltés, azonnali lájk és
ismerős-jelölés, tekerhető folyamatjelző + stop + lejátszási lista (ismétlés/keverés, sorrendezés,
ki/be a listáról), zárképernyős vezérlés és kikapcsolt képernyőn is szóló zene, valamint a
frissen vásárolt zene azonnali megjelenése. **A 345-öt ez váltja.**

> **FONTOS:** a **korábbi AAB-eket ne töltsd fel** — a 345 mindegyiket tartalmazza, és kisebb
> verziókódú csomagot a Play amúgy sem fogadna el.

**A plugin ehhez 2.5.9** (`build/huhs-mobile-api-2.5.9.zip`) — **ez már fent van** (élőben igazolva:
`apiVersion = 2.5.9`), ezért **nem kell újra feltölteni**. Ha viszont valaha újratelepíted a plugint,
ez a csomag a jó: ebben van a beküldések elfogadását lekérdező végpont (2.5.8) **és a dupla push
elleni védelem (2.5.9)**.

## 1. Play Console — RÖVID (ezt másold be)

A tulajdonos kérése: *„röviden kéne a Playbe"*. A Play a kiadási megjegyzést a frissítés
kártyáján **rövidítve** mutatja, ezért a **rövid** szöveg a jó. A részletes lista nem vész el —
az **az app Névjegyében** van (3. pont), és a felhasználó ott bármikor megnézheti.

A Play **nyelvenként 500 karaktert** enged ([súgó](https://support.google.com/googleplay/android-developer/answer/9859348?hl=en));
az alábbi blokk **mérve a limit töredéke** (a pontos számot a `tools/check-play-notes.mjs` írja ki).

```play-notes
- Javítva: a „Megvásárolt zenéim" lejátszója elindul (a 345-ben néma maradt).
- Javítva: minden hibaüzenet magyar, és hiba esetén a hang visszakerül a rádióhoz.
- Javítva: a lista és a lapozás mindig az összes letöltött zenét mutatja.
- Javítva: a zárképernyőn a tekerősáv hossza és az aktuális tétel jelölése helyes.
```

## 1b. Play Console — a NYILVÁNOS kiadáshoz (329–346 összesítő)

**Ezt akkor használd, amikor a production sávra kikerül az első nyilvános kiadás**, mert a
felhasználók legutóbb a **328**-at kapták — ők ezt a teljes listát kapják.

```play-notes
- Értesítés: chat-lájk, -válasz, komment-válasz.
- Az ikon mutatja az olvasatlanokat; a rangod szintlépésnél frissül.
- A rádió folyamatosan szól.
- A YouTube-videó az appban szól.
- Aktivitási pont, vásárlás +20.
- Eseményt csak szervező küldhet.
- ÚJ: „Megvásárolt zenéim", kvíz azonnali jelzése.
- ÚJ: gyorsabb betöltés, azonnali lájk/ismerős, lejátszó.
- ÚJ: zene kikapcsolt képernyőn is, zárképernyőről vezérelve.
- ÚJ: a listáról zene ki-/bevehető és sorrendezhető.
```

## 1c. Play Console — CSAK a 346-hoz, bővebben (tartalék)

Ugyanaz a kiadás, részletesebben — akkor használd, ha a Play kártyáján több sort akarsz
megjeleníteni. **Ez is csak a 346-ot írja le** (a 345 már fent van a zárt teszt sávján).

```play-notes
- Javítva: a „Megvásárolt zenéim" lejátszója elindul — a 345-ben a zene el sem indult, és angol hibaüzenet jelent meg.
- Javítva: minden hibaüzenet magyar; ha egy zene indítása nem sikerül, a hang visszakerül a rádióhoz.
- Javítva: a lejátszási lista és a lapozás mindig az összes letöltött zenét mutatja.
- Javítva: a zárképernyőn a tekerősáv hossza és az aktuális tétel jelölése is helyes.
- Javítva: a lejátszás indítása nem indul el kétszer véletlenül.
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

## 4. HUHS Mobile API WordPress-plugin — kiadásjegyzék (2.5.9)

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
3. Az AAB verziókódja a merge-elt manifestből: **338**.
4. `node tools/verify-native-admin-menu.mjs` — a natív admin menüpontjai és a plugin végpontjai egyeznek.
5. `node tools/verify-achievement-points.mjs` — az achievement-pontok konzisztenciája (ÉLES, csak olvas).
6. `node tools/verify-achievement-guide.mjs` — az Achievement-útmutató szövege egyezik a kóddal (napi keretek, pontértékek, létező források).
7. `node tools/check-play-track.mjs` — mi van tényleg a Play sávjain.
8. `node tools/verify-submission-payout.mjs --live` — a feltöltött plugin végpontja él és védett (4/4).
9. `node tools/verify-wp-admin-endpoints.mjs` — a plugin admin-végpontjai a frissítés után is működnek (15/15).
