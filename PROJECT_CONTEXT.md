# PROJECT_CONTEXT.md

# Hungarian Hardstyle App

> AI Project Context
> Read this document before making any code changes.

---

# Project Goal

The Hungarian Hardstyle App is the official mobile application of the Hungarian Hardstyle community.

This is **NOT** just a news application.

The application should become the central platform of the Hungarian harder styles scene.

Everything should originate from WordPress and be available on:

- Android
- iOS
- Website

The WordPress installation is the single source of truth.

---

# Main Brand

## Hungarian Hardstyle

Main platform.

Contains:

- News
- Events
- Artists
- Organizers
- Releases
- Store
- Newsletter

---

# Related Brands

## Hardstyle Revolution

Functions:

- Record Label
- Event Series

Has its own:

- Facebook
- Instagram

Future:

- Releases
- Store
- Radio

---

## Rave Revolution

New event series.

Supports every harder electronic music style.

Examples:

- Hardstyle
- Rawstyle
- Hardcore
- Uptempo
- Hard Techno
- Reverse Bass

---

## Hard Lake

Free summer flashmob-style events.

Usually located at Lake Velence.

---

# Architecture

WordPress

↓

REST API

↓

Flutter

↓

Android

↓

iOS

Website uses the same WordPress backend.

Never duplicate data.

---

# Technology

Backend

- WordPress Plugin
- Custom Post Types
- REST API

Frontend

- Flutter
- Riverpod
- Dio
- Go Router

---

# Data Source

Everything must come from WordPress.

Never hardcode data unless temporary.

---

# Current WordPress Modules

## News

WordPress Posts.

Future:

Support all embedded content:

- YouTube
- Spotify
- TikTok
- Instagram

Links must open correctly.

---

## Artists

Contains:

- Name
- Image
- Biography
- Genres
- Country
- City
- Facebook
- Instagram
- TikTok
- Spotify
- SoundCloud
- YouTube

Future:

Upcoming Events list.

Clickable.

---

## Organizers

Contains:

- Logo
- Description
- Website
- Facebook
- Instagram
- TikTok

- Music genres/styles (multi-select)

Future:

Upcoming Events list.

Clickable.

Organizer genres are editable in WordPress, returned by the organizer REST API, and displayed on both app and public web profiles.

DJ and organizer listing cards must show images in one consistent frame size and aspect ratio. Use cover cropping with an upper-center focus so faces remain visible in portrait images while organizer logos and artwork keep the same card dimensions.

---

## Events

Contains:

- Title
- Description
- Flyer
- Start date
- End date
- Venue
- ZIP
- Address
- Country
- Google Maps
- Organizer
- Artists
- Ticket URL
- Featured
- Visible
- Status

Future:

Own frontend page.

---

# Releases

Future module.

Contains:

- Cover
- Artist
- Label
- Catalog Number
- Release Date
- Preview
- Spotify
- Hardstyle.com
- YouTube

Release = Product

Do NOT separate Releases and Store.

---

# Store

Future.

Runs from WordPress.

Uses Releases.

The current catalog only exposes a maximum 60-second preview. The later
store may offer a full 128 kbps MP3 after a rewarded advertisement, while
320 kbps MP3 and WAV/lossless remain paid products. Source/master files stay
private and higher-quality downloads require explicit paid entitlements.

---

# Radio

The radio is a v0.99.2.1 scope item, not a deferred post-v1.0 feature. Use the Real Hardstyle FM stream and its current-track metadata; the feature is complete when a custom compact bar player matching the app's red-black design with Play/Stop/Mute, safe bottom-navigation placement, and the provider page are delivered.

Online streaming.

Background playback.

Place a compact, user-controllable player directly below the Hungarian Hardstyle logo on Home. A server-side AutoDJ should continuously rotate a configurable library of X uploaded tracks; Flutter consumes one live stream and does not bundle or sequence the production library. Audible playback starts only after a user action and can always be paused or stopped.

The former AutoDJ/AzuraCast and separate self-hosted radio-backend concepts are removed from the roadmap. The active implementation uses the Real Hardstyle FM stream.



Before implementation, decide music licensing, hosting, bandwidth, codec/bitrate, background playback, audio focus, interruptions, notification controls, and the initial X-sized music library.

---

# Newsletter

Mailchimp. The app now has a native signup screen backed by the live WordPress `newsletter/subscribe` endpoint (backend 2.4.15); invalid-email validation and a real personal e-mail double-opt-in test both succeeded. The Mailchimp API key stays on the server, and the hosted signup landing page remains available as a fallback.

No registration.

---

# Favorites

Stored locally.

No login.

Contains:

- Favorite News
- Favorite Events
- Favorite DJs

---

# Authentication

Current versions do not require registration and do not yet have user accounts.

For v1.0, add Google account sign-in and community user accounts.

Confirmed scope: registration and community accounts exist only in the mobile app. The public WordPress website does not need registration, user profiles, friendships, live feed, or chat UI.

Architecture exception: WordPress remains the single source of truth for editorial content, but app-only community data may use a separate real-time backend. This exception is limited to authentication, community profiles, friendships, chat/feed posts, image uploads, moderation state, and event attendance responses.

Public content such as news, events, DJs, and organizers should remain available anonymously where possible.

Authentication will be required for:

- live feed posting
- live chat
- image uploads
- creating and editing a personal profile
- adding and managing friends
- event attendance responses
- submitting DJs, organizers, and events once registration has been introduced

Until registration exists, the current public submission forms may remain available with rate limiting, file validation, and mandatory editorial approval. When authentication launches, Flutter must hide these forms from signed-out users and the backend must reject unauthenticated submissions.

The authentication and community backend must support privacy controls, moderation, reporting, blocking, account deletion, and safe image storage.

---

# REST API

Current

/events

/artists (backend 2.2.0 deployed and verified; returns only visible DJs)

/artists/{id} (deployed and verified with live DJ data)

/event-submission-options (backend 2.2.0 deployed and verified; shared genre options)

/event-submissions (POST, backend 2.2.0 deployed; validation verified, successful creation awaits intentional app test)

/organizers (backend 2.3.0 deployed and live-verified)

/organizers/{id} (backend 2.3.0 deployed and live-verified with upcoming events)

/profile-submission-options (backend 2.4.0 deployed and live-verified)

/artist-submissions (POST route live-verified in backend 2.4.0; pending editorial review)

/organizer-submissions (POST route live-verified in backend 2.4.0; pending editorial review)

Future

/releases

/store

---

# Mobile Navigation

Bottom Navigation

- News
- Events
- DJs
- Organizers
- More

Confirmed navigation change:

- The old empty Tickets slot is now used by the completed Live Feed/Chat destination.
- Do not reintroduce a separate Tickets slot or replace the Live Feed/Chat destination with the DJ directory.
- Home and News should remain the first two bottom-navigation items.
- Define a deliberate importance order for what belongs on Home, in primary navigation, and under More. The leading user-hook hypothesis is immediate utility (what is happening now / what event is next), making Events a stronger primary-tab candidate while DJs may initially live under More.
- Revisit this choice using real testing and usage feedback before locking the final navigation.
- The dedicated Live Feed/Chat tab and its bottom-navigation placement are implemented; do not treat them as future work.
- Detail screens should eventually open inside a persistent navigation shell so the bottom tabs remain visible and the active tab/history is preserved. Implement this centrally rather than copying the bottom bar into each detail screen.

Confirmed event relationship behavior:

- Event content remains managed through the WordPress API.
- Every related DJ/artist name and the organizer shown on event detail must be clickable.
- They must navigate to complete dedicated DJ and organizer profiles populated from WordPress REST APIs.
- DJ and organizer profile screens are API-backed and connected to their event relationships.

---

# More Menu

Favorites

Newsletter

Settings

Social

Contact

About

The future About/App information screen should include:

- app name
- runtime app version and build number (read from package metadata, not hardcoded)
- developer/maintainer credit
- Hungarian Hardstyle website
- contact link
- privacy policy
- terms/community guidelines
- optional open-source licenses

---

# Settings

Contains

Push Notifications

News Notifications

Event Notifications

Version

Cache

Future

Theme

Language

---

# UI

Dark theme.

Modern.

Minimal.

Fast.

Use rounded corners.

Consistent spacing.

Avoid clutter.

---

# Flutter Rules

Always use:

Riverpod

Go Router

Dio

Models

Providers

Repositories

Avoid duplicated code.

---

# WordPress Rules

Everything should be editable from WordPress.

Never hardcode content.

Always expose new modules through REST API.

## AI-assisted editorial importer

Add a private WordPress admin workflow where an editor enters a public article URL and receives a Hungarian draft with supported media placement. Publishing that WordPress post should make it available to both the website and the existing Flutter posts API.

Requirements:

- always create a draft and require human editorial approval
- provide an original Hungarian summary/adaptation mode with a visible source link for third-party reporting
- store the source URL and attribution metadata
- import featured and inline images into the WordPress Media Library only when reuse rights are confirmed; otherwise require an owned/replacement image
- never expose the AI provider key to Flutter or public REST responses
- validate remote URLs and block internal/private network targets, unsafe HTML, oversized downloads, and slow requests
- retain the existing WordPress post format so galleries, embeds, website rendering, and the Flutter app continue to use one source of truth

---

# Future Features

- Purposeful Hungarian Hardstyle-branded loading animation for v1.0, without artificial startup delay and with reduced-motion support
- The full HUHS-logo startup animation with transparent/no-white background is complete.

- Online Radio is a v1.0 goal, with a Home mini-player and server-side AutoDJ

- Five curated Spotify playlists should be available from a dedicated app section; open Spotify first and fall back to the browser.

- Before external/cloud image uploads, compress submission images on-device to roughly 1200–1600 px width in JPEG/WebP format to reduce storage and bandwidth use.

- Hardstyle Revolution Releases are covered by the completed v0.99.89 WordPress-managed Label catalog; paid purchase/store remains a later extension in that same area.

- Music Store

- Hungarian Hardstyle Top DJ Voting

- Top Track Voting

- Calendar integration

- Better search

- Recommendations

- Live Feed with chat, image posts and moderation is complete.
- Push notifications should cover new published news, new published events, event reminders one week before and on the event day, plus admin-created custom notifications from WordPress.
- Event-day reminder delivery is live-verified and is not an open investigation.
- Current push status: Flutter initializes Firebase/FCM, stores the token locally, registers it with the WordPress API, shows foreground notifications, opens news/event targets in native screens, and syncs per-device notification preferences. Backend 2.4.16 includes Firebase HTTP v1 sending, news/event/link targets, automatic HUHS URL resolution, publish hooks, event reminder scheduling, preference filtering, and a protected service-account settings page. Custom push, news/event publishing pushes, and foreground display are live-tested successfully; the first natural event-day reminder did not arrive, so WP-Cron execution, timezone/date parsing, preference filtering, and the FCM send path must be investigated. Credentials must never be embedded in Flutter or committed to the plugin.
- The WordPress custom-push form lists the latest published news and events by title, so editors do not need to know WordPress post IDs. It validates that the selected content matches the chosen target type.
- Backend 2.4.12 is live with published IRP related-post records and a public post-detail endpoint. The live endpoint and a real "Kapcsolódó cikk" target were verified. Flutter opens IRP records and normal WordPress "Kapcsolódó cikk", "Kapcsolódó", and "Ez is érdekelhet" links in the native news detail screen and falls back to the in-app browser when no post ID is available.

- Google account registration and sign-in

- Community user profiles

- Friend connections

- Event attendance (`Ott leszek` / `Nem leszek ott`)

- Friend attendance visibility on profiles and events

- WordPress-managed FAQ / GYIK is planned for v0.99.4 under More, with categories, ordering, search, and expandable answers in Flutter

## Annual Top DJ And Track Voting

v0.99.99 is complete and phone-verified: one WordPress season editor provides category-level candidate fields, WordPress manages unlimited candidates per category, DJ and organizer candidates do not use Spotify/YouTube links, the Hungarian hardstyle track category supports optional Spotify/YouTube, Flutter enforces category selection limits of 5/3/2/1/3, displays the active Home entry and voting categories with a 5-second API timeout, registered-user votes are protected by Firestore rules, the newsletter question is separate and explicit, and the native admin summary uses the deployed Firebase API function `getVotingSummary`. ARM64 debug APK: `build/HUHS-v0.99.99+6-arm64-debug.apk`; updated existing API package: `build/huhs-mobile-api-2.4.42.zip`. Test votes were cleared from Firebase after verification.

## v0.99.999 Android security and public QA

The scope was limited to security hardening and final public Android QA. R8/resource shrinking, Dart obfuscation with split debug symbols, non-debug release signing, HTTPS-only networking, Android backup disablement, and verification of existing Firebase/WordPress server-side authorization and rate limits are implemented. `flutter test` passes all 27 tests, and the signed ARM64 release artifact is `build/HUHS-v0.99.999+1-arm64-release.apk`. Phone testing, Google sign-in with the release certificate, Android QA and signing-key backup are complete. Permanent Play publication, paid Label sales and iOS remain v1.0 scope.

The existing annual WordPress-extension voting workflow should be replaced or complemented by a dedicated Hungarian Hardstyle voting module and REST API.

WordPress remains the administration surface and source of truth for:

- voting seasons and year
- start and end timestamps
- voting status and rules
- `Legjobb magyar hardstyle DJ – <év>` candidates
- `Legjobb magyar hardcore DJ – <év>` candidates
- `Legjobb magyar hardstyle zene – <év>` candidates
- `Legjobb magyar szervező – <év>` candidates
- `Legjobb külföldi DJ – <év>` candidates
- candidate names, artist/title data, images/covers, optional previews, and external links
- result publication settings

The displayed year should come from the voting season configuration. Candidate types must support DJs, organizers, and tracks.

Flutter must:

- fetch the active annual voting season and categories
- show a prominent Home button for the active season; WordPress/admin configuration must be able to enable or disable it, and it must be hidden when no voting is active
- display DJ and track candidates
- allow authenticated users to vote in-app
- clearly show whether the user has already voted
- require a registered, signed-in app account; guests cannot vote
- ask separately about HUHS newsletter subscription and call the existing Mailchimp flow only after explicit consent
- show results only according to the server-defined visibility policy

The backend must enforce voting windows, authentication, duplicate-vote prevention, and category limits. Prefer one authenticated user vote per category by default. Before implementation, decide whether votes can be changed, when results become public, what audit data is retained, and how suspicious voting is moderated.

WordPress admin must include a private overall results dashboard with:

- total submitted votes
- unique voter count where privacy rules allow it
- per-category totals and ranking
- candidate vote totals and percentages
- optional suspicious-vote/moderation indicators
- export capability if needed later

This summary is admin-only. Do not expose it through public REST routes and do not make it visible to ordinary app users unless a season explicitly publishes a separate sanitized result response after voting closes.

### Published Results After Voting

When voting is closed, WordPress admins must be able to explicitly publish a separate results summary that the Flutter app can display. Closing a season and publishing its results are separate actions.

The public results API/page should support:

- season title and year
- voting closed timestamp
- all published categories
- final candidate ranking per category
- candidate name/title and image/cover/logo
- optional vote count and percentage controlled by season settings
- winner highlighting

The public result must never expose voter identities, authentication identifiers, raw vote records, IP/device data, audit logs, moderation notes, or suspicious-vote indicators. Admins should also be able to keep results private or unpublish the public summary if correction is required.

---

# iOS

Application must fully support:

- Android

- iPhone

Future:

iPad

---

# Current Version

v0.99.1+12 (current Flutter package version; community authorization build)

Planned next package: v0.99.2. Its first release check is the AdMob test banner, enabled for the test build with `HUHS_ENABLE_TEST_ADS=true`. Production AdMob IDs and consent/privacy handling remain deferred until the public release.

The v0.99.3 scope also includes making the About screen contact e-mail open the device mail app and keeping the Real Hardstyle FM stream playing when the user switches between apps.

v0.99.4 is implemented and closed in Flutter `0.99.4+3`: the `Több` menu is categorized as `Felfedezés`, `Közösség`, `Beküldés`, `Kapcsolat és támogatás`, and `Alkalmazás`; Donate, versioned feedback e-mail, FAQ search/category/expandable answers, account-backed favorites with bulk deletion, compact social buttons, Home/news test AdMob banners, Instagram URL normalization, and equal-height compact Home event cards are implemented. The WordPress Mobile API `2.4.33` is uploaded, deployed, live-verified, and active with the public FAQ endpoint and managed FAQ post type. Production AdMob identifiers and consent/privacy handling remain release work.

v0.99.2 bugfixes to investigate: e-mail/password sign-in fails despite valid credentials; saved profile images do not render on the profile/avatar; admin user deletion returns a Firebase Functions `INTERNAL` error; and the owner account intermittently falls back from `Szervező` to `Bulizó` while admin access must remain intact. Account roles are final after registration; only admins may change another user's role, enforced server-side. Profiles and Chat must render the persisted account role, with separate `Admin` or `Moderátor` access badges.

Tag- and genre-filtered discovery lists must use API pagination/infinite scroll so all matching news and DJ results can be reached, not only the initially loaded page.

v0.99.3: separate Facebook, Instagram, TikTok, YouTube, and Spotify fields are implemented during registration and in the community profile.
- Next build follow-up: add a password-reset link to login and replace raw Firebase credential errors with a clear Hungarian message.
- Next build follow-up: add password visibility toggles and an optional strong-password generator during registration.
- Next build follow-up: refresh the Home top-left profile avatar immediately after sign-in without requiring manual refresh.
- Next build follow-up: add a dismissible/pinnable Chat notice, admin-created pinned messages, admin pin controls, and a configurable profanity filter that masks blocked words with asterisks.
- Next build follow-up: show an admin-managed startup announcement image with a close button; allow image upload/replacement from the app admin panel and the WordPress Mobile API.
- v0.99.2 follow-up: allow gallery images to be saved to the device with platform permission handling.
- v0.99.2 follow-up: add a Data protection / GDPR information section covering privacy, retention, and user rights.
- v0.99.2 follow-up: review personal-data access rules and keep sensitive operations server-side.
- v0.99.2 follow-up: add practical release hardening (release signing, obfuscation, restricted backend secrets, and abuse/rate-limit checks); absolute protection against reverse engineering is not possible.
- v0.99.2.1 radio scope: completed the Real Hardstyle FM integration at `https://stream.realhardstyle.nl` as the Home radio stream, with a custom compact bar player (Play, Stop, and Mute), current-track metadata when available, safe placement above bottom navigation, and a More-section provider page with the supplied logo, website, and attribution text.
- Real Hardstyle FM provider page must include this legal information: the radio is operated by Dutch Real Hardstyle; according to the provider's public information it has the required Dutch music-rights licences (Buma/Stemra and Sena); Hungarian Hardstyle stores no music files, operates no radio media server, and does not broadcast its own stream; the app only accesses and plays Real Hardstyle's official external stream.
- v0.99.2.1 follow-up: completed the readable modern/cyber-style font fallback with Hungarian accented-character support.

### v0.99.3 - HUHS Vezérlőközpont

- The WordPress Mobile API administration is implemented in source as a separate, red-black branded, Admin-only `HUHS Vezérlőközpont`. It covers readable event/DJ/organizer content and custom metadata editing, submissions, trash, Mobile API settings/status, push, newsletter status, shortcodes, About data and the persistent `Indítási kép`; the radio provider and generic WordPress news/page/media/comment/taxonomy/user menus are excluded.
- A separate admin-only `Felhasználók` menu with search and user-management actions is implemented.
- Event submission is restricted to authenticated registered users in Flutter and unauthenticated API requests are rejected.
- The approved red-black TypeUI layout is implemented globally across Home and every menu/screen with Rajdhani typography, consistent cards and controls, compact sections and radio bar, the unchanged original `assets/logos/huhs_logo.png` HUHS logo, and the `A magyar hardstyle otthona` Home slogan.
- The Home logo area does not repeat bottom-navigation destinations. The persistent radio control is a compact two-line TypeUI bar with a dedicated Play/Stop control, station label, current-track line and Mute control.
- Startup-image saving no longer reports a false failure after a successful backend save; the native admin refresh assigns the new request inside a synchronous `setState` callback.
- The native startup-image dialog includes a delete action that disables display and clears the stored image URL.
- The Chat composer keeps the camera action, emoji helper, and signed-in status on one compact line above the Send button, avoiding overlap on phone widths.
- The About screen contact e-mail opens the device mail app.
- Real Hardstyle FM keeps playing while switching between apps and stops when the app is fully closed.
- The profile screen uses the saved profile image, then the Firebase photo URL, then a name/e-mail monogram. Its editor previews the same circular crop used by the saved avatar and supports free pinch zoom plus horizontal/vertical pan.
- Existing Chat messages resolve the author's live community profile image and crop settings instead of remaining on the avatar stored when the message was created.
- Profile save, image changes, authentication changes and self-deletion invalidate the community auth/profile streams.

Current v0.99.3 source status (2026-07-29):

Completed in source: native Mobile API admin coverage, Firebase-to-WordPress proxy, TypeUI/Rajdhani design, radio behavior, profile image/monogram fallback with free two-axis zoom/pan/focus, profile refresh, persistent no-cache WordPress-backed startup image, Chat permissions/deletion/pinned data, REST/Firebase/Cloudinary checks, pagination, the event-tag fast-scroll fix and expired-event filtering.

Completed follow-ups: the Hungarian character-encoding/mojibake errors on the community profile screen are fixed, and the unnecessary `Beállítások`, `Hírlevél`, and `Shortcode` entries are removed from the native HUHS Vezérlőközpont.

The final v0.99.3 source pass separates the read-only community profile from its editor, persists and reuses the circular avatar's X/Y position and pinch zoom, refreshes active Real Hardstyle FM metadata periodically, and removes the foreground-push lifecycle dependency on a transient widget context. Physical phone verification is performed separately by the project owner.

The Android radio foreground service now retries the Real Hardstyle FM stream after an unexpected playback error or stream completion instead of remaining silently marked as playing. Explicit Stop and full app closure still cancel pending reconnects.

The owner will perform phone verification separately. Firebase proxy Functions are deployed. The updated WordPress package is `build/huhs-mobile-api-2.4.37.zip`, which includes the completed Label release catalog endpoint, preview generation and the native controller editor choices. Security hardening and signing/obfuscation are covered by v0.99.999; paid store work remains v1.0.


Cloudinary is the only active image-upload path for the app. The dedicated Facebook Event URL field is deployed in backend 2.4.3 and tested.

Backend 2.4.9 organizer genre/style metadata and synchronized Flutter display/submission support are implemented; the Flutter changes pass analysis and all tests. Live organizer genre verification remains an editorial content check.

v0.9 implementation status:

- completed: local favorites for news, events, DJs, organizers, and the featured news card
- completed: native news/event titles, related-article navigation, artist Website/Booking labels, organizer genres, social/contact, settings, FCM registration, and custom push targets
- completed: native Mailchimp signup screen and WordPress proxy (backend 2.4.15 live; personal double-opt-in test successful)
- completed operational verification: one-week, one-day/event-day and six-hour reminder delivery is live-verified

v0.95 implementation status:

- completed: on-device submission-image resizing and quality reduction before multipart upload (up to 1600 px, quality 82)

v0.97 polish build status: complete

- fix DJ logo rendering in Flutter while retaining the profile-image fallback order
- standardize DJ and organizer list thumbnails with a fixed cover frame and upper-center portrait focus
- deploy backend 2.4.20 with `Happy Hardcore` in the shared DJ, event, and organizer genre options
- keep DJ names readable in two-column cards on one line by scaling long names down instead of truncating them beside action icons (implemented in Flutter)
- [x] rename the event ticket action to `Jegyvásárlás`
- [x] use the Google Maps app when installed, otherwise the external browser fallback
- one-week, one-day and six-hour reminders are live-verified

v0.99 submission polish:

- Event submission must require date, venue name, city, and address in both Flutter and WordPress/API validation.
- Add the required address field below the venue name.
- Add event end date and end time fields; reject an end datetime earlier than the start datetime.
- Populate the organizer dropdown from WordPress in Flutter and keep it aligned with the existing WordPress selector.
- Require at least one genre; missing required values must show inline messages and red invalid-field styling.
- Use only direct Cloudinary upload with the unsigned `Hun_hs_Mobile` preset, then send the returned URL to WordPress for DJ, organizer, and event submissions.
- Flutter implementation is complete in release `0.99.1+4`; WordPress Mobile API `2.4.31` is uploaded, deployed to production, live-verified, and confirmed active by the project owner; deployment and live verification are complete. It adds authenticated permission checks to submission POST routes while keeping public option GET routes available.
- v0.97 polish complete: event postal-code input accepts digits only in Flutter and WordPress/API validation; new-event publication pushes remain global to FCM-token devices.
- Planned v1.0 notification personalization: normal event pushes target users who favorited or marked attendance; featured-event publication and reminder pushes remain global to every app-installed device with an FCM token, regardless of account registration; users who favorite an organizer receive that organizer's new-event notifications. Explicit notification opt-outs remain respected. A separate admin/editor push for newly received submissions is an optional follow-up.

Planned v1.0 community profile details:

- expose the authenticated profile from a circular top-left Home avatar, using the profile image or a monogram fallback
- let users select an onboarding role: DJ, organizer, or attendee/partygoer
- show DJ submission only to DJ accounts, organizer submission only to organizer accounts, and both to admins; enforce this in the backend as well as Flutter
- bootstrap a private app-admin account for the project owner with full submission approval and editing permissions; do not publish the owner e-mail in app content
- store profile social links, planned events, and favorites together in the profile area
- allow a registered user to claim a DJ profile only after verifying the private or artist-owned booking e-mail stored on that profile; exclude the Hungarian Hardstyle-managed booking address (`info@hungarianhardstyle.hu`) from ownership proof
- add friend requests and an `Ismerősök` list
- show attending friends on event details
- Reuse the Cloudinary direct-upload path for authenticated Live Feed/chat image posts.

Current v0.99.1 implementation status:

- The user-facing community destination is named `Chat`; the Firestore collection remains `live_feed_posts` for compatibility. The composer is responsive, Firebase initializes before the app shell, missing WordPress tag names are hydrated from the core posts REST endpoint, and Firestore rules are deployed. Google sign-in provider and Android SHA configuration are present; release-device verification remains a final external check.

- Flutter includes Firebase Auth registration/sign-in with mandatory DJ, organizer, and partygoer roles.
- The public Firestore Live Feed supports anonymous text-only posts, registered Cloudinary image posts, Unicode emoji, and fixed reactions.
- Home exposes a profile entry, a five-item news slider with 10-second rotation, and news detail exposes tappable tags with a native filtered article list.
- Firestore deployment files are `firestore.rules`, `firebase.json`, and `.firebaserc`; physical ARM verification and rules deployment remain external release checks.
- v0.99.1+12 fixes the community profile/avatar synchronization, signed-in Chat image permission state, author monogram/avatar rendering, separates account roles from access roles, adds admin-only Chat deletion and admin user-role management for legacy profiles, reloads profiles after Auth restoration, and deploys Firestore rules to the named `hungarian-hardstyle` database used by the app. Profile uploads use Cloudinary face-aware cropping; manual focal-point editing remains a later UX enhancement.
- Chat message deletion and the in-app role-management panel are implemented; actual Firebase Auth account deletion for another user is handled by the deployed server-side Cloud Function/Admin SDK task.
- The Cloud Function source is in `functions/` (`deleteCommunityUser`) and is deployed to Firebase. Artifact cleanup retains old function images for 90 days.
- Also record for the next fix pass: push notification text has an encoding bug and may show Hungarian punctuation/accents as HTML entities (for example `&#8211;`) instead of decoded characters.
- Additional community authorization requirements are implemented: the `djdeeroy@gmail.com` admin role is restored on profile load, normal users cannot change roles after onboarding, and admins can remove users and delete Chat messages.
- The latest v0.99.1 bugfix build addresses the previously reported profile/avatar, Chat deletion, logout, duplicate-role, and admin-menu issues. Manual focal-point editing remains optional UX polish.
- v0.99.1 remaining external check: verify Google sign-in on the release device with the current Firebase Android SHA configuration; manual profile focal-point editing remains optional polish.

Planned v0.99.1 Community MVP decisions:

- The Live Feed is publicly readable without registration.
- Signed-out users may publish text only under a generated `Unknown User ####` display name; they cannot upload images or create profiles.
- Registration requires an account role: DJ, organizer, or partygoer.
- Registered users get an app-only profile with avatar/monogram, name, bio, social links, favorites, and planned events.
- Registered users may publish compressed snapshot images to the Live Feed.
- Live Feed messages support Unicode emoji and a small fixed reaction set without introducing a heavy emoji dependency.
- Firebase Authentication/Firestore is the minimal community backend; Cloudinary is the temporary image store. WordPress remains the editorial source of truth.
- Friendships, attendance visibility, profile claims, Live Feed moderation and app-admin tooling are complete; privacy and account deletion remain v1.0 work.
- Add a `Több`-menu user directory/search that lists registered users only and is unavailable to guests.
- Organize `Több`-menu entries into clear categories while keeping `Több` as the visible menu name.

Additional v1.0 product requirements:

- Refresh the WordPress-managed FAQ with the new v0.99.999/v1.0 features and current user guidance.
- Make displayed genres selectable. A genre detail/discovery screen should show separate API-backed `Események`, `DJ-k`, and `Hírek` sections for the selected genre and clearly retain the active genre label.
- The More-section `Támogatás / Donate` card is planned for v0.99.4, backed by a configurable PayPal donation URL with PayPal-app-first and browser fallback opening; do not build a custom payment flow.

Completed

âś" News

âś" Search

âś" Events Backend

âś" Artists Backend

âś" Organizers Backend

âś" Event REST API

âś" Flyer

âś" Ticket URL

âś" Google Maps

âś" Event Shortcode

Flutter Completed

- Dynamic Events in Flutter

- Event Detail with flyer, ticket and Google Maps actions

- HTML tag cleanup for news excerpts

- Clickable event artists and organizer open their API-backed profile screens and are verified with live data

- API-backed DJ directory under More with search, Hardstyle/Hardcore filters, portrait-focused profile cards, full DJ details, social links, biography, and upcoming events

- Event artist and organizer taps open their real API detail screens

In Progress

- Artists API and the Flutter DJ module are deployed and confirmed working with live data.

- Responsive WordPress collection shortcodes: `[huhs_djs]` groups linked DJ cards by category, while `[huhs_events]` lists all upcoming visible events with flyer, date, venue, details, and ticket actions

- Public WordPress archive URLs `/djs/` and `/events/` automatically use the plugin's matching polished collection templates; manual shortcode pages remain optional

- WordPress admin includes `HUHS Mobile > Shortcode-ok`, a copyable reference page for all supported shortcode variants and parameters

- Flutter Events includes an `Esemény beküldése` form. Genres come from WordPress, multiple genres can be selected, and successful submissions are stored as pending items for editorial review rather than being auto-published

- Organizer list/detail API and Flutter UI are implemented and live-verified, including search, logo, description, social links, and upcoming events

- Rich content: YouTube, Spotify, SoundCloud, Instagram and TikTok embeds now render in article detail; interactive WordPress shortcodes open in an in-app web view
- Backend package `2.2.0` includes the earlier rich-content fixes and DJ API/category work, plus the upgraded `[huhs_events]` collection, shared event/DJ genre options, and moderated public event submissions

- Backend `2.2.1` is deployed and confirmed working. It renames the DJ `hero_image` concept to `Profilkép` in the admin, uses that profile image before logo/featured-image fallbacks in DJ directories, and exposes `profile_image` in the artist API while retaining `hero_image` for compatibility

- Backend `2.2.2` is deployed and confirmed working. It and the Flutter DJ UI use consistent cover cropping with an upper-center portrait focal point so faces remain visible when source profile images have different dimensions
- Backend `2.3.0` is deployed and live-verified with organizer list/detail REST endpoints and related upcoming events; the Flutter organizer module and event-detail organizer navigation use these responses
- Backend `2.4.0` is deployed and live-verified. It adds moderated DJ/organizer submissions, admin approval into non-public draft profiles, public DJ booking e-mail support, and a `booking_via_huhs` option that routes booking requests to `info@hungarianhardstyle.hu`
- Backend `2.4.1` is deployed. It accepts optional multipart event flyers and DJ profile images, restricted to JPG/PNG/WebP and 5 MB, stores them as Media Library attachments on pending submissions, previews them for admins, and applies an approved DJ image to the generated draft profile
- Flutter event and DJ submission forms use the device gallery/camera with local preview instead of requiring users to paste image URLs
- Backend `2.4.2` is deployed and its organizer-logo upload was tested in the admin flow; an approved organizer submission receives the uploaded Media Library image as its logo and featured image
- Backend `2.4.3` is deployed and tested. It adds a dedicated `facebook_event_url` field to the WordPress event editor and events mobile API.
- Backend `2.4.7` is deployed and awaiting live approval-flow verification. It replaces the invalid nested approval form with a nonce-protected admin action, removes the misleading native publish box from submissions, restores DJ/organizer draft creation, and adds event-submission conversion into a non-visible event draft.
- Backend `2.4.8` is historical. Its multipart image path remains documented for compatibility, but the active app upload path is Cloudinary; the old upstream-WAF limitation is no longer a current deployment status.
- The public WordPress `/events/` directory should later include an `Esemény beküldése` call-to-action; after app registration is available, the action must require an authenticated user.
- Flutter includes DJ and organizer submission forms under More. DJ submitters can choose Hungarian Hardstyle-managed performance booking; submitted profiles still require WordPress editorial approval and explicit publication/app visibility
- Submitted profile and organizer images are reviewable URLs. They are not automatically copied into the WordPress Media Library; the editor selects/imports the approved image before publication
- DJ logos now render in Flutter and public WordPress artist profiles; direct multipart upload remains separate and uses Cloudinary.
- Profile list refresh now uses auto-dispose providers; continue monitoring live WordPress/API cache behavior after publishing.
- Link handling implemented: normal news, event, ticket, and shortcode links open in one shared in-app browser view, and plain-text URLs in WordPress news/event HTML become tappable automatically. Native media and Maps handoff remain explicit exceptions.

- Web Event Detail

---

# Development Philosophy

WordPress is the CMS.

Flutter is the client.

Never duplicate content.

One backend.

Multiple platforms.

Keep architecture clean.

Keep code modular.

Think long-term.

---

# Vision

The Hungarian Hardstyle App should become the central hub of the Hungarian harder styles scene.

One platform.

One backend.

Multiple brands.

Multiple clients.

Android.

iOS.

Website.

Community.

Music.

Events.

News.

v0.99.4 follow-up status: the Beküldés section explains registration/role requirements when no action is available; Home event cards use the smaller uniform layout; the GDPR screen reflects current Firebase, Cloudinary, WordPress, Mailchimp, and test-AdMob data flows; the native news list has a second separated adaptive test-AdMob placement after the first five cards; and signed-in favorites persist in Firestore with a local cache and bulk deletion.

v0.99.5 is complete in Flutter `0.99.5+1`:

- password reset, visibility toggle, clear Hungarian authentication errors, and strong-password suggestion
- clickable social buttons plus avatar refresh, crop, zoom, and positioning persistence
- Chat profanity masking and automatic message/avatar refresh
- native admin panel scope and readable content with concise save/cancel errors
- final loading/card/control polish and test-AdMob placement

The final ARM64 debug APK artifact is `build/HUHS-v0.99.5+1-arm64-debug.apk`; it is phone-verified by the project owner and v0.99.5 is closed.

v0.99.6 is complete in Flutter `0.99.6+1`:

- gallery images can be saved to the device, including a pre-Android 10 permission fallback
- widget tests are Firebase-safe and the full test suite passes
- Gradle 8.14, AGP 8.11.1 and Kotlin 2.2.20 are verified
- the full HUHS-logo startup animation is active
- profile and Chat avatar refresh/cache behavior is covered by the current implementation
- Hungarian text and character encoding were audited
- accessibility/layout overflow coverage is green
- AdMob test placement and display are verified
- the final ARM64-only debug test APK is built and verified as `build/HUHS-v0.99.6+1-arm64-debug.apk` (package `0.99.6`, ARM64 ABI)

Everything connected.

### v0.99.7 - Community follow-up (complete)

- Verified-email DJ profile claiming matches the authenticated e-mail to the public artist booking e-mail; the Hungarian Hardstyle-managed booking route is excluded.
- Registered-user search/listing is available under `Több` and starts filtering from the first typed character.
- Admin-triggered personalized event and organizer pushes target users who favorited the matching record.
- Chat moderation includes report submission, user blocking, filtering blocked authors from the feed, and admin report visibility.
- Firestore rules and the `claimArtistProfile`/`sendPersonalizedPush` Cloud Functions are deployed. Analyzer, Flutter tests, and Cloud Function syntax checks pass.
- Final ARM64 debug test APK: `build/HUHS-v0.99.7+3-arm64-debug.apk`.

### v0.99.7+3 follow-up (complete)

- After a DJ profile is claimed, show one `Saját DJ-adatlap megnyitása` button on the user's profile; it opens the native in-app DJ detail screen through the deployed `getMyClaimedArtists` callable.

### v0.99.8 - User profile navigation and community details (complete)

- [x] Make each profile card in `Több -> Felhasználók` tappable and open that user's native in-app profile.
- [x] Show only favorite DJs, organizers, and events on the user profile, together with planned event attendance; favorite news is excluded from this profile section.
- [x] Add event attendance states (`Ott leszek` / `Nem leszek ott`), persist the choice, and show participant counts on event details.
- [x] Add basic friends/connections with request, accept/reject, and profile connection-list flows.
- [x] Separate Facebook, Instagram, TikTok, YouTube, and Spotify profile links.
- [x] Show planned events and favorites on the user profile.
- [x] Add biometric unlock for an already saved sign-in session.
- [x] Add simpler own-chat management, a blocked-user list, and report-status visibility.
- [x] Admin-only Chat message deletion and editing are enforced in the app and Firestore rules; normal users and moderators cannot delete or edit messages.
- v0.99.8+2 bugfix pass: attendance records now include the validated event ID; attendance errors are surfaced; connection-request status refreshes after send; the named `hungarian-hardstyle` database push trigger `notifyConnectionRequest` is deployed; biometric enablement checks real device support; `MainActivity` uses `FlutterFragmentActivity` for `local_auth`. Final ARM build is pending phone testing.

### v0.99.8+3 - Connections, reports and planned-event links (complete; phone verification pending)

- [x] Show the sender's profile name and avatar in incoming friend requests, with native profile navigation.
- [x] Send connection-request push notifications for list, map, string and legacy single-token storage.
- [x] Make profile favorites and planned events open their native detail screens.
- [x] Add an admin-only report-management screen with reported user/message details, resolve, delete-message and block-user actions.

### v0.99.8 closure (2026-08-06)

v0.99.8 is closed after the final community fixes. The final ARM64 debug test APK is `build/HUHS-v0.99.8+16-arm64-debug.apk`. Friend-request FCM delivery is live-verified; tapping the notification opens the requester profile. Chat reads live account/access roles, public profiles show favorite DJs/organizers but not favorite news, and the complete attendance, reports, biometric, Chat-permission and admin-role scope is implemented. Remaining release work belongs to v1.0.

### v0.99.89 - Label release-katalógus (complete and closed, 2026-08-06)

- A meglévő HUHS Mobile API új `huhs_release` erőforrást ad címhez, borítóhoz, műfajhoz, több előadóhoz és külső elérhetőségi linkekhez.
- A feltöltött teljes MP3 csak ideiglenes forrás; a plugin FFmpeg-gel a 30. másodperctől legfeljebb 60 másodperces preview MP3-at generál, majd törli az eredeti MP3-at. Az API kizárólag a preview URL-t adja vissza.
- Flutterben önálló `Label` alsó navigációs fül van a Chat és Több között.
- Az előadók külön kattinthatók, és az adott előadó további release-ei listázhatók.
- A preview saját lejátszóval hallgatható; vásárlás, kosár, letöltés és saját digitális store nem része ennek a buildnek.
- A kész cache-javító csomag a meglévő HUHS Mobile API 2.4.37-es változata, nem új API.
- A build lezárt: ARM64 debug APK: `build/HUHS-v0.99.89+1-arm64-debug.apk`.
- A későbbi fizetős zeneértékesítés ugyanebbe a Label katalógusba kerül; külön katalógus vagy külön Store-rész nem készül.

### v0.99.90 - HUHS Vezérlőközpont bugfixek (lezárva, 2026-08-07)

A korábbi build-ek késznek és lezártnak tekintendők. A következő hibákat a v0.99.90-ben kell kezelni:

- [x] A `Mégse` biztonságosan megszakítja az Events/DJ/Szervező és kapcsolódó szerkesztőket téves piros hiba és hibás űrlapállapot nélkül.
- [x] A natív Mobil API-szerkesztők mezői tagoltabbak és átláthatóbbak.
- [x] A DJ-k név alapján választhatók, nem csak ID-k jelennek meg.
- [x] A nem kért `Személyre szabott push` vezérlőfelület kikerült; az általános és egyedi push megmaradt.
- [x] A vezérlőközpont életciklus- és dialóguskezelése védi a `_dependents.isEmpty` assertion útvonalát.
- [x] A célzott UX-, accessibility- és layout-polish elkészült.

Telefonon ellenőrizve és lezárva. ARM64 debug APK: `build/HUHS-v0.99.90+3-arm64-debug.apk`. Az aktív, meglévő HUHS Mobile API frissített csomagja `2.4.37` (`build/huhs-mobile-api-2.4.37.zip`).
