# GYIK — javasolt, emberi szövegek

Ez a fájl a **Segítség** (GYIK) menü új szövegeit tartalmazza. A jelenlegi GYIK a
WordPressből jön (`huhs_faq` bejegyzéstípus), 33 bejegyzéssel — ezek között van
**tárgyi hiba**, **elavult** és **felesleges** pont is.

A javaslat elve: **csak arról írunk, ami tényleg van**, egy kérdés = egy téma,
és a szöveg a felhasználónak szól — nem fejlesztőnek.

---

## Amit a jelenlegi GYIK-ben javítani kell

### 1. Tárgyi hiba (ezt muszáj javítani)

- **„Hogyan működnek az achievement pontok?"** — azt írja, hogy
  *„cikkkomment 1 pontot ér, de ebből naponta legfeljebb **öt** alkalom számít"*.
  A kódban a plafon **3** (`ARTICLE_COMMENT_DAILY_POINT_LIMIT = 3`).
  **Aki elhiszi az ötöt, a negyedik komment után azt hiszi, elromlott az app.**

### 2. Kétszer szerepel ugyanaz

- **„Hogyan törölhetem a profilomat?"** — két külön bejegyzés (12606-os és 12172-es
  azonosító), ugyanarról. Az egyik `App és közösség`, a másik kategória nélkül.

### 3. Személyes/technikai részletek, amiknek semmi keresnivalójuk itt

- *„Ugyanaz az indítási kép egy telefonon **két órán belül** nem jelenik meg újra."*
  → Ez a rendszer működése, nem segítség. A felhasználót csak az érdekli, hogy
  **ne jöjjön fel ugyanaz a kép minden indításnál**.
- *„Az appban ... a **`Firebase`** ... "* — sehol nem szabad belső
  technológiát említeni. **Jelenleg ilyen nincs a szövegekben**, ez figyelmeztetés
  a jövőre: ne is kerüljön bele.
- *„…a `96 kbps MP3` reklám megtekintésével oldható fel"* → a fájlformátum és a
  bitráta senkit nem érdekel; az számít, hogy **kisebb minőség, cserébe ingyen**.

### 4. Felesleges, mert magától értetődő

- *„Mire keres rá a hírek keresője?"* — hogy címben és szövegben keres. Ez a
  kereső definíciója, nem segítség.
- *„Milyen külső tartalmak érhetők el?"* — hogy külső oldalaknak saját szabályai
  vannak. Jogi szöveg, nem segítség.
- *„Mit láthatok a barátaimról?"* — beleolvad az ismerősök témájába.

### 5. Hiányzó témák (amiről kérdezni fognak, de nincs róla szó)

- **Nyereményjáték** — teljesen új funkció, egyetlen szó sincs róla.
- **Kérdőív** (a rövid közvélemény-kutatás) — szintén nincs.
- **Értesítések kezelése** — hogy hol lehet kikapcsolni, és mit jelent az
  „Archivált" fül.

---

## A javasolt GYIK

Hét témakör, **26 kérdés**. A jelenlegi 33 helyett — rövidebb, de használhatóbb.

---

### Témakör: Első lépések

**Hogyan regisztrálhatok?**
Koppints a Regisztrációra, add meg a kért adatokat, és erősítsd meg az
e-mail-címedet a kapott levélben. Google-fiókkal is regisztrálhatsz — akkor
e-mail-megerősítésre nincs szükség. A regisztráció után saját profilod lesz, és
használhatod a közösségi funkciókat.

**Mely funkciók használhatók bejelentkezés nélkül?**
Bejelentkezés nélkül is böngészheted a híreket, az eseményeket, a DJ-ket és a
kiadványokat, hallgathatod a rádiót, szavazhatsz az éves szavazáson és
hozzászólhatsz a cikkekhez. A Chathez, a privát üzenetekhez, a kedvencekhez, a
jelvényekhez és a vásárlásokhoz viszont fiók kell.

**Miért érdemes kitölteni a profilomat?**
Mert a profilodból dolgozik a közösség: a neved és a képed jelenik meg a chatben
és a hozzászólásoknál, és a profilod adja a rangodat. Ráadásul a **teljes
profilért 30 achievement-pontot** kapsz egyszer.

**Hogyan törölhetem a fiókomat?**
A profilod beállításainál indíthatod el a fiók törlését, majd meg kell
erősítened. A törlés után a hozzád tartozó helyi adatok és a gyorsítótár is
törlődik, és visszakerülsz a kezdőlapra. **A törlés végleges**, ezért csak
akkor csináld, ha biztos vagy benne.

### Témakör: Közösség

**Hogyan működik a chat?**
A nyilvános chatben mindenki látja az üzeneteidet, a privát beszélgetésekben
csak te és a másik fél. Tudsz válaszolni egy üzenetre, emojival reagálni, és a
saját üzenetedet **utólag szerkeszteni** is. Ha valami nem oda való, jelentsd
vagy tiltsd le azt a felhasználót.

**Tudok hozzászólni a cikkekhez?**
Igen, minden cikknek külön hozzászólásai vannak — így nem keverednek össze a
különböző cikkek alatti beszélgetések. Bejelentkezés nélkül is írhatsz,
ilyenkor egy automatikus nevet kapsz; regisztráltan a saját profilneved
jelenik meg. A saját hozzászólásodat később **szerkesztheted**, és ha valaki
mást ír, válaszolhatsz rá.

**Mit jelent a kedvencek?**
A kedvencekbe a számodra érdekes DJ-ket és szervezőket mentheted el, hogy
később könnyen megtaláld őket. A jelölést ugyanott vissza is vonhatod. Ez
független a hírek kedvelésétől.

**Hogyan gyűjthetek achievement-pontokat?**
A közösségben végzett tevékenységekért pont jár:

- profil teljes kitöltése — **30 pont** (egyszer)
- éves szavazás leadása — **10 pont**
- lejárt esemény értékelése — **10 pont**
- Meetup jelzés — **5 pont**
- játék teljesítése — **1–20 pont** az eredménytől függően
- ajánlás, ha a meghívottad regisztrál — **50 pont**
- cikk kedvelése — **2 pont**
- cikkhez írt hozzászólás — **1 pont**

Hír kedveléséért és hozzászólásért **naponta legfeljebb 3-3 alkalommal** jár
pont — a többi lájkolás és komment természetesen működik, csak nem ad több
pontot aznap. A pontjaidból rangot és jelvényt kapsz, és szintlépésnél
értesítést is kapsz.

**Mit jelentenek a rangok és a jelvények?**
A rangod és a jelvényed a megszerzett pontjaid alapján jelenik meg. Mások a
nyilvános profilodon és a chatben is a jelenlegi állapotodat látják. Ha új
rangot érsz el, a profilod magától frissül, és értesítést is kaphatsz róla.

**Mi az a Meetup?**
Ha egy eseménynél bejelölöd a Meetupot, akkor jelzed, hogy szívesen
találkoznál más résztvevőkkel. Ők az esemény adatlapján látják, hogy ott
leszel — így könnyebb egymásra találni egy bulin. A jelzésért **5 pont** jár.

### Témakör: Hírek és értesítések

**Hogyan kedvelhetem a híreket?**
A híreknél a kedvelés gombbal jelezheted, hogy tetszett a cikk, és a
reakciód később vissza is vonhatod. A hírek mindig azt mutatják, ami a
weboldalon is látszik, tehát frissítés után ugyanazt kapod, mint a gépen.

**Hogyan kapok értesítést?**
Értesítést kaphatsz új hírekről, közelgő eseményekről, privát üzenetről, a
hozzászólásaidra érkező válaszról, valamint pont- és szintlépésről. A
Beállításokban kiválaszthatod, melyik típusokról szeretnél értesülni. Ha egy
értesítésre koppintasz, azonnal a hozzá tartozó tartalom nyílik meg.

**Mi az „Aktív" és az „Archivált" fül az értesítéseknél?**
Az Aktív fülön a friss értesítések vannak, az Archivált fülre azok kerülnek,
amelyeket elolvastál és eltettél. Így a lényeges dolgok nem vesznek el a
sok olvasott között. A törlés mindig csak a látható fülre vonatkozik: az
Aktív fül az aktívakat törli, az Archivált fül az archiváltakat.

### Témakör: Zene és kiadványok

**Hogyan hallgathatom meg előre egy kiadványt?**
A kiadvány adatlapján általában van egy rövid előzetes, amit egy lejátszóval
azonnal meg is hallgathatsz — a megjelenés előtt is.

**Hogyan vásárolhatok és tölthetek le zenét?**
A teljes, jó minőségű változatot (WAV és 320 kbps MP3) megvásárlás után
töltheted le. A kisebb minőségű MP3 egy rövid reklám megtekintésével ingyen
nyílik meg. A vásárláshoz és a védett letöltésekhez be kell jelentkezned, a
fizetést a Google Play intézi.

**Mi a különbség a Radio és az Extended változat között?**
A Radio a rövidebb, rádióbarát változat, az Extended a hosszabb klubverzió.
Nem minden kiadványnál van mindkettő — mindig az adatlap mutatja, mi érhető el.

**Már megvettem korábban — hogyan kapom vissza?**
Ha ugyanazzal a Google-fiókkal vásároltad, a vásárlásod visszaállítható.
Sikeres ellenőrzés után a letöltés gomb ismét megjelenik. Ha mégsem, indítsd
el a vásárlások visszaállítását, és próbáld újra.

**Hallgathatom a rádiót az appban?**
Igen. A lejátszó gombjával indíthatod, a hangerőt a lejátszónál állíthatod, és
a lejátszás akkor is megy, ha közben másik képernyőt nyitsz meg.

### Témakör: Játékok

**Milyen játékok vannak?**
Időszakosan elérhető HUHS-játékokat találsz, például kvízt és Hardstyle
idővonalat. A játékokért a teljesítményedtől függően achievement-pont jár, az
eredményeidet pedig az app mutatja.

**Hogyan működik a pontozás a játékokban?**
A kvízeknél a helyes válaszok aránya számít: minél jobb az eredményed, annál
több pontot kapsz. A többi játéktípusnál a hibátlan teljesítés kell a pontért.

### Témakör: Szavazás, kérdőív, nyereményjáték

**Hogyan működik az éves HUHS szavazás?**
A kategóriáknál az app kiírja, hány jelöltet kell választanod, a teljes
szavazólapot pedig egyetlen gombbal küldheted be. Egy készülékről egy évadban
csak egyszer lehet szavazni, ezért beküldés előtt nézd át a választásaidat.
Bejelentkezve **10 pontot** kapsz érte.

**Mikor láthatók a szavazás eredményei?**
A szavazás lezárása után az eredmények nem jelennek meg azonnal. Akkor tesszük
közzé őket, amikor minden ellenőrzés lezajlott — onnantól az appban és a
weboldalon ugyanazt látod, kategóriánként, szavazatszám szerinti sorrendben.

**Mi az a kérdőív?**
A kérdőív egy rövid, egykérdéses szavazás a főoldalon — például arról, hogy
tetszik-e az app. Egy fiókkal egyszer szavazhatsz, és a szavazatod utólag nem
módosítható. Az eredmény nem nyilvános.

**Hogyan működik a nyereményjáték?**
A főoldalon látszik, ha nyitva van egy nyereményjáték. Egy kvízkérdésre kell
válaszolnod, és **csak a helyes válasz** vesz részt a sorsolásban. Egy fiókkal
**egyszer** játszhatsz: ha elrontod, sajnos nem tudod újra megpróbálni — de a
következő játéknál ott leszünk.

**Honnan tudom, hogy nyertem?**
A játék lezárása után rövid időn belül kisorsoljuk a nyertest egy helyes
válaszoló közül, és ezt az appban is látni fogod a nyertes nevével együtt.
Ha te nyersz, értesítést és e-mailt is kapsz a részletekkel. A nyertes nevét
a játék beállításától függő ideig mutatjuk.

### Témakör: Segítség és adatvédelem

**Hogyan jelezhetek hibát vagy küldhetek ötletet?**
A Több menüben a Hibajelzésnél tudsz levelet írni — az app automatikusan
csatolja a verziószámot, ami sokat segít. Írd le röviden, mi történt és melyik
képernyőn, és ha lehet, csatolj képernyőképet.

**Hogyan kezelitek az adataimat?**
Csak a működéshez szükséges adatokat tároljuk. A profilod nyilvános részét te
töltöd ki, a személyes adataidat nem tesszük közzé. A részleteket az
Adatkezelési tájékoztatóban olvashatod, és a fiókodat bármikor törölheted.

**Beküldtem egy DJ-t vagy eseményt — mi történik vele?**
A beküldött adatokat átnézzük, ezért nem jelennek meg azonnal. Ha kell,
pontosítjuk őket, és külön döntünk a közzétételről. Ez azért van, hogy a
katalógusban minden adat ellenőrzött legyen.

**Módosíthatom később a szerepkörömet?**
Igen. A szerepköröd a profilodhoz tartozik, és a profilbeállításokban
módosíthatod. Ha elakadsz, írj a Kapcsolat oldalon.

---

## Amit a jelenlegiből érdemes megtartani

Ezek jók voltak, csak megfogalmazásra szorulnak — a fenti listában már bennük van:

| Jelenlegi bejegyzés | Hova került |
|---|---|
| Hogyan értékelhetek egy eseményt? | **Közösség** → Meetup mellett érdemes külön kérdésként bent hagyni |
| Hogyan iratkozhatok fel a hírlevélre? | **Hírek és értesítések** |
| Hogyan küldhetek be tartalmat? | **Segítség** → „Beküldtem egy DJ-t…" |
| Milyen külső tartalmak érhetők el? | **Zene** → „Hallgathatom a rádiót…" |

Javaslom ezt a négyet is átfogalmazva megtartani (a fenti szövegekben a lényegük
már ott van).

---

## Amit törölni javaslok

- **„Hogyan törölhetem a profilomat?"** — a duplikátum (a másik marad).
- **„Mire keres rá a hírek keresője?"** — magától értetődő.
- **„Hogyan működnek az értesítések és az indítási kép?"** — a „két órán belül
  nem jelenik meg újra" rendszerleírás; a hasznos része átkerült az
  értesítésekhez.
- **„Milyen külső tartalmak érhetők el az appban?"** — jogi szöveg, nem segítség.
- **„Mit láthatok a barátaimról és az eseményekről?"** — beleolvad az
  ismerősök/Meetup témába.

---

## Amit ellenőrizni kell, mielőtt élesbe megy

1. **A pontszámok** (30 / 10 / 10 / 5 / 1–20 / 50 / 2 / 1) és a **napi 3-3
   plafon** a kódból származnak. Ha ez változik, a GYIK is avul.
2. **A nyereményjáték** leírása a jelenlegi szabályt írja le (egy játék, nincs
   újrapróbálkozás). Ha ezen változtatsz, itt is módosítani kell.
3. **A „bejelentkezés nélkül hozzászólhatsz"** állítás igaz — de ha ezt
   szigorítod, a szöveg is változik.

## Hogyan kerül be a WordPressbe

A GYIK a WordPress `huhs_faq` bejegyzéstípusa, és a **HUHS Mobile → GYIK** menüben
szerkeszthető. Két lehetőség van:

- **Kézzel:** bemásolod a szövegeket az adminban (te irányítasz, de lassú).
- **Egyszeri migrációval:** a plugin egy egyszer lefutó lépése felveszi ezeket a
  bejegyzéseket és besorolja a témakörökbe — de ez **felülírja** a meglévő
  szövegeket, ezért csak a te jóváhagyásoddal szabad lefuttatni.

**Ez a fájl javaslat. Amíg nem szólsz, a WordPressben semmi nem változik.**
