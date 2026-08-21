# Hungarian Hardstyle App

## Külön projekt: Hungarian Hardstyle Ticketing

Önálló WordPress ticketing modul és REST API készülhet `jegy.hungarianhardstyle.hu` alatt. A rendszer nem a jelenlegi mobil API-ba kerül közvetlenül; később a Flutter app és a scanner ugyanazt a ticketing API-t használja. Partnerenként konfigurálható lesz a Stripe vagy Barion, a Billingo-kapcsolat, a számlázási adatok és a kezelési költség. A tervezett funkciók közé tartozik az esemény- és jegytípus-kezelés, névre szóló PDF-jegy, egyedi vonalkód, vendéglista és szerveroldali beléptetés.

## +167 utólagos backend-javítás

Az ingyenes `free_wav` letöltés Firebase-útvonala vendég/névtelen kérést is elfogad; a fizetős és reklámos MP3-változatok hitelesítése változatlan. A `getLabelDownloadUrl` funkció élesítve, a WordPress WAV-token végpont ellenőrizve.

Következő build feladata: ingyenes kiadványhoz opcionális külső feloldási link, például Hypeddit. A link reklám után legyen elérhető, de ne generáljon WAV-ot; az ingyenes WAV- és normál 128 kbps MP3-útvonal változatlan maradjon.

## +167 állapot — production AAB elkészült; zárt tesztbe feltöltésre vár

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

- Production AAB: `build/HUHS-v1.0.0+165-release.aab`, versionCode 165. A korábbi production AdMob App/Banner/Rewarded azonosítók visszaállítva és az AAB-ban ellenőrizve.
- `flutter analyze --no-pub`, Gradle release build és `git diff --check` sikeres. A Play zárt tesztbe feltöltés még függőben van az interaktív Play Console-vezérlés hiánya miatt.

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

- Ingyenes kiadvány letöltése: WAV fájl legyen, ne 128 kbps MP3; a javítást Playből telepítve ellenőrizni kell. Ez csak az ingyenes kiadványra vonatkozik; a normál release marad 128 kbps MP3 reklámért.
- Helyi állapot: az ingyenes kiadvány kliens- és letöltési útvonala külön `free_wav` változatra állítva; a WordPress-végpont csak `is_free` kiadványnál engedi ezt. A normál `mp3_128` jutalmazott útvonal változatlan. Playből telepített ellenőrzés és backend-élesítés még hátra van.
- Play Console „Alkalmazásoptimalizálás: Közepes”: a +164 AAB-nál a Play Console két hiányzó optimalizálást jelzett (optimalizált erőforráscsökkentés és osztályok újracsomagolása). A buildlánc AGP 9.0.1-re és Gradle 9.1.0-ra, az AGP 9-kompatibilis `google_mobile_ads` csomag 9.1.0-ra frissítve; az elavult adaptív banner API is lecserélve. A Gradle-konfiguráció és a statikus ellenőrzés sikeres; új AAB feldolgozása után kell visszaellenőrizni, hogy a mutató javult-e.
- Chat: az adminfunkciók kerüljenek a hárompontos üzenetmenübe, a blokkolás és jelentés mellé.
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

- A fő Label-lista már kiszűri az ingyenes kiadványokat; ezek kizárólag az „Ingyenes kiadványok” nézetben jelennek meg. A kártyák a WordPress API-ból érkező borítóképet jelenítik meg; Playből telepített futásidejű ellenőrzés még hátra van.
- A kiadványkártyák fix magasságot használnak; a hosszú című kártyák vizuális ellenőrzése Playből telepített +164-ben maradt.
- Az ingyenes jutalmazott feloldás visszajelzése a free release nézetben is látható; Playből telepítve ellenőrizendő, hogy nem ragad be.
- A Közösség főmenübe bekerült a Kedvencek és a Hírlevél; a „Több” menüből külön menüpontként eltávolítva maradnak.
- A Hírlevél a Közösség menüben megmaradt, és kikerült a saját felhasználói profil read-only és szerkesztési nézetéből; futásidejű ellenőrzés még nincs.
- Az AdMob banner betöltési útvonala kódoldalon javítva: a consent és az SDK inicializálása folyamat-szinten egyszer fut, az elavult/párhuzamos kérések kiesnek, a sikertelen betöltés 5 másodperc után kontrolláltan újrapróbálkozik; a tényleges Play-beli bannerbetöltés még ellenőrizendő.
- A telefonos és kompatibilitási teszt nem blokkolja a +164 célját.
- A release AAB elkészült: `build/HUHS-v1.0.0+164-release.aab`; 100%-os zárt tesztkiadásként feltöltve és felülvizsgálatra beküldve. A Google gyorsellenőrzése/felülvizsgálata még folyamatban.

- A +163 alkalmazásoldali javításai helyben elkészültek; Android 15 Pixel emulátoron ellenőrizve a rendszer-visszagomb, a kezdőlapi kilépési kérdés, a kilépés utáni task-eltávolítás, a fekvő Chat és a kijelentkezett Chat-avatar.
- A hosszú release-címek kártyaméretezése egységesítve, az ingyenes kiadvány `is_free` modelltesztjei bekerültek.
- `flutter analyze` sikeres, mind a 29 Flutter-teszt átment, `git diff --check` rendben.
- A production +163 AAB elkészült: `build/HUHS-v1.0.0+163-release.aab` (73.8 MB), a +161-ből visszaállított production AdMob-azonosítókkal és release-aláírással. A Play Console zárt tesztcsatornájába feltöltve és felülvizsgálatra beküldve; jelenleg „Felülvizsgálat alatt álló módosítások”.
- Az ingyenes kiadványok UI-ja és explicit API-mezője elkészült; a WordPress `huhs-mobile-api-2.4.53` csomagban az „Ingyenes kiadvány” jelölő és a külön médiafeltöltő mező bekerült, az API élesben telepítve és a `/wp-json/huhs/v1/releases` végponton `is_free` mezővel ellenőrizve.
- A telefonos és kompatibilitási tesztek utólagos tulajdonosi validációk; ezek nem blokkolják a +163 cél elérését vagy a release-folyamatot.

## +162 aktuális állapot — 2026-08-18

### +163 végrehajtási állapot

- A release-kártyák hosszú című megjelenítési javítása helyben elkészült: álló és fekvő nézetben is ugyanaz a fix magasságú fekvő listaelrendezés fut, a cím legfeljebb két soros. Playből telepítve még ellenőrizni kell.
- A Label képernyő jobb felső sarkában látható „Ingyenes kiadványok” gomb nyissa meg az explicit API-val jelölt ingyenes zenék szekcióját; a zenék reklám megtekintése után legyenek letölthetők. A kliens és a `huhs-mobile-api-2.4.53` csomag kész; az éles Play-ből telepített kliens letöltési tesztje még nyitott.
- Közösség menü: a Kedvencek és a Hírlevél ténylegesen jelenjen meg a Közösségben; a „Több” menüből maradjanak eltávolítva.
- Android rendszer-visszagomb regresszió javítva: egyetlen központi `PopScope` kezeli a rendszer-visszát; nem kezdőlap tabgyökerén a Kezdőlap nyílik meg, a Kezdőlap gyökerén megerősítés jelenik meg, és az „Igen” után a natív Activity taskja eltávolításra kerül.
- Zenevásárlás/Play Billing: a WordPressből kapott termékazonosítók és a Play Billing `ProductDetails` lekérése közti szürke gombos hibát javítani kell; legyen kontrollált újrapróbálás, pontos ID-alapú állapotkezelés és érthető hibaüzenet. A Play Console-termékek aktívak, ezért ezt a kliensoldali Billing-útvonalon és Playből telepített verzióban kell ellenőrizni.
- Play Console „Alkalmazásoptimalizálás: Közepes” mutató újraellenőrzése a feldolgozás után.
- A +163 feltöltött alkalmazásoldali feladatköre elkészült; az ingyenes kiadványok főlistából való kizárása a feltöltés után külön +164 javításként került be. A telefonos/kompatibilitási teszt utólagos validáció, nem célblokkoló.
- Release előtt marad: a +163 AAB Play zárt tesztcsatornába feltöltése; utólag ellenőrizendő a Play Console „Közepes” mutatója és az ingyenes kiadvány tényleges Play-letöltése.

- Az alkalmazásoldali +162 javítások elkészültek, a production AAB: `build/HUHS-v1.0.0+162-release.aab` (versionCode 162).
- A csomag a Google Play zárt tesztcsatornájába feltöltve és felülvizsgálatra beküldve; a Play Console állapota „Ellenőrzés alatt”.
- Flutter ellenőrzés: analyze sikeres, 27/27 teszt sikeres, diff-check whitespace-hiba nélkül.
- A release-date backend módosítása a `huhs-mobile-api-2.4.52` csomagban telepítve és élesben ellenőrizve; az API `release_date` mezőt ad vissza.
- A tesztelői széles Android/tablet/gyártói kompatibilitás még külső ellenőrzés; a Play-optimalizálási újraellenőrzés átkerült a +163 feladatai közé.
- Pixel Tablet API 35 emulátoros fekvő ellenőrzés sikeres; a valódi gyártói eszközök ellenőrzése még tesztelői készüléklistát igényel.

### Aktuális build: +162 — külső ellenőrzés alatt

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

### v1.0.0+161 hotfix — technikai versionCode 161

A +161 javítja a +160 Play-regresszióját: az adaptív AdMob banner szélességi kérése ismét legalább 320 px-es használható szélességgel indul, így a 0/1 px-es átmeneti layoutból nem készül érvénytelen bannerkérés. A rewarded reklám- és consent-logika változatlan. A release AAB: `build/HUHS-v1.0.0+161-release.aab`. A helyi `flutter analyze`, 27 Flutter-teszt és `git diff --check` sikeres. A tulajdonosi teszt szerint az AdMob, az Android visszagomb, a preview végi vezérlő-visszaállítása és a preview utáni rádió-újraindítás működik; a főoldali kilépési megerősítés tényleges bezárása +162-re marad.

### v1.0.0+160 release — technikai versionCode 160

A +160 release AAB: `build/HUHS-v1.0.0+160-release.aab`. A +159 Play-piszkozat törölve lett, a +160-as AAB a Google Play zárt tesztcsatornájába feltöltve és felülvizsgálatra beküldve. A Play Console jelenleg a gyors ellenőrzéseket/felülvizsgálatot futtatja. A helyi `flutter analyze`, 27 Flutter-teszt és `git diff --check` sikeres.

Tulajdonosi visszajelzés: a +158-ban az AdMob banner működött, a +160-ban a Playből telepített változatban nem jelenik meg, miközben a jutalmazott reklám működik. Ez +160 regresszióként nyitott; a banner consent/`canRequestAds()` útvonalát és a release konfigurációját össze kell vetni a +158-cal, majd új buildben javítani és Playből ellenőrizni.

A +161 ezt a banner-szélességi regressziót javítja. Az AAB a zárt tesztcsatornába feltöltve és felülvizsgálatra beküldve; a tulajdonosi teszt szerint az AdMob banner működik.

### Archív v1.0.0+159 release — technikai versionCode 159

A +159 release fekvő tablet/telefon nézetben `SafeArea`-ba helyezi a tartalmat, ezért az Android rendszer-navigáció nem takarja el a rádiót. A fekvő NavigationRail görgethető, így nem okoz túlcsordulást. A release AAB: `build/HUHS-v1.0.0+159-release.aab`, belső versionCode: 159.

Play Console állapot: a zárt teszt feltöltése a 159-es verziókód miatt megakadt; a Play szerint ezt a verziókódot már felhasználták. A +159 helyett a +160 került beküldésre.

Ellenőrzés: `flutter analyze` hibamentes, mind a 27 Flutter-teszt átment, `git diff --check` rendben, Graphify frissítve.

### v1.0.0+154 hotfix — technikai versionCode 154

A hotfix eltávolítja a lejárt eseményeket a profilok „Események, ahol ott leszek” listájából és a kedvencekből is, továbbá megbízhatóvá teszi a Label-preview szüneteltetését/leállítását. A lejátszás indítása nem zárolja a vezérlőket a preview végéig. A +153 navigációs és chatkép-javításai változatlanul benne maradnak. A production AAB: `build/HUHS-v1.0.0+154-release.aab`; a kiadás éles a Google Play zárt tesztcsatornáján.

### Archív v1.0.0+158 hotfix végrehajtási és ellenőrzési állapot

A +158 hotfix a +157 visszajelzett hibáját javítja: az Android rendszer-visszagomb kezelését egyetlen központi `PopScope` kezeli, így a tabgyökér nem ürül ki, a belső oldal visszalép, a nem kezdőlap tabgyökeréről a Kezdőlap nyílik meg, a Kezdőlap gyökerén pedig kilépési megerősítés jelenik meg. A release AAB elkészült: `build/HUHS-v1.0.0+158-release.aab`; a Play Console zárt tesztkiadásába feltöltve és felülvizsgálatra beküldve, az automatikus ellenőrzés folyamatban.

- Alsó navigációs tab főoldalán (Hírek, Események, Label, Több, Közösség stb.) az Android visszagomb a főoldalra navigáljon, ne léptesse ki az appot.
- Belső aloldalon az Android visszagomb az előző képernyőre navigáljon.
- A főoldal gyökerén az Android visszagomb megerősítő kilépési kérdést jelenítsen meg.
- Törölt vagy már nem elérhető hírek, DJ-k és szervezők tűnjenek el az user adatlapján a kedvencek közül is.
- AdMob banner javítása Playből telepített verzióban: a consent-frissítés és a `canRequestAds()` ellenőrzése előzze meg a bannerkérést; a betöltési hibakód, domain és üzenet legyen naplózható, sikertelen betöltés után pedig működjön kontrollált újrapróbálás. A jutalmazott reklámfolyamat nem törhet el.
- Preview végén a lejátszó vezérlői álljanak vissza alapállapotba.
- Preview leállítása vagy befejezése után a Real Hardstyle FM rádió legyen ismét indítható.
- Ponytail-alapú kódtakarítás: a nem használt, elavult vagy már kiváltott kódágak és duplikált megoldások célzott felülvizsgálata, majd biztonságos eltávolítása.
- A Play Console „Alkalmazásoptimalizálás: Közepes” mutatójának kivizsgálása és javítása: memóriahasználat, teljesítmény, obfuszkáció és méretcsökkentés ellenőrzése, majd új Play-feldolgozási eredmény alapján visszaellenőrzése.

### Archív +16 állapot — technikai versionCode 152 (nem aktuális build)

A +16 kliensjavításai elkészültek, a release AAB elkészült: `build/app/outputs/bundle/release/app-release.aab`. A build R8/minify és resource shrink mellett Dart-obfuszkációval, split-debug-info szimbólummentéssel és production AdMob-azonosítókkal készült. A 4467 ellenőrzött projektfájl UTF-8-validációja hibátlan. A Play Console optimalizálási „Közepes” mutatója az AAB feltöltése és feldolgozása után számolható újra; ez nem helyi kódhiba-jelzés.

Kódoldalon elkészült: az eseményszekciók szétválasztása, a profil eseménycímkéje, a teljes Közösség-belépési pont, az új verzió ellenőrzése appnyitáskor/elő­térbe visszatéréskor, a nested Android visszanavigáció, a preview kézi leállítása/újraindítása, a preview–rádió állapotszinkron, a törölt ismerősök takarítása, az adaptív AdMob banner újramérése, valamint a fekvő Chat és rádió elrendezésének javítása.

Még külső tesztelendő: Playből telepített AdMob banner és a telefonos fekvő Hírek/Chat/radio UX; tableten a fekvő Hírek olvasható. Több gyártó/verzió/tablet kompatibilitása továbbra is ellenőrizendő. Az Android visszagomb tulajdonosi hibája a +155-be került. A Play Billing, push és biometria már működőként igazolt.

### Archív +16 feladatlista és ellenőrzési állapot (nem aktuális build, csak történeti nyilvántartás)

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

## Központi Cégregiszter – tervezett WordPress projekt

Ez a projektmemória tartalmazza a `szakmaiceg.sql` alapján tervezett, önálló WordPress cégregiszter követelményeit is.

- Céloldal: `https://kozponticegregiszter.hu/`
- A Mosets Tree SQL teljes importja WordPressbe.
- Saját `Cég` tartalomtípus, backend cégfeltöltő és saját Business API.
- A főoldalon a kategóriák legyenek a központi, kattintható elemek.
- Kattintható kategóriák, cégek, céges adatlapok és térképes cégek.
- Keresés és szűrés cégnév, kulcsszó, város, megye és kategória alapján.
- Interaktív, beágyazott OpenStreetMap/Leaflet térkép céges adatlapokon és összesített térképes nézetben.
- A Mosets Tree meglévő GPS-koordinátáinak megtartása.
- A látványterv csak vizuális irányadó; képként nem kerül beillesztésre.
- Fehér–kék–türkiz, modern, üzleti és mobilbarát business-directory megjelenés.

### KCR mobilapp – rögzített navigáció és működés

- Az app designja a `kozponticegregiszter.hu` üzleti, fehér–kék–türkiz megjelenését kövesse.
- Az alsó navigáció menüi: `Cégek`, `Megrendelés`, `Cégünkről`, `ÁSZF`, `Hírlevél`.
- A `Belépés` a felső bal sarokban legyen; sikeres belépés után ugyanott `Fiók` jelenjen meg.
- A céges útvonal: fő kategória → alkategória → kártyás céglista → cégadatlap.
- A Fiókban látszódjon a felhasználó saját cége, hirdetése, lejárata és szerkesztési lehetősége.
- A cégadatok és a hirdetési jogosultságok forrása a WordPress/KCR API; az app ne használjon külön cégadatbázist.
- A lejárati időt a backend állítja be fizetés után. Lejáratkor a cég piszkozatba kerül; a dátum nélküli régi cégek aktívak maradnak.
- Az app integrációs végpontja: `/wp-json/kcr/v1/companies/{id}/listing-period`, amely a `starts`, `expires`, `active` és `legacy_without_expiry` mezőket adja.

### Importálandó cégmezők

Név, alias, leírás, kulcsszavak, kategória, alkategória, kapcsolattartó, telephely/cím, város, megye, ország, irányítószám, telefon, mobil, fax, e-mail, másodlagos e-mail, weboldal, Facebook, képek és fájlok, szélességi/hosszúsági koordináta, térképzoom, térkép megjelenítése, kiemelt és publikációs státusz, SEO metaadatok, létrehozási és módosítási adatok.

Az SQL-ben található képhivatkozások teljes átviteléhez a Mosets Tree tényleges képmappája is szükséges. A WordPress telepítés és alkalmazásjelszó elkészülte után következhet a plugin, az importáló és az API telepítése.

### SEO-követelmények a meglévő cégekhez

- Minden céghez egyedi, kulcsszóbarát SEO title és meta description készüljön.
- A cég neve, fő tevékenysége, városa és releváns kategóriája jelenjen meg természetesen a metaadatokban.
- Legyen SEO-barát, stabil céges URL és canonical URL.
- A Mosets Tree régi céges URL-jeihez 301-es átirányítási lista készüljön.
- A céges adatlapok kapjanak `LocalBusiness`/megfelelő üzleti `schema.org` strukturált adatot, névvel, címmel, telefonnal, weboldallal, kategóriával és koordinátákkal.
- A kategória- és városoldalak indexelhető, egyedi title-lel és leírással készüljenek.
- A céges képekhez értelmes fájlnév, ALT-szöveg és cím kerüljön.
- Legyen XML sitemap a céges adatlapokhoz és kategóriaoldalakhoz.
- A duplikált, üres vagy nem publikált rekordok ne kerüljenek indexelésre.
- A meglévő Mosets meta keywords és meta description mezőket importáljuk, majd szabályosan tisztítjuk és kiegészítjük.
- Az import végén SEO-ellenőrző riport készüljön hiányzó title, description, koordináta, kép-ALT és canonical URL esetekről.

The official cross-platform application of **Hungarian Hardstyle**, built as a central hub for the Hungarian harder styles scene.

WordPress is the source of truth for editorial content. Flutter consumes the public REST API for news, events, DJs, organizers and the Label release catalog.

## Current status

### v1.0.0+160 aktuális release

- [x] A +160 release AAB elkészült: `build/HUHS-v1.0.0+160-release.aab`.
- [x] `flutter analyze` hibamentes és mind a 27 Flutter-teszt átment.
- [x] A +159 Play-piszkozat törölve; a Play a 159-es versionCode-ot már felhasználtnak jelezte.
- [x] +160 feltöltése és Play-oldali feldolgozásának elindítása a zárt tesztcsatornán; a Play-felülvizsgálat folyamatban.

### Archív v1.0.0+159 release

- [x] Fekvő tablet/telefon nézetben a rendszer-navigáció nem takarja el a rádiót (`SafeArea`), a fekvő navigációs rail görgethető.
- [x] A +159 release AAB elkészült és belső versionCode-ja ellenőrzötten 159: `build/HUHS-v1.0.0+159-release.aab`.
- [x] `flutter analyze`, 27 Flutter-teszt és `git diff --check` sikeres.
- [x] A Graphify-index a +159 forrásállapotra frissítve.
- [ ] Google Play zárt tesztcsatorna-feltöltés és Play-oldali feldolgozás.

### Következő build – biztonsági és kompatibilitási audit

- [x] Fióktörlés után teljes kijelentkeztetés: Firebase Auth-munkamenet, lokális profil-/session-állapot és visszatöltés ellenőrzése.
- [x] Release preview javítása: ugyanaz a preview többször is lejátszható, és preview indításakor a Real Hardstyle FM rádió leáll.
- [x] A release preview lejátszóján a 60 másodperces anyagban működik az előre- és visszatekerés.
- [ ] Rate limiting felülvizsgálata: megvizsgálni a példányonkénti memóriás számláló központi, több példányon is konzisztens megoldásra cserélését.
- [ ] Firestore-olvasási szabályok célzott auditja és szűkítése úgy, hogy a meglévő profil-, ismerős-, esemény-, Chat- és moderációs funkciók ne törjenek el.
- [ ] Széleskörű Android-kompatibilitási ellenőrzés több Android-verzión, gyártón és rendszerfelületen (például Samsung/One UI, Xiaomi/HyperOS, Pixel/stock Android és más elérhető készülékeken), telefonon, tableten, eltérő kijelzőméreteken és fekvő nézetben; külön Play Billing, AdMob, push és biometria tesztekkel. A háttér-rádió működő funkció, nem nyitott feladat.
- [ ] Obfuszkáció és release-hardening újraellenőrzése; az APK visszafejthetetlensége nem garantálható, ezért titok és jogosultsági döntés továbbra sem kerülhet kliensoldalra.
- [ ] Tanúsítvány-pinning megvalósíthatóságának vizsgálata külön kompatibilitási teszttel; csak akkor bevezetni, ha a Firebase, WordPress, CDN/WAF és AdMob tanúsítványcseréi mellett biztonságosan fenntartható.
- [ ] AdMob banner/csík hirdetések kivizsgálása és javítása a Playről telepített zárt tesztverzióban; a működő jutalmazott reklámfolyamat ne törjön el.
- [x] Sima e-mail/jelszavas regisztráció e-mailes hitelesítése: Firebase-küldés, appoldali állapotfrissítés és látható újraküldés; a kézbesítés/tartalom Playtől független Firebase-ellenőrzés.
- [ ] A regisztrációs kétfaktoros figyelmeztetés és az érintett auth-üzenetek magyar karakterkódolásának javítása; ne jelenjen meg mojibake vagy technikai hiba.
- [x] Fióktörlés után teljes kijelentkeztetés és lokális profil-/session-állapot törlése.
- [x] A release-preview korlátlanul újraindítható, indításakor leáll a rádió, és a 60 másodperces preview-ban működik az előre- és visszatekerés.
- [x] Eseményrészvétel színjavítása: csak az aktív választás piros, a másik semleges.
- [x] Eseménybeküldő űrlap layout-hibája javítva: a mezők, címkék és műfajgombok nem fedik egymást.
- [x] Közösségi admin szerepkör-választó layout-hibája javítva.
- [x] Főoldali hírszlider lapozási pontjai a ténylegesen megjelenő hírrel szinkronban vannak.
- [x] Profilnév módosítása normál regisztrált felhasználónál tiltva van; az admini útvonal megmarad.
- [x] Android rendszer-vissza navigáció: a nested navigatorok kezelése után csak a főoldal gyökerénél történik kilépés.
- [x] Label-kereső: a keresőkifejezés megmarad, szerkeszthető és törölhető.
- [x] Beküldések duplikációvédelme az esemény-, DJ- és szervezőbeküldésnél.
- [x] Custom push duplikációvédelme és token-deduplikáció.
- [x] Beküldési értesítések csak admin címzettre mennek.
- [x] Admin-címzett push technikai útvonal és felhasználóhoz kötött FCM-token-szinkron.
- [x] Alsó értesítési buborékok 7–8 másodperc után automatikusan eltűnnek és kézzel is lehúzhatók.
- [x] Bejelentkezett e-mail/jelszavas felhasználó megfelelő újrahitelesítéssel módosíthatja a jelszavát.
- [x] E-mailes regisztrációnál külön jelszó-megerősítő mező van.

### Következő build kötelező UX- és kompatibilitási feladata

- [ ] Teljes fekvő mobil-layout: a jelenlegi portré-elrendezés helyett fekvő telefonon is használható nézet kell kompakt rádióval és navigációval, kétoszlopos hír-/eseménykártyákkal, kétoszlopos űrlapmezőkkel, megfelelő adatlap-elrendezéssel és jól méretezett modalokkal.
- [x] Külön „Közösség” gomb és felirat van a jobb felső sarokban, a közösségi adatlap/ismerőslista közvetlen elérésével.

### v0.99.3 — complete and closed (2026-07-30)

- Current Flutter build: `0.99.999+1`; v0.99.3 through v0.99.90, v0.99.89 and v0.99.99 are closed. Older APK references are historical.
- Firestore rules and the named `hungarian-hardstyle` database `deleteCommunityUser` Function are deployed.
- Account roles remain independent from Admin/Moderátor access roles; the owner account is Organizer + Admin.
- v0.99.999 is complete and phone-verified; final Play Store packaging remains v1.0 work.
- WordPress submissions and native admin submission editing/approval/trash actions use server-side Firebase Functions: they verify Firebase Auth and access roles before forwarding to WordPress. No WordPress credential belongs in Flutter.
- Cloudinary uploads are client-guarded to JPG/JPEG/PNG/WebP and 5 MB. The unsigned `Hun_hs_Mobile` preset must use the same allowed formats, `huhs/community` folder, unique filenames, and overwrite disabled.
- Expired events are filtered from API results and the cached event list rechecks every minute.
- Firestore rules for role-bound Chat authorship are compiled and deployed to the hungarian-hardstyle database.
- The Real Hardstyle FM provider page includes the requested legal information.

### v0.99.1 implementation status

The Community MVP source implementation is complete on `codex/v1.0`: Firebase Authentication (email/password and Google), mandatory account roles, public Firestore Chat, anonymous text-only posting, registered Cloudinary image posts, profile entry/editing, fixed reactions, a five-item Home news slider with 10-second rotation, and native article-tag filtering. `firestore.rules`, `firebase.json` and `.firebaserc` are included for deployment. Physical ARM verification, Firebase rules deployment, and Google OAuth Console configuration remain external release checks.

The current delivery target is **v0.99.1 Community MVP**. The first MVP implementation is now in the Flutter source: Firebase Auth/Firestore Chat, anonymous text posting, registered image posting through Cloudinary, role-aware registration, profile entry, the five-news ten-second Home slider, and native article-tag filtering.

The v0.99.1 community bugfix pass is implemented in `v0.99.1+12`; e-mail/password registration and Google-account sign-in remain the required entry paths, with a mandatory account role.
The v0.99.1+11 authorization pass also resolves the previously reported Chat deletion, admin-role persistence, and in-app user-management issues. Manual profile focal-point editing remains optional polish.
v0.99.1+12 fixes the community profile/avatar synchronization, signed-in Chat image permission state, author monogram/avatar rendering, separate account/access roles, admin-only Chat deletion, admin user-role management for legacy profiles, Auth-restored profile loading, duplicate-role dropdown crash, logout navigation crash, and deploys the Firestore rules to the named `hungarian-hardstyle` database used by the app. Google sign-in remains a release-device/Firebase SHA verification check; manual focal-point editing is optional later UX polish.

- Separate Facebook, Instagram, TikTok, YouTube, and Spotify fields are implemented during registration and in the community profile.
- Next build follow-up: add a password-reset link to login and replace raw Firebase credential errors with a clear Hungarian message.
- Next build follow-up: add password visibility toggles and an optional strong-password generator during registration.
- Next build follow-up: refresh the Home top-left profile avatar immediately after sign-in without requiring manual refresh.
- Next build follow-up: add a dismissible/pinnable Chat notice, admin-created pinned messages, admin pin controls, and a configurable profanity filter that masks blocked words with asterisks.
- Next build follow-up: show an admin-managed startup announcement image with a close button; allow image upload/replacement from the app admin panel and the WordPress Mobile API.
Chat message deletion and the in-app role-management panel are implemented. The server-side `functions/deleteCommunityUser` Cloud Function performs real Auth/profile/Chat deletion and is deployed to Firebase. Artifact cleanup retains old function images for 90 days.
Push notification text also needs an encoding fix because HTML entities can appear literally in the notification body.
Community permissions are server-enforced: the owner keeps admin access, account roles are final for normal users, admins manage account/access roles and Chat messages, and moderators cannot edit or delete Chat messages.

The WordPress backend package **2.4.49** is deployed and live-verified. A local **2.4.51** package is also prepared but not deployed: it removes the direct WordPress submission broadcast so event/DJ/organizer submission pushes can only be sent by the authenticated Firebase Function to admin recipients. The 2.4.49 package includes the Mailchimp double-opt-in handling: new contacts use `POST` with `status: pending`, while existing non-active contacts are explicitly changed to `pending` so the confirmation flow can start. The app does not need a new APK for this backend change. The package retains the live voting module, separate Radio/Extended Label uploads, Radio preview generation, private WAV/320 kbps derivatives for both versions, one-time download-token handling, release-title filenames for rewarded and purchased downloads, v1.0 FAQ guidance, native admin fields for the four Google Play product IDs/prices, and the protected route for the Firebase Play-product synchronizer. The public release API never exposes private audio paths.

### v0.99.2 — next test build

- [x] re-enable the Google AdMob test banner with `HUHS_ENABLE_TEST_ADS=true` (test build default)
- [ ] verify the test ad on the ARM debug APK without blocking startup
- [x] configure production AdMob App, Banner and Rewarded identifiers plus the rewarded SSV callback
- [x] fix e-mail/password sign-in independently of the misleading raw Firebase credential error
- [x] fix saved profile-image rendering and Cloudinary upload persistence in source; physical phone verification remains with the project owner
- [x] fix admin user deletion and deploy the `deleteCommunityUser` Cloud Function
- [x] make the owner's `djdeeroy@gmail.com` account role persist as `Szervező` while retaining admin access
- [x] enforce final account roles server-side: users choose once at registration; only admins may change another user's role
- [x] always render the persisted account role on profiles and Chat; show `Admin` or `Moderátor` as a separate access badge next to the account role

 - [x] tag-filtered news uses API pagination/infinite scroll so all matching articles can be reached
 - [x] allow gallery images to be saved to the device with platform permission handling
 - [x] add an in-app Data protection / GDPR information section with privacy and retention details
 - [x] keep sensitive account, role, deletion and WordPress proxy operations server-side
 - [x] complete the v0.99.999 security hardening pass: R8/resource shrinking, Dart obfuscation, release signing, HTTPS-only Android networking, backup disablement, and verified existing backend rate limits
 - [x] complete the Real Hardstyle FM radio integration at `https://stream.realhardstyle.nl` in v0.99.2.1 with a custom compact red-black bar player and Play/Stop/Mute controls
 - [x] show the currently playing track title in the radio player when stream metadata provides it
 - [x] place the persistent radio player above the bottom navigation without covering event panels
 - [x] add a More-section radio provider page with Real Hardstyle FM name, website, logo, and provider attribution text
 - [x] adopt a readable modern/cyber-style font such as Rajdhani with complete Hungarian accented-character support (native condensed fallback)

### v0.99.3 implementation status — complete and closed (2026-07-30)

Implemented in source: the approved Rajdhani/TypeUI red-black visual system while retaining the original `assets/logos/huhs_logo.png` HUHS logo, Home slogan and branding; the Admin-only native HUHS Vezérlőközpont; Mobile API events, DJs, organizers, submissions, trash, settings, push, newsletter, shortcode, About and persistent startup-image management; the separate Firebase community-user administration; profile image/monogram fallback; radio Stop synchronization; tag/genre pagination, the fast-scroll fix and expired-event filtering. Generic WordPress news/page/media/comment/taxonomy/user menus are intentionally not duplicated in the mobile controller.

The Home header does not duplicate the bottom navigation with extra quick-action tiles. The radio uses the compact TypeUI red-black two-line bar with a dedicated Play/Stop control, station label, track metadata and Mute control.

v0.99.3 completion:

- [x] Fix the visible Hungarian character-encoding/mojibake errors on the community profile screen.
- [x] Remove the unnecessary `Beállítások`, `Hírlevél`, and `Shortcode` entries from the native HUHS Vezérlőközpont.
- [x] Make the circular profile-image editor persist and reproduce true horizontal and vertical positioning together with zoom.
- [x] Open the community profile in a read-only view and place editing behind a separate `Profil szerkesztése` action and screen.
- [x] Refresh the Real Hardstyle FM current-track metadata automatically while the radio is playing.
- [x] Reconnect the Real Hardstyle FM player automatically after an unexpected stream interruption.
- [x] Fix the push-settings screen lifecycle assertion (`_dependents.isEmpty`) without changing the already working push delivery.

The native admin refresh after saving the persistent startup image uses a synchronous `setState` callback, so a successful save is no longer reported as a Flutter error.
The same admin dialog can also disable and clear the configured startup image.

The Chat composer keeps the camera action, emoji helper, and signed-in status on one compact line above the Send button so none overlaps the message field.
Existing Chat messages resolve their author's current profile image, crop and zoom settings, so an avatar change updates earlier messages too.

Firebase WordPress proxy Functions are deployed. WordPress Mobile API `2.4.33` is live, deployed, and verified; it adds the managed FAQ post type/category editor and paginated public FAQ endpoint on top of the native admin/startup-image work. Do not treat this deployment as an open re-verification task.

v0.99.3 is complete, phone-verified, and closed in Flutter build `0.99.3+27`. Release signing/obfuscation and broader security remain v1.0.

### v0.99.4 — Small improvements (implemented)

Implemented in Flutter `0.99.4+3`:

- organize the existing `Több` entries without changing the menu name:
  - `Felfedezés`: DJ-k, Szervezők, Spotify Playlistek
  - `Közösség`: Kedvencek, Hírlevél; the v1.0 registered-user search will also belong here
  - `Beküldés`: role-gated event, DJ and organizer submissions
  - `Kapcsolat és támogatás`: Social és kapcsolat, Támogatás / Donate, Hibajelzés, GYIK / FAQ
  - `Alkalmazás`: Beállítások, Adatvédelem és GDPR, Az appról, Rádió szolgáltató
  - keep the HUHS Vezérlőközpont in the Admin profile; do not duplicate it in `Több`
- [x] add the `Támogatás / Donate` card with PayPal app/browser fallback
- [x] add a pre-addressed feedback e-mail action that includes the app version
- [x] add the WordPress-managed FAQ under More with categories, ordering, search, expandable answers, and loading/empty/error states (prepared API package 2.4.33)
- [x] persist favorites in the signed-in user's Firestore profile (with local cache and bulk deletion)
- [x] replace full social-media URLs on community profiles with compact, clickable Facebook, Instagram, TikTok, YouTube, and Spotify buttons
- [x] move the existing Home AdMob banner below both the latest-news and upcoming-events sections
- [x] add one clearly separated inline adaptive test AdMob banner to the native news list
- [x] fix Instagram post embeds in news so `instagram://` URLs are converted to supported web links before opening
- [x] compact the Home event cards while keeping every card the same height and preserving title, date/time, city, genres, favorite, and open actions
- [x] show a clear registered-user/role requirement in the `Beküldés` section when no submission action is available
- [x] update the in-app GDPR text for the current Firebase, Cloudinary, WordPress, Mailchimp, and test-AdMob functions
- [x] add a second separated adaptive test AdMob placement after the first five news cards

The WordPress API `2.4.33` FAQ endpoint is available in production and is populated with the initial 10 Hungarian FAQ entries. Production AdMob identifiers and the rewarded SSV callback are configured for the Android release path.

### v0.99.5 — complete

Implemented in Flutter `0.99.5+1`:

- [x] password reset, visibility toggle, clear Hungarian authentication errors, and strong-password suggestion
- [x] clickable social buttons plus avatar refresh, crop, zoom, and positioning persistence
- [x] Chat profanity masking and automatic message/avatar refresh
- [x] native admin panel scope and readable content with concise save/cancel errors
- [x] final loading/card/control polish and test-AdMob placement

Phone-verified by the project owner; all listed v0.99.5 items are marked complete. ARM64 test APK: `build/HUHS-v0.99.5+1-arm64-debug.apk`.

### v0.99.6 — complete

- [x] allow gallery images to be saved to the device, including the pre-Android 10 permission fallback
- [x] make widget tests Firebase-safe and restore a green test run
- [x] update Gradle, Android Gradle Plugin and Kotlin compatibility
- [x] finalize the full HUHS-logo startup animation
- [x] polish profile and Chat avatar refresh/cache behavior
- [x] complete a Hungarian text and character-encoding audit
- [x] resolve remaining accessibility and layout-overflow issues
- [x] complete AdMob test-placement and display verification
- [x] produce and verify the final ARM64 debug test APK for this build

Analyzer and the complete Flutter test suite pass. The final ARM64-only debug artifact is `build/HUHS-v0.99.6+1-arm64-debug.apk` (package `0.99.6`, ARM64 ABI). Graphify was refreshed after the final source and documentation changes.

The v0.99.999 hardening pass is complete; paid music sales will later extend the completed v0.99.89 Label catalog in v1.0+.

### v0.99.8 closure (2026-08-06)

v0.99.8 is complete and closed. The final ARM64 debug test APK is `build/HUHS-v0.99.8+16-arm64-debug.apk`. Completed scope: friend requests and push delivery, push-to-requester profile navigation, accept/reject/unfriend flows, live role/access badges in Chat, public profiles and friends, favorite DJs/organizers on profiles (favorite news excluded), planned events and attendance, registered Chat writes, native Chat author profiles, report management, biometric session handling, and admin role/access management. Firebase rules and the connection-request FCM trigger are deployed. `flutter analyze`, the full Flutter test suite, Cloud Function syntax checks and Graphify refresh pass. v1.0 remains for security hardening, obfuscation, release signing, purchase/store work and final release preparation.

### v0.99.89 — Label release catalog (complete and closed, 2026-08-06)

The Label tab is live between Chat and Több. It reads WordPress-managed release records with title, clickable multiple artists, cover, genre, 60-second preview playback and Spotify, Apple Music, Beatport, Hardstyle.com and YouTube links. The uploaded MP3/WAV is only a temporary source: FFmpeg creates a preview from the 30th second, then the source is deleted. No full-track download, cart or purchase flow is included. ARM64 debug APK: `build/HUHS-v0.99.89+1-arm64-debug.apk`. The later paid music store will be implemented inside this Label catalog.

### v0.99.90 — HUHS Vezérlőközpont bugfixek (lezárva, 2026-08-07)

A korábbi build-ek továbbra is lezártak; ezek újonnan felfedezett hibák a következő buildhez:

- [x] Events, DJ-k, Szervezők és kapcsolódó beküldési szerkesztőkben a `Mégse` nem küld hibás piros hibaüzenetet, és nem hagy hibás űrlapállapotot.
- [x] A natív Mobil API-szerkesztő mezői tagoltabbak, a mezők között következetes térközzel.
- [x] A DJ-k kiválasztása név alapján történik; az eseményszerkesztő nem csak azonosítókat mutat.
- [x] A nem kért „Személyre szabott push” vezérlőfelület kikerült; az általános és az egyedi push megmaradt.
- [x] A vezérlőközpont életciklus- és párbeszédablak-kezelése védett a `_dependents.isEmpty` assertion ellen.
- [x] Elvégezve a célzott UX-, accessibility- és layout-polish: térközök, feliratok, vezérlők, loading/error állapotok és visszafogott működés ellenőrzése.

Telefonon ellenőrizve, a v0.99.90 lezárható. ARM64 debug APK: `build/HUHS-v0.99.90+3-arm64-debug.apk`. A HUHS Mobile API frissített csomagja `build/huhs-mobile-api-2.4.37.zip`.

### v0.99.7 — Community follow-up (complete)

- [x] allow verified-email users to claim a DJ profile after matching the private or artist-owned booking e-mail; the Hungarian Hardstyle-managed booking address never qualifies as proof
- [x] add registered-user search/listing under `Több`; the list filters from the first typed character
- [x] add admin-triggered personalized event and organizer notifications for favorited records
- [x] add community moderation follow-up with reporting, blocking, blocked-post filtering, and admin report visibility

Firebase rules and the `claimArtistProfile`/`sendPersonalizedPush` Cloud Functions are deployed. Flutter analyzer, tests, and Cloud Function syntax checks pass.
The final ARM64 debug test APK is `build/HUHS-v0.99.7+3-arm64-debug.apk`.

### v0.99.7+3 — Claim display follow-up (complete)

- [x] After a DJ profile is claimed, show one `Saját DJ-adatlap megnyitása` button on the user's profile; it opens the native in-app DJ detail screen through the deployed `getMyClaimedArtists` callable.

The v0.99.999 hardening pass is complete. The Label release catalog itself is already closed in v0.99.89; paid store work remains v1.0+.

### v0.99.8 — User profile navigation and community details (closed)

Status is authoritative: the voting fix is packaged as WordPress Mobile API `2.4.39`; the v0.99.99+2 ARM64 debug build is the current phone-test artifact. Earlier completed work is not reopened here.

- [x] Make each profile card in `Több → Felhasználók` tappable and open that user's native in-app profile.
- [x] On a user profile, show the user's favorite DJs, organizers, and events; favorite news does not appear in this profile section.
- [ ] Stabilize planned-event display and attendance states (`Ott leszek` / `Nem leszek ott`), persistence, participant counts and friend visibility.
- [ ] Stabilize friend requests, accept/reject, persistence and list consistency; remove false success/error states.
- [x] Keep separate Facebook, Instagram, TikTok, YouTube, and Spotify profile links (already implemented).
- [x] Show planned events and favorites on the user profile.
- [ ] Fix biometric enablement, false unlock errors, and session behaviour (once per open app, again after a full close).
- [ ] Complete registered/guest public-profile visibility, clickable friend lists, blocked-user list and report-status visibility.
- [x] Restrict Chat message editing and deletion to admins; normal users cannot edit or delete their own messages.

### v0.99.8 open fixes (including the former +3 follow-up)

- [ ] Show the requester's display name/avatar instead of a UID and retain friend connections consistently.
- [ ] Send connection-request push notifications reliably and remove false-success/false-failure errors.
- [x] Make profile favorites and planned events open their native detail screens.
- [ ] Complete admin report management: reporter, reported user, reason, message details, resolve/close (removed from the active list), delete-message and block-user actions; remove duplicate report UI and mojibake.
- [ ] Provide unfriend/remove actions and context-sensitive friend controls on public profiles; own profiles must not show self-actions.
- [ ] Let registered non-admin users write Chat messages and make Chat author name/avatar open the native profile.
- [ ] Fix admin account-role changes.

#### FAQ-választervezet

- **Hogyan regisztrálhatok?** A Több → Profil oldalon e-mail-címmel vagy Google-fiókkal regisztrálhatsz. Regisztrációkor kötelező szerepkört választani: bulizó, DJ vagy szervező.
- **Módosíthatom később a szerepkörömet?** Nem. A szerepkör a regisztráció után végleges; módosítani csak adminisztrátor tud.
- **Hogyan küldhetek be tartalmat?** A beküldés regisztrációhoz és a megfelelő szerepkörhöz kötött. A beküldés szerkesztői jóváhagyás után jelenik meg.
- **Hogyan működnek a kedvencek?** A hírek, események és DJ-k adatlapján a szív ikon menti vagy törli a kedvencet. A mentett elemek a Kedvencek menüben kezelhetők.
- **Hogyan működnek a push értesítések?** A beállításokban kapcsolhatók. Értesítés érkezhet új hír, új esemény és esemény-emlékeztető miatt.
- **Hogyan használhatom a rádiót?** A Real Hardstyle FM lejátszója a főképernyő alján található. A Play/Stop és némítás gombbal vezérelhető; a szám címe akkor látható, ha a stream metaadata elérhető.
- **Hogyan iratkozhatok fel a hírlevélre?** A Több → Hírlevél menüben add meg az e-mail-címed, majd erősítsd meg a feliratkozást a kapott e-mailben.
- **Hogyan törölhetem a profilomat?** A saját profil oldalon válaszd a Profil törlése lehetőséget, majd erősítsd meg a műveletet.
- **Hogyan kezeljük az adataimat?** A Firebase a közösségi fiókot és Chat-adatokat, a Cloudinary a feltöltött képeket, a WordPress a tartalmakat, a Mailchimp a hírlevél-feliratkozást kezeli. Részletek az Adatvédelem és GDPR menüben.
- **Hogyan jelezhetek hibát vagy támogathatom a projektet?** A Több → Hibajelzés előre címzett e-mailt nyit meg az app verziójával. Támogatáshoz használd a Támogatás / Donate menüpontot.

Backend **2.4.7** is deployed and awaiting live approval-flow testing. It fixes DJ/organizer approval redirects and adds one-click event draft creation from pending submissions; generated drafts remain non-visible until reviewed and published manually.

Backend **2.4.8** is deployed. It adds a separate optional DJ-logo upload, an editable DJ website field across WordPress, REST API, public profiles, and Flutter, and complete event details when an event is opened from a DJ or organizer profile. The profile-event navigation fix is live-verified.

Cloudinary is the only active image-upload path. The dedicated Facebook Event URL field is deployed in backend 2.4.3; the app submission field remains a general event link.

Implemented:

- dark Material 3 Flutter UI with Riverpod and Dio
- API-backed news list, search and detail views
- rich news content, galleries, embeds and in-app link handling
- dynamic events with flyers, tickets, Maps and related profiles
- searchable DJ and organizer directories with full profile pages
- related upcoming events on DJ and organizer profiles
- moderated event, DJ and organizer submissions
- Cloudinary-backed image submissions for event flyers, DJ profile images and organizer logos
- WordPress admin approval into non-public draft profiles
- local favorites for news, events, DJs and organizers
- native Mailchimp newsletter signup
- Firebase/FCM push notifications for news and events, including foreground display

## Roadmap

### Current bug-fix backlog

- [x] make AdMob initialization failure-safe and platform-aware so it can never block app startup
- [x] add the iOS AdMob test application identifier; replace it with the production App ID before release
- [x] remove the remaining event-card overflow at 2.0x accessibility text scaling and add a small-screen regression test
- [x] prevent the favorites startup load from overwriting a newly saved favorite
- [x] make saved news, events and DJs openable from the Favorites screen
- [x] dispose late AdMob banner callbacks safely; consent/privacy handling remains required before production ads
- [x] replace the three deprecated `withOpacity()` calls
- [x] restore artist/DJ logo rendering on both the Flutter app and public WordPress pages
- [x] make newly published or edited DJ profiles refresh reliably in the app without forced refresh
- [ ] upgrade Gradle, Android Gradle Plugin and Kotlin before current Flutter support is dropped

### v0.4 — Foundation

- [x] Flutter application structure and dark brand UI
- [x] WordPress REST API foundation
- [x] API-backed news, search and detail screens
- [x] pull-to-refresh and basic loading/error handling
- [x] update the default widget test for `HungarianHardstyleApp`
- [ ] finish asset cleanup and launcher icon setup
- [ ] set the final Android application ID and release signing

### v0.5 — Dynamic events

- [x] API-backed event list and detail screen
- [x] flyer, ticket and Google Maps actions
- [x] clickable DJ and organizer relationships
- [x] public event submission form with server-managed genres
- [x] gallery/camera flyer upload
- [ ] complete an intentional live submission and approval test
- [ ] finish the public WordPress event detail experience

### v0.6 — DJ database

- [x] searchable DJ list
- [x] Hardstyle and Hardcore category filters
- [x] API-backed DJ profiles
- [x] profile image, biography, genres, location and social links
- [x] TikTok and upcoming events
- [x] moderated DJ submission with optional profile image
- [x] Hungarian Hardstyle-managed booking option
- [x] standardize every DJ list image to one card frame and aspect ratio with upper-center face-focused cover cropping
- [ ] complete an intentional live image submission and approval test

### v0.7 — Organizers

- [x] searchable organizer list
- [x] API-backed organizer profiles
- [x] logo, description, location, website and social links
- [x] related upcoming events
- [x] moderated organizer submission
- [x] gallery/camera logo upload in backend 2.4.2
- [x] standardize every organizer list image to the same fixed card frame; logos retain contain rendering inside the frame
- [ ] live-verify organizer logo upload and draft-profile approval
- [x] add optional multi-select music genres/styles (backend 2.4.9 prepared)

### v0.8 — Rich content

- [x] YouTube, Spotify, SoundCloud, Instagram and TikTok embeds
- [x] WordPress galleries and supported shortcode detection
- [x] shared in-app browser for normal content links
- [x] automatic linkification of plain-text web URLs
- [ ] add a private AI-assisted WordPress article importer
- [ ] enforce draft-only import, attribution, safe URL fetching and media rights checks

### v0.9 — Community utilities (implemented)

- [x] local favorites for news, events, DJs and organizers
- [x] allow the featured news card on Home to be marked as a favorite
- [x] show the opened news title in the app-bar instead of the generic `HĂ­r` label
- [x] show the opened event title in the app-bar instead of a generic event label
- [x] Mailchimp newsletter signup via hosted landing page
- [x] native Mailchimp newsletter signup screen with a WordPress server-side proxy (backend 2.4.15 live; personal e-mail double-opt-in test successful)
- [x] organizer favorites in profile screens and the local favorites list
- [x] notification and cache settings
- [x] social, contact and About sections
- [x] show runtime app version and build number from package metadata
- [x] prepare local push notification preferences
- [x] integrate the Firebase/FCM client and store the device token locally
- [x] open related WordPress articles (including "Kapcsolódó cikk", "Kapcsolódó", and "Ez is érdekelhet" links) in the native app news screen; backend 2.4.12 is live and the detail endpoint was verified with a real related article
- [x] rename the artist website label to `Website`
- [x] rename the artist booking action to `Booking` or `Fellépés lekötése`
- [x] add organizer genre/style selection in WordPress, API, and submission flow (backend 2.4.9 prepared)
- [x] configure and live-test WordPress-created custom push delivery; news and event publishing pushes plus foreground display are live-verified
- [x] implement one-week and event-day reminder scheduling in the backend
- [x] monitor the first natural one-week and event-day reminder occurrences; event-day delivery is live-verified

Push setup: in Firebase Console open Project settings → Service accounts → Generate new private key, then upload the downloaded JSON under WordPress `HUHS Mobile → Push értesítések`. The JSON stays on the server; never commit or embed it in Flutter.

Push verification after uploading the WordPress package:

- choose a published news item or event by title in the custom-push form and send it; the app should open the native detail screen;
- paste a HUHS news/event URL as an individual link; the server resolves it to the native detail screen, while unrelated external URLs open in the in-app browser;
- [x] publish a new news item and a new visible event, then verify the automatic notifications;
- [x] create a future event and monitor the one-week and event-day reminder jobs at their first natural occurrences.

### v0.95 — Media

- [x] Spotify playlist section with five curated Hungarian Hardstyle playlists (Spotify app first, browser fallback)
- [x] compress submission images on-device before upload (target: up to 1600 px, quality 82; native picker output)

### v0.97 — Polish build

Small, low-risk finishing work that can be released independently before the larger v1.0 modules:

- [x] show uploaded/approved DJ logos in the Flutter DJ list and profile with a consistent fallback order
- [x] standardize DJ and organizer list thumbnails with a fixed frame, cover crop and upper-center face focus
- [x] include `Happy Hardcore` in the shared DJ, event and organizer genre options
- [x] keep DJ names readable in the two-column cards; keep them on one line and scale long names down instead of truncating them
- [x] rename the event ticket action in the app to `Jegyvásárlás`
- [x] use the Google Maps app when installed, otherwise the external browser fallback
- [x] verify the one-week, one-day and six-hour reminders
- [x] validate event postal codes as numeric-only in both Flutter and WordPress/API submission flows
- [x] keep new-event publication pushes global to FCM-token devices; personalized recipient rules remain a v1.0 task

### v0.99 — Submission polish

- [x] make event submission date, venue name, city and address required in Flutter and WordPress validation
- [x] add the required event address field below the venue name
- [x] add event end date and end time fields, validating that the end is not before the start
- [x] load the organizer list from WordPress and provide an organizer dropdown in the app and WordPress editor
- [x] require at least one genre and show inline error messages and red invalid-field styling for every missing required value
- [x] use direct Cloudinary uploads (`fjxo93em` / unsigned `Hun_hs_Mobile`) and pass returned image URLs to WordPress for DJ, organizer and event submissions
- [x] prepare WordPress Mobile API 2.4.28 for Cloudinary image URLs, the new event fields, numeric postal-code validation, automatic address-based Maps links and published post tag names; approval also migrates legacy image URL meta keys and the WordPress admin shows Cloudinary image previews

### v0.99 — Completed polish items

- [x] add a WordPress Mobile API trash/recycle-bin menu for deleted submissions and managed content, with restore and permanent-empty actions protected by capability and nonce checks
- [x] add a WordPress Mobile API `About` menu showing the developer/maintainer information and the current API version
- [x] refresh DJ/organizer list data after navigation instead of retaining stale family-provider cache
- [x] make event, DJ and organizer genre chips open grouped Események/DJ-k/Hírek discovery results
- [x] render the DJ logo on public WordPress artist profiles as well as in the app

### v0.99.1 — Community MVP (implemented; external setup remains)

- [x] app-only registration and sign-in code (e-mail/password and Google)
- [x] mandatory account role during registration: DJ, organizer or partygoer
- [x] profile from the top-left Home avatar, with profile image or monogram fallback
- [x] profile name, bio, social links, favorites and planned-events placeholder
- [x] Chat visible without registration
- [x] anonymous text posting with generated `Unknown User ####` display names
- [x] registered users can post text and compressed snapshots in Chat
- [x] anonymous users cannot upload images
- [x] support Unicode emoji in messages and a small fixed reaction set (for example ❤️ 🔥 🙌)
- [x] use Firebase Authentication/Firestore for community data and Cloudinary for images; keep WordPress as the editorial source of truth
- [x] apply basic size, permission and ownership checks before adding full moderation/friend features in v1.0
- [x] remove the Chat composer overflow at narrow widths
- [x] native article tags: hydrate tag names from WordPress core REST when the HUHS endpoint only returns tag IDs
- [x] deploy `firestore.rules` to the `hungarian-hardstyle` Firebase project
- [x] enable Google provider and add Android SHA-1/SHA-256 credentials; release-device verification is complete

### v1.0 — First public release

Core release quality:

- [x] refresh the WordPress-managed FAQ with the new v0.99.999/v1.0 features and current user guidance (live-verified)
- [x] reorganize `Több` into `Felfedezés`, `Közösség`, `Beküldés`, `Kapcsolat és támogatás`, and `Alkalmazás`; keep Label only in its dedicated tab
- [x] add a `Több`-menu search and collapsible category sections, with Admin functions in a separate admin-only block
- [x] complete final UX polish covering consistent card sizes, spacing, icons, loading/empty/error states, tap targets, back behavior, tab history, and accessibility scaling (v0.99.90)
- [x] configure production release signing and obfuscated ARM64 release packaging with production AdMob configuration
- [x] stabilize news, events, DJs and organizers for public release
- [x] make genre chips clickable and add a genre discovery screen with separate `Események`, `DJ-k` and `Hírek` result sections, using paginated infinite scroll for DJ/news matches
- [x] make artist/DJ profile genre tags open the same grouped `Események`, `DJ-k` and `Hírek` discovery view with the complete paginated result set
- [x] complete the Label release catalog in v0.99.89, including preview playback, WordPress release records, multi-artist links, cover art and external release links
- [x] extend the existing Label tab with paid products; no separate store/catalog is planned (client/API, WordPress, Firebase and live Play products verified)
- [x] add a purposeful Hungarian Hardstyle-branded loading animation without artificial startup delay, with reduced-motion support
- [x] refine the Android startup animation to use the full HUHS logo on a transparent/no-white background (complete)
- [x] introduce a persistent navigation shell with per-tab history
- [x] add the Chat tab to the persistent bottom-navigation shell
- [ ] perform the final owner phone verification and publish the Android release; iOS preparation is deferred until an Apple Developer account is available

Authentication and community:

- deferred: Apple account sign-in remains outside the Android v1.0 scope until an Apple Developer Program membership is available
- [x] Google sign-in and app-only community accounts
- [x] let users choose an account role during onboarding: DJ, organizer, or attendee/partygoer
- [x] show DJ submission only to DJ accounts, organizer submission only to organizer accounts, and both to admins; enforce the same rules server-side
- [x] bootstrap a separate app-admin account and role with full submission approval and editing permissions
- [x] top-left Home avatar profile entry with profile image or monogram fallback
- moved to v0.99.8: user profiles with social links, planned events, and favorites
- moved to v0.99.7: add a `Több`-menu user directory/search listing registered users only
- moved to v0.99.7: allow DJ profile claiming after verified private/artist-owned booking e-mail; the Hungarian Hardstyle-managed booking address must never qualify as proof of ownership
- moved to v0.99.8: friend requests and an `Ismerősök` profile section
- [x] complete Live Feed chat/image-post moderation and community features (complete)
- moved to v0.99.8: event attendance: `Ott leszek` / `Nem leszek ott`
- moved to v0.99.8: show which friends are attending on event details
- moved to v0.99.8: friend attendance visibility
- moved to v0.99.7: personalized event pushes for favorites/attendance
- [x] send publication and reminder pushes for featured events to every app-installed device with an FCM token, regardless of account registration (respect explicit notification opt-out)
- moved to v0.99.7: favorited-organizer event notifications
- [ ] optionally send a separate admin/editor push when a new event submission is received
- [x] complete moderation/reporting/blocking follow-up, privacy information and self-service account deletion

App administration:

- [x] keep WordPress as the editorial source of truth and enforce admin permissions server-side

News, events, DJs and organizers should remain readable without registration. Event, DJ and organizer submission forms remain public until authentication launches. After that, only signed-in users may see and use them, and the backend must reject unauthenticated submissions.

Radio delivery is now part of v0.99.2.1 through the Real Hardstyle FM stream and its in-app player.

### v0.99.99 — Annual HUHS voting (complete; phone verified)

- [x] WordPress-managed voting seasons and candidates
- [x] best Hungarian hardstyle DJ
- [x] best Hungarian hardcore DJ
- [x] best Hungarian hardstyle track
- [x] best Hungarian organizer
- [x] best international DJ
- [x] authenticated one-user/one-vote enforcement
- [x] private admin dashboard and explicitly published public results
- [x] add a prominent Home button for the active voting season, controlled by an admin on/off setting and hidden when voting is inactive
- [x] require a registered, signed-in app account before voting
- [x] ask separately whether the voter wants the HUHS newsletter; only explicit consent may trigger the existing Mailchimp subscription flow

Implemented in source: one WordPress season editor with category-level `+ Jelölt hozzáadása` fields, unlimited candidates per category, DJ and organizer candidates without Spotify/YouTube fields, and optional Spotify/YouTube support for the Hungarian hardstyle track category. Each category accepts up to 5 / 3 / 2 / 1 / 3 selected candidates respectively. The Home button appears when a published, enabled season is within its configured time window. The private admin summary is served by the deployed Firebase API function `getVotingSummary`; the unnecessary results-publication checkbox was removed. Registered-user voting, Firestore duplicate protection, separate Mailchimp consent, and the private admin summary remain in place. Final phone testing passed in `build/HUHS-v0.99.99+6-arm64-debug.apk`; the test votes were cleared from Firebase after verification. WordPress package: `build/huhs-mobile-api-2.4.42.zip`.

### v1.0 — Hardstyle Revolution paid Label extension

The Label preview catalog is already complete in v0.99.89; this section covers only the later paid extension.

### v0.99.999 — Android security and public QA (complete; phone verified)

- [x] Android release signing with a local, git-ignored release keystore
- [x] R8 code shrinking and resource shrinking
- [x] Dart obfuscation with split debug symbols
- [x] disable Android backup and cleartext traffic
- [x] verify existing Firebase/WordPress rate limiting and server-side authorization
- [x] run `flutter test` successfully (27 tests)
- [x] build and verify a signed ARM64 release APK

Artifact: `build/HUHS-v0.99.999+1-arm64-release.apk`. The hardening and QA scope is complete. The final v1.0 production artifacts are `build/HUHS-v1.0.0+9-arm64-release.apk` and `build/HUHS-v1.0.0+9-arm64-release.aab`; they use production AdMob IDs and include the BILLING permission. Final owner phone verification of the production artifact is still required before public rollout; iOS is deferred until an Apple Developer account is available.

- [x] let each existing WordPress Label release accept one uploaded WAV master, generate its preview, and offer configurable Radio and Extended versions (live API 2.4.46 verified)
- [x] let the editor set separate prices for the WAV/lossless and 320 kbps MP3 products (live WordPress fields and Play pricing verified)
- [x] use the requested first-release prices: WAV `700 HUF`, 320 kbps MP3 `550 HUF` for both Radio and Extended versions
- [x] sell the WAV/lossless and 320 kbps MP3 products through Google Play Billing (all four Play products active in Hungary; live verification Function and WordPress download path deployed)
- [x] generate a 128 kbps MP3 derivative that is unlocked after a rewarded advertisement (production AdMob SSV callback validated and saved)
- [x] process all derivatives in a background job and keep the WAV master private (live release 12123 audio status is `ready`)
- [x] verify Websupport FFmpeg support (`/usr/bin/ffmpeg` 4.4.2 with `libmp3lame`) and the live derivative path
- [ ] optional purchase and download history

The rewarded-ad revenue target is approximately 300 HUF per 128 kbps unlock, but actual revenue depends on AdMob eCPM, geography, fill rate and user demand; it cannot be guaranteed per impression.

Releases and Store use one WordPress-managed catalog rather than separate content systems.

## Navigation direction

- Home and News remain the first two primary destinations.
- The unused Tickets tab will be removed; its future primary-tab slot is now the Chat destination.
- The public WordPress `/events/` directory should later include an `Esemény beküldése` call-to-action, gated by authentication once registration is available.
- Events are a strong primary-tab candidate because they provide immediate utility.
- DJs and organizers may initially remain under More.
- The app now exposes the community destination as a dedicated Chat tab.
- Detail screens should open inside one persistent navigation shell instead of duplicating the bottom bar.

## Language direction

- The mobile REST APIs for news, events, DJs and organizers should serve the stored language requested by Flutter, with Hungarian fallback, rather than translating content on demand.

## Brands

- **Hungarian Hardstyle** — main community platform
- **Hardstyle Revolution** — record label and event series
- **Rave Revolution** — multi-genre hard dance event series
- **Hard Lake** — free summer event concept around Lake Velence

## Long-term vision

One connected platform for Android, iOS and the web, combining news, events, artists, organizers, community, radio, releases and digital music distribution.
- v0.99.8+2 bugfix pass: attendance writes now include the validated event ID; attendance UI reports save failures; connection-request state refreshes after sending; the named-database connection-request push trigger is deployed; biometric enablement requires real device support; Android uses a FragmentActivity host for local_auth.
FAQ v1.0 kiegészítések: a Label oldalon csak legfeljebb 60 másodperces preview hallgatható meg, a teljes master nem nyilvános; a későbbi WAV/lossless és 320 kbps MP3 hozzáférés ellenőrzött Google Play-vásárláshoz kötött, a 128 kbps változat pedig jutalmazott reklám után oldható fel. Az Apple-belépés Apple Developer-tagság hiányában nincs bekapcsolva, és kimarad a jelenlegi Android v1.0 kiadásból.

#### Android/Label release beállítások

- A Google Play termékazonosítókat release-enként a WordPress Label-adatlapján kell megadni (`wav_product_id`, `mp3_product_id`); az alkalmazás ezeket csak a nyilvános release API-ból olvassa.
- Az API `2.4.48` külön Radio és Extended forrásból készít preview-t, WAV-ot és MP3 320-at privát fájlban, a Radio forrásból pedig reklámos MP3 128-at; egyszer használatos letöltési tokent használ, a letöltött fájlokat a release címe és változata alapján nevezi el, és a natív Release-ek adminban kezeli a négy Play product ID/ár mezőt. A védett Play-termékfrissítési útvonal élesben tesztelt.
- A vásárlást a `verifyLabelPurchase` Firebase Function ellenőrzi a Google Play Developer API-val. Deploy előtt a Firebase Secret Managerben be kell állítani a `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` secretet; a JSON-kulcs nem kerülhet a repóba vagy az APK-ba.
- Production buildnél a `HUHS_ADMOB_APP_ID` Gradle property és a `HUHS_ADMOB_BANNER_ID` dart-define szükséges. Teszt buildnél maradhat a Google tesztazonosító.

#### v1.0 aktuális élesítési akadályok

- v1.0.0+5 bugfix: a production AdMob App/Banner/Rewarded azonosítók most a Flutter Dart-kódba és az Android manifestbe is bekerülnek. A +4-ben a Gradle azonosítók megvoltak, de a Flutter rewarded ID üres maradt, ezért a gomb azonnal sikertelen állapotot adott. A production ARM64 APK: `build/HUHS-v1.0.0+5-arm64-release.apk`.
- v1.0.0+9 bugfix: a már reklámmal feloldott 128 kbps fájlnál a letiltott `Feloldva` gomb helyett aktív `Letöltés` gomb jelenik meg. A feloldás release-enként végleges, ezért újabb reklám nem indul. Ellenőrzött ARM64 release APK: `build/HUHS-v1.0.0+9-arm64-release.apk` (`versionCode 2009`).
- A +9 production APK és AAB újra lett építve a production AdMob-azonosítókkal; a pontos +9 ARM64 APK aláírása ellenőrzött. A valódi Google Play Billing- és jutalmazott reklámtranzakció Playből telepített APK-val és valós tesztfiókkal ellenőrizendő.

- A WordPress API `2.4.45` jelenleg telepítve és live-ellenőrizve van; a `/releases` válasz külön Radio/Extended verziókat és `audio_status: ready` állapotot ad. A natív Release-ek adminmezőkkel bővített telepíthető csomag: `build/huhs-mobile-api-2.4.46.zip`.
- A WordPress API `2.4.46` telepítve és live-ellenőrizve van; a `/releases` válasz külön Radio/Extended verziókat, `audio_status: ready` állapotot és a négy termékmezőt adja. A natív Release-ek adminmezőkkel bővített csomag: `build/huhs-mobile-api-2.4.46.zip`.
- A WordPress API `2.4.48` telepítve és live-ellenőrizve van: `build/huhs-mobile-api-2.4.48.zip`. A reklámos és megvásárolt fájlok letöltési nevét a release címéből, valamint a Radio/Extended és formátum jelölésből képezi.
- A `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` Firebase Secret Manager-secret engedélyezve van; a Play szolgáltatásfiók aktív alkalmazásszintű pénzügyi hozzáféréssel rendelkezik. A `verifyLabelPurchase`, `getLabelDownloadUrl` és `admobRewardedSsv` Functionök élesek.
- A 12123-as és 12185-ös release mind a négy Play Billing-terméket tartalmazza; ezek aktívak Magyarországon a kért 700/550 HUF alapárakkal.
- A produkciós AdMob App ID, Banner és Rewarded egység létrejött; a jutalmazott egység SSV callbackje ellenőrzött és mentett.
- Az 1.0 egyetlen fennmaradó gate-je a projekt tulajdonosának végső telefonos ellenőrzése a produkciós APK-n; ezt a Codex nem tudja helyettesíteni.
- A Play Console alkalmazás létrejött a végleges `hu.hungarianhardstyle.app` Android csomagnévvel; a Firebase Android-app és a release SHA-k ehhez vannak konfigurálva.
- A 128 kbps feloldás AdMob SSV callbacket használ; az AdMob jutalmazott hirdetésén be kell állítani az `admobRewardedSsv` HTTPS callback URL-t, és a callback csak hitelesített aláírás után írhat feloldást.

#### Következő Android-frissítés nyitott feladatai

- [ ] Emailes regisztráció hitelesítésének teljes auditja: Firebase Auth levélkézbesítés, template-ek, logok és korlátok; az appban a hitelesített állapot frissítése és látható megerősítőlevél-újraküldés. A nem hitelesített fiók ne kapjon teljes hozzáférést.

v1.0.0+13 előkészítve: az FCM-token Play-telepítés utáni újraregisztrációja és a régi tokenek takarítása bekerült, a `notifyConnectionRequest` Cloud Function élesben frissült, az AdMob hibák rövid felhasználói üzenetet adnak, valamint az e-mailes regisztráció megerősítő levelet küld és erre figyelmeztet. A production ARM64 release APK és AAB elkészült; a Play-feltöltés és a tulajdonosi telefonos ellenőrzés még külön lépés.

- [ ] Kivizsgálni és javítani, hogy a production AdMob banner/jutalmazott hirdetés Playből telepített verzióban is megbízhatóan betöltődjön és a jutalom jóváírása megtörténjen.
- [ ] E-mail-cím megerősítése a jelszavas regisztráció részeként; a nem megerősített fiók ne kapjon teljes hozzáférést.
- [x] Opcionális Google Authenticator MFA, Android PIN/jelkódos profilvédelem, külön kapcsolók és munkamenetenkénti azonosítás elkészült. Google-belépéshez nem kell authenticator.
- A fenti három külső feltétel és az új release APK telefonos ellenőrzése nélkül az 1.0 nem tekinthető késznek.
