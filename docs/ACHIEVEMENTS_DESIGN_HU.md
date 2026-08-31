# HUHS achievement- és jelvényrendszer – technikai terv

## Termékdöntés

- A jelvénygrafikákat a tulajdonos készíti és tölti fel; a rendszer nem generál AI-grafikát.
- Minden regisztrált felhasználó kap egy alapjelvényt 0 pontnál.
- A profil mindig a legmagasabb elért aktív rang jelvényét mutatja.
- A pontszám és a rang elérése szerveroldali döntés; a kliens nem írhat közvetlenül pontot.
- A jelvénykatalógus és a FAQ külön adminisztrációs feladat; a FAQ csak a végleges működés után frissítendő.

## Megvalósítási állapot

Az app profilnézeteibe bekerült a visszafelé kompatibilis achievement-kártya. A saját és a nyilvános profil a szerver által küldött pontot, jelvénynevet, leírást és kép-URL-t jeleníti meg; hiányzó adatnál a nulla pontos „Kezdő ütem” alapjelvény látszik. A kliens nem írhat achievement-pontot, ezért a pontozó ledger és a pontokat hitelesen kiíró backend-funkciók külön következő lépésként maradnak.

## Kezdeti ranglépcsők

| Minimum pont | Rang | Jelvény |
|---:|---|---|
| 0 | Kezdő ütem | alap, feltöltött grafika |
| 100 | Első lépés | feltöltött grafika |
| 300 | Rendszeres látogató | feltöltött grafika |
| 700 | Hardstyle arc | feltöltött grafika |
| 1500 | Közösségi ember | feltöltött grafika |
| 3000 | Scene veteran | feltöltött grafika |
| 6000 | HUHS legenda | feltöltött grafika |

Az értékek kezdeti javaslatok; élesítés előtt adminból módosíthatónak kell lenniük.

## Pontforrások és visszavonás

Az aktivitás eseményazonosítóhoz vagy műveletazonosítóhoz kötött, idempotens ledger-bejegyzést hoz létre.

- eseményre „Ott leszek”: +10, eseményenként egyszer;
- meetup jelzés: +5, eseményenként egyszer, visszavonáskor levonható;
- kölcsönös meetup-kapcsolat: +15, páronként és eseményenként egyszer;
- eseményértékelés: +10, eseményenként egyszer;
- hír like: +2, hírenként egyszer; like visszavonásakor levonható;
- profil első teljesítése: +30, felhasználónként egyszer;
- moderált, értékes közösségi aktivitás: csak külön jóváhagyott pontforrásként;
- meghívott új regisztrációja: +50 a meghívónak, egyszeri szerveroldali ellenőrzéssel;

Nem adható pont saját tartalomra, ismételt kattintgatásra vagy kliensből beküldött tetszőleges pontértékre.

## Adatmodell-javaslat

### WordPress – jelvénykatalógus

Admin által kezelt `achievement_badge` rekordok:

- `slug` – stabil, kisbetűs azonosító;
- `name` – megjelenő rangnév;
- `min_points` – szükséges pontszám;
- `description` – rövid magyarázat;
- `image_url` – feltöltött jelvénygrafika;
- `sort_order` és `active`.

Publikus REST-válaszban csak az aktív, megjelenítéshez szükséges mezők szerepelhetnek. A feltöltés és szerkesztés admin jogosultságú marad.

### Firebase – felhasználói pontállapot

- `community_profiles/{uid}`: összesített `achievementPoints`, `highestBadgeSlug`, `achievementUpdatedAt`;
- `community_profiles/{uid}/achievement_ledger/{eventKey}`: `source`, `delta`, `eventId`, `createdAt`, `reversedAt`.

A ledger az idempotencia és az audit alapja; az összesítés Cloud Function tranzakcióban frissül.

## Biztonság és anti-farm

- Pontjóváírás kizárólag hitelesített, szerveroldali triggerből vagy jogosított callable Functionből történhet.
- Minden jutalmazott műveletnél stabil `eventKey` kell, hogy ugyanaz a művelet ne adjon többször pontot.
- A meetup- és jelenléti pont az adott eseményhez kötött; esemény- vagy állapot-visszavonáskor korrigálható.
- A badge-küszöböt a szerver számolja, nem a kliens által küldött rangot fogadja el.
- Profilváltáskor a jogosultság mindig az új Firebase UID-hoz kötődik.
- Admin által kézzel adott korrekció kötelező indoklással és naplózott admin UID-val történjen.

## App-megjelenítés

- Profil fejlécében: jelvénygrafika, rangnév, opcionálisan pontszám.
- Jelvényre koppintva: elért rang, következő rang és hátralévő pont.
- A még el nem ért rangok halvány/lezárt állapotban láthatók lehetnek, de a grafika és a feltételek a publikus katalógusból érkezzenek.
- A rangkártya ne takarja el a profilt, és ne legyen kötelezően teljes képernyős elem.

## Bevezetési sorrend

1. WordPress badge-katalógus és admin feltöltés.
2. Firebase ledger + szerveroldali pontszámítás.
3. Kezdeti, bizonyítható pontforrások: Ott leszek, meetup, értékelés, hír like, profilkitöltés.
4. Profiljelvény és rangállapot megjelenítése.
5. Anti-farm tesztek és kétfelhasználós esemény/meetup ellenőrzés.
6. FAQ frissítése csak a működő végleges folyamat után.
