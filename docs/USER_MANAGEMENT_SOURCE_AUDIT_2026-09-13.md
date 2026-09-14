# Felhasználókezelési forrásaudit — Hungarian Hardstyle

**Dátum:** 2026-09-13  
**Vizsgált állapot:** a helyi, jelenlegi és nem commitolt módosításokat is tartalmazó forrásfa  
**Projektverzió:** `1.0.0+300`  
**Hatókör:** Flutter Auth- és profilfolyamok, Firebase Auth, Cloud Functions, Firestore Rules, SMTP/action linkek, session-életciklus, törlés, tiltás és kapcsolódó tesztek

Az audit kizárólag a meglévő forrásfájlokat vizsgálta. Alkalmazás- vagy backendkód, Firebase-konfiguráció és éles adat nem módosult; deploy és új build nem történt.

## Összegzés

**Pontszám: 70/100.**

Pontozási alap: Auth és session 17/20, profil- és jogosultságvédelem 12/25, e-mailes identitásfolyamok 10/15, törlés/tiltás 12/15, adatvédelem és függőségek 9/15, automatizált bizonyíték 10/10.

Az alapvető e-mailes és Google Auth-folyamatok, a sessionfigyelés, az explicit tiltási marker, az idempotens szerveroldali névfoglalás és a törlési újrapróbálás jó irányban vannak. A forrás azonban jelenleg nem tekinthető teljesen kiadáskésznek, mert a Firestore Rules közvetlen kliensírással megkerülhetővé teszi az első névfoglalást, két biztonsági értesítés SMTP-hiba után végleg elveszhet, és a közvetlen Nodemailer-függőséghez ismert magas súlyosságú sebezhetőség tartozik.

## Bizonyítékszintek

- **E1 — forrásbizonyíték:** konkrét végrehajtási ág vagy Rules-feltétel.
- **E2 — automatizált teszt:** helyben sikeresen lefuttatott Flutter- vagy Node-teszt.
- **E3 — Emulator-integráció:** Firebase Auth, Firestore és Functions Emulator közös futása.
- **N:** nincs viselkedési bizonyíték; csak statikus vagy külső ellenőrzésre váró állítás.

## Magas súlyosságú megállapítások

### H1 — Az első profil közvetlenül létrehozható a szerveres névfoglalás megkerülésével

**Bizonyíték:** E1  
**Érintett:** `firestore.rules:91-133`, `functions/index.js:1165-1235`

A `community_profiles/{userId}` create szabály engedi, hogy bármely nem törölt, hitelesített felhasználó a saját UID-ján közvetlenül létrehozza a profilt és megadja a `displayName` mezőt. A szabály csak a 2–40 karakteres hosszt ellenőrzi; nem követeli meg, hogy a név a `claimDisplayName` callable tranzakcióján és a `display_name_index` foglalásán keresztül jöjjön létre.

Következmény:

- megkerülhető a név egyedisége;
- megkerülhető a szerveroldali karakter- és tiltottkifejezés-ellenőrzés;
- duplikált vagy megtévesztő nyilvános profilnév hozható létre;
- a kliensoldali profilkapu érvényes szerepkörrel teljes profilként fogadhatja el a közvetlenül írt dokumentumot.

**Legkisebb biztonságos javítás:** a kliens közvetlen profil-create műveletének tiltása, és az első dokumentum létrehozásának kizárólag a `claimDisplayName` szerveroldali tranzakción keresztüli engedése. A jelenlegi kliensfolyam már előbb hívja a `claimDisplayName` callable-t, ezért a későbbi profilmező-mentés update maradhat. Ezt tényleges Rules Emulator-teszttel kell igazolni.

### H2 — E-mail-váltási és admin törlési értesítés SMTP-hiba után végleg elveszhet

**Bizonyíték:** E1  
**Érintett:** `functions/index.js:140-163`, `functions/index.js:222-246`, `functions/index.js:2644-2674`

A `sendIdentityEmailOnce` SMTP-hibánál `{ sent: false }` eredményt ad vissza, nem dob hibát. A `syncEmailChange` előbb törli a `previousEmail` mezőt, majd figyelmen kívül hagyja a küldés eredményét. Így sikertelen SMTP-kísérlet után a régi cím már nem áll rendelkezésre egy későbbi újrapróbáláshoz.

Az admin törlési értesítésnél hasonló a helyzet: az Auth-fiók már törlődik, a helper sikertelen eredményét a hívó nem ellenőrzi, a munkarekord pedig csak címzetthasht tárol. A következő próbálkozáskor a címzett teljes címe már nem feltétlenül rekonstruálható.

**Következmény:** a felhasználó nem kapja meg a biztonsági értesítést, miközben a művelet sikeresnek látszik.

**Legkisebb biztonságos javítás:** az értesítéshez szükséges címet rövid TTL-lel, szerveroldali és kliens számára olvashatatlan retry-rekordban megőrizni; a `sent`, `smtp_accepted`, `failed` és `in_flight` eredményeket a hívóban külön kezelni. A fióktörlést SMTP-hiba továbbra se fordítsa vissza.

### H3 — A közvetlen Nodemailer-függőség auditja magas súlyosságú sebezhetőséget jelez

**Bizonyíték:** `npm audit --omit=dev --json`  
**Érintett:** `functions/package.json:12`, `functions/package-lock.json:2434`, `functions/email_service.js`

A telepített verzió `nodemailer 7.0.13`. Az npm audit egy közvetlen, összesítve **high** súlyosságú függőségi találatot jelentett, többek között `GHSA-p6gq-j5cr-w38f` és `GHSA-2x7j-588g-ccc2` azonosítókkal. A javasolt javított verzió `10.0.9`, amely főverzióváltás.

A jelenlegi kód nem használ `raw`, URL/file attachment vagy OAuth2 transport opciót, ezért több advisory közvetlen kihasználhatósága korlátozott. Ettől a sérülékeny közvetlen függőség ténye megmarad.

**Legkisebb biztonságos javítás:** külön backendkörben Nodemailer 10-re frissíteni, majd SMTP `verify()`, regisztrációs megerősítés, jelszó-reset, e-mail-váltási értesítés és admin törlési értesítés regressziós tesztjeit lefuttatni.

## Közepes súlyosságú megállapítások

### M1 — Az új jelszó-visszaállítási kérés 24 órán át régi sikereredményt kaphat új levél nélkül

**Bizonyíték:** E1  
**Érintett:** `functions/index.js:166-181`, `functions/index.js:267-305`

A deduplikáció csak az `auth-verification` típust engedi újra 60 másodperc után. Minden más típus — így az `auth-passwordReset` is — egy már `sent` munkarekordnál `already_sent` eredményt ad. A munkarekord 24 óráig marad meg, a kulcs pedig azonos címhez és actiontípushoz stabil.

Ez azt jelenti, hogy a felhasználó a rate limit betartása mellett is kaphat sikeres API-választ úgy, hogy nem készül új action link és nem indul új SMTP-küldés.

**Javaslat:** a password reset külön, rövid deduplikációs ablakkal működjön; külön felhasználói újrakérés új Firebase action linket és tényleges új SMTP-kísérletet indítson.

### M2 — App Check minden callable Functionnél kikapcsolt

**Bizonyíték:** E1, E2  
**Érintett:** `functions/index.js` callable exportok

Az `enforceAppCheck: false` szándékosan minden callable útvonalon megmaradt. Az Auth- és adminjogosultság-ellenőrzések nagy része ettől függetlenül szerveroldali, tehát ez nem automatikus jogosultságmegkerülés. Ugyanakkor az anonim vagy nyilvános callable végpontok könnyebben automatizálhatók és költség-/abuse-kockázatot jelentenek.

**Állapot:** elfogadott kompatibilitási kockázat. Enforcementet csak készülékes, Play Integrity/App Check kompatibilitás igazolása után szabad bekapcsolni.

### M3 — Nincs tényleges Firestore Rules viselkedési teszt

**Bizonyíték:** E1, E2, E3

A `functions/security-permissions.test.cjs` reguláris kifejezésekkel ellenőrzi a forrásszöveget. A `registration.integration.test.cjs` Admin SDK-val ír Firestore-ba, ezért megkerüli a Rules-t. A repositoryban nincs `@firebase/rules-unit-testing` alapú teszt.

Így a profil-create bypass, a profilupdate-mezőlista, a privát üzenetek és a törölt UID-k Rules-viselkedése nincs futásban bizonyítva.

**Javaslat:** egy minimális Rules Emulator-tesztcsomag szükséges legalább ezekre: közvetlen profil-create elutasítása, saját profil engedélyezett update-je, más UID profiljának tiltása, védett névmező tiltása, törölt UID tiltása és privátüzenet-blokk.

### M4 — A rate-limit rekordoknak nincs forrásban látható megőrzési vagy törlési útvonala

**Bizonyíték:** E1  
**Érintett:** `functions/index.js:600-613`, `firestore.rules`

Az `allowCall` minden percben új `rate_limits` dokumentumot készít, benne nyers UID-val, kulccsal és időbucket értékkel. `expiresAt` nincs, és a cleanup nem törli ezt a kollekciót. A Rules nem enged klienshozzáférést, de a szerveroldali adat korlátlanul nőhet.

**Javaslat:** `expiresAt` mező és célzott TTL-policy vagy scheduleres törlés, kizárólag a `rate_limits` kollekcióra.

### M5 — A fióktörlés globális collection-group beolvasást végez

**Bizonyíték:** E1  
**Érintett:** `functions/index.js:2390-2478`

Minden törléskor lefut a `db.collectionGroup('users').get()`, majd a kód kliensoldali ciklusban szűri az összes eseményrészvételi, meetup- és ratingdokumentumot. Ez a jelenlegi adatmennyiségnél működhet, de növekedéskor timeoutot, magas olvasási költséget és hosszú `cleanup_pending` állapotot okozhat.

**Javaslat:** a UID alapján lekérdezhető, indexelt tulajdonosi mezők használata; a globális scan csak célzott legacy fallback legyen.

## Alacsony súlyosságú megállapítások

### L1 — A védett főadmin törlési kísérlete előtt létrejön a pending rekord

**Bizonyíték:** E1  
**Érintett:** `functions/index.js:2582-2601`

Az `account_deletions/{uid}` `pending` rekordja a célfiók lekérése és a főadmin-védelem előtt jön létre. A tiltott törlési kísérlet így aktív Auth-fiókhoz lejárat nélküli pending rekordot hagyhat, amelyet a scheduler minden futáskor átugrik.

**Javaslat:** a célfiók és a főadmin-védelem ellenőrzése előzze meg a pending rekord létrehozását.

### L2 — A Hosting sikeroldal művelettípus-felismerése nem bizonyított

**Bizonyíték:** E1, N  
**Érintett:** `functions/index.js:20`, `functions/index.js:279-284`, `hosting/index.html:21-32`

A Hosting oldal a saját URL `mode` paramétere alapján választ szöveget, miközben az action-link `continueUrl` értéke csak a domain gyökere. A forrásból nem bizonyítható, hogy a Firebase Auth handler a `mode` értéket továbbadja a gyökéroldalnak. Emiatt a specifikus „Köszönjük!” szöveg helyett a generikus szöveg jelenhet meg.

**Javaslat:** valódi action linkkel ellenőrizni a végső URL-t; szükség esetén explicit, művelettípushoz kötött continue URL vagy saját támogatott action handler használata.

### L3 — Az SMTP feladó formátuma és Reply-To nincs explicit rögzítve

**Bizonyíték:** E1  
**Érintett:** `functions/email_service.js:41-58`

A levél `from` értéke közvetlenül `HUHS_SMTP_USER`, `replyTo` nincs megadva. Ez nem garantálja forrásból a `Hungarian Hardstyle <info@hungarianhardstyle.hu>` megjelenést és az explicit Reply-To fejlécet.

**Javaslat:** a feladó megjelenített nevét és a Reply-To címet szerveroldali konstansként rögzíteni, miközben az SMTP-hitelesítő adat továbbra is secret marad.

## Igazoltan megfelelő részek

- Az e-mail-regisztráció eligibility-ellenőrzés után hoz létre Auth-fiókot, és a fiók megmarad SMTP-hiba esetén (`community_service.dart:422-540`).
- A megerősítetlen e-mailes fiók beléphet; a kliens figyelmeztetést és újraküldést kínál (`community_service.dart:604-637`).
- A Google-belépés nem követel külön e-mail-megerősítést, és meglévő saját profilnevet nem ír felül (`community_service.dart:784-923`).
- A Google displayName csak validálás és szerveres névfoglalás után kerül profilba; e-mail-címből nem képződik profilnév.
- A `claimDisplayName` szerveroldali tranzakciója idempotens azonos UID és azonos név esetén; a tényleges névváltási limitet csak eltérő, korábbi nem-placeholder név fogyasztja (`functions/index.js:1182-1225`).
- A profilkapu név + érvényes szerepkör alapján dönt; kép, bio és social link nem kötelező (`profile_access_gate.dart:3-9`).
- A sessionfigyelő nem tekinti a hálózati hibát törölt fióknak, a távoli Auth-törlést legfeljebb 60 másodperces periódussal és foreground-visszatéréskor ellenőrzi (`session_watcher.dart`).
- Saját törléshez nem szükséges teljes profil; a backend a hitelesített saját UID alapján engedélyez (`community_service.dart:2346-2357`, `functions/index.js:2552-2582`).
- A fióktörlés Auth-törlés után retryképes pending állapotot tart fenn, a lezárt rekord 48 órás `expiresAt` értéket kap.
- Önkéntes és egyszerű admin törlés nem jelent identity bant; csak strukturált `administrator-ban` vagy `abuse` marker blokkol újraregisztrációt.
- A személyes blokkolás külön `blocked_users` rendszer; a regisztrációs identity marker logikája nem értelmezi személyes blokkolásként.
- Jelszó nem kerül Firestore-ba, SharedPreferences-be vagy logba. A TOTP secret a platform secure storage-ban marad.
- A publikus profilprojekció nem tartalmaz e-mailt vagy FCM tokent; a `public_profiles` kliensoldalon csak olvasható.
- A privát FCM-tokenek `private_user_data/{uid}` alatt vannak, és a Rules csak a saját UID olvasását/írását engedi.
- Az SMTP TLS tanúsítvány-ellenőrzése aktív (`rejectUnauthorized: true`), a jelszó Functions secretből érkezik.
- A levéldiagnosztika operation ID-t és tisztított SMTP-kódot használ; teljes cím, action link, token vagy levéltartalom nem kerül az alkalmazás saját logjába.

## Teszteredmények

| Ellenőrzés | Eredmény | Mit bizonyít |
|---|---:|---|
| `flutter analyze --no-pub` | sikeres | nincs analyzer-hiba |
| `flutter test` | 102/102 sikeres | widget- és egységtesztek |
| Node célzott tesztek | 38/38 sikeres | Functions-forrásinvariánsok és segédfüggvények |
| Auth + Firestore + Functions Emulator | 10/10 sikeres | regisztráció, névfoglalás, eligibility és markerlogika |
| `node --check` | sikeres | Functions és e-mail szolgáltatás szintaxisa |
| `git diff --check` | sikeres | nincs whitespace-hiba; csak LF/CRLF figyelmeztetések |
| `npm audit --omit=dev` | 1 high | Nodemailer-függőségi kockázat |

Fontos korlátok:

- A Flutter `community_service_test.dart` több Auth/Google ellenőrzése forrásszöveg-keresés, nem végrehajtott viselkedési teszt.
- A ProfileAccessGate teszt a valódi kaput használja, de nem hajtja végre a teljes Google Auth → névfoglalás → Firestore snapshot → kapufeloldás láncot.
- A regisztrációs integráció Admin SDK-val ír Firestore-ba, ezért Firestore Rules-t nem bizonyít.
- A Functions Emulator a konfigurált Node 22 helyett a gép Node 24 runtime-ját használta; a teszt sikeres, de a production runtime-paritás nem teljes.
- Éles Functions-revíziót, Hosting-deployt, TTL-policyt, SMTP-kézbesítést és készülékes navigációt ez a forrásaudit nem ellenőrzött.

## Prioritási sorrend

1. Firestore Rules-ban lezárni a közvetlen profil-create névfoglalás-bypassát, majd tényleges Rules Emulator-tesztet hozzáadni.
2. Az e-mail-váltási és admin törlési értesítések címzettjét retryképes, rövid életű szerveroldali munkában megőrizni.
3. Nodemailer 10 kompatibilitási frissítés és célzott SMTP-regresszió.
4. A password-reset deduplikációt külön újrakérési ablakkal javítani.
5. `rate_limits` TTL/cleanup bevezetése.
6. A törlési globális collection-group scan fokozatos kiváltása indexelt UID-lekérdezésekkel.
7. A Hosting action-link végső URL-jének viselkedési ellenőrzése.

## Kiadási döntés

**Zárt tesztre alkalmas, szélesebb vagy éles kiadásra a magas súlyosságú pontok lezárása előtt nem ajánlott.**

A legsürgősebb hiba nem a normál kliensfolyamatban látszik, hanem a bizalmi határon: egy módosított kliens közvetlen Firestore create művelettel megkerülheti a névfoglalási callable-t. Ezt Rules-oldalon kell lezárni; kliensoldali validáció önmagában nem védelem.
