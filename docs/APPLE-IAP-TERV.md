# Apple IAP (App Store) — terv és előkészítés

> **Állapot:** **KUTATÁS, munka nem indult** (2026-09-24). Ez a dokumentum a tulajdonos
> kérdésére adott válasz rögzítése:
> *„meg lehet oldani, hogy az iphone-os boltba is beküldje majd, ha kész a developer acc?"*,
> illetve *„ha feltöltök egy kiadványt a labelbe, akkor feltölti playbe meg a storekitbe is?"*
>
> **A válasz: IGEN, megoldható** — a meglévő WordPress → Firestore → függvény láncra egy
> **második bolt-adapter** kerül. Az Apple-oldali részt **nem próbáltuk élesben**, mert nincs
> Apple Developer Program tagság és API-kulcs; amíg az nincs meg, ez **terv, nem ígéret**.

---

## 1. Ami MA működik (mérve a kódból, 2026-09-24)

A kiadvány-feltöltés **már ma automatikusan** létrehozza a **Google Play**-termékeket:

| Lépés | Hol | Mit tesz |
|---|---|---|
| WP: hang feldolgozva | WordPress (plugin) | beír egy kérést: `label_product_sync_requests/{requestId}` |
| azonnali feldolgozás | `functions/index.js` → `syncQueuedWordPressLabelProducts` (`onDocumentCreated`, ~6855. sor) | `runWordPressLabelSync(releaseId)` |
| biztonsági háló | `syncWordPressLabelProducts` (`onSchedule`, 5 percenként, 300 s keret, zár a `sync_locks/label_product_sync`-on, ~6837. sor) | ugyanaz, minden kiadványra |
| adatforrás | `syncWordPressLabelProducts()` (~6747. sor) | **maga kéri le** a meglévő `${WORDPRESS_BASE_URL}/releases` végpontot |
| írás a boltba | `upsertPlayProduct(...)` (~6423. sor), hívva a `syncReleasePlayProducts`-ből (~6680. sor) | Play Developer API: termék létrehozás/PATCH **árral, a 9 ország régióival, vásárlási opciókkal** |

**Következmény:** a Play Console-ban **nem** kell kézzel terméket gyártani. Kézzel marad az
**app** (AAB) feltöltése és a kiadási szöveg.

⚠️ Az **„upcoming"** kiadvány termékei szándékosan **`DRAFT`**-ban maradnak (mérve: a 12699-nél
4 db), ezért a megjelenésig **nem vásárolhatók** — a megjelenés napján a szinkron aktiválja őket.

---

## 2. Amit az Apple-ághoz tudni kell (dokumentáció, nem saját mérés)

Az **App Store Connect API** ma már a **teljes IAP-életciklust** tudja programból:

| Lépés | Végpont |
|---|---|
| létrehozás | `POST /v2/inAppPurchases` (név, `productId`, típus, `reviewNote`, app-kapcsolat) |
| listázás / módosítás | `GET /v1/apps/{id}/inAppPurchasesV2`, `PATCH /v2/inAppPurchases/{id}` |
| lokalizáció | `POST /v1/inAppPurchaseVersions` → `POST /v2/inAppPurchaseLocalizations` |
| ár | `GET /v2/inAppPurchases/{id}/pricePoints?filter[territory]=…` → `POST /v1/inAppPurchasePriceSchedules` |
| országok | „In-App Purchase availability" erőforrás |
| beküldés | `POST /v1/reviewSubmissions` → `POST /v1/reviewSubmissionItems` → `PATCH … {submitted: true}` |
| kötelező melléklet | review-képernyőkép: `POST /v1/inAppPurchaseAppStoreReviewScreenshots` (+`PUT`, `PATCH`) |

Forrás: [Managing In-App Purchases](https://developer.apple.com/documentation/appstoreconnectapi/managing-in-app-purchases),
[IAP price schedules](https://developer.apple.com/documentation/appstoreconnectapi/in-app-purchase-price-schedules),
[Review submissions](https://developer.apple.com/documentation/appstoreconnectapi/in-app-purchase-and-subscription-app-store-review-submissions).

**Jogosultság:** `ACCOUNT_HOLDER` / `ADMIN` / `APP_MANAGER` szerepű **API-kulcs** (`.p8` +
Issuer ID + Key ID). Ez kerül a Secret Managerbe a Play service account **mellé**.

---

## 3. A négy dolog, amiért az iOS NEM tükör-másolat

1. **Az ELSŐ terméket az Apple csak app-bináris beküldéssel együtt fogadja el** — a fenti
   review-submission út **csak a másodiktól** működik. A **létrehozás** persze API-ból is mehet;
   az első kör beküldése félig kézi, utána automatizálható.
2. **Ár:** az Apple **fix árpontokat** használ (nincs szabad ár) — az 550 Ft → 1,49 EUR / 39 CZK /
   169 RSD / 59 UAH létra **hozzárendelést** kér országonként. Ez **döntés**, nem képlet.
   ⚠️ Egy **áremelést** az Apple nem enged visszavonni.
3. **Az „upcoming" kapu:** a Play-en a `DRAFT` állapot zárja a vásárlást; az Apple-nél ilyen
   állapot nincs, ezért a megjelenés előtti vásárlást **nekünk** kell tiltani (a meglévő
   `isUpcoming` szabály erre alkalmas).
4. **A kliens- és szerveroldal:** iOS-en a vásárlást **StoreKit** adja (`in_app_purchase` ezt már
   támogatja), a visszaigazolás viszont **App Store Server API + App Store Server Notifications
   V2** — a **`verifyLabelPurchase` iOS-ága ma nem létezik**, és ez a legkockázatosabb rész
   (pénz mozog). Mellé: **fizetős tagság ($99/év) + Paid Applications Agreement + bank/adó**, és
   a jutalék (15% a Small Business Programban, egyébként 30%).

---

## 4. Amit NEM kell megírni újra

- a **WP → Firestore → függvény** trigger és a **zár/retry** minta;
- az **adat**, mert a szinkron a meglévő `/releases` végpontból dolgozik: kiadvány-azonosító, cím,
  előadók, borító, műfaj, dátum, `is_upcoming`, `is_free`, `products` tömb;
- a **tiszta plan-modul** séma (`functions/play-product-plan.js` mintája) és a tesztjei;
- a **termék-azonosító séma** (`radio_mp3_320`, …) — a két bolt külön nyilvántartás, ugyanaz a
  szöveg jó;
- az **árlétra** forrása és a szövegek.

**A WordPress és a plugin (2.7.0) VÁLTOZATLAN marad**, és nem is tud az Apple-ágról.
**Opcionális** WP-bővítés (plugin 2.8.0), csak ha a tulajdonos kézzel akarja írni: IAP-név/leírás
és review-kép meta mezőnként, illetve Apple-státusz a WP-admin szinkron-panelben (csak kijelzés).

---

## 5. Javasolt sorrend, ha egyszer nekiállunk

| # | Lépés | Miért ebben a sorrendben |
|---|---|---|
| 1 | Apple Developer Program tagság + Paid Applications Agreement + bank/adó | enélkül nincs sem API-kulcs, sem eladható termék |
| 2 | API-kulcs a Secret Managerbe, majd **csak olvasó** eszköz: `tools/check-appstore-products.mjs` (a `check-play-products.mjs` mintájára, írás csak `--confirm`-mal) | az **első éles hívás** mondja meg, mi elérhető a mi fiókunkon |
| 3 | tiszta `functions/appstore-product-plan.js` + tesztek (árpont-hozzárendelés, országok, nevek, `reviewNote`) | a döntések mérhető, tesztelt helyen legyenek |
| 4 | szinkron: **létrehozás + ár + elérhetőség** (még beküldés nélkül) | ez már önmagában látszik az App Store Connectben |
| 5 | beküldés bírálatra (**a második** terméktől) + review-képernyőkép | az első termék az app-binárissal megy |
| 6 | **kliens StoreKit + szerveroldali visszaigazolás** (App Store Server API + Notifications V2) | ez zárja a kört, és ez kér **zárt tesztet a készüléken** |

---

## 6. Nyitott döntések (a tulajdonosé)

1. **Árpont-hozzárendelés** országonként (a fix Apple-árpontokhoz).
2. **A review-képernyőkép forrása** — a kiadvány borítója elég-e, vagy kell egy képernyőkép az
   appból; és ez kézzel vagy generálva legyen.
3. **Az IAP megjelenítendő neve/leírása** — generált szöveg a címből + terméktípusból, vagy kézi
   WP-mező (plugin 2.8.0).
4. **Az „upcoming" kapu** iOS-en: kliens-oldali tiltás (egyszerű), vagy szerveroldali
   jogosultság-kapu (szigorúbb).
5. **Az iOS-vásárlás elszámolása** — ugyanaz a `label_entitlements` modell, App Store
   visszaigazolással; és mi legyen a visszatérítéseknél (a Play-oldalon ez ma nincs kezelve
   külön).

---

## 7. Őszinte korlátok

- A fenti végpontok az **Apple 2026-os dokumentációjából** származnak — **nem** a saját
  fiókunkon mértük. Az első olvasó hívás után ez a szakasz **méréssel** frissül.
- Az Apple **bírálata emberi**, tehát a „feltöltés → eladható" nem azonnali, és el is utasítható.
- Az iOS **kliens-oldali** vásárlás ma **nincs implementálva** (`verifyLabelPurchase` iOS-ág
  nélkül), ezért az Apple-ág önmagában **nem** teszi eladhatóvá a zenét iOS-en: a 6. lépés
  kötelező hozzá.
