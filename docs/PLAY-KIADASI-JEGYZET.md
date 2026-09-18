# Play Console — kiadási jegyzet (másolható)

Ez a fájl a **következő feltöltéshez** tartozó, **kész, másolható** changelog-szövegeket
tartalmazza. A szabály ugyanaz, mint a `docs/RELEASE_CHANGELOG_CHECKLIST.md`-ben:
ugyanaz a magyar changelog megy a Play Console-ra, az app Névjegyére
(`lib/data/app_changelog.dart`) és a plugin kiadásjegyzékére.

<!-- play-notes-meta
currentBuild: 328
currentVersion: 1.0.0
lastPublishedBuild: 322
aab: build/HUHS-v1.0.0+328-release.aab
sha256: C8D3BEDBFE7D24C8B6F0ECB004D23AA07E986C81332BF1A934D38B681B660EB9
-->

## A feltöltendő AAB (mérve)

| | |
|---|---|
| Fájl | `build/HUHS-v1.0.0+328-release.aab` |
| Verzió | `1.0.0` (versionName) |
| Verziókód | **328** (a merge-elt release manifestből visszaolvasva) |
| Méret | 79,22 MB |
| SHA-256 | `C8D3BEDBFE7D24C8B6F0ECB004D23AA07E986C81332BF1A934D38B681B660EB9` |

**Miért a 328-at kell feltenni:** ez a legfrissebb, és **minden korábbi javítást tartalmaz**
(323–328). A Play-en a legutóbb publikált build a **322** (ezt a tulajdonos jelezte), ezért
a felhasználók **egyszerre** kapják meg a 323–328 összes változását — a kiadási jegyzetnek is
ezt kell tükröznie, különben a javítások fele láthatatlan maradna.

> **Ha a 323–327 közül valamelyik mégis kiment a Playre**, akkor a „teljes ugrás" blokk
> helyett a 328-hoz tartozó rövidebb blokk való (lásd lent), és a `lastPublishedBuild`
> értékét itt kell átírni — a `tools/check-play-notes.mjs` erre figyelmeztet.

## 1. Play Console — RÖVID (ezt másold be)

A tulajdonos kérése: *„röviden kéne a Playbe"*. A Play a kiadási megjegyzést a frissítés
kártyáján **rövidítve** mutatja, ezért a **rövid** szöveg a jó: 3 sor, minden sor egy
érthető újdonság. A részletes lista nem vész el — az **az app Névjegyében** van (3. pont),
és a felhasználó ott bármikor megnézheti.

A Play **nyelvenként 500 karaktert** enged ([súgó](https://support.google.com/googleplay/android-developer/answer/9859348?hl=en));
az alábbi blokk **mérve a limit töredéke** (a pontos számot a `tools/check-play-notes.mjs` írja ki).

```play-notes
- Súgó (GYIK): témakörökre bontva, érthetően.
- Egységes kártyák a főoldalon.
- Chat- és hozzászólás-szerkesztés, jobb értesítéskezelés.
```

## 1b. Play Console — ha bővebben szeretnéd (tartalék)

Ugyanaz, hosszabban — ez is a limiten belül van (**458/500**). Akkor használd, ha
részletesebben akarod felsorolni, mit kap a felhasználó.

```play-notes
- ÚJ: a GYIK (Segítség) témakörökre bontva, érthető szöveggel.
- ÚJ: kiadási jegyzet a Névjegy alatt, verziószámmal.
- A Chatben és a cikkek alatti hozzászólásoknál a saját üzenetedet szerkesztheted.
- Az értesítéseknél az „összes törlése” már csak a látható fület üríti.
- A nyereményjáték nyertese és a kérdőív állapota azonnal frissül.
- A kérdőív eredményeinél a saját válaszai látszanak.
- A főoldalon a „További hírek” sor egységes kártyaformát kapott.
```

## 2. Play Console — ha csak a 328 megy ki (tartalék)

Ezt akkor használd, ha a 323–327 már fent van a Playen.

```play-notes
- A főoldalon a „További hírek” sor ugyanolyan kártyaformát kapott, mint a kérdőív és a nyereményjáték.
- A GYIK (Segítség) témakörökre bontva, érthető szöveggel; a pontok és a napi limitek a valós értékeket mutatják.
```

## 3. App (Több → Névjegy) — tételes, build szerint

Ez a lista **maga az app** (`lib/data/app_changelog.dart`), ezért külön feltölteni nem kell;
itt azért van, hogy egy helyen látsszon, mit kap a felhasználó. A sorok a legfrissebbel kezdődnek.

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

## 4. HUHS Mobile API WordPress-plugin — kiadásjegyzék (2.5.5)

A plugin csomag: `build/huhs-mobile-api-2.5.5.zip` (44 fájl, 138,0 KB,
SHA-256 `06512149E638EFC41F168C839A021659B37D7A090990CBFA09242B3996CCE3D0`).

```text
- GYIK: 7 témakör, 31 érthető kérdés-felelet; a régi, kategóriátlan bejegyzések vázlatba kerülnek (nem törlődnek).
- A migráció megkíméli a tulajdonos kézzel írt/átírt GYIK-szövegét.
- A migráció verziójelzője 5 — a 2.5.3 migrációja már lefutott, ezért a 4-es jelzővel a szigorúbb nyugdíjazás nem indult volna el.
- A faq.php érvénytelen UTF-8 bájtjai javítva (a WordPress szerkesztő hibás karakterei megszűntek).
- Az app oldalán nincs API-törő változás: a meglévő végpontok változatlanok.
```

## 5. Ellenőrzés feltöltés előtt

1. `node tools/check-play-notes.mjs` — a Play-blokkok hossza és a build-lefedettség.
2. `flutter test test/data/app_changelog_test.dart` — az app changelogja egyezik a `pubspec.yaml`-lel.
3. Az AAB verziókódja a merge-elt manifestből: **328**.
