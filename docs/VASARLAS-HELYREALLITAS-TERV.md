# Vásárlások helyreállítása — terv és ötletjavaslat (a tulajdonosnak)

> **Állapot: NEM épült meg.** A tulajdonos kérése a 349-es körben szó szerint ez volt:
> *„lehet kéne vásárlások visszaállítása rész, de nemtudom ez jó ötlet e (a beállításokba)
> és ezt hogy lehetne kivitelezni, erre kérek ötleteket"* — vagyis **előbb döntést kér**,
> nem kódot. Ez a fájl a döntéshez szükséges tényeket és a kiviteli tervet tartalmazza,
> **hogy a következő körben ne kelljen újra kikutatni**.

---

## 1. Mi történik ma egy vásárlásnál (mérve a kódból)

| Lépés | Hol | Mi történik |
|---|---|---|
| 1. Terméklista | `LabelPurchaseService.loadProducts(productIds)` (`:118`) | a Play-ből lekéri a `huhs_release_<kiadvány>_<változat>` termékeket |
| 2. Vásárlás | `LabelPurchaseService.buy()` → `buyNonConsumable` (`:254`) | **nem fogyó** termék, ezért a Play **örökre nyilvántartja** a fiókhoz |
| 3. Esemény | `LabelPurchaseService.listen()` → `_pendingUpdates` (`:186-204`) | a `purchaseStream` minden eseményt **megtart**, amíg a képernyő vissza nem igazolja |
| 4. Szerver-ellenőrzés | `verifyLabelPurchase` (functions/index.js:5421) | a Google Play API-val ellenőrzi, majd `label_entitlements/<uid>_<productId>` |
| 5. Jogosultság | `label_entitlements` + `label_ad_unlocks` | **ez a Zenéid lista egyetlen igazsága** (`getMyLabelLibrary`, functions/index.js:5609) |

**Amit ez jelent:** a vásárlás **ténye** a Google-nél van, a **jogosultság** viszont a mi
szerverünkön. Ha a 4. lépés bármiért kimarad, a Play szerint megvan a zene, nálunk nem.

## 2. A valódi rés (ez az, amit egy „visszaállítás" megoldana)

- **Ami MA IS működik:** új telepítés / új telefon után, ha a **jogosultság** már bekerült a
  szerverre, a belépés után minden megjelenik (`getMyLabelLibrary` fiókhoz kötött). Ehhez
  **nem kell** semmilyen visszaállítás.
- **Ami viszont NEM működik:** ha a vásárlás a Playnél **sikerült**, de a szerver-ellenőrzés
  **elmaradt** (kilőtték az appot, elment a net, a Play-véglegesítés nem futott le). Ilyenkor a
  felhasználó **csak szerencsével** tudja helyrehozni: meg kell nyitnia **pont azt** a kiadványt,
  és rá kell koppintania az **árra** — ekkor a Play „már a tiéd" hibát ad, és a kód ebből
  visszaállítja (`release_detail_screen.dart:110-121`). Ez a felfedezhetetlen út a rés lényege.

## 3. Miért nem elég a mai `restore()` (a mért technikai gyökér)

- `LabelPurchaseService.restore()` **létezik** (label_purchase_service.dart:300), és **egy helyen
  hívjuk is**: a kiadvány adatlapján (`release_detail_screen.dart:59`, `:90`, `:119`).
- **DE a feldolgozás egyetlen kiadványhoz van kötve:**
  - `_handlePurchase` **kidobja** azokat a vásárlásokat, amelyek termék-azonosítója nincs a
    nyitott kiadvány termékei között (`_knownProductIds`, release_detail_screen.dart:93-100);
  - a szerver-ellenőrzés is a **nyitott** kiadvány azonosítójával megy
    (`verifyPurchase(releaseId: _release.id)`, `:129-132`);
  - a „már a tiéd" ág (`isAlreadyOwned`, label_purchase_service.dart:258) is **csak** a nyitott
    kiadvány termékeit látja, mert a Play-hiba eseményében nincs token (`:110-121`).
- Vagyis a Play visszaadja **az összes** birtokolt vásárlást, de a **többi kiadványé némán
  elveszik** — mert a képernyő nem is ismeri fel őket.
- **A gyökér tehát szerkezeti:** a visszaállítás logikája egy **képernyőben** él, pedig
  **fiókszintű** művelet. A helyreállításnak a **szolgáltatásba** kell kerülnie.

## 4. Amit a szerver már most jól csinál (nem kell félni a visszaéléstől)

- **A termék-azonosító tartalmazza a kiadványt** (`huhs_release_<id>_<változat>`), és a szerver
  **kötelezően** egyezteti: ha a küldött `releaseId` nem egyezik a termék-azonosítóban lévővel,
  `invalid-argument` (functions/index.js:5436-5447). Ezért a visszaállításnál **a termék-
  azonosítóból kell kiolvasni** a kiadványt.
- **Egy vásárlási token csak EGY fiókhoz tartozhat**: `label_purchase_claims/<tokenHash>` és
  `label_entitlements.purchaseTokenHash` — ha más fiókkal próbálják ugyanazt érvényesíteni:
  *„Ez a vásárlás már másik felhasználóhoz tartozik."* (functions/index.js:5469-5505).
  **Ezért a visszaállítás NEM adható arra, hogy egy Google-fiókkal több app-fiókot lássunk el
  ingyen zenével** — a szerver ezt elutasítja. Ez a legfontosabb biztonsági érv a funkció mellett.
- **Pontot nem ad kétszer:** a `release-purchase:<productId>` naplókulcs miatt egy ismételt
  ellenőrzés nem növeli újra az achievement-pontot (functions/index.js:5507-5510).

## 5. ⚠️ A korlát, amit mindenképp kezelni kell: 10 kérés / 60 másodperc

- `verifyLabelPurchase`: `allowCall(uid, 'label_purchase', 10)` — **10 hívás / 60 másodperc /
  fiók** (functions/index.js:5430, a `allowCall` fix 60 másodperces vödröt használ: `:1148-1169`).
- **A következmény:** akinek **10-nél több** megvásárolt kiadványa van, a naiv
  „mindent visszaállítok" kör a 11.-nél `resource-exhausted`-be fut.
- **A megoldás (a terv része):** a helyreállítás **saját szerver-kulcsot** kapjon
  (`allowCall(uid, 'label_restore', N)`), **és** a kliens **daraboljon** (pl. 8 termékenként,
  a megmaradtakat a következő körre hagyva, „folytatás" lehetőséggel). A kettő együtt kell:
  a darabolás önmagában lassú, az emelt keret önmagában visszaélhető.

## 6. Három kivitel — és a javaslat

### A) Kézi gomb a Beállításokban
A `settings_screen.dart` „Gyorsítótár" kártyája (`:437-447`) mintájára egy új kártya:
**„Vásárlások helyreállítása"**, magyar magyarázattal (*„Ha a Google Play szerint megvan egy
zene, de az appban nem látod, itt helyreállíthatod."*). Megnyomásra: Play → birtokolt termékek →
egyenként ellenőrzés a **helyes** kiadvány-azonosítóval → összegzés:
*„3 vásárlás helyreállítva, 0 hiba."*

### B) Automatikus, háttérben
A „Megvásárolt zenéim" képernyő megnyitásakor (vagy bejelentkezés után) a háttérben lefut, a
felhasználó nem is látja; **csak akkor szól**, ha talált valamit (*„1 korábbi vásárlásodat
helyreállítottuk."*). Ez a legjobb élmény, de ez fogyasztja a keretet, ezért **kell** hozzá
az 5. pont szerinti darabolás és külön szerver-kulcs.

### C) Csak jelzés
Ha a Play szerint van olyan vásárlás, amihez nálunk **nincs** jogosultság, a Beállításokban
megjelenik egy sor: *„1 vásárlás helyreállítható"* — a felhasználó dönt. A legkisebb kockázat,
de a legkevesebb haszon.

### ➜ A javaslatom: **A + B együtt, KÜLÖN körben**
- **A** adja a biztos, kiszámítható utat (és a „hol találom?" választ),
- **B** adja a jó élményt (a felhasználó észre sem veszi, hogy valaha hiányzott valami),
- **C** önmagában kevés: a felhasználó nem fog kitalálni egy „helyreállítható" feliratot, ha
  nem tudja, minek kellene ott lennie.

## 7. Kiviteli terv (ha a tulajdonos rábólint)

**Kliens (új, tesztelhető mag):**
1. Új tiszta modul: `lib/services/label_restore_plan.dart`
   - `releaseIdFromProductId(String productId) → int?` (a `^huhs_release_([0-9]+)_(.+)$` mintával),
   - `restorablePurchases(...)` — a Play-től kapott tételekből kiszűri azokat, amelyek **nem
     fogyó** termékek, ismert kiadványhoz tartoznak, és **még nincsenek** a szerver-
     jogosultságok között,
   - `restoreBatches(items, {int size = 8})` — a 10/60 s kerethez igazodó darabolás,
   - `restoreSummary(results)` — a magyar összegző mondat.
2. Új fiókszintű reconciler a `LabelPurchaseService`-ben (a `purchaseUpdates` streamet használja,
   **nem** a képernyő visszahívásait) — a képernyő csak **kijelzi** az eredményt.
3. A Beállítások „A" kártyája + opcionális „B" automatikus futás a Zenéid képernyőn.
4. A `release_detail_screen` maradhat, de a benne lévő egy-kiadványos logika **áthelyeződik** a
   közös reconcilerbe (nehogy két helyen legyen a szabály — ugyanaz a hiba, mint a 341-es
   kártyacímeknél).

**Szerver:**
5. Új `allowCall` kulcs a helyreállításnak (pl. `label_restore`, 20/perc), **a meglévő
   `label_purchase` 10-es kerete érintetlen**.
6. **Nincs új szükséges végpont**: a `verifyLabelPurchase` már most elvégzi a helyes dolgot,
   ha a **helyes** `releaseId`-t kapja. (Ezért elég a kliens-oldali javítás + a keret.)

**Teszt-terv:**
7. Tiszta tesztek a `label_restore_plan.dart`-ra: a termék-azonosító feldolgozása (helyes,
   hibás, idegen formátum), a „már megvan" kiszűrése, a darabolás (9/10/17 termék), az összegzés
   szövege, és hogy **idegen fiók tokenje nem kerülhet a listába**.
8. Forrás-lint: a képernyő **nem** szűri ki a „más kiadvány" vásárlásokat; a reconciler a
   szolgáltatásban él; a Beállításokban megvan a kártya.
9. Szerver-teszt: a 10/60 s keret és az új kulcs **külön** fut (a régi keret ne lazuljon).
10. Mutációs bizonyíték: a darabolás kivételével és a `releaseId` hibás forrásból olvasásával
    **el kell hasalnia** a tesztnek (majd byte-pontos visszaállás).

## 8. Döntési pontok a tulajdonosnak

1. **Kell-e egyáltalán?** A javaslatom: **igen**, de nem azért, mert a jogosultságok elvesznének
   (azok nem vesznek el), hanem mert a **félbemaradt vásárlás** ma csak szerencsével hozható helyre.
2. **Hova kerüljön?** A) gomb a Beállításokban, B) automatikus a háttérben, C) csak jelzés —
   a javaslat **A + B**.
3. **Mit mondjunk, ha a vásárlás MÁS app-fiókhoz tartozik?** A szerver ilyenkor elutasítja
   (*„Ez a vásárlás már másik felhasználóhoz tartozik."*). A javaslat: a felület **mondja meg
   magyarul**, hogy ez a vásárlás egy másik fiókhoz van kötve, és **ne** tűnjön hibának.
4. **Kérjünk-e e-mailt/nyugtát?** Nem javaslom: a Play-nyugta és a token elég, és a token-
   egyediség miatt a visszaélés kizárt.

## 9. Amit SZÁNDÉKOSAN nem javaslok

- **Új „visszatérítés visszavonása" logika** — a Play kezeli, nálunk nincs rá adat.
- **A jogosultság törlése, ha a Play már nem látja** — a Play átmenetileg is hibázhat; egy
  „eltűnt a jogosultság" élmény rosszabb, mint egy elavult sor. (Ez ugyanaz az elv, amiért a
  349-ben a listából eltűnt kiadvány **megtartja** a feloldást.)
- **A `label_purchase` keret emelése** — az a folyamatos vásárlás-ellenőrzés védelme; a
  helyreállítás **külön** kulcsot kapjon.
