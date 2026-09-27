# Hungarian Hardstyle App

The official cross-platform application of **Hungarian Hardstyle** — one hub for the Hungarian harder styles scene: news, events, DJs and organizers, community chat, the Hardstyle Revolution label catalog, games and yearly voting.

**Live:** [Google Play](https://play.google.com/store/apps/details?id=hu.hungarianhardstyle.app) · [hungarianhardstyle.hu](https://hungarianhardstyle.hu) · [Privacy policy](https://hungarianhardstyle.hu/adatvedelmi-nyilatkozat/) · [Account deletion](https://hungarianhardstyle.hu/fiok-torles/) · [Child safety](https://hungarianhardstyle.hu/gyermekbiztonsag/)

WordPress stays the editorial source of truth. The Flutter app reads the public REST API of the companion **HUHS Mobile API** WordPress plugin (**2.14.5**) for news, events, DJs, organizers, releases, FAQ, polls and games, while Firebase provides authentication, community data, push notifications and every server-side decision.

## Current status

| Area | State |
| --- | --- |
| App version | **1.0.0+377** (`versionCode 377`) — Android via the Play production track; iOS built unsigned in CI and installed by sideload for testing |
| WordPress plugin | **2.14.5** |
| Cloud Functions | **81 deployed** — 53 callable, 12 scheduled, 15 Firestore triggers (23 in `europe-central2`, 58 legacy in `us-central1`) |
| Localization | Hungarian + English, **1450** dictionary keys, language follows the device and can be switched in-app; **42** notification kinds in both languages |
| Test suite | **1220** Flutter tests, **349** pure Cloud Functions tests, **9** emulator suites (including Firestore-rules tests) |

### Shipped

- dark Material 3 Flutter UI (Riverpod + Dio) with a persistent navigation shell and per-tab history: **Home, News, Events, Chat, Label, More**
- API-backed news list, search, category/tag filtering and detail views with galleries, embeds and in-app link handling
- dynamic events with flyers, ticket links, Maps, meetups and related DJ/organizer profiles
- searchable DJ and organizer directories with full profiles, and e-mail-verified artist profile claiming
- moderated event, DJ and organizer submissions with Cloudinary uploads and a WordPress approval workflow
- app-only registration (e-mail/password and Google), profiles, favorites, private messages, reporting and blocking
- Live Feed with images, emoji reactions, `@` mentions and a `@mindenki` fan-out that writes in-app notifications and sends push
- achievements, points, levels, badges, leaderboard and a referral program
- games, polls, prize draws and yearly voting with published results
- Hardstyle Revolution label catalog with previews, free downloads, Google Play Billing purchases and an offline "my music" library
- online radio (Real Hardstyle FM) with a native Android foreground service, an iOS stream player and a persistent player bar in the navigation shell
- Mailchimp newsletter signup (through the WordPress API) and consent-gated AdMob monetization of free downloads
- Firebase Cloud Messaging push for news, events, chat, achievements, moderation and birthdays, with per-user notification preferences
- child-safety layer: 16+ registration gate, birth date (required at registration, hidden by default), warning banner when a minor talks to an adult, private-chat reporting and a server-side private-message flagging system

### How changes are verified

Every round ships with measured evidence rather than assumptions:

- `flutter analyze lib test` → clean
- `flutter test` → **1220/1220**
- `node tools/run-function-tests.mjs` → **349/349** pure + **9/9** emulator suites
- `node tools/check-i18n.mjs --strict` → every extracted Hungarian UI string has an English entry
- `node tools/check-adjacent-literals.mjs` → multi-line concatenated literals must exist as dictionary keys
- `node tools/check-play-notes.mjs` → release notes fit the Play character limits
- `node tmp/verify-aab.mjs <aab> <versionCode>` → dictionary keys, notification catalog and every changelog line present in all three ABIs
- mutation proofs (`tmp/mutation-proof-*.mjs`) → each new gate is shown to actually catch the defect it exists for, and the restored tree has to go green again

## Architecture

| Layer | Technology |
| --- | --- |
| Client | Flutter 3.47 / Dart 3.13, Riverpod, Dio, Material 3 dark theme, `just_audio` + `audio_service` |
| Editorial content | WordPress + HUHS Mobile API plugin (REST), Cloudinary for user-uploaded images |
| Identity & community | Firebase Authentication, Cloud Firestore (named database `hungarian-hardstyle`), App Check |
| Server logic | Cloud Functions for Node.js 22 (`europe-central2` for data-handling functions), Firestore security rules, scheduled jobs |
| Messaging | Firebase Cloud Messaging push + in-app notification center |
| Monetization | Google Play Billing (label releases), AdMob (banner/rewarded, consent-gated), PayPal donations |
| Localization | JSON string dictionary (`assets/i18n/en.json`), generated notification catalog shared with the server |

Server-side decisions live in small pure modules (`functions/*-plan.js`) that are unit-tested without the emulator — birth-date reminders, birthday greetings, child-safety flagging, mention fan-out, Play product listings, push de-duplication. Firestore security rules deny client writes for moderation records, and every privileged action re-checks the caller's role on the server.

## Repository layout

| Path | Contents |
| --- | --- |
| `lib/` | Flutter application (screens, widgets, services, models, i18n runtime) |
| `assets/` | Images and fonts, plus the Hungarian/English i18n dictionaries |
| `functions/` | Cloud Functions, pure decision modules and their Node test suites |
| `test/` | Flutter unit, widget and source-lint tests |
| `android/`, `ios/` | Platform projects (release signing, ProGuard rules, CI-buildable iOS target) |
| `tools/` | Verification, measurement and release tooling (`check-*`, `verify-*`, `optimize-*`) |
| `tmp/` | Round-specific probes, AAB/IPA verifiers and mutation proofs, kept as evidence |
| `docs/` | Release journal, Play Console guide, iOS CI notes, moderation proposal, i18n glossary |
| `hosting/`, `firebase.json`, `firestore.rules` | Firebase Hosting and security rules |
| `wordpress-release-catalog/` | Small companion WordPress plugin |

`AGENTS.md` is the internal delivery log: it records, per round, what the owner reported, the measured root cause, what was built, the evidence and the honest limits. The user-facing changelog lives in `lib/data/app_changelog.dart`, and the Play-ready Hungarian release notes in `docs/PLAY-KIADASI-JEGYZET.md`.

## Build and release

Android release build (no secret is stored in the repository; ad identifiers and keys are passed in at build time):

```powershell
flutter build appbundle --release `
  -P "HUHS_ADMOB_APP_ID=ca-app-pub-…" `
  -P "HUHS_ADMOB_BANNER_ID=ca-app-pub-…/…" `
  -P "HUHS_ADMOB_REWARDED_ID=ca-app-pub-…/…"
```

iOS is currently verified through the `iOS fordítás-ellenőrzés` GitHub Actions workflow (`.github/workflows/ios-unsigned-check.yml`), which produces the unsigned IPA artifact used for sideload testing; TestFlight distribution is documented in `docs/IOS-CI-TESTFLIGHT.md`.

Server deployment:

```powershell
firebase deploy --only functions,firestore:rules --project hungarian-hardstyle
node tools/check-function-errors.mjs --hours 1
```

Every released build gets a **new versionCode**; an already published build is never rebuilt or re-announced. The repository always carries the next build, so the versionCode live on Play is the last one uploaded there. The current release journal entry (`docs/PLAY-KIADASI-JEGYZET.md`) holds the exact AAB name, size, SHA-256 and the release-note blocks that go into the Play Console.

## Documentation

| Document | Purpose |
| --- | --- |
| `docs/PLAY-KIADASI-JEGYZET.md` | Release journal: current build, AAB hash, ready-to-paste Play notes |
| `docs/PLAY-CONSOLE-UTMUTATO.md` | Step-by-step Play Console guide (tracks, data safety, declarations) |
| `docs/PLAY-PRODUCTION-BEADAS.md` | Production submission checklist |
| `docs/IOS-CI-TESTFLIGHT.md` | iOS CI build and TestFlight distribution |
| `docs/GYERMEKBIZTONSAG-MODERACIO-JAVASLAT.md` | Child-safety and moderation design (phased) |
| `docs/I18N-GLOSSARY.md` | Hungarian → English terminology used by the app |
| `docs/RELEASEHARDSTYLE-BEILLESZTES-TERV.md` | Planned native integration of releasehardstyle.nl |
| `AGENTS.md` | Round-by-round delivery log with measured evidence |

## Roadmap

### v1.0 — remaining

- [ ] online radio backend: server-side AutoDJ for a managed track library, AzuraCast (Liquidsoap + Icecast) preferred, bulk SFTP upload, S3-compatible or Dropbox storage instead of a custom Google Drive sync
- [ ] decide licensing, hosting, bandwidth, codec/bitrate and interruption/notification behaviour for the radio
- [ ] move the online-radio player under the Home logo (it currently ships as a persistent player bar in the navigation shell)
- [ ] refine the Android startup animation to use the full HUHS logo on a transparent/no-white background
- [x] dedicated `Kiadások` / Label destination and the Hardstyle Revolution release catalog
- [x] release preview playback (radio-aware: previewing stops the stream and resumes it afterwards)
- [x] Hungarian/English UI localization with reviewed English WordPress content served by locale-aware APIs
- [x] WordPress-managed FAQ under More with search and expandable answers
- [x] `Támogatás / Donate` card under More with a PayPal link (app first, browser fallback)
- [x] background playback and audio-focus handling
- [x] persistent navigation shell with per-tab history, and the Live Feed as a primary destination
- [ ] after v1.0, revisit the Websupport WAF and decide whether direct WordPress multipart uploads are worth restoring alongside Cloudinary
- [ ] upgrade Gradle, Android Gradle Plugin and Kotlin before current Flutter support is dropped

### Community and moderation — next phases

- [x] app-only accounts, roles chosen at onboarding (DJ, organizer, partygoer) and role-gated submission forms (one shared `SubmissionRules` on client and server)
- [x] user profiles with avatar, bio, social links and favorites
- [x] connection ("ismerős") requests with an `Ismerősök` section, accepted or declined in the app
- [x] event attendance (`Ott leszek` / `Nem leszek ott`), friend attendance visibility, meetup chat and post-event rating requests
- [x] global publication pushes for new events to every device with an FCM token
- [ ] per-user event targeting: pushes only to users who favorited an event or marked `Ott leszek`, plus notifications for an organizer's new events
- [ ] show planned events on the profile (currently a placeholder pointing at the attendance feature)
- [x] reporting, blocking, privacy controls and account deletion (in-app and a signed-out web path)
- [x] phase 1 child-safety flagging on private messages, human-reviewed, with no automatic ban or deletion
- [ ] phase 2: reporting/queue tooling for moderators, retention rules and metrics
- [ ] phase 3: external hash-based media detection for CSAM (requires a third-party service)
- [ ] authenticated admin backend so admins can review, approve and edit submissions without the WordPress dashboard
- [ ] annual voting administration: WordPress-managed seasons and candidates with one-user/one-vote enforcement
- [ ] claim a DJ profile only after verifying the private or artist-owned booking e-mail (the Hungarian Hardstyle-managed address never qualifies)

### v1.5 — Hardstyle Revolution Store

- [ ] free MP3 releases without payment or advertising
- [ ] rewarded-ad 128 kbps MP3 downloads for premium releases
- [ ] paid 320 kbps MP3 downloads and paid WAV/lossless downloads
- [ ] process paid digital downloads through Google Play Billing (not direct Google Pay checkout)
- [ ] upload one WAV master and generate 128 kbps MP3, 320 kbps MP3 and preview derivatives server-side with FFmpeg in a background job, keeping the WAV master private
- [x] verify Websupport FFmpeg support (`/usr/bin/ffmpeg` 4.4.2 with `libmp3lame`)
- [ ] optional purchase and download history

Releases and Store share one WordPress-managed catalog rather than separate content systems.

## Navigation direction

- Home and News remain the first two primary destinations.
- The unused Tickets tab was removed; its primary-tab slot went to the Live Feed/chat destination.
- The public WordPress `/events/` directory should later include an `Esemény beküldése` call-to-action, gated by authentication.
- Events are a strong primary-tab candidate because they provide immediate utility; DJs and organizers live under More.
- Detail screens open inside one persistent navigation shell instead of duplicating the bottom bar.

## Language direction

- The Flutter interface supports Hungarian and English; Hungarian literals are the dictionary keys, so a missing translation is visible immediately.
- AI-assisted English article versions are created and reviewed in the standard WordPress post editor; new content is translated automatically about a minute after publication, with an hourly sweep for older content.
- The mobile REST APIs serve the stored language requested by Flutter, with Hungarian fallback, rather than translating on demand.
- User-generated content — chat messages, post text, profile names — is intentionally **not** translated.

## Brands

- **Hungarian Hardstyle** — main community platform
- **Hardstyle Revolution** — record label and event series
- **Rave Revolution** — multi-genre hard dance event series
- **Hard Lake** — free summer event concept around Lake Velence

## Long-term vision

One connected platform for Android, iOS and the web, combining news, events, artists, organizers, community, radio, releases and digital music distribution.

## Contact

Questions, feedback and partnership requests: [hungarianhardstyle.hu](https://hungarianhardstyle.hu), or the social links inside the app under More → *Social és kapcsolat* (social and contact).
