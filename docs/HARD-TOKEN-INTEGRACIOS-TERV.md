# HARD Token – integrációs terv a meglévő HUHS-projektre

Állapot: **terv, kódmódosítás nélkül** (2026-11-20). Forrás: `Desktop\HARD_Token_projekt_osszefoglalo.md`, a projekt kódja és a Google Play szabályai.

## 0. Rögzített döntések

- A tulajdonos egy személy; a kincstár többaláírású tárcájához **legalább egy független második aláíró** kell.
- Kell presale, de **pénz beszedése csak ügyvédi jóváhagyás után**, és **az appon kívül** (külön weboldal). Az app nem árul tokent.
- **iOS kimarad.** Csak Android.
- A HUHS-pontok és achievementek **külön rendszer maradnak**, nincs pont↔token átváltás.
- Az első verzió Solana **devnet**; mainnet külön döntés.

## 0.1 Devnet-állapot (2026-11-20)

- **Mint (devnet):** `C8mKvFsSmbro4jTHAGMrK4MJ5k2MaAgrDR4QFZadpYuV`, név: *HUHS*, szimbólum: *HARD*, 6 tizedes, 100 000 000 kínálat.
- Lánc-szinten ellenőrizve: a **mint és a freeze authority visszavonva**, a metaadat **nem módosítható** (nem nevezhető át).
- Eszköz: `tools/hard-devnet/hard-devnet-token.mjs` (`--verify`, `--new`). A kulcsok a repón kívül vannak (`~/.huhs-hard/`).
- A backend (`hardWalletChallenge/Verify/Disconnect`, `hardGetBalance`) és a szabályok megvannak és tesztelve; **élesítve nincs**, a `hard_config/current` még nincs létrehozva.

## 1. Mit találtam a mostani projektben

| Terület | Állapot | Következmény |
|---|---|---|
| Backend | `functions/index.js`, **JavaScript, v1 callable-ök**, Node 22, firebase-functions 7, firebase-admin 14; ~134 export; `europe-central2` | A dokumentum TypeScript/REST (`/v1/...`) tervét **callable-ökre és JS-re kell fordítani**, a meglévő `*-plan.js` + `*.test.cjs` mintával. |
| Adatbázis | Firestore, `hungarian-hardstyle` nevű adatbázis; a szabályok 687 sorosak | Új gyűjtemények **alapból tiltottak a kliensnek** (mint az `achievement_ledger`), csak szerver ír. |
| Pontok | `awardAchievementPoints` + `achievement_ledger`: egy sor forrásonként, idempotens | Ugyanezt a mintát kell követni a HARD-jóváíráshoz (egyedi forráskulcs → egyszeri kifizetés). |
| Check-in | `checkInEvent` már működik (QR → WordPress → `event_checkins` → +25 pont) | **Nem kell újraírni**: a jutalom-sort ide kell kötni, ha a felhasználónak van összekapcsolt tárcája. |
| Rate limit | `allowCall(uid, kulcs, limit)` – **Firestore-tranzakciós**, tehát központi | Használható; külön memóriás számláló nem kell. |
| App Check | A legtöbb callable `enforceAppCheck: false` (régi Play-buildek miatt, a kódkomment szerint szándékosan) | Az App Check **nem lehet az egyedüli védelem**; Auth + regisztrált + limit + szerveroldali ellenőrzés kell. |
| Solana | Nincs benne semmi (sem `pubspec.yaml`, sem `functions/package.json`) | Teljesen új függőségek kellenek, mindkét oldalon. |
| Mappaszerkezet | `lib/screens`, `lib/services`, `lib/providers`, `lib/models` | A dokumentum `features/hard_token/` javaslatát **nem követjük**; az AGENTS.md szerinti szerkezetet használjuk. |

## 2. Cél-architektúra

```
Flutter (Android)                Firebase (europe-central2)               Solana devnet
─────────────────                ──────────────────────────               ─────────────
HardScreen  ── callable ──►  hardWalletChallenge   ──► nonce doc (TTL)
Tárca (MWA) ◄─ aláírás ───   hardWalletVerify      ──► ed25519 ellenőrzés
                             hardGetBalance        ──► RPC: token-account egyenleg
Jutalomlista ─ callable ──►  hardClaimReward       ──► hard_ledger (idempotens)
                             hardPayoutQueue (ütemezett) ──► kifizetés (devnet)
```

A kliens **soha nem dönt jogosultságról** és nem ír a HARD-gyűjteményekbe.

### 2.1 Firestore (új, mind kliens-tiltott)

- `hard_wallet_links/{uid}`: `address`, `verifiedAt`; **egy tárca egy fióknak** (külön `hard_wallet_owners/{address}` → `uid` a duplikáció ellen).
- `hard_wallet_challenges/{id}`: `uid`, `nonce`, `expiresAt` (rövid, egyszer használatos).
- `hard_rewards/{id}`: katalógus (név, ár HARD-ban, készlet, típus, aktív). Admin írja.
- `hard_ledger/{hash(uid:forráskulcs)}`: állapot (`pending`/`paid`/`failed`), mennyiség **egész legkisebb egységben**, tranzakció-aláírás.
- `hard_config/current`: mint-cím, RPC-profil, napi/kampány limitek, kapcsoló (ki/be).
- `hard_audit_logs/{id}`: minden admin- és kifizetési művelet.

Az `hard_rewards` és `hard_config` olvasása regisztráltaknak engedhető, minden más szerver-only. A szabályokat az `firestore.rules`-ban a meglévő stílus szerint kell bővíteni, és a rules-tesztet is.

### 2.2 Callable-ök (új, `functions/`)

| Név | Feladat | Védelem |
|---|---|---|
| `hardWalletChallenge` | nonce kiadása | regisztrált + `allowCall` |
| `hardWalletVerify` | aláírás ellenőrzése, tárcakötés | nonce egyszeri, lejáratos, uid-hoz kötött; `hard_wallet_owners` ütközés tiltva |
| `hardWalletDisconnect` | kötés törlése | regisztrált |
| `hardGetBalance` | egyenleg a **rögzített mint** token-accountjáról | RPC-kiesés kezelése, cache rövid ideig |
| `hardListRewards` / `hardClaimReward` | katalógus, igénylés | idempotens ledger, készlet- és limitellenőrzés tranzakcióban |
| `hardPayoutQueue` (ütemezett) | `pending` → kifizetés | napi/kampány limit, kis összegű hot wallet |

A `checkInEvent` végén egy **opcionális, hibatűrő** ág: ha van kötött tárca és aktív kampány, `pending` ledger-sor jön létre. A check-in hibája soha nem lehet a HARD miatt.

### 2.3 Flutter (új)

- `lib/screens/hard/`: irányítópult, tárcakapcsolat, jutalomlista, előzmények.
- `lib/services/hard_service.dart` + tiszta `*_plan.dart` fájlok (mint a `tonight_plan.dart`), tesztekkel.
- `lib/providers/hard_provider.dart`, `lib/models/hard_*.dart`.
- Belépési pont a **Több → Közösség** alatt, **csak regisztrált, nagykorú**, és csak ha a `hard_config` be van kapcsolva. Kikapcsolt állapotban semmi nem látszik.
- Tárcakapcsolat: **külső tárca** (Solana Mobile Wallet Adapter), saját tárcát nem építünk. A konkrét Flutter-csomagot a megvalósítás előtt kell kiválasztani és ellenőrizni (karbantartottság, `minSdk`, manifest `queries`). Ezt itt nem rögzítem, mert nem néztem utána.

## 3. Google Play-megfelelés (kapu)

A keresési találatok alapján (a hivatalos oldalakat érdemes egyszer teljesen átolvasni):

1. **Financial features declaration** kitöltése a Play Console-ban, mert az app tokenjutalmat ad.
2. **Tilos nyereséget ígérni vagy dicsőíteni** – az app szövegeiben, a store-leírásban és a push-ban sem.
3. **Digitális tartalom tokenért: Play Billing kötelező.** Ezért a **Label-zenéket nem lehet tokenért adni**; a token csak **fizikai/esemény előnyre** (jegykedvezmény, VIP, merch).
4. A presale **nem** az appban folyik.
5. A „szoftveres tárca" szabályait ellenőrizni kell (a mi app külső tárcához csatlakozik, ezt nyilatkozatban rögzíteni).

## 4. Rug pull elleni garanciák (lánc-szintűen ellenőrizhető)

- Mint authority **és** freeze authority visszavonva, nyilvánosan ellenőrizhetően.
- LP-token zárolva/elégetve; csapat- és partner-keret lánc-szintű vestinggel.
- Kincstár: multisig, legalább 2 független aláíró.
- Presale pénze nyilvános multisig tárcába, nyilvános felhasználási tervvel.
- Nincs hozam- vagy árfolyamígéret sehol.

## 5. Fázisok és kapuk

| # | Fázis | Kimenet | Kapu |
|---|---|---|---|
| A | Jogi kérdéslista + Play-nyilatkozat előkészítése | ügyvédi válasz | **Nélküle nincs pénzmozgás** |
| B | Devnet-token a lánc oldalán, az appon kívül | mint, authority visszavonás kipróbálva | – |
| C | Backend: gyűjtemények, szabályok, callable-ök, tesztek | emulátoron zöld | – |
| D | Android tárcakapcsolat + egyenleg (proof of concept) | működő devnet egyenleg | – |
| E | Jutalmak, check-in-kötés, kifizetési sor, admin | 20 sikeres beváltás devnetben | – |
| F | Zárt béta (≥30 tesztelő) | hibalista | **Biztonsági + jogi go/no-go** |
| G | Presale (appon kívül) / mainnet | – | Csak A + F után, külön döntés |

## 6. Kockázatok, amiket tudatosan vállalunk vagy kezelünk

- **Hot wallet a felhőben.** A kifizető kulcs Firebase Secret Managerben lenne (mint a Play szolgáltatásfiók-kulcs), kis összeggel és napi limittel. Éles értékű tokenre ez nem elég; a mainnet előtt külön biztonsági döntés kell.
- **Fiókfarmolás.** Egy tárca = egy fiók, kampányonkénti uid-limit, a meglévő regisztrációs szűrés (`checkRegistrationEligibility`, tiltólista) marad. Bot-ellen nincs tökéletes védelem.
- **Tárca-kulcs elvesztése** a felhasználónál; a HUHS ezért nem felel és nem is tud segíteni (ezt ki kell írni).
- **Függőségek:** a Solana-csomagok növelik az APK-méretet és a támadási felületet; a `functions/` cold startját lazy-load-dal kell védeni (ahogy a `googleapis` is).

## 7. Amit ez a terv nem néz meg

A WordPress-plugin érintettségét (jelenleg nincs szükség rá), a konkrét RPC-szolgáltatót és költségét, a Flutter-oldali Solana-csomagokat, valamint a jogi minősítést. Az állítások a Play-szabályokról keresési kivonatokból valók.

## 8. Gazdasági vázlat: mennyi HARD jár, mit lehet venni (ötletek, 2026-11-21)

Állapot: **csak ötletek, kód nélkül**. A számokat a kincstár méretéből kell kiszámolni, itt csak súlyviszonyok vannak. Két rögzített korlát: **digitális tartalmat (Label-zene) tokenért nem adhatunk** (Play Billing kötelező), és **a HUHS-pontok külön rendszer maradnak** (nincs pont↔HARD átváltás).

### 8.1 Miért és mennyi HARD jár

Elv: HARD-ot a **valós részvételért** kapjon a felhasználó, ne hirdetésnézésért vagy kattintásért.

| Tevékenység | Súly | Megjegyzés |
|---|---|---|
| Valós buli (QR-becsekkolás) | nagy | Fizikai jelenlét, nehéz csalni |
| Meghívott barát első becsekkolása | nagy | Mindkét félnek, csak a becsekkolás után |
| Szavazás az éves szavazáson | közepes | Évente egyszer |
| Heti streak (pl. 4 hétig minden héten buli) | közepes | A kitartás jutalma |
| Jóváhagyott esemény-beküldés | közepes | Csak az elfogadott fizet, a spam nem |
| Hír/esemény megosztása | kicsi | Napi felső korláttal |
| Kérdőív kitöltése | kicsi | |

Nem jár: hirdetésnézésért, napi bejelentkezésért, semmiért, amit bottal vagy több fiókkal ki lehet használni. Minden jutalom a szerveren számolódik, egy tárca egy fiók, napi/heti korláttal.

Nyitott kérdések:
- Mekkora része a 100 millióból a „jutalom" keret, és hány év alatt oszlik el (a ütemet nyilvánosan kell vállalni)?
- Van-e éves felső korlát fiókonként?
- Mi lesz a jutalommal, ha a tárca nincs összekötve (várakozik vagy elveszik)?

### 8.2 Mit lehet venni HARD-ért (fizikai / eseményelőny)

| Ötlet | Típus |
|---|---|
| Jegykedvezmény (−10% vagy ajándék belépő) | fizikai |
| VIP-sor / gyorsabb bejutás | esemény |
| Merch (póló, kitűző, matrica) | fizikai |
| Backstage / meet & greet verseny | esemény |
| Saját név a kreditek között egy eseményen | esemény |
| Jelképes szavazási súly / jelölési jog (ne befolyásolja a végeredményt) | közösségi |
| Ajándék belépő küldése barátnak | esemény |

Az elköltött HARD a kincstárba megy; hogy részben elégetjük-e, külön döntés.

### 8.3 Új funkciók HARD-ért

1. **HARD-bolt:** lista a kedvezményekről és merchről, készlettel és határidővel.
2. **Kuponok/belépők:** tokenért kapott, QR-kódos, egyszer beváltható utalvány (a meglévő QR-becsekkolás mellé).
3. **Ranglista és szintek:** a becsekkolások alapján, nem a vagyon alapján.
4. **Közösségi szavazás a következő bulira:** jelképes támogatás, nem döntő.
5. **Streak-jutalom:** pl. 4 egymást követő buli után bónusz.
6. **Csapat-kihívás:** baráti társaság együtt gyűjt egy jutalomra.

### 8.4 Óvatosság

- **Nincs ígéret árra vagy hozamra** sehol (app, Play-leírás, push). „Megéri megvenni" jellegű szöveg tilos.
- **Jogi kérdés nyitott:** az „earn" jutalom a MiCA szerint „ingyenes ajánlatnak" számít-e, ha cserébe adatot vagy használatot kapunk; az azonosítható kibocsátó; pool esetén a nyilvános ajánlat. Ügyvéddel tisztázandó, éles token kiosztása előtt.
- **Play financial features nyilatkozat** kell, ha az app tokenjutalmat ad.
- **Ne legyen pay-to-win:** a vásárolható dolog kényelmi/élmény-előny legyen, ne a közösségi döntést vagy a ranglistát torzítsa.
- **Likviditás nélkül a HARD csak jutalompont:** a kedvezmény az egyetlen érték, erről őszintén kell kommunikálni.

### 8.5 Következő döntés

Mi az a 2–3 tevékenység, amiért HARD jár, és az mennyit ér egy jegykedvezményben? Ebből kiszámolható a kiosztási keret és a szükséges kincstár; a bolt, a kuponok és a ranglista erre épül.

Nem néztem: a meglévő HUHS-pontrendszer pontos szabályait, a kiosztási keretet és árazást, a Play szabályainak friss szövegét.

## 9. HARD Wallet specifikáció értelmezése és tulajdonosi döntések (2026-11-21)

Forrás: `Desktop\HARD_Wallet_Claude_spec.md` (beépített tárca, jutalmak, NFT-rendszer). Állapot: **terv, kód nélkül.**

### 9.1 Rögzített tulajdonosi döntések

1. **Beépített (non-custodial) tárca kell.** A mostani külső tárcás összekapcsolás (MWA + WalletConnect) megmarad, a beépített tárca mellé vagy helyett kerül; a sorrendet külön kell eldönteni.
2. **Kvízjutalom: mindkettő lehet, és később választható legyen** (HUHS-pont, HARD, vagy mindkettő). Ez beállítás legyen (kvízenként/kampányonként), ne kódba égetve. A pont↔HARD átváltás továbbra sincs.
3. **Az NFT fizetős legyen az elejétől.** (Következmények: 9.4.)
4. **Az alapítói részesedés lánc-szintű zárolással (vesting) induljon**; a zárolás a mintelés előtt, nyilvánosan ellenőrizhetően legyen beállítva.

### 9.2 Eltérések a specifikáció és a rögzített terv között

- **A spec mint-címe elavult** (`8yi3Sa…`): a mostani devnet-mint `C8mKvFs…`. A hálózatot és a tulajdonságokat RPC-n kell ellenőrizni.
- **Apple-belépés** csak iOS-hez kell; iOS jelenleg kimarad.
- **Tokenelosztás** (35% jutalom / 20% likviditás / 20% kincstár / 15% alapító / 10% partner): az alapítói rész zárolása a 4. fejezet rug-pull elleni elveivel egyezik.
- **Digitális szolgáltatás HARD-ért** (zene, reklámmentesség): a spec is tiltja a Play/iOS szabályok ellenőrzése nélküli élesítést; lásd 8. fejezet.

### 9.3 Beépített tárca: nyitott döntések

- **Kulcskezelés:** saját megoldás (recovery phrase, jelszóból képzett kulcs) vagy külső MPC/embedded wallet szolgáltató. A spec saját kriptográfiát audit nélkül tilt; javasolt: kész szolgáltató. Szolgáltatók (pl. Privy, Web3Auth, Turnkey) **nincsenek megvizsgálva**.
- **Helyreállítás:** a Google-/Apple-fiók nem kulcsmentés; külön erős faktor kell. Az elveszett faktor következményét dokumentálni kell.
- **Jog:** a tárcafunkció szabályozott kriptoszolgáltatásnak minősülhet-e (MiCA); a Play szabálya a non-custodial tárcát nem érinti, de a jogi minősítés ügyvédi kérdés.

### 9.4 Fizetős NFT az elejétől: következmények

- **Play:** a fizetős NFT digitális tartalom. Az appban történő eladáshoz **Play Billing** kell (jutalék), és a terméket **tokenizált digitális eszközként** be kell jelenteni; a Financial features nyilatkozat is kell. Nem hirdethető nyereség/értéknövekedés.
- **Web mint alternatíva:** ha az eladás a weben történik, a Play fizetési szabálya nem az appban érvényesül, de az app nem terelheti oda a felhasználót (lásd 8. fejezet). Az EU külső ajánlati szabályait nem néztük meg.
- **MiCA:** a nagy sorozatú, egymással helyettesíthető NFT nem automatikusan mentes; egyedi minősítés kell.
- **Adó, számla, fogyasztóvédelem:** a spec szerinti 60/40 megosztás nettó bevételből történik; az elszámolás és az áfa-kezelés tisztázandó.
- **Szerzői jog:** DJ-fotó, képmás, logó: írásos hozzájárulás minden kollekcióhoz.
- **Jogdíj (5%):** nem ígérhető, a piacterek nem kötelesek betartani.
- **Piactér:** saját letétkezelő piactér nem épül audit és jogi vizsgálat nélkül; az első lépés az elsődleges eladás, nem a P2P kereskedés.
- **Ügyvédi/hatósági kapu:** a fizetős NFT-eladás éles indítása csak a jogi és Play-egyeztetés után.

### 9.5 Javasolt sorrend

1. Külső tárcás összekapcsolás (kész) + jutalom (earn) + jegykedvezmény-bolt (8. fejezet).
2. A beépített tárca előkészítése: szolgáltató-összehasonlítás, threat model, helyreállítási UX.
3. Kvízjutalom-beállítás (pont / HARD / mindkettő).
4. Az NFT-modul előkészítése devneten (ingyenes tesztkollekció), a fizetős élesítés külön kapu mögött.

### 9.6 Még nincs megvizsgálva

Költségek (RPC, Firebase, audit, Metaplex Core vs. alternatívák), MPC-szolgáltatók feltételei és ára, az EU külső ajánlati szabályai a Play-en, a meglévő kvíz/Guess the Track kód, a partneri szerződések tartalma.

## 10. Újabb döntések és javaslatok (2026-11-21)

### 10.1 Rögzített döntés

- **A beépített tárca kulcskezelője: MetaMask Embedded Wallets (korábban Web3Auth).** Még **nincs bevezetve**; először külön ágon próba kell (Firebase-JWT-s belépés, Solana ed25519 kulcs, MFA/helyreállítás, az aláírás elfogadása a mostani szerverrel). Ellenőrizendő: az SDK a kulcsot az eszközön állítja össze (az MPC Core Kit, ami nem, Enterprise csomagban van); a helyreállítási faktor Firebase JWT mellett is működik-e; árak a hivatalos oldalon. Nyitott kockázat: függés a szolgáltatótól, ezért kell kulcs-exportálás.
- **OneTicket:** a tulajdonos megkérdezi (kupon-API, CSV-feltöltés, használat/kód, beváltási lista, díj); az eredmény dönti el az A/B/C esetet (lásd 8. fejezet).

### 10.2 Javaslat: mennyi HARD jár, és mit ér (illusztratív számok, nem döntés)

**Alapelv.** A HARD értékét nem árfolyam adja, hanem a **bolt belső árszintje**: 1 HARD ≈ 1 Ft kedvezmény *a mi saját termékeinkben* (jegy, merch). Ez belső ár, **nem piaci árígéret**; az appban és a kommunikációban „1 HARD = 1 Ft” nem szerepelhet értékként, csak a bolt konkrét árai.

**Kiosztási keret.** A spec szerinti 35% (35 000 000 HARD) 5 évre, csökkenő ütemben: 1. év 10 M, 2. év 8 M, 3. év 7 M, 4. év 5 M, 5. év 5 M. Az 1. év heti kerete ~190 000 HARD. A ütemet nyilvánosan kell vállalni.

**Jutalmak (javaslat).**

| Tevékenység | HARD | Korlát |
|---|---|---|
| QR-becsekkolás egy buliban | 300 | buliként egyszer |
| Meghívott barát első becsekkolása | 300 a meghívónak, 150 a meghívottnak | a becsekkolás után, fiókonként max. 10 meghívás |
| Éves szavazáson való részvétel | 150 | évadonként egyszer |
| 4 hetes streak (4 hétig minden héten buli) | +500 bónusz | |
| Jóváhagyott esemény-beküldés | 300 | |
| Kvíz / Guess the Track | 10–50 | napi 100 |
| Megosztás | 5 | napi 20 |

Fiókonkénti éves felső korlát: **12 000 HARD**. Egy átlagos látogató (havi 2 buli) ~7 000 HARD-ot gyűjt évente.

**Bolt (javaslat, a belső árszint szerint).**

| Termék | HARD |
|---|---|
| Jegykedvezmény (kb. 10%) | 1 500 |
| Ingyenes belépő | 5 000 |
| VIP-sor / gyorsabb bejutás | 800 |
| Matrica / kitűző | 400 |
| Póló | 5 000 |

Egy kedvezmény kb. 5 buli után jár, egy ingyenes jegy kb. 17 után. A kerettel és a jutalmakkal ez fenntartható, ha az elköltött HARD visszamegy a jutalomkeretbe (nem elégetjük).

**Költség a szervezőnek.** Ha egy 1 000 fős aktív közösség évente ~6 M HARD-ot gyűjt és mindet beváltja jegykedvezményre, az ~6 M Ft kedvezményt jelent. Ezt a Hungarian Hardstyle saját bulijainál vállalhatja; más szervezőknél külön megállapodás kell. A kedvezmény mértékét és a beváltási arányt mérni kell, és a jutalmakat ehhez kell hangolni.

**Visszaélés-védelem.** Minden jutalom szerveroldalon számolódik, egy tárca egy fiók, a becsekkolás QR-ablakhoz kötött, napi/éves korlátok, auditnapló.

### 10.3 Javaslat: webes kiadványvásárlás HARD-ért

- **Adatforrás:** a meglévő WordPress kiadvány-rekordok és API (a web és az app ugyanazt használja).
- **Kötés:** a vásárlás a **Firebase-fiókhoz** (uid) kötődik, a **tárcával** történő aláírás igazolja a fizetést. Fiók nélkül nincs vásárlás (letöltési jog, visszaállítás, jelentés).
- **Ár (belső árszint szerint):** 320 kbps MP3 = 550 HARD, WAV = 700 HARD (a mostani Play-árakkal egyező szám, a Play-vásárlás külön marad).
- **Fizetés:** HARD-átutalás a kincstárba (vagy égetés, ez külön döntés); a szerver ellenőrzi a tranzakciót (összeg, címzett, rendelés-azonosító memóban, véglegesítés, újrafelhasználás elleni védelem).
- **Letöltés:** egy fiókhoz kötött, tartós jog; letöltés lejáró, aláírt URL-lel, napi korláttal.
- **Az app nem linkel és nem hirdeti** a webes vásárlást (Play fizetési szabály); az EU külső ajánlati szabályait nem néztük meg.
- Nyitott: kincstárba megy vagy elégetjük; Firebase-bejelentkezés weben; adó/számla a tokenes fizetésnél.

### 10.4 Még nincs megvizsgálva
A számok illusztratívak; nem néztük a tényleges közösségméretet, a jegyárbevételt, az adózást és a Play külső ajánlati szabályait.

## 11. Összefoglaló: jutalom, bolt, tárca-funkciók (2026-11-21, tulajdonosi döntések)

### 11.1 Rögzített
- **Hír-megosztás és chat-aktivitás:** 1 HARD/alkalom, **összesen legfeljebb heti 3 HARD** (a két forrásra együtt, szerveroldali ISO-heti számlálóval). A megosztás csak azt tudja jelezni, hogy a felhasználó megnyitotta a megosztás-ablakot (az Android nem jelzi vissza a tényleges elküldést); a chat-jutalom késleltetett, és csak a nem moderált, nem duplikált, nem túl rövid üzenetre jár, napi 1 üzenetig.
- **Buy / Sell gomb:** később lehet, de **csak külső linkként a DEX oldalára**, appon belüli ügylet nélkül. Mainnet és jogi válasz (MiCA, Play) után.
- **Küldés felhasználók között:** tervezett, devnet-en, először csak barátok közt, napi plafonnal, megerősítő képernyővel; a tárca írja alá. Nyitott: ki fizeti a hálózati díjat (SOL) és az új címzett számlájának létrehozását; farmolás elleni heti plafon.
- **Tárca-képernyő:** token-logó (`assets/logos/hard_token.png`, a token metaadatában szereplő logó) és „Mire jó a HARD?” kártya; a tervezett funkciók tervezettként szerepelnek, értéket nem ígér. Következő kör: teljes cím + másolás + QR + explorer-link.

### 11.2 Skálák ütköznek: döntendő
A 10.2 táblázat (300 HARD/becsekkolás, bolt: póló 5 000) és a beszélgetésben felmerült kisebb skála (20–50 HARD/becsekkolás) **nem ugyanaz**. A heti 3 × 1 HARD passzív jutalom a nagyobb skálán elhanyagolható a becsekkoláshoz (300) képest, ami kívánatos. A skálát a kibocsátási keret határozza meg; amíg ez nincs eldöntve, a 10.2 számai az érvényesek.

### 11.3 Fizikai termékek a bolthoz (a tulajdonos készletéből)
Hardstyle Revolution **bögre, passztartó, maszk**; eseményen átvétel (nincs postázás), darabszám-korláttal. Árjavaslat a 10.2 skálán (nem döntés): matrica/kitűző 400, passztartó ~1 500, maszk ~1 500, bögre ~2 500, póló 5 000. Darabszámok: a tulajdonos adja meg. Fizikai termékre a Play Billing nem kötelező, de a jogi/Play pontokat (8–10. fejezet) előbb át kell nézni.

### 11.4 GYIK
A WordPress-kezelt GYIK szövegei: `docs/HARD-GYIK-SZOVEGEK.md` (a felvitel a WordPress adminban a tulajdonos dolga, vagy API-hozzáférés után az enyém).
