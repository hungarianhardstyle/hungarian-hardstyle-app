# Angol nyelvi verzió – későbbi terv

## Döntések

- A magyar oldal és a magyar appos működés marad az alapértelmezett.
- A meglévő magyar cikkeket nem írjuk felül; külön angol fordítás készül hozzájuk.
- Az angol webes tartalom külön `/en/` URL-struktúrát és nyelvváltót kap.
- A magyar és angol cikkváltozatok össze lesznek kapcsolva.
- A fordítás természetes, humanizált angol legyen, ne ellenőrzés nélküli szó szerinti gépi fordítás.
- Első körben a fontosabb és újabb cikkek készülnek el, majd kategóriánként haladunk.

## Mobilapp

- Ha az appban is elérhető lesz az angol tartalom, kell egy Magyar / English nyelvválasztó.
- A magyar legyen az alapértelmezett nyelv.
- A választás legyen elmentve, és újraindítás után is maradjon meg.
- A felület fordítása és a hírek/tartalmak nyelve külön kezelhető legyen.
- Az API később `lang=hu` és `lang=en` alapján adhassa vissza a megfelelő tartalmat.
- Hiányzó angol fordításnál ne legyen hibás automatikus szöveg; maradjon magyar, vagy jelenjen meg egyértelmű jelzés.

## Biztonsági feltétel

- A WordPress HUHS API magyar útvonalai, az app meglévő funkciói és a magyar tartalom működése nem törhet el.
- A bevezetés sorrendje: WordPress nyelvi réteg, angol oldalak és cikkek, API-kompatibilitási teszt, majd opcionálisan az app angol támogatása.
