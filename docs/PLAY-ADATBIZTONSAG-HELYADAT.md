# Play Console – Adatbiztonság (Data safety) frissítése a helyadat miatt

**Mikor:** a 421-es (helyalapú becsekkolást tartalmazó) AAB feltöltése ELŐTT. A Play Console-ban az űrlapot csak a tulajdonos tudja módosítani; az alábbi válaszok a kód működéséből jönnek. A Play kérdéseinek pontos szövege változhat, ezért a válaszokat a konzol aktuális szövegével kell egyeztetni (a kódot ellenőriztem, az űrlap mostani szövegét nem láttam).

**Útvonal:** Play Console → az alkalmazás → Szabályzat és programok → Alkalmazás tartalma → Adatbiztonság → Kezelés.

## Mit csinál az app (a kód alapján)
- Az Android-engedély: `ACCESS_FINE_LOCATION` és `ACCESS_COARSE_LOCATION`, **csak előtérben** (használat közben), a „Itt vagyok a helyszínen” gombra koppintva, megerősítő ablak után.
- A telefon pozícióját **egyszer** elküldi a `checkInEventGps` szerverfüggvénynek (Firebase), amely csak azt ellenőrzi, hogy az esemény helyszínének 250 m-es körzetében vagy-e. A pozíciót **nem tároljuk és nem naplózzuk**, csak az eredményt (becsekkolt vagy nem).
- Az alkalmazás nem kér háttérben történő helyhozzáférést.

## Javasolt válaszok

| Kérdés | Válasz |
|---|---|
| Gyűjt vagy oszt-e helyadatot? | **Igen, gyűjt** |
| Adattípus | **Pontos hely** (és a közelítő hely, mert az engedély azt is kéri) |
| Megosztja harmadik féllel? | **Nem** (a szervert mi üzemeltetjük; a Firebase adatfeldolgozó, a Play szerint a szolgáltatói adatfeldolgozás nem „megosztás”) |
| Ideiglenesen (ephemerálisan) kezelik? | **Igen**, az adat csak a kérés feldolgozásáig él, nem kerül tárolásra |
| Kötelező vagy választható? | **Választható** (a QR-kód mindig használható helyette) |
| Cél | **Alkalmazásfunkciók** (becsekkolás ellenőrzése); nem hirdetés, nem elemzés |
| Titkosítva továbbítják? | **Igen** (HTTPS) |
| Törlési lehetőség | A pozíciót nem tároljuk, ezért nincs mit törölni; a becsekkolás-rekord a fiók törlésével törlődik |

## Egyéb, amit érdemes átnézni ugyanekkor
- **HARD-tárca:** az összekötött tárcacím a fiókhoz kötve tárolódik (az adatvédelmi szövegben szerepel). A Play adattípusai között nincs kifejezetten „tárcacím”; a legközelebbi választás a **Felhasználói azonosítók** vagy az **Egyéb pénzügyi adatok**. Ezt a tulajdonosnak kell eldöntenie, és a **Pénzügyi funkciók nyilatkozatával** (kripto) összhangban kell tartani (ügyvédi lista 20. pont).
- **Egyéb, már deklarált adatok** (fiók, e-mail, profilkép, push-token, vásárlás) változatlanok.
- A Play-ben az engedélyhez **nem kell külön „háttérhely” nyilatkozat**, mert csak előtérben használjuk.
- Az adatvédelmi szöveg (Adatvédelem és GDPR) a helyalapú becsekkolást és a jelvényeket már tartalmazza; a **webes adatvédelmi nyilatkozat** (ha a Play-ben az van megadva) ezzel egyeztetendő.

## Nem ellenőrzött
Az űrlap jelenlegi kérdései és kategóriái; hogy a Play a Firebase Cloud Functions használatát adatfeldolgozásnak tekinti-e (a szabályzat szerint igen, de a konzol jelzése dönt); a tárcacím besorolása.
