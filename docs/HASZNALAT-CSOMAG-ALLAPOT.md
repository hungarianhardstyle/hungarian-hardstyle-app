# Használat-növelő csomag — ÁLLAPOT (mért, 2026-09-28)

Ez a lap a **négy kiválasztott irány** állását rögzíti, a mért bizonyítékokkal és
a hátralévő munkával. Minden állítás mérésből származik (a parancsot is odaírtam).

## A mért kiindulás (ezért ezek az irányok)

| Mit | Mennyi | Honnan |
|---|---|---|
| Push-ra regisztrált **eszköz** | **1016** (hu 1015 + en 1) | `node tmp/probe-digest-live.mjs` (száraz kör) |
| **Közösségi profil** | **45** | `node tmp/probe-birth-date-notice-reach.mjs` |

Vagyis a felhasználók ~4,5%-a lép be a közösségi rétegbe — minden személyes
funkció (kedvencek, pontok, követés) ezen a szűk rétegen keresztül ér el.

## 1. Push-célzás a regisztráltakon túl — ✅ ÉL

- **Plugin 2.14.8/2.14.9** + **Cloud Function**: a heti összefoglaló szövege a
  szerveren készül, a **küldést a WordPress** végzi (ott van a token-tár), ezért
  **45 helyett 1016 eszköz** érhető el; a bejövő értesítés változatlanul
  létrejön a regisztráltaknak, és van **tartalék-út**, ha a plugin-végpont nem
  elérhető.
- **Kedvenc-alapú célzás:** a `/push/preferences` tárolja a követett
  DJ-k/szervezők azonosítóit, a tartalom-push átadja a szereplőket (mért
  meta-kulcsok: `artists`, `organizer_id`), és a szűrő **csak akkor szűkít, ha a
  rekordban van kedvenc** — aki nem küld kedvenceket, azt semmi nem érinti.
- **Éles bizonyíték:** a végpont hitelesítés nélkül **401** (védett), admin
  jelszóval **200**, elérés **1016 eszköz**; a hibaág (404) is mért volt a
  feltöltés előtt.
- **Hátra:** a kliens a **381-es buildben** küldi majd a kedvenceket — addig a
  személyes célzás „fegyverben van", de nem sül el.

## 2. Onboarding 3 lépésben — 🔵 DÖNTÉS KÉSZ, felület hátra

- `lib/services/onboarding_state.dart`: (1) bemutatás → (2) kedvenc DJ(k) →
  (3) értesítési engedély; **egyszer** fut, **átugorható**, **mélylinkről nyitva
  nem jelenik meg** (a tartalom az első), és nem írja felül a meglévő
  döntéseket. Teszt: `test/services/onboarding_state_test.dart` **6/6**.
- **Hátra:** a 3 lépés **felülete** (a `FavoriteButton`/DJ-lista és a
  `NotificationPermissionGate` már megvan hozzá), és a bekötés az indulásba.

## 3. Appon belüli link-megnyitás — 🔵 3/4 KÉSZ

1. **Manifest:** az app fogja az `/invite`, `/events`, `/releases`, `/djs`
   útvonalakat (`autoVerify` marad) — `AndroidManifest.xml`.
2. **Értelmező:** `lib/services/content_link_route.dart` a **mért**
   permalink-alakokra (esemény, kiadvány, DJ, dátum-alapú **hír**, meghívó,
   `?p={id}`); idegen domain/séma → főoldal. Teszt **8/8**.
3. **Feloldó:** `lib/services/content_link_resolver.dart` + a plugin
   **2.14.10** `GET /huhs/v1/resolve` végpontja (slug **vagy** azonosító →
   típus + azonosító; csak publikált tartalom; hibára 404). Teszt **6/6**,
   Docker-harness **72/72**.
- **Hátra:** a feloldó **bekötése** a navigációba (a meglévő `AppLinks`
  figyelő már kezeli az `/invite`-ot — ezt kell kiterjeszteni).

## 4. Esemény-oldali QR — 🔵 TELEPÍTÉSI ÚT KÉSZ

- `tools/make-qr-links.mjs`: kiírja a QR-be másolandó címeket (Play-link
  `referrer=qr` kampány-paraméterrel, weboldal, konkrét esemény `?p={id}`), és
  **minden címet ellenőriz** — mérve **3/3 él** (HTTP 200).
- **Hátra:** a QR **beolvasása az appban** → jelenlét + pont a meglévő
  `event_attendance`/pontrendszerrel (381-es kör).

## Kapuk (utolsó mért értékek)

| Kapu | Érték |
|---|---|
| `flutter analyze lib test` | No issues found! |
| `flutter test` | **1313/1313** |
| `node tools/run-function-tests.mjs --pure` | **382/382** |
| Docker plugin-harness (2.14.10) | 49 lintelt fájl, **117/117**, **117/117**, **72/72**, push-lánc **12/12**, mind az 5 jelző |
| Mutációs bizonyítékok | 6/6 (379–380), 3/3 (log-szint), 3/3 (digest fan-out), 2/2 (IPA-merő) |

## A tulajdonos lépései

1. **`build/huhs-mobile-api-2.14.10.zip`** feltöltése (minden eddigi plugin-javítás egyben).
2. A **380** kivitele a zárt tesztből a **nyílt/éles** sávra (mért állapot: production 377, zárt teszt 380).
3. Az áruházi szövegek bemásolása (`docs/PLAY-ARUHAZ-LISTA-SZOVEGEK.md`).

## Ami még hátra van (egy buildben: 381)

Onboarding felület + a link-feloldó bekötése + a kedvencek átküldése a
`/push/preferences`-be + a QR-beolvasás az appban → utána AAB, ellenőrzés,
Play-jegyzet és iOS-ellenőrzés.
