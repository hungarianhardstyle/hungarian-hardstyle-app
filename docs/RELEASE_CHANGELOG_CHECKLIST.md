# Kiadási changelog ellenőrzőlista

## Következő kiadás (1.0.0+322) — changelog szövegek

**Google Play Console – kiadási megjegyzések (magyar):**

```
- Új: Nyereményjáték a főoldalon — kvízkérdés, helyes válasz esetén részvétel a sorsoláson.
- A nyertes nevét és a nyeremény leírását a játék lezárása után az app is mutatja.
- A Kérdőív és a Szavazz/Eredmények sor a főoldalon ugyanolyan széles, mint a felette lévő kártya.
- A kérdőív eredményeit csak adminisztrátor látja; adminnak szavazás nélkül is látszik.
```

**App (Több → Névjegy) – ugyanez röviden:**

```
- Nyereményjáték: kvíz a főoldalon, helyes válasszal a sorsolásban.
- Egységes, hero-szélességű sorok a főoldalon.
- A kérdőív eredményeit csak admin látja.
```

**HUHS Mobile API WordPress-plugin (2.5.0) – kiadásjegyzék:**

```
- Új: Nyereményjáték (kvíz) — CPT, admin oldal legördülővel, sorsolás és nyertes-kihirdetés.
- Új REST-útvonalak: /prize/active (nyilvános), /prize/enter, /prize/status,
  /prize/pending, /prize/participants, /prize/winner (a nyilvánoson kívül mind
  application password-del védett).
- A /prize/active bekerült a nyilvános cache engedélylistájába.
```

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
