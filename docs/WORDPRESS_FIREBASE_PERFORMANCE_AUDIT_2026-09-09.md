# HUHS WordPress/Firebase teljesítményaudit — 2026-09-09

## 1. Feltárt teljesítményproblémák

Az alkalmazásban a WordPress-kérések egy része korábban ismétlődött navigációkor és egyidejű betöltéskor; a kliensben ezekre singleton Dio, tartós publikus cache, HEAD/ETag validálás és in-flight összevonás került. A listák lapozottak. Az eseményrészlet korábban a teljes, 59 929 karakteres archívumot kérte le, mert a szerver nem biztosított egyedi eseményvégpontot; ezt a 2.4.102 WordPress-csomag célzott `/events/{id}` útvonala és a kompatibilis kliensjavítás megszünteti.

## 2. Módosított fájlok és céljuk

- `lib/services/wordpress_service.dart`: közös Dio-életciklus, timeoutok, publikus cache, ETag/304 kezelés, in-flight deduplikáció, korlátozott átmeneti retry.
- `lib/services/community_service.dart`: szerveroldali chatbeküldés és érzékeny naplózás szűkítése.
- `lib/main.dart`, `lib/services/push_notification_service.dart`: debug-only, személyes adatot nem kiíró diagnosztika.
- `lib/providers/*`, `lib/screens/*`, `lib/widgets/*`: meglévő cache-, provider-, listener- és képméretezési útvonalak célzott javításai.
- `functions/index.js`, `firestore.rules`, `firestore.indexes.json`: szerveroldali jogosultság-, idempotencia- és indexvédelmek.
- `lib/services/wordpress_head_cache.dart`: tartós publikus body+ETag cache, 30 másodperces validálási ablak, HEAD-alapú változásvizsgálat, offline fallback és azonos kérések összevonása.
- `G:\App\huhs-mobile-api`: a 2.4.102 csomagban célzott, publikus és csak látható/publikált eseményt visszaadó `/events/{id}` végpont készült.

## 3. Cache-first működés megvalósítása

A publikus WordPress-adatok használható helyi body+ETag példányát a kliens azonnal visszaadja. Harminc másodpercen belül nincs hálózati kérés; utána a képernyő blokkolása nélkül HEAD-validálás indul. Változatlan ETag esetén nincs új GET, megváltozott ETag esetén a friss body háttérben letöltődik, majd a közös változásjelző csak az érintett WordPress-providereket újraértékeli. A személyes Firebase-adatok nem kerülnek ebbe a publikus cache-be; sikertelen háttérfrissítés nem törli a régi adatot.

## 4. WordPress-optimalizálások

A listák lapozottak, a kliens nem tölti le induláskor a teljes archívumot. A kérések célzott végpontokat és szükséges mezőket használnak, a kép URL-je a lista-válasz része, ezért nincs elemenkénti média-N+1 kérés. A kliens a tárhely URL-alapú OpenResty-cache-ének fejlécproblémáját HEAD/ETag összehasonlítással kezeli, ezért változatlan adatnál nem tölti le újra a válasz törzsét. A 2.4.102-es egyedi eseményvégpont telepítéséig kompatibilitási fallback marad.

## 5. Firebase-optimalizálások és szükséges indexek

A listener-életciklusok és stream-leállítások át lettek nézve; a közösségi adatfolyamok megosztott providereken futnak. A nagy forgalmú chat-, privátüzenet- és riportfolyamok 60/50/100 dokumentumos limiteket használnak. A teljes publikus felhasználólista valós idejű figyelése szándékos, mert név- és profilképváltozásnak azonnal meg kell jelennie; a növekedési határ elérésekor ezt cursoros lapozásra kell cserélni. A szükséges indexek a repositoryban szerepelnek: `chat_reports(reporterId ASC, createdAt DESC)` és `public_profiles(achievementPoints DESC, __name__ ASC)`. A Firestore és a v2 triggerek `europe-central2`, de több kompatibilitási v1 callable még az alapértelmezett `us-central1` régióban fut; biztonságos migráció nélkül ez többlet-késleltetést okoz.

## 6. Riverpod- és állapotkezelési módosítások

A lista-providerek automatikusan felszabadulnak, a megosztott közösségi adatfolyamok nem indulnak újra minden navigációnál. A WordPress cache háttérfrissítési jelzőjét a hír-, esemény-, előadó-, szervező-, kiadvány- és GYIK-providerek figyelik; friss ETag esetén nem az egész alkalmazás, csak ezek az adatforrások értékelődnek újra. A felhasználói profil- és achievement-adatok UID szerint frissülnek; kijelentkezéskor a személyes cache törlődik. Az async műveletek dispose után nem írnak állapotot.

## 7. Képletöltési és képminőségi módosítások

A hírek, események, kiadványborítók, szervezői és előadói logók, profilképek és badge-ek a tényleges logikai méretből és a készülék DPR-jéből számított célméretet használnak. A 3× pixelsűrűségű telefonokon korábban kevés 180/300/440/900 pixeles fix korlátok megszűntek; a részletes nézetek 1080–1600 px közötti dekódolást engednek. A képarány megmarad, a placeholder végleges képre cserélődik. Nagy pixelsűrűségű fizikai készülékes vizuális ellenőrzés még tulajdonosi ellenőrzésre vár.

## 8. Hálózatkezelési módosítások

Egyetlen, újrahasznált WordPress/Cloudinary Dio kliens fut 20 másodperces kapcsolódási, küldési és fogadási timeouttal; az indítási közlemény is megosztott, 10 másodperces timeoutú klienst használ. Csak GET kérésekre, átmeneti hibáknál legfeljebb két retry fut exponenciális késleltetéssel; végleges, jogosultsági vagy megszakítási hibát nem ismétel. A hálózati hiba nem törli a használható cache-t.

## 9. Lefuttatott ellenőrzések, tesztek és build pontos eredménye

- `flutter analyze --no-pub`: sikeres.
- `flutter test --no-pub`: **74/74 sikeres**.
- A 274-es obfuszkált release APK Pixel 8 API 35 emulátorra telepítve elindult; a fő Activity aktív maradt, az ellenőrzött 300 naplózási sorban nem volt `FATAL EXCEPTION` vagy ANR.
- `node --check functions/index.js`: sikeres.
- `node --test functions/*.test.cjs`: **16/16 sikeres**.
- `npm audit --omit=dev --audit-level=moderate`: **0 sérülékenység**.
- `git diff --check`: whitespace-hiba nélkül.
- A 274-es előző Play-build mellett elkészült az új, obfuszkált production AAB `versionCode=275`, `versionName=1.0.0` konfigurációval; SHA-256: `399E2109E240513D227903B14FB97458F258080701D6D8814A96585972CD5E28`.
- Emulátoros telepítés és indítás: sikeres, fatal crash nem volt.
- Play Console: a zárt Alpha csatornában a 274 (1.0.0) kiadás jelenleg aktív; a 275-ös AAB helyben elkészült, feltöltése még hátra van.

## 10. Előtte–utána mérési eredmények

2026-09-09-i reprodukálható eseménymérés: a lapozott, 12 elemre korlátozott összefoglaló **2 722 karakter / 1 628 ms**, míg a korábbi részlet-fallback teljes archívuma **59 929 karakter / 1 240 ms**. A 2.4.102 telepítése után egy részletkérés már csak egy eseményt ad; változatlan ETag mellett a kliens HEAD után **0 válasz-body bájttal** használja a cache-t. A cache egységtesztje bizonyítja, hogy párhuzamos azonos kérésből egy hálózati művelet indul.

Az élő WP-lista `Accept-Encoding: gzip, br` kérésre `Content-Encoding: br`, `Vary: Accept-Encoding` és publikus, rövid `Cache-Control` fejlécet ad; a személyes/authenticated útvonalakat a kliens cache-e nem kezeli publikus adatként.

## 11. Repositoryn kívül elvégzendő WordPress-, Cloudflare- vagy Firebase-beállítások

- A WordPress 2.4.102 eseményrészlet-végpontja éles: a `/wp-json/huhs/v1/events/12298` 200-at és teljes leírást ad; a tulajdonosi alkalmazásteszt is visszaigazolta, hogy az eseményleírás betöltődik.
- Android-fejlesztői igazolás: a Play Console-ban a `hu.hungarianhardstyle.app` csomagnév **Regisztrált** állapotú; az identitásadatok a fejlesztői fiókban rendelkezésre állnak.
- Az OpenResty URL-cache továbbra sem variál `If-None-Match` alapján; ezt a kliens cache-busteres HEAD/ETag ellenőrzése kompatibilisen megkerüli. Tárhelyoldalon később javítható a header-aware cache, de nem klienskiadási akadály.
- Cloudflare/CDN esetén a publikus GET válaszokra engedélyezhető Brotli és rövid, publikus `Cache-Control`; személyes/authenticated válasz nem kerülhet megosztott cache-be.
- A Cloudinary unsigned preset maradjon kizárólag `jpg/jpeg/png/webp` típusokra korlátozva.
- Firebase App Check enforcement továbbra is kikapcsolva marad; a callable végpontokon Auth-, szerep-, UID- és rate-limit-ellenőrzés véd. Enforcement csak kontrollált Play Integrity mintakérések után kapcsolható be.
- Firebase-régiómigráció: a v1 callable-ekből új, eltérő nevű `europe-central2` aliasokat kell telepíteni; az új kliens ezekre váltson, miközben a régi `us-central1` végpontok legalább a korábbi Play-build támogatási idejéig megmaradnak. Csak az új kliens forgalmának igazolása után törölhetők a régi aliasok. Meglévő export régióját helyben átírni tilos, mert az már kiadott appokat törne el.

## 12. Az összes követelményt tartalmazó ellenőrzőlista

- Teljes WP/Firebase adatfolyam feltérképezése — **KÉSZ**; kód- és végpontszintű áttekintés megtörtént.
- Duplikált/N+1 kérések — **KÉSZ**; összevonás és listaoldali kép-URL használat beépítve.
- Cache-first, háttérfrissítés, TTL, izoláció, offline fallback — **KÉSZ**; statikus és tesztelt kliensútvonal.
- Párhuzamosítás és in-flight deduplikáció — **KÉSZ**; közös service/providerek használják.
- Hírek/események lapozása — **KÉSZ**; első oldal limitált, cursor/page kezelés megvan.
- WP célzott mezők, lapozás és feltételes kérés — **KÉSZ**; summary végpontok, HEAD/ETag cache és a 2.4.102-es eseményrészlet-végpont elkészült és élesben ellenőrizve.
- Firebase indexek és listener-életciklus — **KÉSZ**; repository-indexek, query-limitek és provider-leállítás ellenőrizve. A callable régiómigráció **BLOKKOLT** production deployment/kompatibilitási átállásig, pontos lépése a 11. pontban szerepel.
- Riverpod dispose/stale-state kezelés — **KÉSZ**; érintett providerek és képernyők áttekintve.
- Képfelbontás/DPR/placeholder/képarány — **KÉSZ**; kódoldali ellenőrzés kész, széles készülék-mátrix futtatása még hiányzik.
- Dio reuse/timeout/retry/cancel/cache fallback — **KÉSZ**; korlátozott retry és cache fallback beépítve.
- UX villogás/duplikáció/görgetés/frissítés — **KÉSZ**; érintett listaútvonalak javítva, teljes runtime-mátrix nincs.
- Biztonságos logolás, publikus/személyes cache, titkok — **KÉSZ**; maradó logok debug/timing-gátoltak.
- Statikus elemzés, tesztek, release build — **KÉSZ**; eredmények a 9. pontban.
- Előtte–utána reprodukálható mérés — **KÉSZ**; az esemény teljes archívumának és lapozott/részlet útvonalának mérése, valamint a body nélküli HEAD-cache tesztje rögzítve.
- Eseményleírás végponttól végpontig — **KÉSZ**; az élő API és a tulajdonosi alkalmazásteszt is visszaigazolta.
- A teljes optimalizálási csomag Playből telepített végponttól végpontig ellenőrzése — **BLOKKOLT**; a 274 aktív a Playben, de jelenleg nincs csatlakoztatott ADB-eszköz/emulátor a futtatási ellenőrzéshez.
