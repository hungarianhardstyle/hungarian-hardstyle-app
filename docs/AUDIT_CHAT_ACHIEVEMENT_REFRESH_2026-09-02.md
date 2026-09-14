# Chat achievement-jelvény/rang frissítés – audit

**Dátum:** 2026-09-02  
**Hatókör:** `LiveFeed` profilfrissítési generation/Timer, `_PostAuthorLabels` `forceRefresh` és Future/cache-kezelése, valamint a `CommunityService.refreshMyAchievementBadge()` utáni UID-cache-invalidálás.

Az audit során kódot nem módosítottam; buildet és deployt nem futtattam.

## Összegzés

Friss, hideg betöltéskor a rang/jelvény meg tud jelenni, de a jelenleg látható LiveFeed-sorokban a `refreshMyAchievementBadge()` önmagában nem garantálja az azonnali frissülést. Emellett a `forceRefresh` párhuzamos, nem deduplikált kéréseket indíthat, és a már futó régi Future invalidálás után is visszaírhatja a stale eredményt a cache-be.

## Bizonyított hiba

### 1. Az UID-cache törlése nem frissíti a már felépült chat-sort

`refreshMyAchievementBadge()` a sikeres callable után csak a célzott UID profil- és achievement-cache-ét törli: [`community_service.dart:942–952`](../lib/services/community_service.dart#L942).

A LiveFeed `_profileRefreshGeneration` értéke csak auth-változáskor, a kétperces Timerből vagy kézi chat-frissítéskor változik: [`community_screen.dart:662–690`](../lib/screens/community/community_screen.dart#L662).

Az `_PostAuthorLabels` csak a post szerzőjének változásakor vagy generation-változáskor tölti újra a profilt: [`community_screen.dart:1393–1402`](../lib/screens/community/community_screen.dart#L1393). Ezért egy már látható sor régi `_profileFuture` eredményt tarthat meg a következő Timerig, kézi frissítésig vagy auth-eseményig.

### 2. A `forceRefresh` megkerüli az in-flight request deduplikációt

A `getPublicProfile()` csak `forceRefresh == false` esetén használja a meglévő requestet: [`community_service.dart:976–999`](../lib/services/community_service.dart#L976).

Generation-frissítéskor minden látható `_PostAuthorLabels` külön `forceRefresh` kérést indít: [`community_screen.dart:1397–1419`](../lib/screens/community/community_screen.dart#L1397). Több azonos szerzőjű bejegyzés ezért több párhuzamos callable-hívást eredményezhet.

### 3. Régi Future invalidálás után is visszaírhat a cache-be

Az invalidálás eltávolítja a UID request-map bejegyzését: [`community_service.dart:1071–1085`](../lib/services/community_service.dart#L1071). A már elindult profil-Future azonban a válasz megérkezésekor feltétel nélkül beír a cache-be: [`community_service.dart:988–991`](../lib/services/community_service.dart#L988).

Ugyanez az achievement-cache esetén is fennáll: [`community_service.dart:1107–1114`](../lib/services/community_service.dart#L1107), miközben az in-flight Future törlése itt sem akadályozza meg a későbbi stale visszaírást.

## Kockázat

- A per-UID cache-kulcs konzisztens: a lekérés és az invalidálás is trimelt UID-t használ. Viszont az összesített `_publicProfilesCache` külön cache, amelyet a célzott UID-invalidálás nem töröl: [`community_service.dart:1017–1022`](../lib/services/community_service.dart#L1017), [`community_service.dart:1071–1085`](../lib/services/community_service.dart#L1071).
- A profilfrissítés hibája el van nyelve: [`community_screen.dart:1717–1720`](../lib/screens/community/community_screen.dart#L1717). Callable- vagy hálózati hiba esetén nincs retry vagy felhasználói jelzés, ezért a régi rang maradhat látható.
- Hiányos profil-achievement-adat esetén a fallback callable hibája `AchievementSummary.empty` értékkel felülírhatja a profilból olvasható részleges rangot: [`community_screen.dart:1452–1474`](../lib/screens/community/community_screen.dart#L1452).

## Megjelenési ellenőrzés

Sikeres friss kérés esetén a backend a publikus profilválaszba beleteszi az achievement-pontot és a jelvényt: [`functions/index.js:441–449`](../functions/index.js#L441). A chat ezt a profilválaszból feldolgozza és megjeleníti: [`community_screen.dart:1445–1474`](../lib/screens/community/community_screen.dart#L1445).

**Verdict:** az új rang/jelvény hideg betöltéskor vagy explicit LiveFeed-refresh után megjelenhet, de a `refreshMyAchievementBadge()` után azonnali, determinisztikus megjelenés jelenleg nem bizonyított és a fenti első hiba miatt nem garantált.

## Tesztlefedettség

- [`test/services/community_service_test.dart:5–38`](../test/services/community_service_test.dart#L5) csak profanity- és Cloudinary-URL-transzformációt tesztel.
- [`test/models/achievement_test.dart`](../test/models/achievement_test.dart) a parser működését fedi le.
- Nincs teszt cache-invalidálásra, párhuzamos Future-ökre, stale response-ra, LiveFeed generation-frissítésre vagy widgetben történő új jelvénymegjelenítésre.

## Javaslat

1. UID-nként egyetlen megosztott refresh-Future legyen; a `forceRefresh` ne indítson új kérést, ha ugyanarra az UID-re már fut frissítés.
2. Kerüljön invalidációs epoch/token a cache-be; csak az aktuális epochhoz tartozó Future írhasson vissza.
3. A `refreshMyAchievementBadge()` után legyen megfigyelhető refresh-jelzés, amely a LiveFeed generationjét is növeli.
4. Kerüljön be service- és widgetteszt az azonos UID-k deduplikációjára, az invalidálás utáni stale válasz elutasítására és az új jelvény tényleges chat-megjelenésére.
