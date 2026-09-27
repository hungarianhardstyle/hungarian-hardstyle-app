# Gyermekbiztonság: moderációs javaslat (2026-09-27)

> **Miről szól:** a tulajdonos az appot **Közösségi** kategóriába tette, ezért a Play
> **Gyermekbiztonsági normák** nyilatkozatot kér. Ehhez a normák közzététele
> (kész: `https://hungarianhardstyle.hu/gyermekbiztonsag/`) és az **alkalmazáson
> belüli bejelentés** (kész: hozzászólás, Chat-üzenet, **privát beszélgetés**)
> mellett a kérdés az, hogyan lehet a **gyermekek zaklatására utaló jeleket**
> kiszűrni vagy legalább **jelezni az adminnak**.
>
> **A mért tények** (nem tippek):
> * a privát chat a **Firestore-ban** él: `private_conversations/{conversationId}`
>   (a beszélgetés azonosítója a két UID-ből: `privateConversationId(uid1, uid2)`),
>   az üzeneteket a **kliens írja** a szabályok (`firestore.rules` 481–560. sor) őrzése mellett;
> * a szerveren **már van** `onDocumentCreated` trigger a privát üzenetre:
>   `exports.notifyPrivateMessage` (`functions/index.js` ~8002. sor) — ez a
>   természetes hely a szűrésnek, **nem kell új infrastruktúra**;
> * a bejelentések a **`chat_reports`** kollekcióba mennek, és a meglévő
>   `handleChatReportNotification` értesíti az adminokat;
> * a blokkolás (`community_profiles.blockedIds`), a beszélgetés- és üzenettörlés,
>   valamint az admin-oldali törlés/kitiltás **már működik**.

## 1. Javaslat — három fázis (költség szerint növekvő)

### 1. fázis — „olcsó és azonnal hasznos" (ajánlott elsőként)

A `notifyPrivateMessage` trigger (vagy egy mellette futó testvér-trigger) minden új
privát üzenetnél kiszámol néhány **jelet**, és ha a pontszám átlép egy küszöböt,
**bejegyzést ír** és **értesíti az adminokat** (ugyanaz az értesítési út, mint a
`chat_reports`-nál):

1. **Életkor-különbség (a legerősebb olcsó jel):** ha az egyik fél **kiskorú**
   (`birthDate` szerint < 18) és a másik **nagykorú**, akkor a beszélgetés
   automatikusan „figyelt" státuszba kerül — és ha a felnőtt **kezdeményez**, az
   önmagában is jel.
2. **Kulcsszó-minták (HU + EN):** életkorra kérdezés („hány éves vagy", „how old"),
   titoktartás kérése („ne mondd el a szüleidnek", „titok marad", „don't tell"),
   találkozó kezdeményezése, más platformra terelés (snap/insta/telegram + „privátban"),
   képet kérés („küldj képet", „send pics"), valamint explicit szexuális kifejezések.
3. **Kapcsolat-csere:** telefonszám/e-mail/link mintázat **felnőtt → kiskorú**
   irányban (a „kiszakítás” klasszikus első lépése).
4. **Viselkedés:** felnőttől kiskorúnak rövid időn belül sok üzenet, illetve
   **blokk után is próbálkozás** (új beszélgetés ugyanazzal a párossal).

**Amit teszünk vele:** `moderation_flags` bejegyzés (ki, kivel, miért, idézet,
pontszám) + admin-értesítés + megjelenés az admin moderációs listájában. Az üzenetet
**nem tartjuk vissza** (a téves riasztás így nem akadályoz), de a jel azonnal látszik.

### 2. fázis — szabályok és korlátok

* Felnőtt → kiskorú első kapcsolatfelvételére **napi korlát** és/vagy „figyelmeztetés”
  (a küldő lát egy rövid üzenetet: „A közösségi szabályok a kiskorúak fokozott védelmét
  írják elő”), ismétlésnél a beszélgetés letiltása.
* **Kiskorú profilján** a születési dátum alapból rejtve (ez már így van), és a
  kiskorú nem kereshető kor alapján.
* Admin-oldali **„Moderáció” lista**: nyitott bejelentések + automatikus jelek egy
  helyen, a beszélgetés megnyitásával és a szokásos műveletekkel (törlés, kitiltás).

### 3. fázis — ha a közösség nő (külső szolgáltatás)

* **Képek hash-egyeztetése** (CSAM): ehhez külső szolgáltató kell
  (pl. Cloudflare CSAM Scanning Tool, Thorn Safer, PhotoDNA-jellegű megoldás) —
  ez **fizetős és jogi folyamatot** is igényel (bejelentési kötelezettség,
  hatósági kapcsolat).
* Szöveg-moderáció modellalapú szolgáltatással (a kulcsszavaknál pontosabb, de
  adatvédelmi mérlegelést kér).

## 2. Amit a jelenlegi tudásunk szerint **nem** tudunk megoldani

* **Automatikus CSAM-felismerés**: hash-adatbázis nélkül nem lehetséges; a
  kulcsszó-szűrés erre **nem** alkalmas. Ezért a hangsúly a **bejelentésen** és a
  **gyors emberi moderáción** van (ez a Google elvárása is: „megfelelő intézkedések”,
  amint tudomást szerzünk róla).
* A kulcsszólista **megkerülhető** (más nyelv, elírás, szóközök) — ezért a jelzések
  **gyanújelzések**, nem bizonyítékok, és mindig emberi döntés követi.
* A zárt beszélgetések olvasása **adatvédelmi tájékoztatást** kér: a
  `docs/FIOKTORLES-OLDAL-SZOVEG.md`-hez hasonlóan az adatvédelmi tájékoztatóban
  szerepelnie kell, hogy visszaélés-megelőzés céljából **automatikus jeleket**
  készítünk (ez ma is benne van a „biztonság, visszaélés-megelőzés” jogalapnál).

## 3. Amit a Play Console-on meg kell adni (a tulajdonos lépése)

* **Közzétett normák URL-je:** `https://hungarianhardstyle.hu/gyermekbiztonsag/`
  (él, HTTP 200, HU + EN, benne az app neve és csomagneve — mérve).
* **Alkalmazáson belüli bejelentés:** ✅ van (hozzászólás, Chat-üzenet, **privát
  beszélgetés** menü: *Felhasználó jelentése*), és e-mail is (`info@hungarianhardstyle.hu`).
* **CSAM kezelése:** a bejelentés → 24 órán belüli vizsgálat → tartalom törlése,
  fiók kitiltása → hatósági bejelentés (a normák oldalán leírva).
* **Gyermekbiztonsági kapcsolattartó:** név + e-mail (a tulajdonos adja meg; a
  honlapon a `info@hungarianhardstyle.hu` szerepel).
* **Jogszabályi megfelelés:** nyilatkozat a gyermekbiztonsági jogszabályok betartásáról.

## 4. Mért állapot (2026-09-27)

| Elem | Állapot |
|---|---|
| Gyermekbiztonsági normák oldala | **kész, él** (`/gyermekbiztonsag/`, #12883, HU+EN, HTTP 200 minden user-agenttel) |
| Születési dátum kötelező + láthatóság + visszamenőleges felszólítás | **kész az appban** (lásd a kiadási jegyzetet) |
| Bejelentés privát chatben | **kész az appban** (a `chat_reports`-ba ír, az admin-értesítés a meglévő úton megy) |
| Automatikus gyanújelzés az adminnak | **javaslat kész** (1. fázis); a megvalósítás a tulajdonos döntése |
| CSAM hash-szűrés | **nincs** (külső szolgáltató kell — 3. fázis) |

## 5. Döntést kérő pontok

1. **Induljon-e az 1. fázis** (életkor-különbség + kulcsszó-jelek + admin-értesítés)?
   Ez szerveroldali munka (`functions/index.js` + egy admin-lista), app-buildet nem
   igényel.
2. **Kiskorú regisztráció:** maradjon-e engedélyezett (a születési dátum rögzítésével),
   vagy legyen **16/18 év alatt tiltott**? (A Play ezt nem írja elő, de a közösségi
   kategóriában a szigorúbb út védhetőbb.)
3. **Külső szolgáltató** (3. fázis) — csak akkor, ha a közösség mérete indokolja.
