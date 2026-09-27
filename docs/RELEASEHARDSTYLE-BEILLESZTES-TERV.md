# releasehardstyle.nl beépítése az appba — mérés és terv (2026-09-27)

> **A tulajdonos kérése:** *„https://releasehardstyle.nl/releases/ — ezt nem lehet valahogy beépíteni
> az appba natív? a prew linkekkel együtt"*
>
> **A rövid válasz: IGEN, megoldható natívan** — a lista és az adatlapok **statikus, jól tagolt
> HTML-ben** vannak, minden kiadványhoz tartozik borító, előadó, cím, dátum, kiadó és hallgatási link,
> a „preview" pedig külső beágyazás (YouTube / Streamable). **Egy dolgot viszont el kell dönteni:**
> a WordPress REST API-jukat a `robots.txt` **tiltja** (`Disallow: /wp-json/`), ezért azt **nem**
> használjuk; a nyilvános HTML-oldalakat olvassuk, **szerveroldali gyorsítótárral** (egy kérés
> óránként, nem felhasználónként), és a felületen **feltüntetjük a forrást**.

## 1. Amit mértem (mind a mai, 2026-09-27-i állapot)

Mérőeszközök (csak olvasnak, nem tárolnak tartalmat):
`tmp/probe-releasehardstyle.mjs` … `-8.mjs`.

| Mit mértem | Eredmény |
|---|---|
| A lista oldala | `https://releasehardstyle.nl/releases/` → **HTTP 200**, 417 918 bájt, WordPress + Elementor |
| A lista szerkezete | `releasetracker-list-container` → **217 db** `releasetracker-list-entry` (Elementor „releasetracker" plugin) |
| Egy lista-elem mezői | `targetid` (belső azonosító), **borító** (`i.scdn.co/image/…`), **`Előadó - Cím`**, **dátum** (`25 Sep 2026`), **Spotify-track link** |
| A lista mélysége | **2026-09-01 … 2026-10-15** (kb. 6 hét, 25 egyedi dátum) — **nem** a teljes előzmény |
| Lapozás | van rá utalás a HTML-ben („load more"/pagination) — külön mérés kell, ha a teljes előzmény kell |
| Az adatlap | `/release/{targetid}` → **HTTP 200**, ~180 KB; benne: **Title** (`CREST - Monsters`), **Artist(s)** (link: `/artist/{id}`), **Label** (`Redemption Records`), **Release date**, **Catalog ID**, **Hardstyle.com link**, **Source link** |
| Hallgatás (a kiadvány) | **Spotify-embed**: `<iframe src="https://embed.spotify.com/?uri=https://open.spotify.com/track/…">` — ez játszható le |
| **PREVIEWS** szakasz | az adatlapon külön blokk; ahol van tartalom, ott **külső beágyazás**: `https://www.youtube-nocookie.com/embed/…` (időbélyeggel is: `?start=499`) vagy `//streamable.com/e/…`. A legtöbb kiadványnál **üres** (nincs preview) |
| Robots | `robots.txt`: `User-agent: *` → **`Disallow: /wp-json/`** és `Disallow: /?rest_route=`; a sitemap és a nyilvános oldalak **engedettek** |
| RSS | `/feed/` él, de **2023 februári** bejegyzéseket ad (havi összefoglalók) → a listához **nem** használható |
| Külön „release" tartalomtípus | **nincs** (a WordPress-oldalon csak `post`/`page` van) → az adat az Elementor-widgetben él |

## 2. A javasolt megoldás (natív, gyorsítótárazva)

**Elv:** a telefon **soha** nem kéri közvetlenül az ő szerverüket; egy **szerveroldali kör** (Cloud
Function, ütemezve, pl. 30 percenként) letölti a listát, kiolvassa a mezőket, és a **Firestore-ba**
írja. Az app a Firestore-ból olvas — így gyors, offline is látszik a legutóbbi állapot, és a
releasehardstyle.nl terhelése **egy kérés / fél óra** (nem több ezer).

```
releasehardstyle.nl/releases/  ──(30 percenként, 1 kérés)──▶  Cloud Function (HTML→adat)
        ▲                                                        │
        │ (adatlap megnyitáskor, egyszer, gyorsítótárba)          ▼
        └──────────────  Firestore: release_tracker/{targetid}  ──▶  app (natív lista)
```

1. **Szerver:** `functions/release-tracker-plan.js` (tiszta, mérhető HTML→adat kiolvasás) +
   `exports.syncReleaseTracker` (ütemezett): a lista 217 eleme + a **hiányzó** adatlapok mezői
   (kiadó, katalógusszám, Hardstyle.com link, preview linkek), kedves ütemezéssel (kérésenkénti
   szünet), és **hibatűrő**: ha a HTML szerkezete megváltozik, a kör **nem ír felül** rossz adattal,
   hanem naplózza (`release_tracker_parse_failed`) — a felület ilyenkor a legutóbbi jó állapotot
   mutatja.
2. **Adat:** `release_tracker/{targetid}` — `artist`, `title`, `date`, `coverUrl`, `spotifyUrl`,
   `label`, `catalogId`, `hardstyleUrl`, `previews: [{type: 'youtube'|'streamable', url}]`,
   `sourceUrl` (`https://releasehardstyle.nl/release/{id}`), `syncedAt`.
3. **App (natív):** lista borítóval, „Előadó – Cím", dátummal, hónap szerinti csoportosítással;
   koppintásra **adatlap**: nagy borító, kiadó, dátum, katalógusszám, majd a gombok:
   **▶ Hallgatás (Spotify)** és **▶ Előnép** (YouTube/Streamable beágyazás az app beépített
   böngészőjében vagy natív lejátszóban), végül **„Megnyitás a Release Hardstyle oldalán"**
   (forrás-link, ugyanaz a minta, mint a `openInAppBrowser`).
4. **Jelzés/értesítés (később, külön döntés):** az új kiadványokról szólhatna értesítés is
   („Új kiadvány: X – Y") — ez a meglévő értesítés-katalógussal megy, de **csak akkor**, ha a
   tulajdonos kéri (és ha a forrás engedi).

## 3. Amit el KELL dönteni (a tulajdonosé a döntés)

1. **Engedély / forrás.** A tartalom a releasehardstyle.nl-é. A `robots.txt` a REST API-t tiltja, a
   nyilvános oldalakat nem. Két tiszta út:
   * **(a) engedéllyel** — a tulajdonos jelzi nekik, hogy az appban megjelenik (forrás megjelöléssel,
     visszalinkkel), vagy
   * **(b) hivatalos adatforrás** — megkérjük őket, hogy adjanak **JSON/RSS végpontot** (ez a
     legjobb: nem HTML-t kell olvasnunk, nem törik el egy témaváltásnál).
   Ha egyik sem megy, **marad a „csak link"** változat: a Több menüben egy sor, ami a beépített
   böngészőben nyitja a listát (nulla karbantartás, nulla jogi kérdés).
2. **Hova kerüljön az appban?** (a) új fül, (b) a **Kiadványok** képernyőn belül egy második szakasz,
   (c) a főoldalon egy „Friss kiadványok" sáv.
3. **Az előnép melyik fajtája kell?** A mérés szerint náluk ez **külső beágyazás** (YouTube /
   Streamable) és/vagy a **Spotify-lejátszó** — az appban **beágyazva** (appon belüli böngésző) vagy
   **kilinkelve** (a Spotify/YouTube app megnyitása) lehet.

## 3. A TULAJDONOS DÖNTÉSEI (2026-09-27) — ezek a mérvadók

| Kérdés | Döntés |
|---|---|
| **Engedély** | *„írjunk nekik és kérjünk engedélyt"* → a kész levél: **`docs/RELEASEHARDSTYLE-ENGEDELYKERES.md`** (címzett: `info@releasehardstyle.nl`, mérve) |
| **Hova kerüljön** | **A Több menüben** — egy „Releases" sor (nem új fül, nem a Kiadványok képernyőn belül) |
| **Előnép** | **Mindkettő:** próbálja **az appon belül** (beépített böngésző), **és** legyen **„Megnyitás az appban"** gomb is |
| **Most** | **Semmi nem épül** az ő adataikra, amíg nincs válasz. Utána: szerveroldali szinkron + natív lista/adatlap a Több menüben (a **377**-es buildben) |

## 4. Költség és kockázat (őszintén)

* **Kockázat:** a HTML-szerkezet az ő oldalukon bármikor változhat (Elementor-widget). Ezért a
  feldolgozás **szerveroldali, tesztelt tiszta függvény**, és **nem ír felül** kétes adattal; a
  felület a legutóbbi jó állapotot mutatja, és a hiba a naplóban látszik.
* **A lista csak ~6 hetet ad** (a `/releases/` ablak) — a teljes előzményhez lapozás kell (külön
  mérés), vagy marad a „csak az új kiadványok" nézet.
* **Az előnép nem minden kiadványnál van** (a mért 12-ből 2-nél volt konkrét embed) — a felület
  ilyenkor csak a Spotify-hallgatást kínálja.
* **Jogi oldal:** forrásmegjelölés + visszalink kötelező, és a tartalmat **nem** tároljuk
  hosszú távon (a gyorsítótár rövid életű, és a borítóképet a saját CDN-jükről töltjük).
* **Új build kell** (377): a 376 már a zárt tesztben van, ezért ez a **következő** kör.

## 5. Amit azonnal meg tudok csinálni, ha a tulajdonos rábólint

1. a HTML→adat feldolgozó **tiszta modul + tesztek** (a valódi HTML-mintán, elmentett pillanatképpel),
2. a **szerveroldali szinkron** (ütemezve, naplózással, hibahatárral),
3. a **natív lista + adatlap** (borító, kiadvány-adatok, Spotify- és előnép-gombok, forrás-link),
4. **magyar + angol** szövegek, és a meglévő kapuk (analyze, tesztek, i18n, mutációs bizonyíték).
