# Hungarian Hardstyle App - Project Context for AI Agents

### Kiadvány megjelenési dátum szerinti élesítés + PRESAVE (2026-09-18)

- **Tulajdonosi kérés:** új kiadvány feltöltésekor a Play-szinkron fusson le (kimegy a Google Play felé), de az appban **csak a megjelenési dátumtól** legyen megvásárolható, és a **96 kbps ingyenes (reklámos) letöltés is csak akkor** működjön. Emellett legyen **PRESAVE link** mező.
- **Tulajdonosi döntések (mind rögzítve):**
  1. A dátum előtt a kiadvány **látszódik** „Hamarosan" jelöléssel + PRESAVE gombbal.
  2. A PRESAVE **egy URL-mező**, ami a megjelenési dátum után **automatikusan eltűnik**.
  3. A Play-termék **csak a megjelenési napon aktiválódik** (addig létezik, de nem vásárolható).
  4. **A 60 másodperces preview a dátum előtt is működik** — ez külön, nyilvános fájl, a kapu nem érinti.
- **Hol születik a döntés (egyetlen hely):** `huhs_release_is_upcoming()` a `helpers.php`-ban. A dátum a **webhely időzónájában** értendő, és a kiadvány a megjelenési napján **00:00-kor** válik elérhetővé. A nyilvános API ebből adja az `is_upcoming` mezőt, ezért a kliensnek **nem kell dátumot számolnia** — így nincs időzóna-eltérés az app és a szerver között. Érvénytelen/üres dátum → hamis (elérhető), hogy egy elgépelt dátum ne zárja ki a vásárlókat.
- **A letöltés-kapu a WordPressben van** (`private-download.php`, `huhs_release_create_download_token`): a token **minden** privát változatra (fizetős WAV/320, reklámos 96 kbps, ingyenes WAV) elutasításra kerül a dátum előtt. Ez azért itt van, mert itt van a dátum és az időzóna, és mert így a **már telepített kliensek is védettek**. A Firebase-oldalon nem kellett külön kaput tenni: a `getLabelDownloadUrl` a WordPress hibaüzenetét adja tovább (`failed-precondition`), így a felhasználó értelmes magyar üzenetet kap.
- **Play-termék ütemezése** (`functions/index.js`, `upsertPlayProduct`): a termék a dátum előtt is létrejön (hogy a Play ellenőrzése és a terjesztés lefusson a premierig), de a vásárlási opció **INACTIVE** marad; a napon az **ötpercenkénti ütemezett szinkron** aktiválja, emberi beavatkozás nélkül. A dátum előtti ellenőrzés szándékosan **nem egy konkrét Play-állapotot** követel meg, hanem csak azt, hogy „ne legyen ACTIVE" — a katalógusnak több nem-aktív állapota van, és egy ismeretlen érték elutasítása feleslegesen elbuktatná a szinkront.
- **WordPress oldal (2.4.112):** új `presave_url` meta + admin mező a „Megjelenes elotti elorendeles" szekcióban; az `is_upcoming` és a `presave_url` bekerült a lista- és a részlet-válaszba is (a `presave_url` csak akkor, ha a kiadvány még előtte van). Csomag: `build/huhs-mobile-api-2.4.112.zip` (SHA-256 `A462311F9EFC8F60F3C4D5C2178D17CF656AEA012F0AE427B16772D65BC38F31`), forrás: `.tmp-api-24112/huhs-mobile-api/`.
- **Kliens:** a `HuhsRelease` modell új `isUpcoming` és `presaveUrl` mezőt kapott (hiányzó `is_upcoming` esetén `false`, vagyis a régi viselkedés marad). A lista-kártyán „Hamarosan · Megjelenés: …" felirat; a részletoldalon egy „Hamarosan" kártya a PRESAVE gombbal, és a **vásárlási/letöltési blokkok elrejtve** a dátum előtt. A kliens-oldali elrejtés csak megjelenítés: a tényleges kapu a szerveren van.
- **Ami még hátra van:** a kliensoldali változás **csak a következő AAB-buildben** élesedik. Addig a telepített app a dátum előtt is mutatja a vásárlás/letöltés gombot, de a szerver elutasítja, és a magyar hibaüzenet jelenik meg — ez szándékos és biztonságos.

### Biztonság: a névfoglalás megkerülése lezárva (2026-09-18)

- **A rés, igazolva:** a `community_profiles` create-szabály megengedte, hogy egy kliens közvetlenül írjon profil-dokumentumot tetszőleges `displayName`-nel, megkerülve a `claimDisplayName` szerveroldali névfoglalását. Így egy módosított kliens **már lefoglalt nevet is elvehetett** (név-utánzás).
- **Két akadály, amit előbb fel kellett oldani:**
  1. A `displayNameKey()` **SHA-256 hash**, amit a Firestore szabályok **nem tudnak kiszámolni**, ezért a meglévő `display_name_index`-et egy szabály nem tudja megnézni.
  2. A **jelenleg telepített +225-ös app közvetlenül írja a `displayName`-t** (`community_service.dart` 276. és 459. sor a +225 commitban, `f87bb8fc`). Ezért **tilos** volt a mezőt kivenni a szabályból: az a telepített app regisztrációját törte volna el.
- **A megoldás: plain-text tükör.** Új `display_name_claims/<normalizáltNév>` kollekció (kliensoldalról `allow read, write: if false`):
  - `claimDisplayName` tranzakcióban írja (és átnevezéskor törli a régit, ha a hívóé volt);
  - a fióktörlés felszabadítja, különben a név örökre blokkolódna;
  - a napi `repairCommunityProfileProjections` **feltölti** a meglévő profilok neveit, és ütközést jelent (`community_profile_display_name_conflicts`), de nem nevez át senkit automatikusan.
- **A szabály** (`firestore.rules`): `normalizedDisplayName()` = `trim().lower().replace('\\s+', ' ')`, és `displayNameClaimAvailable()` engedi a szabad nevet **vagy** a saját foglalást. Beépítve a create-ágba és az admin-átnevezés ágába is.
  - **A mező jelenlétét `'displayName' in request.resource.data`-val kell ellenőrizni**, mert a hiányzó kulcs olvasása *evaluation error* a szabály-nyelvben, és az elfedné a valódi elutasítási okot. Ezt az emulátoros teszt fogta meg.
- **Emulátoros szabályteszt: `functions/rules.test.cjs`** (8 teszt, mind zöld). Futtatás a repo gyökeréből:
  `npx firebase emulators:exec --only firestore --project demo-huhs "node functions/rules.test.cjs"`
  Ez az első valódi Firestore Rules Emulator-teszt a projektben (a `USER_MANAGEMENT_SOURCE_AUDIT` M3 pontja), és épp a kiadás-biztonságot bizonyítja: **szabad nevet a telepített kliens továbbra is beírhat**, idegen foglalást nem lehet elvenni, a tulajdonos a sajátját igen, a normalizálás (kis-nagybetű, dupla szóköz) egyezik a szerverrel, a foglalás-kollekció kliensből elérhetetlen, a szokásos profilfrissítés működik.
- **Fontos ütemezés:** a meglévő nevek védelme a **következő 03:00-s napi javításkor** épül fel (akkor fut a backfill). Addig csak a deploy után foglalt nevek védettek. A védelem hiánya nem hiba, csak késleltetett.
- **Az app nem törhet el:** a szabály csak olyan create-et utasít el, amit a kliens magától is elutasított volna (a nevet a `checkDisplayNameAvailability`/`claimDisplayName` már foglaltnak jelezte).

### Biztonsági függőség-frissítés: nodemailer 7 → 10 (2026-09-18)

- `npm audit` a `functions/`-ben **1 magas súlyosságú** sebezhetőséget jelzett a `nodemailer@7.0.13`-ban; a javítás a `nodemailer@10.0.10` (törő verzióváltás).
- **Ellenőrizve, hogy biztonságos:** a `functions/email_service.js` csak a stabil API-t használja (`createTransport({host, port, secure, auth, tls, connectionTimeout, greetingTimeout, socketTimeout})` és `sendMail({from, to, subject, text, html})`), ezek a 10-es verzióban is léteznek; a futtatókörnyezet Node 22.
- Frissítés után: **`npm audit`: 0 sebezhetőség**, `node --check functions/index.js` OK, és mind a **9 függvény-teszt zöld**.
- **Tanulság a tesztek futtatásához:** a `functions/*.test.cjs` fájlokat a **repo gyökeréből** kell indítani (`node functions/<nev>.test.cjs`). A `functions/` könyvtárból futtatva a `security-permissions.test.cjs` elhasal egy relatív útvonalon, ami **nem regresszió**, csak rossz munkakönyvtár.

### Cache-invalidációs audit — mind a hat hiba MÁR javítva volt (2026-09-18)

- A `docs/AUDIT_CHAT_ACHIEVEMENT_REFRESH_2026-09-02.md` „bizonyított" hibái az audit óta **már javítva lettek**, ezért **nem szabad újraimplementálni** őket. Bizonyíték a jelenlegi kódban:
  1. **A chat-sor nem frissült** → javítva: `community_screen.dart:746` figyeli a `CommunityService.publicProfileRefreshGeneration` értéket, és növeli a `_profileRefreshGeneration`-t.
  2. **A `forceRefresh` megkerülte a deduplikációt** → javítva: `_publicProfileRefreshRequests` (`community_service.dart:1502`) és `_publicAchievementRefreshRequests` (`1842`) visszaadja a már futó frissítést.
  3. **A régi Future visszaírt a cache-be** → javítva: epoch-ellenőrzés a visszaírás előtt, profilnál `1522`, achievementnél `1856` (`_cacheEpochFor(...) == requestEpoch`).
  4. **Az összesített `_publicProfilesCache` nem invalidálódott** → javítva: `clearPublicProfileCache(uid)` nullázza (`1799`) és növeli a `_publicProfilesEpoch`-ot.
  5. **Hibák elnyelve, nincs újrapróbálás** → részben javítva: 3 próbálkozás növekvő várakozással (`1511`, `1848`); felhasználói hibaüzenet szándékosan nincs, mert a profilból olvasott részleges rang a helyes fallback.
  6. **`AchievementSummary.empty` felülírhatta a részleges rangot** → javítva: `community_screen.dart:1651-1656` a helyi (profilból olvasott) értéket tartja meg, ha a fallbacknek nincs jelvényképe.
- **Ami valóban hiányzik: a tesztfedezet.** Az audit által kért service-/widgettesztek (deduplikáció, invalidálás utáni stale válasz elutasítása, jelvény megjelenése a chatben) **nem készültek el**. Ezekhez a `CommunityService`-t injektálhatóvá kellene tenni (interfész kiemelése), ami **valódi refaktor a működő appban** — ezért a „ne törjön el az app" elv miatt **szándékosan elhalasztva**, külön döntést igényel.
- **Ne olvasd a régi auditot nyitott hibák listájaként.** Előbb ellenőrizd a kódot.

### Játékok: ÉLESBEN MŰKÖDNEK — a régi audit állításai elavultak (2026-09-18)

- **Tulajdonosi visszajelzés:** *„fut egy éppen, egy meg lezárva"*. Ez megerősíti, hogy a játék-funkció éles és használatban van.
- Élesben ellenőrizve: `GET /wp-json/huhs/v1/games/active` → HTTP 200, 1742 bájt, **id 12662, „Hardstyle kvíz"**, `type=hardstyle_quiz`, `start_at=2026-09-15T19:55`, `end_at=2026-09-25T19:00`, `results_until=2026-09-27T19:00`, `status=active`, **5 kérdés**, 6 jutalomsáv.
- **Az artwork fel van töltve:** `artwork=https://hungarianhardstyle.hu/wp-content/uploads/2026/09/02_HARDSTYLE_KVÍZ.png`. Tehát a `docs/GAMES_IMPLEMENTATION_AUDIT_HU.md` „a félkész Flutter játék-UI nincs bekötve" és „végleges artworkök feltöltése hátra van" pontjai **elavultak** — a `GameScreen` be van kötve (`lib/screens/home/home_screen.dart:522`), a `lib/models/game.dart` és a `lib/providers/games_provider.dart` megvan, és a szerveroldali végpont él.
- **NYITOTT RENDELLENESSÉG, amit élesben mértem:** `GET /wp-json/huhs/v1/games/results/latest` → **HTTP 200, de 0 bájt** (üres törzs). A `games.php` forrása szerint ez a végpont a legutóbbi `closed` állapotú játék adatait adná vissza, és `rest_ensure_response(null)`-t ad, ha nincs ilyen — az viszont `null` (4 bájt) lenne, nem üres. Két lehetséges ok: vagy nincs a `huhs_game_status()` szerint `closed` játék (pl. lejárt a `results_until` ablaka), vagy a payload-építés futásidejű hibát ad, és a már elküldött 200-as fejléc mellett üres marad a törzs. **A tulajdonos visszajelzése kell hozzá:** megjelenik-e az appban a lezárt játék eredménye. Ha nem, ezt ki kell vizsgálni (szerver error_log + a lezárt játék `_huhs_game_*` meta mezői).
- **A nyereményjáték (nyereményjáték / prize draw) ETTŐL FÜGGETLEN**, külön WordPress-rendszer, és **még nincs megcsinálva**. Tulajdonosi döntés: *„az ráér"* — **ne kezdd el**, amíg nem szól. A spec a „Következő fejlesztési feladat — külön WordPress nyereményjáték-rendszer" szakaszban van.
- Tanulság a jövőre: a `docs/` auditok **státusza elavulhat** (a játékoknál ez megtörtént). Mielőtt egy dokumentumban „nyitott" tételt felajánlanál, ellenőrizd a kódban vagy élesben.

### 2.4.111 éles mérés — a saját pluginunk betöltése elhanyagolható (2026-09-18)

- **Eredmény: `our_files_ms=2–3` (egy mintában 19).** A saját 40 include-fájlunk betöltése **2–3 ms** — vagyis az a felvetés, hogy az admin-only fájlokat lustán töltsük be, **nem éri meg**. A mérés nélkül felesleges és kockázatos refaktor készült volna. Ez a kérdés **lezárva**, ne nyúlj hozzá újra.
- A mérés a `plugin_file_at` (az első saját fájl, a `diagnostics.php` betöltése) és az `our_files_at` (a fő pluginfájl vége) különbsége. A `diagnostics.php` szándékosan a 3. include, ezért a `plugin_file_at` jó közelítés a saját betöltésünk kezdetére.
- **A `queries` változatlanul 111**, és a `plugins` lista ugyanaz a 38 — az ötperces scan szűkítése csak akkor látszik, amikor a cron ténylegesen lefuttatja (5 percenként egyszer), ezért egy átlagos kérésben nem mérhető.
- **FONTOS, ne tulajdonítsuk magunknak:** ebben a mérési ablakban `wp_to_response` 849–947 ms volt a korábbi 1396–1416 ms helyett, DE a statikus fájl ugyanakkor **132 ms** volt a korábbi 20–40 ms helyett — vagyis a host épp **terheltebb**, mégis gyorsabb PHP-választ adott. A 38 bővítmény és a 111 lekérdezés **azonos**, ezért ez **host-terhelés szórása, nem a változtatásunk eredménye**. Különböző ablakok méréseit tilos összehasonlítani; mindig kell mellé statikus fájl-kalibráció.
- Regresszió-ellenőrzés 2.4.111 után: `HEAD` elsőre `fresh` (a pluginfrissítés invalidálta a cache-t — helyes), ismételve `early`; GET 455 ms. A cache-út rendben.
- **Az esemény-dátum formátuma ellenőrizve élesben:** `/events` szerint `event_start_date` mindig `Y-m-d` (pl. `2026-10-17`, `2026-09-26`), tehát a `meta_query` `BETWEEN` szűrés formátum-feltevése helyes. Élőben 3 esemény van; közülük a `2026-09-26` esik a 8 napos horizontba, a távolabbiak helyesen kimaradnak.
- **Az ablak bizonyítottan elég tág:** a hét-emlékeztető ablaka `start - 7 nap`-nál nyílik, és ekkor a horizont `now + 8 nap = start + 1 nap ≥ start`, tehát az esemény benne van. Ugyanez igaz az egy napos és a hat órás ablakra. Az alsó korlát (`ma`) is biztonságos: emlékeztető csak `start ≥ now + 5 óra` esetén esedékes.
- `push_tokens=895` továbbra is — a halott-token tisztítás **még nem igazolható**, mert a 2.4.111 feltöltése óta nem futott push-kör. Az első éles cikk közzététele után kell visszamérni: ha a szám csökken, a tisztítás működik.

### Tulajdonosi döntés: a bővítményekhez nem nyúlunk (2026-09-18)

- A tulajdonos visszajelzése a 38 bővítményről: *„semmit ne kapcsolj ki, kellenek az oldal működéséhez sajna”*.
- **Ezért a `docs/PLUGIN_AUDIT_HU.md` listájából semmit nem szabad kikapcsolni.** A dokumentum megmarad nyilvántartásnak (mi mit csinál, mi hagy nyomot az élő oldalon), de **nem végrehajtási terv** — ne ajánld fel újra.
- Következmény: az oldal lassulása a bővítmények oldaláról **nem javítható**. Marad (a) a **saját pluginunk** belseje, (b) a **hosting** (OPcache, tartós object cache) — utóbbi külön tulajdonosi döntés, mert a szolgáltató korábban VPS-ajánlattal élt, (c) annak biztosítása, hogy az app a lehető legkevesebb kérést indítsa (a cache-first működés ezt nagyrészt megoldja).
- **Az app szempontjából a helyzet így is jó:** a 2.4.108 óta a cache-elt választ a szerver már a pluginbetöltés közben kiszolgálja (~0,43–0,6 s a ~1,4 s helyett), a kliens cache-first, és a frissítés is háttérben fut. A lassulás elsősorban **hideg** kéréseken és a weboldal látogatóin látszik.

### 2.4.111 — saját plugin költsége és az ötperces esemény-scan (2026-09-18)

- **Új mérés:** a fő pluginfájl végén egy `huhs_diag_mark('plugin_files_done')` jelölés, és a boot-próba fejlécében két új érték: **`our_files_at`** és **`our_files_ms`** — vagyis hogy a saját 40 include-fájlunk mennyibe kerül. Ez a szám kell ahhoz, hogy eldönthessük: megéri-e az admin-only fájlokat lustán betölteni. Éles mérés 2.4.111 feltöltése után.
- **Javított ötperces scan:** a `huhs_push_scan_event_reminders()` eddig **minden** publikált eseményt betöltött (max. 500 bejegyzés + meta), ötpercenként, örökké — méghozzá WP-Cronon keresztül, tehát **egy véletlenszerű látogatói vagy app-kérés fizette meg**. Pedig emlékeztető csak a következő egy héten belül kezdődő eseményhez lehet esedékes. Most `meta_query` szűkíti a kört `event_start_date` BETWEEN [ma, ma+8 nap] értékre (szándékosan tágabb a három emlékeztető-ablaknál: hét / egy nap / hat óra). Így a lekérdezés jellemzően néhány sort ad 500 helyett.
- **Időzóna-csapda, amit elkerültem:** az `event_start_date` **helyi naptári dátum**, ezért a határokat valós időből és a site időzónájából kell számolni (`wp_date('Y-m-d', time())`). A függvény `$now` változója `current_time('timestamp')`, ami egy **helyileg eltolt** időbélyeg — abból számolt dátum duplán tolódna.
- **Nem változtattam** a többi emlékeztető-úton (`huhs_push_schedule_event_reminders`, `save_post_huhs_event`), és az emlékeztető-küldés logikája (`huhs_push_event_reminder`) érintetlen.
- Csomag: `build/huhs-mobile-api-2.4.111.zip` (SHA-256 `4060FE2E5CCCA2AE267247495AC5EE910767E0D401DA3CC6035985D575AEDB8B`), forrás: `.tmp-api-24111/huhs-mobile-api/`. **Ez tartalmazza a 2.4.110 push-feldarabolást is**, ezért a tulajdonosnak csak a 2.4.111-et kell feltöltenie (a 2.4.110-et nem töltötte fel).

### Push-kézbesítés — 895 eszköz, ezért feldarabolva (2026-09-18, 2.4.110)

- A 2.4.109 éles health-próba megmutatta: **`push_tokens=895`**. A régi kód **minden** eszközre külön, sorban küldött egy blokkoló kérést (~200 ms/db), ezért egy hír közzététele **~3 percig** tartott. Ha a host 60 s-nál elvágja a kérést (PHP-FPM `request_terminate_timeout`, nginx `fastcgi_read_timeout`), akkor a lista **nagy része értesítést sem kapott** — a hír-pushnak ugyanis nincs újrapróbája, a release-nek van.
- Ezért a **2.4.110** feldarabolja a `huhs_push_send()`-et: egy kérés legfeljebb `HUHS_PUSH_TIME_BUDGET` = **15 s**-ot küld, a maradékot a `huhs_push_continue` cron-hook viszi tovább (offset + `huhs_push_job_<random>` opció, nem autoloadolt), legfeljebb `HUHS_PUSH_MAX_RUNS` = **40** körig. 895 eszköz ≈ 12 kör ≈ 3 perc összmunka, de **egyetlen kérés sem hosszabb 15 s-nál**, így a host nem tudja elvágni.
- Új: **a halott tokenek törlése.** Ha az FCM 404 / `NOT_FOUND` / `UNREGISTERED` választ ad (app törölve, vagy a token lecserélődött), az a token eddig **örökre** a listában maradt, és minden további pushban lassított. Most a kör végén egyetlen opcióírással törlődnek.
- **A viselkedés nem változik:** ugyanaz a cím, szöveg, `data`, és ugyanaz a preferenciaszűrés — a szűrő logika `huhs_push_recipients()`-be került, a feltételek változatlanok.
- **WordPress-tények, amiket a `wp-cron.php` forrásában ellenőriztem:** `ignore_user_abort(true)` van, `set_time_limit(0)` **nincs**, és korán meghívja a `fastcgi_finish_request()`-et; a `spawn_cron()` pedig `DOING_CRON` alatt **azonnal visszatér, nem csinál semmit**. Ezért a folytató körök a következő WP-Cron-t kiváltó kérésre futnak le (`wp_cron()` az `init`-en minden kérésnél ott van, és az app maga folyamatosan kéréseket küld) — másodpercek, nem percek.
- Logikai ellenőrzés PHP nélkül: `tools/verify-push-delivery.mjs` (futtatás: `node tools/verify-push-delivery.mjs`) — a kézbesítés algoritmusát szimulálja (szűrés, időkeret, offset, folytatás, tisztítás). Ellenőrizve: 895 eszköznél mindenki **pontosan egyszer** kap értesítést, a lánc lefut, a halottak törlődnek, az élők megmaradnak, 1 eszköz/kör esetén is végigmegy, tartós FCM-hibánál is lefut, kórosan lassú esetben a plafon megállítja. **Ha a push-kézbesítés logikája változik, ezt a szimulációt is frissíteni kell**, mert ez az egyetlen futó ellenőrzés erre a részre.
- Csomag: `build/huhs-mobile-api-2.4.110.zip` (SHA-256 `92A4B8C37271C6989BF0F3FEDA6A11F8DE60F47F98ECF3602160547B7EABA36F`), forrás: `.tmp-api-24110/huhs-mobile-api/`.
- Nyitott ötlet a további gyorsításra: a küldés párhuzamosítása `curl_multi`-val (a WordPress HTTP API nem tud ilyet). Ez a ~3 perc összmunkát töredékére vágná, de éles PHP-tesztek nélkül kockázatos, ezért külön döntést igényel.

### Az oldal lassulása — a 2.4.109 health-próba eredménye (2026-09-18)

- Éles `X-HUHS-Health`: `opcache=restricted object_cache=no plugins=38 autoload=1247opts/667KB cron=79 cron_disabled=no push_tokens=895 memory_limit=512M php=8.4.24`.
- **38 aktív bővítmény** — ez a fő ok. `plugins_loaded` 788–1044 ms, teljes válasz 1423–1642 ms, 111–116 lekérdezés, 166–168 MB csúcs, mindezt egy 10 KB-os JSON-ért.
- **`object_cache=no`** — nincs tartós object cache, ezért minden kérés az adatbázisból olvassa az opciókat és a transienteket.
- **`opcache=restricted`** — az `opcache_get_status()` `false`-t adott. Ez **kétértelmű**: vagy ki van kapcsolva az OPcache, vagy az `opcache.restrict_api` tiltja a lekérdezést. A pontos válaszhoz egy következő próbában `ini_get('opcache.enable')` kell.
- **`autoload=1247opts/667KB`** — minden kérésnél 667 KB opció töltődik be. A legnagyobb egyetlen tétel a `_transient_dirsize_cache` **206 KB** (a `get_dirsize()` méret-gyorsítótára), ami több ezer könyvtárbejegyzést jelent; utána `rewrite_rules` 36 KB, `fs_accounts` 35 KB.
- **Teendő-jelöltek (tulajdonosi döntés kell, magamtól nem nyúlok hozzá):** a 38 plugin átvilágítása — több feleslegesnek tűnik (`broken-link-checker`, `google-site-kit`, `intelly-related-posts`, `real-category-library-lite`, `category-subcategory-list-widget`, `child-theme-wizard`, `final-tiles-grid-gallery-lite`, `video-player-block`, `all-in-one-video-gallery`, `wp-flyer-popup`, `blog-designer-pack`, `advanced-import`, `poll-maker`, `disqus-comment-system`), és tisztázni kell a három további HUHS-plugin sorsát is (`huhs-push-auto-permission-patch-0.1.5-all-categories`, `huhs-release-catalog-1.1.0`, `hungarian-hardstyle-google-source-1.0.4`). Emellett a hostnál kérhető az **OPcache bekapcsolása** és egy **tartós object cache (Redis)**.
- Fontos: ha bármelyik bővítményt kikapcsoljuk, utána **ellenőrizni kell**, hogy az app végpontjai és a mentési folyamatok működnek-e (a `huhs-*` három plugin kivétele különösen kockázatos: lehet, hogy a push-engedélyezés vagy a release-katalógus múlik rajtuk).
- **A döntés-előkészítő lista elkészült: `docs/PLUGIN_AUDIT_HU.md`** — mind a 38 bővítmény besorolva (tilos kikapcsolni / aktív és használt / valószínűleg kikapcsolható), kívülről gyűjtött bizonyítékokkal (nyilvános asset-nyomok, HTML-markerek, regisztrált tartalomtípusok), kiindulási méréssel és biztonságos sorrenddel. **Tulajdonosi döntés: ő dönt, a bővítményekhez magamtól nem nyúlok.**
- Két konkrét hiba a listából: (1) a `huhs-push-auto-permission-patch-0.1.5-all-categories` a nyilvános oldalon minden betöltésnél kéri az `assets/push.js`-t, ami **404-et ad** (a `sw.js` service worker viszont megvan, 200) — vagyis a webes böngésző-push feliratkozás része törött; (2) `huhs-release-catalog-1.1.0` **semmilyen nyomot nem hagy** (0 találat), lehet, hogy elavult. Mindkettő külön döntést igényel.
- **Kritikus, nem nyilvánvaló függés:** az app képméretezése (`ResizedNetworkImage` → `WordPressImageUrl`) a **Jetpack Photon CDN-jére** (`i0.wp.com`) épül. A `jetpack` bővítményt ezért **tilos kikapcsolni**, különben a képek visszaesnek az eredeti (bizonyítottan 1,5 MB-os) fájlra. A `jetpack-boost` adja a 196 ms-os cache-elt főoldalt, az is marad.
- Kiindulási mérés a bővítmény-tisztítás előtt (3 minta): `plugins_loaded` 792–825 ms, `wp_to_response` 1396–1416 ms, `queries=111`, `peak_mb=166,5`. A tisztítás után ugyanezzel a próbával kell visszamérni.

### Javítva — lassú cikkmentés: a blokkoló FCM push (2026-09-18)

- **Tünet:** a tulajdonos szerint a WordPress adminban **csak közzétételkor** volt lassú a cikk mentése (piszkozat mentése gyors), és maga az oldal is lassú.
- **Ok (bizonyított, nem sejtés):** a `push.php` `huhs_push_on_publish()` a `transition_post_status` hookon, a mentési kérésen **belül** hívta a `huhs_push_send()`-et `post` típusnál. A `huhs_push_send()` pedig **egyenként, sorban** küld egy blokkoló `wp_remote_post`-ot az FCM-nek **minden regisztrált készülékre** (`timeout: 15`). Vagyis a szerkesztő addig várt, amíg az összes telefon értesítése elment: 100 készülék × 200–400 ms = 20–40 másodperc. Piszkozatnál nincs `transition_post_status` publish felé, ezért az gyors maradt — ez a megfigyelés egyezik a diagnózissal.
- **A hiba nem szándékos:** ugyanabban a fájlban az egyedi push már régóta sorba van állítva, szó szerinti indoklással (`huhs_push_queue_custom`: „Queue a custom push instead of keeping the authenticated REST request open while FCM is contacted once for every registered device”). Az esemény és a release is `wp_schedule_single_event`-tel megy. **Csak a hír** maradt a régi, blokkoló úton.
- **Javítás:** új `huhs_schedule_news_push()` + `huhs_push_publish_news` cron-hook. A publikálás csak **ütemez** (`time() + 1`), majd `spawn_cron()`-nal (nem blokkoló loopback) azonnal el is indítja; a küldés a kérésen kívül fut. Ugyanaz a cím, ugyanaz a payload és ugyanaz a `news` preferenciaszűrés, tehát a funkció nem változik, csak nem blokkol. Ha az ütemezés mégis meghiúsul, a régi, azonnali küldés fut le tartalékként, hogy egy értesítés se vesszen el.
- **Ugyanaz a hiba a release-nél is javítva:** a `releases.php` `save_post_huhs_release` ága a `huhs_queue_label_product_sync()`-et hívta közvetlenül a mentésben, pedig az egy OAuth tokent kér a Google-től **és** ír a Firestore-ba (két hálózati kör, 15 s timeouttal). Új `huhs_schedule_label_product_sync()` + `huhs_label_product_sync` cron-hook; az admin „Play-termékek létrehozása” gomb szándékosan maradt szinkron, mert ott a felhasználó kifejezetten az eredményre vár.
- Csomag: `build/huhs-mobile-api-2.4.109.zip` (SHA-256 `2969969D012F123CEA960E61220D8904CF2D8CC0FD08B4A43A8F457938FF009F`), forrás: `.tmp-api-24109/huhs-mobile-api/`. A tulajdonos tölti fel.
- **Újraindítható csomagoló:** `tools/build-plugin-zip.mjs` (Node, forward slash, helyes root mappa, `deflateRaw` + CRC32). Eddig minden verzióhoz kézzel készült a ZIP; mostantól: `node tools/build-plugin-zip.mjs <plugin-mappa> <out.zip> <rootMappa>`. Ellenőrizve: 41 bejegyzés, `/` elválasztó, `huhs-mobile-api/` gyökér, mind a 41 fájl bájt-azonos a forrással.

### Oldal-lassulás — hol tart a vizsgálat (2026-09-18)

- **Mérés (cache-busterrel, valódi kérés):** főoldal cache-ből (Jetpack Boost) 196 ms, **valódi főoldal 1817 ms**, `/posts` 1253 ms, statikus kép 20–40 ms. A hálózat tehát gyors, a WordPress bootja a költség.
- A `X-HUHS-Boot` éles értéke: `plugins_loaded=761 ms`, `init=945 ms`, `rest_api_init=1101 ms`, válasz 1253 ms, **111 lekérdezés**, **166 MB csúcsmemória** egy 10 KB-os JSON-hoz. A kérés ~60%-a a pluginok betöltése.
- **A gyökér még nem ismert**, csak a gyanúsítottak: OPcache kikapcsolva (ekkor minden kérés újrafordítja a PHP-t), nincs perzisztens object cache, felduzzadt autoload options tábla, túl sok plugin, illetve a Jetpack (és a Jetpack Boost) súlya.
- Ezért a **2.4.109** egy új diagnosztikai fejlécet ad: **`X-HUHS-Health`** — `opcache`, `object_cache`, `plugins=<n>:<lista>`, `autoload=<n>opts/<KB>KB`, `top_autoload=<5 legnagyobb>`, `cron=<n>`, `cron_disabled`, `push_tokens`, `memory_limit`, `php`.
- Használat: `GET /wp-json/huhs/v1/posts?per_page=1&huhs_diag=huhs-boot-probe-2026&probe=<véletlen>`. A `probe` értéknek **minden mérésnél másnak kell lennie** (része a cache-kulcsnak), különben a korai cache kiszolgál és nem lesz fejléc. Csak a titkos markerrel működik, csak fejlécet ad, a tartalmat nem érinti.
- A `push_tokens` szám közvetlenül megmutatja, hány készüléknek küld a push — ebből számolható, mennyi volt a régi, blokkoló mentés valódi költsége.
- A `cron_disabled` azért fontos, mert a fenti javítások WP-Cronra támaszkodnak; ha a host letiltotta (`DISABLE_WP_CRON`), akkor a következő oldalletöltés futtatja őket (a WordPress `init`-en minden kérésnél ütemez), tehát továbbra is másodperceken belül elmennek — de ezt tudni kell.

### Javítva — hiányzó achievement-jelvény (2026-09-18)

- Kiváltó ok: a `getAchievementBadges()` WordPress-kimaradás esetén a kép nélküli vészkatalógust (`defaultAchievementBadges`) adja vissza, és ezt a pontozás, a jelvény-újraszámolás és az admin-egyeztetés eddig **el is mentette** a profilba. Így egy WordPress-lassulás a felhasználót a „Kezdő ütem” rangra visszaminősítette, és törölte a feltöltött jelvénygrafikát.
- A vészkatalógus mostantól csak megjelenítésre használható: `persistedAchievementBadge()` kizárólag akkor számol rangot a katalógusból, ha az valóban betöltődött; különben a profilban már tárolt jelvény marad érintetlen.
- A napi `repairCommunityProfileProjections` a valódi WordPress-katalógusból számolja újra a jelvényt, és a hiányzó grafikát is pótolja.
- A `getPublicProfile` és a toplista a már betöltött (meleg) katalógust használja plusz kérés nélkül, a nyilvános profiladatlap pedig kép nélküli jelvénynél a `getPublicAchievement` callable-lel számoltatja újra.
- A pontozás csak tényleges rangváltásnál bumpolja az `achievementUpdatedAt`-et, így nem indul újra a jelvénykép letöltése minden egyes lájk után.
- Élesítve (`firebase deploy --only functions`), majd a napi javítás azonnali futtatásával ellenőrizve: 22 profilból 5 hibás jelvénye állt helyre, jelenleg egyetlen profil sem mutat kép nélküli jelvényt.
- Új teszt: `functions/achievements.test.cjs`; a `functions/article-comments.test.cjs` a regisztrációs kapu szerinti szerződésre frissítve (névtelen felhasználó nem hozhat létre hozzászólást). A `registration.integration.test.cjs` helyi Firestore-emulátort igényel, ezért emulátor nélkül nem fut.
- Kliensoldali kiegészítés a `CommunityPublicProfileScreen`-ben elkészült, de **szándékosan még nincs új AAB-ban** (a tulajdonos kérésére most nem készül build); a következő build viszi.

### Cache-first megjelenítés és frissítés ikon (2026-09-18)

- A WordPress-tartalom rétegzett cache-e (memória + ETag/HEAD + SharedPreferences) már korábban elkészült; ez a kör a **megjelenítést** tette cache-firstté.
- A Hírek lista eddig nyitáskor erőltetett hálózati kérést várt, ezért teljes képernyős töltő jelent meg. Most a mentett oldal azonnal kirajzolódik, és a friss válasz utána cseréli le; ha a háttérfrissítés hibázik, a mentett lista a képernyőn marad.
- A `PaginatedNewsNotifier` betöltői injektálhatók (`loadPage`, `loadCategories`), ezért a cache-first viselkedés élő WordPress nélkül tesztelhető (`test/providers/news_provider_cache_first_test.dart`).
- Új `ContentRefreshIcon` widget: látható frissítés ikon, pörgés a kérés alatt, és ismételt koppintás nem indít párhuzamos kérést. Bekötve a főoldal, a Hírek, az Események, a DJ-k, a Szervezők és a Kiadványok fejlécébe/AppBarjába.
- A húzással történő frissítés és az ikon ugyanazt az erőltetett frissítést futtatja (`_refreshHome`, `_refreshNews`, `_refreshEvents`, `_refreshArtists`, `_refreshOrganizers`, `refreshNow`), így nem alakulhat ki eltérő viselkedés.
- Az Események/DJ-k/Szervezők/Kiadványok listák és a részletoldalak már eddig is a cache-ből rajzolódtak (a `WordpressHeadCache` a lemezen is tárol, és lejárat után előbb a mentett törzset adja vissza, majd háttérben revalidál).
- Kliensoldali változás: a következő AAB-build viszi.

### Cache TTL-politika — megjelenítés és frissítés szétválasztva (2026-09-18)

- Két külön útvonal: a **megjelenítés** (`forceRefresh: false`) mindig a rendelkezésre álló cache-t adja ki, kortól függetlenül, és csak háttérben revalidál; a **frissítés** (`forceRefresh: true`) a hálózatra vár.
- A `WordpressHeadCache` (ETag/HEAD) eddig is így működött: a 30 másodperces ablak után a mentett törzs azonnal kimegy, a revalidáció háttérben fut. Ezt a `test/services/wordpress_head_cache_test.dart` fedi.
- A perzisztens JSON cache (`_persistentCacheTtl`, 5 perc) viszont **eldobta** a lejárt értéket. Ez gyakorlatban a hír-kategóriákat érintette (a lista/chip 5 perc után hálózatra várt). Mostantól a lejárt érték is kimegy, és a TTL csak azt jelzi, hogy háttérfrissítés kell (`_persistentValueNeedsRefresh`).
- A `getStickyPosts` (Hírek „Kiemelt” sor) eddig minden megjelenítésnél erőltetett kérést indított; mostantól cache-first, `forceRefresh` paraméterrel a kézi frissítéshez.
- Az éles WordPress minden `/huhs/v1` végponton küld `ETag`-et, és a szerver maga is `Cache-Control: max-age=45, stale-while-revalidate=60`-at ad, ezért a lemezes cache valóban revalidálható, nem kell rövid élettartamot kényszeríteni.
- Teszt: `test/services/wordpress_cache_policy_test.dart` (lejárt érték kiszolgálása, frissítés-jelzés, sérült bejegyzés törlése, sticky- és kategória-megjelenítési út).
- Szándékosan nem módosítva: a `CommunityService` publikus profil-/achievement cache-e 24 óra után dobja el a mentett értéket. Ugyanaz az elv alkalmazható rá, de ott még nincs tesztfedezet, ezért külön körben érdemes.

### Képméretezés — Photon CDN, élesség megtartásával (2026-09-18)

- Kiindulás: a hírkártyák és a kis felületek (avatarok, jelvények) a WordPress **teljes** feltöltött képét kérték le. Éles mérés: egy 1024 px-es featured kép PNG-ben **1,5 MB**.
- A WordPress `?resize=` paramétere nem működik (a teljes fájlt adja vissza), a `-WxH` utótagos változatok pedig nem számíthatók ki megbízhatóan (404).
- A Jetpack **Photon CDN (`i0.wp.com`) viszont elérhető a site-hoz**, és formátumtartóan méretez: ugyanaz a kép 1024 px-en **365 KB**, 600 px-en 135 KB, 200 px-en 20 KB. A PNG tehát PNG marad (átlátszóság megmarad), nincs formátumváltás.
- Új `lib/core/images/wordpress_image_url.dart`: a kért szélesség mindig a **fizikai** pixelszélesség (`logikai méret × devicePixelRatio`), és sosem nagyobb, mint a hivatkozott forrásváltozat szélessége → nincs felnagyítás, nincs lágyítás.
- Új `lib/widgets/resized_network_image.dart`: a CDN URL-t kéri, és ha a CDN nem adja, egyszer visszaesik az eredeti WordPress URL-re, így az optimalizálás miatt egy kép sem tűnhet el. A memóriabeli dekódolási méret is a ténylegesen szolgáltatott szélesség.
- Bekötve: hírkártya (teljes és kompakt), kiemelt hírkártya, eseménykártya, achievement-jelvénykártya, toplista-jelvény, cikk-komment avatar, valamint a `CommunityService.optimizedImageUrl` (chat-, privát üzenet- és publikus profil-avatarok WordPress-hátterű képei).
- Éles ellenőrzés: `w=982` → pontosan 982×654 px (arány 1,502 a forrás 1,499-e helyett), `w=200` → 200×133 px, jelvénykép `w=112` → 112×112 px / 8 KB.
- **Szándékos döntés:** a listaképeknél nem kértünk 600 px-t, mert a kártya modern telefonon ~980–1100 fizikai pixel széles; ott a 600 px láthatóan lágy lenne. A nyereség a mérethelyes kérésből és a Photon újrakódolásából jön (1,5 MB → 0,37 MB ugyanazon a felbontáson), a kis felületeknél pedig 20–75×-ös adatcsökkenés.
- Teszt: `test/core/images/wordpress_image_url_test.dart`.
- Kliensoldali változás: a következő AAB-build viszi.

### Induláskori előtöltés — hírek és események a splash alatt (2026-09-18)

- Az app indulásakor eddig **csak** a saját profil és az adminadatok töltődtek elő (`CommunityService.preloadOwnProfile` / `preloadWordPressAdmin`, csak bejelentkezve), valamint az indulási üzenet. A hírek és az események lekérése a főoldal felépüléséig nem indult el.
- A főoldal mégis azonnali volt, mert a lemezes ETag-cache (cache-first) a mentett tartalmat azonnal kiadja. Friss telepítésnél viszont a 700 ms-os splash után megjelent a töltő, és meg kellett várni a hálózatot.
- Új `lib/services/public_content_warmer.dart`: a `main()` a `runApp` után azonnal elindítja a hírek + események lekérését, így az a **startup gate mögött** fut le. Mire a főoldal felépül, az adat már a cache-ben van, tehát az első indítás is tartalmat mutat.
- Nem generál plusz kérést: ugyanazokat a hívásokat indítja, amiket a főoldal providerei, és a szolgáltatás a folyamatban lévő kéréseket megosztja (`_postsInFlight`, `_eventsInFlight`).
- Hiba esetén a melegítés elnyeli a kivételt (az indulás nem törhet meg), a képernyők pedig maguktól újrapróbálnak.
- Teszt: `test/services/public_content_warmer_test.dart` (párhuzamos indítás, részleges és teljes hiba).
- Ez a megoldás a korábban felvetett csontváz-(skeleton) helyett készült el: nem szépíti a várakozást, hanem a splash alá rejti.
- Kliensoldali változás: a következő AAB-build viszi.

### Részletoldal-előtöltés görgetés közben (2026-09-18)

- Új `lib/widgets/detail_prefetch.dart`: a kártya 700 ms-ig a képernyőn marad, és csak akkor indítja el a részletadatok lekérését. Gyors elgörgetésnél a kártya eldobása törli az időzítőt, tehát **nem indul kérés** — csak arra a kártyára tölt elő, amin a felhasználó megáll.
- Bekötve a kártyákba (`NewsCard`, `FeaturedNewsCard`, `EventCard`, `_ArtistCard`, `_OrganizerCard`, `_ReleaseCard`), így minden lista automatikusan lefedett: hírek, kiemelt hír, események, DJ-k, szervezők, kiadványok.
- Nem generál plusz kérést: ugyanazokat a hívásokat indítja, amiket a részletoldal (`getPost`, `getEvent`, `getArtist`, `getOrganizer`, `getRelease`), a szolgáltatás pedig id szerint cache-el és deduplikál.
- A legnagyobb nyereség a hírrészletnél van: a lista csak összefoglalót hoz (`summary=true`, üres `content`), a teljes cikk a részletoldalon érkezik — ez most előre betöltődik.
- Hiba esetén néma (a részletoldal saját hibadoboza jelenik meg), és a widget nem nyúl a megjelenéshez.
- Teszt: `test/widgets/detail_prefetch_test.dart` (késleltetés, elgörgetéskor törölt kérés, néma hiba).
- Kliensoldali változás: a következő AAB-build viszi.

### WordPress szerveroldali cache — vizsgálat (2026-09-18)

- **Nincs szerveroldali cache.** A plugin `includes/http-cache.php` fájlja csak `rest_post_dispatch`-ben (tehát a válasz teljes összeállítása **után**) tesz `ETag`-et, `Cache-Control: public, max-age=45, stale-while-revalidate=60`-at és `Last-Modified`-et, majd az `If-None-Match` egyezésnél 304-et ad. A `max-age` kizárólag a kliensekre/proxykra vonatkozik, a WordPress munkáját nem csökkenti.
- Éles mérések: statikus kép **164 ms**, a főoldal HTML-je **279 ms**, a `/huhs/v1/*` végpontok viszont **1,0–1,6 s** minden kérése — `HEAD`-re is (200 + ETag), és a `max-age=300`-at deklaráló `/games/active` is ~1,1 s. Feltételes GET (`If-None-Match`) élesben **200**-at adott 304 helyett, de az app ezt kezeli (ETag-egyezés alapján a mentett törzset használja), így ez nem funkcionális hiba.
- **Következmény: a 45 s → 300 s emelés önmagában semmit nem javít a szerver terhelésén**, mert nincs mit hosszabbítani. Ami valóban segítene: (a) valódi szerveroldali válasz-cache (transient/object cache) a GET-végpontokra, a cache-elt törzsből számolt ETag-gal és `_huhs_revalidate` esetén megkerüléssel; (b) hosting/CDN szintű lapcache; (c) a végpontok N+1 lekérdezéseinek optimalizálása (ez a valódi gyökérök).
- A (a) pont elkészíthető pluginfrissítésként (a tulajdonos tölti fel); a döntés az övé, mert a TTL és a frissesség között tradeoff van.

### WordPress szerveroldali válasz-cache — elkészült (2026-09-18)

- A `HUHS Mobile API` plugin `includes/http-cache.php` fájlja mostantól **valódi szerveroldali cache-t** is tartalmaz a nyilvános, csak olvasható végpontokra (`/posts`, `/events`, `/releases`, `/artists`, `/organizers`, `/faq`, `/translations`, `/achievements/badges`).
- Működés: a felépített választ egy transient tárolja (`huhs_pc_<md5>`, kulcs = route + normalizált query, a `_huhs_revalidate` és `_` paraméter nélkül). A `rest_pre_dispatch` a cache-elt törzsből szolgál ki, saját ETag-gal; `If-None-Match` egyezésnél **304-et ad újrarenderelés nélkül**. A `rest_post_dispatch` (9998) menti a friss választ, a meglévő fejléc-logika (9999) változatlanul fut.
- Élettartam: `HUHS_PUBLIC_CACHE_TTL` = 120 s, és **minden tartalomváltozás azonnal invalidál** (`save_post`, `deleted_post`, `trashed_post`, `untrashed_post`, `edited_terms`, `created_term`, `delete_term`, valamint `huhs_` előtagú opciófrissítés — a számláló saját magára nem reagál, különben rekurzió lenne).
- **Szándékos döntés:** poszt-meta írásra NEM invalidálunk, mert a `pvc_view_post()` minden cikkmegtekintésnél metát ír — az minden olvasásnál ürítené a cache-t.
- Biztonság: csak GET, csak a nyilvános allow-lista (mindegyik `permission_callback => '__return_true'`, felhasználói kontextus nélkül), ezért cache-elt válasz nem szivároghat át látogatók között.
- Várható nyereség: az ismételt kérések (és az app ETag/HEAD revalidálása) ~1,2 s helyett ~50 ms.
- Csomag: `build/huhs-mobile-api-2.4.105.zip` (a tulajdonos tölti fel WordPress alatt); a forrás a `.tmp-api-24105/huhs-mobile-api/` munkamappában van (a `.tmp-*` gitignore-olt, ezért a következő verziót abból kell továbbépíteni).
- Ellenőrzés PHP nélkül: `.tmp-phpcheck/check.mjs` Node-alapú PHP-parser (`php-parser` npm csomag) — 39/39 fájl parse-olható; a csomag 40/40 fájlja bájt-azonos a forrással, a ZIP-bejegyzések `/` elválasztót és `huhs-mobile-api/` gyökeret használnak. ZIP SHA-256: `0074DA0C720C3E84BD53ED255BF68969B360EBC331844638907F4AF256BA77AC`.
- **Fontos tanulság:** a .NET `ZipFile.CreateFromDirectory` visszafelé perjelet ír a ZIP-bejegyzésekbe, ami WordPress alatt szétesik; a csomagot kézzel, `/` elválasztóval kell építeni.

### A WordPress boot-idő a valódi szűk keresztmetszet (2026-09-18)

- Párosított, azonos körülményű mérés (a hálózati zaj kiszűrésére): statikus kép **21–109 ms**, Jetpack Boost cache-ből jött főoldal 282 ms, **cache-busteres (valódi) főoldal ~2080 ms**, **nem létező REST útvonal 929–1243 ms**, `/posts` 1067–1293 ms.
- **A `/posts` és a 404-es REST út különbsége 6 mérés átlagában 74 ms** (szórás −98…+352 ms). Vagyis a ~1,2 s a **WordPress + pluginok bootja**, nem a HUHS végpont munkája.
- Következmény: **a szerveroldali válasz-cache plafonja ~74 ms (~6%)**, ezért nem hozott látható gyorsulást — a korábbi „1,2 s / végpont” mérés is boot-idő volt. A 2.4.105 cache a helyén maradhat (helyes, ártalmatlan, kevesebb DB-munkát jelent).
- A látható gyorsulás útja az **él-cache**: a plugin már küldi a `Cache-Control: public, max-age=45, s-maxage=45, stale-while-revalidate=60` + `ETag` fejléceket, így egy CDN vagy reverse-proxy külön munka nélkül kiszolgálhatja a `/wp-json/huhs/v1/*` GET válaszokat (~50–150 ms a ~1,2 s helyett).
- Cloudflare-dokumentáció szerint a CDN **nem cache-el, ha `Set-Cookie` van a válaszon**, és a JSON-t alapból nem cache-eli (Cache Rule kell). Ezért a **2.4.106** szerveroldalon cache-elhetővé teszi a válaszokat: `header_remove('Set-Cookie')` a nyilvános JSON-útvonalakon (a Facebook pixel `_fbp` sütije minden kérésnél új értéket kapott, és blokkolta volna a CDN-t), `s-maxage=45` hozzáadva, valamint a duplikált `Vary: Accept-Encoding,Accept-Encoding,Origin` normalizálva `Accept-Encoding, Origin`-re.
- Csomag: `build/huhs-mobile-api-2.4.106.zip` (SHA-256 `4AE112C02576E6D5590075DB4D0F9C0081AC17DB5FC3CD3A610F046B8D7FF6D1`), forrás: `.tmp-api-24106/huhs-mobile-api/`.
- **Él-cache beállításnál a cache-kulcsból ki kell zárni a `_huhs_revalidate` és `_` query paramétereket**, különben az app revalidálása minden alkalommal cache-miss lenne.
- A 2.4.106 éles ellenőrzése (2026-09-18): a `Set-Cookie` **eltűnt** mind az öt vizsgált JSON-végpontról, a `Cache-Control: public, max-age=45, s-maxage=45, stale-while-revalidate=60` mindenhol ott van, a tartalom és az ETag változatlan (nincs regresszió). A `Vary` normalizálás nem érvényesül teljesen (a WP CORS-logika és az openresty is hozzáfűzi a magáét), de ez a Cloudflare cache-kulcsát nem befolyásolja, ezért nem érdemes vele újabb kört csinálni.
- **Tulajdonosi döntés: az „A” út** — host-oldali microcache (nincs DNS-mozgatás, nincs e-mail-kockázat). A szolgáltatónak küldhető, konfigurációs vázlatot és ellenőrzési lépéseket tartalmazó dokumentum: `build/huhs-microcache-host-request.md`.
- Az él-cache bekapcsolása után ellenőrizendő: `X-Cache-Status`/`Age` a válaszokon, és a `/posts` válaszidő ~50–150 ms a mostani ~1,2 s helyett.
- Nyitott: a boot-idő gyökere (Jetpack? lassú DB? nincs perzisztens object cache?) — ehhez diagnosztikai mu-plugin kellene; ez az egész weboldalt gyorsítaná, nem csak az appot.

### Boot-idő mérés és korai cache-kiszolgálás (2026-09-18)

- A **2.4.107 diagnosztika** (csak a `huhs_diag=huhs-boot-probe-2026` paraméterre válaszol, `X-HUHS-Boot` fejlécben) éles mérése szerint egy `/posts` kérés (~870–1360 ms) így oszlik meg: **plugin-fájlok betöltése 513–811 ms**, `init` +130–180 ms, `rest_api_init` +155–185 ms, maga a végpont +66–180 ms; közben **97 adatbázis-lekérdezés** és **164 MB csúcsmemória** egy 10 KB-os JSON-hoz. A saját pluginunk fájlja a folyamat ~285–455 ms-ánál töltődik.
- Ezért a **2.4.108** kiszolgálja a cache-elt választ **már a saját pluginfájl betöltésekor** (`huhs_try_serve_public_cache_early()` a `http-cache.php` végén), mielőtt a többi plugin betöltődne és mielőtt bármely `init`/REST callback lefutna. Csak GET/HEAD, csak a nyilvános allow-lista útvonalaira; minden más kérés egyetlen `strpos`-szal tér vissza. GET-re a cache-elt JSON-t küldi, HEAD-re csak a fejléceket (az app revalidálása HEAD-es), `If-None-Match` egyezésre 304-et.
- A cache-elt válasz fejlécei is tárolódnak (`headers`), így a korai válasz azonos a REST-ével; a `Set-Cookie` és a hop-by-hop fejlécek kimaradnak.
- Új diagnosztikai fejléc: **`X-HUHS-Cache: early|memory|fresh`** — ebből kiderül, melyik réteg szolgált ki (early = pluginbetöltéskor, memory = REST-réteg cache, fresh = most renderelte a végpont).
- Várható eredmény: ~0,9–1,4 s helyett **~0,3–0,5 s** cache-elt kérésre (host, CDN és app-módosítás nélkül).
- Ha a mérés azt mutatja, hogy a fejléc mindig `fresh`, akkor a transient cache nem perzisztál ezen a hoston → akkor fájl-alapú cache-re kell váltani (wp-content/uploads), ez a következő lépés.
- További lehetőség (ha kell): mu-plugin drop-in, ami még a plugin-fájlok betöltése előtt kiszolgál (~0,15–0,25 s), de ez egy új, minden kérésnél lefutó fájl, ezért külön döntést igényel.
- Csomag: `build/huhs-mobile-api-2.4.108.zip` (SHA-256 `09B8FF5E9CBA63ACE5BB124EB648C88782C4AEB189150941DDC11A8717BF7F33`), forrás: `.tmp-api-24108/huhs-mobile-api/`.
- **Éles mérés a 2.4.108 után (2026-09-18): működik.** `/posts` hidegen 1478 ms (`fresh`), ismételve **431–438 ms (`early`)**; `HEAD` + `If-None-Match` → **304, 495 ms (`early`)**; a `_huhs_revalidate` paraméterrel is `early` (507 ms); `/faq` hidegen 1229 ms, ismételve **450 ms**; a statikus kép 20–40 ms ugyanabban a körben, tehát a nyereség valódi (~3×).
- A korai válasz tartalma **szemantikailag azonos** a friss válasszal (11 elem, azonos címek/ID-k/kategóriák, mezők; normalizált JSON-összehasonlítás egyezik), és **az ETag ugyanaz** — csak a JSON-kódolás más (WP escape-el, a cache-elt `json` nem), ezért a byte-hossz eltér (11071 vs 9689). Az app ETag-alapú revalidálása emiatt zavartalanul működik a két út között.
- Ismert, szándékos tradeoff: a `_huhs_revalidate` paraméter a cache-kulcsból ki van zárva, ezért a kézi frissítés is a cache-ből szolgálható ki (max. 120 s régi tartalom), **de tartalomváltozás azonnal invalidál**. Ha a tulajdonosnak a kézi frissítésnél is garantáltan friss kell, egy kis kiegészítéssel a GET + paraméter megkerülheti a cache-t (a HEAD revalidáció maradna gyors).
- A padló a mi pluginfájlunk előtt betöltődő pluginok (~0,28–0,45 s). Opcionális továbblépés: mu-plugin drop-in, ami még ezek előtt kiszolgál (~0,15–0,25 s), de az egy új, minden kérésnél lefutó fájl — külön tulajdonosi döntést igényel.
- **Tulajdonosi döntés (2026-09-18): a mu-plugin drop-in NEM készül el**, a 2.4.108 korai kiszolgálás így marad. A szerveroldali gyorsítás ezzel lezárva; a további nyereség a boot-idő gyökerének feltárásából jöhetne (az egész weboldalra), de az külön vizsgálat.
- Újra-ellenőrzés (2026-09-18): `HEAD /posts` három egymást követő mérése egyaránt `HTTP/1.1 200 OK` + `X-HUHS-Cache: early`, a GET ~600 ms ugyanabban a hálózati ablakban — a korai kiszolgálás stabilan él. Ez a javítás szerveroldali, ezért **már a jelenleg kiadott appban is érvényes**, nem kell hozzá új AAB.

### Következő folytatandó feladat — teljes cache-first adatbetöltés

- Minden hálózatról vagy Firebase-ből letöltött adatnál a korábbi állapot azonnal legyen látható.
- A menüpont megnyitásakor induljon háttérfrissítés; sikeres válasznál frissüljön a cache és a képernyő.
- Következő appindításkor is maradjon meg a legutóbbi adat, ne legyen üres lap vagy felesleges töltőképernyő.
- Érintett területek: hírek, események, DJ-k, szervezők, kiadványok, játékok, toplisták, ajánlások, kommentek, chat, profilok és adminadatok.
- Hibánál a használható korábbi cache maradjon látható; fiókváltáskor UID-kötötten ne keveredjenek az adatok.
- A profil cache-first javítás már elkészült; a teljes többi adatbetöltési láncot a következő munkamenetben kell végigvezetni és tesztelni.

### Következő fejlesztési feladat — külön WordPress nyereményjáték-rendszer

- A Kvíztől külön menüpont és adatmodell legyen a WordPress HUHS API-ban.
- Kezelje a kérdést, 3–5 választ, a helyes választ, a kezdési és befejezési időt, valamint a nyeremény típusát és leírását.
- Csak regisztrált felhasználó játszhasson; a válasz, eredmény és részvétel szerveroldalon, egyszer játszhatóan tárolódjon.
- A sorsolás a játék lezárásakor szerveroldali, véletlenszerű és idempotens legyen.
- A nyertes appos notify-t és e-mailt kapjon a nyereményről és a kapcsolatfelvételről (`info@hungarianhardstyle.hu`).
- A főoldalon a Kvíz felett jelenjen meg kép; lezárás után a beállított ideig csak a nyertes felhasználóneve, a nyeremény és a gratuláció látszódjon.
- A résztvevői e-mail-címek csak a játék és a sorsolás/értesítés idejére maradjanak meg, majd automatikusan törlődjenek; username, részvétel és eredmény anonimizálás nélkül, de e-mail nélkül megőrizhető.

### Tartós munkamenet-jegyzet — 2026-09-04

- Profil törlés után a kliens törli a jelenlegi felhasználóhoz kötött profil-, achievement-, admin- és WordPress-cache állapotot, a helyi kedvenceket és biztonsági/token adatokat, majd kijelentkezik és a Kezdőlapra vált.
- Ismerős-jelölés elfogadásakor a jelölő Notification-bejegyzést és push értesítést kap; a Firebase `notifyConnectionRequest` trigger élesítve van, determinisztikus duplikációvédelemmel.
- Push értesítés elfogadáskor az elfogadó profiljára navigál; az appoldali változás a következő APK/AAB buildben érvényesül.
- A hírek-, DJ- és szervezőkeresés API-válaszait a kliens valódi szöveges egyezéssel is szűri, ezért értelmetlen keresés nem adhat hamis találatot.
- A projekt tartós „second brain” forrásai: ez az `AGENTS.md`, a gyökér `README.md`, valamint a Graphify-index (`graphify-out/`). Működő funkciót és meglévő menüpontot célzott javítás miatt sem szabad regressziósan eltávolítani.

### Aktuális build: +225 (1.0.0) — AAB a zárt tesztbe feltöltve, felülvizsgálatra beküldve

- A +225 AAB elkészült és a Play zárt tesztébe feltöltve; a Play automatikus ellenőrzései még folyamatban lehetnek.
- Billing-javítások: megosztott folyamat-szintű listener, tartós pending-event kezelés, kontrollált acknowledgement-újrapróbálás, valamint szerveres purchase-token tulajdonjog-ellenőrzés.
- Ellenőrzések sikeresek: Flutter tesztek 47/47, `flutter analyze --no-pub`, `node --check functions/index.js`, `git diff --check`.

### Következő ellenőrzések

- Playből telepített builden végponttól végpontig ellenőrizni a vásárlást, visszaállítást és letöltést.
- Ingyenes kiadványoknál Billing-hiány státusz ne jelenjen meg; a fizetős Billing-útvonal változatlan maradjon.
- Nyitott: Play-vásárlási export egyeztetés, értesítések, AdMob és natív HUHS API-admin futásidejű auditja.

- A `build/app/outputs/bundle/release/app-release.aab` a kért versionCode 223-mal elkészült.
- A +223 AAB a Play Console zárt teszt kiadásába feltöltve, 100%-os terjesztésre beállítva és felülvizsgálatra beküldve; a magyar change log bekerült.
- A +223 AAB SHA-256 ellenőrzőösszege: `83F6940DE9285B3F029EF8B73ED4BABCFFF6E893B90531515ED97F6C1BBCF890`.
- A Firestore-szabályok és az esemény-/meetup-pontozó Firebase-funkciók élesek; meetup-kapcsolat törlésekor a +15 pont visszavonódik.
- A Label Billing kliens batch-lekérdezés után minden hiányzó product ID-t egyenként is lekérdez, az egyetlen ID-s release sem marad ki, és átmeneti Billing-hibánál is automatikus újrapróbálás fut.
- A chatben a bekapcsolható achievement-megjelenítés a feltöltött jelvénygrafikát is mutatja a név mellett, egy sorban; a publikus achievement-lekérdezés UID szerint gyorsítótárazott.
- A `getPublicAchievement` Firebase callable élesítve van. A Play-termék megjelenését az app nem hamisítja: csak a Billing által ténylegesen visszaadott termék vásárolható.

### Következő build — ingyenes kiadvány Play-termék státuszának elrejtése

- Az ingyenes kiadványokhoz nem tartozik Google Play Billing-termék; ezeknél ne jelenjen meg a „Play-termékazonosító nem érkezett meg” hiba vagy más Billing-várakozási státusz.
- Az ingyenes kiadványok maradjanak elérhetők a saját WAV-/külső linkes feloldási útvonalukon, a fizetős release-ek Billing-kezelése változatlanul működjön.

### Aktuális Play-build: +211 — zárt Alpha tesztbe felülvizsgálatra beküldve

- A +211 AAB elkészült és a Play Console zárt Alpha csatornájába feltöltve, majd felülvizsgálatra beküldve.
- A +211 tartalmazza a release-termékek friss WordPress-lekérdezését, a Billing-lekérdezés hiányzó termékekre és hibákra kezelhető újrapróbálását, valamint az achievement/jelvény mobilapp-felületét.
- A change log a Play Console-ban rögzítve; a Play gyorsellenőrzése még folyamatban van.

### Aktuális Play-build: +191 — zárt Alpha tesztbe felülvizsgálatra beküldve

### Következő tervezett funkció — Achievement- és jelvényrendszer

- A tulajdonos készíti és tölti fel a jelvénygrafikákat; automatikus vagy AI-jelvénygenerálás nem része a funkciónak.
- Minden felhasználó 0 pontnál alapjelvényt kap; a magasabb rangok ne legyenek gyorsan kifarmolhatók.
- A jelvénykatalógus WordPress-adminból kezelendő, a pontledger és az összesített felhasználói állapot Firebase-ben marad.
- Pontot csak szerveroldali, idempotens művelet adhat; a kliens nem küldhet szabadon pontértéket vagy rangot.
- A részletes terv a `docs/ACHIEVEMENTS_DESIGN_HU.md` fájlban van. A GYIK frissítése csak a végleges, működő implementáció után történjen.

### Achievement-rendszer — jelenlegi állapot

- A mobilapp saját és nyilvános profilnézetében megjelenik a pontszám és a szerver által adott jelvény; hiányzó adatoknál a 0 pontos „Kezdő ütem” alapállapot látszik.
- A Firebase `hungarian-hardstyle` projektben élesítve vannak a részvétel-, Meetup-, hír-like- és profilkitöltés-pontozó triggerei.
- A pontozás `achievement_ledger` idempotens bejegyzésekkel működik; a kliensoldali profilmentés nem írhat pontot vagy ledger-adatot.
- A HUHS Mobile API-hoz elkészült a `build/huhs-mobile-api-achievements-20260829.zip` csomag, benne a HUHS Mobile → Achievementek adminoldallal, médiatár-választóval és a `/huhs/v1/achievements/badges` végponttal.
- A jelvénygrafikákat a tulajdonos tölti fel; az app és a backend nem generál véletlenszerű vagy AI-jelvényt.
- A pontforrások és jelvények FAQ-tervezete frissítve; az élő WordPress GYIK a csomag telepítése után ellenőrizendő.

- A `build/app/outputs/bundle/release/app-release.aab` elkészült; a Play Console a tényleges versionCode 191-et elfogadta.
- A +189 tartalmazza a hír-like javítását: saját like visszavehető, más user like-ja megmarad, nincs 4/5 darabos korlát.
- A korábbi hír-like reakciódokumentumok törölve lettek, az új Firestore-szabályok élesítve.
- A helyi ellenőrzések sikeresek: `flutter test` (39/39), `git diff --check`; az analyze csak egy korábbi, ettől független információs lintet jelez.
- A +191 a Play Console zárt Alpha csatornájába feltöltve és felülvizsgálatra beküldve.
- A Play gyorsellenőrzései még futnak; a Play „Közepes” optimalizálási mutatója feldolgozás után ellenőrizendő.
- A +191 a +190 javításaira épülő új technikai versionCode; a kiadás a zárt Alpha csatornában gyorsellenőrzés alatt áll.
- Az eseménybeküldés utáni admin-push javítva, élesítve és tulajdonosi teszttel visszaigazolva: a `submitWordPressContent` most a privát `private_user_data/{uid}` tokeneket is feloldja, nem csak a régi publikus mezőt.

### Lezárt Play-katalógus probléma — Freak release

- A WordPress release `12327` helyes árai: `radio_wav` 700 Ft, `radio_mp3_320` 550 Ft, `extended_wav` 700 Ft, `extended_mp3_320` 550 Ft.
- A hiba oka bizonyítva: az egyedi termékeket a Function a `batchUpdate` végponton küldte, amely ezeknél HTTP 500 `backendError` választ adott.
- A javított Function a dokumentált `monetization.onetimeproducts.patch` upsert végpontot használja `allowMissing=true` mellett; deploy után a Freak megvásárolható termékei létrejöttek.
- A `2025/03` régióverzió, a determinisztikus product-ID-k és a WordPress-ID-visszaírási folyamat megmaradt; ezt a működő megoldást nem szabad visszacserélni per-product `batchUpdate`-re.
- A 700/550 Ft célárakat minden új release-nél Play-visszaolvasással kell ellenőrizni; a WordPressben tárolt ár önmagában nem bizonyítja a magyar vevői végösszeget.

### Label Billing kliensvédelme — jövőbeli release-ek

- A Play-katalógusban létrejött új termékek rövid ideig részlegesen vagy üresen érkezhetnek vissza a Billing-lekérdezésből; ezt a kliens nem tekintheti azonnal végleges „nem érhető el” állapotnak.
- A `LabelPurchaseService.loadProducts` öt, fokozatosan hosszabbodó tömbös lekérdezést végez, majd a hiányzó ID-ket egyenként is lekéri; a már megtalált termékeket mindig megtartja.
- A 12353-as release négy terméke a javított szinkron után 700/550/700/550 áron `status: ok` eredménnyel szinkronizálódott, ezért ezt a Play- és WordPress-oldali szerződést minden jövőbeli release-nél meg kell őrizni.

### Következő build: még nincs kijelölve; nyitott pontok

- Play Console „Közepes” optimalizálási mutató kivizsgálása az új AAB feldolgozása után.
- A +190-ben a „bazd meget” és „baszd meget” alakok szűrése célzottan javítva, teszttel lefedve.
- A push-tokenek új verzióban a `private_user_data/{uid}` dokumentumba kerülnek; a szabályok és a két push Cloud Function élesítve. A régi profil-tokenek átmeneti fallbackként megmaradtak.
- Az igazoltan nem használt `cupertino_icons` közvetlen függőség eltávolítva; működő funkcióhoz nem nyúlt.
- Működő AdMob-, like-, chat- és egyéb útvonalakhoz nem szabad hozzányúlni, kivéve ha a célzott javítás bizonyíthatóan szükségessé teszi.
- A +189 Playből telepített futásidejű ellenőrzése megtörtént; a mutató ellenőrzése továbbra is nyitott.
- AdMob-audit: az éles alkalmazás 613 kérést és 63 megjelenést mutat (13,87% egyezési arány), tehát a kérések eljutnak az AdMobhoz; az AdMob-fiókban kifizetési ellenőrzési figyelmeztetés és „Véleményezést igényel” állapot látszik. Az Irányelvközpont nem jelez hirdetéskorlátozást.

### +174 — Play-optimalizálás biztonságos javítása

- Az R8 Configuration Analyzer alapján felül kell vizsgálni a 36%-os optimalizálási, obfuszkálási és csökkentési mutatót.
- Csak bizonyítottan túl széles keep-szabályokat szabad szűkíteni; a WorkManager/Room, Firebase, AdMob és Billing működése nem romolhat.
- A Flutter natív AOT-kódját és a működő útvonalakat nem szabad kockázatosan módosítani.
- Erőforrás- és függőségcsökkentés csak használati bizonyíték alapján végezhető.
- A változtatások után kötelező a Flutter teszt, release-build, indulási/regressziós ellenőrzés és az új AAB Play-feldolgozása utáni mutató-ellenőrzés.

### Történeti Play-build: +173 — korábbi zárt Alpha kiadás

- A `build/HUHS-v1.0.0+173-release.aab` elkészült, a belső versionCode 173.
- A +173 tartalmazza a privát üzenetek partner-avatarját, a becenévprofil-megnyitást, a beszélgetés- és saját üzenettörlést, valamint a privát beszélgetésből indítható blokkolást.
- A Firestore-szabályok élesítve lettek a `hungarian-hardstyle` projekten; a saját üzenet törlése és a résztvevői beszélgetéstörlés szerveroldalon védett.
- `flutter test`: 29/29 sikeres; `flutter analyze --no-pub`: csak egy korábbi, ettől független konstruktor-lint információ maradt; `git diff --check` sikeres.
- A Play Console visszaigazolta: a +173 zárt Alpha kiadás felülvizsgálatra elküldve. A Play gyorsellenőrzése még folyamatban lehet.

### +173-ban lezárt Chat és privát üzenet javítások

- A Chat composer fekvő/álló elágazása most a tényleges készülék-orientációból dönt, nem a billentyűzet felnyílásakor változó LayoutBuilder-magasságból; így a billentyűzet megnyitása nem ejti el a fókuszt.
- A privát beszélgetés első megnyitása már nem próbálja olvasni a címzett tiltási listáját; a kölcsönös tiltást a Firestore üzenetszabály ellenőrzi.
- A privát beszélgetés dokumentumának saját UID-t tartalmazó, még nem létező azonosítója olvasható az üres beszélgetés megjelenítéséhez; az üzenetek továbbra is csak tényleges résztvevőknek olvashatók.
- A Firestore-szabályok élesítve lettek a `hungarian-hardstyle` projekten; az új kliens build elkészült és a Play zárt Alpha tesztébe felülvizsgálatra be lett küldve.

### +172 — történeti Play-build

> Ez a blokk az aktuális állapot. Az alábbi +164–+171 részek történeti naplók; azok „ellenőrizendő” pontjai nem aktuális feladatok.

- Tulajdonosi visszajelzés alapján a +172 helyes AAB-ja feltöltve és működőként visszaigazolva.
- Ellenőrzöttként lezárva: Chat billentyűzet, privát üzenetek, Billing, ingyenes kiadványok, release-kártyák, Közösség/profil és események.
- AdMob banner: a viewportból kikerülő hírszűrő-listaelem már megtartja a betöltött banner állapotát, így visszagörgetéskor nem semmisül meg és nem indul újra véletlenszerűen. A production Banner/Rewarded azonosítók felcserélését build-time ellenőrzés akadályozza meg; `flutter analyze`, 29/29 Flutter-teszt és helyi release APK build sikeres. Playből telepített új builden a tulajdonosi ellenőrzés még szükséges.
- Emulátoron reprodukált ok: az AdMob `format mismatch` (`Ad failed to load: 3`) hibát ad, mert a +172 buildben a banner és a rewarded production azonosítója fel volt cserélve. Az AdMob konzol szerinti helyes párosítás beépült a Gradle release-ellenőrzésébe: Banner `ca-app-pub-7714662594685378/5219184964`, Rewarded `ca-app-pub-7714662594685378/5286829694`; felcserélt azonosítóval a release build leáll. Új build és emulátoros/Play-ellenőrzés még szükséges.
- Nyitott: AdMob Play-beli stabilitásának tulajdonosi visszaellenőrzése és a Play Console „Közepes” optimalizálási mutatója.
- A további készülék-/gyártó-kompatibilitás nem nyitott kiadási akadály; ezt a nyílt tesztben kell figyelni.

### +171 — production AAB helyben elkészült

- A következő szabad versionCode-ra épített production AAB elkészült: `build/HUHS-v1.0.0+171-release.aab`.
- A +171 ugyanazt a stabil AdMob banner-javítást tartalmazza; a production App/Banner/Rewarded azonosítók megmaradtak.
- `flutter analyze --no-pub`, `flutter test` (29/29) és `git diff --check` sikeres.
- A +171 AAB a Play Console zárt Alpha tesztcsatornájában elérhető, 100%-os közzététellel és 19 081 támogatott eszközzel.
- A Play Console állapota: a kiválasztott tesztelők számára hozzáférhető; a Play „Közepes” optimalizálási mutatója az AAB feldolgozása után továbbra is külön ellenőrzendő.

### +170 — production AAB feltöltve és felülvizsgálatra beküldve

- A `build/HUHS-v1.0.0+170-release.aab` a Play zárt Alpha tesztcsatornájába feltöltve és felülvizsgálatra beküldve.
- A Play Console státusza: „Felülvizsgálat alatt álló módosítások”; a gyors ellenőrzések még futhatnak.
- A kiadás kibocsátási megjegyzése: AdMob, Chat és privát üzenet hibajavítások.

### +169 — korábbi production AAB

### +169 — production AAB elkészült és beküldve

- A production AAB elkészült: `build/HUHS-v1.0.0+169-release.aab`; versionCode 169.
- A +169 a privát üzenetek újranyitható menüjét és a címzettnek küldött push értesítést tartalmazza.
- `flutter analyze --no-pub`, `flutter test` (29/29) és `git diff --check` sikeres.
- A Play Console zárt teszt Alpha kiadásába feltöltve, majd felülvizsgálatra beküldve; a módosítások jelenleg felülvizsgálat alatt állnak.
- A Play „Közepes” optimalizálási mutatója az új AAB feldolgozása után ellenőrizendő.

### +168 — production AAB elkészült

- A +168 production AAB elkészült: `build/HUHS-v1.0.0+168-release.aab`; versionCode 168.
- A korábbi production AdMob App/Banner/Rewarded azonosítók az aláírt AAB-ban ellenőrizve.
- A változtatás az ingyenes kiadvány „Radio verzió” feliratának elrejtése; normál release-megjelenítés változatlan.
- A Play zárt tesztbe feltöltés és a Play Console „Közepes” mutatójának újraellenőrzése még hátra van.

### +167 — production AAB elkészült, optimalizálás alkalmazva

### Kiemelt biztonsági javítás — felhasználóhoz kötött Label-jogosultságok

- A Label-vásárlások és a reklámért kapott feloldások kizárólag a Firebase-felhasználó UID-jához tartozhatnak; készülékhez vagy megmaradt lokális képernyőállapothoz nem.
- A `free_wav` letöltés többé nem érhető el névtelenül: az ingyenes kiadvány WAV-ja is csak az adott felhasználóhoz tartozó, sikeres reklámos feloldás után adható ki.
- A reklámos feloldás változatonként (`free_wav` / `mp3_128`) kerül tárolásra; a régi, változat nélküli feloldások csak a korábbi `mp3_128` jogosultságként maradnak kompatibilisek.
- A Google Play-vásárlási token nem köthető hozzá másik Firebase-felhasználóhoz; az ellenőrző végpont eltérő UID esetén megtagadja az átadást.
- Fiókváltáskor a kliens törli az előző felhasználó feloldási és vásárlási állapotát, majd az új UID-re tölti vissza az állapotot.
- A négy Firebase-funkció élesítve: `getLabelDownloadUrl`, `getLabelAdUnlockStatus`, `admobRewardedSsv`, `verifyLabelPurchase`.
- Lokális ellenőrzés sikeres: `flutter analyze`, 29/29 Flutter-teszt, `git diff --check`, `node --check functions/index.js`. Új kliens build és Playből telepített, két külön felhasználós végponttól végpontig teszt még szükséges.

### Történeti következő build — ingyenes kiadvány opcionális külső linkje

- Az ingyenes kiadványhoz opcionális `free_external_link` mező került a WordPress API-ba és az admin felületre; például Hypeddit-link adható meg.
- A link csak ingyenes kiadványnál jelenik meg, reklámos `free_link` feloldás után nyitható meg, és a feloldás Firebase UID-hoz kötött.
- Ehhez nem készül és nem jelenik meg WAV; az ingyenes WAV-letöltés külön, változatlan `free_wav` útvonal marad.
- A normál release 128 kbps MP3 reklámos útvonala változatlan.
- Elkészült a WordPress API `build/huhs-mobile-api-2.4.55.zip` csomag; működő útvonalakat nem módosítottam. Kliens build és Playből telepített ellenőrzés még szükséges.
- Ingyenes kiadványnál az „Elérhető változatok” listából kikerült a „Radio verzió” felirat; a normál release-ek megjelenítése változatlan.

- A +167-ben a Flutter asset-bundből kikerült a nem használt `assets/icons/` könyvtár; a forrásfájlok megmaradtak, működő funkció nem változott.
- Az R8 teljes módja, a kód-/erőforrás-csökkentés és az osztály-újracsomagolás már korábban aktív volt; túl széles keep-szabályt nem módosítottunk a WorkManager/Room indulás védelme miatt.
- `flutter analyze --no-pub`, `flutter test` és `git diff --check` sikeres; a production AAB: `build/HUHS-v1.0.0+167-release.aab`.
- A Play zárt tesztbe feltöltés ebben a munkamenetben még nincs végrehajtva. A „Közepes” Play Console-mutató az AAB feldolgozása után ellenőrizendő.

### +166 — production AAB elkészült, emulátoron ellenőrizve

- A production AAB elkészült: `build/HUHS-v1.0.0+166-release.aab`; versionCode 166. A korábbi production AdMob App/Banner/Rewarded azonosítók az AAB-ban ellenőrizve.
- Android 15 emulátoron a production release APK elindult, a főképernyő megjelent, a folyamat futva maradt; R8/WorkManager/Room indulási hiba nem jelentkezett.
- A hír-like mentés emulátoron ellenőrizve: a kedvelésszám változott, és nem jelent meg reakciómentési vagy Firestore jogosultsági hiba.
- A Play zárt tesztbe feltöltés ebben a munkamenetben még nincs végrehajtva; a Play Console optimalizálási mutatója csak a feldolgozás után ellenőrizhető.

### +165 — rögzített javítás, AAB elkészült

- A production AAB elkészült: `build/HUHS-v1.0.0+165-release.aab`; versionCode 165. A production AdMob App/Banner/Rewarded azonosítók a korábbi release-konfigurációból visszaállítva és az AAB-ban ellenőrizve.
- `flutter analyze --no-pub`, Gradle release build és `git diff --check` sikeres. A Play zárt tesztbe feltöltés még nincs végrehajtva, mert az interaktív Play Console-vezérlés ebben a munkamenetben nem csatlakozott.

### +166 végrehajtási ellenőrzés

- Play Console „Alkalmazásoptimalizálás: Közepes”: az R8 osztály-újracsomagolása és a szükséges keep-szabályok a +166-ban beépítve; az optimalizálási mutató az új AAB feldolgozása után ellenőrizendő.
- +165 indulási crash: a WorkManager/Room `WorkDatabase` keep-szabálya a +166-ban megmaradt; production release APK-ból emulátoron az indulás ellenőrizve.
- Helyi állapot: az R8 osztály-újracsomagolása bekapcsolva (`-repackageclasses ''`, `-allowaccessmodification`), a WorkManager/Room keep-szabályok megmaradtak. A +166 release APK emulátoros indulása ellenőrizve; a Play optimalizálási mutató csak az új AAB feldolgozása után zárható le.
- Hír-like mentés: a reakciódokumentum merge-elt írást használ, a Firestore szabály pedig create és update esetén külön kezeli a meglévő extra mezőket; a szabály élesítve és a +166 production APK-val emulátoron ellenőrizve.

### +167 — ellenőrzés és szükség szerinti javítás

- Play Console „Alkalmazásoptimalizálás: Közepes” mutató kivizsgálása az új AAB feldolgozása után.
- Ellenőrizni, hogy az R8 teljes mód, kód- és erőforráscsökkentés, obfuszkáció, valamint az osztályok újracsomagolása ténylegesen érvényesül-e.
- R8-riportok alapján megkeresni a túl széles `keep` szabályokat és a felesleges Android/Flutter függőségeket vagy erőforrásokat; csak biztonságos, regressziómentes javítás alkalmazható.
- A Flutter AOT/native kód arányát figyelembe venni: a Play-mutató javulása nem garantálható pusztán újabb Gradle-kapcsolóval.
- Ha indokolt és biztonságos, Startup Profile és további méret-/teljesítmény-optimalizálás beépítése.
- Új AAB készítése után Play Console-ban ismét ellenőrizni a mutatót; a meglévő működő funkciók és az indulás nem romolhatnak.
- Regressziós alapelv: működő funkciót nem szabad elrontani vagy önkényesen módosítani; minden +167-es optimalizálás után a meglévő működéseket vissza kell ellenőrizni.
- Ingyenes kiadvány WAV-letöltés: a WordPress API `2.4.54` csomagban a `free_wav` variáns külön kezelést kapott, az `is_free` ellenőrzés kompatibilisebb lett, és a régi/új WAV-metaútvonalak fallbackje is bekerült. Feltöltés után Playből telepítve ellenőrizendő.
- Ingyenes kiadvány adatlapján a Billing-terméklista üres lekérdezése letiltva; a fizetős kiadványok termékbetöltése változatlan. Új APK/AAB után ellenőrizendő, hogy a hamis terméklista-hiba eltűnt.
- Ingyenes `free_wav` letöltésnél a Firebase callable vendég/névtelen kérést is elfogad; a fizetős és reklámos MP3-változatok hitelesítése és jogosultság-ellenőrzése változatlan. A `getLabelDownloadUrl` Firebase-funkció élesítve, a WordPress WAV-token végpont a 12242-es kiadvánnyal ellenőrizve.
- Következő build: ingyenes kiadványhoz opcionálisan külső feloldási link is megadható legyen (például Hypeddit). Ez a link ne generáljon és ne kínáljon WAV-ot; reklám megtekintése után váljon elérhetővé. A meglévő ingyenes WAV- és normál 128 kbps MP3-útvonal változatlan maradjon, regressziót külön ellenőrizni kell.

### További, később rögzítendő feladatok

- Ingyenes kiadvány letöltése: a letöltött hangfájl WAV legyen, ne 128 kbps MP3; a módosítást Playből telepítve is ellenőrizni kell. Ez csak az ingyenes kiadványra vonatkozik; a normál release marad 128 kbps MP3 reklámért.
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

### +164 — végrehajtási állapot

- A fő Label-lista már kiszűri az `is_free` kiadványokat; az ingyenesek külön „Ingyenes kiadványok” nézetben maradnak. Playből telepített +164-es ellenőrzés szükséges.
- Az ingyenes kiadványok kártyája most már a WordPress API-ból érkező borítóképet jeleníti meg, az adatlap borítóképes nézete megmaradt; `flutter analyze` sikeres, teljes futásidejű ellenőrzés még nincs.
- A release-kártyák hosszú című megjelenítési javítása helyben elkészült: álló és fekvő nézetben is ugyanaz a fix magasságú fekvő listaelrendezés fut, a cím legfeljebb két soros. Playből telepítve még ellenőrizni kell.
- Az ingyenes kiadvány feloldása és letöltése Playből telepítve működik; ez a +164-ben tulajdonos által visszaigazolt.
- A Közösség főmenübe bekerült a Kedvencek és a Hírlevél; a „Több” menüben nem maradtak külön menüpontként. +164-ben ellenőrizendő.
- A Hírlevél a Közösség menüben megmaradt, és kikerült a saját felhasználói profil read-only és szerkesztési nézetéből; futásidejű ellenőrzés még nincs.
- Az AdMob banner betöltési útvonala kódoldalon javítva: a consent és az SDK inicializálása folyamat-szinten egyszer fut, az elavult/párhuzamos kérések kiesnek, a sikertelen betöltés 5 másodperc után kontrolláltan újrapróbálkozik; Playből telepítve a tényleges betöltés még ellenőrizendő.
- A telefonos és kompatibilitási tesztek utólagos validációk, nem blokkolják a +164 cél elérését.
- Release AAB: `build/HUHS-v1.0.0+164-release.aab`; statikus ellenőrzések sikeresek. A Play zárt tesztbe feltöltve, 100%-os kiadásként beküldve; a gyorsellenőrzés/felülvizsgálat még folyamatban.

### +163 helyi állapot — 2026-08-18

- A +163-ben kért alkalmazásoldali javítások és regressziókezelések helyben beépítve; Android 15 Pixel emulátoron a rendszer-visszagomb, a kezdőlapi kilépési kérdés, a kilépés utáni task-eltávolítás, a fekvő Chat és a kijelentkezett Chat-avatar ellenőrizve.
- A hosszú release-címek kártyaméretezése egységesítve, az ingyenes kiadvány `is_free` modelltesztjei bekerültek.
- `flutter analyze`: sikeres; `flutter test`: 29/29 sikeres; `git diff --check`: whitespace-hiba nélkül.
- A +163 production AAB elkészült: `build/HUHS-v1.0.0+163-release.aab` (73.8 MB), a korábbi +161 production AdMob-konfiguráció visszaállított azonosítóival és release-aláírással. A Play Console zárt tesztcsatornájába feltöltve és felülvizsgálatra beküldve; jelenleg „Felülvizsgálat alatt álló módosítások”.
- Az ingyenes kiadványok UI-ja és explicit API-mezője elkészült; a WordPress `huhs-mobile-api-2.4.53` csomagban az „Ingyenes kiadvány” jelölő és a külön médiafeltöltő mező bekerült, az API élesben telepítve és a `/wp-json/huhs/v1/releases` végponton `is_free` mezővel ellenőrizve.
- A telefonos és kompatibilitási tesztek utólagos tulajdonosi validációk; ezek nem blokkolják a +163 cél elérését vagy a release-folyamatot.

### +163 — végrehajtási állapot

- A +163 feltöltött alkalmazásoldali feladatköre elkészült; a +163 után az ingyenes kiadványok főlistából való kizárása külön +164 javításként került rögzítésre.
- Ellenőrizve: `flutter analyze`, 29/29 Flutter-teszt, `git diff --check`, valamint Android 15 Pixel emulátoron a visszagomb teljes útvonala.
- A +163 release-feltöltés kész; ezt a telefonos/kompatibilitási teszt nem blokkolta.
- Utólagos ellenőrzés: Playből telepített ingyenes kiadvány-letöltés, Play Console „Közepes” optimalizálási mutató újraellenőrzése és a további tulajdonosi készüléktesztek.

### +162 végrehajtási állapot — 2026-08-18

- A felsorolt alkalmazásoldali +162 javítások elkészültek: Android vissza/bezárás, tablet fekvő rádió-inset, telefonos fekvő Chat, kijelentkezett Chat ikon, korábbi események, Közösség áthelyezés, AdMob banner, Label megjelenési dátum kliensoldali megjelenítése, Chat kamera/galéria/válasz és szervezői kedvenc ikon.
- A WordPress release-date mező és API módosítása a `huhs-mobile-api-2.4.52` csomagban elkészült és élesben ellenőrizve: a `GET /wp-json/huhs/v1/releases` válasz `release_date` mezőt ad vissza.
- A production AAB elkészült: `build/HUHS-v1.0.0+162-release.aab`; a belső versionCode 162.
- `flutter analyze`: sikeres, csak 3 korábbi stílus-információ maradt; `flutter test`: 27/27 sikeres; `git diff --check`: whitespace-hiba nélkül futott.
- A +162 AAB a Google Play zárt tesztcsatornájába feltöltve és felülvizsgálatra beküldve; a Play Console jelenleg „Ellenőrzés alatt” állapotot mutat.
- Külső ellenőrzésre maradt: tesztelői eszközökön a széles Android-/tablet-/gyártói kompatibilitás. A Play Console „Közepes” optimalizálási mutató újraellenőrzése átkerült a +163 feladatai közé.
- A Pixel Tablet API 35 emulátoros fekvő ellenőrzés sikeres: az alsó rádió a rendszer navigációs sávja fölött marad; valódi gyártói eszközök további ellenőrzése még szükséges.

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

A +161 a +160 Play-regresszióját javítja: az adaptív AdMob banner szélességi kérése ismét legalább 320 px-es használható szélességgel indul, így a 0/1 px-es átmeneti layoutból nem készül érvénytelen bannerkérés. A rewarded reklám- és consent-logika változatlan. A release AAB elkészült: `build/HUHS-v1.0.0+161-release.aab`. `flutter analyze`, mind a 27 Flutter-teszt és `git diff --check` sikeres. A tulajdonosi teszt szerint az AdMob, az Android visszagomb, a preview végi vezérlő-visszaállítása és a preview utáni rádió-újraindítás működik; a főoldali kilépési megerősítés tényleges bezárása +162-re marad.

### v1.0.0+160 release — technikai versionCode 160

A +160 ugyanazt a javított forrásállapotot tartalmazza, mint a +159, új Play-kompatibilis versionCode-dal. A helyi AAB elkészült: `build/HUHS-v1.0.0+160-release.aab`; a helyi ellenőrzések hibamentesek. A +159-es Play-piszkozat törölve lett, majd a +160-as AAB zárt tesztbe feltöltve és felülvizsgálatra beküldve. A Play Console jelenleg a gyors ellenőrzéseket/felülvizsgálatot futtatja.

Tulajdonosi visszajelzés: a +158-ban az AdMob banner működött, a +160-ban a Playből telepített változatban nem jelenik meg, miközben a jutalmazott reklám működik. Ez +160 regresszióként nyitott; a banner consent/`canRequestAds()` útvonalát és a release konfigurációját össze kell vetni a +158-cal, majd új buildben javítani és Playből ellenőrizni.

A +161 ezt a banner-szélességi regressziót javítja. Az AAB a zárt tesztcsatornába feltöltve és felülvizsgálatra beküldve; a tulajdonosi teszt szerint az AdMob banner működik.

### Archív v1.0.0+159 release — technikai versionCode 159

A +159 a jelenlegi javításokra épülő release build. A fekvő tablet/telefon nézetben a rendszer alsó navigációja már nem takarja el a rádiót: a landscape tartalom `SafeArea`-ban jelenik meg, a NavigationRail pedig görgethető. A release AAB elkészült: `build/HUHS-v1.0.0+159-release.aab`; a csomag belső versionCode-ja ellenőrzötten 159.

- A Google Play zárt tesztfeltöltése nem fejezhető be ezzel a csomaggal: a Play Console jelezte, hogy a 159-es verziókódot már felhasználták. Az AAB helyi buildje hibátlan, de a +159 nem került új kiadásként beküldésre; a következő szabad versionCode várhatóan 160.

- Android visszagomb: a tabgyökér, belső aloldal és főoldali kilépési kérdés kezelése a +158-ban javítva, a +159 változatlanul tartalmazza.
- Fekvő tablet/telefon: az Android rendszer-navigáció nem takarja el a rádiót, a fekvő navigációs rail nem túlcsorduló.
- Statikus ellenőrzés: `flutter analyze` hibamentes, mind a 27 Flutter-teszt átment, `git diff --check` rendben.
- Graphify-index: a +159 forrásállapotra frissítve.

### v1.0.0+154 hotfix — technikai versionCode 154

A +154 hotfix a +153 javításaira épít: a lejárt események eltűnnek a profil „Események, ahol ott leszek” listájából és a kedvencekből is; a Label-preview kézi leállítása és szüneteltetése nem marad a lejátszás végéig zárolva, és a leállítás akkor is végrehajtja az állapot-visszaállítást, ha a lejátszó átmeneti állapotban van. A production AAB elkészült: `build/HUHS-v1.0.0+154-release.aab`; a kiadás éles a Google Play zárt tesztcsatornáján.

### Archív v1.0.0+158 hotfix végrehajtási és ellenőrzési állapot

A +158 hotfix a +157 visszajelzett hibáját javítja: az Android rendszer-visszagomb kezelését egyetlen központi `PopScope` kezeli, így a tabgyökér nem ürül ki, a belső oldal visszalép, a nem kezdőlap tabgyökeréről a Kezdőlap nyílik meg, a Kezdőlap gyökerén pedig kilépési megerősítés jelenik meg. A release AAB elkészült: `build/HUHS-v1.0.0+158-release.aab`; a Play Console zárt tesztkiadásába feltöltve és felülvizsgálatra beküldve, az automatikus ellenőrzés folyamatban.

- Android visszagomb: kódoldalon javítva; a tabgyökér, belső aloldal és főoldali kilépési kérdés tulajdonosi/emulátoros ellenőrzése szükséges.
- Törölt vagy már nem elérhető hírek, DJ-k és szervezők kedvencből való eltávolítása: +154-ben kész és tulajdonosi teszttel visszaigazolt.
- AdMob banner: kódoldalon javítva consent-várakozással, `canRequestAds()` ellenőrzéssel, hibaloggal és kontrollált újrapróbálással; Playből telepített változaton még ellenőrizni kell.
- Preview végi vezérlő-visszaállítás és preview utáni rádió-újraindítás: kódoldalon javítva; eszközön ellenőrizni kell.
- Telefonos fekvő Hírek-nézet: kódoldali javítás jelen van; új AAB-bal ellenőrizni kell.
- Telefonos fekvő Chat/Hírek/radio UX és széles Android/tablet/gyártói kompatibilitás: külső eszközteszt szükséges.
- Ponytail-alapú kódtakarítás: a célzott, biztonságos takarítás ebben a körben elvégezve; új funkciót nem törölt.
- A Play Console „Alkalmazásoptimalizálás: Közepes” mutatójának kivizsgálása és javítása: memóriahasználat, teljesítmény, obfuszkáció és méretcsökkentés ellenőrzése, majd új Play-feldolgozási eredmény alapján visszaellenőrzése.

### Archív +16 állapot — technikai versionCode 152 (nem aktuális build)

A +16 kódoldali javításai elkészültek. A release AAB: `build/app/outputs/bundle/release/app-release.aab`. A release R8/minify, resource shrink, Dart-obfuszkáció és split-debug-info beállításokkal készült. 4467 releváns fájl UTF-8-validációja hibátlan. A Play Console „Közepes” optimalizálási mutatója csak feltöltés/feldolgozás után lesz újra mérhető.

Külső tesztelendő marad: Playből telepített AdMob banner és a telefonos fekvő Hírek/Chat/radio UX. Tableten a fekvő Hírek olvasható; a széles Android-/gyártó-/tablet-kompatibilitás további eszközökön ellenőrizendő. Az Android visszagomb tulajdonosi hibája a +155-be került. A Play Billing, push és biometria már működőként igazolt, nem nyitott feladat.

### Archív +16 feladatlista és ellenőrzési állapot (nem aktuális build, csak történeti nyilvántartás)

- Play Console alkalmazásoptimalizálás javítása: memóriahasználat, általános teljesítmény, obfuszkációs és méretcsökkentési mutatók felülvizsgálata. A Play Console ezt jelenleg „Közepes” szintű optimalizálásként jelzi; a jelenlegi ellenőrzési státuszt a +156 blokk tartalmazza.
- Az események két külön szekcióban jelenjenek meg: „Kiemelt események” és „Események”.
- A profil-adatlapon a „Tervezett események” cím helyett „Események, ahol ott leszek” jelenjen meg.
- A lejárt események eltűnése a profil „Események, ahol ott leszek” listájából és a kedvencekből is — +154-ben elkészült és tulajdonos által működőként visszaigazolva.
- Minden jövőbeli frissítésnél és buildnél ellenőrizni kell a karakterkódolást, különösen a magyar ékezeteket, hogy ne jelenjenek meg krikszkrakszok.
- A történeti +16 körben a külön „Közösség” menü legyen teljes: az ismerőslista mellett tartalmazza az ismerős kérelmeket és státuszokat, a felhasználókeresést, a publikus profilokat, az ismerősök kezelését/törlését, a blokkolt felhasználókat és a jogosultság szerinti közösségi adminisztrációt; ezek kerüljenek ki a „Több” menüből.
- Az alkalmazáson belüli új verziójelző késését vagy esetleges eltűnését auditálni kell: ellenőrizni kell, hogy új frissítés esetén az app megnyitásakor megjelenik-e, és a frissítés indítása működőképes marad-e. Lehet, hogy csak a Play késleltetett frissítésjelzése okozta.
- Android visszagomb: a korábbi +16 állapotjelentésben még nyitott volt; a jelenlegi javítás a +155-ben található.
- Label preview: a korábbi +16 állapotjelentés történeti állapotot rögzít; a preview végi vezérlő-visszaállítás és rádió-újraindítás javítása a +155-ben található.
- Törölt felhasználó maradhat az ismerőslistában és „HUHS user” néven nyílhat meg; a törölt profilt az ismerőslistából és a kapcsolódó ismerős-adatokból ki kell takarítani vagy frissíteni.
- Playből telepítve az AdMob banner/csík nem tölt be, miközben a jutalmazott reklám működik; a +155 kódjavítása elkészült, az éles Play-ellenőrzés külső teszt.
- Fekvő telefonon a Chat és a Hírek használhatatlan, a rádiólejátszó túl nagy; a +155-ben kódoldali javítások vannak, az éles eszközteszt külső ellenőrzés.
- Széles Android-kompatibilitás külön +16-os tesztelendő pont: tablet és minden elérhető eltérő Android-verzió/gyártói rendszerfelület ellenőrzése; teljes laborlefedettség jelenleg nem áll rendelkezésre.

## Központi Cégregiszter – külön WordPress migrációs követelmények

## Külön projekt: Hungarian Hardstyle Ticketing

- A jegyértékesítés önálló WordPress-modul/szolgáltatás és külön REST API lesz; nem kerül közvetlenül a jelenlegi `huhs-mobile-api` mobil API-ba.
- A cél egy külön, mobilbarát ticketing aloldal, például `jegy.hungarianhardstyle.hu`, későbbi natív Flutter-app- és scanner-integrációval.
- Partnerenként backendből konfigurálható legyen a Stripe vagy Barion, a saját Billingo-kapcsolat, számlázási adatok, kezelési költség és egyéb fizetési beállítások.
- A projekt része: esemény- és jegytípus-kezelés, névre szóló jegy, vendéglista, PDF-jegy, egyedi vonalkód, szerveroldali scanner-validáció és belépési státusz.

A projektben külön, tervezett WordPress cégregiszter-migráció is szerepel. Célja a `G:\szakmaiceg.sql` Mosets Tree SQL-export teljes átültetése a `https://kozponticegregiszter.hu/` friss WordPress-oldalára.

### Kötelező irányelvek

- Saját WordPress `Cég` tartalomtípus és saját Business API készüljön; Business Directory plugin csak alternatíva lehet.
- A Mosets Tree kategóriahierarchia, cégek, egyedi mezők, státuszok, kapcsolatok, koordináták és képhivatkozások maradjanak meg.
- A főoldalon a kategóriák legyenek a legfontosabb elemek, és minden kategória/alkategória legyen kattintható.
- A cégek, adatlapok, keresési eredmények és térképpontok legyenek kattinthatók.
- Legyen cégnév-, kulcsszó-, város-, megye- és kategóriaalapú keresés/szűrés.
- Legyen beágyazott, interaktív OpenStreetMap + Leaflet térkép a céges adatlapokon és összesített térképes nézetben.
- A Mosets Tree meglévő `lat`, `lng` és `zoom` értékeit használjuk, ahol rendelkezésre állnak.
- A látványterv csak designreferencia; ne képként kerüljön a WordPress-oldalra.
- A design modern, üzleti, fehér–kék–türkiz és mobilbarát legyen.

### Backend cégfeltöltő mezői

A backend cégfeltöltő a SQL-ben felismert mezőket kezelje: cégnév, alias, leírás, kulcsszavak, kategória/alkategória, kapcsolattartó, cím/telephely, város, megye, ország, irányítószám, telefon, mobil, fax, e-mail, másodlagos e-mail, weboldal, Facebook, képek és fájlok, térkép megjelenítése, szélességi és hosszúsági koordináta, térképzoom, kiemelt státusz, publikációs státusz, SEO metaadatok, létrehozási és módosítási dátum.

### API- és importelvárások

- Az API adjon listázó, részletező, kategória- és keresési végpontokat.
- Az API legyen frontend- és későbbi mobilapp-kompatibilis.
- A teljes import legyen újrafuttatható, naplózható és hibajelentéssel ellenőrizhető.
- A Mosets Tree képekhez a SQL mellett szükséges a tényleges képmappa/ZIP is.
- A magyar karakterkódolást import közben ellenőrizni és javítani kell.
- Az éles telepítés előtt friss WordPress és alkalmazásjelszó szükséges; jelszót chatben nem szabad elküldeni.

### SEO-irányelvek a meglévő cégekhez

- Importkor minden publikált cég kapjon egyedi SEO title-t, meta descriptiont és canonical URL-t.
- A title és description tartalmazza a cég nevét, fő szolgáltatását/tevékenységét, valamint ahol értelmes, a várost vagy megyét; kulcsszóhalmozás tilos.
- A Mosets Tree régi URL-jeit 301-es átirányításokkal kell az új céges URL-ekre vezetni.
- A cégadatlapokhoz a megfelelő `schema.org` üzleti strukturált adatot kell kiadni, legalább név, cím, telefon, weboldal, kategória és GPS-koordináták mezőkkel, ha elérhetők.
- Kategória- és városoldalakhoz egyedi, indexelhető title, meta description és canonical URL készüljön.
- A céges képekhez beszédes fájlnév és magyar ALT-szöveg szükséges.
- A publikált cégek és kategóriaoldalak kerüljenek XML sitemapbe; nem publikált, üres vagy duplikált rekordok ne indexelődjenek.
- A Mosets `metakey` és `metadesc` értékeket meg kell őrizni/importálni, de a tényleges SEO-kimenetben tisztítani és szükség esetén kiegészíteni kell.
- Az import végén készüljön SEO-audit: hiányzó title/description, duplikáció, canonical, átirányítás, kép-ALT, koordináta és indexelhetőség.

This file is the project memory for Codex and other AI coding agents working on the Hungarian Hardstyle app. Keep it up to date when architectural decisions, roadmap priorities, API contracts, or brand rules change.

## Kötelező kontextus-ellenőrzés minden munkánál

Minden feladat, kérdés, státuszlekérdezés, visszaigazolás vagy dokumentációs módosítás előtt teljes egészében ellenőrizni kell az elsődleges projektforrásokat:

- `AGENTS.md`
- `PROJECT_CONTEXT.md`, ha létezik
- `README.md`
- `graphify-out/GRAPH_REPORT.md`

Ezek tartalma elsőbbséget élvez a korábbi beszélgetési emlékekkel és feltételezésekkel szemben. A kész, nyitott és tesztelésre váró feladatokat ezek, valamint a felhasználó legutóbbi konkrét visszajelzése alapján kell szétválasztani. Minden tényleges kód- vagy dokumentációváltozás után a Graphify-indexet frissíteni kell.

## Project Summary

Hungarian Hardstyle is a cross-platform mobile app and web-connected platform for the Hungarian harder styles community.

The long-term goal is to create a central hub for:

- news
- events
- DJs and artists
- organizers
- releases
- online radio
- community features
- digital music distribution

The mobile app is built with Flutter. WordPress is the backend and the single source of truth.

## Main Brands

### Hungarian Hardstyle

The main brand, community platform, website, and app identity. Hungarian Hardstyle is the umbrella brand that contains the news, app, community, and related sub-brands.

### Hardstyle Revolution

An important sub-brand under Hungarian Hardstyle.

Hardstyle Revolution can represent:

- a record label
- an event series
- its own Facebook page
- its own Instagram page
- releases inside the app
- future store/catalog features

### Rave Revolution

A newer multi-genre hard dance event series. It can include hardstyle, rawstyle, hardcore, hard techno, and other harder electronic styles.

### Hard Lake

A summer/free/flashmob-style event concept, usually connected to Lake Velence.

In the app, these sub-brands can later appear in a "Brands" or "Our Brands" area under the More section, each with logo, short description, and social links.

## Core Product Direction

This is not intended to become a generic music app. It should feel like a platform built specifically around the Hungarian hard dance scene.

The app should prioritize:

- a strong dark visual identity
- fast access to fresh news
- dynamic events
- clear artist and organizer discovery
- future media and release features
- a community feeling without requiring registration at first

## Data Source Rule

WordPress is the source of truth for editorial/content data (news, events, DJs, organizers and future catalog items). Firebase is the source for community authentication and community data such as profiles, roles, Chat and reactions.

Do not create separate hardcoded databases in Flutter for real app content. Temporary placeholder content is allowed only while a feature is being built.

Expected data flow:

1. WordPress admin creates or edits content.
2. WordPress exposes that content through REST API endpoints.
3. Flutter fetches and renders the API data.
4. Later, public web detail pages can use the same WordPress content.

## Current State

- Fióktörlés után az user teljes kijelentkeztetése és minden lokális profil-/munkamenet-állapot törlése; újraindítás után se maradjon visszatölthető belépett állapot.
- Release preview: a preview lejátszása legyen újraindítható/többször lejátszható; preview indításakor álljon le az éppen szóló Real Hardstyle FM rádió.
- Release preview: a 60 másodperces anyag lejátszósávján legyen működő előre- és visszatekerés.
- A példányonkénti memóriás rate limiting felülvizsgálata és szükség esetén központi, több Function-példányon is konzisztens számlálóra cserélése.
- A Firestore-olvasási szabályok célzott auditja és szűkítése regresszió nélkül.
- Széleskörű Android-kompatibilitási próba: több Android-verzió, gyártó és rendszerfelület (Samsung/One UI, Xiaomi/HyperOS, Pixel/stock Android és más elérhető eszközök), telefonok, tabletek és kijelzőméretek, álló/fekvő nézet; Play Billing, AdMob, push és biometria. A háttér-rádió működő funkció, külön nyitott feladat nélkül.
- Release-obfuszkáció és hardening ellenőrzése; kliensoldali titkok és jogosultsági döntések továbbra is tiltottak.
- Tanúsítvány-pinning megvalósíthatósági vizsgálata és csak kompatibilitási teszt után történő bevezetése.

As of the current project state:

- Flutter app structure exists.
- Dark UI exists.
- Home screen and bottom navigation exist.
- News API integration works in the Flutter app.
- News list works with API-backed content.
- News search UI exists.
- News item tap/click opens the news detail view.
- News cards display remote images, title, date, and featured state.
- The WordPress API plugin source is present locally as deployable ZIPs in `build/`; package `2.4.46` is historical, package `2.4.48` is historical, and package `2.4.49` is deployed and live-verified on `hungarianhardstyle.hu`.
- Package `2.4.48` retains the live voting and release APIs, uses separate Radio and Extended upload fields, generates the preview from Radio, creates private WAV/320 kbps derivatives from both versions, and exposes the four Play product ID/price fields in the native admin API. Private audio paths are never returned by the public release API. Its protected download response names both rewarded-ad and purchased files from the release title plus the version/format suffix, and its protected product-ID route is live-tested.
- v1.0 remains open only for final owner phone verification of the production Android artifact. The Firebase Play secret, Play service-account permission, WordPress release product metadata, production AdMob identifiers and rewarded SSV are configured.
- v1.0.0+13 is prepared locally: FCM token refresh/re-registration and stale-token cleanup are included, `notifyConnectionRequest` is deployed to `europe-central2`, AdMob load failures use short user-facing messages, and ordinary e-mail registration requires verification. Production ARM64 APK/AAB are built; Play upload and owner phone verification remain external checks.
- The 128 kbps rewarded unlock must use the `admobRewardedSsv` HTTPS Function; do not restore a client-only unlock callable, because it would allow fabricated rewards.
- v1.0.0+5 fixes the production AdMob configuration gap: App/Banner/Rewarded IDs are passed to both the Android manifest and Flutter Dart via `--dart-define`, so the rewarded button no longer receives an empty production unit ID. Production ARM64 artifact: `build/HUHS-v1.0.0+5-arm64-release.apk`.
- v1.0.0+9 keeps the rewarded 128 kbps entitlement permanent and changes an already unlocked release from a disabled `Feloldva` control to an active `Letöltés` action; it never shows another rewarded ad for that release. Verified ARM64 release artifact: `build/HUHS-v1.0.0+9-arm64-release.apk` (`versionCode 2009`).
- The final Android package name is `hu.hungarianhardstyle.app`; Firebase Android configuration and release SHA certificates are registered for this package, and the Play Console app has been created.
- The v1.0 BILLING permission is included in the Android manifest. Production artifacts are `build/HUHS-v1.0.0+1-arm64-release.apk` and `build/HUHS-v1.0.0+1-release.aab`; the Play Console closed-test draft and four active Hungary products are configured.
- Backend package `2.3.0` is deployed and confirmed working. It includes organizer list/detail REST endpoints, organizer search, logo/social data, and organizer upcoming-event relations.
- Backend package `2.4.0` is deployed and live-verified. It adds moderated DJ and organizer submissions, a one-click admin approval flow that creates non-public draft profiles, and DJ booking fields including the optional Hungarian Hardstyle-managed booking route.
- Backend package `2.4.1` is deployed. It adds multipart image upload for event flyers and DJ profile images. Files are limited to 5 MB and JPG/PNG/WebP, stored in the WordPress Media Library, attached to the pending submission, and never auto-published.
- Backend package `2.4.2` is deployed and its organizer-logo upload was tested in the admin flow.
- Backend package `2.4.3` is deployed and tested. It adds a dedicated `facebook_event_url` field to the WordPress event editor and events mobile API.
- Backend package `2.4.7` is deployed. It fixes the invalid nested admin approval form that prevented DJ and organizer draft creation, removes the misleading native publish box from submissions, and adds the same one-click draft creation flow for event submissions. The approval flow still requires a live WordPress admin test.
- Backend package `2.4.8` is historical. Its multipart image path remains documented for compatibility; the active app upload path is Cloudinary and direct multipart uploads are not a current WAF/deployment status.
- Backend package `2.4.12` is deployed and live-verified. It exposes published IRP related-post records and a public post-detail endpoint; a real "Kapcsolódó cikk" target was verified. Flutter opens returned related articles plus normal WordPress "Kapcsolódó cikk", "Kapcsolódó", and "Ez is érdekelhet" links in the native news detail screen and falls back to the in-app browser when IDs are unavailable.
- Backend package 2.4.31, 2.4.33, 2.4.36, 2.4.37, 2.4.42, 2.4.45, 2.4.46 and 2.4.47 are historical; 2.4.48 is deployed and live-verified for the v1 Label product metadata flow.
- Backend package `2.4.16` also contains the FCM HTTP v1 sender: mobile token registration, news/event/link targets, automatic HUHS URL resolution, foreground display support, per-device notification preferences, publish-time news/event pushes, scheduled event reminders, and an admin custom-push form. Custom push and news/event publishing pushes are live-tested; the first natural event-day reminder did not arrive and the cron/timezone/filter path needs investigation.
- Event-day reminder delivery is now live-verified; it is not an open v0.99.8 or v1.0 investigation.
- The custom-push admin form lists recent published news and events by title and validates the selected post type, so editors do not need to look up event IDs manually.
- Backend package `2.4.15` adds the server-side Mailchimp newsletter subscription endpoint and protected admin settings page; the endpoint is live and both invalid-email validation and a real personal e-mail double-opt-in test succeeded. Flutter includes a native signup screen with consent and double opt-in messaging.
- Backend package `2.4.9` is prepared for deployment. It adds organizer genre/style metadata, WordPress editor controls, API output, and genre validation/storage for organizer submissions. Flutter now displays organizer genres and includes them in organizer submissions.
- Cloudinary is the only active app image-upload path.
- DJ logos are rendered in Flutter and public WordPress artist profiles; direct multipart upload remains separate and uses Cloudinary.
- DJ/organizer list providers now use auto-dispose so newly published or edited profiles refresh after navigation.
- The WordPress plugin exposes `GET /wp-json/huhs/v1/posts`.
- The WordPress plugin exposes `GET /wp-json/huhs/v1/events`.
- Backend package `2.2.0` is deployed. Its artist list/category endpoints, shared submission genre options, validation response, and public DJ/event archive templates were verified live. A successful real submission still needs an intentional end-to-end app test because it creates a pending WordPress item.
- The v0.99.89 Label release catalog is complete; only the later paid store extension remains future work.
- Dynamic events and the event detail screen are connected to the WordPress events API.
- Event detail artists and organizer are clickable. Artist links open complete API-backed DJ profiles. Organizer links are now connected to the organizer detail provider and require backend `2.3.0` in production.
- News excerpts are converted to plain text and HTML tags are removed for both custom and standard WordPress responses.
- News search uses the custom `huhs/v1/posts` endpoint so search results retain the same processed content, featured images, galleries, and embeds as the normal news flow.
- News detail renders deduplicated YouTube, Spotify, SoundCloud, Instagram, and TikTok embeds in-app. Supported interactive WordPress shortcodes (`ays_poll`, `irp`, and legacy Final Tiles Gallery) are detected; their raw shortcode text is removed and the rendered WordPress content can be opened inside the app.
- Plain-text web URLs in news and event HTML are automatically converted into tappable links. Normal article, event, ticket, and shortcode links use the shared in-app browser; native media and Maps handoff remain intentional exceptions.
- WordPress API work exists and should continue to be the backend source for new dynamic features.
- Flutter-side WordPress integration is complete for the current news, events, DJs, organizers, submissions and the closed v0.99.89 Label release catalog. The native HUHS Vezérlőközpont remains the admin source.

Do not assume that an empty or partial integration file is a bug by itself. Treat it as an implementation placeholder unless it blocks the requested feature or conflicts with a known working module.

## Flutter Stack

The Flutter app uses or is expected to use:

- Flutter
- Material 3
- dark theme
- Riverpod for state management
- Dio for HTTP requests
- cached_network_image for remote images
- intl for date formatting
- go_router when route-based navigation becomes necessary

Prefer existing dependencies before adding new ones.

## Flutter Conventions

Use the existing folder structure:

- `lib/main.dart`
- `lib/core/theme/`
- `lib/models/`
- `lib/providers/`
- `lib/services/`
- `lib/screens/`

Preferred feature pattern:

- model in `lib/models/`
- API/service code in `lib/services/`
- Riverpod provider in `lib/providers/`
- screen UI in `lib/screens/<feature>/`

For API-backed screens, include:

- loading state
- empty state
- error state
- pull-to-refresh when useful

Keep UI dark and brand-forward. Use red accents carefully and consistently.

## WordPress Conventions

WordPress should manage the content. Flutter should consume REST API responses.

Expected WordPress content areas:

- news/posts
- events
- artists/DJs
- organizers
- releases
- future store items

Expected event metadata:

- title
- date
- location
- Google Maps URL
- ticket URL
- flyer image
- related artists
- related organizer
- featured flag
- visible-in-app flag

When implementing WordPress save logic, always verify nonce, permissions, autosave behavior, and sanitize fields before saving metadata.

## API Direction

Known current custom API endpoints:

- `GET /wp-json/huhs/v1/posts`
- `GET /wp-json/huhs/v1/events`
- `GET /wp-json/huhs/v1/artists` (deployed and verified in backend `2.2.0`)
- `GET /wp-json/huhs/v1/artists/{id}` (deployed and verified with live DJ data)
- `GET /wp-json/huhs/v1/event-submission-options` (deployed and verified; returns the shared DJ/event genre list)
- `POST /wp-json/huhs/v1/event-submissions` (deployed; required-field validation verified, successful pending-item creation awaits intentional app testing)
- `GET /wp-json/huhs/v1/organizers` (deployed and live-verified in backend `2.3.0`)
- `GET /wp-json/huhs/v1/organizers/{id}` (deployed and live-verified with upcoming events in backend `2.3.0`)
- `GET /wp-json/huhs/v1/profile-submission-options` (deployed and live-verified in backend `2.4.0`; shared genres and DJ categories)
- `POST /wp-json/huhs/v1/artist-submissions` (route live-verified in backend `2.4.0`; creates a pending submission only)
- `POST /wp-json/huhs/v1/organizer-submissions` (route live-verified in backend `2.4.0`; creates a pending submission only)

Current posts response fields:

- `id`
- `title`
- `date`
- `excerpt`
- `content`
- `featured_image`
- `link`
- `gallery_id`
- `gallery_images`
- `embeds`

Current events response fields:

- `id`
- `title`
- `description`
- `start_date`
- `start_time`
- `end_date`
- `end_time`
- `venue_name`
- `venue_city`
- `venue_zip`
- `venue_address`
- `venue_country`
- `google_maps`
- `ticket_type`
- `ticket_url`
- `facebook_event_url` (separate Facebook Event link on event records and mobile API; backend 2.4.3)
- `organizer`
- `artists`
- `flyer`
- `featured`
- `visible`
- `status`

The events API currently returns only published `huhs_event` posts where `visible` is truthy. It sorts featured events first, then by `start_date`.

Artist and organizer custom post types and their list/detail mobile APIs are deployed and verified. Only profiles with `Publikálás az alkalmazásban` (`visible`) enabled appear in their mobile APIs, although published artists may still appear on the public WordPress `/djs/` archive.

The artist list endpoint supports `page`, `per_page`, `search`, and `category` parameters. Artist responses include biography, excerpt, images, genres, Hardstyle/Hardcore category objects, location, social links including TikTok, flags, public link, and detail-only `upcoming_events`.

WordPress artist management includes the hierarchical `huhs_artist_category` taxonomy. The default categories are `Hardstyle` and `Hardcore`, and an artist may belong to either or both. The `[huhs_djs]` shortcode renders a responsive, category-grouped DJ directory linking to public profiles. `[huhs_djs category="hardstyle"]` and `[huhs_djs category="hardcore"]` render a single category.

The `[huhs_events]` shortcode renders the complete responsive upcoming-event directory with flyer, date/time, venue, description, detail link, ticket link, and featured state. Use `[huhs_events include_past="true"]` only when a page intentionally needs past events too.

Backend `2.2.0` also overrides the public `huhs_artist` and `huhs_event` archive templates so `/djs/` and `/events/` automatically render the same polished collection views without requiring manually created WordPress pages.

For artists, `hero_image` is the stored legacy meta key but its product/admin name is `Profilkép`. Use the API `profile_image` field for new Flutter code. `hero_image` remains in responses temporarily for backward compatibility. DJ list cards must prefer `profile_image`; the logo is only a fallback.

DJ profile images use `cover` cropping with an upper-center portrait focus (approximately 50% horizontal / 25% vertical on web, matching upper-center alignment in Flutter) so faces remain visible across mixed source image dimensions.

DJ and organizer list cards must use a consistent image frame size and aspect ratio across every item. Use `cover` cropping with an upper-center focal alignment so portrait faces remain visible; organizer logos or non-portrait artwork should still fill the same standardized frame without changing card dimensions.

The WordPress `HUHS Mobile > Shortcode-ok` admin page is the canonical in-dashboard shortcode reference. It lists every supported DJ/event shortcode, parameters, descriptions, and copy buttons; keep it updated whenever a shortcode is added or changed.

Event submissions from Flutter require title, date, venue, at least one server-approved genre, and contact e-mail. Optional fields are start time, city, organizer name, event URL, and description. Submissions must remain `pending`; they must never become published events automatically.

With backend `2.4.1`, event submissions may include an uploaded flyer selected from the device gallery or camera. The admin submission screen previews the uploaded image and links to its Media Library attachment. Backend `2.4.8` also accepts a separate optional `logo` image alongside the DJ profile `image`, with the same 5 MB and JPG/PNG/WebP validation.

DJ, organizer, and event submissions from Flutter remain pending until editorial review. Backend `2.4.7` adds a nonce-protected WordPress approval action that creates the matching draft DJ/organizer/event with `visible` disabled; publishing and app visibility remain separate manual decisions. Submitted profile/logo images are supplied as reviewable URLs and are not automatically imported into the Media Library.

DJ profiles support a public booking e-mail and a `booking_via_huhs` option. When enabled, both the public website and Flutter must show `info@hungarianhardstyle.hu` as the booking address and explain that the performance can be arranged through Hungarian Hardstyle. The private submission contact e-mail must never be exposed on the public profile.

Artist/DJ and organizer profile APIs should include related events:

- Artist/DJ profiles should show events where the artist performs.
- Organizer profiles should show events organized by that organizer.
- These can be derived from event relationships: `artists` contains artist IDs and `organizer_id` contains the organizer ID.
- Prefer returning an `upcoming_events` array in artist and organizer detail responses.

Artist/DJ profiles should include a TikTok field when the DJ API is implemented. Organizer already has a `tiktok` meta field in the reviewed plugin ZIP.

The API should support:

- news list, currently working in Flutter
- news detail, currently working in Flutter
- event list, endpoint exists in WordPress
- event detail, can initially use the event object from the list or a future detail endpoint
- artists list, deployed and verified with live data
- artist detail, deployed and verified with live data
- organizers list, deployed and live-verified in backend `2.3.0`
- organizer detail with upcoming events, deployed and live-verified in backend `2.3.0`
- the Label release catalog is complete in v0.99.89; paid purchase/store is a later extension in the same area

Flutter should not rely on WordPress admin-only fields or HTML that is hard to render on mobile unless rich content support is explicitly being implemented.

Prefer API responses that are easy for Flutter to parse:

- plain strings for titles
- ISO dates or clear date strings
- direct image URLs
- arrays for related artists/organizers
- booleans for flags
- explicit nullable fields

## Roadmap

### KCR mobilapp – cégmegjelenési időszak

- A mobilappban a cégmegjelenéshez tartozó kezdő- és lejárati dátumot a KCR API adja vissza; a telepíthető KCR 1.9.24 csomag ezt a `listing_starts`, `listing_expires` és `listing_active` mezőkkel, valamint a `/wp-json/kcr/v1/companies/{id}/listing-period` végponttal biztosítja.
- A sikeres megrendelés/Google Pay/Apple Pay vagy más jóváhagyott fizetés után a backend állítja be az időszakot; a kliens nem dönthet jogosultságról.
- Lejáratkor a webes backend a céget piszkozatba teszi, ezért az appból is eltűnik a nyilvános listából.
- A dátum nélküli, korábban importált cégek aktívak maradnak, őket az automatikus lejártatás nem érinti.
- Az admin és a cég tulajdonosa a megfelelő jogosultsággal láthatja a lejárati állapotot; tulajdonosi szerkesztésnél a dátum nem hosszabbítható meg fizetés nélkül.

### KCR mobilapp – navigáció és design

- A mobilapp vizuális világa a kozponticegregiszter.hu weboldal üzleti, fehér–kék–türkiz designjához igazodjon.
- A fő navigáció alsó menüsávban legyen.
- Az alsó menük: `Cégek`, `Megrendelés`, `Cégünkről`, `ÁSZF`, `Hírlevél`.
- A `Belépés` a felső bal sarokból legyen elérhető; belépés után ugyanott a felhasználói fiók/állapot jelenjen meg, és a belépési pont a `Fiók` felületére vezessen.
- A céges böngészés hierarchikus legyen: fő kategória → alkategória → ízléses, kártyás céglista → cégadatlap.
- A céglista és a cégadatlap a weboldal meglévő kártya-, szín-, tipográfia- és képkezelési rendszerét kövesse, reszponzív mobilhasználattal.
- A mobilapp ne tartson külön, eltérő cégadatbázist; a WordPress/KCR API maradjon az egyetlen adatforrás.

### v0.99.1 implementation note

The current Flutter branch contains the Community MVP implementation: Firebase Auth registration/sign-in with mandatory DJ/organizer/partygoer roles, public Firestore Chat, anonymous text-only posts, registered Cloudinary image posts, profile entry/editing with monogram fallback, fixed reactions, a five-item Home news slider rotating every 10 seconds, and native article-tag filtering. Firestore deployment files are `firestore.rules`, `firebase.json`, and `.firebaserc`; rules are deployed to the named `hungarian-hardstyle` database and physical ARM verification is complete for `v0.99.1+10`. The authorization follow-up is now `v0.99.1+12`. The composer uses a responsive layout. Google sign-in provider and Android SHA configuration are present in the checked-in Firebase Android configuration; release-device verification remains a final external check. The HUHS posts endpoint does not currently expose tag names, so Flutter hydrates them from the WordPress core posts endpoint when necessary.

Historical v0.99.1 follow-up reports are addressed in the current bugfix build. Registration offers both e-mail/password and Google-account sign-in, with the account role selected during onboarding.
Chat message deletion and the in-app role-management panel are implemented; actual Firebase Auth account deletion for another user is handled by the deployed server-side Cloud Function/Admin SDK task.
The Cloud Function source is in `functions/` (`deleteCommunityUser`) and is deployed to Firebase. Artifact cleanup retains old function images for 90 days.
Also record for the next fix pass: push notification text has an encoding bug and may show Hungarian punctuation/accents as HTML entities (for example `&#8211;`) instead of decoded characters.
Community authorization is now separated: `djdeeroy@gmail.com` is an Admin with the account role Szervező; normal users cannot change account roles after onboarding; admins manage account/access roles and Chat messages; moderators cannot edit or delete Chat messages.

The latest v0.99.1 bugfix build addresses the previously reported profile/avatar, Chat deletion, logout, duplicate-role, and admin-menu issues. Superseded by v0.99.3: free profile-image zoom and movement are required.
v0.99.1+12 fixes the community profile/avatar synchronization, signed-in Chat image permission state, author monogram/avatar rendering, separates account roles from access roles, adds admin-only Chat deletion and admin user-role management for legacy profiles, reloads profiles after Auth restoration, and deploys the Firestore rules to the named database used by the app. Google sign-in remains a release-device/Firebase SHA verification check; Superseded by v0.99.3: free profile-image zoom and movement are required.

The next Flutter test build is v0.99.2. The Google AdMob test banner is enabled for the test build with `HUHS_ENABLE_TEST_ADS=true`; do not switch to production AdMob identifiers yet. Consent/privacy and production monetization remain release work.

The v0.99.3 scope also includes making the About screen contact e-mail open the device mail app and keeping the Real Hardstyle FM stream playing when the user switches between apps.

Record for v0.99.2 bugfix work: diagnose the e-mail/password sign-in failure without assuming the password is wrong; restore profile-image rendering; fix the `deleteCommunityUser` Cloud Function `INTERNAL` failure from admin user deletion; persist `djdeeroy@gmail.com` as account role `organizer`/`Szervező` while retaining `admin` access; enforce final account roles server-side so only admins can change them after registration; and show the persisted account role on profiles and Chat with separate Admin/Moderátor access badges.

Tag- and genre-filtered discovery lists must use API pagination/infinite scroll so all matching news and DJ results can be reached, not only the initially loaded page.

Separate Facebook, Instagram, TikTok, YouTube, and Spotify fields during registration and in the community profile are complete.
- Next build follow-up: add a password-reset link to login and replace raw Firebase credential errors with a clear Hungarian message.
- Next build follow-up: add password visibility toggles and an optional strong-password generator during registration.
- Next build follow-up: refresh the Home top-left profile avatar immediately after sign-in without requiring manual refresh.
- Next build follow-up: add a dismissible/pinnable Chat notice, admin-created pinned messages, admin pin controls, and a configurable profanity filter that masks blocked words with asterisks.
- Next build follow-up: show an admin-managed startup announcement image with a close button; allow image upload/replacement from the app admin panel and the WordPress Mobile API.
- v0.99.2 follow-up: allow gallery images to be saved to the device with platform permission handling.
- v0.99.2 follow-up: add a Data protection / GDPR information section covering privacy, retention, and user rights.
- v0.99.2 follow-up: review personal-data access rules and keep sensitive operations server-side.
- v0.99.999: complete security hardening, obfuscation, restricted backend secrets, abuse/rate-limit checks, and Android release signing; absolute protection against reverse engineering is not possible.
- v0.99.2.1 radio scope: completed the Real Hardstyle FM integration at `https://stream.realhardstyle.nl` as the Home radio stream, including a custom compact bar player matching the app's red-black design (Play, Stop, and Mute), current-track metadata when available, safe placement above bottom navigation, and a More-section provider page with the supplied logo, website, and attribution text.
- v0.99.2.1 follow-up: completed the readable modern/cyber-style font fallback with Hungarian accented-character support.

### v0.99.3 - HUHS Vezérlőközpont

- [x] Implement the WordPress Mobile API administration natively in the Admin-only HUHS Vezérlőközpont, including readable content/custom metadata editing, submissions, trash, Mobile API settings/status, push, newsletter status, shortcodes, About and persistent `Indítási kép` management. Exclude the radio provider and generic WordPress news/page/media/comment/taxonomy/user menus.
- [x] Add a separate admin-only `Felhasználók` menu inside the admin panel with user search and user-management actions.
- [x] Restrict event submission to authenticated registered users; the Flutter form is hidden/guarded for guests, and WordPress-side unauthenticated rejection is verified.
- [x] Complete the approved red-black TypeUI visual layout across Home and every menu/screen: Rajdhani typography with Hungarian accents, consistent cards and controls, compact sections and radio bar, the unchanged original `assets/logos/huhs_logo.png` HUHS logo, and the Home slogan.
- [x] Keep the Home logo area free of navigation shortcuts that duplicate the persistent bottom navigation; use the compact two-line TypeUI radio bar above the bottom navigation.
- [x] Refresh the native admin after startup-image saving without returning the asynchronous reload request from `setState`.
- [x] Allow admins to disable and clear the configured startup image from the app.
- [x] Keep the Chat emoji helper on one line and the send action in its own full-width row.
- [x] Make the About screen contact e-mail open the device mail app.
- [x] Keep the Real Hardstyle FM stream playing when the user switches between apps.
- [x] Show the saved profile image on the user's own profile screen, falling back to the Firebase user photo URL and then a name/e-mail monogram.
- [x] Refresh profile/avatar state after authentication and profile-image changes.
- [x] Keep the editor preview identical to the saved circular avatar crop and persist true horizontal and vertical positioning together with pinch zoom.
- [x] Open the community profile in a read-only view and place editing behind a separate `Profil szerkesztése` action and screen.
- [x] Refresh the Real Hardstyle FM current-track metadata automatically while playback is active.
- [x] Reconnect the Real Hardstyle FM player automatically after an unexpected stream interruption.
- [x] Fix the push-settings screen lifecycle assertion (`_dependents.isEmpty`); push delivery itself remains unchanged.
- [x] Resolve Chat avatars from the author's current community profile so earlier messages update after a profile-image change.
- [x] Add a profile deletion option with an explicit confirmation step.
- [x] Require confirmation before deleting Chat messages.
- [x] Require confirmation before an admin deletes a user account.
- [x] Keep the Chat camera action, emoji helper (`Emoji a billentyűzetről is használható`) and signed-in status on one compact line above the Send button.

- [x] Fix the phone-verified Hungarian character-encoding/mojibake errors on the community profile screen.
- [x] Remove the unnecessary `Beállítások`, `Hírlevél`, and `Shortcode` entries from the native HUHS Vezérlőközpont.

v0.99.3 is complete, phone-verified by the project owner in Flutter build `0.99.3+27`, and closed. Do not reopen or rework this release unless a new regression is explicitly reported.

### v0.99.4 - Small Improvements (implemented)

Implemented in Flutter `0.99.4+3`:

- categorize the existing `Több` entries without renaming the menu:
  - `Felfedezés`: DJ-k, Szervezők, Spotify Playlistek
  - `Közösség`: Kedvencek, Hírlevél; the v1.0 registered-user search will also belong here
  - `Beküldés`: role-gated event, DJ and organizer submissions
  - `Kapcsolat és támogatás`: Social és kapcsolat, Támogatás / Donate, Hibajelzés, GYIK / FAQ
  - `Alkalmazás`: Beállítások, Adatvédelem és GDPR, Az appról, Rádió szolgáltató
  - keep the HUHS Vezérlőközpont in the Admin profile; do not duplicate it in `Több`
- [x] add the PayPal `Támogatás / Donate` card
- [x] add a pre-addressed feedback e-mail action with the runtime app version
- [x] add the WordPress-managed FAQ under More with categories, ordering, search, expandable answers, and loading/empty/error states; the initial 10 Hungarian FAQ entries are populated in production (API package 2.4.33)
- [x] persist favorites in the signed-in user's Firestore profile (with local cache and bulk deletion)
- [x] replace full social-media URLs on community profiles with compact, clickable Facebook, Instagram, TikTok, YouTube, and Spotify buttons
- [x] move the existing Home AdMob banner below both the latest-news and upcoming-events sections
- [x] add one clearly separated inline adaptive AdMob banner to the native news list
- [x] fix Instagram post embeds in news so `instagram://` URLs are converted to supported web links before opening
- compact the Home event cards while keeping every card the same height and preserving title, date/time, city, genres, favorite, and open actions
- [x] show a registered-user/role requirement in `Beküldés` when no submission action is available
- [x] update the in-app GDPR text for the current Firebase, Cloudinary, WordPress, Mailchimp, and test-AdMob data flows
- [x] add a second separated adaptive test AdMob placement after the first five news cards

- [x] compact the Home event cards while keeping every card the same height and preserving title, date/time, city, genres, favorite, and open actions

The event-tag fast-scroll regression is fixed. WordPress Mobile API `2.4.33` is deployed and live-verified with the FAQ endpoint. The ARM64 test APK is `build/HUHS-v0.99.4+3-arm64-debug.apk`. Production AdMob identifiers and consent/privacy handling remain release work. v0.99.4 is closed.

### v0.99.5 - complete

Implemented in Flutter `0.99.5+1`:

- [x] password reset, visibility toggle, clear Hungarian authentication errors, and strong-password suggestion
- [x] clickable social buttons plus avatar refresh, crop, zoom, and positioning persistence
- [x] Chat profanity masking and automatic message/avatar refresh
- [x] native admin panel scope and readable content with concise save/cancel errors
- [x] final loading/card/control polish and test-AdMob placement

v0.99.5 is complete, phone-verified by the project owner, and closed. The ARM64 debug APK is `build/HUHS-v0.99.5+1-arm64-debug.apk`.

### v0.99.6 - complete

- [x] save gallery images to the device, including the pre-Android 10 permission fallback
- [x] make widget tests Firebase-safe and restore a green test run
- [x] update Gradle, Android Gradle Plugin and Kotlin compatibility
- [x] finalize the full HUHS-logo startup animation
- [x] polish profile and Chat avatar refresh/cache behavior
- [x] audit Hungarian text and character encoding
- [x] resolve remaining accessibility and layout-overflow issues
- [x] verify AdMob test placement and display
- [x] build and verify the final ARM64 debug test APK

v0.99.6 is complete after passing `flutter analyze` and the full `flutter test` suite. The final ARM64-only debug artifact is `build/HUHS-v0.99.6+1-arm64-debug.apk`; Graphify was refreshed after the final source and documentation changes.

### v0.99.7 - Community follow-up (complete)

- [x] allow verified-email users to claim a DJ profile after matching the private or artist-owned booking e-mail; the Hungarian Hardstyle-managed booking address never qualifies as proof
- [x] add registered-user search/listing under `Több`; the list filters from the first typed character
- [x] add admin-triggered personalized event and organizer notifications for favorited records
- [x] add community moderation follow-up with reporting, blocking, blocked-post filtering, and admin report visibility

Firebase rules and the `claimArtistProfile`/`sendPersonalizedPush`/`getArtistClaimStatus`/`getMyClaimedArtists` Cloud Functions are deployed. Analyzer, Flutter tests, and Cloud Function syntax checks pass. The final ARM64 debug test APK is `build/HUHS-v0.99.7+3-arm64-debug.apk`.

### v0.99.7+3 follow-up (complete)

- [x] Show one `Saját DJ-adatlap megnyitása` button on the user's profile; it opens the native in-app DJ detail screen through the deployed `getMyClaimedArtists` callable.

The v0.99.999 security-hardening and Android public-QA pass owns R8/resource shrinking, Dart obfuscation, release signing, HTTPS-only networking, backup disablement and verification of existing backend rate limits. The paid Label purchase extension is part of the current v1.0 release; the Label preview catalog is closed in v0.99.89.

### v0.99.8 closure (2026-08-06)

v0.99.8 is complete and closed. Final ARM64 debug test APK: `build/HUHS-v0.99.8+16-arm64-debug.apk`. Completed: friend requests, push delivery and push-to-requester profile navigation; accept/reject/unfriend; live Chat role/access badges; public profiles and friends; favorite DJs/organizers on profiles with favorite news excluded; planned events and attendance; registered Chat writes; Chat author profile navigation; report management; biometric session handling; and admin role/access management. Firebase rules and the connection-request FCM trigger are deployed. Analyzer, full Flutter tests, Cloud Function syntax checks and Graphify refresh pass. v1.0 retains security hardening, obfuscation, release signing, purchase/store work and final release preparation.

### v0.99.89 - Label release catalog (complete; 2026-08-06)

v0.99.89 is complete. The Label tab is between Chat and Több and includes WordPress release records, clickable multiple artists, cover, genre, external links and preview playback. MP3/WAV uploads are temporary sources only: FFmpeg creates a maximum 60-second preview from the 30th second and the source is deleted. Full-track downloads, buying and a separate store are excluded. Future paid music sales will extend this same Label catalog.

### v0.99.90 - HUHS Vezérlőközpont bugfixek (complete; 2026-08-07)

All previous builds remain complete and closed. Newly discovered issues recorded for v0.99.90:

- [x] In native Mobile API editors for Events, DJs, Organizers and related submissions, `Mégse` safely cancels without a false error or invalid form state.
- [x] Improve editor field spacing and grouping.
- [x] Let admins select DJs by display name instead of only numeric IDs.
- [x] Remove the unrequested `Személyre szabott push` controller; general and custom push remain.
- [x] Guard the controller lifecycle and dialogs against the `_dependents.isEmpty` assertion path.
- [x] Complete the targeted UX, accessibility and layout polish pass.

The owner phone-verified the fixes. v0.99.90 is closed. ARM64 debug APK: `build/HUHS-v0.99.90+3-arm64-debug.apk`. The updated existing HUHS Mobile API package is `build/huhs-mobile-api-2.4.37.zip`.

### v0.99.8 - User profile navigation and community details (closed)

Authoritative status: WordPress Mobile API `2.4.37` is the updated package for v0.99.90; the current app build is the ARM64 debug phone-test artifact. Completed v0.99.3 TypeUI/native admin, profile crop, radio, tag/genre pagination, general push, social fields, FAQ and Label catalog remain complete.

- [x] Make each profile card in `Több -> Felhasználók` tappable and open that user's native in-app profile.
- [x] Show only favorite DJs, organizers, and events on the user profile; favorite news is excluded from this profile section.
- [ ] Stabilize planned events and attendance (`Ott leszek` / `Nem leszek ott`), persistence, participant counts and friend visibility.
- [ ] Stabilize friend request/accept/reject persistence and remove false success/error states.
- [x] Keep separate Facebook, Instagram, TikTok, YouTube, and Spotify profile links (already implemented).
- [x] Show planned events and favorites on the user profile.
- [ ] Fix biometric enablement, false unlock errors, and once-per-open-app session behaviour.
- [ ] Complete registered/guest public-profile visibility, clickable friends, blocked-user list and report-status visibility.
- [x] Restrict Chat message editing and deletion to admins; normal users cannot edit or delete their own messages.

### v0.99.8 open fixes (including the former +3 follow-up)

- [ ] Show request display names/avatars instead of UIDs and retain connections consistently.
- [ ] Send connection-request push notifications reliably and remove false-success/false-failure errors.
- [x] Make profile favorites and planned events open their native detail screens.
- [ ] Complete admin report management with full details, resolve/close removal, delete/block actions, and no duplicate/mojibake UI.
- [ ] Provide unfriend/remove actions and context-sensitive public-profile friend controls.
- [ ] Allow registered non-admin Chat writes and open native profiles from Chat author name/avatar.
- [ ] Fix admin account-role changes.

### v0.4 - Foundation

Focus:

- base Flutter app
- dark UI
- WordPress backend foundations
- REST API foundation
- temporary/static screens where needed

### v0.5 - Dynamic Events

Focus:

- dynamic events in Flutter
- event detail screen
- flyer support
- ticket button
- Google Maps button
- WordPress event detail frontend

Flutter status: dynamic list, detail, flyer, ticket, Google Maps, and clickable artist/organizer relations are implemented. Both relations open real API-backed profile screens.

The Events screen includes an `Esemény beküldése` action and a validated submission form with multi-select genres loaded from WordPress. It requires backend `2.2.0` or newer to work against production.

### v0.6 - DJ Database

Focus:

- DJs menu
- DJ list
- DJ profile
- genres
- biography
- social links
- TikTok link
- upcoming events
- separate Hardstyle and Hardcore DJ categories, assignable in WordPress and filterable through the REST API
- reusable WordPress DJ directory with linked profile cards, using the `[huhs_djs]` shortcode

Flutter status: the DJ list and detail module is implemented under More and confirmed working with live data, including API search, Hardstyle/Hardcore filters, portrait-focused profile images, biography HTML, genres/categories, location, social links, and upcoming events. Event-detail artist taps use the real DJ detail provider.

The app includes a moderated `DJ beküldése` form, device image selection for the profile picture, and a `Fellépésszervezés a Hungarian Hardstyle-on keresztül` switch. Backend `2.4.1` is required for uploaded images. On approval, the submitted DJ image becomes the draft profile's `hero_image` and featured image.

### v0.7 - Organizers

Focus:

- organizers menu
- organizer list
- organizer profile
- social links
- description
- upcoming events
- organizer music genres/styles, editable in WordPress and exposed through the REST API

Flutter status: organizer search/list and full detail screens are implemented under More and confirmed against live API data, including logo, description HTML, location, genres, website/social links, and upcoming events. Event-detail organizer taps use the real organizer detail provider.

The app includes a moderated `Szervező beküldése` form. Its backend `2.4.0` route is deployed and live-verified; a successful real submission still requires an intentional app test because it creates a pending WordPress item.

### v0.8 - Rich Content

Focus:

- WordPress shortcode/rich content support
- YouTube embeds
- Spotify embeds
- TikTok embeds
- Instagram embeds
- galleries
- external link handling
- admin-only AI-assisted article importer in WordPress: accept a public source URL, extract usable article content, create Hungarian copy, and preserve supported inline media
- imported content must always be created as a draft for human review; never auto-publish AI output
- support two explicit modes: faithful translation for owned/licensed/partner content, and an original Hungarian summary/adaptation with source attribution for third-party reporting
- import images into the WordPress Media Library only when reuse rights are confirmed; otherwise require an owned/replacement image and do not hotlink or copy third-party assets automatically
- store the original source URL and attribution with the draft, keep the AI provider key server-side, and protect the fetcher against private/internal URLs, oversized responses, unsafe HTML, and timeouts

### v0.9 - Community (implemented)

Focus:

- local favorites
- allow the featured news card on Home to be marked as a favorite
- show the opened news article's title in its app-bar instead of the generic `HĂ­r` label
- show the opened event's title in its app-bar instead of a generic event label
- newsletter integration
- settings
- social links
- contact/about pages
- open related articles inside the app instead of sending users to the public website browser page
- capitalize the artist social-link label as `Website`
- rename the artist booking action from `Fellépés kérése` to `Booking` or `Fellépés lekötése`
- add the same server-managed genre/style selector to organizer profiles and organizer submissions
- push notification preparation
- Push notification requirements: notify for newly published news and events, send event reminders one week before and on the event day, and later allow admins to create/send custom push notifications from the WordPress Mobile API admin area.
- About/app information screen with runtime version and build number, developer/maintainer credit, website, contact, privacy policy, and terms links

### v0.95 - Media

Focus:

- five curated Spotify playlists in a dedicated app section, opened through the shared in-app browser
- client-side image compression before cloud upload (target 1200–1600 px width, JPEG/WebP) to reduce storage and bandwidth use

### v0.97 - Polish build (complete)

Keep this release intentionally small and low-risk:

- fix rendering of uploaded/approved DJ logos in the Flutter DJ list and profile, preserving the profile-image fallback order
- standardize DJ and organizer list thumbnails with a fixed frame, cover crop, and upper-center portrait focus
- deploy backend 2.4.20 with `Happy Hardcore` in the shared DJ, event, and organizer genre options
- keep DJ names readable in two-column cards; keep them on one line and scale long names down instead of truncating them (implemented in Flutter)
- [x] rename the event ticket action to `Jegyvásárlás`
- [x] use the Google Maps app when installed, otherwise the external browser fallback
- verify the one-week and six-hour reminders; the one-day reminder is live-verified with a five-minute WP-Cron delay

### v0.99 - Submission polish

- make event submission date, venue name, city, and address required in Flutter and WordPress validation
- add the required event address field directly below the venue name
- add event end date and end time fields and reject an end before the start
- load organizers from WordPress for an app dropdown and keep the WordPress organizer selector aligned
- require at least one genre and show inline validation text and red invalid-field styling for every missing required value
- replace blocked multipart image submission with direct Cloudinary upload (`fjxo93em` / unsigned `Hun_hs_Mobile`) and send the returned URL to WordPress for DJ, organizer, and event submissions

### v0.99.1 - Community MVP (implemented; Firebase deployment live)

- App-only registration/sign-in with e-mail/password and Google; account role is mandatory (`DJ`, `organizer`, or `partygoer`).
- Home top-left avatar opens the user's profile, showing profile image or monogram, name, bio, social links, favorites, and planned events.
- Live Feed is readable without registration. Anonymous users may publish text only under a generated `Unknown User ####` name and cannot upload images.
- Registered users may publish text and compressed snapshot images in the Live Feed.
- Live Feed messages support normal Unicode emoji and a small fixed reaction set; do not add a heavy emoji package unless the native keyboard proves insufficient.
- Use Firebase Authentication and Firestore for community data, and Cloudinary for community images.
- Keep security hardening and release signing in v1.0; v0.99.8 owns friendships, attendance, public community profiles, friend-request notifications, and completed moderation/reporting. v0.99.3 owns the completed app-admin tooling and Chat moderation.
- Add a `Több`-menu user directory/search that lists registered users only and is unavailable to guests (v0.99.7).

### v1.0 - First Public Release (later)

Focus:

- Reorganize `Több` into clear categories: `Felfedezés`, `Közösség`, `Beküldés`, `Kapcsolat és támogatás`, and `Alkalmazás`; keep Label only in its dedicated bottom tab.
- [x] Add search and collapsible sections to `Több`, and keep administration in a separate admin-only block.
- Complete UX polish across cards, spacing, icons, loading/empty/error states, touch targets, back behavior, tab history and accessibility scaling.
- Refresh the WordPress-managed FAQ with the new v0.99.999/v1.0 features and current user guidance.
- stable news
- stable events
- event details
- DJ directory
- organizer directory
- clickable genre chips with a grouped discovery screen for events, DJs, and news
- paid Hardstyle Revolution music sales (later, inside the completed Label catalog)
- Hardstyle.com is an external destination only; do not scrape or import its catalog
- show configured Hardstyle.com, Beatport, Spotify and Apple Music links at the bottom of each release detail screen
- the own shop catalog may contain both Radio Edit/Radio Version and Extended/full versions when they are intentionally uploaded as separate products
- basic community features
- a purposeful Hungarian Hardstyle-branded loading animation that does not delay startup and respects reduced-motion accessibility settings
- the full HUHS-logo startup animation with a transparent/no-white background is complete
- polished Android release
- iOS preparation if ready

Confirmed community direction (v0.99.8 scope; only security/privacy remains v1.0):

- The dedicated Live Feed bottom-navigation tab is complete.
- Registered users can chat in the live feed and publish image posts.
- Live Feed/chat image posts use the direct Cloudinary upload path.
- Add Google account sign-in and user registration/onboarding.
- Users can create and manage their own community profile. Once registration exists, make the profile reachable from the top-left of Home through a circular avatar; show the profile image or a monogram fallback.
- During onboarding, users can choose an account role: DJ, organizer, or attendee/partygoer. Role changes and privileged actions require server-side authorization.
- DJ submission is visible to DJ accounts, organizer submission to organizer accounts, and both submission flows to admins; Flutter visibility is not sufficient without matching API enforcement.
- v0.99.3 provides the admin-only HUHS Vezérlőközpont with full review, approval, editing, user, trash, settings, and management access for the WordPress Mobile API, excluding only the radio provider menu. The owner admin e-mail is configured privately during deployment and must not be hardcoded into public app content.
- Registered users can claim a DJ profile only after proving control of the private or artist-owned booking e-mail stored on that profile; this is complete in v0.99.7. The Hungarian Hardstyle-managed booking address (`info@hungarianhardstyle.hu`) is never valid claim proof.
- Users can add social-media links to their profile, see the events they plan to attend, and access favorites from the profile area.
- Users can send, accept, and manage friend connections; each profile should include an `Ismerősök` list.
- Events must include `Ott leszek` and `Nem leszek ott` attendance actions.
- Event details should include an embedded map preview where platform/API constraints allow it. The fallback should open the Google Maps app when installed and otherwise open Google Maps in the browser.
- When viewing an event, show which friends are attending it.
- User profiles and friend lists should indicate whether that person plans to attend an upcoming event.
- News, events, DJs, organizers, and the Live Feed should remain readable without registration where possible. Anonymous Live Feed text posts are allowed under a generated `Unknown User ####` name, but anonymous users cannot upload images; profiles, friendships, and attendance state require authentication.
- [x] Define and implement moderation, reporting, blocking, privacy, image upload/storage, retention, and account deletion rules.
- Registration and community accounts are app-only; do not add account registration or community UI to the public WordPress website.
- WordPress remains the source of truth for editorial content (news, events, DJs, organizers, and releases), while the app community backend may be a deliberately separate service optimized for authentication, real-time chat/feed data, friendships, attendance, and user uploads.
- Once app registration is available, DJ, organizer, and event submission actions and forms must be visible only to authenticated users. The submission API must also enforce authentication server-side; hiding the forms in Flutter is not sufficient.

### v0.99.99 - Annual HUHS Voting (complete; phone verified)

Confirmed annual voting direction for v0.99.99:

- Replace or complement the current WordPress voting extension with a dedicated Hungarian Hardstyle voting module and REST API.
- WordPress admin must manage each annual voting season, its opening/closing dates, status, rules, and candidates.
- Required annual categories are:
  - `Legjobb magyar hardstyle DJ – <év>`
  - `Legjobb magyar hardcore DJ – <év>`
  - `Legjobb magyar hardstyle zene – <év>`
  - `Legjobb magyar szervező – <év>`
  - `Legjobb külföldi DJ – <év>`
- Derive the displayed year from the voting season instead of requiring it to be typed into every category name.
- Admins must be able to add unlimited DJ, organizer, and track candidates per category, including the display data needed by the app (name/title, artist, image/cover/logo, and external links for tracks).
- Flutter must list active voting categories and candidates and allow votes to be submitted in-app.
- Flutter Home must show a prominent button for the active voting season; WordPress/admin configuration must be able to turn it on or off, and it must be hidden when no season is active.
- Voting should use authenticated app users when Google sign-in is available, with server-side one-user/one-vote enforcement per category unless a season explicitly defines different rules.
- Voting must require a registered, signed-in app account; guests cannot open or submit a vote. Category selection limits are 5 Hungarian hardstyle DJs, 3 Hungarian hardcore DJs, 2 Hungarian hardstyle tracks, 1 Hungarian organizer, and 3 international DJs.
- Before submitting a vote, ask separately whether the user wants the HUHS newsletter. Only an explicit yes may call the existing Mailchimp subscription flow; voting must remain independent from newsletter consent.
- The API must enforce voting windows and duplicate-vote protection server-side; Flutter validation alone is not sufficient.
- Define result visibility (`live`, `hidden until close`, or `admin only`), vote correction rules, audit data, abuse protection, and privacy before launch.
- Provide a complete private admin summary/dashboard with totals and per-category results. It must never be exposed by a public REST endpoint or displayed to normal app users.
- After a voting season closes, admins must be able to publish a separate public results summary for the app.
- Publishing results must be an explicit admin action; closing voting must not automatically expose results.
- The public summary should contain the season/year, category names, final ranking, candidate display data, and optionally vote totals or percentages according to the season settings.
- Never include voter identities, audit logs, moderation flags, suspicious-vote indicators, or other private admin data in the public results response.

The implementation was phone-verified in `build/HUHS-v0.99.99+6-arm64-debug.apk`. It includes one WordPress season editor with category-level `+ Jelölt hozzáadása` fields, unlimited candidates per category, DJ and organizer candidates without Spotify/YouTube fields, Spotify/YouTube support for the Hungarian hardstyle track category, category selection limits of 5/3/2/1/3, a Home entry point with a 5-second API timeout, registered-user voting with Firestore duplicate protection, separate Mailchimp consent, and a private native admin summary served by the deployed `getVotingSummary` API function. The updated existing HUHS Mobile API package is `build/huhs-mobile-api-2.4.42.zip`; Firebase Firestore rules are deployed. Test votes were cleared after verification; the build is closed.

### v0.99.999 - Android security and public QA (complete; phone verified)

- [x] R8/resource shrinking, Dart obfuscation and split debug symbols
- [x] non-debug Android release signing with a git-ignored local keystore
- [x] HTTPS-only networking and Android backup disablement
- [x] verify existing server-side authorization and rate limiting
- [x] pass the Flutter test suite and verify the signed ARM64 release APK

Artifact: `build/HUHS-v0.99.999+1-arm64-release.apk`. Phone testing, Google sign-in with the release certificate, Android QA and signing-key backup are complete. Permanent Play publication remains a v1.0 release operation; paid store work remains v1.0+.

### v1.0 - Hardstyle Revolution paid Label extension

Focus:

- rewarded-ad full MP3 download at 128 kbps only
- paid 320 kbps MP3 and WAV/lossless products must use Google Play Billing; Google Pay is not the correct in-app product API
- purchase/download history if needed

Current status: the Flutter purchase/download flow and WordPress API package are implemented, all four Wellerman Play products (Radio/Extended WAV and 320 kbps MP3) are active in Hungary, the four product IDs are populated in WordPress release 12123, the Google Play service-account secret and Play permission are active, and production AdMob units/SSV are configured. The remaining gate is final owner phone testing of the production APK/AAB before public rollout.

## Release And Store Business Model (later, not in v0.99.89)

The existing Label tab may offer a 128 kbps full MP3 after a rewarded advertisement,
plus paid 320 kbps MP3 and WAV/lossless products for the already uploaded
WordPress release records. It must not offer
unadvertised or anonymous full-MP3 downloads.

Payment requirement:

- paid digital releases are purchased through Google Play Billing (not a direct Google Pay checkout) so the Android app remains Play policy compliant

Release processing:

- upload one WAV master per release
- generate only the preview derivative server-side with FFmpeg for the catalog; store derivatives remain private until a later paid-store design exists
- run conversion as a background job, never inside the upload/API request
- keep the WAV master private and expose each derivative only after its entitlement is satisfied

Paid options inside the existing Label tab:

- 128 kbps MP3 after a rewarded advertisement
- 320 kbps MP3, example price `1.99 EUR`
- WAV/lossless, example price `2.99 EUR`
- Each release may expose separate Radio and Extended versions.
- The editor sets the actual price for each paid product.
- Current requested price defaults for the first release: WAV `700 HUF`, 320 kbps MP3 `550 HUF` for both Radio and Extended versions.

The 128 kbps rewarded-ad target may be approximately 300 HUF per unlock, but
AdMob revenue is variable and must be measured by eCPM, fill rate and geography;
the app must not promise a fixed amount per impression.

Example later paid-store UI structure:

- release title
- artist name
- preview player
- `Buy MP3` option for `320 kbps`, paid
- `Buy WAV` option for lossless, paid

Future release/store API fields should likely include:

- `id`
- `title`
- `artist_name`
- `cover_image`
- `preview_url`
- `release_type` (`paid`)
- `mp3_320_price`
- `mp3_320_url`
- `wav_price`
- `wav_url`
- `wav_master_url` (private/admin-only; never expose before purchase)
- `processing_status`
- `spotify_url`
- `youtube_url`
- `hardstyle_com_url`

## UX Direction

The app should feel:

- dark
- direct
- energetic
- music/event focused
- mobile-first
- easy to scan

Avoid turning the app into a generic landing page. The first screen should feel like the actual app experience.

Useful mobile sections:

- latest news
- upcoming events
- featured event
- quick access to tickets
- DJs
- organizers
- more/settings/social/contact

## Android Notes

Before a public Android release:

- replace `com.example...` package/application id
- set the visible app label to `Hungarian Hardstyle`
- configure release signing
- verify launcher icons
- verify permissions
- use Gradle 8.14+, Android Gradle Plugin 8.11.1+, and Kotlin 2.2.20+
- test on a physical Android device

## iOS Notes

iOS is planned later. Do not optimize for iOS first unless the user explicitly asks.

When iOS preparation starts:

- test iPhone layouts
- test iPad layouts if desired
- prepare App Store metadata
- prepare icons/screenshots
- verify web links and external intents

## Content Language

Hungarian is the primary app language.

## Coding Style

Follow existing Flutter and Dart conventions.

Prefer:

- small readable widgets
- clear model parsing
- Riverpod providers for async app data
- Dio for network calls
- explicit error handling
- simple, direct naming

Avoid:

- hardcoding real production content in Flutter
- adding unnecessary abstractions too early
- changing unrelated platform files
- large rewrites when a focused feature is requested

## Testing Expectations

At minimum:

- keep Flutter widget tests compiling
- update the default Flutter counter test if it still exists
- add focused tests for parsing models when API structures become stable

If a command cannot be run in the current environment, say so clearly.

## User Collaboration Preferences

The user prefers practical, directly usable code.

When providing code manually, prefer complete replacement file contents instead of tiny snippets or vague patch instructions.

When working inside the repo, make the actual file changes when possible and summarize what changed.

Keep explanations clear and in Hungarian unless the user asks otherwise.

When the user says "mehet", continue with the next clearly scoped implementation step without pausing for confirmation on minor sub-decisions.

When a WordPress backend change is required, never leave out the deployable WordPress files. Always identify the exact plugin files that must be uploaded, include them in the handoff (or package them when possible), and keep the Flutter/API contract changes synchronized. A Flutter-only change is incomplete when the backend contract also changed.

Do not change the Flutter app version in `pubspec.yaml` automatically. Only bump the app version when the user explicitly requests it or after confirming an objectively justified release milestone.

For major product or architecture decisions with meaningful alternatives, use the installed `grill-me` skill to clarify requirements before implementation. Do not invoke it for small, obvious, or narrowly scoped fixes.

Use the installed Ponytail plugin/rules for implementation work: prefer deleting or skipping unnecessary work, reuse existing project code, then standard/native platform features, then installed dependencies, and only write the minimum custom code that safely solves the task. Never trade away validation, security, accessibility, or data-loss protection merely to reduce code or token usage.

## Központi Cégregiszter WordPress frissítési szabály

- A Központi Cégregiszterhez a jövőben egyetlen egységes, verziózott, teljesen telepíthető WordPress-frissítőcsomag készüljön.
- Tilos minden apró javításhoz új, külön `kcr-*` pluginmappát és külön feltöltési csomagot létrehozni.
- A frissítőcsomag mindig ugyanazt a stabil plugin-slugot használja, és a meglévő plugin frissítéseként települjön.
- A csomag tartsa meg a meglévő adatokat, beállításokat, médiát, REST API-végpontokat és működő funkciókat.
- Csomagolás előtt kötelező ellenőrizni: ZIP-struktúra, fő pluginfájl, plugin fejléc, PHP szintaxis, UTF-8 karakterkódolás, verziószám és aktiválhatóság.
- A csomagot telepítés előtt helyi ellenőrzéssel, telepítés után pedig éles oldalon alapfunkciókkal kell tesztelni.
- Régi csomagok csak akkor törölhetők, ha az éles WordPress pluginlistája alapján biztosan inaktívak; az aktív jelenlegi verziót nem szabad felülírni vagy törölni.
- A leadás része legyen a pontos fájlnév, verziószám, rövid változáslista és egyértelmű telepítési utasítás.

### Aktuális KCR-takarítási emlékeztető

- FTP-n csak a WordPress adminban igazoltan inaktív, régi KCR-verziók törölhetők.
- A jelenlegi működő főplugin: `kcr-plugin-1.9.30`; ezt és az aktív pluginokat tilos törölni.
- A korábban azonosított régi/inaktív mappák: `kcr-plugin-1.9.25`, `kcr-plugin-1.9.26`, `kcr-plugin-1.9.27`, `kcr-plugin-1.9.28`, `kcr-plugin-1.9.29`, `kcr-account-ui-fix-1.0.5`, `kcr-account-ui-fix-1.0.6`, `kcr-account-ui-fix-correct-1.0.6`, `kcr-account-ui-fix-correct-1.0.7`, `kcr-account-ui-fix-correct-1.0.8`.
- A `kcr-account-1`, `kcr-account-ui-fix-correct-1.0.9` és `kozponti-cegregiszter` mappákat nem szabad találomra törölni; csak az éles pluginlistából egyértelműen igazolt inaktivitás után.
- Minden frissítés előtt meg kell őrizni a már működő kategória-, cég-, keresési-, térkép-, galéria-, üzenetküldési-, fiók- és hírlevél-funkciókat.

## Important Current Implementation Priorities

Likely next useful tasks:

Product decisions confirmed by the user:

- The old empty Tickets bottom-navigation slot is now used by the completed Live Feed/Chat destination.
- Keep Home and News as the first two bottom-navigation items. Before finalizing the remaining items, define a clear importance order for primary navigation, Home content, and the More section.
- Evaluate the main user hook around immediate utility (for example, what is happening now and which event is next). Events are a strong primary-tab candidate; the DJ directory may initially live under More unless usage testing supports promoting it.
- Event data continues to come from the WordPress events API.
- Artist/DJ names and the organizer on event detail must be clickable.
- Artist and organizer event relations open dedicated API-backed profile screens and are confirmed against live data.
- Live Feed chat and image posting are already implemented and are not v1.0 future work.
- v1.0 focuses on purchase/store work and remaining Android public-release quality. Apple account sign-in and iOS remain deferred until an Apple Developer Program membership is available.
- Label purchase verification uses the Firebase `verifyLabelPurchase` callable and Google Play Developer API. The `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` value is a Firebase Secret Manager secret only; never commit it or expose it to Flutter. Product IDs remain WordPress release metadata.
- Label Play-product synchronization is implemented through the Firebase `syncWordPressLabelProducts` scheduled function (every five minutes) and the admin-only `syncLabelProducts` callable. It reads visible, audio-ready WordPress releases, creates or updates the four configured Hungarian one-time products at the WordPress editor prices, activates their purchase option, and writes the deterministic product IDs back through the authenticated WordPress API. The 128 kbps rewarded-ad derivative is intentionally not a Play product. WordPress API `2.4.48` contains the protected metadata update route; the route and both current audio-ready releases are live-verified. After the Play service account was granted Admin access, the scheduled sync no longer reports the earlier 403 permission failures.
- Critical Play catalog fixes (2026-08-28): the individual one-time-product upsert must use `monetization.onetimeproducts.patch` with `allowMissing=true`, not the previous per-product `batchUpdate` route. In the Node `googleapis` client, the required REST query field must be passed as the flattened `'regionsVersion.version'` parameter; passing `{ regionsVersion: { version: '2025/03' } }` serializes to `regionsVersion[version]` and causes HTTP 400 `INVALID_ARGUMENT`. The previous route also returned HTTP 500 `backendError` for both existing-product updates and new-product creation. After deploying the flattened PATCH parameter, release 12353 (Denoiser - Can't Stop Me) produced four `status: 'ok'` items at 700/550/700/550 HUF and completed the WordPress product-ID writeback. Do not regress this back to per-product `batchUpdate` or object-form `regionsVersion`; preserve the four deterministic product IDs and verify Play readback before WordPress ID writeback.
- Current 1.0 live status (2026-08-13): all four Play Billing products for releases 12123 and 12185 are active in Hungary with the requested 700/550 HUF base prices. The `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` secret is enabled, the Play service account has Admin access, `verifyLabelPurchase`/`getLabelDownloadUrl`/`admobRewardedSsv` and the scheduled product synchronizer are deployed, and production AdMob Banner/Rewarded units plus the SSV callback are configured. The final signed ARM64 APK and AAB for v1.0.0+9 were rebuilt and verified; the remaining gate is the project owner's final phone smoke test of that exact artifact.
- Follow-up tasks for the next Android update: investigate the still-failing production AdMob flow on the Play-installed build and fix ordinary e-mail/password registration verification. Optional Google Authenticator MFA, Android PIN/password/pattern protection, independent Settings toggles, session-level authentication, and the Google-sign-in exclusion are complete. Do not remove the existing biometric flow.
- The e-mail-verification task must include a Firebase-side delivery/template/log audit and an app-side verified-state refresh plus visible resend flow; the current source calls `sendEmailVerification`, but ordinary e-mail registration was reported as not working end to end.
- Owner-reported next-build fixes: investigate and fix AdMob banner ads not loading in the Play-installed closed test while preserving the working rewarded flow; fix the Hungarian mojibake in the registration two-factor warning and related auth messages; complete the ordinary e-mail/password verification flow; fully sign out and clear local state after account deletion; make release previews replayable, stop the radio when a preview starts, and support seeking within the 60-second preview.
- Owner-reported UI bug: event attendance buttons must color only the active choice red — `Ott leszek` when selected, or `Nem leszek ott` when selected — while the inactive choice remains neutral.
- Owner-reported UI bug: the event-submission organizer dropdown/menu overlays the address, organizer and genre fields. Fix the menu/field layout so labels, values and genre chips never overlap and remain readable on phones and tablets.
- Owner-reported backend bug: an event submission was received twice by WordPress. Audit and add idempotency protection so repeated requests cannot create duplicate event submissions; apply the same review to DJ and organizer submissions.
- Owner-reported backend bug: a custom push was delivered twice. Audit the admin request path and FCM token deduplication so one explicit custom-push action produces one notification per device.
- Owner-reported backend bug: event-submission pushes are broadcast to everyone. Submission notifications for events, DJs and organizers must be routed only to the admin recipient, never to normal user tokens.
- Owner-reported UI bug: the Community Administration account-role dropdown opens on the wrong layer and overlaps adjacent user cards/text. Fix the dropdown positioning/overlay so the role choices stay attached to the active user card and remain readable on phones and tablets.
- Owner-reported UX bug: the Home news slider's bottom page indicators do not move with the visible slide. Keep the indicator index synchronized with the actual slider page during swipes and automatic rotation.
- Owner-reported authorization bug: a regular registered user can change the profile display name. Audit the Flutter edit path and Firestore/server authorization, then enforce the intended immutable-name rule outside admin access as well.
- Owner-reported Android navigation rule: the system back button may exit the app only on the Home screen. Every other screen, nested navigator and modal must return to the previous screen instead.
- Owner-reported Label search bug: after entering a query such as “COS”, the displayed query disappears when results refresh and cannot be cleared/restored. Preserve the controller value and provide a reliable clear/edit path.
- Technical requirement for the fix: the API currently stores FCM tokens without an authenticated owner, so the next build must bind token registration to the Firebase user/admin identity and add a recipient-targeted push path. This requires coordinated Flutter APK and WordPress API changes; do not disable broadcast globally because editorial/news/custom pushes still need their existing audience.
- Owner-reported UX bug: the translucent bottom feedback bubble can remain indefinitely after actions such as event submission. Give transient success/error feedback a 7–8 second automatic dismissal while retaining manual swipe dismissal.
- Owner-requested auth feature: an authenticated email/password user needs an in-app password-change flow with the required Firebase reauthentication.
- Owner-requested auth validation: email/password registration must include a separate password-confirmation field and reject mismatches before account creation.
- Later-build UX task, explicitly deferred beyond the next fix build: implement a true landscape phone layout instead of rotating the portrait UI. Rework radio/navigation density, news/event cards, forms, detail screens and modal sizing for usable landscape phones.
- v0.99.99 should include an annual WordPress-managed Top DJ and Top Track voting API with in-app voting and an admin-controlled Home entry point.
- Organizer profiles and submissions now support server-managed selectable music genres/styles (backend 2.4.9 prepared; deploy and live-test still pending).
- Add an About/App information area under More. Read the app version and build number from package metadata instead of hardcoding them, and include developer credit plus relevant website, contact, privacy, and terms links.
- Refactor navigation into a persistent shell so the bottom tabs remain visible on news, event, DJ, and organizer detail screens. Do not duplicate the NavigationBar inside each detail screen; preserve the active tab and each tab's navigation history.
- Keep using the shared in-app browser for ordinary article, event, profile, ticket, shortcode, and About-page links. Media and Maps may remain intentional native-app exceptions.
- Keep plain-text `http://` and `https://` URL linkification enabled for WordPress news and event HTML. A URL styled as a link must always be tappable even when the source did not wrap it in an HTML `<a>` tag.
- Event submission retains its general event/Facebook link field, while published event records now expose the dedicated `facebook_event_url` field through backend 2.4.3.
- The public WordPress `/events/` directory should later include an `Esemény beküldése` call-to-action that leads to the submission flow; once app registration exists, the action must require authentication.

1. Fix the default Flutter widget test so it matches `HungarianHardstyleApp`.
2. Clean up asset folder references or create the missing asset folders.
3. Set Android app label and application id before release.
4. Keep the working News API/list/detail flow intact when refactoring.
5. Improve News loading, empty, and error states if needed.
6. Improve WordPress rich content/HTML rendering for news if needed.
7. Add and connect dedicated artist list/detail REST endpoints.
8. Keep the deployed organizer list/detail REST endpoints compatible with the Flutter organizer module.
9. Keep organizer genres/styles from backend 2.4.9 compatible with the working organizer API.
10. Keep upcoming events working on DJ and organizer profiles.
11. Do not bump the app version unless the user explicitly asks; the version has not intentionally changed yet.

## Agent Reminder

Before making code changes:

- inspect the relevant files
- preserve existing working behavior
- do not treat placeholders as bugs unless they block the requested task
- keep changes scoped to the requested feature
- summarize what changed and what could not be verified
Documentation note: backend package entries older than 2.4.33 are historical deployment notes; the current active package is 2.4.33.
- v0.99.3 source fix: the radio Stop action now synchronizes against the native playback service before deciding Play/Stop.
- v0.99.3 completed fix: profile images use the persisted raw Cloudinary URL and fall back to a name/e-mail monogram; persisted X/Y positioning and zoom are implemented and phone-verified.
- v0.99.3 source fix: the startup announcement is stored in WordPress and served by a public endpoint so it remains visible on every app launch until an admin disables or removes it.
- Phone verification of the v0.99.3 fixes is complete in Flutter build `0.99.3+27`.
- WordPress Mobile API `2.4.33` is active at `build/huhs-mobile-api-2.4.33.zip`; it adds the managed FAQ post type/category editor and paginated public FAQ endpoint. It is deployed and live-verified and must not be repeatedly rechecked.
- v0.99.8+2 bugfix pass (historical, superseded by the active v0.99.8+7 build): attendance records now include the validated event ID; attendance errors are surfaced; connection-request status refreshes after send; the named `hungarian-hardstyle` database push trigger `notifyConnectionRequest` is deployed; biometric enablement checks real device support; `MainActivity` uses `FlutterFragmentActivity` for `local_auth`. Current v0.99.8 friend/profile/notification and moderation fixes are closed.
