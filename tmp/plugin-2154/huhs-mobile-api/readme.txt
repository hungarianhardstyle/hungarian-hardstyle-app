=== HUHS Mobile API ===
Contributors: denoiser
Tags: firebase, push, api, mobile
Requires at least: 6.0
Tested up to: 6.8
Requires PHP: 7.4
Stable tag: 2.16.5
License: GPLv2 or later
License URI: https://www.gnu.org/licenses/gpl-2.0.html

A Hungarian Hardstyle mobilalkalmazás (Flutter) WordPress-oldali API-ja: tartalom, feltöltések, push értesítések, fordítás és admin végpontok.

== Description ==

A plugin a mobilalkalmazás egyetlen backendje: REST végpontok a hírekhez, eseményekhez, kiadványokhoz, DJ-khez, szavazásokhoz, játékokhoz és a közösségi feltöltésekhez, valamint az FCM **push-küldés** (a széles körök szeletekben, folytatható láncban mennek ki).

== Changelog ==

= 2.16.5 =
* Bulis becsekkolás: a buli kezdetekor nyílik (korábban a kezdés előtt 1 órával).

= 2.16.4 =
* DJ verseny: a szavazás december 25-ig tart (a jelentkezés határideje december 10 marad).

= 2.16.3 =
* DJ verseny: a megosztási oldal csak JavaScripttel irányít át (a meta refresh-t a közösségi crawlerek követhetik, és a céloldal képét mutatták).

= 2.16.2 =
* DJ verseny: a megosztott jelentkező linkje a külön verseny-oldalra visz.

= 2.16.1 =
* DJ verseny: nyertes a szavazás lezárása után (legtöbb lájk, vagy kézi jelölés), értesítő levél a nyertesnek és az adminnak; a szavazás határideje december 20, a jelentkezésé december 10.

= 2.16.0 =
* Új: DJ verseny (HUHS Mobile → DJ verseny). Jelentkezés a hardstylerevolution.hu oldalról, jóváhagyás az adminban (Közzététel), lájkolás és egyenkénti megosztás.

= 2.15.8 =
* Az éves szavazóoldal címében megjelenik az évszám, aktív évad nélkül is.

= 2.15.7 =
* Az éves szavazóoldal a stílust és az évad állapotát az első válaszban adja vissza, lezárt évadnál nincs szavazóprogram-betöltés.

= 2.15.6 =
* Mobilbarát éves szavazás a /eves-szavazas címen, Firebase e-mailes azonosítással és közös appos szavazatszámlálással.

= 2.15.5 =
* Javítva: a több szeletben kimenő push (hír) haladását a token **kulcsa** követi, nem a sorszám — ha a kör közben valaki regisztrált vagy tokent cserélt, az egyik eszköz kétszer kapta, a másik kimaradt.

= 2.15.4 =
* Új: az időbeosztásnál megadható, mikortól látszódjon az appban (pl. a buli napján 18:00-tól).

= 2.15.3 =
* Javítva: a jelvénykép gomb a médiatárat nyitja (a médiatár a szerkesztő betöltésekor töltődik be).

= 2.15.2 =
* Új: a becsekkolási jelvény képe feltölthető/kiválasztható a médiatárból (gomb), nem kell URL-t másolni.

= 2.15.0 =
* Új: **QR-becsekkolás a bulikon** — az esemény szerkesztőjében eseményenként egyedi QR (letölthető PNG). Csak a buli ideje alatt érvényes, fiókonként egyszer; a becsekkolók pontot és jelvényt kapnak, a szerkesztőben látszik a létszám.
* Új: **időbeosztás** mező az eseményeken (soronként: 22:00 - 23:30 | DJ) — az appban a „Ma este” kártyán és az adatlapon jelenik meg.
* Új: becsekkolási jelvény neve és képe eseményenként.

= 2.14.29 =
* Javítva: egy készülék **egy** értesítést kap egy körből (a token-tárban egy eszköz több kulcson is szerepelhetett → 2-3 push ugyanarra a telefonra).
* Javítva: az **esemény-emlékeztető**, az **esemény/kiadvány push** és a **nyitás-értesítés** nem megy ki kétszer, ha a pontos cron-esemény és az ötperces biztonsági scan ugyanabba az ablakba esik (foglalás a küldés előtt).
* Javítva: az esemény/kiadvány adatcsomagjában a követett DJ-k/szervezők listája szövegként megy ki (`Array` helyett).
* Új: `push_dup=` diagnosztika — hány duplikált token van a tárban.
= 2.14.28 =
* Új: **Kiadásjegyzék az adminban** — HUHS Mobile → Kiadásjegyzék (ezt a szöveget mutatja, a readme.txt-ből).

= 2.14.27 =
* Javítva: a főoldali kiemelt kép mobil nézete — a stílus **erősebb szelektorral** és a téma után (99-es prioritás) tölt be, mert a 2.14.26 szabályát a téma azonos súlyú, későbbi szabálya felülírta. Mobilra szűkített 16:9 ablak (a kép 40% → 93%-a látszik).
* Új: ez a kiadásjegyzék (`readme.txt`), hogy a plugin oldalán is látszódjon, mi változott.

= 2.14.26 =
* Új: a főoldali kiemelt kép mobil nézete — külön, csak mobilra érvényes CSS (16:9), a plugin verziójával töltve (cache-busting).

= 2.14.25 =
* Javítva: a befejezett hír-kör **lezárja** a cikk könyvelését (kész jelölő, a feljegyzett haladás törlése) — e nélkül az ötperces ör **ötpercenként újraindította** a maradékot (ismétlődő push).
* Javítva: a hír a **saját** feladatának haladását jegyzi fel (nem a globális „aktív” mutatóét); két egyidejű körnél ez korábban a másik kör offsetjét írta be.
* Új: `news_resume=` diagnosztika (hány folytatás indult az elmúlt órában).

= 2.14.24 =
* Javítva: a küldési lánc **minden** széles körre (esemény, kézi/admin, `@mindenki` chat, hír) végigmegy, akkor is, ha a folytatás cron-eseménye elveszik.
* Új: lánc-jegyzék (`huhs_push_chain_index`) — a biztonsági háló kérésenként legfeljebb két kört folytat, a régi egyhelyes mutató helyett.
* Javítva: átmeneti access token hiba esetén a feladat **nem tűnik el**, 60 másodperc múlva újrapróbálja (legfeljebb 20×), utána látható okkal zárul (`push_last=…/no-credentials`).
* Új: `push_jobs=` diagnosztika (hány kör van folyamatban).

= 2.14.23 =
* Javítva: a címzettek **determinisztikus sorrendben** mennek (a token-tár sorrendje változhatott, ezért ugyanaz a token két szeletbe esett → dupla push).

= 2.14.22 =
* Javítva: a „van-e folyamatban lévő küldés” kérdésre a **feladat-tár** a válasz (az aktív hely csak gyors út) — két széles kör többé nem tolja ki egymást.

= 2.14.21 =
* Új: a félbeszakadt hír-küldés **folytatása** a feljegyzett haladástól (a nulláról indítás dupla értesítést okozott volna).

= 2.14.20 =
* Javítva: a hír jelölője a **legelső** hívásnál íródik be (korábban a küldés után, ezért újrapróbánál/örnél a cikk többször is kimehetett).

= 2.14.19 =
* Új: `@mindenki` chat-push **széles** küldése nyelvenkénti szöveggel (`chat_everyone`), a `chat` kapcsoló tiszteletben tartásával.
* Új: kézi/admin push nyelvenkénti szövegekkel (`texts`).
