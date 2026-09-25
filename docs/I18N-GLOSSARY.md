# Angol fordítás — glosszárium és szabályok

Ez a fájl **kötelező** minden fordítónak (embernek és modellnek): ugyanaz a
magyar szó mindig ugyanazt az angol szót kapja, különben a felület széthúz.

## A legfontosabb szabályok

1. **A magyar szöveg a kulcs** — nem szabad megváltoztatni, csak az angol értéket
   írni. Ha egy szövegre nincs jó angol, a magyar marad (a program úgyis a
   magyarra esik vissza).
2. **Márkaneveket nem fordítunk**: Hungarian Hardstyle, HUHS, DJ-nevek, fesztivál-
   nevek, kiadványcímek, előadónevek — ezek maradnak.
3. **Helyőrzők és formázók érintetlenül**: `{n}`, `%s`, `\n`, `…`, zárójelek,
   írásjelek szerkezete. A `…` marad `…` (ne `...`).
4. **Ne legyen üres érték.** Ha a szöveg már angol, az érték ugyanaz.
5. **Rövid, gomb-barát feliratok**: ahol a magyar rövid (`Mégse`, `Törlés`),
   ott az angol is rövid (`Cancel`, `Delete`).
6. **Nem fordítunk felhasználói tartalmat** (chat üzenet, hozzászólás, név) —
   az ilyen szövegek nincsenek is a kulcsok között.

## Glosszárium (magyar → angol)

| Magyar | Angol | Megjegyzés |
| --- | --- | --- |
| hír / hírek | news | |
| esemény | event | |
| szervező | organizer | |
| kiadvány | release | zenei megjelenés |
| előadó / DJ | artist / DJ | a „DJ" marad DJ |
| nyereményjáték | giveaway | |
| szavazás | voting | |
| szavazat | vote | |
| kvíz | quiz | |
| kérdőív / szavazólap | poll | |
| közösség | community | |
| értesítés | notification | |
| hozzászólás | comment | |
| kedvelés / lájk | like | |
| bejegyzés / poszt | post | |
| üzenet | message | |
| hírlevél | newsletter | |
| feliratkozás | subscribe | |
| fiók | account | |
| bejelentkezés | sign in | |
| kijelentkezés | sign out | |
| regisztráció | sign up | |
| jelszó | password | |
| e-mail-cím | email address | |
| felhasználónév | username | |
| megjelenítési név | display name | |
| profil | profile | |
| ismerősök | friends | |
| követés / követő | follow / follower | |
| moderátor | moderator | |
| admin | admin | |
| feltöltés | upload | |
| beküldés | submission | |
| jóváhagyás | approval | |
| elutasítás | rejection | |
| szerkesztés | edit | |
| törlés | delete | |
| mentés | save | |
| mégse | cancel | |
| bezárás | close | |
| vissza | back | |
| tovább | next | |
| kész | done | |
| újrapróbálás | retry | |
| frissítés | refresh | |
| betöltés | loading | |
| találat | result | |
| keresés | search | |
| összes | all | |
| kiemelt | featured | |
| hamarosan | coming soon | |
| zene | music | |
| lejátszás | playback | |
| cím | title | |
| hossz | duration | |
| szöveg | text | |
| beállítások | settings | |
| megosztás | share | |
| másolás | copy | |
| link | link | |
| feltétel | requirement | |
| szint | level | |
| pont | point | |
| jelvény | badge | |
| ranglista | leaderboard | |
| statisztika | statistics | |

## A folyamat

- A kulcsokat a kód adja: `node tools/extract-ui-strings.mjs --write`
  (`tmp/i18n/keys.json`, chunkok a `tmp/i18n/chunks/`-ban).
- A fordítások chunkonként készülnek: `tmp/i18n/en/chunk-NN.json` (magyar → angol).
- Az összevonás és az ellenőrzés: `node tools/merge-i18n.mjs --write` +
  `node tools/check-i18n.mjs --strict` (lefedettség, üres érték, helyőrzők,
  magyarul maradt szövegek).

## Mért állapot (2026-09-25, első kör)

- **783 célzott literál, 67 fájlban** → **589 egyedi szöveg (15 473 karakter)**.
- **589/589 lefordítva (100%)**, 0 üres, 0 magyarul maradt érték, 0 helyőrző-hiba.
- A szótár: `assets/i18n/en.json` (599 kulcs; a 10 többlet a kézzel írt magból
  van, és nem árt: csak akkor él, ha a kód pontosan azt a szöveget kéri).

## Amit az első kör SZÁNDÉKOSAN kihagyott

- **Interpolált (`$`-os) feliratok** — csak **8** ilyen van, és ezek külön,
  `trArgs`-os körben mennek (a helyőrző `{n}` alakban kerül a szótárba):
  `'${index + 1}. lehetőség'`, `'${option + 1}. válasz'`,
  `'Jelentések (${reports.length})'`, `'Beküldés #$id'`,
  `'Már értékelted: …'`, `'Ott leszek: $attending résztvevő'`,
  `'Kiválasztva: ${selected.length}/5'`, `'Összes megjelenése (${all.length})'`.
- **Nem UI-környezetű** magyar szövegek (napló, hibaszöveg, `throw` üzenet):
  ezeket a `check-i18n.mjs` külön körben méri.
- **A felhasználó szövege** (chat üzenet, hozzászólás, név): soha.

## Fordítói döntések, amiket érdemes tudni

- `Elutasítás` → **Reject** (nem „Rejection"): az `Elfogadás` → „Accept" párja
  mellett gomb-feliratnak rövidebb kell (a fordító jelezte, jóváhagyva).
- `adatlap` → **profile** (a szó szerinti „data sheet" félrevezető lenne).
- `Meetup` és a márkanevek (Hungarian Hardstyle, HUHS, Real Hardstyle FM,
  Spotify, PayPal, Cloudinary) **maradnak**.
- `Előre`/`Előző` → **Forward**/**Previous** (nem „Next"): a `Tovább` a „Next".
- `Újra` → **Retry** (a két előfordulás hiba utáni újrapróbálás).

