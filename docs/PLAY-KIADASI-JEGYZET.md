# Play Console — kiadási jegyzet (másolható)

Ez a fájl a **következő feltöltéshez** tartozó, **kész, másolható** changelog-szövegeket
tartalmazza. A szabály ugyanaz, mint a `docs/RELEASE_CHANGELOG_CHECKLIST.md`-ben:
ugyanaz a magyar changelog megy a Play Console-ra, az app Névjegyére
(`lib/data/app_changelog.dart`) és a plugin kiadásjegyzékére.

<!-- play-notes-meta
currentBuild: 330
currentVersion: 1.0.0
lastPublishedBuild: 328
aab: build/HUHS-v1.0.0+330-release.aab
sha256: 094C860547BA154417BEC1981AF88B25535B83BC8496EACEB6377937926DF496
-->

## A feltöltendő AAB (mérve)

| | |
|---|---|
| Fájl | `build/HUHS-v1.0.0+330-release.aab` |
| Verzió | `1.0.0` (versionName) |
| Verziókód | **330** (a merge-elt release manifestből visszaolvasva) |
| Méret | 79,38 MB |
| SHA-256 | `094C860547BA154417BEC1981AF88B25535B83BC8496EACEB6377937926DF496` |

**Miért a 330-at kell feltenni:** ez a legfrissebb, és **minden korábbi javítást tartalmaz**
(323–330). A Play-en a legutóbb publikált build a **328**; a **329 soha nem ment ki**, ezért a
felhasználók most a **329 és a 330 újdonságait** kapják egyben.

> **FONTOS:** a **329-es AAB-et ne töltsd fel** — a 330 ugyanazt tartalmazza, plusz a natív admin
> menüpontjait. Ha a 329-et is feltöltenéd, a Play verziókód szerint a 330-at fogja kiszolgálni,
> de felesleges kör.

## 1. Play Console — RÖVID (ezt másold be)

A tulajdonos kérése: *„röviden kéne a Playbe"*. A Play a kiadási megjegyzést a frissítés
kártyáján **rövidítve** mutatja, ezért a **rövid** szöveg a jó. A részletes lista nem vész el —
az **az app Névjegyében** van (3. pont), és a felhasználó ott bármikor megnézheti.

A Play **nyelvenként 500 karaktert** enged ([súgó](https://support.google.com/googleplay/android-developer/answer/9859348?hl=en));
az alábbi blokk **mérve a limit töredéke** (a pontos számot a `tools/check-play-notes.mjs` írja ki).

```play-notes
- Adminoknak: a HUHS adminban új menüpontok — kvíz, kérdőív és nyereményjáték eredményei.
- Chat: a régebbi üzenetek lefelé görgetve betöltődnek.
- A „már szavaztam / már játszottam” állapot azonnal látszik.
```

## 1b. Play Console — ha bővebben szeretnéd (tartalék)

Ugyanaz, hosszabban — ez is a limiten belül van. Akkor használd, ha részletesebben akarod
felsorolni, mit kap a felhasználó.

```play-notes
- Adminoknak: a natív HUHS adminban új menüpontok — Kvíz és játékok, Kérdőív, Nyereményjáték.
- Adminoknak: a kérdőív eredményei és a nyereményjáték résztvevői az adminból is elérhetők.
- Chat: a régebbi üzenetek lefelé görgetve betöltődnek.
- A „már szavaztam / már játszottam” állapot azonnal látszik.
- A főoldalon a „További hírek” sor egységes kártyaformát kapott.
- Az értesítéseknél az „összes törlése” már csak a látható fület üríti.
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

## 4. HUHS Mobile API WordPress-plugin — kiadásjegyzék (2.5.6)

A plugin csomag: `build/huhs-mobile-api-2.5.6.zip` (44 fájl, 139,0 KB,
SHA-256 `492CC69DF5115AE5EBCB4D33AE6F8C77B1268468508A4FB2CBD2782F8B28FF9E`).

```text
- ÚJ: a nyereményjáték admin-nézete az appban (prize_games, prize_results): játéklista, válaszmegoszlás a helyes válasz jelölésével, résztvevők és nyertes.
- Az app-admin játék-nézet nem ad ki UID-t és hash-t a kliensnek.
- GYIK: 7 témakör, 31 érthető kérdés-felelet; a régi, kategóriátlan bejegyzések vázlatba kerülnek (nem törlődnek).
- A migráció megkíméli a tulajdonos kézzel írt/átírt GYIK-szövegét.
- Az app oldalán nincs API-törő változás: a meglévő végpontok változatlanok.
```

## 5. Ellenőrzés feltöltés előtt

1. `node tools/check-play-notes.mjs` — a Play-blokkok hossza és a build-lefedettség.
2. `flutter test test/data/app_changelog_test.dart` — az app changelogja egyezik a `pubspec.yaml`-lel.
3. Az AAB verziókódja a merge-elt manifestből: **330**.
4. `node tools/verify-native-admin-menu.mjs` — a natív admin menüpontjai és a plugin végpontjai egyeznek.
