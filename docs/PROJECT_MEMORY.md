# Hungarian Hardstyle App — projektmemória

## 2026-09-04

### Profil törlés

Sikeres profil törlés után a kliens üríti a felhasználóhoz kötött memória- és tartós cache-eket, a helyi kedvenceket, admin-cache-t, profil/achievement snapshotokat és biztonsági/token állapotot. A WordPress publikus cache is ürül, majd a fiók kijelentkezik és a navigáció a Kezdőlapra vált.

### Ismerős-jelölés elfogadása

Elfogadáskor a jelölő Notification-bejegyzést és push értesítést kap. A bejegyzés az elfogadó profiljára mutat, és determinisztikus kulccsal védett a duplikációtól. A Firebase `notifyConnectionRequest` trigger éles.

### Keresés

A hírek-, DJ- és szervezőkeresés API-válaszait a kliens is tartalmi egyezéssel szűri. A szerver esetleges alapértelmezett vagy hibás visszaadását így nem lehet hamis találatként megjeleníteni.

### Következő build

Az elfogadási push értesítés appoldali profilnavigációja a következő APK/AAB buildben lesz tesztelhető. Új AAB a fenti módosításokhoz jelenleg nem készült.

## 2026-09-05

### HUHS szavazás — közös aktuális állás és teljes beküldés

- A WordPress Mobile API `2.4.75` csomagban elkészült az admin `voting_seasons` és `voting_summary` szerződés, valamint az „Aktuális szavazási állás” WordPress-menüpont. Az évadválasztó, a kategóriánkénti jelöltek és a Firestore-ból számolt szavazatszám ugyanabból az adatforrásból érkezik.
- A WordPress admin belső összesítője kategóriánként csökkenő szavazatszám szerint rendez. A nyilvános eredménylink csak az „Eredmények közzététele engedélyezve” kapcsoló és a megadott link mellett jelenik meg; a belső állás nem publikus.
- A natív HUHS admin összesítője a WordPress admin API `voting_summary` válaszát használja, évadválasztóval és szavazatszám szerinti sorrenddel.
- A mobilos szavazólap egyetlen közös „Szavazok” gombot használ. A hiányzó kötelező kategóriákat és választásszámokat előre jelzi; a már leadott kategóriák „Köszönjük a szavazatod!” állapotot mutatnak.
- A `submitVotingBallot` és `getVotingStatus` Firebase callable-ok élesek. A `voting_votes` kliensoldali közvetlen írása le van tiltva; a szerver pontos kategória- és jelöltszámot, duplikációt és ismételt beküldést ellenőriz.
- Regisztrált felhasználó teljes, kötelező szavazólapjának leadásakor évadonként egyszer 10 achievement pont jár. A jóváírás szerveroldali, idempotens ledger-bejegyzés; az app achievement-leírása is tartalmazza ezt a pontforrást. A `submitVotingBallot` frissítve és élesítve.
- Ellenőrzés: `flutter analyze --no-pub`, Flutter tesztek 55/55, Node tesztek 10/10, `node --check functions/index.js`, Firestore-szabály deploy sikeres. APK/AAB ebben a körben nem készült.
- Telepíthető WordPress csomag: `build/huhs-mobile-api-2.4.75.zip`. A WordPress éles feltöltése külön telepítési lépés; a natív összesítő az új API telepítése után működik.

### 2026-09-05 — vendégszavazás és anonim chat-megjelenítés

- Az éves szavazás regisztráció nélkül is leadható anonim Firebase-fiókkal.
- A kliens egy telepítéshez kötött, véletlenszerű azonosítót biztonságos helyi tárban tart; a szerver évadonkénti készülék-claimet vezet, így ugyanarról az apptelepítésről másik fiókkal sem küldhető új szavazat.
- A vendégszavazás regisztrációkor e-mailes vagy Google-fiókhoz kapcsolható az anonim Firebase-fiók összekapcsolásával, így a korábbi szavazás ugyanahhoz az UID-hoz marad kötve. Már létező Google-fióknál a szerveres készülék-claim védi a második szavazást.
- A +10 éves szavazási achievement továbbra is csak regisztrált felhasználónak jár, teljes szavazólap után, évadonként egyszer.
- A fő Chat anonim bejegyzései nem töltenek be achievementet vagy kezdő/generált jelvényt; a `isAnonymous` jelölés a régi `Unknown User ...` bejegyzésekkel is kompatibilis.
- Élesítve: `submitVotingBallot`, `getVotingStatus` és a `voting_device_claims` szerver-only Firestore-szabály.
- Ellenőrzés: Flutter tesztek 55/55, Node tesztek 10/10, `flutter analyze --no-pub`, `node --check functions/index.js`.
- A jelenlegi `+253 (1.0.0)` forrásból elkészült a debug APK és a production AAB; a készülékes futásidejű ellenőrzés még külön lépés.
