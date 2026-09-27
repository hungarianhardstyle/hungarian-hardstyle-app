# A fióktörlési oldal szövege (Play-hez) — 2026-09-27

> **Miért készült ez a fájl:** a Play Console **elutasította** a frissítést
> (*„Felhasználói adatok – Fióktörlési követelmény: Érvénytelen adattörlési link
> az Adatbiztonsági űrlapon"*, 2026. szept. 27.). A mérés szerint **az oldal él**
> (`https://hungarianhardstyle.hu/fiok-torles/` → HTTP 200, közzétéve 2026-09-23),
> a hiba oka a **Play-űrlap** (a link mező üresen maradt), **és** az oldalon
> leírt **appon belüli menüút nem létezik**: az oldal azt írja, hogy
> „Több → Beállítások → Fiók törlése", viszont az appban a valódi út:
> **Chat fül → jobb felső „Profil" ikon (a profilképed) → „Profil szerkesztése"
> → a lap alján a „Profil törlése" gomb.** Az alábbi szöveg ezt javítja, és
> **angol szakaszt** is ad (a felülvizsgáló ezt keresi).

## Amit a Play Console-on be kell állítani (a tulajdonos lépése)

> **Hol van?** Az Adatbiztonság űrlap **nem** külön bal oldali menüpont, hanem az
> **Alkalmazástartalom** (*App content*) oldalon van. Közvetlen link (bejelentkezés után):
> **https://play.google.com/console/app/app-content/summary**
> Útvonal a felületen: **Szabályzat és programok** (*Policy and programs*) →
> **Alkalmazástartalom** (*App content*) → **Adatbiztonság** (*Data safety*) szakasz.
> A Google súgója is ezt az oldalt jelöli meg:
> [A Google Play-alkalmazások fióktörlési követelményeinek ismertetése](https://support.google.com/googleplay/android-developer/answer/13327111?hl=hu).

1. Play Console → a **Hungarian Hardstyle** app → **Szabályzat és programok** →
   **Alkalmazástartalom** → **Adatbiztonság** (*Data safety*) → **Adattörlés** (*Data deletion*).
2. Válaszok:
   - „Lehetővé teszi az alkalmazás fiókok létrehozását?" → **igen**,
   - „Törli a felhasználói adatokat?" → **igen**,
   - „Megadja a felhasználóknak az adataik törlésének módját?" → **igen**,
   - jelöld be **mindkettőt**: **„Az alkalmazásban"** *és* **„Webes hivatkozás"**,
   - a webes mezőbe **pontosan ez** kerüljön (kötőjellel, szóköz nélkül):
     `https://hungarianhardstyle.hu/fiok-torles/`
3. **Mentés**, majd a **kiadás újraküldése** (a 374-es AAB maradhat, nem kell új
   csomag: az elutasítás nem a buildről szólt).

**⚠️ Amit a Google a webes linknél ellenőriz (a súgó szerint):** a link
**működőképes** legyen, a **törlési útvonal feltűnően látható és könnyen
felfedezhető** legyen az oldalon, az oldal **hivatkozzon az alkalmazás vagy a
fejlesztő nevére** (ahogy a Play-adatlapon szerepel), és a felhasználó **az
alkalmazás újratelepítése nélkül** kérhesse a törlést. Ezért fontos, hogy az
oldalon leírt **appon belüli menüút valódi** legyen (lásd lent).

## A WordPress-oldal szövege (ezt másold be a `/fiok-torles/` oldalra)

> A WordPress-szerkesztőben a sorokat sima bekezdésként illeszd be; a címeket a
> szerkesztő „Címsor" (Heading) eszközével jelölheted. A lényeg, hogy a
> **menüút** a valódi legyen, és az **angol szakasz** is fent legyen.

Fiók törlése

A Hungarian Hardstyle mobilalkalmazásban (csomagnév: hu.hungarianhardstyle.app) a fiókodat bármikor törölheted. Ez az oldal elmondja, hogyan kérheted, mi törlődik, mi marad meg, és mennyi ideig tart.

1. Hogyan kérheted a törlést?

Az appban (ez a leggyorsabb): nyisd meg a Chat fület, koppints a jobb felső „Profil" ikonra (a profilképed), majd a „Profil szerkesztése" gombra — a lap alján találod a „Profil törlése" gombot. A megerősítés után a törlés azonnal elindul.

E-mailben: írj a info@hungarianhardstyle.hu címre a fiókhoz tartozó e-mail címről, „Fiók törlése" tárggyal. Legkésőbb 30 napon belül elvégezzük (a gyakorlatban ennél jóval hamarabb).

2. Mi törlődik?

a fiókod és a bejelentkezési adataid (e-mail cím, jelszó), a közösségi profilod (név, bemutatkozás, profilkép), a chat-üzeneteid és a privát beszélgetéseid, a cikk-hozzászólásaid, a kedveléseid és a kapcsolódási kéréseid, az értesítéseid, a játék- és kvízeredményeid, valamint az achievement-pontjaid és a napi aktivitási előzményeid, a szavazataid (közönségszavazás, kérdőív), a bejelentéseid és a rólad szóló bejelentések, a DJ-adatlap átvételeid, a vásárlási jogosultsági rekordjaid (hogy melyik kiadványt vetted meg) és a hozzájuk tartozó vásárlás-azonosítók, a reklámos feloldásaid, az általad feltöltött képek (profilkép, hírekhez és beszélgetésekhez feltöltött képek).

3. Mi marad meg, és miért?

A Google Play-vásárlásod a Google-fiókodnál marad — ez nem nálunk van, ezért nem is tudjuk törölni. Ez jó hír: ha később új fiókot regisztrálsz, a megvásárolt kiadványokat újra ellenőrizni tudod, és ismét elérhetők lesznek — nem kell újra fizetned. A számlázási és vásárlási előzmények a Google-nál, illetve a jogszabályban előírt megőrzési időn belül maradnak meg. Az általad beküldött, de még el nem fogadott DJ- vagy szervező-adatlap tartalma a beküldés feldolgozásához szükséges ideig maradhat meg.

4. Mennyi ideig tart?

A fiók és a profil törlése azonnal megtörténik. A feltöltött képek törlése a háttérben fejeződik be, legfeljebb 48 órán belül (ha egy lépés megszakad, a rendszer újrapróbálja). Az e-mailes kérés esetén legkésőbb 30 napon belül elvégezzük a törlést, és visszaigazoljuk.

5. Kérdésed van?

Írj a info@hungarianhardstyle.hu címre — szívesen segítünk.

Ez a tájékoztató a Hungarian Hardstyle mobilalkalmazásra vonatkozik (csomagnév: hu.hungarianhardstyle.app).

Delete your account (English)

In the Hungarian Hardstyle mobile app (package name: hu.hungarianhardstyle.app) you can delete your account at any time. This page explains how to request deletion, what is deleted, what is kept, and how long it takes.

1. How to request deletion

In the app (fastest): open the Chat tab, tap the "Profile" icon in the top right corner (your profile picture), then tap "Profil szerkesztése" (Edit profile) — the "Profil törlése" (Delete profile) button is at the bottom of that page. Deletion starts immediately after you confirm.

By e-mail: write to info@hungarianhardstyle.hu from the e-mail address of your account, with the subject "Account deletion". We complete the deletion within 30 days at the latest (in practice much sooner).

2. What is deleted

Your account and sign-in data (e-mail address, password), your community profile (name, bio, profile picture), your chat messages and private conversations, your article comments, your likes and friend requests, your notifications, your game and quiz results, your achievement points and daily activity history, your votes (public voting, polls), your reports and the reports about you, your DJ page claims, your purchase entitlement records (which releases you bought) and the related purchase identifiers, your rewarded-ad unlocks, and the images you uploaded (profile picture, images uploaded to news and conversations).

3. What is kept, and why

Your Google Play purchase stays with your Google account — it is not stored by us, so we cannot delete it. This is good news: if you register a new account later, you can verify the purchased releases again and they become available — you do not have to pay twice. Billing and purchase history remain with Google and for the retention period required by law. The content of a DJ or organizer page you submitted but that has not yet been approved may be kept for as long as needed to process the submission.

4. How long does it take

Deleting the account and the profile happens immediately. Uploaded images are removed in the background within at most 48 hours (if a step is interrupted, the system retries). For an e-mail request we complete the deletion within 30 days at the latest and confirm it.

5. Questions

Write to info@hungarianhardstyle.hu — we are happy to help.

This notice applies to the Hungarian Hardstyle mobile application (package name: hu.hungarianhardstyle.app).

## Mérés (a javítás után ismételhető)

```bash
node tmp/probe-deletion-url.mjs            # él-e a link (200), és a tippelt változatok (404)
node tmp/probe-deletion-page-content.mjs   # az oldal tartalma a Play követelményeihez
node tmp/probe-deletion-access.mjs         # Googlebot / Play-Review UA, robots.txt, http/www
node tmp/probe-deletion-page-dates.mjs     # a WordPress-oldal létrehozásának dátuma (REST API)
```
