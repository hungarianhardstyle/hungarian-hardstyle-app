# Play Console — kiadási jegyzet (másolható)

Ez a fájl a **következő feltöltéshez** tartozó, **kész, másolható** changelog-szövegeket
tartalmazza. A szabály ugyanaz, mint a `docs/RELEASE_CHANGELOG_CHECKLIST.md`-ben:
ugyanaz a magyar changelog megy a Play Console-ra, az app Névjegyére
(`lib/data/app_changelog.dart`) és a plugin kiadásjegyzékére.

<!-- play-notes-meta
currentBuild: 334
currentVersion: 1.0.0
lastPublishedBuild: 328
aab: build/HUHS-v1.0.0+334-release.aab
sha256: 5834831C474722C89BF2B5FA938AA2BC0E6E36BDFE9EDE7A002BD468F490B228
-->

## 0. ÉLŐ ÁLLAPOT a Play-en (mérve, `node tools/check-play-track.mjs`)

A Play Developer API-t **olvasásra** kérdezve (2026-09-19, a 334 build előtt):

| Sáv | Állapot | Build |
|---|---|---|
| **alpha (zárt teszt)** | **completed** (100%-ban kigördült) + egy **üres piszkozat** | **332** — „332 (1.0.0)", kiadási szöveggel |
| beta | üres | — |
| production | üres | — |
| internal | completed + egy üres piszkozat | 278 |

- Vagyis **a zárt teszt sávján most a 332 él**, és mellette egy **befejezetlen (draft) kiadás** áll — a **333 nem ment ki** egyetlen sávra sem (ezt a mérés igazolta: se az alpha, se az internal nem hozta).
- **A 333-at tehát semmi nem váltja a tesztelőknél**: a **334** viszi mindazt, amit a 333 tartalmazott volna.
- A feltöltött AAB-ek a Playen: 1, 155, 159, 171, 175, 178, 181, 190, 204, 277, 278, 297, 319, 328, 329, 330, 331, **332** (és a most feltöltendő **334**).
- **A zárt teszt sávján egyszerre egy kiadás él**, ezért a 334 automatikusan felváltja a 332-t; a félbemaradt **piszkozatot** a Play Console-ban **el kell dobni** (Discard), különben ott marad.
- Az alkalmazott kiadási szöveg a **hosszabb (1b.) változat** volt — a rövidebb (1.) is ugyanazt mondja, csak tömörebben.

## A feltöltendő AAB (mérve)

| | |
|---|---|
| Fájl | `build/HUHS-v1.0.0+334-release.aab` |
| Verzió | `1.0.0` (versionName) |
| Verziókód | **334** (a merge-elt release manifestből visszaolvasva) |
| Méret | 79,54 MB |
| SHA-256 | 5834831C474722C89BF2B5FA938AA2BC0E6E36BDFE9EDE7A002BD468F490B228 |

**Miért a 334-et kell feltenni:** ez a legfrissebb, és **minden korábbi javítást tartalmaz**
(323–334). A Play-en a legutóbb publikált build a **328**, a zárt teszt sávján pedig a **332** él —
a **333 nem ment ki** (egy félbemaradt piszkozat maradt helyette), ezért a tesztelők a **334-gyel**
kapják meg az Achievement-útmutató javítását, a három új pontforrást és a rang-frissítést.

> **FONTOS:** a **korábbi AAB-eket (köztük a 333-at) ne töltsd fel** — a 334 mindegyiket tartalmazza,
> és a 333-nál kisebb verziókódú csomagot a Play amúgy sem fogadna el.

**A plugin ehhez 2.5.7** (`build/huhs-mobile-api-2.5.7.zip`) — **ezt is fel kell tölteni**, mert a
létrehozás a plugin új végpontjait használja (a 2.5.6-tal a mentés „nem engedélyezett"-et adna).

## 1. Play Console — RÖVID (ezt másold be)

A tulajdonos kérése: *„röviden kéne a Playbe"*. A Play a kiadási megjegyzést a frissítés
kártyáján **rövidítve** mutatja, ezért a **rövid** szöveg a jó. A részletes lista nem vész el —
az **az app Névjegyében** van (3. pont), és a felhasználó ott bármikor megnézheti.

A Play **nyelvenként 500 karaktert** enged ([súgó](https://support.google.com/googleplay/android-developer/answer/9859348?hl=en));
az alábbi blokk **mérve a limit töredéke** (a pontos számot a `tools/check-play-notes.mjs` írja ki).

```play-notes
- ÚJ: napi aktivitási pont — kommentért és chatért 1–5 pont jár, a szerver számolja.
- ÚJ: kiadvány megvásárlásáért +20, jóváhagyott beküldésért +10 pont jár.
- Az Achievement-útmutató pontos leírást kapott (napi keretek, szabályok).
- A rangod és a jelvényed szintlépésnél magától frissül, nem kell újranyitni az appot.
- A hírek, a DJ-k és az események listája görgetés közben már nem villog.
```

## 1b. Play Console — ha bővebben szeretnéd (tartalék)

Ugyanaz, hosszabban — ez is a limiten belül van. Akkor használd, ha részletesebben akarod
felsorolni, mit kap a felhasználó.

```play-notes
- ÚJ: napi aktivitási pont — kommentért és chatért 1–5 pont jár, a szerver számolja.
- ÚJ: kiadvány-vásárlásért +20 pont jár minden változatért.
- ÚJ: a jóváhagyott beküldésekért (esemény, DJ, szervező) +10 pont jár.
- Az Achievement-útmutató pontos leírásokat kapott: napi keretek.
- A rang és a jelvény szintlépésnél magától frissül.
- A hírek, a DJ-k és az események listája görgetés közben már nem villog.
- A kedvelt hír pontját a lájk visszavonása nem veszi el.
```

## 2. Play Console — CSAK akkor, ha a 329 is kiment volna

**Most NE ezt használd!** Ez a blokk csak a **330** változásait sorolja fel, ezért akkor való, ha
a 329 **már kint van**, és csak a rákövetkező kiadás megy fel. Most az **1. pont** blokkját kell
bemásolni (mert a 329 nem ment ki).

```play-notes
- Adminoknak: a HUHS adminban új menüpontok — kvíz, kérdőív és nyereményjáték eredményei.
- A Vezérlőközpontban a Hírlevél, a Shortcode-ok és a Beállítások is megnyitható.
```

## 3. App (Több → Névjegy) — tételes, build szerint

Ez a lista **maga az app** (`lib/data/app_changelog.dart`), ezért külön feltölteni nem kell;
itt azért van, hogy egy helyen látsszon, mit kap a felhasználó. A sorok a legfrissebbel kezdődnek.

### 334 — pontos Achievement-útmutató, három új pontforrás, rang-frissítés
- Az Achievement-útmutató (Több → Achievementek) pontos leírásokat kapott: a napi keretek (lájk 3, komment 3, beküldés 3), a lájkpont véglegessége, és az is, hogy az esemény/meetup pont **eseményenként egyszer** jár, de lemondásnál elvész.
- A szintek és jelvények listája mostantól a szerverről jön, ezért azonnal követi, ha az adminban átírnak egy küszöböt vagy nevet.
- Kiadvány megvásárlásáért +20 pont jár minden megvásárolt változatért (a vásárlást a Google Play ellenőrzi).
- A jóváhagyott beküldésekért (esemény, DJ, szervező) +10 pont jár a beküldőnek, naponta legfeljebb 3 beküldésért.
- ÚJ napi aktivitási pont: a cikkhez írt hozzászólásaidért és a chat-üzeneteidért a következő napon 1–5 pontot kapsz, amennyit a szerver az aktivitásodból számol.
- A rang és a jelvény továbbra is gyorsítótárból jelenik meg azonnal, de szintlépésnél magától frissül.

### 333 — NEM ment ki (a tartalma a 334-ben van)
- A 333 elkészült, de **egyetlen Play-sávra sem került fel** (a mérés szerint az alpha és az internal sávon is csak egy üres piszkozat maradt). A tartalma **változatlanul a 334-ben** van, ezért a tesztelők onnan kapják meg.

### 332 — villogás javítása + lájkpont-jelzés
- A hírek, a DJ-k és az események listája görgetés közben már nem villog — a képek áttűnés nélkül, azonnal megjelennek.
- Ha a napi lájkpontod (3) elfogyott, az app mostantól szól, mielőtt lájkolnál — eddig csendben maradt, pedig ilyenkor nem járt pont.
- A hír kedveléséért járó pontot a lájk visszavonása már nem veszi el, és a régebben tévesen elvett lájkpontok visszaálltak.

### 331 — létrehozás a natív adminból (kérdőív, nyereményjáték, kvíz)
- A HUHS adminban (natív) mostantól új kérdőív, nyereményjáték és kvíz is létrehozható — nem kell hozzá a WordPress admin.
- A kvíz-szerkesztőben kérdéseket vehetsz fel 2–6 válasszal, és bepipálhatod a helyes választ; mentés előtt minden hibát megnevez a képernyő.
- A nyereményjátéknál a helyes válasz sorszámát adod meg, a látszási napokat pedig számban — a lista pedig azonnal frissül.

### 330 — natív admin menüpontok (kvíz, kérdőív, nyereményjáték)
- A HUHS Vezérlőközpontban (natív admin) új menüpontok: „Kvíz és játékok", „Kérdőív" és „Nyereményjáték" — a kérdőív eredményei és a nyereményjáték résztvevői mostantól innen is elérhetők.
- A Vezérlőközpontban elérhető lett a „Hírlevél", a „Shortcode-ok" és a „Beállítások" menüpont is (eddig a háttérben már működtek, de nem lehetett megnyitni őket).

### 329 — chat-lapozás, azonnali állapot, natív nyereményjáték-admin
- A Chatben lefelé görgetve betölti a régebbi üzeneteket — akár hetekkel ezelőttit is visszaolvashatsz, és egy gombbal visszaugorhatsz a legfrissebbhez.
- A nyereményjáték és a kérdőív „már játszottam / már szavaztam" állapota azonnal megjelenik nyitáskor, nem kell a betöltésre várni.
- Adminoknak: új „Résztvevők" nézet a nyereményjátékhoz az appban — ki játszott, mit válaszolt, helyes volt-e, és ki nyert.

### 328 — „További hírek" kártya + GYIK
- A főoldalon a „További hírek" sor ugyanolyan kártyaformát kapott, mint a kérdőív és a nyereményjáték — így egységes a megjelenés.
- A GYIK (Segítség) témakörökre bontva, érthetőbben — és a pontok, valamint a napi limitek a valós értékeket mutatják.

### 327 — kiadási jegyzet a Névjegy alatt
- ÚJ: a Névjegy alatt mostantól látszik a kiadási jegyzet (changelog) verziószámmal.
- Az aktuális verzió ki van emelve, alatta a korábbi kiadások újdonságai.

### 326 — chat és cikk-hozzászólás szerkesztése
- A Chatben a saját üzenetedet szerkesztheted, az admin bárkiét is — és az admin törölhet.
- Ugyanez a cikkek alatti hozzászólásoknál: a sajátodat szerkesztheted, az admin bárkiét.
- A szerkesztett üzenet és hozzászólás mellett „szerkesztve" jelzés látszik.

### 325 — értesítések: „összes törlése" fülre szűkítve
- Az értesítéseknél az „összes törlése" már csak a látható fület üríti: az Aktív fül az aktívakat, az Archivált fül az archiváltakat.
- A törlés megerősítő szövege megmondja, melyik fület érinti.

### 324 — nyertes és kérdőív azonnali frissülése
- A nyereményjáték nyertese már azonnal megjelenik a kártyán, nem késik perceket.
- A kérdőív nyitása és zárása is azonnal követi a szervert.

### 323 — kérdőív-eredmények javítása
- A kérdőív eredményeinél már a kérdőív saját válaszai látszanak az éves szavazás adatai helyett.
- A nyereményjátéknál eltűnt a felesleges kép mező.

## 4. HUHS Mobile API WordPress-plugin — kiadásjegyzék (2.5.7)

A plugin csomag: `build/huhs-mobile-api-2.5.7.zip` (45 fájl, 142,9 KB,
SHA-256 `352223459F8DC5318321303B8BF835623AE8856465F15412E03D5002F744F2E9`).

```text
- ÚJ: a natív adminból létrehozható új KÉRDŐÍV, NYEREMÉNYJÁTÉK és KVÍZ (admin-create.php).
- A mezők kulcsa a valódi meta-kulcs, ezért a mentés nem tud elcsúszni a WordPress-űrlaptól.
- Validáció a szerveren is: kérdőív 2–6 válasz, nyereményjáték 3–5 válasz + helyes válasz, kvíz 1+ kérdés 2–6 válasszal és megjelölt helyes válasszal.
- A `_huhs_prize_correct` 1-alapú (emberi) sorszámát a szerver fordítja 0-alapú indexre.
- A haladó beállítások (jutalomsávok, idővonal, hang-borítók, „találd ki a zenét” típusok) szándékosan a WordPress adminban maradnak.
- A nyilvános végpontok változatlanok; UID/hash továbbra sem megy ki a kliensnek.
```

## 5. Ellenőrzés feltöltés előtt

1. `node tools/check-play-notes.mjs` — a Play-blokkok hossza és a build-lefedettség.
2. `flutter test test/data/app_changelog_test.dart` — az app changelogja egyezik a `pubspec.yaml`-lel.
3. Az AAB verziókódja a merge-elt manifestből: **334**.
4. `node tools/verify-native-admin-menu.mjs` — a natív admin menüpontjai és a plugin végpontjai egyeznek.
5. `node tools/verify-achievement-points.mjs` — az achievement-pontok konzisztenciája (ÉLES, csak olvas).
6. `node tools/verify-achievement-guide.mjs` — az Achievement-útmutató szövege egyezik a kóddal (napi keretek, pontértékek, létező források).
7. `node tools/check-play-track.mjs` — mi van tényleg a Play sávjain.
