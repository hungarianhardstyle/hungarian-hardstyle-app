# Hungarian Hardstyle App - Project Context for AI Agents

### DJ-adatlap CLAIM: admin-kivétel megszüntetése + működő értesítés-koppintás (2026-09-21, AAB **348** + plugin **2.6.0**)

- **A TULAJDONOS JELZÉSEI:** *„egy dj beküldött egy dj-t… valamiért tudtam ÉN mint admin claimelni - ami hiba"*, *„most a Denoiser accomon a Sunshite State dj van claimelve - ami hiba - lekéne szedni rólam"*, majd a szabály: *„Claimelni csak az tudja a feltett dj adatlapot, akinek egyezik az email címe amivel regelt a dj adatlapon szereplő email címmel"* és *„a claim akkor jelenjen CSAK meg ha valamelyik email cím egyezik (booking vagy privát)"*. Kiegészítés: *„ha valaki megnyitja egy user adatlapját és claimelt egy DJ profilt, látszódjon az is ott, egy kattintható kártyaként"*, végül egy külön hiba: *„az »új dj került fel« notifyra nem nyitja meg az adott dj adalapját, ha rányomok"*.
- **A MÉRT GYÖKEREK (négy külön hiba, mind kód-szinten igazolva):**
  1. **AZ ADMIN-KIVÉTEL (a lényeg):** a `claimArtistProfile`-ban `const isAdminClaim = email === ADMIN_EMAIL;`, és a kapu `(!isAdminClaim && booking_email !== email)` volt — vagyis **az admin bármelyik adatlapot claimelhette**, és csak a `booking_email`-t hasonlította. Élesben pont ez vitte a tulajdonos fiókjára egy **idegen** DJ adatlapját.
  2. **A GOMB MINDENKINEK LÁTSZOTT:** a képernyő `emailVerified == true`-ra tette ki a claim gombot (nem volt jogosultság-kérdés).
  3. **A CLAIMELT ADATLAPOKAT MÁSRÓL NEM LEHETETT OLVASNI:** az `artist_claims` szabálya csak a saját UID-re (vagy adminra) enged olvasást, és a publikus profil-projekció nem tartalmaz claim-mezőt → **szerver-oldali callable kellett**.
  4. **AZ ÉRTESÍTÉS-ÚTVÁLASZTÓ NÉMA VOLT:** a `notification_center_screen.dart::_open` nem ismerte az `artist` (és `organizer`, `chat_report`) célpontot, ezért a koppintás a szám-feldolgozás után **egyik ágba sem** esett → semmi nem történt. (A `chat_report` azonosítója **nem szám**, ezért azt a szám-feldolgozás **előtt** kell kezelni.)
- **A MEGOLDÁS:**
  - **ÚJ tiszta modul** `functions/artist-claim-plan.js`: `normalizeClaimEmail`, `claimEmailsFor` (booking + **privát** `contact_email`, a ház `info@` címe nélkül), `artistClaimState` (→ `{claimed, mine, canClaim, reason}`), `claimErrorMessage` (magyar), `artistClaimRecord`, `claimedArtistIds`. **Admin-kivétel nincs** — a szabály mindenkire ugyanaz.
  - **`claimArtistProfile`:** a döntés a tiszta modulon megy át, a címeket a **privát WordPress-végpontról** kéri (5 perces memória-gyorsítótárral), és **visszaesik a nyilvános `booking_email`-re**, ha a privát végpont még nincs fent (a plugin-frissítés előtti ablakban is működjön).
  - **`getArtistClaimStatus`** most `{claimed, mine, canClaim}`-t ad (**e-mail cím nélkül**), ezért a gomb **csak egyező címmél** jelenik meg; **`releaseArtistClaim`** (a saját claimet bárki, a hibásat az admin) és **`getClaimedArtistsForUser`** (a profil-kártyákhoz) ÚJ callable-ok.
  - **Kliens:** `lib/models/artist_claim_status.dart` (ÚJ), `artistClaimStatusProvider` most ezt adja vissza, a DJ-adatlap gombja `claim.canClaim`-hez kötött, `mine` esetén **„Claim visszavonása"**, foglaltnál magyarázó sor; a nyilvános profilon **`_ClaimedArtistsSection` + `_ClaimedArtistCard`** (kép + név, koppintásra `ArtistDetailScreen`).
  - **ÉRTESÍTÉS:** az útválasztó megkapta az `artist`, `organizer` és `chat_report` ágakat (előbbi kettő a `ArtistDetailScreen`/`OrganizerDetailScreen` képernyőt nyitja).
- **PLUGIN 2.6.0 (a tulajdonos tölti fel):** az `api-artists.php` új **privát** (`manage_options`) végpontja `GET /artists/<id>/claim-emails` (booking + privát cím, kisbetűsítve) és egy **idempotens** `POST /artists/claim-emails/backfill`, ami a **jóváhagyásnál eddig elvesző** `contact_email`-t átmásolja a meglévő DJ-adatlapokra (csak ha még nincs ott — kézzel javított címet nem ír felül). Emellett a `submissions.php` jóváhagyása **mostantól átviszi** a `contact_email`-t az új adatlapra.
- **AZ ÉLES ADAT JAVÍTÁSA (mérve, `tools/check-artist-claims.mjs`):** a gyűjteményben **2 claim** volt, mindkettő a `d***@gmail.com` (admin) címmel: artist **12812 „Sunshine State"** és **11678 „Denoiser"**. A **hibásat (12812) töröltük** (`--release 12812 --confirm`), azóta **1 claim** maradt (a tulajdonos saját DJ-adatlapja). Az eszköz `--self-test`-je **9/9**.
- **BIZONYÍTÉK:** `flutter analyze lib test` **tiszta**; `flutter test` **640/640**; `node --test functions/artist-claim-plan.test.cjs` **15/15** (köztük a **szerver-forrás** ellenőrzése: nincs `isAdminClaim`, és a címek a privát végpontról jönnek); `functions/security-permissions.test.cjs` **36/36** (az új App Check-es callable felvéve a listába); `node tools/check-artist-claims.mjs --self-test` **9/9**; `check-play-notes` **MINDEN ELLENŐRZÉS RENDBEN**; `check-signing-identity` 1 identitás.
- **A FUNKCIÓK TELEPÍTVE** (`npx firebase deploy --only functions`), és a `firebase functions:list` szerint mind a négy callable fent van (`claimArtistProfile`, `getArtistClaimStatus`, `releaseArtistClaim`, `getClaimedArtistsForUser`).
- **Csomagok:** `build/HUHS-v1.0.0+348-release.aab` (versionCode **348**, 80,49 MB, SHA-256 `B2770AD59E810934B1502A9AA286AF81F8D16F3391765D55FC7EE80CE5484036`) **és** `build/huhs-mobile-api-2.6.0.zip` (45 fájl, 147,0 KB, SHA-256 `289E8CC099DD6B43D131A736E54740A8F8232769C9D7DDE633272AAC4901BCFE`). **Mindkettőt a tulajdonos tölti fel** (AAB → zárt teszt sáv, plugin → WordPress).
- **⚠️ TELEPÍTÉSI SORREND ÉS KORLÁT:** a **privát cím** útja csak a **plugin 2.6.0 felkerülése után** él (addig a függvény a nyilvános `booking_email`-re esik vissza, és ha az a ház címe, a gomb nem jelenik meg). A `backfill` végpontot egyszer futtatni kell, különben a **korábban** jóváhagyott DJ-adatlapokon nincs privát cím. **⚠️ A gépen nincs PHP**, ezért a plugin kódját **nem tudtam lefuttatni/lintelni** — a szintaktikát kézzel ellenőriztem és a kód a WordPress szabványos mintáit követi; ha a feltöltés hibát jelez, a `huhs_backfill_artist_claim_emails`/`huhs_get_artist_claim_emails` a két új függvény az `api-artists.php`-ban.
- **✅ A PLUGIN 2.6.0 FELKERÜLT ÉS A PÓTLÁS LEFUTOTT (2026-09-21, mérve):** a tulajdonos jelezte („2.6.0 feltöltve"), mire (1) a `--ping 12812` igazolta, hogy a **privát végpont él** és adja a címkéket, (2) a `--backfill --confirm` **1 adatlapot pótolt** — ez a **12812 „Sunshine State"**, vagyis a beküldött DJ a saját (privát) címével **most már claimelheti** a saját adatlapját; (3) a `--scan-emails` szerint **16 publikált adatlapból 11-en van cím, 5-en nincs**: **11678 „Denoiser"**, 11726 „Adam Bass", 11731 „Impulz", 11734 „Noizemaker", 12373 „Goze" — ezeket **a DJ sem tudja claimelni**, amíg nincs rajtuk booking vagy privát e-mail (a WordPress admin „Nyilvános booking e-mail" mezője elég hozzá). **⚠️ WordPress object cache:** közvetlenül a pótlás után az érték még **elavultan üres** lehet (ezt láttam is a 12812-nél), ezért a mérés néhány másodperc késleltetéssel ismételendő.
- **✅ A HÁZ-DOMAIN SZABÁLY (2026-09-21, a tulajdonos észrevétele — SZERVEROLDALI, AAB NEM kell hozzá):** *„info@ mail lehet privát, ha nem hungarianhardstyle.hu a domain sztem"*. Ezért a claim **nem a pontos címre**, hanem a **domainre** szűr: `isHouseEmail()` szerint minden `@hungarianhardstyle.hu` végű cím (a `HOUSE_DOMAIN` konstans) **kizárt** — a `claimEmailsFor` nem veszi be őket, és a ház domainjével bejelentkező fiók sem claimelhet (`reason: 'house-email'`). **DE** egy **más** domainen lévő `info@` (pl. `info@sajatdomain.hu`) a DJ **privát címe lehet**, ezért azt **el kell fogadni** — pont ez volt az észrevétel lényege (a korábbi pontos egyezés mellett a `booking@hungarianhardstyle.hu` átcsúszott volna). Az `info@hungarianhardstyle.hu` (`HOUSE_EMAIL`) marad a ház elsődleges címe. **Bizonyíték:** `functions/artist-claim-plan.test.cjs` **18/18** (+3 új teszt: `info@sajatdomain.hu` elfogadva, ház-domain cím elutasítva, ház-domainnévvel bejelentkező elutasítva), `node tools/check-artist-claims.mjs --self-test` **13/13**; a függvények **újratelepítve** (a kliens változatlan, ezért **a 348-as AAB marad érvényben**).
- **📌 A TULAJDONOS DÖNTÉSE — JÖVŐBELI TEENDŐ, EGYELŐRE TILOS MEGCSINÁLNI (2026-09-21):** a tulajdonos szavai: *„ja mert hungarian hardstyle bookingolja, ezt lehet átkéne majd írni info@hungarianhardstyle.hu -ra, ha általunk intézi a bookingot és itt majd a privát e-mail címe számítson, ha azzal regelt :D btw egyelőre ezt NE csináld meg csak jegyezd meg"*.
  - **A MEGFIGYELÉS, AMIRE EZ VÁLASZ:** a `--scan-emails` mérése szerint **10 adatlap** booking e-mailje a tulajdonos **személyes** címe (`d***@gmail.com`) — azért, mert a bookingot a Hungarian Hardstyle intézi.
  - **A JAVASLAT (későbbi kör):** ahol a HH intézi a bookingot, ott a `booking_email` legyen a ház címe (`info@hungarianhardstyle.hu`, ez a `booking_via_huhs` jelentése), és a claim **a DJ privát (`contact_email`) címén** működjön — vagyis az számítson, amivel a DJ regisztrált/beküldte az adatlapot.
  - **⚠️ AMIT EZÉRT TUDNI KELL (a jelenlegi kód következményei):** (1) a `claimEmailsFor` a **ház címet szándékosan kihagyja**, tehát `info@hungarianhardstyle.hu`-val **senki nem claimelhet** — pont ez a cél; (2) ezért az érintett adatlapokon a **privát cím megléte lesz a feltétel**: ahol nincs (ma **5 ilyen** van: 11678 „Denoiser", 11726 „Adam Bass", 11731 „Impulz", 11734 „Noizemaker", 12373 „Goze"), ott **senki** nem tud claimelni, amíg a privát cím oda nem kerül; (3) a tulajdonos a saját `d***@gmail.com` címével az átírás **után már nem** claimelheti ezeket az adatlapokat (ma viszont igen) — ha ez kell, a privát címeket előbb pótolni kell; (4) a meglévő claim-eket az átírás **nem** érinti (azok a Firestore-ban vannak).
  - **A 10 érintett adatlap (2026-09-21-i mérés, csak a cím maszkolt):** 11724 „Outragers", 11727 „Dr Skull", 11730 „Peacey", 12301 „Cyanotic", 12378 „Nu-Clear", 12444 „Capital Noise" (a fenti lista a `--scan-emails` kimenetéből; a többi cím a DJ-k saját domainje, azokat nem kell átírni).
  - **ÁLLAPOT:** *egyelőre **NE** csináld meg* — a feljegyzés a következő körre szól.
- **ISMERT, DOKUMENTÁLT HIÁNY:** a `prize` célpontú értesítés (nyeremény-nyertes) **még nem nyit** semmit: a kliensnek nincs „nyeremény azonosító alapján" lekérdezése (csak az **aktív** játéké). Ezt a `test/screens/notification_targets_test.dart` kifejezetten felsorolja, ezért nem tud csendben elfelejtődni.

### A lejátszó „agyát" átvitte a szolgáltatás + tabletes kártyák (2026-09-21, AAB **347**)

- **A tulajdonos kérése:** előbb megkérdezte, *„fejtsd ki mi a baj ezzel"* a kimondott korlátról (a képernyő elhagyása után a zárképernyő következő/előző gombja nem hat), majd a felajánlott irányok közül a **teljes javítást** választotta: *„Teljes javítás: a sor a szolgáltatásé"*. Közben jelezte: *„természetesen a lejátszót is csináld meg"*.
- **A MÉRT GYÖKÉR (kód-szinten, nem feltételezés):** a zárképernyő gombjai **nem a lejátszót** vezérelték, hanem a **képernyő visszahívásait**: `MusicAudioHandler.skipToNext()` az `onNext` mezőt hívta, ha nem `null` — a képernyő `dispose()`-a pedig **null-ra** állította (`my_music_screen.dart`). A szolgáltatás élt tovább (ez a háttér-lejátszás lényege), de a „agy" megszűnt: a gomb **ott maradt és néma volt**. **Ugyanez volt a nagyobb baj is:** a dal végi továbblépést a képernyő `playerStateStream`-figyelője (`ProcessingState.completed` → `_advance()`) végezte, és a `dispose` **ezt a feliratkozást is** lemondta — ezért a dal végén **megállt a zene**. (Ráadásul a vezérlők listája statikus: a `MediaControl.skipToPrevious/skipToNext` mindig benne van, ezért a felület **halott gombot** mutatott — néma hibaként, üzenet nélkül.)
- **A MEGOLDÁS — három réteg, egy döntéshozó:**
  1. **`lib/services/music_queue_player.dart` (ÚJ):** `MusicQueueTrack` (kulcs + **fájlútvonal** + `MediaItem`), **`MusicQueuePlan`** (tiszta: alap-sorrend, keverés, kurzor — lejátszó **nélkül** mérhető) és **`MusicQueuePlayer`** (végrehajtó: `playAt`/`next`/`previous`/`toggle`/`stop`, `completed` → automatikus továbblépés, hossz közzététele, magyar hibaüzenet).
  2. **`MusicAudioHandler`:** a **sor az övé** (`late final MusicQueuePlayer session`), a `skipToNext`/`skipToPrevious`/`setRepeatMode`/`setShuffleMode` már **nem visszahívás**, hanem a sor művelete; a `_toPlaybackState` az ismétlést/keverést is közzéteszi (eddig minden esemény visszaállította a zárképernyőn).
  3. **`my_music_screen.dart`:** már csak az **alap-sorrendet adja át** (`_pushBaseOrder(paths)`: letöltött + nincs kivéve + kézi sorrend + **fájlútvonalak**), és **kirajzolja** a szolgáltatás állapotát (`_onSessionTracks`/`_onSessionCurrent`/`_onSessionModes`/`_onSessionError` figyelőkön). A `_publishMetadata`, a `_starting`/`_pendingIndex` kapu, a `_loadedSourceKey` és a `_rebuildOrder` **megszűnt** (mindegyik átköltözött), a `dispose` pedig **nem** bontja le a sort.
- **⚠️ HÁROM CSAPDA, amit menet közben KELLETT kezelni:**
  1. **A keverés nem keverhet újra minden pásztázásnál.** A `setBaseOrder` eleve újraszámol, ezért **változatlan alap-sorrendnél és bekapcsolt keverésnél megtartjuk a kevert sorrendet** (`_baseSignature` + `_shuffle && unchanged`) — különben a fájlpásztázás (új vásárlás, katalógus-újraépítés) minden alkalommal újrakevert volna, és a „következő" gomb **ugrált** volna. Ezt a szabályt **külön teszt** méri.
  2. **`late final session` és a lejátszó-események sorrendje:** a `_toPlaybackState` a sor állapotát is olvassa, ezért a `session`-t **előbb** kell létrehozni, mint a `playbackEventStream`-feliratkozást — különben egy korai esemény `LateInitializationError`-t dobna.
  3. **A megjelenítés hibája nem némíthatja el a zenét** (ez volt a 346-os éles hiba): a közzététel **mindkét oldalon** saját `try`/`catch`-ben fut (`_publishPlan` a sorban, `_publishSession`/`_publishModes` a szolgáltatásban), és a hibát a naplóba írjuk.
- **TABLETES JAVÍTÁSOK (ugyanabban a csomagban, a tulajdonos jelzései):** *„tableten a kiemelt hírek a hírek tabon nagyon nagyok, olyannak kéne lennie mint a többi hír kártyának"*, *„tableten a kvíz kártya is kurvanagy"*, majd a pontosítás: *„álló nézetben okés a tablet, csak a fekvőre vonatkozik amit írtam"*.
  - **A gyökér mindkettőnél ugyanaz:** széles (fekvő) nézetben a kártya a **teljes szélességet** kitölti, a hírkártya 16:9-es képe és a játék `fitWidth` borítója pedig az eredeti képarányával együtt nő — 1200 px széles tableten ez **675 px magas kép**, azaz az egész képernyő. A „Friss hírek" lista ezt **már kezelte** (max. 760 px + **sávos** kártya), a „Kiemelt hírek" sor **nem** — ezért nézett ki másképp (ez volt a hiba lényege: két helyen volt a szabály).
  - **Javítás 1 (egy szabály egy helyen):** új **`AdaptiveNewsCard`** a `news_card.dart`-ban (fekvő nézet → `maxLandscapeWidth = 760` + `compact: landscape`), és a hírek tab **mindkét** helye ezt használja. A teszt **darabszámot** mér (`AdaptiveNewsCard(` == `NewsCard(` előfordulás), mert a `NewsCard(` szöveg benne van az új névben — így nem maradhat külön, kezeletlen hívás.
  - **Javítás 2:** a `_ActiveGameCard` borítója **csak fekvő nézetben** kap `maxHeight: 260` korlátot (`BoxFit.cover`, nem `fitWidth`); **álló nézetben szándékosan semmi nem változott**, mert ott a tulajdonos szerint jó.
  - **⚠️ A teszt-eszköz csapdája:** a `news_screen.dart` **CRLF**-fel van a lemezen, ezért a többsoros forrás-lint hamisan bukott — a segéd **normalizálja a sorvéget** (`\r\n` → `\n`).
- **BIZONYÍTÉK:** `flutter analyze lib test` **tiszta**; `flutter test` **625/625** (a kör előtt 608). Új tesztek: `test/services/music_queue_plan_test.dart` (**13**, lejátszó nélkül: a szóló tétel túléli az átrendezést, a keverés permutáció 30 maggal, változatlan alapnál nem kever újra, a hossz az aktuális tételre kerül), `test/widgets/adaptive_cards_test.dart` (**3**, forrás-lint a fekvő nézetre), és **átírt** forrás-lintek a `music_audio_handler_pipe_test.dart`-ban, a `music_background_playback_test.dart`-ban, a `label_playback_plan_test.dart`-ban és a `label_library_plan_test.dart`-ban (a régi lintek a **képernyő visszahívásait** követelték meg — ezeket a **szolgáltatás sorára** írtam át, mert a régi szabály maga volt a hiba).
  - **Mutációs bizonyíték (4 helyen, mind elhasalt):** (1) a `skipToNext`-ből a `session.next()` kivétele, (2) a `next(isAutoAdvance: true)` → `false`, (3) a kiemelt sor visszaállítása `NewsCard(post: post)`-ra, (4) a `? 260` → `? double.infinity` → **5 teszt elhasalt**, majd mind a négy fájl **byte-pontosan** visszaállt (SHA-256 egyezik mind a néggyel).
- **Csomag:** `build/HUHS-v1.0.0+347-release.aab` (versionCode **347** a merge-elt manifestből, 80,46 MB, SHA-256 `BF0F6FA02EEE64BFB604C1EE2C590634103DBDC01D4A14F337B835D00C128064`), 1 aláírási identitás; a Play-jegyzet 1./1b./1c. blokkja és a changelog is a 347-re szól.
- **⚠️ A PLAY ÁLLAPOTA (mérve, `node tools/check-play-track.mjs`, 2026-09-21):** a **zárt teszt sávján a 346 van élesben** (completed, „346 (1.0.0)"), a **347 AAB már fel van töltve**, a production és a beta sáv **üres**, az internal sávon egy **üres piszkozat** maradt (Discard kell). A tulajdonos jelzése: *„346 az éles, most megy fel a 347"* — ezért a `play-notes-meta` `lastPublishedBuild` értéke **346**, és a rövid (1.) blokk **már csak a 347 újdonságait** írja le (a 346 javítása nem kell bele, mert az már kint van). **Korábbi, elavult feljegyzés:** a 346-ot egyszer „nem feltöltöttként" tartottam nyilván — ez **téves volt**, a mérés a 346-ot mutatta élesben.
- Az R8-mappingben az `AudioServiceFragmentActivity` a **valódi nevén** marad (a 345-ös keep-szabály hat), és a `libapp.so`-ban benne van az új kód (`MusicQueuePlayer`, `MusicQueuePlan`, `AdaptiveNewsCard`).
- **⚠️ ŐSZINTE KORLÁT:** futásidejű, **eszközön mért** igazolás nincs (a zárképernyős léptetés és a tabletes nézet a tulajdonos készülékén mérhető) — a bizonyíték futó teszt + forrás-lint + csomag-ellenőrzés.

### A lejátszó NÉMASÁGA: „You cannot add items while items are being added from addStream" (2026-09-21, AAB **346** javítás)

- **A tulajdonos jelzése egy képernyőfelvétellel:** a „Megvásárolt zenéim" képernyőn **angol hibaüzenet** egy csíkban (*„You cannot add items while items are being added from addStream"*), a sáv **`1/1 · 15 letöltve`** (miközben a fejléc `17 kiadvány · 22 tétel · 166.7 MB`), `0:00 / 0:00`, a kiemelt sor „MP3 96 — reklám — Letöltve a készüléken", a **rádió szól**, és a zene **el sem indul** („nem szól, nem indul el a dolog"). Kérés: *„auditáld a lejátszó működését és keress hibákat, subagentel"* + *„a hibaüzeneteket amúgy is magyarul kéne"*.
- **A MÓDSZER:** két párhuzamos **olvasási audit** (subagent) — az egyik a hangláncot (audio_service/just_audio/rxdart), a másik a képernyő állapotgépét vizsgálta —, plusz a saját reprodukciós tesztem. Ez **6 további valódi hibát** talált azon kívül, amit én láttam.
- **1. A NÉMASÁG GYÖKERE (bizonyítva, a csomagok forrásából + futó teszttel):** a `BaseAudioHandler.playbackState` egy **rxdart `BehaviorSubject`** (`audio_service-0.18.19/lib/audio_service.dart:2982`), a `Stream.pipe(consumer)` pedig a `consumer.addStream(...)`-et hívja. Az rxdart `Subject.addStream` **egyszer s mindenkorra** beállítja az `_isAddingStreamItems` jelzőt, és **csak akkor engedi el, ha a forrás lezárul** (`rxdart-0.28.0/lib/src/subjects/subject.dart:104-132`); a lejátszó `playbackEventStream`-je **soha nem zárul le**, ezért **minden** további `add()` dob (`:135-142`) — pontosan ezzel az üzenettel. A mi kódunkban ez a **konstruktorban** futott (`_player.playbackEventStream.map(...).pipe(playbackState)`), tehát a folyamat indulásától kezdve minden `playbackState.add(...)` (a `publishQueue`-ban, az ismétlés/keverés beállításában **és a `super.stop()`-ban is**) kivételt dobott.
  - **⚠️ ÁLTALÁNOS SZABÁLY:** **rxdart `Subject`-re `pipe()`-olni és közben `add()`-olni TILOS** — a `pipe` `addStream`-et indít. A `listen(subject.add)` a helyes minta. (Az rxdart 0.27.7-ben **ugyanaz** a guard van, tehát verzió-lezárás nem segít.)
  - **A javítás egy sor:** `_stateSubscription = _player.playbackEventStream.map(_toPlaybackState).listen(playbackState.add, onError: playbackState.addError);` + a feliratkozás elengedése a lezárásnál.
  - **BIZONYÍTÉK MŰSZER NÉLKÜL:** új `test/services/music_audio_handler_pipe_test.dart` — a `pipe` után az `add()` **dob** (a valódi üzenettel), a `listen`-minta után **nem**; + forrás-lint, hogy a szolgáltatás nem használ `.pipe(playbackState)`-t (a **kommenteket kiszűrve**, mert a fejléc idézi a hibás mintát).
- **2. A NÉMASÁG MÁSIK FELE (a „semmi nem szól" éles tünet):** a kivétel a `publishQueue`-ban jött, **a `setAudioSource` ELŐTT** — ezért a hangforrás **soha nem töltődött be** (innen a `0:00/0:00`), a `_currentIndex` viszont már be volt állítva (innen a piros sor). Ráadásul a rádiót már leállítottuk és a `releasePreviewPlayingState` **igaz** maradt, amitől a rádió gombja **némán működésképtelen** lett (a sáv `if (releasePreviewPlayingState.value) return;`-nel tér vissza) → az app **teljesen elhallgatott**.
  - **Javítás:** (a) a sorrend **hangforrás → lejátszás → metaadat**, a metaadat-közzététel **saját `try`-ban** (a díszítés nem akadályozhatja a zenét); (b) a hibaág **`await _releaseAudio()`-t** hív (visszaadja a hangot a rádiónak, leviszi az értesítést) és **visszaállítja** a kijelölést; (c) minden lejátszó-hiba **magyar** üzenetet ad.
- **3. A „1/1 · 15 letöltve" GYÖKERE (bizonyítva):** a sorrend **elavult pillanatképből** épült. A `_scanDownloads` a `_queue`-t a **pásztázás elején** olvasta ki, a `_downloadedSignature` pedig **ugyanabban a `changed`-ágban** íródott — ezért egy későbbi, egyező lenyomatú pásztázás **örökre** elavultan hagyta a `_order`-t (22 tétel, 15 letöltött, de 1 elemű sorrend).
  - **Javítás:** a pásztázás elején mentjük a **sor lenyomatát** (`final queueSignature = _queueSignature;`), és az `await` után **eldobjuk** az eredményt, ha a sor közben kicserélődött; emellett keverés nélkül **mindig** újraépül a sorrend (keverésnél csak változáskor, hogy ne ugorjon a „következő").
- **4. MAGYAR HIBÁÜZENETEK (a tulajdonos kérése):** a `userFacingError` eddig a `StateError` üzenetét **szó szerint** kiírta — így került a felületre az angol motor-szöveg. **Javítás:** `looksLikeForeignEngineMessage(...)` szűrő (a saját magyar üzeneteink átmennek, a keretrendszer angol fordulatai nem) + külön `lib/core/errors/playback_error.dart` (`playbackErrorMessage`): a lejátszó hibáira **mindig magyar** mondat jön (eltűnt fájl → „töltsd le újra", ismeretlen → „nem indult el, próbáld újra"), a technikai ok a naplóba megy.
- **5. TOVÁBBI, AUDITBÓL JAVÍTOTT HIBÁK:** a `queueIndex`-et **nem** írja felül a just_audio `event.currentIndex`-e (egyetlen forrásnál mindig 0/null — az értesítés mindig az első tételt jelölte volna); a **`MediaItem.duration`** közzététele (enélkül a zárképernyő tekerősávja hossz nélküli); a stop utáni **`play()` újratölt** (`ProcessingState.idle` → `load()`), különben a zárképernyő play gombja néma; a kétszeres indítás kapuja **nem dobja el** a koppintást, hanem eltárolja és a végén elindítja (`_pendingIndex`); `_advance`/`_playNext`/`_playPrevious` **lokális sorrend-másolatból** indexel (a két olvasás között a sorrend újraépülhetett → `RangeError`); a `_releaseAudio` a jelzőket a **stop után** állítja; a `dispose` a saját lejátszót csak a leállás **befejezése után** dobja el; a `_syncWithBackgroundPlayback` a **sorépítés után is** lefut (különben a visszatéréskor üres volt a kijelzés); a `_togglePlay` a **betöltött tétel azonosítóját** is nézi (`needsSourceReload`), nem csak azt, hogy van-e forrás.
- **ISMERT KORLÁT (szándékos):** a képernyő elhagyása után a zárképernyő **következő/előző** gombja nem hat (a visszahívások a képernyőhöz kötöttek, és a `dispose` leválasztja őket) — a play/szünet/stop és a tekerés viszont működik.
- **BIZONYÍTÁS:** `flutter analyze` tiszta; `flutter test` **608/608** (a kör előtt 577); új: `test/services/music_audio_handler_pipe_test.dart` (3 futásidejű viszony + 6 forrás-lint), `test/core/hungarian_error_messages_test.dart` (13), és a lejátszó állapotgépének 7 forrás-lintje. **Mutációs bizonyíték:** a `.pipe(playbackState)` visszatétele ÉS a hibaági `_releaseAudio()` törlése → **2 teszt elhasal**, majd mindkét fájl byte-pontosan visszaállt (SHA-256 egyezik).
- **Csomag:** `build/HUHS-v1.0.0+346-release.aab` (versionCode **346**, 80,43 MB, SHA-256 `662CAB098AA88923180304F52064DCB3ED102E1547165C4C3F25782FA762B859`) — a Play-jegyzet 1./1b./1c. blokkja és a changelog is frissült (a javítás is benne). **A 345-öt ez váltja.**
- **⚠️ MIÉRT 346 ÉS NEM 345 (a tulajdonos szava: „tsó, 345 már fel van töltve"):** a **345-ös versionCode MÁR HASZNÁLATBAN van** a Play zárt teszt sávján, ezért **ugyanaz a versionCode nem tölthető fel újra** — a javítást **kötelező** magasabb, szigorúan növekvő versionCode-dal kiadni. Innen a szabály: **minden további javítás új versionCode** (most 346, a következő 347). A `pubspec.yaml` (`1.0.0+346`), az `app_changelog.dart`, a Play-jegyzet meta-adatai (`currentBuild: 346`, `lastPublishedBuild: 345`) és az AAB-fájlnév is ezt tükrözi.
- **⚠️ TANULSÁG:** egy **sikeres build és tiszta `analyze` semmit nem bizonyít a futásidejű bekötésről** — ezt a hibát csak futó teszt (a `pipe`/`listen` különbség) és két független audit találta meg. A `pipe`-csapda ráadásul **némán** jelentkezik: a kód lefut, csak épp nem szól semmi.

### Zárképernyő + értesítés-vezérlés: a megvásárolt zene kikapcsolt képernyőn is szól (2026-09-20, AAB **345**)

- **A tulajdonos kérése** (a felajánlott extrák közül): *„zárképernyő + értesítés-vezérlés"* — a megvásárolt zene **kikapcsolt képernyőn is szóljon**, és a zárképernyőn/értesítésben legyen vezérlés. Emellett az utasítása: *„nem tölteném fel az aab-t amig nincs kész minden"* — ezért ez az **egy kész csomag** (a 343/344 helyett).
- **A MEGOLDÁS:** `audio_service` 0.18.19 + `audio_session` 0.2.4 (a `just_audio` már megvolt) — saját `MusicAudioHandler` adja a médiamunkamenetet. **Saját Kotlin-szolgáltatást szándékosan NEM írtunk**: a rádióé (`RadioPlaybackService`) nehezen működik jól, és érintetlen kell maradjon.
- **EGY SZABÁLY EGY HELYEN (a legfontosabb tervezési döntés):** a szolgáltatás **nem dönt** — a „következő", „előző", ismétlés és keverés **visszahíváson** megy vissza a képernyőnek (`onNext`, `onPrevious`, `onRepeatChanged`, `onShuffleChanged`), mert csak a képernyő tudja, mi van **letöltve** és mi a kevert sorrend. A szolgáltatásé csak a **lejátszás/szünet/stop/tekerés** (azok nem döntések). Így a zárképernyő gombja **pontosan azt** teszi, amit az app gombja.
- **A MEGJELENÍTÉS:** minden indításnál `MediaItem` (cím, előadó, album = változat, borító) megy a munkamenetnek (`AudioSource.file(..., tag: item)`), a sor és az aktuális tétel pedig `queue`/`mediaItem`/`queueIndex` formában — ebből lesz az értesítés és a zárképernyő. Az értesítés vezérlői: előző / play-pause / következő / stop, `MediaAction.seek` engedélyezve.
- **A KÉPERNYŐ ÉLETCIKLUSA MEGVÁLTOZOTT (szándékosan):** a képernyő elhagyása **nem állítja le** a zenét (pont ez a lényeg) — helyette a `resumeRadioWhenStopped` jelzőt adja át a szolgáltatásnak, ezért a **zárképernyőről indított stop is visszaadja a hangot a rádiónak**. Visszatéréskor a **lejátszó az igazság** (`_syncWithBackgroundPlayback`: a `currentItem` alapján áll be a kijelzés). Ha az `AudioService` nem indul el, a képernyő **a saját lejátszójával** működik tovább (tartalék, nem hibaág).
- **HANGFÓKUSZ (ugyanaz a szabály, mint a rádiónál):** `AudioSessionConfiguration.music()`; **fejhallgató kihúzása** → szünet; **hívás** → szünet, és **csak `pause` típusú megszakítás után** folytatjuk magunktól (más zene-apptól nem vesszük vissza a fókuszt); duck → halkítás.
- **MANIFEST/ACTIVITY:** `com.ryanheise.audioservice.AudioService` (foregroundServiceType=`mediaPlayback`, exported) + `MediaButtonReceiver`; a `MainActivity` bázisa **`AudioServiceFragmentActivity`** (ez a `FlutterFragmentActivity`-ből származik, ezért az ujjlenyomat/PIN-es belépés megmarad).
- **⚠️ A KÖR LEGFONTOSABB TANULSÁGA — RELEASE-ONLY CSAPDA, amit a mapping fogott meg:** az első release build **sikeres** volt, a viselkedés viszont élesben némán más lehetett volna: az R8 teljes mód a `build/app/outputs/mapping/release/mapping.txt` szerint **`com.ryanheise.audioservice.AudioServiceFragmentActivity -> R8$$REMOVED$$CLASS$$515`** — vagyis **begyúrta** az Activity bázis-osztályát, miközben a plugin `context instanceof AudioServiceFragmentActivity` ellenőrzést végez. **Javítás:** `-keep class com.ryanheise.audioservice.** { *; }` a `android/app/proguard-rules.pro`-ban; az újraépítés után a mapping **a valódi neveket** tartja meg, és a dex is tartalmazza az osztályt. **ÁLTALÁNOS SZABÁLY: ha egy csomag típus-ellenőrzésre vagy reflectionre épül, a sikeres build nem bizonyíték — a R8-mappingot kell megnézni.** (Ugyanez a hiba-osztály, mint a korábbi Firebase App Check eseténél.)
- **BIZONYÍTÁS:** új `test/services/music_background_playback_test.dart` (**19/19**, forrás-lint): a szolgáltatás + a gomb-vevő a manifestben, előtér-típussal; a **rádió szolgáltatása érintetlen**; az Activity bázis-osztálya és a BiometricPrompt megmaradása; a szolgáltatás a `runApp` **előtt** indul, a saját csatornán, `androidStopForegroundOnPause`-szal és tartalék `catch`-csel; a fókusz-szabályok; a stop **leveszi az értesítést** (`super.stop()`) és visszaadja a hangot; a döntések visszahíváson mennek; a képernyő a szolgáltatást használja (tartalékkal), `MediaItem`-et ad, és a **dispose nem állítja le** a zenét. **Mutációs bizonyíték:** az előtér-típus törlésével ÉS az `androidStopForegroundOnPause: false`-ra állításával **2 teszt elhasal**, majd mindkét fájl byte-pontosan visszaállt (SHA-256 egyezik). `flutter analyze` tiszta, `flutter test` **539/539**.
- **⚠️ ESZKÖZ-TANULSÁG (a forrás-lint segéd újabb csapdája):** a `_functionBody` a `\n\s*[A-Za-z_][\w<>, ?]*\s név\(` mintával a **hívási helyet** is eltalálja (`await _initializeBackgroundAudio();`), és `=>` alakú metódusnál (`Future<void> play() => …`) a **következő** metódus törzsét adja vissza. A javított változat a kulcsszavakat kizárja (`(?!await\b|unawaited\b|return\b|…)`), a `=>`-s metódusokat pedig teljes sorral mérjük.
- **A LEJÁTSZÁSI LISTÁRÓL KI/BE (ugyanebben a csomagban, a tulajdonos kérdésére):** *„zenét hogy tud a playlistre rakni/levenni"* — eddig **csak** a letöltéssel/törléssel lehetett (a lista = amit letöltöttél). Most a **kivett** tételeket tároljuk fiókonként (`lib/services/label_playlist_membership.dart`, `huhs.music.excluded.<uid>`), és a tétel sorában a **lista ikon** veszi ki, illetve teszi vissza (a **kuka továbbra is a fájlt törli** — a két dolog szándékosan külön gomb). A kivett tétel **a készüléken marad**, csak nem szól bele a sorba: a szűrést a tiszta `downloadedIndices(..., excluded:)` végzi, ezért a lapozás, a sor végi továbblépés és a lista is átugorja. Ha épp az szólt, a kivétel **megállítja** (nem mutatunk a sávban olyat, ami nincs a listán). A panel magától frissül (`StatefulBuilder`), a lábléc pedig megmondja, hány tétel van kivéve. **Miért a kivetteket tároljuk:** így az alapállapot változatlan (minden letöltött tétel a listán van), és egy későbbi vásárlás/letöltés **automatikusan** bekerül.
- **BIZONYÍTÁS (a lista ki/be):** `test/services/label_playlist_membership_test.dart` (**12/12**: mentés/visszaolvasás, **másik fiók nem örököl**, vendégnél nincs írás/olvasás, hibás JSON nem dob, a kulcs-tisztítás tiszta függvénye) + 4 új tiszta/logikai teszt (`excluded` szűrés) és 3 forrás-lint (a gomb megjelenik és megmondja, hogy a fájl megmarad; a sorrend szűri a kivetteket; a kivétel megállítja az épp szóló tételt). **Mutációs bizonyíték:** az `excluded: _excludedFromPlaylist` kivételével **1 lint elhasal**, majd byte-pontos visszaállás (SHA-256 egyezik). `flutter analyze` tiszta, `flutter test` **558/558**.
- **A LISTA SORRENDEZÉSE (ugyanebben a csomagban):** *„A lista kézi sorrendje (fel/le mozgatás)"* — a „Lista" panelen minden soron **fel/le nyilak**, és a sorrend fiókonként megmarad (`huhs.music.order.<uid>`). A döntés a tiszta `orderedPlaylistIndices(keys, downloaded, excluded, customOrder)`-ban van: (1) alap a **könyvtár sorrendje**, (2) a **kézi sorrend elöl** megy (de csak azokra, amik tényleg a listán vannak — így egy törölt/kivett tétel nem hagy lyukat), (3) az **új/rendezetlen** tételek a **végére** kerülnek (nem kell „felvenni"), (4) az elavult/duplikált bejegyzés nem tesz kárt. A mozgatás a **látható sorrendet** menti, ezért a következő nyíl ehhez képest lép. **Keverés közben a nyilak le vannak tiltva**, és a lábléc meg is mondja, mit kell tenni (a kevert sorrendet nem lehet értelmesen szerkeszteni). **A tulajdonos kifejezett döntése (2026-09-21):** *több, elnevezett lista és átnevezés* **NEM kell** — ne építsük meg.
- **⚠️ KÉT VALÓDI HIBA, amit a saját tesztem fogott meg (mindkettő a sorrendnél):** (1) a sorrend kulcsa a `keyFor()`-ból épült, ami **már tartalmazza** az `excluded` előtagot → **dupla prefix** lett (`huhs.music.order.huhs.music.excluded.<uid>`), ezért a hibás JSON nem törlődött; külön `orderKeyFor()` kell. (2) ismétlődő kulcsnál a `Map`-építés az **utolsó** indexet tartotta meg; most az **első** (`putIfAbsent`) — ez a stabil, kiszámítható választás.
- **BIZONYÍTÁS (lista sorrend + ki/be):** 6 új tiszta teszt (`orderedPlaylistIndices` hat szabálya, `moveInOrder` a széleken nem mozdul és nem módosítja a bemenetet) + 7 store-teszt (mentés/visszaolvasás, fiók-szétválasztás, üres sorrend törli a kulcsot, vendégnél nincs írás/olvasás, hibás JSON, `sanitizeOrderKeys`, és hogy a ki/be és a sorrend **nem ugyanaz a kulcs**) + 2 forrás-lint (nyilak + keverés-tiltás; a sorrend mentése és a `customOrder` bekötése). **Mutációs bizonyíték:** a `customOrder: _playlistOrder` kivételével **1 lint elhasal**, majd byte-pontos visszaállás (SHA-256 egyezik). `flutter analyze` tiszta, `flutter test` **577/577**. A `label_library_plan_test.dart` lapozás-lintje is átíródott `orderedPlaylistIndices`-re (a régi `downloadedIndices` helyett) — a szabály ugyanaz, csak a forrás neve és a kivétel/kézi sorrend is bekerült az állításba.
- **Csomag:** `build/HUHS-v1.0.0+345-release.aab` (versionCode **345** a merge-elt manifestből, 80,43 MB, SHA-256 `8280E863C28F66A7159E114A14EF5E5675A536CCA725EB184E76D0E526C1A3BD`), 1 aláírási identitás; a Play-jegyzet 1./1b./1c. blokkja és a changelog is a 345-re szól. **A 343/344-et ez váltja.**
  - **⚠️ EZ A CSOMAG MÁR FEL VAN TÖLTVE (2026-09-21, a tulajdonos szava: „tsó, 345 már fel van töltve")** — a zárt teszt sávján **ez a versionCode már elhasznált**, ezért a benne maradt **némaság-javítást a 346 hozza** (lásd a legfelső szakaszt), mert ugyanaz a versionCode **nem tölthető fel újra**. A 345-öt **ne** ajánld feltöltésre.
- **ŐSZINTE KORLÁT:** futásidejű, **eszközön mért** igazolás nincs (a zárképernyő és a háttér-lejátszás a tulajdonos telefonján mérhető); és ha a felhasználó a **zárképernyőről** állítja le a zenét úgy, hogy a képernyőt előtte bezárta, a rádió a jelző miatt visszakapja a hangot — ez a szándékos viselkedés, de élesben még nem láttuk.

### A lejátszó: tekerés, stop, lejátszási lista, ismétlés/keverés és „folytatás" (2026-09-20, AAB **343**)

- **A tulajdonos kérése:** *„Megvásárolt zenéknél a lejátszóba sztem kéne tekerés lehetőség, egy stop gomb és egy playlist opció is"* — majd a felajánlott extrákból ezeket választotta: **folytatás ott, ahol abbahagytad**, **ismétlés/keverés**, és **zárképernyő + értesítés-vezérlés** (utóbbi külön kör).
- **AMI ELKÉSZÜLT (kliens):**
  1. **Tekerhető folyamatjelző** — `Slider` `0:42 / 4:10` kiírással. A lényeg a részleteken van: húzás közben a **kéz számít** (`_seeking`), mert a `positionStream` 200 ms-onként jelentkezik, és különben visszarántaná a sávot; a `seek()` az `onChangeEnd`-ben fut. A pozíció/hossz **saját `StreamBuilder`-ben** él, nem a képernyő `setState`-ében — különben 200 ms-onként újrarajzolódna a teljes lista.
  2. **Stop gomb** — nem ugyanaz, mint a szünet: megáll, a szám **elejére áll**, és a **rádió visszakapja a hangot**. A mentett folytatási pontot is törli („stop = elölről"), a sávban viszont marad a cím, hogy egy koppintással újraindítható legyen.
  3. **Lejátszási lista** (lenyúló panel): **csak a letöltött** tételek a **lejátszási sorrendben** (keverésnél is), az aktuális kiemelve, koppintásra azonnal indul; felül az összegzés („17 tétel · keverve · 2 nincs letöltve"), alul pedig a magyarázat, hogy a nem letöltött tételek a kártyákon tölthetők le.
  4. **Ismétlés** (nincs → mind → egy) és **keverés**. A keverés **valódi permutáció** (Fisher–Yates), és bekapcsoláskor az **aktuális tétel az első helyre** kerül — így nem szakad meg, amit épp hallgatsz. Az ismétlés-egy **csak az automatikus** továbblépést érinti: a kézi „következő" továbbra is tovább lép (különben beragadna egy számba).
  5. **„Folytatás ott, ahol abbahagytad"** — fiókonként, 5 másodpercenként mentett pont (`LabelPlaybackMemory`, `huhs.music.last.<uid>`), és a képernyő tetején felajánlás („Folytatás: … — 1:23-tól", „Elölről" / „Folytatás"). A mentés **csak érdemi** pozícióra történik (5 s után, 10 s-nél több hátralévő résznél), és csak akkor ajánljuk fel, ha a tétel **a készüléken is megvan**.
- **A DÖNTÉS TISZTA MODULBAN VAN:** `lib/services/label_playback_plan.dart` (`downloadedIndices`, `shuffledIndices`, `playOrderFor`, `stepPlayback`, `previousPlaybackStep`, `nextPlaybackRepeat`, `playbackClock`, `worthResuming`), az emlékezet pedig `lib/services/label_playback_memory.dart`. A képernyő csak **végrehajtja** a döntést.
- **A LÁTHATÓ SZABÁLY VÁLTOZATLAN:** továbbra is **csak letöltött** zene játszható, lapozás közben **nincs letöltés**, és a fájlok **fiókonként külön mappában** vannak.
- **A LÉPÉSEK SORRENDJE (`_order`) — egy csapda, amit mérve javítottam:** a lapozás a **lejátszási sorrend** indexein lépked, nem a nyers sorén. Ezért a sor változásakor (új vásárlás, eltűnt kiadvány) a **most hallgatott tételt a kulcsa alapján kell visszakeresni**, különben a „következő" gomb egy másik zenére lépne; a sorrend pedig **csak akkor épül újra**, ha a letöltött készlet tényleg változott (különben minden fájlpásztázás átrendezné a keverést).
- **BIZONYÍTÁS:** `test/services/label_playback_plan_test.dart` (**35/35**) — a keverés permutáció (50 maggal: se kihagyás, se duplázás), az aktuális tétel az első, a léptetés a sor végén megáll / körbefordul / ismétel, az egy-ismétlés mellett a kézi léptetés nem ragad be, az óra-felirat `m:ss`, a „folytatás" szabálya (5 s / 10 s), **és forrás-lint** arra, hogy a képernyő tényleg ezt használja (Slider + `seek` + `_seeking`, stop-gomb, playlist-panel, ismétlés/keverés, `_order`-alapú lapozás, érdemi pozíció mentése 5 másodperces küszöbbel). `test/services/label_playback_memory_test.dart` (**12/12**) — mentés/visszaolvasás/törlés, **másik fiók nem örököl**, fiókváltás és külön törlés, vendégnél nincs írás/olvasás, hibás JSON nem dob, negatív/tizedes pozíció kezelése. `flutter analyze` tiszta.
- **Mutációs bizonyíték:** a stop-gombból a `_memory.clear(_uid)`-t kivéve ÉS az `_advance`-ből az `isAutoAdvance: true`-t elvéve **2 forrás-lint elhasal**, majd a fájl **byte-pontosan** visszaállt (SHA-256 egyezik).
- **⚠️ ESZKÖZ-TANULSÁG (a saját teszt-segédem hibája):** a `_functionBody` (forrás-lint segéd) addig a **név utáni első `{`**-t vette a metódus törzsének kezdetének. Amint egy metódus **néves paramétert** kapott (`_playIndex(int index, {int? startAtMs})`), a segéd a **paraméterlista** kapcsos zárójelét találta meg, és a „törzs" egyetlen új sor lett — három forrás-lint hasalt el látszólag ok nélkül. A javítás: a segéd **átugorja a `(` … `)` paraméterlistát**, és csak utána keresi a `{`-t (a minta a négy test-fájlban ott van).
- **AMI SZÁNDÉKOSAN KÜLÖN KÖR:** a zárképernyő/értesítés-vezérlés (előtér-szolgáltatás) a rádió szolgáltatásával való hangfókusz-egyeztetést is érinti, ezért nem kerül ugyanabba a csomagba a felületi javításokkal.

### A WordPress-lassulás: „nagyon lassan töltenek be" — a gyökerek és a javítás (2026-09-20, AAB **343**)

- **A tulajdonos jelzése:** *„Wordpress api lekérős dolgok nagyon lassan töltenek be, a tárhely változtatása nem opció, de pl ez az új megvárásolt zenéim is lassan tölt be"*. **A tárhely nem cserélhető, ezért a megoldás a kliens oldala.**
- **A MÉRT ALAP (3 minta/endpoint):** a WordPress **minden** kérésre **0,4–2,0 másodperc** alatt kezd válaszolni, **a válasz méretétől függetlenül** — egy **264 bájtos** válasz is **2,2 másodperc** volt, a 27 KB-os kiadványlista 0,5 s. Vagyis nem a payload a baj, hanem a **kérésszám** és a **várakozás**: a javítás nem lehet „kisebb válasz", csak **kevesebb kör** + **helyi elsőbbség** + **háttérbeli egyeztetés**.
- **A MÉRT GYÖKEREK (audit, majd javítás) — négy valódi hiba:**
  1. **`_hydratePostTags` (extra kör MINDEN hírkérésnél).** A hír-végpont a címkéket azonosítóként adja vissza, ezért a szolgáltatás **még egy** kérést indított a címkenevekért — a **hírlista, a keresés és a cikknyitás** mind fizette ezt. **Javítás:** új tiszta modul (`wordpress_tag_cache.dart`: a kulcs a **sorba rendezett** azonosítók halmaza) + mentés a meglévő állandó gyorsítótárba; találatnál **egyáltalán nincs hálózat**, lejárt értéknél pedig **háttérben** egyeztet (a kirajzolás nem vár).
  2. **A hírek megnyitása `forceRefresh: true`-val ment** — az viszont a `WordpressHeadCache`-ben **HEAD + GET**, vagyis **két** várakozás. **Javítás:** a megjelenítési út (megnyitás, keresés, kategóriaváltás) a mentett oldalt adja azonnal, a **kifejezett** frissítés (lehúzás, frissítés ikon) marad valódi, friss kérés.
  3. **A főoldali kérdőív/nyeremény sor `bypassCache: true`-val kért** a megjelenítési úton, ezért a sor **előbb nem is látszott**, csak másodpercekkel később „pattant be" (`SizedBox.shrink()`). **Javítás:** a megjelenítési út a mentett értéket rajzolja (és a háttérben egyeztet), a **kifejezett frissítés** útja külön provideren megy (`activePollRefreshProvider`) — az továbbra is **megkerüli** a cache-t. Új **helykitöltő kártya** (`HomeActionCardPlaceholder`) a valódi kártya formátumával: a főoldal nem ugrik, és nem ígérünk olyat, ami még nem biztos.
     - **⚠️ MIÉRT KELL A FRISS-ÚTNAK CACHE-T MEGKERÜLNIE (a régi teszt indoklása valós volt):** a `forceRefresh` (HEAD + ETag) a WordPress cache-elt válaszától **ugyanazt az ETag-ot** kapja, ezért a **frissen kihirdetett nyertes csak tíz perccel később** jelent meg. Ezért a frissítési út `bypassCache: true` maradt, csak **külön útra** került; a két régi provider-tesztet ezért **át kellett írni** (nem „enyhíteni") — most a friss-utat mérik.
  4. **A „Megvásárolt zenéim" `autoDispose` provider volt, gyorsítótár nélkül** — minden megnyitás elölről kérdezte le a szervert. **Javítás:** `ref.keepAlive()` + **fiókonként mentett** lista a szolgáltatásban (`load(uid:)` + `pendingRefresh(uid)`), a háttér-ellenőrzés után a provider újraszámol. **Emellett** a nyilvános listáról eltűnt kiadvány jelölése is **megmarad 24 óráig** (`lib/services/label_release_availability.dart`), különben minden megnyitáskor újra lefutott volna az egyenkénti `getRelease` (0,4–2 s) — a jelölés a sikeres lekérdezésnél **törlődik**, hibánál keletkezik.
- **⚠️ A JAVÍTÁS KÖZBEN TALÁLT VALÓDI HIBA (nem a tulajdonos panasza, de a javítás feltétele):** a `publicContentRefreshProvider` a szolgáltatás **globális** `ValueNotifier`-jét adta vissza, amit a Riverpod a scope lezárásakor **dispose-ol** → a következő olvasó már egy **eldobott** notifierhez iratkozott volna fel (`A ValueNotifier<int> was used after being disposed`). Új `PublicContentRefreshMirror`: minden scope a **saját tükrét** kapja, ami a scope-pal együtt szűnik meg, a forrás jelzőt viszont nem viszi magával.
- **BIZONYÍTÁS:** `flutter analyze lib test` → **tiszta**; `flutter test` → **486/486** (a 342-es körben 410 volt). Új/átírt tesztek: `test/providers/news_provider_cache_first_test.dart` (mentett oldal azonnal, háttérhiba nem viszi el a listát, üres cache-nél töltő állapot), `test/providers/poll_provider_test.dart` és `prize_provider_test.dart` (a **friss-út** kerüli meg a cache-t, a megjelenítési út nem), `test/services/label_release_availability_test.dart` (**14/14**: lejárat, hibás bejegyzés eldobása, ismételt jelölés nem növeszt, a lejárt takarítás, **és forrás-lint**, hogy a képernyő megnyitáskor betölti, siker-ágban törli, hiba-ágban megjelöli).
- **⚠️ A SAJÁT JAVÍTÁSUNK MELLÉKHATÁSA + hotfix (AAB 344):** a `keepAlive` miatt a képernyő újranyitása **nem** futtatta újra a providert, ezért egy **frissen megvásárolt** kiadvány a **mentett** listában nem jelent meg (a vásárlás ugyanis semmit nem invalidál) — akár a **munkamenet végéig** sem. **Javítás:** 30 másodperces időzítő (`Timer.periodic` → `ref.invalidateSelf()`, ugyanaz a minta, mint az `eventsProvider` percenkénti frissítésénél) + 60 másodperces frissességi ablak a szolgáltatásban; a lista ilyenkor a **mentett** értéket rajzolja (nincs töltő állapot), és a háttérben egyeztet. **Ez a 344-es csomag, a 343-at ez váltja** (`flutter analyze` tiszta, `flutter test` **520/520**).
- **⚠️ ŐSZINTE TRADE-OFF, amit a tulajdonosnak is tudni kell:** a kérdőív/nyereményjáték **megjelenítési útja** mostantól a mentett választ rajzolja, ezért egy **frissen kihirdetett nyertes** a háttér-egyeztetéssel jelenik meg — a WordPress saját 45 s-os cache-e miatt ez akár **45–75 másodperc** is lehet. **A lehúzás / frissítés ikon viszont azonnali** (`bypassCache`). A régi kód pont ezért kerülte meg mindig a cache-t; a kettő szétválasztása volt a kompromisszum.
- **A plugin változatlan (2.5.9)** — ez a kör **kliensoldali** volt, szerveroldali változás nélkül.

### A lájk és az ismerős-jelölés „600 év" volta — optimista felület (2026-09-20, AAB **343**)

- **A tulajdonos jelzése:** *„Ismerősnek jelölés, chat like, 600 év volt mire sikerült, nagyon LASSSÚ, nem úgy kéne, hogy az appban már végrehajtódik, de közben megy ki a kérés a szerver felé?"* — **pontosan így kell**: a felület azonnal lép, a szerverhívás a háttérben megy.
- **A MÉRT GYÖKÉR:** mindkét út **egy Firebase callable-t várt meg** (hideg indulásnál **1–3 s**), és **csak utána** írt helyi állapotot: a chat-reakciónál a `setState` az `await` **után** volt (a chip 1–3 s-ig pontosan úgy nézett ki, mintha nem történt volna semmi), a darabszám pedig a Firestore-képből jött (az is csak a szerveroldali írás után); az ismerős-jelölésnél a `_connectionStatus` vált csak a hívás után. **Ráadásul** a chat-reakció hibája **néma** volt (`catch (_) {}`), és **nem volt dupla-koppintás kapu**; az érkező felkérés elfogadása/elutasítása pedig **try/catch nélkül** futott (a hiba kezeletlen async hibaként tűnt el), a listában lévő csempe pedig **meg sem várta** a hívást.
- **A JAVÍTÁS (a privát üzenet szívének mintája szerint):**
  - **Chat-reakció:** a koppintás pillanatában `setState` (**az `await` előtt**) + **helyi darabszám-korrekció** (delta: régi emojinál −1, újnál +1), ezért a chip **és** a szám azonnal mozdul; a szerver válasza az igazság, a delta pedig **magától 0-ra esik**, amikor a Firestore-kép beéri. Hiba esetén **visszaáll** ÉS **SnackBar** szól (a néma ág megszűnt). Új **busy-kapu**: ugyanarra az üzenetre nem indulhat két párhuzamos toggle (a busy alatti koppintás szándékosan **elveszik** — a sorba állítás kiszámíthatatlan szerveroldali sorrendet okozna).
  - **Ismerős-jelölés:** a „pending" állapot **a koppintás pillanatában** látszik, a gombok letiltva a hívás alatt, hiba esetén visszaáll + a megmaradt SnackBar (kiegészítve a hiba okával). **Új `_respondConnection(accept)`**: az elfogadás/elutasítás eddig **semmilyen** hibakezeléssel nem rendelkezett.
  - **A lista csempéje** (`_ConnectionRequestTile`) **stateful** lett (azonnali „Elfogadva/Elutasítva", várakozás nélkül), és **`ValueKey(request.id)`-t kapott** — enélkül a Flutter a megmaradt `State`-et (vele a „kezelt" jelzőt) a **következő** felkéréshez párosíthatta volna, és **hamis „Elfogadva"** csempét mutatott volna.
- **BIZONYÍTÁS:** új `test/services/optimistic_ui_test.dart` (**9/9**, forrás-lint: a helyi írás a hívás **előtt**, van visszaállás + hibaüzenet, van busy-kapu, a szolgáltatás-hívás neve változatlan), a meglévő `test/widgets/chat_reaction_mine_test.dart` is zöld (**16/16** együtt), `flutter analyze` tiszta, `flutter test` **486/486**. **Mutációs bizonyíték:** az `_react`-ből az optimista `setState`-et kivéve **2 teszt elhasal** (7/9), majd a fájl byte-pontosan visszaállt (SHA-256 egyezik).
- **ŐSZINTE KORLÁT:** a bizonyíték forrás-lint + widget-teszt; **futásidejű, eszközön mért** igazolás nincs (a panasz a tulajdonos telefonján mérhető igazán).

### Nyereményjáték-sorsolás: „biztos random?" — MÉRVE, nem feltételezve (2026-09-20, **szerver/eszköz: AAB NEM kell hozzá**)

- **A tulajdonos jelzése:** *„nyereményjáték sorolás teszt: az elsőnél a legelső beküldő nyert, a másodiknál a legutolsó — biztos random?"*
- **A VÁLASZ: IGEN, random — és a két megfigyelése is igaz, mindkettő 1/n esélyű volt.** A sorsolás a `drawPrizeWinnerForPrizes`-ben (`functions/index.js`) **`crypto.randomInt(0, eligible)`**-tal húz (a Node **kriptográfiailag biztonságos** generátora, nem `Math.random`), a jelöltlista pedig a **helyes választ adók** listája (`/prize/participants`), a beküldés sorrendjében. Nincs súlyozás, nincs „első/utolsó" előny.
- **A MÉRT HÚZÁSOK (élő, `node tools/check-prize-draws.mjs --days 30 --participants`):**
  - `#12709` (2026-09-18, nyertes **Denoiser**): **3 jogosult**, a nyertes az **1.** helyen → esélye **33,3%**;
  - `#12797` (2026-09-20, nyertes **Kobakologia**): **8 jogosult**, a nyertes a **8.** helyen → esélye **12,5%**.
  - Együtt **1/24 ≈ 4,2%** — ez **nem** említésre méltó ritkaság, két húzásból **nem lehet** elfogultságra következtetni (2 húzásnál a minta semmi).
- **⚠️ A MÉRÉS KÉT FORRÁSA (és miért kellett a második):** az audit-adat a `prize_draws/<prizeId>` dokumentumban van (`eligibleCount`, `chosenIndex`, `candidatesHash`, `drawnAt`) — ezt a **341-es körben** tette be a függvény, ezért a `#12709` dokumentumában **nincs** (`chosenIndex` hiányzik). A Cloud Logging `prize_draw_choice` bejegyzése **már nem elérhető** (a napló lejár) — ezért a régi húzásnál a **jelöltlista mai állapotából** rekonstruáltam a helyet (`--participants`, jelszóval védett végpont, Secret Managerből olvasott jelszóval; **csak olvasás**). Ez **utólagos rekonstrukció**, nem a húzás pillanatában naplózott adat — ezt az eszköz ki is mondja.
- **⚠️ TANULSÁG:** a *„nézzünk a naplóba"* itt **nem működött** (0 találat, mert a napló lejárt) — a **dokumentumba írt audit-adat** az, ami évekig bizonyít. Ezért a `chosenIndex`/`eligibleCount` beírása nem „extra", hanem a **bizonyíthatóság** feltétele.
- **AZ ESZKÖZ (`tools/check-prize-draws.mjs`) BŐVÍTÉSE:** éles módban (1) a Firestore `prize_draws` az **elsődleges** forrás, (2) a napló a **kiegészítés** (ha a dokumentumban nincs audit-adat, de a naplóban még megvan), (3) `--participants` esetén a **jelöltlistából való rekonstrukció**, és a végén egy **megfigyelés** arról, hány húzás esett a lista szélére (első/utolsó) — **kimondva, hogy ez önmagában nem bizonyíték**.
- **BIZONYÍTÁS (mind a generátorra, mind a mérésre):**
  - `node tools/check-prize-draws.mjs --self-test` → **9/9**: 2/3/5 jelöltnél 200 000 húzás, a legnagyobb eltérés **<0,18 százalékpont**; egy **szándékosan elrontott** („mindig az első") szabályt a mérés **elkap** (66,7 százalékpont); a húzás a `0..n-1` tartományban marad; **új**: a rekonstrukció a nyertest az **első** és az **utolsó** helyen is megtalálja, ismeretlen nyertesnél **nem tippel** (`-1`), üres listánál nem hibázik.
  - `npx firebase emulators:exec --only firestore --project demo-huhs "node functions/prize-draw.test.cjs"` → **24/24**, köztük *„a sorsolás NEM favorizálja az ELSŐ beküldőt (200 húzás, valódi véletlen)"*.
  - **Mutációs bizonyíték:** a rekonstrukciót elrontva (mindig `0` index) a self-test **3 hibát** jelez (6/9), majd a fájl **byte-pontosan** visszaállt (SHA-256 egyezik).
- **A SORSOLÁS EGYSZER FUT (mérve a kódban):** az ütemezett függvény a WordPress `/prize/pending` listáját dolgozza fel (lezárult, nyertes nélküli játékok), a WordPress `huhs_prize_set_winner()` pedig **nem írja felül** a meglévő nyertest — ezért egy játékot nem sorsol újra, és a véletlen döntés nem módosul utólag.

### A 341 SAJÁT REGRESSZIÓJA: a könyvtár kártyái „betöltés" állapotban ragadtak (2026-09-20, AAB **342**)

- **A tulajdonos jelzése egy képernyőfelvétellel:** *„itt valami eltört"* — a felvételen (ffmpeg-gel kockákra bontva, `read_image`-del megnézve) a **„Megvásárolt zenéim"** lista **minden** kártyája ezt mutatta: `Kiadvány #12466` / `Adatok betöltése…` **végig**, 9 másodpercig — **miközben a lejátszósáv már a valódi címet** („Goze - TikaTika — MP3 96") és a fejléc valódi számokat („17 kiadvány · 22 tétel · 166,7 MB").
- **A MÉRT GYÖKÉR (a saját hibám):** a 341-ben a kártya-render **csak** a lusta lekérdezés térképéből olvasott (`_releaseMeta`), a **katalógusból** (`_catalogById`) nem — pedig a nyilvános katalógus a 21 kiadványból **20-at ismer**, és a lejátszási sor **helyesen** a katalógust használta. Ezért mondott ellent a kettő: a sor tudta a címet, a kártya nem. (A „Kiadvány #12327" elleni javításom mellékterméke: a katalógusból hiányzó kiadványokra bevezetett lusta lekérdezés **mellé** kellett volna tenni, nem **helyette**.)
- **A javítás:** a kártya ugyanabból a térképből dolgozik, mint a sor (`_catalogById[item.releaseId] ?? _releaseMeta[item.releaseId]`), a képernyő pedig eltárolja a katalógust (`_catalogById = catalogById`) a rajzoláshoz. A „betöltés" állapot szövege is őszintébb lett: „Kiadvány betöltése…" + azonosító (nem egy szám, ami címnek látszik).
- **⚠️ TANULSÁG (a legfontosabb ebből):** két külön térkép ugyanarra a kérdésre („mi ez a kiadvány?") **mindig széthúz**. A javítás nem az, hogy mindkettőt jól töltjük, hanem hogy **egy** forrás legyen.
- **BIZONYÍTÁS:** `test/services/label_library_plan_test.dart` **25/25** — új **regresszió-lint**, hogy a kártya a `_catalogById`-ból veszi a címet, és hogy a képernyő eltárolja a katalógust. **Mutációs bizonyíték:** a hibát visszatelepítve (`_releaseMeta[item.releaseId]`) a teszt **elhasal** (24/25), majd a fájl byte-pontosan visszaállt. `flutter analyze` tiszta, `flutter test` **410/410** (a menet előtt 409 volt).
- **⚠️ AMIT NEM SIKERÜLT (őszintén):** a képernyőhöz **widget-tesztet** írtam (a valódi címet kereste volna), de a teszt **felakadt** (5 perc után sem futott le) — ezért **töröltem**, és helyette forrás-lintet tettem be. Egy felakadó teszt rosszabb, mint a hiányzó: az egész `flutter test`-et megállítaná. **Ha valaki újra próbálkozik:** a `MyMusicScreen` `AudioPlayer`-t hoz létre (`just_audio`), és valószínűleg az akad meg a teszt-környezetben.
- **Csomag:** `build/HUHS-v1.0.0+342-release.aab` (versionCode **342**, 79,85 MB, SHA-256 `43A8E6BC47EE2F014E055B44B4402220382380FE78DF775B76ED4BE658246C69`) — `pubspec.yaml` `1.0.0+342`, changelog-bejegyzés, Play-jegyzet (az 1. blokk a 342-t írja le, az 1b. a 329–342 összesítő). **A 341-et ez váltja.** **A plugin változatlan (2.5.9).**

### „Megvásárolt zenéim": csak a letöltött zenék + a menü-design (2026-09-20, AAB **341**)

- **A tulajdonos jelzései:** *„ha lapozok a zenék között, le akarja tölteni ami nincs letöltve, és így akarja lejátszani, csak a letöltött zenéket játsza le"*, *„van ott egy kiadvány #12327 ami nem tudom mi"*, végül: *„az a saját zenéim lehetne »megvásárolt zenéim« és illeszkedhetne rendesen a »Több« menü designbe"*.
- **1. LETÖLTÉS LAPOZÁS KÖZBEN (kliens):** a `_playIndex` eddig **minden** lejátszás előtt letöltötte, ami hiányzott — így egy „következő" gomb egy nagy WAV letöltését indíthatta el. **A javítás:** lejátszani **csak letöltött** zene játszható; a lapozás (előre/hátra) és a szám végi automatikus továbblépés **átugorja** a le nem töltött tételeket (nem indít letöltést), és ha egy zenét kézzel indítanál, de nincs meg, a lejátszó **kiírja**, hogy előbb le kell tölteni. A döntés a **tiszta** modulban van: `firstDownloadedIndex` / `nextDownloadedIndex` / `previousDownloadedIndex` (a korábbi `firstUndownloadedIndex` helyett, ami a régi viselkedést szolgálta).
- **2. „KIADVÁNY #12327" — MEGMÉRVE:** ez egy **reklámmal feloldott** kiadvány (`mp3_128`, a `07527e2c…` fióknál), ami **már nincs a nyilvános listában** — a `/releases/12327` végpont **404**-et ad, és a nyilvános katalógus 21 kiadványa közül egyedül ez hiányzik. Vagyis nem hiba volt, hanem egy **időközben törölt/elrejtett kiadvány**, amire a feloldás megmaradt. **A javítás:** a katalógusból hiányzó kiadványt egyenként lekérdezzük (`getRelease(id)`), és ha az sem adja, **megnevezzük** („Ez a kiadvány már nem elérhető", azonosítóval) — és **nem kerül a lejátszási sorba**, mert a fájlja úgysem tölthető le. (A lista összes többi kiadványa rendben feloldódik: 20/21 cím.)
- **3. NÉV ÉS DESIGN:** a szakasz neve **„Megvásárolt zenéim"** (a képernyő címe is), a menüpont pedig „Lejátszás és letöltés". **A valódi design-hiba az volt, hogy a szakasz nem szerepelt a `_expanded` halmazban**, ezért **csukott kártyaként** indult, míg a többi négy (Felfedezés, Beküldés, Kapcsolat, Alkalmazás) nyitva — így lógott ki a sorból. Most nyitva indul, és a kereső is megtalálja.
- **BIZONYÍTÉS:** `test/services/label_library_plan_test.dart` **24/24** — a sor-lépkedés a **letöltött** tételek között (átugorja a többit, a végén megáll), és **forrás-lint**, hogy a `_playIndex` **nem** hív letöltést, a `_advance` is letöltött tételre lép, és a felület megnevezi az eltűnt kiadványt. `flutter analyze` tiszta, `flutter test` **409/409** (a menet előtt 402 volt).
- **⚠️ TANULSÁG (eszköz):** a doksi soronkénti átírása (`Get-Content` → `WriteAllLines`) **CRLF-re** váltotta a fájlt, amitől a Play-blokk mérés **+7 karaktert** ugrott (a `\r` is kódpont) — a kapu ezt **el is kapta** (486/480). A fájlt vissza kell állítani LF-re, különben a „biztonsági margó" hamisan szűkül.
- **Csomag:** `build/HUHS-v1.0.0+341-release.aab` (versionCode **341**, 79,85 MB, SHA-256 `88EAA49C072D8FF91B628B551885FBB689EE4B61ADE04FF3FBEDD3A8FF29EC8A`) — `pubspec.yaml` `1.0.0+341`, changelog-bejegyzés, Play-jegyzet (az 1. blokk a 341-et írja le, az 1b. a 329–341 összesítő). **A 339/340-et ez váltja.** **A plugin változatlan (2.5.9).**

### A kvíz azonnal jelzi, hogy már kitöltötted (2026-09-20, AAB **340**)

- **A tulajdonos jelzése:** *„kviznél lassan frissül, hogy már kitöltötte, pár másodpercig úgy jelzi mintha tudna még játszani"*.
- **A MÉRT GYÖKÉR (és a meglepő rész):** az állapot három lépcsőn derül ki — **app → Cloud Function → WordPress** (`getGameAttemptStatus` `wordPressCall`, hideg indulásnál másodpercek) —, a `GameScreen` pedig addig **játszhatónak** mutatta a kvízt: a kérdések szerkeszthetők voltak, csak a beküldés gomb volt letiltva (`_checkingSubmission`), a felirat pedig „Válaszok beküldése" volt.
  - **Ez a hiba MÁR ISMERT VOLT — csak a kvíz maradt ki.** A `lib/services/vote_memory.dart` fejléce **szó szerint idézi ugyanezt a panaszt**: *„Kvíznél elsőre kicsit sokára tölti be, hogy már játszottam"*, és a megoldás (helyi emlékezet + háttérellenőrzés) **már működött a kérdőívnél** (`_pollPrefix`) **és a nyereményjátéknál** (`_prizePrefix`) — a **kvíz** viszont **nem** használta (`GameScreen` csak a szervert kérdezte, és nem is volt `game` kulcs). Ez a fajta rés a legrosszabb: a tudás megvan, csak nem mindenhol.
- **A javítás (kliens, AAB 340):**
  - `VoteMemory`: új `isGamePlayed` / `markGamePlayed` / `clearGamePlayed` (`huhs.played.game.<uid>.<id>`), ugyanazzal a két szabállyal, mint a többi: **csak `true`-t** írunk, és a **UID a kulcsban** van (más fiók nem örököl).
  - `GameScreen`: beküldés után **azonnal** megjegyzi a tényt; a megnyitáskor **előbb a helyi emlékezetet** kérdezi (és csak utána a szervert), ezért a „már játszottál" **azonnal** látszik. Amíg a szerver meg nem erősít, **nem a játszható kvíz** látszik, hanem egy semleges várakozó kártya („Ebben a kvízben már játszottál — betöltjük az eredményedet").
  - **A szerver a hiteles forrás:** ha azt mondja, mégsem játszottál (pl. az admin újranyitotta a kvízt), a jelzés **törlődik** és a kvíz újra játszható. Ez azért fontos, mert a helyi emlékezet önmagában **elrejthetné** egy újranyitott kvízt.
- **BIZONYÍTÁS:** új `test/services/vote_memory_game_test.dart` (**11/11**): a beküldött kvíz megjegyződik; a törlés működik; **másik fiók nem örököl**; másik kvíz nem keveredik; vendégként nem írunk/olvasunk; érvénytelen azonosítóval nem írunk félre; a kvíz-kulcs nem nyúl a kérdőív/nyeremény kulcsaihoz; és **forrás-lint**, hogy a `GameScreen` (a) megjegyzi a beküldést, (b) az emlékezetet **a szerver előtt** kérdezi, (c) törli, ha a szerver nem játszottat mond, (d) nem a játszható kvízt rajzolja, ha az emlékezet szerint már játszottál. `flutter analyze` tiszta, `flutter test` **402/402** (a menet előtt 391 volt).
- **Csomag:** `build/HUHS-v1.0.0+340-release.aab` (versionCode **340**, 79,83 MB, SHA-256 `0B8E13326617593CF540C12249C4B6940E0431965DA1D63E74695FF4A7269EA7`) — `pubspec.yaml` `1.0.0+340`, changelog-bejegyzés, Play-jegyzet (az 1. blokk a 340-et írja le, az 1b. a 329–340 összesítő). **A 339-et ez váltja** (ha még nem töltötted fel, egyenesen ezt tedd fel). **A plugin változatlan (2.5.9).**

### „Saját zenéim" — a megvásárolt zenék könyvtára (2026-09-20, AAB **339**)

- **A tulajdonos kérése:** *„kéne egy user specifikus menüpont a megvett zenékre, ahol le tudja játszani, ha vége a zenének, ugrik a következőre, le is tudja tölteni újra, úgymond megmarad ott a megvásárolt zenéje"*, majd: *„tudjon törölni is ha akar, de a letöltési lehetősége maradjon meg, nyilván ha másik accal lép be, ne látszódjon és letölteni se tudja"*, végül: *„az eddig megvásárolt, letöltött zenéket is tegye be oda, ugye a régebbi verziókban volt aki vásárolt, vagy feloldott zenét"*. Hely: **Több → Saját zenéim → Megvásárolt zenéim**.
- **A MÉRT ALAP: a jogosultság ÉVEK ÓTA megvan, csak senki nem kérdezte le.** A `label_entitlements/<uid>_<productId>` (Play-ellenőrzött vásárlás) és a `label_ad_unlocks/<uid>_<releaseId>` (reklámmal feloldott változatok, `variants: {mp3_128: true, …}`) eddig **csak egyenként** volt elérhető: a kliens egy dokumentumot nézett meg név szerint, a letöltés-végpont pedig egy fájlt adott. **Listázó végpont nem volt**, és a Firestore-szabályokban ezekre a gyűjteményekre **nincs kliens-olvasás** (szándékosan).
- **SZERVER:** új `getMyLabelLibrary` callable — a **hitelesített** uid-del szűr (`where('uid','==',uid)`), és a döntést a **tiszta** `functions/label-library-plan.js` hozza (`parseLabelProductId`, `adUnlockedVariants`, `labelLibraryPayload`), hogy WordPress és Firestore nélkül mérhető legyen. A válasz **szándékosan sovány**: kiadvány-azonosító + változatok (a cím/borító a kliens kiadvány-katalógusából jön, így nem tud ellentmondani a valódi kiadványnak).
  - **Egy szabály egy helyen:** a letöltés-kapu `activeAdUnlock()`-ja mostantól **ugyanazt** a modult hívja (`adUnlockedVariants(...).includes(variant)`), ezért a könyvtár és a letöltés **nem mondhat ellent** (a régi, változat nélküli feloldás továbbra is az eredeti 128 kbps jutalmat jelenti).
- **ÉLES MÉRÉS (2026-09-20, `node tools/check-label-library.mjs`):** **6 megvásárolt tétel, ebből 0 maradna ki** a könyvtárból; **21 reklám-feloldás, mind lejátszható változatot ad**; összesen **4 fióknak** van zenéje, **17 kiadvány** érintett; a legnagyobb könyvtár **17 kiadvány / 23 tétel**. Vagyis a **régi vásárlások és feloldások automatikusan bekerülnek** — nem kell adatátalakítás.
  - **⚠️ A SAJÁT ESZKÖZÖM HIBÁJA, amit éles mérés fogott meg:** a riport első változata a feldolgozás során **felülírta** a rekord `variants` mezőjét a kiszámolt listával, ezért a `labelLibraryPayload` már nem találta a `variants.<változat> === true` jelölést, és a **csak-reklámos fiókok némán eltűntek** (2 helyett 4 fiók). A javítás: a rekordot változatlanul adjuk tovább (`unlockedVariants` külön mezőben), és **önteszt** őrzi, hogy a csak-reklámos fióknak is legyen könyvtára. **A tanulság ugyanaz, mint a hibaszűrőnél: a „minden rendben" csak akkor ér valamit, ha a számot is ellenőrizzük.**
- **KLIENS:**
  - `lib/models/label_library.dart` — `LabelLibraryItem` (vásárolt/feloldott változatok) és `LabelQueueEntry` (**egy birtokolt változat = egy lejátszható tétel**), változat-nevek, kiterjesztés és fájlnév (`huhs_<kiadvány>_<változat>.<wav|mp3>`).
  - `lib/services/label_library_plan.dart` — **tiszta** sor-összeállítás: a könyvtár sorrendje (legfrissebb kiadvány elöl), egy kiadványon belül a felületi változat-sorrend, **duplikáció nélkül**, a katalógusból hiányzó kiadvány is a sorban marad („Kiadvány #&lt;id&gt;"), a sor végén **megáll** (nem teker körbe).
  - `lib/services/label_download_manager.dart` — **fiókonként külön mappa** (`label_music/<uid>/`), `.part` fájlon át (nem marad „kész" látszatú fél fájl), **egy hiba után egyszer új linkkel** próbálkozik (a WordPress linkje 5 percig él, egy nagy WAV tovább tölthet), törlés és összméret. **Vendég (bejelentkezés nélküli) állapotban nincs letöltés** (a vásárlás bejelentkezéshez kötött).
  - `lib/screens/more/my_music_screen.dart` + `lib/providers/label_library_provider.dart` — a lista és a lejátszó-sáv (előző/következő, folyamatjelzés, „Letöltve"/„Törlés a készülékről"/„Letöltés", tárhely-ürítés). A lejátszás a **letöltött fájlból** megy, és a szám végén **magától a következőre lép** (ha az még nincs meg, előbb letölti). A rádióval ugyanaz a minta, mint a kiadvány-előhallgatónál: leáll, majd a lejátszó bezárásakor visszaindul.
- **ADATVÉDELEM (a tulajdonos kérése: „másik accal ne látszódjon"):** a lista a **szerverről**, a hitelesített uid-del szűrve jön (más fiók zenéje nem is kérdezhető le), a **helyi fájlok pedig fiókonként külön mappában** vannak — enélkül a készüléken maradt fájl **másik fióknak is látszana és lejátszható lenne**, mert a fájl létezése a „megvan" jelzés. A mappanévből minden elválasztót kiszűrünk (`../uid` nem tud kilépni).
- **BIZONYÍTÁS:** `test/services/label_library_plan_test.dart` (**17**), `test/services/label_download_manager_test.dart` (**11**, köztük a fiók-szétválasztás: A megvan → B nem látja, a fiókváltás nem viszi el, az egyik fiók törlése nem törli a másikét), `test/services/label_library_service_test.dart` (**6**, köztük hogy a hiba **nem** lesz üres könyvtár) → `flutter analyze` tiszta, `flutter test` **391/391** (a menet előtt 357 volt); `functions/label-library-plan.test.cjs` **9/9**; `tools/check-label-library.mjs --self-test` **11/11**.
- **⚠️ MELLÉKES JAVÍTÁS (a kapu hamisan piros volt):** a `functions/security-permissions.test.cjs` „connections and chat reactions are server-managed" tesztje a `callFirebaseCallable<Map<String, dynamic>>(` hívást **nem** ismerte fel (`[^>]+` minta), ezért a 336-os menet óta **hamisan hibázott** (a `toggleReaction` visszatérési értéket kapott). A minta most `[^()]{1,80}` — a lényeg változatlan (a chat-hívás a szerveroldali callable-re menjen).
- **Csomag:** `build/HUHS-v1.0.0+339-release.aab` (versionCode **339**, 79,82 MB, SHA-256 `9FC837E394400022E2E00B4ACC73CAE415A8438591C23F9514ED42E8D9D7D27E`) — `pubspec.yaml` `1.0.0+339`, changelog-bejegyzés, Play-jegyzet (az 1. blokk a 339-et írja le, az 1b. a 329–339 összesítő). **A plugin változatlan (2.5.9).**
- **A TULAJDONOS DÖNTÉSE (2026-09-20):** a kiadvány adatlapjáról **NEM kell** „Megnyitás a lejátszóban" gyorsgomb — a szava: *„sztem ez nem kell"*. A belépés a **Több → Saját zenéim** úton van, és ez így marad. **Ne told hozzá** (fölösleges kör a vásárlás után, a felhasználó úgyis a saját listáját nyitja meg).
- **ISMERT KORLÁTOK (szándékosak):** a WAV-ok nagyok (50–100 MB), ezért a felület csak a letöltött **összméretet** mutatja, nem figyelmeztet külön méretre; a lejátszó sáv a **képernyőn belül** él (nem előtér-szolgáltatás), ezért az app elhagyásakor megáll — ez azért van így, hogy a **rádióval ne ütközzön** (a rádió ilyenkor visszakapja a hangot).

### Chat-értesítések, ikonjelvény és a folyamatos rádió (2026-09-20, AAB **338**)

- **A tulajdonos kérései egy menetben:**
  1. *„chat like-ról legyen az adott usernek notify"*,
  2. *„Ha valaki válaszol neked a chaten legyen róla notify"*,
  3. *„ha valaki valaszol az usernek a cikkek alatti kommenteknél, legyen róla notify"*,
  4. *„Csak notify, push nem kell"*,
  5. *„Az app ikon jelezze mennyi notifyd meg pushod van, olvasatlan, egybe számolva"*,
  6. *„Rádiot nezzuk meg… ha valaki nincs belepve, 5 perc után megszakad… Cél az, hogy folyamatosan menjen"*,
  7. (menet közben) *„ha megy a rádió, de valaki elindítja a spotifyt vagy a youtubeot, szól tovább a rádió, közben el kéne hallgatnia"*.
- **1–2. CHAT: LÁJK ÉS VÁLASZ ÉRTESÍTÉS (szerveroldali, AAB NEM kellett volna hozzá — a szöveghez mégis, lásd lent).** A `toggleChatReaction` és a `publishChatPost` eddig **egyáltalán nem** értesített senkit; a chat-válaszhoz a kliens **nem is küldte** a válaszolt üzenet szerzőjének UID-ját (csak a nevet és a szöveget), így a szerver nem is tudhatta volna, kit szólítson.
  - **A döntés tiszta modulba került** (`functions/chat-notification-plan.js`), hogy WordPress és Firestore nélkül is mérhető legyen: `chatReactionNotification` / `chatReplyNotification`. A hívókban **csak a kiírás** marad.
  - **Négy szándékos szabály:** (1) **visszavonáskor nincs** értesítés; (2) a **saját** üzenet saját lájkja/válasza nem értesít; (3) a naplókulcs (`chat-reaction:<üzenet>:<ki lájkolta>`, illetve `chat-reply:<válasz üzenete>:<címzett>`) miatt ugyanaz **egyszer** szól — visszavonás+újralájk és trigger-újrakézbesítés sem dupláz; (4) **nincs találgatás**: hiányzó célpont esetén nem szólunk senkinek (a régi kliens válasza sem).
  - **PUSH NÉLKÜL:** a `createNotificationBestEffort` csak az app értesítés-listájába ír; a hívók push-t **nem** hívnak. Ezt a teszt **forrás-linttel** kéri számon (`sendMulticastToAllTokens`/`sendEachForMulticast` tilos a két hívóban).
  - **Kliens:** a `publishPost` mostantól küldi a `replyToAuthorId` mezőt, a Chat-képernyő pedig a válasz gombnál eltárolja (`_replyToAuthorId = post.authorId`).
  - **Az értesítés-központ** megkapta a `chat` célpontot: a chat-értesítésre koppintva a **Chat** képernyő nyílik.
- **3. CIKK-KOMMENT VÁLASZ: MÁR MŰKÖDÖTT — mérve, nem feltételezve.** A szerver a `replyToCommentId`-ból **kikeresi** a célkomment szerzőjét, és `article_comment_reply` értesítést ír (push nélkül). **ÉLŐ BIZONYÍTÉK:** a `notifications` gyűjteményben **már van ilyen rekord** („Denoiser válaszolt a hozzászólásodra egy cikknél."), vagyis a funkció élesben **működik** — ehhez nem kellett kód.
  - **ÉLŐ típusösszegzés (721 rekord):** `new_news` 489, `achievement_points` 90, `private_message` 79, `new_release` 20, `event_rating_request` 13, `new_event` 10, `connection_request` 10, `meetup_interest` 6, `article_comment` 1, `connection_accepted` 1, **`article_comment_reply` 1**, `prize_winner` 1; a `chat_reaction`/`chat_reply` **nulla** volt (ezek az újak).
- **4. APP-IKON JELVÉNY (olvasatlan értesítések száma).** Az app-ban a harang már mutatta a számot, a **launcher-ikon** viszont nem. Új `lib/services/app_badge_sync.dart` + az `app_badge_plus` csomag: a `notifications` stream **olvasatlan** elemeit számolja, és **csak változáskor** frissíti a jelvényt (0-nál is, mert az tünteti el).
  - **MIÉRT EZ A SZÁM:** a szerver ugyanabba a listába írja a **push-sal járó** értesítéseket is (és a WordPress-tartalomfigyelő is), ezért az olvasatlanok száma = **„notify + push egybe számolva"**.
  - **⚠️ KORLÁT, AMIT MEG KELL MONDANI A TULAJDONOSNAK:** a **számot** csak azok a launcherek mutatják, amelyek támogatják (Samsung, Xiaomi/MIUI, Huawei/Honor, Oppo, Vivo, Sony, LG, HTC, Nova, Apex, Yandex, ZTE). A **stock Android** (pl. a Pixel launcher) a csomag saját `DefaultBadge`-jével **nem csinál semmit** — ott csak a rendszer „pöttye" jelenik meg az aktív értesítésektől.
  - **⚠️ CSAPDA, amit mérve javítottam:** a `NotificationService()` **dob** Firebase nélkül, ezért a szinkron `start()`-ja előbb a `Firebase.apps.isEmpty`-t nézi (ugyanaz a minta, mint az `achievementRankSyncProvider`-nél) — enélkül a teljes appot indító widget-teszt elhasalt.
- **5–6. RÁDIÓ: nem szakad meg (wake lock) + elhallgat, ha más app szól (hangfókusz).**
  - **A MÉRT GYÖKÉR (1. rész):** a `RadioPlaybackService` **nem tartotta ébren a készüléket** — sem `setWakeMode`, sem wake lock, sem Wi-Fi lock nem volt, és a manifestből a **`WAKE_LOCK` engedély is hiányzott**. Streaming lejátszásnál ez a klasszikus hiba: képernyő ki → a CPU elalszik → a stream a puffer kifogyása után megáll. (Bejelentkezve az app egyéb hátterei időnként felébresztették a folyamatot, ezért tűnt úgy, hogy „bejelentkezve jobb".)
  - **A javítás:** `WAKE_LOCK` + `ACCESS_WIFI_STATE` + `CHANGE_WIFI_MULTICAST_STATE` engedély; `player.setWakeMode(PARTIAL_WAKE_LOCK)`; **szolgáltatás-szintű** wake lock (az újracsatlakozás alatt is tart, mert a lejátszó lockja ilyenkor elengedődik); nagy teljesítményű **Wi-Fi lock**; az URL is mentődik, a `START_STICKY` + `intent == null` ág pedig **folytatja** a lejátszást, ha a rendszer újraindítja a szolgáltatást.
  - **A MÉRT GYÖKÉR (2. rész, az új kérés):** a rádió **soha nem kért hangfókuszt**, ezért **nem is kapott jelzést** arról, hogy a Spotify/YouTube elindult — ezért szólt tovább. **A javítás:** `requestAudioFocus(AUDIOFOCUS_GAIN)` + `OnAudioFocusChangeListener`: **végleges elvesztés** (másik zene-app) → a rádió **elhallgat**; **ideiglenes** (hívás) → szünet, majd a fókusz visszakapásakor **folytatja**; **duck** → lehalkítás.
  - **A MÉRT GYÖKÉR (3. rész, a tulajdonos pontosítása):** *„ha megy a háttérben a rádió és valaki elindít pl egy spotifyt, akkor kussoljon be a rádió, ha kikapcsolja a spotifyt, vagy youtubeot, stb, menjen tovább a rádió"*. Az Android a fókusz **végleges** elvesztése után **nem** küld vissza `AUDIOFOCUS_GAIN`-t (a másik app „elvette", nem ideiglenesen), ezért a folytatáshoz **magunktól** kell újra fókuszt kérni — de csak akkor, ha a másik app **már nem játszik**, különben elvennénk tőle (pont az ellenkezője annak, amit a tulajdonos kért).
  - **A javítás (3. rész):** `pauseForFocusLoss(permanent)` **nem állítja le** a szolgáltatást (nincs `stopSelf`, nincs `stopForeground`, a `KEY_PLAYING` marad) — csak elhallgat. A folytatás **egy közös döntés** (`resumeAfterFocusLoss()`), amelyet **két út** hív:
    1. `AudioManager.AudioPlaybackCallback` (`registerAudioPlaybackCallback`, API 26+) — **azonnal** szól, ha a rendszer lejátszás-listája változik;
    2. `focusWatchdog` — 2 másodpercenként megkérdezi a publikus **`AudioManager.isMusicActive()`**-et (azért kell, mert a visszahívás nem garantált minden készüléken). A watchdog `stopPlayer()`-nél és `AUDIOFOCUS_GAIN`-nél leáll, és magától nem pörög tovább, ha a rádió leállt.
    A folytatás valódi: `requestAudioFocus()` → ha megkaptuk, `pausedByFocus = false` és `startPlayer(url)`.
  - **⚠️ HÍVÁS-VÉDELEM (a saját első változatom hibája, mérve javítva):** ha az őrkutya **minden** fókusz-elvesztésnél elindulna, akkor **bemerészkedne a hívásba**: hívás közben a zene-stream nem aktív (`isMusicActive` hamis), ezért a 2 másodperces próbálkozás visszavenné a fókuszt a hívástól, és a rádió beleszólna. Ezért **két kapu** van: (1) a `pausedByFocus` jelző **csak a végleges** elvesztést jelöli (`pausedByFocus = permanent`), így ideiglenes elvesztésnél (hívás, navigáció) az őrkutya **el sem indul** — ott a rendszer úgyis küld `AUDIOFOCUS_GAIN`-t; (2) a `resumeAfterFocusLoss()` a publikus `AudioManager.mode`-ot is nézi, és **`MODE_IN_CALL`/`MODE_IN_COMMUNICATION` alatt nem folytat** (ehhez nem kell engedély).
  - **KÉPERNYŐ-KI — a tulajdonos kérése (2026-09-20):** *„kikapcsolt képernyőn is mennie kéne a rádiónak ha fut az app"*. Ez **két külön eset**, és mindkettőt le kell fedni:
    1. **A rádió SZÓL** képernyő-ki mellett: ezt a streamelés lockja adja — `setWakeMode(PARTIAL_WAKE_LOCK)` + **korlátlan** szolgáltatás-szintű wake lock + nagy teljesítményű Wi-Fi lock. Ezért az `acquireLocks()` streameléshez **mindig korlátlan** lockot állít (ha épp korlátozottat tartunk, lecseréli) — egy lejáró lock képernyő-ki mellett megállítaná a rádiót.
    2. **A fókusz miatt elhallgatott rádió** képernyő-ki mellett is **folytatódjon**: ehhez az őrkutyának futnia kell, ezért a `pauseForFocusLoss()` **nem engedi el** a CPU-lockot, hanem az `acquireFocusWatchLock()` **korlátozott idejű** (20 perc) lockot tart, és csak a Wi-Fi lockot engedi el. A korlát szándékos: egy elfeledett szünet (a felhasználó egy órán át Spotify-t hallgat) ne fogyassza a telepet — ha lejár, az őrkutya a következő ébredésnél folytatja, tehát a rádió **nem vész el**.
    **Kliensoldalon semmi nem állítja le a rádiót háttérbe tételkor vagy képernyő-kinél** (mérve: a `WidgetsBindingObserver`-ek mind csak `AppLifecycleState.resumed`-re cselekszenek).
  - **⚠️ MÉRT API-CSAPDA (két sikertelen build):** a kézenfekvő `config.isActive` és `config.clientUid` **nem használható** — a `getClientUid()` (és a stub `android.jar` szerint az `isActive()` is) **rendszer-API**, ezért a Kotlin-fordító `Unresolved reference`-szal elhasal. Ezért a döntés a **publikus** `isMusicActive()`-re épül. **A másik csapda:** a `AudioPlaybackCallback` osztály csak API 26-tól létezik, ezért a figyelő **nem lehet mezőinicializálóban** (`private val x = object : AudioManager.AudioPlaybackCallback()`) — az a szolgáltatás létrehozásakor **azonnal** lefutna, és a `minSdk = 24` miatt a régi készülékeken `NoClassDefFoundError`-ral elhasalna az app. Ezért `private var playbackWatcher: ...? = null` + `@RequiresApi(O)` regisztráló függvény.
  - **✅ A TULAJDONOS MEGERŐSÍTETTE A HELYES VISELKEDÉST (2026-09-20):** *„rádió leáll ha kilépek az appból, ha csak háttérbe teszem megy tovább, ami helyes működés"*. Ez **szándékos és megmarad**: a szolgáltatás `onTaskRemoved`-je (a feladat eltávolítása = kilépés) **leállítja** a lejátszást, háttérbe tételnél viszont **tovább szól** — utóbbi pont a wake lock javítás lényege. **Ezt a viselkedést ne „javítsd"**: a `START_STICKY` + `stopSelf()` együtt azt jelenti, hogy a kilépés utáni újraindítás **nem** történik meg, a rendszer okozta kill viszont igen (akkor a mentett URL-lel folytatjuk).
  - **ÉLŐ FELHASZNÁLÓI VISSZAJELZÉS (a `notifications` gyűjteményből, 2026-09-20):** az egyik privát üzenet szerint *„Jelzi mar a chat likod ha frissitesz"* — vagyis a **336-os chat-lájk jelzés** a valódi felhasználóknál **működik**; egy másik pedig a rádiót tesztelte („most nézem én is ezt a rádiót").
  - **⚠️ AMIT NEM SIKERÜLT BIZONYÍTANI (őszintén):** az emulátoros **futásidejű** mérés **kétszer is elhalt**, mert a debug build az emulátoron **összeomlik indulás után** (`Fatal signal 11 SIGSEGV … FirestoreWorker`, illetve `SIGTRAP … MemoryInfra`) — ilyenkor a launcher kerül előtérbe, és a koppintás már nem az appba megy. Ez **emulátor-specifikus** (x86_64 + debug), a tulajdonos telefonján az app stabilan fut. Ezért a rádió javítását **statikusan** igazoltam: a **merge-elt manifest** tartalmazza a három új engedélyt és a `foregroundServiceType="mediaPlayback"` szolgáltatást; a futásidejű igazolás a **tulajdonos telefonján** történik (a szimptómát is ő jelezte).
  - **⚠️ TANULSÁG (emulátor):** a mérés előtt **kötelező** a képernyőt bekapcsolni (`input keyevent 224` + `wm dismiss-keyguard`), különben a képernyőkép **teljesen fekete**, és a koppintások nem érnek célt — az első „mérésem" pont ezért lett hamis (a YouTube-videó hangja látszott „rádióként", a Chromium hangfókusz-vonala miatt).
- **BIZONYÍTÁS:** `functions/chat-notification-plan.test.cjs` (**15/15**: a lájk/válasz értesítés minden szabálya, a naplókulcsok, a „nincs push" forrás-lint, és hogy a kliens elküldi a `replyToAuthorId`-t); `test/services/app_badge_sync_test.dart` (**7/7**: olvasatlan-szám, csak változáskor, 0-ra törlés, hiba nem állítja meg, dispose); **`test/core/android_radio_service_test.dart` (20/20, forrás-lint a Kotlin-szolgáltatásra és a manifestre)**: a három engedély és a `mediaPlayback` előtér-típus; `setWakeMode` + wake lock + Wi-Fi lock; `START_STICKY` + mentett URL; fókusz-kérés és duck; **a fókusz elvesztése nem állítja le a szolgáltatást** (nincs `stopSelf`/`stopForeground`/`KEY_PLAYING=false` az elhallgató ágban); a folytatás fókuszt kér és újraindítja a lejátszót, de **csak ha `isMusicActive` hamis**; a visszahívás és a 2 másodperces őrkutya is ezt hívja, és mindkettő leáll a leállításnál; a figyelő **nem** jön létre API 26 alatt (mezőinicializáló-tilalom); **`onTaskRemoved` továbbra is leállít** (a tulajdonos által igazolt helyes működés). **Mutációs bizonyíték (újramérve a végleges kódon):** a `WAKE_LOCK` engedély törlésével ÉS a fókusz-kapu kiiktatásával (`if (false)`) **2 teszt elhasal** (18/20), majd a fájlok byte-pontosan visszaálltak. `flutter analyze` tiszta, `flutter test` **357/357** (a menet előtt 337 volt).
- **Élesítve:** `firebase deploy --only functions:toggleChatReaction,functions:publishChatPost` → **Deploy complete!** (a két chat-értesítés **már él**, AAB nélkül is).
- **Csomag:** `build/HUHS-v1.0.0+338-release.aab` (versionCode **338**, 79,61 MB, SHA-256 `0854CB8C785CA70D0B8AFF44B5BBCB05E66D78D61386B1B078FCD0BEDE6C764F`) — a `pubspec.yaml` `1.0.0+338`, changelog-bejegyzés (a rádió Spotify/YouTube viselkedése is benne), Play-jegyzet frissítve (az 1. blokk már csak a 338-at írja le, az 1b. a 329–338 összesítő a production kiadáshoz). **A kész release AAB a rádió folytatásával újraépült** (a korábbi, `083BAA98…` hash-ű csomag a fókusz-visszaszerzés előtti állapot volt — **ne azt töltsd fel**). **A plugin változatlan (2.5.9).**

### YouTube-videó lejátszása az appban (2026-09-20, AAB **337**) — **emulátorban igazolva**

- **A tulajdonos jelzése:** *„a cikkekben lévő youtube linket az appban le tudja játszani a play gombra, most youtube appot nyitja meg, erre van valami megoldásod?"* — hozzátéve, hogy *„a codex nem tudta megoldani"*.
- **A MÉRT GYÖKÉR (egyetlen sor):** a `lib/widgets/post_embed_card.dart` `initState`-je **szándékosan kihagyta** a YouTube-ot (`if (widget.embed.type == 'youtube') return;`), és helyette a `_YouTubeLinkCard`-ot rajzolta: thumbnail + „Videó megnyitása a YouTube-on" felirat, koppintásra pedig `_openExternal(...)` → `LaunchMode.externalApplication` = **a YouTube-alkalmazás**. A többi beágyazás (Spotify, SoundCloud, Instagram, TikTok) **már WebView-ban** ment. (A `_embedUri` egyébként kiszámolta a `youtube.com/embed/<id>` címet — de a YouTube-ág soha nem jutott el odáig.)
- **Két további mérés, ami szűkítette a hibát:**
  1. **ÉLŐ:** az első 20 cikkből **4 YouTube-embed**, mindegyikből kinyerhető az azonosító (a JSON-escape-elt `\u0026` alak is kezelve van);
  2. a cikk **szövegében** lévő linkek **már eddig is** az appon belüli böngészőt nyitották (`openInAppBrowser`) — tehát kizárólag a **kártya** volt a hibás.
- **A javítás (kliens, AAB 337 — `webview_flutter` már függőség volt, nem kellett új csomag):**
  1. **Új, tiszta modul:** `lib/core/media/youtube_embed.dart` — `youTubeVideoId` (a YouTube **összes** linkformája), `youTubeEmbedUri`, `youTubeEmbedHtml`, `youTubeEmbedBaseUrl`, `youTubeEmbedUserAgent`.
  2. **Origin/hivatkozó — EZ A LÉNYEG:** a lejátszót **saját HTML**-be ágyazzuk, és `loadHtmlString(..., baseUrl: youTubeEmbedBaseUrl)` tölti be. Ha a WebView közvetlenül a `youtube.com/embed/...` címet nyitja meg, a kérésnek **nincs hivatkozója**, és a YouTube „Video unavailable" / 153-as hibát ad — ezért nem működött eddig senkinek a WebView-os megoldása. A HTML emellett `referrerpolicy="origin"`-t és `name="referrer" content="origin"`-t is küld.
  3. **Chrome user-agent:** `setUserAgent(youTubeEmbedUserAgent)`, mert a WebView saját `…; wv` fejlécét a YouTube **nem támogatott böngészőnek** látja.
  4. **JavaScript** engedélyezve (a lejátszó enélkül el sem indul), `playsinline=1` (a lejátszás az appban marad), 16:9 `AspectRatio`, fekete háttér, töltésjelző.
  5. **Tartalék:** „Megnyitás a YouTube-on" gomb a lejátszó alatt (ha egy videó beágyazása tiltott), és az **azonosító nélküli** YouTube-link továbbra is a régi thumbnail-kártyát kapja — semmi nem törik el.
- **EMULÁTOROS BIZONYÍTÁS (Pixel_8, Android 15, `flutter build apk --debug`):** a telepítés után a **„Wasted Penguinz szünetet tart…"** cikk (id 12785) megnyitva → a videó a cikk **„Média" szakaszában játsszódik**, a YouTube saját vezérlőivel (play/pause, CC, beállítások, teljes képernyő), alatta a tartalék gomb. **Nem nyílt meg a YouTube-alkalmazás.**
  - **⚠️ TANULSÁG (emulátor, mérve):** az első indítás **nem app-hiba** miatt halt meg: `lowmemorykiller: Kill 'hu.hungarianhardstyle.app.debug' … to free 406536kB rss` — a debug build ~400 MB, és az alapértelmezett AVD memóriája kevés. Az emulátort **`-memory 4096`**-tal kell indítani (`emulator -avd Pixel_8 -memory 4096 -cores 4`).
  - **⚠️ TANULSÁG (eszközkép):** a képernyőképet `adb shell screencap -p /sdcard/x.png` + `adb pull` adja helyesen; a PowerShell `>` átirányítás **elrontja a PNG-t**.
- **BIZONYÍTÁS — új `test/core/youtube_embed_test.dart` (16):** az azonosító kinyerése **minden** valós alakból (a cikkekből mért `watch?feature=shared&v=…`, `&amp;`, `\u0026`, séma nélküli, `youtu.be`, `shorts`, `embed`, `live`); érvénytelen bemenet → `null` (nem YouTube link, üres, csatorna-URL); a **konfiguráció** (a `baseUrl` HTTPS-origin és nem `about:blank`, a UA Chrome-fejléc `wv` nélkül, `playsinline=1`); a **HTML** (iframe, `allowfullscreen`, origin-hivatkozó, `encrypted-media`); és **forrás-lint**, hogy a YouTube nem esik ki a WebView-ból, `loadHtmlString`+`baseUrl` van, a tartalék gomb megmaradt, és az azonosító nélküli link a régi kártyát kapja.
  - `flutter analyze` tiszta, `flutter test` **330/330** (a menet előtt 314 volt).
- **Csomag:** `build/HUHS-v1.0.0+337-release.aab` (versionCode **337**, 79,59 MB, SHA-256 `35FEB3EEFF1FFA30C04AB86C707E36574916691A89A9D4706F9B0939D21219A3`) — `pubspec.yaml` `1.0.0+337`, changelog-bejegyzés, Play-jegyzet frissítve. **A 336 MÁR FENT VAN a zárt teszt sávján** (mérve: `alpha = completed 336`), ezért a `lastPublishedBuild` mostantól **336**, az 1. Play-blokk már csak a 337-et írja le, az 1b. pedig a **329–337 összesítő** a production kiadáshoz.
- **A TULAJDONOS ÉLES ESZKÖZÖN IS IGAZOLTA (2026-09-20):** *„megy fel a 337, működött a youtube"* — vagyis a javítás a **valódi telefonján** is lejátszotta a videót az appban, nem csak az emulátorban. Ez a legerősebb bizonyíték (a hangot/képminőséget innen nem lehetett mérni).

### Chat-reakció: látszik, hogy TE már lájkoltad (2026-09-20, AAB **336**)

- **A tulajdonos jelzése:** *„ha valaki lájkol egy chat üzenetet, valahogy jelezhetné hogy az adott user lájkolta mert nem egyértelmű, nevet ne írjon oda, csak lássa hogy már lájkolta"*.
- **A MÉRT GYÖKÉR (két dolog együtt):**
  1. **A szerver már mindent tud:** a `toggleChatReaction` (`functions/index.js`) a `reactions` (emoji → darabszám) mellett **`reactionBy: {uid: emoji}`** térképet is ír — vagyis a „ki mivel reagált" adat **évek óta megvan**.
  2. **Az app eldobta:** a `CommunityPost.fromDocument` **csak** a `reactions` darabszámot olvasta be, a `reactionBy`-t nem — a felület pedig egy **múló** `_selectedReaction` mezővel jelölt (csak az utolsó koppintást, ami újratöltésnél elveszett). Ezért volt „nem egyértelmű".
- **A javítás (kliens, AAB 336):**
  - **`CommunityPost`**: új, **opcionális** `reactionBy` mező (`Map<String, String>`) + `myReaction(uid)` — **kizárólag a saját** UID-ot olvassa, neveket nem. A nem-string értékeket kiszűri.
  - **`CommunityService.toggleReaction`** mostantól **visszaadja** a szerver `selected` mezőjét (`''` = visszavontuk) — ez az egyetlen biztos forrás az azonnali visszajelzéshez (a szerveroldali írás 100–300 ms).
  - **`_PostCard`**: a saját reakció chipje **bejelölve** jelenik meg (`Icons.check_circle` + `primaryContainer` háttér + keret + félkövér címke + „Te reagáltál erre" tipp). Az optimista érték **pontosan a szerver válasza** (nem tipp), és a következő Firestore-kép beérkezésekor átadja a helyét a szerver állapotának (`didUpdateWidget`). Hiba esetén **nem hazudik**: marad a szerver-kép.
  - **⚠️ SZÁNDÉKOS DÖNTÉS — miért nem `currentUidProvider`:** az a provider **null-t ad vendégnek** (`isAnonymous`), a Chat-reakció viszont **vendégnek is engedélyezett** (`ensureAnonymousUser()` a szolgáltatásban, a szerver csak UID-ot kér). Ezért a `communityAuthProvider` **nyers** UID-ját használjuk, különben a vendég nem látná a saját reakcióját.
  - **Adatvédelem (tudni kell):** a `reactionBy` (UID → emoji) a Firestore-szabály szerint `allow read: if true`, tehát a kliens **megkapja** a teljes térképet — ez **nem új** (a privát üzenetek képernyője eddig is ebből olvasta a sajátját: `reactionBy[user.uid]`), és a felület **soha nem ír ki nevet**. Ha ezt szigorítani akarsz, a tiszta út egy `live_feed_posts/{postId}/reactions/{uid}` alkollekció (csak a tulajdonos olvashatja) — külön döntés, mert szerver + szabály + átállás.
- **BIZONYÍTÁS — új `test/widgets/chat_reaction_mine_test.dart` (7):** a saját reakció **jelölve** van és a tipp is megjelenik; **más** reakciója **nem** jelenik meg az enyémként (és nincs névkiírás); a koppintás **azonnal** jelöl (a szerver válaszából, a képre nem várva); **visszavonáskor eltűnik**; a `myReaction` csak a saját UID-ot olvassa (null/üres/idegen → üres); a `reactionBy` **beolvasása a Firestore-dokumentumból** (a nem-string érték kiszűrve); hiányzó `reactionBy` → üres, nem dob.
  - **⚠️ CSAPDA, amit mérve javítottam:** az első teszt-harness `Fake implements User`-rel **elhasalt** (`UnimplementedError: email`), mert a `_PostCard` az admin-jogot az **e-mailből** is nézi (`CommunityService.isAdmin`). A hamis felhasználónak ezért az `email`/`displayName`/`photoURL` is kell.
  - `flutter analyze` tiszta, `flutter test` **314/314** (a menet előtt 307 volt).
- **Csomag:** `build/HUHS-v1.0.0+336-release.aab` (versionCode **336**, 79,54 MB, SHA-256 `6C56CA5B103D82777DDF61C69630CBEC332225741A88CC07253348A070947C7F`) — a `pubspec.yaml` `1.0.0+336`, a changelog-bejegyzés a `lib/data/app_changelog.dart`-ban, a Play-szöveg a `docs/PLAY-KIADASI-JEGYZET.md`-ben (a blokkok **rövidítve**, hogy a 480 karakteres margó megmaradjon). **A plugin változatlan (2.5.9).**
- **⚠️ TANULSÁG:** a Play-blokk hosszát **minden új sorral újra kell mérni** (`node tools/check-play-notes.mjs`) — egyetlen hozzáadott sor átlépte az 500 karakteres limitet (540/552), ezért a régi sorokat is rövidíteni kellett.

### Play-követelmény: alkalmazás- és aláírásregisztráció (2026-09-20, határidő **2026-09-30**, **nincs teendő a kódban**)

- **A tulajdonos jelzése:** a Play Console egy zöld figyelmeztetést mutatott: *„Regisztrálj az összes olyan alkalmazás csomagnevét és aláírási kulcsát, amelyet Androidon terjesztesz"* — 2026. szeptember 30-tól a nem regisztrált Play-alkalmazásokat **globálisan letiltják**, és a **Playen kívül** terjesztett, Android-aláírási kulcsot használó buildek **sem telepíthetők** a tanúsítvánnyal rendelkező eszközökre bizonyos országokban. A kérdése: *„nekünk ezzel van dolgunk?"*
- **A MÉRT VÁLASZ: gyakorlatilag nincs teendő, de egy dolgot ellenőrizni kell.** A Play Console a mi sorunknál **„Regisztrált"** állapotot és **3 kulcsot** mutat (utolsó frissítés 2026-08-12), a feltöltési kulcsunk pedig egyetlen:
  - `applicationId = hu.hungarianhardstyle.app` — **egyetlen** alkalmazás (`android/app/build.gradle.kts`), nincs második csomagnév;
  - a **helyi buildek aláíró tanúsítványa**: SHA-256 `B4:FB:6D:AF:37:A7:0C:56:17:6F:8D:34:A5:BE:79:A1:7C:2E:5B:B5:59:1C:C4:F6:64:BF:29:47:F0:AB:0A:50`, `CN=Hungarian Hardstyle, OU=Mobile, O=Hungarian Hardstyle, L=Budapest, C=HU` (2053-12-23-ig);
  - **mind a 37 kész csomag (35 AAB 301…335 + 2 release APK) UGYANEZZEL a kulccsal** készült → **1 aláírási identitás** (a repóban lévő két `.jks` **bájtra azonos**, `D9FEC0D2…`);
  - a `android/app/build.gradle.kts`-ben **egy** release signing config van (`signingConfigs.create("release")`), és release buildhez **kötelező** a `key.properties` (különben a build el sem indul);
  - **Playen kívüli terjesztés nincs**: sem a plugin, sem a weboldal nem kínál app-APK-t (a „letöltés" a kiadványok zenéjére vonatkozik) — a zárt teszt is a Playről megy.
- **Amit a tulajdonosnak ellenőrizni kell (nem kód):** a Play Console „Aláírási kulcsok" nézetében szerepeljen a fenti lenyomat (a **feltöltési kulcsunk**) **és** a Google-féle **app signing key**. Ha valaha APK-t ad ki a Playen kívül, **azt a kulcsot is** regisztrálni kell — ezért a szabály: **egy kulccsal** írjunk alá mindent.
- **ÚJ ESZKÖZ: `tools/check-signing-identity.mjs`** — kiolvassa a kész AAB-ok/APK-k aláírását (`keytool -printcert -jarfile`, illetve `apksigner`; **a kulcstárat nem nyitja meg, titkot nem kér**), és megmondja, hány **különböző** aláírási identitás van. Egynél több → **figyelmeztetés** (mert a nem regisztrált kulcsú build 2026-09-30 után nem telepíthető). Önteszt **8/8** (lenyomat-egységesítés, `keytool`/`apksigner` kimenet-parsolás, csoportosítás, csonka lenyomat elutasítása).
  - **Mérve:** `1 különböző aláírási identitás`, 37 csomag.
- **⚠️ TANULSÁG:** a `.bat`-ot (Windows-on az `apksigner`) Node-ból **csak `shell: true`-val** lehet futtatni — enélkül a hívás üres kimenetet ad, és a „nem olvasható aláírás" **hamis riasztás** lenne (az első futás pontosan ezt mutatta a release APK-ra).

### Dupla push — „nézzünk rá, hogy LEHETSÉGES, némelyik push kétszer megy ki" (2026-09-20, **plugin 2.5.9 + szerveroldali javítás: AAB NEM kell hozzá**)

- **A tulajdonos kérdése:** *„nézzünk rá arra, hogy LEHETSÉGES, némelyik Push kétszer megy ki"*. A válasz **igen, lehetett** — és **két külön mechanizmus** okozta, mindkettő mérve.
- **MÉRÉS 1 — a küldő utak:** két rendszer küld push-t, és **szándékosan nem ugyanarra az eseményre**: a **WordPress-plugin** (`includes/push.php`) küldi a hírt/eseményt/release-t/emlékeztetőt/egyedi admin-üzenetet, a **Cloud Function-ök** pedig az ismerős-jelölést, meetup-érdeklődést, privát üzenetet, chatjelentést, értékelés-kérést, beküldés-értesítést és az achievement-pontot. A tokenek két helyen élnek (WP `huhs_push_tokens`, Firestore `fcmTokens`), és az app **mindkettőbe** regisztrál (`push_notification_service.dart`). **Nincs átfedő eseménytípus**, tehát innen nem jött dupla.
- **MÉRÉS 2 — a WordPress-oldali versenyhelyzet (ez a fő ok, „némelyik" = a nagy körüzenetek egy szelete):**
  - A küldési láncot **két út** futtatja ugyanarra a feladatra: a **cron-esemény** (`huhs_push_continue`) és a **biztonsági háló** (`huhs_push_resume_pending_job`, minden kérés `shutdown`-jában).
  - A háló abból következtetett az elakadásra, hogy a `last_run` régi (`HUHS_PUSH_RESUME_GAP` = **10 s**) — a `last_run` viszont **csak a kör VÉGÉN** íródott, egy kör pedig a `HUHS_PUSH_TIME_BUDGET` = **15 s** (plusz az utolsó köteg, akár +10 s HTTP) miatt **hosszabb**, mint a küszöb.
  - Ezért egy **éppen futó** kör „elakadtnak" látszott, és a háló **ugyanarról az offsetről** (az offset is csak a kör végén perzisztálódik) indított egy **második** kört → az éppen küldött eszközök **kétszer** kapták a push-t. A dupla tehát **nem mindenkinél** jelentkezik, hanem az éppen küldött szeletnél — pontosan a tulajdonos jelzése („**némelyik**").
  - **ÉLŐ MÉRÉS, ami igazolja, hogy a verseny valós:** a `?huhs_diag=huhs-boot-probe-2026` diagnosztika szerint **807 regisztrált eszköz**, és az utolsó kör **125 eszközt** vitt el → egy kör bizonyítottan hosszabb, mint a 10 s-os „elakad" küszöb.
  - **A javítás (plugin 2.5.9):** (1) **szívverés** — a kör **elején** frissül a `last_run`, így a futó kör nem tűnik elakadtnak; (2) **atomikus foglalás** (`huhs_push_job_lock_<key>`, `add_option`, `HUHS_PUSH_JOB_LOCK_TIMEOUT` = 60 s), amit a cron **és** a háló is tiszteletben tart, és a kör végén felszabadul.
  - **Ráadás javítás:** az **újrapróbálkozás** (hír/release) eddig a **nulláról** indult, ha az első szelet nem ment át — így azok is megkapták még egyszer, akiket a lánc már kiszolgált. Új `huhs_push_has_pending_job($expected)`: ha **ugyanannak a küldésnek** él a lánca, az újrapróba **nem indul**.
- **MÉRÉS 3 — a szerveroldali (Firebase) dupla, naplóból:** a Firestore-triggerek **legalább egyszer** (at-least-once) kézbesítenek, ezért ugyanaz az esemény kétszer is lefuthat. Az **értesítés** (`dedupeKey` + `.create()`) eddig is idempotens volt, a **push viszont nem**: a `notifyMeetupInterest`, a `notifyPrivateMessage` és a `notifyChatReport` a `createNotificationBestEffort` **eredményét eldobta**, és minden futásnál küldött. (Az ismerős-jelölésnél ez a kapu **már megvolt**: `if (!created) return null;`.)
  - **ÉLŐ BIZONYÍTÉK:** `node tools/check-push-duplicates.mjs --hours 720` → a naplóban ugyanarra a beszélgetésre **5–7 ezredmásodpercen belül kétszer** futott le a küldés (`private_message_push_result`), ami két külön emberi üzenetnél nem reális.
  - **A javítás (`functions/index.js`, AAB nélkül):** mindhárom út megkapta a `created` kaput (a `chat_report`-nál `!created.some(Boolean)`), és a privát üzenet naplója mostantól viszi a **`messageId`-t** is — így a dupla a jövőben **bizonyítható**, nem csak valószínűsíthető.
  - **Bizonyítás:** új `functions/push-dedupe.test.cjs` (**7/7**, Firestore-emulátoron, a VALÓDI függvényekkel, csak a küldést helyettesítve): ugyanaz az esemény kétszer leadva → **egy** push; két külön üzenet → két push (a védelem nem blokkol túl); chatjelentés és meetup ugyanígy; forrás-lint, hogy **minden** push-út védett (a függő ismerős-jelölésnél állapotváltás-kapu, ami újrakézbesítésnél nem enged át), és hogy csak a közös helper hívja a Firebase API-t.
  - **Élesítve:** `firebase deploy --only functions:notifyPrivateMessage,functions:notifyMeetupInterest,functions:notifyChatReport` → **Deploy complete!**
- **A plugin oldali bizonyíték (`tools/verify-push-dedupe.php`, 12/12):** stubolt WordPress-környezetben az FCM-stub az **első kézbesítés közben** meghívja a biztonsági hálót (ez a verseny), és számolja, melyik eszköz hány push-t kapott. A **javított** kódon egy eszköz sem kap kétszer; a **régi** viselkedést szimulálva (a foglalás törlésével) a dupla **megjelenik** — vagyis a kapu nem tud „néma" lenni.
- **ÉLESBEN IGAZOLVA (2026-09-20, a tulajdonos „2.5.9 fent van" jelzése után):**
  - `apiVersion = 2.5.9`; `verify-submission-payout.mjs --live` → **4/4**, `verify-wp-admin-endpoints.mjs` → **15/15** (a frissítés nem tört el mást);
  - `node tools/check-wp-push-state.mjs` → **807 eszköz**, az utolsó kör **`news`** volt: **130 eszköz, 0 hiba, 0 halott token**, és a lánc **lezárt** (`push_job=none`, `push_active=none`) → nincs elakadt küldés;
  - `node tools/check-push-duplicates.mjs --hours 8` → a privát üzenet naplója **már viszi a `messageId`-t**, és **minden üzenethez pontosan egy küldés** tartozik → **nincs dupla**.
  - **A WP-oldali javítás közvetlen megfigyelése a következő nagy körüzenetnél** lesz esedékes (a régi hibában az azonos offset futott újra; a diagnosztika a kör előrehaladását mutatja). **Ötlet a következő plugin-verzióhoz:** a `huhs_push_diag_summary()` írja ki a `job_lock` meglétét is, hogy a foglalás működése a fejlécből is látszódjon.
- **⚠️ TANULSÁG:** a *„csak a naplóba néztem"* itt **nem elég**: a WP-oldali dupla a saját cron/háló versenyéből jön, amit csak **kód + időzítés együtt** bizonyít. A `--self-test` mellett ezért van a harnessben **régi-viselkedés szimuláció**, ami megmutatja, hogy a kapu tényleg elkapja a hibát.
- **AAB NEM kell hozzá** (sem a plugin-, sem a szerveroldali javításhoz nem változott a kliens).

### A HIBASZŰRŐ VAKFOLTJA + egy valódi éles hiba (2026-09-20, szerveroldali javítás)

- **A felfedezés a dupla-push vizsgálat közben történt:** a `tools/check-function-errors.mjs` **nulla** találatot adott a push-naplókra, miközben azok **léteznek**. Az ok **mérve**: a **2. generációs** függvények (`onDocumentCreated`, `onDocumentWritten`, `onSchedule`) naplója a **`cloud_run_revision`** erőforrás alatt jelenik meg, **nem** `cloud_function` alatt. Az eszköz `resource.type="cloud_function"` szűrője ezért **a legfontosabb függvényeink hibáit egyáltalán nem látta**.
  - **Javítva:** a szűrő most `("cloud_function" OR "cloud_run_revision" OR "cloud_scheduler_job")`, és a függvénynév a `service_name`/`job_id` mezőből is kiolvasható (eddig „ismeretlen függvény" volt).
  - **Ez a tanulság általános: ha egy ellenőrző eszköz „minden rendben"-t mond, azt is meg kell mérni, hogy egyáltalán LÁTJA-e a vizsgálandó dolgokat.**
- **Amit a javított szűrő azonnal talált (24 óra, ~730 ERROR):**
  1. **`syncWordPressLabelProducts`: ~475 hibabejegyzés** — a Cloud Scheduler `DEADLINE_EXCEEDED` / 504, **5 percenként**. A gyökér a kódban: a szinkron **minden körben az összes kiadványt** végigjárja, és termékenként **egy Play GET + egy PATCH**-et küld (`upsertPlayProduct`), ezért nem fér bele a 2. generációs `onSchedule` **60 másodperces** alapkeretébe — a napló szerint a szinkron **soha nem fejeződött be**. **Javítás:** `timeoutSeconds: 300` (a párhuzamos futást a `sync_locks/label_product_sync` foglalás zárja ki). **Élesítve.**
  2. **`cleanupIncompleteAccounts`:** egy „maximum request timeout" (a fióktakarítás egy köre is túllépheti a 60 s-ot) — `timeoutSeconds: 300`. **Élesítve.** (A gyűjtemény további bejegyzései a **már javított** Cloudinary 403-as időszakból valók, nem újak.)
  - **MEGVALÓSÍTVA (2026-09-20, a tulajdonos jóváhagyásával: „csináld, ha NEM TÖRI EL a működést") — a label-szinkron nem küldi fel a VÁLTOZATLAN terméket.** A szinkron eddig minden körben az összes terméket felküldte (termékenként egy Play GET + egy PATCH), akkor is, ha semmi nem változott.
    - **A választott megoldás szándékosan a BIZTONSÁGOS irány: nincs gyorsítótár és nincs „utolsó szinkron" jelölő** (az elavulhatna, és a Play Console-ban kézzel átírt terméket elrejtené). A Play **olvasása megmarad**, és a választ pontosan azzal hasonlítjuk össze, amit a PATCH küldene — ha egyezik, **csak az ÍRÁS marad el**. Így a kézzel átírt termék továbbra is **azonnal** kiderül és javítva lesz; a nyereség a fölösleges írás.
    - **Az összehasonlítás a PATCH kérés törzsét tükrözi** (`updateMask: 'listings,purchaseOptions'`): a `listings` a PATCH-csel **lecserélődik**, ezért csak akkor egyező, ha a jelenlegi állapot pontosan az egyetlen `hu-HU` bejegyzés ugyanazzal a címmel/leírással; a régióknál a `HU` árnak (HUF, `units`, `nanos: 0`) és az `AVAILABLE` elérhetőségnek kell stimmelnie, és **nem lehet régió nélküli bejegyzés** (a PATCH eldobná). A `state`t **szándékosan nem** hasonlítjuk (a PATCH nem tartalmazza, tehát nem is változtatná — csak felesleges írást okozna).
    - **A döntés tiszta, nulla függőségű modulban van:** `functions/play-product-plan.js` (`playProductMatches`) — ugyanazt használja a függvény és a teszt, ezért nem tud elcsúszni.
    - **Bizonyítás:** `functions/play-product-plan.test.cjs` (**12/12**): az azonos terméket felismeri; a megváltozott **ár**, a `nanos`, a **cím/leírás**, az `UNAVAILABLE`, a **hiányzó HU régió**, a **régió nélküli bejegyzés**, a hiányzó `purchaseOption`/`buyOption` és a **több nyelvű** termék mind „nem azonos" (tehát írunk); a hibás bemenet (0/NaN ár, üres válasz) szintén nem azonos (nem hagyunk ki írást); és forrás-lint, hogy a döntés a **PATCH előtt** fut, a **valódi Play-választ** kapja, és egyezésnél `return`.
    - **ÉLŐ MÉRÉS a deploy után (2026-09-20 10:00–10:06):** **104 termékfeldolgozásból 60 írást kihagyott** (`label_product_sync_play_unchanged`: 60, `label_product_sync_play_patch_response`: 44), a kör `label_sync_summary { processed: 21, failed: [] }`-vel lezárult. **Egy átmeneti Google 503** (`radio_wav`, 10:00) a **következő körben magától elmúlt** — nem regresszió, a szinkron 5 percenkénti ismétlésének pont ez a célja.
    - **Élesítve:** `firebase deploy --only functions:syncWordPressLabelProducts,functions:syncLabelProducts,functions:syncQueuedWordPressLabelProducts` → **Deploy complete!**

### Achievement-pontok auditja — a „lájkoltam, mégsem kaptam pontot" ügy (2026-09-19, **szerveroldali javítás: AAB NEM kell hozzá**)

- **A tulajdonos jelzése:** *„nézz rá az achievent pontok kiosztására mert egy user jelezte, hogy lájkolt hírt és nem kapta meg és valóban nullán áll (Szabó Attila) + ha kiveszem a lájkot, ne adja vissza megint + a többi achi pont kiosztását is auditáld"*.
- **Amit ÉLŐBEN mértem (21 profil, 465 ledger-sor):**
  1. **Az invariáns tart**: minden profil `achievementPoints` értéke **pontosan** a `achievement_ledger` sorainak összege (**0 eltérés**) → a jóváírás/levonás mindig együtt íródik, nincs néma részleges írás.
  2. **Forrásonkénti mérleg:** `news-like` 379 grant / **20 revoke** (nettó +718), `attendance` 11/4, `meetup` 7/4, `meetup-interest` 11/4; a `article-comment`, `event-rating`, `game`, `profile-complete`, `voting` forrásoknál **nulla** revoke.
  3. **A valódi hiba (mért): 19 olyan eset**, ahol ugyanarra a (felhasználó, cikk) párra **grant ÉS revoke is** van → a pont **véglegesen elveszett**. Plusz **1** revoke, amihez nem tartozott grant (levonás a semmiből).
  4. **Szabó Attila konkrét esete:** 6 grant (+12 pont, 09-18 és 09-19), majd **6 revoke (−12)** → **0 pont**. Vagyis a pont **megérkezett**, de a lájkok visszavonása **elvette**, és a napi keret (3/nap) is elfogyott, ezért az új lájkjai már nem adtak pontot.
- **A gyökér (két, egymást erősítő hiba):**
  1. **A ledger-kulcs `grant`/`revoke` párt használt** (`sha256(uid:source:grant|revoke)`), ezért **a visszavonás UTÁN az újabb jóváírás örökre blokkolva maradt** (a `grant` sor már létezett). Emiatt a felhasználó mínuszba került ugyanazzal a cikkel. **Ugyanez a csapda állt** az esemény-részvételnél, a meetupnál és a meetup-érdeklődésnél is (oda-vissza váltogatás).
  2. **A lájk visszavonása levonta a pontot** — a tulajdonos szabálya viszont az, hogy *„ha kiveszem a lájkot, ne adja vissza megint"*, azaz a pont **egyszer jár** (és nem arról szól, hogy elvegyék).
- **A javítás (`functions/index.js`):**
  - **Egy ledger-sor forrásonként, `state: 'granted' | 'revoked'` mezővel** (a régi `grant`/`revoke` páros helyett). Jóváírás csak **állapotváltásnál** történik; a `revoke` után a `grant` **újra működik** (nincs csapda); a sosem adott pont **nem vonható le**; az ismételt jóváírás továbbra sem ad pontot (farmolás elleni védelem megmaradt). A régi sorokból az állapot **levezethető**, ezért az átállás nem veszít el adatot.
  - **A hír-lájk pontmagja külön, tesztelhető függvény** (`awardNewsReactionPoints`): a **visszavonás nem vesz el pontot**, ezért az újralájk **állapotváltozás nélkül** fut → nem ad új pontot, de nem is lehet vele pontot farmolni. Ezzel a tulajdonos szabálya **viselkedésként** teljesül.
  - A napi plafon (hír 3, komment 3) **változatlan** — az szándékos.
- **Bizonyítás (`functions/achievement-daily-limit.test.cjs`, 6 → 8 teszt):** a valódi tranzakciót futtatja Firestore-emulátoron; az új tesztek: *„a hír-lájk: a visszavonás NEM vesz el pontot, és az újralájk nem ad újat"* (lajk → visszavonás → újralájk, egyetlen ledger-sorral) és *„az esemény-részvétel oda-vissza váltogatása nem veszíti el a pontot"* (+10 → −10 → **+10 újra jóváír**, ismétlésre nem, és a sosem adott pont nem vonható le).
- **Élesítve:** `firebase deploy --only functions` (az `awardAchievementPoints`-t használó összes függvény és a `awardAchievementFromNewsReaction` trigger).
- **A VISSZAÁLLÍTÁS MEGTÖRTÉNT (2026-09-19, a tulajdonos jóváhagyásával: „rendben állítsd vissza, de a szabályok maradjanak meg").** ÉLŐ mérés a végrehajtás előtt és után:
  - **20 visszaállítás (+40 pont), 6 felhasználónál, 0 hiba** — Szabó Attila **0 → 12**, Denoiser **+14**, Benyo1982 **+8**, dornyeil **+2**, Zndo **+2**, deejay **0 → 2**;
  - **1 korrekció (−30)**: a saját hibám (dupla `profile-complete`) — Denoiser **222 → 206** (nettó +14 − 30 = **−16**);
  - az **invariáns tart**: 21 profil, 487 ledger-sor, **0 eltérés**, és **nincs visszaállítatlan elveszett pont** (`node tools/verify-achievement-points.mjs` → 2/2).
  - **A szabályok megmaradtak:** a visszaállítás külön forrás (`news-like-restore:<postId>`) a valódi `awardAchievementPoints` tranzakcióval (állapot-alapú ledger, farmolás-védelem), a **napi plafon nem fogy** tőle, és a lájk visszavonása továbbra sem ad/vesz el pontot.
- **A `profile-complete` dupla jóváírás korrekciója (`correction:` forrás).** A ledger-séma nem enged levonni olyan forrásra, amihez nincs korábbi jóváírás (`if (!ledger.exists && delta < 0) return`) — ez a „nincs mínusz a semmiből" védelem. Ezért az `awardAchievementPoints` kapott egy **kizárólag a karbantartási útból** használt `options.allowNegativeWithoutGrant` kapcsolót, a korrekció pedig **külön** `correction:profile-complete-duplicate` sor: így a **jóváírás eredeti naplója megmarad**, a `profile-complete` sor állapota `granted` marad (nem nyílik újra a jóváírás), és az összeg (30+30−30) továbbra is egyezik a profillal.
- **ÚJ ESZKÖZ: `tools/restore-lost-achievement-points.mjs`** — előnézet (írás nélkül) → megmutatja, ki mennyit kap; `--confirm` → létrehoz egy `maintenance_jobs/restore-lost-points` **munkakérést**, amit a **`runAchievementRestoreJob`** Cloud Function hajt végre (a `maintenance_job_results/<id>`-ba írja az eredményt). `--self-test` (7/7) bizonyítja a detektorokat: csak a hír-lájk visszavonást állítja vissza, **pontosan annyit, amennyit elvettek** (sosem többet), az esemény/meetup léptetést nem bántja, és a **biztonsági kapu** (max 200 pont / 25 felhasználó) megállítja a nagyszabású tévedést. A terv **tiszta logikája** `functions/achievement-restore-plan.js` (nulla függőség) — ugyanazt használja a függvény és az eszköz, ezért nem tud elcsúszni.
- **⚠️ TANULSÁG (mérve): az új Eventarc/Firestore-trigger nem azonnal kézbesít.** A `runAchievementRestoreJob` létrehozása után **23 másodperccel** kiírt munkakérésre **nem futott le semmi** (a naplóban csak a létrehozás látszott), és a futtatás 8 perc után időtúllépéssel állt le. A **második** kiírásra (a triggertől számítva ~9 perccel) **azonnal lefutott**. Ezért az eszköz **idempotens** (a terv a már visszaállított pontot nem kéri újra), és egy újrafuttatás mindig biztonságos.
- **⚠️ SAJÁT HIBA, AMIT A JAVÍTÁS OKOZOTT (2026-09-19, javítva ugyanaznap, `796c0f52`):** a ledger-kulcs átállása (`sha(uid:source)` a régi `sha(uid:source:grant|revoke)` helyett) miatt a kód a **régi sorokat nem találta meg**, ezért ugyanazért a teljesítményért **másodszor is kifizette** a pontot. Mért eset: **Denoiser `profile-complete` +30 kétszer** (2026-08-29 és 2026-09-19 15:38) — a tulajdonos ezt jelezte („kaptam valamire 30 pontot, nem tudom mire"). **A javítás:** a tranzakció `transaction.getAll(...)`-lal a régi `grant`/`revoke` sorokat is beolvassa; hír-lájk esetén a régi visszavonást **nem** tekinti állapotnak (a lájkpont egyszer jár), más forrásnál a későbbi sor dönt. **Új regresszió-teszt** őrzi (9/9 zöld). **A dupla jóváírás visszavonása megtörtént** (lásd fent: `correction:profile-complete-duplicate`, −30).
- **A LEDGER-ÖSSZEG SZABÁLYA (a `tools/verify-achievement-points.mjs`-ben, mérve igazolva):** a profil pontszáma a ledger-sorok összegével egyezik, ahol
  - **régi sor** (nincs `state`): a `delta` számít (minden váltás külön sor);
  - **új sor** (`state`): a forrás **nettó** hatása — `granted` → `+delta`, `revoked` → **0** (a jóváírás és a levonás kioltja egymást; a tárolt `delta` a legutóbbi lépésé);
  - **kivétel a `correction:` forrás**: ott maga a levonás az érvényes állapot, ezért a `delta` számít.
  - Ez a szabály a `profile-complete` korrekció **nélkül** hibás eltérést jelezne (ezért derült ki: az audit először 206 vs 236-ot mért) — **a saját öntesztje** (7/7) őrzi mindhárom esetet.
- **MÉRVE, NEM FELTÉVEZVE:** a Denoiser elveszett pontjai **14** (nem 12, ahogy korábban becsültem) — a terv a valódi ledgert olvassa, nem a korábbi kézi számolást.
- **NYITOTT (C)/(D):** lásd lentebb a „napi lájkpont-jelzés" és az AAB **332** szakaszt.

### Napi lájkpont-jelzés + görgetési villogás — a két utolsó tulajdonosi jelzés (2026-09-19, AAB **332**)

- **A tulajdonos jelzései:** *„jelezték, hogy pár dolog, pl a djk, hírek stb scrollozás közben villog, gondolom a háttérbetöltés miatt"*, *„kaptam valamire 30 achievement pontot… a notifyban MINDIG jelezze miért kapsz épp achievement pontot"*, valamint *„profilt rég kitöltöttem, de nem írta mér kaptam, PICIT késve jött meg, hetek után"* (= a dupla jóváírás és a visszamenőleges visszaállítás, lásd az achievement szakaszt).
- **A villogás mért gyökere:** a `ResizedNetworkImage` a `CachedNetworkImage` **alapértelmezett áttűnését** (500 ms be / 1000 ms ki) használta, és a lista minden újraépítése (görgetés, provider-frissülés) **újraindította** az animációt → a kép **minden görgetésnél kifakult és visszatűnt**. A javítás: `fadeInDuration: Duration.zero, fadeOutDuration: Duration.zero` (a memória-gyorsítótárból azonnal megjelenik). Ez **minden listát** érint, amelyik ezt a komponenst használja (hírek, DJ-k, események, kiadványok).
  - **Bizonyítás:** `test/widgets/resized_network_image_test.dart` (**2**) — azt méri, hogy a komponens **nulla áttűnést** ad át, és hogy a `memCacheWidth` be van állítva (különben a nagy kép lassú lenne).
- **A napi lájkpont-jelzés (C) — mért hiány:** a szerver a napi `count`-ot a profilba is írja (`achievementDailyLimit: {kind, date, count, limit}`), de az app **semmit nem mutatott**: aki a napi 3 pont után lájkolt, **néma csendet** látott, és azt hitte, elromlott. A GYIK írta a limitet, a felület nem.
  - **Kliens:** `NewsReactionService.watchDailyLikePoints()` + **tiszta** `dailyLikePointsOf(profileData, {now})` → `DailyLikePoints {count, limit, date, exhausted, label}` (`'A mai lájkpontod elfogyott.'` / `'Ma $count/$limit lájkpont jár.'`). A `NewsReactionButton` feliratkozik rá, és **csak lájk irányban** (nem visszavonáskor) szól: SnackBar „… Hírek kedveléséért naponta 3 alkalommal jár pont." A jelzés **nem blokkolja** a reakciót (a lájk attól még megtörténik).
  - **Három szándékos szabály:** (1) **más napra** szóló (elavult) számlálót nem használunk — nem állítunk olyat, amit nem tudunk; (2) `articleComment` típusú keret **nem** lájkpont; (3) hiányzó/0 limitnél **nincs** jelzés (nincs hamis „elfogyott").
  - **Bizonyítás:** `test/services/news_reaction_daily_points_test.dart` (**10**: 6 tiszta logika + 4 widget) — a widget-teszt a szűk `service` paraméterrel **Firebase nélkül** méri, hogy elfogyott keretnél **megjelenik** a SnackBar a limit megnevezésével, maradék keretnél/vendégnél/visszavonásnál **nem**.
  - **Egy hozzá tartozó hiba is javítva:** a `NewsReactionButton` a napi keret feliratkozását **nem mondta le** a `dispose()`-ban (szivárgás minden kártyánál) — most lemondja.
- **A korábbi szerveroldali rész (már élesben):** az `achievementReasonText(sourceKey)` minden értesítésbe beírja a **miértet** („+2 pont egy hír kedveléséért. Új összpontszámod: …"), és a profilba bekerül az `achievementDailyLimit` tükre. **AAB nem kellett hozzá** — ez a 332-ben csak a *kliensoldali jelzés*.
- **⚠️ ELSŐRE FÉLREVEZETŐ LEHET:** a `watchDailyLikePoints()` **vendégnél** (`isAnonymous`) `null`-t ad — a vendég nem kap achievement pontot, ezért nem is ígérünk neki keretet.
- **Csomag (D):** `build/HUHS-v1.0.0+332-release.aab` — `pubspec.yaml` `1.0.0+332`, changelog-bejegyzés a `lib/data/app_changelog.dart`-ban, Play-szöveg a `docs/PLAY-KIADASI-JEGYZET.md`-ben. A 332 **minden korábbi javítást tartalmaz** (329/330/331 nem ment ki), ezért **egyedül ezt kell feltölteni**. A plugin változatlan (**2.5.7**).

### Az Achievement-útmutató rendberakva + HÁROM ÚJ pontforrás (2026-09-19, AAB **333** + szerver)

- **A tulajdonos jelzése:** *„amit javítani kéne az Achievement menüben a »Több«-ben elavult meg pontatlan leírások vannak, ezt át kéne beszélni"*. Átbeszéltük; a döntései: **minden javítás + a napi limitek kiírása**, a két „üres" sor pedig **nem törlés, hanem megvalósítás** (*„Mi az hogy azok nem léteznek? Azoknak léteznie kéne"*), végül: *„arra is kéne 1-5 achievement pont naponta, ha valaki kommentel egy cikkhez, ír a chatre — ezt döntse el a szerver, mennyit aktívkodott és úgy ossza ki"*.
- **Amit MÉRVE találtam a képernyőn (`lib/screens/more/achievement_guide_screen.dart`), a valódi kóddal összevetve** (az összes `awardAchievementPoints(` hívás + az élő WordPress-jelvénykatalógus):
  1. **„Hír kedvelése +2 — a reakciód visszavonásakor a pont is visszavonódik"** → a 2026-09-19-i javítás óta **hamis** (a pont végleges), és a **napi 3-as keret** sem szerepelt.
  2. **„Cikk kommentelése +1 — naponta legfeljebb 5"** → **hamis: 3** (ugyanaz a tévedés, amit a GYIK-nál már javítottunk).
  3. **„Kiadvány megvásárlása +20 pont"** és **„Közösségi aktivitás +5–20 pont"** → **nem volt mögöttük szabály** a kódban (fantom sorok).
  4. Az esemény/meetup/kapcsolat sornál **hiányzott**, hogy lemondásnál a pont **elvész**.
  5. A „Fontos szabályok" technikai zsargonnal írt („idempotensen könyveli"), és félig igaz volt.
  6. A **szintek listája beégetve** volt az appban (ma pontosan egyezett az élő katalógussal, de bármikor elavulhatott).
- **SZERVER — a két „hiányzó" forrás mostantól VALÓDI (a tulajdonos döntései szerint):**
  - **Kiadvány-vásárlás +20 (`release-purchase:<productId>`):** a `verifyLabelPurchase` útvonalba kötve, amely a vásárlást a **Google Play APIn** ellenőrzi — ezért **nincs napi keret** (fizetős tétel, nem farmolható). A naplókulcs a **termék-azonosító**, ezért **minden megvásárolt változat** (radio/extended, MP3/WAV) egyszer jár.
  - **Jóváhagyott beküldés +10 (`submission:<kind>:<wpId>`):** a beküldött esemény/DJ/szervező **jóváhagyásakor** kapja a **beküldő** (a jóváhagyás admin-művelet, ezért a felhasználó magát nem tudja jóváírni). A `submitWordPressContent` mostantól elmenti a **szerző-megfeleltetést** (`submission_authors/<wpId>`, szerveroldali, kliens nem olvashatja), és a `manageWordPressSubmission` approve-ága osztja ki a pontot. **Napi keret: 3** (`APPROVED_SUBMISSION_DAILY_POINT_LIMIT`), mert a beküldések száma a felhasználó kezében van.
    - **FONTOS, ŐSZINTE KORLÁT:** a **korábban** beküldött (még függő) elemeknél nincs szerző-megfeleltetés, ezért azok jóváhagyása **nem** ad pontot — csak a bevezetés utáni beküldéseké.
  - **Napi aktivitási pont 1–5 (`daily-activity:<YYYY-MM-DD>`):** a tulajdonos kérése szerint a **szerver dönti el**, mennyit aktívkodott a felhasználó. Ezért nem cselekvésenként jár, hanem a **LEZÁRT nap** értékelése után, **egyszer**: a szerver a nap folyamán szerveroldali számlálót vezet (`daily_activity/<uid>_<dátum>`, kliens nem olvashatja), majd egy **ütemezett függvény** (`awardDailyActivityPoints`) sávosan oszt:
      `1 egység → 1 pont · 4 → 2 · 8 → 3 · 15 → 4 · 25 → 5`, ahol **1 cikkkomment = 2 egység** (több munka), **1 chat-üzenet = 1 egység**; a plafon napi **5**.
    - A számláló két helyről töltődik: a cikkkomment szerveroldali útvonalából (`articleComments` → `recordDailyActivity(uid,'comments')`), a chat-üzenetből pedig egy **új Firestore-triggerből** (`recordChatActivity` a `live_feed_posts` létrehozására) — azért trigger, mert a chat-üzenetet a **kliens** írja közvetlenül a gyűjteménybe, így a szerver csak így látja. A vendég (anonim) és a képes üzenet nem számít.
    - **MIÉRT 03:20-kor fut (budapesti idő), és miért nem éjfélkor:** a napi számlálók a **UTC-nap** szerint készülnek (mint a többi napi keret), a UTC-nap viszont Budapesten **01:00/02:00-kor** zárul. 00:20-kor a feladat a **még nyitott** napot értékelné, és a hajnali aktivitás elveszne; 03:20-kor a `now − 24h` UTC-dátuma már **lezárt** nap.
  - **Indoklás mindenhol:** az `achievementReasonText` új ágai (`submission:`, `release-purchase:`, `daily-activity:`), ezért az értesítés továbbra is **mindig megmondja, miért** járt a pont.
  - **A napi keret általánosítva:** a `dailyLimit`/`dailyLimitKind`/`dailyLimitCollection` egy helyen dől el (hír, komment, beküldés), és a profilba írt `achievementDailyLimit` **ugyanazt a `kind`-ot** kapja — így a kliens jelzése (`dailyLikePointsOf`) és a szerver számlálója nem tud elcsúszni.
  - **Törlés:** a `daily_activity` és a `submission_authors` bekerült a fióktörlés referenciáinak listájába (a törölt felhasználóra mutató sorok nem maradnak).
- **KLIENS:**
  - Az útmutató szövegei a valós működést írják (napi keretek, a lájkpont véglegessége, lemondásnál elvesző pontok, a három új forrás), **technikai zsargon nélkül**; a „Fontos szabályok" most felsorolás.
  - **A szintek a SZERVERRŐL jönnek:** új `getAchievementBadgeCatalog` callable (a szerveroldali 30 s-os WordPress-katalógust adja tovább, IP-re szűrt limittel), új `lib/services/achievement_service.dart` és `lib/providers/achievement_provider.dart`. A szolgáltatás **hálózati hiba esetén a beépített tartalék listát** adja, ezért a képernyő **soha nem lehet üres** — és a katalógus-lakérdezés **injektálható** (`catalogCaller`), hogy a teszt ne nyúljon Firebase-hez.
- **BIZONYÍTÁS:**
  - `functions/achievement-guided-points.test.cjs` (**11/11**, Firestore-emulátor, a VALÓDI függvényekkel): jóváhagyott beküldés +10 a beküldőnek indoklással, ismételt jóváhagyás nem fizet kétszer, a **4. beküldés már nem jár ponttal** (napi 3), ismeretlen beküldés nem ír jóvá, kiadvány-vásárlás +20 változatonként (ismételt ellenőrzés nem fizet, másik változat igen), a napi aktivitás **sávjai** (1 egységtől 1 pont, 25-től 5, plafon), a számláló gyűjtése, a napra egyszer járás + indoklás, és hogy aktivitás nélkül nincs pont.
    - **Mutációs bizonyíték:** a beküldés napi keretét kiiktatva (`isSubmissionGrant = false`) **elhasal** a napi keret tesztje (6/7).
  - `test/widgets/achievement_guide_test.dart` (**4/4**): a szöveg nem tartalmazza a régi tévedéseket (5 komment, „visszavonódik"), a napi keretek és az új sorok megvannak, a szintek a **szerverről** jönnek (felülírt listával mérve), hálózat nélkül a **tartalék** lista jelenik meg, a szerver-listát pedig pontszám szerint rendezi és a hibás elemeket kihagyja.
  - **ÚJ KAPU: `tools/verify-achievement-guide.mjs`** (**20/20** + önteszt **6/6**) — a `functions/index.js`-ből kiolvassa a pontértékeket, a napi kereteket és a **létező forrásokat**, majd megköveteli, hogy az útmutató szövege ugyanazt írja. Az önteszt **bizonyítottan elhasal** a régi szövegeken (5 komment, „visszavonáskor elvész"), a megváltoztatott kódkonstanson, a hiányzó napi aktivitási soron és a forrás nélküli kiadvány-soron.
  - `flutter analyze` tiszta, `flutter test` zöld, `functions/achievement-daily-limit.test.cjs` **9/9**, `functions/account-deletion.test.cjs` **6/6** (a törlés az új gyűjteményekkel is).
- **A RANG/JELVÉNY frissítése szintlépésnél (a tulajdonos kérése: „cache-ben megvan, de ha szintet lép, indít egy lekérést").** A mért állapot: a gyorsítótár **megvolt** (memória + tartós tároló, a jelvénykép URL-je pedig **verziózott**: `?huhs_badge_v=<updatedAt|achievementUpdatedAt>`, és a szerver csak akkor ír új verziót, amikor a jelvény **tényleg** változik — épp azért, hogy egy lájk ne érvénytelenítse mindenki képét). A **hiányzó láncszem** viszont az volt, hogy a `CommunityService.refreshMyAchievementBadge()` **létezett, de SENKI nem hívta** (holt út), ezért a szintlépés csak a cache lejárta után (30 s / 2 perc) vagy újranyitáskor látszott.
  - **Új `lib/services/achievement_rank_sync.dart`:** a saját profil **nyilvános vetületére** (`public_profiles/<uid>`, amit a szerver minden pontváltozásnál frissít) figyel, és **csak akkor** indít frissítést, ha a **rang tényleg megváltozott** (más a jelvény `slug`-ja **vagy** új verziójú a jelvénykép). A pontnövekedés önmagában **nem** indít semmit.
  - **Három szándékos szabály:** (1) az **első** kép nem változás (induláskor nincs felesleges szerverhívás — a cache épp ezért van); (2) két frissítés között **2 perc** telik el (egy gyors pontgyűjtés sem indít több hívást; a közben történt változást a kiürített cache miatt a következő olvasás úgyis látja); (3) egy **hibázó** frissítés nem állítja meg a figyelést.
  - **Bekötés:** `achievementRankSyncProvider` (a `currentUidProvider`-re épül, és a `refreshMyAchievementBadge()`-et hívja, ami a szerveren újraszámolja a jelvényt, majd kiüríti a profil/jelvény cache-t) — a **Kezdőlap** watcholja, mert az az első fül, ezért a feliratkozás a teljes munkamenet alatt él.
  - **⚠️ CSAPDA, amit mérve javítottam:** a provider első változata **elhasalt a widget-tesztekben** (`FirebaseException`: a `communityServiceProvider` Firebase nélkül dob) — ezért a provider az első sorban a `Firebase.apps.isEmpty`-t vizsgálja, és **null-t ad**, ha nincs Firebase. Ez a minta a projektben máshol is így van (`NewsReactionService._firestore`).
  - **Bizonyítás:** `test/services/achievement_rank_sync_test.dart` (**7/7**, injektált streammel, Firebase nélkül): szintlépésnél indul lekérés; **pontnövekedés ugyanabban a rangban nem** indít; a **kicserélt jelvénygrafika** (új kép-verzió) igen; a 2 perces korlát fog; a hiányos vetület és a stream-hiba nem dönt; a hibázó frissítés után is figyelünk tovább; a jelvény-kulcs a slugból és a kép verziójából áll.
  - `flutter analyze` tiszta, `flutter test` **302/302**.
- **BEKÜLDÉSI SZEREPKÖR-SZABÁLY (2026-09-19, AAB 335) + a „csak elfogadottért jár pont" kérdés.** A tulajdonos két jelzése:
  1. *„djt csak dj szerepkörrel, esemény csak szervező szerepkörrel és szervezőt is szervező szerepkörrel lehet csak beküldeni"* — a **mérés** szerint a DJ és a szervező eddig is így működött, **az ESEMÉNY viszont szerepkör nélkül** volt (`role: null`): a szerver bármelyik bejelentkezett felhasználótól elfogadta, és az app az **Események fülön mindenkinek** felkínálta a gombot (`canSubmit = user != null && !user.isAnonymous`). Ez volt az **egyetlen könnyen farmolható** beküldés (napi 3 elfogadott = +30 pont).
  2. *„csak ELFOGADOTT beküldésért járjon achi"* — ez az **app-úton eddig is így volt** (a jóváírás a WordPress approve **sikeres** visszaigazolása után fut; a `trash` nem ad pontot; az ismételt elfogadás a naplókulcs miatt egyszer fizet). **DE megmértem a rést:** a beküldést a **WordPress adminban is** el lehet fogadni (`admin_post_huhs_approve_profile_submission` → `huhs_approve_profile_submission()`), az viszont **nem szól a Firebase-nek**, ezért ott **nem jár pont** (a WP csak egy piszkozat-profilt hoz létre, és a `created_profile_id` metát írja a beküldésre). Ezt jeleztem a tulajdonosnak; a teljes lefedéshez a WordPress-oldali elfogadás visszajelzése kell (kis plugin-kiegészítés, következő plugin-verzió).
  - **A javítás:** `submissionRoutes.event.role = 'organizer'` + **tiszta `submissionRoleAllows(routeRole, profileRole, isAdmin)`** (a `role` **lista** is lehet, ezért egy szó egy későbbi lazítás); a hibaüzenet megnevezi a szükséges szerepkört. Kliensen **ugyanaz a szabály** egy helyen: új `lib/services/submission_rules.dart` (`requiredRoles`, `canSubmit`, `denialMessage`, `notice`) — a `Több → Beküldés` szakasz és az Események fül gombja ezt használja, ezért a felület nem kínál olyat, amit a szerver elutasítana.
  - **Bizonyítás:** `functions/achievement-guided-points.test.cjs` **12/12** (új teszt: esemény = szervező, DJ = DJ, admin mindent, lista is működik, szerepkör nélkül semmi), `test/services/submission_rules_test.dart` **5/5**, `flutter analyze` tiszta, `flutter test` **307/307**, a `tools/verify-achievement-guide.mjs` **23/23** + önteszt **8/8** — két új **mutációs bizonyítékkal**: a szerepkör nélküli esemény ÉS a szerveroldali kapu eltávolítása is **elhasal**.
  - **Csomag:** `build/HUHS-v1.0.0+335-release.aab` (versionCode **335**, 79,54 MB, SHA-256 `4D824B24B9C071BB1A429530ABF93D5BC6803D0CC68B4C94BE0B869772CAA10D`), mert a **334 már felkerült** a zárt teszt sávjára (mérve: `alpha → completed 334`).
- **A MÁSIK JÓVÁHAGYÁSI ÚT PÓTLÁSA — plugin 2.5.8 + ütemezett függvény (2026-09-19, AAB NEM kell hozzá).** A tulajdonos a teljes megoldást választotta („*ez kell*”): ha egy beküldést a **WordPress adminban** fogadnak el, a pont **utólag is megérkezzen**.
  - **Plugin 2.5.8 — új végpont:** `GET /huhs/v1/submission-statuses?ids=1,2,3` → `{ items: [{ id, type, status, accepted, profileId, profileStatus }], count }`. Az elfogadást a **`created_profile_id` meta** jelöli (a WordPress-admin approve ezt írja; a beküldés poszt-státusza `pending` marad, ezért a státusz nem használható). **Batch** (legfeljebb **100** azonosító), és **hitelesítés mögött van** (`huhs_submission_api_permission`), tehát nem nyilvános. A tiszta logika külön függvény (`huhs_submission_status_payload`), és a `profileStatus` mezőt is visszaadja — így később egy szóval szigorítható („csak publikált profilért járjon pont”) anélkül, hogy a végpont változna.
  - **Szerver — `reconcileSubmissionPoints` (30 percenként, europe-central2):** végigmegy a `submission_authors` megfeleltetéseken (amelyeknél nincs `awardedAt`/`abandonedAt`), lekérdezi a végpontot, és **csak `accepted === true`** esetén fizet a VALÓDI `awardAchievementPoints`-szal. **Négy szándékos szabály:** (1) csak elfogadottra fizet; (2) **nem fizet kétszer** — ha a naplóban már `granted` sor van (pl. az app-út már kifizette), csak megjelöli késznek; (3) a **napi keret miatt elhalasztott** pontot **nem jelöli késznek**, ezért a következő körben kifizeti (nincs elveszett pont); (4) **WordPress-hiba esetén semmit nem jelöl meg**, hogy újrapróbálhassa.
  - **Bizonyítás:** `functions/achievement-guided-points.test.cjs` **18/18** (5 új teszt: WP-adminban elfogadott beküldés pontja megérkezik + kész-jelölés; az appból már kifizetett nem fizet kétszer; a még nem elfogadottért nem fizet; a **napi keret nem veszíti el a pontot**; WP-hiba után nem jelöl késznek) — **mutációs bizonyítékkal**: az „elfogadás nélkül is fizet” változat **elhasal** (17/18).
  - **ÚJ KAPU: `tools/verify-submission-payout.mjs`** (**10/10** + önteszt **5/5**, négy mutációval: nyilvános végpont, elfogadás nélküli fizetés, dupla-fizetés ellenőrzésének eltávolítása, WP-hiba „kész”-nek jelölése) — és van **`--live`** módja is, ami a feltöltés után a valódi végpontot méri (üres kérésre 400, ismeretlen id-ra üres lista, hitelesítés nélkül 401/403, `apiVersion >= 2.5.8`).
  - **Csomag:** `build/huhs-mobile-api-2.5.8.zip` (45 fájl, 143,8 KB, SHA-256 `6F758F4DD0179B584017B34EB8365DB4C0C5FD8325FBC6BBB7C2A7D292FED206`) — **ezt a tulajdonos tölti fel**; 44/44 PHP fájl tiszta, `check-plugin-encoding.mjs` **45/45**, `check-wp-admin-menu.mjs` **8/8**. **AAB nem kell hozzá.**

### Létrehozás a natív adminból: kérdőív, nyereményjáték, kvíz (2026-09-19, AAB **331** + plugin **2.5.7**)

- **A tulajdonos kérdése:** *„ja de most már tudok hozzáadni kvizt, nyereményjátékot és kérdőívet natív adminból?”* — a válasz **nem** volt, és ezt kódban is igazoltam: a `_creatableSections` csak `huhs_event`/`huhs_artist`/`huhs_organizer`, a `save_resource` **kizárólag meglévő** bejegyzést mentett (`get_post()` + `edit_post` jog), a `huhs_admin_resource_fields()` pedig a `huhs_poll`/`huhs_prize`/`huhs_game` típusokra **üres listát** adott. A tulajdonos ezután **mindhármat** kérte.
- **Szerver (plugin 2.5.7) — új `includes/admin-create.php`:**
  - `HUHS_ADMIN_CREATABLE_TYPES` (a meglévő négy + a három új), `HUHS_ADMIN_QUIZ_TYPES` (csak a 3 kvíz-típus), `huhs_admin_is_creatable_type()`.
  - `huhs_admin_interaction_fields($type)` — a három típus mezői. **A mezők kulcsa MINDIG a valódi meta-kulcs** (`_huhs_poll_options`, `_huhs_prize_correct`, `_huhs_game_questions`), ezért a mentés nem tud elcsúszni a WordPress-oldali űrlaptól.
  - **Tiszta, WP nélkül tesztelhető logika:** `huhs_admin_text_list_values()`, `huhs_admin_question_values()` (minden sort **megtart**, hogy a hiba meg tudja nevezni a hibás sort), `huhs_admin_validate_resource_values()`, `huhs_admin_encode_meta_value()`, `huhs_admin_normalize_resource_meta()`, `huhs_admin_created_status()`, `huhs_admin_resource_title()`.
  - `api-admin.php`: a `resource` művelet `id=0`-ra a **mező-definíciókat** adja vissza (üres értékkel) — így az app **ugyanazt az űrlapot** használja létrehozáshoz és szerkesztéshez; a `save_resource` `id=0`-ra **létrehoz** (`wp_insert_post`), validál, majd menti a metákat.
  - **Négy tudatos döntés:** (1) a `_huhs_prize_correct` a felületen **1-alapú** (ahogy az ember számol), a szerver fordítja **0-alapú indexre** — egy helyen; (2) az új elem alapból **`publish`**, mert a „piszkozat” csendes lenne (a szerver `draft` helyőrzőjét az app szándékosan **figyelmen kívül hagyja** — ezt a teszt fogta meg); (3) a kvíznél **csak a 3 kvíz-típus** választható, a többi játéktípus (idővonal, „találd ki a zenét”, hang-borítók, jutalomsávok) **szándékosan a WordPress adminban marad**; (4) a hibaüzenet **megnevezi a hibás kérdés sorszámát**.
- **App (AAB 331) — új `lib/screens/community/admin_resource_editor_screen.dart`:**
  - `adminResourceRequestProvider` (szűk szelet) → a képernyő **Firebase nélkül tesztelhető**.
  - Mezőtípusok: `text`, `textarea`, `int`, `bool`, `select`, `url`, `email`, **`text_list`** (2–6 válasz, a sorok számát a mező `min` értéke adja), **`questions`** (kérdés + 2–6 válasz + a helyes válasz bepipálása).
  - Belépési pontok: „＋” a **Kvíz és játékok** szakaszon (`Key('game-create')`), a **Kérdőív-eredmények** (`Key('poll-create')`) és a **Nyereményjáték-admin** (`Key('prize-create')`) képernyőn; mentés után a lista frissül.
  - Helyi ellenőrzés a mentés előtt (ugyanaz, amit a szerver is kér), és a szerver hibája **megjelenik** — nincs néma hiba.
- **Bizonyítás:**
  - `test/widgets/admin_resource_editor_test.dart` (**6 teszt**) — nem a külalakot, hanem a **kimenő tartalmat** méri: a mentés a valódi meta-kulcsokat és a megjelölt helyes választ küldi; 1 megadott válasszal **nem** indul mentés; a hibás kérdés sorszáma megjelenik; a szerver hibáját kiírja.
  - `tools/verify-admin-create.php` (**41 ellenőrzés**) — a tiszta logika stubolt WordPress-környezetben; a mutációs bizonyíték: a „legfeljebb 6 válasz” feltétel kiiktatásával **elhasal**.
  - `tools/verify-native-admin-menu.mjs` **31 → 51** — az új szakasz a három létrehozási útvonalat ÉS a **mezőtípus-egyeztetést** méri (amit a szerver küldhet, azt az appnak ismernie kell).
  - `flutter analyze` tiszta, `flutter test` **279/279**, 44/44 PHP parse, `check-plugin-encoding.mjs` **45/45**, `check-wp-admin-menu.mjs` **8/8**, `verify-prize-draw.mjs` **47/47**, `verify-poll-status.mjs` **25/25**, `check-play-notes.mjs` zöld.
- **Csomagok:** `build/HUHS-v1.0.0+331-release.aab` (versionCode **331**, 79,49 MB, SHA-256 `6D5798840E5C47EA6AB7DF54B2BB1C2A3767016E89BCD3B4326158973EC85336`) és `build/huhs-mobile-api-2.5.7.zip` (45 fájl, 142,9 KB, SHA-256 `352223459F8DC5318321303B8BF835623AE8856465F15412E03D5002F744F2E9`). **Mindkettőt fel kell tölteni** (app + plugin), és a 329/330 AAB helyett a 331 megy.
- **⚠️ FIGYELEM, DURVÁN FONTOS A JÖVŐRE:** a **plugin forrása gitignore-olt munkafában él** (`.gitignore: /.tmp-*`), ezért a repóban **csak a ZIP és a dokumentáció** látszik — egy másik agens (Codex) a plugin kódját **nem látja**. A `build/` szintén ignorált. Ha a munkafa törlődik, a plugin forrás-előzménye elvész. Ezt jeleztem a tulajdonosnak; a megoldás külön döntés (a plugin forrásának verziókezelése).
- **ÉLESBEN IGAZOLVA (2026-09-19, a tulajdonos feltöltése UTÁN):** a plugin **2.5.7** fent van — `apiVersion=2.5.7`, és az új `tools/verify-admin-create-live.mjs` **11/11**-gyel igazolta a létrehozó-utat:
  1. mindhárom típus űrlapja lekérhető (`action=resource&type=…&id=0`) a **valódi meta-kulcsokkal**;
  2. `--confirm`-mal egy **piszkozat** kvíz **létrejött** (`wp_insert_post`), és a meta-körjárás megmaradt (típus, kérdések JSON, jutalom pont);
  3. a `save_resource` **frissítő** útja is működik (a cím átírása `200`, a piszkozat állapot **nem** változott — nem lehet véletlenül publikálni).
  - Az élő teszthez egy **piszkozat kvíz** maradt a WordPressben (`id=12771`, „TESZT – törölhető (éles ellenőrzés)”) — az appban **nem** látszik, a WP adminban törölhető (a `huhs_game` típus nincs `show_in_rest` módban, ezért REST-ből nem törölhető).
- **ISMERT, APRÓ DÖNTÉS (nem hiba, de tudni kell):** a natív létrehozásnál a **kvíz címe a „Rövid leírás” mezőből** lesz (`huhs_admin_resource_title()`), mert a WordPress űrlapján a cím külön mező, nálunk viszont nincs — és a `save_resource` **létrehozásnál** a kérdés/leírás mezőt részesíti előnyben. Ez **csak az admin-listákban** látszik: az **app a típusnevet** mutatja a játéknak (`'title' => HUHS_GAME_TYPES[$type]` a nyilvános payloadban), nem a post-címet. Ha a tulajdonos kéri, a következő plugin-verzióban egy „Név” mezőt veszünk fel, és a cím-preferenciát a szerveren fordítjuk meg.

### Élő ellenőrző eszközök — a hibavadászat „szemei" (2026-09-19, commitolva a `tools/` alá)

A 2026-09-19-i hibavadászat ideiglenes szkriptekkel történt, ezért azok **nem látszottak** a következő agensnek. Mostantól a `tools/` alatt vannak, **egy paranccsal** újrafuttathatók, és **titkot nem tartalmaznak** (a Firebase CLI bejelentkezését és a Secret Managert használják futásidőben).

| Eszköz | Mit mér | Használat |
|---|---|---|
| `tools/verify-live-account-deletion.mjs` | **ÉLES**: nincs-e elakadt törlés (`pending` rekord létező profillal) és nincs-e „szellem-profil" (törölt jelölés + létező profil) | `node tools/verify-live-account-deletion.mjs` · önteszt: `--self-test` |
| `tools/verify-wp-admin-endpoints.mjs` | **ÉLES**: a plugin `apiVersion`-je, a `prize_games`/`prize_results`/`poll_results`/`polls` végpontok, UID/hash-szivárgás, `players = résztvevők` konzisztencia | `node tools/verify-wp-admin-endpoints.mjs` · önteszt: `--self-test` |
| `tools/verify-native-admin-menu.mjs` | a natív admin menüpontjai ↔ a plugin admin-végpontjai (forrás-lint) | `node tools/verify-native-admin-menu.mjs` |
| `tools/check-play-listing.mjs` | a **nyilvános** Play-oldal állapota (zárt tesztnél 404 = várt eredmény) | `node tools/check-play-listing.mjs [csomagnév]` |
| `tools/check-play-track.mjs` | **ÉLES**: mi van tényleg a Play sávjain (melyik build, milyen állapotban, milyen kiadási szöveggel) — a Play Developer API-t **olvasásra** kérdezi | `node tools/check-play-track.mjs [csomagnév]` |
| `tools/run-account-cleanup.mjs` | a 15 percenkénti fiók-takarítás **azonnali** futtatása (idempotens) | előnézet: `node tools/run-account-cleanup.mjs` · futtatás: `--confirm` |
| `tools/check-play-notes.mjs` | a kiadási szöveg (karakterlimit, build-lefedettség, AAB-hash) | `node tools/check-play-notes.mjs` |
| `tools/verify-achievement-points.mjs` | **ÉLES**: a profil-pontszám egyezik-e a ledgerrel, és van-e **visszaállítatlan** elveszett hír-lájk pont | `node tools/verify-achievement-points.mjs` · önteszt: `--self-test` |
| `tools/restore-lost-achievement-points.mjs` | az elveszett pontok **visszaállítása** (előnézet írás nélkül; `--confirm` → munkakérés a Cloud Functionnek) | `node tools/restore-lost-achievement-points.mjs` · `--confirm` · önteszt: `--self-test` |
| `tools/verify-achievement-guide.mjs` | az Achievement-útmutató **szövege** egyezik-e a kóddal (pontértékek, napi keretek, létező források, nincs zsargon) | `node tools/verify-achievement-guide.mjs` · önteszt: `--self-test` |
| `tools/check-function-errors.mjs` | **ÉLES**: volt-e `ERROR`/`WARNING` a Cloud Function-ökben az elmúlt időszakban (Cloud Logging, függvényenkénti összegzéssel) | `node tools/check-function-errors.mjs [--hours 72] [--warnings]` |

- **Közös modul:** `tools/lib/live-firebase.mjs` — Firebase CLI token (memóriában), Firestore-olvasás, titok-lekérés, ütemező-indítás, egységes ellenőrzés-kiíró, UID/hash-szivárgás-kereső. **Titkot a repóban soha**; a token-tároló fájlhoz nem nyúlunk.
- **Az öntesztek bizonyítják a detektorokat:** a törlés-kapu a „pending + létező profil" és a „szellem-profil" esetet is elkapja (és egy „mindig rendben" mutált változat elbukna), a WordPress-kapu pedig megtalálja az UID/hash-szivárgást.
- **Node-csapda Windowson (érdemes megjegyezni):** a `process.exit()` a nyitott hálózati kapcsolatok mellett **elhasal** (`libuv assertion … async.c`), ezért ezek az eszközök `process.exitCode`-ot állítanak, és a folyamat magától lezárul.
- **⚠️ TITOK-OLVASÁSI CSAPDA, mérve (2026-09-19, javítva a `tools/lib/live-firebase.mjs`-ben):** a `secret(name)` a `gcloud secrets versions access` **kimenetének UTOLSÓ sorát** vette — a CLI viszont a titok után **egy üres sort** is nyomtat, ezért a visszaadott érték **üres string** lett. Az első `--live` futás emiatt hasalt el (`A(z) WORDPRESS_APPLICATION_PASSWORD titok nem olvasható`), miközben a titok **létezett és jó volt**. A javítás: az **utolsó NEM ÜRES** sor kell (`split(/\r?\n/).filter(l => l.length).pop()`). A tanulság általános: **a titkot nem a kimenet alakjából, hanem a tartalmából kell kivenni** — és ha egy „nem olvasható a titok" hiba jön, **előbb a kiolvasást kell ellenőrizni**, nem a titkot hinni rossznak. (Ugyanez a hibaosztály, mint a Cloudinary `l`/`I` eseténél: a hiba a **kiolvasásban** volt, nem a szolgáltatásban.)

### Natív admin: a kvíz, a kérdőív és a nyereményjáték menüpontjai (2026-09-19, AAB **330**)

- **A tulajdonos jelzése:** *„ami nem működik: a natív huhs adminban nincsenek ott a nyereményjáték, kviz, és a kérdőiv meg a hozzá tartozó menüpontok"*.
- **A mért gyökér (két külön dolog):**
  1. **Elérhetetlen menüpontok.** A plugin admin-végpontjai (`polls`, `poll_results`, `prize_games`, `prize_results`, `settings`, `newsletter`, `shortcodes`) **éltek**, sőt a `wordpress_admin_screen.dart` `_load()`-ja egy részüket **be is töltötte** — de a **menüben** (`_sections`) nem szerepeltek. Pontosan a néma hibaosztály, amit kergetünk: a szerver tudja, az app nem kínálja fel. (Ugyanez volt korábban a `users` szakasszal is, az is holt kód.)
  2. **A „kvíz" valójában ott volt, csak más néven.** A „Játékok" chip a `huhs_game` bejegyzéstípus listája: `hardstyle_quiz`, `festival_quiz`, `hungarian_hardstyle_quiz` + Hardstyle idővonal. A tulajdonos ezt „kvíz" néven kereste, és nem ismerte fel — ezért a cím mostantól **„Kvíz és játékok"**.
- **A javítás (`wordpress_admin_screen.dart`):**
  - `_sections` bővítve: **`Kvíz és játékok`** (átnevezve), **`Kérdőív`** (`poll_results`), **`Nyereményjáték`** (`prize_results`), **`Hírlevél`**, **`Shortcode-ok`**, **`Beállítások`** — az utolsó három eddig is működött a háttérben, csak nem lehetett megnyitni.
  - **Új `_openingSections` térkép** (`String → WidgetBuilder`): a „csak megnyitó" pontok (Szavazási állás, Kérdőív, Nyereményjáték) egy helyen vannak, és a `_select` ezt használja — nincs többé szétszórt `if`. Így a menüpont és a célképernyő **nem tud elcsúszni** egymástól (ezt a kapu is méri).
  - A „Kérdőív" a `PollResultsScreen`-t, a „Nyereményjáték" a `PrizeAdminScreen`-t nyitja — mindkettő a **saját** szervervégpontjait használja (`polls`/`poll_results`, illetve `prize_games`/`prize_results`), és **nem** ad ki UID-t/hash-t.
- **Új, önmagát bizonyító kapu: `tools/verify-native-admin-menu.mjs`** (**31/31**) — a plugin **összes** `$action === '…'` ágát kiolvassa az `api-admin.php`-ból, az app menüjét/szaka­sz-kezelőit a `wordpress_admin_screen.dart`-ból, és megköveteli, hogy **minden olvasó végpont elérhető legyen** valahonnan (közvetlen menüpont, kezelő ág, vagy egy megnyitó menüpont mögötti képernyő — ezt a célscreen forrásából igazolja). A dokumentált kivételek: `voting_seasons` (a szezonok adminja szándékosan a WordPressben marad) és `resource` (belső szerkesztő/törlő művelet) + a write-ágak.
  - **A mutációs bizonyíték:** a javítás előtti `wordpress_admin_screen.dart`-on a kapu **elhasal** (20/28, 8 HIBA: nincs `_openingSections`, nincs „Kvíz és játékok"/„Kérdőív"/„Nyereményjáték" menüpont), a javított kódon **31/31**.
- **Csomag:** `build/HUHS-v1.0.0+330-release.aab` — a **329 helyett** ezt kell feltölteni (a 330 mindent tartalmaz, amit a 329, plusz ezt). A `pubspec.yaml` `1.0.0+330`, a changelogbejegyzés a `lib/data/app_changelog.dart`-ban, a Play-szöveg a `docs/PLAY-KIADASI-JEGYZET.md`-ben.
  - **Miért 330 és nem 329:** a 329 **soha nem ment ki** (a tulajdonos épp feltöltötte volna, amikor ez a jelzés jött), ezért a `lastPublishedBuild` továbbra is **328**, és a Play-szöveg a 329+330 újdonságait fedi le egyben.
- **Ellenőrzések:** `flutter analyze` tiszta, `flutter test` zöld, `node tools/verify-native-admin-menu.mjs` **31/31**, `node tools/check-play-notes.mjs` zöld.

### „Nem törli az usert — a »Teszt acc« ugyanúgy ott van" — a Cloudinary-hiba MEGSZAKÍTOTTA a törlést (2026-09-19, **szerveroldali javítás: AAB NEM kell hozzá**)

- **A tulajdonos jelzése:** *„még a 328-as van fent de ez az admin user törlés nem akar menni a 'teszt acc' user ugyanúgy ott van"*. (Ez a 329-es menet 4. pontjának a folytatása — akkor a napló alapján még azt hittem, a törlés sikerült.)
- **Amit ÉLŐBEN mértem (Firestore-olvasás a Firebase CLI saját tokenjével, írás nélkül):**
  1. `community_profiles/<uid>` — **LÉTEZIK**, `displayName = "Teszt acc"`, `profileImagePublicId` **van**, utolsó módosítás `2026-09-17T20:49:56Z`;
  2. `deleted_user_ids/<uid>` — **létezik** (`2026-09-19T10:38:27Z`), tehát a törlés **el is indult**;
  3. `account_deletions/<uid>` — `status: pending`, **`lastError: cloudinary-delete-temporary-failure:401`**;
  4. a `deleteCommunityUser` naplója ugyanakkor **HTTP 200** + `community_user_core_deleted_cleanup_pending` volt.
- **A gyökér (egy nem védett `await`):** a `deleteUserReferences()` a `destroyCloudinaryAsset()` hívást **try/catch nélkül** hívta, a Cloudinary pedig a rossz API-secret miatt **401**-et adott, amire az **dob** (`cloudinary-delete-temporary-failure:401`). A kivétel kifutott a `deleteUserReferences`-ből, a hívó a `catch` ágban **ellenőrzés nélkül** visszatért `cleanup_pending`-gel — **még a `community_profiles/<uid>` törlése ELŐTT** (`await db.recursiveDelete(...)`, ami a függvény **végén** van). Ezért az Auth-fiók eltűnt, a **profil viszont a helyén maradt**, és a felhasználó továbbra is látszott az admin listában.
  - **A korábbi tévedésem, javítva:** a `profileStillExists` ellenőrzés **csak a sikeres ágon** fut le; a `cleanup_pending` hibaága **soha** nem ellenőrizte, hogy a profil eltűnt-e. A naplóbeli HTTP 200 tehát **nem** bizonyította a törlést.
  - **A hiba hatóköre (mérve):** **49** `account_deletions` rekord ragadt `pending` állapotban `2026-09-11` óta, mind ugyanezért — vagyis a törölt felhasználók profilja hetek óta a helyén maradhatott.
- **A Cloudinary titok külön probléma (mérve):** a `GET /v1_1/fjxo93em/ping` a jelenlegi kulccsal **`401 {"error":{"message":"api_secret mismatch"}}`** — vagyis a Secret Managerben lévő `CLOUDINARY_API_SECRET` **nem ehhez a kulcshoz tartozik** (a kulcs rotálódott, vagy a titok másolása hibás). **Ez a tulajdonos dolga** (Cloudinary Console → Settings → API Keys). A képfeltöltés **nem** tört el, mert az app **aláírás nélküli upload preset**-tel tölt fel (`Hun_hs_Mobile`), ehhez nem kell a secret.
- **A javítás (mind szerveroldali, `functions/index.js`):**
  1. **A kép-törlés hibája nem állíthatja meg a felhasználó-törlést:** a destroy-hívás `try/catch`-be került; a sikertelen `public_id`-k a `failedCloudinaryAssets` listába mennek, a napló pedig `account_deletion_cloudinary_destroy_failed` eseményt ír a **hibakóddal** (a diagnosztika nélkül a napló csak annyit mondott, hogy „fuggoben").
  2. **A hibaág nem hazudhat siker helyett:** ha a takarítás mégis megszakad, a kód **megnézi, hogy a profil a helyen maradt-e**; ha igen, `community_user_profile_cleanup_failed` + `throw HttpsError('aborted', 'A fiók törlése nem fejeződött be, próbáld újra.')` — az app (329) pontosan ezt a szöveget írja ki.
  3. **A maradék kép nem vész el:** a `pendingCloudinaryAssets` + `cloudinaryListPending` mezők a `account_deletions` rekordba kerülnek (kliens innen **nem** olvashat — nincs rájuk szabály, tehát tiltott).
  4. **A 15 percenkénti újrapróba „olcsó útja":** ha a profil **már nincs meg**, csak a képek maradtak, akkor a `retryCloudinaryAssetCleanup()` **csak a Cloudinaryval** foglalkozik (1 HTTP hívás), nem futtatja újra a teljes `collectionGroup`-takarítást. Korábban a `if (cleanup.cloudinaryListPending) continue;` miatt **50 rekord** teljes takarítása futott 15 percenként — ez indokolatlan terhelés volt. Amint a Cloudinary újra válaszol, a maradék képek **maguktól** törlődnek, és a rekord `completed` lesz.
- **Bizonyítás:** új `functions/account-deletion.test.cjs` (**5/5**) valódi Firestore-emulátoron, a **valódi** `__deleteUserReferencesForTests`/`__retryCloudinaryAssetCleanupForTests` függvényekkel, csak a `fetch`-et helyettesítve. A lényeg: **401-es Cloudinary mellett is eltűnik** a profil, a `public_profiles`, a `private_user_data`, a `community_bans`, az értesítés, a chat-poszt és a kapcsolat; a maradék képek pedig listázva jönnek vissza.
  - **A mutációs bizonyíték:** a javítás előtti viselkedést (védtelen `await destroyCloudinaryAsset`) visszaállítva a teszt **elhasal** (`a profil nem tunt el`), a javított kódon **5/5**.
  - **Egy régi forrás-lintet is frissítettem:** a `security-permissions.test.cjs` az „Auth is already gone" **kommentre** illeszkedett — ez a mondat a javítással eltűnt. Helyette mostantól a **viselkedést** kéri számon (`profileRemains`, `community_user_profile_cleanup_failed`, `cloudinaryDestroyFailed`, `onlyCloudinaryLeft`).
- **Élesítve:** `npx firebase deploy --only functions:deleteCommunityUser,functions:cleanupIncompleteAccounts` → **Deploy complete!** A 15 percenkénti takarítás a következő futásánál **magától** befejezi a félbemaradt törléseket (a „Teszt acc" is eltűnik), és a 49 elakadt rekord is lezárul.
- **A Cloudinary-titok gyökere megvan (2026-09-19, mérve):** a Secret Managerben tárolt `CLOUDINARY_API_SECRET` **egyetlen karakterben** tért el a helyestől: a 17. helyen **kis `l`** volt **nagy `I`** helyett — a Cloudinary konzol betűtípusában ez a kettő **egyformán néz ki**, ezért a szemmel történő bemásolás hibázott. Ezt nem tippeltem: a `/ping` „api_secret mismatch" és az aláírt feltöltés „Invalid Signature" válasza után a **szemmel összekeverhető karakterek** (0/O/Q, 1/l/I, 2/Z, 5/S) variánsait próbáltam ki — a **18. variáns** adott 200-at. A javított secret a **2-es verzió**, **élőben igazolva**: `/ping` **200**, a képek listája **200**, az aláírt feltöltés (fájl nélkül) **400** = a hitelesítés rendben.
  - **Örökérvényű tanulság:** **titkot soha ne olvassunk be szemre** — a Cloudinary konzol „API environment variable" sorát kell kimásolni (vágólapra, nem kézzel), mert az `l`/`I` és a `0`/`O` összetéveszthető.
- **A javítás ÉLŐ eredménye (mérve, 2026-09-19 11:21 UTC):** a `cleanupIncompleteAccounts` azonnali futtatása után a **„Teszt acc" profil ELTŰNT** (`community_profiles` 22 → **21**, a `public_profiles` is), és a **49 félbemaradt törlésből 48 `completed`** lett.
  - **Egy kép maradt** (`huhs_users/<uid>/em1somtvrywtfbjxxbvv`): a törlés **HTTP 403**-at kapott — vagyis a hitelesítés már **jó** (nem 401), de a `huhs-user-cleanup` kulcs szerepe **„Media Library User"**, ami nem enged törölni.
- **A szerep megoldása és a VÉGSŐ, mérve igazolt eredmény (2026-09-19 11:37 UTC):** a Cloudinary „Assign Roles" ablakában **nincs** „Media Library Admin" — csak **„Master Admin”** és **„Media Library User”** van. A tulajdonos a kulcsot **Master Admin**-ra állította, és ezzel a lánc lezárult:
  - a törlési rekord `pending` → **`completed`** (`completedAt: 11:37:12`), a `pendingCloudinaryAssets` eltűnt;
  - a Cloudinaryn a törölt felhasználóhoz tartozó képek száma **1 → 0** (`/resources/image/upload?prefix=huhs_users/<uid>/` → `resources: []`);
  - **mind az 49 félbemaradt törlés `completed`** (0 függőben), a `community_profiles` száma **22 → 21**, a „Teszt acc” **nincs** (a `public_profiles` sora is törölve).
  - **Tanulság:** a 401 a titok elgépelése volt, a **403 viszont valódi jogosultsági hiba** — a kettőt a HTTP-státusz különbözteti meg, ezért kellett a diagnosztika a `cloudinary.js`-be.
- **Amit a tulajdonosnak kell tennie:** **semmit** — se az appban, se a Cloudinaryn. (A kulcs szerepe már Master Admin, a titok a 2-es verzió, a takarítás lezárt.)
- **Ellenőrzések:** `functions/rules.test.cjs` **18/18**, `functions/account-deletion.test.cjs` **6/6**, `functions/prize-draw.test.cjs` **24/24**, `functions/security-permissions.test.cjs` **22/22**, `node --check functions/index.js` tiszta.
  - **Ismert, NEM az én hibám:** a `functions/registration.integration.test.cjs` **5/11**-et ad (`401 UNAUTHENTICATED` a függvény-emulátorban) — ezt **visszamértem a javítás előtti kódra is**, ugyanaz az eredmény, tehát **előzőleg is így volt** (környezeti/Auth-emulátor ok, nem regresszió).

### Öt tulajdonosi jelzés egy menetben — chat-lapozás, azonnali állapot, admin user-törlés, natív admin (2026-09-19, AAB 329 + plugin 2.5.6)

A tulajdonos öt pontot adott egyszerre, majd: *„csináld meg ezeket"*. Mindegyikhez **mért gyökér** és **bizonyított javítás** tartozik.

#### 1–2. „Kvíznél/Kérdőívnél elsőre kicsit sokára tölti be, hogy már játszottam/kitöltöttem"
- **A gyökér:** az állapot csak egy **három lépcsős út** végén derül ki (app → Cloud Function → WordPress), első hívásnál a függvény hidegen is indul; a felület pedig **szándékosan** nem mutat válaszlehetőségeket, amíg a szerver nem mondja ki, hogy nem szavaztál/játszottál. Ezért a várakozás **látszott**.
- **A javítás — helyi emlékezet + háttérellenőrzés:** új `lib/services/vote_memory.dart` (`VoteMemory`) megjegyzi a legutóbbi ismert állapotot. A `hasVotedProvider` / `prizePlayProvider` **azonnal** a mentett értéket adja, majd a háttérben megkérdezi a szervert; ha az azt mondja, mégsem szavaztál/játszottál, a jelzést törli és **`ref.invalidateSelf()`**-fel visszavált a szavazólapra.
  - **Két szándékos szabály:** (1) **csak `true`-t** („már megtörtént") mentünk — hamis állapotot soha, mert az elrejtené a szavazólapot; (2) a kulcs **tartalmazza a UID-t** (`huhs.voted.poll.<uid>.<pollId>`), ezért más fiók bejelentkezése nem örökli az emléket.
  - A játéknál a **`correct` és a választott index is** mentődik, különben a visszatérő játékos egy pillanatra **rossz ítéletet** látna („helyes volt / nem talált").
  - **Új szűk provider: `currentUidProvider`** (`community_provider.dart`) — ez adja a UID-t a kulcshoz, és **tesztben Firebase nélkül felülírható**.
  - **Riverpod-csapda (2.6.1):** a `Ref.mounted` **nem létezik** ebben a verzióban, ezért a háttérfeladat a provider építésekor regisztrált `ref.onDispose` flaggel ellenőrzi, hogy szabad-e még újraszámolni. Enélkül a lezárásnál *„The provider … was disposed during loading state"* hibát kapunk.
- **Bizonyítás:** `test/providers/poll_provider_test.dart` **+4** és `prize_provider_test.dart` **+3**. A lényeg mérése: a szerver kérése egy **soha be nem fejeződő `Completer`** (`statusGate`), a provider mégis **2 másodperc alatt** válaszol — vagyis tényleg nem vár rá.

#### 3. Chat: „legyen valami limit … lefele scrollozáskor töltsön be"
- **A mért kiindulás:** a chat **már nem** tölti le az összeset — élőben csak a **legfrissebb 60** üzenetet figyeli (`watchPosts()`). Az 5000 üzenet tehát **nem** lassítja. A valódi hiányosság: a 60-nál régebbit **nem lehetett elérni**.
- **A javítás:** új `lib/services/chat_paging.dart` (**tiszta logika**) + `CommunityService.loadOlderPosts({before, limit = 30})` + a `LiveFeedScreen` görgetésre tölt.
  - **A chat a legfrissebbel kezdődik**, ezért **lefelé** görgetve haladunk vissza az időben — a tulajdonos megfogalmazása pontosan erre illik.
  - **A kitűzött (pinned) üzenet kora nem lehet a lapozás határa** (`oldestBoundary`): ha egy hete kitűzött üzenetet beszámítanánk, a következő lap **átugraná** a közte lévő beszélgetést.
  - **Duplikáció-szűrés** (`newOlderPosts`): se az élő ablakkal, se a már betöltött lapokkal nem ismétlődik.
  - A lap alján **„Régebbi üzenetek betöltése"** gomb (görgetés nélkül is működik), a végén **„Ez a beszélgetés eleje."**, és mély görgetésnél egy **„a legfrissebbre"** gomb. A lehúzásos frissítés (`_refreshChat`) **eldobja** a betöltött régebbi lapokat.
- **Bizonyítás:** `test/services/chat_paging_test.dart` **10** + `test/widgets/chat_paging_test.dart` **2** — a második **valódi görgetéssel** méri, hogy a régebbi üzenet **megjelenik**, és hogy elfogyás után **nem kér újra**.

#### 4. „Adminként nem törli az usert, googleval regelt" — a törlés LEFUTOTT, a felhasználó viszont visszajött
- **Élő mérés (függvénynapló, 06:39):** a `deleteCommunityUser` **kétszer is lefutott**, mindkétszer **HTTP 200**-at adott (`cleanup_pending`), és a kód a visszatérés előtt **ellenőrzi**, hogy az Auth-fiók és a `community_profiles` sor is eltűnt. ~~Tehát a törlés sikeres volt; csak a Cloudinary-képek takarítása maradt függőben.~~ **⚠️ EZT A KÖVETKEZTETÉST 2026-09-19-ÉN MEGCÁFOLTA A MÉRÉS:** ez az ellenőrzés **csak a sikeres ágon** fut le; a `cleanup_pending` **hibaága** (a `deleteUserReferences` dobott) **ellenőrzés nélkül** tért vissza, és a `community_profiles/<uid>` **a helyén maradt**. A részleteket lásd a legfelső szakaszban („Nem törli az usert"). A naplóbeli HTTP 200 tehát **nem** bizonyította a törlést.
- **A valódi hiba (kettős):**
  1. **A Google-fiókkal regisztrált felhasználó Auth-fiókja újra létrejön** ugyanazzal a UID-dal, amikor újra bejelentkezik. Az app viszont **sehol nem nézte** a szerveroldali `deleted_user_ids` jelzőt, ezért a visszatérő törölt fiók **érthetetlen hibákba** futott (minden `isRegistered()` szabály tiltja) ahelyett, hogy megmondtuk volna neki: *ez a fiók törölve lett*.
  2. **Néma no-op:** az appon belüli WP-admin „Felhasználók" fülén a törlés `id == 0` esetén **üzenet nélkül visszatért** — pontosan ez kelti a „nem törli" érzést.
- **A javítás:**
  - **`firestore.rules`:** a felhasználó a **saját** `deleted_user_ids/<uid>` sorát olvashatja (`allow get`), írni senki. **FIGYELEM, csapda:** itt **szándékosan nem** `isRegistered()` áll, mert az maga is nézi a `deleted_user_ids`-et — így pont a törölt felhasználótól tagadná meg a választ.
  - **`CommunityService.isAccountMarkedDeleted(uid)`** + bekötve a **`refreshCurrentSession()`**-be: ha a jelző ott van, `{'active': false, 'deleted': true}`-t ad, amire a `main.dart` **már meglévő** útja kijelentkeztet és kiírja: *„A fiókodat törölték. Kijelentkeztettünk."* Hálózati hiba esetén **false** (átmeneti hiba nem zárhat ki senkit).
  - **`functions/cloudinary.js`:** a hiba mostantól viszi a **HTTP-státuszt és a Cloudinary üzenetét** is (`cloudinary-list-temporary-failure:429`), különben a naplóból nem derül ki, hogy 401/429/alak volt-e a baj.
  - **`wordpress_admin_screen._deleteUser`:** `id == 0` esetén **érthető üzenet** (nincs WordPress-azonosító; az app-fiókok a Közösségi adminisztrációban törölhetők).
  - **`community_screen`:** a törlés után **szerveroldali ellenőrzés** (nem cache-ből), és a válasz egyértelmű: „törölve" / „nem fejeződött be, próbáld újra".
- **Bizonyítás:** `functions/rules.test.cjs` **14 → 18** + `test/services/deleted_account_guard_test.dart` (**5**, kézzel írt Firestore-hasznossal, új csomag nélkül).

#### 5. „Natív HUHS adminba bekerülhetnének az új dolgok, működően (értds: az appba)"
- **Amit találtam:** az appon belüli admin API (`/huhs/v1/admin?action=…`) **nem** tudott a nyereményjátékról — az csak a WordPress adminjában volt átlátható, holott az app a játékot már mutatta a felhasználóknak.
- **A javítás:**
  - **Plugin (`includes/api-admin.php`, 2.5.6):** új `prize_games` (játéklista) és `prize_results` (állapot, nyeremény, **helyes válasz indexe**, válaszonként `count`/`percent`, résztvevők). `prizeId` nélkül a **nyitott → friss nyertes → legfrissebb** sorrendben választ.
    - **A helyes válasz itt kiadható** (a nyilvános `/prize/active`-nál nem): ez a végpont `manage_options` mögött van, és az admin a saját játékát ellenőrzi.
    - **UID és hash viszont itt sem megy ki** — ezt a `verify-prize-draw.mjs` forrás-linttel kéri számon.
  - **Kliens:** új `lib/screens/community/prize_admin_screen.dart` (legördülő a játékokból, állapot + nyeremény + megjelenítési napok, válaszmegoszlás a **helyes válasz jelölésével**, résztvevő-lista ✔/✖/🏆 jelekkel), és a nyereményjáték képernyőn egy **admin-only** „Résztvevők (admin)" gomb (`Key('prize-admin-open')`).
    - A hálózat itt is **szűk providereken** megy (`prizeAdminRequestProvider`, `prizeAdminCacheClearProvider`) — ezért a képenyő **Firebase nélkül tesztelhető**.
- **Bizonyítás:** `tools/verify-prize-draw.mjs` **44 → 47** (a hibás változaton — UID kiadása a résztvevő-sorokban — **elhasal**) + `test/widgets/prize_admin_screen_test.dart` (**4**).

#### Csomagok és ellenőrzések
- **AAB:** `build/HUHS-v1.0.0+329-release.aab` (versionCode **329**) — `pubspec.yaml` `1.0.0+329`, és a `lib/data/app_changelog.dart`-ba bekerült a 329 bejegyzés (a `test/data/app_changelog_test.dart` **megköveteli**).
- **Plugin:** `build/huhs-mobile-api-2.5.6.zip` — 44 fájl, 139,0 KB, SHA-256 `492CC69DF5115AE5EBCB4D33AE6F8C77B1268468508A4FB2CBD2782F8B28FF9E`.
- **Élesítve:** `firestore:rules` (a törölt-fiók olvasásához **kötelező**) és `functions` (a `cloudinary.js` diagnosztika miatt).
- **Ellenőrzések:** `flutter analyze` tiszta, `flutter test` **273/273** (a menet elején 245 volt — **+28 új teszt**), `functions/rules.test.cjs` **18/18**, 43/43 PHP parse, `check-plugin-encoding.mjs` **44/44**, `verify-faq-content.mjs` **43/43**, `verify-faq-retire.php` **16/16**, `check-wp-admin-menu.mjs` **8/8**, `check-wp-meta-json.mjs` zöld, `verify-prize-draw.mjs` **47/47**, `verify-poll-status.mjs` **25/25**, `check-play-notes.mjs` zöld.

### A „További hírek" sor egységes kártyaformát kapott (2026-09-18, AAB 328)

- **A tulajdonos jelzése:** *„a TOVÁBBI hírek gomb a főoldalon lehetne olyan mint a kérdőív meg a nyereményjáték kártya, egységesen"*.
- **A gyökér:** a „További hírek" egy `OutlinedButton.icon` volt (`SizedBox(width: double.infinity)`-tel), tehát **más volt a formája**, mint a főoldali hero-soroknak (kérdőív, nyereményjáték, éves szavazás) — azok a `HomeActionCard`-ot használják. Ráadásul a `Column`-ban nem volt `crossAxisAlignment: stretch`, ezért a sor **nem is töltötte ki** a teljes szélességet.
- **A javítás:** a sor mostantól **`HomeActionCard`** (`key: Key('more-news')`, `eyebrow: 'HÍREK'`, `label: 'További hírek'`, `icon: Icons.arrow_forward_rounded`), és a `Column` megkapta a `crossAxisAlignment: CrossAxisAlignment.stretch`-et. Így **pontosan ugyanaz a formátum és szélesség**, mint a többi hero-soron — a közös komponens miatt nem tud elcsúszni tőlük.
- **Miért `crossAxisAlignment: stretch` kellett:** a `HomeActionCard` egy `Padding`-be csomagolt `Semantics`/`Material`/`InkWell`, ami **a szülőtől kapott szélességet** tölti ki. `stretch` nélkül a `Column` a gyerekek saját (tartalomhoz igazodó) szélességét használja.
- **Új teszt: `test/widgets/home_more_news_test.dart` (4 teszt)** — a **teljes főoldalt** rendereli (provider-felülírásokkal, hálózat nélkül), és méri, hogy a sor **bal széle és szélessége egyezik** a hírsáv `Rect`-jével; hogy megvan a `HÍREK` felirat és a nyíl (a közös formátum jele); hogy koppintásra meghívódik a `onShowMoreNews`; és hogy **hírek nélkül nincs sor**.
  - **Tanulság a jövőre:** a teszt-nézet legyen **valósághű** (1200 px / 3x = 400 logikai px). Az első futásom 1080 px-szel **11 pixeles túlcsordulást** jelzett a **fejléc-sorban** (`home_screen.dart:130`), ami **nem** a módosításom hibája volt, hanem a túl szűk nézeté — a valódi telefonon nem jelentkezik.
- **Ellenőrzések:** `flutter analyze` tiszta, `flutter test` **245/245**.
- **Csomag:** `build/HUHS-v1.0.0+328-release.aab` — tisztán kliensoldali, **a pluginhoz nem kell nyúlni**.

### A Play-kiadási jegyzet másolhatóan + kapu rá (2026-09-18, AAB 328)

- **A tulajdonos kérése:** *„add az utolsó aab-t + changelog másolhatónak, tételesen"*, majd *„röviden kéne a Playbe"* — vagyis legyen egy helyen, **kész és másolható** formában az, amit a Play Console-ra be kell illeszteni.
- **Az új dokumentum: `docs/PLAY-KIADASI-JEGYZET.md`** — tartalmazza
  1. a feltöltendő AAB **mért** adatait (fájl, versionName, versionCode, méret, SHA-256),
  2. a **Play Console blokkot** (```play-notes fenced blokk — ez másolható egyben),
  3. egy **tartalék blokkot arra az esetre, ha csak a 328 megy ki**,
  4. az **app Névjegyének tételes listáját build szerint** (328…323),
  5. a **plugin 2.5.5 kiadásjegyzékét**,
  6. a feltöltés előtti ellenőrzések sorrendjét.
- **A Play-szöveg RÖVID (a tulajdonos kérése: „röviden kéne a Playbe"):** az elsődleges blokk **3 sor, 136/500 karakter** — a Play a frissítés kártyáján úgyis rövidítve mutatja. A tételes lista nem vész el: **az app Névjegyében** van (3. pont), és a dokumentum **1b.** szakaszában a hosszabb (458/500) változat is ott marad, ha mégis bővebben kellene.
- **MIÉRT a teljes ugrás (322 → 328) a referencia:** a Playen a legutóbb publikált build a **322** (ezt a tulajdonos jelezte), a 323–328 pedig **egy csomagban** megy ki, ezért a tételes lista (és a hosszabb Play-változat) **mind a hatot** lefedi — így nem marad láthatatlan pont az, amit kifejezetten kért (chat/komment szerkesztés, értesítés-törlés, azonnali frissülés).
- **A tulajdonos MEGERŐSÍTETTE a kiindulást:** *„csak a 328 megy fel, az előtte lévőket nem tettem fel, 322 volt előtte"* — vagyis a 323–327 **soha nem került fel a Playre**, a 328 viszont **mindet tartalmazza**, ezért a **322 → 328 ugrás** a helyes jegyzet, és a `lastPublishedBuild: 322` érték **igazolt** (nem feltevés).
  - Emiatt a dokumentum **2. blokkja** („csak a 328 változásai") **csapda volt**: a címénél fogva épp erre az esetre tűnt valónak, pedig az csak akkor való, ha a 323–327 már kint van. **Átneveztem és figyelmeztetést tettem rá** („Most NE ezt használd!"), nehogy a tulajdonos a rosszat másolja be — azzal ugyanis a hat build javításainak a nagy része láthatatlan maradt volna.
- **A Play- és a Névjegy-szöveg viszonya:** a Play-blokk **összevont, felhasználói összefoglaló**, az app Névjegyében (`lib/data/app_changelog.dart`) viszont **build szerinti, teljes** lista van. Ez szándékos: a Play nyelvenként **500 karakterre** korlátoz _(a Play Console súgója szerint; a korlátot a gyakorlat is visszaigazolja)_, a Névjegy viszont nem korlátozott.
- **Új kapu: `tools/check-play-notes.mjs`** — ez a hatodik olyan ellenőrzés, ami **magát a kiadási szöveget** méri, nem a kódot:
  1. minden ```play-notes blokk **≤ 500 karakter** (mért érték: **136/500** a rövid fő blokké, **458/500** a hosszabbé, **217/500** a „csak 328" tartaléké);
  2. **biztonsági margó**: 480 karakter felett **jelez**, mert egy későbbi szövegmódosítás különben csendben átbillentené a feltöltést (a fő blokk **458/480**);
  3. a dokumentum fejlécében lévő build/verzió **egyezik a `pubspec.yaml`-lel** (1.0.0+328);
  4. **(lastPublishedBuild, currentBuild] minden buildjéhez van tételes bejegyzés** — így nem lehet egy javítás „lemaradni";
  5. az **AAB létezik, és a dokumentumban szereplő SHA-256 tényleg az** (a fájlt valóban beolvassa és hashel: `C8D3BEDB…B660EB9`);
  6. nincs `TODO`/`XXX`/`FIXME` a szövegben.
  - **Mind a négy hibamód bizonyítottan elhasal:** túl hosszú blokk (637/500), kihagyott build (327), hamis SHA-256, és a pubspec-től eltérő build — mindegyik **HIBA**, a valódi dokumentumon **MINDEN ELLENŐRZÉS RENDBEN**.
  - **Saját hibám, amit érdemes megjegyezni:** a hibamódokat először PowerShell-egysorosokkal próbáltam generálni, és a magyar idézőjelek/ékezetek a parancsstringben **megsérültek** — a „túl hosszú" eset ezért **hamis zöldet** adott. A mutációkat végül **Node-szkripttel** (UTF-8-biztosan) generáltam, és akkor mind a négy elhasalt. Tanulság: **magyar szöveges mutációt ne parancssori literálból** állíts elő.
- **AAB (mérve):** `build/HUHS-v1.0.0+328-release.aab` — versionCode **328** (a merge-elt release manifestből visszaolvasva), versionName `1.0.0`, 79,22 MB, SHA-256 `C8D3BEDBFE7D24C8B6F0ECB004D23AA07E986C81332BF1A934D38B681B660EB9`.
- **Ellenőrzések:** `check-play-notes.mjs` **MINDEN ELLENŐRZÉS RENDBEN**, `flutter test` **245/245** (ebből `test/data/app_changelog_test.dart` a pubspec-egyezést kényszeríti ki — a 328-hoz van bejegyzés), `flutter analyze` tiszta.

### A GYIK (Segítség) rendberakva — tárgyi hiba, duplikáció, zaj és hiányzó témák (2026-09-18, plugin **2.5.5**)

- **A tulajdonos jelzése:** *„nézzük meg a GYIK menüt is mert most elég gagyi, érthető normális funkció ismertető kell, nem pedig mindenféle Firebase meg semmi értelme duma, és csak az elérhető funkciókról segítség"*. Ez a korábban **ELHALASZTVA** jelölt feladat.
- **A GYIK a WordPressből jön** (`huhs_faq` bejegyzéstípus, `huhs_faq_category` taxonómia, `/wp-json/huhs/v1/faq` végpont), nem az app kódjából. **33 bejegyzés volt**, ezeket mértem át élőben.
- **A gyökerek (mind mérve):**
  1. **TÁRGYI HIBA:** a „Hogyan működnek az achievement pontok?" azt állította, hogy cikkkommentért *„naponta legfeljebb öt alkalom"* jár. A kódban a plafon **három** (`ARTICLE_COMMENT_DAILY_POINT_LIMIT = 3`). Aki elhiszi az ötöt, a negyedik komment után azt hiszi, elromlott az app.
  2. **DUPLIKÁCIÓ:** a „Hogyan törölhetem a profilomat?" **két** bejegyzésként szerepelt.
  3. **RENDSZERLEÍRÁS A SEGÍTSÉG HELYETT:** *„Ugyanaz az indítási kép egy telefonon két órán belül nem jelenik meg újra."*
  4. **ZAJ:** „Mire keres rá a hírek keresője?" (a kereső definíciója) és a külső oldalak jogi bekezdése.
  5. **HIÁNYZÓ TÉMÁK:** a **nyereményjátékról** és a **kérdőívről** egyetlen szó sem volt; az értesítések Aktív/Archivált füléről sem.
  6. **SORREND:** a régi `huhs_seed_v3_faq_once()` **minden** bejegyzésnek `menu_order = 100`-at adott, a játékoknak 95-öt, 16-nak pedig 0-t — ezért a lista **elején 16 kategórianélküli bejegyzés** keveredett összevissza, és csak utána jöttek a témakörök.
- **A megoldás: új `includes/faq-human.php`** (`huhs_seed_human_faq_once`, `HUHS_FAQ_CONTENT_VERSION = 5`):
  - **7 témakör** (`menu_order` tízes egységekkel: Első lépések 100, Közösség 200, Hírek és értesítések 300, Zene és kiadványok 400, Játékok 500, Szavazás és nyereményjáték 600, Segítség és adatvédelem 700), **31 kérdés**;
  - minden bejegyzés **slug szerint** kerül fel/frissül, ezért **újrafuttatva is ugyanazt adja**;
  - **tartalom-védelem:** ha a tulajdonos a WordPress adminban **kézzel átír egy szöveget**, a `_huhs_faq_human_edited` meta megvédi — a migráció onnantól **nem írja felül**, csak a besorolást igazítja;
  - **a nyugdíjazás szigorú: MINDEN kiadott GYIK-bejegyzés vázlatba kerül, amelynek a slugja nincs benne az új 31-es listában** (`huhs_faq_v4_retire_stale($keep_slugs)`) — **nem töröl, csak vázlatba tesz**, az adminban visszatalálható, a művelet **idempotens** (újrafuttatva ugyanaz marad), és minden érintett bejegyzést `error_log`-gal megnevez.
    - **Miért lett ilyen szigorú:** a 2.5.3-ban még csak **5 slug** volt a listán (duplikált fióktörlés, rendszerleíró indítási kép, kereső-definíció, jogi bekezdés, barátok-blokk), és **élő mérés** mutatta meg, hogy ez kevés: a `/faq` végpont **52 kiadott** bejegyzést adott vissza, benne **14 db `menu_order = 0`** maradékot (a régi, kategóriátlan bejegyzések) és **8** régi „App és közösség" bejegyzést, amelyek a lista elején keveredtek összevissza. A fehérlista-alapú nyugdíjazás ezt egy menetben rendezi;
    - **DE a tulajdonos keze munkája védett:** ha egy bejegyzést **kézzel írt vagy átírt** (`_huhs_faq_human_edited`), az **nem kerül vázlatba** — publikált marad, és `_huhs_faq_kept_by_hand` jelölést kap, a napló pedig név szerint felsorolja. A migráció dolga a **gépi szemét** eltakarítása, nem a tulajdonos szövegének eldobása;
  - **a „kézzel írt" jelölés mostantól az ÚJ bejegyzést is védi:** a marker `save_post_huhs_faq` hookon fut (a korábbi `post_updated` **csak módosításnál** indul el, új bejegyzésnél nem — ez a rés nyitva volt), és a migráció a `$GLOBALS['huhs_faq_v4_seeding']` jelzővel zárja ki a saját írásait, hogy azokat ne bélyegezze emberi szerkesztésnek;
  - a régi `huhs_seed_v3_faq_once()` **kiürítve** (csak a jelzőt állítja), különben visszahozta volna a hibás szöveget egy friss telepítésen.
- **AMIT A SZÖVEGBEN SZÁNDÉKOSAN NEM ÍRTAM:** technológia (Firebase, Firestore, cache), fájlformátum és bitráta. Helyette az számít, ami a felhasználót érinti („a kisebb minőségű MP3 egy rövid reklámmal ingyen nyílik meg").
- **Új, önmagát bizonyító ellenőrzés: `tools/verify-faq-content.mjs`** (**43/43**):
  - **A szöveget a VALÓS KÓDHOZ köti** — ez a lényeg: kiolvassa a `functions/index.js`-ből az `ARTICLE_COMMENT_DAILY_POINT_LIMIT` / `NEWS_LIKE_DAILY_POINT_LIMIT` értéket, és megköveteli, hogy a GYIK **ugyanazt** írja. Ugyanígy ellenőrzi a pontértékeket (profil 30 · szavazás 10 · esemény-értékelés 10 · meetup 5 · ajánlás 50 · hír kedvelés 2 · komment 1) — vagyis **a mostani hiba nem tud visszakúszni**;
  - tiltott szakkifejezések listája (a `gyorsítótár` **szándékosan kivétel**: a fióktörlésnél a felhasználónak fontos, hogy a helyi adatok és a mentett ideiglenes fájlok is törlődnek);
  - a terjengősséget a **folyó szövegen** méri (a `•`-s felsorolás kimarad), és a mérés előtt **feloldja a `\n` escape-et** — enélkül a nyers szöveg két karakternek számolja a sortörést, és 10-15 karakterrel többet mutat a valósnál (ezt a saját hibámat javítottam);
  - a migráció biztonsága: tartalom-védelem, verzióhoz kötés, vázlatba tétel (nem törlés), admin-jog.
  - **A 2.5.5-ben hat új ellenőrzés jött, mert két csendes hibát találtam:** (1) **elindul-e egyáltalán a migráció** — a konstans nagyobb kell legyen a 2.5.3-ban már alkalmazott **4**-nél (ez a hiba élesben ott volt!); (2) **megkíméli-e a kezzel írt szöveget** (`_huhs_faq_human_edited` + `continue;`); (3) naplózza-e a megtartottakat; (4) a migráció nem bélyegzi saját magát emberi szerkesztésnek (`$GLOBALS['huhs_faq_v4_seeding']`); (5) a marker a **`save_post_huhs_faq`** hookon fut, hogy az **új** bejegyzés is védett legyen; (6) a verziószám ismert.
  - **A detektorok bizonyítottan működnek — mindegyiket kimértem hibás változaton:** a hibás „naponta legfeljebb **öt** alkalommal" szöveg, a **gyenge nyugdíjazás** (5 slug), a **4-es verziójel**, a **kivétel kiiktatása**, a **`save_post` → `post_updated`** csere és a **seeding-jelző törlése** mind **elhasal** (42/43), a valódi forráson **43/43**.
- **Új, VISELKEDÉST bizonyító ellenőrzés: `tools/verify-faq-retire.php`** (**16/16**) — valódi PHP, WordPress nélkül: stubolt tárhelyen futtatja a **valódi** `huhs_faq_v4_retire_stale()`-t, és méri, hogy az új listához nem nyúl, a régit vázlatba teszi, a **kezzel írtat publikáltan hagyja**, a visszatérő tömbben külön szerepel a `retired` és a `kept`, és a **második futás idempotens**.
  - **Miért kellett ez a külön eszköz:** a `verify-faq-content.mjs` csak **forrásszöveget** néz, ezért egy „kiiktatom a feltételt" típusú hibát nem feltétlenül vesz észre. A PHP-harness a viselkedést méri — **kimértem:** a `continue;` elvételével **12/16**-ra esik és elhasal.
  - **Saját hibám, javítva:** a harness első változata a végén `{$checks}/{$checks}`-t írt ki, ezért **hiba esetén is „16/16 rendben"-t** mutatott volna — pontosan az a néma kapu, amit kergetünk. Mostantól `(checks - failures)/checks`, és a kilépési kód is 1.
- **Új kapu a kódolásra: `tools/check-plugin-encoding.mjs`** (**44/44**) — minden plugin-fájl **érvényes UTF-8** kell legyen. **Élő hiba fogta meg:** a `faq.php` docblockjában **négy ANSI/CP1250 bájt** volt (0x97 a „—", 0x84 a „„" helyén), ezért a fájl nem volt érvényes UTF-8 — a WordPress szerkesztője mojibake-et mutatott volna. A kapu a javítás előtt **elhasalt** (43/44, kiírta a bájtpozíciókat), a javítás után **44/44**.
- **Csomag:** `build/huhs-mobile-api-2.5.5.zip` — 44 bejegyzés, 138,0 KB, SHA-256 `06512149E638EFC41F168C839A021659B37D7A090990CBFA09242B3996CCE3D0`.
  - **A 2.5.4-es ZIP-et TÖRÖLTEM a `build/`-ből**, mert a benne lévő migráció a 4-es verziójel miatt **soha nem futott volna le** — nem akarom, hogy véletlenül az kerüljön fel. Helyette a **2.5.5** való.
- **ÉLŐ ÁLLAPOT (2026-09-18, mérve):** élesben a **2.5.3** van fent (`X-HUHS-Health: api=2.5.3`), és annak migrációja **már lefutott** — a `/faq?per_page=100` **52 kiadott** bejegyzést adott (a 31 új a helyes `menu_order`-ekkel 101/201/301/401/501/601/701…, plusz a **14 db `order=0`** és a **8** régi „App és közösség" maradék). A hibás „naponta legfeljebb öt" szöveg **már nincs benne**. **Pontosan ezért kellett az 5-es verzió:** a 2.5.3 ugyanezt a 4-est használta, tehát a 2.5.4-es csomag migrációja **némán visszatért volna**, és a 22 maradék a helyén maradt volna. A **2.5.5** ezt a 22 maradékot teszi vázlatba (a kezzel írtakat kivéve); a migráció akkor fut le, amikor a feltöltés után megnyitod a WordPress adminfelületet (admin_init + verziójelző). Utána a GYIK **7 témakörre bontva, 31 kérdéssel** jelenik meg az appban.
- **Ellenőrzések:** 43/43 PHP parse, `verify-faq-content.mjs` **43/43**, `verify-faq-retire.php` **16/16**, `check-plugin-encoding.mjs` **44/44**, `check-wp-admin-menu.mjs` **8/8**, `check-wp-meta-json.mjs` zöld, `verify-prize-draw.mjs` **44/44**, `verify-poll-status.mjs` **25/25**.
  - **Közben egy néma kaput is megjavítottam:** a `tools/check-wp-meta-json.mjs` a **beégetett `.tmp-api-24114`** munkafát kereste, ami a worktree átnevezése (`.tmp-api-24115`) óta **nem létezik**, ezért a szkript `ENOENT`-tel elhasalt — vagyis az a kapu **csendben használhatatlan volt**. Mostantól kézi útvonal nélkül **automatikusan a legfrissebb `.tmp-api-…` munkafa** `huhs-mobile-api` mappáját választja, és ha egyáltalán nincs ilyen, **érthető üzenettel áll meg**. Mindkét mód (automatikus és kézi) ellenőrizve.
- **A szöveg forrása és indoklása:** `docs/GYIK-JAVASLAT.md` — ha ott változtatsz, a `faq-human.php`-t is át kell írni, és a verziószámot emelni (`HUHS_FAQ_CONTENT_VERSION`).

### A Névjegy alatt kiadási jegyzet (changelog) — a korábban elhalasztott feladat kész (2026-09-18, AAB 327)

- **A tulajdonos kérése:** *„csináld meg azt is hogy az appról részbe legyen changelog is"* — ez a korábban **ELHALASZTVA** jelölt feladat, ami most **elkészült**. A `docs/RELEASE_CHANGELOG_CHECKLIST.md` szerint ugyanazt a magyar changelogot kell vezetni a Play Console-on, az app Névjegyén és a plugin kiadásjegyzékén.
- **Az adat: `lib/data/app_changelog.dart`** — `AppReleaseNotes { version, build, changes }`, a lista a **legfrissebbel elöl**. A `build` a **verziókód** (326, 325, …), mert az azonosítja pontosan a kiadást.
- **Miért a buildszám és nem a verziószám:** a `version` (`1.0.0`) minden kiadásnál ugyanaz, csak a verziókód nő. Ha a verziónevet használnánk kulcsként, a changelog nem tudná megkülönböztetni a kiadásokat.
- **A képernyő (`lib/screens/more/about_screen.dart`):** a verzió továbbra is a `package_info_plus`-ból jön (ezért nem tud elavulni), a **„Újdonságok"** szekcióban az aktuális build bejegyzése **kiemelt kártyán** van „Ez a verzió" jelvénnyel, alatta a **„Korábbi kiadások"** halványabban. Ismeretlen buildnél (friss build, amihez még nincs bejegyzés) kiírja, hogy ehhez még nincs jegyzet — nem hazudik és nem omlik össze.
  - **A `PackageInfo` mostantól opcionális paraméter** (`AboutScreen({this.packageInfo})`): élesben a `PackageInfo.fromPlatform()` fut, a widget-teszt viszont beadhatja az adatot, így nem kell platformcsatorna. Ez a tesztelhetőség egyetlen oka.
- **A fegyelem kikényszerítése — ez a lényeg:** a `test/data/app_changelog_test.dart` **kiolvassa a `pubspec.yaml` verzióját**, és megköveteli, hogy **legyen hozzá changelog bejegyzés**, valamint hogy az **első** bejegyzés az aktuális build legyen. Enélkül a következő kiadásnál a felhasználó üres „Újdonságok" részt látna — ez a hiba pedig pont a frissítés után tűnik fel.
  - **A detektor bizonyítottan működik:** a `pubspec.yaml`-t ideiglenesen `1.0.0+327`-re emeltem úgy, hogy a changelog még 326-ig tartott, és a teszt **elhasalt** ezzel: *„a pubspec verziója 1.0.0+327, de ehhez nincs changelog bejegyzés"*. Utána visszaállítottam.
- **A jelenlegi tartalom (visszamenőleg is):** **326** (chat/komment szerkesztés), **325** (értesítés-törlés fülre szűkítve), **324** (nyertes és kérdőív azonnali frissülése), **323** (kérdőív-összesítő javítás, kép mező törlése), **322** (nyereményjáték + hero-szélesség + admin-eredmények), **321** (szavazat-állapot nem ragad be), **320** (Hamarosan/PRESAVE, előzetes lejátszó, kérdőív kártya), **319** (kérdőív a főoldalon, saját képernyő). **327** = maga a changelog.
- **Új tesztek:** `test/data/app_changelog_test.dart` (8) — pubspec-egyezés, csökkenő buildszám, nincs duplikáció, aktuális/ismeretlen build, nem üres pontok, nincs benne `- ` vagy `TODO`. `test/widgets/about_changelog_test.dart` (5) — a changelog látszik verziószámmal, az aktuális kiadás **feljebb** van, mint a „Korábbi kiadások" fejléc, **régi buildnél a saját kiadás** van kiemelve (nem a legfrissebb), ismeretlen buildnél jelzés, és a Verzió/Weboldal/Kapcsolat adatok megmaradtak.
- **Ellenőrzések:** `flutter analyze` tiszta, `flutter test` **241/241**.
- **Csomag:** `build/HUHS-v1.0.0+327-release.aab`.
- **FONTOS A JÖVŐRE:** **új kiadásnál a `lib/data/app_changelog.dart`-ba is fel kell venni a bejegyzést**, különben a `test/data/app_changelog_test.dart` elhasal — ez szándékos, ez a védelem.

### Chat- és cikk-hozzászólás szerkesztése — a szerző a sajátját, admin bárkiét (2026-09-18, AAB 326 + Firebase)

- **A tulajdonos kérése:** *„+1 javítás, kiegészítés a chaten a felhasználó tudja szerkeszteni a saját üzenetét, ugyanezt a cikkek alatti kommenteknél is. Admin természetesen mindenkiét + admin törölni is tudjon"*.
- **A kiindulás (chat):** a `CommunityService.updatePostText()` **már létezett**, de **csak adminnak** engedte (`if (!isAdmin) throw …`), és a `CommunityScreen` menüjében is csak a `canManagePosts == isAdmin` esetén jelent meg a „Szerkesztés". Vagyis a funkció megvolt, csak épp a felhasználó nem érhette el.
- **A kiindulás (cikk-kommentek):** a `articleComments` callable-nek **nem volt** `edit` művelete — csak `list`, `create`, `delete`, `report`.
- **A jogosultsági modell, egységesen mindkét helyen:**
  - **szerkesztés** — a szerző a sajátját, admin/moderátor **bárkiét**;
  - **törlés** — **csak admin** (a szerző a sajátját sem törölheti: ez moderációs jog);
  - **rögzítés (chat)** — csak admin.
- **Chat — a valódi védelem a Firestore-szabályban van (`firestore.rules`):**
  - **új** `allow update`: `isRegistered() && request.auth.uid == resource.data.authorId && diff().affectedKeys().hasOnly(['text','editedAt']) && text 1–2000 karakter`. Ez **szándékosan szűk**: a szerző nem tud más nevében írni (`authorId`), üzenetet rögzíteni (`pinned`) vagy reakciót hamisítani (`reactions`/`reactionBy`) — ezek külön admin-szabályok maradnak.
  - `editedAt` bekerült a **create** `hasOnly([...])` listájába is, hogy konzisztens legyen (a szűkítés nem gyengül: a lista csak bővült).
  - `allow delete: if isAdmin()` **változatlan** — a szerző nem törölhet.
  - A reakciók amúgy is Cloud Functionből (`toggleChatReaction`) mennek, ami Admin SDK-val ír, ezért a szabály szűkítése ott nem okoz regressziót.
- **Chat — kliens:** `updatePostText()` mostantól `authorId` paramétert kap (a hívó már ismeri a bejegyzést, így nincs plusz olvasás), és nem-admin esetén megköveteli, hogy az egyezzen a bejelentkezett UID-dal. A `CommunityScreen` a `canManagePosts` helyett **három külön jogosultságot** számol (`canEditPost`, `canDeletePost`, `canPinPost`), ezért a menü a helyes pontokat kínálja. A `CommunityPost` modell új `editedAt` mezőt kapott, és a kártya a `createdAt` mellett **„szerkesztve"** jelzést ír ki.
- **Cikk-kommentek — szerver:** új `edit` ág a `articleComments` callable-ben: `db.runTransaction`, `authorId === uid || moderator` ellenőrzés, 1–2000 karakter, `tx.update(ref, {text, editedAt})`; a `list` válasz mostantól `editedAt`-et is ad (0 = még nem szerkesztették).
- **Cikk-kommentek — kliens:** a `ArticleComments` menü új **„Szerkesztés"** pontot kapott (szerző vagy moderátor), `_edit()` dialógussal, és a szöveg alatt „szerkesztve" jelzés. A `onSelected` `switch`-re váltott, mert három külön művelet van.
- **Tesztelés:**
  - `functions/article-comments.test.cjs` **5 → 10**: a szerző szerkesztheti a sajátját (trimmelve tárolva) és `editedAt > 0` jön vissza; admin **és** moderátor is szerkesztheti másét; **más nem** szerkesztheti (a szöveg változatlan marad); a hossz-ellenőrzés ugyanaz, mint létrehozásnál; nem létező hozzászólás → `not-found`. A fixture `runTransaction`-jét bővíteni kellett `update`-tel.
  - `functions/rules.test.cjs` **8 → 14**: emulátoron, a valódi szabállyal mérve — a szerző szerkesztheti a sajátját; **másét nem**; csak a `text`/`editedAt` módosítható (a `authorName`/`pinned`/`reactions` írása **elutasítva**); üres és 2000+ karakteres szöveg elutasítva; a szerző **nem törölheti** a sajátját; az admin bárkiét szerkesztheti **és törölheti**.
  - **Saját hibám, javítva:** az első „nem törölheti" tesztem valójában csak az üres szöveget mérte (nem a törlést). Kettébontottam, és a törlést igazi `deleteDoc`-kal mérem.
- **Élesítve:** `firebase deploy --only functions:articleComments,firestore:rules` — **a szabályok élesítése nélkül a szerkesztés a klienseknél elutasításra futna**, ezért ez a lépés kötelező volt.
- **Ellenőrzések:** `flutter analyze` tiszta, `flutter test` **228/228**, `functions/article-comments.test.cjs` **10/10**, `functions/rules.test.cjs` **14/14**.
- **Csomag:** `build/HUHS-v1.0.0+326-release.aab`.

### „Összes törlése" az értesítéseknél: az Aktív fül az ARCHIVÁLTAT is törölte (2026-09-18, AAB 325)

- **A tulajdonos jelzése:** *„Notifyt lehet archiválni és átrakja az archiváltba — de ha az aktív fülön nyomok egy összes törlését, töröl mindent még az archiváltat is, ezt külön kéne választani: aktívban az aktívat törölje, archivban az archiváltakat"*.
- **A gyökér (egy hiányzó szűrés):** a `NotificationService.deleteAll()` a `recipientUid`-re szűrt, majd **feltétel nélkül az ÖSSZES** rekordot törölte — az `archivedAt` mezőt egyáltalán nem nézte. A képernyő pedig mindig ezt hívta, tekintet nélkül a kiválasztott fülre, ezért az Aktív fülről indított törlés az archívumot is elvitte. A felirat is félrevezető volt: „Biztosan törlöd az összes értesítést?".
- **A javítás:**
  1. **`deleteAll({required bool archived})`** — a törlés a **látható fülre** szűkül. A szűrést a kliensen végezzük (`doc.data()['archivedAt'] != null`), mert a Firestore-ban a **hiányzó mezőre nincs egyenlőség-szűrő** (`archivedAt == null` nem kérdezhető le) — ugyanaz a minta, mint a meglévő `archiveReadOlderThan()`-nél és a `markAllRead()`-nél.
  2. **A megerősítő szöveg megnevezi a fület:** „Biztosan törlöd az összes **AKTÍV** értesítést? Az archivált értesítések megmaradnak." (és fordítva), a cím is fül-specifikus.
  3. **A gomb tooltipje** is megmondja: „Összes aktív törlése" / „Összes archivált törlése".
- **Az „aktív" definíciója szándékosan `archivedAt == null`**, nem pedig `readAt == null`: az olvasottság nem sorol át egy értesítést a másik fülre, különben egy olvasott értesítés átcsúszna, és a törlés a rossz helyen hatna. Ezt a teszt külön rögzíti.
- **Új teszt: `test/services/notification_delete_all_test.dart` (6 teszt)** — aktív törlésnél az archiváltak **megmaradnak** és fordítva; a **más felhasználó** értesítéséhez egyik fül sem nyúl; az olvasott, de nem archivált értesítés az **aktív** fülhöz tartozik; vendég fióknál nem töröl semmit; üres fülön nem hiba.
  - **Nem adtam hozzá új csomagot** (`fake_cloud_firestore`): a teszt kézzel írt Firestore-hasznot használ `implements`-szel, ezért a szolgáltatás a **valódi `deleteAll()`** kódját futtatja, csak a tárhely hamis. Ez a projekt bevett mintája.
- **Ellenőrzések:** `flutter analyze` tiszta, `flutter test` **228/228**.
- **Csomag:** `build/HUHS-v1.0.0+325-release.aab` — tisztán kliensoldali javítás, **a pluginhoz nem kell nyúlni**.

### A WP admin „HUHS Mobile" menü rendberakva — a rendezési lista elavult volt (2026-09-18, plugin 2.5.2)

- **A tulajdonos jelzése:** *„meg apiban tedd rendbe a menüpontokat, elég összevisszaság lett most, about legalul legyen a többi meg értelem szerűen egymáshoz viszonyítva jó helyen"*, majd pontosítva: *„most ugye a WP HUHS mobil menüről beszéltem"*.
- **FONTOS FÉLREÉRTÉS, amit rögzítek:** először az **app** „Több" menüjét kezdtem rendezni. Az a módosítás **visszaállítva** (a `MoreScreen` érintetlen). **Az app menüje külön téma, arról külön kell kérdezni** — a tulajdonos itt a WordPress adminra gondolt.
- **A gyökér:** a `admin.php` végén már **volt** egy rendező hook (`admin_menu`, priority 999), de a benne lévő lista **elavult**: a később hozzáadott modulok — `huhs-poll-results` (2.4.121), `edit.php?post_type=huhs_poll`, `huhs-prize` és `edit.php?post_type=huhs_prize` (2.5.0), `huhs-newsletter` — **benne sem voltak**. A rendezés után ezért a lista **végére** kerültek, a `huhs-trash` és a `huhs-about` társaságába. Pontosan ez volt a „összevisszaság".
- **A javítás — tematikus csoportok (`$groups`) a lapos `$order` helyett:**
  1. **Dashboard** — `huhs-mobile`
  2. **Tartalom** — DJ-k, szervezők, események, kiadványok, GYIK
  3. **Interakció** — kérdőív (+eredmények), nyereményjáték (+admin), éves szavazás szezonjai (+összesítő)
  4. **Közösség** — játékeredmények, játékképek, játékok, új játék, achievementek
  5. **Kommunikáció** — push értesítések, hírlevél
  6. **Beállítások** — rádió, indítási kép, beállítások
  7. **Rendszer** — shortcode-ok, beküldések, lomtár
  8. **Névjegy (About)** — **MINDIG a legalsó sor** (a tulajdonos kérése)
  Az itt fel nem sorolt (jövőbeli) sorok **a végére** kerülnek, hogy semmi ne tűnjön el a menüből.
- **Amit SZÁNDÉKOSAN NEM tettem:** nem raktam **elválasztó sorokat** a csoportok közé. Kipróbáltam, majd elvetettem: az elválasztó sor a WordPress almenüben **kattintható** lenne és egy nem létező oldalra vinne („nincs jogosultságod"), ezért a tiszta, tematikus sorrend önmagában is átlátható. Ezt egy ellenőrzés is tiltja (lásd lent).
- **Új, önmagát bizonyító ellenőrzés: `tools/check-wp-admin-menu.mjs`** (**8/8**). Minden `add_submenu_page()` **5. argumentumát** (a saját slugot) és minden `show_in_menu => 'huhs-mobile'` bejegyzéstípus `edit.php?post_type=…` sorát begyűjti a forrásból, majd megköveteli, hogy **mind szerepeljen** a tematikus sorrendben. Emellett rögzíti a blokkok sorrendjét, hogy az About legalul van, és hogy nincs elválasztó sor.
  - **Két saját parsolási hibát is javítottam közben, érdemes megjegyezni:** (1) a zárójel-párosítást a **hívás** saját nyitó zárójeléből kell indítani, különben a `function ()` zárójelére illeszkedik; (2) az `add_submenu_page()` **első** paramétere a **szülő slug**, ezért a saját slug az **ötödik** (index 4), nem a negyedik. Az első váltolat ezért a `manage_options`/`edit_posts` jogosultság-sztringeket gyűjtötte slugként.
  - **A detektor bizonyítottan működik:** a javítás előtti (lapos `$order`) sorrenden a szkript **szándékosan elhasal** és felsorolja a hiányzó sorokat.
  - Futtatás: `node tools/check-wp-admin-menu.mjs .tmp-api-24115/huhs-mobile-api`
- **Csomag:** `build/huhs-mobile-api-2.5.2.zip` — 43 bejegyzés, 131,7 KB, SHA-256 `C3072A84F00AE82254708AD0404D5BEDECF2D0EA9173FB6DA8028C10807E47D1`.
- **Ellenőrzések:** 42/42 PHP parse, `check-wp-admin-menu.mjs` **8/8**, `check-wp-meta-json.mjs` zöld, `verify-prize-draw.mjs` **44/44**, `verify-poll-status.mjs` **25/25**.

### „100 év után jelent meg a nyertes" — a `forceRefresh` HEAD + ETag útja a RÉGI testet adta vissza (2026-09-18, AAB 324)

- **A tulajdonos jelzése:** *„a játék lejárt 22:17-kor el is tűnt, de nincs ott in app a nyertes a nyereményjáték kártya helyén"*, majd amikor megkérdeztem az app verzióját: **„322 van fent"**, végül: *„ja közben meglett a kártya, 100 év után"*.
- **Amit először kizártam (méréssel, nem sejtéssel):**
  - a szerver **helyes** volt: `GET /prize/active` élőben `state: "drawn"` + `winner.name: "Denoiser"` (a `drawn_at` 20:19:04 UTC = 22:19 budapesti idő, tehát a 22:17-es zárás után 2 perccel a sorsoló lefutott);
  - a kliens **modell** is helyes: `test/models/prize_model_test.dart` az **éles válasz szó szerinti szövegével** (a megmaradt `image` mezővel együtt, mert a plugin akkor még 2.5.0 volt) felismeri a nyertest;
  - az app **322** volt, tehát a kártya kódja benne volt.
  Vagyis a hiba a **kettő között**, a cache-útvonalon volt.
- **A gyökér — a `forceRefresh` nem cache-kerülés, hanem ETag-egyeztetés.** A `WordpressHeadCache._get()` a `forceRefresh` esetén ezt tette: `HEAD` kérés a `_bypass()` (egyedi `_huhs_revalidate`) URI-ra, majd ha a HEAD **ugyanazt az ETag-ot** adta vissza, mint a mentett rekord, akkor `_unchanged()` igaz lett, és a függvény a **mentett testet** szolgálta ki. A WordPress viszont a **cache-elt válaszához ugyanazt az ETag-ot** adja (`X-HUHS-Cache: early`), ezért a kliens tíz percen át a **régi, még üres** `{"prize":null}` testet kapta — hiába volt a szerveren már ott a nyertes. **Élő mérés, ami ezt alátámasztja:** a GET és a HEAD is `X-HUHS-Cache: early` + **azonos ETag** (`"8426d91d…"`), és a feltételes (`If-None-Match`) kérés is **200-at** ad, nem 304-et.
- **Miért nem derült ki a kérdőívnél?** Ott ugyanez a hiba létezett, csak rövidebb ablakon: a kérdőív 45 másodpercenként változó tartalma miatt az ETag hamarabb eltért, ezért a „beragadás" nem tűnt fel. A nyereményjátéknál viszont **egyszeri, ritka esemény** a sorsolás, ezért ott ez tíz perces késést okozott.
- **A javítás — új `bypassCache` jelző a cache-ben (`lib/services/wordpress_head_cache.dart`):**
  - `bypassCache: true` esetén a mentett rekord **egyáltalán nem dönthet**: nincs ablak-ellenőrzés, nincs háttér-frissítés, **nincs HEAD-egyeztetés** — egyenesen `GET` a bypass URI-ra;
  - a választ **elmentjük**, hogy a megjelenítési út (`forceRefresh: false`) továbbra is azonnal tudjon rajzolni;
  - hálózati hiba esetén a mentett test marad (a viselkedés nem romlik);
  - a `forceRefresh` **megmarad** a „felhasználó frissített" jelentésre — a kettő nem ugyanaz.
- **Bekötés:** `getActivePoll()` és `getActivePrize()` (`bypassCache` paraméter), `PollService.activePoll()` és `PrizeService.activePrize()`, majd **`activePollProvider` és `activePrizeProvider` is `bypassCache: true`**-val kér. A `forceRefresh` innentől **egyetlen providerben sem** szerepel ezeknél.
- **Új tesztek (a hiba konkrét leírásával):**
  - `test/services/wordpress_head_cache_test.dart` **+4**: „bypassCache: a mentett test NEM nyerhet, ha az ETag egyezik" (a `methods` `['GET', 'GET']`, tehát nincs HEAD), „üres (null) mentett válasz nem ragadhat be", „hálózati hiba esetén a mentett test marad", „az ablakon belül is a szerverhez megy";
  - `test/providers/poll_provider_test.dart` és `test/providers/prize_provider_test.dart`: a cache-kerülés ellenőrzése `lastForceRefresh` helyett **`lastBypassCache`**;
  - `test/models/prize_model_test.dart` (**+2**): az éles `drawn` válasz feldolgozása, és hogy a megmaradt `image` mező nem töri el.
- **Ellenőrzések:** `flutter analyze` tiszta, `flutter test` **222/222**.
- **Csomag:** `build/HUHS-v1.0.0+324-release.aab` — **a pluginhoz NEM kell nyúlni**, ez tisztán kliensoldali javítás.
- **TANULSÁG A JÖVŐRE:** ha egy végpont tartalma **időponthoz kötött eseménytől** függ (nyitás, zárás, sorsolás), akkor a `forceRefresh` **nem elég** — az csak ETag-egyeztetés, és egy cache-elő szerver ugyanazt az ETag-ot adhatja vissza megváltozott tartalom mellett. Ilyenkor **explicit cache-kerülés** kell (`bypassCache`), különben a felhasználó a régi állapotot látja, és ez a hiba pont azért veszélyes, mert **ritka és egyszeri** eseményeknél jelentkezik.

### A kérdőív eredmény-gombja az ÉVES SZAVAZÁS összesítőjét nyitotta meg — javítva (2026-09-18, plugin 2.5.1 + AAB 323)

- **A tulajdonos jelzése:** *„A kérdőívnél rossz szavazási összesítő van az adminnak, az éves szavazást mutatja"*.
- **A gyökér (a saját hibám a 322-ben):** amikor az eredmény-gombot admin-only-ra szűkítettem, a `PollScreen._openResults()`-t **változatlanul** hagytam: az a `VotingSummaryScreen`-t nyitotta meg. Az viszont a `/huhs/v1/admin?action=voting_summary` végpontot kéri, ami az **éves szavazás jelöltjeire** leadott szavazatokat összesíti (`huhs_vote_firestore_summary`). Vagyis a kérdőívnél a jelöltek adatai jelentek meg — pontosan ahogy a tulajdonos látta. A gomb jogosultságát javítottam, de a **célképernyőt nem**.
- **A javítás három részből áll:**
  1. **Új plugin admin-művelet `poll_results`** (`includes/api-admin.php`) — a **saját** kérdőív-adataiból dolgozik: `huhs_poll_options()` + `huhs_poll_results()` (a szavazat-meta-sorokból újraszámolva), és válaszonként `count` + `percent` mezőt ad. `pollId` nélkül a nyitott, ha nincs, a legfrissebb kérdőívet adja. **Szándékosan nem érinti** a `huhs_vote_firestore_summary`-t.
  2. **Új `polls` admin-művelet** — a kérdőívek listája a választóhoz (id, kérdés, állapot, szavazatszám), `posts_per_page => 200`, hogy a **régi kérdőívek is visszanézhetők** legyenek (ugyanaz a minta, mint a WordPress-oldali „Kérdőív eredményei" lapon).
  3. **Új kliensképernyő `lib/screens/poll/poll_results_screen.dart`** — legördülő a kérdőívekből (`Key('poll-results-select')`, a címkében az állapot és a szavazatszám), alatta a kiválasztott kérdőív válaszai szavazatszámmal, százalékkal és sávval. A `PollScreen._openResults()` mostantól **ezt** nyitja meg, a `VotingSummaryScreen` importja eltűnt a fájlból.
- **Tesztelhetőség (tanulság):** a `PollResultsScreen` a hálózatot egy **szűk provideren** keresztül éri el (`pollAdminRequestProvider`, `pollAdminCacheClearProvider`), nem közvetlenül a `CommunityService`-t. Ennek az az oka, hogy a `CommunityService()` példányosítása a Firestore-t is felépíti, ezért widget-tesztben `overrideWithValue`-val **nem** lehet helyettesíteni (FirebaseException). Az első nekifutásom `extends CommunityService`-szel ezért hasalt el — a szűk provider a jó megoldás.
- **Új teszt: `test/widgets/poll_results_screen_test.dart` (6 teszt)** — a képernyő a kérdőív **saját** válaszait mutatja; **soha nem kéri a `voting_summary`-t** (ez a lényegi regresszió-védelem, mert a rossz gomb pontosan azt hívta); a legördülőből a **régi** kérdőív kiválasztható és az adatai megjelennek; a frissítés ikon újrakérdez és üríti az admin-cache-t; üres lista → érthető üzenet; szavazat nélkül nullák látszanak. A `tools/verify-poll-status.mjs` **20 → 25** ellenőrzés: létezik a `poll_results` és a `polls` művelet, a `poll_results` a saját adatokból számol, és **nem** használja a `huhs_vote_firestore_summary`-t.
- **A plugin ezért 2.5.1** (a verzió-ellenőrzés a szkriptben már `>= 2.5.1`, nem pontos egyezés — a korábbi `=== '2.4.123'` minden verzióemelésnél elhasalt volna).

### A nyereményjáték KÉP mezője törölve — a tulajdonos kérésére (2026-09-18, plugin 2.5.1)

- **A tulajdonos jelzése:** *„játékhoz adhatok meg képet, de minek, nem mutatja, ráadásul feltölteni se lehet képet, csak link van, igazából felesleges is a kép oda, jó a kártya"*.
- **Igaza volt, és ez az én hiányosságom:** a meta boxban volt egy „Kép URL" mező, a `/prize/active` ki is adta `image` néven, a kliens `HuhsPrize.imageUrl`-ként be is olvasta — **de egyetlen widget sem rajzolta ki**. Vagyis a mező csak ígéret volt, megvalósítás nélkül. Feltöltés (médiafeltöltő) pedig soha nem is volt mögötte, csak kézi link.
- **A döntés: nem fejlesztjük tovább, hanem TÖRLÜK.** A kártya kép nélkül is jó (a `HomeActionCard` egységes megjelenése adja a formát), így nem marad félkész funkció a felületen.
- **Amit töröltem:** a meta box „Kép URL" mezője és a hozzá tartozó leírás, a `_huhs_prize_image` mentése a `save_post_huhs_prize`-ból, az `image` kulcs a `/prize/active` **mindkét** ágából (nyitott és kihirdetett), és a kliens `HuhsPrize.imageUrl` mezője. A **meglévő** `_huhs_prize_image` meta-sorok érintetlenül a helyükön maradnak (nem törlünk adatot), csak többé senki nem olvassa őket.
- **Új ellenőrzések a `verify-prize-draw.mjs`-ben (42 → 44):** „nincs kép-mező a nyereményjáték admin űrlapján" és „a nyilvános `/prize/active` nem ad ki képet".

### ELHALASZTVA — a tulajdonos KÉSŐBB kéri, MOST NE kezdd el (2026-09-18)

- **1. Aktuális changelog a Névjegy alatt, verziószámmal.** A tulajdonos jelzése: *„nem vezetem, de ez majd lehet lesz egy feladat KÉSŐBB, hogy a Névjegy alatt legyen aktuális changelog verziószámmal"*. Vagyis: az app **Több → Névjegy** (`lib/screens/more/about_screen.dart`) képernyőn legyen látható az **adott verzióhoz tartozó** frissítési lista, a verziószámmal együtt. Ma a Névjegy csak a `package_info_plus`-ból olvasott verziót mutatja, changelog nincs sehol a kódban. A szöveg forrása a `docs/RELEASE_CHANGELOG_CHECKLIST.md`-ben már vezetett Play-jegyzet (a kettőnek egyeznie kell). **Ez egy önálló feladat lesz — most nem kezdjük el.**
- **2. A GYÍK menü szövegei.** A tulajdonos jelzése: *„rendbe kell majd tenni a GYÍK menüt mert most semmitmondó gépies leírások vannak benne"*. **Kifejezett kérés: ezt még NE kezdd el.** Amikor sorra kerül, előbb meg kell kérdezni, melyik menüpontokat és milyen hangvételt szeretne, mert ez tartalmi (nem technikai) döntés.

### NYEREMÉNYJÁTÉK (kvíz) — implementálva, plugin 2.5.0 + AAB 322 + Firebase (2026-09-18, **ÉLESBEN: plugin 2.5.0 fent, a függvények deployolva**)

- **A tulajdonosi kérés sorrendben:** *„csináld meg a nyereményjátékos dolgot a 322-re, de előtte foglald össze az elvárt működést"* → spec → *„implementálhatod a jelenlegi WP HUHS mobil apiba menüként"*; majd a döntések: **csak a helyes válasz nyerhet**; **rontás után nincs javítás és nincs újrapróba** (*„ha ront, ennyi volt, játszott, nincs javítás"*); **e-mail-címet a rendszer nem tárol** (a nyertes címét a sorsoláskor a Firebase Auth-ból kérdezzük le); a nyertes látszási ideje a **WordPress adminban napokban állítható**; és *„WP adminban lássam kik játszottak, helyes választ adtak e stb, egy külön lapon, dropdown menüvel választhatóan, amiben a régebbi nyereményjáték adatai is meglegyenek"*.
- **A játékszabály, ahogy a kód kikényszeríti:**
  1. **A helyes válasz SOHA nem megy ki az appba** a sorsolás előtt. A nyilvános `GET /prize/active` nyitott játéknál csak a kérdést és a válaszlehetőségeket adja (`'correct' =>` egyetlen return-ben sincs); a `prize_type`/`prize_description` a sorsolásig **szándékosan üres**, hogy a kártya ne árulja el a nyereményt.
  2. **A helyességet a SZERVER dönti el** (`$answer_index === $correct_index` a `huhs_prize_record_entry()`-ben). A kliens csak a választott indexet küldi — a `prizeVote` callable-ben **egyetlen** helyen sem szerepel `correctIndex`/`correctAnswer`, ezt forrás-lint őrzi.
  3. **Egy fiók egyszer játszik.** A második hívás `alreadyPlayed: true`-t kap, és a tárolt választ **nem** módosítja: rontás után nincs javítás. Ez a WordPress `update_post_meta` egyedi során (`_huhs_prize_entry_<sha256>`) és a korai visszatérésen nyugszik.
  4. **Idempotens sorsolás.** A Firebase `drawPrizeWinner` ötpercenként fut, ezért a `huhs_prize_set_winner()` **nem írja felül** a meglévő nyertest (`alreadyDrawn: true`), és a Firebase oldalon egy `prize_draws/<prizeId>` jelző dokumentum gondoskodik róla, hogy a push és az e-mail **pontosan egyszer** menjen ki (a WordPressbe a beírás megismétlődhet, az ártalmatlan).
  5. **Csak helyes válaszolók sorsolhatók.** A `GET /prize/participants` (`if (empty($entry['correct'])) continue;`) eleve csak a helyeseket adja vissza, és a nyertest a Firebase ebből a listából választja `crypto.randomInt(0, players.length)`-tal.
- **Hol van a nyertes e-mail-címe — és miért ott:** a WordPress **soha** nem tárol e-mail-címet (ezt `verify-prize-draw.mjs` forrás-linttel is őrzi: nincs `wp_mail(`, nincs e-mail-mező egyetlen válaszban vagy metában sem). A sorsolás után a Firebase `auth.getUser(winnerUid).email` hívása adja a címet, majd a `sendMail()` kiküldi a `prizeWinnerEmailTemplate()` levelet. Ha a fiók közben megszűnt, **nincs hova küldeni**, de a sorsolás eredménye és az app-értesítés akkor is megvan — a jelző ilyenkor is kirakódik, hogy ne próbálkozzon örökké.
- **A játékos Firebase UID-ja — tudatos döntés.** A bejegyzés (`_huhs_prize_entry_<hash>`) a válasz mellett a **UID-t is tárolja**, mert a nyertes címét csak UID alapján lehet visszakeresni. Ez **nem** kliens-adat: a `GET /prize/participants` végpont `manage_options` jogosultság mögött van (`$server_only`), és kizárólag a Firebase hívja application password-del. A nyilvános `/prize/active` **sem UID-t, sem hash-t nem ad ki** — ezt a `verify-prize-draw.mjs` két külön ellenőrzéssel kéri számon. Az e-mail-cím viszont továbbra sincs sehol a WordPressben.
- **Plugin-oldal (`.tmp-api-24115/huhs-mobile-api/`, `includes/prize.php`, ~830 sor, plugin 2.5.0):**
  - `HUHS_PRIZE_MIN_ANSWERS = 3`, `HUHS_PRIZE_MAX_ANSWERS = 5`; `huhs_prize_salt()`, `huhs_prize_player_hash($id,$uid)`, `huhs_prize_answers()`, `huhs_prize_window_state()` (`before`/`open`/`closed`, a webhely időzónájában), `huhs_prize_display_days()` (alap **7**, `0` = soha nem tűnik el), `huhs_prize_winner_visible()`, `huhs_prize_winner()`, `huhs_prize_active_id()`, `huhs_prize_recent_winner_id()`, `huhs_prize_entry()`, `huhs_prize_entries()`, `huhs_prize_summary()`, `huhs_prize_record_entry()`, `huhs_prize_correct_hashes()`, `huhs_prize_set_winner()`.
  - **CPT `huhs_prize`** (`show_in_menu => 'huhs-mobile'`), meta box kérdés/indulás/zárás/5 válaszsor + helyes-válasz rádió + nyeremény típusa/leírása/kép URL/látszási napok + beépített statisztika; `save_post_huhs_prize` mentő.
  - **Admin oldal `huhs-prize`** a `admin_menu` **priority 20**-szal (a `prize.php` a `admin.php` ELŐTT töltődik be — priority 10-zel a WordPress eldobná az almenüt, pontosan úgy, ahogy a kérdőív-eredményeknél már megtörtént egyszer). Legördülő (`name="prize"`, GET-űrlap, `onchange="this.form.submit()"`, `posts_per_page => 200`, alapból a nyitott játék, különben a legfrissebb; a címke: `Kérdés — állapot · N résztvevő · M helyes`), alatta áttekintés + nyertes-figyelmeztetés + válaszlehetőség-tábla + **résztvevő-tábla** (játékos neve, választott válasz, helyes igen/nem, mikor, 🏆 a nyertesnél). **A régi játékok adatai azért maradnak meg, mert a bejegyzések a játék posztján meta-sorként élnek.**
  - **REST:** `GET /prize/active` (nyilvános), `POST /prize/enter`, `POST /prize/status`, `GET /prize/pending`, `GET /prize/participants`, `POST /prize/winner` — az utolsó öt `manage_options` mögött (`$server_only`).
  - A `huhs_public_cache_route()` engedélylistája (`includes/http-cache.php`) a `prize/active` útvonallal bővült — **egyetlen** engedélylista-forrás van, ezt a `check-wp-meta-json.mjs` is ellenőrzi.
- **Firebase-oldal (`functions/index.js`):**
  - **`exports.prizeVote` callable** — `requireRegisteredViewer()` + `allowCall(uid, 'prize_vote', 20)`. `answerIndex` nélkül a `/prize/status`-t kérdezi (játszott-e már), azzal a `/prize/enter`-t. A megjelenített nevet a **saját** `community_profiles/<uid>.displayName` mezőjéből olvassa (a kliens nem küldhet nevet). Napló: `prize_vote_wordpress_result` / `prize_vote_wordpress_failed` — az UID-t **szándékosan nem**, csak a hosszát.
  - **`exports.drawPrizeWinner`** — `onSchedule` **ötpercenként**, `timeZone: 'Europe/Budapest'`, titkok: WordPress + mind az 5 SMTP, `timeoutSeconds: 120`. Lekéri a `/prize/pending`-et (lezárult, még nem sorsolt játékok), majd játékonként a `/prize/participants`-et, sorsol, `POST /prize/winner`, és értesít: `createNotificationBestEffort()` (`type: 'prize_winner'`) + `sendAchievementPushBestEffort()` + `sendMail()`.
  - **Test-only export:** `exports.__drawPrizeWinnerForTests` — a mag injektálható (`{db, auth, credentials, sendMail}`), ezért az emulátoros teszt a **valódi** tranzakciót és elágazásokat futtatja, csak a hálózatot és az Auth-ot helyettesíti.
  - A **HTML-escape** a nyertes levelében kötelező: a játékos neve felhasználói adat, ezért a `prizeWinnerEmailTemplate()` escape-eli a nevet, a kérdést, a nyeremény nevét és leírását.
- **Firestore-szabály:** `match /prize_draws/{prizeId} { allow read, write: if false; }` — ha a kliens írhatná, újra kiváltaná a sorsolást; ha olvashatná, a nyertest a hivatalos kihirdetés előtt megtudná.
- **Kliens-oldal (AAB 322):** `lib/models/prize.dart` (`HuhsPrize` `open`/`drawn` állapottal, `HuhsPrizeAnswer`, `HuhsPrizeWinner`, `HuhsPrizePlay`), `lib/services/prize_service.dart`, `lib/providers/prize_provider.dart` (`activePrizeProvider` **cache-kikerüléssel**, `prizePlayProvider` család), `lib/screens/prize/prize_screen.dart`, `lib/widgets/prize_entry_card.dart`. A főoldalon a nyereményjáték sora a **legfelső** a hero-sorok között (a kérdőív és az éves szavazás fölött), és ugyanazt a `HomeActionCard`-ot használja, ezért pontosan egyforma széles. A `_refreshHome()` a `activePrizeProvider`-t is invalidálja.
  - A kvíz képernyő **ugyanazt a mintát** követi, mint a kérdőív: a válaszlista **csak kifejezett szerveroldali „nem játszottál"** után jelenik meg (se betöltés, se hiba esetén nem villan fel), és a frissítés ikon újrakérdez.
- **Ellenőrzések:** `flutter analyze` tiszta, `flutter test` **210/210** (+13 widget-teszt a nyereményjátékhoz, +11 provider/modell teszt), **42/42 PHP parse**, `check-wp-meta-json.mjs` zöld, `verify-prize-draw.mjs` **42/42** (a nyilvános végpont nem ad ki helyes választ/UID-t/hash-t, a participants átadja a UID-t, a szerver dönt a helyességről, nincs e-mail-mező, nincs `wp_mail`, priority 20, megjelenítési napok állíthatók), `functions/prize-draw.test.cjs` **22/22** valódi Firestore-emulátoron, `functions/rules.test.cjs` **8/8**.
- **Csomagok (a 323-hoz):** `build/huhs-mobile-api-2.5.1.zip` — 43 bejegyzés, 131 KB, SHA-256 `6EECF3DDE9749BE2099B25BEFFBBFA28E2D6E135FA9C8153B2BD30C4FEBC4272` (**ezt kell feltölteni**); `build/HUHS-v1.0.0+323-release.aab` — 720 bejegyzés, 79,18 MB, versionCode **323**, versionName `1.0.0`, production AdMob App ID jelen, teszt ID nincs, aláírás jelen, SHA-256 `AEF2861B11DC9EFB12D893087208E8C7AD114A85C14C654C4C03177598D7F602` (a tulajdonos tölti fel).
- **Ellenőrzések a 323 előtt:** `flutter analyze` tiszta, `flutter test` **216/216**, 42/42 PHP parse, `check-wp-meta-json.mjs` zöld, `verify-poll-status.mjs` **25/25**, `verify-prize-draw.mjs` **44/44**.
- **Sorrend, ami számít:** a plugin 2.5.1 **és** a `prizeVote`/`drawPrizeWinner` függvények is kellenek ahhoz, hogy a játék élesben működjön. A `prizeVote` és a `drawPrizeWinner` **már deployolva van** (2026-09-18), a plugin 2.5.0 is fent van élesben; a 2.5.1 és a 323 még feltöltésre vár.

### Az eredmény-gomb a kérdőíven: eddig MINDENKINEK megjelent, adminnak viszont nem — javítva (2026-09-18, a következő buildben élesedik)

- **A tulajdonos jelzése:** *„kérdőív szavazás után ott egy eredmények megtekintése gomb a sima usernek, amihez nincs jogosultsága, viszont nekem adminként nincs ott.. ezt javítsd, hogy csak admin lássa és legyen is ott az adminnak"*.
- **A gyökér:** a `PollScreen` az „Eredmények megtekintése" gombot **feltétel nélkül** kiadta, ha a fiók szavazott (`if (registered && _voted)`). A mögötte lévő `VotingSummaryScreen` viszont a **WordPress admin végpontot** hívja (`/huhs/v1/admin?action=voting_summary` a `wordPressAdminRequest`-en keresztül), ezért **sima felhasználónak nincs joga** — hibaüzenetet kapott. Fordítva pedig: a tulajdonosnál a gomb **nem jelent meg** (nem szavazott még a kérdőívben), így nem is látta az összesítőt.
- **A javítás két részből áll:**
  1. **Új `currentUserIsAdminProvider`** (`lib/providers/community_provider.dart`) — a `community_profiles/<uid>.accessRole` mezőt figyeli, és a tulajdonos e-mail-címére **rövidre zár**.
  2. A `PollScreen` a gombot **csak adminnak** adja ki, és **szavazás nélkül is**: `if (registered && ref.watch(currentUserIsAdminProvider).valueOrNull == true)`. Indoklás: aki a kérdőívet összeállítja, annak a **szavazás előtt is** látnia kell, hol tart.
- **Miért nem a `CommunityService.isAdmin`-t használtam:** az egy szolgáltatás-példány belső cache-éből dolgozik (`_cachedAccessRole`), ami **csak akkor tölt**, ha a profilképernyő vagy a `refreshCurrentSession` már lefutott. Egy frissen megnyitott képernyőn ez a cache üres, ezért az admin jogát **nem látta** — pontosan ez volt a „nekem adminként nincs ott" jelenség. Az új provider közvetlenül a profil-dokumentumot olvassa, ezért cache-feltöltéstől független. A tulajdonos e-mail-címe külön rövidzár, mert a szerver is adminnak tekinti akkor is, ha az `accessRole` mező még nem állt be.
- **Új segédfüggvény:** `CommunityService.isOwnerEmail(String?)` (statikus, normalizál: trim + kisbetű). A meglévő `_isAdmin` ugyanezt teszi példányszinten; a statikus változat azért kell, mert a provider nem tud példányt létrehozni Firebase nélkül.
- **Új tesztek:** `test/widgets/poll_entry_button_test.dart` **9 → 12**: sima felhasználónak **nincs** eredmény-gomb (szavazás után sem), adminként **ott van** (szavazás előtt is), és adminként szavazás után is. A `_app()` teszt-segéd átvesz egy `admin` kapcsolót, és a `currentUserIsAdminProvider`-t felülírja (nem kell hozzá Firestore). A `test/services/community_service_test.dart` **+3**: a tulajdonos címe admin (kis-nagybetűtől és szóköztől függetlenül), más cím nem az, a konstansok változatlanok.
- **Ellenőrzések:** `flutter analyze` tiszta, `flutter test` **186/186**.
- **Állapot:** a javítás **kliensoldali**, ezért **a következő AAB-buildben** (322) élesedik — a 321 már fent van a Playen. A plugin/szerver oldalon nincs teendő.

### Tulajdonosi döntés: a Goze-termékek MAGUKTÓL aktiválódnak (2026-09-18)

- **A tulajdonos visszajelzése:** *„Goze termék jó ha magától aktiválódik majd, nem kell kézi beavatkozás"*.
- **Ezért NE ajánld fel újra a kézi aktiválást.** A premier (2026-09-25) előtti korai aktiválás **el van vetve**.
- **Ami automatikusan történik:** az `upsertPlayProduct` a megjelenési dátum előtt **INACTIVE** vásárlási opcióval hozza létre a terméket (ez már megvan: a négy Goze-termék bent van a Console-ban), és az **ötpercenkénti `syncWordPressLabelProducts`** aktiválja a napon, amikor a WordPress `is_upcoming` mezője hamisra vált (a webhely időzónájában 00:00-kor).
- **Az app ezért konzisztens marad:** a vásárlás/letöltés gombot is a WordPress `is_upcoming` mezője vezérli, nem a Play állapota — vagyis nem fordulhat elő, hogy az app vásárlást kínál egy még nem aktivált termékre.
- **Egyetlen dolog, ami ezt elronthatja (nem kell hozzá teendő, csak tudni):** ha a `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` secret lejár vagy visszavonják, a szinkron nem tud aktiválni. A szinkron mostantól **hangosan jelez** (`label_sync_failed`, `label_sync_failed_items`), tehát ez nem marad észrevétlen.

### AZ APP-PUSH NAPOKIG NEM MENT KI — `admin.messaging` már nem létezik a firebase-admin 14-ben (2026-09-18, javítva, **ÉLESÍTVE**)

- **Hogyan került elő:** a tulajdonos a hír-lájk napi korlátját jelentette; a `awardAchievementFromNewsReaction` naplójában megtaláltam a valódi hibát: `{"event":"achievement_push_failed","message":"admin.messaging is not a function"}`.
- **A gyökér (bizonyítva, nem sejtés):** a `functions/package.json`-ban `firebase-admin ^14.3.0` van, és **ebben a verzióban a régi namespace-hívás megszűnt**: `typeof require('firebase-admin').messaging === 'undefined'`. A `sendMulticastToAllTokens()` a `admin.messaging().sendEachForMulticast(...)` alakot használta, ezért **minden** app-push meghalt, ami ezen a helperen megy:
  - achievement pont értesítés,
  - esemény-értékelési kérés,
  - új beküldés az adminoknak,
  - ismerős-jelölés (`notifyConnectionRequest`),
  - meetup-érdeklődés,
  - privát üzenet,
  - chat jelentés.
- **Miért maradt rejtve:** (1) a hívók `console.warn`-nal nyelték el, a művelet maga sikeres maradt (a pont/profil/értékelés beírása nem függ a pushtól); (2) **a hír-értesítést a WordPress plugin küldi**, nem ez a függvény — egy működő hírek-push elfedte a többi hat útvonalat. Élő bizonyíték a fejlécből: `push_last=release/ok … sent=122 failed=0` (az a plugin másik útja).
- **A javítás:** `const { getMessaging } = require('firebase-admin/messaging')` a fájl tetején, és a helper `const messaging = getMessaging();`-t használ. **Új napló:** ha egy körben **nulla** sikeres küldés van, `console.error('push_multicast_all_failed', …)` — ez a hibaosztály nem tud többé némán elmúlni.
- **Új teszt: `functions/push-messaging.test.cjs`** (5 teszt) — a moduláris út létezik, a `admin.messaging(` **kódként** nem térhet vissza (a komment-sorokat a lint kizárja), a telepített firebase-admin-ban tényleg `undefined`, és csak **egy** hely hívja a Firebase API-t (a 6+ útvonal ugyanazon a helperen megy).
- **A deploy megtörtént (2026-09-18, ~16:20):** az első célzott `--only` deploy **csak egy függvényt** frissített és az új ütemezett függvényt **nem hozta létre**, ezért **teljes `firebase deploy --only functions`** futott. Minden függvény **egyetlen közös kód-hash-en** van (`0c0a9080…`), és a `retryPendingIdentityEmails` **létrejött** (`state: ACTIVE`, ütemezett, mind az 5 SMTP secret beállítva). Az app-push javítása így **élesben van**.

### Hír-lájk: napi 3 pont-jogosultság (5 helyett) + emulátoros bizonyíték (2026-09-18, javítva)

- **A tulajdonos jelzése:** *„hír lájkolással ne lehessen achievement pontokat farmolni, eddig volt benne valami tiltás, hogy max napi 3 hír lájkolásért jár achi egy usernek, most mintha nem így működne"*.
- **A tények a git-történetből:** a napi plafon **2026-09-14-én** (`dbc1d887`) került a kódba, és az érték **5** volt (nem 3) — a `f87bb8fc` (08-31) verzióban még **egyáltalán nem volt napi plafon**, csak a ledger. Vagyis a tulajdonos emléke a 3-ról pontatlan volt, a „mintha nem működne" érzés pedig onnan jöhet, hogy **5 lájk elég soknak tűnik**.
- **Két külön védelem, és miért kell mindkettő:**
  1. **`achievement_ledger`** — a kulcs tartalmazza a `postId`-t (`news-like:<postId>`), ezért **ugyanazt a cikket** kétszer lájkolni nem ad kétszer pontot;
  2. **napi számláló** (`achievement_news_like_limits/<uid>_<YYYY-MM-DD>`) — mert egy nap **több tucat különböző cikket** is meg lehet nyitni, és a ledger erre nem véd.
- **A javítás:** `NEWS_LIKE_DAILY_POINT_LIMIT = 3` és `ARTICLE_COMMENT_DAILY_POINT_LIMIT = 3` (nevesített konstansok, egy helyen). A visszavonás (unlike) **szándékosan a plafon fölött is működik**, különben egy elrontott pont nem lenne levehető.
- **Új teszt: `functions/achievement-daily-limit.test.cjs`** (**6/6**, valódi Firestore-emulatoron, a **valódi** `awardAchievementPoints` tranzakcióval — nem forrás-szöveg keresés). Bizonyítja: 3 különböző cikk után 6 pont, a 4–6. cikk **nem** ad pontot, a ledgerben csak 3 sor van, ugyanaz a cikk kétszer nem ad pontot, a visszavonás a plafonon is megy, a kommentnek külön számlálója van, és a nem korlátozott forrás (esemény-részvétel) nem fogyasztja a napi keretet. Futtatás:
  `npx firebase emulators:exec --only firestore --project demo-huhs "node functions/achievement-daily-limit.test.cjs"`
- **A teszthez szükséges egy apró javítás:** a `functions/index.js` mostantól `if (!getApps().length) admin.initializeApp();`, mert az emulátor injektálja a saját `FIREBASE_CONFIG`-ját, és a feltétel nélküli `initializeApp()` a „[DEFAULT] already exists with a different configuration" hibát adta. Az éles futásban ez változatlan (ott sosem létezik még app).
- **Teszt-only exportok** (nem Cloud Functionok, nem deployolódnak): `exports.__awardAchievementPointsForTests`, `exports.__achievementDailyLimitsForTests`.

### A „tájékoztató" levelek újrapróbálása — az audit H2 pontja lezárva (2026-09-18, javítva, **ÉLESÍTVE**)

- **A rés:** a `sendIdentityEmailOnce()` a **duplikáció** ellen véd, nem a **kudarc** ellen. A munkarekord a címzettet csak **hash**-ként tárolja, ezért SMTP-hiba után nincs miből újraküldeni. Két helyen ez **végleges elveszést** jelent, mert nincs, aki újrakérje:
  - **e-mail-csere:** a `syncEmailChange()` a `previousEmail` mezőt a levél **előtt** törli, tehát a régi cím a művelettel eltűnik;
  - **admin fióktörlés:** az Auth-fiók már törölve van, a cím csak a memóriában élt, és a hívás egyszer fut.
  - **Amit ez NEM érint:** a felhasználó által **kért** leveleket (megerősítés, jelszó-visszaállítás). Azok védettek: a `sendAuthEmail` megvizsgálja az eredményt, **hibát dob**, és mivel a munkarekord `failed` (nem `sent`), a következő kérés átmegy a deduplikáción. Ez élesben igazolva (a tulajdonos megkapta a megerősítő és a törlési levelet is).
- **A javítás — új modul `functions/email_delivery_retry.js`:** a címzett és a sablonnév egy **rövid életű** (24 óra), szerveroldali `email_delivery_pending` rekordba kerül, és egy **új ütemezett függvény** (`retryPendingIdentityEmails`, 10 percenként) korlátozottan (max 3 kísérlet, 5 és 30 perc késleltetéssel) újrapróbálja. **Sikeres küldés vagy a 3. kudarc után a rekord — és vele a cím — törlődik**, tehát nem marad személyes adat a szerveren.
- **A Firestore-szabály kiegészítve** (`firestore.rules`): `email_delivery_pending` és `email_delivery_jobs` kliensből `allow read, write: if false` — még a saját UID-hoz tartozó sor sem olvasható. Ugyanez a napi pont-plafon számlálókra (`achievement_news_like_limits`, `achievement_article_comment_limits`): ha a kliens olvasná, kiszámíthatná, ha írná, nullázná a plafont.
- **Új teszt: `functions/email-delivery-retry.test.cjs`** (12 teszt) — a címzett **teljes** címe megmarad (nem hash), a lejárat a rövid TTL-en belül van, üres címzettel nem keletkezik rekord, a siker törli, a kudarc növeli a kísérletszámot és késleltet, a 3. kudarc után **feladja és töröl**, a késleltetés nő; plusz forrás-invariánsok: **mindkét** admin-törlési hívóhely jelöl retry-t, a `sendAuthEmail` **szándékosan nem** (ott az újrakérés a védelem), és a sikeres küldés törli a rekordot.
- **Amiért a `sendAuthEmail` marad jelölés nélkül:** ha egy felhasználó kérte a levelet, ő látja a hibát és újra tudja kérni — ott a szerveroldali újrapróbálás felesleges, a látható hiba a helyes viselkedés.

### E-mail-küldés ÉLESBEN IGAZOLVA — a nodemailer 10 csere nem tört el semmit (2026-09-18)

- **A tulajdonos visszajelzése:** *„a google regisztráció fixen ment, de ahhoz nem kell mail megerősítés — regelés után a megerősítő mail megjött, működik is, admin user törlés után a törlésről szóló levél is megjött"*.
- **Ez éles, valódi postafiókos bizonyíték három külön útra**, ugyanazon a `sendIdentityEmailOnce()` + `email_service.js` láncon (nodemailer 10):
  1. regisztrációs **megerősítő** levél (action link) — megérkezik;
  2. **admin fióktörlés** utáni biztonsági értesítés — megérkezik (`functions/index.js:3762`, `key: admin-deletion:<uid>`, a cím az **Auth-felhasználóból**, nem profilmezőből);
  3. Google-regisztráció — szándékosan **nem** kér e-mail-megerősítést (ez helyes, nem hiányosság).
- **Következmény:** a 2026-09-18-i **nodemailer 7 → 10** főverzió-váltás **nem tört el semmit**. A korábbi „valódi postafiókos megerősítés hiányzik" aggodalom **LEZÁRVA** — többé ne sorold nyitott tételként.
- **Ami az auditból megmarad (H2, szűk élszakasz — NEM regresszió, régóta így van):** ha az SMTP **épp abban a pillanatban** hibázik, amikor az értesítés kimegy, akkor
  - az **e-mail-csere** régi címre küldött értesítése nem próbálható újra, mert a `previousEmail` mezőt a `syncEmailChange` már törölte (`functions/index.js:194-212`);
  - az **admin törlés** értesítése sem próbálható újra, mert a fiók már törölve van és a hívás egyszer fut.
  A művelet maga ilyenkor is sikeres (ez szándékos: egy levélhiba nem fordíthat vissza egy törlést). **A címzett megőrzése retryképes, rövid életű szerveroldali rekordban** zárná le teljesen — külön döntés, nem sürgős.
- **Az auditból LEZÁRVA:** H1 (névfoglalás-bypass → `display_name_claims` + Rules Emulator-teszt), H3 (nodemailer 10 + `npm audit` 0), M3 (Rules Emulator-tesztek, `functions/rules.test.cjs`).

### KÖVETKEZŐ BUILD (322): a kérdőív és az éves szavazás sora hero-szélességű — a tulajdonos kérése (2026-09-18, **AAB még NEM készült**)

- **A tulajdonos jelzése (képernyőképpel):** *„a kérdőív kártya a főoldalon lehetne szebb és szélesebb, hero szélességű"*, majd pontosítva: *„a kérdőív kártya legyen olyan széles mint felette a hero"*, végül: *„és ez vonatkozik az éves szavazásos kártya gombra is"*.
- **A gyökér:** mindkét sor egy tartalomhoz igazodó `OutlinedButton.icon` volt (`minimumSize: Size.zero`, `Align(centerLeft)`), ezért a szöveg hosszáig ért csak — a felette lévő hero kártya viszont a **teljes** belső szélességet kitölti. Ezért lógott ki a kettő egymás alatt.
- **A javítás — egyetlen közös komponens: `lib/widgets/home_action_card.dart` (`HomeActionCard`).** Mindkét sor ezt használja, ezért **nem tudnak elcsúszni egymástól**:
  - a főoldali `ListView` teljes belső szélességét kitölti (nincs `Align`, nincs tartalomhoz igazodó méret);
  - a megjelenése a hero kártyát követi: sötét színátmenet, **4 px piros bal oldali sav**, 1 px világos keret, 10 px sarok;
  - bal oldalon ikon, alatta kis nagybetűs felirat (`KÉRDŐÍV` / `SZAVAZÁS`), a fő szöveg 2 sorig (utána `…`), jobb szélen nyíl;
  - `Semantics(button: true)`, és a `Key('poll-entry')` / `Key('voting-entry')` a tesztekhez;
  - `disabled: true` esetén a sav és az ikon szürke, nyíl nincs, koppintás nincs (előkészítve a lezárt szavazásra).
- **Flutter-korlát, amit érdemes megjegyezni (kétszer is elhasalt rajta a kód):** a `Material`/`Ink` és a `BoxDecoration` kerete **csak egyforma színű kerettel** tud lekerekített sarkot rajzolni (`A borderRadius can only be given on borders with uniform colors`). Ezért a piros bal oldali sav **nem keret**, hanem egy külön `Positioned` csík a `Stack`-ben — így a sarok lekerekítése és a piros sav egyszerre működik.
- **A főoldal sorrendje (fontos, mert egyszer már félrement):** a két sor egy `Column(crossAxisAlignment: stretch)`-ben van egymás alatt, **mindkettő a „Legfrissebb hírek" felirat FÖLÖTT**. A `SizedBox(height: 20)` van a felirat előtt, tehát a sorok nem a hírfolyam részeként jelennek meg. A szavazás sora **változatlanul eltűnik, ha nincs aktív/lezárt szezon** (a `PollEntryButton` pedig akkor tűnik el, ha nincs nyitott kérdőív).
- **Új teszt: „a kerdőív sor olyan szeles, mint a hero kartya"** — egy 1080 px széles, 3x-es sűrűségű nézetben összehasonlítja a hero kártya és a kérdőív-sor `Rect`-jét (`left` és `width` epszilonon belül egyezik). A `Key('poll-entry')` a `HomeActionCard`-ra került, ezért a teszt a teljes sor méretét méri.
- **Ellenőrzések:** `flutter analyze` tiszta, `flutter test` **180/180**.
- **A verziókód emelése (`1.0.0+322`) és az AAB build SZÁNDÉKOSAN elmaradt**, mert a tulajdonos kérése szerint *„de nem kell még aab"* — a 321-es van élesítés alatt. A `pubspec.yaml` még `1.0.0+321`.
- **Changelog a 322-höz (ha kell), magyar, 231 karakter:**
  `- A főoldalon a Kérdőív és a Szavazz/Eredmények sor ugyanolyan széles, mint a felette lévő kártya, és egységes megjelenést kapott.`

### MEGTALÁLVA: a `/poll/status` a meta ÉRTÉKÉT kérdezte, nem a sor LÉTEZÉSÉT — `(bool) '0'` a PHP-ban FALSE (2026-09-18, plugin 2.4.123 + AAB 321)

- **A tulajdonos jelzése (a 320-as telepítése UTÁN):** *„most oké a kérdőív, de még mindig tudok többször szavazni, ha újranyitom az appot"*. Vagyis a kliensoldali javítás (friss `hasVoted` lekérés) **nem volt elég** — a hiba a SZERVEREN volt.
- **A gyökér (egy sor, és pontosan megmagyarázza a tünetet):** a `huhs_poll_api_status()` ezt adta vissza:
  `'voted' => (bool) get_post_meta($poll_id, '_huhs_poll_vote_' . $hash, true)`
  A szavazat értéke a **választott válasz indexe**, és az **első válaszlehetőség indexe `0`**. A PHP-ban viszont a **`(bool) '0'` értéke FALSE**. Ezért aki az **első** válaszra szavazott, arról a végpont azt mondta: **„nem szavaztál"**.
- **A tünetsor pontosan illeszkedik:** az app újra kiadta a szavazólapot → a felhasználó azt hitte, **újra tud szavazni** → „Újra szavaztam" érzés. **Közben a szerver a második szavazatot MINDIG elutasította** (`add_post_meta(..., true)` egyedi sora már létezett, és a végpont `alreadyVoted: true`-t adott) — vagyis **dupla szavazat sosem született**, csak a felület hazudott. Ezt az is magyarázza, hogy a kérdőív eredményeinél a szavazatok száma sosem duplázódott.
- **A javítás (plugin 2.4.123):** a végpont mostantól a **sor létezését** kérdezi:
  `'voted' => metadata_exists('post', $poll_id, '_huhs_poll_vote_' . $hash)`
  Ez pontosan az a kérdés, amire a kliens kíváncsi, és **minden indexre helyes** — az értéktől függetlenül. Az `add_post_meta(..., true)` egyedisége érintetlen, tehát a védelem a helyén marad.
- **Új, önmagát bizonyító ellenőrzés: `tools/verify-poll-status.mjs`** (`node tools/verify-poll-status.mjs [plugin-mappa]`, **20/20** a 2.4.123-on). Szimulálja a PHP kasztot, a `metadata_exists`-et és az `add_post_meta(..., true)` egyediséget, végigjátssza a `szavazás(index 0) → újranyitás → status` láncot, és **a javítatlan 2.4.113 forráson szándékosan elhasal** (17/20, jelzi a `(bool) get_post_meta`-t). A forrás-lint **kizárja a komment-sorokat**, különben a hibát leíró komment maga buktatná el.
- **Kliens-oldali szigorítás (AAB 321) — a tulajdonos kérése:** *„ha valaki szavazott, csak kapja meg a már szavaztál dolgot és ne lássa a listát"*. A `PollScreen` mostantól **nem `FutureBuilder`** (`initialData: false`-szal), hanem `ref.watch(hasVotedProvider(...)).when(...)`:
  - **`loading`** → töltésjelző, **a válaszlista NEM látszik** (korábban a `initialData: false` miatt egy pillanatra **felvillant** a lista, mielőtt a szerver válaszolt);
  - **`error`** → „A szavazás állapotát most nem sikerült lekérdezni…" és **lista nélkül**, mert egy szavazott fióknak nem szabad válaszlehetőségeket látnia;
  - **`data: true`** → „Köszönjük, a szavazatod rögzítettük.";
  - **`data: false`** → **csak akkor** jön a válaszlista.
  Vagyis a lista megjelenésének feltétele egy **kifejezett szerveroldali „nem szavaztál"**.
- **Új tesztek:** `test/widgets/poll_entry_button_test.dart` **6 → 8**: „a válaszlista meg sem jelenik, amíg a szerver válasza úton van" (késleltetett status) és „ha a status lekérdezés hibára fut, a lista NEM jelenik meg". A `_FakePollService` késleltethető (`statusDelay`), és van egy `_FailingStatusPollService`.
- **Ellenőrzések:** `flutter analyze` tiszta, `flutter test` **179/179**, 41/41 PHP parse, `tools/check-wp-meta-json.mjs` zöld, `verify-poll-status.mjs` 20/20, a függvénytesztek (google-auth, security-permissions, voting, achievements, article-comments, cloudinary-deletion) zöldek, `verify-push-delivery.mjs` és `verify-wp-content-notifications.mjs` „Minden ellenőrzés sikeres".
- **Csomagok:**
  - **`build/huhs-mobile-api-2.4.123.zip`** — SHA-256 `630B1039DA1B2608C9921B1C99658B424ECBA081BF5DBCDED276FD7748E90B3E`, 120,4 KB, 42 fájl, bővíti a 2.4.122-t. **Ezt kell feltölteni** (ez a szavazat-állapot javítása).
  - **`build/HUHS-v1.0.0+321-release.aab`** — verziókód **321**, verzióneve 1.0.0, 79,07 MB, 720 bejegyzés, production AdMob App ID jelen, teszt App ID nincs, aláírás jelen (`META-INF/HUHS-UPL.SF`), SHA-256 `519E2D4332A78540329C40EE64E8211D4FB9AFD6A8C6037099175D9FC3C89D07`. A verziókód a merge-elt manifestből visszaolvasva **321**.
  - Élesítve: `firebase deploy --only functions:pollVote` (a napló mostantól a WordPress által adott `voted`/`alreadyVoted` választ is rögzíti, UID nélkül — csak a hosszával).
- **TANULSÁG A JÖVŐRE:** ha egy „igen/nem" állapot egy **index** vagy **szám** tárolt értékéből származik, **soha ne a `(bool)` kasztra alapozz** — a `0` és a `'0'` hamis, az üres sztring is hamis. A helyes kérdés a **sor létezése** (`metadata_exists`), nem az értéke. Ugyanez a csapda a `games.php` és a `voting.php` hasonló ellenőrzéseinél is figyelendő.

### A Play-termékszinkron NAPOKIG NÉMÁN HALT EL — `GoogleAuth` `new` nélkül (2026-09-18, javítva + élesítve)

- **A tulajdonos jelzése:** *„feltettem a Goze - Change of Pace-t, feltöltöttem a wavokat is — nem került be a Play Console egyszeri termékekhez, ezt a megjelenés napján küldi el?"*
- **A válasz: NEM, a termékeknek a megjelenés ELŐTT bent kell lenniük** (a Play-ellenőrzésnek és a terjesztésnek le kell futnia a premierig). Csak a **vásárlási opció** marad `INACTIVE` a megjelenési napig, és az aktiválódik magától.
- **A gyökér (éles naplóból, nem sejtésből):** a `syncWordPressLabelProducts` ütemezett függvény **ötpercenként** lefutott, és minden futás ezzel bukott el:
  `Error: Class constructor GoogleAuth cannot be invoked without 'new'`
  A hiba a **`const auth = googleApis().auth.GoogleAuth({…})`** alakból jött: a `google.auth` egy **AuthPlus-példány**, aminek a `GoogleAuth` tulajdonsága a **class**, ezért `new` nélkül hívni `TypeError`. **Bizonyítva lokálisan:** `typeof google.auth = object`, `ctor = AuthPlus`, `typeof google.auth.GoogleAuth = function GoogleAuth`, `new` → OK, `new` nélkül → pontosan ez a hibaüzenet.
- **Miért maradt rejtve napokig:** a scheduler a hibát **egyetlen generikus sorba** csomagolja (`at httpFunc …/scheduler.js:65`), release, termék és ok nélkül. A `syncWordPressLabelProducts`-ban pedig minden release-t külön `try`-catch vett, így a hiba **nem is jutott el** a `label_product_sync_failed` naplóig. A tünet ezért csak a Play Console-ban látszott: üres „egyszeri termékek" lista.
- **A javítás:**
  1. **Új `createAndroidPublisherClient(serviceAccount, google = googleApis())`** helper — a `GoogleAuth` **egyetlen** helyen épül, `new`-val. Mindkét hívási hely (Play-vásárlás-ellenőrzés és a szinkron) ezt használja.
  2. **`runWordPressLabelSync()` wrapper** a `syncWordPressLabelProducts` körül: sikeres futásnál `label_sync_summary` (hány release, mely termékek mentek, mi maradt ki), hibánál `label_sync_failed` **a release azonosítójával, az üzenettel és a stack első soraival**, plusz `label_sync_failed_items` a termékenkénti hibákra.
  3. A **queued** útra (`syncQueuedWordPressLabelProducts`) is került `label_product_sync_queued_request_failed` — a WordPress-oldali queue-nak nincs újrapróbája, ezért ott a hiba nem maradhat néma.
- **ÉLES BIZONYÍTÉK a javítás után (14:14-kor, a deploy 14:09):** a WordPress `GET /releases/12699` mostantól **négy terméket** ad vissza:
  `huhs_release_12699_radio_wav` (700), `huhs_release_12699_radio_mp3_320` (550), `huhs_release_12699_extended_wav` (700), `huhs_release_12699_extended_mp3_320` (550) — vagyis a termékek **létrejöttek a Playben** és a `label_product_sync_play_verified` napló szerint a vásárlási opció **nem ACTIVE** (helyes a megjelenés előtt). A szinkron élesítve: `firebase deploy --only functions:syncWordPressLabelProducts,syncLabelProducts,syncQueuedWordPressLabelProducts,verifyLabelPurchase`.
- **Új teszt: `functions/google-auth.test.cjs`** (5 teszt) — a helper AuthPlus-példányból épít klienst (fake Google objektummal **és** a valódi `googleapis` csomaggal), a `new` nélküli hívás valóban dob, és a **forrásban pontosan egy `auth.GoogleAuth` előfordulás** lehet, az is `new`-val (ez a lint fogja el a visszakúszást). A helper teszt-exportja `exports.__createAndroidPublisherClientForTests` (nem Cloud Function).
- **Ami a tulajdonosnak hátra van:** a Play Console-ban meg kell **jelentetni** (közzétenni) a négy új terméket — a megjelenítés a Console feladata —, és a **2026-09-25-i Goze – Change of Pace** premier előtt ennek meg kell történnie.

### Kiadvány preview: létezik és megy (2026-09-18, mérés — nem hiba)

- **A tulajdonos jelzése:** *„nem jött létre a preview"*, majd a kérdésre: **„Az appban nincs lejátszó a Goze oldalán"**.
- **Élő mérés szerint a preview LÉTREJÖTT:** `GET /releases/12699` → `tracks[0].preview_url = https://hungarianhardstyle.hu/wp-content/uploads/2026/09/huhs-release-12699-preview-1789739500.mp3`.
- A fájl **valóban kiszolgálható**: `HTTP/1.1 200`, `Content-Type: audio/mpeg`, `Content-Length: 960723`, és **range-kérésre `206` + 65536 bájt** (a lejátszó így tud streamelni).
- **A valódi kliensoldali hiba, amit ez a jelzés feltárt:** a `WordpressService.getRelease(id)` **`/releases?summary=true`-t kért le** (illetve cache-elt `summary` listát), és a `huhs_build_release_summary()` **szándékosan `tracks: []`-t ad** — vagyis a részletoldal „teljes" rekordja **üres tracks-szal** érkezett, ezért a `ReleasePreviewPlayer` a tartalék sorát mutatta („Preview még nem érhető el."), nem lejátszót. Emellett a régi kód kommentje szerint „nincs megbízható `/releases/{id}` útvonal", **pedig van** (`api-releases.php` 7. sor, `huhs_get_release_detail`, és élőben is helyes választ ad).
- **A javítás:** a `getRelease()` **először a dedikált `/releases/{id}` végpontot** hívja (egy kicsi kérés a teljes katalógus helyett), és **csak hiba esetén** esik vissza a gyűjtemény-válaszra. Így a `tracks` (preview URL), a `product_prices`, a `versions` és az `audio_status` is megérkezik.
- **Új teszt:** `test/widgets/release_preview_player_test.dart` (3 teszt) — az API-alak (`tracks[].preview_url`) átmegy a modellen, érvényes URL-nél **lejátszó ikonok** jelennek meg, **üres URL-nél** a tartalék sor. Plusz a `test/services/wordpress_cache_policy_test.dart` új esete rögzíti, hogy a részletoldal a **`/releases/{id}`** útvonalat kéri (és nem summary-t).
- **A preview a megjelenési dátum ELŐTT is megy** — a játékos nincs dátumhoz kötve, a „Hamarosan" kártya szövege is ezt mondja. **A javítás a `+320` AAB-ben élesedik** (a korábbi build még a summary-rekordot kapta, ezért mutatta a „Preview még nem érhető el." sort).
- **A `+320` AAB ezért kétszer készült el:** az első (SHA-256 `73BFEA8A8011E267ECA8C577AB21C2F03EE7D59A3DD43E1B66D225C985628C26`) még a kérdőív-gombot tartalmazta a preview-javítás nélkül; a **végleges** csomag SHA-256 `9B4679CBA1248A53AF82B772F5CD168822B03C2F9815E0915967DB2F2F5CE3D7` (79,1 MB, 720 bejegyzés, versionCode **320**, versionName `1.0.0`, production AdMob App ID, aláírás jelen). **Ezt kell feltölteni.** A `flutter analyze` tiszta, `flutter test` **177/177**.

### Kérdőív: gomb a hírek fölött + saját képernyő + beragadt szavazott-állapot (2026-09-18, AAB 1.0.0+320)

- **Tulajdonosi jelzések, sorrendben:** (1) a kérdőív „rossz helyen és nem gombként" jelent meg — a `PollCard` a **„Legfrissebb hírek" felirat ALATT** lógott, ezért a hírfolyam részének tűnt (ráadásul az éves szavazás blokk épp üres volt, mert nem volt aktív szezon, így semmi nem választotta el a kártyát a hírektől); (2) **„a »Legfrissebb hírek« felirat FÖLÖTT legyen"**; (3) **„ha ráfrissítettem a kérdőívre, tudtam megint szavazni"**, majd **„ha újra megnyitottam az appot, engedett megint szavazni"**.
- **A felületi javítás (kliens):**
  - **Új `lib/widgets/poll_entry_button.dart`** (`PollEntryButton`): a főoldalon már **csak egy gomb** van, `OutlinedButton.icon` (`Icons.poll_outlined`, felirat: `Kérdőív: <a kérdés>`), a **„Legfrissebb hírek" felirat FÖLÖTT**, a fejléc-blokk utáni `SizedBox(height: 20)` után. A gomb magától eltűnik, ha nincs nyitott kérdőív (az időablak döntése továbbra is a WordPressben születik).
  - **Új `lib/screens/poll/poll_screen.dart`** (`PollScreen({required HuhsPoll poll})`): a szavazás **saját képernyőn** történik, ezért a válaszlista és a „Szavazok" gomb nem nyomja el a hírfolyamot. A **rádiógombos sorok maradtak** (tulajdonosi kérés: „Rádiógombos sorok (most ilyen)"), a vendég figyelmeztetést kap, a szavazás után a „Köszönjük" állapot jön. A fejlécben **frissítés ikon** (`ContentRefreshIcon`) újrakérdezi a szavazott-állapotot.
  - **`lib/widgets/poll_card.dart` TÖRÖLVE.** A `PollCard` `WidgetsBindingObserver`-alapú újrakérdezése (`AppLifecycleState.resumed`) átkerült a providerbe (lásd lent), mert a főoldalon már nincs mit figyelni.
  - A főoldal a kérdőívhez tartozó `SizedBox(height: 6)`-ot megtartotta, a hírek előtti térköz változatlan.
- **A „szavaztam már?" állapot beragadása — a valódi hiba, amit a tulajdonos jelzése mutatott meg:** a korábbi `_PollCardState` a `hasVoted` választ egy **`Future`-ként a `State`-ben** tartotta (`_statusFuture`, `_statusPollId`), ezért az **a képernyő élettartamáig élt**: ha a felhasználó közben (a weblapon, vagy egy korábbi munkamenetben) szavazott, az app továbbra is a régi „nem szavaztál" választ mutatta, és **megint engedett szavazni**. A lapozott/hátrahagyott állapot nem frissült a főoldal frissítésére sem.
  - **Javítás:** új **`hasVotedProvider = FutureProvider.family<bool, int>`** a `lib/providers/poll_provider.dart`-ban. A `PollScreen` ezt figyeli, a „szavaztal már?" kérdés ezért **minden képernyő-megnyitáskor, minden frissítésnél és minden szavazás után** újra a szerverhez megy. A `pollId < 1` rövidzár nem indít hálózati kérést.
  - **A végső védelem továbbra is a SZERVEREN van** (WordPress `add_post_meta(..., true)` egyedi sor + `pollVote` callable `requireRegisteredViewer`), ezért egy elavult kliens-válasz sem ad második érvényes szavazatot: a második hívás `alreadyVoted: true`-t kap, és az app azt írja ki, hogy „Ebben a kérdőívben már szavaztál."
- **A szerver oldal éles ellenőrzése (nem sejtés):** a `pollVote` Cloud Function **naplózza** a WordPress válaszát (`poll_vote_wordpress_result`: `status`, `voted`, `alreadyVoted`, `uidLength` — az UID-t **szándékosan nem**, csak a hosszát, adatvédelem). A régi `poll_vote_wordpress_failed` sor csak hibánál keletkezik, és **a 2026-09-18-i hívásoknál ilyen nem volt**: minden hívás 200-at kapott. Ezért a szerver nem utasított el semmit — a duplán megjelenő szavazólap a kliens beragadt állapotából jött.
- **Új teszt: `test/widgets/poll_entry_button_test.dart`** (6 widget-teszt) — a gomb megjelenik a kérdéssel, nincs gomb nyitott kérdőív nélkül, a gomb megnyitja a `PollScreen`-t (cím + rádiógombos sorok + „Szavazok"), szavazás után a „Köszönjük" állapot jön, **a szerver szerint már szavazott fióknál nincs válaszlista**, vendégnek regisztrációs figyelmeztetés van. A `poll_provider_test.dart` **4 → 9 teszt**: a szavazott-állapot a szerverről jön, **újranyitás után újra lekérdez** (a tulajdonos esete), szavazás után frissül, a második szavazás a szerver jelzését adja vissza, érvénytelen azonosító nem indít kérést.
- **Ellenőrzések:** `flutter analyze` tiszta, `flutter test` **177/177** (167 + 6 poll + 3 preview + 1 release-útvonal).
- **AAB: `build/HUHS-v1.0.0+320-release.aab`** — a `pubspec.yaml` verziója `1.0.0+320` (a **319-et a tulajdonos még nem küldte be**, ezért ment 320). **Ez a csomag a kérdőív-gombot ÉS a preview-javítást is tartalmazza** (a `getRelease()` már a `/releases/{id}` végpontot kéri). Verziókód a merge-elt manifestből visszaolvasva: **320**, versionName `1.0.0`, production AdMob App ID jelen, teszt App ID nincs, aláírás jelen (`META-INF/HUHS-UPL.SF`), 720 bejegyzés, 79,1 MB, SHA-256 `9B4679CBA1248A53AF82B772F5CD168822B03C2F9815E0915967DB2F2F5CE3D7`.
- **A `PollCard`-ra hivatkozó régi szakaszok** (a lentebbi „Kérdőív kártya az appban — javítva, AAB 1.0.0+319" és a 2.4.113-as fejezet) **történeti leírások**: a kártya helyét a gomb vette át.

### Kérdőív: a szavazat szerveroldali bizonyítása — LEZÁRVA a 2.4.123-mal (2026-09-18)

- **A kérdés eredete:** a tulajdonos kétszer tudott szavazni. Először a kliens beragadt állapotát javítottuk, majd a szerveroldali okot is megtaláltuk — **lásd a legfelső „`(bool) '0'` a PHP-ban FALSE" szakaszt.**
- **A diagnosztika, ami elvezetett oda:** a `pollVote` callable naplója (`poll_vote_wordpress_result`), amiből kiderült, hogy a WordPress **soha nem utasított el szavazatot** (minden hívás 200), tehát a hiba a `/poll/status` VÁLASZÁBAN volt, nem a rögzítésben. A napló **éles** marad, és továbbra is az UID **hosszát** rögzíti, nem az UID-t (adatvédelem).
- **Amit átmenetileg megépítettem, majd visszavontam:** a `/poll/vote` `remove` ága (proba-UID sorának törlése) + egy ideiglenes `pollVoteDiagnostics` callable. **Egyik sem maradt a kódban** — nem is kellett hozzájuk nyúlni, mert a valódi ok egyetlen sor volt.
- **A plugin ezért 2.4.123** (nem 2.4.122), és a javítás egy sor: `metadata_exists()` a `(bool) get_post_meta()` helyett.

### Kérdőív kártya az appban — javítva, AAB 1.0.0+319 (2026-09-18)

- **A tulajdonos jelzése:** a kérdőív **nem jelent meg az appban**, pedig a szerver bizonyítottan helyes volt (élőben: `{"poll":{"id":12694,"question":"Tetszik az Applikáció?","options":[…,"Utálom"…],"start":"2026-09-18T15:20","end":"2026-09-22T19:00"}}`), és a `getActivePoll()` + `HuhsPoll.fromJson()` lánc is helyesen olvasta.
- **A gyökér (kliens):** a `activePollProvider` egy sima `FutureProvider` volt, amely a `/poll/active` végpontot **munkamenetenként egyszer** kérdezte le, és a `getActivePoll()` a **cache-first** úton ment (`forceRefresh: false`). Ezért ha az app a kérdőív **kinyílása előtt** kérdezte le (`{"poll":null}`), a `null` **az egész munkamenetre** beragadt — se a főoldal frissítése, se az app újranyitása (a munkameneten belül) nem javította.
- **A javítás négy ponton (mind a kliensben):**
  1. `WordpressService.getActivePoll({bool forceRefresh = false})` — átadja a `forceRefresh`-t a `_getHeadCached`-nek.
  2. `PollService.activePoll({bool forceRefresh = false})` — ugyanez.
  3. `activePollProvider` mostantól **`forceRefresh: true`**-val kérdez: a kérdőív nyitása/zárása **időponthoz kötött**, ezért a mentett válasz nem dönthet. A végpont kicsi (~250 bajt), a szerver pedig maga 45 másodpercig cache-eli, tehát ez olcsó.
  4. **Újrakérdezés két úton:** a főoldal `_refreshHome()`-ja (húzással frissítés **és** a fejléc frissítés ikon) `ref.invalidate(activePollProvider)`-t is hív és megvárja; a `PollCard` pedig **`WidgetsBindingObserver`**-ként figyeli az app állapotát, és **`AppLifecycleState.resumed`**-nél újrakérdez. Így egy közben kinyílt vagy lezárult kérdőív újraindítás nélkül követhető.
- **Új teszt: `test/providers/poll_provider_test.dart`** (4 teszt) — a szolgáltatástól kéri le, **igazolja, hogy a lekérdezés megkerüli a cache-t** (`forceRefresh: true`), hogy frissítés után **újra lekérdez**, és hogy zárt kérdőívnél `null`. A `PollService` injektálható (`pollServiceProvider.overrideWithValue`), ezért ez valódi egységteszt, nem szimuláció.
- **Ellenőrzések:** `flutter analyze` tiszta, `flutter test` **162/162** (158 + 4 új).
- **AAB: `build/HUHS-v1.0.0+319-release.aab`** — **79,1 MB**, SHA-256 `938E59AB7C525E3022A88F822E52B8D8E94C6A55CD7372E5103FD190A17D6A54`. A merge-elt manifestből visszaolvasva: **versionCode = 319**, versionName `1.0.0`; a production AdMob App ID benne van, a **teszt App ID nincs**, az aláírás jelen (`META-INF/HUHS-UPL.RSA`). A `+318` AAB a helyén maradt, de elavult (a **317-es kód foglalt volt**, ezért 319 lett).
- A build parancs a szokásos három `-P` AdMob-paraméterrel készült (lásd a lenti „AAB build" szakaszt); ezek nélkül a Gradle szándékosan elhasal.
- **A `+318`-as szakaszban leírt „nyitott kliensoldali hiba" ezzel LEZÁRVA.**

### Kérdőív eredményei: legördülő a régebbi kérdőívekhez (2026-09-18, plugin 2.4.122)

- **Tulajdonosi kérés:** *„ha mondjuk ez lezáródik, nekem maradjon meg az eredmény és egy dropdown menüből tudjam visszanézni a régebbi kérdőíveket"*.
- **A megőrzés eddig is működött:** a szavazatok `_huhs_poll_vote_<sha256>` meta-sorként a kérdőív bejegyzésén maradnak, és a `huhs_poll_results()` **mindig a szavazat-sorokból számol újra** — a lezárás (`huhs_poll_window_state()` = `closed`) **csak az appban** rejti el a kártyát, az adatot nem érinti. Ezt a tulajdonos felé is kimondtuk, mert a kérés mögött ez a bizonytalanság volt.
- **A változás:** a „Kérdőív eredményei" oldal eddig **az összes** kérdőívet egy hosszú listában mutatta. Mostantól egy **legördülő** van felül (a legfrissebb elöl, a címke tartalmazza az állapotot és a szavazatszámot: `Kérdés — nyitott/lezárult · N szavazat`), és alatta **csak a kiválasztott** kérdőív részletes eredménye látszik. Alapértelmezés: a **nyitott** kérdőív, ha nincs, akkor a legfrissebb.
- A választás sima GET-űrlap (`admin.php?page=huhs-poll-results&poll=<id>`), ezért **könyvjelzőzhető**, és `noscript`-nél is működik (Megjelenítés gomb). A `posts_per_page` 50 → **200**, hogy sok kérdőívnél se maradjon ki egy sem.
- Csomag: `build/huhs-mobile-api-2.4.122.zip` (SHA-256 `E80FEA3AAE6F5D2DA13388111FEAEF0789F395143754FA21BA26CDFE07458121`), forrás `.tmp-api-24115/huhs-mobile-api/`, 42 fájl, bájt-azonos, 41/41 PHP parse. **A 2.4.121-et is tartalmazza** (az admin-menü javításával).

### Az admin almenü a szülő-menü ELŐTT regisztrálódott — „Kérdőív eredményei" halott (2026-09-18, plugin 2.4.121)

- **A tulajdonos jelzése:** a WordPress adminban a **HUHS Mobile → Kérdőív eredményei** nem nyílik meg („Hoppá! Az oldal nem található.", majd a közvetlen címre „Sajnáljuk, nincs megfelelő jogosultság ehhez az oldalhoz kapcsolódni.").
- **A diagnózis lépései:** (1) élőben lekértem négy admin címet — a `huhs-poll-results`, `huhs-voting-summary`, `huhs-push` és `huhs-game-results` **mind ugyanúgy** 302-vel a bejelentkezésre irányít, tehát **a cím és a hoszting rendben**; (2) a „nincs jogosultság" üzenet viszont a WordPress **regisztrálatlan** admin-oldalra adott válasza; (3) a fő pluginfájl include-sorrendjében a **`poll.php` a 34. sorban, az `admin.php` (a szülő-menü) a 42. sorban** van.
- **A gyökér:** a WordPress az admin-oldal hooknevét a **szülő-menü ismeretében** számolja. Mivel a `poll.php` hamarabb töltődik be, az `admin_menu` callbackje **hamarabb is fut le**, mint az `admin.php`-é — vagyis az almenü **még a HUHS Mobile menü létezése előtt** regisztrálódik. Ezért a regisztrált hooknév eltér attól, amit az `admin.php` később keres, és az oldal **eldobódik**.
- **A bizonyíték, hogy nem új hiba:** az **`achievements.php`-ban pontosan ez a javítás már benne volt** (priority 20 + a szó szerinti komment: „Register after the main HUHS menu exists; registering before its parent can make WordPress drop this submenu from the admin menu."). Az `achievements.php` a 33., a `poll.php` a 34. sorban töltődik — mindkettő az `admin.php` ELŐTT. **A kérdőívnél kimaradt ugyanez a priority.** A `push.php`, `voting.php`, `games.php`, `newsletter.php` az `admin.php` UTÁN töltődik, ezért azok priority 10-zel is működnek.
- **A javítás (2.4.121):** a `huhs-poll-results` regisztráció **`admin_menu` priority 20**-ra került (a `poll.php`-ban), pontosan úgy, ahogy az Achievementek oldalnál. Az `achievements.php` érintetlen (már helyes volt).
- **Új ellenőrzés, ami elkapja ezt a hibaosztályt:** a `tools/check-wp-meta-json.mjs` 4. szakasza beolvassa a fő pluginfájl **include-sorrendjét**, és minden olyan fájlt megjelöl, amely az `admin.php` ELŐTT töltődik, mégis `add_submenu_page`-t hív **priority 20 alatt**. A detektor működését a szkript **önmagán bizonyítja**: egy szintetikus, javítás előtti mintán (priority 10) hibát ad. Futtatás: `node tools/check-wp-meta-json.mjs .tmp-api-24115/huhs-mobile-api`.
- Csomag: `build/huhs-mobile-api-2.4.121.zip` (SHA-256 `24BDE84086B559D857A211E44E540373BB519EDD9507738AC8216D698799D68A`), forrás `.tmp-api-24115/huhs-mobile-api/`, 42 fájl, bájt-azonos, 41/41 PHP parse-olható. **A 2.4.120-at is tartalmazza** (a push-javításokkal együtt).
- **NYITOTT KLIENSOLDALI HIBA (a következő AAB-be):** a **kérdőív kártya** az appban **munkamenetenként egyszer** kérdezi le a `/poll/active` végpontot (`FutureProvider`, nincs újratöltés), és a cache-first szabály miatt az első kérés a **mentett** választ adja vissza. Ezért ha az app a kérdőív kinyílása előtt kérdezte le (`{"poll":null}`), a kártya **az egész munkamenetre eltűnik**. A szerver oldal **bizonyítottan helyes** (élőben: `{"poll":{"id":12694,"question":"Tetszik az Applikáció?","options":[…,"Utálom"…],"start":"2026-09-18T15:20","end":"2026-09-22T19:00"}}`). A javítás a következő buildben: a kérdőív **kerülje meg a cache-t**, és a főoldal frissítésével együtt töltődjön újra.

### Az app-értesítéslista csak az ELSŐ közzétételre szólt (2026-09-18, Firebase-függvény)

- **A tulajdonos jelzése:** „elsőre ment, a visszavonás és újra publikálás után nem" — vagyis az **első** közzétételnél megjelent a bejegyzés az app **Értesítések** paneljén (Aktív/Archivált), vázlat→újra közzététel után viszont **nem**, pedig a push megérkezett.
- **A gyökér: két külön rendszer dönti el, mi „új tartalom".**
  1. **Push:** a WordPress plugin küldi, minden közzétételi eseményre (2.4.117 óta esemény-tokenhez kötve, ezért újra közzétételnél is megy).
  2. **App-értesítéslista:** a Firebase `pollWordPressContentNotifications` ütemezett függvény (5 percenként) tölti fel, és **csak az azonosítót** figyelte (`app_settings/wordpress_content_notifications.ids`). Az újra közzétett cikk **azonosítója nem változott**, ezért a job azt hitte, nincs új tartalom → nem szólt.
- **Élesben igazoltam a jelzőt:** a cikk `date` mezője az újra közzétételkor **megváltozott** (`2026-09-18T14:52:19+02:00` → `15:21:24+02:00`), miközben az `id` ugyanaz maradt. **A publikálási dátum csak közzétételkor változik, egyszerű szerkesztéskor nem** — ezért pontosan ugyanazt az eseményt jelöli, mint a push.
- **A javítás (csak Firebase, pluginfeltöltés nem kell):** a poller mostantól **revision-térképet** is tárol (`revisions[key][id] = date`), és értesítést ad, ha az azonosító **vagy a revision változott**. A dedupe-kulcs is tartalmazza a revisiont (`wordpress_content:<key>:<id>:<revision>:<uid>`), így egy új közzététel **új** értesítés-dokumentumot hoz létre (a korábbi megmarad), a futás ismétlése viszont idempotens marad.
  - **Bázis-védelem:** a régi állapot-dokumentumban nincs `revisions` térkép, ezért a telepítés utáni **első futás csak feltölti** azt, és **nem** küld visszamenőleges értesítés-vihart a meglévő tartalmakra.
  - **Hiányzó dátum** nem lesz revision (nincs téves értesítés).
- **Ellenőrzés: `tools/verify-wp-content-notifications.mjs`** (10/10) — bázis, változatlan lista, új cikk, **vázlat→újra közzététel**, a kulcs eltérése, ugyanarra a közzétételre nincs ismétlés, régi állapotforma (nincs vihar), hiányzó dátum. Futtatás: `node tools/verify-wp-content-notifications.mjs`.
- **Amit tudni kell a működéséről:** az app-értesítéslista **5 percenként** frissül, ezért a pushhoz képest akár **5 percet késhet**; és csak azok kapják, akiknek **közösségi profiljuk** van (`community_profiles` fan-out). A push ezzel szemben minden regisztrált eszközre azonnal megy.
- Élesítve: `firebase deploy --only functions:pollWordPressContentNotifications` (csak ez az egy függvény, hogy ne nyúljunk a többihez).

### AAB build: 1.0.0+318 — feltöltésre kész (2026-09-18)

- Csomag: **`build/HUHS-v1.0.0+318-release.aab`**, **79,1 MB**, SHA-256 `0ADA179475CE0176F830A1B846A90C7EE8985003AF5513A8AA0370469F31E6E6`. **A tulajdonos tölti fel**, az agent soha.
- **A 317-es verziókód már foglalt volt a Playen** (a tulajdonos visszajelzése), ezért a `pubspec.yaml` verziója `1.0.0+318`-ra emelkedett és újra kellett építeni. A `build/HUHS-v1.0.0+317-release.aab` helyben maradt, de **ne töltsd fel**.
- **A verziókód ellenőrzése a kész buildből:** a merge-elt release manifest (`build/app/intermediates/merged_manifest/release/.../AndroidManifest.xml`) szerint **versionCode = 318**, versionName = `1.0.0`. Ez a mérés **kötelező minden buildnél**, mert a verziókód a pubspecből származik, és a Play a foglalt kódot elutasítja.
- **A build parancs kötelező `-P` paraméterekkel** (különben a Gradle szándékosan elhasal):
  ```
  flutter build appbundle --release \
    -P "HUHS_ADMOB_APP_ID=ca-app-pub-7714662594685378~1123886696" \
    -P "HUHS_ADMOB_BANNER_ID=ca-app-pub-7714662594685378/5219184964" \
    -P "HUHS_ADMOB_REWARDED_ID=ca-app-pub-7714662594685378/5286829694"
  ```
  Kell még az `android/key.properties` (release-aláírás); ez megvan. A Gradle **ellenőrzi is** az azonosítókat, és elutasítja a felcserélt banner/rewarded párt — ez véd a korábbi `format mismatch` hiba ellen.
- **Ellenőrizve a kész AAB-ban:** a production AdMob **App ID benne van** a manifestben, a **teszt App ID nincs benne**, `versionName 1.0.0`, és az aláírás jelen van (`META-INF/HUHS-UPL.RSA`). A banner/rewarded egységazonosítók szándékosan **nincsenek** a manifestben: azokat a `lib/providers/ads_provider.dart` adja a beégetett production defaultokból (a komment ki is mondja, hogy egy hiányzó dart-define nem kapcsolhatja ki némán a reklámokat).
- **Mit tartalmaz (kliensoldal):** kiadvány „Hamarosan" + PRESAVE felület és dátumig rejtett vásárlás/letöltés; új **Kérdőív** kártya a főoldalon; cache-first első kirajzolás + frissítés ikon; Photon képméretzés; induláskori előtöltés; részlet-előtöltés görgetés közben; hiányzó rangjelvény önjavítása.
- **Ellenőrzések a build előtt:** `flutter analyze` tiszta, `flutter test` **158/158**.
- **A verziókód-tanulság:** a 317-es kódot a Play már felhasználta, ezért a build **csak a `pubspec.yaml` `version:` sorának emelésével** volt feltölthető. Minden új AAB előtt érdemes a legutóbb feltöltött kódot ellenőrizni, és a merge-elt manifestből visszaolvasni a tényleges `versionCode`-ot.
- **Baseline profile:** szándékosan **nem** lett újragenerálva, mert ahhoz rootolt emulátor vagy támogatott fizikai eszköz kell (`docs/BASELINE_PROFILE.md`); a meglévő, build közben összeálló profil került a csomagba.

### Push: a biztonsági háló átveszi az elárvult feladatot is (2026-09-18, plugin 2.4.119)

- **A 2.4.118 ellenőrzésekor kiderült:** a biztonsági háló csak a **jövőbeli** küldéseket védi, mert a `huhs_push_active_job` mutatót csak a 2.4.118 írja. A korábban elakadt feladat (offset=338, 405 eszköz hátra) a DB-ben maradt, de **semmi nem mutatott rá** — ezért `push_active=none`, és a maradék 405 eszköz továbbra sem kapott értesítést.
- **A 2.4.119 ezt is pótolja:** `huhs_push_adopt_orphan_job()` a `shutdown`-ban (a biztonsági háló előtt) átvesz egy elárvult `huhs_push_job_%` feladatot, ha nincs aktív mutató, és beállítja a `huhs_push_active_job`-ot. A scan **legfeljebb 5 percenként** fut, és csak akkor, ha nincs aktív feladat (hogy a lassú site-on ne legyen állandó lekérdezés); egy **napnál régebbi** feladatot inkább töröl (ne toljon a semmiből egy „új hír" értesítést).
- Ezzel a háló **önmagától is gyógyul**: ha a jövőben bármikor elveszik a mutató (vagy a cron-esemény), a sor akkor is befejeződik, amint bármelyik kérés beérkezik.
- Csomag: `build/huhs-mobile-api-2.4.119.zip` (SHA-256 `76B71B5A0C9BAAB99EB5F6F56A6CFD875682CD9C274305D478CC8E497D0670E9`), forrás `.tmp-api-24115/huhs-mobile-api/`. **A 2.4.118-at is tartalmazza.**

### Push: a küldési lánc elakadt, mert a cron-esemény eltűnt — biztonsági háló (2026-09-18, plugin 2.4.118)

- **A mérés (2.4.117 diagnosztikája, élőben):** `push_job=none`, `push_active` még nem létezett, `cron_overdue=1 → 0` két mérés között. **Ez a döntő tény:** a WP-Cron **működik** (a lejárt események száma csökkent), de a `huhs_push_continue` **nincs betervezve** — vagyis a folytatás nem várakozott, hanem **elveszett**. Ezért állt meg a küldés 338 eszköznél, és a maradék 405 **soha nem kapott értesítést**.
- **A hiba jellege:** a lánc egyetlen cron-eseményen múlott, és ha az eltűnik (a `cron` opciót a WordPress több kérése is írja, és a `wp_cron()`-nak **nincs zára**, ezért párhuzamos kérések ugyanazt az eseményt is futtathatják), akkor **néma leállás** következik be. A `huhs_push_continue` ráadásul három helyen **nyom nélkül** tért vissza (`$job` nem tömb, üres kulcs, hiányzó hitelesítés), és a `wp_schedule_single_event()` visszatérési értékét **nem ellenőrizte** — így a lánc megszakadása semmilyen nyomot nem hagyott.
- **A javítás (2.4.118) — biztonsági háló:** új `huhs_push_resume_pending_job()` a **`shutdown` hookon** (priority 99). A válasz elküldése **után** megnézi, hogy van-e fuggőben lévő feladat (`huhs_push_active_job` opció), és ha az utolsó kör **10 másodpercnél** régebben futott, lefuttatja a következőt. Így a sor **minden olyan kérésnél halad, ami eljut a WordPressig**, függetlenül attól, hogy a cron-esemény megvan-e.
  - A köre szándékosan **rövid** (`HUHS_PUSH_RESUME_BUDGET` = 5 s), mert ha éppen egy látogató kérése fizeti meg, ne várjon sokat; a `HUHS_PUSH_RESUME_GAP` = 10 s pedig a sűrűséget korlátozza.
  - **Zár** védi a párhuzamos futástól: `add_option('huhs_push_resume_lock', …)` atomikus, és 120 s után lejár (elhalt folyamat nem blokkol örökre).
  - **Nem hívunk `fastcgi_finish_request()`-et** — ez szándékos: a válasz levágásának kockázata nagyobb, mint az 5 másodperces várakozás nyeresége.
- **A hívási lánc mostantól ellenőrzi a hibát:** a `wp_schedule_single_event()` visszatérési értékét mindkét helyen naplózzuk, és **nem töröljük a feladatot**, ha az ütemezés meghiúsul (a háló így is folytatni tudja). A három néma visszatérés mindegyike **logol**, és a feladat-bejegyzést is rendben hagyja.
- **A diagnosztika is pontosabb:** `push_active=runs=/offset=/age=` — vagyis **látszik, ha a feladat megvan, de a cron-esemény nincs** (pontosan az a hiba, ami eddig rejtve maradt).
- **Éles tempó (miért lassú a sok kör):** a mérés szerint egy 25 hívást küldő köteg **0,9–2,3 másodpercig** tart, tehát a párhuzamosítás nyeresége valós, de a teljes ~750 eszköz néhány kör. **A szűk keresztmetszet nem a sávszélesség, hanem az FCM válaszideje és a körök közötti szünetek** — utóbbit szünteti meg a biztonsági háló.
- **Ellenőrzés:** 41/41 PHP parse, `tools/check-wp-meta-json.mjs` zöld, `tools/verify-push-delivery.mjs` 26/26.
- Csomag: `build/huhs-mobile-api-2.4.118.zip` (SHA-256 `536AE0508682189DA219DFBF64A09E33CE2A29455CEC374117AAA61DE3038BE7`), forrás `.tmp-api-24115/huhs-mobile-api/`. **A 2.4.117-et is tartalmazza.**

### Push: az értesítés a KÖZZÉTÉTELHEZ kötődik, nem a cikkhez (2026-09-18, plugin 2.4.117)

- **A tulajdonos kérdése:** „eltettem vázlatba és újra kitettem, elvileg ilyenkor is kéne push/notify". **Igaza volt, és a válasz két részre bomlik.**
- **A mérés (a 2.4.116 diagnosztikájával, élőben):** a `push_last` fejléc megmutatta, hogy az értesítés **elindult és ment**: `news/ok recipients=743 processed=240 sent=240 failed=0 dead=0 at=15:04`, majd a következő kör `processed=98 sent=97 dead=1`. Tehát a vázlat→közzététel **kiváltotta** a push-t, és a küldés hibátlan volt.
- **A hiba, amit a kérdés mutatott meg:** a 2.4.116-ban a jelző **cikkenként** működött (`_huhs_push_news_sent` = időbélyeg). Emiatt **egy cikkhez életében csak EGY értesítés** ment volna: a második vázlat→közzététel már **némán elmaradt** volna. Ez pont az, amit a tulajdonos elvárása szerint nem szabad.
- **A javítás (2.4.117): a jelző a közzétételi ESEMÉNYHEZ tartozik, nem a cikkhez.**
  - a `huhs_schedule_news_push()` minden közzétételnél **új tokent** ad (`wp_generate_password`), és azzal ütemezi a hookot;
  - a `huhs_push_publish_news($post_id, $token, $attempt)` csak akkor küld, ha erre a tokenre még nem ment értesítés; siker esetén eltárolja a tokent;
  - az **újrapróba ugyanazt a tokent** használja, ezért egy eseményhez **soha nem megy ki kétszer**, viszont egy **új közzététel új tokent kap → megint megy értesítés**;
  - a folyamatban lévő értesítést a `_huhs_push_news_pending_at` jelző védi a dupla indítástól, **de ez a jelző 1 óra után lejár** — különben egy elhalt folyamat (fatal error) **örökre** elnémítaná a cikk értesítését;
  - a retry mostantól `array($post_id, $token, $attempt)` és `add_action(..., 10, 3)`. A **régi, egyargumentumos** ütemezett események is működnek: a `$token` alapértéke üres, és üres tokennél a jelző-ellenőrzés szándékosan kimarad, hogy egy már sorban álló értesítés ne vesszen el.
- **Éles tempómérés (ez a következő szűk keresztmetszet):** a párhuzamos küldés körönként **240**, majd **98** eszközt vitt el, **0 hibával**; utána a lánc **megállt** (15:05:40 után 1,5 percig nem indult új kör), és ezt a meglévő fejlécből **nem lehetett kideríteni**. Ezért a fejléc két új mezőt kapott: **`push_job=<DUE|inNs>/runs=/offset=`** (be van-e ütemezve a folytatás, és hol tart) és **`cron_overdue=<n>`** (van-e egyáltalán lejárt cron-esemény a site-on). Ezek együtt **megkülönböztetik** a „nincs betervezve" esetet attól, hogy „be van tervezve, de a WP-Cron nem fut le" — pont az a kérdés, amit válaszidő-mérésből nem lehet eldönteni. A `HUHS_PUSH_CONCURRENCY` **15 → 25** (a 15-tel mért körben a Firebase egyetlen hibát sem adott vissza, tehát 25 még bőven a kvótán belül van). **Ami továbbra is korlátoz:** a folytató körök csak akkor futnak, ha valami kérést indít (`wp_cron()` az `init`-en), mert a `wp-cron.php` loopback ezen a hoston hatástalan (0,09 s, 0 bájtos 200). Ezért a teljes idő a forgalomtól is függ, nem csak a küldéstől.
- **Ellenőrzés:** 41/41 PHP parse, `tools/check-wp-meta-json.mjs` zöld, `tools/verify-push-delivery.mjs` **26/26** — köztük a tulajdonos esete (vázlat→közzététel **még egyszer** értesít), az „ugyanaz a token nem küldhet kétszer" és az „1 óra után nem blokkol örökre" eset.
- Csomag: `build/huhs-mobile-api-2.4.117.zip` (SHA-256 `FFFACC5DA5165D7B042088B074158173D669B6AAD77A732B1E02EA568B989303`), forrás `.tmp-api-24115/huhs-mobile-api/`. **A 2.4.116-ot is tartalmazza**, és a `push_job`/`cron_overdue` diagnosztikával együtt készült (ez az érvényes hash).

### Push: lassú volt, nem hibás — és mostantól látható + párhuzamos (2026-09-18, plugin 2.4.116)

- **A tulajdonos jelzése:** „a WP cikk mentés gyors, de a push nem ment még ki, vagy csak lassú", majd „notify megjött", végül „push még nem jött". A mérés végül tisztázta: **minden értesítés megérkezett, csak percekkel később**. A `posts` végpont szerint a cikk **14:52-kor** jelent meg, az értesítés ~6 perccel később; a korábbi (12:29-es) cikk értesítése is késve jött — a tulajdonos valószínűleg azt látta először „megjött"-ként.
- **SAJÁT HIBA, amit rögzítek:** a válaszidő-mérésből (friss kérések 1,0–2,1 s, `wp-cron.php` 0,09 s) azt a következtetést vontam le, hogy „a kör el sem indult". **Ez téves volt**: a mérés nem tudja megkülönböztetni az „el sem indult" esetet attól, hogy „elindult és azonnal, hiba nélkül visszatért" (a néma kilépési pontok pontosan ilyenek). **Tanulság: negatív időmérésből nem szabad hiányzó működésre következtetni, ha a kódnak néma, azonnali visszatérési útjai vannak.** Ilyenkor láthatóvá kell tenni a folyamatot, nem kitalálni az okot.
- **A valódi hibák a kódban (mindkettő javítva):**
  1. **Néma elveszés.** A `huhs_push_send()` három helyen `return 0`-t adott **minden nyom nélkül**: hiányzó szolgáltatásfiók vagy sikertelen OAuth-hívás, nem tömb tokenlista, illetve üres címzettlista. A hír-értesítésnek pedig **sem jelzése, sem újrapróbája** nem volt (a release-nek van), ezért egy néma hiba = **véglegesen elveszett értesítés**, amiről semmi nem árulkodott.
  2. **Soros FCM-hívások.** Eszközönként egy-egy teljes oda-vissza út, 15 s-os körönként: 900 eszköz ≈ **4–6 perc**, és közben a folytató körök csak a beérkező kérések által hajtott `wp_cron()`-ra támaszkodhatnak (a `wp-cron.php` 0,09 s alatt 0 bájtos 200-at ad, tehát a loopback `spawn_cron()` gyakorlatilag nem csinál semmit — ezt élesben mértem).
- **Amit a 2.4.116 tesz:**
  1. **Láthatóvá tétel:** körönként/ küldésenként **egy** `error_log` sor, plusz a `huhs_push_last_result` opció, ami a **tités diagnosztikai fejlécben** is megjelenik: `push_last=<típus>/<ok> recipients=… processed=… sent=… failed=… dead=… http=… status=… at=…`. Ebből **élőben** (a `huhs_diag=huhs-boot-probe-2026` markerrel) megválaszolható, hogy el sem indult, elutasította a Firebase, vagy csak lassú. Az okok: `no-credentials`, `no-token-list`, `no-recipients`, `ok`, `undelivered`.
  2. **Hír-értesítés jelzővel és újrapróbával:** `_huhs_push_news_sent` meta a sikeres küldés után (így egy cikkhez **egy** értesítés megy), sikertelen küldésnél korlátozott újrapróbálkozás (+5 és +10 perc, `HUHS_PUSH_NEWS_MAX_ATTEMPTS=3`), és **csak akkor**, ha egyáltalán volt kit értesíteni. Három sikertelen kísérlet után **logolva** adja fel — néma elveszés nincs többé.
  3. **Párhuzamos küldés `curl_multi`-val** (`HUHS_PUSH_CONCURRENCY=15`, hívásonkénti plafon `HUHS_PUSH_HTTP_TIMEOUT=10` s). A kört **köttegenként** zárja le, mert a folytató kör offsetje csak akkor pontos, ha a feldolgozott elemek valódi **előtagot** alkotnak; az első köteget mindig lefuttatja, így egy kör mindig halad. Várható eredmény: 900 eszköz **egy-két körben, néhány tíz másodperc** alatt a 4–6 perc helyett (a szimulációban 895 eszköz 1 kör).
  4. **Biztonsági háló:** ha a párhuzamos út **egyetlen hívást sem tud elindítani** (nincs curl a hosztingon, vagy minden kapcsolat elhalt — `transport` számláló), akkor a **bevált soros útra esik vissza**, tehát a legrosszabb eset a mai működés, nem rosszabb. A `X-HUHS-Health` mostantól `curl=yes/no` és `curl_multi=yes/no` értéket is ad, hogy ez **feltöltés után azonnal ellenőrizhető** legyen.
  5. **Egy igazság a besorolásban:** az FCM-válasz értelmezése (`sent` / `dead` / `failed`) egyetlen `huhs_push_classify_response()` függvény, és a kérés törzse egyetlen `huhs_push_message_body()` — pont azért, mert a duplikált logika (lásd az engedélylista-esetet lentebb) már egyszer hibát okozott.
- **Ráadás javítás — a nyilvános cache felesleges ürítése:** a `huhs_invalidate_public_cache_on_option()` eddig **minden** `huhs_` opcióírásra ürítette a nyilvános cache-t. A `huhs_push_tokens` rekord viszont `updated_at`-et tartalmaz, ezért **minden app-telepítés/regisztráció kiürítette a teljes nyilvános cache-t**, a küldési lánc pedig körönként írta a `huhs_push_job_*` opciót. Ezek egyike sem változtat nyilvános tartalmat, ezért ki vannak véve. **Az app-végpontokra ez látható gyorsulás lehet.**
- **Ellenőrzés:** 41/41 PHP fájl parse-olható, a `tools/check-wp-meta-json.mjs` (meta/JSON + egyetlen engedélylista) zöld, és a **`tools/verify-push-delivery.mjs` 20/20** — új esetek a párhuzamos kötegelésre, az előtag-invariánsra, az 1-es párhuzamosság ≡ soros egyezésre, a transport-alapú visszaesésre és a hír-újrapróba mind a négy ágára.
- Csomag: `build/huhs-mobile-api-2.4.116.zip` (SHA-256 `6117BFB1B28678519581CFE1CCFF6552519A2FD6C0D0D4B4C80ACAD58C69A302`), forrás `.tmp-api-24115/huhs-mobile-api/`, 42 fájl, bájt-azonos. **A 2.4.115-öt is tartalmazza**, tehát ezt a csomagot kell feltenni a 2.4.115 helyére.

### Javítva — a nyilvános cache engedélylistája három példányban élt (2026-09-18, plugin 2.4.115)

- **Élő mérés közben talált második hiba:** a `/poll/active` **friss** (cache-miss) válasza `Cache-Control: public, max-age=300, stale-while-revalidate=60` fejléccel és **ETag nélkül** ment ki, miközben ugyanannak a végpontnak a cache-elt válasza helyesen `max-age=45` + ETag + `X-HUHS-Cache: early` volt.
- **Ok:** a `http-cache.php`-ban a nyilvános útvonalak engedélylistája **három helyen** szerepelt kézzel másolva. Amikor a 2.4.113-ban a `/poll/active` bekerült a `huhs_public_cache_route()`-ba, a másik kettőből kimaradt:
  1. `huhs_add_public_cache_headers()` (`rest_post_dispatch` 9999) — ez adja a **friss** válasz ETag/45 s fejlécét; ezért a friss válasz fejléctelen maradt, és **a hosting tette alá a maga 300 másodperces fejlécét**;
  2. `huhs_preserve_public_not_modified()` — ez őrzi meg a 304-et a REST-szerializáláson át; ezért a kérdőívnél a 304 nem érvényesült.
- **Következmény (a javítás előtt):** egy épp megnyíló vagy épp záruló kérdőív akár **5 percet** késhetett — nem a saját 120 s-os transientünk miatt, hanem a hosting 300 s-os fejléce miatt. Ez pontosan az a fajta hiba, amit mérés nélkül nem lehet megtalálni.
- **Javítás:** mindkét hely a közös `huhs_public_cache_route()`-ot hívja, tehát **egy engedélylista-igazság** van. A `tools/check-wp-meta-json.mjs` ezt **ellenőrzi is**: a javítatlan 2.4.113-on „az engedélylista 3 helyen szerepel" hibát ad, a 2.4.115-ön átmegy.
- **Új: a plugin verziója látszik a diagnosztikában** — `X-HUHS-Health: api=2.4.115 …`, kizárólag a titkos `huhs_diag=huhs-boot-probe-2026` markerrel. Ebből **élőben ellenőrizhető, hogy egy feltöltött csomag tényleg kicserélődött** (eddig erre nem volt mód: a `plugins=` lista csak könyvtárneveket ad, verziót nem).
- **ÉLŐ ÁLLAPOT a 2.4.114 feltöltése után:** `/poll/active` → `{"poll":null}` — **nincs nyitott kérdőív**, ezért a kártya nem jelenik meg az appban. A `huhs_poll_active_id()` csak **`publish` állapotú** és **nyitott időablakú** kérdőívet ad vissza, ezért a kérdőívet **közzé kell tenni**, a kezdésnek a múltban, a zárásnak a jövőben kell lennie. Ez nem hiba, hanem a beállítás hiánya.
- **Élő mérés ehhez:** a `poll/active` cache-elt válasza `early` + `max-age=45` + ETag (0,53 s), a `posts?per_page=1` pedig `fresh` + 45 + ETag — a cache-út tehát ép. A `max-age=300` fejlécet a **nem engedélylistázott** útvonalak kapják (`games/active`, `does-not-exist` 404), ez a hosting alapértéke.
- Csomag: `build/huhs-mobile-api-2.4.115.zip` (SHA-256 `BC9BDA30569F80B10BDBD1A66FCBB194D25B991DBFA1777D02D071C6899EC7C5`), forrás `.tmp-api-24115/huhs-mobile-api/`, 42 fájl, bájt-azonos. **A 2.4.114 forrása nem maradt meg külön mappában** (a munkamappa a 2.4.115-re lett átnevezve), mert a 2.4.115 mindent tartalmaz belőle; a 2.4.114 egy köztes javítás volt.

### Javítva — a WordPress post meta lenyeli a `json_encode` escape-ét (2026-09-18, plugin 2.4.114)

- **A tulajdonos észrevétele:** a WordPress adminban a kérdőív egyik válaszlehetősége `Utu00e1lom` alakban jelent meg `Utálom` helyett.
- **Az ok bizonyítva, nem sejtés:** az `update_post_meta()` → `update_metadata()` **`wp_unslash()`-t futtat a meta értékén** (mert a WordPress a `$_POST`-ot megslasheli). A `wp_json_encode()` viszont a nem-ASCII karaktereket `\uXXXX` alakra írja, és annak a backslashnek nincs `$_POST`-beli párja, amit a `wp_unslash()` visszaadhatna: **egyszerűen törli**. Így a tárolt érték `["Igen","Nem","Lehetne jobb","Utu00e1lom","Minek ez?"]` lett — **pontosan ez a szöveg jelent meg a képernyőképen**, és ez ment volna ki az appba is.
- **A hibaosztály szabálya:** ha a saját kódunk generál backslasht (bármilyen `json_encode`) és post metába írja, akkor kell **`wp_slash()`** a JSON köré, és kell **`JSON_UNESCAPED_UNICODE`**, hogy ne is keletkezzen `\uXXXX`. A `wp_slash()` és a meta-írás `wp_unslash()`-ja **pontosan kioltja egymást**, tehát a tárolt érték a `json_encode` nyers kimenete lesz. (Ugyanez a minta már régóta helyesen szerepelt a `games.php`-ban.)
- **Amit a javítás tesz (2.4.114):**
  1. **Mentés:** `wp_slash(wp_json_encode($options, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES))` — új adat sosem csonkul.
  2. **Olvasás:** `huhs_poll_repair_escapes()` visszaállítja a hiányzó backslasht, ezért a **régi, csonka adat is helyesen jelenik meg** a WP adminban és az appban. A minta az opcionális backslasht is elfogadja, tehát **idempotens**, a már helyes ékezetes szöveget nem rontja el.
  3. **Egyszeri migráció** (`init`, priority 20, `huhs_poll_escape_repair` jelzővel): a tiszta szöveget **visszaírja a tárolt metába**, ezért a tulajdonosnak **nem kell újramentenie a kérdőívet**. Olvashatatlan JSON-hoz nem nyúl, hogy egy hibás értéket ne írjon felül üres listával.
- **Ugyanez a hiba a három éves szavazás jelöltlistájában is benne volt** (`voting.php`, `_huhs_vote_candidates`): ott `JSON_UNESCAPED_UNICODE` volt, de `wp_slash()` nem — egy **idézőjel** a jelölt nevében olvashatatlan JSON-t adott volna, és a `json_decode()` `null`-t adva **az egész jelöltlista eltűnt volna**. Javítva. (Élő adat nem sérült: a mérés 0 hibát talált.)
- **ÉLŐ AUDIT — minden más rendben:** a `games/active`, `games/results/latest`, `posts`, `events`, `releases`, `artists`, `organizers`, `faq`, `achievements/badges`, `poll/active` végpontokat élőben lekértem, és **egyikben sincs `u00XX` csonkulás**. A `games.php` JSON-mentése (`wp_slash` + mindkét unescaped flag) már helyes volt; az `api-admin.php` (`ids`), `releases.php` (`artists`) és `meta-save.php` esetében a JSON **csak egész számokat** tartalmaz, ott backslash nem keletkezhet. A többi meta-írás `sanitize_text_field(wp_unslash($_POST[...]))`, ami a helyes minta.
- **Új, újrafuttatható ellenőrző: `tools/check-wp-meta-json.mjs`** (`node tools/check-wp-meta-json.mjs [plugin-mappa]`). Két dolgot csinál: (a) **forrás-lint** — végignézi a meta-írásokat, és elutasítja a `wp_slash()` nélküli vagy `JSON_UNESCAPED_UNICODE` nélküli `json_encode`-t (a csak-egész-számos esetek külön allowlistán vannak); (b) **futásidejű szimuláció** — lejátssza a `json_encode → update_post_meta wp_unslash → json_decode` láncot, és igazolja, hogy a 2.4.113 pontosan az `Utu00e1lom` szöveget adja, hogy a javítás visszaállítja az `Utálom` szöveget, hogy idempotens, és hogy az új mentési út idézőjellel, backslashsel és emojival is sértetlen. A **javítatlan 2.4.113 forráson szándékosan elhasal** (2 hiba), ezért ez a jövőben is elkapja ezt a hibaosztályt.
- Csomag: `build/huhs-mobile-api-2.4.114.zip` (SHA-256 `062E6402CFD3E82A05389874D70E95F0BCB5CE7297002062E0930CCAD778D7C8`), forrás: `.tmp-api-24114/huhs-mobile-api/`, 42 fájl, bájt-azonos, `/` elválasztó. A `.tmp-api-24113` (élő 2.4.113) érintetlen maradt. 41/41 PHP fájl parse-olható.

### Új funkció: Közvéleménykutatás — Kérdőív (2026-09-18, plugin 2.4.113)

- **Tulajdonosi kérés:** a WordPress adminban megadható **egy kérdés** és legfeljebb **10 válaszlehetőség**; **csak regisztrált** felhasználó szavazhasson; az eredmény **a WordPressben** tárolódjon **felhasználónév és e-mail nélkül**, csak az összesített számok; **állítható kezdő és záró dátum**; **publikus eredmény nem kell**; a főoldalon az **éves szavazás alatt** jelenjen meg; **kép nem kell**.
- **Tulajdonosi döntések:** (1) a kérdőív **csak a két dátum között** látszik az appban; (2) **egy fiók egyszer szavazhat**, és a szavazat **nem módosítható**.
- **Adatvédelem — ez a lényeg:** a WordPress **soha** nem tárol felhasználónevet, e-mail-címet vagy Firebase UID-t. Minden szavazat csak egy **sótolt ujjlenyomatot** hagy (`_huhs_poll_vote_<sha256>`), amiből a duplikáció kiszűrhető, de a szavazó nem azonosítható. A só (`huhs_poll_salt` opció) a szerveren marad, ezért a kliens **nem tud más nevében szavazni**.
- **Ki dönt az időablakról:** a `huhs_poll_window_state()` a WordPressben (`before` / `open` / `closed`), a webhely időzónájában. A `/poll/active` végpont **csak nyitott** kérdőívet ad vissza, ezért az app nem számol dátumot, és egy elállított készülék-idő nem tudja kitolni az ablakot. Hiányzó dátum → nyitott határ, hogy egy elgépelt dátum ne tegye használhatatlanná a kérdőívet.
- **Ki szavazhat:** a `pollVote` Firebase callable `requireRegisteredViewer(context)`-tel indul, tehát **névtelen (vendég) fiók nem szavazhat**. A callable a **hitelesített tokenből** veszi a UID-t, nem a kliens kéréséből, így egy fiók nem tud más nevében szavazni. (`optionIndex` nélkül hívva csak azt válaszolja meg, hogy ez a fiók szavazott-e már — ebből lesz a „Köszönjük" állapot.)
- **Hol van a szavazat:** `POST /poll/vote` és `POST /poll/status` a pluginben, `current_user_can('manage_options')`-szel védve, mert **csak a Firebase** hívja a WordPress application passworddel (ugyanaz a minta, mint a `/releases/{id}/play-products`). Az egyediség `add_post_meta(..., true)`-val történik, a szavazatszám pedig a szavazat-sorokból **számolódik újra**, ezért nincs külön számláló, ami elcsúszhatna.
- **Publikus eredmény nincs:** külön adminoldal (HUHS Mobile → *Kérdőív eredményei*) mutatja a számokat és az arányokat; publikus eredmény-végpont szándékosan nem készült.
- **Cache:** a `/poll/active` bekerült a szerveroldali cache engedélylistájába (a lassú boot miatt), ezért egy épp kinyíló vagy épp záruló kérdőív **legfeljebb 120 s-ig** késhet. Ez tudatos tradeoff.
- **Kliens:** `lib/models/poll.dart`, `lib/services/poll_service.dart`, `lib/providers/poll_provider.dart`, `lib/widgets/poll_card.dart`, bekötve a `home_screen.dart`-ban **közvetlenül az éves szavazás kártyája alá**. A kártya magától eltűnik, ha nincs nyitott kérdőív, és vendégnek regisztrációs figyelmeztetést mutat. A `RadioListTile` helyett szándékosan `ListTile` + rádió ikon van, mert ebben a Flutter-verzióban a Material radio API `RadioGroup`-ra migrál (`deprecated_member_use`).
- Csomag: `build/huhs-mobile-api-2.4.113.zip` (SHA-256 `FB75635AC70C2F84EF22ACD8B312C9FCF24E15D61B8A2644BE7748955537BF5A`), forrás: `.tmp-api-24113/huhs-mobile-api/`. **A 2.4.112 forrása érintetlen maradt** (`.tmp-api-24112`), mert az van élesben.
- **Ami hátra van:** a kliensoldali kártya **a következő AAB-buildben** élesedik. Addig a `/poll/active` végpont nem is létezik a telepített pluginban, ezért a kliens `null`-t kap és nem jelenít meg semmit — nincs hibaüzenet.
- **Ellenőrzés:** 41/41 PHP-fájl parse-olható, `flutter analyze` tiszta, `flutter test` **158/158** (4 új modellteszttel), függvény-tesztek 9/9, `node --check` OK, `pollVote` élesítve.

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
