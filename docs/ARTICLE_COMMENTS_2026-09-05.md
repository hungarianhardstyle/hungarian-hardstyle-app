# Natív cikkhozzászólások

- Minden NewsDetailScreen, régi és új cikk esetén, a WordPress postId alapján külön hozzászóláslistát jelenít meg.
- Tárolás: article_comments/{postId}/comments/{commentId}. Kliens közvetlenül nem írja: az articleComments callable végzi az olvasást, küldést, törlést és jelentést.
- Vendég küldésnél a meglévő anonim Firebase munkamenet használható; Unknown User + UID-ból képzett négyszámjegyű azonosító. Regisztrált szerző neve/képe a szerveres profilból érkezik.
- Legfeljebb 2000 karakter, percenként legfeljebb 5 új küldési kísérlet, idempotens kliensazonosító, tiltásellenőrzés, cikk létezésének ellenőrzése.
- Saját komment törölhető, admin/moderátor minden kommentet törölhet a cikk alatt. Jelentés a meglévő chat_reports adminlistába kerül articleId és type mezővel.
- 20 komment oldalanként, újabbak elöl; kézi frissítés és újrapróbálás. A Disqus-adatok külön maradnak.
- A kommentben tárolt név/kép pillanatfelvétel, későbbi profilváltozás nem írja át. A frontend a meglévő chat káromkodásszűrőjét használja.
- Ellenőrzés: 4 izolált backendteszt (identitás, cikkelválasztás, idempotencia, jogosultság, tiltás, validáció, gyakoriságkorlát), 53 Flutter-teszt, flutter analyze és node --check. Telefonos vizuális és bejelentkezési ellenőrzés külön szükséges.
- A helyi kiadási verzió változatlanul 1.0.0+253. Play-feltöltés nem része ennek a változtatásnak.
