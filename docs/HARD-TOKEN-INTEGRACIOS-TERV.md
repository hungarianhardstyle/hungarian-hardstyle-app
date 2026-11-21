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
