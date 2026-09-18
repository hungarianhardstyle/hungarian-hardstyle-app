# Bővítmény-audit — Hungarian Hardstyle (2026-09-18)

> ## TULAJDONOSI DÖNTÉS (2026-09-18): a bővítményekhez NEM nyúlunk
>
> A tulajdonos visszajelzése: *„semmit ne kapcsolj ki, kellenek az oldal
> működéséhez sajna”*. Ezért **ebből a listából semmit nem szabad kikapcsolni** —
> a dokumentum megmarad nyilvántartásnak és magyarázatnak (mi mit csinál, mi
> hagy nyomot az élő oldalon), de **nem végrehajtási terv**. Ne ajánld fel újra.
>
> A lassulás így a bővítmények oldaláról nem javítható. Ami marad, az a **saját
> pluginunk** belseje és a **hosting** (OPcache, tartós object cache) — utóbbihoz
> a tulajdonos döntése kell, mert a szolgáltató korábban VPS-ajánlattal élt.

**Miért készült:** az oldal lassú, és a mérés szerint a WordPress boot-idő ~60%-a a
bővítmények betöltése. Élesben 38 aktív bővítmény fut: `plugins_loaded` 788–1044 ms,
teljes válasz 1423–1642 ms, 111–116 adatbázis-lekérdezés és 166–168 MB csúcsmemória
**egy 10 KB-os JSONért**.

**Mit mértem:** `GET /wp-json/huhs/v1/posts?per_page=1&huhs_diag=huhs-boot-probe-2026&probe=<véletlen>`
→ `X-HUHS-Boot` és `X-HUHS-Health` fejléc.

## Hogyan készült ez a lista — és mi a korlátja

Kívülről vizsgáltam: letöltöttem a főoldalt és az események oldalát, és megnéztem

- melyik bővítmény tölt be **fájlt a nyilvános oldalra** (`wp-content/plugins/<mappa>/`),
- milyen **nyomokat** hagy a HTML (pl. `fbq(`, `gtag(`, `ays-poll`, `code-block-`),
- milyen **tartalomtípusokat** regisztrál a REST (`/wp-json/wp/v2/types`).

**A korlát, amit tudnod kell:** a csak admin-felületen vagy csak a szerveren futó
bővítmény **nem hagy nyomot**, ezért azokról a bővítmény ismert rendeltetése alapján
döntöttem. Kívülről nem lehet megállapítani, hogy egy admin-eszközt használsz-e.
Ezért a lista **javaslat**, nem ítélet — a döntés a tiéd.

**Amit semmiképp nem szabad kikapcsolni**, azt külön fejezet jelzi.

---

## 1. NE kapcsold ki — bizonyítottan vagy nagy valószínűséggel kell

| Bővítmény | Miért marad |
|---|---|
| `huhs-mobile-api` | **A saját pluginunk.** Az app összes végpontja, a push, a gyorsítótár, a release-ek. Kikapcsolása az appot teljesen megbénítja. |
| `jetpack` | **Kritikus, nem nyilvánvaló függés:** az app képméretezése a Jetpack **Photon CDN-jét** (`i0.wp.com`) használja. Ha kikapcsolod, a képek visszaesnek az eredeti fájlra — bizonyítottan **1,5 MB** egy 1024 px-es PNG helyett 365 KB. A `ResizedNetworkImage` tartalék ága miatt a kép nem tűnik el, de a gyorsítás odavész. Emellett site-statisztika és social megosztás. |
| `jetpack-boost` | Ez adja a **196 ms-os cache-elt főoldalt** (cache nélkül 1817 ms). Kikapcsolása minden látogatót lassítana. |
| `wordfence` | Tűzfal és behatolásvédelem. Kívülről nem látszik, de a védelem kell. |
| `wp-mail-smtp` | Ezen megy az e-mail-küldés (hírlevél, értesítések). Kikapcsolása esetén a levelek spambe kerülnek vagy el sem mennek. |
| `wp-consent-api` | Consent API, amit a Site Kit és a Facebook pixel használ. Kikapcsolása a hozzájárulás-kezelést törheti. |
| `wordpress-seo` | Bizonyítottan aktív (Yoast schema + meta a HTML-ben). A site keresőmegjelenése múlik rajta. |
| `custom-post-type-ui` | **Kockázatos:** az esemény/DJ/szervező/release tartalomtípusokat ez regisztrálja futásidőben. Kikapcsolása eltüntetheti őket az adminból. |
| `akismet` | Spam-szűrés a hozzászólásoknál — az app cikkeihez is lehet hozzászólni. |
| `cmb2` | Meta-box **könyvtár**, amit más bővítmények használhatnak. Kikapcsolása egy másik bővítményt törhet el. |
| `classic-editor` | A cikkírás szerkesztője. Kikapcsolása megváltoztatja a szerkesztést. |
| `classic-widgets` | A widget-felület. Kikapcsolása átrendezheti a láblécet/oldalsávot. |

---

## 2. Aktív és bizonyítottan használt — csak akkor, ha tudod, hogy nem kell

Ezek **nyomot hagynak az élő oldalon**, tehát valóban működnek. Kikapcsolásuk
látható változást okoz, ezért csak akkor tedd, ha a funkciót nem akarod.

| Bővítmény | Bizonyíték | Ha kikapcsolod |
|---|---|---|
| `official-facebook-pixel` | `fbq(` és `connect.facebook.net` a HTML-ben | Megszűnik a Facebook-konverziómérés (hirdetéseknél számíthat). |
| `google-site-kit` | `gtag(` 14×, `googlesitekit` a HTML-ben; 34 KB autoload | Megszűnik az Analytics/Search Console adat. **Nehéz bővítmény**, ezért ha nem nézed a számokat, jó jelölt. |
| `mailchimp` | 22 nyom + saját asset a nyilvános oldalon | Megszűnik a hírlevél-feliratkozás a weboldalon. |
| `disqus-comment-system` | `disqus` 3× a HTML-ben | **Eltűnnek a hozzászólások** a nyilvános oldalról. |
| `simple-tags` | saját asset a nyilvános oldalon | A címkék megjelenítése változhat. |
| `simple-local-avatars` | nincs nyilvános asset (admin-oldali) | Nem lehet feltölteni szerzői avatart. |
| `contact-form-7` | `wpcf7`/`cf7` a HTML-ben | Megszűnik a kapcsolatfelvételi űrlap. |
| `poll-maker` | `ays-poll` 15× az események oldalon | Eltűnnek a szavazások. |
| `wp-flyer-popup` | 44 nyom | Eltűnik a szórólap-felugró. |
| `ad-inserter` | `code-block-` a HTML-ben; 31 KB autoload | Eltűnnek a cikkekbe szúrt hirdetések. |
| `all-in-one-video-gallery` | `aiovg` 24× + `aiovg_videos` tartalomtípus | Eltűnnek a videógalériák. |
| `blog-designer-pack` | `bdpp_layout` tartalomtípus regisztrálva | Eltűnnek a Blog Designer elrendezések. |
| `video-player-block` | `video-player-block` tartalomtípus regisztrálva | Eltűnnek a videólejátszó blokkok. |
| `hungarian-hardstyle-google-source-1.0.4` | `huhs-google-source` 20× a HTML-ben | Eltűnik a „Google preferált forrás” sáv. |

### Külön figyelmeztetés: `huhs-push-auto-permission-patch-0.1.5-all-categories`

Ez egy **webes (böngészős) push** bővítmény a látogatóknak — nem az app push-ja.
A `sw.js` service worker megvan (200, 889 bájt), **de a hozzá tartozó
`assets/push.js` 404-et ad**, pedig minden oldal kéri. Vagyis:

- minden oldalletöltés elindít egy **hibás kérést** és egy JavaScript-hibát,
- a feliratkozás része **nem működik**, tehát valószínűleg senki nem is iratkozik fel.

Három lehetőség: (a) megkeressük és megjavítjuk a hiányzó fájlt, (b) kikapcsoljuk,
(c) marad, de akkor is törött. **Döntést igényel.** A `huhs-release-catalog-1.1.0`
szintén HUHS-bővítmény, de **semmilyen nyomot nem hagy** (0 találat) — lehet, hogy
elavult; érdemes megnézni az adminban, mit csinál.

---

## 3. Valószínűleg biztonságosan kikapcsolható — kicsi a kockázat

Ezek vagy egyszeri eszközök, vagy **nem hagynak semmilyen nyomot** a vizsgált
oldalakon. A legolcsóbb nyereség: nem érintik a látogatót, csak a boot-időt.

| Bővítmény | Mi ez | Miért jelölt |
|---|---|---|
| `broken-link-checker` | Linkellenőrző, adatbázisban tárolja az eredményt | Látogatóknak semmit nem ad, ismerten nehéz. Kikapcsolás után nem lesznek új ellenőrzések. |
| `advanced-import` | Demó-tartalom importáló | Egyszeri eszköz; futásidőben nincs funkciója. |
| `child-theme-wizard` | Gyermektéma létrehozó | A téma már fájlként létezik (`walkerpress` / `xpomagazine`), ezért létrehozásra nincs szükség. |
| `real-category-library-lite` | Kategória-kezelő admin felület | A kategóriák a WordPress-ben vannak; ez csak kényelmi réteg. |
| `sitelinks-search-box` | Google-találati keresőmező | Apró SEO-kozmetika. |
| `intelly-related-posts` | Kapcsolódó cikkek | **0 nyom** a vizsgált oldalakon, és a saját pluginunknak is van kapcsolódó-cikk funkciója → duplikáció. |
| `final-tiles-grid-gallery-lite` | Csempés galéria | **0 nyom** a vizsgált oldalakon. |
| `simple-embed-code` | `[embed-code]` shortcode | **0 nyom** — valószínűleg egyetlen bejegyzés sem használja. |
| `category-subcategory-list-widget` | Kategória-lista widget | **0 nyom** — valószínűleg nincs használt oldalsávban. |
| `hide-featured-image-on-all-single-pagepost` | Kiemelt kép elrejtése a cikkoldalon | Egyetlen megjelenítési szabály; ha a cikkoldalon tényleg nem látszik a kiemelt kép, akkor **ezért** — ilyenkor maradjon. |

---

## 4. Biztonságos végrehajtási sorrend

### Kiindulási mérés — ehhez hasonlítsd a végeredményt

Három egymást követő mérés a 2.4.110 előtt (a `X-HUHS-Boot` fejlécből):

| Mérés | plugins_loaded | wp_to_response | queries | peak_mb |
|---|---|---|---|---|
| 1 | 797 ms | 1416 ms | 111 | 166,5 |
| 2 | 792 ms | 1405 ms | 111 | 166,5 |
| 3 | 825 ms | 1396 ms | 111 | 166,5 |

A `queries` és a `plugins_loaded` a legjobb viszonyítási pont: ha a 3. fejezet
bővítményeit kikapcsolod, ezeknek **mérhetően csökkenniük kell**. A méréshez
ugyanaz a parancs kell, mindig **más** `probe` értékkel (különben a cache válaszol):

```
GET /wp-json/huhs/v1/posts?per_page=1&huhs_diag=huhs-boot-probe-2026&probe=<véletlen>
```

### A sorrend

Ne kapcsold ki egyszerre az egészet — ha valami elromlik, ne kelljen találgatni.

1. **Először a 3. fejezet** (10 bővítmény). Ezek nem érintik a látogatót.
2. Minden kör után ellenőrizd: a főoldal, egy cikk, az események oldala, az admin
   bejelentkezés, **és az app** (hírek, események, DJ-k, release-ek).
3. Utána a 2. fejezet, **egyenként**, a legkevésbé használtakkal kezdve
   (`google-site-kit` → `disqus` → `poll-maker` → `wp-flyer-popup` → `ad-inserter`).
4. Az 1. fejezetet **hagyd békén.**

**Különleges óvatosság:** ha a `custom-post-type-ui`, `cmb2` vagy `classic-widgets`
bármelyikét kikapcsolod, utána azonnal nézd meg az adminban, hogy az események, DJ-k,
szervezők és release-ek megvannak-e. Ha eltűnnek, kapcsold vissza.

## 5. Ami a bővítményeken túl segítene (hosting)

- **OPcache** — a mérés `opcache=restricted`-et adott, ami kétértelmű: lehet, hogy ki
  van kapcsolva. Ha ki van, a szerver **minden kérésnél újrafordítja** az összes
  bővítmény PHP-ját. 38 bővítménynél ez a legnagyobb egylépéses nyereség.
- **Tartós object cache (Redis)** — `object_cache=no`. Enélkül minden kérés az
  adatbázisból olvassa az opciókat és a transienteket.
- **Autoload** — 667 KB töltődik be minden kérésnél, amiből **206 KB egyetlen**
  méret-gyorsítótár (`_transient_dirsize_cache`).

## 6. Amit ez a lista nem tartalmaz

- Nem mértem bővítményenként a boot-időt — a WordPress erre nem ad módot. A sorrend
  a bővítmény jellege és a nyilvános nyomok alapján készült, nem mért ms-értékekből.
- A 3. fejezet kikapcsolása után **pontosan mérhető lesz a nyereség**: a
  `X-HUHS-Boot` fejléc `wp_to_response` és `queries` értéke ugyanazzal a paranccsal
  újramérhető.
