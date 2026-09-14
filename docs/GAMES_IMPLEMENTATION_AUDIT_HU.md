# HUHS játékok – audit és megvalósítási irány

## Meglévő, újrahasználandó rendszerek

- A Flutter kliens Riverpodot, a `WordpressService` rövid idejű és tartós gyorsítótárát használja.
- A WordPress HUHS Mobile API plugin jelenlegi forrása `G:\App\huhs-mobile-api`; a játékok ugyanebbe a pluginba kerülnek.
- Az achievement pontot a Firebase Functions `awardAchievementPoints` függvénye írja az idempotens `achievement_ledger` alapján. Ez az egyetlen pontjóváírási útvonal.
- A HUHS Legenda küszöb már központilag 6000 pont (`huhs-legend` jelvény); a pontszámnak nincs felső korlátja.
- A Firebase Functions rendelkezik ütemezett feladattal, értesítés-inboxszal és FCM push-küldéssel.
- A Firebase Functionök biztonságosan tudnak WordPress Application Passworddel szerver–szerver kérést küldeni.
- A kezdőlapon a Hírek és a Közelgő események közötti hely rendelkezésre áll az aktuális játék kártyájának.

## Felelősségi határ

| Rendszer | Felelősség |
| --- | --- |
| WordPress | Játék-konfiguráció, artwork, kérdések, helyes válaszok, időablakok, publikus játék- és eredményadatok |
| Firebase Functions | Hitelesített beküldés, egy próbálkozás kikényszerítése, ütemezett kiértékelés, idempotens pontjóváírás, személyes értesítés |
| Flutter | Játék megjelenítése, válasz beküldése, eredmények és HUHS Legendák felülete; biztonsági döntést nem hoz |

## Kötelező védelmi döntések

1. A publikus WordPress API soha nem ad helyes választ vagy megoldókulcsot.
2. A Firebase Function a hitelesített Firebase UID-t használja; a kliens nem adhat meg felhasználóazonosítót.
3. A játékok szerverideje és lezárása ütemezett Function alapján történik, nem telefonóra vagy WordPress cron alapján.
4. A pontjóváírás kulcsa `game:{gameId}:reward`, így retry és párhuzamos kiértékelés sem írhat jóvá kétszer.
5. Zenefelismerésnél a WordPress csak a kijelölt, rövidített részletet szolgálhatja ki; teljes MP3 és azonosítható metadata nem kerül a klienshez.

## Megvalósítási sorrend

1. WordPress játék-adatmodell, magyar admin, időablak- és átfedés-validáció, artwork-kötelezettség.
2. Publikus, titkos megoldást nem tartalmazó játék API és belső, csak Firebase által hívható kiértékelési API.
3. Firebase beküldés, ütemezett lezárás, eredmény, pontledger és értesítés.
4. Flutter modellek, aktív játékkártya a Hírek és Események között, játék- és eredményképernyők.
5. HUHS Legendák toplista, GYIK és Achievement-szövegek.
6. Regressziós, biztonsági és release-ellenőrzés.

## Elkészült első szelet

- A WordPress pluginban létrejött a `huhs_game` játékmodell magyar időablak- és átfedés-ellenőrzéssel.
- A játéktípusonkénti alapértelmezett artwork a „Játékképek” adminoldalon, médiatár-választóval kezelhető; az egyedi játékkép felülírja.
- A kérdések és a 2–6 válaszlehetőségek adminban menthetők, a helyes válasz külön metaadatban marad.
- A publikus `/games/active` és `/games/{id}` válasz nem tartalmaz megoldókulcsot. A `/games/{id}/private` kizárólag WordPress-admin jogosultsággal érhető el, később a Firebase szerverproxy használhatja.
- A zenés feladványoknál a WordPress a kiválasztott, legfeljebb 10 másodperces részt 96 kbps MP3-ként külön, tiltott könyvtárba vágja; az app csak hitelesített, egyszer használatos, 5 perces tokenes URL-t kérhet hozzá. A teljes forrás-MP3 és a metaadata nem kerül a publikus játékválaszba.
- A Flutterben elkészült a publikus `HuhsGame` modell, az aktív játék rövid memóriacache-es lekérése és a Riverpod provider; a félkész UI még nincs bekötve.
- A Flutter szolgáltatás és Firebase callable előkészítve a rövid audio-token lekérésére; a WordPress API csomag 2.4.85-re verziózva.
- Ellenőrizve: `flutter analyze --no-pub`, célzott game-teszt, `node --check functions/index.js`, `git diff --check`.

## Nyitott, de nem blokkoló tartalom

- A játéktípusonkénti végleges artworköket a tulajdonos tölti fel; artwork nélkül egy játék nem időzíthető.
- A Firebase callable és a 2.4.87-es WordPress-csomag éles telepítése, valamint az app játék- és eredményfelületének bekötése még külön lépés; addig a kliens nem kaphat teljes MP3-at kerülőútként.
- Az idővonal külön adatmodellt kapott: előadó, trackcím és szerveroldalon tárolt `YYYY-MM` megjelenési idő; a publikus appadat a hónapot nem tartalmazza, a sorrend ellenőrzése védett szervervégponton történik.
- A „Kvíz” típusoknál tetszőleges számú kérdés adható hozzá, a nem kvíz típusoknál kérdésenként 3–5 válaszlehetőség érvényes. A kvíz jutalomsávjai, más játékok fix jutalompontja adminból állítható.
