# Play-áruházlista — mért állapot és javasolt szövegek (2026-09-27)

Ez a dokumentum a **Play Console áruházi lista** (nem a kiadási jegyzet!) szövegeit és kép-tervét
tartalmazza. A mérés a Play Developer API-ból jött (`tmp/probe-play-listing-texts.mjs`, csak olvas),
a javaslatok pedig a Play karakter-korlátain belül vannak (**cím 30**, **rövid leírás 80**,
**hosszú leírás 4000** karakter).

## A mért jelenlegi állapot

| Mező | Most | Korlát | Megjegyzés |
| --- | --- | --- | --- |
| Nyelv | **csak `hu-HU`** | — | angol lista nincs (pedig az app tud angolul) |
| Cím | `Hungarian Hardstyle` | 19/30 | márkanév, nincs benne kulcsszó |
| Rövid leírás | `Magyar hardstyle hírek, események, DJ-k, közösség és kiadványok.` | 64/80 | jó, de kevés kulcsszó |
| Hosszú leírás | 4 bekezdés | **545/4000** | **a legnagyobb kihasználatlan hely** |
| Videó | nincs | — | opcionális |
| Képek | ikon 1, feature graphic 1, **telefon-képernyő 3** | 8/telefon | 7" és 10" tablet-kép **nincs** |

## Javaslat 1 — rövid leírás (80 karakterig)

Most (64):
```
Magyar hardstyle hírek, események, DJ-k, közösség és kiadványok.
```
Javasolt (68):
```
Magyar hardstyle és hardcore: hírek, bulik, DJ-k, rádió és közösség.
```

## Javaslat 2 — hosszú leírás (a mért 545 karakter helyett **1461**, a 4000-es korlát alatt)

```
A Hungarian Hardstyle a magyar hardstyle és hardcore színtér hivatalos mobilappja — hírek,
események, DJ-k, szervezők, közösség és kiadványok egy helyen.

HÍREK ÉS ESEMÉNYEK
• Friss hazai és nemzetközi hardstyle/hardcore hírek, kereshetően és kategóriákra bontva.
• Eseménynaptár flyerekkel, jegy-linkkel, térképpel és útvonaltervvel.
• Jelöld be, hogy „Ott leszek", és az app emlékeztet a buli előtt (1 héttel, 1 nappal és 6 órával).
• Ismerőseid is jönnek? Az eseménynél látod, ki lesz ott.

DJ-K, SZERVEZŐK, KIADVÁNYOK
• Teljes DJ- és szervező-adatbázis: életrajz, elérhetőségek, fellépések, kiadványok.
• Hardstyle Revolution Records kiadványai: előzetes meghallgatás, ingyenes és prémium letöltések.
• Saját zenei könyvtár: a megvásárolt/letöltött számok egy helyen, offline is.

KÖZÖSSÉG
• Chat és Live Feed: posztolás, képek, reakciók, említések.
• Saját profil, ismerősök, privát beszélgetések, jelentés és blokkolás.
• Pontok, szintek, jelvények és toplista — a közösségi aktivitás jutalmazva.
• Szavazások, kvízek, nyereményjátékok és az éves szavazás.

RÁDIÓ ÉS ÉRTESÍTÉSEK
• Real Hardstyle FM rádió az appban, háttérben is.
• Értesítések hírekről, eseményekről, emlékeztetőkről és születésnapokról — beállíthatóan.
• Magyar és angol felület, a nyelvet te választod.

Az app ingyenes, olvasni regisztráció nélkül is tudsz. A közösségi funkciókhoz 16 éves kor feletti
regisztráció szükséges; a születési dátumodat te döntöd el, hogy mások láthatják-e.
```
(Ez mért **1461** karakter — a maradék helyre további kulcsszavak és a gyakori kérdések rövid válaszai
kerülhetnek, pl. „Hogyan küldhetek be eseményt?", „Hogyan leszek DJ-profil tulajdonosa?".)

## Javaslat 3 — képernyőképek (3 → 8, magyar felirattal)

A Play a **legfeljebb 8** telefon-képernyőt mutat, és az első három számít a legtöbbet. Javasolt
sorrend és felirat (a feliratot érdemes a képre égetni, nagy betűvel):

1. **Kezdőlap** — „Minden hardstyle hír egy helyen"
2. **Események** — „Bulik, flyerek, jegyek — és az emlékeztető"
3. **Esemény adatlap** — „Ott leszek: látod, ki jön még"
4. **DJ-adatlap** — „DJ-k és szervezők, fellépésekkel"
5. **Chat / Live Feed** — „A színtér közössége"
6. **Kiadások** — „Hardstyle Revolution: hallgasd meg, töltsd le"
7. **Rádió** — „Real Hardstyle FM az appban"
8. **Pontok és szintek** — „Gyűjts pontot, kerülj a toplistára"

Emellett érdemes feltölteni **7"-os és 10"-os tablet-képernyőket** is (ugyanazok a képek
elfogadhatók), mert a Play ezeket a tablet-felületeken használja.

## Hogyan kerül fel?

1. **Play Console → Növekedés → Áruházi jelenlét → Fő áruházi lista** (nyelv: magyar).
2. A **rövid** és a **hosszú leírást** ide másold be; a **címet** csak akkor változtasd, ha a márkanevet
   is módosítanád (a márkanév a keresésben amúgy is erős).
3. **Képernyőképek:** a három meglévő képet egészítsd ki a fenti nyolcas sorrendre.
4. **Mentés**, majd a Play jóváhagyja (általában néhány óra).

⚠️ A szöveg és a képek **nem** részei az AAB-nak: feltöltés nélkül, azonnal életbe lépnek — új build
nem kell hozzá.
