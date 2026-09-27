# Engedélykérés a releasehardstyle.nl-hez (2026-09-27)

> **A tulajdonos döntése:** *„írjunk nekik és kérjünk engedélyt"* — ez a fájl a **kész, másolható
> levél**. A címzett: **info@releasehardstyle.nl** (mérve a `/contact/` oldalon; űrlap nincs, e-mail
> van). A levél angolul megy (az oldal angol nyelvű), a magyar változat lentebb olvasható.
>
> **A tárgy javasolt szövege:**
> `Permission request: showing your release list in the Hungarian Hardstyle app`
>
> **Mit kérünk pontosan:**
> 1. **engedélyt**, hogy a nyilvános kiadvány-listájukat az appban megjelenítsük (forrásmegjelöléssel
>    és visszalinkkel),
> 2. **hivatalos adatvégpontot** (JSON vagy RSS), ha van/ tudnak adni — ez nekik is jobb, mert nem a
>    HTML-t kell olvasnunk,
> 3. egy **kapcsolattartót**, hogy szólhassunk, ha bármit módosítanak.

---

## ✉️ A levél (ANGOL — ezt küldd el)

**To:** info@releasehardstyle.nl
**Subject:** Permission request: showing your release list in the Hungarian Hardstyle app

Hello Release Hardstyle team,

My name is Imre, I run **Hungarian Hardstyle** (https://hungarianhardstyle.hu) and I develop the
official **Hungarian Hardstyle mobile app** (Android: `hu.hungarianhardstyle.app`, iOS: same bundle
id). The app has a few thousand Hungarian hardstyle fans: news, events, DJ pages, community chat and
our own release catalogue.

**What I would like to ask:** may we show **your release list** (`https://releasehardstyle.nl/releases/`)
inside the app, in a native "Releases" section of our More menu — **with your name and a link back to
your site on every screen**?

If you prefer, we would be even happier with an **official data endpoint** (a JSON or RSS feed of your
releases). That is more stable for us and less traffic for you.

**How we would do it (technically, so you can judge it):**

* one of our servers (Google Cloud, EU region) would read your public **`/releases/` page** — the same
  page any browser sees — **at most once every 30 minutes**, and cache the result; the app itself
  never contacts your server,
* we would show: cover image, artist, title, release date, label, catalogue ID, the Spotify link and
  the **preview links** you publish (YouTube / Streamable), plus a **"Open on Release Hardstyle"**
  button,
* we would **not** copy your texts, your reviews or your artwork into our own database beyond that
  short-lived cache, we would **not** use your content commercially, and we would **not** present the
  data as our own,
* the cover images would be loaded from **your** CDN (we would not re-host them),
* we will **remove the section immediately** if you ask us to — one e-mail is enough,
* if you would like a different credit line, a different link, or a smaller frequency, we will follow
  your instructions exactly.

We are happy to mention you in the app's "About / Partners" section as the release data source, and I
can send you a test build (Android) so you can see exactly how it looks before you decide.

Could you let me know:

1. whether we may show your release list, and
2. whether you can give us a **JSON or RSS** endpoint we could use instead of the HTML page, and
3. who we should contact if anything changes on your side?

Thank you very much for your time — and thank you for the work you put into the scene.

Best regards,
**Imre (Denoiser)**
Hungarian Hardstyle
https://hungarianhardstyle.hu · info@hungarianhardstyle.hu

---

## ✉️ A levél (MAGYAR — csak ellenőrzésre, nem kell elküldeni)

Kedves Release Hardstyle csapat!

Imrének hívnak, a **Hungarian Hardstyle** oldalt (https://hungarianhardstyle.hu) viszem, és én
fejlesztem a **Hungarian Hardstyle mobilappot** (Android és iOS, `hu.hungarianhardstyle.app`). Az
appban magyar hardstyle rajongók ezrei olvassák a híreket, az eseményeket, a DJ-adatlapokat, a
közösségi chatet és a saját kiadvány-katalógusunkat.

**A kérésem:** megjeleníthetjük-e az appban a **kiadvány-listájukat**
(`https://releasehardstyle.nl/releases/`) egy natív „Releases" szekcióban a Több menüben — **minden
képernyőn az Önök nevével és a weboldalukra mutató linkkel**?

Ha van/ tudnak adni **hivatalos adatvégpontot** (JSON vagy RSS), annak még jobban örülnénk: az
stabilabb nekünk, és kevesebb terhelés nekik.

**Hogyan csinálnánk (technikailag, hogy megítélhessék):**

* az egyik szerverünk (Google Cloud, EU-régió) a nyilvános **`/releases/` oldalt** olvasná — ugyanazt,
  amit bármelyik böngésző lát —, **legfeljebb félóránként egyszer**, és gyorsítótárazná; maga az app
  **soha** nem kérdezi az Önök szerverét,
* ezt mutatnánk: borító, előadó, cím, megjelenés dátuma, kiadó, katalógusszám, a Spotify-link és az
  Önök által közzétett **előnép-linkek** (YouTube / Streamable), valamint egy **„Megnyitás a Release
  Hardstyle oldalán"** gomb,
* a szövegeiket, kritikáikat és a grafikáikat **nem** másoljuk a saját adatbázisunkba a rövid
  gyorsítótárnál tovább, **nem** használjuk kereskedelmi célra, és **nem** állítjuk be sajátunkként,
* a borítóképeket **az Önök CDN-jéről** töltjük (nem tároljuk újra),
* **azonnal leveszünk** mindent, ha kérik — egy e-mail elég,
* ha más creditsort, más linket vagy ritkább lekérdezést szeretnének, pontosan úgy csináljuk.

Szívesen feltüntetjük Önöket az app „Névjegy / Partnerek" szekciójában mint a kiadvány-adatok
forrását, és tudok küldeni egy teszt-buildet (Android), hogy pontosan lássák, hogyan néz ki, mielőtt
döntenek.

Meg tudnák mondani:

1. megjeleníthetjük-e a kiadvány-listájukat,
2. tudnak-e adni **JSON vagy RSS** végpontot a HTML-oldal helyett, és
3. kit kereshetünk, ha valami változik az Önök oldalán?

Köszönjük a munkájukat a scene-ért!

Üdvözlettel:
**Imre (Denoiser)**
Hungarian Hardstyle
https://hungarianhardstyle.hu · info@hungarianhardstyle.hu

---

## 📋 A döntések (a tulajdonos válaszai, 2026-09-27)

| Kérdés | Döntés |
|---|---|
| Engedély | **Írjunk nekik és kérjünk engedélyt** (ez a fájl) |
| Hova kerüljön | **A Több menüben** (nem a Kiadványok képernyőn, nem új fül) — tehát a „Több" listában egy **„Releases"** sor |
| Előnép | **Mindkettő:** próbálja az appon belül (beépített böngésző), **és** legyen „Megnyitás az appban" gomb is |
| Technikai út | Amíg nincs válasz: **semmi nem épül** az ő adataikra. Ha engedélyt adnak (vagy adatvégpontot), akkor jön a szerveroldali szinkron + a natív lista (a részletek a `docs/RELEASEHARDSTYLE-BEILLESZTES-TERV.md`-ben) |

## ⏭️ Mi történik a válaszuk után

* **„Igen, mehet"** → megépítem a szerveroldali szinkront (30 percenként, gyorsítótárral) és a natív
  listát + adatlapot a **Több menüben**, forrásmegjelöléssel; a következő build (377) viszi.
* **„Igen, és itt egy JSON/RSS végpont"** → ugyanaz, csak HTML-olvasás helyett a végpontot használjuk
  (stabilabb, kevesebb kockázat).
* **„Inkább ne"** → marad a **csak link**: a Több menüben egy sor, ami a beépített böngészőben nyitja
  a listájukat (ez jogilag és technikailag is tiszta, csak nem natív lista).
