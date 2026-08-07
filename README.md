# Hungarian Hardstyle App

The official cross-platform application of **Hungarian Hardstyle**, built as a central hub for the Hungarian harder styles scene.

WordPress is the source of truth for editorial content. Flutter consumes the public REST API for news, events, DJs, organizers and the Label release catalog.

## Current status

### v0.99.3 — complete and closed (2026-07-30)

- Current Flutter build: `0.99.89+1`; v0.99.3 through v0.99.8 and v0.99.89 are closed. Older APK references are historical.
- Firestore rules and the named `hungarian-hardstyle` database `deleteCommunityUser` Function are deployed.
- Account roles remain independent from Admin/Moderátor access roles; the owner account is Organizer + Admin.
- Production release signing, obfuscation, and live AdMob verification remain release checks.
- WordPress submissions and native admin submission editing/approval/trash actions use server-side Firebase Functions: they verify Firebase Auth and access roles before forwarding to WordPress. No WordPress credential belongs in Flutter.
- Cloudinary uploads are client-guarded to JPG/JPEG/PNG/WebP and 5 MB. The unsigned `Hun_hs_Mobile` preset must use the same allowed formats, `huhs/community` folder, unique filenames, and overwrite disabled.
- Expired events are filtered from API results and the cached event list rechecks every minute.
- Firestore rules for role-bound Chat authorship are compiled and deployed to the hungarian-hardstyle database.
- The Real Hardstyle FM provider page includes the requested legal information.

### v0.99.1 implementation status

The Community MVP source implementation is complete on `codex/v1.0`: Firebase Authentication (email/password and Google), mandatory account roles, public Firestore Chat, anonymous text-only posting, registered Cloudinary image posts, profile entry/editing, fixed reactions, a five-item Home news slider with 10-second rotation, and native article-tag filtering. `firestore.rules`, `firebase.json` and `.firebaserc` are included for deployment. Physical ARM verification, Firebase rules deployment, and Google OAuth Console configuration remain external release checks.

The current delivery target is **v0.99.1 Community MVP**. The first MVP implementation is now in the Flutter source: Firebase Auth/Firestore Chat, anonymous text posting, registered image posting through Cloudinary, role-aware registration, profile entry, the five-news ten-second Home slider, and native article-tag filtering.

The v0.99.1 community bugfix pass is implemented in `v0.99.1+12`; e-mail/password registration and Google-account sign-in remain the required entry paths, with a mandatory account role.
The v0.99.1+11 authorization pass also resolves the previously reported Chat deletion, admin-role persistence, and in-app user-management issues. Manual profile focal-point editing remains optional polish.
v0.99.1+12 fixes the community profile/avatar synchronization, signed-in Chat image permission state, author monogram/avatar rendering, separate account/access roles, admin-only Chat deletion, admin user-role management for legacy profiles, Auth-restored profile loading, duplicate-role dropdown crash, logout navigation crash, and deploys the Firestore rules to the named `hungarian-hardstyle` database used by the app. Google sign-in remains a release-device/Firebase SHA verification check; manual focal-point editing is optional later UX polish.

- Separate Facebook, Instagram, TikTok, YouTube, and Spotify fields are implemented during registration and in the community profile.
- Next build follow-up: add a password-reset link to login and replace raw Firebase credential errors with a clear Hungarian message.
- Next build follow-up: add password visibility toggles and an optional strong-password generator during registration.
- Next build follow-up: refresh the Home top-left profile avatar immediately after sign-in without requiring manual refresh.
- Next build follow-up: add a dismissible/pinnable Chat notice, admin-created pinned messages, admin pin controls, and a configurable profanity filter that masks blocked words with asterisks.
- Next build follow-up: show an admin-managed startup announcement image with a close button; allow image upload/replacement from the app admin panel and the WordPress Mobile API.
Chat message deletion and the in-app role-management panel are implemented. The server-side `functions/deleteCommunityUser` Cloud Function performs real Auth/profile/Chat deletion and is deployed to Firebase. Artifact cleanup retains old function images for 90 days.
Push notification text also needs an encoding fix because HTML entities can appear literally in the notification body.
Community permissions are server-enforced: the owner keeps admin access, account roles are final for normal users, admins manage account/access roles and Chat messages, and moderators cannot edit or delete Chat messages.

The current WordPress backend package is **2.4.37**. `build/huhs-mobile-api-2.4.37.zip` is the same HUHS Mobile API with the Vezérlőközpont editor fix; the Label release catalog remains live. Uploaded MP3/WAV files are temporary sources only, converted from the 30th second to a maximum 60-second preview, then deleted. The API exposes preview audio only; full MP3 downloads are not part of the app.

### v0.99.2 — next test build

- [x] re-enable the Google AdMob test banner with `HUHS_ENABLE_TEST_ADS=true` (test build default)
- [ ] verify the test ad on the ARM debug APK without blocking startup
- [ ] keep production AdMob IDs and consent/privacy handling deferred until release
- [x] fix e-mail/password sign-in independently of the misleading raw Firebase credential error
- [x] fix saved profile-image rendering and Cloudinary upload persistence in source; physical phone verification remains with the project owner
- [x] fix admin user deletion and deploy the `deleteCommunityUser` Cloud Function
- [x] make the owner's `djdeeroy@gmail.com` account role persist as `Szervező` while retaining admin access
- [x] enforce final account roles server-side: users choose once at registration; only admins may change another user's role
- [x] always render the persisted account role on profiles and Chat; show `Admin` or `Moderátor` as a separate access badge next to the account role

 - [x] tag-filtered news uses API pagination/infinite scroll so all matching articles can be reached
 - [x] allow gallery images to be saved to the device with platform permission handling
 - [x] add an in-app Data protection / GDPR information section with privacy and retention details
 - [x] keep sensitive account, role, deletion and WordPress proxy operations server-side
 - [ ] complete production security hardening, obfuscation, abuse/rate-limit checks and release signing in v1.0
 - [x] complete the Real Hardstyle FM radio integration at `https://stream.realhardstyle.nl` in v0.99.2.1 with a custom compact red-black bar player and Play/Stop/Mute controls
 - [x] show the currently playing track title in the radio player when stream metadata provides it
 - [x] place the persistent radio player above the bottom navigation without covering event panels
 - [x] add a More-section radio provider page with Real Hardstyle FM name, website, logo, and provider attribution text
 - [x] adopt a readable modern/cyber-style font such as Rajdhani with complete Hungarian accented-character support (native condensed fallback)

### v0.99.3 implementation status — complete and closed (2026-07-30)

Implemented in source: the approved Rajdhani/TypeUI red-black visual system while retaining the original `assets/logos/huhs_logo.png` HUHS logo, Home slogan and branding; the Admin-only native HUHS Vezérlőközpont; Mobile API events, DJs, organizers, submissions, trash, settings, push, newsletter, shortcode, About and persistent startup-image management; the separate Firebase community-user administration; profile image/monogram fallback; radio Stop synchronization; tag/genre pagination, the fast-scroll fix and expired-event filtering. Generic WordPress news/page/media/comment/taxonomy/user menus are intentionally not duplicated in the mobile controller.

The Home header does not duplicate the bottom navigation with extra quick-action tiles. The radio uses the compact TypeUI red-black two-line bar with a dedicated Play/Stop control, station label, track metadata and Mute control.

v0.99.3 completion:

- [x] Fix the visible Hungarian character-encoding/mojibake errors on the community profile screen.
- [x] Remove the unnecessary `Beállítások`, `Hírlevél`, and `Shortcode` entries from the native HUHS Vezérlőközpont.
- [x] Make the circular profile-image editor persist and reproduce true horizontal and vertical positioning together with zoom.
- [x] Open the community profile in a read-only view and place editing behind a separate `Profil szerkesztése` action and screen.
- [x] Refresh the Real Hardstyle FM current-track metadata automatically while the radio is playing.
- [x] Reconnect the Real Hardstyle FM player automatically after an unexpected stream interruption.
- [x] Fix the push-settings screen lifecycle assertion (`_dependents.isEmpty`) without changing the already working push delivery.

The native admin refresh after saving the persistent startup image uses a synchronous `setState` callback, so a successful save is no longer reported as a Flutter error.
The same admin dialog can also disable and clear the configured startup image.

The Chat composer keeps the camera action, emoji helper, and signed-in status on one compact line above the Send button so none overlaps the message field.
Existing Chat messages resolve their author's current profile image, crop and zoom settings, so an avatar change updates earlier messages too.

Firebase WordPress proxy Functions are deployed. WordPress Mobile API `2.4.33` is live, deployed, and verified; it adds the managed FAQ post type/category editor and paginated public FAQ endpoint on top of the native admin/startup-image work. Do not treat this deployment as an open re-verification task.

v0.99.3 is complete, phone-verified, and closed in Flutter build `0.99.3+27`. Release signing/obfuscation and broader security remain v1.0.

### v0.99.4 — Small improvements (implemented)

Implemented in Flutter `0.99.4+3`:

- organize the existing `Több` entries without changing the menu name:
  - `Felfedezés`: DJ-k, Szervezők, Spotify Playlistek
  - `Közösség`: Kedvencek, Hírlevél; the v1.0 registered-user search will also belong here
  - `Beküldés`: role-gated event, DJ and organizer submissions
  - `Kapcsolat és támogatás`: Social és kapcsolat, Támogatás / Donate, Hibajelzés, GYIK / FAQ
  - `Alkalmazás`: Beállítások, Adatvédelem és GDPR, Az appról, Rádió szolgáltató
  - keep the HUHS Vezérlőközpont in the Admin profile; do not duplicate it in `Több`
- [x] add the `Támogatás / Donate` card with PayPal app/browser fallback
- [x] add a pre-addressed feedback e-mail action that includes the app version
- [x] add the WordPress-managed FAQ under More with categories, ordering, search, expandable answers, and loading/empty/error states (prepared API package 2.4.33)
- [x] persist favorites in the signed-in user's Firestore profile (with local cache and bulk deletion)
- [x] replace full social-media URLs on community profiles with compact, clickable Facebook, Instagram, TikTok, YouTube, and Spotify buttons
- [x] move the existing Home AdMob banner below both the latest-news and upcoming-events sections
- [x] add one clearly separated inline adaptive test AdMob banner to the native news list
- [x] fix Instagram post embeds in news so `instagram://` URLs are converted to supported web links before opening
- [x] compact the Home event cards while keeping every card the same height and preserving title, date/time, city, genres, favorite, and open actions
- [x] show a clear registered-user/role requirement in the `Beküldés` section when no submission action is available
- [x] update the in-app GDPR text for the current Firebase, Cloudinary, WordPress, Mailchimp, and test-AdMob functions
- [x] add a second separated adaptive test AdMob placement after the first five news cards

Production AdMob identifiers and consent/privacy handling remain release work. The WordPress API `2.4.33` FAQ endpoint is available in production and is populated with the initial 10 Hungarian FAQ entries.

### v0.99.5 — complete

Implemented in Flutter `0.99.5+1`:

- [x] password reset, visibility toggle, clear Hungarian authentication errors, and strong-password suggestion
- [x] clickable social buttons plus avatar refresh, crop, zoom, and positioning persistence
- [x] Chat profanity masking and automatic message/avatar refresh
- [x] native admin panel scope and readable content with concise save/cancel errors
- [x] final loading/card/control polish and test-AdMob placement

Phone-verified by the project owner; all listed v0.99.5 items are marked complete. ARM64 test APK: `build/HUHS-v0.99.5+1-arm64-debug.apk`.

### v0.99.6 — complete

- [x] allow gallery images to be saved to the device, including the pre-Android 10 permission fallback
- [x] make widget tests Firebase-safe and restore a green test run
- [x] update Gradle, Android Gradle Plugin and Kotlin compatibility
- [x] finalize the full HUHS-logo startup animation
- [x] polish profile and Chat avatar refresh/cache behavior
- [x] complete a Hungarian text and character-encoding audit
- [x] resolve remaining accessibility and layout-overflow issues
- [x] complete AdMob test-placement and display verification
- [x] produce and verify the final ARM64 debug test APK for this build

Analyzer and the complete Flutter test suite pass. The final ARM64-only debug artifact is `build/HUHS-v0.99.6+1-arm64-debug.apk` (package `0.99.6`, ARM64 ABI). Graphify was refreshed after the final source and documentation changes.

Security hardening, obfuscation, release signing and purchase/store work remain scheduled for v1.0+. The Label release catalog is complete in v0.99.89; paid music sales will later extend this same Label area.

### v0.99.8 closure (2026-08-06)

v0.99.8 is complete and closed. The final ARM64 debug test APK is `build/HUHS-v0.99.8+16-arm64-debug.apk`. Completed scope: friend requests and push delivery, push-to-requester profile navigation, accept/reject/unfriend flows, live role/access badges in Chat, public profiles and friends, favorite DJs/organizers on profiles (favorite news excluded), planned events and attendance, registered Chat writes, native Chat author profiles, report management, biometric session handling, and admin role/access management. Firebase rules and the connection-request FCM trigger are deployed. `flutter analyze`, the full Flutter test suite, Cloud Function syntax checks and Graphify refresh pass. v1.0 remains for security hardening, obfuscation, release signing, purchase/store work and final release preparation.

### v0.99.89 — Label release catalog (complete and closed, 2026-08-06)

The Label tab is live between Chat and Több. It reads WordPress-managed release records with title, clickable multiple artists, cover, genre, 60-second preview playback and Spotify, Apple Music, Beatport, Hardstyle.com and YouTube links. The uploaded MP3/WAV is only a temporary source: FFmpeg creates a preview from the 30th second, then the source is deleted. No full-track download, cart or purchase flow is included. ARM64 debug APK: `build/HUHS-v0.99.89+1-arm64-debug.apk`. The later paid music store will be implemented inside this Label catalog.

### v0.99.90 — HUHS Vezérlőközpont bugfixek (lezárva, 2026-08-07)

A korábbi build-ek továbbra is lezártak; ezek újonnan felfedezett hibák a következő buildhez:

- [x] Events, DJ-k, Szervezők és kapcsolódó beküldési szerkesztőkben a `Mégse` nem küld hibás piros hibaüzenetet, és nem hagy hibás űrlapállapotot.
- [x] A natív Mobil API-szerkesztő mezői tagoltabbak, a mezők között következetes térközzel.
- [x] A DJ-k kiválasztása név alapján történik; az eseményszerkesztő nem csak azonosítókat mutat.
- [x] A nem kért „Személyre szabott push” vezérlőfelület kikerült; az általános és az egyedi push megmaradt.
- [x] A vezérlőközpont életciklus- és párbeszédablak-kezelése védett a `_dependents.isEmpty` assertion ellen.
- [x] Elvégezve a célzott UX-, accessibility- és layout-polish: térközök, feliratok, vezérlők, loading/error állapotok és visszafogott működés ellenőrzése.

Telefonon ellenőrizve, a v0.99.90 lezárható. ARM64 debug APK: `build/HUHS-v0.99.90+3-arm64-debug.apk`. A HUHS Mobile API frissített csomagja `build/huhs-mobile-api-2.4.37.zip`.

### v0.99.7 — Community follow-up (complete)

- [x] allow verified-email users to claim a DJ profile after matching the private or artist-owned booking e-mail; the Hungarian Hardstyle-managed booking address never qualifies as proof
- [x] add registered-user search/listing under `Több`; the list filters from the first typed character
- [x] add admin-triggered personalized event and organizer notifications for favorited records
- [x] add community moderation follow-up with reporting, blocking, blocked-post filtering, and admin report visibility

Firebase rules and the `claimArtistProfile`/`sendPersonalizedPush` Cloud Functions are deployed. Flutter analyzer, tests, and Cloud Function syntax checks pass.
The final ARM64 debug test APK is `build/HUHS-v0.99.7+3-arm64-debug.apk`.

### v0.99.7+3 — Claim display follow-up (complete)

- [x] After a DJ profile is claimed, show one `Saját DJ-adatlap megnyitása` button on the user's profile; it opens the native in-app DJ detail screen through the deployed `getMyClaimedArtists` callable.

Security hardening, obfuscation, release signing and purchase/store work remain scheduled for v1.0+. The Label release catalog itself is already closed in v0.99.89.

### v0.99.8 — User profile navigation and community details (closed)

Status is authoritative: the voting fix is packaged as WordPress Mobile API `2.4.39`; the v0.99.99+2 ARM64 debug build is the current phone-test artifact. Earlier completed work is not reopened here.

- [x] Make each profile card in `Több → Felhasználók` tappable and open that user's native in-app profile.
- [x] On a user profile, show the user's favorite DJs, organizers, and events; favorite news does not appear in this profile section.
- [ ] Stabilize planned-event display and attendance states (`Ott leszek` / `Nem leszek ott`), persistence, participant counts and friend visibility.
- [ ] Stabilize friend requests, accept/reject, persistence and list consistency; remove false success/error states.
- [x] Keep separate Facebook, Instagram, TikTok, YouTube, and Spotify profile links (already implemented).
- [x] Show planned events and favorites on the user profile.
- [ ] Fix biometric enablement, false unlock errors, and session behaviour (once per open app, again after a full close).
- [ ] Complete registered/guest public-profile visibility, clickable friend lists, blocked-user list and report-status visibility.
- [x] Restrict Chat message editing and deletion to admins; normal users cannot edit or delete their own messages.

### v0.99.8 open fixes (including the former +3 follow-up)

- [ ] Show the requester's display name/avatar instead of a UID and retain friend connections consistently.
- [ ] Send connection-request push notifications reliably and remove false-success/false-failure errors.
- [x] Make profile favorites and planned events open their native detail screens.
- [ ] Complete admin report management: reporter, reported user, reason, message details, resolve/close (removed from the active list), delete-message and block-user actions; remove duplicate report UI and mojibake.
- [ ] Provide unfriend/remove actions and context-sensitive friend controls on public profiles; own profiles must not show self-actions.
- [ ] Let registered non-admin users write Chat messages and make Chat author name/avatar open the native profile.
- [ ] Fix admin account-role changes.

#### FAQ-választervezet

- **Hogyan regisztrálhatok?** A Több → Profil oldalon e-mail-címmel vagy Google-fiókkal regisztrálhatsz. Regisztrációkor kötelező szerepkört választani: bulizó, DJ vagy szervező.
- **Módosíthatom később a szerepkörömet?** Nem. A szerepkör a regisztráció után végleges; módosítani csak adminisztrátor tud.
- **Hogyan küldhetek be tartalmat?** A beküldés regisztrációhoz és a megfelelő szerepkörhöz kötött. A beküldés szerkesztői jóváhagyás után jelenik meg.
- **Hogyan működnek a kedvencek?** A hírek, események és DJ-k adatlapján a szív ikon menti vagy törli a kedvencet. A mentett elemek a Kedvencek menüben kezelhetők.
- **Hogyan működnek a push értesítések?** A beállításokban kapcsolhatók. Értesítés érkezhet új hír, új esemény és esemény-emlékeztető miatt.
- **Hogyan használhatom a rádiót?** A Real Hardstyle FM lejátszója a főképernyő alján található. A Play/Stop és némítás gombbal vezérelhető; a szám címe akkor látható, ha a stream metaadata elérhető.
- **Hogyan iratkozhatok fel a hírlevélre?** A Több → Hírlevél menüben add meg az e-mail-címed, majd erősítsd meg a feliratkozást a kapott e-mailben.
- **Hogyan törölhetem a profilomat?** A saját profil oldalon válaszd a Profil törlése lehetőséget, majd erősítsd meg a műveletet.
- **Hogyan kezeljük az adataimat?** A Firebase a közösségi fiókot és Chat-adatokat, a Cloudinary a feltöltött képeket, a WordPress a tartalmakat, a Mailchimp a hírlevél-feliratkozást kezeli. Részletek az Adatvédelem és GDPR menüben.
- **Hogyan jelezhetek hibát vagy támogathatom a projektet?** A Több → Hibajelzés előre címzett e-mailt nyit meg az app verziójával. Támogatáshoz használd a Támogatás / Donate menüpontot.

Backend **2.4.7** is deployed and awaiting live approval-flow testing. It fixes DJ/organizer approval redirects and adds one-click event draft creation from pending submissions; generated drafts remain non-visible until reviewed and published manually.

Backend **2.4.8** is deployed. It adds a separate optional DJ-logo upload, an editable DJ website field across WordPress, REST API, public profiles, and Flutter, and complete event details when an event is opened from a DJ or organizer profile. The profile-event navigation fix is live-verified.

Cloudinary is the only active image-upload path. The dedicated Facebook Event URL field is deployed in backend 2.4.3; the app submission field remains a general event link.

Implemented:

- dark Material 3 Flutter UI with Riverpod and Dio
- API-backed news list, search and detail views
- rich news content, galleries, embeds and in-app link handling
- dynamic events with flyers, tickets, Maps and related profiles
- searchable DJ and organizer directories with full profile pages
- related upcoming events on DJ and organizer profiles
- moderated event, DJ and organizer submissions
- Cloudinary-backed image submissions for event flyers, DJ profile images and organizer logos
- WordPress admin approval into non-public draft profiles
- local favorites for news, events, DJs and organizers
- native Mailchimp newsletter signup
- Firebase/FCM push notifications for news and events, including foreground display

## Roadmap

### Current bug-fix backlog

- [x] make AdMob initialization failure-safe and platform-aware so it can never block app startup
- [x] add the iOS AdMob test application identifier; replace it with the production App ID before release
- [x] remove the remaining event-card overflow at 2.0x accessibility text scaling and add a small-screen regression test
- [x] prevent the favorites startup load from overwriting a newly saved favorite
- [x] make saved news, events and DJs openable from the Favorites screen
- [x] dispose late AdMob banner callbacks safely; consent/privacy handling remains required before production ads
- [x] replace the three deprecated `withOpacity()` calls
- [x] restore artist/DJ logo rendering on both the Flutter app and public WordPress pages
- [x] make newly published or edited DJ profiles refresh reliably in the app without forced refresh
- [ ] upgrade Gradle, Android Gradle Plugin and Kotlin before current Flutter support is dropped

### v0.4 — Foundation

- [x] Flutter application structure and dark brand UI
- [x] WordPress REST API foundation
- [x] API-backed news, search and detail screens
- [x] pull-to-refresh and basic loading/error handling
- [x] update the default widget test for `HungarianHardstyleApp`
- [ ] finish asset cleanup and launcher icon setup
- [ ] set the final Android application ID and release signing

### v0.5 — Dynamic events

- [x] API-backed event list and detail screen
- [x] flyer, ticket and Google Maps actions
- [x] clickable DJ and organizer relationships
- [x] public event submission form with server-managed genres
- [x] gallery/camera flyer upload
- [ ] complete an intentional live submission and approval test
- [ ] finish the public WordPress event detail experience

### v0.6 — DJ database

- [x] searchable DJ list
- [x] Hardstyle and Hardcore category filters
- [x] API-backed DJ profiles
- [x] profile image, biography, genres, location and social links
- [x] TikTok and upcoming events
- [x] moderated DJ submission with optional profile image
- [x] Hungarian Hardstyle-managed booking option
- [x] standardize every DJ list image to one card frame and aspect ratio with upper-center face-focused cover cropping
- [ ] complete an intentional live image submission and approval test

### v0.7 — Organizers

- [x] searchable organizer list
- [x] API-backed organizer profiles
- [x] logo, description, location, website and social links
- [x] related upcoming events
- [x] moderated organizer submission
- [x] gallery/camera logo upload in backend 2.4.2
- [x] standardize every organizer list image to the same fixed card frame; logos retain contain rendering inside the frame
- [ ] live-verify organizer logo upload and draft-profile approval
- [x] add optional multi-select music genres/styles (backend 2.4.9 prepared)

### v0.8 — Rich content

- [x] YouTube, Spotify, SoundCloud, Instagram and TikTok embeds
- [x] WordPress galleries and supported shortcode detection
- [x] shared in-app browser for normal content links
- [x] automatic linkification of plain-text web URLs
- [ ] add a private AI-assisted WordPress article importer
- [ ] enforce draft-only import, attribution, safe URL fetching and media rights checks

### v0.9 — Community utilities (implemented)

- [x] local favorites for news, events, DJs and organizers
- [x] allow the featured news card on Home to be marked as a favorite
- [x] show the opened news title in the app-bar instead of the generic `HĂ­r` label
- [x] show the opened event title in the app-bar instead of a generic event label
- [x] Mailchimp newsletter signup via hosted landing page
- [x] native Mailchimp newsletter signup screen with a WordPress server-side proxy (backend 2.4.15 live; personal e-mail double-opt-in test successful)
- [x] organizer favorites in profile screens and the local favorites list
- [x] notification and cache settings
- [x] social, contact and About sections
- [x] show runtime app version and build number from package metadata
- [x] prepare local push notification preferences
- [x] integrate the Firebase/FCM client and store the device token locally
- [x] open related WordPress articles (including "Kapcsolódó cikk", "Kapcsolódó", and "Ez is érdekelhet" links) in the native app news screen; backend 2.4.12 is live and the detail endpoint was verified with a real related article
- [x] rename the artist website label to `Website`
- [x] rename the artist booking action to `Booking` or `Fellépés lekötése`
- [x] add organizer genre/style selection in WordPress, API, and submission flow (backend 2.4.9 prepared)
- [x] configure and live-test WordPress-created custom push delivery; news and event publishing pushes plus foreground display are live-verified
- [x] implement one-week and event-day reminder scheduling in the backend
- [x] monitor the first natural one-week and event-day reminder occurrences; event-day delivery is live-verified

Push setup: in Firebase Console open Project settings → Service accounts → Generate new private key, then upload the downloaded JSON under WordPress `HUHS Mobile → Push értesítések`. The JSON stays on the server; never commit or embed it in Flutter.

Push verification after uploading the WordPress package:

- choose a published news item or event by title in the custom-push form and send it; the app should open the native detail screen;
- paste a HUHS news/event URL as an individual link; the server resolves it to the native detail screen, while unrelated external URLs open in the in-app browser;
- [x] publish a new news item and a new visible event, then verify the automatic notifications;
- [x] create a future event and monitor the one-week and event-day reminder jobs at their first natural occurrences.

### v0.95 — Media

- [x] Spotify playlist section with five curated Hungarian Hardstyle playlists (Spotify app first, browser fallback)
- [x] compress submission images on-device before upload (target: up to 1600 px, quality 82; native picker output)

### v0.97 — Polish build

Small, low-risk finishing work that can be released independently before the larger v1.0 modules:

- [x] show uploaded/approved DJ logos in the Flutter DJ list and profile with a consistent fallback order
- [x] standardize DJ and organizer list thumbnails with a fixed frame, cover crop and upper-center face focus
- [x] include `Happy Hardcore` in the shared DJ, event and organizer genre options
- [x] keep DJ names readable in the two-column cards; keep them on one line and scale long names down instead of truncating them
- [x] rename the event ticket action in the app to `Jegyvásárlás`
- [x] use the Google Maps app when installed, otherwise the external browser fallback
- [x] verify the one-week, one-day and six-hour reminders
- [x] validate event postal codes as numeric-only in both Flutter and WordPress/API submission flows
- [x] keep new-event publication pushes global to FCM-token devices; personalized recipient rules remain a v1.0 task

### v0.99 — Submission polish

- [x] make event submission date, venue name, city and address required in Flutter and WordPress validation
- [x] add the required event address field below the venue name
- [x] add event end date and end time fields, validating that the end is not before the start
- [x] load the organizer list from WordPress and provide an organizer dropdown in the app and WordPress editor
- [x] require at least one genre and show inline error messages and red invalid-field styling for every missing required value
- [x] use direct Cloudinary uploads (`fjxo93em` / unsigned `Hun_hs_Mobile`) and pass returned image URLs to WordPress for DJ, organizer and event submissions
- [x] prepare WordPress Mobile API 2.4.28 for Cloudinary image URLs, the new event fields, numeric postal-code validation, automatic address-based Maps links and published post tag names; approval also migrates legacy image URL meta keys and the WordPress admin shows Cloudinary image previews

### v0.99 — Completed polish items

- [x] add a WordPress Mobile API trash/recycle-bin menu for deleted submissions and managed content, with restore and permanent-empty actions protected by capability and nonce checks
- [x] add a WordPress Mobile API `About` menu showing the developer/maintainer information and the current API version
- [x] refresh DJ/organizer list data after navigation instead of retaining stale family-provider cache
- [x] make event, DJ and organizer genre chips open grouped Események/DJ-k/Hírek discovery results
- [x] render the DJ logo on public WordPress artist profiles as well as in the app

### v0.99.1 — Community MVP (implemented; external setup remains)

- [x] app-only registration and sign-in code (e-mail/password and Google)
- [x] mandatory account role during registration: DJ, organizer or partygoer
- [x] profile from the top-left Home avatar, with profile image or monogram fallback
- [x] profile name, bio, social links, favorites and planned-events placeholder
- [x] Chat visible without registration
- [x] anonymous text posting with generated `Unknown User ####` display names
- [x] registered users can post text and compressed snapshots in Chat
- [x] anonymous users cannot upload images
- [x] support Unicode emoji in messages and a small fixed reaction set (for example ❤️ 🔥 🙌)
- [x] use Firebase Authentication/Firestore for community data and Cloudinary for images; keep WordPress as the editorial source of truth
- [x] apply basic size, permission and ownership checks before adding full moderation/friend features in v1.0
- [x] remove the Chat composer overflow at narrow widths
- [x] native article tags: hydrate tag names from WordPress core REST when the HUHS endpoint only returns tag IDs
- [x] deploy `firestore.rules` to the `hungarian-hardstyle` Firebase project
- [ ] enable Google provider and add Android SHA-1/SHA-256 credentials, then replace `android/app/google-services.json`

### v1.0 — First public release

Core release quality:

- [ ] configure production release signing and final Android release packaging
- [ ] stabilize news, events, DJs and organizers for public release
- [x] make genre chips clickable and add a genre discovery screen with separate `Események`, `DJ-k` and `Hírek` result sections, using paginated infinite scroll for DJ/news matches
- [x] make artist/DJ profile genre tags open the same grouped `Események`, `DJ-k` and `Hírek` discovery view with the complete paginated result set
- [x] complete the Label release catalog in v0.99.89, including preview playback, WordPress release records, multi-artist links, cover art and external release links
- [ ] extend the same Label catalog later with paid Radio Edit/Radio Version and Extended/full products; no separate store/catalog is planned
- [x] add a purposeful Hungarian Hardstyle-branded loading animation without artificial startup delay, with reduced-motion support
- [x] refine the Android startup animation to use the full HUHS logo on a transparent/no-white background (complete)
- [x] introduce a persistent navigation shell with per-tab history
- [x] add the Chat tab to the persistent bottom-navigation shell
- [ ] polish the Android release and prepare iOS support

Authentication and community:

- [x] Google sign-in and app-only community accounts
- [x] let users choose an account role during onboarding: DJ, organizer, or attendee/partygoer
- [x] show DJ submission only to DJ accounts, organizer submission only to organizer accounts, and both to admins; enforce the same rules server-side
- [x] bootstrap a separate app-admin account and role with full submission approval and editing permissions
- [x] top-left Home avatar profile entry with profile image or monogram fallback
- moved to v0.99.8: user profiles with social links, planned events, and favorites
- moved to v0.99.7: add a `Több`-menu user directory/search listing registered users only
- moved to v0.99.7: allow DJ profile claiming after verified private/artist-owned booking e-mail; the Hungarian Hardstyle-managed booking address must never qualify as proof of ownership
- moved to v0.99.8: friend requests and an `Ismerősök` profile section
- [x] complete Live Feed chat/image-post moderation and community features (complete)
- moved to v0.99.8: event attendance: `Ott leszek` / `Nem leszek ott`
- moved to v0.99.8: show which friends are attending on event details
- moved to v0.99.8: friend attendance visibility
- moved to v0.99.7: personalized event pushes for favorites/attendance
- [ ] send publication and reminder pushes for featured events to every app-installed device with an FCM token, regardless of account registration (respect explicit notification opt-out)
- moved to v0.99.7: favorited-organizer event notifications
- [ ] optionally send a separate admin/editor push when a new event submission is received
- moved to v0.99.8: moderation/reporting/blocking follow-up; privacy and account deletion remain v1.0 work

App administration:

- [ ] keep WordPress as the editorial source of truth and enforce admin permissions server-side

News, events, DJs and organizers should remain readable without registration. Event, DJ and organizer submission forms remain public until authentication launches. After that, only signed-in users may see and use them, and the backend must reject unauthenticated submissions.

Radio delivery is now part of v0.99.2.1 through the Real Hardstyle FM stream and its in-app player.

### v0.99.99 — Annual HUHS voting (implementation ready; phone verification pending)

- [x] WordPress-managed voting seasons and candidates
- [x] best Hungarian hardstyle DJ
- [x] best Hungarian hardcore DJ
- [x] best Hungarian hardstyle track
- [x] best Hungarian organizer
- [x] best international DJ
- [x] authenticated one-user/one-vote enforcement
- [x] private admin dashboard and explicitly published public results
- [x] add a prominent Home button for the active voting season, controlled by an admin on/off setting and hidden when voting is inactive
- [x] require a registered, signed-in app account before voting
- [x] ask separately whether the voter wants the HUHS newsletter; only explicit consent may trigger the existing Mailchimp subscription flow

Implemented in source: WordPress-managed seasons/candidates with unlimited candidates per category, DJ and organizer candidates without Spotify/YouTube fields, and Spotify/YouTube support for the Hungarian hardstyle track category. The Home button appears only when a published, enabled season is within its configured time window. Registered-user voting, Firestore duplicate protection, separate Mailchimp consent, and the private admin summary remain in place. ARM64 debug APK: `build/HUHS-v0.99.99+2-arm64-debug.apk`; WordPress package: `build/huhs-mobile-api-2.4.39.zip`. Phone verification remains before final closure.

### v1.5 — Hardstyle Revolution Store

The Label preview catalog is already complete in v0.99.89; this section covers only the later paid extension.

- [ ] offer a rewarded-ad full MP3 download at 128 kbps only
- [ ] sell 320 kbps MP3 and WAV/lossless through Google Play Billing (not direct Google Pay checkout)
- [ ] process conversions in a background job and keep the WAV master private
- [x] verify Websupport FFmpeg support (`/usr/bin/ffmpeg` 4.4.2 with `libmp3lame`); background-job execution still needs an end-to-end test
- [ ] optional purchase and download history

Releases and Store use one WordPress-managed catalog rather than separate content systems.

## Navigation direction

- Home and News remain the first two primary destinations.
- The unused Tickets tab will be removed; its future primary-tab slot is now the Chat destination.
- The public WordPress `/events/` directory should later include an `Esemény beküldése` call-to-action, gated by authentication once registration is available.
- Events are a strong primary-tab candidate because they provide immediate utility.
- DJs and organizers may initially remain under More.
- The app now exposes the community destination as a dedicated Chat tab.
- Detail screens should open inside one persistent navigation shell instead of duplicating the bottom bar.

## Language direction

- The mobile REST APIs for news, events, DJs and organizers should serve the stored language requested by Flutter, with Hungarian fallback, rather than translating content on demand.

## Brands

- **Hungarian Hardstyle** — main community platform
- **Hardstyle Revolution** — record label and event series
- **Rave Revolution** — multi-genre hard dance event series
- **Hard Lake** — free summer event concept around Lake Velence

## Long-term vision

One connected platform for Android, iOS and the web, combining news, events, artists, organizers, community, radio, releases and digital music distribution.
- v0.99.8+2 bugfix pass: attendance writes now include the validated event ID; attendance UI reports save failures; connection-request state refreshes after sending; the named-database connection-request push trigger is deployed; biometric enablement requires real device support; Android uses a FragmentActivity host for local_auth.
