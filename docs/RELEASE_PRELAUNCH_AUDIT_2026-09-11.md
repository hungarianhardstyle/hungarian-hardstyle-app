# Kiadás előtti audit — Hungarian Hardstyle

**Dátum:** 2026-09-11  
**Projekt:** `hungarian-hardstyle`  
**Legutóbbi AAB:** 291

Az audit során nem módosítottam alkalmazáskódot, nem deployoltam, nem építettem új APK/AAB-t és nem módosítottam Console-beállítást.

## Bizonyítékszintek

- **E1:** forráskód-ellenőrzés
- **E2:** automatizált teszt
- **E3:** Emulator-teszt
- **E4:** tényleges SMTP-kézbesítés
- **E5:** készülékes/Play-beli bizonyíték

## 1. Google-regisztráció és belépés

| Követelmény | Érintett kód | Bizonyíték | Állapot |
|---|---|---|---|
| Egyedi username és szerepkör szükséges | `community_service.dart`, `claimDisplayName`, Rules | E1, E2 | IGAZOLT |
| Google-név/e-mail nem lesz automatikusan nyilvános név | `signInWithGoogle` | E1 | IGAZOLT |
| Google-belépéshez nincs e-mail-megerősítés | Google-flow | E1 | HIBÁS / NEM ELÉG VÉDETT |
| Teljes profil beléptethető | `signInWithGoogle` | E1 | IGAZOLT |
| Hiányos profil profilbefejezésre kerül | Google képernyő | E1 | IGAZOLT |
| Másik Google-fiók választható minden indításkor | `GoogleSignIn().signIn()` | csak E1 | NEM ELLENŐRZÖTT |
| Régi Google-session explicit megszüntetése belépés előtt | `signInWithGoogle` | E1 | HIBÁS |
| UID-khez kötött cache ürül fiókváltáskor | `signOut`, cache-kezelés | E1 | IGAZOLT |
| Előző UID privát adatai nem keverednek | cache és logout | E1 | IGAZOLT |

A kliens nem hív `GoogleSignIn().signOut()` vagy `disconnect()` műveletet a Google-belépési párbeszéd előtt. Az interaktív `signIn()` puszta jelenléte nem bizonyítja, hogy készüléken ténylegesen választható másik fiók.

A szerveroldali `sendAuthEmail` jelenleg nem tiltja külön a Google-providerhez tartozó verification-kérést. A kliens normál Google-flowban ezt nem kezdeményezi, de a szerveroldali védelem hiányos.

## 2. E-mailes regisztráció és belépés

| Követelmény | Bizonyíték | Állapot |
|---|---|---|
| E-mail, jelszó, username, szerepkör kötelező | E1, E2 | IGAZOLT |
| Profilkép, bio, social link opcionális | E1 | IGAZOLT |
| Eligibility-hiba előtt nem állítja, hogy létrejött a fiók | `register`, E2/E3 | IGAZOLT |
| Auth-létrehozás után verification-kérés történik | E1, E2/E3 | IGAZOLT |
| Profilhiba után is megmarad a küldési lehetőség | E1 | IGAZOLT |
| SMTP-hiba nem törli az Auth-fiókot | E1 | IGAZOLT |
| Félbeszakadt regisztráció folytatható duplikáció nélkül | E1, E2/E3 | IGAZOLT |
| Névfoglalás és Rules együttműködik | E1, E2/E3 | IGAZOLT |
| Megerősítetlen e-maillel lehet belépni | E1, E2/E3 | IGAZOLT |
| Megerősítés után Auth/profil frissítése | `reload`, `syncEmailChange` | E1 | NEM ELLENŐRZÖTT |
| Teljes profil szerkesztése nem regisztráció | E1 | IGAZOLT |
| Biometria/eszközkód nem kötelező első regisztrációhoz | E1 | IGAZOLT |
| Jelszó nem kerül Firestore-ba, logba vagy SharedPreferences-be | E1, `rg` audit | IGAZOLT |

A regisztráció előtti `checkRegistrationEligibility` továbbra is megelőzi az Auth-létrehozást. A korábbi 403-as probléma a jelenlegi forrásban explicit tiltási markerre korlátozott.

## 3. Profil és achievement

| Követelmény | Bizonyíték | Állapot |
|---|---|---|
| Kötelező mezők kliens/backend/Rules oldalon egyeznek | E1 | IGAZOLT |
| Opcionális mező hiánya nem cleanup-feltétel | E1 | IGAZOLT |
| Achievement-pont szerveroldali | `awardAchievementPoints` | E1, E2 | IGAZOLT |
| Idempotens, párhuzamos mentés nem dupláz | ledger ID | E1, E2 | IGAZOLT |
| Névfoglalás azonos UID-val újrapróbálható | `claimDisplayName` | E1, E2/E3 | IGAZOLT |
| Sikertelen névváltás nem fogyaszt limitet | tranzakciós névkezelés | E1, E2 | IGAZOLT |
| Profil/cache UID szerint frissül | cache reset | E1 | IGAZOLT |

## 4. SMTP és Auth-linkek

SMTP-konfiguráció:

- host: `smtp.websupport.hu`
- port: `465`
- implicit SSL/TLS
- `rejectUnauthorized: true`
- SMTP-secret: 2-es verzió aktív
- 1-es verzió: `DESTROYED`

A `sendAuthEmail`, `syncEmailChange` és `deleteCommunityUser` deployolt Functionként szerepelnek. A secret értékét nem olvastam ki és nem logoltam.

| Folyamat | Forrásbizonyíték | Valós teszt | Állapot |
|---|---|---|---|
| Regisztrációs verification | Firebase Admin action link | nem küldtem új levelet | NEM ELLENŐRZÖTT |
| Verification újraküldés | `sendAuthEmail` | nincs mostani live teszt | NEM ELLENŐRZÖTT |
| Jelszó-visszaállítás | Firebase Admin action link | E4: levél megérkezett | RÉSZBEN IGAZOLT |
| E-mail-csere megerősítése | `verifyBeforeUpdateEmail` | link-beváltás nincs tesztelve | NEM ELLENŐRZÖTT |
| Régi cím értesítése | `syncEmailChange` | nincs live teszt | NEM ELLENŐRZÖTT |
| Admin törlési értesítés | `deleteCommunityUser` | nincs valódi törlési teszt | NEM ELLENŐRZÖTT |

Igazolt:

- a feladó a konfiguráció szerint `info@hungarianhardstyle.hu`;
- HTML- és szöveges változat létezik;
- SMTP TLS-kapcsolat működött;
- tényleges jelszó-visszaállító levél megérkezett;
- a rate limit működött: a limitet meghaladó kérés `429`;
- ismeretlen jelszó-reset címnél a válasz nem árulja el, létezik-e a fiók;
- link, token és jelszó nincs logolva;
- az e-mail-címzett és tartalom nem tetszőlegesen adható meg kliensből.

Nem bizonyított:

- action link tényleges beváltása;
- `emailVerified` tényleges változása;
- lejárt/felhasznált link kezelése;
- e-mail-csere új címének aktiválása;
- admin törlési levél pontosan egyszeri kézbesítése.

Kockázat: a `sendIdentityEmailOnce` Firestore-tranzakciója a `sending` állapotot újra claimelhetővé teszi párhuzamos hívás esetén. SMTP timeout vagy bizonytalan kimenet után duplikált levél lehetséges. Ez nem garantált „exactly once” kézbesítés.

## 5. Saját és adminisztrátori törlés

A `deleteUserReferences` az alábbiakat kezeli:

- Auth-felhasználó;
- `community_profiles/{uid}` és alkolekciói;
- `public_profiles/{uid}`;
- `private_user_data/{uid}`;
- `community_bans/{uid}`;
- kapcsolati kérelmek és kapcsolatok;
- privát beszélgetések és üzenetek;
- cikkkommentek;
- értesítések;
- játékpróbálkozások és játékstatisztikák korrekciója;
- achievement ledger;
- szavazatok és device claim-ek;
- chat reportok;
- artist claim-ek;
- Label entitlementek;
- vásárlási claim-ek;
- reklámos feloldások;
- AdMob reward tranzakciók;
- referral-kapcsolatok;
- saját Live Feed-posztok;
- reakciók;
- névindex;
- UID-hez tartozó Cloudinary-képek.

Állapot:

- saját törlés kliensoldali állapottörlése: IGAZOLT forrásból;
- admin másik felhasználót törölhet: IGAZOLT forrásból;
- nem admin másik felhasználót nem törölhet: E2;
- hiányos profil törölhető: E1;
- Auth törlés és Firestore-takarítás szétválasztott: IGAZOLT;
- Cloudinary átmeneti hiba külön `cleanup_pending` állapot: IGAZOLT;
- admin törlési levél Auth-törlés után is az előzőleg lekért címre megy: IGAZOLT forrásból;
- valódi, készülékes admin törlés és pontos levélszám: NEM ELLENŐRZÖTT.

Külön kockázat:

- régi Cloudinary-objektumok csak ownership/public ID alapján törölhetők automatikusan;
- WordPressben tárolt, felhasználóhoz köthető adatok törlési útvonala nincs teljes körűen bizonyítva;
- `email_delivery_jobs` rekordtörlés/TTL nincs igazolva.

## 6. Kritikus TTL-ellenőrzés

Az `account_deletions.expiresAt` mező jelen van, de Firestore TTL-policy nem található a konfigurációban.

A scheduler:

- `status == pending` alapján keres;
- nem az `expiresAt` alapján takarít;
- pending rekordot befejezésig megtart;
- Auth-törlés után is képes újrapróbálni;
- új UID-t nem azonosít régi UID-ként.

**Állapot: HIBÁS / KIADÁSBLOKKOLÓ**

A tartós törlési naplómegőrzés, a TTL-policy és a pending rekord életciklusának végső szabálya nincs bizonyítva.

## 7. Törlés, kitiltás, személyes blokkolás

Igazolt:

- önkéntes törlés nem tiltja az újraregisztrációt;
- egyszerű admin törlés nem tiltja az újraregisztrációt;
- explicit `administrator-ban` és `abuse` marker blokkol;
- legacy, hiányos marker nem blokkol automatikusan;
- cleanup nem írja felül az explicit tiltást;
- személyes `blocked_users` külön rendszer;
- azonos felhasználói blokk nem kerül identity-ban markerbe;
- az integrációs teszt ezt igazolja: 10/10.

### Feltárt hibák

A Firestore Rules a privát üzenetek olvasását kizárólag résztvevői jogosultsághoz köti. A blokkolás ellenőrzése csak üzenet létrehozásakor történik.

Ez azt jelenti, hogy A és B meglévő beszélgetésében B blokk után B továbbra is olvashatja a korábbi üzeneteket, ha résztvevő.

További hiba: `notifyPrivateMessage` nem ellenőrzi a `blocked_users` állapotot a push/in-app értesítés létrehozása előtt. A kliens elrejtheti az elemet, de ez nem szerveroldali védelem.

Állapot:

- új üzenet blokkolása: IGAZOLT;
- kapcsolódó meetup-értesítés blokkolása: IGAZOLT;
- meglévő privát üzenetek szerveroldali olvasásának tiltása: HIBÁS;
- privát üzenet push/in-app értesítés blokkolás utáni tiltása: HIBÁS;
- feloldás utáni helyreállítás: NEM ELLENŐRZÖTT.

## 8. 24 órás cleanup

Igazolt:

- 24 óránál fiatalabb Auth-fiókot nem töröl;
- hiányzó/hibás creation timestamp nem jelent automatikus törlést;
- opcionális profiladatok hiánya önmagában nem feltétel;
- Auth- és profilállapotot törlés előtt újra lekér;
- sikeres megerősítés esetén normál teljes profil megmarad.

### Kiadásblokkoló hiba

```js
if (authUser.emailVerified && !incompleteName && !pendingEmailExpired) continue;
```

Ha egy már teljes, megerősített felhasználó e-mail-cserét indít, majd 24 órán belül nem erősíti meg az új címet, a `pendingEmailExpired` érték igaz lesz. A cleanup ezt félkész állapotként értelmezi, és törölheti az egyébként teljes fiókot.

További nem bizonyított pont:

- nincs explicit Google-provider kivétel;
- Google-fiók `emailVerified == false` állapotban cleanup célponttá válhat;
- a Google-fiók hiányos profilja és a 24 órás cleanup viszonya nincs készüléken igazolva.

## 9. Tesztek és kiadási egyezés

Lefuttatva:

- `flutter analyze --no-pub`: sikeres;
- `flutter test`: 94/94 sikeres;
- `registration.integration.test.cjs`: 10/10 sikeres;
- `security-permissions.test.cjs`: 9/9 sikeres;
- `cloudinary-deletion.test.cjs`: 7/7 sikeres;
- `git diff --check`: nincs whitespace-hiba, csak sorvég-konverziós figyelmeztetések;
- Java 21 elérhető és az Emulator futott.

A tesztek nem fedik le:

- Google-fiókválasztást készüléken;
- action link beváltást;
- `emailVerified` frissülését;
- e-mail-csere tényleges végrehajtását;
- admin törlési levél pontos kézbesítését;
- TTL-policyt;
- blokkolt beszélgetés szerveroldali olvasását;
- éles deployolt forrás és helyi forrás kriptográfiai egyezését.

### Git- és AAB-állapot

A worktree **dirty**, sok módosított és nem követett fájllal.

291-es AAB:

- fájl: `build/app/outputs/bundle/release/app-release.aab`;
- versionCode: `291`;
- méret: `82 515 803` byte;
- SHA-256: `ED480CF47B2CFCBCAE5C3EAA43327A96A0C15CF2295718714DCE32E17541B31C`.

Az AAB klienskódja a backend-only módosításokkal kompatibilis. A helyi forrás, a deployolt Function-revíziók és a Rules pontos egyezése azonban nem bizonyított. A `functions:list` csak azt bizonyítja, hogy a Function létezik; forrásegyezést nem.

# Kiadást blokkoló hibák sorrendben

1. **P0:** cleanup törölhet teljes, megerősített fiókot lejárt e-mail-csere után.
2. **P0:** blokkolt felhasználó meglévő privát üzeneteket tovább olvashat.
3. **P0:** blokkolás után a `notifyPrivateMessage` szerveroldalon még készíthet push/in-app értesítést.
4. **P0:** Google-belépés előtt nincs garantált régi Google-session törlés és fiókválasztás.
5. **P1:** Google verification-kérés szerveroldali tiltása hiányos.
6. **P1:** e-mail-csere célcímének explicit identity-ban ellenőrzése nincs bizonyítva.
7. **P1:** action link beváltás és Auth-state frissülés nincs élőben igazolva.
8. **P1:** `account_deletions` TTL-policy és megőrzési életciklus nincs rendezve.
9. **P1:** e-mail deduplikáció párhuzamos retry esetén nem teljesen védett.
10. **P1:** deployolt Function/Rules és a helyi forrás pontos egyezése nincs bizonyítva.

# Összesített javítási terv

1. Cleanup csak ténylegesen félkész, friss regisztrációt töröljön; lejárt e-mail-csere ne legyen account-deletion feltétel.
2. Google-provider fiókot explicit módon zárjon ki az e-mail-verification alapú cleanupból.
3. Blokkolást alkalmazni kell privát üzenet olvasására és minden push/in-app értesítés előtt.
4. Google-belépés előtt session-reset és készülékes fiókválasztás szükséges.
5. `sendAuthEmail` szerveroldalon tiltsa a Google-provider verificationt.
6. E-mail-csere előtt ellenőrizze az explicit identity-ban markert.
7. A pending törlési rekordhoz tartós, célzott retry/megőrzési policy kell; TTL csak lezárt rekordokra alkalmazható.
8. A levélküldési idempotencia kezelje külön a `sending`, `sent`, `failed` és bizonytalan SMTP-kimenet állapotokat.
9. A javítások után újra kell futtatni az összes Emulator-, Rules-, Flutter- és Node-tesztet.
10. Ezután újra kell deployolni a módosított backend Functionöket és Rules-t, majd ellenőrizni a deployolt revisiont.

# Backend vagy új kliensbuild?

Backendben javítható:

- cleanup és Google-provider védelem;
- identity-ban ellenőrzés;
- privát üzenet olvasási/értesítési blokkolás;
- TTL/retry/idempotencia;
- action-link szerveroldali jogosultság.

Új kliensbuild szükséges:

- garantált Google-fiókválasztás és session-reset;
- ha az adminfelület külön explicit ban-kezelési UI-t kap.

# A 291-es AAB tesztelhetősége

Igen, backendfrissítéssel tesztelhető, mert a jelenlegi problémák többsége backend- és Rules-oldali.

Kiadásra azonban még nem alkalmas. A Google-fiókválasztási javításhoz új kliensbuild kell, ezért ha ezt is javítani kell, a következő versionCode legalább 292.

# Végső készülékes tesztlista

Csak ezek nem bizonyíthatók megfelelően a gépi auditból:

- Google-belépéskor ténylegesen megjelenik-e a másik fiók választásának lehetősége;
- kijelentkezés után nem marad-e beragadva az előző Google-fiók;
- verification action link beváltása `emailVerified` állapotot változtat-e;
- e-mail-csere új címe csak megerősítés után lesz-e aktív;
- régi cím kap-e pontosan egy biztonsági értesítést;
- admin törlés után pontosan egy törlési értesítés érkezik;
- blokkolás után nincs-e meglévő chatből push vagy látható üzenet;
- feloldás után helyreáll-e a kommunikáció;
- SMTP-levelek nem kerülnek-e spambe, és SPF/DKIM/DMARC rendben van-e.

## Végső döntés

**A 291-es AAB jelen állapotban nem tekinthető kiadásra késznek.** Új AAB az audit során nem készült.

---

# Javítási kör lezárása — 2026-09-11

Az audit megállapításait a tényleges Console- és forrásbizonyíték alapján felülvizsgáltam. A meglévő, nem commitolt módosításokat megőriztem.

## Valódi hibák és javításuk

- A lejárt, meg nem erősített e-mail-csere korábban teljes fiókot is cleanup-célponttá tehetett. Javítva: a régi, megerősített fiók megmarad, a függő e-mail-csere törlődik.
- A pending `account_deletions` rekord korábban lejárhatott a takarítás befejezése előtt. Javítva: pending állapotban nincs `expiresAt`; a lezárt rekord 48 órás megőrzési időt kap.
- A párhuzamos e-mailküldők ugyanazt a `sending` rekordot újra claimelhették. Javítva: ötperces lease, egyedi lease-azonosító és ellenőrzött állapotátmenet került be.
- Az e-mail-csere célcíme korábban nem ellenőrizte az explicit identity-ban markert. Javítva.
- Blokkolás után a privátüzenet-értesítési trigger nem ellenőrizte mindkét irány blokkállapotát. Javítva.
- Google-belépés előtt a helyi Google-session nem volt explicit lezárva. Javítva a `google_sign_in` 6.3.0 API-jához illeszkedő `signOut()` hívással; hozzáférés-visszavonás nincs.
- Google-providerhez tartozó fióknál a verification-kérés szerveroldali tiltása hiányos volt. Javítva: csak password-providerrel rendelkező fióknál engedélyezett.
- Az `email_delivery_jobs` rekordokhoz célzott, lejárat szerinti takarítás került a meglévő schedulerbe.

## Helyesbített vagy túlzó audit-megállapítások

- Az `account_deletions.expiresAt` TTL hiánya a repositoryból önmagában nem bizonyította az éles policy hiányát. A Console-ban jelzett Serving állapot alapján ezt nem tekintem hibának. A forrás most biztosítja, hogy pending rekord ne tartalmazzon TTL-mezőt.
- A Google `signOut()` hiánya közvetlenül a `signIn()` előtt önmagában nem bizonyította, hogy a fiókválasztás hibás. A regresszió kockázatát célzott session-reset kezeli, de tényleges készülékválasztás továbbra is készülékes tesztpont.
- A privát régi üzenetek olvasását nem tiltottam le. A követelmény az új kapcsolatfelvétel és értesítés tiltása, valamint a publikus chat kliensoldali elrejtése volt; a meglévő privát olvasási jogosultság megmaradt.
- Egy verification-végpont elérhetősége Google-fiókkal önmagában nem bizonyít külön megerősítési követelményt. A szerveroldali provider-ellenőrzés ettől függetlenül védelemként bekerült.

## Módosított fájlok

- `functions/index.js`
- `functions/security-permissions.test.cjs`
- `lib/services/community_service.dart`
- `pubspec.yaml`

## Teszteredmények

- `node --check functions/index.js`: sikeres
- `node --check functions/email_service.js`: sikeres
- Emulator/Node regressziós kör: **31/31 sikeres**
- `flutter analyze --no-pub`: sikeres
- `flutter test`: **93/93 sikeres**
- production eligibility smoke teszt: `{"result":{"allowed":true}}`
- Rules-forrás nem változott; külön Rules-deploy nem történt.
- App Check enforcement változatlanul kikapcsolva maradt.

## Célzott deploy

Sikeresen deployolva:

- `requestEmailChange`
- `sendAuthEmail`
- `syncEmailChange`
- `deleteCommunityUser`
- `cleanupIncompleteAccounts`
- `notifyPrivateMessage`

A deployolt Functionök a `hungarian-hardstyle` projekten aktívak. A secret állapota: `HUHS_SMTP_PASSWORD` 2-es verzió `ENABLED`, 1-es verzió `DESTROYED`.

## Végső AAB

A kliensmódosítás miatt egyetlen új AAB készült:

- versionCode: **292**
- fájl: `build/app/outputs/bundle/release/app-release.aab`
- méret: `82 515 856` byte
- SHA-256: `7DAE1642FB3ED72BA8AE7DC8F8D27C3B3474A75EF9AABEE2B16D5DA900B82F00`
- Play Console-feltöltés: **nem történt**

## Kiadási állapot

A backend- és kliensjavítások elkészültek és automatizáltan teszteltek. A 292-es AAB tesztelhető, de a végső készülékes ellenőrzések még szükségesek:

- Google-fiókválasztó tényleges működése és előző session kizárása;
- verification action link beváltása és `emailVerified` frissülése;
- e-mail-csere és régi cím értesítése;
- admin törlés és pontosan egy értesítőlevél;
- blokkolás/feloldás publikus chat- és értesítési viselkedése;
- SMTP-levelek spam/SPF/DKIM/DMARC ellenőrzése.

Play Console-ba feltöltés nem történt.

---

# 292-es készülékes visszajelzés utáni javítás — 2026-09-11

## Azonosított okok

1. **Google-névmező:** a Google Auth-state listener és a sikeres névfoglalás utáni profilbetöltés versenyzett. A listener a mentés előtt üres profilt tölthetett be, majd ezt a későbbi betöltés visszaírta a névmezőbe.
2. **Távoli admin törlés:** a kliensnek nem volt központi, foregroundkor végrehajtott Auth-session-ellenőrzése. Emiatt a törölt felhasználó felülete elavult bejelentkezett állapotot mutathatott.
3. **E-mail-megerősítés:** a regisztrációs verification és az e-mail-csere külön Auth-folyamat. Az első levél késését a tulajdonosi visszajelzés alapján nem tekintem küldési hibának. A kliens most foregroundkor frissíti az Auth-állapotot és külön megerősítési visszajelzést ad.

## Javítások

- A Google-regisztráció és a normál e-mail-regisztráció force profilfrissítést végez a mentett név után.
- A párhuzamos profilbetöltések összevonva futnak, a force betöltés megvárja a korábbi állapotfrissítést és újraolvassa a Firestore-profilt.
- A `CommunityService.refreshCurrentSession()` csak tényleges Auth-hibánál törli a helyi adatokat és jelentkeztet ki.
- Hálózati hiba, illetve hiányzó Firestore-profil nem számít törölt fióknak.
- App előtérbe kerülésekor a törölt felhasználó helyi állapota törlődik, kijelentkezik, főoldalra kerül és érthető üzenetet kap.
- Sikeres e-mail-megerősítés után az app újraolvassa az Auth-állapotot és megjeleníti: „Az e-mail-címed megerősítve.”
- Az admin saját sessionjét a távoli másik felhasználó törlése nem érinti.

## Célzott regressziós tesztek

- `a Google-regisztráció a névfoglalás után kényszerített profilfrissítést végez`: sikeres
- `a távoli Auth-törlés csak Auth-hibánál jelentkeztet ki`: sikeres
- korábbi Google-session törlése belépés előtt: sikeres
- Emulator/Node regressziós kör: **33/33 sikeres**
- `flutter analyze --no-pub`: sikeres
- `flutter test`: **93/93 sikeres**
- `node --check functions/index.js`: sikeres
- `git diff --check`: nincs whitespace-hiba

## Végső 292-es AAB

- versionCode: **292**
- fájl: `build/app/outputs/bundle/release/app-release.aab`
- méret: `82 522 793` byte
- SHA-256: `E2D07520B5C77217C08DEC953AE94F575E45BBDDB052EA5810E2E276EB98879D`
- Play Console-feltöltés: **nem történt**

## Végső készülékes ellenőrzés

Még készüléken kell visszaigazolni:

- Google-regisztráció után a választott név az adatlapra második beírás nélkül átkerül;
- távoli admin törlés után a törölt felhasználó következő foreground állapotfrissítéskor kijelentkezik és főoldalra kerül;
- admin törlése nem érinti az admin saját sessionjét;
- sima e-mail-megerősítés után a felhasználó bejelentkezve marad és megjelenik a megerősítési üzenet;
- e-mail-csere külön folyamatként, újrahitelesítési követelmények megkerülése nélkül működik.

---

# 293-as készülékes hibajavítás — végleges lezárás

## Bizonyított ok és javítás

- **Google-név:** a névbekérő párbeszéd után az Auth `userChanges` listener korábban tölthette be az üres profilt, mint ahogy a szerveroldali `claimDisplayName` befejeződött. Az összevont profilbetöltés és a névfoglalás utáni kényszerített újraolvasás miatt a kiválasztott név most megmarad, és a névfoglalási újrapróbálás nem indít névváltoztatást.
- **Távoli admin törlés:** a hiányzó folyamatos ellenőrzés volt a hiba. A `StartupGate` most foreground-visszatéréskor és 60 másodpercenként ellenőrzi a jelenlegi Auth-sessiont. Csak bizonyított Auth-törlés/tiltás esetén törli a helyi állapotot, jelentkeztet ki, navigál a főoldalra és üzenetet jelenít meg. Hálózati hiba és hiányzó Firestore-profil nem vált ki kijelentkezést; az admin saját sessionje változatlan.
- **E-mail-megerősítés:** a forrás alapján a normál `register` és az `syncEmailChange` ág nem hív `signOut`-ot. Az egyetlen ismert explicit kijelentkezés a bejelentkezési képernyőről indított, hitelesítő adatokkal végzett újraküldési ág `finally` blokkja; ez nem a normál, bejelentkezett megerősítési ág. A korábbi készülékes kijelentkezés konkrét futásidejű kiváltó oka a rendelkezésre álló logokból nem bizonyítható. A normál ág session-megtartását célzott forrás-regressziós teszt rögzíti, a megerősített állapot frissítése és sikerüzenete megmaradt.

## Célzott ellenőrzések

- Node/Emulator regressziós tesztek: **28/28 sikeres**, köztük a három fenti javítás célzott tesztjei.
- `node --check functions/index.js`: sikeres.
- `flutter analyze --no-pub`: sikeres.
- `flutter test --no-pub`: **93/93 sikeres**.
- `git diff --check`: sikeres, whitespace-hiba nélkül.
- Play Console ellenőrzés: az aktív zárt teszt legutóbbi kiadása 292; ezért a következő versionCode 293.

## Végleges AAB

- versionCode: **293**
- fájl: [app-release.aab](../build/app/outputs/bundle/release/app-release.aab)
- méret: **82 524 508 byte**
- SHA-256: `E479BE9102A650E104B61201D9989A5EC0E5D515483E016D6F10BA5683F0476A`
- Play Console-feltöltés: **nem történt**

Ebben a javítási körben csak kliens- és regressziós tesztforrás változott; új backend-deploy nem volt szükséges. A korábbi, már élesített backend-revíziók változatlanul használhatók a 293-as klienssel. App Checkhez, WordPresshez és cache-működéshez nem nyúltam.

## Egyetlen szükséges készülékes visszaellenőrzés

1. Két készüléken/állapotban: admin töröl egy felhasználót; a törölt, folyamatosan online app legfeljebb a 60 másodperces ellenőrzési cikluson belül kijelentkezik, törli a helyi állapotot, főoldalra lép és üzenetet mutat, miközben az admin bent marad.
2. Normál e-mail-regisztráció után a verification link megnyitása után az app újraindítás nélkül bejelentkezve marad, frissíti az állapotot és kiírja a megerősítési üzenetet.
3. Google-regisztrációkor a párbeszédben megadott név az adatlap névmezőjében második beírás nélkül látható.

---

# Új készülékes hibajavítás — 294-es kiadás

## Négy hiba tényleges vizsgálata

1. **Google-név elvesztése — bizonyított ok:** a képernyő force-betöltése nem kerülte meg a `CommunityService.profile()` saját, korábbi üres cache-ét. Javítás: a force útvonal szerverről olvas, majd a `claimDisplayName` után ugyanazt az UID-t és profilt alkalmazza a controllerre. A névfoglalás idempotens marad.
2. **Admin törlés utáni aktív kliens — bizonyított ok:** a korábbi ellenőrzés nem futott folyamatosan, ezért a nyitott app csak elavult Auth/UI-állapotot mutathatott. Javítás: foreground- és 60 másodperces Auth-session-ellenőrzés; csak `user-not-found`, `user-disabled`, `invalid-user-token` vagy `user-token-expired` esetén történik helyi állapottörlés, kijelentkezés és főoldali navigáció. Hálózati hiba és hiányzó profil nem törlésjelzés.
3. **Félbemaradt saját/admin törlés — bizonyított backend-hiba:** a scheduler Auth-fiók hiányakor átugrotta a még meglévő `community_profiles` dokumentumot. Javítás: a pending rekordot Auth nélkül is újrapróbálja, a megmaradt profiladatot átadja a takarításnak; a callable részleges cleanup-hibánál `cleanup_pending` állapotot tart fenn, nem ad hamis teljes sikert.
4. **E-mail-ág — bizonyítható és nem bizonyítható rész:** a normál regisztráció és az `syncEmailChange` forrása nem hív `signOut`-ot; a korábbi készülékes kijelentkezés konkrét runtime oka a rendelkezésre álló logokból nem azonosítható. A sikeres első levél kézbesítési késése nem minősíthető SMTP-hibának. A credential-alapú, login-képernyőről indított újraküldés szándékos `finally`-kijelentkezése külön ág.

## Ellenőrzés

- Firebase Emulator/Node célzott regresszió: **29/29 sikeres**.
- Flutter tesztek: **93/93 sikeres**.
- `flutter analyze --no-pub`: sikeres.
- `node --check functions/index.js`: sikeres.
- `git diff --check`: sikeres.
- Célzott backend-deploy: sikeres, `deleteCommunityUser(us-central1)` és `cleanupIncompleteAccounts(europe-central2)`.
- A deploy a helyi Functions-forrás feltöltésével készült; Play Console-ba nem történt feltöltés.

## 294-es AAB

- versionCode: **294**
- fájl: [app-release.aab](../build/app/outputs/bundle/release/app-release.aab)
- méret: **82 524 724 byte**
- SHA-256: `022CFDC5B8D26DD43C0FF90C06B66ECBAA7F5AB8082657A63B3FA86D5F920890`
- Play Console-feltöltés: **nem történt**

## Korlát és készülékes visszaellenőrzés

A készülékes tesztből említett konkrét tesztfiók azonosítója nem áll rendelkezésemre, ezért éles felhasználót nem kerestem, nem töröltem és nem módosítottam. A célzott megmaradt adatok takarításához szükséges az adott tesztfiók UID-ja vagy e-mail-címe; addig ez a művelet szándékosan nincs végrehajtva.

A 294-es builden ellenőrizendő: online törölt session lezárása, normál e-mail-megerősítés session-megtartása, Google-név egyszeri megőrzése, valamint egy ismert tesztfiók félbemaradt törlésének admin/scheduler általi befejezése.
