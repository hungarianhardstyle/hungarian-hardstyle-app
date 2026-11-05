> **Figyelem:** ez a szöveg **tervezet**, nem jogi tanácsadás. A véglegesítés az üzemeltető (tulajdonos) döntése; a Play-mezőbe a publikált oldal URL-je kerül.

# Az app ÁSZF-je a Google Play „kereskedői állapot" képernyőjéhez

> **A mérés (2026-11-05, Play Console képernyőkép):** a Play az **„Alkalmazásszintű kereskedői állapot és Általános Szerződési Feltételek"** lapon két dolgot kér:
>
> 1. *„A kereskedői állapotod érvényes erre az alkalmazásra?"* → **Igen** (az app fizetős Label-előfizetést és hirdetést tartalmaz, tehát kereskedő).
> 2. *„Általános Szerződési Feltételek URL"* — a követelmények szó szerint:
>    - **aktív, nyilvánosan hozzáférhető** URL (`http://` vagy `https://`), érvényes **SSL**-lel;
>    - **nincs földrajzi korlátozás**, **nincs helymeghatározáson alapuló átirányítás**, **nincs bejelentkezési követelmény**;
>    - **normál, nem szerkeszthető weboldalon** jelenik meg (**nem PDF**, nem letölthető fájl);
>    - **kifejezetten az alkalmazásra vonatkozik**.
>
> Ezért a meglévő, weboldal-szintű ÁSZF (`/altalanos-szerzodesi-feltetelek-aszf/`) **nem** alkalmas — kell egy **app-specifikus** oldal.

## A publikálás 3 lépése (a tulajdonosnak)

1. WordPress → **Oldalak → Új oldal**.
2. Cím: `Az alkalmazás Általános Szerződési Feltételei`; **URL-cím (slug):** `app-felhasznalasi-feltetelek`
   → így az oldal: **`https://hungarianhardstyle.hu/app-felhasznalasi-feltetelek/`** (jelenleg 404, tehát szabad).
3. Másold be az alábbi teljes szöveget (HTML nézetben is jó), majd **Közzététel**. Utána ellenőrizd, hogy **kijelentkezve is** betölt (böngésző privát ablak), és nincs rajta jelszó/jogosultság.

A Play mezőbe ez kerül: **`https://hungarianhardstyle.hu/app-felhasznalasi-feltetelek/`**

---

## A bemásolandó szöveg (magyar)

A Hungarian Hardstyle alkalmazás (a továbbiakban: **Alkalmazás**) használatára az alábbi feltételek érvényesek. Az Alkalmazás letöltésével vagy használatával elfogadod ezeket a feltételeket. Ha nem fogadod el, kérjük, ne használd az Alkalmazást.

**1. Üzemeltető és kapcsolat**
Az Alkalmazást a Hungarian Hardstyle üzemelteti (a továbbiakban: **Üzemeltető**). Kapcsolat: **info@hungarianhardstyle.hu**, weboldal: **https://hungarianhardstyle.hu**. Az Üzemeltető nevét, székhelyét és postai elérhetőségét a weboldal Impresszum oldala tartalmazza (https://hungarianhardstyle.hu/impresszum/).

**2. A szolgáltatás leírása**
Az Alkalmazás a magyar hardstyle/hardcore színtér híreit, eseményeit, kiadványait, DJ- és szervezőprofiljait, rádióadását, közösségi felületét (chat, hozzászólások, feltöltések) és játékait teszi elérhetővé. A tartalom egy része külső forrásból (weboldal, közösségi média) származik. Az Alkalmazás használata ingyenes; egyes tartalmak és funkciók **előfizetéssel** érhetők el (lásd 4. pont).

**3. Fiók, regisztráció**
Egyes funkciókhoz fiók szükséges. A regisztrációnál valós adatokat kell megadnod; a fiók jelszavát és a hozzáférési adataidat te őrzöd. A fiók törölhető az Alkalmazásból (Beállítások → Fiók törlése). A fiók törlésével a nyilvános tartalmaid (pl. hozzászólás) név nélkül maradhatnak, a nyereményjátékokban való részvételed megszűnik.

**4. Előfizetések és fizetés (Hardstyle Revolution Label)**
Egyes digitális kiadványok és funkciók **előfizetéssel** érhetők el. A vásárlás a **Google Play** (Android) vagy az **App Store** (iOS) áruházon keresztül történik, a fizetést az áruház végzi, a hatályos áruházi feltételek szerint. Az előfizetés **automatikusan megújul**, amíg le nem mondod; a lemondás az áruház előfizetés-kezelő felületén történik (Google Play → Előfizetések, illetve App Store → Előfizetések). A lemondás a már kifizetett időszak végéig nem jár visszatérítéssel; a **visszatérítés** az áruház szabályai szerint kérhető. Az árakat az áruház a vásárlás előtt mutatja.

**5. Felhasználói tartalom és magatartás**
A feltöltött tartalomért (kép, szöveg, hozzászólás, chat-üzenet) a feltöltő felel. Tilos a jogszabályba ütköző, gyűlöletkeltő, zaklató, felnőtt tartalmú, más jogait sértő vagy spam jellegű tartalom. Az Üzemeltető a szabályt sértő tartalmat **indoklás nélkül is** eltávolíthatja, a fiókot korlátozhatja vagy megszüntetheti. A nyilvános tartalomra az Alkalmazás használatához szükséges, nem kizárólagos, visszavonható felhasználási jogot adsz az Üzemeltetőnek (megjelenítés az Alkalmazásban és a kapcsolódó felületeken).

**6. Szellemi tulajdon**
Az Alkalmazás kódja, arculata és szerkesztett tartalmai az Üzemeltetőt illetik. A harmadik féltől származó tartalmak (fotók, videók, logók, szövegek) jogai a jogtulajdonosokat illetik. Jogsértés bejelentése: **info@hungarianhardstyle.hu**.

**7. Elérhetőség és változások**
Az Alkalmazás „ahogy van" alapon érhető el; a fenntartás, javítás vagy külső szolgáltatók (pl. adatbázis, hirdetés) miatt átmenetileg szünetelhet. Az Üzemeltető a funkciókat és ezeket a feltételeket módosíthatja; a lényeges változásról az Alkalmazásban vagy ezen az oldalon tájékoztat. A módosítás után való további használat az új feltételek elfogadását jelenti.

**8. Felelősség**
Az Üzemeltető nem felel a felhasználók által közzétett tartalomért, a harmadik féltől származó információk pontosságáért, valamint az Alkalmazás használatából eredő közvetett károkért, a jogszabályok által megengedett legnagyobb mértékben. Ez a pont **nem korlátozza** a fogyasztót megillető, jogszabályon alapuló jogokat.

**9. Adatkezelés**
A személyes adatok kezeléséről az **Adatkezelési tájékoztató** rendelkezik: **https://hungarianhardstyle.hu/adatvedelmi-nyilatkozat/**. Az Alkalmazás hirdetéseket (Google AdMob) jeleníthet meg.

**10. Panasz, jogérvényesítés**
Panaszodat az **info@hungarianhardstyle.hu** címre küldheted; 30 napon belül válaszolunk. Fogyasztóként a lakóhelyed szerinti **békéltető testülethez** vagy a **fogyasztóvédelmi hatósághoz** fordulhatsz; határon átnyúló ügyekben az EU online vitarendezési platformja is elérhető. A feltételekre a **magyar jog** irányadó, a fogyasztó lakóhelye szerinti kötelező szabályok megtartásával.

**11. Vegyes rendelkezések**
Ha egy pont érvénytelennek bizonyul, a többi érvényben marad. A feltételek nyelve a magyar; a kényelmi célú angol fordítás eltérése esetén a magyar változat irányadó.

**Hatályos:** 2026. november 5-től.

---

## A bemásolandó szöveg (angol — a magyar oldal alá, opcionális)

**Terms of Service — Hungarian Hardstyle app**

These terms govern the use of the Hungarian Hardstyle application (the "App"). By downloading or using the App you accept them.

**1. Operator and contact** — The App is operated by Hungarian Hardstyle. Contact: info@hungarianhardstyle.hu, website: https://hungarianhardstyle.hu. The operator's legal name, registered seat and postal address are listed on the Impresszum page (https://hungarianhardstyle.hu/impresszum/).

**2. Service** — The App provides news, events, releases, artist and organiser profiles, the radio stream, community features (chat, comments, submissions) and games for the hardstyle/hardcore scene. Use is free; certain content and features require a subscription (section 4).

**3. Account** — Some features require an account. Provide accurate data when registering and keep your credentials safe. You can delete your account in the App (Settings → Delete account); participation in prize games ends with deletion.

**4. Subscriptions and payments (Hardstyle Revolution Label)** — Some digital releases and features are available by subscription. Purchases are made through Google Play (Android) or the App Store (iOS) and are billed by the store under its terms. Subscriptions renew automatically until cancelled; cancel in the store's subscription settings (Google Play → Subscriptions, App Store → Subscriptions). Cancellation does not refund the current period; refunds follow the store's policy. Prices are shown by the store before purchase.

**5. User content and conduct** — You are responsible for content you upload. Unlawful, hateful, harassing, adult, infringing or spam content is prohibited. The operator may remove content and restrict or terminate accounts. You grant the operator a non-exclusive, revocable licence to display your public content in the App.

**6. Intellectual property** — The App's code, design and edited content belong to the operator; third-party content belongs to its owners. Report infringement to info@hungarianhardstyle.hu.

**7. Availability and changes** — The App is provided "as is"; it may be unavailable during maintenance or due to third-party providers. Features and these terms may change; continued use after a change means acceptance.

**8. Liability** — The operator is not liable for user content, third-party information or indirect damages, to the extent permitted by law. This does not limit statutory consumer rights.

**9. Privacy** — See the Privacy policy: https://hungarianhardstyle.hu/adatvedelmi-nyilatkozat/. The App may show ads (Google AdMob).

**10. Complaints** — Contact info@hungarianhardstyle.hu; we reply within 30 days. Consumers may turn to the competent conciliation body or consumer protection authority, and to the EU online dispute resolution platform. Hungarian law applies, subject to mandatory rules of the consumer's residence.

**11. Miscellaneous** — If a provision is invalid, the rest remains in force. The Hungarian version prevails over this convenience translation.

**Effective:** 5 November 2026.

---

## Ellenőrző lista a Play-mező előtt (a képernyő követelményei szerint)

- [ ] Az URL **`https://hungarianhardstyle.hu/app-felhasznalasi-feltetelek/`** (HTTP 200, érvényes SSL)
- [ ] **Kijelentkezve** is betölt (privát ablak), **nincs jelszó**, nincs „tagoknak" korlátozás
- [ ] Nincs **földrajzi** tiltás vagy ország-alapú átirányítás (WordPress geo-plugin, cache-szabály ne érintse)
- [ ] **HTML oldal**, **nem PDF**, nem letölthető fájl, nem csak bejelentkezve szerkeszthető
- [ ] A szöveg **az appra** vonatkozik (előfizetés, áruházi számlázás, fiók, közösségi tartalom)
- [ ] A Play „kereskedői állapot" kérdésre a válasz: **Igen**
- [ ] (Opcionális, de ajánlott) a Névjegy alatti „Felhasználási feltételek (ÁSZF)" sor URL-je is **erre** az oldalra mutasson — ehhez a `lib/core/legal/legal_links.dart` egyetlen sorát kell átírni (ez app-build, csak kérésre)

## Miért nem jó a mostani link

| Oldal | Állapot | Miért nem alkalmas a Play-mezőbe |
|---|---|---|
| `/altalanos-szerzodesi-feltetelek-aszf/` | HTTP 200 | **weboldal-szintű**, nem az appra szól (nincs benne előfizetés/áruházi számlázás/app-fiók) |
| `/adatvedelmi-nyilatkozat/` | HTTP 200 | ez az **adatkezelés**, nem szerződési feltételek |
| `/app-felhasznalasi-feltetelek/` | **404 (szabad)** | ← ezt kell létrehozni a fenti szöveggel |
