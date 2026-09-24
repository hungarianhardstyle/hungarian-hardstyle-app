# Nyilvános (production) kiadás — a beadás terve

Ez a dokumentum a **nyilvános Play-kiadás** előkészítése: mi az, ami **mérve rendben van**, mi az,
ami **hiányzik**, és milyen **sorrendben** kell a Play Console-ban haladni. Minden állítás mellett ott
van a mérés módja — ahol nem tudtam mérni, az **szándékosan jelölve** van.

> **A tulajdonos jelzése (2026-09-22):** *„van már éles kiadás engedélyem"* — vagyis a **production
> access** megvan, ezért a **12 tesztelő / 14 folyamatos nap** követelmény **nem** blokkol.

---

## 0. Mért állapot (2026-09-24 — a nyilvános kiadás ÉL)

> **A kiadás lezárult:** a **bírálat lefutott**, a bolt-lap **HTTP 200**, a `production` sávon a
> **352** van (`completed`). **Ez a dokumentum ezzel betöltötte a célját** — a további kiadások
> menete a **`docs/PLAY-KIADASI-JEGYZET.md`**-ben van (a **353** már ott van, feltöltésre készen).

| Mit | Állapot | Mérés |
|---|---|---|
| Csomagnév | `hu.hungarianhardstyle.app` | `check-play-track.mjs` |
| **Nyilvános bolt-lap** | **HTTP 200 — ÉL** (korábban 404 volt, mert a bírálat futott) | `check-play-listing.mjs` |
| `production` | **352** (`completed`, 100%-ban kigördült) | `check-play-track.mjs` |
| Zárt teszt (`alpha`) | **352** (completed), a kiadási szöveggel | `check-play-track.mjs` |
| `beta` | üres, **production-nel szinkronizál** | `check-play-products.mjs --tracks` |
| `internal` | 278 (completed) + egy üres piszkozat → **dobd el** | `check-play-track.mjs` |
| Következő csomag | **353** (Firebase major emelés + mért R8-nyereség): `build/HUHS-v1.0.0+353-release.aab` | `check-play-notes.mjs` |
| Termékek országa | **9 ország**: HU, AT, HR, SI, SK, NL, CZ, RS, UA | `check-play-products.mjs` |
| Termékek állapota | 56 `ACTIVE`, 4 `DRAFT` (a 12699 megjelenéséig) | `check-play-products.mjs` |
| Adatvédelmi nyilatkozat | **él** (HTTP 200) | `…/adatvedelmi-nyilatkozat/` |
| ÁSZF | **él** (HTTP 200) | `…/altalanos-szerzodesi-feltetelek-aszf/` |
| **Fióktörlési weboldal** | **él**: `https://hungarianhardstyle.hu/fiok-torles/` (HTTP 200, #12843) | `node tools/create-deletion-page.mjs` |
| Aláírás | **1 identitás** | `check-signing-identity.mjs` |
| Plugin | 2.7.0 fent, élőben igazolt | `verify-submission-payout.mjs --live` |
| Szerver-függvények | telepítve (benne a 9 országos termék-javítás) | `firebase deploy` |

---

## 1. A LEGFONTOSABB SZABÁLY: az országok EGYEZZENEK

⚠️ **Az `alpha` sávon a termékek és az app ugyanabban a 9 országban érhető el.** A **production**
sáv ország-listáját is **pontosan erre a 9 országra** kell állítani — se többre, se kevesebbre:

- Ha a production **több** országot tartalmaz, mint a termékek listája, akkor azokban a vevők
  **telepíteni tudnak, de vásárolni nem** — pontosan az a hiba, amit 2026-09-22-én javítottunk
  (*„A tétel nem áll rendelkezésre az adott országban"*).
- Ha **kevesebbet**, akkor egyszerűen kevesebb helyen lesz elérhető (nem hiba, csak szűkebb).

**A sorrend ezért:** (1) a termékek ország-listája — **kész**; (2) a production sáv ország-listája
ugyanerre a 9 országra; (3) csak ezután kiadás. A `node tools/check-play-products.mjs --tracks`
a kiadás **után** is megmondja, hogy a két lista egyezik-e.

---

## 2. Amit a Console-ban kell kitölteni (App content)

Ezek **nem** olvashatók az API-ból — a Console mutatja a „Hiányos" jelzést. Sorrendben, a mi
válaszainkkal:

| # | Nyilatkozat | A mi válaszunk | Miért |
|---|---|---|---|
| 1 | **Adatbiztonság** (Data safety) | Gyűjtünk: e-mail cím, név/felhasználói profil, **felhasználói tartalom** (chat, komment, beküldés), **fotó** (DJ/szervező kép), **vásárlási előzmény** (kiadvány-jogosultság), **eszköz-/push-token**. Titkosítás átvitel közben: **igen** (HTTPS). Törlés kérhető: **igen** (appon belül). | Ezek ténylegesen a szerveren vannak; a hiányos nyilatkozat a kiadás egyik leggyakoribb elutasítási oka |
| 2 | **Tartalmi besorolás** (IARC kérdőív) | Zene/közösségi app; felhasználói tartalom **van** (chat, komment), erőszak/pornó/szerencsejáték **nincs**. A korhatárt a kérdőív **számolja ki** — a mi elvárásunk **16+ vagy 18+** (a chat és a szöveges tartalom miatt) | A Play a besorolást **kötelezően** kéri a kiadás előtt |
| 3 | **Hirdetések** | **Tartalmaz hirdetést: IGEN** (AdMob: banner + jutalmazott videó) | Ha nem jelöljük, az elutasítás oka lehet |
| 4 | **Célközönség** (target audience) | **Döntés kell** (lásd 5. pont) — a chat és a felhasználói tartalom miatt a **13 év alatti** célközönség **nem** választható | A „gyerekeknek is" választás szigorú családi szabályokat vonna be |
| 5 | **Hírek** (news app) | Az app **hírtartalmat is ad** (hírek, események) → a „news app" kérdésre **igent** kell mondani, és vállalni a hírekre vonatkozó szabályt | Ha nem jelöljük, de van hírszekció, az elutasítás oka lehet |
| 6 | **Alkalmazás-hozzáférés** (App access) | ✅ **KÉSZ:** a bírálói teszt-fiók **létrejött** — `review@hungarianhardstyle.hu` (igazolt e-mail, a bejelentkezés **élőben igazolva**, a szerver is elfogadta). A jelszót a `node tools/create-review-account.mjs` adja ki / állítja újra — **a repóban titkot nem tárolunk**, ezért a jelszó itt **nincs benne**. | Az app bejelentkezést kér: enélkül a bírálat nem tud belépni, és elutasítják |
| 7 | **Felhasználói tartalom** (UGC) | Van chat, cikk-komment, DJ/szervező beküldés — **van jelentés és tiltás** (a funkció létezik, ezt a nyilatkozatban meg kell adni) | A UGC-szabály megköveteli a bejelentés/blokkolás meglétét |
| 8 | Pénzügyi / egészségügyi / kormányzati | **nem** érintett | — |
| 9 | **Adatvédelmi irányelv URL** | `https://hungarianhardstyle.hu/adatvedelmi-nyilatkozat/` (**él**), ÁSZF: `…/altalanos-szerzodesi-feltetelek-aszf/` (**él**) | Mérve, HTTP 200 |

---

## 3. ✅ A fióktörlési **webes hivatkozás** — KÉSZ

**Az appban van fióktörlés** (Beállítások → fiók törlése, a szerveren végigfutó, visszaigazolt
folyamattal — ezt a `tools/verify-live-account-deletion.mjs` élőben méri).

A Play Data safety szakasza **pluszban** kér egy **URL-t**, ahol a felhasználó **az app nélkül** is
kérheti a törlést („Delete account URL"). Ez **elkészült és él**:

> **`https://hungarianhardstyle.hu/fiok-torles/`** (oldal-azonosító **#12843**, HTTP **200**)

A szöveget a **kód írja le, nem találgatás**: a `functions/index.js` `deleteUserReferences()` és
`deleteCommunityUser()` tényleges viselkedését tartalmazza — mi törlődik (fiók, profil, képek, chat,
kommentek, pontok, szavazatok, DJ-átvételek, **vásárlási jogosultsági rekordok**), mi **marad**
(a **Google Play-vásárlás** a Google-fiókodnál — új fiókkal **újra ellenőrizhető**, nem kell újra
fizetni), és mennyi idő alatt (fiók **azonnal**, feltöltött képek **≤48 óra**, e-mailes kérés
**≤30 nap**).

**A szöveg verziókezelve él** a `tools/create-deletion-page.mjs`-ben (`--confirm` nélkül nem ír;
`--confirm --update` frissíti). **⚠️ Ha az éles törlés viselkedése változik, ezt a szöveget is
frissíteni kell** — különben az oldal nem lenne igaz.

---

## 4. A kiadás lépései (sorrendben)

1. **App content** (2. pont) — minden „Hiányos" elem kitöltése, a teszt-fiók megadásával (6. pont).
   - **A korhatár/célközönség döntés megvan: 16+** (a tulajdonos döntése, 2026-09-22).
   - **A fióktörlési URL készen van** (3. pont) — ezt kell a Data safety mezőjébe bemásolni.
2. **Production sáv országai** — **pontosan a 9 ország** (1. pont).
3. **Kiadás létrehozása** a **már feltöltött 352 bundle-ből** — **nem kell új AAB**, mert a 352
   tartalmilag ugyanaz, mint a zárt tesztben élesben lévő csomag. (Ha időközben kliensváltozás
   történik, akkor új verziókód kell, és újra végig kell menni a changelogon.)
4. **Kigördítés: azonnal 100%** (a tulajdonos döntése, 2026-09-22).
5. **Bírálat** — az első nyilvános kiadás bírálata jellemzően **1–7 nap**; utána automatikusan
   kigördül.
6. **Ellenőrzés a kiadás után** (5. pont) — a nyilvános bolt-lap és a termékek ország-listája.

---

## 5. Amit a kiadás UTÁN ellenőrizni lehet innen (eszközökkel)

| Mit | Eszköz | Amit néz |
|---|---|---|
| Megjelent-e a nyilvános bolt-lap | `node tools/check-play-listing.mjs` | a Play-oldal állapota (404 helyett **200**) |
| Teljes-e a bolt-lap tartalma | `node tools/check-play-listing-content.mjs` | leírások hossza + kötelező képek (ikon, grafikus fejléc, telefonos képernyőképek) |
| Mi van élesben | `node tools/check-play-track.mjs` | sávonkénti build és állapot |
| Egyezik-e az ország-lista | `node tools/check-play-products.mjs --tracks` | a production sáv országai vs. a termékek 9 országa |
| A kiadási szöveg kint van-e | `node tools/check-play-notes.mjs` | a changelog és a meta konzisztenciája |
| Aláírás | `node tools/check-signing-identity.mjs` | 1 identitás maradt-e |

---

## 6. Döntések és ami még nyitott

**A tulajdonos döntései (2026-09-22):**

1. **Korhatár / célközönség: 16+** — a chat és a felhasználói tartalom miatt reális, és nem vonja be
   a szigorú családi szabályokat. (Az IARC-kérdőívet ennek megfelelően kell kitölteni; a 13 év alatti
   célközönséget **nem** választjuk.)
2. **Fióktörlési oldal: KÉSZ** (3. pont) — én hoztam létre, a Play Data safety mezőjébe ez az URL való.
3. **Kigördítés: azonnal 100%.**

**Ami még nyitott (Console-only):**

4. **Hír-deklaráció:** az app ad hírtartalmat, ezért a „news app" kérdésre **igent** kell mondani
   (javaslat). Ezt a Console-ban kell megjelölni.
5. **Bírálói teszt-fiók (App access): ✅ KÉSZ.** A `review@hungarianhardstyle.hu` fiók létrejött,
   **igazolt e-maillel**, és a bejelentkezés (e-mail + jelszó) **élőben igazolva** — a szerver is
   elfogadta (`getMyLabelLibrary` → 200). **A jelszót a `tools/create-review-account.mjs` adja ki**
   (`--confirm` létrehoz, `--confirm --reset` új jelszót állít), és **a repóban titkot nem tárolunk**,
   ezért a jelszó itt szándékosan nincs benne. ⚠️ A bírálat **után** érdemes új jelszót adni vagy a
   fiókot törölni.
6. **Adatbiztonsági nyilatkozat** (Data safety) — a 2. pont táblázata szerint, a fióktörlési URL-lel.

---

## 7. Ami MÉRVE nem hiba (hogy ne keressük újra)

- ⚠️ **„A verziókódot (352) már felhasználták"** — a Play egy verziókódot **csak egyszer** fogad el,
  és a 352 **már fent van** a zárt tesztből. **Nem kell új AAB**: a kiadás-létrehozásnál a
  **`Könyvtárból`** (*Add from library*) opcióval a **meglévő** csomag választható, vagy a zárt teszt
  kiadásából a **`Kiadás előléptetése`** (*Promote release*) használható. Ugyanaz a csomag **több
  sávon is lehet** — pont ezért tesztelünk zárt körben, majd léptetünk elő.
- ⚠️ **A kiadás beküldése nem kérdezi a fióktörlési URL-t és a bírálói fiókot** — azok az
  **„Alkalmazás tartalma" nyilatkozatok** között vannak, **nem** a kiadás-varázslóban. **Attól még
  kitöltendők**, mert a bírálat ellenőrzi őket.
- **A 4 `DRAFT` termék** (12699 „Goze – Change of Pace") **szándékos**: a kiadvány `upcoming`,
  megjelenés **2026-09-25**; a megjelenés napján a szinkron **automatikusan aktiválja** őket.
- **A 12475 „Dutch Master – Take Some" és a 12471 „BAZ+"** `is_free = true`, ezért **szándékosan**
  nincs Play-termékük (ingyenes kiadványok).
- **A nyilvános bolt-lap 404-e** zárt tesztben **várt** eredmény.
- ⚠️ **A tesztelői létszám az API-ból NEM mérhető megbízhatóan:** a `tools/check-play-testers.mjs`
  **0-t** adott vissza, miközben a Console-ban **30+ tesztelő** volt. A **Console az irányadó** — ezt
  a tanulságot az eszköz ki is írja, hogy senki ne higgye azt, hogy nincs tesztelő.
