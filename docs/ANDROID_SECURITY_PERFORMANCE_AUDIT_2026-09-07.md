# Android biztonsági és teljesítményaudit — 2026-09-07

## Végrehajtott javítások

- A beépített böngésző, az embedek és a külső hivatkozások csak teljes `https://` URL-t nyitnak meg. A WebView `mailto:`, `tel:` és `geo:` hivatkozásokat a rendszernek adja át, minden más nem HTTPS-es séma blokkolva marad.
- Az esemény-, előadó- és szervezőbeküldő űrlapok már nem engednek `http://` hivatkozást. Ez egyezik az Android `usesCleartextTraffic=false` beállításával.
- A hivatkozásvédelmet kis Flutter-teszt fedi le.
- A képfeltöltés közös útvonalai JPG/PNG/WebP magic-byte ellenőrzést és 5 MB-os korlátot használnak; az üzenetképek megjelenítése csak a saját HTTPS Cloudinary-képtárból engedélyezett.
- A Cloudinary `Hun_hs_Mobile` unsigned preset kezelőfelületi korlátozása is beállítva: `jpg, jpeg, png, webp`.
- A privát chat képei nagyítható lightboxban nyílnak meg, az `X` gombbal bezárhatók.
- A HUHS Legenda toplista 45 másodperces memóriacache-t és in-flight kérés-összevonást kapott, így visszanyitáskor nem kérdezi le újra feleslegesen.
- A Firebase App Check Androidon debug buildben debug providert, release buildben Play Integrity providert használ; a `hu.hungarianhardstyle.app` release app Play Integrity-regisztrációja sikeres, a callable Functions végpontokon az enforcement bekapcsolva. A token nélküli élő `articleComments` próbahívás HTTP 401-et kapott.

## Ellenőrzött állapot

- A release manifestben: `versionCode=263`, `versionName=1.0.0`, `allowBackup=false`, `usesCleartextTraffic=false`.
- R8 teljes minifikálás és erőforrás-csökkentés aktív; az R8 konfigurációs elemző jelentése elkészült: `build/app/reports/r8/r8-config-analyzer-release.html`.
- A WorkManager/Room célzott keep-szabályai megmaradtak, mert ezek release indulási hibát előznek meg. Nem találtam biztonságosan szűkíthető, bizonyítottan fölös szabályt.
- A WordPress szolgáltatás HTTPS-t, időkorlátot, rövid memóriacache-t, tartós publikus cache-t és in-flight kérés-összevonást használ. Nem vezettem be új cache-réteget.
- Az eseményflyerek eredeti minőségben, a hírek és profilképek célmérethez illesztett cache-mérettel töltődnek. Nem változtattam globális képtömörítésen vagy minőségkorláton.
- Publikus klienskonfigurációkon és placeholder mintákon kívül nem találtam repositoryban keménykódolt titkot; a backend érzékeny értékei Firebase Secret Managerből jönnek.

## Függőségek és nyitott karbantartás

- A Functions függőségei frissültek: `firebase-admin` 14.3.0, `firebase-functions` 7.3.2 és a nem törő `qs` 6.16.0 javítás.
- A Firebase Admin 14 által kivezetett `admin.app()` hívás `getApps()[0]`-ra váltott, a régi névtérbeli Firestore-segédek pedig a hivatalos moduláris `FieldPath` és `FieldValue` importokra. A Functions-modul betöltése, a 10 backendteszt, az éles Functions-deploy és az enforcement token nélküli élő próbája (HTTP 401) sikeres.
- `functions/npm audit --omit=dev`: 0 sérülékenység. A Firebase Admin opcionális felhőtárolási tranzitív láncát célzott, Node 22-kompatibilis `@google-cloud/storage` 8.0.1 és `uuid` 11.1.1 override frissíti; régi Firebase Admin főverzióra nem léptünk vissza.
- A Gradle buildben ismert AGP/Kotlin átállási figyelmeztetések vannak több Flutter plugin miatt. Ezek megszüntetése több függőség frissítését igényli; a mostani stabil release útvonalat nem módosítottam.
- A Google Play Data Safety deklaráció célzott, manuális összevetése továbbra is nyitott.
- Az app `https://hungarianhardstyle.hu/invite/...` intent-filtere és a domain `/.well-known/assetlinks.json` végpontja rendben van: HTTP 200, `application/json`, a Play alkalmazás-aláíró SHA-256 tanúsítványa szerepel benne.

## Ellenőrzések

- `flutter test` — sikeres, 62 teszt.
- `flutter analyze --no-pub` — hiba nélkül; 6 meglévő információs lint.
- `node --check functions/index.js` — sikeres.
- `node --test functions/*.test.cjs` — 10/10 sikeres.
- `firebase deploy --only functions` — sikeres; az éles függvények Node.js 22 futtatókörnyezetben futnak.
- `:app:lintRelease` — sikeres.
- `git diff --check` — whitespace hiba nélkül.
- Release AAB: `build/app/outputs/bundle/release/app-release.aab`.
- SHA-256: `80B5AF7EEAEC8EE89EAF49A9571D21088FB02465029CD258A45EF8C3E3B6B252`.

## Release smoke teszt — Pixel 8, Android 16 emulátor

- A saját, minified, aláírt `263 (1.0.0)` release APK települt és elindult.
- Home, Hírek, Események, Chat és Label élő tartalommal megnyílt; nem jelent meg Flutter- vagy Android crash a logcatben.
- A hírek, event flyerek, chat avatarok és release borítók kézzel ellenőrizve élesek és olvashatók voltak.
- Kijelentkezett állapotban a játék látható, megnyitható, de a válaszadás helyett a regisztrációs követelményt jelzi.
- A Label Billing-szolgáltatás emulátoron nem állt készen; az app ezt újrapróbálási állapottal kezelte, crash nélkül. Valódi vásárlás és rewarded hirdetés nem futtatható hiteles Play Billing környezet nélkül.
- Három release cold start: 772 ms, 1460 ms, 662 ms. Aktuális memória-pillanatkép: 209933 kB PSS. Korábbi összehasonlító mérés hiányában ebből nem következik százalékos javulás.
