# PROJECT_CONTEXT.md

# Hungarian Hardstyle App

## Kiemelt biztonsági javítás — felhasználóhoz kötött Label-jogosultságok

A vásárlási jogosultság és a reklámos feloldás nem lehet készülékhez vagy kliensoldali állapothoz kötve. A következő kliens buildben a `free_wav` is bejelentkezett felhasználóhoz kötött reklámos feloldást használ; a backend UID alapján ellenőriz, a vásárlási token UID-közi átadását tiltja, és fiókváltáskor törli a korábbi képernyőállapotot. A négy érintett Firebase-funkció élesítve, a Flutter statikus és tesztellenőrzés sikeres. Playből telepített új builden két külön Firebase-felhasználóval végponttól végpontig ellenőrizendő.

## Külön projekt: Hungarian Hardstyle Ticketing

- Önálló WordPress ticketing modul/szolgáltatás és külön REST API készül; a jelenlegi mobil API-ba nem kerül közvetlenül.
- Tervezett webcím: `jegy.hungarianhardstyle.hu`; később natív Flutter-app és scanner alkalmazás használja ugyanazt az API-t.
- Partnerenként backendből választható és konfigurálható Stripe vagy Barion, saját Billingo-kapcsolat, számlázási adatok és kezelési költség.
- Tervezett funkciók: esemény- és jegytípus-kezelés, névre szóló jegyek, vendéglista, PDF-jegy, egyedi vonalkód és szerveroldali beléptetés.

## +167 utólagos backend-javítás

- Az ingyenes `free_wav` letöltési útvonal Firebase callable-je vendég/névtelen kérést is elfogad; a fizetős és reklámos MP3-változatok hitelesítése változatlan.
- A `getLabelDownloadUrl` funkció élesítve, a WordPress WAV-token végpont a 12242-es kiadvánnyal ellenőrizve.
- Következő build feladata: ingyenes kiadványhoz opcionális külső feloldási link (például Hypeddit), amely reklám után válik elérhetővé, de nem generál és nem kínál WAV-ot. A meglévő WAV- és normál 128 kbps MP3-útvonalhoz nem szabad hozzányúlni.

## Aktuális build: +167 — production AAB elkészült; zárt tesztbe feltöltésre vár

## +167 — production AAB elkészült, optimalizálás alkalmazva

- A +167-ben a Flutter asset-bundből kikerült a nem használt `assets/icons/` könyvtár; a forrásfájlok megmaradtak, működő funkció nem változott.
- Az R8 teljes módja, a kód-/erőforrás-csökkentés és az osztály-újracsomagolás már korábban aktív volt; túl széles keep-szabályt nem módosítottunk a WorkManager/Room indulás védelme miatt.
- `flutter analyze --no-pub`, `flutter test` és `git diff --check` sikeres; a production AAB: `build/HUHS-v1.0.0+167-release.aab`.
- A Play zárt tesztbe feltöltés ebben a munkamenetben még nincs végrehajtva. A „Közepes” Play Console-mutató az AAB feldolgozása után ellenőrizendő.

## +166 — production AAB elkészült, emulátoron ellenőrizve

- A production AAB elkészült: `build/HUHS-v1.0.0+166-release.aab`; versionCode 166. A korábbi production AdMob App/Banner/Rewarded azonosítók az AAB-ban ellenőrizve.
- Android 15 emulátoron a production release APK elindult, a főképernyő megjelent, a folyamat futva maradt; R8/WorkManager/Room indulási hiba nem jelentkezett.
- A hír-like mentés emulátoron ellenőrizve: a kedvelésszám változott, és nem jelent meg reakciómentési vagy Firestore jogosultsági hiba.
- A Play zárt tesztbe feltöltés ebben a munkamenetben még nincs végrehajtva; a Play Console optimalizálási mutatója csak a feldolgozás után ellenőrizhető.

## +165 — rögzített javítás, AAB elkészült

- A production AAB elkészült: `build/HUHS-v1.0.0+165-release.aab`; versionCode 165. A production AdMob App/Banner/Rewarded azonosítók a korábbi release-konfigurációból visszaállítva és az AAB-ban ellenőrizve.
- `flutter analyze --no-pub`, Gradle release build és `git diff --check` sikeres. A Play zárt tesztbe feltöltés még nincs végrehajtva, mert az interaktív Play Console-vezérlés ebben a munkamenetben nem csatlakozott.

## +166 végrehajtási ellenőrzés

- Play Console „Alkalmazásoptimalizálás: Közepes”: az R8 osztály-újracsomagolása és a szükséges keep-szabályok a +166-ban beépítve; az optimalizálási mutató az új AAB feldolgozása után ellenőrizendő.
- +165 indulási crash: a WorkManager/Room `WorkDatabase` keep-szabálya a +166-ban megmaradt; production release APK-ból emulátoron az indulás ellenőrizve.
- Helyi állapot: az R8 osztály-újracsomagolása bekapcsolva (`-repackageclasses ''`, `-allowaccessmodification`), a WorkManager/Room keep-szabályok megmaradtak. A +166 release APK emulátoros indulása ellenőrizve; a Play optimalizálási mutató csak az új AAB feldolgozása után zárható le.
- Hír-like mentés: a reakciódokumentum merge-elt írást használ, a Firestore szabály pedig create és update esetén külön kezeli a meglévő extra mezőket; a szabály élesítve és a +166 production APK-val emulátoron ellenőrizve.

## +167 — ellenőrzés és szükség szerinti javítás

- Play Console „Alkalmazásoptimalizálás: Közepes” mutató kivizsgálása az új AAB feldolgozása után.
- Ellenőrizni, hogy az R8 teljes mód, kód- és erőforráscsökkentés, obfuszkáció, valamint az osztályok újracsomagolása ténylegesen érvényesül-e.
- R8-riportok alapján megkeresni a túl széles `keep` szabályokat és a felesleges Android/Flutter függőségeket vagy erőforrásokat; csak biztonságos, regressziómentes javítás alkalmazható.
- A Flutter AOT/native kód arányát figyelembe venni: a Play-mutató javulása nem garantálható pusztán újabb Gradle-kapcsolóval.
- Ha indokolt és biztonságos, Startup Profile és további méret-/teljesítmény-optimalizálás beépítése.
- Új AAB készítése után Play Console-ban ismét ellenőrizni a mutatót; a meglévő működő funkciók és az indulás nem romolhatnak.
- Regressziós alapelv: működő funkciót nem szabad elrontani vagy önkényesen módosítani; minden +167-es optimalizálás után a meglévő működéseket vissza kell ellenőrizni.
- Ingyenes kiadvány WAV-letöltés: a WordPress API `2.4.54` csomagban a `free_wav` variáns külön kezelést kapott, az `is_free` ellenőrzés kompatibilisebb lett, és a régi/új WAV-metaútvonalak fallbackje is bekerült. Feltöltés után Playből telepítve ellenőrizendő.
- Ingyenes kiadvány adatlapján a Billing-terméklista üres lekérdezése letiltva; a fizetős kiadványok termékbetöltése változatlan. Új APK/AAB után ellenőrizendő, hogy a hamis terméklista-hiba eltűnt.

## További, később rögzítendő feladatok

- Ingyenes kiadvány letöltése: a letöltött hangfájl WAV legyen, ne 128 kbps MP3; a kliens- és backend-letöltési útvonalat ennek megfelelően kell javítani és Playből ellenőrizni. Ez csak az ingyenes kiadványra vonatkozik; a normál release marad 128 kbps MP3 reklámért.
- Helyi állapot: az ingyenes kiadvány kliens- és letöltési útvonala külön `free_wav` változatra állítva; a WordPress-végpont csak `is_free` kiadványnál engedi ezt. A normál `mp3_128` jutalmazott útvonal változatlan. Playből telepített ellenőrzés és backend-élesítés még hátra van.
- Play Console „Alkalmazásoptimalizálás: Közepes”: a +164 AAB-nál a Play Console két hiányzó optimalizálást jelzett (optimalizált erőforráscsökkentés és osztályok újracsomagolása). A buildlánc AGP 9.0.1-re és Gradle 9.1.0-ra, az AGP 9-kompatibilis `google_mobile_ads` csomag 9.1.0-ra frissítve; az elavult adaptív banner API is lecserélve. A Gradle-konfiguráció és a statikus ellenőrzés sikeres; új AAB feldolgozása után kell visszaellenőrizni, hogy a mutató javult-e.
- Chat: az adminfunkciók a hárompontos üzenetmenübe kerüljenek, a blokkolás és jelentés mellé.
- Helyi állapot: a Chat adminműveletei (szerkesztés, törlés, rögzítés) a hárompontos üzenetmenübe kerültek; a blokkolás és jelentés ugyanebben a menüben maradt. Futásidejű/emulátoros ellenőrzés még hátra van.
- Profil: a kedvenc hírek megjelenítése kerüljön ki a felhasználói adatlapról; a kedvenc DJ-k és szervezők maradjanak láthatók.
- Hírek: a kedvencnek jelölés kerüljön le a hírekről; helyette opcionális like/reakció jelenjen meg látható kedvelésszámmal. A DJ-k és szervezők kedvencként jelölhetők maradjanak.
- Cikkek: a kártyán és a cikk részletező oldalán jelenjen meg az alkategória; a fő „Cikkek” kategóriát ne írja ki kategóriaként.
- Helyi állapot: a hírkedvencek betöltéskor kiszűrésre kerülnek, a hírkártyák és a részletező like-számot jelenít meg Firebase-ből, az alkategória pedig a kártyán és a részletezőn látszik a „Cikkek” főnév nélkül. Futásidejű ellenőrzés és szabályélesítés még hátra van.
- Ingyenes kiadványok: a kiadványkártyán és az adatlaphoz kapcsolódó nézetben is jelenjen meg a borító kép; a kliensoldali javítás elkészült, futásidejű/Playből telepített ellenőrzés még hátra van.
- Release-kártyák: a kliensben visszaállítva az egységes, fix magasságú fekvő listaelrendezés; a cím legfeljebb két soros, túlcsordulás esetén rövidített. Futásidejű ellenőrzés még hátra van.
- Események: a kedvencnek jelölés a listakártyáról eltávolítva; az „Ott leszek” és a „Nem leszek ott” részvételi lehetőség változatlan maradt. A felhasználói profilt nem módosítottam; futásidejű ellenőrzés még hátra van.
- Hírlevél: a Közösség menüben marad, a felhasználói profil read-only és szerkesztési nézeteiből kliensoldalon eltávolítva; futásidejű ellenőrzés még hátra van.
- AdMob banner: a Playből telepített verzióban stabilan és az első megjelenítéskor, lehetőleg azonnal töltsön be; a consent- és `canRequestAds()`-állapot legyen helyesen kezelve, ne legyenek duplikált kérések, a sikertelen betöltés kapjon rövid, kontrollált újrapróbálást és diagnosztikát, a production Play-release konfiguráció pedig legyen ellenőrizve. A +164-ben továbbra is időszakosan vagy késve jelenik meg.
- Google Play Billing: a vásárlás után a nem fogyó termék acknowledgementje ténylegesen sikerüljön; a `completePurchase()` eredményét/hibáját kezelni és ellenőrizni kell, a vásárlást nem szabad consume-olni. Playből telepítve végponttól végpontig ellenőrizni kell, valamint a korábbi vásárlás visszaállítását is. A megoldásnak a már feltöltött kiadásokkal és minden jövőbeli feltöltéssel is működnie kell.
- A Billing kódjavítása elkészült: a nem fogyó vásárlás szerveres ellenőrzés után, hibakezeléssel kerül `completePurchase()`-ba; consume nincs, a `restored` vásárlások visszaállítása is feldolgozott. Playből telepített kiadáson az acknowledgement és a korábbi vásárlás még ellenőrizendő.

## +164 végrehajtási állapot

- A fő Label-lista már kiszűri az `is_free` kiadványokat; az ingyenesek kizárólag az „Ingyenes kiadványok” nézetben jelennek meg. Playből telepített +164-ben ellenőrizendő.
- Az ingyenes kiadványok kártyája most már a WordPress API-ból érkező borítóképet jeleníti meg, az adatlap borítóképes nézete megmaradt; `flutter analyze` sikeres, teljes futásidejű ellenőrzés még nincs.
- A kiadványkártyák hosszú című megjelenítési hibája a +164-ben ismert; javítása a +165 feladata.
- Az ingyenes kiadvány feloldása és letöltése Playből telepítve működik; ez a +164-ben tulajdonos által visszaigazolt.
- A Közösség főmenübe bekerült a Kedvencek és a Hírlevél, és nem maradtak külön menüpontként a „Több” alatt.
- A Hírlevél a Közösség menüben megmaradt, és kikerült a saját felhasználói profil read-only és szerkesztési nézetéből; futásidejű ellenőrzés még nincs.
- Az AdMob banner betöltési útvonala kódoldalon javítva: a consent és az SDK inicializálása folyamat-szinten egyszer fut, az elavult/párhuzamos kérések kiesnek, a sikertelen betöltés 5 másodperc után kontrolláltan újrapróbálkozik; a tényleges Play-beli betöltés még külső ellenőrzés.
- A telefonos és kompatibilitási tesztek nem blokkolják a +164 célját.
- Release AAB elkészült: `build/HUHS-v1.0.0+164-release.aab`; a Play zárt tesztbe 100%-os kiadásként feltöltve és felülvizsgálatra beküldve. A gyorsellenőrzés/felülvizsgálat még folyamatban.

## +163 helyi állapot — 2026-08-18

- A +163 alkalmazásoldali javításai helyben beépítve és Android 15 Pixel emulátoron ellenőrizve: rendszer-visszagomb, kezdőlapi kilépési kérdés, tényleges task-eltávolítás, fekvő Chat és kijelentkezett Chat-avatar.
- A hosszú release-címek kártyaméretezése egységesítve, az ingyenes kiadvány `is_free` modelltesztjei bekerültek.
- `flutter analyze` sikeres, `flutter test` 29/29 sikeres, `git diff --check` rendben.
- A production +163 AAB elkészült: `build/HUHS-v1.0.0+163-release.aab` (73.8 MB), a +161-ből visszaállított production AdMob-azonosítókkal és release-aláírással. A Play Console zárt tesztcsatornájába feltöltve és felülvizsgálatra beküldve; jelenleg „Felülvizsgálat alatt álló módosítások”.
- Az ingyenes kiadványok UI-ja és explicit API-mezője elkészült; a WordPress `huhs-mobile-api-2.4.53` csomagban az „Ingyenes kiadvány” jelölő és a külön médiafeltöltő mező bekerült, az API élesben telepítve és a `/wp-json/huhs/v1/releases` végponton `is_free` mezővel ellenőrizve.
- A telefonos és kompatibilitási tesztek utólagos tulajdonosi validációk; ezek nem blokkolják a +163 cél elérését vagy a release-folyamatot.

## +163 végrehajtási állapot

- A release-kártyák hosszú című megjelenítési javítása helyben elkészült: álló és fekvő nézetben is ugyanaz a fix magasságú fekvő listaelrendezés fut, a cím legfeljebb két soros. Playből telepítve még ellenőrizni kell.
- A Label képernyő jobb felső sarkában látható „Ingyenes kiadványok” gomb nyissa meg az explicit API-val jelölt ingyenes zenék szekcióját; a zenék reklám megtekintése után legyenek letölthetők. A kliens és a `huhs-mobile-api-2.4.53` csomag kész; az éles Play-ből telepített kliens letöltési tesztje még nyitott.
- Közösség menü: a Kedvencek és a Hírlevél ténylegesen jelenjen meg a Közösségben; a „Több” menüből maradjanak eltávolítva.
- Android rendszer-visszagomb regresszió javítva: egyetlen központi `PopScope` kezeli a rendszer-visszát; nem kezdőlap tabgyökerén a Kezdőlap nyílik meg, a Kezdőlap gyökerén megerősítés jelenik meg, és az „Igen” után a natív Activity taskja eltávolításra kerül.
- Zenevásárlás/Play Billing: a WordPressből kapott termékazonosítók és a Play Billing `ProductDetails` lekérése közti szürke gombos hibát javítani kell; legyen kontrollált újrapróbálás, pontos ID-alapú állapotkezelés és érthető hibaüzenet. A Play Console-termékek aktívak, ezért ezt a kliensoldali Billing-útvonalon és Playből telepített verzióban kell ellenőrizni.
- Play Console „Alkalmazásoptimalizálás: Közepes” mutató újraellenőrzése a feldolgozás után.
- A +163 feltöltött alkalmazásoldali feladatköre elkészült; az ingyenes kiadványok főlistából való kizárása a feltöltés után külön +164 javításként került be.
- Release előtt marad: a +163 AAB Play zárt tesztcsatornába feltöltése. Utólag ellenőrizendő a Play Console „Közepes” mutatója és az ingyenes kiadvány tényleges Play-letöltése.

## +162 végrehajtási állapot — 2026-08-18

- Az alkalmazásoldali +162 pontok elkészültek: Android vissza/bezárás, tablet fekvő rádió-inset, telefonos fekvő Chat, kijelentkezett Chat ikon, korábbi események, Közösség átszervezése, stabil AdMob banner, Label dátum-megjelenítés, Chat kamera/galéria/válasz és szervezői kedvenc ikon.
- A WordPress release-date mező/API módosítása a `huhs-mobile-api-2.4.52` csomagban telepítve és élesben ellenőrizve: a `GET /wp-json/huhs/v1/releases` válasz `release_date` mezőt ad vissza.
- Elkészült és Play zárt tesztbe feltöltve/felülvizsgálatra beküldve: `build/HUHS-v1.0.0+162-release.aab`, versionCode 162; a Play Console állapota „Ellenőrzés alatt”.
- Ellenőrzések: `flutter analyze` sikeres (3 korábbi info), `flutter test` 27/27 sikeres, `git diff --check` whitespace-hiba nélkül.
- Még külső ellenőrzés: a tesztelői készülékeken végzett széles Android/tablet/gyártói kompatibilitás. A Play Console „Közepes” optimalizálási mutató újraellenőrzése átkerült a +163 feladatai közé.
- Pixel Tablet API 35 emulátoros fekvő ellenőrzés sikeres: az alsó rádió nem kerül a rendszer navigációs sávja alá; valódi gyártói eszközök további ellenőrzése még szükséges.

- A főoldali Androidos kilépési megerősítés tényleges bezárása: a megerősítő párbeszéd jelenjen meg, és az „Igen” választ követően az alkalmazás valóban záródjon be, ne csak háttérbe kerüljön.
- Tablet fekvő nézet: az Android rendszer-/eszköz-navigáció ne takarja el az alsó rádiólejátszót. A telefonos fekvő nézet tulajdonosi teszt szerint rendben van.
- Telefonos és tabletes fekvő Chat/Hírek/radio nézet: tulajdonosi teszt szerint rendben van.
- Kijelentkezett Chat: a jobb felső profilikon a főoldali piros körös fej/profil ikonnal egyezzen meg; a jelenlegi fehér fejikon cserélendő.
- Események: legyen lenyitható „Korábbi események” szekció a már lejárt események listájával.
- Korábbi események: a lenyíló listában dátum szerint, a legutóbbitól visszafelé jelenjenek meg; a kiemelés ebben a listában ne befolyásolja a sorrendet.
- A közelgő „Kiemelt események” és „Események” szekciók ne tartalmazzanak egymást átfedő elemeket.
- Közösség menü: a Kedvencek és a Hírlevél opció kerüljön át a „Több” tabról a Közösség menübe; a „Több” tab külön Közösség része szűnjön meg.
- AdMob banner: vizsgálni és javítani kell, hogy a banner ne véletlenszerűen jelenjen meg, hanem stabilan töltsön be.
- Label kiadványok: legyen megjelenési dátum mező, és a dátum jelenjen meg az app kiadványadatlapján.
- Chat: a kamera ikon ténylegesen nyissa meg a kamerát, és legyen külön fotó-/galéria-megosztási ikon.
- Chat: üzenetekhez legyen „Válasz” művelet, amely idézetként megjeleníti a megválaszolt üzenetet.
- Szervezők: a listaelemekben közvetlenül is jelenjen meg a kedvencnek jelölés szíve, ne csak az adatlap megnyitása után.
- Széles Android-kompatibilitás: a tesztelők telefonmodelljei és rendszerverziói alapján kell ellenőrizni.
  Eddig tesztelve: Samsung S23 Ultra (One UI 8.0), Samsung S25 Ultra (One UI 8.5), Samsung Tab A9+ (One UI 8.0), Samsung A53 (One UI 8.0), Samsung S24 (One UI 8.5), Poco X6 (HyperOS 3.0.8.0), Samsung A52s 5G (One UI 6.1, Android 14), Xiaomi Redmi Note 11 (MIUI Global 13.0.5), Xiaomi Redmi Note 14 5G (Android 15). A kompatibilitási ellenőrzés részben teljesült; további eltérő gyártó/verzió tesztje még nyitott.

## v1.0.0+161 hotfix — technikai versionCode 161

A +161 a +160 Play-regresszióját javítja: az adaptív AdMob banner szélességi kérése ismét legalább 320 px-es használható szélességgel indul, így a 0/1 px-es átmeneti layoutból nem készül érvénytelen bannerkérés. A rewarded reklám- és consent-logika változatlan. A release AAB elkészült: `build/HUHS-v1.0.0+161-release.aab`. `flutter analyze`, mind a 27 Flutter-teszt és `git diff --check` sikeres. A tulajdonosi teszt szerint az AdMob, az Android visszagomb, a preview végi vezérlő-visszaállítása és a preview utáni rádió-újraindítás működik; a főoldali kilépési megerősítés tényleges bezárása +162-re marad.

## v1.0.0+160 release — technikai versionCode 160

A +160 a +159 javított forrásállapotát viszi tovább új Play-kompatibilis versionCode-dal. A helyi AAB elkészült: `build/HUHS-v1.0.0+160-release.aab`; `flutter analyze` hibamentes, a 27 Flutter-teszt átment, a `git diff --check` rendben. A +159 Play-piszkozat törölve lett, majd a +160-as AAB zárt tesztbe feltöltve és felülvizsgálatra beküldve. A Play Console jelenleg a gyors ellenőrzéseket/felülvizsgálatot futtatja.

Tulajdonosi visszajelzés: a +158-ban az AdMob banner működött, a +160-ban a Playből telepített változatban nem jelenik meg, miközben a jutalmazott reklám működik. Ez +160 regresszióként nyitott; a banner consent/`canRequestAds()` útvonalát és a release konfigurációját össze kell vetni a +158-cal, majd új buildben javítani és Playből ellenőrizni.

A +161 ezt a banner-szélességi regressziót javítja. Az AAB a zárt tesztcsatornába feltöltve és felülvizsgálatra beküldve; a tulajdonosi teszt szerint az AdMob banner működik.

## Archív v1.0.0+159 release — technikai versionCode 159

A +159 release a jelenlegi javításokat tartalmazza. Fekvő tablet/telefon nézetben a rendszer alsó navigációja már nem takarja el a rádiót: a tartalom `SafeArea`-ban fut, a fekvő NavigationRail görgethető. A release AAB elkészült: `build/HUHS-v1.0.0+159-release.aab`, belső versionCode: 159.

Play Console állapot: a zárt teszt feltöltésénél a Google jelezte, hogy a 159-es verziókódot már felhasználták, ezért a +159 feltöltése nem fejezhető be új kiadásként. A helyi AAB érvényes; a következő szabad versionCode várhatóan 160.

Ellenőrzés: `flutter analyze` hibamentes, 27/27 Flutter-teszt sikeres, `git diff --check` rendben; Graphify-index frissítve.

## v1.0.0+154 hotfix — technikai versionCode 154

A hotfix a lejárt eseményeket eltávolítja a profil „Események, ahol ott leszek” listájából és a kedvencekből is, valamint megbízhatóvá teszi a Label-preview szüneteltetését/leállítását: a lejátszás indítása nem tartja zárolva a vezérlőket a preview végéig. A +153 navigációs és chatkép-javításai változatlanul benne maradnak. A production AAB: `build/HUHS-v1.0.0+154-release.aab`; a kiadás éles a Google Play zárt tesztcsatornáján.

## Archív v1.0.0+158 hotfix végrehajtási és ellenőrzési állapot

A +158 hotfix a +157 visszajelzett hibáját javítja: az Android rendszer-visszagomb kezelését egyetlen központi `PopScope` kezeli, így a tabgyökér nem ürül ki, a belső oldal visszalép, a nem kezdőlap tabgyökeréről a Kezdőlap nyílik meg, a Kezdőlap gyökerén pedig kilépési megerősítés jelenik meg. A release AAB elkészült: `build/HUHS-v1.0.0+158-release.aab`; a Play Console zárt tesztkiadásába feltöltve és felülvizsgálatra beküldve, az automatikus ellenőrzés folyamatban.

- Android visszagomb: kódoldalon javítva; a tabgyökér, belső aloldal és főoldali kilépési kérdés tulajdonosi/emulátoros ellenőrzése szükséges.
- Törölt vagy már nem elérhető hírek, DJ-k és szervezők tűnjenek el az user adatlapján a kedvencek közül is.
- AdMob banner: kódoldalon javítva a folyamat-szintű consent/SDK-inicializálással és a párhuzamos vagy elavult bannerkérések kiszűrésével; Playből telepített változaton még ellenőrizni kell.
- Preview végi vezérlő-visszaállítás, preview utáni rádió-újraindítás és telefonos fekvő Hírek-nézet: kódoldalon javítva; új AAB-bal ellenőrizni kell.
- Telefonos fekvő Chat/Hírek/radio UX és széles Android/tablet/gyártói kompatibilitás: külső eszközteszt szükséges.
- Ponytail-alapú célzott kódtakarítás: ebben a körben elvégezve.
- A Play Console „Alkalmazásoptimalizálás: Közepes” mutatójának kivizsgálása és javítása: memóriahasználat, teljesítmény, obfuszkáció és méretcsökkentés ellenőrzése, majd új Play-feldolgozási eredmény alapján visszaellenőrzése.

## Archív +16 állapot — technikai versionCode 152 (nem aktuális build)

A +16 kliensjavításai elkészültek, a release AAB helyben elkészült: `build/app/outputs/bundle/release/app-release.aab`. R8/minify, resource shrink, Dart-obfuszkáció és split-debug-info használatban van. 4467 projektfájl UTF-8-validációja hibátlan. A Play Console „Közepes” optimalizálási mutatója csak az AAB feldolgozása után értékelhető újra.

Kódoldalon kész: eseményszekciók, profil eseménycímkéje, Közösség-belépés, update-check, preview stop/restart és rádiószinkron, törölt ismerősök takarítása, adaptív banner-újramérés, valamint fekvő Chat/radio layout. Külső tesztre marad a Playből telepített banner és a telefonos fekvő Hírek/Chat/radio UX; tableten a fekvő Hírek olvasható. A további Android-/gyártó-/tablet-kompatibilitás még ellenőrizendő; az Android visszagomb tulajdonosi hibája a +155-be került.

## Archív +16 feladatlista és ellenőrzési állapot (nem aktuális build, csak történeti nyilvántartás)

- Play Console alkalmazásoptimalizálás javítása: memóriahasználat, általános teljesítmény, obfuszkációs és méretcsökkentési mutatók felülvizsgálata. A Play Console ezt jelenleg „Közepes” szintű optimalizálásként jelzi; a jelenlegi ellenőrzési státuszt a +156 blokk tartalmazza.
- Az események két külön szekcióban jelenjenek meg: „Kiemelt események” és „Események”.
- A profil-adatlapon a „Tervezett események” cím helyett „Események, ahol ott leszek” jelenjen meg.
- A lejárt események eltűnése a profil „Események, ahol ott leszek” listájából és a kedvencekből is — +154-ben elkészült és tulajdonos által működőként visszaigazolva.
- Minden jövőbeli frissítésnél és buildnél ellenőrizni kell a karakterkódolást, különösen a magyar ékezeteket, hogy ne jelenjenek meg krikszkrakszok.
- A történeti +16 körben a külön „Közösség” menü legyen teljes: az ismerőslista mellett tartalmazza az ismerős kérelmeket és státuszokat, a felhasználókeresést, a publikus profilokat, az ismerősök kezelését/törlését, a blokkolt felhasználókat és a jogosultság szerinti közösségi adminisztrációt; ezek kerüljenek ki a „Több” menüből.
- Az alkalmazáson belüli új verziójelző késését vagy esetleges eltűnését auditálni kell: ellenőrizni kell, hogy új frissítés esetén az app megnyitásakor megjelenik-e, és a frissítés indítása működőképes marad-e. Lehet, hogy csak a Play késleltetett frissítésjelzése okozta.
- Android visszagomb: a korábbi +16 javítás után is tulajdonosi hibajelzés érkezett; a végleges viselkedés a +155 feladata a fenti szabályok szerint.
- Label preview: indítás, szünet, folytatás, stop, újraindítás és tekerés működik; a preview végén a vezérlők automatikus alapállapotba visszaállítása még hibás, ezért ez a +155 javítandó pontja.
- Preview után a rádió visszakapcsolhatósága — tulajdonosi teszt alapján továbbra sem működik, +155-ben javítandó.
- Törölt felhasználó maradhat az ismerőslistában és „HUHS user” néven nyílhat meg; a törölt profilt az ismerőslistából és a kapcsolódó ismerős-adatokból ki kell takarítani vagy frissíteni.
- Playből telepítve az AdMob banner/csík nem tölt be, miközben a jutalmazott reklám működik; javítás/éles Play-ellenőrzés még szükséges.
- Fekvő telefonon a Chat és a Hírek használhatatlan, a rádiólejátszó túl nagy; tableten a fekvő Hírek olvasható. A telefonos fekvő UX javítandó.
- Széles Android-kompatibilitás külön +16-os tesztelendő pont: tablet és minden elérhető eltérő Android-verzió/gyártói rendszerfelület ellenőrzése; teljes laborlefedettség jelenleg nem áll rendelkezésre.

> AI Project Context
> Read this document before making any code changes.

---

# Project Goal

The Hungarian Hardstyle App is the official mobile application of the Hungarian Hardstyle community.

This is **NOT** just a news application.

The application should become the central platform of the Hungarian harder styles scene.

Everything should originate from WordPress and be available on:

- Android
- iOS
- Website

The WordPress installation is the single source of truth.

---

# Main Brand

## Hungarian Hardstyle

Main platform.

Contains:

- News
- Events
- Artists
- Organizers
- Releases
- Store
- Newsletter

---

# Related Brands

## Hardstyle Revolution

Functions:

- Record Label
- Event Series

Has its own:

- Facebook
- Instagram

Future:

- Releases
- Store
- Radio

---

## Rave Revolution

New event series.

Supports every harder electronic music style.

Examples:

- Hardstyle
- Rawstyle
- Hardcore
- Uptempo
- Hard Techno
- Reverse Bass

---

## Hard Lake

Free summer flashmob-style events.

Usually located at Lake Velence.

---

# Architecture

WordPress

↓

REST API

↓

Flutter

↓

Android

↓

iOS

Website uses the same WordPress backend.

Never duplicate data.

---

# Technology

Backend

- WordPress Plugin
- Custom Post Types
- REST API

Frontend

- Flutter
- Riverpod
- Dio
- Go Router

---

# Data Source

Everything must come from WordPress.

Never hardcode data unless temporary.

---

# Current WordPress Modules

## News

WordPress Posts.

Future:

Support all embedded content:

- YouTube
- Spotify
- TikTok
- Instagram

Links must open correctly.

---

## Artists

Contains:

- Name
- Image
- Biography
- Genres
- Country
- City
- Facebook
- Instagram
- TikTok
- Spotify
- SoundCloud
- YouTube

Future:

Upcoming Events list.

Clickable.

---

## Organizers

Contains:

- Logo
- Description
- Website
- Facebook
- Instagram
- TikTok

- Music genres/styles (multi-select)

Future:

Upcoming Events list.

Clickable.

Organizer genres are editable in WordPress, returned by the organizer REST API, and displayed on both app and public web profiles.

DJ and organizer listing cards must show images in one consistent frame size and aspect ratio. Use cover cropping with an upper-center focus so faces remain visible in portrait images while organizer logos and artwork keep the same card dimensions.

---

## Events

Contains:

- Title
- Description
- Flyer
- Start date
- End date
- Venue
- ZIP
- Address
- Country
- Google Maps
- Organizer
- Artists
- Ticket URL
- Featured
- Visible
- Status

Future:

Own frontend page.

---

# Releases

Future module.

Contains:

- Cover
- Artist
- Label
- Catalog Number
- Release Date
- Preview
- Spotify
- Hardstyle.com
- YouTube

Release = Product

Do NOT separate Releases and Store.

---

# Store

Future.

Runs from WordPress.

Uses Releases.

The current catalog only exposes a maximum 60-second preview. The later
store may offer a full 128 kbps MP3 after a rewarded advertisement, while
320 kbps MP3 and WAV/lossless remain paid products. Source/master files stay
private and higher-quality downloads require explicit paid entitlements.

---

# Radio

The radio is a v0.99.2.1 scope item, not a deferred post-v1.0 feature. Use the Real Hardstyle FM stream and its current-track metadata; the feature is complete when a custom compact bar player matching the app's red-black design with Play/Stop/Mute, safe bottom-navigation placement, and the provider page are delivered.

Online streaming.

Background playback.

Place a compact, user-controllable player directly below the Hungarian Hardstyle logo on Home. A server-side AutoDJ should continuously rotate a configurable library of X uploaded tracks; Flutter consumes one live stream and does not bundle or sequence the production library. Audible playback starts only after a user action and can always be paused or stopped.

The former AutoDJ/AzuraCast and separate self-hosted radio-backend concepts are removed from the roadmap. The active implementation uses the Real Hardstyle FM stream.



Before implementation, decide music licensing, hosting, bandwidth, codec/bitrate, background playback, audio focus, interruptions, notification controls, and the initial X-sized music library.

---

# Newsletter

Mailchimp. The app now has a native signup screen backed by the live WordPress `newsletter/subscribe` endpoint (backend 2.4.15); invalid-email validation and a real personal e-mail double-opt-in test both succeeded. The Mailchimp API key stays on the server, and the hosted signup landing page remains available as a fallback.

No registration.

---

# Favorites

Stored locally.

No login.

Contains:

- Favorite News
- Favorite Events
- Favorite DJs

---

# Authentication

Current versions do not require registration and do not yet have user accounts.

For v1.0, add Google account sign-in and community user accounts.

Confirmed scope: registration and community accounts exist only in the mobile app. The public WordPress website does not need registration, user profiles, friendships, live feed, or chat UI.

Architecture exception: WordPress remains the single source of truth for editorial content, but app-only community data may use a separate real-time backend. This exception is limited to authentication, community profiles, friendships, chat/feed posts, image uploads, moderation state, and event attendance responses.

Public content such as news, events, DJs, and organizers should remain available anonymously where possible.

Authentication will be required for:

- live feed posting
- live chat
- image uploads
- creating and editing a personal profile
- adding and managing friends
- event attendance responses
- submitting DJs, organizers, and events once registration has been introduced

Until registration exists, the current public submission forms may remain available with rate limiting, file validation, and mandatory editorial approval. When authentication launches, Flutter must hide these forms from signed-out users and the backend must reject unauthenticated submissions.

The authentication and community backend must support privacy controls, moderation, reporting, blocking, account deletion, and safe image storage.

---

# REST API

Current

/events

/artists (backend 2.2.0 deployed and verified; returns only visible DJs)

/artists/{id} (deployed and verified with live DJ data)

/event-submission-options (backend 2.2.0 deployed and verified; shared genre options)

/event-submissions (POST, backend 2.2.0 deployed; validation verified, successful creation awaits intentional app test)

/organizers (backend 2.3.0 deployed and live-verified)

/organizers/{id} (backend 2.3.0 deployed and live-verified with upcoming events)

/profile-submission-options (backend 2.4.0 deployed and live-verified)

/artist-submissions (POST route live-verified in backend 2.4.0; pending editorial review)

/organizer-submissions (POST route live-verified in backend 2.4.0; pending editorial review)

Future

/releases

/store

---

# Mobile Navigation

Bottom Navigation

- News
- Events
- DJs
- Organizers
- More

Confirmed navigation change:

- The old empty Tickets slot is now used by the completed Live Feed/Chat destination.
- Do not reintroduce a separate Tickets slot or replace the Live Feed/Chat destination with the DJ directory.
- Home and News should remain the first two bottom-navigation items.
- Define a deliberate importance order for what belongs on Home, in primary navigation, and under More. The leading user-hook hypothesis is immediate utility (what is happening now / what event is next), making Events a stronger primary-tab candidate while DJs may initially live under More.
- Revisit this choice using real testing and usage feedback before locking the final navigation.
- The dedicated Live Feed/Chat tab and its bottom-navigation placement are implemented; do not treat them as future work.
- Detail screens should eventually open inside a persistent navigation shell so the bottom tabs remain visible and the active tab/history is preserved. Implement this centrally rather than copying the bottom bar into each detail screen.

Confirmed event relationship behavior:

- Event content remains managed through the WordPress API.
- Every related DJ/artist name and the organizer shown on event detail must be clickable.
- They must navigate to complete dedicated DJ and organizer profiles populated from WordPress REST APIs.
- DJ and organizer profile screens are API-backed and connected to their event relationships.

---

# More Menu

Favorites

Newsletter

Settings

Social

Contact

About

The future About/App information screen should include:

- app name
- runtime app version and build number (read from package metadata, not hardcoded)
- developer/maintainer credit
- Hungarian Hardstyle website
- contact link
- privacy policy
- terms/community guidelines
- optional open-source licenses

---

# Settings

Contains

Push Notifications

News Notifications

Event Notifications

Version

Cache

Future

Theme

Language

---

# UI

Dark theme.

Modern.

Minimal.

Fast.

Use rounded corners.

Consistent spacing.

Avoid clutter.

---

# Flutter Rules

Always use:

Riverpod

Go Router

Dio

Models

Providers

Repositories

Avoid duplicated code.

---

# WordPress Rules

Everything should be editable from WordPress.

Never hardcode content.

Always expose new modules through REST API.

## AI-assisted editorial importer

Add a private WordPress admin workflow where an editor enters a public article URL and receives a Hungarian draft with supported media placement. Publishing that WordPress post should make it available to both the website and the existing Flutter posts API.

Requirements:

- always create a draft and require human editorial approval
- provide an original Hungarian summary/adaptation mode with a visible source link for third-party reporting
- store the source URL and attribution metadata
- import featured and inline images into the WordPress Media Library only when reuse rights are confirmed; otherwise require an owned/replacement image
- never expose the AI provider key to Flutter or public REST responses
- validate remote URLs and block internal/private network targets, unsafe HTML, oversized downloads, and slow requests
- retain the existing WordPress post format so galleries, embeds, website rendering, and the Flutter app continue to use one source of truth

---

# Future Features

- Purposeful Hungarian Hardstyle-branded loading animation for v1.0, without artificial startup delay and with reduced-motion support
- The full HUHS-logo startup animation with transparent/no-white background is complete.

- Online Radio is a v1.0 goal, with a Home mini-player and server-side AutoDJ

- Five curated Spotify playlists should be available from a dedicated app section; open Spotify first and fall back to the browser.

- Before external/cloud image uploads, compress submission images on-device to roughly 1200–1600 px width in JPEG/WebP format to reduce storage and bandwidth use.

- Hardstyle Revolution Releases are covered by the completed v0.99.89 WordPress-managed Label catalog; paid products will be implemented inside that same Label tab, not as a separate store.

- Music Store

- Hungarian Hardstyle Top DJ Voting

- Top Track Voting

- Calendar integration

- Better search

- Recommendations

- Live Feed with chat, image posts and moderation is complete.
- Push notifications should cover new published news, new published events, event reminders one week before and on the event day, plus admin-created custom notifications from WordPress.
- Event-day reminder delivery is live-verified and is not an open investigation.
- Current push status: Flutter initializes Firebase/FCM, stores the token locally, registers it with the WordPress API, shows foreground notifications, opens news/event targets in native screens, and syncs per-device notification preferences. Backend 2.4.16 includes Firebase HTTP v1 sending, news/event/link targets, automatic HUHS URL resolution, publish hooks, event reminder scheduling, preference filtering, and a protected service-account settings page. Custom push, news/event publishing pushes, foreground display, and event-day reminders are live-tested successfully. Credentials must never be embedded in Flutter or committed to the plugin.
- The WordPress custom-push form lists the latest published news and events by title, so editors do not need to know WordPress post IDs. It validates that the selected content matches the chosen target type.
- Backend 2.4.12 is live with published IRP related-post records and a public post-detail endpoint. The live endpoint and a real "Kapcsolódó cikk" target were verified. Flutter opens IRP records and normal WordPress "Kapcsolódó cikk", "Kapcsolódó", and "Ez is érdekelhet" links in the native news detail screen and falls back to the in-app browser when no post ID is available.

- Google account registration and sign-in

- Community user profiles

- Friend connections

- Event attendance (`Ott leszek` / `Nem leszek ott`)

- Friend attendance visibility on profiles and events

- WordPress-managed FAQ / GYIK is planned for v0.99.4 under More, with categories, ordering, search, and expandable answers in Flutter

## Annual Top DJ And Track Voting

v0.99.99 is complete and phone-verified: one WordPress season editor provides category-level candidate fields, WordPress manages unlimited candidates per category, DJ and organizer candidates do not use Spotify/YouTube links, the Hungarian hardstyle track category supports optional Spotify/YouTube, Flutter enforces category selection limits of 5/3/2/1/3, displays the active Home entry and voting categories with a 5-second API timeout, registered-user votes are protected by Firestore rules, the newsletter question is separate and explicit, and the native admin summary uses the deployed Firebase API function `getVotingSummary`. ARM64 debug APK: `build/HUHS-v0.99.99+6-arm64-debug.apk`; the current locally prepared follow-up API package is `build/huhs-mobile-api-2.4.43.zip` and still requires WordPress deployment/live verification. Test votes were cleared from Firebase after verification.

The v1.0 Label delivery path is implemented and WordPress API `2.4.48` is deployed and live-verified. API `2.4.49` is prepared locally as a backend-only Mailchimp double-opt-in fix; no APK change is required. The Firebase `syncWordPressLabelProducts` scheduler runs every five minutes after audio processing is ready, creates or updates the four Hungarian one-time products from the WordPress editor prices, activates their purchase options, and writes deterministic IDs to WordPress. The rewarded 128 kbps derivative is not a Play product. Both current audio-ready releases (12123 and 12185) return all four configured products at the requested 700/550 HUF prices. The `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` secret is enabled, the Play service account has Admin access, purchase/download/SSV Functions are deployed, and production AdMob Banner/Rewarded units plus SSV are configured. v1.0.0+9 is rebuilt as the final signed ARM64 APK and AAB (`versionCode 2009`); the remaining v1.0 gate is the project owner's final phone smoke test of that exact production artifact. Apple sign-in and iOS preparation remain explicitly out of scope.

v1.0.0+9 fixes the post-unlock Label state: an already rewarded-unlocked 128 kbps release presents an active `Letöltés` action instead of a disabled `Feloldva` button, while the permanent entitlement prevents repeat ads for the same user and release. Verified ARM64 release artifact: `build/HUHS-v1.0.0+9-arm64-release.apk` (`versionCode 2009`).

## v0.99.999 Android security and public QA

The scope was limited to security hardening and final public Android QA. R8/resource shrinking, Dart obfuscation with split debug symbols, non-debug release signing, HTTPS-only networking, Android backup disablement, and verification of existing Firebase/WordPress server-side authorization and rate limits are implemented. `flutter test` passes all 27 tests, and the signed ARM64 release artifact is `build/HUHS-v0.99.999+1-arm64-release.apk`. Phone testing, Google sign-in with the release certificate, Android QA and signing-key backup are complete. Permanent Play publication and paid Label sales remain v1.0 scope; iOS is deferred until an Apple Developer account is available.

The existing annual WordPress-extension voting workflow should be replaced or complemented by a dedicated Hungarian Hardstyle voting module and REST API.

WordPress remains the administration surface and source of truth for:

- voting seasons and year
- start and end timestamps
- voting status and rules
- `Legjobb magyar hardstyle DJ – <év>` candidates
- `Legjobb magyar hardcore DJ – <év>` candidates
- `Legjobb magyar hardstyle zene – <év>` candidates
- `Legjobb magyar szervező – <év>` candidates
- `Legjobb külföldi DJ – <év>` candidates
- candidate names, artist/title data, images/covers, optional previews, and external links
- result publication settings

The displayed year should come from the voting season configuration. Candidate types must support DJs, organizers, and tracks.

Flutter must:

- fetch the active annual voting season and categories
- show a prominent Home button for the active season; WordPress/admin configuration must be able to enable or disable it, and it must be hidden when no voting is active
- display DJ and track candidates
- allow authenticated users to vote in-app
- clearly show whether the user has already voted
- require a registered, signed-in app account; guests cannot vote
- ask separately about HUHS newsletter subscription and call the existing Mailchimp flow only after explicit consent
- show results only according to the server-defined visibility policy

The backend must enforce voting windows, authentication, duplicate-vote prevention, and category limits. Prefer one authenticated user vote per category by default. Before implementation, decide whether votes can be changed, when results become public, what audit data is retained, and how suspicious voting is moderated.

WordPress admin must include a private overall results dashboard with:

- total submitted votes
- unique voter count where privacy rules allow it
- per-category totals and ranking
- candidate vote totals and percentages
- optional suspicious-vote/moderation indicators
- export capability if needed later

This summary is admin-only. Do not expose it through public REST routes and do not make it visible to ordinary app users unless a season explicitly publishes a separate sanitized result response after voting closes.

### Published Results After Voting

When voting is closed, WordPress admins must be able to explicitly publish a separate results summary that the Flutter app can display. Closing a season and publishing its results are separate actions.

The public results API/page should support:

- season title and year
- voting closed timestamp
- all published categories
- final candidate ranking per category
- candidate name/title and image/cover/logo
- optional vote count and percentage controlled by season settings
- winner highlighting

The public result must never expose voter identities, authentication identifiers, raw vote records, IP/device data, audit logs, moderation notes, or suspicious-vote indicators. Admins should also be able to keep results private or unpublish the public summary if correction is required.

---

# iOS

Application must fully support:

- Android

- iPhone

Future:

iPad

---

# Current Version

v0.99.1+12 (current Flutter package version; community authorization build)

Planned next package: v0.99.2. Its first release check is the AdMob test banner, enabled for the test build with `HUHS_ENABLE_TEST_ADS=true`. Production AdMob IDs and consent/privacy handling remain deferred until the public release.

The v0.99.3 scope also includes making the About screen contact e-mail open the device mail app and keeping the Real Hardstyle FM stream playing when the user switches between apps.

v0.99.4 is implemented and closed in Flutter `0.99.4+3`: the `Több` menu is categorized as `Felfedezés`, `Közösség`, `Beküldés`, `Kapcsolat és támogatás`, and `Alkalmazás`; Donate, versioned feedback e-mail, FAQ search/category/expandable answers, account-backed favorites with bulk deletion, compact social buttons, Home/news test AdMob banners, Instagram URL normalization, and equal-height compact Home event cards are implemented. The WordPress Mobile API `2.4.33` is uploaded, deployed, live-verified, and active with the public FAQ endpoint and managed FAQ post type. Production AdMob identifiers and consent/privacy handling remain release work.

v0.99.2 bugfixes to investigate: e-mail/password sign-in fails despite valid credentials; saved profile images do not render on the profile/avatar; admin user deletion returns a Firebase Functions `INTERNAL` error; and the owner account intermittently falls back from `Szervező` to `Bulizó` while admin access must remain intact. Account roles are final after registration; only admins may change another user's role, enforced server-side. Profiles and Chat must render the persisted account role, with separate `Admin` or `Moderátor` access badges.

Tag- and genre-filtered discovery lists must use API pagination/infinite scroll so all matching news and DJ results can be reached, not only the initially loaded page.

v0.99.3: separate Facebook, Instagram, TikTok, YouTube, and Spotify fields are implemented during registration and in the community profile.
- Next build follow-up: add a password-reset link to login and replace raw Firebase credential errors with a clear Hungarian message.
- Next build follow-up: add password visibility toggles and an optional strong-password generator during registration.
- Next build follow-up: refresh the Home top-left profile avatar immediately after sign-in without requiring manual refresh.
- Next build follow-up: add a dismissible/pinnable Chat notice, admin-created pinned messages, admin pin controls, and a configurable profanity filter that masks blocked words with asterisks.
- Next build follow-up: show an admin-managed startup announcement image with a close button; allow image upload/replacement from the app admin panel and the WordPress Mobile API.
- v0.99.2 follow-up: allow gallery images to be saved to the device with platform permission handling.
- v0.99.2 follow-up: add a Data protection / GDPR information section covering privacy, retention, and user rights.
- v0.99.2 follow-up: review personal-data access rules and keep sensitive operations server-side.
- v0.99.2 follow-up: add practical release hardening (release signing, obfuscation, restricted backend secrets, and abuse/rate-limit checks); absolute protection against reverse engineering is not possible.
- v0.99.2.1 radio scope: completed the Real Hardstyle FM integration at `https://stream.realhardstyle.nl` as the Home radio stream, with a custom compact bar player (Play, Stop, and Mute), current-track metadata when available, safe placement above bottom navigation, and a More-section provider page with the supplied logo, website, and attribution text.
- Real Hardstyle FM provider page must include this legal information: the radio is operated by Dutch Real Hardstyle; according to the provider's public information it has the required Dutch music-rights licences (Buma/Stemra and Sena); Hungarian Hardstyle stores no music files, operates no radio media server, and does not broadcast its own stream; the app only accesses and plays Real Hardstyle's official external stream.
- v0.99.2.1 follow-up: completed the readable modern/cyber-style font fallback with Hungarian accented-character support.

### v0.99.3 - HUHS Vezérlőközpont

- The WordPress Mobile API administration is implemented in source as a separate, red-black branded, Admin-only `HUHS Vezérlőközpont`. It covers readable event/DJ/organizer content and custom metadata editing, submissions, trash, Mobile API settings/status, push, newsletter status, shortcodes, About data and the persistent `Indítási kép`; the radio provider and generic WordPress news/page/media/comment/taxonomy/user menus are excluded.
- A separate admin-only `Felhasználók` menu with search and user-management actions is implemented.
- Event submission is restricted to authenticated registered users in Flutter and unauthenticated API requests are rejected.
- The approved red-black TypeUI layout is implemented globally across Home and every menu/screen with Rajdhani typography, consistent cards and controls, compact sections and radio bar, the unchanged original `assets/logos/huhs_logo.png` HUHS logo, and the `A magyar hardstyle otthona` Home slogan.
- The Home logo area does not repeat bottom-navigation destinations. The persistent radio control is a compact two-line TypeUI bar with a dedicated Play/Stop control, station label, current-track line and Mute control.
- Startup-image saving no longer reports a false failure after a successful backend save; the native admin refresh assigns the new request inside a synchronous `setState` callback.
- The native startup-image dialog includes a delete action that disables display and clears the stored image URL.
- The Chat composer keeps the camera action, emoji helper, and signed-in status on one compact line above the Send button, avoiding overlap on phone widths.
- The About screen contact e-mail opens the device mail app.
- Real Hardstyle FM keeps playing while switching between apps and stops when the app is fully closed.
- The profile screen uses the saved profile image, then the Firebase photo URL, then a name/e-mail monogram. Its editor previews the same circular crop used by the saved avatar and supports free pinch zoom plus horizontal/vertical pan.
- Existing Chat messages resolve the author's live community profile image and crop settings instead of remaining on the avatar stored when the message was created.
- Profile save, image changes, authentication changes and self-deletion invalidate the community auth/profile streams.

Current v0.99.3 source status (2026-07-29):

Completed in source: native Mobile API admin coverage, Firebase-to-WordPress proxy, TypeUI/Rajdhani design, radio behavior, profile image/monogram fallback with free two-axis zoom/pan/focus, profile refresh, persistent no-cache WordPress-backed startup image, Chat permissions/deletion/pinned data, REST/Firebase/Cloudinary checks, pagination, the event-tag fast-scroll fix and expired-event filtering.

Completed follow-ups: the Hungarian character-encoding/mojibake errors on the community profile screen are fixed, and the unnecessary `Beállítások`, `Hírlevél`, and `Shortcode` entries are removed from the native HUHS Vezérlőközpont.

The final v0.99.3 source pass separates the read-only community profile from its editor, persists and reuses the circular avatar's X/Y position and pinch zoom, refreshes active Real Hardstyle FM metadata periodically, and removes the foreground-push lifecycle dependency on a transient widget context. Physical phone verification is performed separately by the project owner.

The Android radio foreground service now retries the Real Hardstyle FM stream after an unexpected playback error or stream completion instead of remaining silently marked as playing. Explicit Stop and full app closure still cancel pending reconnects.

The owner will perform final production phone verification separately. Firebase proxy Functions are deployed. The live WordPress package is `build/huhs-mobile-api-2.4.46.zip`; the locally prepared update is `build/huhs-mobile-api-2.4.47.zip`, which also gives protected audio downloads release-title filenames. Security hardening and signing/obfuscation are complete in v0.99.999; paid Label sales are implemented in v1.0.


Cloudinary is the only active image-upload path for the app. The dedicated Facebook Event URL field is deployed in backend 2.4.3 and tested.

Backend 2.4.9 organizer genre/style metadata and synchronized Flutter display/submission support are implemented; the Flutter changes pass analysis and all tests. Live organizer genre verification remains an editorial content check.

v0.9 implementation status:

- completed: local favorites for news, events, DJs, organizers, and the featured news card
- completed: native news/event titles, related-article navigation, artist Website/Booking labels, organizer genres, social/contact, settings, FCM registration, and custom push targets
- completed: native Mailchimp signup screen and WordPress proxy (backend 2.4.15 live; personal double-opt-in test successful)
- completed operational verification: one-week, one-day/event-day and six-hour reminder delivery is live-verified

v0.95 implementation status:

- completed: on-device submission-image resizing and quality reduction before multipart upload (up to 1600 px, quality 82)

v0.97 polish build status: complete

- fix DJ logo rendering in Flutter while retaining the profile-image fallback order
- standardize DJ and organizer list thumbnails with a fixed cover frame and upper-center portrait focus
- deploy backend 2.4.20 with `Happy Hardcore` in the shared DJ, event, and organizer genre options
- keep DJ names readable in two-column cards on one line by scaling long names down instead of truncating them beside action icons (implemented in Flutter)
- [x] rename the event ticket action to `Jegyvásárlás`
- [x] use the Google Maps app when installed, otherwise the external browser fallback
- one-week, one-day and six-hour reminders are live-verified

v0.99 submission polish:

- Event submission must require date, venue name, city, and address in both Flutter and WordPress/API validation.
- Add the required address field below the venue name.
- Add event end date and end time fields; reject an end datetime earlier than the start datetime.
- Populate the organizer dropdown from WordPress in Flutter and keep it aligned with the existing WordPress selector.
- Require at least one genre; missing required values must show inline messages and red invalid-field styling.
- Use only direct Cloudinary upload with the unsigned `Hun_hs_Mobile` preset, then send the returned URL to WordPress for DJ, organizer, and event submissions.
- Flutter implementation is complete in release `0.99.1+4`; WordPress Mobile API `2.4.31` is uploaded, deployed to production, live-verified, and confirmed active by the project owner; deployment and live verification are complete. It adds authenticated permission checks to submission POST routes while keeping public option GET routes available.
- v0.97 polish complete: event postal-code input accepts digits only in Flutter and WordPress/API validation; new-event publication pushes remain global to FCM-token devices.
- Planned v1.0 notification personalization: normal event pushes target users who favorited or marked attendance; featured-event publication and reminder pushes remain global to every app-installed device with an FCM token, regardless of account registration; users who favorite an organizer receive that organizer's new-event notifications. Explicit notification opt-outs remain respected. A separate admin/editor push for newly received submissions is an optional follow-up.

Planned v1.0 community profile details:

- expose the authenticated profile from a circular top-left Home avatar, using the profile image or a monogram fallback
- let users select an onboarding role: DJ, organizer, or attendee/partygoer
- show DJ submission only to DJ accounts, organizer submission only to organizer accounts, and both to admins; enforce this in the backend as well as Flutter
- bootstrap a private app-admin account for the project owner with full submission approval and editing permissions; do not publish the owner e-mail in app content
- store profile social links, planned events, and favorites together in the profile area
- allow a registered user to claim a DJ profile only after verifying the private or artist-owned booking e-mail stored on that profile; exclude the Hungarian Hardstyle-managed booking address (`info@hungarianhardstyle.hu`) from ownership proof
- add friend requests and an `Ismerősök` list
- show attending friends on event details
- Reuse the Cloudinary direct-upload path for authenticated Live Feed/chat image posts.

Current v0.99.1 implementation status:

- The user-facing community destination is named `Chat`; the Firestore collection remains `live_feed_posts` for compatibility. The composer is responsive, Firebase initializes before the app shell, missing WordPress tag names are hydrated from the core posts REST endpoint, and Firestore rules are deployed. Google sign-in provider and Android SHA configuration are present; release-device verification remains a final external check.

- Flutter includes Firebase Auth registration/sign-in with mandatory DJ, organizer, and partygoer roles.
- The public Firestore Live Feed supports anonymous text-only posts, registered Cloudinary image posts, Unicode emoji, and fixed reactions.
- Home exposes a profile entry, a five-item news slider with 10-second rotation, and news detail exposes tappable tags with a native filtered article list.
- Firestore deployment files are `firestore.rules`, `firebase.json`, and `.firebaserc`; physical ARM verification and rules deployment remain external release checks.
- v0.99.1+12 fixes the community profile/avatar synchronization, signed-in Chat image permission state, author monogram/avatar rendering, separates account roles from access roles, adds admin-only Chat deletion and admin user-role management for legacy profiles, reloads profiles after Auth restoration, and deploys Firestore rules to the named `hungarian-hardstyle` database used by the app. Profile uploads use Cloudinary face-aware cropping; manual focal-point editing remains a later UX enhancement.
- Chat message deletion and the in-app role-management panel are implemented; actual Firebase Auth account deletion for another user is handled by the deployed server-side Cloud Function/Admin SDK task.
- The Cloud Function source is in `functions/` (`deleteCommunityUser`) and is deployed to Firebase. Artifact cleanup retains old function images for 90 days.
- Also record for the next fix pass: push notification text has an encoding bug and may show Hungarian punctuation/accents as HTML entities (for example `&#8211;`) instead of decoded characters.
- Additional community authorization requirements are implemented: the `djdeeroy@gmail.com` admin role is restored on profile load, normal users cannot change roles after onboarding, and admins can remove users and delete Chat messages.
- The latest v0.99.1 bugfix build addresses the previously reported profile/avatar, Chat deletion, logout, duplicate-role, and admin-menu issues. Manual focal-point editing remains optional UX polish.
- v0.99.1 remaining external check: verify Google sign-in on the release device with the current Firebase Android SHA configuration; manual profile focal-point editing remains optional polish.

Planned v0.99.1 Community MVP decisions:

- The Live Feed is publicly readable without registration.
- Signed-out users may publish text only under a generated `Unknown User ####` display name; they cannot upload images or create profiles.
- Registration requires an account role: DJ, organizer, or partygoer.
- Registered users get an app-only profile with avatar/monogram, name, bio, social links, favorites, and planned events.
- Registered users may publish compressed snapshot images to the Live Feed.
- Live Feed messages support Unicode emoji and a small fixed reaction set without introducing a heavy emoji dependency.
- Firebase Authentication/Firestore is the minimal community backend; Cloudinary is the temporary image store. WordPress remains the editorial source of truth.
- Friendships, attendance visibility, profile claims, Live Feed moderation and app-admin tooling are complete; privacy and account deletion remain v1.0 work.
- Add a `Több`-menu user directory/search that lists registered users only and is unavailable to guests.
- Organize `Több`-menu entries into clear categories while keeping `Több` as the visible menu name.

Additional v1.0 product requirements:

- Extend the existing Label tab for the uploaded WordPress release records: WAV master upload, preview generation, configurable Radio/Extended versions, editor-defined WAV and 320 kbps MP3 prices, Google Play Billing, and rewarded-ad unlock for a generated 128 kbps MP3.
- Current requested price defaults for the first release: WAV `700 HUF`, 320 kbps MP3 `550 HUF` for both Radio and Extended versions.
- Keep WAV masters private and generate preview/paid derivatives server-side in a background job. The approximately 300 HUF rewarded-ad revenue target is only an estimate; AdMob eCPM and fill rate determine actual revenue.
- Reorganize `Több` into `Felfedezés`, `Közösség`, `Beküldés`, `Kapcsolat és támogatás`, and `Alkalmazás`; keep Label only in its dedicated bottom tab.
- Add a search field and collapsible category sections to `Több`; place administration in a separate admin-only block.
- Complete final UX polish for consistent card sizes, spacing, icons, loading/empty/error states, touch targets, back behavior, tab history and accessibility scaling.
- Apple account sign-in is deferred until an Apple Developer Program membership is available; it is outside the Android v1.0 scope.
- Label purchase verification is implemented in the Flutter client and Firebase `verifyLabelPurchase` callable, but live deployment still requires the Google Play service-account JSON in Firebase Secret Manager and Play Console product configuration.
- Refresh the WordPress-managed FAQ with the new v0.99.999/v1.0 features and current user guidance.
- Make displayed genres selectable. A genre detail/discovery screen should show separate API-backed `Események`, `DJ-k`, and `Hírek` sections for the selected genre and clearly retain the active genre label.
- The More-section `Támogatás / Donate` card is planned for v0.99.4, backed by a configurable PayPal donation URL with PayPal-app-first and browser fallback opening; do not build a custom payment flow.

Completed

âś" News

âś" Search

âś" Events Backend

âś" Artists Backend

âś" Organizers Backend

âś" Event REST API

âś" Flyer

âś" Ticket URL

âś" Google Maps

âś" Event Shortcode

Flutter Completed

- Dynamic Events in Flutter

- Event Detail with flyer, ticket and Google Maps actions

- HTML tag cleanup for news excerpts

- Clickable event artists and organizer open their API-backed profile screens and are verified with live data

- API-backed DJ directory under More with search, Hardstyle/Hardcore filters, portrait-focused profile cards, full DJ details, social links, biography, and upcoming events

- Event artist and organizer taps open their real API detail screens

In Progress

- Artists API and the Flutter DJ module are deployed and confirmed working with live data.

- Responsive WordPress collection shortcodes: `[huhs_djs]` groups linked DJ cards by category, while `[huhs_events]` lists all upcoming visible events with flyer, date, venue, details, and ticket actions

- Public WordPress archive URLs `/djs/` and `/events/` automatically use the plugin's matching polished collection templates; manual shortcode pages remain optional

- WordPress admin includes `HUHS Mobile > Shortcode-ok`, a copyable reference page for all supported shortcode variants and parameters

- Flutter Events includes an `Esemény beküldése` form. Genres come from WordPress, multiple genres can be selected, and successful submissions are stored as pending items for editorial review rather than being auto-published

- Organizer list/detail API and Flutter UI are implemented and live-verified, including search, logo, description, social links, and upcoming events

- Rich content: YouTube, Spotify, SoundCloud, Instagram and TikTok embeds now render in article detail; interactive WordPress shortcodes open in an in-app web view
- Backend package `2.2.0` includes the earlier rich-content fixes and DJ API/category work, plus the upgraded `[huhs_events]` collection, shared event/DJ genre options, and moderated public event submissions

- Backend `2.2.1` is deployed and confirmed working. It renames the DJ `hero_image` concept to `Profilkép` in the admin, uses that profile image before logo/featured-image fallbacks in DJ directories, and exposes `profile_image` in the artist API while retaining `hero_image` for compatibility

- Backend `2.2.2` is deployed and confirmed working. It and the Flutter DJ UI use consistent cover cropping with an upper-center portrait focal point so faces remain visible when source profile images have different dimensions
- Backend `2.3.0` is deployed and live-verified with organizer list/detail REST endpoints and related upcoming events; the Flutter organizer module and event-detail organizer navigation use these responses
- Backend `2.4.0` is deployed and live-verified. It adds moderated DJ/organizer submissions, admin approval into non-public draft profiles, public DJ booking e-mail support, and a `booking_via_huhs` option that routes booking requests to `info@hungarianhardstyle.hu`
- Backend `2.4.1` is deployed. It accepts optional multipart event flyers and DJ profile images, restricted to JPG/PNG/WebP and 5 MB, stores them as Media Library attachments on pending submissions, previews them for admins, and applies an approved DJ image to the generated draft profile
- Flutter event and DJ submission forms use the device gallery/camera with local preview instead of requiring users to paste image URLs
- Backend `2.4.2` is deployed and its organizer-logo upload was tested in the admin flow; an approved organizer submission receives the uploaded Media Library image as its logo and featured image
- Backend `2.4.3` is deployed and tested. It adds a dedicated `facebook_event_url` field to the WordPress event editor and events mobile API.
- Backend `2.4.7` is deployed and awaiting live approval-flow verification. It replaces the invalid nested approval form with a nonce-protected admin action, removes the misleading native publish box from submissions, restores DJ/organizer draft creation, and adds event-submission conversion into a non-visible event draft.
- Backend `2.4.8` is historical. Its multipart image path remains documented for compatibility, but the active app upload path is Cloudinary; the old upstream-WAF limitation is no longer a current deployment status.
- The public WordPress `/events/` directory should later include an `Esemény beküldése` call-to-action; after app registration is available, the action must require an authenticated user.
- Flutter includes DJ and organizer submission forms under More. DJ submitters can choose Hungarian Hardstyle-managed performance booking; submitted profiles still require WordPress editorial approval and explicit publication/app visibility
- Submitted profile and organizer images are reviewable URLs. They are not automatically copied into the WordPress Media Library; the editor selects/imports the approved image before publication
- DJ logos now render in Flutter and public WordPress artist profiles; direct multipart upload remains separate and uses Cloudinary.
- Profile list refresh now uses auto-dispose providers; continue monitoring live WordPress/API cache behavior after publishing.
- Link handling implemented: normal news, event, ticket, and shortcode links open in one shared in-app browser view, and plain-text URLs in WordPress news/event HTML become tappable automatically. Native media and Maps handoff remain explicit exceptions.

- Web Event Detail

---

# Development Philosophy

WordPress is the CMS.

Flutter is the client.

Never duplicate content.

One backend.

Multiple platforms.

Keep architecture clean.

Keep code modular.

Think long-term.

---

# Vision

The Hungarian Hardstyle App should become the central hub of the Hungarian harder styles scene.

One platform.

One backend.

Multiple brands.

Multiple clients.

Android.

iOS.

Website.

Community.

Music.

Events.

News.

v0.99.4 follow-up status: the Beküldés section explains registration/role requirements when no action is available; Home event cards use the smaller uniform layout; the GDPR screen reflects current Firebase, Cloudinary, WordPress, Mailchimp, and test-AdMob data flows; the native news list has a second separated adaptive test-AdMob placement after the first five cards; and signed-in favorites persist in Firestore with a local cache and bulk deletion.

v0.99.5 is complete in Flutter `0.99.5+1`:

- password reset, visibility toggle, clear Hungarian authentication errors, and strong-password suggestion
- clickable social buttons plus avatar refresh, crop, zoom, and positioning persistence
- Chat profanity masking and automatic message/avatar refresh
- native admin panel scope and readable content with concise save/cancel errors
- final loading/card/control polish and test-AdMob placement

The final ARM64 debug APK artifact is `build/HUHS-v0.99.5+1-arm64-debug.apk`; it is phone-verified by the project owner and v0.99.5 is closed.

v0.99.6 is complete in Flutter `0.99.6+1`:

- gallery images can be saved to the device, including a pre-Android 10 permission fallback
- widget tests are Firebase-safe and the full test suite passes
- Gradle 8.14, AGP 8.11.1 and Kotlin 2.2.20 are verified
- the full HUHS-logo startup animation is active
- profile and Chat avatar refresh/cache behavior is covered by the current implementation
- Hungarian text and character encoding were audited
- accessibility/layout overflow coverage is green
- AdMob test placement and display are verified
- the final ARM64-only debug test APK is built and verified as `build/HUHS-v0.99.6+1-arm64-debug.apk` (package `0.99.6`, ARM64 ABI)

Everything connected.

### v0.99.7 - Community follow-up (complete)

- Verified-email DJ profile claiming matches the authenticated e-mail to the public artist booking e-mail; the Hungarian Hardstyle-managed booking route is excluded.
- Registered-user search/listing is available under `Több` and starts filtering from the first typed character.
- Admin-triggered personalized event and organizer pushes target users who favorited the matching record.
- Chat moderation includes report submission, user blocking, filtering blocked authors from the feed, and admin report visibility.
- Firestore rules and the `claimArtistProfile`/`sendPersonalizedPush` Cloud Functions are deployed. Analyzer, Flutter tests, and Cloud Function syntax checks pass.
- Final ARM64 debug test APK: `build/HUHS-v0.99.7+3-arm64-debug.apk`.

### v0.99.7+3 follow-up (complete)

- After a DJ profile is claimed, show one `Saját DJ-adatlap megnyitása` button on the user's profile; it opens the native in-app DJ detail screen through the deployed `getMyClaimedArtists` callable.

### v0.99.8 - User profile navigation and community details (complete)

- [x] Make each profile card in `Több -> Felhasználók` tappable and open that user's native in-app profile.
- [x] Show only favorite DJs, organizers, and events on the user profile, together with planned event attendance; favorite news is excluded from this profile section.
- [x] Add event attendance states (`Ott leszek` / `Nem leszek ott`), persist the choice, and show participant counts on event details.
- [x] Add basic friends/connections with request, accept/reject, and profile connection-list flows.
- [x] Separate Facebook, Instagram, TikTok, YouTube, and Spotify profile links.
- [x] Show planned events and favorites on the user profile.
- [x] Add biometric unlock for an already saved sign-in session.
- [x] Add simpler own-chat management, a blocked-user list, and report-status visibility.
- [x] Admin-only Chat message deletion and editing are enforced in the app and Firestore rules; normal users and moderators cannot delete or edit messages.
- v0.99.8+2 bugfix pass: attendance records now include the validated event ID; attendance errors are surfaced; connection-request status refreshes after send; the named `hungarian-hardstyle` database push trigger `notifyConnectionRequest` is deployed; biometric enablement checks real device support; `MainActivity` uses `FlutterFragmentActivity` for `local_auth`. Final ARM build is pending phone testing.

### v0.99.8+3 - Connections, reports and planned-event links (complete; phone verification pending)

- [x] Show the sender's profile name and avatar in incoming friend requests, with native profile navigation.
- [x] Send connection-request push notifications for list, map, string and legacy single-token storage.
- [x] Make profile favorites and planned events open their native detail screens.
- [x] Add an admin-only report-management screen with reported user/message details, resolve, delete-message and block-user actions.

### v0.99.8 closure (2026-08-06)

v0.99.8 is closed after the final community fixes. The final ARM64 debug test APK is `build/HUHS-v0.99.8+16-arm64-debug.apk`. Friend-request FCM delivery is live-verified; tapping the notification opens the requester profile. Chat reads live account/access roles, public profiles show favorite DJs/organizers but not favorite news, and the complete attendance, reports, biometric, Chat-permission and admin-role scope is implemented. Remaining release work belongs to v1.0.

### v0.99.89 - Label release-katalógus (complete and closed, 2026-08-06)

- A meglévő HUHS Mobile API új `huhs_release` erőforrást ad címhez, borítóhoz, műfajhoz, több előadóhoz és külső elérhetőségi linkekhez.
- A feltöltött teljes MP3 csak ideiglenes forrás; a plugin FFmpeg-gel a 30. másodperctől legfeljebb 60 másodperces preview MP3-at generál, majd törli az eredeti MP3-at. Az API kizárólag a preview URL-t adja vissza.
- Flutterben önálló `Label` alsó navigációs fül van a Chat és Több között.
- Az előadók külön kattinthatók, és az adott előadó további release-ei listázhatók.
- A preview saját lejátszóval hallgatható; vásárlás, kosár, letöltés és saját digitális store nem része ennek a buildnek.
- A kész cache-javító csomag a meglévő HUHS Mobile API 2.4.37-es változata, nem új API.
- A build lezárt: ARM64 debug APK: `build/HUHS-v0.99.89+1-arm64-debug.apk`.
- A későbbi fizetős zeneértékesítés ugyanebbe a Label katalógusba kerül; külön katalógus vagy külön Store-rész nem készül.

### v0.99.90 - HUHS Vezérlőközpont bugfixek (lezárva, 2026-08-07)

A korábbi build-ek késznek és lezártnak tekintendők. A következő hibákat a v0.99.90-ben kell kezelni:

- [x] A `Mégse` biztonságosan megszakítja az Events/DJ/Szervező és kapcsolódó szerkesztőket téves piros hiba és hibás űrlapállapot nélkül.
- [x] A natív Mobil API-szerkesztők mezői tagoltabbak és átláthatóbbak.
- [x] A DJ-k név alapján választhatók, nem csak ID-k jelennek meg.
- [x] A nem kért `Személyre szabott push` vezérlőfelület kikerült; az általános és egyedi push megmaradt.
- [x] A vezérlőközpont életciklus- és dialóguskezelése védi a `_dependents.isEmpty` assertion útvonalát.
- [x] A célzott UX-, accessibility- és layout-polish elkészült.

Telefonon ellenőrizve és lezárva. ARM64 debug APK: `build/HUHS-v0.99.90+3-arm64-debug.apk`. Az aktív, meglévő HUHS Mobile API frissített csomagja `2.4.37` (`build/huhs-mobile-api-2.4.37.zip`).
