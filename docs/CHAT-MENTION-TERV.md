# Chat-@hivatkozás (mention) — megvalósíthatóság és terv

> **Ez a dokumentum a tulajdonos kérdésére ad választ:** *„Kéne olyan, hogy egy @xy betűvel tudjak
> hivatkozni a chaten cikkre, djre, szervezőre, eseményre, kiadványra vagy személyre/userre, ha
> személyre hivatkozok kapjon róla notifyt és nyissa meg a chaten neki azt az üzenetet és azt is
> jelezze hogy ki hivatkozott rá. Elkezdem irni a betűket és dobja fel a lehetőségeket. A
> személyre/userre hivatkozás legyen elérhető mindenkinek, többi csak admin/moderátornak.
> Természetesen mindegyik kattintható legyen és a megfelelő helyre vigyen."*
>
> **A válasz: MEGVALÓSÍTHATÓ** — a hat célpont közül **mind a hat** elérhető már az appban, és a
> koppintás útvonala **már létezik** (az értesítés-központban). Az alábbi terv a mért állapotra épül.

## 1. Ami MÁR megvan (mérve a kódból, 2026-09-24)

| Kell | Mi van ma | Hol |
|---|---|---|
| Chat-üzenet tárolása | `live_feed_posts/{postId}` — `authorId`, `authorName`, `authorRole`, `authorAccessRole`, `text`, `replyTo*`, `imageUrl`, `reactions`, `createdAt` | `functions/index.js` `publishChatPost` |
| Üzenetküldés útja | **callable** (`publishChatPost`) — a szerver validál és ír | `lib/services/community_service.dart` |
| Szerepkör-modell | `accessRole ∈ {admin, moderator, none}` (normalizálva) | `normalizedAccessRole()` |
| **Személy** célpont | `CommunityPublicProfileScreen(userId)` | `notification_center_screen.dart` `targetType == 'profile'` |
| **Cikk** célpont | `NewsDetailScreen(post)` (`WordpressService.getPost(id)`) | ugyanott, `targetType == 'article'` |
| **DJ** célpont | `ArtistDetailScreen` | ugyanott, `targetType == 'artist'` |
| **Szervező** célpont | szervező-adatlap | ugyanott, `targetType == 'organizer'` |
| **Esemény** célpont | `EventDetailScreen` | ugyanott, `targetType == 'event'` |
| **Kiadvány** célpont | kiadvány-adatlap | ugyanott, `targetType == 'release'` |
| Személy-keresés | `getRegisteredPublicProfiles()` **élő lista**, kliens-oldali név-szűrés | `community_users_screen.dart` |
| Cikk/DJ/szervező/esemény/kiadvány lista | `getPosts()`, `getArtists()`, `getOrganizers()`, `getEvents()`, `getReleases()` — **mentett (cache-elt)** WP-listák | `lib/services/wordpress_service.dart` |
| Értesítés írása | `createNotificationBestEffort({type, title, body, targetType, targetId, dedupeKey, senderId})` | `functions/index.js` |
| **A megjelölt üzenet megnyitása** | `targetType: 'chat'` + `targetId` → a Chat **arra az üzenetre görget és kiemeli** (AAB **357**) | `chat_focus_plan.dart`, `LiveFeedScreen(focusPostId:)` |
| **Ki hivatkozott rá** | a szerver több forrásból oldja fel a cselekvő nevét (AAB **357** + functions) | `actor-name-plan.js`, `resolveActorName()` |

**Ebből következik:** a tulajdonos kérése **négy részből** áll, és ebből **kettő már készen van**:
a „ki hivatkozott rá" és a „nyissa meg azt az üzenetet". A hiányzó kettő: **(a)** az `@` beírása közbeni
javaslatlista, és **(b)** maga a hivatkozás (tárolás + kattintható megjelenítés + értesítés).

## 2. Javaslat — szintaxis és felület

- **Egyetlen `@` mindenre** (ahogy a tulajdonos kérte). A javaslatlista **típus szerint csoportosítva**:
  **Személyek** (mindenkinek) → **Cikkek / DJ-k / Szervezők / Események / Kiadványok** (csak
  adminnak/moderátornak). Az `@` után **1 karaktertől** szűrünk; üresen a legutóbbi/top találatok.
- **A kiválasztás beírja a szövegbe** a nevet (`@Kobakologia`), és a szervernek átadja a **strukturált**
  hivatkozást is. Így a szöveg olvasható marad (régi appon is), a kattintás viszont **nem szöveg-parse**,
  hanem adat alapján megy.
- **Megjelenítés:** `Text.rich` — a hivatkozások **kiemelt színnel + aláhúzással**, koppintásra a
  megfelelő képernyő. (Ma a chat szövege egyszerű `Text(post.text)`.)
- **Értesítés (személy-hivatkozásnál):** cím `„Megemlítettek a Chatben"`, szöveg
  `„{ki} megemlített a Chatben: »{az üzenet első ~80 karaktere}«"`, `targetType: 'chat'`,
  `targetId: <postId>` — vagyis **a koppintás a 357 óta pontosan arra az üzenetre visz**.

## 3. Adatmodell (a meglévő séma bővítése)

```jsonc
// live_feed_posts/{postId}
{
  "text": "Nézd meg @Kobakologia, ez a @Hard Base Classic is jó lesz!",
  "mentions": [
    { "type": "user",     "id": "<uid>",  "label": "Kobakologia" },
    { "type": "event",    "id": "12505",  "label": "Hard Base Classic" }
  ]
}
```

- `type ∈ {user, article, artist, organizer, event, release}`, `id` **string** (WordPress-azonosító
  számként, Firestore-uid), `label` a **pillanatnyi név** (átnevezésnél a szöveg nem hazudik: a régi
  üzenet a régi nevet mutatja, a hivatkozás viszont az **id** alapján a helyére visz).
- **Korlátok (javaslat):** összesen **max. 10** hivatkozás; ebből **max. 5 személy** kap értesítést
  (a spam ellen); `label` ≤ 80 karakter; a `text` marad ≤ 2000.
- **Firestore-szabály:** a `live_feed_posts` create-whitelistbe be kell venni a `mentions` mezőt a
  shape-ellenőrzéssel (a mostani szabály `keys().hasOnly([...])`, ezért **kötelező** a bővítés), és a
  `functions/rules.test.cjs`-be új esetek.

## 4. Jogosultság — szerveroldalon kényszerítve

- **Személy:** mindenki hivatkozhat rá (a tulajdonos kérése).
- **Tartalom (cikk/DJ/szervező/esemény/kiadvány):** csak `accessRole ∈ {admin, moderator}`.
  ⚠️ A kliens-oldali szűrés **csak UX** — a **szerver** a hiteles: a `publishChatPost` a nem
  jogosult tartalom-hivatkozásokat **kihagyja** a `mentions` tömbből (a szöveg marad), és visszaadja,
  hányat hagyott ki; az app ezt egy rövid üzenetben jelzi.
- **Önmagát** megemlíteni szabad, de **nem** kap értesítést (mint a saját lájknál).
- **Duplikátum:** ugyanaz a személy ugyanabban az üzenetben **egyszer** kap értesítést
  (`dedupeKey: chat-mention:{postId}:{uid}` — a meglévő minta).

## 5. Értesítés és a „ki hivatkozott rá"

A `publishChatPost` a mentés után, **best-effort** módon (a meglévő `createNotificationBestEffort`):

| mező | érték |
|---|---|
| `type` | `chat_mention` |
| `recipientUid` | a megemlített felhasználó |
| `title` | `Megemlítettek a Chatben` |
| `body` | `{szerző neve} megemlített a Chatben: „{részlet}”` |
| `targetType` / `targetId` | `chat` / `<postId>` |
| `senderId` | a szerző uid-ja |
| `dedupeKey` | `chat-mention:{postId}:{uid}` |

A **szerző nevét** a 357-es körben bevezetett `resolveActorName()` adja (közösségi profil → nyilvános
profil → Auth-név), ezért itt nem lesz „Egy HUHS tag".

## 6. Javasolt bontás (két kör)

**1. kör — SZEMÉLY-hivatkozás (a tulajdonos fő kérése), egy csomagban:**
1. `mentions` a sémában + szerver-validálás (típus, hossz, darabszám) + Firestore-szabály + teszt;
2. `@` javaslatlista a Chat beviteli mezőjében (személyek: a meglévő élő profil-lista szűrése);
3. kattintható megjelenítés (`Text.rich`) → `CommunityPublicProfileScreen`;
4. `chat_mention` értesítés + a **már meglévő** odaugrás (357) igénybevétele;
5. tiszta modulok + tesztek (javaslat-szűrés, hivatkozás-kiemelés, értesítés-döntés).

**2. kör — TARTALOM-hivatkozás (admin/moderátor):**
6. a javaslatlista tartalom-ágai (cikk/DJ/szervező/esemény/kiadvány) a **mentett** WP-listákból,
   név szerinti szűréssel — hálózat nélkül is működik, mert a listák cache-eltek;
7. a kattintás bekötése a meglévő képernyőkre (a célpont-ágak **már megvannak** az értesítés-központban
   — érdemes **közös** útvonal-feloldóba emelni, hogy a kettő ne tudjon széthúzni);
8. a szerveroldali jogosultság-szűrés + a visszajelzés a felületen.

**3. kör (opcionális, később):** hivatkozás a **cikk-kommentekben** és a **privát chatben** ugyanezzel
a motorral; a megemlített személy jelzése a profilján („hol említettek").

## 7. Nyitott döntések (a tulajdonosé)

1. **Szintaxis:** egy `@` mindenre (javaslat), vagy `@` a személyeknek és `#` a tartalomnak?
2. **Értesítés személy-hivatkozásnál:** minden megemlített kapjon (max. 5/üzenet), vagy csak az első?
3. **Nem jogosult tartalom-hivatkozás:** a szerver **kihagyja** (javaslat) vagy **elutasítja** az
   üzenetet hibával?
4. **Kattintás a személyre:** a nyilvános profil legyen (javaslat), vagy a privát beszélgetés indítása?
5. **Régi üzenetek:** a hivatkozás a **beírás kori nevet** mutassa (javaslat), vagy mindig a friss nevet
   (az `id` alapján)?
6. **Hol legyen először:** csak a Chatben (javaslat), vagy rögtön a cikk-kommentekben is?

## 8. Kockázatok és korlátok (őszintén)

- **Névütközés:** két azonos `displayName` — a hivatkozás az **uid**-hoz kötött, ezért a kattintás
  helyes; a *szöveg* viszont kétértelmű lehet (ez a `@név` szintaxis velejárója).
- **Törölt/eltűnt célpont:** a koppintás ilyenkor hibát kap — a felület ezt kezelje (üzenet, nem
  összeomlás). A hivatkozás nem „javítja" magát.
- **Spam:** a személy-hivatkozás értesítést küld, ezért kell a darabszám-korlát és a napi
  értesítés-plafon (a meglévő `allowCall` mintával).
- **Régi appok:** a `mentions` mezőt nem ismerik, de a szöveget látják (`@Név`) — nem törik el.
- **WP-azonosítók:** a tartalom-hivatkozások a WordPress-azonosítót tárolják; ha egy cikk/DJ törlődik a
  WP-ből, a hivatkozás a „nem található" ágra fut.
- **Amit ez a terv NEM tartalmaz:** hangulatjelek/jelölés-színek, „@mindenki" (broadcast), és a
  hivatkozás-alapú pontozás.

## 9. Becslés

| Rész | Munka |
|---|---|
| Séma + szerver-validálás + értesítés + szabály + tesztek | 1 kör (functions deploy) |
| `@` javaslatlista (személyek) + kattintható megjelenítés | 1 kör (AAB) |
| Tartalom-ágak (5 típus) + jogosultság + közös útvonal-feloldó | 1 kör (AAB) |

**Az 1. kör önmagában is teljes élményt ad** (személy-hivatkozás: javaslat, értesítés, odaugrás,
kattintható profil), és a szerveroldali rész **visszamenőlegesen is működik** a régi appokkal
(a szöveg ott is látszik).
