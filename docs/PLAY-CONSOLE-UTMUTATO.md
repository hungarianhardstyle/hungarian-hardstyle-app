# Play Console — hol van mit kell megnyomni (nyilvános kiadás)

Ez az útmutató **kattintási útvonalakat** ad a Play Console-hoz, mert a menük nem maguktól
értetődők. Minden lépésnél ott van a **magyar** és az **angol** elnevezés is (a Console nyelve
fiókonként és verziónként eltérhet, ezért ha a magyar szöveg nálad máshogy hangzik, az angol
segít megtalálni).

> **Először:** nyisd meg a <https://play.google.com/console> oldalt, és **válaszd ki az alkalmazást**
> (`hu.hungarianhardstyle.app`). Az összes alábbi menü **az alkalmazáson belül** van, a **bal oldali
> menüsávban**.

---

## 0. Ha nem találod a menüt (ezt olvasd először)

A Play Console menüje **verziónként és fiókonként máshogy néz ki**, ezért ha a fenti útvonal nálad
nincs meg, **nem baj** — két biztos módszer van:

### a) Először ellenőrizd, hogy az ALKALMAZÁSON BELÜL vagy-e

Az **alkalmazás szintű** menük (köztük az „Alkalmazás tartalma") **csak akkor látszanak**, ha kiválasztottad
az appot. A bal oldali menüben **látnod kell** ezeket:

- **Tesztelés és kiadás** (*Test and release*)
- **Megjelenés a Play Áruházban** (*Store presence*)
- **Elemzések** (*Statistics*)

Ha **ezek nincsenek** a menüben (csak „Minden alkalmazás", „Értesítések", „Pénzkereset", „Beállítások"),
akkor a **fiók szintjén** vagy: a **Kezdőlapon** kattints az **alkalmazás nevére** (`hu.hungarianhardstyle.app`),
és utána jelennek meg az app-menük.

### b) Használd a Console KERESŐJÉT (ez a leggyorsabb)

A Console **tetején** van egy **keresőmező** (*„Keresés a Play Console-ban"* / *Search Play Console*).
Írd be: **`App content`** (az angol szó a magyar felületen is működik), és a találatból **egyenesen
az oldalra ugrasz** — nem kell menüt böngészni. Ugyanígy:
`Data safety`, `Content rating`, `Target audience`, `App access`, `Production`, `Countries`.

### c) A Kezdőlap beállítási listája

A Console **Kezdőlapján** (*Dashboard*) egy **beállítási lépéslista** is van („Alkalmazás beállítása" /
*Set up your app*), benne közvetlen hivatkozásokkal — például **„Tartalom megadása"** /
*Provide app content*. Ha a menüben nem találod, ott biztosan ott van.

### d) Ha így sem megy

Küldj **képernyőképet a bal oldali menüről**, és megmondom pontosan, melyik sor kell.

---

## 1. „Alkalmazás tartalma" — ide kell a legtöbb nyilatkozat

**Útvonal:** bal oldali menü → **Szabályzati program** → **Alkalmazás tartalma**
(*angolul:* Policy and programs → **App content**)

⚠️ Ez **egy gyűjtőoldal**: rajta egy **lista** van minden kötelező nyilatkozattal, mindegyik mellett
egy **„Kezdés"** / **„Megnyitás"** gomb, és a végén egy állapot (**„Kész"** / **„Hiányos"**). Az a cél,
hogy **minden sor zöld legyen**.

Az alábbi sorokat kell kitölteni (a sor neve → mit válassz):

| Sor a listában (magyar / angol) | Mit kell beírni |
|---|---|
| **Adatbiztonság** / *Data safety* | Az adatkategóriák táblázata lent (2. pont) + a **fióktörlési URL** |
| **Tartalmi besorolás** / *Content rating* | Egy **kérdőív** (kb. 10–15 kérdés) — a válaszok lent (3. pont). A végén a rendszer **kiszámolja** a besorolást |
| **Célközönség és tartalom** / *Target audience and content* | Korcsoportok: **16–17** és **18 év felett** bejelölve; a „gyerekeknek szánt" kérdésre **nem** |
| **Hírek** / *News* | „Ez az alkalmazás hírek?" → **Igen** (van hírszekció) |
| **Hirdetmények** / *Ads* | „Tartalmaz hirdetést?" → **Igen** (AdMob) |
| **Alkalmazás-hozzáférése** / *App access* | ⚠️ **A legfontosabb** — lásd 4. pont |
| **Felhasználói tartalom** / *User-generated content* | Van chat/komment/beküldés → **Igen**, és van **jelentés + tiltás** (mindkettő létezik az appban) |
| **Pénzügyi szolgáltatások** / *Financial features* | **Nem** érintett |
| **Egészségügy** / *Health* | **Nem** érintett |
| **Kormányzati alkalmazás** / *Government apps* | **Nem** |
| **Adatvédelmi irányelv** / *Privacy policy* | `https://hungarianhardstyle.hu/adatvedelmi-nyilatkozat/` |

---

## 2. Adatbiztonság (Data safety) — a válaszok

Ebben az űrlapban **adatkategóriánként** kell megadni, hogy gyűjtöd-e, megosztod-e, és miért.
A mi válaszaink (a szerveren ténylegesen tárolt adatok alapján):

| Kérdés az űrlapon | Válasz |
|---|---|
| Gyűjt az app **e-mail-címet**? | **Igen** — fiókkezelés, bejelentkezés |
| **Nevet / felhasználónevet**? | **Igen** — profil |
| **Fényképeket**? | **Igen** — profilkép, beküldött képek (a felhasználó tölti fel) |
| **Üzeneteket** (chat, komment)? | **Igen** — az app funkciója |
| **Vásárlási előzményt**? | **Igen** — a megvásárolt kiadványok jogosultsága |
| **Eszköz- vagy egyéb azonosítót**? | **Igen** — push-értesítési token |
| **Helyzetadatot**? | **Nem** |
| **Névjegyzéket / hívásokat / SMS-t**? | **Nem** |
| Titkosítva van **átvitel közben**? | **Igen** (minden kérés HTTPS) |
| Kérhető **adattörlés**? | **Igen** — appon belül (Beállítások → fiók törlése) |
| **Fióktörlési URL** / *Delete account URL* | `https://hungarianhardstyle.hu/fiok-torles/` |
| **Megosztod más cégekkel**? | Csak a szolgáltatókkal, amik az app működéséhez kellenek (Firebase, AdMob, Cloudinary) — egyébként **nem** |

---

## 3. Tartalmi besorolás (IARC kérdőív) — a válaszok

**Útvonal:** Alkalmazás tartalma → *Tartalmi besorolás* → **Kezdés** → e-mail cím → kategória.

- **Kategória:** *„Minden más alkalmazástípus"* / *All other app types* (nem játék).
- A kérdésekre a **valóság** a válasz: **nincs** erőszak, **nincs** szexuális tartalom, **nincs**
  szerencsejáték, **nincs** kábítószer-ábrázolás.
- **Van** viszont: **felhasználók közötti interakció** (chat, komment) → erre **igen**;
  **digitális vásárlás** → **igen**; **felhasználói tartalom megosztása** → **igen**.
- **Cél:** a kiszámolt besorolás **16+** legyen (a chat és a felhasználói tartalom miatt). Ha a
  kérdőív 18+-t ad, az is elfogadható — a lényeg, hogy **ne** 13 év alatti legyen.

---

## 4. Alkalmazás-hozzáférése (App access) — a bíráló bejelentkezése

**Útvonal:** Alkalmazás tartalma → *Alkalmazás-hozzáférése* → **Utasítások kezelése**.

1. Válaszd: **„Minden vagy néhány funkció korlátozott"** / *All or some functionality is restricted*.
2. **Új utasítás hozzáadása** → adj neki egy nevet (pl. `Bejelentkezés bírálathoz`).
3. **„Hitelesítési adatok hozzáadása"** / *Add authentication credentials*, és írd be:

```
Név:    Play Áruház bíráló
E-mail: review@hungarianhardstyle.hu
Jelszó: <a jelszó, amit a tulajdonos kapott>
```

4. Az **utasítás szövegébe** ezt írd (bemásolható):

```
Az alkalmazás bejelentkezést igényel. A fenti fiókkal lépj be az e-mail-címmel és jelszóval.
Belépés után a főoldalon hírek, események és a rádió látható; a „Kiadványok" fülön
megvásárolható és ingyen letölthető zenék vannak (a „Goze – TikaTika" kiadvány a legfrissebb
fizetős). A „Chat" fül a közösségi beszélgetés, a „Több" fülön a beállítások és az
„Az appról" képernyő (verzió, changelog). A vásárlás a Google Play fiókhoz kötött, ezért a
bírálathoz nem szükséges.
```

5. **Mentés** — és a lista tetején ennek a sornak is **zöldre** kell váltania.

---

## 5. A production (éles) sáv országai — pontosan a 9 ország

**Útvonal:** bal oldali menü → **Tesztelés és kiadás** → **Éles kiadás**
(*angolul:* Test and release → **Production**)

1. Nyisd meg az **„Országok/régiók"** / *Countries/regions* fület.
2. **Add hozzá pontosan ezt a 9 országot:**

```
Magyarország, Ausztria, Szlovákia, Csehország, Szlovénia, Horvátország, Szerbia, Ukrajna, Hollandia
```

⚠️ **Se többet, se kevesebbet!** A termékeink **csak** ebben a 9 országban vásárolhatók; ha ide több
ország kerül, azokban a felhasználók **telepíteni tudnak, de vásárolni nem**.

3. **Mentés.**

---

## 6. A kiadás létrehozása a meglévő 352 csomagból

**Útvonal:** Tesztelés és kiadás → **Éles kiadás** → **„Új kiadás létrehozása"** / *Create new release*

1. Ha felajánlja a **korábban feltöltött** csomagot (352), **válaszd azt** — **nem kell új AAB**.
2. **Kiadási megjegyzések** / *Release notes*: másold be a rövid szöveget a
   `docs/PLAY-KIADASI-JEGYZET.md` **1. pontjából**.
3. **Kigördítés:** **100%** (a tulajdonos döntése).
4. **„Kiadás áttekintése"** → **„Kiadás indítása"** / *Start rollout*.
5. Ezután a **bírálat** következik (jellemzően **1–7 nap**); az állapot az oldal tetején látszik.

---

## 7. Az `internal` sávon ragadt üres piszkozat eldobása

**Útvonal:** Tesztelés és kiadás → **Belső tesztelés** / *Internal testing*

- Ha ott egy **piszkozat** („Piszkozat" / *Draft*) sor van kiadás nélkül, nyisd meg, és a jobb felső
  **„Elvetés"** / *Discard* gombbal dobd el. Így nem marad gazdátlan piszkozat.

---

## 8. Ellenőrző lista a végére

- [ ] Az **Alkalmazás tartalma** oldalon **minden sor zöld** (nincs „Hiányos")
- [ ] Az **Alkalmazás-hozzáférése** sor kitöltve a bírálói fiókkal
- [ ] **Éles kiadás → Országok:** pontosan a **9 ország**
- [ ] **Éles kiadás:** kiadás elindítva, **100%**
- [ ] **Belső tesztelés:** nincs ott maradt piszkozat
- [ ] A **zárt teszt** sávja változatlanul él (a tesztelők továbbra is kapják a frissítéseket)

**Ami ezután jön (ezt én ellenőrzöm):** a nyilvános bolt-lap megjelenése
(`node tools/check-play-listing.mjs` → 404 helyett **200**), és hogy a production ország-listája
**pontosan egyezik-e** a termékek 9 országával (`node tools/check-play-products.mjs --tracks`).
