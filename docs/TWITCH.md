# Twitch az appban — hogyan működik, és mit tudsz állítani build nélkül

Ez a lap a **387-es build** Twitch-integrációját írja le röviden (2026-10-02).

## Amit a felhasználó lát

1. **Főoldali kártya** — alapból akkor jelenik meg, ha **megy az adás** (és a te
   beállításoddal **előre is**, lásd lent). A képe a Twitch **mozgó** előnézete
   (30 másodpercenként frissül), felül az **ÉLŐ** jelvény és a nézőszám.
   A kártya a hírek blokkja **után**, a „Kedvenceid” előtt áll; ha nem él a csatorna,
   **nem hagy üres helyet**.
2. **Twitch-oldal** (a kártyára koppintva, vagy a „Nézd élőben” gombbal):
   - felül a **beágyazott lejátszó** (`player.twitch.tv/hungarianhardstyle`),
   - alatta **az app saját chatje** (ugyanaz, mint a Chat fülön: emotok, reakciók,
     `@`hivatkozások, értesítés) — a tulajdonos kérése szerint **nem** a Twitch-chat,
   - **Támogatás** gomb (PayPal — ugyanaz a link, mint a Több → Támogatás képernyőn).
3. **Hangfókusz:** amíg az adás oldal nyitva van, a **rádió és az előzetes leáll**;
   amikor kilépsz, a rádió **visszatér**, ha előtte szólt.
4. **Kis képernyő (PiP):** **Androidon és iPhone-on is** — ha az adás közben más appba
   lépsz, a stream **kicsiben megy tovább**; ezen kívül a fejléc **„Kis képernyő”**
   gombjával bármikor kicsinyíthető. (Androidon, ha a videó-PiP nem él, a **teljes app**
   kerül kis képernyőre — ez a tartalék út.)
5. **Push:** amikor elindítod az adást, **minden regisztrált eszköz** értesítést kap
   („Élőben vagyunk Twitchen”), és a bejövő értesítések listájában is megjelenik.
   Egy adásról **egyszer** szól; a következő adás újra szól.

## Amit Te tudsz állítani (build nélkül)

**A beállítás a WordPress-adminban van:** *HUHS Mobile → **Twitch beharangozó***.

| mező | mit csinál |
|---|---|
| **Kép** | **saját kép URL-je** a kártyára (Feltöltés/kiválasztás gombbal a médiatárból). Üresen hagyva a Twitch **mozgó** előnézete megy — az viszont csak adás közben mutat valamit. |
| **Felirat** | a kártya felirata (legfeljebb 80 karakter; alapból: „Élőben a Twitch-csatornán”). |
| **Engedélyezve** | kikapcsolva a kártya **teljesen elrejtve** (a Twitch-oldal persze nyitható marad). |
| **Élő adás nélkül is látszódjon** | **+ kép** → a kártya **élő adás nélkül is látszik** (előre behirdetés). Kép nélkül mentéskor **kikapcsol**, mert nem lenne mit mutatni. |

**Előre behirdetés (példa):** kép: `https://…/plakat.jpg`, felirat: „Következő adás: péntek 20:00”,
és bekapcsolva az „Élő adás nélkül is látszódjon”. Ilyenkor a kártyán **nincs** „ÉLŐ” jelvény, a
gomb felirata pedig „Twitch-csatorna”, vagyis a felhasználó nem kap hamis élő jelzést.

⚠️ **Mennyi idő alatt ér oda?** A beállítást a **Twitch-figyelő kör** viszi át az appokhoz
(**5 percenként** fut), ezért legfeljebb ~5 perc, és **új app-verzió nem kell hozzá** — a már kint
lévő appok is látják. (A kártya a Firestore `app_settings/twitch` dokumentumból dolgozik, ezt
tölti a plugin beállítása.)

Az agent is be tudja állítani helyetted egy paranccsal (a Firestore-t írja):
`node tmp/setup-twitch-card-settings.mjs --offline --image=https://…/plakat.jpg --header="Következő adás: péntek 20:00"`
(kiíráshoz nem kell semmit átírni — a szkript a jelenlegi állapotot is megmutatja).

## Amit az agent tud (ha kéred)

- a kártya **alapértelmezett képét** kicserélni (pl. plakátra) úgy, hogy mindenkinél az legyen;
- a **push szövegét** módosítani (`functions/notification-texts.js` → `twitch_live`);
- a **figyelés ütemét** sűríteni (most 5 percenként fut: `sendTwitchLiveNotice`);
- a Twitch-oldal **elrendezését** (pl. chat a lejátszó mellett, nagy képernyőn).

## Őszinte korlátok

1. A lejátszó **WebView-s beágyazás**, ezért a képminőség a WebView-tól függ; natív
   Twitch-lejátszóhoz Twitch-API-kulcs és külön munka kellene.
2. **iOS-en** a kis képernyő a **WebKit saját videó-PiP-je** — a 387-ben ez már be van
   kötve (inline lejátszás + app-elhagyáskor automatikus kérés + fejléc-gomb). A
   **telefonos** működés mérése **aláírt** buildet kér, ezért az a TestFlight-körhöz
   tartozik; a kód a csomagban van (a sideloadolt 386/387 is tartalmazza).
3. A **Twitch-chat** beágyazása nincs benne (a tulajdonos az app saját chatjét kérte).
4. Az élő állapot a Twitch **nyilvános** web-kliensével kérdezősködik (kulcs nélkül);
   ha a Twitch ezt a végpontot megváltoztatja, a figyelő **némán** nem jelez — ezért a
   kihagyás okát naplózzuk (`twitch_live_skip`), és a főoldali kártya a közvetlen
   mérésből is dolgozik.
5. Az élő adásról szóló **széles push** élesben akkor mérhető, ha **tényleg megy adás**
   (a csatorna a mérés idején nem él) — a döntés logikája tiszta tesztekkel, a küldés
   lánca pedig korábbi éles küldésekkel bizonyított.
