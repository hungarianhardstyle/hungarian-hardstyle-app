# Kiadási changelog ellenőrzőlista

> **A soron következő feltöltés kész, másolható szövegei: `docs/PLAY-KIADASI-JEGYZET.md`**
> (Play-blokkok karakterlimittel, build szerinti tételes lista, plugin-kiadásjegyzék).
> Azt a fájlt ellenőrzi a `node tools/check-play-notes.mjs` — a Play-blokk hosszát,
> a build-lefedettséget és az AAB SHA-256-át is.
>
> **Állapot (2026-09-18):** a Playen a legutóbb publikált build a **322**; a legfrissebb
> elkészült csomag a **`build/HUHS-v1.0.0+328-release.aab`** (versionCode 328), ez viszi fel
> a 323–328 összes javítását. A lenti 322-es blokk ezért **archív**: a 322 már kint van.

## Archív: a 322-es kiadás szövegei (már publikálva)

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
