# Twitch az appban — hogyan működik, és mit tudsz állítani build nélkül

Ez a lap a **385-ös build** Twitch-integrációját írja le röviden (2026-10-02).

## Amit a felhasználó lát

1. **Főoldali kártya** — csak akkor jelenik meg, ha **megy az adás**. A képe a Twitch
   **mozgó** előnézete (30 másodpercenként frissül), felül az **ÉLŐ** jelvény és a nézőszám.
   A kártya a hírek blokkja **után**, a „Kedvenceid” előtt áll; ha nem él a csatorna,
   **nem hagy üres helyet**.
2. **Twitch-oldal** (a kártyára koppintva, vagy a „Nézd élőben” gombbal):
   - felül a **beágyazott lejátszó** (`player.twitch.tv/hungarianhardstyle`),
   - alatta **az app saját chatje** (ugyanaz, mint a Chat fülön: emotok, reakciók,
     `@`hivatkozások, értesítés) — a tulajdonos kérése szerint **nem** a Twitch-chat,
   - **Támogatás** gomb (PayPal — ugyanaz a link, mint a Több → Támogatás képernyőn).
3. **Hangfókusz:** amíg az adás oldal nyitva van, a **rádió és az előzetes leáll**;
   amikor kilépsz, a rádió **visszatér**, ha előtte szólt.
4. **Kis képernyő (PiP):** Androidon, ha az adás közben más appba lépsz, a stream
   **kicsiben megy tovább**. iOS-en a WebView saját PiP-gombja érhető el a videón.
5. **Push:** amikor elindítod az adást, **minden regisztrált eszköz** értesítést kap
   („Élőben vagyunk Twitchen”), és a bejövő értesítések listájában is megjelenik.
   Egy adásról **egyszer** szól; a következő adás újra szól.

## Amit Te tudsz állítani (build nélkül)

A főoldali kártya külseje a Firestore-ban él, a **`app_settings/twitch`** dokumentumban:

| mező | mit csinál |
|---|---|
| `imageUrl` | **saját kép URL-je** a kártyára. Üresen hagyva a Twitch **mozgó** előnézete megy. |
| `headerText` | a kártya felirata (alapból: „Élőben a Twitch-csatornán”). |
| `enabled` | `false` → a kártya **teljesen elrejtve** (a Twitch-oldal persze nyitható marad). |

A dokumentum már létrejött üres értékekkel, tehát csak át kell írnod a
Firebase-konzolon (Firestore → `app_settings` → `twitch`).

## Amit az agent tud (ha kéred)

- a kártya **alapértelmezett képét** kicserélni (pl. plakátra) úgy, hogy mindenkinél az legyen;
- a **push szövegét** módosítani (`functions/notification-texts.js` → `twitch_live`);
- a **figyelés ütemét** sűríteni (most 5 percenként fut: `sendTwitchLiveNotice`);
- a Twitch-oldal **elrendezését** (pl. chat a lejátszó mellett, nagy képernyőn).

## Őszinte korlátok

1. A lejátszó **WebView-s beágyazás**, ezért a képminőség a WebView-tól függ; natív
   Twitch-lejátszóhoz Twitch-API-kulcs és külön munka kellene.
2. **iOS-en** az automatikus (app-elhagyásra induló) PiP külön natív munka
   (`AVPictureInPictureController`), és csak **aláírt** buildben tesztelhető — ez a
   TestFlight-körhöz tartozik.
3. A **Twitch-chat** beágyazása nincs benne (a tulajdonos az app saját chatjét kérte).
4. Az élő állapot a Twitch **nyilvános** web-kliensével kérdezősködik (kulcs nélkül);
   ha a Twitch ezt a végpontot megváltoztatja, a figyelő **némán** nem jelez — ezért a
   kihagyás okát naplózzuk (`twitch_live_skip`), és a főoldali kártya a közvetlen
   mérésből is dolgozik.
