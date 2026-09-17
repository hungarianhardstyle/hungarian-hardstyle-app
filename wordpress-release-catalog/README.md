# HUHS Release Catalog

WordPress shortcode a nyilvános release-katalógushoz (1.3.0):

```text
[huhs_release_catalog]
```

Az adatokat a meglévő `huhs/v1/releases` végpontról olvassa. A fizetős és az
ingyenes kiadványokat külön szekcióban, az eseményoldal kártyáihoz igazított,
egységes méretű kártyákban jeleníti meg. A fizetős kártya csak tényleges
product ID-val és árral rendelkező Play-változatokat mutat; az árak bruttó árak.
Az ingyenes kiadvány nem kap fizetős termékárat és nem jelenik meg hozzá WAV
vagy más nem létező vásárlási opció. Vásárlás és letöltés kizárólag az Android
appban történik.

A plugin nem ad hozzá reklámot, reklámszkriptet vagy hirdetési blokkot. A
katalógusoldalon a téma automatikus hirdetésblokkjai is el vannak rejtve; más
 oldalak hirdetéseihez a plugin nem nyúl.

A plugin a nyilvános `huhs/v1` GET-válaszokra rövid, útvonalfüggő
`Cache-Control` és `Vary: Accept-Encoding` fejléceket ad. A hírek és események
45 másodpercig, a ritkábban változó nyilvános adatok 5 percig cache-elhetők.
Ez nem érinti a vásárlási vagy felhasználói adatokat. A gzip/Brotli tömörítést
a tárhely webszerverén, CDN-jén vagy reverse proxyján kell bekapcsolni; a plugin
nem állít be hamis `Content-Encoding` fejlécet.
