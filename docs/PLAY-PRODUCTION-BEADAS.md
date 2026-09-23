# Nyilvános (production) kiadás — a beadás terve

Ez a dokumentum a **nyilvános Play-kiadás** előkészítése: mi az, ami **mérve rendben van**, mi az,
ami **hiányzik**, és milyen **sorrendben** kell a Play Console-ban haladni. Minden állítás mellett ott
van a mérés módja — ahol nem tudtam mérni, az **szándékosan jelölve** van.

> **A tulajdonos jelzése (2026-09-22):** *„van már éles kiadás engedélyem"* — vagyis a **production
> access** megvan, ezért a **12 tesztelő / 14 folyamatos nap** követelmény **nem** blokkol.

---

## 0. Mért állapot (2026-09-22)

| Mit | Állapot | Mérés |
|---|---|---|
| Csomagnév | `hu.hungarianhardstyle.app` | `check-play-track.mjs` |
| Zárt teszt (`alpha`) | **352** (completed), a kiadási szöveggel | `check-play-track.mjs` |
| `beta` | üres, **production-nel szinkronizál** | `check-play-products.mjs --tracks` |
| `production` | **0 ország**, nincs kiadás | `check-play-products.mjs --tracks` |
| `internal` | 278 (completed) + egy üres piszkozat → **dobd el** | `check-play-track.mjs` |
| Nyilvános bolt-lap | **404** (zárt tesztben nincs) — várt eredmény | `check-play-listing.mjs` |
| Termékek országa | **9 ország**: HU, AT, HR, SI, SK, NL, CZ, RS, UA | `check-play-products.mjs` |
| Termékek állapota | 56 `ACTIVE`, 4 `DRAFT` (a 12699 megjelenéséig) | `check-play-products.mjs` |
| Adatvédelmi nyilatkozat | **él** (HTTP 200) | `…/adatvedelmi-nyilatkozat/` |
| ÁSZF | **él** (HTTP 200) | `…/altalanos-szerzodesi-feltetelek-aszf/` |
| **Fióktörlési weboldal** | **NINCS (404)** ← hiányzik, lásd 3. pont | `…/fiok-torles/` |
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
| 6 | **Alkalmazás-hozzáférés** (App access) | ⚠️ **BEJELENTKEZÉS KÖTELEZŐ** → a bírálóknak **teszt-fiókot kell adni** (e-mail + jelszó), és leírni, hol érdemes körülnézniük (zene, chat, kedvencek). **Ez nélkül a bírálat nem tud belépni, és elutasítják.** | Ez a leggyakoribb elutasítási ok a bejelentkezést igénylő appoknál |
| 7 | **Felhasználói tartalom** (UGC) | Van chat, cikk-komment, DJ/szervező beküldés — **van jelentés és tiltás** (a funkció létezik, ezt a nyilatkozatban meg kell adni) | A UGC-szabály megköveteli a bejelentés/blokkolás meglétét |
| 8 | Pénzügyi / egészségügyi / kormányzati | **nem** érintett | — |
| 9 | **Adatvédelmi irányelv URL** | `https://hungarianhardstyle.hu/adatvedelmi-nyilatkozat/` (**él**), ÁSZF: `…/altalanos-szerzodesi-feltetelek-aszf/` (**él**) | Mérve, HTTP 200 |

---

## 3. ⚠️ HIÁNYZÓ ELEM: a fióktörlési **webes hivatkozás** (az appban VAN törlés!)

**Az appban van fióktörlés** (Beállítások → fiók törlése, a szerveren végigfutó, visszaigazolt
folyamattal — ezt a `tools/verify-live-account-deletion.mjs` élőben méri) — **ez az egyik követelmény,
és teljesül**.

A Play Data safety szakasza viszont **pluszban** kér egy **URL-t**, ahol a felhasználó **az app
nélkül** is kérheti a fiókja törlését („Delete account URL"). Ez ma **404**:

- `https://hungarianhardstyle.hu/fiok-torles/` → **404**
- `https://hungarianhardstyle.hu/adattorles/` → **404**

**A teendő:** egy rövid oldal a honlapon (pl. `fiok-torles` slug), amin ez áll: mi törlődik (fiók,
profil, chat-üzenetek, kedvencek, feltöltött képek), mi **marad** (a megvásárolt zenék jogosultsága a
Play-nél és a számlázási előzmény a jogszabályi megőrzés miatt), meddig tart (legfeljebb 30 nap), és
hogyan lehet kérni (appból egy koppintás, vagy e-mail az `info@hungarianhardstyle.hu`-ra).
**A tartalmat megírom neked** — csak szólj.

---

## 4. A kiadás lépései (sorrendben)

1. **App content** (2. pont) — minden „Hiányos" elem kitöltése, a teszt-fiók megadásával (6. pont).
2. **Fióktörlési oldal** (3. pont) — létrehozás + bemásolás a Console-ba.
3. **Production sáv országai** — **pontosan a 9 ország** (1. pont).
4. **Kiadás létrehozása** a **már feltöltött 352 bundle-ből** — **nem kell új AAB**, mert a 352
   tartalmilag ugyanaz, mint a zárt tesztben élesben lévő csomag. (Ha időközben kliensváltozás
   történik, akkor új verziókód kell, és újra végig kell menni a changelogon.)
5. **Fokozatos kigördítés**: 20% → (1–2 nap után) 50% → 100%. Így egy váratlan hiba csak a
   felhasználók egy részét érinti.
6. **Bírálat** — az első nyilvános kiadás bírálata jellemzően **1–7 nap**; utána automatikusan
   kigördül a beállított százalékig.
7. **Ellenőrzés a kiadás után** (5. pont) — a nyilvános bolt-lap és a termékek ország-listája.

---

## 5. Amit a kiadás UTÁN ellenőrizni lehet innen (eszközökkel)

| Mit | Eszköz | Amit néz |
|---|---|---|
| Megjelent-e a nyilvános bolt-lap | `node tools/check-play-listing.mjs` | a Play-oldal állapota (404 helyett **200**) |
| Mi van élesben | `node tools/check-play-track.mjs` | sávonkénti build és állapot |
| Egyezik-e az ország-lista | `node tools/check-play-products.mjs --tracks` | a production sáv országai vs. a termékek 9 országa |
| A kiadási szöveg kint van-e | `node tools/check-play-notes.mjs` | a changelog és a meta konzisztenciája |
| Aláírás | `node tools/check-signing-identity.mjs` | 1 identitás maradt-e |

---

## 6. Nyitott döntések (a tulajdonosé)

1. **Korhatár / célközönség:** a chat és a felhasználói tartalom miatt **16+ vagy 18+** a reális.
   (A 13 év alatti célközönség a szigorú családi szabályokat vonná be — nem javaslom.)
2. **Hír-deklaráció:** vállaljuk-e a „news app" nyilatkozatot (az app ad hírtartalmat) — **igen a
   javaslat**, mert a hírszekció látható.
3. **Teszt-fiók a bírálóknak:** melyik e-mail címmel jöjjön létre (pl. `review@hungarianhardstyle.hu`
   vagy egy meglévő tesztfiók), és legyen-e benne néhány kedvenc/üzenet, hogy a bíráló lásson
   tartalmat.
4. **Fióktörlési oldal:** megírjam-e a szöveget (3. pont), és a WordPress adminban te hozod létre,
   vagy csináljam meg a meglévő szerveres úton (jóváhagyással).
5. **Kigördítés:** 20% → 100% fokozatosan (javaslat), vagy azonnal 100%.

---

## 7. Ami MÉRVE nem hiba (hogy ne keressük újra)

- **A 4 `DRAFT` termék** (12699 „Goze – Change of Pace") **szándékos**: a kiadvány `upcoming`,
  megjelenés **2026-09-25**; a megjelenés napján a szinkron **automatikusan aktiválja** őket.
- **A 12475 „Dutch Master – Take Some" és a 12471 „BAZ+"** `is_free = true`, ezért **szándékosan**
  nincs Play-termékük (ingyenes kiadványok).
- **A nyilvános bolt-lap 404-e** zárt tesztben **várt** eredmény.
- ⚠️ **A tesztelői létszám az API-ból NEM mérhető megbízhatóan:** a `tools/check-play-testers.mjs`
  **0-t** adott vissza, miközben a Console-ban **30+ tesztelő** volt. A **Console az irányadó** — ezt
  a tanulságot az eszköz ki is írja, hogy senki ne higgye azt, hogy nincs tesztelő.
