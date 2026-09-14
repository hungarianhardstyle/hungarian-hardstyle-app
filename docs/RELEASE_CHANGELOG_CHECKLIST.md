# Kiadási changelog ellenőrzőlista

## Legutóbb tesztelt build

- Verzió: `1.0.0+309` (versionCode 309)
- AAB: `build/HUHS-v1.0.0+309-release.aab`
- Tesztelt fókusz: Google- és e-mailes regisztráció, profilnév frissítése,
  adminfelületi e-mail-megjelenítés, valamint regisztrációs és admin törlési e-mail.

Minden új mobilapp-kiadásnál ugyanazt a rövid, magyar changelogot kell rögzíteni
mindhárom helyen:

1. Google Play Console – az adott zárt tesztkiadás kiadási megjegyzései.
2. Az app **Több → Az appról** / Névjegy képernyője – az aktuális verzióhoz
   tartozó frissítések listája.
3. A HUHS Mobile API WordPress-plugin kiadásjegyzéke – az API-csomag verziója
   és az appot érintő kompatibilitási változások.

## Tartalmi szabályok

- A changelog csak ténylegesen elkészült és ellenőrzött módosításokat írjon le.
- A kliens- és WordPress-oldali változásokat külön pontban kell jelölni.
- Ha nincs WordPress-oldali módosítás, ezt egyértelműen jelezni kell; nem szabad
  API-változást sugallni.
- A verzió- és buildszám minden helyen egyezzen a kiadással.
- Új AAB feltöltése előtt ellenőrizni kell, hogy a Névjegyben látható verzió
  és changelog nem maradt-e le.
